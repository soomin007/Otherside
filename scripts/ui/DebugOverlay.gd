extends CanvasLayer

## 디버그 오버레이 — 모든 화면 위에 뜨는 개발용 도구(autoload). 직접 플레이테스트할 때
## "필요한 부분만" 빠르게 세팅한다: 자원 채우기·불사·노드 공개/점프·플래그·재회 임계·초기화.
##
## 왜 autoload CanvasLayer 인가: 기존 UI 씬(Main/Map/Expedition/Loadout)을 하나도 안 건드리고
## 그 위에 얹혀 GameState/current_run(공개 상태)을 조작한다. 씬 갱신이 필요한 동작은 GameState 라우팅으로 새로 그린다.
##
## 끄기: 배포 정식 빌드에서 안 보이게 하려면 ENABLED = false. (기본 true — 플레이테스트 편의)
## 여는 법: 오른쪽 위 "DEV" 버튼 탭(폰) / 데스크톱은 F1.
## 제약: -s(헤드리스 스크립트)엔 autoload 가 안 뜨므로 시뮬/테스트와 무간섭. UI 미감은 실기기에서 확인.

const ENABLED: bool = true

## 원터치로 켤 런 플래그(선택 반영 체인 테스트용). 같은 런(sets)+영속(sets_persist) 둘 다 켠다.
const TEST_FLAGS: Array = ["pool_drank", "rope_spent_now", "camp_shelter_now", "river_dug", "camp_shelter", "bones_mourned", "oasis_widened", "wall_tent_taken", "water_stocked"]

var _panel: Control
var _state: Label
var _god: bool = false
var _god_btn: Button
var _tick: float = 0.0

func _ready() -> void:
	if not ENABLED:
		return
	layer = 128  # 게임 UI 위
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false
	_refresh_state()

func _input(event: InputEvent) -> void:
	if not ENABLED:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		_toggle()

func _process(delta: float) -> void:
	if not ENABLED:
		return
	# God 모드 — 매 프레임 물/식량을 바닥 위로 유지(Map 의 step 이 0 으로 못 떨어뜨림).
	var run: ExpeditionRun = GameState.current_run
	if _god and run != null and run.alive:
		if run.get_res("water") < 40:
			run.resources["water"] = 40
		if run.get_res("food") < 40:
			run.resources["food"] = 40
	# 패널 열려 있으면 상태 라벨 주기 갱신
	if _panel != null and _panel.visible:
		_tick += delta
		if _tick >= 0.3:
			_tick = 0.0
			_refresh_state()

# --- UI 구성 ---

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 여는 버튼 (오른쪽 위 구석)
	var toggle := Button.new()
	toggle.text = "DEV"
	toggle.modulate = Color(1, 1, 1, 0.5)
	toggle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toggle.offset_left = -66.0
	toggle.offset_right = -8.0
	toggle.offset_top = 6.0
	toggle.offset_bottom = 44.0
	toggle.pressed.connect(_toggle)
	root.add_child(toggle)

	# 패널 (반투명 배경 + 오른쪽 스크롤 컬럼)
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_panel)

	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.55)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(_on_scrim_input)
	_panel.add_child(scrim)

	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	box.offset_left = -380.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.11, 0.98)
	sb.border_color = Color(0.5, 0.4, 0.25)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(12)
	box.add_theme_stylebox_override("panel", sb)
	_panel.add_child(box)

	var scroll := ScrollContainer.new()
	box.add_child(scroll)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.custom_minimum_size = Vector2(344, 0)
	scroll.add_child(col)

	_add_title(col, "디버그  (F1 / 바깥 탭 닫기)")
	_state = Label.new()
	_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_state.add_theme_color_override("font_color", Color(0.8, 0.85, 0.7))
	col.add_child(_state)

	_add_title(col, "생존")
	_add_btn(col, "자원 가득 (물50 식50 로프5 은5)", _fill_resources)
	_god_btn = _add_btn(col, "God 모드: OFF", _toggle_god)

	_add_title(col, "지도 / 이동")
	_add_btn(col, "모든 노드 공개", _reveal_all)
	var jump := OptionButton.new()
	jump.add_item("노드 단면으로 점프…")
	for id in MapGraph.NODES:
		var n: Dictionary = MapGraph.NODES[id]
		jump.add_item("%s  (%s)" % [id, str(n.get("name", ""))])
	jump.item_selected.connect(_on_jump_selected)
	col.add_child(jump)
	_add_btn(col, "새 원정 (지도 처음부터)", _new_run)

	_add_title(col, "선택 반영 체인 (플래그 켜기)")
	for f in TEST_FLAGS:
		var flag: String = str(f)
		_add_btn(col, "flag: " + flag, func() -> void: _set_flag(flag))

	_add_title(col, "결말")
	_add_btn(col, "재회 임계 채우기 (기림 %d·구조 %d·손실 0)" % [GameState.REUNION_MOURN, GameState.REUNION_RESCUES], _fill_reunion)
	_add_btn(col, "엔딩 바로보기: 순환", func() -> void: _show_ending("cycle"))
	_add_btn(col, "엔딩 바로보기: 재회 (크레딧 롤)", func() -> void: _show_ending("reunion"))

	# 각인 글씨(타이틀 메뉴 등) 실시간 튜닝 — 값을 정하면 EngravedItem 의 tune_* 기본값에 박는다.
	_add_title(col, "글씨 튜닝 (각인 메뉴 — 실시간)")
	_add_slider(col, "밑줄 두께", 0.2, 3.0, EngravedItem.tune_core,
		func(v: float) -> void: EngravedItem.tune_core = v)
	_add_slider(col, "밑줄 글로우", 0.0, 3.0, EngravedItem.tune_glow,
		func(v: float) -> void: EngravedItem.tune_glow = v)
	_add_slider(col, "그림자 진하기", 0.0, 1.0, EngravedItem.tune_shadow_a,
		func(v: float) -> void: EngravedItem.tune_shadow_a = v)
	_add_slider(col, "그림자 퍼짐", 0.0, 28.0, float(EngravedItem.tune_shadow_blur),
		func(v: float) -> void: EngravedItem.tune_shadow_blur = int(v))
	_add_slider(col, "테두리 어둠", 0.0, 1.0, EngravedItem.tune_outline_a,
		func(v: float) -> void: EngravedItem.tune_outline_a = v)
	_add_slider(col, "배경 어둠 진하기", 0.0, 1.0, EngravedItem.tune_bg_a,
		func(v: float) -> void: EngravedItem.tune_bg_a = v)
	_add_slider(col, "배경 어둠 퍼짐", 1.0, 4.0, EngravedItem.tune_bg_scale,
		func(v: float) -> void: EngravedItem.tune_bg_scale = v)

	_add_title(col, "제목 튜닝 (타이틀 로고 — 실시간)")
	var main_scr := preload("res://scripts/ui/Main.gd")
	_add_tslider(col, "제목 그림자 진하기", 0.0, 1.0, main_scr.title_shadow_a,
		func(v: float) -> void: main_scr.title_shadow_a = v)
	_add_tslider(col, "제목 그림자 퍼짐", 0.0, 28.0, float(main_scr.title_shadow_blur),
		func(v: float) -> void: main_scr.title_shadow_blur = int(v))
	_add_tslider(col, "제목 테두리 어둠", 0.0, 1.0, main_scr.title_outline_a,
		func(v: float) -> void: main_scr.title_outline_a = v)

	_add_title(col, "세이브")
	_add_btn(col, "세이브 초기화 → 타이틀", _reset)
	_add_btn(col, "닫기", _toggle)

func _add_title(col: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(0.84, 0.70, 0.47))
	col.add_child(l)

func _add_btn(col: VBoxContainer, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(cb)
	col.add_child(b)
	return b

## 제목 튜닝 슬라이더 — setter 후 타이틀(title_screen 그룹)에 적용 브로드캐스트.
func _add_tslider(col: VBoxContainer, text: String, lo: float, hi: float, cur: float, setter: Callable) -> void:
	var lbl := Label.new()
	lbl.text = "%s: %.2f" % [text, cur]
	lbl.add_theme_font_size_override("font_size", 13)
	col.add_child(lbl)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = cur
	s.custom_minimum_size = Vector2(0, 30)
	s.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		lbl.text = "%s: %.2f" % [text, v]
		get_tree().call_group("title_screen", "apply_title_tuning"))
	col.add_child(s)

## 튜닝 슬라이더 한 줄 — 값 바꾸면 setter 실행 후 모든 각인 항목에 즉시 반영(타이틀 띄워놓고 조절).
func _add_slider(col: VBoxContainer, text: String, lo: float, hi: float, cur: float, setter: Callable) -> void:
	var lbl := Label.new()
	lbl.text = "%s: %.2f" % [text, cur]
	lbl.add_theme_font_size_override("font_size", 13)
	col.add_child(lbl)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = cur
	s.custom_minimum_size = Vector2(0, 30)
	s.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		lbl.text = "%s: %.2f" % [text, v]
		get_tree().call_group("engraved_item", "apply_tuning"))
	col.add_child(s)

# --- 동작 ---

func _toggle() -> void:
	if _panel == null:
		return
	_panel.visible = not _panel.visible
	if _panel.visible:
		_refresh_state()

func _on_scrim_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if tap:
		_panel.visible = false

## 현재 원정이 없거나 죽었으면 새로 만든다(디버그 조작이 항상 먹히게).
func _ensure_run() -> void:
	if GameState.current_run == null or not GameState.current_run.alive:
		GameState.begin_run_in_place()

func _fill_resources() -> void:
	_ensure_run()
	var run: ExpeditionRun = GameState.current_run
	run.resources["water"] = 50
	run.resources["food"] = 50
	run.resources["rope"] = 5
	run.resources["shelter"] = 5
	_refresh_state()

func _toggle_god() -> void:
	_god = not _god
	if _god_btn != null:
		_god_btn.text = "God 모드: ON" if _god else "God 모드: OFF"

func _reveal_all() -> void:
	for id in MapGraph.NODES:
		if not GameState.visited_nodes.has(id):
			GameState.visited_nodes.append(id)
	GameState.save_game()
	GameState.go_to_map()
	_panel.visible = false

## 고른 노드의 단면(Expedition) 화면으로 바로 점프한다. 그 노드에 막 도착한 상태로 런을 맞춘다
## (엣지를 걸고 즉시 도착 처리 — 이동 소모는 건너뛴다). end 노드면 Expedition 이 엔딩을 띄운다.
func _on_jump_selected(index: int) -> void:
	if index <= 0:
		return  # 0 = "노드 단면으로 점프…" 안내
	var ids: Array = MapGraph.NODES.keys()
	var target: String = str(ids[index - 1])
	_ensure_run()
	var run: ExpeditionRun = GameState.current_run
	run.begin_edge(target)          # 이 노드로 향하는 엣지를 건다(_target_node = target)
	run._edge_step = run._edge_len  # 즉시 도착 상태로 — target_node_id()=target, 단면이 뜬다
	_reveal(target)
	for nx in MapGraph.node(target).get("next", []):
		_reveal(str(nx))
	GameState.go_to_expedition()    # 해당 노드 단면 화면으로
	_panel.visible = false

func _reveal(id: String) -> void:
	if id != "" and not GameState.visited_nodes.has(id):
		GameState.visited_nodes.append(id)

func _new_run() -> void:
	GameState.begin_run_in_place()
	GameState.go_to_map()
	_panel.visible = false

func _set_flag(flag: String) -> void:
	_ensure_run()
	GameState.current_run.set_flag(flag)
	GameState.add_persist_flags([flag])  # 다음 원정 재방문 변형까지 켠다
	_refresh_state()

## 엔딩 슬라이드쇼를 현재 화면 위에 바로 띄운다(세이브·런 상태는 안 건드림 — 연출 확인용).
## 재회 크레딧 롤은 실제 expedition_names 로 돈다. 끝나면 평소처럼 타이틀 복귀.
func _show_ending(kind: String) -> void:
	GameState.ending_kind_pending = kind
	var scn: Node = get_tree().current_scene
	if scn != null:
		scn.add_child(load("res://scripts/ui/Ending.gd").new())
	_panel.visible = false

func _fill_reunion() -> void:
	# 기림 축 — 더미 node_id 로 mourn_count 만 충족시킨다.
	for i in range(GameState.REUNION_MOURN):
		GameState.mark_mourned("debug_mourn_%d" % i)
	# 구조·온전 축은 이번 런의 상태 — 거둔 것으로 치고, 행렬 손실은 되돌린다(테스트에서 재회가 막히지 않게).
	if GameState.current_run != null:
		GameState.current_run.party_gained = GameState.REUNION_RESCUES
		GameState.current_run.party_lost = 0
	GameState.save_game()
	_refresh_state()

func _reset() -> void:
	GameState.reset_save()
	GameState.go_to_title()
	_panel.visible = false

func _refresh_state() -> void:
	if _state == null:
		return
	var run: ExpeditionRun = GameState.current_run
	var lines: Array = []
	lines.append("원정 #%d · 기림 %d/%d · 낙오자 %d곳 · 죽은자리 %d" % [
		GameState.expedition_count, GameState.mourn_count(), GameState.REUNION_MOURN,
		GameState.straggler_nodes().size(), GameState.deaths.size()])
	lines.append("공개 노드 %d/%d" % [GameState.visited_nodes.size(), MapGraph.NODES.size()])
	if run != null:
		lines.append("노드 %s · leg %d · %s" % [run.current_node, run.leg, ("살아있음" if run.alive else "사망:" + run.death_cause)])
		lines.append("물 %d · 식량 %d · 로프 %d · 장막 %d" % [run.get_res("water"), run.get_res("food"), run.get_res("rope"), run.get_res("shelter")])
		lines.append("행렬 %d명 · 손실 %d · 구조 %d/%d" % [run.party_left(), run.party_lost, run.party_gained, GameState.REUNION_RESCUES])
	else:
		lines.append("(진행 중 원정 없음)")
	_state.text = "\n".join(PackedStringArray(lines))
