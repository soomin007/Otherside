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
