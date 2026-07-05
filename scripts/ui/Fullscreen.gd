extends Node

## 웹 표시 모드 (autoload) — 가로 고정(2026-07-05 사용자 확정)의 실행 지점.
## ① 첫 클릭/탭에서 전체화면 진입 — 이때 project.godot 의 orientation(sensor_landscape)으로
##    모바일 브라우저가 화면을 가로로 잠근다(모바일 주소창/툴바 가림 문제도 함께 해결).
## ② 가로 잠금이 불가능한 환경(iOS 사파리 등)에서 세로로 보고 있으면
##    "가로로 돌려 주세요" 안내가 게임을 덮는다 — 돌리면(또는 잠금이 걸리면) 스스로 사라진다.
## 브라우저 fullscreen API 는 "사용자 제스처"가 있어야 호출되므로 매 클릭에서(창모드일 때만) 요청한다.
## 웹이 아니면 아무 것도 안 한다(데스크톱 창은 사용자 소관).

const ENABLED: bool = true

var _hint: CanvasLayer
var _web: bool = false

func _ready() -> void:
	_web = OS.has_feature("web")
	if not ENABLED or not _web:
		set_process_input(false)
		return
	_build_hint()
	get_viewport().size_changed.connect(_refresh_hint)
	_refresh_hint()

func _input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not tap:
		return
	# 창모드일 때만 전체화면으로 — 이미 전체화면이면 이 클릭은 게임 입력으로 흘려보낸다.
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		# 전체화면 전환은 비동기(브라우저 promise) — 가로 잠금은 전체화면 상태에서만 받아들여지므로
		# 잠깐 뒤 명시 요청한다(두 번 — 기기별 전환 시간 편차). 성공하면 세로로 들고 있어도 스스로 돌아간다.
		get_tree().create_timer(0.5).timeout.connect(_lock_landscape)
		get_tree().create_timer(1.5).timeout.connect(_lock_landscape)
	elif _hint != null and _hint.visible:
		_lock_landscape()  # 전체화면인데 아직 세로(첫 잠금이 씹힘) — 안내 탭에서 재시도

## 화면을 가로로 잠근다(양방향 가로) — 브라우저 orientation API 를 JS 로 직접 호출.
## DisplayServer.screen_set_orientation 은 웹에서 동작하지 않음(실기기 확인 2026-07-06, known_issues).
## 잠금이 불가능한 환경(iOS 사파리·데스크톱)에선 조용히 무시된다.
func _lock_landscape() -> void:
	if not _web:
		return
	JavaScriptBridge.eval(
		"if (screen.orientation && screen.orientation.lock) { screen.orientation.lock('landscape').catch(function(e){}); }",
		true)

# --- 세로 화면 안내 (가로 고정) ---

## 안내 오버레이 — 모든 UI(일지 100·DEV 128) 위. 입력을 막아 세로로는 플레이가 진행되지 않게 한다.
## 탭하면 _input 이 전체화면(=가로 잠금)을 시도하므로, 잠금 가능한 기기는 탭 한 번에 풀린다.
func _build_hint() -> void:
	_hint = CanvasLayer.new()
	_hint.layer = 200
	_hint.visible = false
	add_child(_hint)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_hint.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var title := UITheme.make_label("기기를 가로로 돌려 주세요", UITheme.FS_H1, UITheme.SAND)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF  # CenterContainer 안에서 폭이 없어 글자가 세로로 쪼개지는 것 방지
	box.add_child(title)
	var sub := UITheme.make_label("이 여정은 가로 화면에 맞춰져 있습니다.", UITheme.FS_SMALL, UITheme.MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(sub)

## 세로(높이 > 너비)면 안내를 보이고, 가로가 되면 숨긴다. 뷰포트 크기 변화마다 호출.
func _refresh_hint() -> void:
	if _hint == null:
		return
	var s: Vector2 = get_viewport().get_visible_rect().size
	_hint.visible = s.y > s.x
