extends SceneTree

## 이미지 경량화 — 웹 빌드(.pck) 축소용. 표시 크기에 맞춰 긴 변을 목표 이하로 다운스케일한다.
## 아이콘은 지도에서 ~108px, 초상은 ~160px, 배경은 화면(≤1280px)까지만 표시되는데 원본이 1254²~1672px라
## 과대해상도(웹 로딩·용량 낭비). 표시 크기 기준으로 줄이면 눈에 손실이 없다. 원본은 git 이력에 보존.
##
## 실행: godot --headless --path . -s scripts/tools/downscale.gd
##        (특정 파일만: -- <경로> ...  — 목표는 파일명으로 자동 판별)
##
## 목표 긴 변(px): 아이콘 320 · 초상 512 · 배경/삽화/타이틀 1280. 이미 목표 이하면 건너뜀.
## 제약: -s 컨텍스트엔 autoload 없음 — 순수 Image API 만 쓴다.

const DIRS: Array = ["res://assets/arts", "res://assets/arts/transparent"]
const MAX_ICON: int = 320
const MAX_PORTRAIT: int = 512
const MAX_BG: int = 1280

func _init() -> void:
	var targets: Array = _resolve_targets()
	if targets.is_empty():
		print("대상 png 없음.")
		quit(0)
		return
	var changed: int = 0
	var saved_before: int = 0
	var saved_after: int = 0
	for path in targets:
		var res: Dictionary = _shrink_one(str(path))
		if not res.get("ok", false):
			continue
		saved_before += int(res.get("before", 0))
		saved_after += int(res.get("after", 0))
		if res.get("resized", false):
			changed += 1
	print("=== downscale: %d개 리사이즈 · 합계 %.1fMB → %.1fMB ===" % [
		changed, float(saved_before) / 1048576.0, float(saved_after) / 1048576.0])
	quit(0)

func _resolve_targets() -> Array:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		var out: Array = []
		for a in args:
			out.append(a)
		return out
	var found: Array = []
	for d in DIRS:
		var dir: DirAccess = DirAccess.open(str(d))
		if dir == null:
			continue
		dir.list_dir_begin()
		var fname: String = dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and fname.to_lower().ends_with(".png"):
				found.append(str(d) + "/" + fname)
			fname = dir.get_next()
		dir.list_dir_end()
	found.sort()
	return found

## 파일명으로 목표 긴 변 결정.
func _target_for(base: String) -> int:
	if base.contains("_아이콘_"):
		return MAX_ICON
	# UI 킷(2026-07-12) — 표시가 14~54px 라 320이면 충분(@2x 여유 포함).
	if base.contains("_사람_") or base.contains("_기호_") or base.contains("_소품_"):
		return MAX_ICON
	if base.contains("_초상_"):
		return MAX_PORTRAIT
	return MAX_BG  # 지도·단면·배경·오프닝·타이틀

func _shrink_one(src: String) -> Dictionary:
	var abs_path: String = ProjectSettings.globalize_path(src)
	var before: int = _file_size(abs_path)
	var img: Image = Image.load_from_file(abs_path)
	if img == null:
		print("SKIP 로드 실패: ", src)
		return {"ok": false}
	var w: int = img.get_width()
	var h: int = img.get_height()
	var longest: int = maxi(w, h)
	var target: int = _target_for(src.get_file())
	if longest <= target:
		return {"ok": true, "resized": false, "before": before, "after": before}
	var scale: float = float(target) / float(longest)
	var nw: int = maxi(1, int(round(float(w) * scale)))
	var nh: int = maxi(1, int(round(float(h) * scale)))
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	img.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
	var err: int = img.save_png(abs_path)
	if err != OK:
		print("FAIL 저장(", err, "): ", src)
		return {"ok": false}
	var after: int = _file_size(abs_path)
	print("OK  %s  %dx%d → %dx%d  (%.0fKB → %.0fKB)" % [
		src.get_file(), w, h, nw, nh, float(before) / 1024.0, float(after) / 1024.0])
	return {"ok": true, "resized": true, "before": before, "after": after}

func _file_size(abs_path: String) -> int:
	var f: FileAccess = FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		return 0
	var s: int = f.get_length()
	f.close()
	return s
