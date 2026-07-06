extends CanvasLayer

## 원정 일지 — 이 게임의 **유일한 장부**(autoload CanvasLayer). 일대기·조작·설정이 전부 이 책의 챕터다.
## (예전의 별도 SettingsPanel 은 이 책의 "설정" 챕터로 흡수 통합 — 2026-07-05 사용자 확정.)
## 왼쪽 가장자리에 빨간 책갈피 리본이 삐져나와 있다 — 호버하면 더 나오고, 누르면 일지가 펼쳐진다.
## 챕터는 책 오른쪽의 빨간 책갈피로. 전환 = **낱장이 넘어가는 연출**(오른쪽 잎이 스파인으로 접혔다
## 왼쪽으로 펼쳐짐) + 종이 SFX. 시장이 기록지를 건넨 뒤(GameState.record_seen)에만 리본이 보인다.

signal data_reset  ## 설정 챕터에서 세계를 지웠을 때(타이틀 통계 갱신용)

const ENABLED: bool = true
const RED := UITheme.MARKER_INK      ## 책갈피 리본·붉은 잉크
const INK := UITheme.INK
const INK_FADE := UITheme.INK_FADE
const PAPER := UITheme.PAPER
const PAPER_EDGE := UITheme.PAPER_EDGE
const PAGE_PAD: float = 30.0
const PAGE_SFX: Array = [
	"res://assets/sfx/sfx_page_1.wav",
	"res://assets/sfx/sfx_page_2.wav",
	"res://assets/sfx/sfx_page_3.wav",
]

## 조작 안내 장(정적).
const TUTORIAL_PAGES: Array = [
	"지도에서 갈 곳을 눌러 원정대를 움직입니다. 가봐야 무엇이 있는지 압니다. 걸음마다 물과 식량이 닳습니다.",
	"도착하면 그곳의 단면이 펼쳐집니다. 표시된 곳을 눌러 살핍니다. 조사 횟수는 정해져 있고, 조사에는 자원이 들지 않습니다.",
	"물은 걸음마다, 식량은 두 걸음마다 줄어듭니다. 로프는 갈라진 틈을, 은신막은 폭풍을 견디게 합니다.",
	"죽기 전 단 한 번, 물건 하나를 남길 수 있습니다. 그만큼 잃지만 다음 원정대가 줍습니다. 무엇을 남길지가 이 여정의 마음입니다.",
]

const CHAPTERS: Array = ["일대기", "조작", "설정"]

## 양피지 낱장 그리기 — LedgerBook(펼친 두 쪽)과 FlipLeaf(넘어가는 잎)가 공유.
class PageArt:
	static func paint(c: Control, r: Rect2) -> void:
		var page_sb := StyleBoxFlat.new()
		page_sb.bg_color = UITheme.PAPER
		page_sb.border_color = Color(UITheme.PAPER_EDGE.r, UITheme.PAPER_EDGE.g, UITheme.PAPER_EDGE.b, 0.9)
		page_sb.set_border_width_all(1)
		page_sb.set_corner_radius_all(4)
		page_sb.draw(c.get_canvas_item(), r)
		c.draw_rect(r.grow(-3.0), Color(UITheme.PAPER_EDGE.r, UITheme.PAPER_EDGE.g, UITheme.PAPER_EDGE.b, 0.28), false, 1.5)
		c.draw_rect(r.grow(-7.0), Color(UITheme.PAPER_EDGE.r, UITheme.PAPER_EDGE.g, UITheme.PAPER_EDGE.b, 0.12), false, 1.0)
		var y: float = r.position.y + 92.0
		while y < r.end.y - 34.0:
			c.draw_line(Vector2(r.position.x + 20.0, y), Vector2(r.end.x - 20.0, y),
				Color(UITheme.INK_FADE.r, UITheme.INK_FADE.g, UITheme.INK_FADE.b, 0.13), 1.0)
			y += 42.0

## 책갈피 리본 — 오른쪽 끝에 V 홈이 파인 빨간 리본. length 로 삐져나온 정도를 조절(호버 애니).
## V 홈은 오목 다각형이라 위/아래 두 볼록 조각으로 나눠 그린다.
class Ribbon extends Control:
	var length: float = 38.0:
		set(v):
			length = v
			queue_redraw()
	var text: String = ""
	var ribbon_h: float = 30.0
	var col: Color = UITheme.MARKER_INK
	func _draw() -> void:
		var h: float = ribbon_h
		var notch: float = minf(10.0, length * 0.3)
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, 0), Vector2(length, 0), Vector2(length - notch, h * 0.5), Vector2(0, h * 0.5)]), col)
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, h * 0.5), Vector2(length - notch, h * 0.5), Vector2(length, h), Vector2(0, h)]), col)
		draw_line(Vector2(0, h), Vector2(length - 2.0, h), Color(0.0, 0.0, 0.0, 0.35), 1.5, true)  # 아랫면 그림자(두께감)
		if text != "":
			var f: Font = get_theme_default_font()
			if f != null:
				draw_string(f, Vector2(9.0, h * 0.5 + 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, length - 16.0, 13, Color(0.96, 0.92, 0.86, 0.95))

## 일지 책 — 가죽 표지 + 양피지 두 페이지 + 괘선 + 가운데 접힘(옛 장부의 렌더) + 페이지 두께 스택(§5).
class LedgerBook extends Control:
	var rect_l: Rect2   ## 왼쪽 페이지(로컬) — 내용 배치가 공유
	var rect_r: Rect2
	var thickness_cf: float = 0.0:   ## 챕터 위치(0..챕터수-1, 연속) — 좌우 두께 스택이 이걸 따라 이동(§5)
		set(v):
			thickness_cf = v
			queue_redraw()
	func relayout() -> void:
		var gutter: float = 16.0
		var pw: float = size.x * 0.5 - gutter * 0.5
		rect_l = Rect2(Vector2.ZERO, Vector2(pw, size.y))
		rect_r = Rect2(Vector2(size.x - pw, 0.0), Vector2(pw, size.y))
		queue_redraw()
	func _draw() -> void:
		var book: Rect2 = Rect2(Vector2.ZERO, size).grow(16.0)
		var shadow_sb := StyleBoxFlat.new()
		shadow_sb.bg_color = Color(0, 0, 0, 0.38)
		shadow_sb.set_corner_radius_all(18)
		shadow_sb.draw(get_canvas_item(), Rect2(book.position + Vector2(0.0, 10.0), book.size).grow(4.0))
		var cover_sb := StyleBoxFlat.new()
		cover_sb.bg_color = UITheme.PANEL
		cover_sb.border_color = UITheme.PANEL_BORDER
		cover_sb.set_border_width_all(2)
		cover_sb.set_corner_radius_all(14)
		cover_sb.draw(get_canvas_item(), book)
		# 페이지 두께 스택(§5) — 표지 안쪽, 좌·우 바깥 모서리 세로 띠. 챕터 위치(thickness_cf)에 비례해
		# 한쪽이 두꺼워지고 반대쪽이 얇아진다(넘기는 동안 연속 변화). 안쪽 밝고 바깥 어둡게.
		var n_max: float = 2.0  # 챕터 3개(0..2) — 내부 클래스라 자체 상수
		var cfv: float = clampf(thickness_cf, 0.0, n_max)
		var nl: int = mini(7, roundi(2.0 + cfv * 3.0))
		var nr: int = mini(7, roundi(2.0 + (n_max - cfv) * 3.0))
		var ew: float = 2.1
		for i in range(nl):
			var shade: float = lerpf(0.92, 0.42, float(i) / 6.0)
			var x: float = rect_l.position.x - 2.0 - float(i) * ew
			draw_line(Vector2(x, 4.0), Vector2(x, size.y - 4.0),
				Color(UITheme.PAPER.r * shade, UITheme.PAPER.g * shade, UITheme.PAPER.b * shade), ew - 0.5, true)
		for i in range(nr):
			var shade2: float = lerpf(0.92, 0.42, float(i) / 6.0)
			var x2: float = rect_r.end.x + 2.0 + float(i) * ew
			draw_line(Vector2(x2, 4.0), Vector2(x2, size.y - 4.0),
				Color(UITheme.PAPER.r * shade2, UITheme.PAPER.g * shade2, UITheme.PAPER.b * shade2), ew - 0.5, true)
		PageArt.paint(self, rect_l)
		PageArt.paint(self, rect_r)
		# 가운데 접힘 그림자 — 두 페이지의 마주 보는 안쪽 변.
		for i in range(3):
			var a: float = 0.05 + 0.035 * float(i)
			var w: float = 12.0 - 4.0 * float(i)
			draw_rect(Rect2(rect_l.end.x - w, rect_l.position.y, w, rect_l.size.y), Color(0, 0, 0, a))
			draw_rect(Rect2(rect_r.position.x, rect_r.position.y, w, rect_r.size.y), Color(0, 0, 0, a))

## 책장 넘김 리플(외부 핸드오프 handoff_book_flip 이식) — 낱장을 **스파인(책 중앙) 기준 폭-투영**으로
## 돌린다: 폭 = PW·|cos a|, 수직에서 0이 됐다 반대편에서 다시 넓어짐(가로로 넘어감 — 솟구침·코너축 금지).
## K장이 스태거로 촤라락(리플), 명암(곧추섬 어둠·자유변 그라디언트·이동 하이라이트·드리운 그림자)으로 입체감.
## 밑장 비침 금지: 낱장은 전부 불투명(k=0 앞면 = 현재 페이지 캡처, 나머지 = 양피지 더미).
## 걷히며 드러나는 쪽 베이스는 구멍(실제 목표 콘텐츠 노드가 보임), 덮이는 쪽 베이스 = 현재 페이지 캡처.
class FlipDeck extends Control:
	const DUR: float = 0.45      ## 속도(확정)
	const CURL: float = 1.2      ## 휨(확정)
	const EDGE_SEGS: int = 6     ## 자유변 bow 곡선 분할

	## 리플 구성 — 챕터 점프 기본(확정값). 조작 장 넘기기는 낱장 1장(sheets_n 1·flip_win 1)로 쓴다.
	var sheets_n: int = 8            ## 장수(K)
	var spread: float = 0.45         ## 퍼짐(스태거 폭)
	var flip_win: float = 0.5        ## 넘김창(한 장이 넘어가는 시간 비율)
	var riffle_sfx: bool = true      ## 수직 통과(t≈.5) 촤라락 SFX — 낱장 1장일 땐 끔

	var dir: int = 1                 ## +1 = 다음 챕터(오른쪽 낱장이 왼쪽으로) / -1 = 앞 챕터
	var rect_l: Rect2                ## 왼쪽 페이지(로컬) — LedgerBook 과 동일
	var rect_r: Rect2
	var tex_cover: Texture2D         ## 덮이는 쪽 베이스(현재 페이지 캡처 — dir=+1 이면 왼쪽)
	var tex_front: Texture2D         ## k=0 낱장 앞면(현재 페이지 캡처 — dir=+1 이면 오른쪽)
	var cf_from: float = 0.0         ## 두께 스택용 시작 챕터 위치
	var cf_to: float = 0.0           ## 끝 위치(장 넘기기는 from=to — 두께 변화 없음)
	var on_progress: Callable        ## 매 프레임 (cf) — LedgerBook 두께 갱신
	var on_done: Callable
	var _p: float = 0.0
	var _riffled: bool = false       ## 중간(수직 통과) 촤라락 SFX 1회

	func _process(delta: float) -> void:
		_p += delta / DUR
		if riffle_sfx and not _riffled and _p >= 0.5:
			_riffled = true
			AudioManager.play_sfx_random([
				"res://assets/sfx/sfx_page_1.wav",
				"res://assets/sfx/sfx_page_2.wav",
				"res://assets/sfx/sfx_page_3.wav",
			])
		if on_progress.is_valid():
			on_progress.call(lerpf(cf_from, cf_to, _ease(clampf(_p, 0.0, 1.0))))
		queue_redraw()
		if _p >= 1.0:
			set_process(false)
			if on_done.is_valid():
				on_done.call()
			queue_free()

	## inOutQuad(스펙 §1).
	func _ease(t: float) -> float:
		return 2.0 * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 2.0) * 0.5

	func _draw() -> void:
		var p: float = clampf(_p, 0.0, 1.0)
		# 덮이는 쪽 베이스 = 현재 페이지 캡처(넘어온 장들이 덮는다). 걷히는 쪽은 구멍(실 목표 노드).
		if tex_cover != null:
			draw_texture_rect(tex_cover, rect_l if dir == 1 else rect_r, false)
		# 리플 — 스태거(§1) 후 덜 넘어간 장이 위(위에서 아래로 e 내림차순, 동률은 k 오름차순).
		var sheets: Array = []
		for k in range(sheets_n):
			var st: float = 0.0 if sheets_n <= 1 else (float(k) / float(sheets_n - 1)) * spread
			var lp: float = clampf((p - st) / flip_win, 0.0, 1.0)
			var e: float = lp * lp * (3.0 - 2.0 * lp)  # smoothstep
			sheets.append({"e": e, "k": k})
		sheets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a["e"] != b["e"]:
				return a["e"] > b["e"]
			return a["k"] < b["k"])
		for s in sheets:
			var e: float = s["e"]
			var k: int = s["k"]
			if e > 0.0001 or k == 0:
				_draw_sheet(e, k)

	## 낱장 한 장(§2·§3) — 스파인 폭-투영 + bow 사다리꼴 + 명암.
	func _draw_sheet(e: float, k: int) -> void:
		var pw: float = rect_l.size.x
		var ph: float = rect_l.size.y
		var oy: float = rect_l.position.y
		var sp: float = rect_l.end.x + (rect_r.position.x - rect_l.end.x) * 0.5  # 스파인 x(거터 중앙)
		var a: float = e * PI
		var c: float = cos(a)
		var w: float = pw * absf(c)
		if w < 0.5:
			return
		var front: bool = c >= 0.0
		var side_sign: float = (1.0 if dir == 1 else -1.0) * (1.0 if front else -1.0)
		var rx: float = sp if side_sign > 0.0 else sp - w
		var fe_x: float = rx + w if side_sign > 0.0 else rx
		var bow: float = 12.0 * CURL * sin(a) * (pw / 260.0)
		# bow 사다리꼴 — 스파인변 직선, 위/아래변은 자유변 쪽이 bow 만큼 들린 2차 베지어(분할 근사).
		var pts: PackedVector2Array = PackedVector2Array()
		var uvs: PackedVector2Array = PackedVector2Array()
		for i in range(EDGE_SEGS + 1):  # 위변: 스파인 → 자유변
			var t: float = float(i) / float(EDGE_SEGS)
			var x: float = lerpf(sp, fe_x, t)
			var y: float = _qbez(oy, oy - bow, oy - bow, t)
			pts.append(Vector2(x, y))
			uvs.append(Vector2(clampf((x - rx) / w, 0.0, 1.0), clampf((y - oy) / ph, 0.0, 1.0)))
		for i in range(EDGE_SEGS + 1):  # 아래변: 자유변 → 스파인
			var t2: float = float(i) / float(EDGE_SEGS)
			var x2: float = lerpf(fe_x, sp, t2)
			var y2: float = _qbez(oy + ph - bow, oy + ph - bow, oy + ph, t2)
			pts.append(Vector2(x2, y2))
			uvs.append(Vector2(clampf((x2 - rx) / w, 0.0, 1.0), clampf((y2 - oy) / ph, 0.0, 1.0)))
		# 면 — k=0 앞면은 현재 페이지 캡처(미러 없음), 그 외는 불투명 양피지 더미(+괘선).
		if front and k == 0 and tex_front != null:
			var cols: PackedColorArray = PackedColorArray()
			for i in range(pts.size()):
				cols.append(Color.WHITE)
			draw_polygon(pts, cols, uvs, tex_front)
		else:
			draw_colored_polygon(pts, UITheme.PAPER)
			var lc := Color(UITheme.INK_FADE.r, UITheme.INK_FADE.g, UITheme.INK_FADE.b, 0.13)
			var yl: float = oy + 92.0
			while yl < oy + ph - 34.0:
				draw_line(Vector2(minf(rx + 3.0, fe_x), yl), Vector2(maxf(rx + 3.0, fe_x - 3.0) if side_sign > 0.0 else rx + w - 3.0, yl), lc, 1.0)
				yl += 42.0
		# 명암(§3): ① 곧추섬 어둠(전체) ② 자유변 그라디언트(정점색) ③ 이동 하이라이트.
		var stand: float = 1.0 - absf(c)
		if stand > 0.01:
			draw_colored_polygon(pts, Color(0.102, 0.063, 0.024, stand * 0.5))
		var grad_cols: PackedColorArray = PackedColorArray()
		var a_sp: float = 0.16
		var a_fe: float = 0.10 + 0.2 * stand
		for pt in pts:
			var tt: float = clampf(absf(pt.x - sp) / maxf(w, 0.001), 0.0, 1.0)
			grad_cols.append(Color(0.078, 0.047, 0.016, lerpf(a_sp, a_fe, tt)))
		draw_polygon(pts, grad_cols)
		var hi: float = maxf(0.0, 1.0 - absf(e - 0.35) / 0.4) * 0.18
		if hi > 0.01:
			draw_colored_polygon(pts, Color(1.0, 0.98, 0.92, hi))
		# ④ 드리운 그림자 — 서 있는 낱장이 "떠나온 쪽" 페이지에 지운다(스파인에서 안쪽 150px 상당).
		var sh_a: float = 0.34 * sin(a)
		if sh_a > 0.01:
			var sh_w: float = pw * 0.3 * float(dir)
			var sh_pts := PackedVector2Array([
				Vector2(sp, oy), Vector2(sp + sh_w, oy), Vector2(sp + sh_w, oy + ph), Vector2(sp, oy + ph)])
			var sh_cols := PackedColorArray([
				Color(0, 0, 0, sh_a), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, sh_a)])
			draw_polygon(sh_pts, sh_cols)

	## 2차 베지어 1축 보간.
	func _qbez(p0: float, p1: float, p2: float, t: float) -> float:
		var u: float = 1.0 - t
		return u * u * p0 + 2.0 * u * t * p1 + t * t * p2

var _ribbon: Ribbon
var _panel: Control
var _book: LedgerBook
var _box_l: VBoxContainer      ## 왼쪽 페이지 내용
var _box_r: VBoxContainer      ## 오른쪽 페이지 내용
var _scroll_l: ScrollContainer ## 왼쪽 페이지 스크롤(일대기가 길다)
var _tabs: Array = []          ## 챕터 책갈피(Ribbon) — 책 오른쪽에 얹힘
var _chapter: int = 0
var _tut_idx: int = 0
var _flipping: bool = false
var _rib_tw: Tween
var _opened_ms: int = 0        ## 일지를 연 시각 — 여는 클릭이 스크림 닫기로 새는 것 방지 가드
var _in_confirm: bool = false  ## 설정 챕터의 "세계 지우기" 확인 화면
var _music_value: Label
var _sfx_value: Label
var _pre_mute: float = 1.0     ## 음소거 직전 전체 볼륨(해제 시 복원)

func _ready() -> void:
	if not ENABLED:
		return
	layer = 100  # 게임 UI 위, DEV 오버레이(128) 아래
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false
	_refresh_icon()

func _process(_delta: float) -> void:
	if ENABLED:
		_refresh_icon()

## ESC — 확인 화면이면 설정으로, 열려 있으면 덮는다.
func _input(event: InputEvent) -> void:
	if _panel != null and _panel.visible and event.is_action_pressed("ui_cancel"):
		if _in_confirm:
			_show_settings()
		else:
			_close()
		get_viewport().set_input_as_handled()

## 기록지를 받은 뒤에만 리본을 보인다. 일지가 열려 있거나 풀스크린 오버레이(엔딩 등)가 떠 있으면 숨김.
func _refresh_icon() -> void:
	if _ribbon != null:
		_ribbon.visible = GameState.record_seen and not _panel.visible \
			and get_tree().get_first_node_in_group("fullscreen_overlay") == null

# --- UI 구성 ---

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 왼쪽 가장자리 리본 — 일지에 끼워둔 빨간 책갈피가 화면 밖으로 삐져나온 모양.
	_ribbon = Ribbon.new()
	_ribbon.position = Vector2(0.0, 38.0)
	_ribbon.size = Vector2(96.0, 30.0)  # 히트 영역(그리기는 length 만큼)
	_ribbon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_ribbon.mouse_entered.connect(_ribbon_hover.bind(true))
	_ribbon.mouse_exited.connect(_ribbon_hover.bind(false))
	_ribbon.gui_input.connect(_on_ribbon_input)
	root.add_child(_ribbon)

	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_panel)

	# 책상 어둠 — 탭하면 덮는다.
	var scrim := ColorRect.new()
	scrim.color = Color(UITheme.BG_TOP.r, UITheme.BG_TOP.g, UITheme.BG_TOP.b, 0.94)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(_on_scrim_input)
	_panel.add_child(scrim)

	# 일지 본체 — 두 페이지 책.
	_book = LedgerBook.new()
	_panel.add_child(_book)
	_box_l = VBoxContainer.new()
	_box_l.add_theme_constant_override("separation", 12)
	_scroll_l = ScrollContainer.new()
	_scroll_l.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll_l.add_child(_box_l)
	_box_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box_l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_book.add_child(_scroll_l)
	_box_r = VBoxContainer.new()
	_box_r.add_theme_constant_override("separation", 12)
	_book.add_child(_box_r)

	# 챕터 책갈피 — 책 오른쪽 가장자리에서 삐져나온 작은 리본들(현재 챕터가 가장 김).
	for i in range(CHAPTERS.size()):
		var tab := Ribbon.new()
		tab.text = str(CHAPTERS[i])
		tab.ribbon_h = 28.0
		tab.col = RED if i == 0 else Color(RED.r, RED.g, RED.b, 0.62)
		tab.size = Vector2(96.0, 28.0)
		tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tab.gui_input.connect(_on_tab_input.bind(i))
		_book.add_child(tab)
		_tabs.append(tab)

## 리본 호버 — 좀 더 길게 삐져나온다(잡아당길 수 있다는 신호).
func _ribbon_hover(on: bool) -> void:
	if _rib_tw != null and _rib_tw.is_valid():
		_rib_tw.kill()
	_rib_tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_rib_tw.tween_property(_ribbon, "length", 72.0 if on else 38.0, 0.3)

func _on_ribbon_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		# 같은 클릭(또는 합성 터치)이 방금 열린 스크림까지 흘러가 즉시 닫던 버그 — 소비 + 다음 프레임 열기.
		_ribbon.accept_event()
		call_deferred("open_journal", 0)

func _on_tab_input(event: InputEvent, idx: int) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		var tab: Ribbon = _tabs[idx]
		tab.accept_event()
		_flip_to(idx)

# --- 열기/닫기/레이아웃 ---

## 일지를 특정 챕터로 연다(0=일대기·1=조작·2=설정). 타이틀 메뉴 등 외부 진입점.
func open_journal(chapter: int = 0) -> void:
	_layout_book()
	_panel.visible = true
	UITheme.fade_in(_panel)
	_opened_ms = Time.get_ticks_msec()
	AudioManager.play_sfx("res://assets/sfx/sfx_page_1.wav")
	_chapter = clampi(chapter, 0, CHAPTERS.size() - 1)
	_book.thickness_cf = float(_chapter)  # 페이지 두께 스택(§5) 초기 위치
	_apply_tab_state()
	_render_chapter()

## (구 진입점 호환 — 기존 호출부가 _open 을 부른다.)
func _open() -> void:
	open_journal(0)

func _close() -> void:
	AudioManager.play_sfx(AudioManager.CARD_CLOSE)  # 일지를 덮는 소리
	_panel.visible = false

func _on_scrim_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	# 연 직후 250ms 는 무시 — 여는 클릭의 잔여 이벤트(합성 터치 등)가 바로 닫는 것 방지.
	if tap and Time.get_ticks_msec() - _opened_ms > 250:
		_close()

## 일지 크기 — 화면 90%·상한 1080×640(옛 장부와 동일 비율).
func _layout_book() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var w: float = minf(vp.x * 0.9, 1080.0)
	var h: float = minf(vp.y * 0.86, 640.0)
	_book.size = Vector2(w, h)
	_book.position = (vp - Vector2(w, h)) * 0.5
	_book.relayout()
	# 페이지 내용 배치.
	_scroll_l.position = _book.rect_l.position + Vector2(PAGE_PAD, PAGE_PAD)
	_scroll_l.size = _book.rect_l.size - Vector2(PAGE_PAD * 2.0, PAGE_PAD * 2.0)
	_box_l.custom_minimum_size.x = _scroll_l.size.x - 12.0
	_box_r.position = _book.rect_r.position + Vector2(PAGE_PAD, PAGE_PAD)
	_box_r.size = _book.rect_r.size - Vector2(PAGE_PAD * 2.0, PAGE_PAD * 2.0)
	for i in range(_tabs.size()):
		var tab: Ribbon = _tabs[i]
		tab.position = Vector2(w - 4.0, 36.0 + float(i) * 44.0)

# --- 챕터 (낱장 넘김) ---

## 챕터 책갈피를 누름 — 책장 넘김 리플(외부 핸드오프 handoff_book_flip 이식, 확정값 450ms·8장).
## 현재 두 페이지를 화면에서 캡처해 낱장 텍스처로 쓰고, 콘텐츠는 목표 챕터로 즉시 교체 —
## 같은 프레임에 FlipDeck 가 위를 덮어(p=0 = 이전 모습) 팝이 없다. 점프는 최단 방향 1회(스펙).
func _flip_to(idx: int) -> void:
	if _flipping or idx == _chapter:
		return
	var dir: int = 1 if idx > _chapter else -1
	_run_flip(dir, 8, 0.45, 0.5, true, float(_chapter), float(idx), func() -> void:
		_chapter = idx
		_apply_tab_state()
		_render_chapter())

## 조작 챕터의 장 넘기기 — 낱장 1장이 전체 시간으로 넘어간다(리플·촤라락 SFX 없음, 두께 변화 없음).
func _flip_page(dir: int, swap: Callable) -> void:
	_run_flip(dir, 1, 0.0, 1.0, false, float(_chapter), float(_chapter), swap)

## 공용 넘김 실행 — 현재 두 페이지를 캡처하고, 내용을 교체(swap)한 뒤 FlipDeck 연출을 얹는다.
## 캡처는 이 프레임 렌더 직후의 화면(아직 이전 내용)에서 — 같은 프레임에 덮개가 올라가 팝이 없다.
func _run_flip(dir: int, sheets_n: int, spread: float, flip_win: float, riffle: bool,
		cf_from: float, cf_to: float, swap: Callable) -> void:
	_flipping = true
	AudioManager.play_sfx_random(PAGE_SFX)  # 장 집힐 때 1회
	await RenderingServer.frame_post_draw
	var tex_l: ImageTexture = _capture_page(_book.rect_l)
	var tex_r: ImageTexture = _capture_page(_book.rect_r)
	swap.call()
	var deck := FlipDeck.new()
	deck.dir = dir
	deck.sheets_n = sheets_n
	deck.spread = spread
	deck.flip_win = flip_win
	deck.riffle_sfx = riffle
	deck.rect_l = _book.rect_l
	deck.rect_r = _book.rect_r
	deck.tex_cover = tex_l if dir == 1 else tex_r   # 덮이는 쪽 = 이전 내용(넘어온 장들이 덮음)
	deck.tex_front = tex_r if dir == 1 else tex_l   # k=0 앞면 = 이전 내용(시작 팝 없음)
	deck.cf_from = cf_from
	deck.cf_to = cf_to
	deck.on_progress = func(cf: float) -> void: _book.thickness_cf = cf
	deck.on_done = func() -> void: _flipping = false
	deck.set_anchors_preset(Control.PRESET_FULL_RECT)
	deck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(deck)

## 책 로컬 rect 를 화면 물리 픽셀로 변환해 현재 화면에서 잘라낸다(낱장 텍스처).
func _capture_page(r_local: Rect2) -> ImageTexture:
	var img: Image = get_viewport().get_texture().get_image()
	var ft: Transform2D = get_viewport().get_final_transform()
	var gp: Vector2 = _book.global_position + r_local.position
	var p0: Vector2 = ft * gp
	var p1: Vector2 = ft * (gp + r_local.size)
	var rect := Rect2i(Vector2i(p0.round()), Vector2i((p1 - p0).round()))
	rect = rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if rect.size.x < 2 or rect.size.y < 2:
		return ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	return ImageTexture.create_from_image(img.get_region(rect))

## 현재 챕터 책갈피는 진하고 길게, 나머지는 옅고 짧게.
func _apply_tab_state() -> void:
	for i in range(_tabs.size()):
		var tab: Ribbon = _tabs[i]
		tab.col = RED if i == _chapter else Color(RED.r, RED.g, RED.b, 0.62)
		tab.length = 78.0 if i == _chapter else 58.0

func _render_chapter() -> void:
	match _chapter:
		0:
			_show_chronicle()
		1:
			_show_tutorial()
		2:
			_show_settings()

# --- 챕터: 일대기 ---

## 왼쪽: 원정 목록(스크롤), 오른쪽: 행적 요약 + 덮기.
func _show_chronicle() -> void:
	_clear(_box_l)
	_clear(_box_r)
	_box_l.add_child(_brush_heading("원정 일대기", 40, INK))
	var n: int = GameState.expedition_count
	if n <= 0:
		_box_l.add_child(_ink_label("아직 떠난 원정이 없다.", UITheme.FS_LABEL, INK_FADE))
	else:
		for exp in range(1, n + 1):
			_box_l.add_child(_chronicle_line(exp))
	_box_r.add_child(_brush_heading("행적", 40, INK))
	_box_r.add_child(UITheme.make_hairline(Color(INK.r, INK.g, INK.b, 0.35), 2.0))
	_box_r.add_child(_ledger_row("보낸 원정", "%d회" % GameState.expedition_count))
	_box_r.add_child(_ledger_row("남긴 흔적", "%d" % GameState.traces.size()))
	_box_r.add_child(_ledger_row("죽은 자리", "%d" % GameState.deaths.size()))
	_box_r.add_child(_ledger_row("끝에 닿음", "%d번" % GameState.arrivals.size()))
	_add_close(_box_r)

# --- 챕터: 조작 안내 ---

## 왼쪽: 현재 장 내용, 오른쪽: 장 넘기기 + 덮기.
func _show_tutorial() -> void:
	_clear(_box_l)
	_clear(_box_r)
	_box_l.add_child(_brush_heading("조작 안내", 40, INK))
	_box_l.add_child(_ink_label(str(TUTORIAL_PAGES[_tut_idx]), UITheme.FS_BODY, INK))
	_box_r.add_child(_brush_heading("%d / %d 장" % [_tut_idx + 1, TUTORIAL_PAGES.size()], 34, Color(RED.r, RED.g, RED.b, 0.9)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if _tut_idx > 0:
		row.add_child(_ink_btn("← 앞장", _tut_back))
	if _tut_idx < TUTORIAL_PAGES.size() - 1:
		row.add_child(_ink_btn("다음 장 →", _tut_next))
	_box_r.add_child(row)
	_add_close(_box_r)

func _tut_back() -> void:
	if _flipping or _tut_idx <= 0:
		return
	_flip_page(-1, func() -> void:
		_tut_idx = maxi(0, _tut_idx - 1)
		_show_tutorial())

func _tut_next() -> void:
	if _flipping or _tut_idx >= TUTORIAL_PAGES.size() - 1:
		return
	_flip_page(1, func() -> void:
		_tut_idx = mini(TUTORIAL_PAGES.size() - 1, _tut_idx + 1)
		_show_tutorial())

# --- 챕터: 설정 (소리·화면·이야기 / 여정·위험 구역) ---

## 왼쪽: 소리 + 화면·이야기(전체화면·오프닝 다시보기). 오른쪽: 여정(타이틀로·끝내기) + 위험 구역 + 덮기.
## 웹에선 게임 끝내기·전체화면 토글을 숨긴다(브라우저가 관장 — Fullscreen autoload 가 자동 전체화면).
func _show_settings() -> void:
	_in_confirm = false
	_clear(_box_l)
	_clear(_box_r)
	var web: bool = OS.has_feature("web")

	# ── 왼쪽: 소리
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var htext := _brush_heading("소리", 40, INK)
	htext.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(htext)
	var master: float = AppSettings.load_master_volume()
	var mute := UITheme.make_pill("소리 켜기" if master <= 0.0 else "전체 음소거", INK, Color(0, 0, 0, 0),
		Color(INK.r, INK.g, INK.b, 0.4))
	mute.pressed.connect(_toggle_mute)
	head.add_child(mute)
	_box_l.add_child(head)
	_box_l.add_child(UITheme.make_hairline(Color(INK.r, INK.g, INK.b, 0.35), 2.0))
	_music_value = _add_volume_row(_box_l, "배경음악", AppSettings.load_music_volume(), _on_music_changed, Callable())
	_sfx_value = _add_volume_row(_box_l, "효과음", AppSettings.load_sfx_volume(), _on_sfx_changed, _on_sfx_drag_ended)

	# ── 왼쪽: 화면과 이야기 (가운뎃점(·)은 붓 폰트에 글리프가 없어 웹에서 두부(□) — 순한글로)
	_box_l.add_child(_brush_heading("화면과 이야기", 34, INK))
	_box_l.add_child(UITheme.make_hairline(Color(INK.r, INK.g, INK.b, 0.35), 2.0))
	if not web:
		var fs_on: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		var fs := UITheme.make_pill("창 화면으로" if fs_on else "전체 화면으로", INK, Color(0, 0, 0, 0),
			Color(INK.r, INK.g, INK.b, 0.4))
		fs.pressed.connect(_toggle_fullscreen)
		_box_l.add_child(fs)
	var replay := UITheme.make_pill("오프닝 다시보기", INK, Color(0, 0, 0, 0), Color(INK.r, INK.g, INK.b, 0.4))
	replay.pressed.connect(_replay_opening)
	_box_l.add_child(replay)

	# ── 오른쪽: 여정 (타이틀 화면에선 의미 없어 숨김)
	var on_title: bool = get_tree().current_scene != null \
		and get_tree().current_scene.scene_file_path == "res://scenes/main.tscn"
	if not on_title:
		_box_r.add_child(_brush_heading("여정", 40, INK))
		_box_r.add_child(UITheme.make_hairline(Color(INK.r, INK.g, INK.b, 0.35), 2.0))
		var to_title := UITheme.make_pill("타이틀로 나간다", INK, Color(0, 0, 0, 0), Color(INK.r, INK.g, INK.b, 0.4))
		to_title.pressed.connect(_on_leave_to_title)
		_box_r.add_child(to_title)
	if not web:
		var quit := UITheme.make_pill("게임을 끝낸다", INK, Color(0, 0, 0, 0), Color(INK.r, INK.g, INK.b, 0.4))
		quit.pressed.connect(_on_quit_pressed)
		_box_r.add_child(quit)

	# ── 오른쪽: 위험 구역
	_box_r.add_child(_brush_heading("위험 구역", 34, RED))
	_box_r.add_child(UITheme.make_hairline(Color(RED.r, RED.g, RED.b, 0.5), 2.0))
	_box_r.add_child(_ink_label("저장된 이 세계를 지웁니다.\n원정·흔적·죽은 자리가 모두 사라지고, 처음부터 시작합니다.",
		UITheme.FS_SMALL, INK_FADE))
	var wipe := UITheme.make_pill("저장 데이터 지우기", RED, Color(0, 0, 0, 0), Color(RED.r, RED.g, RED.b, 0.55))
	wipe.pressed.connect(_confirm_wipe)
	_box_r.add_child(wipe)
	_add_close(_box_r)

## 확인 페이지(공용) — 왼쪽: 경고·제목·설명, 오른쪽: 머문다/실행. 지우기·타이틀로·끝내기가 공유.
func _show_confirm_page(warn: String, title: String, desc: String, yes_txt: String, yes_cb: Callable) -> void:
	_in_confirm = true
	AudioManager.play_sfx_random(PAGE_SFX)
	_clear(_box_l)
	_clear(_box_r)
	_box_l.add_child(_ink_label(warn, UITheme.FS_SMALL, RED))
	_box_l.add_child(_brush_heading(title, 40, INK))
	_box_l.add_child(UITheme.make_hairline(Color(RED.r, RED.g, RED.b, 0.5), 2.0))
	_box_l.add_child(_ink_label(desc, UITheme.FS_SMALL, INK))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box_r.add_child(sp)
	var keep := UITheme.make_pill("아니, 머문다", INK, Color(0, 0, 0, 0), Color(INK.r, INK.g, INK.b, 0.4))
	keep.pressed.connect(_show_settings)
	_box_r.add_child(keep)
	var yes := UITheme.make_pill(yes_txt, PAPER, RED, RED)
	yes.pressed.connect(yes_cb)
	_box_r.add_child(yes)
	var sp2 := Control.new()
	sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box_r.add_child(sp2)

## 세계 지우기 확인.
func _confirm_wipe() -> void:
	_show_confirm_page("되돌릴 수 없습니다", "이 세계를 지울까요",
		"모래폭풍이 모든 원정과 흔적을 쓸어 갑니다. 처음부터 다시 시작합니다.\n원정 %d회 · 흔적 %d개가 사라집니다." % [GameState.expedition_count, GameState.traces.size()],
		"지운다", _do_reset)

func _do_reset() -> void:
	GameState.reset_save()
	data_reset.emit()
	_close()
	# 게임 도중(지도·단면)에 세계를 지우면 그 씬은 더 유효하지 않다 — run 도 기록도 없고
	# 일지 리본(record_seen)마저 꺼져, 모든 조작이 null 가드 no-op 이 되는 소프트락(2026-07-06 사용자 제보).
	# DEV 오버레이의 "세이브 초기화 → 타이틀"처럼 타이틀로 내보낸다. 타이틀에서 지웠으면 그대로 둔다.
	var cs: Node = get_tree().current_scene
	if cs == null or cs.scene_file_path != "res://scenes/main.tscn":
		GameState.go_to_title()

# --- 여정 (타이틀로 · 게임 끝내기 · 화면 · 오프닝) ---

## 타이틀로 — 진행 중 원정이 있으면 한 번 묻는다(원정은 저장되지 않아 모래에 묻힌다).
func _on_leave_to_title() -> void:
	if GameState.current_run != null and GameState.current_run.alive:
		_show_confirm_page("지금 원정은 돌아오지 못합니다", "타이틀로 나갈까요",
			"길 위의 원정대는 모래에 묻히고, 세계의 기록만 남습니다.", "나간다", _go_title)
	else:
		_go_title()

func _go_title() -> void:
	_close()
	GameState.go_to_title()

## 게임 끝내기(데스크톱만) — 한 번 묻고 종료. 세계(세이브)는 남는다.
func _on_quit_pressed() -> void:
	var desc: String = "세계의 기록은 남습니다. 다음에 이어서 원정을 보낼 수 있습니다."
	if GameState.current_run != null and GameState.current_run.alive:
		desc = "길 위의 원정대는 모래에 묻히고, 세계의 기록만 남습니다."
	_show_confirm_page("게임을 끝냅니다", "여기서 덮을까요", desc, "끝낸다",
		func() -> void: get_tree().quit())

## 전체화면 토글(데스크톱만 — 웹은 Fullscreen autoload 가 자동).
func _toggle_fullscreen() -> void:
	var fs_on: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs_on else DisplayServer.WINDOW_MODE_FULLSCREEN)
	_show_settings()  # 버튼 문구 갱신

## 오프닝 다시보기 — 일지를 덮고 서사를 재생, 끝나면 타이틀로(Opening 이 opening_replay 를 본다).
func _replay_opening() -> void:
	_close()
	GameState.opening_replay = true
	GameState.go_to_opening()

# --- 소리 핸들러 (옛 장부 그대로) ---

## 라벨 + % 값 + 잉크 슬라이더 한 묶음을 페이지에 추가하고 % 라벨을 돌려준다.
func _add_volume_row(box: VBoxContainer, txt: String, vol: float, on_changed: Callable, on_drag_end: Callable) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := _ink_label(txt, UITheme.FS_LABEL, INK)
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

## 전체 음소거 토글 — Master 볼륨을 0 ↔ 직전 값으로.
func _toggle_mute() -> void:
	var v: float = AppSettings.load_master_volume()
	if v > 0.0:
		_pre_mute = v
		AppSettings.set_master_volume(0.0)
	else:
		AppSettings.set_master_volume(_pre_mute if _pre_mute > 0.0 else 1.0)
	_show_settings()  # 슬라이더·값·버튼 텍스트 갱신

func _pct(v: float) -> String:
	return "%d%%" % int(round(v * 100.0))

# --- 잉크 위젯 헬퍼 ---

func _add_close(box: VBoxContainer) -> void:
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(sp)
	box.add_child(_ink_btn("일지를 덮는다", _close))

## 붓글씨 제목(나눔손글씨 붓 — 지도 지명과 같은 결).
func _brush_heading(txt: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", UITheme.BRUSH_FONT)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	return l

## 장부 한 줄 — 항목은 왼쪽 잉크, 값은 오른쪽 붓글씨(손으로 적은 숫자).
func _ledger_row(name_txt: String, value_txt: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var nm := _ink_label(name_txt, UITheme.FS_LABEL, INK)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(nm)
	row.add_child(_brush_heading(value_txt, 30, RED))
	return row

## 양피지 위 잉크 라벨.
func _ink_label(txt: String, fs: int, col: Color, center: bool = false) -> Label:
	return UITheme.make_label(txt, fs, col, center)

## 잉크 각인 버튼 — 상자 없이 글자만, hover 시 붉은 잉크.
func _ink_btn(txt: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.flat = false
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", UITheme.FS_LABEL)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", RED)
	b.add_theme_color_override("font_pressed_color", RED)
	var emp := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, emp)
	b.pressed.connect(cb)
	return b

## 한 원정의 요약 줄 — 결말은 셋 중 하나: 끝에 닿음(arrivals) / 스러짐(deaths) / 아직 길 위(현재 원정).
## 도달·재회는 arrivals(GameState.mark_arrival), 죽음은 deaths + BODY 흔적으로 재구성한다.
func _chronicle_line(exp: int) -> Label:
	var nm: String = GameState.expedition_name(exp)
	# ① 끝에 닿은 원정 — 재회(붉은 잉크) 또는 도달.
	var arrival: Dictionary = _arrival_of(exp)
	if not arrival.is_empty():
		if str(arrival.get("ending", "")) == "reunion":
			return _ink_label(
				"%d번째 원정 · %s\n    건너편에서 모두와 다시 만났다." % [exp, nm],
				UITheme.FS_LABEL, RED)
		return _ink_label(
			"%d번째 원정 · %s\n    끝에 닿았다. 다음 원정대가 이곳으로 온다." % [exp, nm],
			UITheme.FS_LABEL, INK)
	# ② 스러진 원정 — 장소·거리·사인.
	var death: Dictionary = _death_of(exp)
	if not death.is_empty():
		var node_id: String = str(death.get("node_id", ""))
		var place: String = str(MapGraph.node(node_id).get("name", ""))
		if place == "":
			place = "이름 모를 곳"
		var leg: int = int(death.get("leg", 0))
		return _ink_label(
			"%d번째 원정 · %s\n    %s에서 %d걸음째 스러졌다.%s" % [exp, nm, place, leg, _cause_text(node_id)],
			UITheme.FS_LABEL, INK)
	# ③ 아직 길 위 — 지금 진행 중인 원정(살아 있음). 그 외(옛 세이브 등)는 지워진 기록.
	if exp == GameState.expedition_count and GameState.current_run != null and GameState.current_run.alive:
		return _ink_label(
			"%d번째 원정 · %s\n    아직 길 위에 있다." % [exp, nm],
			UITheme.FS_LABEL, INK_FADE)
	return _ink_label(
		"%d번째 원정 · %s\n    기록이 모래에 지워졌다." % [exp, nm],
		UITheme.FS_LABEL, INK_FADE)

func _arrival_of(exp: int) -> Dictionary:
	for a in GameState.arrivals:
		if a is Dictionary and int(a.get("expedition", -1)) == exp:
			return a
	return {}

func _death_of(exp: int) -> Dictionary:
	for d in GameState.deaths:
		if d is Dictionary and int(d.get("expedition", -1)) == exp:
			return d
	return {}

## 사인 보강 — 그 노드의 BODY 흔적 태그에서 근사(정확한 원정별 매칭은 불가, 태그가 사인 단서).
func _cause_text(node_id: String) -> String:
	for raw in GameState.traces:
		if not (raw is Dictionary):
			continue
		if int(raw.get("object_kind", -1)) != TraceData.ObjectKind.BODY:
			continue
		if str(raw.get("node_id", "")) != node_id:
			continue
		var tg: Array = raw.get("tags", [])
		if tg.has("갈증"):
			return " 갈증이었다."
		if tg.has("없다"):
			return " 식량이 없었다."
		return ""
	return ""

func _clear(box: VBoxContainer) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
