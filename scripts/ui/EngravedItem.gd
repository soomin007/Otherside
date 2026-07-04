class_name EngravedItem
extends Button

## 각인형 메뉴 항목(디자인 핸드오프 타이틀 메뉴) — 배경/테두리 없는 텍스트.
## hover 시 글자가 모래색이 되고, 중앙에서 밑줄이 좌우로 번진다(.35s). 버튼 박스가 아니라 "각인된 글씨".
## 쓰기: var it := EngravedItem.new(); it.text = "..."; it.is_key = true(대표 항목); it.pressed.connect(...)

var is_key: bool = false   ## 대표 항목이면 밑줄을 더 넓게(0.62), 아니면 0.5
var _underline: float = 0.0
var _target: float = 0.0

func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # 텍스트 폭만(밑줄이 글자 기준), VBox 안에서 중앙 정렬
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_color_override("font_color", Color(UITheme.FG.r, UITheme.FG.g, UITheme.FG.b, 0.8))
	add_theme_color_override("font_hover_color", UITheme.SAND)
	add_theme_color_override("font_focus_color", UITheme.SAND)
	add_theme_color_override("font_pressed_color", UITheme.SAND)
	# flat 버튼도 상태별 stylebox 가 배경을 그릴 수 있어 전부 빈 박스로(순수 텍스트).
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(s, empty)
	mouse_entered.connect(func() -> void: _target = 1.0)
	mouse_exited.connect(func() -> void: _target = 0.0)

func _process(delta: float) -> void:
	if not is_equal_approx(_underline, _target):
		_underline = move_toward(_underline, _target, delta / 0.35)
		queue_redraw()

func _draw() -> void:
	if _underline <= 0.01:
		return
	var full: float = size.x * (0.62 if is_key else 0.5)
	var w: float = full * _underline
	var y: float = size.y - 5.0
	var x0: float = (size.x - w) * 0.5
	draw_line(Vector2(x0, y), Vector2(x0 + w, y), Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.9), 1.5)
