extends Control

## 탑뷰 지도 — Slay the Spire 식 분기 노드 맵. 여기서 길을 골라 원정을 떠난다.
## 총괄자가 거듭 보낸 원정대들의 누적(길/죽음/흔적)을 보여주는 창 — 주제의 시각화.
##
## 1단계(현재): 고정 노드 그래프(MapGraph)를 시각화 — 노드·엣지·분기. 위(마을)→아래(목적지).
## 다음 단계: 현재 노드/선택, 노드 선택 → 횡스크롤 엣지 전진, 안개(누적), 죽음·흔적 노드 마커.

const TOP_Y: float = 96.0    ## 제목 아래(지도 시작 y)
const BOT_Y: float = 168.0   ## 하단 출발 영역 높이
const NODE_R: float = 11.0

func _ready() -> void:
	var title := UITheme.make_label("지도 · 원정 계획", UITheme.FS_H1)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = UITheme.SAFE + 10.0
	add_child(title)

	var bottom := CenterContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -BOT_Y
	bottom.offset_bottom = -UITheme.SAFE
	add_child(bottom)

	var bcol := VBoxContainer.new()
	bcol.custom_minimum_size = Vector2(UITheme.COLUMN_W, 0)
	bcol.add_theme_constant_override("separation", 10)
	bottom.add_child(bcol)

	bcol.add_child(UITheme.make_label(
		"이 세계에 놓인 흔적 %d개 · 죽은 자리 %d곳 · 원정 %d회" % [GameState.traces.size(), GameState.deaths.size(), GameState.expedition_count],
		UITheme.FS_SMALL, UITheme.MUTED))

	var embark := UITheme.make_button("출발")
	embark.pressed.connect(_on_embark_pressed)
	bcol.add_child(embark)

	queue_redraw()

func _on_embark_pressed() -> void:
	GameState.start_expedition()

# --- 노드 맵 렌더 ---

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
	var area := Rect2(UITheme.PAD, TOP_Y, rect.x - UITheme.PAD * 2.0, rect.y - TOP_Y - BOT_Y)
	if area.size.y < 60.0 or area.size.x < 60.0:
		return
	var font: Font = get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font

	# 엣지(분기) 먼저 — 노드 뒤에 깔린다.
	for id in MapGraph.NODES:
		var node: Dictionary = MapGraph.NODES[id]
		var from: Vector2 = _node_screen(node, area)
		for nx in node.get("next", []):
			var nn: Dictionary = MapGraph.node(str(nx))
			if nn.is_empty():
				continue
			draw_line(from, _node_screen(nn, area), Color(0.42, 0.40, 0.38, 0.7), 2.0)

	# 노드 + 이름
	for id in MapGraph.NODES:
		var node: Dictionary = MapGraph.NODES[id]
		var p: Vector2 = _node_screen(node, area)
		var kind: String = str(node.get("kind", ""))
		var col: Color = _kind_color(kind)
		# 시작/끝은 테두리로 강조
		if kind == "start" or kind == "end":
			draw_arc(p, NODE_R + 4.0, 0.0, TAU, 24, col, 2.0)
		draw_circle(p, NODE_R, col)
		if font != null:
			draw_string(font, p + Vector2(NODE_R + 7.0, 5.0), str(node.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, 150.0, UITheme.FS_TINY, col)
