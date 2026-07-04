class_name EngravedItem
extends Button

## 각인형 메뉴 항목 — 디자인 원본 `.menu-item` 재현. 배경 없는 텍스트.
## 자간(letter-spacing .18em, hover .26em) + 텍스트 그림자 + hover 시 모래색·자간 확장·밑줄 glow(.35s).
## 쓰기: var it := EngravedItem.new(); it.init_item("...", 22, false); it.pressed.connect(...)

var is_key: bool = false
var _px: int = 22
var _fv: FontVariation
var _spacing_target: float = 0.0
var _spacing_cur: float = 0.0
var _underline: float = 0.0
var _u_target: float = 0.0
var _u_rest: float = 0.0   ## 기본 밑줄 정도 — 대표 항목은 옅게 상시(원본 key::after)

## 생성 직후 호출 — 문구·글자 크기(px)·대표 여부. add_child 전에 부른다.
func init_item(txt: String, px: int, key: bool) -> void:
	text = txt
	_px = px
	is_key = key

func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_font_size_override("font_size", _px)
	# 자간 — FontVariation(base = 기본 폰트 마루부리). em → px: .18em 기준, hover .26em.
	_fv = FontVariation.new()
	var base: Font = get_theme_default_font()
	if base != null:
		_fv.base_font = base
	_spacing_cur = _px * 0.18
	_spacing_target = _spacing_cur
	_apply_spacing()
	add_theme_font_override("font", _fv)
	# 색 — 일반=아이보리*.8, 대표=아이보리, hover=모래색.
	var base_col: Color = UITheme.FG if is_key else Color(UITheme.FG.r, UITheme.FG.g, UITheme.FG.b, 0.8)
	add_theme_color_override("font_color", base_col)
	add_theme_color_override("font_hover_color", UITheme.SAND)
	add_theme_color_override("font_focus_color", UITheme.SAND)
	add_theme_color_override("font_pressed_color", UITheme.SAND)
	# 텍스트 그림자(원본 text-shadow) — blur 는 outline_size 로 근사.
	add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	add_theme_constant_override("shadow_offset_x", 0)
	add_theme_constant_override("shadow_offset_y", 2)
	add_theme_constant_override("shadow_outline_size", 5)
	# 순수 텍스트 — 상태별 배경 박스 제거.
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(s, empty)
	_u_rest = 0.58 if is_key else 0.0  # 대표 항목은 기본 36%(=full 0.62 의 58%) 옅은 밑줄
	_underline = _u_rest
	_u_target = _u_rest
	mouse_entered.connect(func() -> void:
		_u_target = 1.0
		_spacing_target = _px * 0.26)
	mouse_exited.connect(func() -> void:
		_u_target = _u_rest
		_spacing_target = _px * 0.18)

func _apply_spacing() -> void:
	if _fv != null:
		_fv.set_spacing(TextServer.SPACING_GLYPH, int(round(_spacing_cur)))

func _process(delta: float) -> void:
	var changed := false
	if not is_equal_approx(_spacing_cur, _spacing_target):
		_spacing_cur = move_toward(_spacing_cur, _spacing_target, (_px * 0.26 + 1.0) * delta / 0.3)
		_apply_spacing()
		changed = true
	if not is_equal_approx(_underline, _u_target):
		_underline = move_toward(_underline, _u_target, delta / 0.35)
		changed = true
	if changed:
		queue_redraw()

func _draw() -> void:
	if _underline <= 0.01:
		return
	var full: float = size.x * (0.62 if is_key else 0.52)
	var w: float = full * _underline
	var y: float = size.y - 9.0
	var x0: float = (size.x - w) * 0.5
	var t: float = (_underline - _u_rest) / maxf(0.01, 1.0 - _u_rest)  # rest→hover 진행(0~1)
	var a: float = lerpf(0.5, 1.0, t) if is_key else 0.95
	var s := UITheme.SAND
	draw_line(Vector2(x0, y), Vector2(x0 + w, y), Color(s.r, s.g, s.b, a * 0.45), 4.0)  # glow(box-shadow 근사)
	draw_line(Vector2(x0, y), Vector2(x0 + w, y), Color(s.r, s.g, s.b, a), 1.5)         # 밑줄 심
