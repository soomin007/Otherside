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
var _ambient: CPUParticles2D                         ## 상시 모래 드리프트(열려 있는 동안)

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

	# 상시 모래 드리프트 — 어둠 속을 느리게 떠도는 몇 알(정서의 공기). open 때 화면 크기에 맞춰 켠다.
	_ambient = CPUParticles2D.new()
	_ambient.amount = 26
	_ambient.lifetime = 5.0
	_ambient.preprocess = 4.0    # 열자마자 이미 떠다니는 중
	_ambient.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_ambient.direction = Vector2(1.0, -0.12)
	_ambient.spread = 18.0
	_ambient.initial_velocity_min = 10.0
	_ambient.initial_velocity_max = 32.0
	_ambient.gravity = Vector2(2.0, -2.0)
	_ambient.scale_amount_min = 0.9
	_ambient.scale_amount_max = 2.0
	_ambient.color = UITheme.SAND
	var aramp := Gradient.new()
	aramp.offsets = PackedFloat32Array([0.0, 0.3, 0.75, 1.0])
	aramp.colors = PackedColorArray([
		Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.0),
		Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.4),
		Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.28),
		Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.0),
	])
	_ambient.color_ramp = aramp
	_ambient.emitting = false
	add_child(_ambient)

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
	if _ambient != null:
		_ambient.position = size * 0.5
		_ambient.emission_rect_extents = size * 0.46
		# 원정대의 현 위치가 험할수록(진행 row 가 깊을수록) 모래가 더 많이, 더 세게 휘날린다.
		var prog: float = 0.0
		if MapGraph.NODES.has(_node_id):
			prog = float(int(MapGraph.node(_node_id).get("row", 0))) / float(maxi(1, MapGraph.max_row()))
		_ambient.amount = int(lerpf(52.0, 120.0, prog))
		_ambient.initial_velocity_min = lerpf(12.0, 44.0, prog)
		_ambient.initial_velocity_max = lerpf(38.0, 140.0, prog)
		_ambient.gravity = Vector2(lerpf(2.0, 30.0, prog), -2.0)
		_ambient.lifetime = lerpf(5.0, 3.4, prog)
		_ambient.emitting = true
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
	_box.add_child(_hairline())

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
	hov.bg_color = Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.15)
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
	# 사진 밑 은은한 바닥 그림자 — 물건이 "이 자리에 놓여 있음"으로 읽히게(스펙 drop-shadow).
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(0, 130)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := TextureRect.new()
	sh.texture = _shadow_tex()
	sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sh.anchor_left = 0.5
	sh.anchor_right = 0.5
	sh.anchor_top = 1.0
	sh.anchor_bottom = 1.0
	sh.offset_left = -54.0
	sh.offset_right = 54.0
	sh.offset_top = -14.0
	sh.offset_bottom = 8.0
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(sh)
	var icon := ItemIcon.new()
	icon.key = res_key
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(icon)
	v.add_child(stack)
	var nm := UITheme.make_label(label, UITheme.FS_LABEL, UITheme.FG)
	v.add_child(nm)
	var cost: int = _run.leave_cost(res_key)
	var have: int = _run.get_res(res_key)
	var cl := UITheme.make_label("%s -%d · 보유 %d" % [str(UITheme.RES_KO.get(res_key, res_key)), cost, have], 13, COST_COL)
	v.add_child(cl)
	btn.add_child(v)
	if _run.can_leave(res_key):
		btn.pressed.connect(_pick_object.bind(kind, btn))
		# hover — 물건이 살짝 다가오고 이름이 모래빛으로(만질 수 있는 것의 숨).
		btn.mouse_entered.connect(_hover_candidate.bind(btn, nm, true))
		btn.mouse_exited.connect(_hover_candidate.bind(btn, nm, false))
	else:
		btn.disabled = true
		btn.modulate.a = 0.35
	return btn

## 후보 hover — 미세 확대 + 이름 모래빛. 흩어짐 연출 중엔 무시.
func _hover_candidate(btn: Control, nm: Label, on: bool) -> void:
	if _busy:
		return
	btn.pivot_offset = btn.size * 0.5
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(1.045, 1.045) if on else Vector2.ONE, 0.3)
	nm.add_theme_color_override("font_color", UITheme.SAND if on else UITheme.FG)

## 태그 칩 스타일 — selected 는 모래빛이 배어난 상태, hover 는 살짝 밝게.
func _chip_stylebox(selected: bool, hover: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if selected:
		sb.bg_color = Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.20 if hover else 0.16)
		sb.border_color = Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.65)
	else:
		sb.bg_color = Color(0.07, 0.055, 0.04, 0.62 if hover else 0.5)
		sb.border_color = Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.45 if hover else 0.22)
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb

## 헤어라인 — 가운데가 밝은 1px 모래선(디자인 토큰).
func _hairline() -> Control:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([
		Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.0),
		Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.5),
		Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.0),
	])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.0, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.custom_minimum_size = Vector2(340, 1)
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

## 바닥 그림자 텍스처 — 납작한 어두운 방사(물건 밑).
func _shadow_tex() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(0.0, 0.0, 0.0, 0.42), Color(0.0, 0.0, 0.0, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 24
	return gt

## 후보를 고름 — 그 물건이 천천히 모래로 바스러진다(약 1초: 확대+지연 페이드 + 세 번에 나눠 이는 모래).
## 게임 정서의 핵이라 조급하지 않게. 연출 중 재입력 잠금. (연출 속도 설정 옵션은 backlog.)
func _pick_object(kind: int, btn: Control) -> void:
	if _busy:
		return
	_busy = true
	_picked_kind = kind
	AudioManager.play_sfx("res://assets/sfx/sfx_leave.wav")
	var c: Vector2 = btn.get_global_rect().get_center()
	btn.pivot_offset = btn.size * 0.5
	UITheme.sand_puff_at(self, c, 18)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(btn, "scale", Vector2(1.34, 1.34), 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 페이드는 EASE_IN — 형체가 한동안 버티다가 끝에서 모래가 되어 무너진다.
	t.tween_property(btn, "modulate:a", 0.0, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# 세 번에 나눠 이는 모래 — 무너지는 동안 계속 흩어진다.
	var t2 := create_tween()
	t2.tween_interval(0.32)
	t2.tween_callback(func() -> void: UITheme.sand_puff_at(self, c + Vector2(randf_range(-24.0, 24.0), randf_range(-30.0, 6.0)), 24))
	t2.tween_interval(0.3)
	t2.tween_callback(func() -> void: UITheme.sand_puff_at(self, c + Vector2(randf_range(-20.0, 20.0), randf_range(-12.0, 16.0)), 20))
	t2.tween_interval(0.4)
	t2.tween_callback(_step_tags)

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
			tb.focus_mode = Control.FOCUS_NONE
			# 각인 톤 칩 — 어두운 몸통+모래 밑선, 고른 것은 모래빛으로 배어난다(기본 회색 상자 탈피).
			tb.add_theme_color_override("font_color", Color(UITheme.FG.r, UITheme.FG.g, UITheme.FG.b, 0.85))
			tb.add_theme_color_override("font_hover_color", UITheme.SAND)
			tb.add_theme_color_override("font_pressed_color", UITheme.SAND)
			tb.add_theme_stylebox_override("normal", _chip_stylebox(false))
			tb.add_theme_stylebox_override("hover", _chip_stylebox(false, true))
			tb.add_theme_stylebox_override("pressed", _chip_stylebox(true))
			tb.add_theme_stylebox_override("hover_pressed", _chip_stylebox(true, true))
			tb.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			tb.pressed.connect(_toggle_tag.bind(word))
			flow.add_child(tb)
		_box.add_child(flow)
	_box.add_child(_hairline())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var back := EngravedItem.new()
	back.init_item("← 뒤로", 16, false)
	back.pressed.connect(_step_what)
	row.add_child(back)
	var done := EngravedItem.new()
	done.init_item("남기고 계속 간다", 20, true)
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
	if _ambient != null:
		_ambient.emitting = false
	UITheme.fade_out(self, func() -> void: committed.emit())

func _cancel() -> void:
	if _ambient != null:
		_ambient.emitting = false
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
