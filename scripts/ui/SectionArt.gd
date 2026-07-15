class_name SectionArt
extends RefCounted

## 도착 노드 단면의 그림 (static draw 헬퍼) — 웹 안전(셰이더/GPUParticles 없음).
## kind별 손그림 배경 텍스처(불투명)를 rect 에 얹는다. 로드 실패 시 절차적 세피아 측단면으로 fallback
## (에셋 없어도 안 깨짐). node_id 시드는 fallback 실루엣의 결정론에만 쓴다(같은 노드 같은 그림).

## kind → 단면 배경 이미지. 없는 kind 는 dunes(기본 사막)로 대체.
const SECTION_PATHS: Dictionary = {
	"start": "res://assets/arts/13_단면_마을.png",
	"cache": "res://assets/arts/14_단면_폐허.png",
	"blockage": "res://assets/arts/15_단면_갈라진바닥.png",
	"storm": "res://assets/arts/16_단면_모래폭풍.png",
	"end": "res://assets/arts/17_단면_재앙의자리.png",
	"dunes": "res://assets/arts/18_단면_사막.png",
}

## 노드별 맞춤 단면(§17, 2026-07-14) — kind 공용 커버 해소(오아시스가 "폐허" 그림을 쓰는 식).
## 있으면 kind 공용보다 우선, 없으면 kind → 절차적 순 fallback(생성 전에도 안 깨짐 — 지도 아이콘과 같은 패턴).
const NODE_SECTION_PATHS: Dictionary = {
	"a1": "res://assets/arts/72_단면_마른강.png",
	"b1": "res://assets/arts/73_단면_버려진야영지.png",
	"c1": "res://assets/arts/74_단면_오아시스.png",
	"d1": "res://assets/arts/75_단면_뼈의들판.png",
	"d2": "res://assets/arts/76_단면_독웅덩이.png",
	"c2": "res://assets/arts/77_단면_모래의벽.png",
	"e1": "res://assets/arts/78_단면_무너진담.png",
	"f1": "res://assets/arts/79_단면_폭풍의문.png",
}

## kind → Texture2D 캐시(null 도 캐시 = 반복 로드 시도 방지). draw_section 이 매 프레임 불려도 1회만 로드.
static var _tex_cache: Dictionary = {}
static var _label_pool: GradientTexture2D  ## 지점 라벨 뒤 크림 빛 웅덩이 — 사진 위 가독(지도 라벨과 같은 결)

## 지점 마커 킷(2026-07-12, §16) — 손그림 잉크 고리(후광 구움). 없으면 절차적 링 fallback.
const SPOT_TEX_PATHS: Dictionary = {
	"main": "res://assets/arts/transparent/67_기호_주요지점.png",
	"sub": "res://assets/arts/transparent/68_기호_보조지점.png",
}
static var _spot_tex_cache: Dictionary = {}

static func _spot_tex(is_main: bool) -> Texture2D:
	var key: String = "main" if is_main else "sub"
	if _spot_tex_cache.has(key):
		return _spot_tex_cache[key]
	var path: String = str(SPOT_TEX_PATHS[key])
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	_spot_tex_cache[key] = tex
	return tex

## 텍스처를 중심점에 종횡비 유지(긴 변 = target)로, 필요 시 modulate 로 흐리게 얹는다.
static func draw_tex_center(ci: CanvasItem, tex: Texture2D, center: Vector2, target: float, mod: Color = Color.WHITE) -> void:
	var tw: float = float(tex.get_width())
	var th: float = float(tex.get_height())
	if tw <= 0.0 or th <= 0.0:
		return
	var s: float = target / maxf(tw, th)
	var wh: Vector2 = Vector2(tw * s, th * s)
	ci.draw_texture_rect(tex, Rect2(center - wh * 0.5, wh), false, mod)

## 단면 배경 + 지면 + kind별 실루엣을 rect 안에 그린다. 노드 맞춤 > kind 공용 > 절차적 순.
## seed_id = node_id(호출부 둘 다) — 맞춤 아트 키와 fallback 실루엣 시드를 겸한다.
static func draw_section(ci: CanvasItem, kind: String, rect: Rect2, seed_id: String) -> void:
	var tex: Texture2D = _node_tex(seed_id)
	if tex == null:
		tex = _section_tex(kind)
	if tex != null:
		_draw_cover(ci, tex, rect)                      # 배경 이미지(종횡비 유지 cover)
		ci.draw_rect(rect, UITheme.PAPER_EDGE, false, 3.0)  # 낡은 가장자리(양피지와 통일)
		return
	# fallback — 절차적 세피아 측단면(웹 안전, 에셋 없어도 안 깨짐).
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

## 노드 맞춤 배경(1회 로드 후 캐시, null 도 캐시). 미생성이면 null → kind 공용으로.
static func _node_tex(node_id: String) -> Texture2D:
	if not NODE_SECTION_PATHS.has(node_id):
		return null
	var key: String = "node_" + node_id
	if _tex_cache.has(key):
		return _tex_cache[key]
	var path: String = str(NODE_SECTION_PATHS[node_id])
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	_tex_cache[key] = tex
	return tex

## kind 의 배경 텍스처(1회 로드 후 캐시). 미등록 kind 는 dunes 로.
static func _section_tex(kind: String) -> Texture2D:
	var key: String = kind if SECTION_PATHS.has(kind) else "dunes"
	if _tex_cache.has(key):
		return _tex_cache[key]
	var path: String = str(SECTION_PATHS[key])
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	_tex_cache[key] = tex
	return tex

## 텍스처를 rect 에 종횡비 유지로 꽉 채운다(cover — 넘치는 쪽을 잘라 여백/왜곡 없음).
static func _draw_cover(ci: CanvasItem, tex: Texture2D, rect: Rect2) -> void:
	var tw: float = float(tex.get_width())
	var th: float = float(tex.get_height())
	if tw <= 0.0 or th <= 0.0:
		ci.draw_texture_rect(tex, rect, false)
		return
	var ra: float = rect.size.x / rect.size.y
	var ta: float = tw / th
	var src := Rect2(0.0, 0.0, tw, th)
	if ta > ra:                                  # 이미지가 더 넓다 → 좌우를 잘라 세로 기준 맞춤
		var sw: float = th * ra
		src = Rect2((tw - sw) * 0.5, 0.0, sw, th)
	else:                                        # 이미지가 더 높다 → 위아래를 잘라 가로 기준 맞춤
		var sh: float = tw / ra
		src = Rect2(0.0, (th - sh) * 0.5, tw, sh)
	ci.draw_texture_rect_region(tex, rect, src)

## 지점 마커. state: 0=조사가능(붉은 링) 1=완료(체크·흐림) 2=잠김(예산0·흐림)
## is_main = 노드의 본 사건(도착 이벤트) — 채집 지점보다 크고 이중 링으로 눈에 띈다.
static func draw_spot(ci: CanvasItem, font: Font, center: Vector2, label: String, state: int, is_main: bool = false) -> void:
	var r: float = 20.0 if is_main else 15.0   # 너무 크고 강렬 → 축소(2026-07-12 사용자)
	var faded: Color = UITheme.INK_FADE
	var ring_tex: Texture2D = _spot_tex(is_main)
	if state == 0:
		if ring_tex != null:
			# 손그림 잉크 고리(킷 — 크림 후광 구움) + 밝은 그림 대비용 옅은 어두운 원반 + 중심 점(탭 지점).
			ci.draw_circle(center, r + 3.0, Color(0.0, 0.0, 0.0, 0.15))
			draw_tex_center(ci, ring_tex, center, (r + 9.0) * 2.0, Color(1.0, 1.0, 1.0, 0.88))
			ci.draw_circle(center, 4.0 if is_main else 3.0, UITheme.MARKER_INK)
		else:
			# fallback — 절차적 링(2026-07-09 시인성 보강판). 웹 안전(draw_circle/arc).
			ci.draw_circle(center, r + 6.0, Color(0.0, 0.0, 0.0, 0.30))
			ci.draw_arc(center, r + 4.0, 0.0, TAU, 40, Color(0.98, 0.91, 0.72, 0.6), 2.0)
			if is_main:
				ci.draw_arc(center, r + 9.0, 0.0, TAU, 44, Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.32), 1.5)
			ci.draw_arc(center, r, 0.0, TAU, 32, UITheme.MARKER_INK, 3.5 if is_main else 3.0)
			ci.draw_circle(center, 5.0 if is_main else 4.0, UITheme.MARKER_INK)
	else:
		# 살핀 곳/잠김 — 같은 고리를 흐리게(다 본 자리라는 표식만 남긴다).
		if ring_tex != null:
			draw_tex_center(ci, ring_tex, center, r * 2.0, Color(1.0, 1.0, 1.0, 0.38))
		else:
			ci.draw_arc(center, r, 0.0, TAU, 32, faded, 1.5)
		if state == 1:
			ci.draw_polyline(PackedVector2Array([center + Vector2(-6, 0), center + Vector2(-1, 5), center + Vector2(7, -6)]), faded, 2.0)
	if font != null and label != "":
		# 크림 웅덩이 — 어떤 그림 위에서도 라벨이 읽히게(예전엔 잉크색 맨글자라 그림에 묻혔다, 2026-07-06).
		if _label_pool == null:
			var pg := Gradient.new()
			# 글자가 앉는 안쪽은 평탄하게 진하게, 가장자리만 페이드 — 어두운 그림(독 웅덩이 진흙) 위
			# 잉크 글자 대비 확보(2026-07-15 폰 확인. 예전 0.5 지점부터 페이드라 긴 라벨 끝이 흐릿).
			pg.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
			pg.colors = PackedColorArray([
				Color(0.914, 0.839, 0.686, 0.88),
				Color(0.914, 0.839, 0.686, 0.60),
				Color(0.914, 0.839, 0.686, 0.0),
			])
			_label_pool = GradientTexture2D.new()
			_label_pool.gradient = pg
			_label_pool.fill = GradientTexture2D.FILL_RADIAL
			_label_pool.fill_from = Vector2(0.5, 0.5)
			_label_pool.fill_to = Vector2(0.98, 0.5)
			_label_pool.width = 128
			_label_pool.height = 64
		var pool_a: float = 1.0 if state == 0 else 0.55
		# 웅덩이 폭 = 글자 폭 비례 — 고정 156px 은 긴 라벨("앞선 이의 유품")의 양끝을 못 받쳤다(2026-07-15 폰 확인).
		var tw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, UITheme.FS_SMALL).x
		var pw: float = maxf(140.0, tw * 1.8)
		ci.draw_texture_rect(_label_pool, Rect2(center.x - pw * 0.5, center.y + r - 6.0, pw, 40.0), false, Color(1.0, 1.0, 1.0, pool_a))
		var lc: Color = UITheme.INK if state == 0 else faded
		ci.draw_string(font, center + Vector2(-(tw * 0.5 + 8.0), r + 20.0), label, HORIZONTAL_ALIGNMENT_CENTER, tw + 16.0, UITheme.FS_SMALL, lc)

## 낙오자 시각 힌트 — "웅크린 사람" 마커 위에 실제 웅크린 사람 스케치(지도·일지와 같은 킷 61).
## 마커만 있으면 뜬금없다는 지적(2026-07-15 사용자) — 크림 원반(라벨 웅덩이와 같은 결) + 온기 무리 위에
## 사람이 앉아, 어두운 그림에서도 "여기 사람이 있다"가 한눈에 읽히게 한다.
static func draw_straggler(ci: CanvasItem, marker_center: Vector2) -> void:
	var pos: Vector2 = marker_center + Vector2(0.0, -42.0)
	ci.draw_circle(pos, 27.0, Color(0.914, 0.839, 0.686, 0.5))
	ci.draw_circle(pos, 18.0, Color(0.86, 0.66, 0.38, 0.24))  # 옅은 온기 무리(지도 마커와 같은 신호)
	var tex: Texture2D = _straggler_tex()
	if tex != null:
		draw_tex_center(ci, tex, pos, 44.0)
		return
	# fallback — 절차적 웅크린 실루엣(Map._draw_person 과 같은 결. 웹 안전).
	var ink := Color(0.36, 0.24, 0.16, 0.92)
	ci.draw_circle(pos + Vector2(0.0, -10.0), 4.2, ink)
	ci.draw_line(pos + Vector2(-5.0, -5.0), pos + Vector2(-7.0, 7.5), ink, 2.6)
	ci.draw_line(pos + Vector2(0.0, -5.5), pos + Vector2(0.0, 8.0), ink, 2.9)
	ci.draw_line(pos + Vector2(5.0, -5.0), pos + Vector2(7.0, 7.5), ink, 2.6)

## 낙오자 스케치(1회 로드 후 캐시, null 도 캐시 — 에셋이 없어도 안 깨진다).
static func _straggler_tex() -> Texture2D:
	if _tex_cache.has("straggler"):
		return _tex_cache["straggler"]
	var path: String = "res://assets/arts/transparent/61_사람_낙오자.png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	_tex_cache["straggler"] = tex
	return tex

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
