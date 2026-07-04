extends CanvasLayer

## 씬 전환 "흩어짐(scatter)" (디자인 핸드오프) — 모래가 화면을 스윽 삼켰다 걷힌다.
## 웹 셰이더 금지라 blur 대신: 모래색 막 페이드 + 전면 CPUParticles2D 모래 sweep 으로 흩어짐을 낸다.
## autoload. GameState.go_to_* 가 change_scene 대신 Transition.go(path) 를 부른다.

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

	_sand = CPUParticles2D.new()
	_sand.emitting = false
	_sand.one_shot = true
	_sand.amount = 200
	_sand.lifetime = 1.1
	_sand.explosiveness = 0.35
	_sand.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_sand.direction = Vector2(1.0, -0.1)
	_sand.spread = 42.0
	_sand.gravity = Vector2(8.0, 4.0)
	_sand.initial_velocity_min = 60.0
	_sand.initial_velocity_max = 320.0
	_sand.scale_amount_min = 1.0
	_sand.scale_amount_max = 3.0
	_sand.color = UITheme.SAND
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	ramp.colors = PackedColorArray([
		Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.0),
		Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.85),
		Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.0),
	])
	_sand.color_ramp = ramp
	add_child(_sand)

## 모래로 덮었다 걷으며 씬을 바꾼다. 전환 중 재호출은 무시(busy).
func go(scene_path: String) -> void:
	if _busy:
		return
	_busy = true
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_sand.position = vp * 0.5
	_sand.emission_rect_extents = Vector2(vp.x * 0.5, vp.y * 0.5)
	_sand.restart()
	_sand.emitting = true
	var tw: Tween = create_tween()
	tw.tween_property(_veil, "modulate:a", 1.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(scene_path))
	tw.tween_interval(0.05)
	tw.tween_property(_veil, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _busy = false)
