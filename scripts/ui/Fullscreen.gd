extends Node

## 웹 자동 전체화면 (autoload) — 첫 클릭/탭에서 전체화면으로 들어가고,
## ESC 등으로 창모드로 나온 뒤에도 다시 클릭하면 전체화면으로 복귀한다.
## 모바일·웹 브라우저의 주소창/툴바가 뷰포트 하단을 가려 UI 아래가 잘리는 문제를 없앤다.
## 브라우저 fullscreen API 는 "사용자 제스처"가 있어야 호출되므로 매 클릭에서(창모드일 때만) 요청한다.
## 이미 전체화면이면 클릭은 게임이 그대로 처리한다. 웹이 아니면 아무 것도 안 한다.

const ENABLED: bool = true

func _ready() -> void:
	if not ENABLED or not OS.has_feature("web"):
		set_process_input(false)

func _input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not tap:
		return
	# 창모드일 때만 전체화면으로 — 이미 전체화면이면 이 클릭은 게임 입력으로 흘려보낸다.
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
