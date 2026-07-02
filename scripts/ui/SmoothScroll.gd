class_name SmoothScroll
extends ScrollContainer

## 부드러운 세로 스크롤 — 기본 ScrollContainer 의 마우스 휠은 한 번에 턱 점프한다.
## 휠 입력을 가로채 목표 위치로 이징(lerp)해 부드럽게 굴린다. 터치 드래그·스크롤바는 기본 동작 유지.
## 코드 UI 어디서나 ScrollContainer 대신 쓰면 된다(동일 API).

const WHEEL_STEP: float = 110.0   ## 휠 한 칸이 목표를 옮기는 픽셀
const SPEED: float = 16.0         ## 이징 속도(클수록 빠르게 따라붙음)

var _target: float = 0.0
var _smoothing: bool = false

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed:
		return
	var dir: float = 0.0
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		dir = -1.0
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		dir = 1.0
	if dir == 0.0:
		return
	# 스무딩 중이 아니면 현재 위치에서 시작(드래그·바로 옮겨진 위치를 이어받음).
	if not _smoothing:
		_target = float(scroll_vertical)
	_target = clampf(_target + dir * WHEEL_STEP, 0.0, _max_v())
	_smoothing = true
	accept_event()  # 기본 즉시 점프를 막는다

func _process(delta: float) -> void:
	if not _smoothing:
		return
	var v: float = lerpf(float(scroll_vertical), _target, clampf(delta * SPEED, 0.0, 1.0))
	scroll_vertical = int(round(v))
	if absf(float(scroll_vertical) - _target) <= 1.0:
		scroll_vertical = int(_target)
		_smoothing = false

## 스크롤 가능한 최대 세로 위치.
func _max_v() -> float:
	var sb: VScrollBar = get_v_scroll_bar()
	if sb == null:
		return 0.0
	return maxf(0.0, sb.max_value - sb.page)
