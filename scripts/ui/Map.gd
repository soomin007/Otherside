extends Control

## 탑뷰 지도 — 데스 스트랜딩식 탐험. 맵 자체가 게임 인터페이스다(별도 이동 씬 없음).
## 미지("?") 노드를 누르면 마커가 그 노드로 *맵 위에서 실제 이동*하며 자원이 닳고, 도착하면 그 노드 화면으로 넘어간다.
## 가본 노드만 정체(이름·종류)가 드러나고, 갈 수 있는 다음은 "?", 그 너머는 안 보인다(강한 미지).
## 이동 중 자잘한 상황·랜드마크 단면 탐색·지형 비주얼은 다음 단계.

const TOP_Y: float = 140.0   ## 제목 + 자원 HUD 아래(지도 시작 y)
const BOT_Y: float = 110.0
const NODE_R: float = 13.0
const STEP_INTERVAL: float = 0.28  ## 이동 한 걸음의 시간(초)

var _hud: Label
var _guide: Label
var _moving: bool = false
var _move_timer: float = 0.0

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
	bcol.add_child(UITheme.make_label(
		"흔적 %d개 · 죽은 자리 %d곳 · 원정 %d회" % [GameState.traces.size(), GameState.deaths.size(), GameState.expedition_count],
		UITheme.FS_SMALL, UITheme.MUTED))

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
	_hud.text = "물 %d · 식량 %d · 로프 %d · 은신처 %d" % [run.get_res("water"), run.get_res("food"), run.get_res("rope"), run.get_res("shelter")]

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

func _gui_input(event: InputEvent) -> void:
	if _moving:
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

func _kind_color(kind: String) -> Color:
	match kind:
		"start": return UITheme.FG
		"cache": return UITheme.SAND
		"blockage": return Color(0.62, 0.52, 0.42)
		"storm": return Color(0.55, 0.60, 0.72)
		"end": return UITheme.DANGER
		_: return UITheme.MUTED

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

	var cur: String = _current_node_id()
	var nexts: Array = MapGraph.node(cur).get("next", [])

	# 엣지 — 가본 노드에서 나가는 길만(끝이 가봤거나 지금 갈 수 있는 곳일 때).
	for id in MapGraph.NODES:
		if not _is_revealed(id):
			continue
		var from: Vector2 = _node_screen(MapGraph.NODES[id], area)
		var from_cur: bool = (id == cur)
		for nx in MapGraph.node(id).get("next", []):
			var nx_s: String = str(nx)
			if not (_is_revealed(nx_s) or nx_s in nexts):
				continue
			var col: Color = Color(0.80, 0.68, 0.46, 0.95) if from_cur else Color(0.42, 0.40, 0.38, 0.55)
			draw_line(from, _node_screen(MapGraph.node(nx_s), area), col, 3.0 if from_cur else 1.5)

	# 노드 — 가본 곳은 정체, 갈 수 있는 미지는 "?", 나머지는 안 보임.
	for id in MapGraph.NODES:
		var revealed: bool = _is_revealed(id)
		var reachable: bool = id in nexts
		if not (revealed or reachable):
			continue
		var p: Vector2 = _node_screen(MapGraph.NODES[id], area)
		if revealed:
			var col: Color = _kind_color(str(MapGraph.NODES[id].get("kind", "")))
			if reachable and not _moving:
				draw_circle(p, NODE_R + 6.0, Color(col.r, col.g, col.b, 0.22))
				draw_arc(p, NODE_R + 5.0, 0.0, TAU, 28, UITheme.SAND, 2.5)
			draw_circle(p, NODE_R, col)
			if font != null:
				draw_string(font, p + Vector2(NODE_R + 9.0, 5.0), str(MapGraph.NODES[id].get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, 150.0, UITheme.FS_TINY, col)
		else:
			if not _moving:
				draw_circle(p, NODE_R + 5.0, Color(0.84, 0.70, 0.47, 0.18))
				draw_arc(p, NODE_R + 4.0, 0.0, TAU, 28, UITheme.SAND, 2.0)
			draw_circle(p, NODE_R, Color(0.32, 0.31, 0.35))
			if font != null:
				draw_string(font, p - Vector2(4.0, -6.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_BODY, UITheme.SAND)

	# 흔적 — 이전 원정대들이 노드에 남긴 것(누적된 길/죽음의 역사, self-async).
	_draw_traces(area)

	# 플레이어 마커 — 현재 위치(이동 중이면 길 위를 나아간다).
	var mp: Vector2 = _marker_pos(area)
	draw_circle(mp, 7.0, UITheme.FG)
	draw_arc(mp, 11.0, 0.0, TAU, 22, UITheme.FG, 2.0)

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
