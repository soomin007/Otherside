extends Control

## 마을 단면 = 단면 탐색 튜토리얼 (첫 원정만). Loadout 출발 뒤 지도 전에 한 번.
## 사장돼 있던 13_단면_마을(SectionArt "start")을 되살려, 안전·무보상으로 "여러 지점을 조사 예산만큼
## 살핀다"는 코어 실행 동사를 연습시킨다. 실제 단면(Expedition)과 같은 그림·지점·조사 램프를 재사용해
## 첫 진짜 노드에서 위협을 끼고 배우던 온보딩 공백을 메운다. 순수 연출 — 자원·흔적을 건드리지 않는다.

const BUDGET: int = 2   ## 실제 단면 기본 예산과 동일(SectionRun.SECTION_PROBES) — "정해진 횟수" 감각을 그대로.

# 마을 단면의 연습 지점 — 정규화 좌표 + 살필 때 뜨는 담담한 문구(무보상). 마을=평화(거리 곡선 §1).
var _spots: Array = [
	{"at": Vector2(0.29, 0.72), "label": "우물", "done": false,     # 화면 왼쪽 아래 돌우물
		"flavor": "맑은 물이 고여 있다.\n떠나면 이런 물 한 모금이 아쉬워진다."},
	{"at": Vector2(0.50, 0.72), "label": "좌판", "done": false,     # 천막 앞 등불·궤짝(마른 고기·밧줄)
		"flavor": "마른 고기와 밧줄이 널려 있다.\n길 위에서도 이렇게 쓸 만한 것들을 찾게 된다."},
	{"at": Vector2(0.63, 0.54), "label": "천막", "done": false,     # 가운데 큰 천막
		"flavor": "먼저 떠난 이들의 자리다.\n돌아온 원정대는 아직 없다."},
]
var _budget: int = BUDGET
var _rect: Rect2 = Rect2()
var _popup: ResultPopup
var _leave_btn: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_leave_btn = UITheme.make_engraved_button("떠난다", 18, true)
	_leave_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_leave_btn.offset_left = -220.0
	_leave_btn.offset_top = -96.0
	_leave_btn.offset_right = -UITheme.PAD
	_leave_btn.offset_bottom = -UITheme.SAFE
	_leave_btn.pressed.connect(_on_leave)
	add_child(_leave_btn)

	_popup = ResultPopup.new()
	add_child(_popup)

	await get_tree().process_frame
	if not is_inside_tree():
		return
	# 첫 안내 — 무엇을 하는 화면인지 담담하게(무보상 연습임을 못박는다).
	_popup.show_result("여기는 마을일세. 길을 나서면\n닿는 곳마다 몇 군데 둘러보게 되지.\n둘러볼 횟수는 정해져 있으니 잘 고르게.\n여기선 아무 일도 없으니 편히 연습해 보게.", {})
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if _popup != null and _popup.visible:
		return
	var tapped: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not tapped:
		return
	var pos: Vector2 = event.position
	for i in range(_spots.size()):
		var sp: Dictionary = _spots[i]
		if bool(sp.get("done", false)) or _budget <= 0:
			continue
		if pos.distance_to(_spot_screen(sp["at"])) <= 40.0:
			_probe(i)
			return

func _probe(i: int) -> void:
	var sp: Dictionary = _spots[i]
	sp["done"] = true
	_spots[i] = sp
	_budget -= 1
	queue_redraw()
	_popup.show_result(str(sp.get("flavor", "")), {})

func _on_leave() -> void:
	GameState.mark_village_intro_seen()
	GameState.go_to_map()

func _spot_screen(at: Vector2) -> Vector2:
	return _rect.position + Vector2(at.x * _rect.size.x, at.y * _rect.size.y)

func _probed_count() -> int:
	var n: int = 0
	for sp in _spots:
		if bool(sp.get("done", false)):
			n += 1
	return n

func _draw() -> void:
	var s: Vector2 = size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	_rect = Rect2(Vector2.ZERO, s)
	var font: Font = get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font

	SectionArt.draw_section(self, "start", _rect, "n0")

	# 하단 가독 스크림(장소 이름·조사 램프·버튼 밑) — 위가 투명, 아래로 짙어지는 근사 그라데이션.
	var sh: float = 180.0
	for k in range(10):
		var a: float = 0.6 * (float(k) / 9.0)
		draw_rect(Rect2(0.0, s.y - sh + sh / 10.0 * float(k), s.x, sh / 10.0 + 1.0), Color(0.02, 0.02, 0.04, a))

	# 장소 이름(붓글씨, 지도 지명과 같은 결) — 왼쪽 아래.
	var bf: Font = UITheme.BRUSH_FONT if UITheme.BRUSH_FONT != null else font
	var base := Vector2(44.0, s.y - 66.0)
	draw_string(bf, base + Vector2(0.0, 2.5), "마을", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(0.0, 0.0, 0.0, 0.75))
	draw_string(bf, base, "마을", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, UITheme.FG)

	# "조사" + 램프 점 — 남은 조사 횟수(채운 점)/쓴 것(빈 점). 실제 단면과 같은 표현.
	if _budget > 0:
		var by: float = s.y - 30.0
		draw_string(font, Vector2(46.0, by), "조사", HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_LABEL, UITheme.SAND)
		var tw: float = font.get_string_size("조사", HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_LABEL).x
		var px: float = 46.0 + tw + 14.0
		var py: float = by - float(UITheme.FS_LABEL) * 0.32
		for k in range(BUDGET):
			var lc := Vector2(px + float(k) * 17.0, py)
			if k < _budget:
				draw_circle(lc, 5.0, UITheme.SAND)
			else:
				draw_arc(lc, 5.0, 0.0, TAU, 20, Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.4), 1.5)

	# 지점 마커 — 실제 단면과 동일한 SectionArt.draw_spot.
	for i in range(_spots.size()):
		var sp: Dictionary = _spots[i]
		var st: int = 0
		if bool(sp.get("done", false)):
			st = 1
		elif _budget <= 0:
			st = 2
		SectionArt.draw_spot(self, font, _spot_screen(sp["at"]), str(sp.get("label", "")), st, false)

	# 안내 문구 — 첫 조사 전엔 "눌러 살핀다", 다 쓰면 "떠난다".
	var guide: String = ""
	if _budget > 0 and _probed_count() == 0:
		guide = "표시된 곳을 눌러 살핀다  (마을에선 아무 일도 없다)"
	elif _budget <= 0:
		guide = "이제 길을 나설 때다.  '떠난다'를 누르게."
	if guide != "":
		draw_string(font, Vector2(0.0, s.y - 140.0), guide, HORIZONTAL_ALIGNMENT_CENTER, s.x, UITheme.FS_SMALL, Color(0.88, 0.84, 0.76))
