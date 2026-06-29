class_name UITheme
extends RefCounted

## 폰 우선 UI 사이징·색 — 한 곳에 모아 두고, 여기만 바꾸면 모든 화면에 반영된다.
## 논리 해상도는 1280x720 기준(stretch=canvas_items, aspect=expand).
## expand 라 논리 가로폭은 항상 1280 이상이므로 고정폭은 잘리지 않는다.
## 폰에서 물리적으로 작아지는 글씨·터치 타깃을 키우는 것이 핵심.

# --- 터치 타깃 (손가락 기준, 최소 56) ---
const BTN_H: float = 64.0        ## 기본 버튼 높이
const BTN_MIN_W: float = 240.0   ## 기본 버튼 최소 폭
const CHOICE_H: float = 64.0     ## 결정 카드 선택지 버튼 높이
const SLIDER_H: float = 44.0     ## 슬라이더 두께

# --- 글자 크기 (1280 논리폭 기준, 폰에서 읽기 편하게) ---
const FS_TITLE: int = 40         ## 타이틀
const FS_HEADING: int = 30       ## 화면 제목 / 상황 이름
const FS_BODY: int = 24          ## 본문(읽는 텍스트)
const FS_LABEL: int = 20         ## 일반 라벨 / 버튼 기본
const FS_SMALL: int = 16         ## 보조 설명
const FS_TINY: int = 13          ## 지도 눈금 등 캔버스 미세 텍스트

# --- 여백 ---
const SAFE_INSET: float = 28.0   ## 화면 가장자리 안전 여백 (노치/모서리 회피)
const GAP: int = 16              ## 일반 위젯 간격

# --- 색 ---
const SAND := Color(0.78, 0.64, 0.42)    ## 모래색 — 강조
const MUTED := Color(0.6, 0.6, 0.65)     ## 흐린 회색 — 설명문
const DANGER := Color(0.82, 0.36, 0.32)  ## 위험 — 초기화 등
const FG := Color(0.9, 0.9, 0.92)        ## 기본 밝은 글자

## 큼직한 기본 버튼 하나를 만든다 (터치 타깃 보장). 가로폭은 wide=true 면 컨테이너를 채운다.
static func make_button(label: String, wide: bool = false) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(0.0 if wide else BTN_MIN_W, BTN_H)
	if wide:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b
