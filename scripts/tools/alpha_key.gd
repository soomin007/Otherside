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

# 부드러운 페이드가 핵심인 파일 — alpha 스냅을 끈다(단단한 아이콘엔 스냅이 좋지만
# 소용돌이 모래처럼 바깥으로 옅게 흩어지는 그림은 스냅하면 가장자리가 거칠게 끊긴다).
const SOFT_KEYS: Array = ["_미지"]

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
