class_name Backdrop
extends Control

## 사막 밤 공통 배경 — 손그림 배경 텍스처(23)를 화면에 꽉 채운다(cover).
## 타이틀·오프닝 등 다크 UI 화면에 첫 자식으로 깔아 톤을 통일한다. 지도·단면은 자체 양피지라 여기 안 쓴다.
## 로드 실패 시 절차적 세로 그라데이션 + 별 + (village 면 마을 실루엣)으로 fallback(웹 안전).

const BG_PATH: String = "res://assets/arts/23_배경_공통.png"
const BG_PATH_LAND: String = "res://assets/arts/23_배경_공통_가로.png"  ## 가로(데스크톱)용 — 있으면 가로 화면에서 우선
static var _bg_tex: Texture2D
static var _bg_tex_land: Texture2D
static var _bg_loaded: bool = false   ## 1회만 로드 시도(세로+가로 둘 다)

var scene_kind: String = ""  ## "village" 면 (fallback 시) 지평선 좌우에 마을 실루엣. 중앙 UI 는 피한다.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	var r: Vector2 = get_viewport_rect().size
	if r.x <= 0.0 or r.y <= 0.0:
		return
	var tex: Texture2D = _common_tex(r.x > r.y)   # 가로 화면이면 가로판 우선
	if tex != null:
		_draw_cover(tex, r)   # 손그림 밤 배경(종횡비 유지 cover)
		return
	# --- 이하 fallback: 절차적 밤 배경 ---
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

## 원정 준비(마을) 화면 — 지평선 좌우에 밀도있는 사막 도시 실루엣(건물·돔·탑·등불).
## 중앙(가방 UI, x 0.27~0.73)은 비워 가독성 유지. 결정론 시드.
func _draw_village(r: Vector2, horizon: float) -> void:
	var sil := Color(0.08, 0.065, 0.05)  # 지평선보다 어두운 실루엣
	var rng := RandomNumberGenerator.new()
	rng.seed = 4127
	_city_cluster(r.x * 0.00, r.x * 0.27, horizon, rng, sil)   # 좌측 도시
	_city_cluster(r.x * 0.73, r.x * 1.00, horizon, rng, sil)   # 우측 도시

## x0~x1 에 건물을 겹쳐 채운다(밀도). 종류: 사각 건물·돔·탑, 일부 창에 등불.
func _city_cluster(x0: float, x1: float, horizon: float, rng: RandomNumberGenerator, sil: Color) -> void:
	var x: float = x0
	while x < x1:
		var w: float = rng.randf_range(22.0, 46.0)
		var h: float = rng.randf_range(26.0, 78.0)
		var kind: int = rng.randi_range(0, 3)
		if kind == 2:
			# 탑/미너렛 — 높고 좁게 + 뾰족 지붕
			var tw: float = w * 0.55
			var ty: float = horizon - h * 1.5
			draw_rect(Rect2(x, ty, tw, h * 1.5), sil)
			draw_colored_polygon(PackedVector2Array([
				Vector2(x - 2.0, ty), Vector2(x + tw * 0.5, ty - 13.0), Vector2(x + tw + 2.0, ty)]), sil)
		elif kind == 1:
			# 돔 건물 — 사각 몸통 + 반원 돔
			var by: float = horizon - h * 0.6
			draw_rect(Rect2(x, by, w, h * 0.6), sil)
			var dome := PackedVector2Array()
			var cx: float = x + w * 0.5
			for a in range(11):
				var ang: float = PI + PI * float(a) / 10.0
				dome.append(Vector2(cx + cos(ang) * w * 0.5, by + sin(ang) * w * 0.5))
			draw_colored_polygon(dome, sil)
		else:
			# 사각 건물 — 가끔 창에 등불
			draw_rect(Rect2(x, horizon - h, w, h), sil)
			if rng.randf() < 0.35:
				draw_circle(Vector2(x + w * 0.5, horizon - h * rng.randf_range(0.3, 0.7)), 2.0, Color(1.0, 0.72, 0.32, 0.45))
		x += w * rng.randf_range(0.62, 0.92)  # 겹쳐서 밀도를 낸다

## 공통 배경 텍스처(1회 로드 후 static 캐시 — 여러 화면이 각자 Backdrop 을 만들어도 로드 1회).
static func _common_tex(landscape: bool) -> Texture2D:
	if not _bg_loaded:
		_bg_loaded = true
		if ResourceLoader.exists(BG_PATH):
			_bg_tex = load(BG_PATH)
		if ResourceLoader.exists(BG_PATH_LAND):
			_bg_tex_land = load(BG_PATH_LAND)
	if landscape and _bg_tex_land != null:
		return _bg_tex_land
	return _bg_tex

## 텍스처를 r 영역에 종횡비 유지로 꽉 채운다(cover — 넘치는 쪽을 잘라 여백/왜곡 없음).
func _draw_cover(tex: Texture2D, r: Vector2) -> void:
	var tw: float = float(tex.get_width())
	var th: float = float(tex.get_height())
	if tw <= 0.0 or th <= 0.0:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, r), false)
		return
	var ra: float = r.x / r.y
	var ta: float = tw / th
	var src := Rect2(0.0, 0.0, tw, th)
	if ta > ra:
		var sw: float = th * ra
		src = Rect2((tw - sw) * 0.5, 0.0, sw, th)
	else:
		var sh: float = tw / ra
		src = Rect2(0.0, (th - sh) * 0.5, tw, sh)
	draw_texture_rect_region(tex, Rect2(Vector2.ZERO, r), src)
