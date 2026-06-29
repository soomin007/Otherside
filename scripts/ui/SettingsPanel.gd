extends Control

## 설정창 — 타이틀 위에 띄우는 오버레이. 씬 전환 없이 add_child 로 표시한다.
## 모바일 우선: 어두운 배경 + 가운데 카드 + 풀폭 버튼. 사이즈·색은 UITheme.
## 음량은 master bus 에 연결(placeholder, 저장은 아직 안 함). 핵심은 데이터 초기화 — 확인 다이얼로그와 함께.

signal data_reset  ## 데이터 초기화가 끝났을 때 (부모가 통계 라벨 등을 갱신)

var _confirm: ConfirmationDialog

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# 어두운 배경 — 뒤 입력 차단 + 집중. 빈 곳을 누르면 닫힌다.
	var dim := ColorRect.new()
	dim.color = UITheme.SCRIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	# 가운데 카드 — 클릭이 통과하도록 IGNORE (빈 곳 클릭은 dim 이 받아 닫기)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var card := UITheme.make_card()
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UITheme.GAP)
	card.add_child(box)

	box.add_child(UITheme.make_label("설정", UITheme.FS_H1, UITheme.FG, false))

	# --- 소리 (placeholder: master bus 에 연결, 저장은 아직 안 함) ---
	box.add_child(UITheme.make_label("소리", UITheme.FS_LABEL, UITheme.SAND, false))

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = _current_master_volume()
	slider.custom_minimum_size = Vector2(0, UITheme.SLIDER_H)  # 터치 우선 — 손가락 기준 두툼하게
	slider.value_changed.connect(_on_volume_changed)
	box.add_child(slider)

	box.add_child(HSeparator.new())

	# --- 데이터 초기화 ---
	box.add_child(UITheme.make_label(
		"저장된 세계를 모두 지웁니다.\n원정 기록, 흔적, 죽은 자리가 사라지고 처음부터 시작합니다.",
		UITheme.FS_SMALL, UITheme.MUTED, false))

	var reset_btn := UITheme.make_button("데이터 초기화", false)
	reset_btn.add_theme_color_override("font_color", UITheme.DANGER)
	reset_btn.pressed.connect(_on_reset_pressed)
	box.add_child(reset_btn)

	box.add_child(HSeparator.new())

	var close_btn := UITheme.make_button("닫기")
	close_btn.pressed.connect(_close)
	box.add_child(close_btn)

	# 초기화 확인 다이얼로그 — 실수 방지
	_confirm = ConfirmationDialog.new()
	_confirm.title = "정말 초기화할까요?"
	_confirm.dialog_text = "저장된 세계가 모두 사라집니다.\n되돌릴 수 없습니다."
	_confirm.ok_button_text = "초기화"
	_confirm.get_cancel_button().text = "취소"
	_confirm.confirmed.connect(_on_reset_confirmed)
	add_child(_confirm)

# --- 소리 ---

func _current_master_volume() -> float:
	var idx := AudioServer.get_bus_index("Master")
	if idx < 0:
		return 1.0
	if AudioServer.is_bus_mute(idx):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))

func _on_volume_changed(value: float) -> void:
	var idx := AudioServer.get_bus_index("Master")
	if idx < 0:
		return
	var muted := value <= 0.0001
	AudioServer.set_bus_mute(idx, muted)
	if not muted:
		AudioServer.set_bus_volume_db(idx, linear_to_db(value))

# --- 데이터 초기화 ---

func _on_reset_pressed() -> void:
	_confirm.popup_centered()

func _on_reset_confirmed() -> void:
	GameState.reset_save()
	data_reset.emit()
	_close()

# --- 닫기 ---

func _on_dim_input(event: InputEvent) -> void:
	var clicked: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if clicked:
		_close()

func _input(event: InputEvent) -> void:
	# ESC / 뒤로 — 다이얼로그가 떠 있지 않을 때만 (떠 있으면 다이얼로그가 먼저 받음)
	if event.is_action_pressed("ui_cancel") and not _confirm.visible:
		_close()
		get_viewport().set_input_as_handled()

func _close() -> void:
	queue_free()
