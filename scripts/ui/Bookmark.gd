extends CanvasLayer

## 원정 일지 — 모든 화면 왼쪽 가장자리에 **빨간 책갈피 리본**이 삐져나와 있다(autoload CanvasLayer).
## 호버하면 리본이 좀 더 빠져나오고, 누르면 양피지 일지가 펼쳐진다. 일지의 챕터(일대기·조작·설정)는
## 책 오른쪽의 작은 책갈피들로 넘긴다 — 챕터 전환마다 책장이 넘어가는 연출(scale.x 접힘) + 종이 SFX.
## 시장이 기록지를 건넨 뒤(GameState.record_seen)에만 리본이 보인다.
## DebugOverlay 와 같은 패턴 — 기존 씬을 안 건드리고 위에 얹혀 GameState(공개 상태)를 읽는다.

const ENABLED: bool = true
const RED := UITheme.MARKER_INK      ## 책갈피 리본(붉은 세피아)
const INK := UITheme.INK
const INK_FADE := UITheme.INK_FADE
const PAPER := UITheme.PAPER
const PAPER_EDGE := UITheme.PAPER_EDGE
const PAGE_SFX: Array = [
	"res://assets/sfx/sfx_page_1.wav",
	"res://assets/sfx/sfx_page_2.wav",
	"res://assets/sfx/sfx_page_3.wav",
]

## 조작 안내 페이지 (정적).
const TUTORIAL_PAGES: Array = [
	"지도에서 갈 곳을 눌러 원정대를 움직입니다. 가봐야 무엇이 있는지 압니다. 걸음마다 물과 식량이 닳습니다.",
	"도착하면 그곳의 단면이 펼쳐집니다. 표시된 곳을 눌러 살핍니다. 조사 횟수는 정해져 있고, 조사에는 자원이 들지 않습니다.",
	"물은 걸음마다, 식량은 두 걸음마다 줄어듭니다. 로프는 갈라진 틈을, 은신막은 폭풍을 견디게 합니다.",
	"죽기 전 단 한 번, 물건 하나를 남길 수 있습니다. 그만큼 잃지만 다음 원정대가 줍습니다. 무엇을 남길지가 이 여정의 마음입니다.",
]

const CHAPTERS: Array = ["일대기", "조작", "설정"]

## 책갈피 리본 — 오른쪽 끝에 V 홈이 파인 빨간 리본. length 로 삐져나온 정도를 조절(호버 애니).
## V 홈은 오목 다각형이라 위/아래 두 볼록 조각으로 나눠 그린다.
class Ribbon extends Control:
	var length: float = 38.0:
		set(v):
			length = v
			queue_redraw()
	var text: String = ""
	var ribbon_h: float = 30.0
	var col: Color = UITheme.MARKER_INK
	func _draw() -> void:
		var h: float = ribbon_h
		var notch: float = minf(10.0, length * 0.3)
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, 0), Vector2(length, 0), Vector2(length - notch, h * 0.5), Vector2(0, h * 0.5)]), col)
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, h * 0.5), Vector2(length - notch, h * 0.5), Vector2(length, h), Vector2(0, h)]), col)
		draw_line(Vector2(0, h), Vector2(length - 2.0, h), Color(0.0, 0.0, 0.0, 0.35), 1.5, true)  # 아랫면 그림자(두께감)
		if text != "":
			var f: Font = get_theme_default_font()
			if f != null:
				draw_string(f, Vector2(9.0, h * 0.5 + 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, length - 16.0, 13, Color(0.96, 0.92, 0.86, 0.95))

## 일지 페이지 — 양피지 한 장(낡은 가장자리 + 왼쪽 스파인 어둠). 챕터 flip 의 스케일 대상.
class BookPage extends Control:
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, UITheme.PAPER)
		draw_rect(r, UITheme.PAPER_EDGE, false, 3.0)
		var inset: float = 7.0
		draw_rect(Rect2(r.position + Vector2(inset, inset), r.size - Vector2(inset, inset) * 2.0),
			Color(UITheme.PAPER_EDGE.r, UITheme.PAPER_EDGE.g, UITheme.PAPER_EDGE.b, 0.35), false, 1.5)
		# 왼쪽 스파인(책등) 어둠 — 접힌 책의 안쪽.
		for i in range(6):
			var a: float = 0.10 - float(i) * 0.016
			draw_line(Vector2(2.0 + float(i) * 2.0, 3.0), Vector2(2.0 + float(i) * 2.0, size.y - 3.0),
				Color(0.2, 0.13, 0.06, maxf(0.0, a)), 2.0)

var _ribbon: Ribbon
var _panel: Control
var _book: BookPage
var _scroll: ScrollContainer
var _content: VBoxContainer
var _tabs: Array = []          ## 챕터 책갈피(Ribbon) — 책 오른쪽에 얹힘
var _chapter: int = 0
var _tut_idx: int = 0
var _flipping: bool = false
var _rib_tw: Tween
var _opened_ms: int = 0        ## 일지를 연 시각 — 여는 클릭이 스크림 닫기로 새는 것 방지 가드

func _ready() -> void:
	if not ENABLED:
		return
	layer = 100  # 게임 UI 위, DEV 오버레이(128) 아래
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false
	_refresh_icon()

func _process(_delta: float) -> void:
	if ENABLED:
		_refresh_icon()

## 기록지를 받은 뒤에만 리본을 보인다. 일지가 열려 있거나 풀스크린 오버레이(설정 장부·엔딩)가 떠 있으면 숨김.
func _refresh_icon() -> void:
	if _ribbon != null:
		_ribbon.visible = GameState.record_seen and not _panel.visible \
			and get_tree().get_first_node_in_group("fullscreen_overlay") == null

# --- UI 구성 ---

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 왼쪽 가장자리 리본 — 일지에 끼워둔 빨간 책갈피가 화면 밖으로 삐져나온 모양.
	_ribbon = Ribbon.new()
	_ribbon.position = Vector2(0.0, 38.0)
	_ribbon.size = Vector2(96.0, 30.0)  # 히트 영역(그리기는 length 만큼)
	_ribbon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_ribbon.mouse_entered.connect(_ribbon_hover.bind(true))
	_ribbon.mouse_exited.connect(_ribbon_hover.bind(false))
	_ribbon.gui_input.connect(_on_ribbon_input)
	root.add_child(_ribbon)

	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_panel)

	var scrim := ColorRect.new()
	scrim.color = UITheme.SCRIM
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(_on_scrim_input)
	_panel.add_child(scrim)

	# 일지 본체 — 양피지 페이지. 챕터 flip 은 이 노드의 scale.x 로.
	_book = BookPage.new()
	_panel.add_child(_book)
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, 34)
	_book.add_child(mc)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mc.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", UITheme.GAP)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)

	# 챕터 책갈피 — 책 오른쪽 가장자리에서 삐져나온 작은 리본들(현재 챕터가 가장 김).
	for i in range(CHAPTERS.size()):
		var tab := Ribbon.new()
		tab.text = str(CHAPTERS[i])
		tab.ribbon_h = 28.0
		tab.col = RED if i == 0 else Color(RED.r, RED.g, RED.b, 0.62)
		tab.size = Vector2(96.0, 28.0)
		tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tab.gui_input.connect(_on_tab_input.bind(i))
		_book.add_child(tab)
		_tabs.append(tab)

## 리본 호버 — 좀 더 길게 삐져나온다(잡아당길 수 있다는 신호).
func _ribbon_hover(on: bool) -> void:
	if _rib_tw != null and _rib_tw.is_valid():
		_rib_tw.kill()
	_rib_tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_rib_tw.tween_property(_ribbon, "length", 72.0 if on else 38.0, 0.3)

func _on_ribbon_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		# 같은 클릭(또는 마우스가 만든 합성 터치)이 방금 열린 일지의 스크림까지 흘러가
		# 열리자마자 닫아버리던 버그 — 이벤트를 여기서 소비하고, 열기는 다음 프레임으로 미룬다.
		_ribbon.accept_event()
		call_deferred("_open")

func _on_tab_input(event: InputEvent, idx: int) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		var tab: Ribbon = _tabs[idx]
		tab.accept_event()
		_flip_to(idx)

# --- 열기/닫기/레이아웃 ---

func _open() -> void:
	_layout_book()
	_panel.visible = true
	UITheme.fade_in(_panel)
	_opened_ms = Time.get_ticks_msec()
	_chapter = 0
	_apply_tab_state()
	_render_chapter()

func _close() -> void:
	_panel.visible = false

func _on_scrim_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	# 연 직후 250ms 는 무시 — 여는 클릭의 잔여 이벤트(합성 터치 등)가 바로 닫는 것 방지.
	if tap and Time.get_ticks_msec() - _opened_ms > 250:
		_close()

## 일지 크기 — 화면 중앙, 여유 있게(가로 72%·세로 86% 상한). pivot 은 왼쪽 스파인(책이 접히는 축).
func _layout_book() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var w: float = minf(vp.x * 0.72, 880.0)
	var h: float = minf(vp.y * 0.86, 600.0)
	_book.size = Vector2(w, h)
	_book.position = (vp - Vector2(w, h)) * 0.5
	_book.pivot_offset = Vector2(0.0, h * 0.5)
	for i in range(_tabs.size()):
		var tab: Ribbon = _tabs[i]
		tab.position = Vector2(w - 4.0, 36.0 + float(i) * 44.0)

# --- 챕터 (책장 넘김) ---

## 챕터 책갈피를 누름 — 책장이 넘어가듯 접혔다 펴지며 내용이 바뀐다. 설정 챕터는 원정 장부(SettingsPanel)로.
func _flip_to(idx: int) -> void:
	if _flipping or idx == _chapter:
		return
	_flipping = true
	AudioManager.play_sfx_random(PAGE_SFX)
	var tw := create_tween()
	tw.tween_property(_book, "scale:x", 0.04, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_chapter = idx
		_apply_tab_state()
		_render_chapter())
	tw.tween_property(_book, "scale:x", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _flipping = false)

## 현재 챕터 책갈피는 진하고 길게, 나머지는 옅고 짧게.
func _apply_tab_state() -> void:
	for i in range(_tabs.size()):
		var tab: Ribbon = _tabs[i]
		tab.col = RED if i == _chapter else Color(RED.r, RED.g, RED.b, 0.62)
		tab.length = 78.0 if i == _chapter else 58.0

func _render_chapter() -> void:
	match _chapter:
		0:
			_show_chronicle()
		1:
			_render_tutorial()
		2:
			# 설정 = 원정 장부(SettingsPanel, 같은 양피지 장부 컨셉) — 일지를 덮고 장부를 편다.
			_close()
			var scn: Node = get_tree().current_scene
			if scn != null:
				scn.add_child(load("res://scripts/ui/SettingsPanel.gd").new())

# --- 챕터 내용 (양피지 위 잉크 톤) ---

func _show_chronicle() -> void:
	_clear()
	_content.add_child(_ink_label("원정 일대기", UITheme.FS_H1, RED))
	var n: int = GameState.expedition_count
	if n <= 0:
		_content.add_child(_ink_label("아직 떠난 원정이 없다.", UITheme.FS_BODY, INK_FADE))
	else:
		for exp in range(1, n + 1):
			_content.add_child(_chronicle_line(exp))
	_content.add_child(_ink_btn("일지를 덮는다", _close))

func _render_tutorial() -> void:
	_clear()
	_content.add_child(_ink_label("조작 안내  (%d/%d)" % [_tut_idx + 1, TUTORIAL_PAGES.size()], UITheme.FS_SMALL, RED))
	_content.add_child(_ink_label(str(TUTORIAL_PAGES[_tut_idx]), UITheme.FS_BODY, INK))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if _tut_idx > 0:
		row.add_child(_ink_btn("← 앞장", _tut_back))
	if _tut_idx < TUTORIAL_PAGES.size() - 1:
		row.add_child(_ink_btn("다음 장 →", _tut_next))
	_content.add_child(row)
	_content.add_child(_ink_btn("일지를 덮는다", _close))

func _tut_back() -> void:
	_tut_idx = maxi(0, _tut_idx - 1)
	AudioManager.play_sfx_random(PAGE_SFX)
	_render_tutorial()

func _tut_next() -> void:
	_tut_idx = mini(TUTORIAL_PAGES.size() - 1, _tut_idx + 1)
	AudioManager.play_sfx_random(PAGE_SFX)
	_render_tutorial()

## 양피지 위 잉크 라벨.
func _ink_label(txt: String, fs: int, col: Color, center: bool = false) -> Label:
	var l := UITheme.make_label(txt, fs, col, center)
	return l

## 잉크 각인 버튼 — 상자 없이 글자만, hover 시 붉은 잉크.
func _ink_btn(txt: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.flat = false
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", UITheme.FS_LABEL)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", RED)
	b.add_theme_color_override("font_pressed_color", RED)
	var emp := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, emp)
	b.pressed.connect(cb)
	return b

## 한 원정의 요약 줄 — 결말은 셋 중 하나: 끝에 닿음(arrivals) / 스러짐(deaths) / 아직 길 위(현재 원정).
## 도달·재회는 arrivals(GameState.mark_arrival), 죽음은 deaths + BODY 흔적으로 재구성한다.
func _chronicle_line(exp: int) -> Label:
	var nm: String = GameState.expedition_name(exp)
	# ① 끝에 닿은 원정 — 재회(붉은 잉크) 또는 도달.
	var arrival: Dictionary = _arrival_of(exp)
	if not arrival.is_empty():
		if str(arrival.get("ending", "")) == "reunion":
			return _ink_label(
				"%d번째 원정 · %s\n    건너편에서 모두와 다시 만났다." % [exp, nm],
				UITheme.FS_LABEL, RED)
		return _ink_label(
			"%d번째 원정 · %s\n    끝에 닿았다. 다음 원정대가 이곳으로 온다." % [exp, nm],
			UITheme.FS_LABEL, INK)
	# ② 스러진 원정 — 장소·거리·사인.
	var death: Dictionary = _death_of(exp)
	if not death.is_empty():
		var node_id: String = str(death.get("node_id", ""))
		var place: String = str(MapGraph.node(node_id).get("name", ""))
		if place == "":
			place = "이름 모를 곳"
		var leg: int = int(death.get("leg", 0))
		return _ink_label(
			"%d번째 원정 · %s\n    %s에서 %d걸음째 스러졌다.%s" % [exp, nm, place, leg, _cause_text(node_id)],
			UITheme.FS_LABEL, INK)
	# ③ 아직 길 위 — 지금 진행 중인 원정(살아 있음). 그 외(옛 세이브 등)는 지워진 기록.
	if exp == GameState.expedition_count and GameState.current_run != null and GameState.current_run.alive:
		return _ink_label(
			"%d번째 원정 · %s\n    아직 길 위에 있다." % [exp, nm],
			UITheme.FS_LABEL, INK_FADE)
	return _ink_label(
		"%d번째 원정 · %s\n    기록이 모래에 지워졌다." % [exp, nm],
		UITheme.FS_LABEL, INK_FADE)

func _arrival_of(exp: int) -> Dictionary:
	for a in GameState.arrivals:
		if a is Dictionary and int(a.get("expedition", -1)) == exp:
			return a
	return {}

func _death_of(exp: int) -> Dictionary:
	for d in GameState.deaths:
		if d is Dictionary and int(d.get("expedition", -1)) == exp:
			return d
	return {}

## 사인 보강 — 그 노드의 BODY 흔적 태그에서 근사(정확한 원정별 매칭은 불가, 태그가 사인 단서).
func _cause_text(node_id: String) -> String:
	for raw in GameState.traces:
		if not (raw is Dictionary):
			continue
		if int(raw.get("object_kind", -1)) != TraceData.ObjectKind.BODY:
			continue
		if str(raw.get("node_id", "")) != node_id:
			continue
		var tg: Array = raw.get("tags", [])
		if tg.has("갈증"):
			return " 갈증이었다."
		if tg.has("없다"):
			return " 식량이 없었다."
		return ""
	return ""

func _clear() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
