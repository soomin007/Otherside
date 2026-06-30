extends Control

## 탑뷰 지도 — 누적된 길 / 죽음의 역사 / 남긴 흔적의 점. 여기서 이번 원정을 계획하고 출발한다.
## 총괄자가 거듭 보낸 원정대들의 누적(길/죽음/흔적)을 보여주는 창 — 주제의 시각화.
##
## 게임은 1D(leg) 진행이지만 지도는 2D 지형도로 그린다: leg → 결정론적 곡선 좌표(세계마다 같은 길).
## 안개는 가장 멀리 간 곳(최대 도달 leg) 너머를 덮는다 — "죽음 = 정찰"로 원정마다 더 멀리 드러난다.

const MAP_LEGS: int = 30        ## 지도에 그릴 경로 끝 (랜드마크 28 + 여유)
const TOP_Y: float = 96.0       ## 제목 아래(지도 시작 y)
const BOT_Y: float = 168.0      ## 하단 출발 영역 높이

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

# --- 지도 렌더링 ---

## leg 의 정규화 좌표. x ∈ [-1,1] 결정론적 흔들림(구불구불), y ∈ [0,1] 진행(위→아래).
func _path_norm(leg: int) -> Vector2:
	var t: float = float(leg)
	var x: float = sin(t * 0.7) * 0.6 + sin(t * 0.27 + 1.3) * 0.35
	var y: float = t / float(MAP_LEGS)
	return Vector2(clampf(x, -1.0, 1.0), y)

func _to_screen(leg: int, area: Rect2) -> Vector2:
	var n: Vector2 = _path_norm(leg)
	return Vector2(
		area.position.x + (n.x + 1.0) * 0.5 * area.size.x,
		area.position.y + n.y * area.size.y)

## 가장 멀리 간 leg (죽은 자리 + 흔적 중 최대). 안개 경계.
func _max_reached() -> int:
	var m: int = 0
	for d in GameState.deaths:
		if d is Dictionary:
			m = maxi(m, int(d.get("leg", 0)))
	for raw in GameState.traces:
		if raw is Dictionary:
			m = maxi(m, int(raw.get("leg", 0)))
	return m

func _trace_color(kind: int) -> Color:
	match kind:
		TraceData.ObjectKind.WATER: return Color(0.55, 0.78, 0.97)
		TraceData.ObjectKind.FOOD: return Color(0.88, 0.72, 0.42)
		TraceData.ObjectKind.SHELTER: return Color(0.74, 0.66, 0.92)
		TraceData.ObjectKind.BODY: return Color(0.72, 0.4, 0.4)
		_: return UITheme.SAND

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
	var max_reached: int = _max_reached()

	# 경로 — 걷힌 구간은 또렷이, 안개 너머는 흐리게
	var prev: Vector2 = _to_screen(0, area)
	for leg in range(1, MAP_LEGS + 1):
		var p: Vector2 = _to_screen(leg, area)
		var fogged: bool = leg > max_reached
		if fogged:
			draw_line(prev, p, Color(0.28, 0.27, 0.3, 0.3), 1.0)
		else:
			draw_line(prev, p, Color(0.5, 0.44, 0.36, 0.85), 3.0)
		prev = p

	# 랜드마크 — 걷힌 곳은 이름까지, 안개 너머는 흐린 점만
	for lm_leg in Situations.LANDMARKS:
		if lm_leg > MAP_LEGS:
			continue
		var p: Vector2 = _to_screen(lm_leg, area)
		var feat: Dictionary = Situations.LANDMARKS[lm_leg]
		var fogged: bool = lm_leg > max_reached
		var col: Color = Color(0.4, 0.38, 0.42) if fogged else UITheme.SAND
		draw_circle(p, 5.0, col)
		if not fogged and font != null:
			draw_string(font, p + Vector2(9.0, 4.0), str(feat.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, 150.0, UITheme.FS_TINY, col)

	# 흔적 — 종류별 색 점(ROPE 는 다리). 안개 너머는 안 보임.
	for t in GameState.loaded_traces():
		if t.leg > MAP_LEGS or t.leg > max_reached:
			continue
		var p: Vector2 = _to_screen(t.leg, area)
		if t.object_kind == TraceData.ObjectKind.ROPE:
			draw_rect(Rect2(p - Vector2(5.0, 2.0), Vector2(10.0, 4.0)), UITheme.SAND)
		else:
			draw_circle(p + Vector2(0.0, -8.0), 4.0, _trace_color(t.object_kind))

	# 죽은 자리 — X 표식
	for d in GameState.deaths:
		if not (d is Dictionary):
			continue
		var lg: int = int(d.get("leg", 0))
		if lg > MAP_LEGS:
			continue
		var p: Vector2 = _to_screen(lg, area)
		var s: float = 5.0
		draw_line(p - Vector2(s, s), p + Vector2(s, s), UITheme.DANGER, 2.0)
		draw_line(p - Vector2(s, -s), p + Vector2(s, -s), UITheme.DANGER, 2.0)

	# 출발점 (마을)
	var start: Vector2 = _to_screen(0, area)
	draw_circle(start, 6.0, UITheme.FG)
	if font != null:
		draw_string(font, start + Vector2(9.0, 4.0), "마을", HORIZONTAL_ALIGNMENT_LEFT, 100.0, UITheme.FS_TINY, UITheme.FG)
