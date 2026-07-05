extends CanvasLayer

## 원정 기록지 — 상시 책갈피 (모든 화면 위 autoload CanvasLayer).
## 시장이 기록지를 건넨 뒤(GameState.record_seen)에만 좌상단 아이콘이 뜬다. 탭하면 [조작 안내 다시보기] + [원정 일대기].
## DebugOverlay 와 같은 패턴 — 기존 씬(Main/Map/Expedition/Loadout)을 하나도 안 건드리고 위에 얹혀 GameState(공개 상태)를 읽는다.
## 씬 전환으로 일반 노드는 파괴돼도 autoload 는 살아남아 "상시"가 성립한다.

const ENABLED: bool = true

## 조작 안내 페이지 (정적). Phase B 하이라이트 오버레이가 이 콘텐츠를 공유할 예정.
const TUTORIAL_PAGES: Array = [
	"지도에서 갈 곳을 눌러 원정대를 움직입니다. 가봐야 무엇이 있는지 압니다. 걸음마다 물과 식량이 닳습니다.",
	"도착하면 그곳의 단면이 펼쳐집니다. 표시된 곳을 눌러 살핍니다. 조사 횟수는 정해져 있고, 조사에는 자원이 들지 않습니다.",
	"물은 걸음마다, 식량은 두 걸음마다 줄어듭니다. 로프는 갈라진 틈을, 은신막은 폭풍을 견디게 합니다.",
	"죽기 전 단 한 번, 물건 하나를 남길 수 있습니다. 그만큼 잃지만 다음 원정대가 줍습니다. 무엇을 남길지가 이 여정의 마음입니다.",
]

var _icon_btn: Button
var _panel: Control
var _scroll: ScrollContainer
var _content: VBoxContainer
var _tut_idx: int = 0

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

## 기록지를 받은 뒤에만 아이콘을 보인다. 패널이 열려 있으면 숨겨 겹침을 막는다.
func _refresh_icon() -> void:
	if _icon_btn != null:
		_icon_btn.visible = GameState.record_seen and not _panel.visible

# --- UI 구성 ---

## 책갈피 버튼 — 각인형 텍스트 + 모래색 책갈피 클립(핸드오프 타이틀 스펙: 알약 상자 대신 각인).
## 클립(8×20, 아래 V홈)은 오목 다각형이라 Polygon2D(자체 삼각화)로. 글자는 자간 .22em + 그림자.
func _make_bookmark_btn() -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.custom_minimum_size = Vector2(96, 48)  # 터치 타깃 확보(글자보다 넉넉히)
	var emp := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(st, emp)
	var clip := Polygon2D.new()
	clip.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(8, 0), Vector2(8, 20), Vector2(4, 16.4), Vector2(0, 20),
	])
	clip.color = UITheme.SAND
	clip.position = Vector2(16.0, 14.0)
	btn.add_child(clip)
	var lbl := Label.new()
	lbl.text = "기록"
	lbl.add_theme_font_size_override("font_size", 16)
	var fv := FontVariation.new()
	var base: Font = btn.get_theme_default_font()
	if base != null:
		fv.base_font = base
	fv.set_spacing(TextServer.SPACING_GLYPH, 4)  # 스펙 .22em ≈ 16*0.22
	lbl.add_theme_font_override("font", fv)
	lbl.add_theme_color_override("font_color", Color(UITheme.FG.r, UITheme.FG.g, UITheme.FG.b, 0.75))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.add_theme_constant_override("shadow_outline_size", 4)
	lbl.position = Vector2(34.0, 12.0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl)
	return btn

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_icon_btn = _make_bookmark_btn()
	_icon_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_icon_btn.offset_left = UITheme.PAD
	_icon_btn.offset_top = UITheme.SAFE
	_icon_btn.pressed.connect(_open)
	root.add_child(_icon_btn)

	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_panel)

	var scrim := ColorRect.new()
	scrim.color = UITheme.SCRIM
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(_on_scrim_input)
	_panel.add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)

	var card := UITheme.make_card()
	center.add_child(card)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(UITheme.COLUMN_W, 0)
	card.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", UITheme.GAP)
	_content.custom_minimum_size = Vector2(UITheme.COLUMN_W - 8, 0)
	_scroll.add_child(_content)

# --- 열기/닫기 ---

func _open() -> void:
	_panel.visible = true
	# 스크롤 높이를 화면의 60%로 제한(내용이 길면 스크롤, 짧으면 그만큼만).
	var vh: float = get_viewport().get_visible_rect().size.y
	if _scroll != null:
		_scroll.custom_minimum_size.y = maxf(200.0, vh * 0.6)
	_show_menu()

func _close() -> void:
	_panel.visible = false

func _on_scrim_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if tap:
		_close()

# --- 화면들 (_content 를 갈아끼운다) ---

func _show_menu() -> void:
	_clear()
	_content.add_child(UITheme.make_label("원정 기록지", UITheme.FS_H1, UITheme.SAND))
	_content.add_child(UITheme.make_label("떠난 원정대의 이야기가 여기 적힌다.", UITheme.FS_SMALL, UITheme.MUTED))
	var tut := UITheme.make_button("조작 안내 다시보기", false)
	tut.pressed.connect(_show_tutorial)
	_content.add_child(tut)
	var chr := UITheme.make_button("원정 일대기", false)
	chr.pressed.connect(_show_chronicle)
	_content.add_child(chr)
	var settings := UITheme.make_button("설정", false)
	settings.pressed.connect(_open_settings)
	_content.add_child(settings)
	var close := UITheme.make_button("닫기", false)
	close.pressed.connect(_close)
	_content.add_child(close)

## 게임 내 어디서든(기록 버튼은 상시 autoload) 설정 오버레이를 연다. 현재 씬 위에 얹는다.
func _open_settings() -> void:
	_close()
	var scn: Node = get_tree().current_scene
	if scn != null:
		scn.add_child(load("res://scripts/ui/SettingsPanel.gd").new())

func _show_tutorial() -> void:
	_tut_idx = 0
	_render_tutorial()

func _render_tutorial() -> void:
	_clear()
	_content.add_child(UITheme.make_label("조작 안내  (%d/%d)" % [_tut_idx + 1, TUTORIAL_PAGES.size()], UITheme.FS_SMALL, UITheme.SAND))
	_content.add_child(UITheme.make_label(str(TUTORIAL_PAGES[_tut_idx]), UITheme.FS_BODY))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	if _tut_idx > 0:
		var back := UITheme.make_button("뒤로", false)
		back.pressed.connect(_tut_back)
		row.add_child(back)
	if _tut_idx < TUTORIAL_PAGES.size() - 1:
		var nxt := UITheme.make_button("다음", false)
		nxt.pressed.connect(_tut_next)
		row.add_child(nxt)
	else:
		var done := UITheme.make_button("메뉴로", false)
		done.pressed.connect(_show_menu)
		row.add_child(done)
	_content.add_child(row)

func _tut_back() -> void:
	_tut_idx = maxi(0, _tut_idx - 1)
	_render_tutorial()

func _tut_next() -> void:
	_tut_idx = mini(TUTORIAL_PAGES.size() - 1, _tut_idx + 1)
	_render_tutorial()

func _show_chronicle() -> void:
	_clear()
	_content.add_child(UITheme.make_label("원정 일대기", UITheme.FS_H1, UITheme.SAND))
	var n: int = GameState.expedition_count
	if n <= 0:
		_content.add_child(UITheme.make_label("아직 떠난 원정이 없다.", UITheme.FS_BODY, UITheme.MUTED))
	else:
		for exp in range(1, n + 1):
			_content.add_child(_chronicle_line(exp))
	var back := UITheme.make_button("메뉴로", false)
	back.pressed.connect(_show_menu)
	_content.add_child(back)

## 한 원정의 요약 줄 — 결말은 셋 중 하나: 끝에 닿음(arrivals) / 스러짐(deaths) / 아직 길 위(현재 원정).
## 도달·재회는 arrivals(GameState.mark_arrival), 죽음은 deaths + BODY 흔적으로 재구성한다.
func _chronicle_line(exp: int) -> Label:
	var nm: String = GameState.expedition_name(exp)
	# ① 끝에 닿은 원정 — 재회(따뜻) 또는 도달(순환).
	var arrival: Dictionary = _arrival_of(exp)
	if not arrival.is_empty():
		if str(arrival.get("ending", "")) == "reunion":
			return UITheme.make_label(
				"%d번째 원정 · %s\n    건너편에서 모두와 다시 만났다." % [exp, nm],
				UITheme.FS_LABEL, UITheme.SAND, false)
		return UITheme.make_label(
			"%d번째 원정 · %s\n    끝에 닿았다. 다음 원정대가 이곳으로 온다." % [exp, nm],
			UITheme.FS_LABEL, UITheme.FG, false)
	# ② 스러진 원정 — 장소·거리·사인.
	var death: Dictionary = _death_of(exp)
	if not death.is_empty():
		var node_id: String = str(death.get("node_id", ""))
		var place: String = str(MapGraph.node(node_id).get("name", ""))
		if place == "":
			place = "이름 모를 곳"
		var leg: int = int(death.get("leg", 0))
		return UITheme.make_label(
			"%d번째 원정 · %s\n    %s에서 %d걸음째 스러졌다.%s" % [exp, nm, place, leg, _cause_text(node_id)],
			UITheme.FS_LABEL, UITheme.FG, false)
	# ③ 아직 길 위 — 지금 진행 중인 원정(살아 있음). 그 외(옛 세이브 등)는 지워진 기록.
	if exp == GameState.expedition_count and GameState.current_run != null and GameState.current_run.alive:
		return UITheme.make_label(
			"%d번째 원정 · %s\n    아직 길 위에 있다." % [exp, nm],
			UITheme.FS_LABEL, UITheme.MUTED, false)
	return UITheme.make_label(
		"%d번째 원정 · %s\n    기록이 모래에 지워졌다." % [exp, nm],
		UITheme.FS_LABEL, UITheme.MUTED, false)

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
