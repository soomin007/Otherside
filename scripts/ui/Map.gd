extends Control

## 탑뷰 지도 — 데스 스트랜딩식 탐험. 맵 자체가 게임 인터페이스다(별도 이동 씬 없음).
## 미지("?") 노드를 누르면 마커가 그 노드로 *맵 위에서 실제 이동*하며 자원이 닳고, 도착하면 그 노드 화면으로 넘어간다.
## 가본 노드만 정체(이름·종류)가 드러나고, 갈 수 있는 다음은 "?", 그 너머는 안 보인다(강한 미지).
## 이동 중 자잘한 상황·랜드마크 단면 탐색·지형 비주얼은 다음 단계.

const TOP_Y: float = 140.0   ## 제목 + 자원 HUD 아래(지도 시작 y)
const BOT_Y: float = 156.0   ## 하단 요소(안내·남기기 버튼·통계 라벨)가 다 들어가게 + 웹 주소창 여유
const NODE_R: float = 13.0
const STEP_INTERVAL: float = 0.28  ## 이동 한 걸음의 시간(초)

# 고지도·양피지 팔레트 — UITheme 로 승격(지도·단면 공유). alias 로 기존 참조 유지.
const PAPER: Color = UITheme.PAPER
const PAPER_EDGE: Color = UITheme.PAPER_EDGE
const INK: Color = UITheme.INK
const INK_FADE: Color = UITheme.INK_FADE
const ROUTE: Color = UITheme.ROUTE
const MARKER_INK: Color = UITheme.MARKER_INK

var _hud: Label
var _guide: Label
var _moving: bool = false
var _move_timer: float = 0.0
var _sit_panel: Control       ## 이동 중 상황 카드 모달
var _sit_box: VBoxContainer   ## 카드 내용(매번 갈아끼움)
var _leave_btn: Button        ## "남기기" — 이동 중에도 물건 하나 두고 계속 (런당 1회)
var _bequeath: BequeathPanel  ## 남기기 모달 (공유 컴포넌트 — 도착 화면과 같은 것)
var _result_popup: ResultPopup ## 선택 결과 팝업 (공유)

func _ready() -> void:
	if GameState.current_run == null or not GameState.current_run.alive:
		GameState.begin_run_in_place()

	var title := UITheme.make_label("지도 · 탐험", UITheme.FS_H1)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = UITheme.SAFE + 8.0
	add_child(title)

	_hud = UITheme.make_label("", UITheme.FS_LABEL, UITheme.FG)
	_hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hud.offset_top = UITheme.SAFE + 54.0
	add_child(_hud)

	var bottom := CenterContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -BOT_Y
	bottom.offset_bottom = -UITheme.SAFE
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	var bcol := VBoxContainer.new()
	bcol.custom_minimum_size = Vector2(UITheme.COLUMN_W, 0)
	bottom.add_child(bcol)
	_guide = UITheme.make_label(_guide_text(), UITheme.FS_LABEL, UITheme.SAND)
	bcol.add_child(_guide)
	# 남기기 — 이동 중에도 상시 누를 수 있게 둔다(이동 중 고갈사 전에 남길 기회). 누르면 멈추고 남긴 뒤 계속.
	_leave_btn = UITheme.make_button("남기기", false)
	_leave_btn.pressed.connect(_on_leave_pressed)
	bcol.add_child(_leave_btn)
	bcol.add_child(UITheme.make_label(
		"흔적 %d개 · 죽은 자리 %d곳 · 원정 %d회" % [GameState.traces.size(), GameState.deaths.size(), GameState.expedition_count],
		UITheme.FS_SMALL, UITheme.MUTED))

	_build_situation_panel()
	# 남기기·결과 팝업 = 공유 컴포넌트(도착 화면과 같은 것).
	_bequeath = BequeathPanel.new()
	_bequeath.committed.connect(_on_bequeath_done)
	_bequeath.cancelled.connect(_on_bequeath_done)
	add_child(_bequeath)
	_result_popup = ResultPopup.new()
	add_child(_result_popup)
	_refresh_hud()
	queue_redraw()

func _guide_text() -> String:
	if _moving:
		return "나아가는 중..."
	if _current_node_id() == "end":
		return "목적지에 닿았다. (여기까지가 Phase 0)"
	return "갈 곳을 고르세요. 가봐야 무엇이 있는지 압니다."

func _current_node_id() -> String:
	if GameState.current_run != null:
		return GameState.current_run.current_node
	return MapGraph.START_ID

func _is_revealed(id: String) -> bool:
	return GameState.visited_nodes.has(id)

func _refresh_hud() -> void:
	var run: ExpeditionRun = GameState.current_run
	if run == null or _hud == null:
		return
	_hud.text = "물 %d · 식량 %d · %s" % [run.get_res("water"), run.get_res("food"), Items.tools_summary(run.resources)]
	_update_leave_btn(run)

## 남기기 버튼 상태 — 이미 남겼으면 잠그고, 아니면 남길 수 있는 자원이 하나라도 있을 때만 활성.
func _update_leave_btn(run: ExpeditionRun) -> void:
	if _leave_btn == null:
		return
	if run.bequeathed:
		_leave_btn.disabled = true
		_leave_btn.text = "남겼다"
	else:
		_leave_btn.disabled = not _any_leavable(run)
		_leave_btn.text = "남기기"

func _any_leavable(run: ExpeditionRun) -> bool:
	for key in ["water", "food", "rope", "shelter"]:
		if run.can_leave(key):
			return true
	return false

## 남기기 — 이동 중이면 멈추고, 마지막 밟은 노드에 물건을 둔다(런당 1회). 남긴 뒤 이동을 잇는다.
func _on_leave_pressed() -> void:
	var run: ExpeditionRun = GameState.current_run
	if run == null or not run.alive or run.bequeathed:
		return
	if _sit_panel.visible or _bequeath.is_open() or _result_popup.is_open():
		return
	_moving = false
	if _guide != null:
		_guide.text = "멈춰 선다."
	_bequeath.open(run, run.current_node)  # 이동 중=마지막 밟은 노드에 남긴다(death_node_id 와 일관)

## 남기기 패널이 닫힌 뒤 (남겼든 취소든) — 이동 중이었으면 이어서 나아간다.
func _on_bequeath_done() -> void:
	var run: ExpeditionRun = GameState.current_run
	_refresh_hud()
	if run != null and run.alive and run.target_node_id() != "" and not run.arrived():
		_moving = true
		_move_timer = 0.0
		if _guide != null:
			_guide.text = "나아가는 중..."
	elif _guide != null:
		_guide.text = _guide_text()

# --- 이동 (맵 위에서 실제로) ---

func _process(delta: float) -> void:
	if not _moving:
		return
	queue_redraw()
	_move_timer += delta
	if _move_timer < STEP_INTERVAL:
		return
	_move_timer = 0.0
	var run: ExpeditionRun = GameState.current_run
	if run == null:
		_moving = false
		return
	run.step()
	_refresh_hud()
	if not run.alive or run.arrived():
		_moving = false
		GameState.go_to_expedition()  # 도착(또는 도중 고갈사) → 그 노드 화면
	elif not run.pending_situation.is_empty():
		_moving = false
		_show_situation_card()  # 이동 중 마주친 상황 — 결정하면 이동을 잇는다

func _gui_input(event: InputEvent) -> void:
	if _moving or (_sit_panel != null and _sit_panel.visible) or (_bequeath != null and _bequeath.is_open()) or (_result_popup != null and _result_popup.is_open()):
		return
	var clicked: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not clicked:
		return
	var pos: Vector2 = event.position
	var area := _map_area()
	for nx in MapGraph.node(_current_node_id()).get("next", []):
		var p: Vector2 = _node_screen(MapGraph.node(str(nx)), area)
		if pos.distance_to(p) <= NODE_R + 18.0:
			GameState.begin_travel(str(nx))
			_moving = true
			_move_timer = 0.0
			if _guide != null:
				_guide.text = "나아가는 중..."
			return

# --- 이동 중 상황 카드 ---

func _build_situation_panel() -> void:
	_sit_panel = Control.new()
	_sit_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sit_panel.visible = false
	add_child(_sit_panel)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = UITheme.SCRIM
	_sit_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sit_panel.add_child(center)
	var card := UITheme.make_card()
	center.add_child(card)
	_sit_box = VBoxContainer.new()
	_sit_box.add_theme_constant_override("separation", UITheme.GAP)
	card.add_child(_sit_box)

## 이동 중 마주친 상황 카드 — 읽고 한 가지를 고른다(관리·대비). 결정하면 이동을 잇는다(죽으면 그 자리 노드 화면).
func _show_situation_card() -> void:
	var run: ExpeditionRun = GameState.current_run
	if run == null:
		return
	var sit: Dictionary = run.pending_situation
	for c in _sit_box.get_children():
		_sit_box.remove_child(c)
		c.queue_free()
	if _guide != null:
		_guide.text = "멈춰 선다."
	var threat_kind: int = int(sit.get("threat", Threats.Kind.CONSUMPTION))
	var threat_info: Dictionary = Threats.info(threat_kind)
	_sit_box.add_child(UITheme.make_label("[ %s ]" % str(threat_info.get("label", "상황")), UITheme.FS_SMALL, UITheme.SAND))
	_sit_box.add_child(UITheme.make_label(str(sit.get("text", "")), UITheme.FS_BODY))
	var event_id: String = str(sit.get("id", ""))
	var choices: Array = sit.get("choices", [])
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var effect: Dictionary = choice.get("effect", {})
		var enabled: bool = Situations.can_choose(choice, run.resources)
		var seen: bool = GameState.has_seen_choice(event_id, i)  # 겪어본 선택지만 결과 노출
		var btn := UITheme.make_button("", false)
		btn.text = UITheme.choice_text(choice, enabled, seen)
		if enabled:
			btn.pressed.connect(_on_situation_choice.bind(event_id, i, str(choice.get("label", "")), effect, choice.get("sets", []), choice.get("sets_persist", [])))
		else:
			btn.disabled = true
		_sit_box.add_child(btn)
	_sit_panel.visible = true

func _on_situation_choice(event_id: String, idx: int, label: String, effect: Dictionary, sets: Array, sets_persist: Array) -> void:
	var run: ExpeditionRun = GameState.current_run
	if run == null:
		return
	GameState.mark_choice_seen(event_id, idx)  # 이 선택지를 겪었다 — 다음 대면 때 결과가 보인다(런 한정)
	run.apply_choice(effect)
	for f in sets:
		run.set_flag(str(f))
	for f in sets_persist:
		run.set_flag(str(f))
	if not sets_persist.is_empty():
		GameState.add_persist_flags(sets_persist)
	_sit_panel.visible = false
	_refresh_hud()
	# blind choice 뒷면 — 결과(자원 변화)를 팝업으로 공개하고, 닫으면 이동을 잇는다.
	_result_popup.show_result(label, effect, _after_situation)

## 이동 중 상황의 결과 팝업을 닫은 뒤 — 죽었으면 그 자리 노드 화면, 아니면 이동 재개.
func _after_situation() -> void:
	var run: ExpeditionRun = GameState.current_run
	if run == null:
		return
	if not run.alive:
		GameState.go_to_expedition()  # 결정이 곧 죽음 → 그 자리 노드 화면
		return
	_moving = true   # 아직 도착 전 — 이동을 잇는다
	_move_timer = 0.0
	if _guide != null:
		_guide.text = "나아가는 중..."

# --- 렌더 ---

func _map_area() -> Rect2:
	var rect: Vector2 = size
	return Rect2(UITheme.PAD, TOP_Y, rect.x - UITheme.PAD * 2.0, rect.y - TOP_Y - BOT_Y)

func _node_screen(node: Dictionary, area: Rect2) -> Vector2:
	var mr: int = maxi(1, MapGraph.max_row())
	var col: float = float(node.get("col", 0.5))
	var row: float = float(int(node.get("row", 0)))
	return Vector2(
		area.position.x + col * area.size.x,
		area.position.y + (row / float(mr)) * area.size.y)

## 플레이어 마커 위치 — 이동 중이면 현재→목표 노드 보간, 아니면 현재 노드.
func _marker_pos(area: Rect2) -> Vector2:
	var run: ExpeditionRun = GameState.current_run
	if run == null:
		return _node_screen(MapGraph.node(MapGraph.START_ID), area)
	var cur_p: Vector2 = _node_screen(MapGraph.node(run.current_node), area)
	var tgt: String = run.target_node_id()
	if not _moving or tgt == "":
		return cur_p
	var prog: float = float(ExpeditionRun.EDGE_LEN - run.edge_remaining()) / float(ExpeditionRun.EDGE_LEN)
	return cur_p.lerp(_node_screen(MapGraph.node(tgt), area), clampf(prog, 0.0, 1.0))

func _draw() -> void:
	var rect: Vector2 = size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return
	var area := _map_area()
	if area.size.y < 60.0 or area.size.x < 60.0:
		return
	var font: Font = get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font

	# 양피지 바탕 + 은은한 지형결 + 낡은 가장자리(전부 절차적 — 웹 안전).
	draw_rect(area, PAPER)
	_draw_terrain(area)
	_draw_paper_edge(area)

	var cur: String = _current_node_id()
	var nexts: Array = MapGraph.node(cur).get("next", [])

	# 길 — 가본 노드에서 나가는 트레일. 밟은 길은 진한 실선, 미지로 향하는 길은 점선.
	for id in MapGraph.NODES:
		if not _is_revealed(id):
			continue
		var from: Vector2 = _node_screen(MapGraph.NODES[id], area)
		var from_cur: bool = (id == cur)
		for nx in MapGraph.node(id).get("next", []):
			var nx_s: String = str(nx)
			if not (_is_revealed(nx_s) or nx_s in nexts):
				continue
			var to: Vector2 = _node_screen(MapGraph.node(nx_s), area)
			if _is_revealed(nx_s):
				draw_line(from, to, ROUTE, 3.0 if from_cur else 2.0)
			else:
				_draw_dashed(from, to, INK_FADE, 2.0)

	# 노드 — 가본 곳은 손그림 장소 심볼+이름, 갈 수 있는 미지는 "?", 나머지는 안 보임.
	for id in MapGraph.NODES:
		var revealed: bool = _is_revealed(id)
		var reachable: bool = id in nexts
		if not (revealed or reachable):
			continue
		var p: Vector2 = _node_screen(MapGraph.NODES[id], area)
		if reachable and not _moving:
			draw_arc(p, NODE_R + 6.0, 0.0, TAU, 28, INK, 2.0)  # 누를 수 있는 곳
		if revealed:
			_draw_landmark_symbol(str(MapGraph.NODES[id].get("kind", "")), p)
			if font != null:
				draw_string(font, p + Vector2(NODE_R + 8.0, 5.0), str(MapGraph.NODES[id].get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, 150.0, UITheme.FS_TINY, INK)
		else:
			draw_circle(p, NODE_R - 2.0, Color(INK_FADE.r, INK_FADE.g, INK_FADE.b, 0.22))
			if font != null:
				draw_string(font, p - Vector2(4.0, -6.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_BODY, INK_FADE)

	# 흔적 — 이전 원정대들이 노드에 남긴 것(누적된 길/죽음의 역사, self-async).
	_draw_traces(area)

	# 원정대 마커 — 현재 위치(이동 중이면 길 위를 나아간다). 붉은 세피아로 도드라지게.
	var mp: Vector2 = _marker_pos(area)
	draw_circle(mp, 6.0, MARKER_INK)
	draw_arc(mp, 10.0, 0.0, TAU, 22, MARKER_INK, 2.0)

## 양피지 지형결 — 은은한 등고선(결정론 sin 곡선). 사막 지도의 결.
func _draw_terrain(area: Rect2) -> void:
	var line_col := Color(INK.r, INK.g, INK.b, 0.06)
	var rows: int = 7
	for i in range(1, rows):
		var base_y: float = area.position.y + area.size.y * float(i) / float(rows)
		var pts: PackedVector2Array = []
		var steps: int = 24
		for s in range(steps + 1):
			var t: float = float(s) / float(steps)
			var x: float = area.position.x + area.size.x * t
			var y: float = base_y + sin(t * TAU * 1.5 + float(i) * 1.3) * 7.0 + sin(t * TAU * 3.0) * 3.0
			pts.append(Vector2(x, y))
		draw_polyline(pts, line_col, 1.5)

## 양피지 가장자리 — 낡아 그을린 테두리(비네팅 대용, 셰이더 없이).
func _draw_paper_edge(area: Rect2) -> void:
	draw_rect(area, PAPER_EDGE, false, 3.0)
	var inset: float = 6.0
	draw_rect(Rect2(area.position + Vector2(inset, inset), area.size - Vector2(inset, inset) * 2.0), Color(PAPER_EDGE.r, PAPER_EDGE.g, PAPER_EDGE.b, 0.3), false, 1.5)

## 손그림 장소 심볼 (kind별) — 세피아 잉크. 점이 아니라 "장소"로 읽히게.
func _draw_landmark_symbol(kind: String, p: Vector2) -> void:
	match kind:
		"start":  # 마을 — 작은 천막
			var roof: PackedVector2Array = [p + Vector2(-9, 6), p + Vector2(0, -9), p + Vector2(9, 6)]
			draw_polyline(roof, INK, 2.0)
			draw_line(p + Vector2(-9, 6), p + Vector2(9, 6), INK, 2.0)
		"cache":  # 자원 — 우물(이중 원)
			draw_arc(p, 8.0, 0.0, TAU, 20, INK, 2.0)
			draw_circle(p, 2.5, INK)
		"blockage":  # 차단 — 갈라진 틈(지그재그)
			var zz: PackedVector2Array = [p + Vector2(-8, -7), p + Vector2(-2, 0), p + Vector2(-6, 3), p + Vector2(2, 8)]
			draw_polyline(zz, INK, 2.0)
		"storm":  # 폭풍 — 소용돌이(나선 두 겹)
			draw_arc(p, 8.0, 0.4, 0.4 + TAU * 0.8, 18, INK, 2.0)
			draw_arc(p, 4.5, 1.0, 1.0 + TAU * 0.7, 14, INK, 2.0)
		"end":  # 목적지 — 깃발
			draw_line(p + Vector2(-1, 9), p + Vector2(-1, -9), INK, 2.0)
			var flag: PackedVector2Array = [p + Vector2(-1, -9), p + Vector2(9, -5), p + Vector2(-1, -1)]
			draw_colored_polygon(flag, INK)
		_:
			draw_circle(p, 5.0, INK)

## 점선 — 미지로 향하는 길(아직 안 밟음).
func _draw_dashed(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var dist: float = a.distance_to(b)
	if dist < 0.5:
		return
	var dir: Vector2 = (b - a) / dist
	var dash: float = 7.0
	var gap: float = 5.0
	var d: float = 0.0
	while d < dist:
		var seg_end: float = minf(d + dash, dist)
		draw_line(a + dir * d, a + dir * seg_end, col, w)
		d = seg_end + gap

## 노드별 흔적 마커 — 죽음 X·로프 다리·자원 점. 가본 노드에만(흔적은 가본 곳에서만 생긴다). 한 노드에 여러 개면 옆으로 쌓는다.
func _draw_traces(area: Rect2) -> void:
	var per_node: Dictionary = {}
	for tr in GameState.loaded_traces():
		var nid: String = tr.node_id
		if nid == "" or not MapGraph.NODES.has(nid) or not _is_revealed(nid):
			continue
		var idx: int = int(per_node.get(nid, 0))
		per_node[nid] = idx + 1
		var base: Vector2 = _node_screen(MapGraph.node(nid), area)
		_draw_trace_marker(base + Vector2(-NODE_R - 7.0 - idx * 11.0, NODE_R + 11.0), tr.object_kind)

func _draw_trace_marker(p: Vector2, kind: int) -> void:
	match kind:
		TraceData.ObjectKind.BODY:
			var s: float = 4.5  # 죽은 자리 — 작은 X
			draw_line(p + Vector2(-s, -s), p + Vector2(s, s), UITheme.DANGER, 2.0)
			draw_line(p + Vector2(-s, s), p + Vector2(s, -s), UITheme.DANGER, 2.0)
		TraceData.ObjectKind.ROPE:
			draw_line(p + Vector2(-5.0, 0.0), p + Vector2(5.0, 0.0), UITheme.SAND, 2.5)  # 로프 다리
		TraceData.ObjectKind.WATER:
			draw_circle(p, 3.5, Color(0.55, 0.78, 0.97))
		TraceData.ObjectKind.FOOD:
			draw_circle(p, 3.5, Color(0.88, 0.72, 0.42))
		TraceData.ObjectKind.SHELTER:
			draw_circle(p, 3.5, Color(0.70, 0.85, 0.70))
		_:
			draw_circle(p, 2.5, UITheme.MUTED)
