extends Control

## 폭풍 막간(Interlude) — 원정과 원정 사이. 죽음/순환으로 한 원정이 끝나면
## GameState.go_to_interlude() 가 이 씬을 띄운다(첫 원정은 오프닝→마을 직행이라 안 뜬다).
## 연출(2026-07-12 아트 교체 — 옛 절차적 지도 띠 폐기): 삽화 3장 크로스페이드
##   ① 폭풍이 세상을 쓸어간다(자동 진행, 탭으로 건너뛰기)
##   ② 모래가 가라앉았다 + 지난 원정이 어디서 끝났는지(실제 런 기록)
##   ③ 다음 원정대 지명 → 탭하면 마을(Loadout)로.
## 느린 줌(켄 번즈)으로 정지 이미지에 숨을 넣는다 — 영상 없이 컷신처럼.
## "매년"이 아니라 "폭풍이 지날 때마다"라는 주기 엔진을 플레이로 드러내는 막간(기획서 §2·§3).
## 순수 연출 — 흔적 uses·안개를 실제로 깎지 않는다(시간 기반 소멸은 별도 결정 후 후속).
## 웹 안전: 셰이더/GPUParticles 금지 → TextureRect + Tween + CPUParticles2D.

const ART_PATHS: Array = [
	"res://assets/arts/55_막간_폭풍.png",
	"res://assets/arts/56_막간_고요.png",
	"res://assets/arts/57_막간_채비.png",
]
const FADE: float = 1.4        ## 장면 크로스페이드
const TEXT_FADE: float = 0.9
const STORM_HOLD: float = 3.4  ## 폭풍 장면이 머무는 시간(그 뒤 자동으로 고요로)
const KB_ZOOM: float = 1.06    ## 켄 번즈 줌 배율(은은하게)
const KB_DUR: float = 11.0     ## 켄 번즈 줌 시간 — 장면 체류보다 길어 끝까지 안 멈춘다
const SCRIM_A: float = 0.42    ## 텍스트 가독 스크림(고요부터 텍스트와 함께 배어난다)

var _phase: int = -1           ## 0=폭풍 1=고요(요약) 2=채비(지명). 탭으로 전진, 2에서 탭=마을
var _tex: Array = []           ## 장면별 Texture2D(없으면 null — 어두운 무대 fallback)
var _art_a: TextureRect        ## 삽화 레이어 A/B — 오프닝과 같은 "위로 배어나는" 크로스페이드
var _art_b: TextureRect
var _art_front: TextureRect
var _art_tw: Tween
var _kb_tw: Tween
var _hold_tw: Tween
var _scrim: ColorRect
var _center: VBoxContainer
var _hint: Label
var _sand: CPUParticles2D
var _motion: float = 1.0

func _ready() -> void:
	AudioManager.set_wind(0.95)  # 폭풍이 분다(마을 Loadout 이 다시 0 으로 되돌린다)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_motion = AppSettings.load_motion()

	# 삽화 로드 — 하나라도 있으면 레이어 두 장(크로스페이드용)을 깐다. 없으면 어두운 무대 + 텍스트만.
	for p in ART_PATHS:
		_tex.append(load(str(p)) if ResourceLoader.exists(str(p)) else null)
	if _tex.any(func(t): return t != null):
		_art_a = _make_art_layer()
		_art_b = _make_art_layer()
		_art_front = _art_a

	# 모래 커튼(전경 알갱이) — 폭풍 장면 동안 화면을 오른쪽에서 왼쪽으로 흩날린다(삽화의 폭풍 방향과 일치).
	_sand = CPUParticles2D.new()
	_sand.emitting = false
	_sand.local_coords = false
	_sand.lifetime = 2.4
	_sand.lifetime_randomness = 0.42
	_sand.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_sand.direction = Vector2(-1.0, 0.0)
	_sand.spread = 14.0
	_sand.initial_velocity_min = 260.0
	_sand.initial_velocity_max = 640.0
	_sand.gravity = Vector2(0.0, -4.0)
	_sand.scale_amount_min = 1.0
	_sand.scale_amount_max = 3.0
	_sand.color = UITheme.SAND
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.28, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.0),
	])
	_sand.color_ramp = ramp
	add_child(_sand)

	# 글씨 가독용 어두운 스크림(삽화 위, 텍스트 아래) — 폭풍 장면엔 없다가 텍스트와 함께 배어난다.
	_scrim = ColorRect.new()
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.color = Color(0.02, 0.02, 0.04, SCRIM_A)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.modulate.a = 0.0
	add_child(_scrim)

	# 텍스트(고요부터 뜬다) — 화면 중하단, 삽화의 차분한 하단 위에.
	var cc := CenterContainer.new()
	cc.anchor_left = 0.0
	cc.anchor_right = 1.0
	cc.anchor_top = 0.56
	cc.anchor_bottom = 0.92
	cc.offset_left = 0.0
	cc.offset_right = 0.0
	cc.offset_top = 0.0
	cc.offset_bottom = 0.0
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	_center = VBoxContainer.new()
	_center.alignment = BoxContainer.ALIGNMENT_CENTER
	_center.add_theme_constant_override("separation", 16)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.modulate.a = 0.0
	_center.add_to_group(Transition.UI_GROUP)  # 마을로 넘어갈 때 모래처럼 흩어진다
	cc.add_child(_center)

	# 하단 힌트("탭하여 계속") — 고요부터 보인다.
	var bottom := CenterContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -100.0
	bottom.offset_bottom = -UITheme.SAFE
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	_hint = UITheme.make_label("탭하여 계속", UITheme.FS_SMALL, UITheme.MUTED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.modulate.a = 0.0
	bottom.add_child(_hint)

	get_viewport().size_changed.connect(_on_resize)
	await get_tree().process_frame  # 레이아웃 확정 뒤 피벗(줌 중심)을 잡고 시작
	if not is_inside_tree():
		return
	_on_resize()
	var storm_tex: Texture2D = _tex[0]
	if _anim() and storm_tex != null:
		_enter_phase(0)
	else:
		_enter_phase(1)  # 모션 줄이기 또는 폭풍 삽화 없음 — 폭풍 장면 생략

func _anim() -> bool:
	return _motion > 0.02

func _enter_phase(p: int) -> void:
	_phase = p
	_show_art(p)
	match p:
		0:
			_sand.amount = clampi(int(size.x * size.y / 4200.0), 40, 220)
			_sand.emission_rect_extents = Vector2(40.0, size.y * 0.5)
			_sand.position = Vector2(size.x + 60.0, size.y * 0.5)
			_sand.emitting = true
			_hold_tw = create_tween()
			_hold_tw.tween_interval(STORM_HOLD)
			_hold_tw.tween_callback(_enter_phase.bind(1))
		1:
			AudioManager.set_wind(0.4)  # 폭풍이 잦아든다(마을에서 완전히 0 으로)
			_sand.emitting = false
			_set_text_lines(_calm_lines())
			_reveal_ui()
		2:
			_swap_text_lines(_muster_lines())

## ② 고요 — 폭풍이 지나갔고, 지난 원정이 어떻게 끝났는지.
func _calm_lines() -> Array:
	var out: Array = [{"text": "모래가 다시 가라앉았다.", "fs": UITheme.FS_H1, "color": UITheme.FG}]
	var s: String = _last_run_summary()
	if s != "":
		out.append({"text": s, "fs": UITheme.FS_BODY, "color": UITheme.MUTED})
	return out

## ③ 채비 — 다음 원정대 지명.
func _muster_lines() -> Array:
	var n: int = GameState.expedition_count + 1
	var out: Array = [{"text": "%d번째 원정대가 떠날 채비를 한다." % n, "fs": UITheme.FS_BODY, "color": UITheme.MUTED}]
	if GameState.pending_expedition_name != "":
		out.append({"text": GameState.pending_expedition_name, "fs": UITheme.FS_H1, "color": UITheme.SAND})
	return out

## 방금 끝난 원정의 마지막을 세계의 말로 한두 줄. 기록이 없으면 빈 문자열(제목 줄만 뜬다).
## 도달(순환) 기록 우선 — 재회는 타이틀로 가서 막간에 안 온다. 아니면 이번 원정의 죽음 기록.
func _last_run_summary() -> String:
	var n: int = GameState.expedition_count
	if n <= 0:
		return ""
	for a in GameState.arrivals:
		if a is Dictionary and int(a.get("expedition", -1)) == n:
			return "지난 원정은 끝에 닿았다.\n그리고 돌아오지 않았다."
	for i in range(GameState.deaths.size() - 1, -1, -1):
		var d: Variant = GameState.deaths[i]
		if not (d is Dictionary) or int(d.get("expedition", -1)) != n:
			continue
		var nid: String = str(d.get("node_id", ""))
		var nname: String = str(MapGraph.node(nid).get("name", "")) if nid != "" else ""
		if nname != "":
			return "지난 원정은 %s에서 멈췄다.\n돌아온 사람은 없다." % nname
		return "지난 원정은 길 위에서 멈췄다.\n돌아온 사람은 없다."
	return ""

## 텍스트 줄들을 즉시 교체(각 줄 = {text, fs, color}).
func _set_text_lines(lines: Array) -> void:
	for c in _center.get_children():
		c.queue_free()
	for ln in lines:
		var d: Dictionary = ln
		var col: Color = d["color"]
		_add_center_label(str(d["text"]), int(d["fs"]), col)

## 텍스트를 페이드아웃 → 교체 → 페이드인.
func _swap_text_lines(lines: Array) -> void:
	if not _anim():
		_set_text_lines(lines)
		return
	var t: Tween = create_tween()
	t.tween_property(_center, "modulate:a", 0.0, TEXT_FADE * 0.5)
	t.tween_callback(_set_text_lines.bind(lines))
	t.tween_property(_center, "modulate:a", 1.0, TEXT_FADE)

func _add_center_label(text: String, fs: int, color: Color) -> void:
	var lb: Label = UITheme.make_label(text, fs, color)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.custom_minimum_size = Vector2(UITheme.COLUMN_W, 0)
	_center.add_child(lb)

## 텍스트·힌트·스크림을 함께 배어나게 한다(고요 진입 시 1회).
func _reveal_ui() -> void:
	if not _anim():
		_center.modulate.a = 1.0
		_hint.modulate.a = 1.0
		_scrim.modulate.a = 1.0
		return
	var t: Tween = create_tween()
	t.set_parallel(true)
	t.tween_property(_center, "modulate:a", 1.0, TEXT_FADE)
	t.tween_property(_hint, "modulate:a", 1.0, TEXT_FADE)
	t.tween_property(_scrim, "modulate:a", 1.0, TEXT_FADE)

## 장면 삽화를 idx 로 크로스페이드 — 옛 장은 불투명하게 남긴 채 새 장이 그 위로 배어난다
## (동시 교차는 중간에 뒤 무대가 비친다 — 오프닝에서 검증된 방식). 새 장엔 켄 번즈 줌을 건다.
func _show_art(idx: int) -> void:
	if _art_front == null:
		return
	if _art_tw != null and _art_tw.is_valid():
		_art_tw.kill()
	for l in [_art_a, _art_b]:
		l.modulate.a = 1.0 if l == _art_front else 0.0
	var nt: Texture2D = null
	if idx >= 0 and idx < _tex.size():
		nt = _tex[idx]
	if nt == null:
		_art_front.modulate.a = 0.0  # 이 장면 삽화 없음 — 어두운 무대 위 텍스트만
		return
	if _art_front.texture == null or not _anim():
		_art_front.texture = nt
		_art_front.modulate.a = 1.0
		_start_kenburns(_art_front)
		return
	var back: TextureRect = _art_front
	var front: TextureRect = _art_b if _art_front == _art_a else _art_a
	front.texture = nt
	front.scale = Vector2.ONE
	if front.get_index() < back.get_index():
		move_child(front, back.get_index())  # 새 장을 옛 장 바로 위로(모래·스크림·글은 그대로 위)
	_art_front = front
	_art_tw = create_tween()
	_art_tw.tween_property(front, "modulate:a", 1.0, FADE)
	_art_tw.tween_callback(func() -> void: back.modulate.a = 0.0)
	_start_kenburns(front)

## 느린 줌(켄 번즈) — 정지 이미지가 살아 있는 것처럼. 화면 중심 기준(피벗은 _on_resize 가 잡는다).
func _start_kenburns(layer: TextureRect) -> void:
	if not _anim():
		return
	if _kb_tw != null and _kb_tw.is_valid():
		_kb_tw.kill()
	layer.scale = Vector2.ONE
	_kb_tw = create_tween()
	_kb_tw.tween_property(layer, "scale", Vector2(KB_ZOOM, KB_ZOOM), KB_DUR)

## 삽화 레이어 한 장(풀스크린 cover, 투명 시작).
func _make_art_layer() -> TextureRect:
	var tr := TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.modulate.a = 0.0
	add_child(tr)
	return tr

## 리사이즈 — 줌 피벗을 화면 중심으로 다시 잡는다(줌이 가장자리로 쏠리지 않게).
func _on_resize() -> void:
	for l in [_art_a, _art_b]:
		if l != null:
			l.pivot_offset = l.size * 0.5
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not tapped:
		return
	match _phase:
		0:
			# 폭풍 건너뛰기 — 자동 진행 예약을 죽이고 바로 고요로.
			if _hold_tw != null and _hold_tw.is_valid():
				_hold_tw.kill()
			_enter_phase(1)
		1:
			_enter_phase(2)
		2:
			GameState.go_to_loadout()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UITheme.BG)  # 어두운 무대(삽화 없는 장면의 fallback 겸 크로스페이드 밑판)
