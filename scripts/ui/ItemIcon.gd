class_name ItemIcon
extends Control

## 아이템 하나를 그린다(가방 슬롯·책상 등). 손그림 삽화(투명 PNG, 30~37)가 있으면 그걸,
## 없으면 key별 절차적 글리프로 fallback(웹 안전 — 셰이더/GPUParticles 없음). 아트 준비되면 자동 교체.

const ART_PATHS: Dictionary = {
	"water": "res://assets/arts/transparent/30_아이템_물통.png",
	"food": "res://assets/arts/transparent/31_아이템_식량.png",
	"jerky": "res://assets/arts/transparent/32_아이템_말린고기.png",
	"rope": "res://assets/arts/transparent/33_아이템_로프.png",
	"shelter": "res://assets/arts/transparent/34_아이템_은신막.png",
	"medicine": "res://assets/arts/transparent/35_아이템_약초.png",
	"flint": "res://assets/arts/transparent/36_아이템_부싯돌.png",
	"filter": "res://assets/arts/transparent/37_아이템_정화천.png",
}
static var _tex_cache: Dictionary = {}   ## key → Texture2D (null 도 캐시)

# 글리프 팔레트 (세피아 계열).
const CANVAS: Color = Color(0.60, 0.49, 0.31)  ## 캔버스·가죽
const DARK: Color = Color(0.28, 0.21, 0.13)    ## 어두운 디테일·끈
const WATER_C: Color = Color(0.44, 0.56, 0.63) ## 물빛
const LEAF: Color = Color(0.47, 0.56, 0.36)    ## 약초
const STONE: Color = Color(0.52, 0.52, 0.55)   ## 부싯돌
const SPARK: Color = Color(0.95, 0.75, 0.35)   ## 불똥

var key: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_key(k: String) -> void:
	if key == k:
		return
	key = k
	queue_redraw()

func _draw() -> void:
	var s: Vector2 = size
	if s.x < 6.0 or s.y < 6.0:
		return
	var tex: Texture2D = _art(key)
	if tex != null:
		_draw_contain(tex, s)   # 손그림 삽화(종횡비 유지, 안 잘리게)
		return
	# 절차적 글리프 — 중앙 정사각 기준(r = 반경).
	var r: float = minf(s.x, s.y) * 0.42
	var c: Vector2 = s * 0.5
	match key:
		"water": _g_water(c, r)
		"food": _g_food(c, r)
		"jerky": _g_jerky(c, r)
		"rope": _g_rope(c, r)
		"shelter": _g_shelter(c, r)
		"medicine": _g_medicine(c, r)
		"flint": _g_flint(c, r)
		"filter": _g_filter(c, r)
		_: _g_generic(c, r)

static func _art(k: String) -> Texture2D:
	if not ART_PATHS.has(k):
		return null
	if _tex_cache.has(k):
		return _tex_cache[k]
	var path: String = str(ART_PATHS[k])
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	_tex_cache[k] = tex
	return tex

func _draw_contain(tex: Texture2D, s: Vector2) -> void:
	var tw: float = float(tex.get_width())
	var th: float = float(tex.get_height())
	if tw <= 0.0 or th <= 0.0:
		return
	var sc: float = minf(s.x / tw, s.y / th)
	var sz: Vector2 = Vector2(tw * sc, th * sc)
	draw_texture_rect(tex, Rect2((s - sz) * 0.5, sz), false)

# --- 절차적 글리프 (아트 없을 때 fallback) ---

func _g_water(c: Vector2, r: float) -> void:  # 물통 — 둥근 몸통 + 짧은 목
	draw_circle(c + Vector2(0.0, r * 0.18), r * 0.78, WATER_C)
	draw_arc(c + Vector2(0.0, r * 0.18), r * 0.78, 0.0, TAU, 28, DARK, 2.0)
	draw_rect(Rect2(c.x - r * 0.2, c.y - r * 0.95, r * 0.4, r * 0.55), DARK)  # 목
	draw_arc(c + Vector2(-r * 0.28, r * 0.1), r * 0.3, PI * 0.9, PI * 1.5, 8, Color(1, 1, 1, 0.25), 3.0)  # 하이라이트

func _g_food(c: Vector2, r: float) -> void:  # 식량 자루 — 묶은 목의 자루
	var top: float = c.y - r * 0.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - r * 0.55, c.y + r * 0.85), Vector2(c.x - r * 0.7, top),
		Vector2(c.x + r * 0.7, top), Vector2(c.x + r * 0.55, c.y + r * 0.85)]), CANVAS)
	draw_rect(Rect2(c.x - r * 0.45, top - r * 0.28, r * 0.9, r * 0.28), DARK)  # 묶은 목
	for i in range(2):  # 삐죽한 주둥이
		draw_line(Vector2(c.x - r * 0.2 + r * 0.4 * float(i), top - r * 0.28),
			Vector2(c.x - r * 0.3 + r * 0.6 * float(i), top - r * 0.6), DARK, 2.0)

func _g_jerky(c: Vector2, r: float) -> void:  # 말린 고기 — 끈에 걸린 두 조각
	draw_line(Vector2(c.x - r, c.y - r * 0.7), Vector2(c.x + r, c.y - r * 0.7), DARK, 2.0)
	for i in range(2):
		var x: float = c.x - r * 0.45 + r * 0.9 * float(i)
		var strip := PackedVector2Array([
			Vector2(x - r * 0.22, c.y - r * 0.6), Vector2(x + r * 0.22, c.y - r * 0.5),
			Vector2(x + r * 0.28, c.y + r * 0.75), Vector2(x - r * 0.16, c.y + r * 0.65)])
		draw_colored_polygon(strip, Color(0.46, 0.28, 0.18))
		draw_polyline(strip, DARK, 1.5)

func _g_rope(c: Vector2, r: float) -> void:  # 로프 — 감긴 사리
	draw_arc(c, r * 0.85, 0.0, TAU, 28, CANVAS, 5.0)
	draw_arc(c, r * 0.55, 0.0, TAU, 24, CANVAS, 5.0)
	draw_arc(c, r * 0.85, 0.0, TAU, 28, DARK, 1.0)
	draw_arc(c, r * 0.55, 0.0, TAU, 24, DARK, 1.0)

func _g_shelter(c: Vector2, r: float) -> void:  # 은신막 — 접힌 천(삼각 천막꼴)
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x, c.y - r * 0.8), Vector2(c.x + r * 0.85, c.y + r * 0.7),
		Vector2(c.x - r * 0.85, c.y + r * 0.7)]), CANVAS)
	draw_line(Vector2(c.x, c.y - r * 0.8), Vector2(c.x, c.y + r * 0.7), DARK, 2.0)  # 접힌 선
	draw_line(Vector2(c.x - r * 0.85, c.y + r * 0.7), Vector2(c.x + r * 0.85, c.y + r * 0.7), DARK, 2.0)

func _g_medicine(c: Vector2, r: float) -> void:  # 약초 꾸러미 — 잎다발 + 묶음
	for i in range(3):
		var ang: float = -PI * 0.5 + (float(i) - 1.0) * 0.5
		var tip: Vector2 = c + Vector2(cos(ang), sin(ang)) * r * 0.9
		draw_line(c + Vector2(0.0, r * 0.4), tip, LEAF, 4.0)
		draw_circle(tip, r * 0.16, LEAF)
	draw_rect(Rect2(c.x - r * 0.22, c.y + r * 0.35, r * 0.44, r * 0.3), DARK)  # 묶음

func _g_flint(c: Vector2, r: float) -> void:  # 부싯돌 — 돌 + 불똥
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - r * 0.7, c.y + r * 0.3), Vector2(c.x - r * 0.1, c.y - r * 0.1),
		Vector2(c.x + r * 0.1, c.y + r * 0.5), Vector2(c.x - r * 0.5, c.y + r * 0.7)]), STONE)
	for i in range(4):  # 불똥
		var ang: float = -PI * 0.4 + float(i) * 0.35
		draw_line(c + Vector2(r * 0.1, c.y * 0.0 - r * 0.1),
			c + Vector2(cos(ang), sin(ang)) * r * 0.85 + Vector2(r * 0.15, -r * 0.1), SPARK, 1.5)

func _g_filter(c: Vector2, r: float) -> void:  # 정화천 — 천 + 물방울
	draw_arc(c + Vector2(0.0, -r * 0.3), r * 0.7, 0.0, PI, 16, CANVAS, 3.0)  # 천 테두리(둥근 걸침)
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - r * 0.7, c.y - r * 0.3), Vector2(c.x + r * 0.7, c.y - r * 0.3),
		Vector2(c.x + r * 0.35, c.y + r * 0.3), Vector2(c.x - r * 0.35, c.y + r * 0.3)]), Color(CANVAS.r, CANVAS.g, CANVAS.b, 0.75))
	draw_circle(c + Vector2(0.0, r * 0.7), r * 0.18, WATER_C)  # 방울

func _g_generic(c: Vector2, r: float) -> void:
	draw_rect(Rect2(c.x - r * 0.6, c.y - r * 0.6, r * 1.2, r * 1.2), CANVAS)
	draw_rect(Rect2(c.x - r * 0.6, c.y - r * 0.6, r * 1.2, r * 1.2), DARK, false, 2.0)
