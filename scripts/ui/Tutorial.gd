extends CanvasLayer

## 조작 오버레이 튜토리얼 — 첫 원정에 지도 이동·단면 조사·남기기를 실제 화면 위에서 짚어준다(스포트라이트+말풍선).
## autoload CanvasLayer — 기존 씬(Map/Expedition)을 미터치. 현재 씬을 감지해 해당 단계만 띄운다.
## 게이트: GameState.controls_tutorial_seen(영속). 다 보거나 건너뛰면 다시 안 뜬다. record_seen(기록지 받음=첫 원정 시작) 이후에만.
## 강조는 특정 노드 Rect 가 아니라 대략적 앵커 영역(정규화 0~1) — 씬 레이아웃이 바뀌어도 견고.

const ENABLED: bool = true

const STEPS: Array = [
	{"scene": "res://scenes/map.tscn", "rect": Rect2(0.12, 0.17, 0.76, 0.36),
		"text": "지도에서 갈 곳을 눌러 나아갑니다. 가봐야 무엇이 있는지 알 수 있어요. 걸음마다 물과 식량이 닳습니다."},
	{"scene": "res://scenes/map.tscn", "rect": Rect2(0.08, 0.78, 0.84, 0.16),
		"text": "언제든 [남기기]로 물건 하나를 두고 갈 수 있습니다. 그만큼 잃지만, 다음 원정대가 그걸 줍습니다."},
	{"scene": "res://scenes/expedition.tscn", "rect": Rect2(0.12, 0.24, 0.76, 0.40),
		"text": "도착한 곳은 표시된 지점을 눌러 살핍니다. 조사 횟수는 정해져 있고, 살피는 데 자원은 들지 않아요."},
]

var _root: Control
var _highlight: Panel
var _bubble_holder: CenterContainer
var _bubble_label: Label
var _next_btn: EngravedItem
var _skip_btn: EngravedItem
var _step_idx: int = 0
var _rendered_idx: int = -1

func _ready() -> void:
	if not ENABLED:
		return
	layer = 110  # Bookmark(100) 위, DEV(128) 아래
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false

func _process(_delta: float) -> void:
	if not ENABLED or _root == null:
		return
	# 게이트: 이미 봤거나(영속) 아직 기록지 전(첫 원정 시작 전)이면 안 뜬다.
	if GameState.controls_tutorial_seen or not GameState.record_seen:
		_hide()
		return
	# 사망(고갈·위협)으로 결과 화면이 떠 있는 동안엔 안 뜬다 — 이동 중 죽어 단면(사망 안내·[지도로])으로
	# 넘어왔을 때 조사 튜토리얼이 그 위에 겹치던 버그. 죽은 원정엔 조작 안내가 무의미하다.
	if GameState.current_run != null and not GameState.current_run.alive:
		_hide()
		return
	# 일지(Bookmark, 레이어 100)가 열려 있으면 안 뜬다 — 튜토리얼(110)이 일지 위로 겹치던 버그(2026-07-06).
	# 일지를 덮으면 그 씬의 단계가 다시 뜬다.
	if Bookmark.is_open():
		_hide()
		return
	if _step_idx >= STEPS.size():
		GameState.mark_controls_tutorial_seen()
		_hide()
		return
	var step: Dictionary = STEPS[_step_idx]
	if _current_scene_path() == str(step.get("scene", "")):
		if not _root.visible:
			_root.visible = true
		if _rendered_idx != _step_idx:
			_render_step()
			_rendered_idx = _step_idx
	else:
		_hide()  # 이 단계의 씬이 아니면 대기(그 씬에 도착하면 뜬다)

## 조작 안내를 처음부터 다시 보여준다(설정 "조작 안내 다시보기"). seen 플래그를 재무장하면
## _process 가 현재 지도·단면 씬에서 1단계부터 다시 띄운다. 완료·건너뛰면 다시 seen 처리된다.
func replay() -> void:
	if not ENABLED:
		return
	_step_idx = 0
	_rendered_idx = -1
	GameState.controls_tutorial_seen = false

func _hide() -> void:
	if _root != null and _root.visible:
		_root.visible = false
	_rendered_idx = -1

func _current_scene_path() -> String:
	var cs: Node = get_tree().current_scene
	return cs.scene_file_path if cs != null else ""

# --- UI 구성 ---

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP  # 튜토리얼 중 게임 입력 차단
	add_child(_root)

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.02, 0.02, 0.04, 0.62)
	scrim.gui_input.connect(_on_scrim_input)
	_root.add_child(scrim)

	_highlight = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.12)
	sb.border_color = UITheme.SAND
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	_highlight.add_theme_stylebox_override("panel", sb)
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_highlight)

	_bubble_holder = CenterContainer.new()
	_bubble_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bubble_holder)
	# 각인형 말풍선 — 가죽 카드 상자 폐기(양산형 웹 카드 금지), 스크림 위에 헤어라인+글+각인 버튼만.
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(UITheme.COLUMN_W, 0)
	box.add_theme_constant_override("separation", UITheme.GAP)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 빈 곳 탭은 스크림(다음)으로 통과, 버튼만 자기 입력
	UITheme.attach_dark_pool(box)  # 상자 대신 방사 어둠 — 밑의 지도 글씨와 안 섞이게
	_bubble_holder.add_child(box)
	box.add_child(UITheme.make_hairline(Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.35), 2.0))
	_bubble_label = UITheme.make_label("", UITheme.FS_BODY)
	box.add_child(_bubble_label)
	box.add_child(UITheme.make_hairline(Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.35), 2.0))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	_skip_btn = EngravedItem.new()
	_skip_btn.init_item("건너뛰기", 15, false)
	_skip_btn.pressed.connect(_skip)
	row.add_child(_skip_btn)
	_next_btn = EngravedItem.new()
	_next_btn.init_item("다음", 18, true)
	_next_btn.pressed.connect(_next)
	row.add_child(_next_btn)
	box.add_child(row)

func _render_step() -> void:
	var step: Dictionary = STEPS[_step_idx]
	var vp: Vector2 = get_viewport().get_visible_rect().size
	# 현재 씬이 실제 강조 rect(픽셀)를 주면 그걸 쓴다(반응형·여백에 견고). 없으면 정규화 rect fallback.
	var hl: Rect2
	var cs: Node = get_tree().current_scene
	if cs != null and cs.has_method("tutorial_highlight_rect"):
		hl = cs.tutorial_highlight_rect(_step_idx)
	else:
		var r: Rect2 = step.get("rect", Rect2(0.1, 0.2, 0.8, 0.4))
		hl = Rect2(r.position.x * vp.x, r.position.y * vp.y, r.size.x * vp.x, r.size.y * vp.y)
	_highlight.position = hl.position
	_highlight.size = hl.size
	_bubble_label.text = str(step.get("text", ""))
	# 마지막 단계(또는 그 씬의 단계가 하나뿐일 때) — "건너뛰기"는 무의미하니 숨기고 "시작"만.
	var last: bool = _step_idx >= STEPS.size() - 1
	_next_btn.set_label("다음" if not last else "시작")
	if _skip_btn != null:
		_skip_btn.visible = not last
	# 강조가 화면 위쪽이면 말풍선을 아래로, 아래쪽이면 위로 — 서로 안 겹치게(픽셀→화면비 환산).
	var center_y: float = (hl.position.y + hl.size.y * 0.5) / maxf(1.0, vp.y)
	_place_bubble(center_y >= 0.5)

## 말풍선 밴드를 화면 위/아래에 앵커로 붙인다(가로는 여백만 두고 꽉, CenterContainer 가 카드를 중앙 정렬).
func _place_bubble(top: bool) -> void:
	_bubble_holder.anchor_left = 0.0
	_bubble_holder.anchor_right = 1.0
	_bubble_holder.offset_left = UITheme.PAD
	_bubble_holder.offset_right = -UITheme.PAD
	if top:  # 강조가 아래쪽 → 말풍선 위
		_bubble_holder.anchor_top = 0.05
		_bubble_holder.anchor_bottom = 0.42
	else:  # 강조가 위쪽 → 말풍선 아래(하단 각인 버튼 줄과 안 겹치게 0.88 까지만 — 2026-07-06 겹침 지적)
		_bubble_holder.anchor_top = 0.52
		_bubble_holder.anchor_bottom = 0.88
	_bubble_holder.offset_top = 0.0
	_bubble_holder.offset_bottom = 0.0

func _on_scrim_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if tap:
		_next()

func _next() -> void:
	_step_idx += 1
	_rendered_idx = -1
	if _step_idx >= STEPS.size():
		GameState.mark_controls_tutorial_seen()
		_hide()

func _skip() -> void:
	GameState.mark_controls_tutorial_seen()
	_step_idx = STEPS.size()
	_hide()
