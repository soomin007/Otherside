extends Control

## 타이틀 — 코어 루프의 입구. 여기서 지도(계획 단계)로 들어간다.
## 모바일 우선: 중앙 컬럼에 큰 타이틀 + 풀폭 버튼. 사이즈·레이아웃은 UITheme.

const SettingsPanel := preload("res://scripts/ui/SettingsPanel.gd")

var _stat_label: Label  # 데이터 초기화 후 갱신하려고 들고 있는다

func _ready() -> void:
	var col := UITheme.build_column(self, 22)

	var title := UITheme.make_label("See you on the other side", UITheme.FS_DISPLAY)
	title.add_theme_color_override("font_color", UITheme.FG)
	col.add_child(title)

	col.add_child(UITheme.make_label(
		"누군가 결국 닿을 것을 알 때,\n미래의 나를 위해 지금의 나는 무엇을 포기하는가.",
		UITheme.FS_LABEL, UITheme.SAND))

	_stat_label = UITheme.make_label(_stat_text(), UITheme.FS_SMALL, UITheme.MUTED)
	col.add_child(_stat_label)

	# 버튼 사이 약간의 간격
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	col.add_child(spacer)

	var start := UITheme.make_button("원정 떠나기")
	start.pressed.connect(_on_start_pressed)
	col.add_child(start)

	var settings := UITheme.make_button("설정", false)
	settings.pressed.connect(_on_settings_pressed)
	col.add_child(settings)

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
