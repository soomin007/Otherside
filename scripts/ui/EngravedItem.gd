class_name EngravedItem
extends Button

## 각인형 메뉴 항목 — 원본 `.menu-item`. 배경 없는 텍스트.
## hover 시 모래색 + 자간(.18em→.26em) 확장 + 밑줄이 중앙에서 부드럽게(cubic ease-out) 펼쳐진다.
## 쓰기: var it := EngravedItem.new(); it.init_item("...", 22, false); it.pressed.connect(...)

## 라이브 튜닝(DEV 오버레이 "글씨 튜닝" 슬라이더) — 전 인스턴스 공유. 기본값 = 사용자 확정(2026-07-05).
static var tune_core: float = 1.0       ## 밑줄 심지 높이(px)
static var tune_glow: float = 0.55      ## 밑줄 글로우 배율(0=글로우 없음)
static var tune_shadow_a: float = 0.25  ## 글자 그림자 진하기
static var tune_shadow_blur: int = 3    ## 글자 그림자 퍼짐(blur)
static var tune_outline_a: float = 0.1  ## 글자 밀착 테두리 어둠(그림자와 별개 — halo 를 빽빽하게)
static var tune_bg_a: float = 0.15      ## 항목 뒤 은은한 어둠(로고 방사 어둠처럼 넓게) 진하기
static var tune_bg_scale: float = 1.3   ## 그 어둠이 항목보다 얼마나 넓게 퍼지나(배율)

var is_key: bool = false
var _px: int = 22
var _fv: FontVariation
var _spacing_cur: float = 0.0
var _underline: float = 0.0
var _u_rest: float = 0.0   ## 기본 밑줄 정도(대표 항목은 옅게 상시 — 원본 key::after)
var _tween: Tween
var _line_tex: GradientTexture2D  ## 밑줄 텍스처 — 가로로 투명→모래→투명(끝이 네모지지 않게 스르르 사라짐)
var _bg_tex: GradientTexture2D    ## 항목 뒤 은은한 방사 어둠(로고 _dark_glow 와 같은 결 — 넓게 퍼져 상자로 안 읽힘)
var _lbl: Label                   ## 실제 글자 렌더 — Button 은 그림자 테마가 없어(무시됨) Label 이 그린다
var _base_col: Color              ## 평상시 글자색(hover 해제 시 복귀)

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
	# ⚠️ Button 테마엔 글자 그림자 속성이 없다(오버라이드가 조용히 무시됨 — DEV 슬라이더가 안 먹히던 원인).
	# → Button 글자는 투명(자리·크기 계산용)으로 두고, 같은 자리의 내부 Label 이 실제 렌더(그림자·테두리 지원).
	for ck in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_disabled_color"]:
		add_theme_color_override(ck, Color(0.0, 0.0, 0.0, 0.0))
	_base_col = UITheme.FG if is_key else Color(UITheme.FG.r, UITheme.FG.g, UITheme.FG.b, 0.8)
	_lbl = Label.new()
	_lbl.text = text
	_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lbl.offset_left = 26.0
	_lbl.offset_right = -26.0
	_lbl.offset_top = 14.0
	_lbl.offset_bottom = -16.0
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl.add_theme_font_override("font", _fv)
	_lbl.add_theme_font_size_override("font_size", _px)
	_lbl.add_theme_color_override("font_color", _base_col)
	_lbl.add_theme_constant_override("shadow_offset_x", 0)
	_lbl.add_theme_constant_override("shadow_offset_y", 2)
	_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lbl)
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
	# 항목 뒤 방사 어둠 — 로고 뒤 어둠(_dark_glow)과 같은 프로필(중앙→0.55→가장자리 0). 넓게 퍼져 덩어리로 안 읽힘.
	var bgg := Gradient.new()
	bgg.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	bgg.colors = PackedColorArray([
		Color(0.0, 0.0, 0.0, 1.0),
		Color(0.0, 0.0, 0.0, 0.45),
		Color(0.0, 0.0, 0.0, 0.0),
	])
	_bg_tex = GradientTexture2D.new()
	_bg_tex.gradient = bgg
	_bg_tex.fill = GradientTexture2D.FILL_RADIAL
	_bg_tex.fill_from = Vector2(0.5, 0.5)
	_bg_tex.fill_to = Vector2(0.98, 0.5)
	_bg_tex.width = 128
	_bg_tex.height = 64
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
	if _lbl != null:
		_lbl.add_theme_color_override("font_color", UITheme.SAND if on else _base_col)
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
	# 항목 뒤 은은한 어둠(상시) — 로고처럼 항목 전체를 넓게 감싼다. 진하기·퍼짐 = tune_bg_*(DEV 슬라이더).
	if _bg_tex != null and tune_bg_a > 0.01:
		var bw: float = size.x * tune_bg_scale
		var bh: float = size.y * tune_bg_scale * 0.9
		draw_texture_rect(_bg_tex, Rect2((size.x - bw) * 0.5, (size.y - bh) * 0.5, bw, bh), false,
			Color(1, 1, 1, tune_bg_a))
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

## 튜닝 적용 — 그림자·테두리를 내부 Label 에(Button 은 그림자 미지원) + 밑줄 다시 그림(DEV 슬라이더가 그룹 호출).
func apply_tuning() -> void:
	if _lbl != null:
		_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, tune_shadow_a))
		_lbl.add_theme_constant_override("shadow_outline_size", tune_shadow_blur)
		_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, tune_outline_a))
		_lbl.add_theme_constant_override("outline_size", 4)
	queue_redraw()
