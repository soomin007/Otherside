extends Control

## 엔딩 슬라이드쇼 — 순환/재회 (기획서 §3 결말). 오프닝식 삽화 + 내레이션 크로스페이드.
##  순환(cycle): 슬라이드 3장(47~49) → 암전 → 3초 후 "아무 키나 눌러 계속" → 타이틀. 49 에 언더테일식 암시.
##  재회(reunion): 슬라이드 3장(50~52) + `Other Side` 크레딧곡 → 타이틀.
## kind 는 GameState.ending_kind_pending 로 주입(Expedition._show_ending). 어느 쪽이든 끝나면 타이틀 복귀.

const FADE: float = 1.1
const CYCLE_SLIDES: Array = [
	{"img": "res://assets/arts/47_엔딩순환_도착.png", "text": "재앙의 자리엔, 먼저 간 원정대가 서 있었다."},
	{"img": "res://assets/arts/48_엔딩순환_밀어냄.png", "text": "멈추려면 그를 밀어내야 했다.\n이제 이 자리에 선 것은 우리다."},
	{"img": "res://assets/arts/49_엔딩순환_이어짐.png", "text": "곧 다음 원정대가 이곳을 향해 온다.\n릴레이는 멈추지 않는다."},
]
const REUNION_SLIDES: Array = [
	{"img": "res://assets/arts/50_엔딩재회_닿음.png", "text": "목적지에 닿았다. 죽지 않고, 온전히."},
	{"img": "res://assets/arts/51_엔딩재회_지나쳐.png", "text": "밀어내지 않아도 되었다.\n지나쳐, 건너편으로."},
	{"img": "res://assets/arts/52_엔딩재회_모두.png", "text": "먼저 간 모든 원정대가 기다리고 있었다.\n릴레이가 멈춘다. 드디어 그쪽에서 만난다."},
]

var _slides: Array = []
var _reunion: bool = false
var _idx: int = -1
var _phase: String = "slides"   ## slides / prompt / blackout
var _busy: bool = false          ## 페이드 중 입력 무시

var _illus: TextureRect
var _label: Label
var _dim: ColorRect
var _prompt: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size   # 오버레이 크기 즉시 확정(레이아웃 패스 전 size 0 방지 — known_issues)
	_reunion = (GameState.ending_kind_pending == "reunion")
	_slides = REUNION_SLIDES if _reunion else CYCLE_SLIDES
	_build()
	if _reunion:
		AudioManager.play_reunion()   # 크레딧곡(잔잔 베드 → Other Side 크로스페이드)
	_advance()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP  # 뒤(Expedition) 입력 차단 + 탭 감지
	bg.gui_input.connect(_on_bg_input)
	add_child(bg)

	_illus = TextureRect.new()
	_illus.set_anchors_preset(Control.PRESET_FULL_RECT)
	_illus.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_illus.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # 화면 꽉(가로 아트)
	_illus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_illus.modulate.a = 0.0
	add_child(_illus)

	# 하단 어둠 — 내레이션 가독
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.02, 0.04, 0.5)
	scrim.anchor_left = 0.0
	scrim.anchor_right = 1.0
	scrim.anchor_top = 0.6
	scrim.anchor_bottom = 1.0
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", UITheme.FS_H2)
	_label.add_theme_color_override("font_color", UITheme.FG)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.anchor_left = 0.08
	_label.anchor_right = 0.92
	_label.anchor_top = 0.72
	_label.anchor_bottom = 0.92
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.modulate.a = 0.0
	add_child(_label)

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", UITheme.FS_SMALL)
	_prompt.add_theme_color_override("font_color", UITheme.MUTED)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.anchor_left = 0.0
	_prompt.anchor_right = 1.0
	_prompt.anchor_top = 0.82
	_prompt.anchor_bottom = 0.9
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.modulate.a = 0.0
	add_child(_prompt)

	var skip := UITheme.make_button("건너뛰기", false)
	skip.custom_minimum_size = Vector2(140, UITheme.BTN_H_SM)
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.offset_left = -140.0 - UITheme.PAD
	skip.offset_top = UITheme.SAFE
	skip.offset_right = -UITheme.PAD
	skip.pressed.connect(_exit)   # 건너뛰기 = 바로 타이틀
	add_child(skip)

# --- 진행 ---

## 다음 슬라이드로 (또는 끝). 삽화·내레이션 함께 크로스페이드.
func _advance() -> void:
	if _busy or _phase != "slides":
		return
	_idx += 1
	if _idx >= _slides.size():
		_end_slides()
		return
	_busy = true
	var slide: Dictionary = _slides[_idx]
	var img: String = str(slide["img"])
	var tex: Texture2D = load(img) if ResourceLoader.exists(img) else null
	var t := create_tween()
	t.tween_property(_label, "modulate:a", 0.0, FADE * 0.5)
	t.parallel().tween_property(_illus, "modulate:a", 0.0, FADE * 0.5)
	t.tween_callback(_apply_slide.bind(tex, str(slide["text"])))
	t.tween_property(_illus, "modulate:a", 1.0, FADE * 0.7)
	t.parallel().tween_property(_label, "modulate:a", 1.0, FADE)
	t.tween_callback(_clear_busy)

func _apply_slide(tex: Texture2D, text: String) -> void:
	_illus.texture = tex
	_label.text = text

func _clear_busy() -> void:
	_busy = false

## 마지막 슬라이드 후 — 재회는 크레딧 여운, 순환은 암전 후 안내.
func _end_slides() -> void:
	if _reunion:
		_phase = "prompt"
		_reveal_prompt("여기까지.  아무 키나 누르면 돌아갑니다.")
	else:
		_phase = "blackout"
		AudioManager.fade_out(2.5)   # 여운을 위해 음악도 서서히
		var t := create_tween()
		t.tween_property(_dim, "color:a", 1.0, 2.5)   # 암전
		t.tween_interval(3.0)                          # 3초 여운
		t.tween_callback(_reveal_prompt.bind("아무 키나 눌러 계속"))

func _reveal_prompt(text: String) -> void:
	_prompt.text = text
	var t := create_tween()
	t.tween_property(_prompt, "modulate:a", 1.0, 1.3)

func _exit() -> void:
	GameState.ending_kind_pending = ""
	GameState.go_to_title()

# --- 입력: 탭/키로 진행 ---

## 탭(배경 STOP 이 받음) / 키 로 진행. 배경이 Expedition 입력도 막는다.
func _on_bg_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_handle_go()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_go()

func _handle_go() -> void:
	match _phase:
		"slides":
			_advance()
		"prompt":
			_exit()
		"blackout":
			if _prompt.modulate.a > 0.5:   # 안내 문구가 뜬 뒤에만
				_exit()
