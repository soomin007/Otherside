extends CanvasLayer

## 씬 전환 "흩어짐(scatter)" (핸드오프 전환 시스템) — 원칙: **배경과 UI 분리.**
## 배경은 절대 움직이지 않고 검은 무대로 페이드만, UI 레이어만 모래처럼 흩어진다.
## 웹 셰이더 금지라 blur(18px) 대신 스케일 확대+페이드 근사.
## 씬이 자기 UI 노드를 그룹 "ui_scatter" 에 넣으면 흩어짐에 참여한다(태그 없는 씬 = 베일 페이드 폴백 — Map 등).
## 전면 모래 sweep = 스펙: 중앙 밀집(0.7 수축)에서 임의 방향 방사, 화면 크기 비례 수(≤440), 2색,
## 느리게 오래 떠다니다 잦아듦(drag·swirl 근사). autoload — GameState.go_to_* 가 Transition.go() 를 부른다.

const UI_GROUP: String = "ui_scatter"
const OUT_DUR: float = 0.45   ## UI 흩어짐 — 배경 페이드와 겹쳐 총 OUT ~0.8s(스펙 880ms)
const VEIL_IN: float = 0.35   ## 배경 → 검은 무대(UI 가 대체로 사라진 뒤 시작)
const VEIL_OUT: float = 0.8   ## 새 화면 드러남(스펙 IN .8s)
const SAND2 := Color(0.659, 0.549, 0.376)  ## 파티클 보조색(스펙 rgb(168,140,96))

var _veil: ColorRect
var _sand: CPUParticles2D
var _busy: bool = false

func _ready() -> void:
	layer = 120  # 거의 최상단(DEV 128 아래)
	process_mode = Node.PROCESS_MODE_ALWAYS  # 전환 중 씬이 바뀌어도 유지

	_veil = ColorRect.new()
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.color = UITheme.BG            # 무대색(전환 시 드러나는 검은 무대)
	_veil.modulate.a = 0.0
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)

	# 모래 sweep — 스펙 파티클(수는 go() 에서 화면 크기로 결정).
	_sand = CPUParticles2D.new()
	_sand.emitting = false
	_sand.one_shot = true
	_sand.explosiveness = 1.0            # 클릭 순간 한꺼번에 흩어져 오래 떠다닌다
	_sand.lifetime = 2.2                 # 스펙 life 70~130프레임(1.2~2.2s)
	_sand.lifetime_randomness = 0.46
	_sand.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_sand.direction = Vector2(1.0, 0.0)
	_sand.spread = 180.0                 # 임의 방향 방사(angle = rand·2π)
	_sand.initial_velocity_min = 48.0    # 스펙 0.8~3.8 px/frame
	_sand.initial_velocity_max = 228.0
	_sand.gravity = Vector2(0.0, -13.0)  # vy 살짝 위(스펙 -0.2)
	_sand.damping_min = 28.0             # drag .992 근사 — 서서히 잦아듦
	_sand.damping_max = 80.0
	_sand.tangential_accel_min = -22.0   # swirl .05 근사 — 궤적이 살짝 감긴다
	_sand.tangential_accel_max = 22.0
	_sand.scale_amount_min = 1.0
	_sand.scale_amount_max = 3.0
	_sand.color = UITheme.SAND
	# 입자마다 두 모래색 사이 랜덤(스펙 2색).
	var init_ramp := Gradient.new()
	init_ramp.offsets = PackedFloat32Array([0.0, 1.0])
	init_ramp.colors = PackedColorArray([UITheme.SAND, SAND2])
	_sand.color_initial_ramp = init_ramp
	# 수명에 따른 알파(떠올랐다 잦아듦).
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	ramp.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 0.85),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	_sand.color_ramp = ramp
	add_child(_sand)

## 씬 전환 — UI 흩어짐 → 배경 페이드 → 교체 → 걷힘. 전환 중 재호출은 무시(busy).
func go(scene_path: String) -> void:
	if _busy:
		return
	_busy = true
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_sand.amount = mini(440, int(vp.x * vp.y / 2600.0))  # 스펙: min(440, w*h/2600)
	_sand.position = vp * 0.5
	_sand.emission_rect_extents = vp * 0.5 * 0.7          # 중앙 0.7 수축(스펙)
	_sand.restart()
	_sand.emitting = true
	_scatter_out()
	var tw: Tween = create_tween()
	tw.tween_interval(OUT_DUR * 0.7)  # UI 가 대체로 사라진 뒤 배경이 무대로 잠긴다(겹침 — 총 ~0.8s)
	tw.tween_property(_veil, "modulate:a", 1.0, VEIL_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(scene_path))
	tw.tween_interval(0.05)
	tw.tween_property(_veil, "modulate:a", 0.0, VEIL_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _busy = false)

## 떠나는 화면의 UI 만 흩어짐(OUT) — 배경은 그대로(원칙). 흩어짐은 씬 교체 전에 끝난다(0.45 < 0.665).
func _scatter_out() -> void:
	for n in get_tree().get_nodes_in_group(UI_GROUP):
		var c := n as Control
		if c == null or not c.is_visible_in_tree():
			continue
		c.pivot_offset = c.size * 0.5
		var t: Tween = create_tween()
		t.set_parallel(true)
		t.set_trans(Tween.TRANS_SINE)   # 스펙 cubic-bezier(.3,0,.5,1) ≈ 완만한 in-out — 처음부터 고르게 흩어진다
		t.set_ease(Tween.EASE_IN_OUT)
		t.tween_property(c, "scale", c.scale * 1.14, OUT_DUR)
		t.tween_property(c, "modulate:a", 0.0, OUT_DUR)
