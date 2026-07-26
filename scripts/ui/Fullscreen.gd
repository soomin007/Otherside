extends Node

## 웹 표시 모드 (autoload) — 가로 고정(2026-07-05 사용자 확정)의 실행 지점.
## ① 첫 클릭/탭에서 전체화면 진입 — 이때 project.godot 의 orientation(sensor_landscape)으로
##    모바일 브라우저가 화면을 가로로 잠근다(모바일 주소창/툴바 가림 문제도 함께 해결).
## ② 가로 잠금이 불가능한 환경(iOS 사파리 등)에서 세로로 보고 있으면
##    "가로로 돌려 주세요" 안내가 게임을 덮는다 — 돌리면(또는 잠금이 걸리면) 스스로 사라진다.
## 브라우저 fullscreen API 는 "사용자 제스처"가 있어야 호출되므로 매 클릭에서(창모드일 때만) 요청한다.
## 웹이 아니면 아무 것도 안 한다(데스크톱 창은 사용자 소관).

const ENABLED: bool = true

## 가로 잠금 JS — 전체화면이 "되는 순간"(fullscreenchange)에 lock 을 건다(타이밍 경합 제거).
## 결과를 window._lockRes 에 남겨 실패 사유를 세로 안내 화면에서 읽을 수 있게 한다(진단).
const LOCK_JS: String = """
(function(){
	function tryLock(){
		if (!screen.orientation || !screen.orientation.lock) { window._lockRes = 'no-api'; return; }
		screen.orientation.lock('landscape').then(function(){ window._lockRes = 'ok'; })
			.catch(function(e){ window._lockRes = e.name + ': ' + e.message; });
	}
	if (document.fullscreenElement) { tryLock(); }
	else { document.addEventListener('fullscreenchange', function(){ if (document.fullscreenElement) { tryLock(); } }, {once: true}); }
})();
"""

var _hint: CanvasLayer
var _hint_sub: Label   ## 안내 보조 줄 — 잠금 실패 사유 진단 표시
var _web: bool = false
var _in_iframe: bool = false   ## itch 등 임베드 안인가 — 전체화면 소유권 판단(아래 참조)

func _ready() -> void:
	_web = OS.has_feature("web")
	if not ENABLED or not _web:
		set_process_input(false)
		return
	_in_iframe = bool(JavaScriptBridge.eval("window.self !== window.top", true))
	_build_hint()
	get_viewport().size_changed.connect(_refresh_hint)
	_refresh_hint()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and _web:
		_release_stuck_touches()

func _input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not tap:
		return
	# 창모드일 때만 전체화면으로 — 이미 전체화면이면 이 클릭은 게임 입력으로 흘려보낸다.
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
		_lock_landscape()  # 전체화면이 "되는 순간" 잠기도록 fullscreenchange 에 먼저 건다
		# itch 같은 iframe 임베드 + 터치 기기에선 전체화면을 호스트(래퍼)가 소유한다 — 폰 itch 는
		# 항상 자기가 전체화면으로 띄우고, 우리가 캔버스로 전체화면을 뺏으면 래퍼가 "나갔다"고
		# 오판해 오버레이를 덮을 수 있다(뒤로가기→Restore 후 터치 먹통 후보 ②, 2026-07-26).
		# 가로 잠금(_lock_landscape)은 누가 전체화면이든 fullscreenchange 에 걸리므로 계속 우리 몫.
		if not (_in_iframe and DisplayServer.is_touchscreen_available()):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			get_tree().create_timer(1.2).timeout.connect(_lock_landscape)  # 보험(이벤트가 씹힌 경우)
	elif _hint != null and _hint.visible:
		_lock_landscape()  # 전체화면인데 아직 세로 — 안내 탭에서 재시도

## 복귀 자기 치유 — 전체화면 이탈(안드로이드 뒤로가기 = 가장자리 스와이프 제스처)이 touchend 없이
## 끊기면 엔진에 "눌린 손가락"이 남고, 이후 모든 탭이 두 번째 손가락 취급이 된다(마우스 에뮬레이션은
## 0번 손가락만 따라감 → UI 전체 먹통. 폰 itch 뒤로가기→Restore 후 터치 사망 후보 ①, 2026-07-26).
## 포커스 복귀·화면 재배치 때 남은 손가락을 전부 뗀 것으로 주입한다(안 눌린 index 의 release 는 no-op).
func _release_stuck_touches() -> void:
	if not DisplayServer.is_touchscreen_available():
		return
	for i in range(10):
		var ev := InputEventScreenTouch.new()
		ev.index = i
		ev.pressed = false
		ev.position = Vector2(-1, -1)
		Input.parse_input_event(ev)

## 화면을 가로로 잠근다(양방향 가로) — 브라우저 orientation API 를 JS 로 직접 호출.
## DisplayServer.screen_set_orientation 은 웹에서 동작하지 않음(실기기 확인 2026-07-06, known_issues).
## 잠금이 불가능한 환경(iOS 사파리·데스크톱)에선 조용히 무시된다.
func _lock_landscape() -> void:
	if not _web:
		return
	JavaScriptBridge.eval(LOCK_JS, true)

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
	_hint_sub = UITheme.make_label("", UITheme.FS_TINY, Color(UITheme.MUTED.r, UITheme.MUTED.g, UITheme.MUTED.b, 0.7))
	_hint_sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(_hint_sub)

## 세로(높이 > 너비)면 안내를 보이고, 가로가 되면 숨긴다. 뷰포트 크기 변화마다 호출.
func _refresh_hint() -> void:
	if _hint == null:
		return
	_release_stuck_touches()  # 전체화면 이탈·복귀는 반드시 리사이즈를 동반 — 고착 터치 치유 2차 트리거
	var s: Vector2 = get_viewport().get_visible_rect().size
	_hint.visible = s.y > s.x
	if _hint.visible:
		_update_diag()
		get_tree().create_timer(2.0).timeout.connect(_update_diag)  # lock 결과가 늦게 도착하는 경우

## 가로 잠금 시도 결과(window._lockRes)를 안내에 작게 표시 — 실기기 진단용. 성공/미시도면 비움.
func _update_diag() -> void:
	if _hint_sub == null or not _web:
		return
	var res: String = str(JavaScriptBridge.eval("window._lockRes || ''", true))
	_hint_sub.text = "" if (res == "" or res == "ok") else "[ %s ]" % res
