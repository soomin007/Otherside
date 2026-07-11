extends SceneTree

## 흰 배경 → 투명 변환 도구 (아트 파이프라인)
##
## 배경: 이미지 생성기는 투명 배경을 못 만들고 순백(#FFFFFF)으로 뽑는다(art_prompts.md 교훈).
##       넣기 전 흰색을 투명으로 떨어뜨린다 — 잉크 linework + 세피아 wash 는 채도가 있어 남고,
##       채도 0 에 가까운 밝은 배경만 지워진다(밝기만으로 자르면 옅은 모래색까지 날아감).
##
## 실행:
##   godot --headless --path . -s scripts/tools/alpha_key.gd
##     → assets/arts/ 안의 `_아이콘_`·`_초상_` 파일을 전부 변환(01 지도 배경 등 불투명 대상은 건드리지 않음)
##   godot --headless --path . -s scripts/tools/alpha_key.gd -- assets/arts/09_아이콘_독웅덩이.png ...
##     → 인자로 준 파일만 변환
##
## 출력: 원본은 보존, 결과는 assets/arts/transparent/<같은 이름>.png (재튜닝 가능하게 원본 미파괴).
## 검증: 저장 후 detect_alpha() 로 투명 픽셀이 실제로 생겼는지 확인(ALPHA_NONE 이면 실패로 표시).
##
## 제약: -s 컨텍스트엔 autoload 없음 — 순수 Image API 만 쓴다(core_smoke 와 동일 제약).

const SRC_DIR: String = "res://assets/arts"
const OUT_DIR: String = "res://assets/arts/transparent"

# --- 컬러키 손잡이 (결과 보고 튜닝) ---
const WHITE_LO: float = 0.80   # 이 밝기 이하는 배경 후보 아님(완전 불투명 유지)
const WHITE_HI: float = 0.97   # 이 밝기 이상 + 저채도면 완전 투명
const CHROMA_MAX: float = 0.12 # 이 채도 이상이면 그림(세피아·모래)으로 보고 남긴다
const ALPHA_LO: float = 0.18   # 배경 잔여(이 이하 alpha) → 완전 투명으로 스냅(사각 헤일로 방지)
const ALPHA_HI: float = 0.82   # 그림 내부(이 이상 alpha) → 완전 불투명으로 스냅
const MARGIN: int = 8          # 크롭 후 사방 여백(px)
const ERODE: int = 1           # 흰 헤일로 제거: 반투명 경계를 이 px 만큼 깎는다(0=끔). soft 파일엔 미적용.
const WHITE_ERODE: int = 3     # 흰색만 골라 깎기: 순백에 가까운(밝고 저채도) 경계 픽셀만 이 px 깎는다.
                               # 피규어에 붙은 밝은 잔결(수염·터번 실오라기 끝)만 없애고 어두운 가장자리는 보존.
const SPECK_FRAC: float = 0.02 # 떠다니는 흰 조각 제거: 가장 큰 덩어리의 이 비율보다 작은 불투명 섬은 지운다(0=끔).
                               # 흰 배경의 밝은 RGB가 경계 반투명 픽셀에 남아 어두운 카드 위에서 밝게 뜨는 걸 없앤다.

# 부드러운 페이드가 핵심인 파일 — alpha 스냅을 끈다(단단한 아이콘엔 스냅이 좋지만
# 소용돌이 모래처럼 바깥으로 옅게 흩어지는 그림은 스냅하면 가장자리가 거칠게 끊긴다).
# _기호_(UI 킷 — 크림 후광이 흰색으로 잦아드는 링·배지)·_스러짐(흩날리는 모래)도 soft(2026-07-12).
const SOFT_KEYS: Array = ["_미지", "_기호_", "_스러짐"]

func _init() -> void:
	var targets: Array = _resolve_targets()
	if targets.is_empty():
		print("대상 파일 없음. assets/arts 에 `_아이콘_`/`_초상_` 파일을 두거나 인자로 경로를 준다.")
		quit(1)
		return

	_ensure_out_dir()

	var fail: int = 0
	for path in targets:
		if not _convert_one(str(path)):
			fail += 1

	print("=== alpha_key: %d개 중 %d 실패 ===" % [targets.size(), fail])
	quit(1 if fail > 0 else 0)

# --- 대상 결정: 인자 우선, 없으면 폴더 스캔 ---

func _resolve_targets() -> Array:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		var out: Array = []
		for a in args:
			out.append(a)
		return out
	# 폴더 스캔 — 흰 배경 대상(아이콘·초상)만. 지도 배경(01)·단면·화면 배경은 불투명이라 제외.
	var found: Array = []
	var dir: DirAccess = DirAccess.open(SRC_DIR)
	if dir == null:
		print("폴더를 열 수 없음: ", SRC_DIR)
		return found
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.to_lower().ends_with(".png"):
			if fname.contains("_아이콘_") or fname.contains("_초상_"):
				found.append(SRC_DIR + "/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	found.sort()
	return found

func _ensure_out_dir() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(OUT_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

# --- 한 장 변환 ---

func _convert_one(src: String) -> bool:
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(src))
	if img == null:
		print("FAIL 로드: ", src)
		return false
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)

	var soft: bool = _is_soft(src)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var cleared: int = 0
	for y in range(h):
		for x in range(w):
			var c: Color = img.get_pixel(x, y)
			var a: float = _bg_alpha(c, soft)
			if a < 1.0:
				c.a = a
				img.set_pixel(x, y, c)
				if a <= 0.0:
					cleared += 1

	# soft — 눈에 안 보이는 극미량 알파(≤0.02)만 0으로 스냅. 페이드는 보존하면서
	# get_used_rect 크롭이 배경 노이즈에 막히지 않게 한다(2026-07-12, 기호 후광 크롭 안 되던 것).
	if soft:
		for y in range(h):
			for x in range(w):
				var sc: Color = img.get_pixel(x, y)
				if sc.a > 0.0 and sc.a <= 0.02:
					sc.a = 0.0
					img.set_pixel(x, y, sc)
	# 흰 헤일로 제거 — 반투명 경계를 ERODE px 깎는다(soft 는 부드러운 페이드 보존 위해 제외).
	if ERODE > 0 and not soft:
		_erode_alpha(img, ERODE, false)
	# 흰색만 골라 깎기 — 순백에 가까운 경계 잔결(수염·실오라기)만 없앤다(어두운 가장자리 보존).
	if WHITE_ERODE > 0 and not soft:
		_erode_alpha(img, WHITE_ERODE, true)
	# 떠다니는 흰 조각 제거 — 본체(가장 큰 덩어리)에서 떨어진 작은 불투명 섬을 지운다.
	if SPECK_FRAC > 0.0 and not soft:
		_remove_specks(img, SPECK_FRAC)

	if img.detect_alpha() == Image.ALPHA_NONE:
		print("FAIL 투명픽셀 없음(문턱 재조정 필요): ", src)
		return false

	# 여백 크롭 — 보이는 영역 bounding box + MARGIN
	var used: Rect2i = img.get_used_rect()
	if used.size.x > 0 and used.size.y > 0:
		used = used.grow(MARGIN)
		used = used.intersection(Rect2i(0, 0, w, h))
		img = img.get_region(used)

	var base: String = src.get_file()
	var out_path: String = OUT_DIR + "/" + base
	var err: int = img.save_png(ProjectSettings.globalize_path(out_path))
	if err != OK:
		print("FAIL 저장(", err, "): ", out_path)
		return false

	print("OK  %s → %s  [%dx%d, 배경 %d px 투명%s]" % [base, out_path, img.get_width(), img.get_height(), cleared, " · soft" if soft else ""])
	return true

## 알파 침식 — 완전 투명(alpha≈0) 이웃이 있는 경계 픽셀을 투명으로 깎는다. px 회수 반복(스냅샷 후 일괄).
## white_only=true 면 순백에 가까운(밝고 저채도) 경계 픽셀만 깎는다(흰 잔결 제거, 어두운 가장자리 보존).
func _erode_alpha(img: Image, px: int, white_only: bool) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	# white-only 는 희미한(faint) 이웃까지 '빈 곳'으로 봐서, 반투명에 둘러싸인 흰 잔흔도 깎는다.
	var near: float = 0.35 if white_only else 0.0
	for _pass in range(px):
		var cut: Array = []
		for y in range(h):
			for x in range(w):
				var c: Color = img.get_pixel(x, y)
				if c.a <= 0.0:
					continue
				if white_only and not _is_whiteish(c):
					continue
				if _has_clear_neighbor(img, x, y, w, h, near):
					cut.append(Vector2i(x, y))
		for p in cut:
			var pi: Vector2i = p
			var cc: Color = img.get_pixel(pi.x, pi.y)
			cc.a = 0.0
			img.set_pixel(pi.x, pi.y, cc)

## 순백에 가까운가 — 밝고(값 높음) 저채도. 밝은 흰 잔결만 True(회색 수염·베이지 터번·어두운 옷은 False).
func _is_whiteish(c: Color) -> bool:
	var mx: float = maxf(c.r, maxf(c.g, c.b))
	var mn: float = minf(c.r, minf(c.g, c.b))
	return mx > 0.82 and (mx - mn) < 0.12

func _has_clear_neighbor(img: Image, x: int, y: int, w: int, h: int, thresh: float) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if nx < 0 or ny < 0 or nx >= w or ny >= h:
			continue
		if img.get_pixel(nx, ny).a <= thresh:
			return true
	return false

## 떠다니는 흰 조각 제거 — 불투명(alpha>0.5) 픽셀을 연결 성분으로 묶어, 가장 큰 덩어리(본체)의
## frac 배보다 작은 성분은 투명으로 지운다. 본체에서 떨어진 작은 흰 자국(터번 옆 점 등)을 없앤다.
func _remove_specks(img: Image, frac: float) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(w * h)  # 0=미방문, 1=처리됨
	var comps: Array = []  # 각 성분의 픽셀 목록
	for y in range(h):
		for x in range(w):
			var idx: int = y * w + x
			if seen[idx] == 1:
				continue
			if img.get_pixel(x, y).a <= 0.15:
				seen[idx] = 1
				continue
			# flood fill(4이웃) — 0.15 초과를 연결로 본다(수염 잔결이 본체와 이어지게).
			var comp: Array = []
			var stack: Array = [Vector2i(x, y)]
			seen[idx] = 1
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				comp.append(p)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = p.x + d.x
					var ny: int = p.y + d.y
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var ni: int = ny * w + nx
					if seen[ni] == 1:
						continue
					seen[ni] = 1
					if img.get_pixel(nx, ny).a <= 0.15:
						continue
					stack.append(Vector2i(nx, ny))
			comps.append(comp)
	if comps.size() <= 1:
		return
	var maxsz: int = 0
	for c in comps:
		maxsz = maxi(maxsz, (c as Array).size())
	var thresh: int = int(float(maxsz) * frac)
	var removed: int = 0
	for c in comps:
		var arr: Array = c
		if arr.size() >= thresh:
			continue
		for p in arr:
			var pi: Vector2i = p
			var col: Color = img.get_pixel(pi.x, pi.y)
			col.a = 0.0
			img.set_pixel(pi.x, pi.y, col)
			removed += 1
	if removed > 0:
		print("    떠다니는 조각 제거: %d px (임계 %d)" % [removed, thresh])

func _is_soft(src: String) -> bool:
	var base: String = src.get_file()
	for key in SOFT_KEYS:
		if base.contains(str(key)):
			return true
	return false

# --- 컬러키: 배경(순백)일수록 alpha 낮게. 채도 있으면 그림으로 보고 남긴다 ---

func _bg_alpha(c: Color, soft: bool) -> float:
	var mx: float = maxf(c.r, maxf(c.g, c.b))   # value(밝기)
	var mn: float = minf(c.r, minf(c.g, c.b))
	var chroma: float = mx - mn                  # 흰/회색 = 0, 세피아·모래 = 높음
	# 밝을수록 배경 후보(0~1)
	var bright: float = smoothstep(WHITE_LO, WHITE_HI, mx)
	# 채도 높을수록 그림(배경 아님) — 배경 점수 깎기
	var chroma_gate: float = 1.0 - smoothstep(0.0, CHROMA_MAX, chroma)
	var bg_score: float = bright * chroma_gate    # 1 = 확실한 배경, 0 = 확실한 그림
	var alpha: float = clampf(1.0 - bg_score, 0.0, 1.0)
	# soft: 스냅 없이 원본 페이드 유지(소용돌이 등 옅은 가장자리가 부드럽게 사라진다).
	if soft:
		return alpha
	# 대비 강화 — 배경 잔여는 완전 투명, 그림 내부는 완전 불투명. 얇은 경계만 반투명으로 남긴다.
	if alpha <= ALPHA_LO:
		return 0.0
	if alpha >= ALPHA_HI:
		return 1.0
	return smoothstep(ALPHA_LO, ALPHA_HI, alpha)
