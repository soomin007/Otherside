extends Control

## 설정 — 디에게틱 풀스크린 "원정 장부" (2026-07-05 리디자인, 사용자 확정).
## 어두운 책상 위에 펼친 장부 두 페이지. 왼쪽 = 세계 기록 + 위험 구역(세계 지우기),
## 오른쪽 = 소리(배경음악·효과음 따로 + 전체 음소거) + 덮기. 지우기 확인은 페이지를 넘기듯 전환.
## 양피지·잉크는 지도와 같은 팔레트(UITheme.PAPER/INK) — 셰이더 없이 _draw 로 그린다(웹 안전).
## 호출부 API 는 이전과 동일: SettingsPanel.new() 를 씬에 add_child, data_reset 시그널.

signal data_reset  ## 데이터 초기화가 끝났을 때 (부모가 통계 라벨 등을 갱신)

const INK := UITheme.INK
const INK_FADE := UITheme.INK_FADE
const PAPER := UITheme.PAPER
const PAPER_EDGE := UITheme.PAPER_EDGE
const RED_INK := UITheme.MARKER_INK

const PAGE_PAD: float = 30.0   ## 페이지 안쪽 여백
const PAGE_SFX: Array = [
	"res://assets/sfx/sfx_page_1.wav", "res://assets/sfx/sfx_page_2.wav", "res://assets/sfx/sfx_page_3.wav",
]

var _page_l_box: VBoxContainer   ## 왼쪽 페이지 내용
var _page_r_box: VBoxContainer   ## 오른쪽 페이지 내용
var _music_value: Label
var _sfx_value: Label
var _in_confirm: bool = false
var _pre_mute: float = 1.0   ## 음소거 직전 전체 볼륨(음소거 해제 시 복원)

var _rect_l: Rect2   ## 왼쪽 페이지(그리기와 내용 배치가 공유)
var _rect_r: Rect2

func _ready() -> void:
	add_to_group("fullscreen_overlay")  # 기록 책갈피(Bookmark)가 이 그룹을 보고 아이콘을 숨긴다
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size  # 레이아웃 패스 전 size 0 방지(known_issues)
	mouse_filter = Control.MOUSE_FILTER_STOP  # 풀스크린 — 뒤 화면 입력 차단
	_page_l_box = _make_page_box()
	_page_r_box = _make_page_box()
	_layout()
	resized.connect(_layout)
	_show_main()
	AudioManager.play_sfx(AudioManager.CARD_OPEN)  # 장부가 펼쳐지는 양피지 소리(sfx_settings 톤은 보류 — audio_list §2)
	# 장부가 스르륵 펼쳐짐
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.22).set_ease(Tween.EASE_OUT)

func _make_page_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	return box

## 화면 크기에서 두 페이지 자리를 잡는다. 가로면 좌우 펼침, 세로(예외)면 위아래.
func _layout() -> void:
	var vp: Vector2 = size
	var horizontal: bool = vp.x >= vp.y * 1.05
	var bw: float
	var bh: float
	if horizontal:
		bw = minf(vp.x * 0.9, 1080.0)
		bh = minf(vp.y * 0.86, 640.0)
	else:
		bw = minf(vp.x * 0.94, 560.0)
		bh = minf(vp.y * 0.9, 1040.0)
	var origin := Vector2((vp.x - bw) * 0.5, (vp.y - bh) * 0.5)
	var gutter: float = 16.0
	if horizontal:
		var pw: float = bw * 0.5 - gutter * 0.5
		_rect_l = Rect2(origin, Vector2(pw, bh))
		_rect_r = Rect2(origin + Vector2(bw - pw, 0.0), Vector2(pw, bh))
	else:
		var ph: float = bh * 0.5 - gutter * 0.5
		_rect_l = Rect2(origin, Vector2(bw, ph))
		_rect_r = Rect2(origin + Vector2(0.0, bh - ph), Vector2(bw, ph))
	_place(_page_l_box, _rect_l)
	_place(_page_r_box, _rect_r)
	queue_redraw()

func _place(box: VBoxContainer, r: Rect2) -> void:
	box.position = r.position + Vector2(PAGE_PAD, PAGE_PAD)
	box.size = r.size - Vector2(PAGE_PAD * 2.0, PAGE_PAD * 2.0)

# --- 장부 그리기 (셰이더 없이) ---

func _draw() -> void:
	# 책상 — 따뜻한 어둠, 아래쪽에 아주 옅은 온기
	draw_rect(Rect2(Vector2.ZERO, size), UITheme.BG_TOP)
	draw_rect(Rect2(0.0, size.y * 0.6, size.x, size.y * 0.4),
		Color(UITheme.BG_BOT.r, UITheme.BG_BOT.g, UITheme.BG_BOT.b, 0.22))

	var book: Rect2 = _rect_l.merge(_rect_r).grow(16.0)
	# 그림자
	var shadow_sb := StyleBoxFlat.new()
	shadow_sb.bg_color = Color(0, 0, 0, 0.38)
	shadow_sb.set_corner_radius_all(18)
	shadow_sb.draw(get_canvas_item(), Rect2(book.position + Vector2(0.0, 10.0), book.size).grow(4.0))
	# 가죽 표지
	var cover_sb := StyleBoxFlat.new()
	cover_sb.bg_color = UITheme.PANEL
	cover_sb.border_color = UITheme.PANEL_BORDER
	cover_sb.set_border_width_all(2)
	cover_sb.set_corner_radius_all(14)
	cover_sb.draw(get_canvas_item(), book)

	for r in [_rect_l, _rect_r]:
		_draw_page(r)

	# 가운데 접힘 그림자 — 두 페이지의 마주 보는 안쪽 변
	var horizontal: bool = _rect_r.position.x > _rect_l.position.x
	for i in range(3):
		var a: float = 0.05 + 0.035 * float(i)
		var w: float = 12.0 - 4.0 * float(i)
		if horizontal:
			draw_rect(Rect2(_rect_l.end.x - w, _rect_l.position.y, w, _rect_l.size.y), Color(0, 0, 0, a))
			draw_rect(Rect2(_rect_r.position.x, _rect_r.position.y, w, _rect_r.size.y), Color(0, 0, 0, a))
		else:
			draw_rect(Rect2(_rect_l.position.x, _rect_l.end.y - w, _rect_l.size.x, w), Color(0, 0, 0, a))
			draw_rect(Rect2(_rect_r.position.x, _rect_r.position.y, _rect_r.size.x, w), Color(0, 0, 0, a))

## 양피지 한 장 — 바탕 + 그을린 가장자리 두 겹 + 옅은 장부 괘선.
func _draw_page(r: Rect2) -> void:
	var page_sb := StyleBoxFlat.new()
	page_sb.bg_color = PAPER
	page_sb.border_color = Color(PAPER_EDGE.r, PAPER_EDGE.g, PAPER_EDGE.b, 0.9)
	page_sb.set_border_width_all(1)
	page_sb.set_corner_radius_all(4)
	page_sb.draw(get_canvas_item(), r)
	draw_rect(r.grow(-3.0), Color(PAPER_EDGE.r, PAPER_EDGE.g, PAPER_EDGE.b, 0.28), false, 1.5)
	draw_rect(r.grow(-7.0), Color(PAPER_EDGE.r, PAPER_EDGE.g, PAPER_EDGE.b, 0.12), false, 1.0)
	var y: float = r.position.y + 92.0
	while y < r.end.y - 34.0:
		draw_line(Vector2(r.position.x + 20.0, y), Vector2(r.end.x - 20.0, y),
			Color(INK_FADE.r, INK_FADE.g, INK_FADE.b, 0.13), 1.0)
		y += 42.0

func _clear(box: VBoxContainer) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()

# --- 메인 (왼쪽 = 기록·위험 구역 / 오른쪽 = 소리·덮기) ---

func _show_main() -> void:
	_in_confirm = false
	_clear(_page_l_box)
	_clear(_page_r_box)

	# ── 왼쪽 페이지: 세계 기록
	_page_l_box.add_child(_brush_heading("원정 장부", 44, INK))
	_page_l_box.add_child(UITheme.make_hairline(Color(INK.r, INK.g, INK.b, 0.35), 2.0))
	_page_l_box.add_child(_ledger_row("보낸 원정", "%d회" % GameState.expedition_count))
	_page_l_box.add_child(_ledger_row("남긴 흔적", "%d" % GameState.traces.size()))
	_page_l_box.add_child(_ledger_row("죽은 자리", "%d" % GameState.deaths.size()))
	_page_l_box.add_child(_expand_spacer())
	_page_l_box.add_child(_ink_label("저장된 이 세계를 지웁니다.\n원정·흔적·죽은 자리가 모두 사라지고, 처음부터 시작합니다.",
		UITheme.FS_SMALL, INK_FADE))
	var wipe := UITheme.make_pill("저장 데이터 지우기", RED_INK, Color(0, 0, 0, 0),
		Color(RED_INK.r, RED_INK.g, RED_INK.b, 0.55))
	wipe.pressed.connect(_show_confirm)
	_page_l_box.add_child(wipe)

	# ── 오른쪽 페이지: 소리
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var htext := _brush_heading("소리", 38, INK)
	htext.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(htext)
	var master := AppSettings.load_master_volume()
	var mute := UITheme.make_pill("소리 켜기" if master <= 0.0 else "전체 음소거", INK, Color(0, 0, 0, 0),
		Color(INK.r, INK.g, INK.b, 0.4))
	mute.pressed.connect(_toggle_mute)
	head.add_child(mute)
	_page_r_box.add_child(head)
	_page_r_box.add_child(UITheme.make_hairline(Color(INK.r, INK.g, INK.b, 0.35), 2.0))

	_music_value = _add_volume_row(_page_r_box, "배경음악", AppSettings.load_music_volume(), _on_music_changed, Callable())
	_sfx_value = _add_volume_row(_page_r_box, "효과음", AppSettings.load_sfx_volume(), _on_sfx_changed, _on_sfx_drag_ended)

	_page_r_box.add_child(_expand_spacer())
	var close_btn := UITheme.make_pill("장부를 덮는다", PAPER, INK, Color(INK.r, INK.g, INK.b, 0.8))
	close_btn.pressed.connect(_close)
	_page_r_box.add_child(close_btn)

# --- 확인 (지우기 — 페이지를 넘기듯 두 쪽 다 전환) ---

func _show_confirm() -> void:
	_in_confirm = true
	AudioManager.play_sfx_random(PAGE_SFX)
	_clear(_page_l_box)
	_clear(_page_r_box)

	_page_l_box.add_child(_ink_label("되돌릴 수 없습니다", UITheme.FS_SMALL, RED_INK))
	_page_l_box.add_child(_brush_heading("이 세계를 지울까요", 40, INK))
	_page_l_box.add_child(UITheme.make_hairline(Color(RED_INK.r, RED_INK.g, RED_INK.b, 0.5), 2.0))
	_page_l_box.add_child(_ink_label("모래폭풍이 모든 원정과 흔적을 쓸어 갑니다. 처음부터 다시 시작합니다.",
		UITheme.FS_SMALL, INK))
	_page_l_box.add_child(_ink_label("원정 %d회 · 흔적 %d개가 사라집니다." % [GameState.expedition_count, GameState.traces.size()],
		UITheme.FS_SMALL, INK_FADE))

	_page_r_box.add_child(_expand_spacer())
	var keep := UITheme.make_pill("아니, 둔다", INK, Color(0, 0, 0, 0), Color(INK.r, INK.g, INK.b, 0.4))
	keep.pressed.connect(_back_to_main)
	_page_r_box.add_child(keep)
	var wipe := UITheme.make_pill("지운다", PAPER, RED_INK, RED_INK)
	wipe.pressed.connect(_do_reset)
	_page_r_box.add_child(wipe)
	_page_r_box.add_child(_expand_spacer())

func _back_to_main() -> void:
	AudioManager.play_sfx_random(PAGE_SFX)
	_show_main()

func _do_reset() -> void:
	GameState.reset_save()
	data_reset.emit()
	_close()

# --- 잉크 위젯 헬퍼 ---

## 붓글씨 표제(나눔손글씨 붓 — 지도 지명과 같은 결).
func _brush_heading(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UITheme.BRUSH_FONT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

func _ink_label(text: String, font_size: int, color: Color) -> Label:
	return UITheme.make_label(text, font_size, color, false)

## 장부 한 줄 — 항목은 왼쪽 잉크, 값은 오른쪽 붓글씨(손으로 적은 숫자).
func _ledger_row(name_text: String, value_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := _ink_label(name_text, UITheme.FS_LABEL, INK)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var val := _brush_heading(value_text, 30, INK)
	row.add_child(val)
	return row

func _expand_spacer() -> Control:
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sp

## 라벨 + % 값 + 잉크 슬라이더 한 묶음을 페이지에 추가하고 % 라벨을 돌려준다.
## on_drag_end 가 유효하면 손을 뗄 때 호출(효과음 미리듣기용).
func _add_volume_row(box: VBoxContainer, text: String, vol: float, on_changed: Callable, on_drag_end: Callable) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := _ink_label(text, UITheme.FS_LABEL, INK)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var value := _ink_label(_pct(vol), UITheme.FS_SMALL, INK_FADE)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.autowrap_mode = TextServer.AUTOWRAP_OFF  # "50%" 가 좁은 폭에서 세로로 쪼개지지 않게
	row.add_child(value)
	box.add_child(row)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = vol
	slider.custom_minimum_size = Vector2(0, UITheme.SLIDER_H)
	UITheme.style_slider(slider, INK)
	slider.value_changed.connect(on_changed)
	if on_drag_end.is_valid():
		slider.drag_ended.connect(on_drag_end)
	box.add_child(slider)
	return value

# --- 소리 핸들러 ---

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

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back_or_close()
		get_viewport().set_input_as_handled()

## 확인 화면이면 메인으로, 아니면 닫는다.
func _back_or_close() -> void:
	if _in_confirm:
		_back_to_main()
	else:
		_close()

func _close() -> void:
	AudioManager.play_sfx(AudioManager.CARD_CLOSE)  # 장부를 덮는 소리(보이스는 AudioManager 소유라 해제 후에도 끝까지 재생)
	queue_free()
