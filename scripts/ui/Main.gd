extends Control

## 타이틀 — 코어 루프의 입구(디자인 원본 재현). 로고 상단·각인 메뉴 하단·통계 좌하단·기록 좌상단(Bookmark autoload).
## 배경 키아트(방향 자동 교체) + 하단 그라디언트 스크림으로 글씨 가독. 부제 없음(원본 구도).

const SettingsPanel := preload("res://scripts/ui/SettingsPanel.gd")
const EN_TITLE_FONT := preload("res://assets/fonts/Cinzel.ttf")  ## 영어 타이틀·통계 전용(비문풍 세리프)

var _stat_label: Label
var _title_tr: TextureRect   ## 타이틀 키아트 배경 — 방향 따라 세로/가로 교체
var _title_port: Texture2D
var _title_land: Texture2D

func _ready() -> void:
	AppSettings.apply_saved()  # 저장된 음량 복원(앱 시작 = 항상 타이틀 경유)
	_build_background()
	_build_logo()
	_build_menu()
	_build_stat()

# --- 배경(키아트 + 스크림) ---

func _build_background() -> void:
	const TITLE_ART: String = "res://assets/arts/29_타이틀_키아트.png"
	const TITLE_ART_LAND: String = "res://assets/arts/29_타이틀_키아트_가로.png"
	if ResourceLoader.exists(TITLE_ART):
		_title_port = load(TITLE_ART)
	if ResourceLoader.exists(TITLE_ART_LAND):
		_title_land = load(TITLE_ART_LAND)
	if _title_port != null or _title_land != null:
		_title_tr = TextureRect.new()
		_title_tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		_title_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_title_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # 화면 꽉(cover)
		_title_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_title_tr)
		_update_title_art()
		get_viewport().size_changed.connect(_update_title_art)
	else:
		add_child(Backdrop.new())  # fallback: 사막 밤 공통 배경

	# 하단 그라디언트 스크림(원본: 하단 56% 투명→어둠) — 메뉴·통계 가독.
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(0.035, 0.024, 0.016, 0.0), Color(0.035, 0.024, 0.016, 0.82)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_LINEAR
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 8
	gt.height = 128
	var bot := TextureRect.new()
	bot.texture = gt
	bot.stretch_mode = TextureRect.STRETCH_SCALE
	bot.set_anchors_preset(Control.PRESET_FULL_RECT)
	bot.anchor_top = 0.44  # 하단 56%
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bot)

func _update_title_art() -> void:
	if _title_tr == null:
		return
	var r: Vector2 = get_viewport_rect().size
	var land: bool = r.x > r.y
	var t: Texture2D = _title_land if (land and _title_land != null) else _title_port
	if t == null:
		t = _title_land
	_title_tr.texture = t

# --- 로고(상단 15%) ---

func _build_logo() -> void:
	var logo := Label.new()
	logo.text = "See you on the\nother side"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var fv := FontVariation.new()
	fv.base_font = EN_TITLE_FONT
	fv.set_spacing(TextServer.SPACING_GLYPH, 3)  # letter-spacing .045em × 62 ≈ 3px
	logo.add_theme_font_override("font", fv)
	logo.add_theme_font_size_override("font_size", 62)
	logo.add_theme_constant_override("line_spacing", 2)
	logo.add_theme_color_override("font_color", UITheme.FG)  # ivory
	logo.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	logo.add_theme_constant_override("shadow_offset_x", 0)
	logo.add_theme_constant_override("shadow_offset_y", 4)
	logo.add_theme_constant_override("shadow_outline_size", 4)  # 은은한 후광(원본은 부드러운 큰 blur — Godot 한계로 얇게 근사)
	logo.anchor_left = 0.0
	logo.anchor_right = 1.0
	logo.anchor_top = 0.15
	logo.anchor_bottom = 0.15
	logo.offset_left = 40.0
	logo.offset_right = -40.0
	logo.grow_vertical = Control.GROW_DIRECTION_BOTH
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)

# --- 각인 메뉴(하단 13%) ---

func _build_menu() -> void:
	var menu := VBoxContainer.new()
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation", 2)
	menu.anchor_left = 0.0
	menu.anchor_right = 1.0
	menu.anchor_top = 0.58
	menu.anchor_bottom = 0.87  # 하단 13%
	add_child(menu)

	var start := EngravedItem.new()
	start.init_item("원정을 떠나 보낸다", 27, true)
	start.pressed.connect(_on_start_pressed)
	menu.add_child(start)

	var record := EngravedItem.new()
	record.init_item("지난 원정의 기록", 22, false)
	record.pressed.connect(_on_record_pressed)
	menu.add_child(record)

	var settings := EngravedItem.new()
	settings.init_item("설정", 22, false)
	settings.pressed.connect(_on_settings_pressed)
	menu.add_child(settings)

# --- 통계(좌하단) ---

func _build_stat() -> void:
	_stat_label = Label.new()
	_stat_label.text = _stat_text()
	var fv := FontVariation.new()
	fv.base_font = EN_TITLE_FONT
	fv.set_spacing(TextServer.SPACING_GLYPH, 3)  # letter-spacing .24em × 12 ≈ 3px
	_stat_label.add_theme_font_override("font", fv)
	_stat_label.add_theme_font_size_override("font_size", 12)
	_stat_label.add_theme_color_override("font_color", Color(UITheme.FG.r, UITheme.FG.g, UITheme.FG.b, 0.55))
	_stat_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_stat_label.add_theme_constant_override("shadow_offset_y", 2)
	_stat_label.anchor_left = 0.0
	_stat_label.anchor_top = 1.0
	_stat_label.anchor_bottom = 1.0
	_stat_label.offset_left = 40.0
	_stat_label.offset_top = -48.0
	_stat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stat_label)

func _stat_text() -> String:
	return "보낸 원정 %d  ·  남긴 흔적 %d" % [GameState.expedition_count, GameState.traces.size()]

# --- 액션 ---

func _on_start_pressed() -> void:
	if GameState.opening_seen:
		GameState.go_to_loadout()
	else:
		GameState.go_to_opening()

func _on_record_pressed() -> void:
	Bookmark._open()  # 상시 책갈피(autoload) — 원정 일대기·조작 안내

func _on_settings_pressed() -> void:
	var panel := SettingsPanel.new()
	panel.data_reset.connect(_on_data_reset)
	add_child(panel)

func _on_data_reset() -> void:
	_stat_label.text = _stat_text()
