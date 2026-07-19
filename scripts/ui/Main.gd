extends Control

## 타이틀 — 코어 루프의 입구(디자인 원본 재현). 로고 상단·각인 메뉴 하단·통계 좌하단·의견 카드 우하단·기록 리본(Bookmark autoload).
## 배경 키아트(방향 자동 교체) + 하단 그라디언트 스크림으로 글씨 가독. 부제 없음(원본 구도).

const EN_TITLE_FONT := preload("res://assets/fonts/Cinzel.ttf")  ## 영어 타이틀·통계 전용(비문풍 세리프)
const LOGO_ART: String = "res://assets/arts/80_로고_제목.png"  ## 게임 로고(§18) — 있으면 텍스트 로고 대신, 오프닝 제목 카드와 공용

var _stat_label: Label
var _title_tr: TextureRect   ## 타이틀 키아트 배경 — 방향 따라 세로/가로 교체
var _title_port: Texture2D
var _title_land: Texture2D

## 제목(로고) 전용 그림자·테두리 튜닝(DEV 슬라이더) — 메뉴 각인 글씨(tune_*)와 별도. 확정값(2026-07-06).
static var title_shadow_a: float = 0.5
static var title_shadow_blur: int = 7
static var title_outline_a: float = 0.2

var _logo_nodes: Array = []   ## 등장 stagger 대상(로고 글로우+글자)
var _logo_lbl: Label          ## 로고 글자(튜닝 적용 대상)
var _menu_node: Control
var _stat_node: Control

# 의견 카드(우하단) — 메뉴 밖 별도 카드(2026-07-19 사용자: 메뉴 바닥에 붙는 느낌 싫음).
var _fb_card: Control
var _fb_label: Label
var _fb_lines: Array = []     ## 위아래 헤어라인(반짝임 대상)
var _fb_hover: bool = false
const FB_COL_REST := Color(0.965, 0.925, 0.831, 0.8)  ## 평상시 글자색(UITheme.FG 의 0.8)

func _ready() -> void:
	AppSettings.apply_saved()  # 저장된 음량 복원(앱 시작 = 항상 타이틀 경유)
	Bookmark.data_reset.connect(_on_data_reset)  # 일지 설정 챕터에서 세계를 지우면 통계 갱신
	AudioManager.play_bed()    # 엔딩곡에서 돌아왔으면 베드로 크로스페이드(이미 베드면 무시)
	AudioManager.set_wind(0.0) # 타이틀 = 무풍(바람은 여정에서만)
	_build_background()
	_build_logo()
	_build_menu()
	_build_stat()
	_build_feedback_card()
	# 등장 stagger(스펙 inScatter) — 로고 → 메뉴 → 통계 → 의견 카드 순으로 "모래가 모여 형체를 이루듯".
	# 구현은 Transition.appear(공용) — 배경(키아트)은 움직이지 않는다(원칙: 배경/UI 분리).
	for n in _logo_nodes:
		Transition.appear(n, 0.08)
	if _menu_node != null:
		Transition.appear(_menu_node, 0.16)
	if _stat_node != null:
		Transition.appear(_stat_node, 0.30)
	if _fb_card != null:
		Transition.appear(_fb_card, 0.42)

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

	# 하단 그라디언트 스크림(원본: 하단 56% 투명→어둠 .78) — 메뉴·통계 가독.
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(0.035, 0.024, 0.016, 0.0), Color(0.035, 0.024, 0.016, 0.78)])
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
	# 로고 뒤 어두운 방사 글로우 — 글씨마다 그림자 대신 영역 언저리에 두꺼운 어둠(밝은 배경에서 가독 + 무게).
	var glow := _dark_glow()
	add_child(glow)
	var logo: Control
	if ResourceLoader.exists(LOGO_ART):
		logo = _logo_image()  # 로고 이미지(80) — 텍스트 로고와 같은 상단 띠
	else:
		var lbl := _logo_label(UITheme.FG, 0.0, 0.0)
		_logo_lbl = lbl  # 텍스트일 때만 DEV 제목 튜닝 대상
		logo = lbl
	logo.add_to_group("ui_scatter")  # 전환 OUT 때 UI 만 흩어짐(글로우=배경층이라 제외)
	add_child(logo)
	_logo_nodes = [glow, logo]
	add_to_group("title_screen")  # DEV 제목 튜닝 브로드캐스트 대상
	apply_title_tuning()

## 로고 이미지 한 겹 — 텍스트 로고 자리(상단 띠)에 contain. 뒤 글로우·등장 stagger 는 그대로.
func _logo_image() -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = load(LOGO_ART)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.anchor_left = 0.0
	tr.anchor_right = 1.0
	tr.anchor_top = 0.10
	tr.anchor_bottom = 0.34
	tr.offset_left = 40.0
	tr.offset_right = -40.0
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

## 제목 그림자·테두리 적용 — DEV "제목 튜닝" 슬라이더가 그룹 호출.
func apply_title_tuning() -> void:
	if _logo_lbl == null:
		return
	_logo_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, title_shadow_a))
	_logo_lbl.add_theme_constant_override("shadow_outline_size", title_shadow_blur)
	_logo_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, title_outline_a))
	_logo_lbl.add_theme_constant_override("outline_size", 4)

## 로고 뒤 어두운 방사 그라디언트(중앙 어둠 → 가장자리 투명). 로고를 넓게 감싼다.
## 스펙 (a): radial 58%×42% at (50%,25%), rgba(16,10,5,.55) → transparent 70%.
func _dark_glow() -> TextureRect:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	grad.colors = PackedColorArray([
		Color(0.063, 0.039, 0.020, 0.55),
		Color(0.063, 0.039, 0.020, 0.14),
		Color(0.063, 0.039, 0.020, 0.0),
	])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 128
	var tr := TextureRect.new()
	tr.texture = gt
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	# 타원 58%×42%가 (50%,25%)에 놓이는 외접 rect — 화면 기준 anchors.
	tr.anchor_left = -0.08
	tr.anchor_right = 1.08
	tr.anchor_top = -0.17
	tr.anchor_bottom = 0.67
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

## 로고 한 겹. col=색(그림자는 검은 저알파, 본체는 아이보리), dx/dy=오프셋(그림자 겹치기용).
func _logo_label(col: Color, dx: float, dy: float) -> Label:
	var l := Label.new()
	l.text = "See you on the\nother side"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var fv := FontVariation.new()
	fv.base_font = EN_TITLE_FONT
	fv.set_spacing(TextServer.SPACING_GLYPH, 3)  # letter-spacing .045em × 62 ≈ 3px
	fv.variation_opentype = {"wght": 700}  # Cinzel 가변 폰트 — bold(사용자 확정). 소문자는 폰트 특성상 스몰캡
	l.add_theme_font_override("font", fv)
	l.add_theme_font_size_override("font_size", 62)
	l.add_theme_constant_override("line_spacing", 2)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = 0.13
	l.anchor_bottom = 0.32
	l.offset_left = 40.0 + dx
	l.offset_right = -40.0 + dx
	l.offset_top = dy
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# --- 각인 메뉴(하단 13%) ---

func _build_menu() -> void:
	# 메뉴 뒤 은은한 방사 어둠(스펙 Legibility (c)) — 스크림 위 한 겹 더, 메뉴 글씨만 감싼다.
	var mg := _menu_glow()
	add_child(mg)
	var menu := VBoxContainer.new()
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation", 2)
	menu.anchor_left = 0.0
	menu.anchor_right = 1.0
	menu.anchor_top = 0.58
	menu.anchor_bottom = 0.87  # 하단 13%
	menu.add_to_group("ui_scatter")
	add_child(menu)
	_menu_node = menu

	# 길 위에 원정이 있으면 "이어서" — 서스펜드 저장(한 슬롯, 시점 선택 없음). 새 원정은 그 원정이 끝나야.
	var start := EngravedItem.new()
	start.init_item("원정 이어가기" if GameState.has_resumable_run() else "원정을 떠난다", 27, true)
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

## 메뉴 뒤 방사 어둠 — 중앙 하단(메뉴 영역)만 은은하게(가장자리 투명).
func _menu_glow() -> TextureRect:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	grad.colors = PackedColorArray([
		Color(0.03, 0.02, 0.01, 0.38),
		Color(0.03, 0.02, 0.01, 0.18),
		Color(0.03, 0.02, 0.01, 0.0),
	])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 128
	var tr := TextureRect.new()
	tr.texture = gt
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.anchor_left = 0.14
	tr.anchor_right = 0.86
	tr.anchor_top = 0.52
	tr.anchor_bottom = 0.95
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

# --- 통계(좌하단) ---

func _build_stat() -> void:
	_stat_label = Label.new()
	_stat_label.text = _stat_text()
	var fv := FontVariation.new()
	var base := get_theme_default_font()  # 마루부리(한글 포함) — Cinzel 은 한글 글리프가 없어 통계 한글이 두부(□)로 깨짐
	if base != null:
		fv.base_font = base
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
	_stat_label.add_to_group("ui_scatter")
	add_child(_stat_label)
	_stat_node = _stat_label

func _stat_text() -> String:
	return "보낸 원정 %d  ·  남긴 흔적 %d" % [GameState.expedition_count, GameState.traces.size()]

# --- 의견 카드(우하단) ---

## 의견 설문(구글 폼) 진입 카드 — 메뉴 항목이 아니라 우하단의 독립 카드.
## 각인 문법(방사 어둠 + 모래 헤어라인 위아래)의 작은 판. 가죽 상자 카드는 게임 화면 금지(2026-07-06)라 안 쓴다.
## 몇 초마다 글자와 헤어라인에 모래색이 배었다가 돌아온다(반짝임 — 2026-07-19 사용자 요청).
func _build_feedback_card() -> void:
	if GameState.FEEDBACK_URL.is_empty():
		return  # 폼 개설 전 — 카드 자체를 만들지 않는다
	var card := Button.new()
	card.flat = true
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		card.add_theme_stylebox_override(s, empty)
	# 우하단 코너 — 통계(좌하단)와 대칭, 일지 리본(우상단)과 안 겹침. 터치 타깃 68px(>56).
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.anchor_top = 1.0
	card.anchor_bottom = 1.0
	card.offset_left = -236.0
	card.offset_right = -36.0
	card.offset_top = -104.0
	card.offset_bottom = -36.0
	card.pressed.connect(_on_feedback_pressed)
	card.mouse_entered.connect(func() -> void:
		_fb_hover = true
		_fb_apply(1.0))
	card.mouse_exited.connect(func() -> void:
		_fb_hover = false
		_fb_apply(0.0))
	UITheme.attach_dark_pool(card, 1.7, 0.8)  # 상자 대신 뒤를 가라앉혀 판으로 세운다
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var top_line := UITheme.make_hairline(Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.35), 1.0)
	box.add_child(top_line)
	_fb_label = Label.new()
	_fb_label.text = "의견 보내기"
	_fb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fb_label.add_theme_font_size_override("font_size", 18)
	_fb_label.add_theme_color_override("font_color", FB_COL_REST)
	_fb_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	_fb_label.add_theme_constant_override("shadow_offset_y", 2)
	_fb_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_fb_label)
	var bot_line := UITheme.make_hairline(Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.35), 1.0)
	box.add_child(bot_line)
	_fb_lines = [top_line, bot_line]
	card.add_to_group("ui_scatter")
	add_child(card)
	_fb_card = card
	# 주기 반짝임 — 4초쯤마다 1.5초 동안 모래색이 스며들었다 돌아온다(sin 곡선, 셰이더 없이 웹 안전).
	var tw := card.create_tween().set_loops()
	tw.tween_interval(4.2)
	tw.tween_method(_fb_glint, 0.0, 1.0, 1.5)

## 반짝임 한 순간 — t 0→1 을 sin 으로 0→1→0 강도로 바꿔 적용. hover 중엔 최대 강도 유지.
func _fb_glint(t: float) -> void:
	_fb_apply(maxf(sin(t * PI), 1.0 if _fb_hover else 0.0))

## 카드 강조 강도 적용(k 0=평상시, 1=모래색 만개) — 글자색과 헤어라인이 함께 물든다.
func _fb_apply(k: float) -> void:
	if _fb_label != null:
		_fb_label.add_theme_color_override("font_color", FB_COL_REST.lerp(UITheme.SAND, k))
	for hl in _fb_lines:
		var line := hl as ColorRect
		if line != null:
			line.color = Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, lerpf(0.35, 0.9, k))

# --- 액션 ---

func _on_start_pressed() -> void:
	if GameState.has_resumable_run():
		GameState.resume_run()  # 떠났던 자리에서 잇는다(엣지 위=지도, 노드=그 노드 화면)
	elif GameState.opening_seen:
		GameState.go_to_loadout()
	else:
		GameState.go_to_opening()

func _on_record_pressed() -> void:
	Bookmark.open_journal(0)  # 원정 일지(autoload) — 일대기 챕터

func _on_settings_pressed() -> void:
	Bookmark.open_journal(Bookmark.CH_SETTINGS)  # 원정 일지의 설정 챕터(옛 별도 장부는 일지로 흡수 통합)

func _on_feedback_pressed() -> void:
	GameState.open_feedback()  # 새 탭(웹)/브라우저(데스크톱) — pressed 컨텍스트라 팝업 차단 없음

func _on_data_reset() -> void:
	_stat_label.text = _stat_text()
