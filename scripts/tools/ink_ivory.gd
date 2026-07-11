extends SceneTree

## 잉크판 → 아이보리판 변환 (아트 파이프라인, 2026-07-12)
##
## 배경: UI 킷(사람 픽토그램 등)은 양피지용 세피아 잉크판 한 벌만 뽑는다(UI_그래픽_핸드오프 §3).
##       어두운 화면(지도 좌 칼럼·HUD)용 아이보리판은 여기서 파생한다 — 어두울수록(잉크 선) 밝은
##       아이보리로 남고, 밝은 크림 채움은 잦아들어 어두운 배경에 스며든다(잉크 스케치의 반전).
##
## 실행: godot --headless --path . -s scripts/tools/ink_ivory.gd -- assets/arts/transparent/58_사람_대원갑.png ...
## 출력: 같은 폴더에 `<이름>_밝음.png` (원본 미파괴).
## 제약: -s 컨텍스트엔 autoload 없음 — 순수 Image API 만.

const IVORY := Color(0.965, 0.925, 0.831)  # UITheme.FG(#F6ECD4) — 어두운 표면의 기본 글자색과 한 몸
const ALPHA_GAIN: float = 1.6              # 잉크 진하기 → 불투명도 증폭(선명한 선 유지, 채움은 흐려짐)

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		print("사용법: -- <transparent png 경로> ...")
		quit(1)
		return
	var fail: int = 0
	for a in args:
		if not _convert_one(str(a)):
			fail += 1
	print("=== ink_ivory: %d개 중 %d 실패 ===" % [args.size(), fail])
	quit(1 if fail > 0 else 0)

func _convert_one(src: String) -> bool:
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(src))
	if img == null:
		print("FAIL 로드: ", src)
		return false
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y in range(h):
		for x in range(w):
			var c: Color = img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var lum: float = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
			var strength: float = clampf((1.0 - lum) * ALPHA_GAIN, 0.0, 1.0)
			img.set_pixel(x, y, Color(IVORY.r, IVORY.g, IVORY.b, c.a * strength))
	var out_path: String = src.get_basename() + "_밝음.png"
	var err: int = img.save_png(ProjectSettings.globalize_path(out_path))
	if err != OK:
		print("FAIL 저장(", err, "): ", out_path)
		return false
	print("OK  %s → %s" % [src.get_file(), out_path.get_file()])
	return true
