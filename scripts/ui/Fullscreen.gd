extends Node

## 웹 자동 전체화면 (autoload) — 사이트 첫 클릭/탭에서 전체화면으로 전환한다.
## 모바일·웹 브라우저의 주소창/툴바가 뷰포트 하단을 가려 UI 아래가 잘리는 문제를 없앤다.
## 브라우저 fullscreen API 는 "사용자 제스처"가 있어야 호출되므로 첫 입력에서 한 번만 요청한다.
## 웹이 아니면(데스크탑·모바일 네이티브) 아무 것도 하지 않는다.

const ENABLED: bool = true

var _done: bool = false

func _ready() -> void:
	if not ENABLED or not OS.has_feature("web"):
		set_process_input(false)

func _input(event: InputEvent) -> void:
	if _done:
		return
	var tap: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not tap:
		return
	_done = true
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	set_process_input(false)  # 한 번이면 충분 — 이후 입력은 게임이 그대로 처리
