extends Control

## 타이틀 — 코어 루프의 입구. 여기서 지도(계획 단계)로 들어간다.
## 모바일 우선: 중앙 컬럼에 큰 타이틀 + 풀폭 버튼. 사이즈·레이아웃은 UITheme.

const SettingsPanel := preload("res://scripts/ui/SettingsPanel.gd")
const EN_TITLE_FONT := preload("res://assets/fonts/Cinzel.ttf")  ## 영어 타이틀 전용(비문풍 세리프)

var _stat_label: Label  # 데이터 초기화 후 갱신하려고 들고 있는다
var _title_tr: TextureRect   ## 타이틀 키아트 배경(있을 때) — 방향 따라 세로/가로 교체
var _title_port: Texture2D   ## 세로본
var _title_land: Texture2D   ## 가로본(_가로) — 없을 수 있음

func _ready() -> void:
	AppSettings.apply_saved()  # 저장된 음량 복원 (앱 시작 = 항상 타이틀 경유)
	# 타이틀 키아트 배경 — 방향 따라 세로/가로(_가로) 교체. 둘 다 없으면 공통 배경(Backdrop) fallback(웹 안전).
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
		_title_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # 화면 꽉 채우기(cover)
		_title_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_title_tr)
		_update_title_art()
		get_viewport().size_changed.connect(_update_title_art)  # 창 크기 바뀌면 방향 재판정
		# 제목·버튼 글씨 가독용 가벼운 어두운 스크림(키아트 위, 컬럼 아래).
		var scrim := ColorRect.new()
		scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
		scrim.color = Color(0.04, 0.04, 0.06, 0.35)
		scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(scrim)
	else:
		add_child(Backdrop.new())  # fallback: 사막 밤 공통 배경
	var col := UITheme.build_column(self, 22)

	var title := UITheme.make_label("See you on the other side", UITheme.FS_DISPLAY)
	title.add_theme_color_override("font_color", UITheme.FG)
	title.add_theme_font_override("font", EN_TITLE_FONT)  # 영어 세리프(Cinzel) — 밋밋한 기본 글씨체 대신
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

	# 각인형 텍스트 메뉴(디자인 핸드오프) — 버튼 박스가 아니라 새긴 글씨. hover 시 모래색 + 밑줄이 번진다.
	var start := EngravedItem.new()
	start.text = "원정을 떠나 보낸다"
	start.is_key = true
	start.add_theme_font_size_override("font_size", UITheme.FS_H2)
	start.pressed.connect(_on_start_pressed)
	col.add_child(start)

	var record := EngravedItem.new()
	record.text = "지난 원정의 기록"
	record.add_theme_font_size_override("font_size", UITheme.FS_LABEL)
	record.pressed.connect(_on_record_pressed)
	col.add_child(record)

	var settings := EngravedItem.new()
	settings.text = "설정"
	settings.add_theme_font_size_override("font_size", UITheme.FS_LABEL)
	settings.pressed.connect(_on_settings_pressed)
	col.add_child(settings)

## 화면 방향에 맞는 타이틀 키아트로 교체(가로면 가로판, 아니면 세로본). 창 리사이즈 시 재호출.
func _update_title_art() -> void:
	if _title_tr == null:
		return
	var r: Vector2 = get_viewport_rect().size
	var land: bool = r.x > r.y
	var t: Texture2D = _title_land if (land and _title_land != null) else _title_port
	if t == null:
		t = _title_land  # 세로본이 없을 때(가로만 있는 경우) 대비
	_title_tr.texture = t

func _stat_text() -> String:
	return "지금까지 보낸 원정 %d 흔적 %d" % [GameState.expedition_count, GameState.traces.size()]

func _on_start_pressed() -> void:
	# 첫 플레이면 오프닝 서사부터, 이후엔 마을(가방 꾸리기)로.
	if GameState.opening_seen:
		GameState.go_to_loadout()
	else:
		GameState.go_to_opening()

func _on_record_pressed() -> void:
	Bookmark._open()  # 상시 책갈피(autoload) — 원정 일대기·조작 안내 열람

func _on_settings_pressed() -> void:
	var panel := SettingsPanel.new()
	panel.data_reset.connect(_on_data_reset)
	add_child(panel)

func _on_data_reset() -> void:
	_stat_label.text = _stat_text()
