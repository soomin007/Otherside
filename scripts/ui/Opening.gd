extends Control

## 오프닝 서사 슬라이드쇼 — 첫 플레이 자동 재생(이후 스킵, GameState.opening_seen).
## 담담·서늘, 맥거핀 유지(재앙 정체는 안 밝힌다). 탭/클릭으로 넘기고 마지막 제목 카드 뒤 지도로. 건너뛰기 가능.
## 기획서 §0·§2 세계관을 각색.

## FS_H1(28)·520px 컬럼 = 한 줄 ~17자. 수동 \n 필수(autowrap 은 음절 중간을 끊는다).
const SLIDES: Array = [
	"모래가 가라앉으면,\n재앙을 멈추러 원정대가 떠난다.",
	"거의 다 도중에 죽는다.\n한 번에 닿은 이는 아직 없었다.",
	"모래폭풍이 글을 지우는 땅.\n말은 남지 않는다. 물건만 남는다.",
	"너는 그들을 거듭 보내는 자.\n매번 다른 이가 떠나고,\n너는 그 사실을 안다.",
	"죽기 전 단 한 번.\n다음 원정대에게 무엇을 남길지,\n그것만이 네 몫이다.",
]
const TITLE_TEXT: String = "See you on the other side"
## 게임 로고(§18) — 있으면 제목 카드에 텍스트 대신 로고가 배어난다. 없으면 텍스트 fallback.
## 오프닝은 행렬판(81 — 지평선 위 작은 행렬이 슬라이드 서사를 받는다), 타이틀은 글자판(80 — 키아트와 수평선 중복 회피).
const LOGO_PATH: String = "res://assets/arts/81_로고_제목_행렬.png"
const FADE: float = 0.6
const TITLE_FADE: float = 1.4      ## 제목 카드 전용 페이드 — 본문보다 느리게 배어나며 무게를 준다
const TITLE_GUARD_MS: int = 900    ## 제목 카드 등장 직후 탭 무시 — 연타에 제목이 잠깐 스치고 지나가는 것 방지

## 슬라이드별 배경 삽화(SLIDES 와 1:1). 없으면 삽화 없이 Backdrop 만(fallback).
const ILLUS_PATHS: Array = [
	"res://assets/arts/24_오프닝_떠난다.png",
	"res://assets/arts/25_오프닝_죽는다.png",
	"res://assets/arts/26_오프닝_지운다.png",
	"res://assets/arts/27_오프닝_보내는자.png",
	"res://assets/arts/28_오프닝_남긴다.png",
]
## 가로(데스크톱)용 — `_가로` 접미사. 있으면 가로 화면에서 우선, 없으면 세로본.
const ILLUS_PATHS_LAND: Array = [
	"res://assets/arts/24_오프닝_떠난다_가로.png",
	"res://assets/arts/25_오프닝_죽는다_가로.png",
	"res://assets/arts/26_오프닝_지운다_가로.png",
	"res://assets/arts/27_오프닝_보내는자_가로.png",
	"res://assets/arts/28_오프닝_남긴다_가로.png",
]

var _idx: int = 0
var _label: Label
var _hint: Label
var _title_mode: bool = false
var _logo: TextureRect             ## 로고 레이어(에셋 있을 때만, 제목 카드에서 텍스트 대신)
var _title_guard_until: int = 0    ## 이 시각(msec)까지 제목 카드 탭 무시
var _label_tw: Tween               ## 진행 중 글씨 페이드(연타 시 킬 — 이전 트윈이 글씨를 되살리는 것 방지)
## 삽화 전환은 글씨와 같은 리듬(페이드아웃 → 교체 → 페이드인, 2026-07-17 사용자 요청).
## 삽화 뒤에 검은 밑판을 깔아 전환 중 맨 뒤 Backdrop(사막 밤 폴백)이 비치지 않게 한다
## (2026-07-06 사용자 지적 "밤배경 이미지 같은 게 나온다" 재발 방지).
var _illus: TextureRect            ## 삽화 레이어(한 장 — 꺼졌다 새 장으로 켜진다)
var _illus_black: ColorRect        ## 삽화 뒤 검은 밑판(제목 카드에서만 함께 걷힘)
var _illus_tw: Tween               ## 진행 중 페이드(연타 시 킬)
var _illus_tex: Array = []         ## 세로본 Texture2D(없으면 null)
var _illus_tex_land: Array = []    ## 가로본 Texture2D(없으면 null)
var _illus_cur: int = 0            ## 지금 보이는 삽화 슬라이드(리사이즈 시 방향 재판정용, -1=삽화 없음)

func _ready() -> void:
	add_child(Backdrop.new())  # 사막 밤 공통 배경(맨 뒤)

	# 슬라이드별 삽화 — Backdrop 위, 텍스트 아래. 세로+가로본 로드. 하나라도 있으면 레이어를 깐다.
	for p in ILLUS_PATHS:
		_illus_tex.append(load(str(p)) if ResourceLoader.exists(str(p)) else null)
	for p in ILLUS_PATHS_LAND:
		_illus_tex_land.append(load(str(p)) if ResourceLoader.exists(str(p)) else null)
	if _illus_tex.any(func(t): return t != null) or _illus_tex_land.any(func(t): return t != null):
		_illus_black = ColorRect.new()
		_illus_black.set_anchors_preset(Control.PRESET_FULL_RECT)
		_illus_black.color = UITheme.BG
		_illus_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_illus_black)
		_illus = _make_illus_layer()
		_illus.texture = _tex_for(0)  # 첫 장도 글씨처럼 _fade_in 에서 함께 배어난다
		get_viewport().size_changed.connect(_on_illus_resize)  # 창 방향 바뀌면 재판정
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

	# 로고 레이어 — 화면 중앙, 좌우 12%·상하 24% 여백 안에 contain. 제목 카드에서만 켜진다.
	if ResourceLoader.exists(LOGO_PATH):
		_logo = TextureRect.new()
		_logo.texture = load(LOGO_PATH)
		_logo.anchor_left = 0.12
		_logo.anchor_right = 0.88
		_logo.anchor_top = 0.24
		_logo.anchor_bottom = 0.76
		_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_logo.modulate.a = 0.0
		add_child(_logo)

	var bottom := CenterContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -110.0
	bottom.offset_bottom = -UITheme.SAFE
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	_hint = UITheme.make_label("탭하여 계속", UITheme.FS_SMALL, UITheme.MUTED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	bottom.add_child(_hint)

	var skip := UITheme.make_engraved_button("건너뛰기", 15, false)
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.offset_left = -200.0
	skip.offset_top = UITheme.SAFE
	skip.offset_right = -UITheme.PAD
	skip.offset_bottom = UITheme.SAFE + 54.0
	skip.pressed.connect(_finish)
	add_child(skip)

	_fade_in()

func _gui_input(event: InputEvent) -> void:
	var clicked: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if clicked:
		if _title_mode and Time.get_ticks_msec() < _title_guard_until:
			return  # 제목 카드가 배어나는 중 — 연타로 스쳐 지나가지 않게 잠깐 받친다
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
		_title_guard_until = Time.get_ticks_msec() + TITLE_GUARD_MS
		if _hint != null:
			_hint.text = "탭하여 시작"
		_set_illus(-1)  # 제목 카드 — 삽화 없이(어두운 배경 위 제목만)
		if _logo != null:
			_reveal_logo()
		else:
			_reveal_title_text()

## 삽화 레이어 한 장(풀스크린 cover, 투명 시작).
func _make_illus_layer() -> TextureRect:
	var tr := TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.modulate.a = 0.0
	add_child(tr)
	return tr

## 삽화를 idx 슬라이드로 전환 — 글씨와 같은 리듬(페이드아웃 → 교체 → 페이드인).
## 전환 중 빈 자리는 검은 밑판이 받쳐 뒤 Backdrop 이 비치지 않는다.
## idx 밖 = 삽화·밑판 함께 걷음(제목 카드 — 어두운 밤 배경 위 제목만, 이건 의도된 노출).
## 레이어 없으면 no-op(fallback).
func _set_illus(idx: int) -> void:
	if _illus == null:
		return
	_illus_cur = idx
	if _illus_tw != null and _illus_tw.is_valid():
		_illus_tw.kill()
	var nt: Texture2D = _tex_for(idx)
	_illus_tw = create_tween()
	if nt == null:
		_illus_tw.set_parallel(true)
		_illus_tw.tween_property(_illus, "modulate:a", 0.0, FADE * 0.5)
		_illus_tw.tween_property(_illus_black, "modulate:a", 0.0, FADE * 0.5)
		return
	_illus_black.modulate.a = 1.0
	_illus_tw.tween_property(_illus, "modulate:a", 0.0, FADE * 0.5)
	_illus_tw.tween_callback(func() -> void: _illus.texture = nt)
	_illus_tw.tween_property(_illus, "modulate:a", 1.0, FADE)

## idx 슬라이드의 삽화 — 가로 화면이고 가로본이 있으면 가로본, 아니면 세로본(둘 다 없으면 null).
func _tex_for(idx: int) -> Texture2D:
	if idx < 0 or idx >= _illus_tex.size():
		return null
	var land: bool = get_viewport_rect().size.x > get_viewport_rect().size.y
	if land and idx < _illus_tex_land.size() and _illus_tex_land[idx] != null:
		return _illus_tex_land[idx]
	return _illus_tex[idx]

## 창 방향이 바뀌면 지금 슬라이드 삽화를 그 방향본으로 즉시 교체(페이드 없이).
func _on_illus_resize() -> void:
	if _illus != null:
		_illus.texture = _tex_for(_illus_cur)

func _fade_in() -> void:
	_label.modulate.a = 0.0
	var t := _restart_label_tw()
	t.tween_property(_label, "modulate:a", 1.0, FADE)
	if _illus != null:
		_illus_tw = create_tween()
		_illus_tw.tween_property(_illus, "modulate:a", 1.0, FADE)

## 제목 카드(로고) — 글씨를 걷고 로고가 느리게 배어나며, 살짝 크게 시작해 자리 잡는다.
func _reveal_logo() -> void:
	var t := _restart_label_tw()
	t.tween_property(_label, "modulate:a", 0.0, FADE * 0.5)
	t.tween_property(_logo, "modulate:a", 1.0, TITLE_FADE)
	_logo.pivot_offset = _logo.size * 0.5
	_logo.scale = Vector2(1.04, 1.04)
	var s := create_tween()
	s.tween_interval(FADE * 0.5)
	s.tween_property(_logo, "scale", Vector2.ONE, TITLE_FADE * 1.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

## 제목 카드(텍스트 fallback) — 본문 슬라이드보다 느린 페이드로 무게를 준다.
func _reveal_title_text() -> void:
	var t := _restart_label_tw()
	t.tween_property(_label, "modulate:a", 0.0, FADE * 0.5)
	t.tween_callback(_apply_text.bind(TITLE_TEXT, UITheme.FS_DISPLAY, UITheme.SAND))
	t.tween_property(_label, "modulate:a", 1.0, TITLE_FADE)

## 텍스트를 페이드아웃 → 교체 → 페이드인.
func _fade_to(text: String, size: int, color: Color) -> void:
	var t := _restart_label_tw()
	t.tween_property(_label, "modulate:a", 0.0, FADE * 0.5)
	t.tween_callback(_apply_text.bind(text, size, color))
	t.tween_property(_label, "modulate:a", 1.0, FADE)

## 글씨 트윈 재시작 — 진행 중이던 페이드를 죽이고 새로 만든다.
## (연타로 슬라이드 트윈이 돌던 중 제목 카드에 들어가면, 이전 트윈이 뒤늦게 글씨를 되살려
## 로고 위에 겹치던 버그 방지. _illus_tw 와 같은 킬 패턴.)
func _restart_label_tw() -> Tween:
	if _label_tw != null and _label_tw.is_valid():
		_label_tw.kill()
	_label_tw = create_tween()
	return _label_tw

func _apply_text(text: String, size: int, color: Color) -> void:
	_label.text = text
	_label.add_theme_font_size_override("font_size", size)
	_label.add_theme_color_override("font_color", color)

func _finish() -> void:
	GameState.mark_opening_seen()
	if GameState.opening_replay:
		# 설정 "오프닝 다시보기" — 원정 준비가 아니라 온 곳(타이틀)으로 돌아간다.
		GameState.opening_replay = false
		GameState.go_to_title()
	else:
		GameState.go_to_loadout()
