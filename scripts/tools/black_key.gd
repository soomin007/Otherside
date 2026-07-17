extends SceneTree

## 검정 배경 → 투명 변환 도구 (로고 등 "밝은 그림 · 검정 배경" 전용, alpha_key.gd 의 자매)
##
## 배경: 밝은 모래색 로고는 흰 배경으로 뽑으면 흰→투명 키잉(alpha_key)이 글자까지 지운다.
##       그래서 검정(#000000) 배경으로 뽑고, 여기서 밝기를 alpha 로 되살린다(언프리멀티플라이).
##       원본이 검정 위 합성이므로 c' = c / a, a = 밝기 램프 — 어두운 화면 위에 얹으면 원본과 같게 보인다.
##
## 실행 (대상은 인자로만 받는다 — 폴더 스캔 없음):
##   godot --headless --path . -s scripts/tools/black_key.gd -- <입력.png> <출력.png> [<입력2> <출력2> ...]
##
## 처리: ① 밝기 램프 alpha (FLOOR 이하 = 배경 노이즈 → 0, SOLID 이상 → 1)
##       ② 내부 구멍 메움 — 글자 안 어두운 질감(돌 틈)이 반투명해지면 밝은 배경 위에서 씻겨 보인다.
##          테두리에서 못 닿는 저알파 픽셀 = 내부 → 원색 그대로 불투명 유지.
##          단, 순검정(a=0) 심이 있는 내부 영역은 글자 속 구멍(O·D 의 속)이라 배경으로 재분류(투명).
##       ③ 바깥(모래 흩날림)은 c/a 언프리멀티플라이로 부드러운 페이드 보존
##       ④ 여백 크롭(+MARGIN) ⑤ MAX_W 초과 시 Lanczos 다운스케일
##
## 제약: -s 컨텍스트엔 autoload 없음 — 순수 Image API 만 쓴다(alpha_key 와 동일).

const FLOOR: float = 0.03   # 이 밝기 이하 = 배경 노이즈 → 완전 투명
const SOLID: float = 0.72   # 이 밝기 이상 = 그림 본체 → 완전 불투명
const HOLE_A: float = 0.98  # 이 alpha 미만을 '빈 곳 후보'로 보고 테두리 flood fill — 못 닿으면 내부 구멍
const MARGIN: int = 8       # 크롭 후 사방 여백(px)
const MAX_W: int = 1600     # 결과 최대 폭(로고 선명도 유지 선에서 다이어트)

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

	# ②-2 글자 속 구멍 재분류 — 내부인데 순검정(a=0) 픽셀이 있으면 그 연결 영역은 배경이다
	#      (O·D 의 속 구멍). 검정 심에서 저알파 픽셀을 타고 flood fill → outside 와 같게 취급.
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

	if img.detect_alpha() == Image.ALPHA_NONE:
		print("FAIL 투명픽셀 없음(문턱 재조정 필요): ", src)
		return false

	# ④ 여백 크롭
	var used: Rect2i = img.get_used_rect()
	if used.size.x > 0 and used.size.y > 0:
		used = used.grow(MARGIN)
		used = used.intersection(Rect2i(0, 0, w, h))
		img = img.get_region(used)

	# ⑤ 폭 다이어트
	if img.get_width() > MAX_W:
		var nh: int = int(round(float(img.get_height()) * float(MAX_W) / float(img.get_width())))
		img.resize(MAX_W, nh, Image.INTERPOLATE_LANCZOS)

	var err: int = img.save_png(ProjectSettings.globalize_path(dst))
	if err != OK:
		print("FAIL 저장(", err, "): ", dst)
		return false
	print("OK  %s → %s  [%dx%d, 배경 %dpx 투명, 내부 메움 %dpx]" % [src.get_file(), dst, img.get_width(), img.get_height(), cleared, filled])
	return true
