extends SceneTree

## 투명 변환 검증용 미리보기 시트 (재검증용 — 아이콘 늘 때마다 다시 확인)
## transparent/ 의 결과를 어두운 세피아 배경에 합성해 한 장의 그리드로 저장.
## 흰 배경 뷰어로는 안 보이는 "진짜 투명·경계 헤일로·하이라이트 구멍"을 눈으로 확인한다.
## 실행: godot --headless --path . -s scripts/tools/alpha_preview.gd -- <출력 절대경로.png>

const DIR: String = "res://assets/arts/transparent"
const CELL: int = 320
const COLS: int = 4
const PAD: int = 28

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 1:
		print("사용법: -s scripts/tools/alpha_preview.gd -- <출력 절대경로.png>")
		quit(1)
		return
	var out_path: String = args[0]

	var files: Array = []
	var dir: DirAccess = DirAccess.open(DIR)
	if dir == null:
		print("폴더 없음: ", DIR)
		quit(1)
		return
	dir.list_dir_begin()
	var f: String = dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.to_lower().ends_with(".png"):
			files.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	files.sort()

	if files.is_empty():
		print("미리보기 대상 없음")
		quit(1)
		return

	var rows: int = int(ceil(files.size() / float(COLS)))
	var sheet: Image = Image.create(COLS * CELL, rows * CELL, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.17, 0.13, 0.09, 1.0))   # 어두운 세피아(지도 톤 근사)

	for i in range(files.size()):
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(DIR + "/" + files[i]))
		if img == null:
			continue
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		var longest: int = maxi(img.get_width(), img.get_height())
		var scale: float = float(CELL - PAD * 2) / float(longest)
		var nw: int = int(img.get_width() * scale)
		var nh: int = int(img.get_height() * scale)
		img.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
		var col: int = i % COLS
		var row: int = int(i / COLS)
		var cx: int = col * CELL + int((CELL - nw) / 2.0)
		var cy: int = row * CELL + int((CELL - nh) / 2.0)
		sheet.blend_rect(img, Rect2i(0, 0, nw, nh), Vector2i(cx, cy))

	var err: int = sheet.save_png(out_path)
	if err != OK:
		print("저장 실패(", err, "): ", out_path)
		quit(1)
		return
	print("미리보기 저장: ", out_path, " (", files.size(), "장, ", COLS * CELL, "x", rows * CELL, ")")
	quit(0)
