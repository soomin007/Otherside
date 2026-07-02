class_name Figures
extends Control

## 인물·사물 초상 — 마을 준비 화면용. kind: "market"(시장)·"leader"(대장)·"pack"(배낭).
## 손그림 초상 텍스처(흰→투명 변환본)를 얹는다. 로드 실패 시 절차적 draw_*(웹 안전) fallback.
## 다크 배경/카드 위에 얹히므로 투명 PNG 그대로 얹혀 읽힌다.

## kind → 초상 텍스처(투명 변환본).
const PORTRAIT_PATHS: Dictionary = {
	"market": "res://assets/arts/transparent/19_초상_시장.png",
	"leader": "res://assets/arts/transparent/20_초상_대장.png",
	"pack": "res://assets/arts/transparent/21_초상_배낭.png",
}
static var _tex_cache: Dictionary = {}   ## kind → Texture2D (null 도 캐시 = 반복 로드 방지)

var kind: String = "leader"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_kind(k: String) -> void:
	kind = k
	queue_redraw()

func _draw() -> void:
	var s: Vector2 = size
	if s.x < 8.0 or s.y < 8.0:
		return
	var tex: Texture2D = _portrait_tex(kind)
	if tex != null:
		_draw_contain(tex, s)   # 초상 이미지(종횡비 유지, 안 잘리게 contain·중앙)
		return
	match kind:
		"market": _market(s)
		"pack": _pack(s)
		_: _leader(s)

## kind 초상 텍스처(1회 로드 후 캐시). 미등록 kind 는 null → 절차적 fallback.
static func _portrait_tex(k: String) -> Texture2D:
	if not PORTRAIT_PATHS.has(k):
		return null
	if _tex_cache.has(k):
		return _tex_cache[k]
	var path: String = str(PORTRAIT_PATHS[k])
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	_tex_cache[k] = tex
	return tex

## 텍스처를 s 안에 종횡비 유지로 다 담는다(contain — 잘리지 않게, 가운데 정렬).
func _draw_contain(tex: Texture2D, s: Vector2) -> void:
	var tw: float = float(tex.get_width())
	var th: float = float(tex.get_height())
	if tw <= 0.0 or th <= 0.0:
		return
	var sc: float = minf(s.x / tw, s.y / th)
	var sz: Vector2 = Vector2(tw * sc, th * sc)
	draw_texture_rect(tex, Rect2((s - sz) * 0.5, sz), false)

## 시장 — 터번 쓴 사막 상인 흉상.
func _market(s: Vector2) -> void:
	var cx: float = s.x * 0.5
	var fill := Color(0.72, 0.60, 0.42)
	var dark := Color(0.30, 0.24, 0.16)
	var base: float = s.y * 0.98
	var fr: float = minf(s.x, s.y) * 0.16
	var fy: float = s.y * 0.06 + fr * 1.6
	# 어깨/로브
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - s.x * 0.34, base), Vector2(cx - s.x * 0.20, fy + fr * 1.2),
		Vector2(cx + s.x * 0.20, fy + fr * 1.2), Vector2(cx + s.x * 0.34, base)]), fill)
	draw_rect(Rect2(cx - fr * 0.4, fy + fr * 0.55, fr * 0.8, fr * 0.9), fill)  # 목
	draw_circle(Vector2(cx, fy), fr, fill)  # 얼굴
	# 터번 (얼굴 위 반원 + 밴드)
	var turb := PackedVector2Array()
	for a in range(13):
		var ang: float = PI + PI * float(a) / 12.0
		turb.append(Vector2(cx + cos(ang) * fr * 1.2, fy - fr * 0.15 + sin(ang) * fr * 1.05))
	draw_colored_polygon(turb, dark)
	draw_rect(Rect2(cx - fr * 1.15, fy - fr * 0.2, fr * 2.3, fr * 0.42), dark)
	# 수염 + 눈
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - fr * 0.6, fy + fr * 0.35), Vector2(cx, fy + fr * 1.15), Vector2(cx + fr * 0.6, fy + fr * 0.35)]),
		Color(0.55, 0.54, 0.55))
	draw_circle(Vector2(cx - fr * 0.38, fy), 2.5, UITheme.INK)
	draw_circle(Vector2(cx + fr * 0.38, fy), 2.5, UITheme.INK)

## 대장 — 후드/망토 쓴 원정대장 흉상(얼굴은 그늘, 눈빛 두 점).
func _leader(s: Vector2) -> void:
	var cx: float = s.x * 0.5
	var fill := Color(0.55, 0.45, 0.30)
	var hood := Color(0.34, 0.27, 0.18)
	var base: float = s.y * 0.98
	var fr: float = minf(s.x, s.y) * 0.15
	var fy: float = s.y * 0.08 + fr * 1.8
	# 망토
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - s.x * 0.38, base), Vector2(cx - s.x * 0.16, fy),
		Vector2(cx + s.x * 0.16, fy), Vector2(cx + s.x * 0.38, base)]), fill)
	# 후드 (얼굴 감싸는 큰 반원)
	var hd := PackedVector2Array()
	for a in range(15):
		var ang: float = PI + PI * float(a) / 14.0
		hd.append(Vector2(cx + cos(ang) * fr * 1.5, fy + sin(ang) * fr * 1.7))
	draw_colored_polygon(hd, hood)
	draw_circle(Vector2(cx, fy), fr * 0.85, Color(0.12, 0.10, 0.08))  # 얼굴 그늘
	draw_circle(Vector2(cx - fr * 0.32, fy - fr * 0.1), 2.0, Color(0.85, 0.80, 0.60, 0.85))
	draw_circle(Vector2(cx + fr * 0.32, fy - fr * 0.1), 2.0, Color(0.85, 0.80, 0.60, 0.85))

## 배낭 — 뚜껑·앞주머니·끈·버클.
func _pack(s: Vector2) -> void:
	var cx: float = s.x * 0.5
	var canvas := Color(0.50, 0.40, 0.26)
	var strap := Color(0.34, 0.26, 0.16)
	var dark := UITheme.INK
	var w: float = minf(s.x * 0.5, s.y * 0.7)
	var h: float = w * 1.15
	var x: float = cx - w * 0.5
	var y: float = s.y * 0.5 - h * 0.42
	draw_rect(Rect2(x, y, w, h), canvas)                                   # 몸통
	draw_rect(Rect2(x - w * 0.04, y - h * 0.02, w * 1.08, h * 0.34), strap) # 뚜껑
	draw_rect(Rect2(cx - w * 0.24, y + h * 0.5, w * 0.48, h * 0.34), strap) # 앞주머니
	draw_line(Vector2(x + w * 0.2, y), Vector2(x + w * 0.1, y + h), dark, 3.0)  # 끈
	draw_line(Vector2(x + w * 0.8, y), Vector2(x + w * 0.9, y + h), dark, 3.0)
	draw_rect(Rect2(cx - w * 0.08, y + h * 0.32, w * 0.16, h * 0.06), dark)     # 버클
