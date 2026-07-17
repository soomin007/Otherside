extends SceneTree

## 배경 컬러키 → 투명 변환 도구 (로고 등 단색 배경 생성물 전용, alpha_key.gd 의 자매)
##
## 배경색을 모서리에서 자동 감지해 두 모드 중 하나로 키잉한다:
## - **마젠타 크로마키(#FF00FF, 권장)** — 마젠타 성분 m=min(r,b)-g 로 alpha 를 세우고,
##   c = f·a + key·(1-a) 를 풀어 진짜 전경색을 복원(언믹스). 모래·아이보리·갈색엔 마젠타가 없어
##   어두운 디테일까지 깨끗이 분리된다. 검정 모드의 내부 구멍 편법이 필요 없다(2026-07-18 사용자 제안).
## - 검정(#000000, 구판 호환) — 밝기를 alpha 로 되살린다(언프리멀티플라이). 어두운 디테일과 배경을
##   구분 못 해 내부 구멍 메움 편법이 붙는다. 새로 뽑을 땐 마젠타로.
##
## 실행 (대상은 인자로만 받는다 — 폴더 스캔 없음):
##   godot --headless --path . -s scripts/tools/black_key.gd -- <입력.png> <출력.png> [<입력2> <출력2> ...]
##
## 처리: ①~③ 키잉(모드별 — 마젠타 언믹스 / 검정 언프리멀티플라이+내부 구멍 메움)
##       ④ 여백 크롭(+MARGIN)
##       ⑤ 그림자 굽기 — 알파를 블러해 아래로 민 어두운 판을 밑에 깐다(밝은 키아트 위 가독. 셰이더 금지
##          제약이라 런타임 블러가 없어 에셋에 굽는다. 어두운 배경에선 안 보여 무해).
##       ⑥ 광학 중심 정렬 — 본체(alpha≥CENTER_A) bbox 중심이 캔버스 중심에 오도록 투명 여백을 비대칭 보정.
##          한쪽으로 뻗는 모래 뿌림이 bbox 를 늘려, 이미지째 가운데 정렬하면 글자가 옆으로 밀리는 것 방지
##          (2026-07-18 사용자 지적).
##       ⑦ MAX_W 초과 시 Lanczos 다운스케일
##
## 제약: -s 컨텍스트엔 autoload 없음 — 순수 Image API 만 쓴다(alpha_key 와 동일).

const FLOOR: float = 0.03   # 이 밝기 이하 = 배경 노이즈 → 완전 투명
const SOLID: float = 0.72   # 이 밝기 이상 = 그림 본체 → 완전 불투명
const HOLE_A: float = 0.98  # 이 alpha 미만을 '빈 곳 후보'로 보고 테두리 flood fill — 못 닿으면 내부 구멍
const MARGIN: int = 8       # 크롭 후 사방 여백(px)
const MAX_W: int = 1600     # 결과 최대 폭(로고 선명도 유지 선에서 다이어트)

# --- ⑤ 그림자 손잡이 ---
const SHADOW_A: float = 0.55            # 그림자 최대 진하기
const SHADOW_COL: Color = Color(0.04, 0.025, 0.015)  # 그림자 색(따뜻한 검정 — 세계 팔레트)
const SHADOW_OFF: Vector2i = Vector2i(0, 5)          # 그림자 오프셋(아래로)
const SHADOW_R: int = 3                 # 박스 블러 반경
const SHADOW_PASSES: int = 3            # 블러 반복(가우시안 근사)
const SHADOW_PAD: int = 16              # 블러·오프셋이 잘리지 않게 미리 키우는 캔버스 여백

# --- ⑥ 정렬 손잡이 ---
const DENS_FRAC: float = 0.10  # 열/행 알파 밀도가 최대치의 이 비율 이상이면 본체.
                               # 뿌림 입자는 밝아서 픽셀 alpha 로는 본체와 구분이 안 되고(1.0),
                               # 성긴 밀도로만 갈라진다 — 글자 열은 빽빽, 뿌림 열은 듬성.

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2 or args.size() % 2 != 0:
		print("사용법: -- <입력.png> <출력.png> [<입력2> <출력2> ...]")
		quit(1)
		return
	var fail: int = 0
	for i in range(0, args.size(), 2):
		if not _convert_one(str(args[i]), str(args[i + 1])):
			fail += 1
	print("=== black_key: %d개 중 %d 실패 ===" % [args.size() / 2, fail])
	quit(1 if fail > 0 else 0)

func _convert_one(src: String, dst: String) -> bool:
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(src))
	if img == null:
		print("FAIL 로드: ", src)
		return false
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()

	# ①~③ 키잉 — 배경색을 모서리에서 감지해 모드 결정
	var key: Color = _detect_key(img)
	var stats: PackedInt32Array
	if minf(key.r, key.b) - key.g > 0.5:
		stats = _key_chroma(img, key)  # 마젠타 크로마키 — 언믹스
	else:
		stats = _key_black(img)        # 검정(구판 호환) — 언프리멀티플라이 + 내부 구멍 메움
	var cleared: int = stats[0]
	var filled: int = stats[1]

	if img.detect_alpha() == Image.ALPHA_NONE:
		print("FAIL 투명픽셀 없음(문턱 재조정 필요): ", src)
		return false

	# ④ 여백 크롭
	var used: Rect2i = img.get_used_rect()
	if used.size.x > 0 and used.size.y > 0:
		used = used.grow(MARGIN)
		used = used.intersection(Rect2i(0, 0, w, h))
		img = img.get_region(used)

	# ⑤ 그림자 굽기 — 캔버스를 키우고, 알파 블러판을 오프셋해 원본 밑에 src-over 합성
	img = _bake_shadow(img)

	# ⑥ 광학 중심 정렬 — 본체 bbox 중심을 캔버스 중심으로(모자란 쪽에만 투명 여백 추가)
	img = _center_on_core(img)

	# ⑦ 폭 다이어트
	if img.get_width() > MAX_W:
		var nh: int = int(round(float(img.get_height()) * float(MAX_W) / float(img.get_width())))
		img.resize(MAX_W, nh, Image.INTERPOLATE_LANCZOS)

	var err: int = img.save_png(ProjectSettings.globalize_path(dst))
	if err != OK:
		print("FAIL 저장(", err, "): ", dst)
		return false
	print("OK  %s → %s  [%dx%d, 배경 %dpx 투명, 내부 메움 %dpx]" % [src.get_file(), dst, img.get_width(), img.get_height(), cleared, filled])
	return true

## 배경색 감지 — 네 모서리 8×8 패치 평균.
func _detect_key(img: Image) -> Color:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var sum: Vector3 = Vector3.ZERO
	var n: int = 0
	for corner in [Vector2i(0, 0), Vector2i(w - 8, 0), Vector2i(0, h - 8), Vector2i(w - 8, h - 8)]:
		for dy in range(8):
			for dx in range(8):
				var c: Color = img.get_pixel(corner.x + dx, corner.y + dy)
				sum += Vector3(c.r, c.g, c.b)
				n += 1
	return Color(sum.x / n, sum.y / n, sum.z / n)

## 마젠타 크로마키 — 마젠타 성분 m=min(r,b)-g 으로 alpha 를 세우고,
## c = f·a + key·(1-a) 를 풀어 전경색 복원(언믹스).
## 따뜻한 팔레트(초록>파랑)에선 이 alpha 가 과대해져 반투명 영역에 분홍이 남는다 —
## 본체 픽셀에서 팔레트의 파랑/초록 비율(ρ)을 학습해, 그 비율을 넘는 파랑을 마젠타 잔여로
## 보고 배경 몫으로 되돌린다(c = f·a + k·(1-a) 의 정확한 재매개화 — 합성 결과 불변).
func _key_chroma(img: Image, key: Color) -> PackedInt32Array:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var mk: float = minf(key.r, key.b) - key.g
	# 1패스 — 본체(alpha≈1) 픽셀로 팔레트 비율 ρ = Σ(b·g)/Σ(g²) (가중 최소제곱)
	var bg_sum: float = 0.0
	var gg_sum: float = 0.0
	for y in range(h):
		for x in range(w):
			var c: Color = img.get_pixel(x, y)
			var m: float = minf(c.r, c.b) - c.g
			if 1.0 - clampf(m / mk, 0.0, 1.0) >= 0.97 and c.g > 0.1:
				bg_sum += c.b * c.g
				gg_sum += c.g * c.g
	var rho: float = 0.75 if gg_sum <= 0.0 else clampf(bg_sum / gg_sum, 0.3, 0.95)
	# 2패스 — 키잉 + 잔여 마젠타 재배분
	var cleared: int = 0
	for y in range(h):
		for x in range(w):
			var c: Color = img.get_pixel(x, y)
			var m: float = minf(c.r, c.b) - c.g
			var a: float = 1.0 - clampf(m / mk, 0.0, 1.0)
			if a <= 0.06:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				cleared += 1
			elif a >= 0.97:
				img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
			else:
				var fr: float = clampf((c.r - key.r * (1.0 - a)) / a, 0.0, 1.0)
				var fg: float = clampf((c.g - key.g * (1.0 - a)) / a, 0.0, 1.0)
				var fb: float = clampf((c.b - key.b * (1.0 - a)) / a, 0.0, 1.0)
				var t: float = clampf(fb - rho * fg, 0.0, 0.85)  # 팔레트 비율 초과분 = 마젠타 잔여
				if t > 0.003:
					fr = clampf((fr - key.r * t) / (1.0 - t), 0.0, 1.0)
					fg = clampf((fg - key.g * t) / (1.0 - t), 0.0, 1.0)
					fb = clampf((fb - key.b * t) / (1.0 - t), 0.0, 1.0)
					a = a * (1.0 - t)
				img.set_pixel(x, y, Color(fr, fg, fb, a))
	return PackedInt32Array([cleared, 0])

## 검정 키(구판 호환) — 밝기 램프 언프리멀티플라이 + 내부 구멍 메움 + 글자 속 구멍 재분류.
func _key_black(img: Image) -> PackedInt32Array:
	var w: int = img.get_width()
	var h: int = img.get_height()
	# ① 밝기 램프 alpha 맵
	var amap: PackedFloat32Array = PackedFloat32Array()
	amap.resize(w * h)
	for y in range(h):
		for x in range(w):
			var c: Color = img.get_pixel(x, y)
			var mx: float = maxf(c.r, maxf(c.g, c.b))
			amap[y * w + x] = clampf((mx - FLOOR) / (SOLID - FLOOR), 0.0, 1.0)
	# ② 내부 구멍 판정 — 테두리에서 저알파(HOLE_A 미만) 픽셀만 밟아 flood fill. 못 닿은 저알파 = 내부.
	var outside: PackedByteArray = PackedByteArray()
	outside.resize(w * h)  # 1 = 바깥(테두리와 저알파로 연결됨)
	var stack: Array = []
	for x in range(w):
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, h - 1))
	for y in range(h):
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(w - 1, y))
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		var idx: int = p.y * w + p.x
		if outside[idx] == 1 or amap[idx] >= HOLE_A:
			continue
		outside[idx] = 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = p.x + d.x
			var ny: int = p.y + d.y
			if nx >= 0 and ny >= 0 and nx < w and ny < h and outside[ny * w + nx] == 0:
				stack.append(Vector2i(nx, ny))
	# ②-2 글자 속 구멍 재분류 — 내부인데 순검정(a=0) 심이 있으면 그 연결 영역은 배경(O·D 의 속 구멍).
	for y2 in range(h):
		for x2 in range(w):
			var si: int = y2 * w + x2
			if outside[si] == 0 and amap[si] <= 0.0:
				stack.append(Vector2i(x2, y2))
	while not stack.is_empty():
		var p2: Vector2i = stack.pop_back()
		var pi: int = p2.y * w + p2.x
		if outside[pi] == 1 or amap[pi] >= HOLE_A:
			continue
		outside[pi] = 1
		for d2 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var mx2: int = p2.x + d2.x
			var my2: int = p2.y + d2.y
			if mx2 >= 0 and my2 >= 0 and mx2 < w and my2 < h and outside[my2 * w + mx2] == 0:
				stack.append(Vector2i(mx2, my2))
	# ③ 픽셀 쓰기 — 본체/내부 구멍 = 원색 불투명, 바깥 페이드 = 언프리멀티플라이
	var cleared: int = 0
	var filled: int = 0
	for y in range(h):
		for x in range(w):
			var idx2: int = y * w + x
			var a: float = amap[idx2]
			var c2: Color = img.get_pixel(x, y)
			if a >= HOLE_A:
				img.set_pixel(x, y, Color(c2.r, c2.g, c2.b, 1.0))
			elif outside[idx2] == 0:
				img.set_pixel(x, y, Color(c2.r, c2.g, c2.b, 1.0))  # 내부 어두운 질감 보존
				filled += 1
			elif a <= 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				cleared += 1
			else:
				img.set_pixel(x, y, Color(minf(c2.r / a, 1.0), minf(c2.g / a, 1.0), minf(c2.b / a, 1.0), a))
	return PackedInt32Array([cleared, filled])

## ⑤ 그림자 굽기 — 알파 채널을 블러한 어두운 판을 SHADOW_OFF 만큼 밀어 그림 밑에 깐다.
func _bake_shadow(src: Image) -> Image:
	var w: int = src.get_width() + SHADOW_PAD * 2
	var h: int = src.get_height() + SHADOW_PAD * 2
	var canvas: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	canvas.blit_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(SHADOW_PAD, SHADOW_PAD))
	var am: PackedFloat32Array = PackedFloat32Array()
	am.resize(w * h)
	for y in range(h):
		for x in range(w):
			am[y * w + x] = canvas.get_pixel(x, y).a
	var bl: PackedFloat32Array = _box_blur(am, w, h)
	for y in range(h):
		for x in range(w):
			var sx: int = x - SHADOW_OFF.x
			var sy: int = y - SHADOW_OFF.y
			if sx < 0 or sy < 0 or sx >= w or sy >= h:
				continue
			var sa: float = minf(bl[sy * w + sx] * 1.4, 1.0) * SHADOW_A
			if sa <= 0.004:
				continue
			var f: Color = canvas.get_pixel(x, y)
			var ra: float = f.a + sa * (1.0 - f.a)
			if ra <= 0.0:
				continue
			var r: float = (f.r * f.a + SHADOW_COL.r * sa * (1.0 - f.a)) / ra
			var g: float = (f.g * f.a + SHADOW_COL.g * sa * (1.0 - f.a)) / ra
			var b: float = (f.b * f.a + SHADOW_COL.b * sa * (1.0 - f.a)) / ra
			canvas.set_pixel(x, y, Color(r, g, b, ra))
	return canvas

## 분리형 박스 블러(슬라이딩 윈도, 가장자리 클램프) — SHADOW_PASSES 회 반복으로 가우시안 근사.
func _box_blur(src: PackedFloat32Array, w: int, h: int) -> PackedFloat32Array:
	var cur: PackedFloat32Array = src.duplicate()
	var span: float = float(SHADOW_R * 2 + 1)
	for _p in range(SHADOW_PASSES):
		# 가로
		var hz: PackedFloat32Array = PackedFloat32Array()
		hz.resize(w * h)
		for y in range(h):
			var row: int = y * w
			var acc: float = 0.0
			for i in range(-SHADOW_R, SHADOW_R + 1):
				acc += cur[row + clampi(i, 0, w - 1)]
			for x in range(w):
				hz[row + x] = acc / span
				acc -= cur[row + clampi(x - SHADOW_R, 0, w - 1)]
				acc += cur[row + clampi(x + SHADOW_R + 1, 0, w - 1)]
		# 세로
		var vt: PackedFloat32Array = PackedFloat32Array()
		vt.resize(w * h)
		for x2 in range(w):
			var acc2: float = 0.0
			for i2 in range(-SHADOW_R, SHADOW_R + 1):
				acc2 += hz[clampi(i2, 0, h - 1) * w + x2]
			for y2 in range(h):
				vt[y2 * w + x2] = acc2 / span
				acc2 -= hz[clampi(y2 - SHADOW_R, 0, h - 1) * w + x2]
				acc2 += hz[clampi(y2 + SHADOW_R + 1, 0, h - 1) * w + x2]
		cur = vt
	return cur

## ⑥ 광학 중심 정렬 — 본체(밀도 기준) bbox 중심이 캔버스 중심에 오도록 투명 여백을 한쪽에 더한다.
func _center_on_core(src: Image) -> Image:
	var w: int = src.get_width()
	var h: int = src.get_height()
	var col: PackedFloat32Array = PackedFloat32Array()
	var row: PackedFloat32Array = PackedFloat32Array()
	col.resize(w)
	row.resize(h)
	for y in range(h):
		for x in range(w):
			var a: float = src.get_pixel(x, y).a
			col[x] += a
			row[y] += a
	var cmax: float = 0.0
	var rmax: float = 0.0
	for x in range(w):
		cmax = maxf(cmax, col[x])
	for y in range(h):
		rmax = maxf(rmax, row[y])
	if cmax <= 0.0 or rmax <= 0.0:
		return src  # 본체 없음 — 정렬 생략
	var minx: int = 0
	var maxx: int = w - 1
	var miny: int = 0
	var maxy: int = h - 1
	while minx < maxx and col[minx] < cmax * DENS_FRAC:
		minx += 1
	while maxx > minx and col[maxx] < cmax * DENS_FRAC:
		maxx -= 1
	while miny < maxy and row[miny] < rmax * DENS_FRAC:
		miny += 1
	while maxy > miny and row[maxy] < rmax * DENS_FRAC:
		maxy -= 1
	var ccx: float = float(minx + maxx + 1) * 0.5
	var ccy: float = float(miny + maxy + 1) * 0.5
	var pad_l: int = maxi(0, int(round(float(w) - ccx * 2.0)))
	var pad_r: int = maxi(0, int(round(ccx * 2.0 - float(w))))
	var pad_t: int = maxi(0, int(round(float(h) - ccy * 2.0)))
	var pad_b: int = maxi(0, int(round(ccy * 2.0 - float(h))))
	if pad_l == 0 and pad_r == 0 and pad_t == 0 and pad_b == 0:
		return src
	var canvas: Image = Image.create(w + pad_l + pad_r, h + pad_t + pad_b, false, Image.FORMAT_RGBA8)
	canvas.blit_rect(src, Rect2i(0, 0, w, h), Vector2i(pad_l, pad_t))
	print("    광학 정렬: 본체중심 (%.0f,%.0f) → 여백 좌%d 우%d 상%d 하%d" % [ccx, ccy, pad_l, pad_r, pad_t, pad_b])
	return canvas
