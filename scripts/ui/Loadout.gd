extends Control

## 마을 · 원정 준비 — 매 원정 출발 전. 두 단계로 나눈다:
##  1) 원정대를 꾸린다 — 이름 + 대장 특기(직능) + 챙길 도구 하나. (대장 초상)
##  2) 배낭을 챙긴다 — 6칸 가방에 책상 물품을 담는다(합산 = 시작 자원). (배낭 초상)
## 단계를 나눠 각 화면이 짧고, 스크롤 컨테이너로 감싸 넘쳐도 떠나기 버튼까지 도달한다(이전엔 세로 초과로 잘림).
## 첫 원정엔 시장 NPC(초상)가 규칙을 안내하고 기록지를 건넨다.
## 모바일 우선: 중앙 최대폭 컬럼, 큰 버튼, 탭.

const BAG_SLOTS: int = 6
const PRESET: Array = ["water", "water", "food", "food", "rope", "shelter"]  ## 표준 구성 (아이템 정의는 core/Items.gd)

## 첫 원정 시장 인트로 — 규칙을 한 번 쭉 설명하고 마지막에 기록지를 건넨다(give_record). Opening 슬라이드식.
const MARKET_PAGES: Array = [
	"시장: 잘 왔소. 떠날 채비를 돕겠소.",
	"시장: 가방은 여섯 칸뿐이오. 물과 식량이 곧 목숨이고, 로프는 갈라진 틈을, 은신막은 폭풍을 견디게 하지.",
	"시장: 지도에서 갈 곳을 고르면 원정대가 그리로 가오. 걸음마다 물이 닳으니, 멀수록 목이 마르지.",
	"시장: 도착한 곳은 몇 번 살필 수 있소. 살피는 데 자원은 안 드니 아끼지 마시오.",
	"시장: 죽기 전 단 한 번, 물건을 남길 수 있소. 다음 원정대가 그걸 줍지. 무엇을 남길지가 당신 몫이오.",
	"시장: 이 기록지를 가져가시오. 떠난 원정대의 이야기가 여기 적힐 거요. 화면 구석 책갈피에서 언제든 펴 보시오.",
]

var _step: int = 1
var _col: VBoxContainer            ## 단계 콘텐츠 컨테이너(스크롤 안). _show_step 이 자식을 갈아끼운다.

var _bag: Array = []               ## 담은 물품 key 배열(최대 BAG_SLOTS) — 단계 넘어 유지
var _bag_box: HFlowContainer       ## step2 위젯
var _preview: Label                ## step2 위젯
var _depart_btn: Button            ## step2 위젯

var _pending_name: String = ""     ## 이번 원정대 이름 — 랜덤 초기값, 편집·다시 뽑기 가능
var _pending_vocation: String = "" ## 이번 대장의 직능 id (기본 "" = 평범)
var _pending_tool: String = ""     ## 주머니 도구 하나 (기본 "" = 없음). 가방 6칸과 별개
var _voc_desc: Label               ## step1 위젯 (직능 설명 갱신)
var _name_edit: LineEdit           ## step1 위젯
var _rng := RandomNumberGenerator.new()
var _market_panel: Control         ## 첫 원정 시장 인트로 모달(있을 때만)
var _market_label: Label
var _market_idx: int = 0

func _ready() -> void:
	_rng.randomize()
	var bg := Backdrop.new()  # 사막 밤 + 마을 실루엣(맨 뒤)
	bg.scene_kind = "village"
	add_child(bg)

	# UI 가독성 — 컬럼 뒤에 어두운 세로 띠를 깐다(지평선·색 변화가 글씨를 방해하지 않게).
	# Backdrop 위, 스크롤 아래. 화면 세로로 꽉 차 스크롤해도 글씨는 늘 어두운 면 위에 있다.
	var band := ColorRect.new()
	band.color = Color(0.05, 0.05, 0.07, 0.95)
	band.anchor_left = 0.5
	band.anchor_right = 0.5
	band.anchor_top = 0.0
	band.anchor_bottom = 1.0
	band.offset_left = -(UITheme.COLUMN_W * 0.5 + UITheme.PAD)
	band.offset_right = UITheme.COLUMN_W * 0.5 + UITheme.PAD
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 클릭은 위 스크롤/버튼으로 통과
	add_child(band)

	# 스크롤 컬럼 — 콘텐츠가 화면보다 길어도 아래 버튼까지 스크롤로 도달(중앙 최대폭 정렬). 휠은 부드럽게(SmoothScroll).
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(UITheme.PAD))
	add_child(margin)
	var scroll := SmoothScroll.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 14)
	_col.custom_minimum_size = Vector2(UITheme.COLUMN_W, 0)
	center.add_child(_col)

	_pending_name = ExpeditionNamer.random(_rng)
	_bag = PRESET.duplicate()  # 처음엔 표준 구성(빠른 출발)
	_show_step(1)

	# 첫 원정이면 시장이 규칙을 쭉 설명하고 기록지를 건넨다(책갈피가 켜진다).
	if GameState.expedition_count == 0 and not GameState.record_seen:
		_show_market_intro()

## 단계 전환 — 컬럼 자식을 비우고 그 단계 UI 를 다시 짓는다. _pending_* 은 멤버라 단계 넘어 유지된다.
func _show_step(n: int) -> void:
	_step = n
	_bag_box = null
	_preview = null
	_depart_btn = null
	_name_edit = null
	_voc_desc = null
	for c in _col.get_children():
		_col.remove_child(c)
		c.queue_free()
	if n == 1:
		_build_step1()
	else:
		_build_step2()

## 절차적 초상(Figures) — 단계 상단에 얹는다.
func _portrait(kind: String, h: float) -> Figures:
	var fig := Figures.new()
	fig.kind = kind
	fig.custom_minimum_size = Vector2(0, h)
	fig.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return fig

# --- 단계 1: 원정대를 꾸린다 ---

func _build_step1() -> void:
	_col.add_child(_portrait("leader", 150.0))
	_col.add_child(UITheme.make_label("원정대를 꾸린다", UITheme.FS_H1))
	_col.add_child(UITheme.make_label(_npc_line(), UITheme.FS_SMALL, UITheme.SAND))

	# 원정대 이름 — 랜덤 초기값 + 다시 뽑기 + 직접 입력(애착·서사).
	_col.add_child(UITheme.make_label("원정대 이름", UITheme.FS_LABEL, UITheme.MUTED))
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	_name_edit = LineEdit.new()
	_name_edit.text = _pending_name
	_name_edit.placeholder_text = "원정대 이름"
	_name_edit.custom_minimum_size = Vector2(0, UITheme.BTN_H_SM)
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.add_theme_font_size_override("font_size", UITheme.FS_LABEL)  # 혼자 크던 것 다른 라벨과 맞춤
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER  # 가운데 정렬
	_name_edit.text_changed.connect(_on_name_edited)
	name_row.add_child(_name_edit)
	var reroll := UITheme.make_button("다시 뽑기", false)
	reroll.custom_minimum_size = Vector2(160, UITheme.BTN_H_SM)
	reroll.pressed.connect(_reroll_name)
	name_row.add_child(reroll)
	_col.add_child(name_row)

	# 이번 대장의 특기(직능) — 매 원정 다른 사람이 간다. 고른 특기가 그 원정의 결을 바꾼다.
	_col.add_child(UITheme.make_label("이번 대장의 특기", UITheme.FS_LABEL, UITheme.MUTED))
	var voc := OptionButton.new()
	voc.custom_minimum_size = Vector2(340, UITheme.BTN_H_SM)
	voc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # 컬럼 폭 다 채우지 말고 내용 폭 + 가운데(빈 공간 축소)
	voc.add_theme_font_size_override("font_size", UITheme.FS_LABEL)
	var vids: Array = Vocations.ids()
	for i in range(vids.size()):
		voc.add_item(Vocations.name_of(str(vids[i])))
		if str(vids[i]) == _pending_vocation:
			voc.select(i)
	voc.item_selected.connect(_on_voc_selected)
	_col.add_child(voc)
	_voc_desc = UITheme.make_label(str(Vocations.by_id(_pending_vocation).get("desc", "")), UITheme.FS_SMALL, UITheme.SAND)
	_col.add_child(_voc_desc)

	# 챙길 도구 하나 — 가방 6칸과 별개(주머니). 특정 위기의 보험.
	_col.add_child(UITheme.make_label("챙길 도구 하나 (주머니)", UITheme.FS_LABEL, UITheme.MUTED))
	var tool := OptionButton.new()
	tool.custom_minimum_size = Vector2(340, UITheme.BTN_H_SM)
	tool.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tool.add_theme_font_size_override("font_size", UITheme.FS_LABEL)
	tool.add_item("없음")
	for i in range(Items.POUCH_TOOLS.size()):
		var tk: String = str(Items.POUCH_TOOLS[i])
		tool.add_item(Items.label_of(tk))
		if tk == _pending_tool:
			tool.select(i + 1)
	tool.item_selected.connect(_on_tool_selected)
	_col.add_child(tool)

	var nxt := UITheme.make_button("배낭 챙기기 →")
	nxt.pressed.connect(_show_step.bind(2))
	_col.add_child(nxt)

# --- 단계 2: 배낭을 챙긴다 ---

func _build_step2() -> void:
	_col.add_child(_portrait("pack", 130.0))
	_col.add_child(UITheme.make_label("배낭을 챙긴다", UITheme.FS_H1))
	_col.add_child(UITheme.make_label("가방은 여섯 칸. 담은 만큼이 이번 원정의 목숨이다.", UITheme.FS_SMALL, UITheme.MUTED))

	_col.add_child(UITheme.make_label("책상에서 챙긴다", UITheme.FS_LABEL, UITheme.MUTED))
	var desk := HFlowContainer.new()
	desk.add_theme_constant_override("h_separation", 10)
	desk.add_theme_constant_override("v_separation", 10)
	for it in Items.CATALOG:
		var item: Dictionary = it
		if str(item.get("key", "")) in Items.POUCH_TOOLS:
			continue  # 주머니 도구는 단계 1 "챙길 도구"에서 따로 고른다(가방 칸과 별개)
		var start: Dictionary = item.get("start", {})
		var btn := UITheme.make_button("%s  (%s)" % [str(item.get("label", "")), UITheme.effect_hint(start)], false)
		btn.clip_text = false  # 긴 설명(말린 고기 등)이 박스 밖으로 잘리지 않게 — 내용 폭에 맞춘다
		btn.custom_minimum_size = Vector2(0, UITheme.BTN_H_SM)  # 폭은 내용대로(HFlow 가 줄바꿈)
		btn.pressed.connect(_add_item.bind(str(item.get("key", ""))))
		desk.add_child(btn)
	_col.add_child(desk)

	_col.add_child(UITheme.make_label("가방  (탭해서 빼기)", UITheme.FS_LABEL, UITheme.MUTED))
	_bag_box = HFlowContainer.new()
	_bag_box.add_theme_constant_override("h_separation", 8)
	_bag_box.add_theme_constant_override("v_separation", 8)
	_col.add_child(_bag_box)

	_preview = UITheme.make_label("", UITheme.FS_LABEL, UITheme.FG)
	_col.add_child(_preview)

	var preset_btn := UITheme.make_button("표준 구성으로 채우기", false)
	preset_btn.pressed.connect(_apply_preset)
	_col.add_child(preset_btn)

	# 뒤로(단계 1) + 떠난다 — 스크롤 안이라 세로가 길어도 도달한다.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var back := UITheme.make_button("← 뒤로", false)
	back.pressed.connect(_show_step.bind(1))
	row.add_child(back)
	_depart_btn = UITheme.make_button("떠난다")
	_depart_btn.pressed.connect(_depart)
	row.add_child(_depart_btn)
	_col.add_child(row)

	_refresh()

## 시장 NPC 한 마디 — 첫 원정이면 규칙 안내, 이후엔 짧게.
func _npc_line() -> String:
	if GameState.expedition_count == 0:
		return "시장: 무엇을 지고, 누가 이끌지 정하시오. 물과 식량이 곧 목숨이오."
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
	if _bag_box == null:
		return  # 단계 1 에선 가방 UI 가 없다 (핸들러가 안전하게 no-op)
	for c in _bag_box.get_children():
		_bag_box.remove_child(c)
		c.queue_free()
	for i in range(_bag.size()):
		var key: String = _bag[i]
		var btn := UITheme.make_button(Items.label_of(key), false)
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
	var wgt: int = Items.bag_weight(_bag) + (Items.weight_of(_pending_tool) if _pending_tool != "" else 0)
	var pen: int = maxi(0, wgt - ExpeditionRun.WEIGHT_FREE) / maxi(1, ExpeditionRun.WEIGHT_STEP)
	var pen_str: String = "  · 무거워 물 +%d/걸음" % pen if pen > 0 else ""
	_preview.text = "물 %d · 식량 %d · %s\n무게 %d%s    (%d/%d칸)" % [
		int(res["water"]), int(res["food"]), Items.tools_summary(res), wgt, pen_str, _bag.size(), BAG_SLOTS]
	if _depart_btn != null:
		_depart_btn.disabled = int(res["water"]) <= 0 and int(res["food"]) <= 0

## 가방 물품 합산 → 시작 자원(core/Items.gd 카탈로그의 start 델타 합).
func _bag_resources() -> Dictionary:
	var res: Dictionary = Items.resources_of(_bag)
	if _pending_tool != "":
		res[_pending_tool] = int(res.get(_pending_tool, 0)) + 1  # 주머니 도구 하나(가방 칸 밖)
	return res

func _depart() -> void:
	var wgt: int = Items.bag_weight(_bag)
	if _pending_tool != "":
		wgt += Items.weight_of(_pending_tool)  # 주머니 도구도 무게에 더한다
	GameState.begin_run_with(_bag_resources(), _pending_name.strip_edges(), _pending_vocation, wgt)
	GameState.go_to_map()

# --- 원정대 이름 / 직능 / 도구 (단계 1 핸들러) ---

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

## 주머니 도구 선택 — 인덱스 0="없음", 1.. = POUCH_TOOLS 순서.
func _on_tool_selected(idx: int) -> void:
	if idx <= 0:
		_pending_tool = ""
	elif idx - 1 < Items.POUCH_TOOLS.size():
		_pending_tool = str(Items.POUCH_TOOLS[idx - 1])
	_refresh()

# --- 첫 원정 시장 인트로 (초상 + 규칙 설명 + 기록지 건네기) ---

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
	# 시장 초상 — 말하는 이가 시장임을 알게 한다.
	var fig := Figures.new()
	fig.kind = "market"
	fig.custom_minimum_size = Vector2(0, 160.0)
	fig.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(fig)
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
