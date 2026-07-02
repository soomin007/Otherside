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

## 첫 원정 시장 인트로 — 규칙을 한 번 쭉 설명하고 마지막에 기록지를 건넨다(give_record). Opening 슬라이드식.
const MARKET_PAGES: Array = [
	"시장: 잘 왔소. 떠날 채비를 돕겠소.",
	"시장: 가방은 여섯 칸뿐이오. 물과 식량이 곧 목숨이고, 로프는 갈라진 틈을, 은신막은 폭풍을 견디게 하지.",
	"시장: 지도에서 갈 곳을 고르면 원정대가 그리로 가오. 걸음마다 물이 닳으니, 멀수록 목이 마르지.",
	"시장: 도착한 곳은 몇 번 살필 수 있소. 살피는 데 자원은 안 드니 아끼지 마시오.",
	"시장: 죽기 전 단 한 번, 물건을 남길 수 있소. 다음 원정대가 그걸 줍지. 무엇을 남길지가 당신 몫이오.",
	"시장: 이 기록지를 가져가시오. 떠난 원정대의 이야기가 여기 적힐 거요. 화면 구석 책갈피에서 언제든 펴 보시오.",
]

var _bag: Array = []   ## 담은 물품 key 배열(최대 BAG_SLOTS)
var _bag_box: HFlowContainer
var _preview: Label
var _depart_btn: Button

var _pending_name: String = ""   ## 이번 원정대 이름 — 랜덤 초기값, 편집·다시 뽑기 가능. _depart 에서 begin_run_with 로 넘긴다.
var _pending_vocation: String = ""  ## 이번 대장의 직능 id (기본 "" = 평범). _depart 에서 넘긴다.
var _voc_option: OptionButton
var _voc_desc: Label
var _name_edit: LineEdit
var _rng := RandomNumberGenerator.new()
var _market_panel: Control       ## 첫 원정 시장 인트로 모달(있을 때만)
var _market_label: Label
var _market_idx: int = 0

func _ready() -> void:
	_rng.randomize()
	var bg := Backdrop.new()  # 사막 밤 + 마을 실루엣(맨 뒤)
	bg.scene_kind = "village"
	add_child(bg)
	var col := UITheme.build_column(self, 14)

	col.add_child(UITheme.make_label("마을 · 원정 준비", UITheme.FS_H1))
	col.add_child(UITheme.make_label(_npc_line(), UITheme.FS_SMALL, UITheme.SAND))

	# 원정대 이름 — 랜덤 초기값 + 다시 뽑기 + 직접 입력(애착·서사).
	_pending_name = ExpeditionNamer.random(_rng)
	col.add_child(UITheme.make_label("원정대 이름", UITheme.FS_LABEL, UITheme.MUTED))
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	_name_edit = LineEdit.new()
	_name_edit.text = _pending_name
	_name_edit.placeholder_text = "원정대 이름"
	_name_edit.custom_minimum_size = Vector2(0, UITheme.BTN_H_SM)
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.add_theme_font_size_override("font_size", UITheme.FS_BODY)
	_name_edit.text_changed.connect(_on_name_edited)
	name_row.add_child(_name_edit)
	var reroll := UITheme.make_button("다시 뽑기", false)
	reroll.custom_minimum_size = Vector2(160, UITheme.BTN_H_SM)
	reroll.pressed.connect(_reroll_name)
	name_row.add_child(reroll)
	col.add_child(name_row)

	# 이번 대장의 특기(직능) — 매 원정 다른 사람이 간다. 고른 특기가 그 원정의 결을 바꾼다.
	col.add_child(UITheme.make_label("이번 대장의 특기", UITheme.FS_LABEL, UITheme.MUTED))
	_voc_option = OptionButton.new()
	_voc_option.custom_minimum_size = Vector2(0, UITheme.BTN_H_SM)
	_voc_option.add_theme_font_size_override("font_size", UITheme.FS_LABEL)
	for vid in Vocations.ids():
		_voc_option.add_item(Vocations.name_of(str(vid)))
	_voc_option.item_selected.connect(_on_voc_selected)
	col.add_child(_voc_option)
	_voc_desc = UITheme.make_label(str(Vocations.by_id("").get("desc", "")), UITheme.FS_SMALL, UITheme.SAND)
	col.add_child(_voc_desc)

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

	col.add_child(UITheme.make_label("가방  (탭해서 빼기)", UITheme.FS_LABEL, UITheme.MUTED))
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

	# 첫 원정이면 시장이 규칙을 쭉 설명하고 기록지를 건넨다(책갈피가 켜진다).
	if GameState.expedition_count == 0 and not GameState.record_seen:
		_show_market_intro()

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
		var btn := UITheme.make_button(_item_label(key), false)
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
	GameState.begin_run_with(_bag_resources(), _pending_name.strip_edges(), _pending_vocation)
	GameState.go_to_map()

# --- 원정대 이름 ---

func _on_name_edited(text: String) -> void:
	_pending_name = text

func _reroll_name() -> void:
	_pending_name = ExpeditionNamer.random(_rng)
	if _name_edit != null:
		_name_edit.text = _pending_name

## 직능 선택 — OptionButton 인덱스는 Vocations.ids() 순서와 같다. 설명을 갱신한다.
func _on_voc_selected(idx: int) -> void:
	var ids: Array = Vocations.ids()
	if idx < 0 or idx >= ids.size():
		return
	_pending_vocation = str(ids[idx])
	if _voc_desc != null:
		_voc_desc.text = str(Vocations.by_id(_pending_vocation).get("desc", ""))

# --- 첫 원정 시장 인트로 (규칙 설명 + 기록지 건네기) ---

func _show_market_intro() -> void:
	_market_idx = 0
	_market_panel = Control.new()
	_market_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_market_panel)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = UITheme.SCRIM
	dim.gui_input.connect(_on_market_input)
	_market_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_market_panel.add_child(center)
	var card := UITheme.make_card()
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UITheme.GAP)
	card.add_child(box)
	_market_label = UITheme.make_label(str(MARKET_PAGES[0]), UITheme.FS_BODY)
	box.add_child(_market_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var skip := UITheme.make_button("건너뛰기", false)
	skip.pressed.connect(_finish_market)
	row.add_child(skip)
	var nxt := UITheme.make_button("다음", false)
	nxt.pressed.connect(_market_advance)
	row.add_child(nxt)
	box.add_child(row)

func _on_market_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if tap:
		_market_advance()

func _market_advance() -> void:
	_market_idx += 1
	if _market_idx >= MARKET_PAGES.size():
		_finish_market()
		return
	if _market_label != null:
		_market_label.text = str(MARKET_PAGES[_market_idx])

func _finish_market() -> void:
	GameState.give_record()  # 기록지 = 책갈피(Bookmark)를 켠다
	if _market_panel != null:
		_market_panel.queue_free()
		_market_panel = null
