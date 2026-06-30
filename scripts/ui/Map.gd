extends Control

## 탑뷰 지도 — Slay the Spire 식 분기 노드 맵. 현재 노드에서 갈 수 있는(밝게 빛나는) 다음 노드를 골라 떠난다.
## 루프: 지도에서 노드 선택 → 그 길을 가다(이동) → 랜드마크 도착 → (다음 단계: 단면 탐색 씬) → 지도 복귀.
## 안개: 가본 곳 + 그 인접만 보인다. 미지의 노드는 흐린 "?". 원정마다 더 드러난다(self-async).
## 노드 맵 비주얼·이동 연출·랜드마크 단면은 다음 단계 — 지금은 맵 정비(클릭 표시·안개).

const TOP_Y: float = 96.0
const BOT_Y: float = 120.0
const NODE_R: float = 13.0

func _ready() -> void:
	# 새 원정이면(run 없음 또는 직전 원정이 죽음) 마을부터 새로 시작한다. 도착 복귀(살아있는 run)는 유지.
	if GameState.current_run == null or not GameState.current_run.alive:
		GameState.begin_run_in_place()

	var title := UITheme.make_label("지도 · 원정 계획", UITheme.FS_H1)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = UITheme.SAFE + 10.0
	add_child(title)

	var bottom := CenterContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -BOT_Y
	bottom.offset_bottom = -UITheme.SAFE
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)

	var bcol := VBoxContainer.new()
	bcol.custom_minimum_size = Vector2(UITheme.COLUMN_W, 0)
	bcol.add_theme_constant_override("separation", 8)
	bottom.add_child(bcol)

	bcol.add_child(UITheme.make_label(_guide_text(), UITheme.FS_LABEL, UITheme.SAND))
	bcol.add_child(UITheme.make_label(
		"흔적 %d개 · 죽은 자리 %d곳 · 원정 %d회" % [GameState.traces.size(), GameState.deaths.size(), GameState.expedition_count],
		UITheme.FS_SMALL, UITheme.MUTED))

	queue_redraw()

func _guide_text() -> String:
	if _current_node_id() == "end":
		return "목적지에 닿았다. (여기까지가 Phase 0)"
	return "밝게 빛나는 곳을 눌러 떠나세요"

func _current_node_id() -> String:
	if GameState.current_run != null:
		return GameState.current_run.current_node
	return MapGraph.START_ID

## 안개 — 가본 노드, 또는 가본 노드에 인접한 노드만 보인다. 나머지는 미지("?").
func _is_visible(id: String) -> bool:
	if GameState.visited_nodes.has(id):
		return true
	for v in GameState.visited_nodes:
		if id in MapGraph.node(str(v)).get("next", []):
			return true
	return false

# --- 노드 선택(클릭) ---

func _gui_input(event: InputEvent) -> void:
	var clicked: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not clicked:
		return
	var pos: Vector2 = event.position
	var area := _map_area()
	for nx in MapGraph.node(_current_node_id()).get("next", []):
		var p: Vector2 = _node_screen(MapGraph.node(str(nx)), area)
		if pos.distance_to(p) <= NODE_R + 18.0:
			GameState.travel_to(str(nx))
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

	# 엣지 — 양 끝이 보이는 경우만. 지금 갈 수 있는 길(현재→next)은 또렷이.
	for id in MapGraph.NODES:
		if not _is_visible(id):
			continue
		var node: Dictionary = MapGraph.NODES[id]
		var from: Vector2 = _node_screen(node, area)
		var reachable_edge: bool = (id == cur)
		for nx in node.get("next", []):
			if not _is_visible(str(nx)):
				continue
			var nn: Dictionary = MapGraph.node(str(nx))
			var col: Color = Color(0.80, 0.68, 0.46, 0.95) if reachable_edge else Color(0.40, 0.38, 0.36, 0.5)
			draw_line(from, _node_screen(nn, area), col, 3.0 if reachable_edge else 1.5)

	# 노드 — 안개는 흐린 "?", 보이는 곳은 종류색. 현재(굵은 테두리)·갈 수 있는 곳(밝게 빛남) 강조.
	for id in MapGraph.NODES:
		var node: Dictionary = MapGraph.NODES[id]
		var p: Vector2 = _node_screen(node, area)
		if not _is_visible(id):
			draw_circle(p, 5.0, Color(0.30, 0.30, 0.34, 0.5))
			if font != null:
				draw_string(font, p - Vector2(4.0, -5.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, Color(0.45, 0.45, 0.5))
			continue
		var kind: String = str(node.get("kind", ""))
		var col: Color = _kind_color(kind)
		var selectable: bool = id in nexts
		if selectable:
			# 갈 수 있는 곳 — 밝은 후광 + 큰 테두리로 "여기 누르세요"
			draw_circle(p, NODE_R + 6.0, Color(col.r, col.g, col.b, 0.22))
			draw_arc(p, NODE_R + 5.0, 0.0, TAU, 28, UITheme.SAND, 2.5)
			draw_circle(p, NODE_R + 1.0, col)
		else:
			draw_circle(p, NODE_R, col)
		if id == cur:
			draw_arc(p, NODE_R + 6.0, 0.0, TAU, 28, UITheme.FG, 3.0)
		if font != null:
			var name_col: Color = col if (selectable or id == cur) else Color(col.r, col.g, col.b, 0.7)
			draw_string(font, p + Vector2(NODE_R + 9.0, 5.0), str(node.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, 150.0, UITheme.FS_TINY, name_col)
