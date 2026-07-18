extends Control

## 도착한 노드 화면 — 이동은 맵에서 끝났다(맵이 곧 탐험 인터페이스). 여긴 도착 카드(이벤트/줍기/로프 통과)·죽음·남기기 결정.
## 핵심 동사: 관리·판독·대비·남기기 (턴제 사색형). 로직은 core(ExpeditionRun·Situations), 여기선 렌더링·입력만.
## 그림은 _draw 로 그려 웹 안전(셰이더/GPUParticles 없음). 모바일 우선: 상단 HUD 바, 하단 큰 전진 버튼, 모달은 카드.
## 폭풍 biome 단면은 시각 폭풍 3층(1층 모래 헤이즈=_draw, 2·3층 파티클=StormFX)을 얹는다(_spawn_storm_fx).

var _run: ExpeditionRun

var _status_label: Label
var _water_label: Label
var _food_label: Label
var _aux_label: Label
var _advance_btn: EngravedItem
var _leave_btn: EngravedItem   ## "남기기" — 물건 하나 두고 계속 (런당 1회). 자발적 죽음은 없다(모든 죽음 비자발적).

var _death_panel: Control
var _death_label: Label

var _sit_panel: Control
var _sit_name_label: Label
var _sit_threat_label: Label
var _sit_text_label: Label
var _choice_box: VBoxContainer

var _bequeath: BequeathPanel               ## "남김 한 번" 모달 (공유 컴포넌트 — 지도와 같은 것)

var _section: SectionRun            ## 도착 노드의 단면 탐색 상태(예산·지점)
var _section_rect: Rect2            ## 단면 그림 영역(지점 히트테스트 기준) — 화면 전체(cover)
var _result_popup: ResultPopup     ## 조사·선택 결과 팝업(공유) — 하단 배너 대신 모달로 통일

var _hud_box: Control              ## 상단 HUD 바 — 진입 stagger 대상
var _bottom_bar: Control           ## 하단 버튼 묶음 — 진입 stagger 대상
var _scrim_top: GradientTexture2D  ## 위 가독 스크림(HUD 밑) — 풀스크린 그림 위 글씨 보호
var _scrim_bot: GradientTexture2D  ## 아래 가독 스크림(장소 이름·버튼 밑)
var _storm_fx: StormFX              ## 폭풍 biome 단면의 모래 파티클(2·3층) — 폭풍 아니면 null
var _storm_haze: GradientTexture2D ## 폭풍 1층(옅은 모래 헤이즈) — 1회 생성
var _vignette: GradientTexture2D   ## 가장자리 은은한 암전(시네마틱 깊이 + 가독) — 1회 생성

func _ready() -> void:
	_run = GameState.current_run
	if _run == null:
		# 안전장치: 지도를 거치지 않고 직접 이 씬으로 들어온 경우 (씬 전환 없이) 새 원정만 만든다.
		GameState.begin_run_in_place()
		_run = GameState.current_run
	# 위치 반영 바람 — 이 노드가 깊을수록 돌풍이 잦고 세다. 죽음 화면에도 분다(사막의 공기).
	# 엔딩 진입 시엔 엔딩곡이 스스로 바람을 끈다(AudioManager.play_reunion/play_cycle).
	var wind_nid: String = _run.target_node_id() if _run.target_node_id() != "" else _run.current_node
	AudioManager.set_wind(MapGraph.progress(wind_nid))
	_build_hud()
	_refresh()
	# 도착해서 들어온 노드 화면 — 죽음 / 목적지(결말) / 단면 탐색.
	if not _run.alive:
		_die(_run.death_cause)
	elif _run.target_node_id() == "end":
		_show_ending()
	else:
		# 이어하기 복원 — 이 노드의 단면 스냅샷이 있으면 그대로 살린다(살핀 지점·남은 예산·도착 카드까지.
		# _init 을 다시 태우면 도착 카드가 재추첨되고 예산이 리셋된다 — 정밀 복원, 사용자 확정 2026-07-10).
		var saved_section: Dictionary = GameState.section_state
		if not saved_section.is_empty() and str(saved_section.get("node_id", "")) == _run.target_node_id():
			_section = SectionRun.from_dict(saved_section)
		else:
			_section = SectionRun.new(_run, MapGraph.node(_run.target_node_id()),
				GameState.probed_spot_ids(_run.target_node_id()))  # 총괄자의 기억 — 살핀 지점 주입
			GameState.autosave_run(_section.to_dict())  # 도착 카드 추첨 결과 확정 — 다시 뽑히지 않게 즉시 저장
		# 폭풍 biome 노드는 위기곡으로 교체, 그 외엔 베드(이미 재생 중이면 무시 — 연속 유지).
		if str(MapGraph.node(_run.target_node_id()).get("biome", "")) == "storm":
			AudioManager.play_storm()
			_spawn_storm_fx()   # 시각 폭풍 2·3층(파티클) — 1층 헤이즈는 _draw 가 그린다
		else:
			AudioManager.play_bed()
		_refresh()
		queue_redraw()
		# 씬 등장 stagger(스펙 inScatter) — HUD → 하단 버튼 순. 단면 그림(배경)은 베일 페이드가 담당.
		# 죽음·결말 진입에선 생략(패널이 주인공이라 등장 연출이 어색하다).
		Transition.appear(_hud_box, 0.08)
		Transition.appear(_bottom_bar, 0.20)
		_sync_advance_gate()  # 필수 위협이 있으면 마주하기 전까지 "떠난다" 잠금
		# 도착하는 마지막 걸음이 행렬에서 사람을 앗아갔으면(지도가 못 보여주고 넘어온 손실) 여기서 알린다.
		var carried_loss: String = _take_loss_note()
		if carried_loss != "":
			_result_popup.show_result("", {}, _after_carried_loss, carried_loss, UITheme.DANGER, ResultPopup.party_state(_run, "lose"))
		elif not _run.pending_situation.is_empty():
			# 이어하기 복귀 — 카드가 열린 채 끊겼다. 결정부터 다시 마주한다.
			_show_situation.call_deferred()

func _build_hud() -> void:
	# 상단 HUD 바 — 가독성을 위해 반투명 어두운 배경 위에 텍스트. 전체 폭.
	var hud := PanelContainer.new()
	hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var hud_sb := StyleBoxFlat.new()
	hud_sb.bg_color = Color(0.03, 0.03, 0.05, 0.62)  # 풀스크린 그림 위라 살짝 짙게(가독)
	hud_sb.content_margin_left = UITheme.PAD
	hud_sb.content_margin_right = UITheme.PAD
	hud_sb.content_margin_top = UITheme.SAFE + 6.0
	hud_sb.content_margin_bottom = 14.0
	hud.add_theme_stylebox_override("panel", hud_sb)
	hud.add_to_group("ui_scatter")  # 전환 OUT 때 UI 층만 흩어짐(단면 그림=배경은 남는다)
	add_child(hud)
	_hud_box = hud

	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	hud.add_child(top)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", UITheme.FS_SMALL)
	_status_label.add_theme_color_override("font_color", UITheme.MUTED)
	top.add_child(_status_label)

	# 물·식량 = 가장 자주 보는 생존 수치 → 크게
	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 28)
	top.add_child(res_row)

	_water_label = Label.new()
	_water_label.add_theme_font_size_override("font_size", UITheme.FS_H1)
	res_row.add_child(_water_label)

	_food_label = Label.new()
	_food_label.add_theme_font_size_override("font_size", UITheme.FS_H1)
	res_row.add_child(_food_label)

	_aux_label = Label.new()
	_aux_label.add_theme_font_size_override("font_size", UITheme.FS_SMALL)
	_aux_label.add_theme_color_override("font_color", Color(0.62, 0.62, 0.68))
	top.add_child(_aux_label)

	# 하단 — 각인 버튼 두 개(남기기 · 떠난다). 상자 없이 그림 위 스크림에 얹는다(가죽 박스 폐기, 2026-07-06).
	var bar := CenterContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -128.0
	bar.offset_bottom = -UITheme.SAFE
	bar.add_to_group("ui_scatter")
	add_child(bar)
	_bottom_bar = bar

	var brow := HBoxContainer.new()
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.add_theme_constant_override("separation", 56)
	bar.add_child(brow)

	# 보조: 남기기(물건 하나 두고 계속, 런당 1회). 자발적 죽음은 없다 — 모든 죽음은 비자발적(고갈/위협).
	_leave_btn = UITheme.make_engraved_button("남기기", 17, false)
	_leave_btn.pressed.connect(_on_leave_pressed)
	brow.add_child(_leave_btn)

	_advance_btn = UITheme.make_engraved_button("떠난다 · 지도로", 21, true)
	_advance_btn.pressed.connect(_on_advance)
	brow.add_child(_advance_btn)

	_build_situation_panel()
	_build_death_panel()
	# 남기기·결과 팝업은 공유 컴포넌트(지도와 같은 것) — 코드로 얹는다.
	_bequeath = BequeathPanel.new()
	_bequeath.committed.connect(_on_bequeath_done)
	_bequeath.cancelled.connect(_on_bequeath_done)
	add_child(_bequeath)
	_result_popup = ResultPopup.new()
	add_child(_result_popup)

## 폭풍 단면의 모래 파티클(중경 2층 + 전경 3층)을 얹는다. 단면 그림 위·HUD·모달 아래(첫 자식).
## 밴드(폭풍 영역)와 1층 헤이즈는 _draw 가 화면 전체로 갱신한다(리사이즈 추종). CPUParticles2D 만(웹 안전).
func _spawn_storm_fx() -> void:
	_storm_fx = StormFX.new()
	add_child(_storm_fx)
	move_child(_storm_fx, 0)  # 첫 자식 = 단면 그림 위, UI(HUD·버튼·모달) 아래

func _build_situation_panel() -> void:
	_sit_panel = Control.new()
	_sit_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sit_panel.visible = false
	add_child(_sit_panel)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = UITheme.SCRIM
	_sit_panel.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sit_panel.add_child(center)

	# 각인 모달(가죽 카드 폐기) — 방사 어둠 + 헤어라인 사이 내용.
	var parts: Array = UITheme.make_engraved_modal()
	center.add_child(parts[0])
	var box: VBoxContainer = parts[1]

	_sit_name_label = UITheme.make_label("", UITheme.FS_H1)
	box.add_child(_sit_name_label)

	_sit_threat_label = UITheme.make_label("", UITheme.FS_SMALL, UITheme.SAND)
	box.add_child(_sit_threat_label)

	_sit_text_label = UITheme.make_label("", UITheme.FS_BODY)
	box.add_child(_sit_text_label)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 6)
	box.add_child(_choice_box)

func _build_death_panel() -> void:
	_death_panel = Control.new()
	_death_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_panel.visible = false
	add_child(_death_panel)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.04, 0.9)
	_death_panel.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_panel.add_child(center)

	# 각인 모달(가죽 카드 폐기) — 죽음도 담담하게, 헤어라인과 글만.
	var parts: Array = UITheme.make_engraved_modal()
	center.add_child(parts[0])
	var dbox: VBoxContainer = parts[1]
	dbox.add_theme_constant_override("separation", UITheme.GAP + 6)

	_death_label = UITheme.make_label("", UITheme.FS_BODY)
	dbox.add_child(_death_label)

	var to_next := UITheme.make_engraved_button("다음 원정대를 꾸린다", 19, true)
	to_next.pressed.connect(_on_next_party)
	dbox.add_child(to_next)

func _refresh() -> void:
	var food_per_leg: String = String.num(1.0 / float(ExpeditionRun.FOOD_EVERY), 2)
	_status_label.text = "%d번째 원정 · %d걸음 · 행렬 %d명\n걸음마다 물 %d · 식량 %s" % [GameState.expedition_count, _run.leg, _run.party_left(), _run.water_cost(), food_per_leg]
	var water: int = maxi(0, _run.get_res("water"))
	var food: int = maxi(0, _run.get_res("food"))
	AudioManager.warn_thirst(water)  # 물이 임계로 떨어지는 순간 경고음 1회(지도와 공용 상태)
	_water_label.text = "물 %d" % water
	_food_label.text = "식량 %d" % food
	_water_label.add_theme_color_override("font_color", _res_color(water, 3, Color(0.55, 0.78, 0.97)))
	_food_label.add_theme_color_override("font_color", _res_color(food, 2, Color(0.88, 0.72, 0.42)))
	_aux_label.text = "지닌 것: %s" % Items.tools_summary(_run.resources)
	_update_leave_btn()
	queue_redraw()

## "남기기" 버튼 상태 — 이미 남겼으면 잠그고("남겼다"), 아니면 남길 수 있는 자원이 하나라도 있을 때만 활성.
func _update_leave_btn() -> void:
	if _leave_btn == null:
		return
	if _run.bequeathed:
		_leave_btn.disabled = true
		_leave_btn.set_label("남겼다")
	else:
		_leave_btn.disabled = not _any_leavable()
		_leave_btn.set_label("남기기")

func _any_leavable() -> bool:
	for key in ["water", "food", "rope", "shelter"]:
		if _run.can_leave(key):
			return true
	return false

func _res_color(value: int, low: int, base: Color) -> Color:
	return UITheme.DANGER if value <= low else base

## 이어하기 복귀에서 이월 손실 팝업을 닫은 뒤 — 열려 있던 카드가 있으면 그것부터 다시 마주한다.
func _after_carried_loss() -> void:
	if not _run.pending_situation.is_empty():
		_show_situation()

## 방금 선택/조사가 행렬에서 사람을 앗아갔으면 그 서사를 꺼낸다. 죽었으면 버린다(죽음 화면이 말한다).
func _take_loss_note() -> String:
	var notes: Array = _run.take_loss_notes()
	if not _run.alive or notes.is_empty():
		return ""
	return "\n".join(PackedStringArray(notes))

# --- 입력 ---

func _on_advance() -> void:
	# 이동은 맵에서 끝났다. 이 화면은 도착한 노드 — 결정을 마쳤으면 지도로 복귀한다.
	if not _run.alive or not _run.pending_situation.is_empty():
		return
	# 폭풍/차단 같은 필수 위협은 마주하기 전엔 떠날 수 없다(스킵 방지 — 버튼도 잠기지만 방어적으로 막는다).
	if _section != null and _section.has_unresolved_threat():
		return
	GameState.arrive_node()

## "떠난다" 잠금 상태를 위협 게이트에 맞춘다 — 마주 안 한 필수 위협이 있으면 잠긴다.
## (카드/팝업이 열려 있는 동안의 잠금은 각 흐름이 따로 관리한다 — 여긴 위협 게이트만.)
func _sync_advance_gate() -> void:
	if _advance_btn == null:
		return
	_advance_btn.disabled = _section != null and _section.has_unresolved_threat()

## 남기기 — 물건 하나를 두고(자원 -비용) 계속 간다(런당 1회). 죽음과 분리.
func _on_leave_pressed() -> void:
	if not _run.alive or _run.bequeathed or _bequeath.is_open() or _sit_panel.visible or _result_popup.is_open():
		return
	_bequeath.open(_run, _run.target_node_id())  # 도착 노드에 남긴다
	_advance_btn.disabled = true
	_leave_btn.disabled = true

## 죽음 후 — 폭풍 막간(지도 쓸기·다음 원정대 지명)을 거쳐 마을(Loadout)로. 새 대장 특기·가방을 고른다(매 원정 다른 사람).
func _on_next_party() -> void:
	GameState.go_to_interlude()

# --- 상황 읽기 (결정 카드) ---

func _show_situation() -> void:
	var sit: Dictionary = _run.pending_situation
	var place_name: String = str(sit.get("name", ""))
	_sit_name_label.text = place_name
	_sit_name_label.visible = place_name != ""
	var threat_kind: int = int(sit.get("threat", Threats.Kind.CONSUMPTION))
	AudioManager.play_situation_card(threat_kind)  # 카드 열림 — 위협 종류별 소리(폭풍 돌풍·갈라진 울림·양피지)
	var threat_info: Dictionary = Threats.info(threat_kind)
	_sit_threat_label.text = "[ %s ]" % str(threat_info.get("label", "상황"))
	_sit_text_label.text = str(sit.get("text", ""))

	_clear_choices()
	var event_id: String = str(sit.get("id", ""))
	var choices: Array = sit.get("choices", [])
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var effect: Dictionary = choice.get("effect", {})
		var enabled: bool = Situations.can_choose(choice, _run.resources)
		var seen: bool = GameState.has_seen_choice(event_id, i)  # 겪어본 선택지만 결과 노출
		var btn := UITheme.make_engraved_button(UITheme.choice_text(choice, enabled, seen), 17, false)
		if enabled:
			var sets: Array = choice.get("sets", [])
			var sets_p: Array = choice.get("sets_persist", [])
			btn.pressed.connect(_on_choice.bind(event_id, i, str(choice.get("label", "")), effect, str(choice.get("action", "")), sets, sets_p, int(choice.get("trace_kind", -1)), choice.get("then", {})))
		else:
			btn.disabled = true
		_choice_box.add_child(btn)

	_advance_btn.disabled = true
	_leave_btn.disabled = true
	_sit_panel.move_to_front()  # 직전 결과 팝업이 페이드 중이어도 카드가 그 아래 깔리지 않게
	_sit_panel.visible = true
	UITheme.recenter_modal.call_deferred(_sit_panel)  # 웹 하단 치우침 방어(레이아웃 레이스)

func _on_choice(event_id: String, idx: int, label: String, effect: Dictionary, action: String = "", sets: Array = [], sets_persist: Array = [], trace_kind: int = -1, then: Dictionary = {}) -> void:
	GameState.mark_choice_seen(event_id, idx)  # 이 선택지를 겪었다 — 다음 대면 때 결과가 보인다(런 한정)
	var here_leg: int = _run.leg
	var here_node: String = _run.target_node_id()  # 지금 결정 중인 도착 노드
	_run.apply_choice(effect)
	# 차단에 로프 고정 = 영구 지형 흔적(ROPE). 다음 원정부터 이 노드를 무료로 건넌다(가장 뿌듯한 흔적).
	if action == "bridge":
		_bridge_here(here_node, here_leg)
	# 과거 흔적 줍기 — 자원 보충 후 그 노드 흔적의 uses 를 깎는다(소진되면 사라짐).
	if action == "pickup" and trace_kind >= 0:
		GameState.use_trace(here_node, trace_kind)
		AudioManager.play_sfx(AudioManager.PICKUP)  # 이전 원정대의 흔적을 줍는다
	# 낙오자 거두기 — 행렬 +1, 세계에서 그 자리 제거(영속). 데리고 닿아야 재회 축이 찬다.
	var rescued: bool = action == "rescue"
	if rescued:
		_run.rescue_straggler(here_node)
		GameState.rescue_straggler(here_node)
	# 선택 반영 — 플래그를 켠다. sets(같은 런 즉시) + sets_persist(다음 원정에도, GameState 영속).
	for f in sets:
		_run.set_flag(str(f))
	for f in sets_persist:
		_run.set_flag(str(f))
	if not sets_persist.is_empty():
		GameState.add_persist_flags(sets_persist)
	# 후속 장면(then) — 같은 자리에서 이야기 한 박자 더. autosave 앞에 raise(이어하기가 후속부터 잇는다).
	if _run.alive and not then.is_empty():
		_run.raise_situation(then)
	_sit_panel.visible = false
	GameState.autosave_run(_section.to_dict() if _section != null else {})  # 결정 확정 — 즉시 이어하기 저장
	_refresh()
	# blind choice 뒷면 — 눌러봐야 결과를 안다. 무엇이 일어났는지(자원 변화)를 팝업으로 공개한다.
	# 구조(따뜻한 모래색)와 손실(붉은색)이 겹치면 손실이 우선 — 잃은 쪽이 더 무겁다.
	var note: String = _take_loss_note()
	var note_color: Color = UITheme.DANGER
	var party: Dictionary = {}
	if note != "":
		party = ResultPopup.party_state(_run, "lose")
	elif rescued and _run.alive:
		note = "한 사람이 행렬에 들어선다.\n행렬은 %d명이 되었다." % _run.party_left()
		note_color = UITheme.SAND
		party = ResultPopup.party_state(_run, "gain")
	_result_popup.show_result(label, effect, _after_choice, note, note_color, party)

## 결과 팝업을 닫은 뒤 — 후속 장면(then)이 걸려 있으면 그 카드부터, 죽었으면 죽음 화면, 아니면 계속.
func _after_choice() -> void:
	_sync_advance_gate()  # 위협 카드를 방금 해결했으면 잠금이 풀린다. 보조 이벤트면 위협이 남아 계속 잠긴다.
	if not _run.alive:
		_die(_run.death_cause)
		return
	if not _run.pending_situation.is_empty():
		_show_situation()  # 후속 장면 — 같은 자리에서 이야기 한 박자 더

## 지금 선 차단 노드에 로프를 건다 - core 에 표시(같은 런 즉시 반영) + ROPE 흔적(node_id)을 남기고 저장(다음 원정에 영속).
## "남김 한 번"과 별개의 부산물 흔적이다(통과의 결과로 길이 영구히 바뀐다).
func _bridge_here(node_id: String, at_leg: int) -> void:
	AudioManager.play_sfx(AudioManager.ROPE)  # 로프가 팽팽하게 걸린다
	_run.mark_bridged(node_id)
	var tags: Array[String] = []
	tags.assign(["건너"])
	var trace := TraceData.new(TraceData.ObjectKind.ROPE, at_leg, tags)
	trace.node_id = node_id
	GameState.leave_trace(trace)
	GameState.save_game()

func _clear_choices() -> void:
	for c in _choice_box.get_children():
		_choice_box.remove_child(c)
		c.queue_free()

# --- 남김 한 번 (물건 두고 계속) — 결정 UI 는 공유 BequeathPanel 이 맡는다 ---

## 남기기 패널이 닫힌 뒤 (남겼든 취소든) — 계속 전진. 줄어든 자원·소진된 버튼을 반영한다.
func _on_bequeath_done() -> void:
	_sync_advance_gate()  # 남기기를 위협보다 먼저 했어도 위협이 남아 있으면 "떠난다"는 잠긴 채로.
	_refresh()

func _obj_name(kind: int) -> String:
	match kind:
		TraceData.ObjectKind.WATER: return "물통"
		TraceData.ObjectKind.FOOD: return "식량 자루"
		TraceData.ObjectKind.ROPE: return "로프"
		TraceData.ObjectKind.SHELTER: return "장막"
		TraceData.ObjectKind.BODY: return "시체"
		_: return "표식"

func _clear_box(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()

# --- 죽음 (고갈사 = 못 남김, 시체만) ---

func _die(cause: String) -> void:
	var tags: Array[String] = _death_tags(cause)
	var node_id: String = _run.death_node_id()  # 도착 죽음=그 노드, 이동 중 죽음=떠나온 노드
	var trace := TraceData.new(TraceData.ObjectKind.BODY, _run.leg, tags)
	trace.node_id = node_id
	if _run.is_mid_edge():   # 이동 중 죽음 = 엣지 위 쓰러진 지점에 시체를 남긴다(노드로 흡수 안 함)
		trace.to_node = _run.target_node_id()
		trace.position = _run.edge_fraction()
	GameState.leave_trace(trace)
	GameState.record_death(_run.leg, node_id, cause)  # 사인 전달 — 공훈(물지기·강골 해금) 통계
	GameState.save_game()
	_show_death(cause, tags)

## 죽음의 사인에 따라 남길 태그를 고른다 (WordPool 어휘). untyped 리터럴은 assign 으로 안전 대입.
func _death_tags(cause: String) -> Array[String]:
	var out: Array[String] = []
	match cause:
		"thirst": out.assign(["갈증", "끝"])
		"hunger": out.assign(["없다", "끝"])
		_: out.assign(["끝"])
	return out

func _death_message(cause: String) -> String:
	match cause:
		"thirst": return "물이 떨어졌다. 여기서 갈증으로 끝났다."
		"hunger": return "식량이 떨어졌다. 더 가지 못했다."
		_: return "여기서 끝났다."

func _show_death(cause: String, tags: Array[String], kind: int = TraceData.ObjectKind.BODY) -> void:
	AudioManager.play_sfx(AudioManager.DEATH)  # 스러짐 — 낮게 울리고 잦아든다
	_advance_btn.disabled = true
	_sit_panel.visible = false
	if _bequeath != null:
		_bequeath.visible = false
	var left: String = _obj_name(kind)
	if tags.is_empty():
		_death_label.text = "%s\n\n남긴 것: %s" % [_death_message(cause), left]
	else:
		_death_label.text = "%s\n\n남긴 것: %s  [ %s ]" % [_death_message(cause), left, " · ".join(PackedStringArray(tags))]
	# 거두어 데려가던 낙오자는 런과 운명을 같이한다(기획서 §3 ②) — 잃었음을 여기서 말한다.
	if _run.party_gained == 1:
		_death_label.text += "\n\n거두어 함께 걷던 한 사람도\n여기서 걸음을 멈췄다."
	elif _run.party_gained >= 2:
		_death_label.text += "\n\n거두어 함께 걷던 %d명도\n여기서 걸음을 멈췄다." % _run.party_gained
	_death_panel.move_to_front()  # 죽음은 항상 최상단(팝업·카드 위)
	_death_panel.visible = true
	queue_redraw()

# --- 단면 탐색 (그림 + 지점 조사) ---

func _gui_input(event: InputEvent) -> void:
	if _section == null or _sit_panel.visible or _bequeath.is_open() or _result_popup.is_open() or _death_panel.visible:
		return
	var clicked: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not clicked:
		return
	var pos: Vector2 = event.position
	for i in range(_section.spot_count()):
		if not _section.can_probe(i):
			continue
		var spot: Dictionary = _section.get_spot(i)
		var at: Vector2 = spot.get("at", Vector2(0.5, 0.5))
		if pos.distance_to(_spot_screen(at)) <= 40.0:
			_probe_spot(i)
			return

## 지점을 조사한다 — 결과 디스패치. event=선택 카드, delta/empty=결과 팝업(모두 모달로 통일).
func _probe_spot(i: int) -> void:
	var res: Dictionary = _section.probe(i)
	if res.is_empty():
		return
	# 총괄자의 기억 — 살핀 보조 지점을 세계 기록에(다음 원정이 재방문 때 기억으로 본다).
	# 저장은 아래 각 분기의 autosave_run 이 함께 싣는다.
	var probed_sid: String = str(_section.get_spot(i).get("id", ""))
	if probed_sid != "":
		GameState.record_probed_spot(_section.node_id, probed_sid)
	AudioManager.play_sfx(AudioManager.REVEAL, -4.0)  # 조사 — 잉크가 번지듯 드러난다
	# 이어하기 저장은 각 분기에서 상태가 다 정해진 뒤에 — 열린 카드(pending)·자원 반영까지 스냅샷에 실린다.
	var t: String = str(res.get("type", ""))
	if t == "event":
		_run.raise_situation(res.get("event", {}))
		GameState.autosave_run(_section.to_dict())
		_refresh()
		queue_redraw()
		if not _run.pending_situation.is_empty():
			_show_situation()
		return
	if t == "delta":
		var effect: Dictionary = res.get("effect", {})
		_run.apply_choice(effect)
		for f in res.get("sets", []):
			_run.set_flag(str(f))
		var sp: Array = res.get("sets_persist", [])
		for f in sp:
			_run.set_flag(str(f))
		if not sp.is_empty():
			GameState.add_persist_flags(sp)
		GameState.autosave_run(_section.to_dict())
		_refresh()
		queue_redraw()
		var probe_loss: String = _take_loss_note()
		_result_popup.show_result(str(res.get("text", "")), effect, _after_delta, probe_loss, UITheme.DANGER,
			ResultPopup.party_state(_run, "lose") if probe_loss != "" else {})
		return
	# empty — 빈손도 팝업으로(하단 배너 폐기, 결과는 전부 모달로 통일).
	GameState.autosave_run(_section.to_dict())
	_refresh()
	queue_redraw()
	_result_popup.show_result(str(res.get("text", "아무것도 없다.")), {}, Callable())

## 자원 결과 팝업을 닫은 뒤 — delta 로도 죽을 수 있으니(음수 효과) 죽음 판정.
func _after_delta() -> void:
	_sync_advance_gate()  # 보조 지점을 파도 필수 위협이 남아 있으면 "떠난다"는 계속 잠긴 채로.
	if not _run.alive:
		_die(_run.death_cause)

## 단면 내용 rect 안의 정규화 좌표(0..1) → 화면 좌표.
func _spot_screen(at: Vector2) -> Vector2:
	return _section_rect.position + Vector2(at.x * _section_rect.size.x, at.y * _section_rect.size.y)

## 위/아래 가독 스크림 텍스처 — 풀스크린 그림 위 글씨 보호(1회 생성).
func _make_scrims() -> void:
	var mk := func(top_a: float, bot_a: float) -> GradientTexture2D:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 1.0])
		g.colors = PackedColorArray([Color(0.02, 0.02, 0.04, top_a), Color(0.02, 0.02, 0.04, bot_a)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill_from = Vector2(0.5, 0.0)
		t.fill_to = Vector2(0.5, 1.0)
		t.width = 16
		t.height = 128
		return t
	_scrim_top = mk.call(0.72, 0.0)
	_scrim_bot = mk.call(0.0, 0.85)

## 폭풍 1층 헤이즈 텍스처 — 위가 짙고 아래로 옅어지는 따뜻한 모래 베일(1회 생성).
func _make_storm_haze() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(0.72, 0.63, 0.47, 0.16), Color(0.72, 0.63, 0.47, 0.05)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	t.width = 16
	t.height = 128
	_storm_haze = t

## 비네트 텍스처 — 가운데 투명 → 가장자리 어둠(방사). 그림 중앙에 시선을 모은다(1회 생성).
func _make_vignette() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.58, 1.0])
	g.colors = PackedColorArray([Color(0.02, 0.02, 0.04, 0.0), Color(0.02, 0.02, 0.04, 0.0), Color(0.02, 0.02, 0.04, 0.4)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.02, 1.02)
	t.width = 160
	t.height = 90
	_vignette = t

func _draw() -> void:
	var rect: Vector2 = size
	if rect.x <= 0.0 or rect.y <= 0.0 or _run == null:
		return
	var font: Font = get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font
	# 단면 = 화면 전체(cover). 예전 가운데 띠는 위아래가 죽은 여백이었다(2026-07-06 사용자 지적).
	_section_rect = Rect2(Vector2.ZERO, rect)
	var node_id: String = _run.target_node_id()
	var kind: String = _section.kind if _section != null else ""
	SectionArt.draw_section(self, kind, _section_rect, node_id)
	# 폭풍 1층 — 옅은 모래 헤이즈(분위기). 파티클(2·3층)이 있을 때만. 스크림 아래(글씨는 그 위에서 보호).
	if _storm_fx != null:
		if _storm_haze == null:
			_make_storm_haze()
		draw_texture_rect(_storm_haze, _section_rect, false)
		_storm_fx.set_band(_section_rect)   # 화면 전체 = 폭풍 영역(리사이즈 추종)
	# 비네트 — 가장자리를 은은히 눌러 그림 중앙으로 시선을 모으고, 모서리 라벨 가독을 돕는다.
	if _vignette == null:
		_make_vignette()
	draw_texture_rect(_vignette, _section_rect, false)
	# 가독 스크림 — 위(HUD 밑)·아래(장소 이름·버튼 밑). 그림 중앙이 주인공, 글씨는 어둠 위에.
	if _scrim_top == null:
		_make_scrims()
	draw_texture_rect(_scrim_top, Rect2(0.0, 0.0, rect.x, 200.0), false)
	draw_texture_rect(_scrim_bot, Rect2(0.0, rect.y - 240.0, rect.x, 240.0), false)
	# 장소 이름(붓글씨, 지도 지명과 같은 결) + 남은 조사 횟수 — 왼쪽 아래 스크림 위.
	if node_id != "":
		var nm: String = str(MapGraph.node(node_id).get("name", ""))
		var bf: Font = UITheme.BRUSH_FONT if UITheme.BRUSH_FONT != null else font
		var base := Vector2(44.0, rect.y - 66.0)
		draw_string(bf, base + Vector2(0.0, 2.5), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(0.0, 0.0, 0.0, 0.75))
		draw_string(bf, base, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, UITheme.FG)
		if _section != null and _section.spot_count() > 0 and _section.budget_left() > 0:
			# "조사" + 램프 점 — 남은 조사 횟수(채워진 점) / 쓴 것(빈 점). 숫자보다 한눈에.
			var by: float = rect.y - 30.0
			draw_string(font, Vector2(46.0, by), "조사", HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_LABEL, UITheme.SAND)
			var tw: float = font.get_string_size("조사", HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_LABEL).x
			var px: float = 46.0 + tw + 14.0
			var py: float = by - float(UITheme.FS_LABEL) * 0.32
			for k in range(_section.budget_start):
				var lc: Vector2 = Vector2(px + float(k) * 17.0, py)
				if k < _section.budget_left():
					draw_circle(lc, 5.0, UITheme.SAND)
				else:
					draw_arc(lc, 5.0, 0.0, TAU, 20, Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.4), 1.5)
	if _section == null:
		return
	for i in range(_section.spot_count()):
		if not _section.is_spot_visible(i):
			continue  # 두 단계 — 통과(위협/다리)를 열기 전엔 보조 지점을 그리지 않는다
		var spot: Dictionary = _section.get_spot(i)
		var at: Vector2 = spot.get("at", Vector2(0.5, 0.5))
		var st: int = 0
		if bool(spot.get("done", false)):
			st = 1
		elif not _section.can_probe(i):
			st = 2  # 예산 소진(선택형). 필수 위협은 can_probe 가 항상 true라 열린 채로 남는다.
		var is_main: bool = bool(spot.get("_result", {}).get("main", false))
		SectionArt.draw_spot(self, font, _spot_screen(at), str(spot.get("label", "")), st, is_main)
		# 총괄자의 기억 — 지난 원정이 살핀 지점은 라벨 밑에 기억 한 줄(흐리게).
		var mem: String = _section.memory_line(i)
		if mem != "":
			SectionArt.draw_spot_memory(self, font, _spot_screen(at), mem)
		# 낙오자면 마커 위에 웅크린 사람이 실제로 보이게(2026-07-15 사용자 — 시각 힌트 없인 뜬금없다).
		if is_main and st == 0 and str(spot.get("_result", {}).get("event", {}).get("kind", "")) == "straggler":
			SectionArt.draw_straggler(self, _spot_screen(at))
	if _section.spot_count() == 0:
		draw_string(font, Vector2(0.0, rect.y * 0.5), "둘러볼 것이 없다. 떠난다.", HORIZONTAL_ALIGNMENT_CENTER, rect.x, UITheme.FS_BODY, UITheme.FG)
	elif _section.has_unresolved_threat():
		# 필수 위협(폭풍/차단)을 아직 안 열었다 — 마주해야 떠날 수 있다고 짚어준다(모래빛 경고 톤).
		var gate_msg: String = "이곳의 위협을 마주하기 전엔 떠날 수 없다"
		match _section.unresolved_threat_kind():
			Threats.Kind.STORM:
				gate_msg = "폭풍을 지나기 전엔 떠날 수 없다"
			Threats.Kind.BLOCKAGE:
				gate_msg = "막힌 길을 넘기 전엔 떠날 수 없다"
		draw_string(font, Vector2(0.0, rect.y - 140.0), gate_msg, HORIZONTAL_ALIGNMENT_CENTER, rect.x, UITheme.FS_SMALL, UITheme.SAND)
	elif _section.budget_left() > 0 and _section.probed_count() == 0:
		# 첫 도착 안내 — 지점을 눌러 조사한다는 걸 짚어준다. 한 번이라도 조사하면 숨긴다(학습).
		# 하단 버튼 위 스크림 자리(그림에 안 묻히게 — 예전엔 그림 위 잉크색이라 안 읽혔다).
		draw_string(font, Vector2(0.0, rect.y - 140.0), "표시된 곳을 눌러 살핀다", HORIZONTAL_ALIGNMENT_CENTER, rect.x, UITheme.FS_SMALL, Color(0.88, 0.84, 0.76))
	elif _section.gate_opened() and _section.probed_count() == 1 and _section.budget_left() > 0 and _section.spot_count() > 1:
		# 두 단계 안내 — 통과(위협/다리)를 막 열어 보조 지점이 드러났다. 한 곳이라도 살피면 숨긴다.
		draw_string(font, Vector2(0.0, rect.y - 140.0), "건너온 자리다. 이제 주변을 둘러볼 수 있다", HORIZONTAL_ALIGNMENT_CENTER, rect.x, UITheme.FS_SMALL, Color(0.88, 0.84, 0.76))

# --- 결말 (목적지 도달: 순환과 재회) ---
# (옛 결말 카드 패널은 폐기 — 엔딩 슬라이드쇼 오버레이(Ending.gd)가 전부 맡는다. 2026-07-06 죽은 코드 정리.)

## 목적지(end) 도달 — 순환(기본) 또는 재회(흔적 충분 축적 + 무사 도달). 기획서 §3 결말.
func _show_ending() -> void:
	var kind: String = GameState.ending_kind()
	GameState.mark_arrival(kind)          # 일대기(Bookmark)에 도달/재회 기록
	GameState.ending_kind_pending = kind  # Ending 오버레이가 읽는다
	if _advance_btn != null:
		_advance_btn.disabled = true
	if _leave_btn != null:
		_leave_btn.disabled = true
	# 엔딩 슬라이드쇼(순환/재회) 오버레이 — Expedition 위에 얹는다(씬 전환 X → Transition busy 회피).
	# 순환: 슬라이드 → 암전 → "아무 키나" → 타이틀. 재회: 슬라이드 + Other Side 크레딧 → 타이틀.
	add_child(load("res://scripts/ui/Ending.gd").new())
