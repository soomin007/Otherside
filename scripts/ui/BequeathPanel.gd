class_name BequeathPanel
extends Control

## 남기기 화면 (지도·단면 공유) — 물건 하나를 골라 태그를 얹어 그 자리에 둔다(런당 1회, 자원 -비용).
## 죽음과 별개(자발적 죽음 없음) — 남기고도 계속 간다. 기획서 §3.
## 게임의 정서적 핵(핸드오프 §3): 풀스크린 어두운 방사 배경 + 후보 사진 가로 배치,
## 고른 물건은 그 자리에서 모래로 흩어져 사라진다("말은 남지 않는다. 물건만 남는다").
## 쓰임: 도착 화면(Expedition, 도착 노드에 남김) + 지도 이동 중(Map, 마지막 밟은 노드에 남김).
## core(ExpeditionRun.can_leave/do_leave/leave_cost) + GameState.leave_trace 호출. 위치(node_id)는 open 때 주입.

signal committed   ## 남기기 완료 (자원 변경됨 — 호출측이 refresh/이동 재개)
signal cancelled   ## 남기지 않고 닫음

const EN_TITLE_FONT := preload("res://assets/fonts/Cinzel.ttf")     ## 에이브로우 영문 전용
const COST_COL := Color(0.788, 0.541, 0.478)   ## 대가 문구(#c98a7a — 스펙)
const NOTE_COL := Color(0.541, 0.478, 0.388)   ## "말은 남지 않는다" 소문구(#8a7a63 — 스펙)

var _run: ExpeditionRun
var _node_id: String = ""                            ## 남길 노드(도착=target, 이동 중=current)
var _picked_kind: int = TraceData.ObjectKind.MARK    ## 남길 물건 종류
var _picked_tags: Array[String] = []                 ## 얹을 태그(WordPool, 최대 2개)
var _box: VBoxContainer                              ## 단계별 내용을 갈아끼우는 컨테이너
var _busy: bool = false                              ## 흩어짐 연출 중 재입력 잠금

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

	# 어두운 방사 그라디언트 배경(스펙 — 사진 아님). 셰이더 금지라 GradientTexture2D FILL_RADIAL.
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([
		Color(0.165, 0.110, 0.063),  # 중심 #2a1c10
		Color(0.090, 0.063, 0.039),  # 중간 #17100a
		Color(0.039, 0.027, 0.020),  # 가장자리 #0a0705
	])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.42)
	gt.fill_to = Vector2(0.5, 1.15)
	var bg := TextureRect.new()
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", UITheme.GAP)
	_box.custom_minimum_size = Vector2(640, 0)  # 카드 없이 배경 위 직접 — 태그 flow 줄바꿈 기준 폭
	center.add_child(_box)

func is_open() -> bool:
	return visible

## 남기기 시작 — run 의 자원으로 node_id 위치에 남긴다.
func open(run: ExpeditionRun, node_id: String) -> void:
	_run = run
	_node_id = node_id
	_picked_kind = TraceData.ObjectKind.MARK
	_picked_tags = []
	_step_what()
	UITheme.fade_in(self)
	UITheme.sand_puff(self)

## 1단계 — 무엇을 남길까. 남기면 그만큼 잃는다(자기 수명 깎기). 생존 자원(물/식량)은 죽지 않을 만큼만 남길 수 있다.
## 후보 = 사진(ItemIcon) + 이름 + 대가, 가로 배치(스펙 §3). 고르면 그 물건이 모래로 흩어진다.
func _step_what() -> void:
	_busy = false
	_clear()
	var eye := UITheme.make_label("BEQUEATH", 11, Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.9))
	var efv := FontVariation.new()
	efv.base_font = EN_TITLE_FONT
	efv.set_spacing(TextServer.SPACING_GLYPH, 4)  # 스펙 .32em
	eye.add_theme_font_override("font", efv)
	_box.add_child(eye)
	_box.add_child(UITheme.make_label("무엇을 남길까", UITheme.FS_H1))
	_box.add_child(UITheme.make_label("물건 하나를 여기 둔다. 그만큼 잃지만, 계속 갈 수 있다.", UITheme.FS_SMALL, UITheme.MUTED))
	_box.add_child(UITheme.make_label("말은 남지 않는다. 물건만 남는다.", 13, NOTE_COL))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(row)
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
		row.add_child(_make_candidate(kind, label, res_key))

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	_box.add_child(gap)
	var cancel := EngravedItem.new()
	cancel.init_item("아무것도 남기지 않고 간다", 18, false)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.pressed.connect(_cancel)
	_box.add_child(cancel)

## 남길 후보 하나 — 사진(130×130) 위 이름(ivory)·대가(#c98a7a). 남길 수 없으면 흐리게+잠금.
func _make_candidate(kind: int, label: String, res_key: String) -> Control:
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.custom_minimum_size = Vector2(148, 196)
	var hov := StyleBoxFlat.new()
	hov.bg_color = Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.10)
	hov.set_corner_radius_all(12)
	var emp := StyleBoxEmpty.new()
	for st in ["normal", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(st, emp)
	btn.add_theme_stylebox_override("hover", hov)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	var icon := ItemIcon.new()
	icon.key = res_key
	icon.custom_minimum_size = Vector2(0, 130)
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(icon)
	var nm := UITheme.make_label(label, UITheme.FS_LABEL, UITheme.FG)
	v.add_child(nm)
	var cost: int = _run.leave_cost(res_key)
	var have: int = _run.get_res(res_key)
	var cl := UITheme.make_label("%s -%d · 보유 %d" % [str(UITheme.RES_KO.get(res_key, res_key)), cost, have], 13, COST_COL)
	v.add_child(cl)
	btn.add_child(v)
	if _run.can_leave(res_key):
		btn.pressed.connect(_pick_object.bind(kind, btn))
	else:
		btn.disabled = true
		btn.modulate.a = 0.35
	return btn

## 후보를 고름 — 그 물건이 모래로 흩어져 사라진 뒤(스펙 leave: 40입자 + 흐려지며 소멸, 웹이라 blur 대신
## 확대+페이드 근사) 태그 단계로 넘어간다. 연출 중 재입력 잠금.
func _pick_object(kind: int, btn: Control) -> void:
	if _busy:
		return
	_busy = true
	_picked_kind = kind
	AudioManager.play_sfx("res://assets/sfx/sfx_leave.wav")
	var c: Vector2 = btn.get_global_rect().get_center()
	UITheme.sand_puff_at(self, c, 40)
	btn.pivot_offset = btn.size * 0.5
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(btn, "scale", Vector2(1.28, 1.28), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "modulate:a", 0.0, 0.4)
	t.chain().tween_callback(_step_tags)

## 2단계 — 어떤 표식(태그)을 얹을까. WordPool 에서 최대 2개. 없이 남겨도 된다.
func _step_tags() -> void:
	_clear()
	_box.add_child(UITheme.make_label("남길 것: %s" % _obj_name(_picked_kind), UITheme.FS_BODY, UITheme.SAND))
	var picked_str: String = (" · ".join(PackedStringArray(_picked_tags))) if not _picked_tags.is_empty() else "(없음)"
	_box.add_child(UITheme.make_label("표식: %s" % picked_str, UITheme.FS_SMALL, UITheme.MUTED))
	_box.add_child(UITheme.make_label("한두 마디. 다음 원정대가 읽는다.", UITheme.FS_SMALL, UITheme.MUTED))
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
		_box.add_child(flow)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var back := UITheme.make_button("뒤로", false)
	back.pressed.connect(_step_what)
	row.add_child(back)
	var done := UITheme.make_button("남기고 계속 간다", false)
	done.pressed.connect(_commit)
	row.add_child(done)
	_box.add_child(row)

## 태그 토글 — 최대 2개. 넘으면 가장 오래된 것을 밀어낸다.
func _toggle_tag(word: String) -> void:
	if _picked_tags.has(word):
		_picked_tags.erase(word)
	else:
		_picked_tags.append(word)
		if _picked_tags.size() > 2:
			_picked_tags.remove_at(0)
	_step_tags()

## 결정 확정 — 물건을 그 자리에 남기고(자원 그만큼 잃음) 계속 간다. 죽지 않는다.
## 남긴 자원 흔적은 줍기 가능(uses) — 다음 원정대가 집어 쓴다(루프가 닫힌다).
func _commit() -> void:
	var res_key: String = _kind_to_key(_picked_kind)
	if res_key == "":
		_cancel()
		return
	_run.do_leave(res_key)  # 자원 -비용 + 토큰 소진 (can_leave 가 생존 보장 → 안 죽음)
	var uses: int = TraceData.PICKUP_USES if _is_pickup_kind(_picked_kind) else 0
	var trace := TraceData.new(_picked_kind, _run.leg, _picked_tags, uses)
	trace.node_id = _node_id  # 도착 노드(Expedition) 또는 마지막 밟은 노드(Map 이동 중)
	GameState.leave_trace(trace)
	GameState.save_game()
	UITheme.fade_out(self, func() -> void: committed.emit())

func _cancel() -> void:
	UITheme.fade_out(self, func() -> void: cancelled.emit())

# --- helpers ---

## 줍기형(자원) 흔적인가 — 물통/식량/은신막만 다음 원정대가 집어 쓸 수 있다(uses 부여).
func _is_pickup_kind(kind: int) -> bool:
	return kind == TraceData.ObjectKind.WATER or kind == TraceData.ObjectKind.FOOD or kind == TraceData.ObjectKind.SHELTER

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

func _clear() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
