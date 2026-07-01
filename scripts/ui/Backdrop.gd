class_name Backdrop
extends Control

## 사막 밤 공통 배경 — 세로 그라데이션(밤하늘 → 모래 지평선) + 지평선 + 은은한 별·모래결.
## 타이틀·마을·오프닝 등 다크 UI 화면에 첫 자식으로 깔아 톤을 통일한다. 전부 절차적 draw(웹 안전).
## 지도·단면은 자체 양피지 배경이라 여기 안 쓴다.

var scene_kind: String = ""  ## "village" 면 지평선 좌우에 마을 실루엣(원정 준비 화면). 중앙 UI 는 피한다.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	var r: Vector2 = get_viewport_rect().size
	if r.x <= 0.0 or r.y <= 0.0:
		return
	var horizon: float = r.y * 0.70

	# 세로 그라데이션 — 위 밤하늘, 아래 모래.
	var top: Color = UITheme.BG_TOP
	var mid: Color = UITheme.BG_BOT
	draw_polygon(
		PackedVector2Array([Vector2(0.0, 0.0), Vector2(r.x, 0.0), Vector2(r.x, horizon), Vector2(0.0, horizon)]),
		PackedColorArray([top, top, mid, mid]))
	# 지평선 아래 — 모래 바닥(살짝 밝은 황토).
	draw_rect(Rect2(0.0, horizon, r.x, r.y - horizon), UITheme.SAND_FLOOR)

	# 은은한 별 (지평선 위, 결정론 시드).
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260701
	for i in range(60):
		var sx: float = rng.randf() * r.x
		var sy: float = rng.randf() * (horizon - 8.0)
		var a: float = rng.randf_range(0.10, 0.40)
		draw_circle(Vector2(sx, sy), rng.randf_range(0.7, 1.5), Color(0.92, 0.93, 1.0, a))

	# 지평선 선 + 아래 은은한 모래결(결정론 sin).
	draw_line(Vector2(0.0, horizon), Vector2(r.x, horizon), UITheme.HORIZON, 1.5)
	var line_col := Color(UITheme.INK.r, UITheme.INK.g, UITheme.INK.b, 0.05)
	for j in range(1, 4):
		var base_y: float = horizon + (r.y - horizon) * float(j) / 4.0
		var pts := PackedVector2Array()
		for s in range(21):
			var t: float = float(s) / 20.0
			pts.append(Vector2(r.x * t, base_y + sin(t * TAU * 1.2 + float(j)) * 5.0))
		draw_polyline(pts, line_col, 1.0)

	if scene_kind == "village":
		_draw_village(r, horizon)

## 원정 준비(마을) 화면 — 지평선 좌우에 천막·모닥불 실루엣. 중앙(가방 UI)은 비워 가독성 유지.
func _draw_village(r: Vector2, horizon: float) -> void:
	var sil := Color(0.085, 0.07, 0.055)  # 지평선보다 어두운 실루엣
	# 좌측 마을 무리
	_tent(Vector2(r.x * 0.07, horizon), 48.0, sil)
	_tent(Vector2(r.x * 0.14, horizon), 34.0, sil)
	_tent(Vector2(r.x * 0.205, horizon), 40.0, sil)
	# 우측 무리
	_tent(Vector2(r.x * 0.86, horizon), 44.0, sil)
	_tent(Vector2(r.x * 0.93, horizon), 32.0, sil)
	# 모닥불 글로우(좌측 천막 곁)
	var fire := Vector2(r.x * 0.11, horizon - 5.0)
	draw_circle(fire, 8.0, Color(0.9, 0.5, 0.2, 0.20))
	draw_circle(fire, 3.5, Color(1.0, 0.72, 0.32, 0.5))

func _tent(base: Vector2, w: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-w * 0.5, 0.0), base + Vector2(0.0, -w * 0.85), base + Vector2(w * 0.5, 0.0)]), col)
