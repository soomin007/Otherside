extends Control

## 도착한 노드 화면 — 이동은 맵에서 끝난다(맵이 곧 탐험 인터페이스). 여긴 도착 이벤트·죽음·남기기·줍기 결정.
## 핵심 동사: 관리·판독·대비·남기기 (턴제 사색형). 로직은 core(ExpeditionRun·Situations), 여기선 렌더링·입력만.
## 그림은 _draw 로 그려 웹 안전(셰이더/GPUParticles 없음). 모바일 우선: 상단 HUD 바, 하단 큰 전진 버튼, 모달은 카드.
## (지형 비주얼·랜드마크 단면 탐색(TWoM)·폭풍 파티클 연출은 다음 단계 — StormFX.gd 는 그때 쓰려고 보존.)

const RES_KO: Dictionary = {"water": "물", "food": "식량", "rope": "로프", "shelter": "은신처"}

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

var _bequeath_panel: Control               ## 자발적 종료 시 "남김 한 번" 결정 화면
var _bequeath_box: VBoxContainer           ## 단계별 내용을 갈아끼우는 컨테이너
var _picked_kind: int = TraceData.ObjectKind.BODY  ## 남길 물건 종류
var _picked_tags: Array[String] = []       ## 얹을 태그(WordPool, 최대 2개)

func _ready() -> void:
	_run = GameState.current_run
	if _run == null:
		# 안전장치: 지도를 거치지 않고 직접 이 씬으로 들어온 경우 (씬 전환 없이) 새 원정만 만든다.
		GameState.begin_run_in_place()
		_run = GameState.current_run
	_build_hud()
	_refresh()
	# 도착해서 들어온 노드 화면 — 이동은 맵에서 끝났다. 죽었으면 죽음, 도착 이벤트가 있으면 표시.
	if not _run.alive:
		_die(_run.death_cause)
	elif not _run.pending_situation.is_empty():
		_show_situation()

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

	_advance_btn = UITheme.make_button("전진 (한 걸음)")
	_advance_btn.pressed.connect(_on_advance)
	bcol.add_child(_advance_btn)

	# 보조: 남기기(물건 하나 두고 계속, 런당 1회). 자발적 죽음은 없다 — 모든 죽음은 비자발적(고갈/위협).
	_leave_btn = UITheme.make_button("남기기", false)
	_leave_btn.pressed.connect(_on_leave_pressed)
	bcol.add_child(_leave_btn)

	_build_situation_panel()
	_build_death_panel()
	_build_bequeath_panel()

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

func _build_bequeath_panel() -> void:
	_bequeath_panel = Control.new()
	_bequeath_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bequeath_panel.visible = false
	add_child(_bequeath_panel)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = UITheme.SCRIM
	_bequeath_panel.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bequeath_panel.add_child(center)

	var card := UITheme.make_card()
	center.add_child(card)

	_bequeath_box = VBoxContainer.new()
	_bequeath_box.add_theme_constant_override("separation", UITheme.GAP)
	card.add_child(_bequeath_box)

func _refresh() -> void:
	_status_label.text = "원정 %d째 · %d걸음 · 물 -%d/걸음" % [GameState.expedition_count, _run.leg, _run.water_cost()]
	var water: int = maxi(0, _run.get_res("water"))
	var food: int = maxi(0, _run.get_res("food"))
	_water_label.text = "물 %d" % water
	_food_label.text = "식량 %d" % food
	_water_label.add_theme_color_override("font_color", _res_color(water, 3, Color(0.55, 0.78, 0.97)))
	_food_label.add_theme_color_override("font_color", _res_color(food, 2, Color(0.88, 0.72, 0.42)))
	_aux_label.text = "로프 %d · 은신처 %d  (남길 수 있는 것)" % [_run.get_res("rope"), _run.get_res("shelter")]
	_advance_btn.text = "도착 · 지도로" if _run.arrived() else "전진 (한 걸음)"
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
	if not _run.alive or _run.bequeathed or _bequeath_panel.visible or _sit_panel.visible:
		return
	_show_bequeath()

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
	var choices: Array = sit.get("choices", [])
	for c in choices:
		var choice: Dictionary = c
		var effect: Dictionary = choice.get("effect", {})
		var btn := UITheme.make_button("", false)
		btn.text = "%s   (%s)" % [str(choice.get("label", "")), _effect_hint(effect)]
		if Situations.can_choose(choice, _run.resources):
			var sets: Array = choice.get("sets", [])
			var sets_p: Array = choice.get("sets_persist", [])
			btn.pressed.connect(_on_choice.bind(effect, str(choice.get("action", "")), sets, sets_p, int(choice.get("trace_kind", -1))))
		else:
			btn.disabled = true
			btn.text = "%s   (자원 부족)" % str(choice.get("label", ""))
		_choice_box.add_child(btn)

	_advance_btn.disabled = true
	_leave_btn.disabled = true
	_sit_panel.visible = true

func _on_choice(effect: Dictionary, action: String = "", sets: Array = [], sets_persist: Array = [], trace_kind: int = -1) -> void:
	var here: int = _run.leg
	_run.apply_choice(effect)
	# 차단에 로프 고정 = 영구 지형 흔적(ROPE). 다음 원정부터 이 틈을 무료로 건넌다(가장 뿌듯한 흔적).
	if action == "bridge":
		_bridge_here(here)
	# 과거 흔적 줍기 — 자원 보충 후 그 흔적의 uses 를 깎는다(소진되면 사라짐).
	if action == "pickup" and trace_kind >= 0:
		GameState.use_trace(here, trace_kind)
	# 선택 반영 — 플래그를 켠다. sets(같은 런 즉시) + sets_persist(다음 원정에도, GameState 영속).
	for f in sets:
		_run.set_flag(str(f))
	for f in sets_persist:
		_run.set_flag(str(f))
	if not sets_persist.is_empty():
		GameState.add_persist_flags(sets_persist)
	_sit_panel.visible = false
	_advance_btn.disabled = false
	_refresh()
	if not _run.alive:
		_die(_run.death_cause)

## 지금 선 차단에 로프를 건다 - core 에 표시(같은 런 즉시 반영) + ROPE 흔적을 남기고 저장(다음 원정에 영속).
## "남김 한 번"과 별개의 부산물 흔적이다(통과의 결과로 길이 영구히 바뀐다).
func _bridge_here(at_leg: int) -> void:
	_run.mark_bridged(at_leg)
	var tags: Array[String] = []
	tags.assign(["건너"])
	var trace := TraceData.new(TraceData.ObjectKind.ROPE, at_leg, tags)
	GameState.leave_trace(trace)
	GameState.save_game()

func _clear_choices() -> void:
	for c in _choice_box.get_children():
		_choice_box.remove_child(c)
		c.queue_free()

## 자원 델타를 읽기 쉬운 한 줄로 ("물 -2 · 식량 -1"). 빈 효과는 "그대로".
func _effect_hint(effect: Dictionary) -> String:
	if effect.is_empty():
		return "그대로"
	var parts: PackedStringArray = []
	for key in effect:
		var v: int = int(effect[key])
		var sign_str: String = "+" if v > 0 else ""
		parts.append("%s %s%d" % [str(RES_KO.get(key, key)), sign_str, v])
	return " · ".join(parts)

# --- 남김 한 번 (물건 두고 계속) ---

## "남김 한 번" 결정 화면을 연다 — 물건 하나를 골라 태그를 얹는다. 죽지 않고 계속 간다(그 자원만 그만큼 잃음).
func _show_bequeath() -> void:
	_picked_kind = TraceData.ObjectKind.MARK
	_picked_tags = []
	_advance_btn.disabled = true
	_leave_btn.disabled = true
	_sit_panel.visible = false
	_bequeath_step_what()
	_bequeath_panel.visible = true

## 1단계 — 무엇을 남길까. 남기면 그만큼 잃는다(자기 수명 깎기). 생존 자원(물/식량)은 죽지 않을 만큼만 남길 수 있다.
func _bequeath_step_what() -> void:
	_clear_box(_bequeath_box)
	_bequeath_box.add_child(UITheme.make_label("무엇을 남길까", UITheme.FS_H1))
	_bequeath_box.add_child(UITheme.make_label("물건 하나를 여기 둔다. 그만큼 잃지만, 계속 갈 수 있다.", UITheme.FS_SMALL, UITheme.MUTED))
	var opts: Array = [
		[TraceData.ObjectKind.WATER, "물통", "water"],
		[TraceData.ObjectKind.FOOD, "식량 자루", "food"],
		[TraceData.ObjectKind.ROPE, "로프", "rope"],
		[TraceData.ObjectKind.SHELTER, "은신막", "shelter"],
	]
	for o in opts:
		var kind: int = o[0]
		var label: String = o[1]
		var res_key: String = o[2]
		var cost: int = _run.leave_cost(res_key)
		var have: int = _run.get_res(res_key)
		var btn := UITheme.make_button("%s  (%s -%d / 보유 %d)" % [label, str(RES_KO.get(res_key, res_key)), cost, have], false)
		if _run.can_leave(res_key):
			btn.pressed.connect(_pick_object.bind(kind))
		else:
			btn.disabled = true
		_bequeath_box.add_child(btn)

	_bequeath_box.add_child(HSeparator.new())
	var cancel := UITheme.make_button("그냥 간다", false)
	cancel.add_theme_color_override("font_color", UITheme.MUTED)
	cancel.pressed.connect(_cancel_bequeath)
	_bequeath_box.add_child(cancel)

func _pick_object(kind: int) -> void:
	_picked_kind = kind
	_bequeath_step_tags()

## 2단계 — 어떤 표식(태그)을 얹을까. WordPool 에서 최대 2개. 없이 남겨도 된다.
func _bequeath_step_tags() -> void:
	_clear_box(_bequeath_box)
	_bequeath_box.add_child(UITheme.make_label("남길 것: %s" % _obj_name(_picked_kind), UITheme.FS_BODY, UITheme.SAND))
	var picked_str: String = (" · ".join(PackedStringArray(_picked_tags))) if not _picked_tags.is_empty() else "(없음)"
	_bequeath_box.add_child(UITheme.make_label("표식: %s" % picked_str, UITheme.FS_SMALL, UITheme.MUTED))
	_bequeath_box.add_child(UITheme.make_label("한두 마디. 다음 원정대가 읽는다.", UITheme.FS_SMALL, UITheme.MUTED))
	for cat in [WordPool.DIRECTION, WordPool.WARNING, WordPool.TIME, WordPool.GREETING]:
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		for w in cat:
			var word: String = str(w)
			var tb := Button.new()
			tb.text = word
			tb.toggle_mode = true
			tb.button_pressed = _picked_tags.has(word)
			tb.custom_minimum_size = Vector2(0, 44)
			tb.add_theme_font_size_override("font_size", UITheme.FS_LABEL)
			tb.pressed.connect(_toggle_tag.bind(word))
			flow.add_child(tb)
		_bequeath_box.add_child(flow)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var back := UITheme.make_button("뒤로", false)
	back.pressed.connect(_bequeath_step_what)
	row.add_child(back)
	var done := UITheme.make_button("남기고 계속 간다", false)
	done.pressed.connect(_commit_bequeath)
	row.add_child(done)
	_bequeath_box.add_child(row)

## 태그 토글 — 최대 2개. 넘으면 가장 오래된 것을 밀어낸다.
func _toggle_tag(word: String) -> void:
	if _picked_tags.has(word):
		_picked_tags.erase(word)
	else:
		_picked_tags.append(word)
		if _picked_tags.size() > 2:
			_picked_tags.remove_at(0)
	_bequeath_step_tags()

## 줍기형(자원) 흔적인가 — 물통/식량/은신막만 다음 원정대가 집어 쓸 수 있다(uses 부여).
func _is_pickup_kind(kind: int) -> bool:
	return kind == TraceData.ObjectKind.WATER or kind == TraceData.ObjectKind.FOOD or kind == TraceData.ObjectKind.SHELTER

## 결정 확정 — 물건을 그 자리에 남기고(자원 그만큼 잃음) 계속 간다. 죽지 않는다.
## 남긴 자원 흔적은 줍기 가능(uses) — 다음 원정대가 집어 쓴다(루프가 닫힌다).
func _commit_bequeath() -> void:
	var res_key: String = _kind_to_key(_picked_kind)
	if res_key == "":
		_cancel_bequeath()
		return
	_run.do_leave(res_key)  # 자원 -비용 + 토큰 소진 (can_leave 가 생존 보장 → 안 죽음)
	var uses: int = TraceData.PICKUP_USES if _is_pickup_kind(_picked_kind) else 0
	var trace := TraceData.new(_picked_kind, _run.leg, _picked_tags, uses)
	GameState.leave_trace(trace)
	GameState.save_game()
	_bequeath_panel.visible = false
	_advance_btn.disabled = false
	_refresh()  # 줄어든 자원·소진된 남기기 버튼 반영. 계속 전진.

## 남김 취소 — 결정 화면을 닫고 계속 간다.
func _cancel_bequeath() -> void:
	_bequeath_panel.visible = false
	_advance_btn.disabled = false
	_refresh()

## 남길 물건 종류 → 자원 키 ("" = 자원 아님/없음).
func _kind_to_key(kind: int) -> String:
	match kind:
		TraceData.ObjectKind.WATER: return "water"
		TraceData.ObjectKind.FOOD: return "food"
		TraceData.ObjectKind.ROPE: return "rope"
		TraceData.ObjectKind.SHELTER: return "shelter"
		_: return ""

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
	var trace := TraceData.new(TraceData.ObjectKind.BODY, _run.leg, tags)
	GameState.leave_trace(trace)
	GameState.record_death(_run.leg)
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
	_bequeath_panel.visible = false
	var left: String = _obj_name(kind)
	if tags.is_empty():
		_death_label.text = "%s\n\n남긴 것: %s" % [_death_message(cause), left]
	else:
		_death_label.text = "%s\n\n남긴 것: %s  [ %s ]" % [_death_message(cause), left, " · ".join(PackedStringArray(tags))]
	_death_panel.visible = true
	queue_redraw()

# --- 도착 노드 화면 렌더링 (_draw) ---
## 이동은 맵에서 끝났다(막대 걷기 폐기). 여긴 도착/진행을 담담히 보여줄 뿐 — 결정은 카드 모달로.
## (지형 비주얼·랜드마크 단면 탐색(TWoM)은 다음 단계.)

func _draw() -> void:
	var rect: Vector2 = size
	if rect.x <= 0.0 or rect.y <= 0.0 or _run == null:
		return
	var font: Font = get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font
	if _run.target_node_id() == "":
		return
	var total: int = ExpeditionRun.EDGE_LEN
	var done: int = total - _run.edge_remaining()
	var cy: float = rect.y * 0.48
	if _run.arrived():
		draw_string(font, Vector2(0.0, cy), "도착했다", HORIZONTAL_ALIGNMENT_CENTER, rect.x, UITheme.FS_BODY, UITheme.SAND)
	else:
		draw_string(font, Vector2(0.0, cy), "미지를 향해 가는 중", HORIZONTAL_ALIGNMENT_CENTER, rect.x, UITheme.FS_BODY, UITheme.MUTED)
		draw_string(font, Vector2(0.0, cy + 38.0), "%d / %d 걸음" % [done, total], HORIZONTAL_ALIGNMENT_CENTER, rect.x, UITheme.FS_SMALL, UITheme.MUTED)
