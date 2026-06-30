extends Control

## 탑뷰 지도 — 데스 스트랜딩식 탐험. 미지를 나아가며 발견한다(가봐야 무엇이 있는지 안다).
## 가본 노드만 정체가 드러나고(이름·종류), 지금 갈 수 있는 다음은 "?"(미지)로만 보인다. 그 너머는 안 보인다.
## 루프: 갈 곳(미지) 선택 → 이동 → 도착해서 그 장소를 알게 됨 → 다음 갈래가 드러남 → 또 고른다.
## StS 의 "앞이 다 보임"을 버린 형태. 지형 비주얼·이동을 맵으로 완전 이전·랜드마크 단면 탐색은 다음 단계.

const TOP_Y: float = 96.0
const BOT_Y: float = 120.0
const NODE_R: float = 13.0

func _ready() -> void:
	if GameState.current_run == null or not GameState.current_run.alive:
		GameState.begin_run_in_place()

	var title := UITheme.make_label("지도 · 탐험", UITheme.FS_H1)
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
	return "갈 곳을 고르세요. 가봐야 무엇이 있는지 압니다."

func _current_node_id() -> String:
	if GameState.current_run != null:
		return GameState.current_run.current_node
	return MapGraph.START_ID

## 정체가 드러난 노드(가본 곳). 이름·종류가 보인다.
func _is_revealed(id: String) -> bool:
	return GameState.visited_nodes.has(id)

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

	# 엣지 — 가본 노드에서 나가는 길만. 끝이 가봤거나(드러남) 지금 갈 수 있는(미지) 곳일 때.
	for id in MapGraph.NODES:
		if not _is_revealed(id):
			continue
		var from: Vector2 = _node_screen(MapGraph.NODES[id], area)
		var from_cur: bool = (id == cur)
		for nx in MapGraph.node(id).get("next", []):
			var nx_s: String = str(nx)
			var to_reachable: bool = nx_s in nexts
			if not (_is_revealed(nx_s) or to_reachable):
				continue
			var col: Color = Color(0.80, 0.68, 0.46, 0.95) if from_cur else Color(0.42, 0.40, 0.38, 0.55)
			draw_line(from, _node_screen(MapGraph.node(nx_s), area), col, 3.0 if from_cur else 1.5)

	# 노드 — 가본 곳은 정체(이름·종류), 갈 수 있는 미지는 "?"(밝게 빛남), 나머지는 안 보임.
	for id in MapGraph.NODES:
		var revealed: bool = _is_revealed(id)
		var reachable: bool = id in nexts
		if not (revealed or reachable):
			continue
		var p: Vector2 = _node_screen(MapGraph.NODES[id], area)
		if revealed:
			var kind: String = str(MapGraph.NODES[id].get("kind", ""))
			var col: Color = _kind_color(kind)
			if reachable:
				draw_circle(p, NODE_R + 6.0, Color(col.r, col.g, col.b, 0.22))
				draw_arc(p, NODE_R + 5.0, 0.0, TAU, 28, UITheme.SAND, 2.5)
			draw_circle(p, NODE_R, col)
			if id == cur:
				draw_arc(p, NODE_R + 6.0, 0.0, TAU, 28, UITheme.FG, 3.0)
			if font != null:
				draw_string(font, p + Vector2(NODE_R + 9.0, 5.0), str(MapGraph.NODES[id].get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, 150.0, UITheme.FS_TINY, col)
		else:
			# 갈 수 있지만 가본 적 없는 곳 — 미지("?"). 밝게 빛나 클릭을 부른다.
			draw_circle(p, NODE_R + 5.0, Color(0.84, 0.70, 0.47, 0.18))
			draw_arc(p, NODE_R + 4.0, 0.0, TAU, 28, UITheme.SAND, 2.0)
			draw_circle(p, NODE_R, Color(0.32, 0.31, 0.35))
			if font != null:
				draw_string(font, p - Vector2(4.0, -6.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_BODY, UITheme.SAND)
