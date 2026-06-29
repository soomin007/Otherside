extends Control

## 탑뷰 지도 — 누적된 길 / 죽음의 역사 / 남긴 흔적의 점. 여기서 이번 원정을 계획하고 출발한다.
## "후대가 곧 나" 라는 구조의 시각화이자 주제를 보여주는 창.
## Phase 0 플레이스홀더 — 안개 걷힘 / 경로 / 죽은 자리 / 흔적 점 렌더링은 추후.

func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var head := Label.new()
	head.text = "지도 · 원정 계획"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", UITheme.FS_HEADING)
	box.add_child(head)

	var info := Label.new()
	info.text = "이 세계에 놓인 흔적 %d개 죽은 자리 %d곳" % [GameState.traces.size(), GameState.deaths.size()]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", UITheme.FS_SMALL)
	info.add_theme_color_override("font_color", UITheme.MUTED)
	box.add_child(info)

	var embark := UITheme.make_button("출발")
	embark.pressed.connect(_on_embark_pressed)
	box.add_child(embark)

func _on_embark_pressed() -> void:
	GameState.start_expedition()
