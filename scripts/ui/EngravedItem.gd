class_name EngravedItem
extends Button

## 각인형 메뉴 항목 — 원본 `.menu-item`. 배경 없는 텍스트.
## hover 시 모래색 + 자간(.18em→.26em) 확장 + 밑줄이 중앙에서 부드럽게(cubic ease-out) 펼쳐진다.
## 쓰기: var it := EngravedItem.new(); it.init_item("...", 22, false); it.pressed.connect(...)

var is_key: bool = false
var _px: int = 22
var _fv: FontVariation
var _spacing_cur: float = 0.0
var _underline: float = 0.0
var _u_rest: float = 0.0   ## 기본 밑줄 정도(대표 항목은 옅게 상시 — 원본 key::after)
var _tween: Tween

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
	_fv = FontVariation.new()
	var base: Font = get_theme_default_font()
	if base != null:
		_fv.base_font = base
	_spacing_cur = _px * 0.18
	_apply_spacing()
	add_theme_font_override("font", _fv)
	var base_col: Color = UITheme.FG if is_key else Color(UITheme.FG.r, UITheme.FG.g, UITheme.FG.b, 0.8)
	add_theme_color_override("font_color", base_col)
	add_theme_color_override("font_hover_color", UITheme.SAND)
	add_theme_color_override("font_focus_color", UITheme.SAND)
	add_theme_color_override("font_pressed_color", UITheme.SAND)
	add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	add_theme_constant_override("shadow_offset_x", 0)
	add_theme_constant_override("shadow_offset_y", 2)
	add_theme_constant_override("shadow_outline_size", 5)
	# 순수 텍스트 + 안쪽 여백(원본 padding) — 밑줄이 글씨 아래에 오도록 하단 여백.
	var empty := StyleBoxEmpty.new()
	empty.content_margin_top = 14.0
	empty.content_margin_bottom = 16.0
	empty.content_margin_left = 26.0
	empty.content_margin_right = 26.0
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(s, empty)
	_u_rest = 0.58 if is_key else 0.0
	_underline = _u_rest
	mouse_entered.connect(_animate.bind(true))
	mouse_exited.connect(_animate.bind(false))

## hover 진입/이탈 — 밑줄과 자간을 동시에 부드럽게(cubic ease-out) 애니.
func _animate(on: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var u: float = 1.0 if on else _u_rest
	var sp: float = _px * (0.26 if on else 0.18)
	_tween.tween_method(_set_underline, _underline, u, 0.35)  # 밑줄이 사라락 펼쳐짐(스펙 .35s)
	_tween.tween_method(_set_spacing_px, _spacing_cur, sp, 0.3)  # 자간(원래 속도)

func _set_underline(v: float) -> void:
	_underline = v
	queue_redraw()

func _set_spacing_px(v: float) -> void:
	_spacing_cur = v
	_apply_spacing()

func _apply_spacing() -> void:
	if _fv != null:
		_fv.set_spacing(TextServer.SPACING_GLYPH, int(round(_spacing_cur)))

func _draw() -> void:
	if _underline <= 0.01:
		return
	var text_w: float = maxf(0.0, size.x - 52.0)  # 좌우 여백(26*2) 뺀 글씨 폭 — hover(_underline=1) 면 밑줄이 글씨 전체 길이
	var w: float = text_w * _underline
	var cx: float = size.x * 0.5
	var y: float = size.y - 9.0
	var t: float = (_underline - _u_rest) / maxf(0.01, 1.0 - _u_rest)  # rest→hover 진행(0~1)
	var a: float = lerpf(0.5, 1.0, t) if is_key else 0.95
	var s := UITheme.SAND
	var x0: float = cx - w * 0.5
	var x1: float = cx + w * 0.5
	# 가느다란 각인 밑줄(원본 1px + glow) — 마름모(두꺼운 브러쉬)는 draw_colored_polygon 이라 계단(픽셀)이 보였음.
	# antialiased draw_line 으로 매끈하게: 넓고 옅은 글로우선(box-shadow 0 0 8px 대체) 위에 가는 본선.
	draw_line(Vector2(x0, y), Vector2(x1, y), Color(s.r, s.g, s.b, a * 0.20), 4.5, true)  # 소프트 글로우
	draw_line(Vector2(x0, y), Vector2(x1, y), Color(s.r, s.g, s.b, a), 1.2, true)          # 가는 본선(≈1px)
