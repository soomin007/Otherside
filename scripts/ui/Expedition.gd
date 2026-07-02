extends Control

## 도착한 노드 화면 — 이동은 맵에서 끝났다(맵이 곧 탐험 인터페이스). 여긴 도착 카드(이벤트/줍기/로프 통과)·죽음·남기기 결정.
## 핵심 동사: 관리·판독·대비·남기기 (턴제 사색형). 로직은 core(ExpeditionRun·Situations), 여기선 렌더링·입력만.
## 그림은 _draw 로 그려 웹 안전(셰이더/GPUParticles 없음). 모바일 우선: 상단 HUD 바, 하단 큰 전진 버튼, 모달은 카드.
## (지형 비주얼·랜드마크 단면 탐색(TWoM)·폭풍 파티클 연출은 다음 단계 — StormFX.gd 는 그때 쓰려고 보존.)

var _run: ExpeditionRun

var _status_label: Label
var _water_label: Label
var _food_label: Label
var _aux_label: Label
var _advance_btn: Button
var _leave_btn: Button   ## "남기기" — 물건 하나 두고 계속 (런당 1회). 자발적 죽음은 없다(모든 죽음 비자발적).

var _death_panel: Control
var _death_label: Label

var _sit_panel: Control
var _sit_name_label: Label
var _sit_threat_label: Label
var _sit_text_label: Label
var _choice_box: VBoxContainer

var _bequeath: BequeathPanel               ## "남김 한 번" 모달 (공유 컴포넌트 — 지도와 같은 것)

var _section: SectionRun            ## 도착 노드의 단면 탐색 상태(예산·지점)
var _section_rect: Rect2            ## 단면 그림 영역(지점 히트테스트 기준)
var _probe_label: Label            ## "조사 N번 가능" — 남은 조사 횟수(예산)
var _result_popup: ResultPopup     ## 조사·선택 결과 팝업(공유) — 하단 배너 대신 모달로 통일

var _ending_panel: Control         ## end 도달 결말 화면(순환/재회)
var _ending_box: VBoxContainer

func _ready() -> void:
	_run = GameState.current_run
	if _run == null:
		# 안전장치: 지도를 거치지 않고 직접 이 씬으로 들어온 경우 (씬 전환 없이) 새 원정만 만든다.
		GameState.begin_run_in_place()
		_run = GameState.current_run
	_build_hud()
	_refresh()
	# 도착해서 들어온 노드 화면 — 죽음 / 목적지(결말) / 단면 탐색.
	if not _run.alive:
		_die(_run.death_cause)
	elif _run.target_node_id() == "end":
		_show_ending()
	else:
		_section = SectionRun.new(_run, MapGraph.node(_run.target_node_id()))
		_refresh()
		queue_redraw()

func _build_hud() -> void:
	# 상단 HUD 바 — 가독성을 위해 반투명 어두운 배경 위에 텍스트. 전체 폭.
	var hud := PanelContainer.new()
	hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var hud_sb := StyleBoxFlat.new()
	hud_sb.bg_color = Color(0.03, 0.03, 0.05, 0.5)
	hud_sb.content_margin_left = UITheme.PAD
	hud_sb.content_margin_right = UITheme.PAD
	hud_sb.content_margin_top = UITheme.SAFE + 6.0
	hud_sb.content_margin_bottom = 14.0
	hud.add_theme_stylebox_override("panel", hud_sb)
	add_child(hud)

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
	_aux_label.add_theme_color_override("font_color", Color(0.56, 0.56, 0.62))
	top.add_child(_aux_label)

	_probe_label = Label.new()  # "조사 N번 가능" — 남은 조사 횟수(예산)
	_probe_label.add_theme_font_size_override("font_size", UITheme.FS_LABEL)
	_probe_label.add_theme_color_override("font_color", UITheme.SAND)
	top.add_child(_probe_label)

	# 하단 — 큰 전진 버튼(주) + 보조 끝 버튼. 가운데 최대폭 컬럼(가로에선 카드처럼).
	var bar := CenterContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -200.0
	bar.offset_bottom = -UITheme.SAFE
	add_child(bar)

	var bcol := VBoxContainer.new()
	bcol.add_theme_constant_override("separation", 12)
	bcol.custom_minimum_size = Vector2(UITheme.COLUMN_W, 0)
	bar.add_child(bcol)

	_advance_btn = UITheme.make_button("떠난다 · 지도로")
	_advance_btn.pressed.connect(_on_advance)
	bcol.add_child(_advance_btn)

	# 보조: 남기기(물건 하나 두고 계속, 런당 1회). 자발적 죽음은 없다 — 모든 죽음은 비자발적(고갈/위협).
	_leave_btn = UITheme.make_button("남기기", false)
	_leave_btn.pressed.connect(_on_leave_pressed)
	bcol.add_child(_leave_btn)

	_build_situation_panel()
	_build_death_panel()
	# 남기기·결과 팝업은 공유 컴포넌트(지도와 같은 것) — 코드로 얹는다.
	_bequeath = BequeathPanel.new()
	_bequeath.committed.connect(_on_bequeath_done)
	_bequeath.cancelled.connect(_on_bequeath_done)
	add_child(_bequeath)
	_result_popup = ResultPopup.new()
	add_child(_result_popup)
	_build_ending_panel()

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

	var card := UITheme.make_card()
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UITheme.GAP)
	card.add_child(box)

	_sit_name_label = UITheme.make_label("", UITheme.FS_H1)
	box.add_child(_sit_name_label)

	_sit_threat_label = UITheme.make_label("", UITheme.FS_SMALL, UITheme.SAND)
	box.add_child(_sit_threat_label)

	_sit_text_label = UITheme.make_label("", UITheme.FS_BODY)
	box.add_child(_sit_text_label)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 12)
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

	var card := UITheme.make_card()
	center.add_child(card)

	var dbox := VBoxContainer.new()
	dbox.add_theme_constant_override("separation", UITheme.GAP + 6)
	card.add_child(dbox)

	_death_label = UITheme.make_label("", UITheme.FS_BODY)
	dbox.add_child(_death_label)

	var to_map := UITheme.make_button("지도로 돌아가기")
	to_map.pressed.connect(_on_to_map)
	dbox.add_child(to_map)

func _refresh() -> void:
	_status_label.text = "원정 %d째 · %d걸음\n물 -%d/걸음 · 식량 -1/%d걸음" % [GameState.expedition_count, _run.leg, _run.water_cost(), ExpeditionRun.FOOD_EVERY]
	var water: int = maxi(0, _run.get_res("water"))
	var food: int = maxi(0, _run.get_res("food"))
	_water_label.text = "물 %d" % water
	_food_label.text = "식량 %d" % food
	_water_label.add_theme_color_override("font_color", _res_color(water, 3, Color(0.55, 0.78, 0.97)))
	_food_label.add_theme_color_override("font_color", _res_color(food, 2, Color(0.88, 0.72, 0.42)))
	_aux_label.text = "로프 %d · 은신처 %d  (남길 수 있는 것)" % [_run.get_res("rope"), _run.get_res("shelter")]
	_advance_btn.text = "떠난다 · 지도로"
	if _probe_label != null:
		if _section != null and _section.spot_count() > 0 and _section.budget_left() > 0:
			_probe_label.text = "조사 %d번 가능" % _section.budget_left()
		else:
			_probe_label.text = ""
	_update_leave_btn()
	queue_redraw()

## "남기기" 버튼 상태 — 이미 남겼으면 잠그고("남겼다"), 아니면 남길 수 있는 자원이 하나라도 있을 때만 활성.
func _update_leave_btn() -> void:
	if _leave_btn == null:
		return
	if _run.bequeathed:
		_leave_btn.disabled = true
		_leave_btn.text = "남겼다"
	else:
		_leave_btn.disabled = not _any_leavable()
		_leave_btn.text = "남기기"

func _any_leavable() -> bool:
	for key in ["water", "food", "rope", "shelter"]:
		if _run.can_leave(key):
			return true
	return false

func _res_color(value: int, low: int, base: Color) -> Color:
	return UITheme.DANGER if value <= low else base

# --- 입력 ---

func _on_advance() -> void:
	# 이동은 맵에서 끝났다. 이 화면은 도착한 노드 — 결정을 마쳤으면 지도로 복귀한다.
	if not _run.alive or not _run.pending_situation.is_empty():
		return
	GameState.arrive_node()

## 남기기 — 물건 하나를 두고(자원 -비용) 계속 간다(런당 1회). 죽음과 분리.
func _on_leave_pressed() -> void:
	if not _run.alive or _run.bequeathed or _bequeath.is_open() or _sit_panel.visible or _result_popup.is_open():
		return
	_bequeath.open(_run, _run.target_node_id())  # 도착 노드에 남긴다
	_advance_btn.disabled = true
	_leave_btn.disabled = true

func _on_to_map() -> void:
	GameState.go_to_map()

# --- 상황 읽기 (결정 카드) ---

func _show_situation() -> void:
	var sit: Dictionary = _run.pending_situation
	var place_name: String = str(sit.get("name", ""))
	_sit_name_label.text = place_name
	_sit_name_label.visible = place_name != ""
	var threat_kind: int = int(sit.get("threat", Threats.Kind.CONSUMPTION))
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
		var btn := UITheme.make_button("", false)
		btn.text = UITheme.choice_text(choice, enabled, seen)
		if enabled:
			var sets: Array = choice.get("sets", [])
			var sets_p: Array = choice.get("sets_persist", [])
			btn.pressed.connect(_on_choice.bind(event_id, i, str(choice.get("label", "")), effect, str(choice.get("action", "")), sets, sets_p, int(choice.get("trace_kind", -1))))
		else:
			btn.disabled = true
		_choice_box.add_child(btn)

	_advance_btn.disabled = true
	_leave_btn.disabled = true
	_sit_panel.visible = true

func _on_choice(event_id: String, idx: int, label: String, effect: Dictionary, action: String = "", sets: Array = [], sets_persist: Array = [], trace_kind: int = -1) -> void:
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
	# 선택 반영 — 플래그를 켠다. sets(같은 런 즉시) + sets_persist(다음 원정에도, GameState 영속).
	for f in sets:
		_run.set_flag(str(f))
	for f in sets_persist:
		_run.set_flag(str(f))
	if not sets_persist.is_empty():
		GameState.add_persist_flags(sets_persist)
	_sit_panel.visible = false
	_refresh()
	# blind choice 뒷면 — 눌러봐야 결과를 안다. 무엇이 일어났는지(자원 변화)를 팝업으로 공개한다.
	_result_popup.show_result(label, effect, _after_choice)

## 결과 팝업을 닫은 뒤 — 계속 전진(또는 결정이 곧 죽음이었으면 죽음 화면).
func _after_choice() -> void:
	_advance_btn.disabled = false
	if not _run.alive:
		_die(_run.death_cause)

## 지금 선 차단 노드에 로프를 건다 - core 에 표시(같은 런 즉시 반영) + ROPE 흔적(node_id)을 남기고 저장(다음 원정에 영속).
## "남김 한 번"과 별개의 부산물 흔적이다(통과의 결과로 길이 영구히 바뀐다).
func _bridge_here(node_id: String, at_leg: int) -> void:
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
	_advance_btn.disabled = false
	_refresh()

func _obj_name(kind: int) -> String:
	match kind:
		TraceData.ObjectKind.WATER: return "물통"
		TraceData.ObjectKind.FOOD: return "식량 자루"
		TraceData.ObjectKind.ROPE: return "로프"
		TraceData.ObjectKind.SHELTER: return "은신막"
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
	GameState.leave_trace(trace)
	GameState.record_death(_run.leg, node_id)
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
	_advance_btn.disabled = true
	_sit_panel.visible = false
	if _bequeath != null:
		_bequeath.visible = false
	var left: String = _obj_name(kind)
	if tags.is_empty():
		_death_label.text = "%s\n\n남긴 것: %s" % [_death_message(cause), left]
	else:
		_death_label.text = "%s\n\n남긴 것: %s  [ %s ]" % [_death_message(cause), left, " · ".join(PackedStringArray(tags))]
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
	var t: String = str(res.get("type", ""))
	if t == "event":
		_run.raise_situation(res.get("event", {}))
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
		_refresh()
		queue_redraw()
		_result_popup.show_result(str(res.get("text", "")), effect, _after_delta)
		return
	# empty — 빈손도 팝업으로(하단 배너 폐기, 결과는 전부 모달로 통일).
	_refresh()
	queue_redraw()
	_result_popup.show_result(str(res.get("text", "아무것도 없다.")), {}, Callable())

## 자원 결과 팝업을 닫은 뒤 — delta 로도 죽을 수 있으니(음수 효과) 죽음 판정.
func _after_delta() -> void:
	if not _run.alive:
		_die(_run.death_cause)

## 단면 내용 rect 안의 정규화 좌표(0..1) → 화면 좌표.
func _spot_screen(at: Vector2) -> Vector2:
	return _section_rect.position + Vector2(at.x * _section_rect.size.x, at.y * _section_rect.size.y)

func _draw() -> void:
	var rect: Vector2 = size
	if rect.x <= 0.0 or rect.y <= 0.0 or _run == null:
		return
	var font: Font = get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font
	var top_y: float = 150.0
	var bot_y: float = 240.0
	_section_rect = Rect2(UITheme.PAD, top_y, rect.x - UITheme.PAD * 2.0, rect.y - top_y - bot_y)
	if _section_rect.size.y < 40.0 or _section_rect.size.x < 40.0:
		return
	var node_id: String = _run.target_node_id()
	var kind: String = _section.kind if _section != null else ""
	SectionArt.draw_section(self, kind, _section_rect, node_id)
	if node_id != "":
		var nm: String = str(MapGraph.node(node_id).get("name", ""))
		draw_string(font, Vector2(_section_rect.position.x + 12.0, _section_rect.position.y + 30.0), nm, HORIZONTAL_ALIGNMENT_LEFT, _section_rect.size.x - 24.0, UITheme.FS_H2, UITheme.INK)
	if _section == null:
		return
	for i in range(_section.spot_count()):
		var spot: Dictionary = _section.get_spot(i)
		var at: Vector2 = spot.get("at", Vector2(0.5, 0.5))
		var st: int = 0
		if bool(spot.get("done", false)):
			st = 1
		elif _section.budget_left() <= 0:
			st = 2
		SectionArt.draw_spot(self, font, _spot_screen(at), str(spot.get("label", "")), st)
	if _section.spot_count() == 0:
		draw_string(font, Vector2(_section_rect.position.x, _section_rect.position.y + _section_rect.size.y * 0.5), "둘러볼 것이 없다. 떠난다.", HORIZONTAL_ALIGNMENT_CENTER, _section_rect.size.x, UITheme.FS_BODY, UITheme.MUTED)
	elif _section.budget_left() > 0 and _section.probed_count() == 0:
		# 첫 도착 안내 — 지점을 눌러 조사한다는 걸 짚어준다. 한 번이라도 조사하면 숨긴다(학습).
		draw_string(font, Vector2(_section_rect.position.x, _section_rect.end.y - 14.0), "표시된 곳을 눌러 조사한다  (자원은 들지 않는다)", HORIZONTAL_ALIGNMENT_CENTER, _section_rect.size.x, UITheme.FS_SMALL, UITheme.INK)

# --- 결말 (목적지 도달: 순환과 재회) ---

func _build_ending_panel() -> void:
	_ending_panel = Control.new()
	_ending_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ending_panel.visible = false
	add_child(_ending_panel)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.03, 0.06, 0.95)
	_ending_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ending_panel.add_child(center)
	var card := UITheme.make_card()
	center.add_child(card)
	_ending_box = VBoxContainer.new()
	_ending_box.add_theme_constant_override("separation", UITheme.GAP + 6)
	card.add_child(_ending_box)

## 목적지(end) 도달 — 순환(기본) 또는 재회(흔적 충분 축적 + 무사 도달). 기획서 §3 결말.
func _show_ending() -> void:
	var kind: String = GameState.ending_kind()
	if _advance_btn != null:
		_advance_btn.disabled = true
	if _leave_btn != null:
		_leave_btn.disabled = true
	_clear_box(_ending_box)

	var title_txt: String
	var body_txt: String
	var btn_txt: String
	var to_title: bool
	if kind == "reunion":
		title_txt = "재회"
		body_txt = "목적지에 닿았다. 죽지 않고, 온전히.\n\n밀어내지 않아도 되었다. 먼저 간 모든 원정대가 건너편에서 기다리고 있었다.\n\n릴레이가 멈춘다. 드디어 그쪽에서 만난다."
		btn_txt = "여기까지"
		to_title = true
	else:
		title_txt = "도달"
		body_txt = "재앙의 자리엔, 먼저 간 원정대가 서 있었다.\n\n멈추려면 그를 밀어내야 했다. 이제 이 자리에 선 것은 우리다. 곧 다음 원정대가 이곳을 향해 온다.\n\n릴레이는 멈추지 않는다."
		btn_txt = "다음 원정을 보낸다"
		to_title = false

	_ending_box.add_child(UITheme.make_label(title_txt, UITheme.FS_H1, UITheme.SAND))
	_ending_box.add_child(UITheme.make_label(body_txt, UITheme.FS_BODY))
	var btn := UITheme.make_button(btn_txt)
	if to_title:
		btn.pressed.connect(GameState.go_to_title)
	else:
		btn.pressed.connect(GameState.next_expedition)
	_ending_box.add_child(btn)
	_ending_panel.visible = true
