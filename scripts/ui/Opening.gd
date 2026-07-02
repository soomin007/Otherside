extends Control

## 오프닝 서사 슬라이드쇼 — 첫 플레이 자동 재생(이후 스킵, GameState.opening_seen).
## 담담·서늘, 맥거핀 유지(재앙 정체는 안 밝힌다). 탭/클릭으로 넘기고 마지막 제목 카드 뒤 지도로. 건너뛰기 가능.
## 기획서 §0·§2 세계관을 각색.

const SLIDES: Array = [
	"해마다, 재앙을 멈추러 원정대가 떠난다.",
	"거의 다 도중에 죽는다.\n한 번에 닿은 이는 아직 없었다.",
	"모래폭풍이 글을 지우는 땅.\n말은 남지 않는다. 물건만 남는다.",
	"너는 그들을 거듭 보내는 자.\n매번 다른 이가 떠나고, 너는 그 사실을 안다.",
	"죽기 전 단 한 번.\n다음 원정대에게 무엇을 남길지,\n그것만이 네 몫이다.",
]
const TITLE_TEXT: String = "See you on the other side"
const FADE: float = 0.6

## 슬라이드별 배경 삽화(SLIDES 와 1:1). 없으면 삽화 없이 Backdrop 만(fallback).
const ILLUS_PATHS: Array = [
	"res://assets/arts/24_오프닝_떠난다.png",
	"res://assets/arts/25_오프닝_죽는다.png",
	"res://assets/arts/26_오프닝_지운다.png",
	"res://assets/arts/27_오프닝_보내는자.png",
	"res://assets/arts/28_오프닝_남긴다.png",
]

var _idx: int = 0
var _label: Label
var _hint: Label
var _title_mode: bool = false
var _illus: TextureRect            ## 슬라이드 배경 삽화(있을 때만). 넘길 때 크로스페이드.
var _illus_tex: Array = []         ## 로드된 Texture2D(없으면 null)

func _ready() -> void:
	add_child(Backdrop.new())  # 사막 밤 공통 배경(맨 뒤)

	# 슬라이드별 삽화 — Backdrop 위, 텍스트 아래. 하나라도 로드되면 레이어를 깐다(없으면 Backdrop 만).
	for p in ILLUS_PATHS:
		_illus_tex.append(load(str(p)) if ResourceLoader.exists(str(p)) else null)
	if _illus_tex.any(func(t): return t != null):
		_illus = TextureRect.new()
		_illus.set_anchors_preset(Control.PRESET_FULL_RECT)
		_illus.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_illus.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_illus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_illus.texture = _illus_tex[0]
		add_child(_illus)
		# 글씨 가독용 어두운 스크림(삽화 위, 텍스트 아래).
		var scrim := ColorRect.new()
		scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
		scrim.color = Color(0.03, 0.03, 0.05, 0.5)
		scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_label = UITheme.make_label(SLIDES[0], UITheme.FS_H1, UITheme.FG)
	_label.custom_minimum_size = Vector2(UITheme.COLUMN_W, 0)
	center.add_child(_label)

	var bottom := CenterContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -110.0
	bottom.offset_bottom = -UITheme.SAFE
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	_hint = UITheme.make_label("탭하여 계속", UITheme.FS_SMALL, UITheme.MUTED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	bottom.add_child(_hint)

	var skip := UITheme.make_button("건너뛰기", false)
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.custom_minimum_size = Vector2(150, UITheme.BTN_H_SM)
	skip.offset_left = -160.0
	skip.offset_top = UITheme.SAFE
	skip.offset_right = -UITheme.PAD
	skip.pressed.connect(_finish)
	add_child(skip)

	_fade_in()

func _gui_input(event: InputEvent) -> void:
	var clicked: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if clicked:
		_advance()

func _advance() -> void:
	if _title_mode:
		_finish()
		return
	_idx += 1
	if _idx < SLIDES.size():
		_set_illus(_idx)
		_fade_to(SLIDES[_idx], UITheme.FS_H1, UITheme.FG)
	else:
		_title_mode = true
		if _hint != null:
			_hint.text = "탭하여 시작"
		_set_illus(-1)  # 제목 카드 — 삽화 없이(어두운 배경 위 제목만)
		_fade_to(TITLE_TEXT, UITheme.FS_DISPLAY, UITheme.SAND)

## 삽화를 idx 슬라이드로 크로스페이드(idx 밖 = 삽화 끔). _illus 없으면 no-op(fallback).
func _set_illus(idx: int) -> void:
	if _illus == null:
		return
	var tex: Texture2D = _illus_tex[idx] if idx >= 0 and idx < _illus_tex.size() else null
	var t := create_tween()
	t.tween_property(_illus, "modulate:a", 0.0, FADE * 0.5)
	t.tween_callback(_apply_illus.bind(tex))
	t.tween_property(_illus, "modulate:a", 1.0, FADE)

func _apply_illus(tex: Texture2D) -> void:
	if _illus != null:
		_illus.texture = tex

func _fade_in() -> void:
	_label.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_label, "modulate:a", 1.0, FADE)

## 텍스트를 페이드아웃 → 교체 → 페이드인.
func _fade_to(text: String, size: int, color: Color) -> void:
	var t := create_tween()
	t.tween_property(_label, "modulate:a", 0.0, FADE * 0.5)
	t.tween_callback(_apply_text.bind(text, size, color))
	t.tween_property(_label, "modulate:a", 1.0, FADE)

func _apply_text(text: String, size: int, color: Color) -> void:
	_label.text = text
	_label.add_theme_font_size_override("font_size", size)
	_label.add_theme_color_override("font_color", color)

func _finish() -> void:
	GameState.mark_opening_seen()
	GameState.go_to_loadout()
