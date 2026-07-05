class_name EngravedItem
extends Button

## 각인형 메뉴 항목 — 원본 `.menu-item`. 배경 없는 텍스트.
## hover 시 모래색 + 자간(.18em→.26em) 확장 + 밑줄이 중앙에서 부드럽게(cubic ease-out) 펼쳐진다.
## 쓰기: var it := EngravedItem.new(); it.init_item("...", 22, false); it.pressed.connect(...)

## 라이브 튜닝(DEV 오버레이 "글씨 튜닝" 슬라이더) — 전 인스턴스 공유. 값이 정해지면 여기 기본값을 갱신.
static var tune_core: float = 0.45      ## 밑줄 심지 높이(px)
static var tune_glow: float = 1.0       ## 밑줄 글로우 배율(0=글로우 없음)
static var tune_shadow_a: float = 0.95  ## 글자 그림자 진하기
static var tune_shadow_blur: int = 14   ## 글자 그림자 퍼짐(blur)
static var tune_outline_a: float = 0.5  ## 글자 밀착 테두리 어둠(그림자와 별개 — halo 를 빽빽하게)

var is_key: bool = false
var _px: int = 22
var _fv: FontVariation
var _spacing_cur: float = 0.0
var _underline: float = 0.0
var _u_rest: float = 0.0   ## 기본 밑줄 정도(대표 항목은 옅게 상시 — 원본 key::after)
var _tween: Tween
var _line_tex: GradientTexture2D  ## 밑줄 텍스처 — 가로로 투명→모래→투명(끝이 네모지지 않게 스르르 사라짐)

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
	# 글씨 그림자·테두리 — 글자 하나하나에 붙는다(가운데 덩어리 금지). 농도·퍼짐은 tune_*(DEV 슬라이더).
	add_theme_constant_override("shadow_offset_x", 0)
	add_theme_constant_override("shadow_offset_y", 2)
	add_to_group("engraved_item")  # DEV 튜닝 브로드캐스트 대상
	# 밑줄 텍스처 — 끝 12% 구간이 서서히 사라진다(draw_line 의 네모난 끝 대체).
	var lg := Gradient.new()
	lg.offsets = PackedFloat32Array([0.0, 0.12, 0.88, 1.0])
	lg.colors = PackedColorArray([
		Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.0),
		UITheme.SAND, UITheme.SAND,
		Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.0),
	])
	_line_tex = GradientTexture2D.new()
	_line_tex.gradient = lg
	_line_tex.fill_from = Vector2(0.0, 0.5)
	_line_tex.fill_to = Vector2(1.0, 0.5)
	_line_tex.width = 256
	_line_tex.height = 4
	apply_tuning()
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

## hover 진입/이탈 — 밑줄과 벌어짐을 동시에 부드럽게 애니.
## 자간(glyph spacing)은 정수 px 단위라 트윈하면 2~3단 점프로 뚝뚝 끊긴다(딱딱함의 원인).
## → 자간은 rest(.18em) 고정, 벌어짐은 scale.x(연속값)로 — 끊김 없이 사라락 넓어진다.
func _animate(on: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	pivot_offset = size * 0.5  # 중앙 기준으로 벌어짐(레이아웃 확정 후라 size 유효)
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var u: float = 1.0 if on else _u_rest
	var sx: float = 1.045 if on else 1.0  # .18em→.26em 상당의 폭 확장을 연속 스케일로
	_tween.tween_method(_set_underline, _underline, u, 0.55)  # 밑줄이 은은하게 배어나옴
	_tween.tween_property(self, "scale", Vector2(sx, 1.0), 0.55)

func _set_underline(v: float) -> void:
	_underline = v
	queue_redraw()

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
	a *= clampf(_underline * 1.6, 0.0, 1.0)  # 펼쳐지는 초입엔 옅게 — 빛이 스며들 듯
	var x0: float = cx - w * 0.5
	# 각인 밑줄 — 가로 그라디언트 텍스처(끝이 스르르 사라짐, draw_line 의 네모 끝 없음).
	# 심지 + 글로우 두 겹, 두께·글로우는 tune_*(DEV 슬라이더).
	if _line_tex != null and w > 2.0:
		if tune_glow > 0.01:
			var gh: float = 4.6 * tune_glow
			draw_texture_rect(_line_tex, Rect2(x0, y - gh * 0.5, w, gh), false, Color(1, 1, 1, a * 0.16))
		var ch: float = maxf(0.2, tune_core)
		draw_texture_rect(_line_tex, Rect2(x0, y - ch * 0.5, w, ch), false, Color(1, 1, 1, a * 0.95))

## 튜닝 적용 — 그림자·테두리 테마 갱신 + 밑줄 다시 그림(DEV 슬라이더가 그룹 호출).
func apply_tuning() -> void:
	add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, tune_shadow_a))
	add_theme_constant_override("shadow_outline_size", tune_shadow_blur)
	add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, tune_outline_a))
	add_theme_constant_override("outline_size", 4)
	queue_redraw()
