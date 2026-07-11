class_name InventoryOverlay
extends Control

## 인벤토리 오버레이 (핸드오프 §9 + 각인 미학) — "지금 지닌 것"을 아이템 사진으로 본다.
## 상자·패널 없이: 어두운 스크림 위에 각인 제목 + 헤어라인 + 사진·이름·수치. 남기기 화면과 같은 문법.
## 지도 좌 칼럼 하단 "가방 열기 →"로 연다. 카드를 누르면(올리면) 아래에 설명이 나온다.

const EN_TITLE_FONT := preload("res://assets/fonts/Cinzel.ttf")
const NAME_COL := Color(0.910, 0.875, 0.804)    ## 이름(#e8dfcd — 스펙)
const RES_KEYS: Array = ["water", "food", "rope", "shelter"]

var _run: ExpeditionRun
var _content: VBoxContainer
var _desc: Label
var _cards: Dictionary = {}   ## key -> {"btn": Button, "count": Label}

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 어두운 스크림 — 지도가 은은히 비치는 어둠. 탭하면 덮는다.
	var scrim := ColorRect.new()
	scrim.color = Color(0.024, 0.020, 0.039, 0.86)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 빈 영역 클릭은 스크림(닫기)으로
	add_child(center)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 14)
	center.add_child(_content)

	var title := UITheme.make_label("지닌 것", UITheme.FS_H1, UITheme.FG)
	_shadow(title)
	_content.add_child(title)
	_content.add_child(_hairline())

	# 자원 4칸 — 가로 한 줄(상자 없이 사진·글만).
	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 18)
	res_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(res_row)
	for k in RES_KEYS:
		res_row.add_child(_make_card(str(k)))

	# 주머니 3칸.
	var pl := UITheme.make_label("주머니", UITheme.FS_SMALL, UITheme.MUTED)
	_shadow(pl)
	_content.add_child(pl)
	var pouch_row := HBoxContainer.new()
	pouch_row.add_theme_constant_override("separation", 18)
	pouch_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pouch_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(pouch_row)
	for k in Items.POUCH_TOOLS:
		pouch_row.add_child(_make_card(str(k)))

	_content.add_child(_hairline())
	_desc = UITheme.make_label("물건을 누르면 설명이 나온다.", UITheme.FS_SMALL, UITheme.MUTED)
	_shadow(_desc)
	_desc.custom_minimum_size = Vector2(0, 44)
	_content.add_child(_desc)

	var close := EngravedItem.new()
	close.init_item("덮는다", 18, false)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_close)
	_content.add_child(close)

func is_open() -> bool:
	return visible

## 연다 — 수량을 채우고 스펙 ovin(scale .96→1 + fade, .35s)으로 등장.
func open(run: ExpeditionRun) -> void:
	_run = run
	_refresh()
	visible = true
	AudioManager.play_sfx("res://assets/sfx/sfx_card_open.wav")
	modulate.a = 0.0
	_content.pivot_offset = _content.size * 0.5
	_content.scale = Vector2(0.96, 0.96)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.35)
	tw.tween_property(_content, "scale", Vector2.ONE, 0.35)

func _close() -> void:
	AudioManager.play_sfx("res://assets/sfx/sfx_card_close.wav")
	UITheme.fade_out(self)

func _on_scrim_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if tap:
		_close()

## 카드 — 사진(88) + 이름(15 #e8dfcd) + 수치(Cinzel 17 sand). 상자 없음, hover = 햇빛 웅덩이.
func _make_card(key: String) -> Control:
	var btn := Button.new()
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(126, 148)
	var emp := StyleBoxEmpty.new()
	for st in ["normal", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(st, emp)
	btn.add_theme_stylebox_override("hover", UITheme.sun_glow_stylebox(0.18))
	btn.mouse_entered.connect(_show_desc.bind(key))
	btn.pressed.connect(_show_desc.bind(key))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	var icon := ItemIcon.new()
	icon.key = key
	icon.custom_minimum_size = Vector2(0, 88)
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(icon)
	var nm := UITheme.make_label(Items.label_of(key), 15, NAME_COL)
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	_shadow(nm)
	v.add_child(nm)
	var cnt := UITheme.make_label("0", 17, UITheme.SAND)
	cnt.autowrap_mode = TextServer.AUTOWRAP_OFF
	var cfv := FontVariation.new()
	cfv.base_font = EN_TITLE_FONT  # 수치 = Cinzel(숫자 전용 — 한글 두부 없음)
	cnt.add_theme_font_override("font", cfv)
	_shadow(cnt)
	v.add_child(cnt)
	btn.add_child(v)
	_cards[key] = {"btn": btn, "count": cnt}
	return btn

## 수량 갱신 — 없는 주머니 도구는 흐리게.
func _refresh() -> void:
	if _run == null:
		return
	for key in _cards:
		var info: Dictionary = _cards[key]
		var n: int = _run.get_res(str(key))
		var cnt: Label = info["count"]
		cnt.text = str(n)
		var btn: Button = info["btn"]
		btn.modulate.a = 1.0 if n > 0 else 0.38

func _show_desc(key: String) -> void:
	var item: Dictionary = Items.by_key(key)
	_desc.text = "%s — %s" % [str(item.get("label", key)), str(item.get("desc", ""))]
	_desc.add_theme_color_override("font_color", NAME_COL)

## 헤어라인 — 가운데가 밝은 1px 모래선.
func _hairline() -> Control:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([
		Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.0),
		Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.45),
		Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.0),
	])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.0, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.custom_minimum_size = Vector2(400, 1)
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

## 어두운 배경 위 글씨 그림자.
func _shadow(lbl: Label) -> void:
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.add_theme_constant_override("shadow_outline_size", 4)
