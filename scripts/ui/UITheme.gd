class_name UITheme
extends RefCounted

## 모바일 우선 UI 시스템 — 사이즈·색·레이아웃 헬퍼를 한 곳에.
##
## 체감 크기의 핵심: 논리 해상도(base)가 작아야 폰 세로에서 요소가 크게 보인다.
## stretch=canvas_items, aspect=expand 에서 "제약 축 = base 값"이다.
## 세로폰에선 가로가 제약 축 → 논리 가로폭 = base 가로폭(600). 그래서 600 으로 디자인하면
## 폰 세로 화면을 600 폭 캔버스로 보는 셈이라 글자·버튼이 충분히 크다(1280 이면 절반으로 줄어듦).
## 가로/데스크톱은 세로 base 가 제약 축이라 영향 없음.
##
## 레이아웃 원칙: 콘텐츠는 "중앙 정렬 + 최대폭 컬럼". 세로폰에선 거의 꽉 차고, 가로에선 가운데 카드처럼.

# --- 색 ---
const BG := Color(0.066667, 0.070588, 0.094118)  ## 배경(클리어 컬러와 동일)
const FG := Color(0.93, 0.93, 0.96)              ## 기본 밝은 글자
const SAND := Color(0.84, 0.70, 0.47)            ## 모래색 — 강조
const MUTED := Color(0.62, 0.62, 0.69)           ## 흐린 회색 — 보조 설명
const DANGER := Color(0.88, 0.42, 0.38)          ## 위험 — 초기화 등
const PANEL := Color(0.10, 0.105, 0.13)          ## 카드 배경
const PANEL_BORDER := Color(0.27, 0.26, 0.33)    ## 카드 테두리
const SCRIM := Color(0.02, 0.02, 0.04, 0.8)      ## 모달 뒤 어둡게

# --- 고지도·양피지 팔레트 (지도·단면이 공유) ---
const PAPER := Color(0.82, 0.74, 0.57)       ## 빛바랜 양피지 바탕
const PAPER_EDGE := Color(0.58, 0.48, 0.32)  ## 가장자리(낡아 그을린)
const INK := Color(0.27, 0.19, 0.11)         ## 세피아 잉크 — 심볼·이름·테두리
const INK_FADE := Color(0.50, 0.41, 0.29)    ## 빛바랜 — 미방문·미지
const ROUTE := Color(0.38, 0.28, 0.16)       ## 밟은 길(트레일)
const MARKER_INK := Color(0.55, 0.20, 0.12)  ## 원정대 마커(붉은 세피아)

# --- 타입 스케일 (base 600 세로 기준, 폰에서 읽기 편한 크기) ---
const FS_DISPLAY: int = 46   ## 타이틀 로고
const FS_H1: int = 34        ## 화면 제목 / 상황 이름
const FS_H2: int = 27        ## 자원 수치 등 큰 강조
const FS_BODY: int = 26      ## 본문(읽는 텍스트) / 주요 버튼
const FS_LABEL: int = 22     ## 일반 라벨 / 보조 버튼
const FS_SMALL: int = 18     ## 보조 설명
const FS_TINY: int = 14      ## 지도 눈금 등 캔버스 미세 텍스트

# --- 터치 / 레이아웃 ---
const BTN_H: float = 76.0      ## 주요 버튼 높이
const BTN_H_SM: float = 60.0   ## 보조 버튼 높이
const SLIDER_H: float = 48.0   ## 슬라이더 두께
const COLUMN_W: float = 520.0  ## 콘텐츠 최대폭
const PAD: float = 32.0        ## 화면 가장자리 여백
const CARD_PAD: float = 28.0   ## 카드 안쪽 여백
const GAP: int = 18            ## 위젯 간격
const SAFE: float = 24.0       ## 노치/모서리 안전 여백

# --- 레이아웃 헬퍼 ---

## 화면 중앙의 최대폭 컬럼을 만들어 반환한다. 위젯을 여기에 쌓으면
## 세로폰에선 거의 꽉 차고 가로에선 가운데 정렬된다. 반환된 VBox 가 콘텐츠 컨테이너.
static func build_column(host: Control, gap: int = GAP) -> VBoxContainer:
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_set_margin(mc, int(PAD))
	host.add_child(mc)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	mc.add_child(cc)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", gap)
	col.custom_minimum_size = Vector2(COLUMN_W, 0)
	cc.add_child(col)
	return col

## 카드(둥근 패널 + 테두리 + 안쪽 여백). 모달 콘텐츠를 떠다니는 텍스트가 아니라 읽기 좋은 면 위에 둔다.
static func make_card(width: float = COLUMN_W) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = PANEL_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(CARD_PAD)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(width, 0)
	return p

## 풀폭 버튼(터치 타깃 보장). primary=true 면 크고 본문 크기, false 면 낮고 라벨 크기.
static func make_button(text: String, primary: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, BTN_H if primary else BTN_H_SM)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", FS_BODY if primary else FS_LABEL)
	b.clip_text = true
	return b

## 자동 줄바꿈 라벨. 컬럼/카드 안에 넣으면 그 폭에서 줄바꿈된다.
static func make_label(text: String, size: int = FS_BODY, color: Color = FG, center: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

static func _set_margin(mc: MarginContainer, v: int) -> void:
	for s in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + s, v)

# --- 다듬기 헬퍼 (설정 등 정적 화면용) ---

## 얇은 가로 구분선(ColorRect) — 기본 HSeparator 대신 색·두께를 통제한다.
static func make_hairline(color: Color = Color(SAND.r, SAND.g, SAND.b, 0.18), thickness: float = 1.0) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, thickness)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r

## 면/테두리를 가진 버튼(pill) — 기본 회색 크롬 대신 의도된 모양. fill 을 투명하게 주면 외곽선 버튼.
static func make_pill(text: String, fg: Color, fill: Color, border: Color, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, BTN_H if primary else BTN_H_SM)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", FS_BODY if primary else FS_LABEL)
	b.clip_text = true
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg.r, fg.g, fg.b, 0.35))
	var solid: bool = fill.a > 0.05
	b.add_theme_stylebox_override("normal", _pill_sb(fill, border))
	b.add_theme_stylebox_override("hover", _pill_sb(
		fill.lightened(0.07) if solid else Color(border.r, border.g, border.b, 0.12),
		border.lightened(0.12)))
	b.add_theme_stylebox_override("pressed", _pill_sb(
		fill.darkened(0.10) if solid else Color(border.r, border.g, border.b, 0.20), border))
	b.add_theme_stylebox_override("disabled", _pill_sb(
		Color(fill.r, fill.g, fill.b, fill.a * 0.4), Color(border.r, border.g, border.b, border.a * 0.4)))
	b.add_theme_stylebox_override("focus", _pill_sb(Color(0, 0, 0, 0), SAND))
	return b

static func _pill_sb(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1 if border.a > 0.01 else 0)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(12)
	return sb

## 모래색 슬라이더 — 얇은 트랙 + 채움(모래) + 모래알 그래버. 기본 밋밋한 슬라이더 대체.
static func style_slider(s: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(SAND.r, SAND.g, SAND.b, 0.16)
	track.set_corner_radius_all(4)
	track.content_margin_top = 3.0
	track.content_margin_bottom = 3.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = SAND
	fill.set_corner_radius_all(4)
	fill.content_margin_top = 3.0
	fill.content_margin_bottom = 3.0
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var dot: ImageTexture = _grain_texture(22, SAND)
	s.add_theme_icon_override("grabber", dot)
	s.add_theme_icon_override("grabber_highlight", dot)

## 모래알(부드러운 원) 텍스처 — 셰이더 없이 절차적. 슬라이더 그래버 등.
static func _grain_texture(sz: int, col: Color) -> ImageTexture:
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var c: float = sz * 0.5
	for y in sz:
		for x in sz:
			var d: float = Vector2(x - c + 0.5, y - c + 0.5).length() / c
			var a: float = smoothstep(0.0, 1.0, clampf(1.0 - d, 0.0, 1.0) * 1.3)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)
