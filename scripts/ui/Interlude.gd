extends Control

## 폭풍 막간(Interlude) — 원정과 원정 사이. 죽음/순환으로 한 원정이 끝나면
## GameState.go_to_interlude() 가 이 씬을 띄운다(첫 원정은 오프닝→마을 직행이라 안 뜬다).
## 연출: 위쪽 탑뷰 지도 띠를 모래폭풍 전선이 한 번 쓸고 지나가며(흔적 일부 묻힘·안개 재차오름)
## 시간이 흘렀음을 보이고, 그 아래 어두운 무대에 다음 원정대를 지명한 뒤 마을(Loadout)로.
## "매년"이 아니라 "폭풍이 지날 때마다"라는 주기 엔진을 플레이로 드러내는 막간(기획서 §2·§3).
## 순수 연출 — 흔적 uses·안개를 실제로 깎지 않는다(시간 기반 소멸은 별도 결정 후 후속).
## 웹 안전: 셰이더/GPUParticles 금지 → 전부 절차적 draw_* + CPUParticles2D.

const SWEEP_DUR: float = 2.4          ## 폭풍 전선이 지도를 가로지르는 시간(연출 세기 비례)
const TEXT_FADE: float = 0.9
const FOG_MAX: float = 0.8

# 밴드(지도 띠) 안 고정 배치 — 결정론(매 redraw 동일, 난수 금지).
const NODE_TS: Array = [0.10, 0.30, 0.50, 0.70, 0.90]           ## 노드 점 가로 비율(밟은 길)
const TRACE_MARKS: Array = [                                     ## 흔적 점(일부는 폭풍에 묻힘)
	{"t": 0.22, "dy": -0.22, "res": true,  "buries": false},
	{"t": 0.45, "dy": 0.24,  "res": true,  "buries": true},
	{"t": 0.64, "dy": -0.26, "res": false, "buries": true},
	{"t": 0.81, "dy": 0.20,  "res": true,  "buries": false},
]

var _front: float = 0.0    ## 폭풍 전선 위치 0(왼쪽 밖) → 1(오른쪽 밖). 흔적 묻힘·먼지벽이 이걸 따른다.
var _fog: float = 0.0      ## 0=안개 없음 → FOG_MAX=재차오름
var _settled: bool = false ## 폭풍이 지나가 텍스트가 뜬 상태(그다음 탭이면 마을로)
var _sand: CPUParticles2D
var _center: VBoxContainer
var _hint: Label
var _tw: Tween

func _ready() -> void:
	AudioManager.set_wind(0.95)  # 폭풍이 분다(마을 Loadout 이 다시 0 으로 되돌린다)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 모래 커튼(전경 알갱이) — 전선을 따라 흩날린다. 먼지벽(_draw)이 주 연출, 이건 디테일.
	_sand = CPUParticles2D.new()
	_sand.emitting = false
	_sand.local_coords = false            # 방출된 입자는 제자리(에미터가 지나가며 흔적을 남긴다)
	_sand.lifetime = 1.5
	_sand.lifetime_randomness = 0.42
	_sand.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_sand.direction = Vector2(1.0, 0.0)
	_sand.spread = 16.0
	_sand.initial_velocity_min = 90.0
	_sand.initial_velocity_max = 260.0
	_sand.gravity = Vector2(0.0, -4.0)
	_sand.damping_min = 14.0
	_sand.damping_max = 48.0
	_sand.scale_amount_min = 1.0
	_sand.scale_amount_max = 3.0
	_sand.color = UITheme.SAND
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.28, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.0),
	])
	_sand.color_ramp = ramp
	add_child(_sand)

	# 텍스트(폭풍이 지나간 뒤 뜬다) — 지도 띠 아래 어두운 무대에(고대비).
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

	var n: int = GameState.expedition_count + 1
	var nm: String = GameState.pending_expedition_name
	_add_center_label("모래가 다시 가라앉았다.", UITheme.FS_H1, UITheme.FG)
	_add_center_label("%d번째 원정대가 떠날 채비를 한다." % n, UITheme.FS_BODY, UITheme.MUTED)
	if nm != "":
		_add_center_label(nm, UITheme.FS_H1, UITheme.SAND)

	# 하단 힌트("탭하여 계속") — 폭풍이 지나간 뒤에만 보인다.
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

	get_viewport().size_changed.connect(queue_redraw)
	await get_tree().process_frame  # 레이아웃 확정 뒤 밴드 좌표로 sweep 시작
	if not is_inside_tree():
		return
	_start()

func _add_center_label(text: String, fs: int, color: Color) -> void:
	var lb: Label = UITheme.make_label(text, fs, color)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.custom_minimum_size = Vector2(UITheme.COLUMN_W, 0)
	_center.add_child(lb)

## 지도 띠 — 화면 위쪽 가로 밴드(자기 size 기준, 리사이즈 자동 대응).
func _band() -> Rect2:
	var s: Vector2 = size
	var band_h: float = clampf(s.y * 0.34, 130.0, 300.0)
	return Rect2(s.x * 0.08, s.y * 0.15, s.x * 0.84, band_h)

func _start() -> void:
	var m: float = AppSettings.load_motion()
	var band: Rect2 = _band()
	var cy: float = band.position.y + band.size.y * 0.5
	if m <= 0.02:
		# 모션 줄이기 — 애니 생략, 최종 상태로.
		_front = 1.0
		_fog = FOG_MAX
		queue_redraw()
		_on_settled()
		return
	_sand.amount = maxi(60, mini(280, int(size.x * size.y / 3600.0)))
	_sand.emission_rect_extents = Vector2(46.0, band.size.y * 0.55)
	_sand.position = Vector2(band.position.x - 90.0, cy)
	_sand.emitting = true
	var sweep: float = SWEEP_DUR * m
	_tw = create_tween()
	_tw.set_parallel(true)
	_tw.tween_property(_sand, "position:x", band.position.x + band.size.x + 90.0, sweep) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.tween_method(_set_front, 0.0, 1.0, sweep).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.tween_method(_set_fog, 0.0, FOG_MAX, sweep)
	_tw.set_parallel(false)
	_tw.tween_callback(_on_settled)

func _set_front(v: float) -> void:
	_front = v
	queue_redraw()

func _set_fog(v: float) -> void:
	_fog = v
	queue_redraw()

func _on_settled() -> void:
	_settled = true
	_front = 1.0
	if _sand != null:
		_sand.emitting = false
	AudioManager.set_wind(0.4)  # 폭풍이 잦아든다(마을에서 완전히 0 으로)
	if AppSettings.load_motion() <= 0.02:
		_center.modulate.a = 1.0
		_hint.modulate.a = 1.0
		return
	var t: Tween = create_tween()
	t.set_parallel(true)
	t.tween_property(_center, "modulate:a", 1.0, TEXT_FADE)
	t.tween_property(_hint, "modulate:a", 1.0, TEXT_FADE)

func _gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not tapped:
		return
	if not _settled:
		# 빨리 넘기기 — 폭풍을 즉시 완결하고 텍스트를 띄운다.
		if _tw != null and _tw.is_valid():
			_tw.kill()
		_fog = FOG_MAX
		queue_redraw()
		_on_settled()
		return
	GameState.go_to_loadout()

func _draw() -> void:
	var s: Vector2 = size
	draw_rect(Rect2(Vector2.ZERO, s), UITheme.BG)  # 어두운 무대
	var band: Rect2 = _band()
	# 양피지 지도 띠
	draw_rect(band, Color(UITheme.PAPER.r, UITheme.PAPER.g, UITheme.PAPER.b, 0.9))
	draw_rect(band, UITheme.PAPER_EDGE, false, 3.0)

	var left: float = band.position.x + band.size.x * 0.06
	var right: float = band.position.x + band.size.x * 0.94
	var midy: float = band.position.y + band.size.y * 0.5
	var amp: float = band.size.y * 0.16

	# 밟은 길(점선 사행) — 짝수 구간만 그려 점선처럼.
	var prev: Vector2 = Vector2(left, _path_y(0.0, midy, amp))
	var steps: int = 64
	for i in range(1, steps + 1):
		var f: float = float(i) / float(steps)
		var pt := Vector2(lerpf(left, right, f), _path_y(f, midy, amp))
		if i % 2 == 0:
			draw_line(prev, pt, UITheme.ROUTE, 2.0)
		prev = pt

	# 노드 점(밟은 자리 — 남는다)
	for nt in NODE_TS:
		var ft: float = float(nt)
		draw_circle(Vector2(lerpf(left, right, ft), _path_y(ft, midy, amp)), 6.0, UITheme.INK)

	# 흔적 점 — 묻히는 것은 폭풍 전선(_front)이 그 자리를 지날 때 사라진다(전선과 동기).
	for mk in TRACE_MARKS:
		var mt: float = float(mk["t"])
		var base := Vector2(lerpf(left, right, mt), _path_y(mt, midy, amp))
		var p2 := base + Vector2(0.0, float(mk["dy"]) * band.size.y)
		var a: float = 0.85
		if bool(mk["buries"]):
			a = 0.85 * clampf((mt + 0.09 - _front) / 0.18, 0.0, 1.0)  # 전선이 지나면 0
		if a <= 0.01:
			continue
		var col: Color = UITheme.SAND if bool(mk["res"]) else UITheme.MARKER_INK
		draw_circle(p2, 5.0, Color(col.r, col.g, col.b, a))

	# 안개 재차오름 — 양피지 위 옅은 헤이즈 + 양끝 부드러운 그라데이션.
	if _fog > 0.001:
		var e := UITheme.PAPER_EDGE
		draw_rect(band, Color(e.r, e.g, e.b, _fog * 0.26))
		var strips: int = 6
		var ew: float = band.size.x * 0.30
		var sw: float = ew / float(strips)
		for i in range(strips):
			var frac: float = 1.0 - float(i) / float(strips)  # 바깥일수록 진하게
			var ha: float = _fog * 0.42 * frac
			var hc := Color(e.r, e.g, e.b, ha)
			draw_rect(Rect2(band.position.x + sw * i, band.position.y, sw, band.size.y), hc)
			draw_rect(Rect2(band.position.x + band.size.x - sw * (i + 1), band.position.y, sw, band.size.y), hc)

	# 폭풍 전선(먼지벽) — 쓸고 지나가는 동안만. 가운데가 짙은 반투명 모래 기둥.
	if _front > 0.02 and _front < 0.98:
		var fx: float = lerpf(band.position.x, band.position.x + band.size.x, _front)
		var sc := UITheme.SAND
		var widths := PackedFloat32Array([0.15, 0.09, 0.045])
		var alphas := PackedFloat32Array([0.14, 0.30, 0.52])
		for i in range(widths.size()):
			var hw: float = band.size.x * widths[i]
			draw_rect(Rect2(fx - hw, band.position.y, hw * 2.0, band.size.y), Color(sc.r, sc.g, sc.b, alphas[i]))

func _path_y(f: float, midy: float, amp: float) -> float:
	return midy + sin(f * TAU * 1.5 + 0.6) * amp
