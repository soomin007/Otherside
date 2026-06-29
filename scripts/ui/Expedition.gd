extends Control

## 횡스크롤 단면 — 현재 원정의 체험. 한 걸음씩 전진, 자원 소모, 흔적.
## 핵심 동사: 관리·판독·대비·남기기 (턴제 사색형). 이 프로토타입의 목적은 "걸음마다 닳는 자원"
## 페이싱이 작동하는지, 한 걸음마다 결정할 게 있는지 체감하는 것.
## 로직은 core/ExpeditionRun(순수), 여기선 렌더링·입력만 한다. 그림은 _draw 로 그려 웹 안전(셰이더/GPUParticles 없음).

const GROUND_RATIO: float = 0.62        ## 지면 y 위치 (화면 높이 비율)
const STEP_PX: float = 90.0             ## 한 걸음의 화면 거리
const WALKER_SCREEN_RATIO: float = 0.35 ## 걷는 이를 화면 어디에 고정할지 (앞을 보도록 왼쪽)

var _run: ExpeditionRun

var _status_label: Label
var _water_label: Label
var _food_label: Label
var _aux_label: Label
var _advance_btn: Button
var _end_btn: Button
var _death_panel: Control
var _death_label: Label

func _ready() -> void:
	_run = GameState.current_run
	if _run == null:
		# 안전장치: 지도를 거치지 않고 직접 이 씬으로 들어온 경우 (씬 전환 없이) 새 원정만 만든다.
		GameState.begin_run_in_place()
		_run = GameState.current_run
	_build_hud()
	_refresh()

func _build_hud() -> void:
	# 상단 좌측 — 상태/자원 readout
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top.position = Vector2(20, 16)
	top.add_theme_constant_override("separation", 4)
	add_child(top)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	top.add_child(_status_label)

	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 20)
	top.add_child(res_row)

	_water_label = Label.new()
	_water_label.add_theme_font_size_override("font_size", 22)
	res_row.add_child(_water_label)

	_food_label = Label.new()
	_food_label.add_theme_font_size_override("font_size", 22)
	res_row.add_child(_food_label)

	_aux_label = Label.new()
	_aux_label.add_theme_font_size_override("font_size", 14)
	_aux_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	top.add_child(_aux_label)

	# 하단 중앙 — 전진 / 끝 버튼 (터치 우선, 큼직하게)
	var bar := CenterContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -110
	bar.offset_bottom = -24
	add_child(bar)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 16)
	bar.add_child(btns)

	_advance_btn = Button.new()
	_advance_btn.text = "전진 (한 걸음)"
	_advance_btn.custom_minimum_size = Vector2(220, 64)
	_advance_btn.pressed.connect(_on_advance)
	btns.add_child(_advance_btn)

	_end_btn = Button.new()
	_end_btn.text = "여기서 끝 (남기고 죽기)"
	_end_btn.custom_minimum_size = Vector2(240, 64)
	_end_btn.pressed.connect(_on_end)
	btns.add_child(_end_btn)

	# 죽음 패널 (처음엔 숨김)
	_death_panel = Control.new()
	_death_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_panel.visible = false
	add_child(_death_panel)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.04, 0.06, 0.82)
	_death_panel.add_child(dim)

	var dcenter := CenterContainer.new()
	dcenter.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_panel.add_child(dcenter)

	var dbox := VBoxContainer.new()
	dbox.alignment = BoxContainer.ALIGNMENT_CENTER
	dbox.add_theme_constant_override("separation", 18)
	dcenter.add_child(dbox)

	_death_label = Label.new()
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.add_theme_font_size_override("font_size", 22)
	dbox.add_child(_death_label)

	var to_map := Button.new()
	to_map.text = "지도로 돌아가기"
	to_map.custom_minimum_size = Vector2(220, 56)
	to_map.pressed.connect(_on_to_map)
	dbox.add_child(to_map)

func _refresh() -> void:
	_status_label.text = "원정 %d째 · %d걸음 전진" % [GameState.expedition_count, _run.leg]
	var water: int = maxi(0, _run.get_res("water"))
	var food: int = maxi(0, _run.get_res("food"))
	_water_label.text = "물 %d" % water
	_food_label.text = "식량 %d" % food
	_water_label.add_theme_color_override("font_color", _res_color(water, 3, Color(0.55, 0.75, 0.95)))
	_food_label.add_theme_color_override("font_color", _res_color(food, 2, Color(0.85, 0.7, 0.4)))
	_aux_label.text = "로프 %d · 은신처 %d  (남길 수 있는 것)" % [_run.get_res("rope"), _run.get_res("shelter")]
	queue_redraw()

func _res_color(value: int, low: int, base: Color) -> Color:
	return Color(0.92, 0.36, 0.3) if value <= low else base

# --- 입력 ---

func _on_advance() -> void:
	if not _run.alive:
		return
	_run.step()
	_refresh()
	if not _run.alive:
		_die(_run.death_cause)

func _on_end() -> void:
	if not _run.alive:
		return
	_die("chosen")

func _on_to_map() -> void:
	GameState.go_to_map()

# --- 죽음 / 남김 한 번 ---

func _die(cause: String) -> void:
	var tags: Array[String] = _death_tags(cause)
	var trace := TraceData.new(TraceData.ObjectKind.BODY, _run.leg, tags)
	GameState.leave_trace(trace)
	GameState.record_death(_run.leg)
	GameState.save_game()
	_show_death(cause, tags)

## 죽음의 사인에 따라 남길 태그를 고른다 (WordPool 어휘). untyped 리터럴은 assign 으로 안전 대입.
func _death_tags(cause: String) -> Array[String]:
	var out: Array[String] = []
	match cause:
		"thirst": out.assign(["갈증", "끝"])
		"hunger": out.assign(["없다", "끝"])
		"chosen": out.assign(["또", "봐"])
		_: out.assign(["끝"])
	return out

func _death_message(cause: String) -> String:
	match cause:
		"thirst": return "물이 떨어졌다. 여기서 갈증으로 끝났다."
		"hunger": return "식량이 떨어졌다. 더 가지 못했다."
		"chosen": return "여기서 멈추기로 했다. 다음 나에게 남긴다."
		_: return "여기서 끝났다."

func _show_death(cause: String, tags: Array[String]) -> void:
	_advance_btn.disabled = true
	_end_btn.disabled = true
	_death_label.text = "%s\n\n남긴 흔적: [ %s ]" % [_death_message(cause), " · ".join(PackedStringArray(tags))]
	_death_panel.visible = true
	queue_redraw()

# --- 횡스크롤 단면 렌더링 (_draw) ---

func _draw() -> void:
	var rect: Vector2 = size
	if rect.x <= 0.0 or rect.y <= 0.0 or _run == null:
		return
	var ground_y: float = rect.y * GROUND_RATIO
	var walker_x: float = rect.x * WALKER_SCREEN_RATIO
	var offset: float = walker_x - _run.leg * STEP_PX

	# 지면 — 단색 (웹 안전)
	draw_rect(Rect2(0.0, ground_y, rect.x, rect.y - ground_y), Color(0.11, 0.10, 0.13))
	draw_line(Vector2(0.0, ground_y), Vector2(rect.x, ground_y), Color(0.3, 0.28, 0.24), 2.0)

	var font: Font = ThemeDB.fallback_font
	# 걸음 눈금 (5걸음마다 숫자)
	var first_leg: int = maxi(int(floor((0.0 - offset) / STEP_PX)) - 1, 0)
	var last_leg: int = int(ceil((rect.x - offset) / STEP_PX)) + 1
	for i in range(first_leg, last_leg + 1):
		var x: float = i * STEP_PX + offset
		draw_line(Vector2(x, ground_y - 6.0), Vector2(x, ground_y + 6.0), Color(0.25, 0.24, 0.21), 1.0)
		if i % 5 == 0 and font != null:
			draw_string(font, Vector2(x - 8.0, ground_y + 24.0), str(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 0.4, 0.42))

	# 과거의 나 — 남긴 흔적 점 (self-async)
	for t in GameState.loaded_traces():
		var tx: float = t.leg * STEP_PX + offset
		if tx < -20.0 or tx > rect.x + 20.0:
			continue
		draw_circle(Vector2(tx, ground_y - 10.0), 5.0, Color(0.78, 0.64, 0.42))
		if not t.tags.is_empty() and font != null:
			draw_string(font, Vector2(tx - 16.0, ground_y - 22.0), " ".join(PackedStringArray(t.tags)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.6, 0.45))

	# 걷는 이
	_draw_walker(Vector2(walker_x, ground_y), _run.alive)

func _draw_walker(foot: Vector2, alive: bool) -> void:
	var col: Color = Color(0.9, 0.9, 0.92) if alive else Color(0.55, 0.32, 0.32)
	if alive:
		draw_line(Vector2(foot.x, foot.y), Vector2(foot.x, foot.y - 26.0), col, 3.0)
		draw_circle(Vector2(foot.x, foot.y - 34.0), 7.0, col)
	else:
		# 쓰러진 자리 — 가로로 누움
		draw_line(Vector2(foot.x - 14.0, foot.y - 4.0), Vector2(foot.x + 14.0, foot.y - 4.0), col, 3.0)
		draw_circle(Vector2(foot.x - 18.0, foot.y - 4.0), 7.0, col)
