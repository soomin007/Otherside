extends Control

## 타이틀 — 코어 루프의 입구. 여기서 지도(계획 단계)로 들어간다.
## Phase 0 플레이스홀더: UI 는 코드로 구성 (.tscn 은 루트 + 스크립트만).

const SettingsPanel := preload("res://scripts/ui/SettingsPanel.gd")

var _stat_label: Label  # 데이터 초기화 후 갱신하려고 들고 있는다

func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	var title := Label.new()
	title.text = "See you on the other side"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "누군가 결국 닿을 것을 알 때,\n미래의 나를 위해 지금의 나는 무엇을 포기하는가."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.78, 0.64, 0.42))
	box.add_child(sub)

	_stat_label = Label.new()
	_stat_label.text = _stat_text()
	_stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stat_label.add_theme_font_size_override("font_size", 14)
	_stat_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	box.add_child(_stat_label)

	var start := Button.new()
	start.text = "원정 떠나기"
	start.custom_minimum_size = Vector2(220, 56)  # 터치 우선 — 손가락 기준 큼직하게
	start.pressed.connect(_on_start_pressed)
	box.add_child(start)

	var settings := Button.new()
	settings.text = "설정"
	settings.custom_minimum_size = Vector2(220, 56)
	settings.pressed.connect(_on_settings_pressed)
	box.add_child(settings)

func _stat_text() -> String:
	return "지금까지 보낸 원정 %d 흔적 %d" % [GameState.expedition_count, GameState.traces.size()]

func _on_start_pressed() -> void:
	GameState.go_to_map()

func _on_settings_pressed() -> void:
	var panel := SettingsPanel.new()
	panel.data_reset.connect(_on_data_reset)
	add_child(panel)

func _on_data_reset() -> void:
	_stat_label.text = _stat_text()
