class_name InventoryOverlay
extends Control

## 인벤토리 오버레이 (핸드오프 MAP_지도화면.md §9) — "지금 지닌 것"을 아이템 사진 카드로 본다.
## 지도 좌 칼럼 하단 "가방 열기 →"로 연다. 자원 4칸(물·식량·로프·은신막) + 주머니 3칸(약초·부싯돌·정화천).
## 카드에 마우스를 올리면(터치는 탭) 아래에 그 물건의 쓰임이 적힌다. 스크림 탭 또는 "덮는다"로 닫는다.

const EN_TITLE_FONT := preload("res://assets/fonts/Cinzel.ttf")
const NAME_COL := Color(0.910, 0.875, 0.804)    ## 이름(#e8dfcd — 스펙)
const RES_KEYS: Array = ["water", "food", "rope", "shelter"]

var _run: ExpeditionRun
var _panel: PanelContainer
var _desc: Label
var _cards: Dictionary = {}   ## key -> {"btn": Button, "count": Label}

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	var scrim := ColorRect.new()
	scrim.color = Color(0.024, 0.020, 0.039, 0.72)  # 스펙 rgba(6,5,10,.72). blur 는 웹 불가 — 생략
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 빈 영역 클릭은 스크림(닫기)으로
	add_child(center)

	# 패널 — 가죽 면 + 가죽 테두리(#7a5a30), 폭 640(스펙).
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.157, 0.118, 0.078)        # leather 중간톤(#2b2016~#1e1610 사이)
	sb.border_color = Color(0.478, 0.353, 0.188)    # #7a5a30
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(22)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_panel.add_child(col)

	var title := UITheme.make_label("지닌 것", UITheme.FS_LABEL, UITheme.SAND)
	col.add_child(title)
	col.add_child(UITheme.make_hairline(Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.25), 1.0))

	# 자원 4칸(4열 그리드 — 스펙).
	var res_grid := GridContainer.new()
	res_grid.columns = 4
	res_grid.add_theme_constant_override("h_separation", 8)
	res_grid.add_theme_constant_override("v_separation", 8)
	col.add_child(res_grid)
	for k in RES_KEYS:
		res_grid.add_child(_make_card(str(k)))

	# 주머니 3칸(3열 그리드 — 스펙).
	var pl := UITheme.make_label("주머니", UITheme.FS_SMALL, UITheme.MUTED, false)
	col.add_child(pl)
	var pouch_grid := GridContainer.new()
	pouch_grid.columns = 3
	pouch_grid.add_theme_constant_override("h_separation", 8)
	pouch_grid.add_theme_constant_override("v_separation", 8)
	col.add_child(pouch_grid)
	for k in Items.POUCH_TOOLS:
		pouch_grid.add_child(_make_card(str(k)))

	# 하단 툴팁(.idesc — 스펙): 카드에 올린 물건의 쓰임.
	col.add_child(UITheme.make_hairline(Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.18), 1.0))
	_desc = UITheme.make_label("물건에 손을 올리면 쓰임이 적힌다.", UITheme.FS_SMALL, UITheme.MUTED)
	_desc.custom_minimum_size = Vector2(0, 44)
	col.add_child(_desc)

	var close := Button.new()
	close.text = "덮는다"
	close.flat = false
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(0, 42)
	close.add_theme_font_size_override("font_size", UITheme.FS_LABEL)
	close.add_theme_color_override("font_color", Color(UITheme.FG.r, UITheme.FG.g, UITheme.FG.b, 0.85))
	close.add_theme_color_override("font_hover_color", UITheme.SAND)
	var emp := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		close.add_theme_stylebox_override(st, emp)
	close.pressed.connect(_close)
	col.add_child(close)

func is_open() -> bool:
	return visible

## 연다 — 수량을 채우고 스펙 ovin(scale .96→1 + fade, .35s)으로 등장.
func open(run: ExpeditionRun) -> void:
	_run = run
	_refresh()
	visible = true
	AudioManager.play_sfx("res://assets/sfx/sfx_card_open.wav")
	modulate.a = 0.0
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.96, 0.96)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.35)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.35)

func _close() -> void:
	AudioManager.play_sfx("res://assets/sfx/sfx_card_close.wav")
	UITheme.fade_out(self)

func _on_scrim_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if tap:
		_close()

## 카드 — 아이템 사진(64) + 이름(15 #e8dfcd) + 수치(Cinzel 15 sand). hover/탭 → 하단 설명.
func _make_card(key: String) -> Control:
	var btn := Button.new()
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 118)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var emp := StyleBoxEmpty.new()
	for st in ["normal", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(st, emp)
	btn.add_theme_stylebox_override("hover", UITheme.sun_glow_stylebox(0.16))
	btn.mouse_entered.connect(_show_desc.bind(key))
	btn.pressed.connect(_show_desc.bind(key))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	var icon := ItemIcon.new()
	icon.key = key
	icon.custom_minimum_size = Vector2(0, 64)
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(icon)
	var nm := UITheme.make_label(Items.label_of(key), 15, NAME_COL)
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(nm)
	var cnt := UITheme.make_label("0", 15, UITheme.SAND)
	cnt.autowrap_mode = TextServer.AUTOWRAP_OFF
	var cfv := FontVariation.new()
	cfv.base_font = EN_TITLE_FONT  # 수치 = Cinzel(스펙 — 숫자 전용이라 두부 없음)
	cnt.add_theme_font_override("font", cfv)
	v.add_child(cnt)
	btn.add_child(v)
	_cards[key] = {"btn": btn, "count": cnt}
	return btn

## 수량 갱신 — 0개인 주머니 도구는 흐리게(없는 물건).
func _refresh() -> void:
	if _run == null:
		return
	for key in _cards:
		var info: Dictionary = _cards[key]
		var n: int = _run.get_res(str(key))
		var cnt: Label = info["count"]
		cnt.text = str(n)
		var btn: Button = info["btn"]
		btn.modulate.a = 1.0 if n > 0 else 0.4

func _show_desc(key: String) -> void:
	var item: Dictionary = Items.by_key(key)
	_desc.text = "%s — %s" % [str(item.get("label", key)), str(item.get("desc", ""))]
	_desc.add_theme_color_override("font_color", NAME_COL)
