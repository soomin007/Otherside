extends Control

## 횡스크롤 단면 — 현재 원정의 체험. 한 걸음씩 전진, 자원 소모, 위협, 흔적.
## 핵심 동사: 관리 · 판독 · 대비 · 남기기 (액션 아님, 턴제 사색형).
## Phase 0 플레이스홀더 — 전진/자원 소모/위협 삼각형/"남김 한 번" 본구현은 추후.
## 지금은 코어 루프(원정 → 죽음 → 흔적 남기기 → 지도 갱신)의 뼈대만 잇는다.

func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var head := Label.new()
	head.text = "원정 %d 전진 중" % GameState.expedition_count
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 28)
	box.add_child(head)

	var res := Label.new()
	res.text = "자원 %s" % str(GameState.carried)
	res.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res.add_theme_color_override("font_color", Color(0.78, 0.64, 0.42))
	box.add_child(res)

	# 죽기 전 단 한 번 남기는 흔적 — Phase 0 에선 시체 자리 + [또][봐] 스텁.
	var die := Button.new()
	die.text = "여기서 끝 (흔적 남기고 죽기)"
	die.custom_minimum_size = Vector2(280, 56)
	die.pressed.connect(_on_die_pressed)
	box.add_child(die)

func _on_die_pressed() -> void:
	var tags: Array[String] = ["또", "봐"]
	var trace := TraceData.new(TraceData.ObjectKind.BODY, GameState.current_leg, tags)
	GameState.leave_trace(trace)
	GameState.record_death(GameState.current_leg)
	GameState.save_game()
	GameState.go_to_map()
