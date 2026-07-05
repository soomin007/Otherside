extends Control

## 설정창 — 타이틀 위에 띄우는 오버레이(씬 전환 없이 add_child).
## 다듬은 모양: 어두운 배경 + 모래 지평선 액센트가 있는 카드. 초기화는 게임 픽션 그대로
##   "모래폭풍이 이 세계를 지운다"로 framing 하되 결과는 명확히. 기본 ConfirmationDialog 대신
##   같은 카드 안에서 확인 화면으로 전환(템플릿 다이얼로그 제거).
## 음량은 AppSettings 가 적용+저장(user://settings.cfg).

signal data_reset  ## 데이터 초기화가 끝났을 때 (부모가 통계 라벨 등을 갱신)

const QUIET_FG := Color(0.82, 0.82, 0.86)
const QUIET_BORDER := Color(0.5, 0.49, 0.56, 0.4)
const DANGER_BORDER := Color(UITheme.DANGER.r, UITheme.DANGER.g, UITheme.DANGER.b, 0.6)
const HORIZON := Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.38)

var _content: VBoxContainer  ## 카드 안 내용(메인 ↔ 확인 전환)
var _music_value: Label
var _sfx_value: Label
var _in_confirm: bool = false
var _pre_mute: float = 0.6   ## 음소거 직전 전체 볼륨(음소거 해제 시 복원)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size  # 오버레이 크기 즉시 확정 — 레이아웃 대기 중 CenterContainer 가 0 → 카드가 왼쪽 위로 쏠리는 것 방지

	# 어두운 배경 — 뒤 입력 차단 + 집중. 빈 곳을 누르면 닫힌다.
	var dim := ColorRect.new()
	dim.color = UITheme.SCRIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var card := UITheme.make_card(480.0)
	center.add_child(card)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 14)
	card.add_child(_content)

	_show_main()

	# 부드럽게 떠오름 (절제된 micro-interaction)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.16).set_ease(Tween.EASE_OUT)

func _clear() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()

# --- 메인 화면 ---

func _show_main() -> void:
	_in_confirm = false
	_clear()

	_content.add_child(UITheme.make_label("설정", UITheme.FS_H1, UITheme.FG, false))
	_content.add_child(UITheme.make_label(
		"원정 %d회 · 흔적 %d · 죽은 자리 %d" % [GameState.expedition_count, GameState.traces.size(), GameState.deaths.size()],
		UITheme.FS_SMALL, UITheme.MUTED, false))
	_content.add_child(UITheme.make_hairline(HORIZON, 2.0))  # 모래 지평선 (시그니처)

	# --- 소리 (배경음악·효과음 따로 + 전체 음소거) ---
	var master := AppSettings.load_master_volume()
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 10)
	var slabel := UITheme.make_label("소리", UITheme.FS_LABEL, UITheme.SAND, false)
	slabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	srow.add_child(slabel)
	var mute := UITheme.make_pill("소리 켜기" if master <= 0.0 else "전체 음소거", QUIET_FG, Color(0, 0, 0, 0), QUIET_BORDER)
	mute.pressed.connect(_toggle_mute)
	srow.add_child(mute)
	_content.add_child(srow)

	_music_value = _add_volume_row("배경음악", AppSettings.load_music_volume(), _on_music_changed, Callable())
	_sfx_value = _add_volume_row("효과음", AppSettings.load_sfx_volume(), _on_sfx_changed, _on_sfx_drag_ended)

	_content.add_child(UITheme.make_hairline())

	# --- 데이터 (모래폭풍 framing, 결과는 명확히) ---
	_content.add_child(UITheme.make_label(
		"저장된 이 세계를 지웁니다.\n원정·흔적·죽은 자리가 모두 사라지고, 처음부터 시작합니다.",
		UITheme.FS_SMALL, UITheme.MUTED, false))
	var wipe := UITheme.make_pill("저장 데이터 지우기", UITheme.DANGER, Color(0, 0, 0, 0), DANGER_BORDER)
	wipe.pressed.connect(_show_confirm)
	_content.add_child(wipe)

	_content.add_child(UITheme.make_hairline())

	var close_btn := UITheme.make_pill("닫기", QUIET_FG, Color(0, 0, 0, 0), QUIET_BORDER)
	close_btn.pressed.connect(_close)
	_content.add_child(close_btn)

# --- 확인 화면 (기본 다이얼로그 대체) ---

func _show_confirm() -> void:
	_in_confirm = true
	_clear()

	_content.add_child(UITheme.make_label("되돌릴 수 없습니다", UITheme.FS_SMALL, UITheme.DANGER, false))
	_content.add_child(UITheme.make_label("이 세계를 지울까요", UITheme.FS_H1, UITheme.FG, false))
	_content.add_child(UITheme.make_hairline(DANGER_BORDER, 2.0))
	_content.add_child(UITheme.make_label(
		"모래폭풍이 모든 원정과 흔적을 쓸어 갑니다. 처음부터 다시 시작합니다.",
		UITheme.FS_SMALL, UITheme.MUTED, false))
	_content.add_child(UITheme.make_label(
		"원정 %d · 흔적 %d 가 사라집니다." % [GameState.expedition_count, GameState.traces.size()],
		UITheme.FS_SMALL, UITheme.MUTED, false))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	_content.add_child(spacer)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var keep := UITheme.make_pill("아니, 둔다", QUIET_FG, Color(0, 0, 0, 0), QUIET_BORDER)
	keep.pressed.connect(_show_main)
	row.add_child(keep)
	var wipe := UITheme.make_pill("지운다", UITheme.FG, UITheme.DANGER, UITheme.DANGER)
	wipe.pressed.connect(_do_reset)
	row.add_child(wipe)
	_content.add_child(row)

func _do_reset() -> void:
	GameState.reset_save()
	data_reset.emit()
	_close()

# --- 소리 ---

## 라벨 + % 값 + 슬라이더 한 묶음을 _content 에 추가하고 % 라벨을 돌려준다.
## on_drag_end 가 유효하면 손을 뗄 때 호출(효과음 미리듣기용).
func _add_volume_row(text: String, vol: float, on_changed: Callable, on_drag_end: Callable) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := UITheme.make_label(text, UITheme.FS_SMALL, QUIET_FG, false)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var value := UITheme.make_label(_pct(vol), UITheme.FS_SMALL, UITheme.MUTED, false)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.autowrap_mode = TextServer.AUTOWRAP_OFF  # "50%" 가 좁은 폭에서 세로로 쪼개지지 않게(가로 유지)
	row.add_child(value)
	_content.add_child(row)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = vol
	slider.custom_minimum_size = Vector2(0, UITheme.SLIDER_H)
	UITheme.style_slider(slider)
	slider.value_changed.connect(on_changed)
	if on_drag_end.is_valid():
		slider.drag_ended.connect(on_drag_end)
	_content.add_child(slider)
	return value

func _on_music_changed(value: float) -> void:
	AppSettings.set_music_volume(value)
	if _music_value != null:
		_music_value.text = _pct(value)

func _on_sfx_changed(value: float) -> void:
	AppSettings.set_sfx_volume(value)
	if _sfx_value != null:
		_sfx_value.text = _pct(value)

## 효과음 슬라이더에서 손을 떼면 탭 소리로 미리듣기 — 배경음악 위에서 실제 크기를 바로 확인.
func _on_sfx_drag_ended(_changed: bool) -> void:
	AudioManager.play_sfx("res://assets/sfx/sfx_tap.wav")

## 전체 음소거 토글 — Master 볼륨을 0 ↔ 직전 값으로. (별도 mute 플래그 없이 볼륨 0 = 음소거로 저장)
func _toggle_mute() -> void:
	var v := AppSettings.load_master_volume()
	if v > 0.0:
		_pre_mute = v
		AppSettings.set_master_volume(0.0)
	else:
		AppSettings.set_master_volume(_pre_mute if _pre_mute > 0.0 else 1.0)
	_show_main()  # 슬라이더·값·버튼 텍스트 갱신

func _pct(v: float) -> String:
	return "%d%%" % int(round(v * 100.0))

# --- 닫기 / 뒤로 ---

func _on_dim_input(event: InputEvent) -> void:
	var clicked: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if clicked:
		_back_or_close()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back_or_close()
		get_viewport().set_input_as_handled()

## 확인 화면이면 메인으로, 아니면 닫는다.
func _back_or_close() -> void:
	if _in_confirm:
		_show_main()
	else:
		_close()

func _close() -> void:
	queue_free()
