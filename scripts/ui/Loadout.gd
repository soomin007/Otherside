extends Control

## 마을 · 원정 준비 (가방 꾸리기) — 매 원정 출발 전. 제한된 칸(6)에 책상 물품을 골라 담아 출발한다.
## 담은 물품 합산 = 시작 자원(고정 START_RESOURCES 대체). 첫 원정엔 시장 NPC 가 규칙을 안내한다.
## 모바일 우선: 중앙 컬럼, 큰 버튼, 탭으로 담고 뺀다.

const BAG_SLOTS: int = 6
const ITEMS: Array = [
	{"key": "water", "label": "물통", "res": "water", "amount": 7},
	{"key": "food", "label": "식량 자루", "res": "food", "amount": 6},
	{"key": "rope", "label": "로프", "res": "rope", "amount": 1},
	{"key": "shelter", "label": "은신막", "res": "shelter", "amount": 1},
]
const PRESET: Array = ["water", "water", "food", "food", "rope", "shelter"]  ## 표준 구성

var _bag: Array = []   ## 담은 물품 key 배열(최대 BAG_SLOTS)
var _bag_box: HFlowContainer
var _preview: Label
var _depart_btn: Button

func _ready() -> void:
	add_child(Backdrop.new())  # 사막 밤 공통 배경(맨 뒤)
	var col := UITheme.build_column(self, 14)

	col.add_child(UITheme.make_label("마을 · 원정 준비", UITheme.FS_H1))
	col.add_child(UITheme.make_label(_npc_line(), UITheme.FS_SMALL, UITheme.SAND))

	col.add_child(UITheme.make_label("책상에서 챙긴다", UITheme.FS_LABEL, UITheme.MUTED))
	var desk := HFlowContainer.new()
	desk.add_theme_constant_override("h_separation", 10)
	desk.add_theme_constant_override("v_separation", 10)
	for it in ITEMS:
		var item: Dictionary = it
		var btn := UITheme.make_button("%s  +%d" % [str(item.get("label", "")), int(item.get("amount", 0))], false)
		btn.custom_minimum_size = Vector2(230, UITheme.BTN_H_SM)
		btn.pressed.connect(_add_item.bind(str(item.get("key", ""))))
		desk.add_child(btn)
	col.add_child(desk)

	col.add_child(UITheme.make_label("가방", UITheme.FS_LABEL, UITheme.MUTED))
	_bag_box = HFlowContainer.new()
	_bag_box.add_theme_constant_override("h_separation", 8)
	_bag_box.add_theme_constant_override("v_separation", 8)
	col.add_child(_bag_box)

	_preview = UITheme.make_label("", UITheme.FS_LABEL, UITheme.FG)
	col.add_child(_preview)

	var preset_btn := UITheme.make_button("표준 구성으로 채우기", false)
	preset_btn.pressed.connect(_apply_preset)
	col.add_child(preset_btn)

	_depart_btn = UITheme.make_button("떠난다")
	_depart_btn.pressed.connect(_depart)
	col.add_child(_depart_btn)

	_apply_preset()  # 처음엔 표준 구성으로 채워둔다(빠른 출발)

## 시장 NPC 한 마디 — 첫 원정이면 규칙 안내(튜토리얼), 이후엔 짧게.
func _npc_line() -> String:
	if GameState.expedition_count == 0:
		return "시장: 가방은 여섯 칸뿐이오. 물과 식량이 곧 목숨이고, 로프는 갈라진 틈을, 은신막은 폭풍을 견디게 하지. 무엇을 지고 갈지는 당신 몫이오."
	return "시장: 또 떠나는군. 부디 조심히."

func _add_item(key: String) -> void:
	if _bag.size() >= BAG_SLOTS:
		return
	_bag.append(key)
	_refresh()

func _remove_item(idx: int) -> void:
	if idx >= 0 and idx < _bag.size():
		_bag.remove_at(idx)
		_refresh()

func _apply_preset() -> void:
	_bag = PRESET.duplicate()
	_refresh()

func _refresh() -> void:
	for c in _bag_box.get_children():
		_bag_box.remove_child(c)
		c.queue_free()
	for i in range(_bag.size()):
		var key: String = _bag[i]
		var btn := UITheme.make_button("%s  ✕" % _item_label(key), false)
		btn.custom_minimum_size = Vector2(150, UITheme.BTN_H_SM)
		btn.pressed.connect(_remove_item.bind(i))
		_bag_box.add_child(btn)
	for i in range(BAG_SLOTS - _bag.size()):
		var empty := UITheme.make_label("· 빈칸 ·", UITheme.FS_SMALL, UITheme.MUTED)
		empty.custom_minimum_size = Vector2(150, UITheme.BTN_H_SM)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_bag_box.add_child(empty)

	var res: Dictionary = _bag_resources()
	_preview.text = "물 %d · 식량 %d · 로프 %d · 은신처 %d    (%d/%d칸)" % [
		int(res["water"]), int(res["food"]), int(res["rope"]), int(res["shelter"]), _bag.size(), BAG_SLOTS]
	if _depart_btn != null:
		_depart_btn.disabled = int(res["water"]) <= 0 and int(res["food"]) <= 0

## 가방 물품 합산 → 시작 자원.
func _bag_resources() -> Dictionary:
	var res: Dictionary = {"water": 0, "food": 0, "rope": 0, "shelter": 0}
	for key in _bag:
		var item: Dictionary = _item(str(key))
		var rk: String = str(item.get("res", ""))
		if rk != "":
			res[rk] = int(res.get(rk, 0)) + int(item.get("amount", 0))
	return res

func _item(key: String) -> Dictionary:
	for it in ITEMS:
		var item: Dictionary = it
		if str(item.get("key", "")) == key:
			return item
	return {}

func _item_label(key: String) -> String:
	return str(_item(key).get("label", key))

func _depart() -> void:
	GameState.begin_run_with(_bag_resources())
	GameState.go_to_map()
