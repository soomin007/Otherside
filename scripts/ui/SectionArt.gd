class_name SectionArt
extends RefCounted

## 도착 노드 단면의 절차적 그림 (static draw 헬퍼) — 전부 draw_*, 웹 안전(셰이더/이미지 없음).
## 양피지 판형(UITheme 팔레트) 위에 kind별 세피아 측단면. node_id 시드로 결정론(같은 노드 같은 그림).

## 단면 배경(양피지) + 지면 + kind별 실루엣을 rect 안에 그린다.
static func draw_section(ci: CanvasItem, kind: String, rect: Rect2, seed_id: String) -> void:
	ci.draw_rect(rect, UITheme.PAPER)
	ci.draw_rect(rect, UITheme.PAPER_EDGE, false, 3.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_id)
	var ground_y: float = rect.position.y + rect.size.y * 0.72
	ci.draw_line(Vector2(rect.position.x, ground_y), Vector2(rect.end.x, ground_y), UITheme.INK, 2.0)
	match kind:
		"start": _draw_camp(ci, rect, ground_y, rng)
		"cache": _draw_ruin(ci, rect, ground_y, rng)
		"blockage": _draw_chasm(ci, rect, ground_y, rng)
		"storm": _draw_storm(ci, rect, ground_y, rng)
		"end": _draw_gate(ci, rect, ground_y, rng)
		_: _draw_dunes(ci, rect, ground_y, rng)

## 지점 마커. state: 0=조사가능(붉은 링) 1=완료(체크·흐림) 2=잠김(예산0·흐림)
static func draw_spot(ci: CanvasItem, font: Font, center: Vector2, label: String, state: int) -> void:
	var r: float = 22.0
	var faded: Color = UITheme.INK_FADE
	if state == 0:
		ci.draw_circle(center, r + 3.0, Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.18))
		ci.draw_arc(center, r, 0.0, TAU, 32, UITheme.MARKER_INK, 2.5)
		ci.draw_circle(center, 4.0, UITheme.MARKER_INK)
	else:
		ci.draw_arc(center, r, 0.0, TAU, 32, faded, 1.5)
		if state == 1:
			ci.draw_polyline(PackedVector2Array([center + Vector2(-6, 0), center + Vector2(-1, 5), center + Vector2(7, -6)]), faded, 2.0)
	if font != null:
		var lc: Color = UITheme.INK if state == 0 else faded
		ci.draw_string(font, center + Vector2(-60.0, r + 20.0), label, HORIZONTAL_ALIGNMENT_CENTER, 120.0, UITheme.FS_SMALL, lc)

# --- kind별 실루엣 ---

static func _draw_camp(ci: CanvasItem, rect: Rect2, gy: float, rng: RandomNumberGenerator) -> void:
	var n: int = 2 + rng.randi_range(0, 1)
	for i in range(n):
		var x: float = rect.position.x + rect.size.x * (0.25 + 0.22 * float(i)) + rng.randf_range(-10.0, 10.0)
		ci.draw_polyline(PackedVector2Array([Vector2(x - 26.0, gy), Vector2(x, gy - 34.0), Vector2(x + 26.0, gy)]), UITheme.INK, 2.0)
	var wx: float = rect.end.x - rect.size.x * 0.2
	ci.draw_arc(Vector2(wx, gy - 6.0), 12.0, PI, TAU, 16, UITheme.INK, 2.0)

static func _draw_ruin(ci: CanvasItem, rect: Rect2, gy: float, rng: RandomNumberGenerator) -> void:
	var cx: float = rect.position.x + rect.size.x * 0.35
	ci.draw_rect(Rect2(cx - 24.0, gy - 20.0, 48.0, 20.0), UITheme.INK, false, 2.0)
	ci.draw_arc(Vector2(cx - 14.0, gy), 8.0, 0.0, TAU, 14, UITheme.INK, 2.0)
	ci.draw_line(Vector2(cx + 24.0, gy - 10.0), Vector2(cx + 44.0, gy - 24.0), UITheme.INK, 2.0)
	for i in range(2):
		var bx: float = rect.end.x - rect.size.x * (0.18 + 0.12 * float(i))
		ci.draw_rect(Rect2(bx - 8.0, gy - 16.0, 16.0, 16.0), UITheme.INK, false, 2.0)

static func _draw_chasm(ci: CanvasItem, rect: Rect2, gy: float, rng: RandomNumberGenerator) -> void:
	var x0: float = rect.position.x + rect.size.x * 0.42
	var x1: float = rect.position.x + rect.size.x * 0.58
	ci.draw_rect(Rect2(x0, gy, x1 - x0, rect.end.y - gy), Color(0.15, 0.11, 0.07, 0.5))
	ci.draw_line(Vector2(x0, gy), Vector2(x0, gy + 30.0), UITheme.INK, 2.0)
	ci.draw_line(Vector2(x1, gy), Vector2(x1, gy + 30.0), UITheme.INK, 2.0)
	ci.draw_line(Vector2(x1, gy), Vector2(rect.end.x, gy - 14.0), UITheme.INK, 2.0)

static func _draw_storm(ci: CanvasItem, rect: Rect2, gy: float, rng: RandomNumberGenerator) -> void:
	var soft: Color = Color(UITheme.INK.r, UITheme.INK.g, UITheme.INK.b, 0.5)
	for i in range(3):
		var yy: float = gy - float(i) * 10.0
		var pts := PackedVector2Array()
		for s in range(17):
			var t: float = float(s) / 16.0
			pts.append(Vector2(rect.position.x + rect.size.x * t, yy + sin(t * TAU + float(i)) * 6.0))
		ci.draw_polyline(pts, soft, 1.5)
	var wind: Color = Color(UITheme.INK.r, UITheme.INK.g, UITheme.INK.b, 0.2)
	for i in range(8):
		var bx: float = rect.position.x + rect.size.x * (0.1 + 0.1 * float(i))
		ci.draw_line(Vector2(bx, rect.position.y + 10.0), Vector2(bx - 20.0, rect.position.y + 40.0), wind, 1.5)

static func _draw_gate(ci: CanvasItem, rect: Rect2, gy: float, rng: RandomNumberGenerator) -> void:
	var cx: float = rect.position.x + rect.size.x * 0.5
	ci.draw_line(Vector2(cx, gy), Vector2(cx, gy - 50.0), UITheme.INK, 2.5)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(cx, gy - 50.0), Vector2(cx + 22.0, gy - 42.0), Vector2(cx, gy - 34.0)]), UITheme.INK)

static func _draw_dunes(ci: CanvasItem, rect: Rect2, gy: float, rng: RandomNumberGenerator) -> void:
	var pts := PackedVector2Array()
	for s in range(17):
		var t: float = float(s) / 16.0
		pts.append(Vector2(rect.position.x + rect.size.x * t, gy - 8.0 - sin(t * TAU * 1.3) * 10.0))
	ci.draw_polyline(pts, UITheme.INK, 1.5)
