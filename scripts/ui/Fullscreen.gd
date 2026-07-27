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

## 엔진 JS 입력 층 강제 청소 — 캔버스에 touchcancel/pointercancel 을 합성 dispatch 해 브라우저 쪽
## 리스너에 남았을 활성 터치 추적을 끊는다. GDScript 로 주입한 release 는 엔진 내부 Input 까지만
## 닿고 이 층을 못 닦는다는 것이 0.3.4 프로브로 확인됨(죽은 상태의 모든 터치가 ScreenDrag 로 도착).
const TOUCH_CANCEL_JS: String = """
(function(){
	var c = document.getElementById('canvas') || document.querySelector('canvas');
	if (!c) { return; }
	try {
		var ts = [];
		for (var i = 0; i < 10; i++) {
			ts.push(new Touch({identifier: i, target: c, clientX: 0, clientY: 0}));
		}
		c.dispatchEvent(new TouchEvent('touchcancel', {changedTouches: ts, touches: [], bubbles: true}));
	} catch (e) {}
	try { c.dispatchEvent(new PointerEvent('pointercancel', {bubbles: true})); } catch (e) {}
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
	# 일지(트리 일시정지) 중에도 전체화면 재진입·복귀 치유·진단이 살아 있어야 한다 —
	# INHERIT 이면 일지가 열린 채 전체화면을 나갔다 오는 경로에서 이 노드가 통째로 잠든다(2026-07-26).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_in_iframe = bool(JavaScriptBridge.eval("window.self !== window.top", true))
	_build_hint()
	_build_probe()
	get_viewport().size_changed.connect(_refresh_hint)
	_refresh_hint()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and _web:
		_release_stuck_touches()
		_probe_wake()

func _input(event: InputEvent) -> void:
	# 진단 프로브 — Node._input 은 GUI 보다 먼저 받으므로, 여기 기록이 갱신되면 입력이 엔진까지는 온 것.
	if _probe != null and _probe.visible:
		var desc: String = event.get_class().trim_prefix("InputEvent")
		var st := event as InputEventScreenTouch
		if st != null:
			desc += "#%d %s(%d,%d)" % [st.index, "dn" if st.pressed else ("cx" if st.canceled else "up"),
				int(st.position.x), int(st.position.y)]
		var dr := event as InputEventScreenDrag
		if dr != null:
			desc += "#%d(%d,%d)" % [dr.index, int(dr.position.x), int(dr.position.y)]
		_last_ev = desc
		_last_ev_ms = Time.get_ticks_msec()
	_track_ghost(event)
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

# --- 유령 드래그 재합성 (0.3.5) ---
# 0.3.4 프로브 판독: 죽은 상태의 모든 터치가 ScreenDrag 로만 도착 = touchstart 를 위(itch 래퍼
# 오버레이 추정)에서 먹혀, 눌림 없는 이동만 엔진에 들어온다. 눌림이 확인 안 된 손가락의 드래그가
# 오면 그 자리에 dn 을 합성해 스트림을 살리고, 드래그가 GHOST_GAP_MS 동안 끊기면 마지막 위치에
# up 을 합성해 탭·드래그를 완성한다. 정상 스트림(dn 이 먼저 온 손가락)에는 개입하지 않는다.

const GHOST_GAP_MS: int = 180
var _touch_down: Dictionary = {}   ## index → true, dn 이 실제로 확인된 손가락
var _ghost: Dictionary = {}        ## index → {pos, ms}, 재합성으로 살린 유령 손가락
var _ghost_count: int = 0          ## 재합성 발동 횟수(프로브 표시용)
var _ghost_test: bool = false      ## 데스크톱 검증 드라이버용 — touchscreen 가드 우회

## 재주입 좌표 보정 — Input.parse_input_event 는 이벤트를 "창 좌표"로 받아 스트레치 변환을 다시
## 적용한다. _input 에서 본 좌표(뷰포트 로컬)를 그대로 주입하면 이중 변환으로 축소·이동된다.
## 폰(창 2340x1080·뷰포트 1509x720)에서 합성 뗌이 전부 좌상단행 → 누름과 뗌 위치가 갈려
## 모든 탭이 무반응이 되던 원인(0.3.7 까지의 자가 치유가 폰에서 헛발이던 이유, gh:40 판독 2026-07-27).
## 데스크톱 검증은 창=뷰포트 1:1 이라 잡지 못했다. 주입 전에 창 좌표로 되돌려 준다.
func _to_window(pos: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * pos

## 매 _input 마다 손가락 눌림 상태를 추적하고, 눌림 없는 드래그(유령)를 재합성으로 살린다.
func _track_ghost(event: InputEvent) -> void:
	if not (DisplayServer.is_touchscreen_available() or _ghost_test):
		return
	var st := event as InputEventScreenTouch
	if st != null:
		if st.pressed:
			_touch_down[st.index] = true
		else:
			# 유령 뗌(0.3.6) — 움직임 없는 깨끗한 탭은 드래그조차 없이 뗌만 온다(0.3.5 폰 프로브:
			# 대기 중 마지막 ev 가 up). 누름 없는 뗌이 GUI 에 닿으면 release 기준 핸들러(챕터 탭 등)를
			# 오발시킨다(복귀 후 첫 터치 = 설정 차례로 넘김). 삼키고 그 자리에 dn+up 짝을 합성한다.
			# 치유 주입분(위치 -1,-1)과 취소 터치(canceled — 뒤로가기 제스처를 시스템이 가로챈 것)는
			# 제외: 취소를 탭으로 되살리면 뒤로가기 스와이프가 매번 가짜 탭이 된다(0.3.7).
			if not _touch_down.has(st.index) and st.position.x >= 0.0 and not st.canceled:
				get_viewport().set_input_as_handled()
				_ghost_count += 1
				var pdn := InputEventScreenTouch.new()
				pdn.index = st.index
				pdn.pressed = true
				pdn.position = _to_window(st.position)
				Input.parse_input_event(pdn)
				var pup := InputEventScreenTouch.new()
				pup.index = st.index
				pup.pressed = false
				pup.position = _to_window(st.position)
				Input.parse_input_event(pup)
				return
			_touch_down.erase(st.index)
			_ghost.erase(st.index)  # 진짜 up 이 오면 재합성 마감 불필요(자연 release 완료)
		return
	var dr := event as InputEventScreenDrag
	if dr == null:
		return
	if _ghost.has(dr.index):
		var g: Dictionary = _ghost[dr.index]
		g["pos"] = dr.position
		g["ms"] = Time.get_ticks_msec()
	elif not _touch_down.has(dr.index):
		_touch_down[dr.index] = true
		_ghost[dr.index] = {"pos": dr.position, "ms": Time.get_ticks_msec()}
		_ghost_count += 1
		var dn := InputEventScreenTouch.new()
		dn.index = dr.index
		dn.pressed = true
		dn.position = _to_window(dr.position)
		Input.parse_input_event(dn)

## 유령 손가락 마감 — 드래그가 GHOST_GAP_MS 동안 끊기면 마지막 위치에서 뗀 것으로 합성(탭 완성).
func _sweep_ghosts() -> void:
	if _ghost.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	for idx: int in _ghost.keys():
		var g: Dictionary = _ghost[idx]
		if now - int(g["ms"]) >= GHOST_GAP_MS:
			_ghost.erase(idx)
			var up := InputEventScreenTouch.new()
			up.index = idx
			up.pressed = false
			up.position = _to_window(g["pos"])
			Input.parse_input_event(up)

## 복귀 자기 치유 — 전체화면 이탈(안드로이드 뒤로가기 = 가장자리 스와이프 제스처)이 touchend 없이
## 끊기면 엔진에 "눌린 손가락"이 남고, 이후 모든 탭이 두 번째 손가락 취급이 된다(마우스 에뮬레이션은
## 0번 손가락만 따라감 → UI 전체 먹통. 폰 itch 뒤로가기→Restore 후 터치 사망 후보 ①, 2026-07-26).
## 포커스 복귀·화면 재배치 때 남은 손가락을 전부 뗀 것으로 주입한다(안 눌린 index 의 release 는 no-op).
func _release_stuck_touches(clear_focus: bool = true) -> void:
	if not DisplayServer.is_touchscreen_available():
		return
	_heal_count += 1
	# 브라우저 입력 층부터 청소(TOUCH_CANCEL_JS 주석 참조) — 그 다음 엔진 내부 주입.
	if _web:
		JavaScriptBridge.eval(TOUCH_CANCEL_JS, true)
	_touch_down.clear()
	_ghost.clear()
	for i in range(10):
		var ev := InputEventScreenTouch.new()
		ev.index = i
		ev.pressed = false
		ev.position = Vector2(-1, -1)
		Input.parse_input_event(ev)
	# 에뮬레이션 마우스의 눌림/캡처도 해제 — 복귀 전 눌림이 GUI 캡처로 남으면 이후 모든 입력이
	# 그 컨트롤로만 흘러 화면이 통째로 무반응처럼 보인다.
	var mv := InputEventMouseButton.new()
	mv.button_index = MOUSE_BUTTON_LEFT
	mv.pressed = false
	mv.position = Vector2(-1, -1)
	Input.parse_input_event(mv)
	if clear_focus:
		get_viewport().gui_release_focus()  # 이름칸 등 잔류 포커스 해제(가상 키보드 재출현 방지 겸)
	# 일지(일시정지 오버레이)가 열려 있으면 새 컨트롤로 다시 짓는다 — "일지만 무반응" 방어.
	var bm: Node = get_node_or_null("/root/Bookmark")
	if bm != null and bool(bm.call("is_open")):
		bm.call("heal_after_restore")

# --- 복귀 진단 프로브 (임시, 베타 전용 — 원인 잡히면 제거) ---
# 폰 itch "복귀 후 일지 터치 먹통"(2026-07-26) 이분 진단: 포커스 복귀·리사이즈 후 20초 동안
# 좌상단에 상태 한 줄을 띄운다. 죽은 상태에서 탭할 때 ev 가 갱신되면 입력이 엔진까지 오는 것
# (= 게임 안 GUI 라우팅 문제), 안 갱신되면 밖(래퍼 오버레이)이 먹는 것(= itch 쪽).

var _probe: CanvasLayer
var _probe_lbl: Label
var _probe_until_ms: int = 0
var _last_ev: String = "-"
var _last_ev_ms: int = 0
var _heal_count: int = 0   ## 복귀 치유가 몇 번 돌았나(프로브 표시용)

func _build_probe() -> void:
	_probe = CanvasLayer.new()
	_probe.layer = 300
	_probe.visible = false
	add_child(_probe)
	_probe_lbl = Label.new()
	_probe_lbl.position = Vector2(6, 4)
	_probe_lbl.add_theme_font_size_override("font_size", 11)
	_probe_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 0.85))
	_probe_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_probe.add_child(_probe_lbl)

## 진단 창을 20초 연다 — 터치 기기에서만(데스크톱 알트탭마다 뜨지 않게).
func _probe_wake() -> void:
	if _probe == null or not DisplayServer.is_touchscreen_available():
		return
	_probe_until_ms = Time.get_ticks_msec() + 20000

var _fs_accum: float = 0.0
var _was_fs: bool = false

func _process(_delta: float) -> void:
	_sweep_ghosts()  # 유령 손가락 마감은 웹 여부와 무관하게 위에서(드라이버 검증 포함)
	if _probe == null:
		return  # 웹이 아니면 _build_probe 를 안 지났다 — 아래는 전부 웹 전용
	# itch 래퍼가 소유한 전체화면 전환은 엔진 쪽 포커스/리사이즈 알림이 안 올 수 있다(0.3.2 프로브가
	# 안 떴다는 제보) — JS 로 문서 전체화면 상태를 0.5초마다 직접 감시해 전환 순간 치유를 건다.
	_fs_accum += _delta
	if _fs_accum >= 0.5:
		_fs_accum = 0.0
		var fs: bool = bool(JavaScriptBridge.eval("!!document.fullscreenElement", true))
		if fs != _was_fs:
			_was_fs = fs
			_release_stuck_touches()
			_probe_wake()
	var now: int = Time.get_ticks_msec()
	var bm: Node = get_node_or_null("/root/Bookmark")
	var jopen: bool = bm != null and bool(bm.call("is_open"))
	# 일지가 열려 있는 동안엔 상시 표시(20초 만료 X) — 먹통이 20초 넘게 이어져 관찰을 놓치던 것 방지.
	_probe.visible = (jopen and DisplayServer.is_touchscreen_available()) or now < _probe_until_ms
	if not _probe.visible:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var bm_txt: String = str(bm.call("debug_state")) if bm != null and jopen else "-"
	_probe_lbl.text = "v%s p:%s vp:%dx%d h:%s heal:%d gh:%d tb:%s | %s | ev:%s +%.1fs" % [
		str(ProjectSettings.get_setting("application/config/version", "?")),
		"1" if get_tree().paused else "0", int(vp.x), int(vp.y),
		"1" if (_hint != null and _hint.visible) else "0", _heal_count, _ghost_count,
		"1" if Transition.busy() else "0",
		bm_txt, _last_ev, float(now - _last_ev_ms) / 1000.0]

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
	# 리사이즈는 가상 키보드가 뜰 때도 온다 — 여기서 포커스까지 지우면 이름칸 키보드가
	# 뜨자마자 닫힌다(0.3.10 폰 제보). 리사이즈 경로는 고착 터치 해제만, 포커스는 남긴다.
	_release_stuck_touches(false)
	_probe_wake()             # 복귀 진단 프로브도 같은 트리거로 연다
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
