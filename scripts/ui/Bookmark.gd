extends CanvasLayer

## 원정 일지 — 이 게임의 **유일한 장부**(autoload CanvasLayer). 일대기·조작·설정이 전부 이 책의 챕터다.
## (예전의 별도 SettingsPanel 은 이 책의 "설정" 챕터로 흡수 통합 — 2026-07-05 사용자 확정.)
## 오른쪽 위 가장자리에 빨간 책갈피 리본이 삐져나와 있다 — 호버하면 더 나오고, 누르면 일지가 펼쳐진다.
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

## 조작 안내 장(정적). 페이지 폭 ~450px·FS_BODY = 한 줄 ~19자 — 수동 \n(autowrap 은 음절 중간을 끊는다).
## 말투 = 담담한 평서(기록지에 적힌 글) — 합쇼체 금지, 게임 공통 목소리.
## 중요한 단어는 BBCode 색 강조(2026-07-12 사용자 — 내용이 다 똑같이 생겨 집중이 안 됨).
## 색: 물 #35667f · 식량 #8c5f16 · 로프 #7a4a1e · 장막 #4d5a26 · 핵심 행동 #8a2f1b(붉은 잉크).
const TUTORIAL_PAGES: Array = [
	"지도에서 갈 곳을 누르면\n원정대가 나아간다.\n가 봐야 무엇이 있는지 알고,\n걸음마다 [color=#35667f]물[/color]과 [color=#8c5f16]식량[/color]이 닳는다.",
	"닿은 곳에선 단면이 펼쳐진다.\n표시된 곳을 눌러 살핀다.\n[color=#8a2f1b]살필 횟수[/color]는 정해져 있고,\n살핀다고 물이 줄지는 않는다.",
	"[color=#35667f]물[/color]은 걸음마다,\n[color=#8c5f16]식량[/color]은 두 걸음마다 줄어든다.\n[color=#7a4a1e]로프[/color]는 갈라진 틈을 건너게 하고,\n[color=#4d5a26]장막[/color]은 폭풍을 버티게 한다.",
	"죽기 전 단 한 번,\n[color=#8a2f1b]물건 하나를 남길 수 있다.[/color]\n그만큼 잃지만\n다음 원정대가 그것을 줍는다.\n무엇을 남길지가 이 여정의 마음이다.",
]

## 챕터 순서 — 바꾸면 아래 CH_* 와 LedgerBook 두께 스택 상한도 같이.
const CHAPTERS: Array = ["일대기", "마을", "조작", "설정"]
const CH_CHRONICLE: int = 0
const CH_VILLAGE: int = 1   ## 공훈 — 이룬 일이 마을에 새 직능을 부른다(2026-07-11)
const CH_CONTROLS: int = 2
const CH_SETTINGS: int = 3

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
		# 괘선은 폐지(2026-07-12 사용자) — 실제 글줄과 안 맞아 어긋나 보였다. 민무늬 양피지가 낫다.

## 책갈피 리본 — 오른쪽 끝에 V 홈이 파인 빨간 리본. length 로 삐져나온 정도를 조절(호버 애니).
## 실제 리본 그림(킷 69, 사용자 생성)을 홈 캡 + 늘어나는 몸통 두 조각으로 그린다 — 길이가 변해도
## V 홈이 안 뭉갠다. 그림이 없으면 기존 절차 폴리곤 fallback(V 홈은 위/아래 두 볼록 조각).
class Ribbon extends Control:
	static var _tex_l: Texture2D          ## V 홈 왼쪽판(화면 모서리 리본 flip=true 용)
	static var _tex_r: Texture2D          ## V 홈 오른쪽판(챕터 탭용)
	static var _tex_loaded: bool = false
	var length: float = 52.0:
		set(v):
			length = v
			queue_redraw()
	var text: String = ""
	var ribbon_h: float = 30.0
	var col: Color = UITheme.MARKER_INK
	var flip: bool = false   ## true 면 오른쪽 가장자리에 걸려 왼쪽으로 삐져나온다(V 홈이 왼쪽 끝). 기본=왼쪽.

	static func _load_tex() -> void:
		if _tex_loaded:
			return
		_tex_loaded = true
		var pl: String = "res://assets/arts/transparent/69_소품_책갈피리본_좌.png"
		var pr: String = "res://assets/arts/transparent/69_소품_책갈피리본_우.png"
		if ResourceLoader.exists(pl):
			_tex_l = load(pl)
		if ResourceLoader.exists(pr):
			_tex_r = load(pr)

	func _draw() -> void:
		_load_tex()
		var h: float = ribbon_h
		var tex: Texture2D = _tex_l if flip else _tex_r
		if tex != null:
			_draw_tex_ribbon(tex, h)
		else:
			_draw_poly_ribbon(h)
		if text != "":
			var f: Font = get_theme_default_font()
			if f != null:
				var tfs: int = clampi(int(h * 0.48), 12, 19)  # 리본 높이에 비례(모바일 확대 탭도 글씨가 따라 큼)
				if flip:
					draw_string(f, Vector2(size.x - length + 7.0, h * 0.5 + tfs * 0.38), L10N.t(text), HORIZONTAL_ALIGNMENT_RIGHT, length - 16.0, tfs, Color(0.96, 0.92, 0.86, 0.95))
				else:
					draw_string(f, Vector2(9.0, h * 0.5 + tfs * 0.38), L10N.t(text), HORIZONTAL_ALIGNMENT_LEFT, length - 16.0, tfs, Color(0.96, 0.92, 0.86, 0.95))

	## 그림 리본 — 원본 비율 그대로, 보이는 길이만큼만 잘라 그린다(늘이지 않는다 — 2026-07-12 사용자:
	## 캡+몸통 늘임 방식이 좌우로 쪼그라져 보였다). 잘린 끝은 화면/책 모서리와 겹쳐 안 보인다.
	func _draw_tex_ribbon(tex: Texture2D, h: float) -> void:
		var tw: float = float(tex.get_width())
		var th: float = float(tex.get_height())
		if tw <= 0.0 or th <= 0.0 or length <= 2.0:
			return
		var mod := Color(1.0, 1.0, 1.0, col.a)
		var sx: float = h / th                     # 자연 배율(세로 맞춤)
		var src_w: float = minf(tw, length / sx)   # 보이는 만큼만 원본을 자른다
		var dst_w: float = src_w * sx
		if flip:
			# V 홈(원본 왼끝)이 안쪽 — 화면 오른끝에서 왼쪽으로 삐져나온 모양.
			draw_texture_rect_region(tex, Rect2(size.x - dst_w, 0.0, dst_w, h), Rect2(0.0, 0.0, src_w, th), mod)
			draw_line(Vector2(size.x, h), Vector2(size.x - dst_w * 0.7, h), Color(0.0, 0.0, 0.0, 0.3), 1.5, true)
		else:
			# V 홈(원본 오른끝)이 리본 끝 — 왼쪽 잘린 면은 책 모서리에 겹친다.
			draw_texture_rect_region(tex, Rect2(0.0, 0.0, dst_w, h), Rect2(tw - src_w, 0.0, src_w, th), mod)
			draw_line(Vector2(0.0, h), Vector2(dst_w * 0.7, h), Color(0.0, 0.0, 0.0, 0.3), 1.5, true)

	## 절차 폴리곤 fallback — 예전 모습 그대로.
	func _draw_poly_ribbon(h: float) -> void:
		var notch: float = minf(10.0, length * 0.3)
		if flip:
			var w: float = size.x   # 기준 = 컨트롤 오른변. x 를 좌우 대칭(w - x)으로 그린다.
			draw_colored_polygon(PackedVector2Array([
				Vector2(w, 0), Vector2(w - length, 0), Vector2(w - length + notch, h * 0.5), Vector2(w, h * 0.5)]), col)
			draw_colored_polygon(PackedVector2Array([
				Vector2(w, h * 0.5), Vector2(w - length + notch, h * 0.5), Vector2(w - length, h), Vector2(w, h)]), col)
			draw_line(Vector2(w, h), Vector2(w - length + 2.0, h), Color(0.0, 0.0, 0.0, 0.35), 1.5, true)
			return
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, 0), Vector2(length, 0), Vector2(length - notch, h * 0.5), Vector2(0, h * 0.5)]), col)
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, h * 0.5), Vector2(length - notch, h * 0.5), Vector2(length, h), Vector2(0, h)]), col)
		draw_line(Vector2(0, h), Vector2(length - 2.0, h), Color(0.0, 0.0, 0.0, 0.35), 1.5, true)  # 아랫면 그림자(두께감)

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
		var n_max: float = 3.0  # 챕터 4개(0..3) — 내부 클래스라 자체 상수(CHAPTERS 바뀌면 같이)
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
var _box_r: VBoxContainer      ## 오른쪽 페이지 내용(넘김/덮기 제외 — 위쪽만)
var _footer_r: VBoxContainer   ## 오른쪽 페이지 바닥 고정 자리 — 넘김·덮기(펼침마다 같은 위치)
var _scroll_l: ScrollContainer ## 왼쪽 페이지 컨테이너 — 전 챕터가 펼침 넘김이라 스크롤은 안전망일 뿐
var _tabs: Array = []          ## 챕터 책갈피(Ribbon) — 책 오른쪽에 얹힘
## 범례 표식 그림 — 조작 챕터 "표식 읽기"가 지도·단면 실제 표식의 축소판을 작은 칸에 그린다.
## 지점 고리·흔적 점은 실제 킷 텍스처(§16)를 그대로 축소해 게임 화면과 똑같이 보이게 한다(없으면 절차 fallback).
class LegendMark extends Control:
	var kind: String = ""
	static var _kit: Dictionary = {}
	static func _tex(path: String) -> Texture2D:
		if _kit.has(path):
			return _kit[path]
		var t: Texture2D = null
		if ResourceLoader.exists(path):
			t = load(path)
		_kit[path] = t
		return t
	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var mk: Color = UITheme.MARKER_INK
		var sand: Color = UITheme.SAND
		match kind:
			"main":  # 주요 지점 — 이중 고리(킷 67, SectionArt 와 동일)
				var tm: Texture2D = _tex("res://assets/arts/transparent/67_기호_주요지점.png")
				if tm != null:
					SectionArt.draw_tex_center(self, tm, c, 46.0)
					draw_circle(c, 4.0, mk)
				else:
					draw_arc(c, 20.0, 0.0, TAU, 32, Color(sand.r, sand.g, sand.b, 0.22), 1.5)
					draw_circle(c, 16.0, Color(sand.r, sand.g, sand.b, 0.18))
					draw_arc(c, 13.0, 0.0, TAU, 32, mk, 3.0)
					draw_circle(c, 4.0, mk)
			"collect":  # 채집 지점 — 단일 고리(킷 68)
				var tc: Texture2D = _tex("res://assets/arts/transparent/68_기호_보조지점.png")
				if tc != null:
					SectionArt.draw_tex_center(self, tc, c, 34.0)
					draw_circle(c, 3.0, mk)
				else:
					draw_circle(c, 13.0, Color(sand.r, sand.g, sand.b, 0.18))
					draw_arc(c, 11.0, 0.0, TAU, 32, mk, 2.5)
					draw_circle(c, 3.0, mk)
			"done":  # 다 살핀 곳 — 같은 고리를 흐리게
				var td: Texture2D = _tex("res://assets/arts/transparent/68_기호_보조지점.png")
				if td != null:
					SectionArt.draw_tex_center(self, td, c, 26.0, Color(1.0, 1.0, 1.0, 0.4))
				else:
					draw_arc(c, 11.0, 0.0, TAU, 32, Color(UITheme.INK_FADE.r, UITheme.INK_FADE.g, UITheme.INK_FADE.b, 0.7), 1.5)
			"ramp":  # 조사 예산 — 찬 점 둘 + 빈 점
				draw_circle(c + Vector2(-14.0, 0.0), 4.0, mk)
				draw_circle(c, 4.0, mk)
				draw_arc(c + Vector2(14.0, 0.0), 4.0, 0.0, TAU, 16, Color(mk.r, mk.g, mk.b, 0.5), 1.5)
			"route":  # 밟은 길 — 트레일 선 + 발자국
				draw_line(c + Vector2(-18.0, 5.0), c + Vector2(18.0, -5.0), UITheme.ROUTE, 2.5)
				for i in range(-2, 3):
					draw_circle(c + Vector2(i * 8.0, 5.0 - i * 2.8), 1.7, UITheme.ROUTE)
			"marker":  # 원정대 마커
				draw_arc(c, 11.0, 0.0, TAU, 20, Color(mk.r, mk.g, mk.b, 0.4), 1.5)
				draw_circle(c, 6.0, mk)
			"trace":  # 남긴 흔적 — 잉크 링(킷 63) + 안료 점(지도 실물과 동일)
				var pig: Color = Color(0.25, 0.44, 0.55)  # 물 안료(대표색)
				var tt: Texture2D = _tex("res://assets/arts/transparent/63_기호_흔적점.png")
				if tt != null:
					SectionArt.draw_tex_center(self, tt, c, 26.0)
					draw_circle(c, 4.0, pig)
				else:
					draw_arc(c, 9.0, 0.0, TAU, 20, Color(pig.r, pig.g, pig.b, 0.4), 1.5)
					draw_circle(c, 5.0, pig)
			"death":  # 죽은 자리 — 해골 낙서(지도 마커와 동일), 없으면 붉은 가위표 fallback
				var tk: Texture2D = _tex("res://assets/arts/transparent/44_낙서_해골.png")
				if tk != null:
					SectionArt.draw_tex_center(self, tk, c, 30.0)
				else:
					draw_line(c + Vector2(-7.0, -7.0), c + Vector2(7.0, 7.0), UITheme.DANGER, 2.5)
					draw_line(c + Vector2(-7.0, 7.0), c + Vector2(7.0, -7.0), UITheme.DANGER, 2.5)
			"straggler":  # 뒤처진 이 — 웅크린 사람(킷 61, 지도 마커와 동일), 없으면 실루엣 fallback
				var ts: Texture2D = _tex("res://assets/arts/transparent/61_사람_낙오자.png")
				if ts != null:
					SectionArt.draw_tex_center(self, ts, c, 30.0)
				else:
					draw_circle(c + Vector2(0.0, -8.0), 4.0, mk)
					draw_arc(c + Vector2(0.0, 4.0), 8.0, PI, TAU, 12, mk, 3.0)

var _chapter: int = 0
var _chron_idx: int = 0        ## 일대기 챕터 펼침(0=목록 첫 장|행적 · 1..=목록 계속) — 책 원칙: 스크롤 대신 넘김
var _ctrl_idx: int = 0         ## 조작 챕터 펼침(0=안내 글·1=표식 읽기) — 양면에 둘씩, 넘겨서 본다
var _set_idx: int = 0          ## 설정 챕터 펼침(차례 · 소리|화면 · 이야기|Credit · 여정|위험)
var _village_idx: int = 0      ## 마을 챕터 펼침(0=사람들·1..=이룬 일) — 책 원칙: 스크롤 대신 넘김
var _flipping: bool = false
var _flip_serial: int = 0           ## 넘김 회차 — 워치독이 "그 넘김"이 아직인지 판별(2026-07-27)
var _flip_started_ms: int = 0       ## 넘김 시작 시각 — 폴링 워치독(_process)용(0.3.6)
var _tab_armed: int = -1            ## 누름이 확인된 탭 index — 누름 없는 뗌(유령)의 넘김 오발 방지(0.3.6)
var _scrim_armed: bool = false      ## 스크림 위 누름 확인 — 유령 뗌이 일지를 닫는 것 방지(0.3.6)
var _repause_count: int = 0         ## "열림+정지 풀림" 자가 수리 횟수 — 프로브 rp(0.3.7, 경로 추적용)
var _last_nav: String = "-"         ## 마지막 챕터 이동의 출처(op=열기·fl=탭·sj=차례·cl=덮음) — 프로브 nv(0.3.9)
var _relayout_wanted: bool = false  ## 넘김 중 도착한 리사이즈 — 넘김이 끝나면 반영(버리면 낡은 배치가 남는다)
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
	# 뷰포트 크기 변화 시 열려 있는 일지를 다시 배치 — 웹에서 책갈피 클릭이 전체화면 진입(Fullscreen)을
	# 일으켜 뷰포트가 리사이즈되면 책이 옛 크기로 남아 비율이 깨지던 것 방지(트리 pause 중에도 신호는 온다).
	get_viewport().size_changed.connect(_on_viewport_resized)

## 뷰포트 리사이즈(전체화면 진입·창 크기 변경) — 일지가 열려 있으면 책과 현재 챕터를 다시 배치·렌더.
## 넘김 중이면 버리지 않고 미뤄 둔다 — 여기서 그냥 return 하면 낡은 배치가 영영 남는다
## (웹: 탭마다 전체화면 재진입 리사이즈가 넘김과 자주 겹친다, 2026-07-14).
func _on_viewport_resized() -> void:
	if _panel == null or not _panel.visible:
		return
	if _flipping:
		_relayout_wanted = true
		return
	_layout_book()
	if not _in_confirm:
		_render_chapter()

func _process(_delta: float) -> void:
	if ENABLED:
		_refresh_icon()
	# 넘김 폴링 워치독(0.3.6) — 타이머 콜백이 어떤 이유로든 안 와도(웹 절전·숨김 왕복 등)
	# 매달린 넘김을 정리한다. get_ticks_msec 는 벽시계라 숨김 중에도 흘러, 복귀 첫 프레임에 잡힌다.
	if _flipping and Time.get_ticks_msec() - _flip_started_ms > 2500:
		_force_end_flip()
	# 불변식 자가 수리(0.3.7) — 일지가 열려 있으면 세계는 반드시 멈춰 있어야 한다.
	# 폰 프로브(0.3.5)에서 p:0(열림+정지 풀림)이 관측됨 — 경로 미상이라 일단 되잠그고 횟수를 남긴다(rp).
	if is_open() and not get_tree().paused:
		get_tree().paused = true
		_repause_count += 1

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

	# 오른쪽 가장자리 리본 — 일지에 끼워둔 빨간 책갈피. 좌상단은 HUD(원정·자원) 자리라 우상단에 건다.
	# DEV 버튼(y6~44)보다 아래(y50~)로 내려 개발 빌드에서도 안 겹친다.
	_ribbon = Ribbon.new()
	_ribbon.flip = true
	_ribbon.anchor_left = 1.0
	_ribbon.anchor_right = 1.0
	_ribbon.offset_left = -128.0 if _touch_ui() else -96.0   # 히트 영역(그리기는 length 만큼) — 터치는 넉넉히
	_ribbon.offset_right = 0.0
	_ribbon.offset_top = 50.0
	_ribbon.offset_bottom = 96.0 if _touch_ui() else 80.0
	if _touch_ui():
		_ribbon.ribbon_h = 38.0
		_ribbon.length = 66.0
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
	_footer_r = VBoxContainer.new()  # 바닥 고정 — 넘김/덮기가 내용 높이와 무관하게 항상 같은 자리
	_footer_r.add_theme_constant_override("separation", 6)
	# ★ 컨테이너 기본 PASS 는 "투명"이 아니다 — 픽킹을 가로채 부모로만 올려, 밑에 깔린 형제(버튼)는
	#   탭을 영영 못 받는다. 확인 페이지에서 _box_r 버튼이 이 (비워진) 푸터 밑으로 가라앉으면
	#   "나간다" 무반응(2026-07-14 폰 웹 제보). IGNORE 면 자식(넘김 버튼)은 그대로 받고 몸통만 투명.
	_footer_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(_footer_r)

	# 챕터 책갈피 — 책 오른쪽 가장자리에서 삐져나온 작은 리본들(현재 챕터가 가장 김).
	# 터치 기기(폰)에선 손가락 표적으로 한 단계 크게(2026-07-12 사용자 — 폰·데스크톱을 똑같이 맞출 필요 없음).
	var th: float = 46.0 if _touch_ui() else 28.0
	for i in range(CHAPTERS.size()):
		var tab := Ribbon.new()
		tab.text = L10N.t(str(CHAPTERS[i]))
		tab.ribbon_h = th
		tab.col = RED if i == 0 else Color(RED.r, RED.g, RED.b, 0.62)
		tab.size = Vector2(170.0 if _touch_ui() else 120.0, th)  # 히트 영역(그리기는 length 만큼) — 터치 여유
		tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tab.gui_input.connect(_on_tab_input.bind(i))
		_book.add_child(tab)
		_tabs.append(tab)

## 터치 기기(폰)인가 — 탭 크기 등 손가락 표적 분기.
func _touch_ui() -> bool:
	return DisplayServer.is_touchscreen_available()

## 리본 호버 — 좀 더 길게 삐져나온다(잡아당길 수 있다는 신호).
func _ribbon_hover(on: bool) -> void:
	if _rib_tw != null and _rib_tw.is_valid():
		_rib_tw.kill()
	_rib_tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_rib_tw.tween_property(_ribbon, "length", 88.0 if on else 52.0, 0.3)

func _on_ribbon_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		# 같은 클릭(또는 합성 터치)이 방금 열린 스크림까지 흘러가 즉시 닫던 버그 — 소비 + 다음 프레임 열기.
		_ribbon.accept_event()
		call_deferred("open_journal", 0)

## 탭은 "뗄 때" 반응한다(누를 때 X, 2026-07-27) — 안드로이드 뒤로가기 = 오른쪽 가장자리 스와이프의
## 시작 터치가 탭 띠(책 오른편~화면 끝)에 얹힌다. 누름 기준이면 의도치 않은 챕터 넘김이 시작된 채
## 시스템이 제스처를 가로채(뗌이 안 옴) 넘김이 매달렸다(폰 itch 복귀 먹통의 시발점). 탭 밖 뗌 = 취소.
func _on_tab_input(event: InputEvent, idx: int) -> void:
	var tab: Ribbon = _tabs[idx]
	var mb := event as InputEventMouseButton
	var st := event as InputEventScreenTouch
	if (mb != null and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed) or (st != null and st.pressed):
		tab.accept_event()  # 누름은 삼키기만 — 스크림 닫기로 새지 않게
		_tab_armed = idx    # 뗌이 유효하려면 같은 탭의 누름이 선행해야 한다(0.3.6)
		return
	if st != null and st.canceled:
		_tab_armed = -1     # 시스템이 가로챈 터치(뒤로가기 제스처) — 탭으로 치지 않는다(0.3.7).
		return              # 누름+취소 뗌이 둘 다 탭 위라 arming 만으론 못 거른다(0.3.5 폰 판독).
	var released: bool = (mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed) \
		or (st != null and not st.pressed)
	if not released:
		return
	var armed: int = _tab_armed
	_tab_armed = -1
	if armed != idx:
		return  # 누름 없이 도착한 뗌(복귀 후 유령 터치) — 무시. 0.3.5 폰 제보: 첫 터치가 설정 넘김 오발.
	var pos: Vector2 = mb.position if mb != null else st.position  # gui_input 좌표 = 컨트롤 로컬
	if Rect2(Vector2.ZERO, tab.size).grow(6.0).has_point(pos):
		tab.accept_event()
		_flip_to(idx)

# --- 열기/닫기/레이아웃 ---

## 일지를 특정 챕터로 연다(0=일대기·1=조작·2=설정). 타이틀 메뉴 등 외부 진입점.
func open_journal(chapter: int = 0) -> void:
	if Transition.busy():
		return  # 전환 중엔 열지 않는다 — 일지 밑에서 씬이 바뀌는 것 방지
	# ★ 일지가 열리면 세계가 멈춘다(트리 pause). 지도 이동·씬 전환이 일지 밑에서 계속 진행돼
	#   설정 위로 다음 씬 튜토리얼이 겹치던 버그(2026-07-06 사용자 제보)의 근본 차단 —
	#   "오버레이 밑에서 세계가 흐르는" 계열 전체를 막는다. Bookmark/AudioManager/Transition/Tutorial 은
	#   PROCESS_MODE_ALWAYS 라 일지 조작·음악·(닫은 뒤) 전환은 그대로 동작한다.
	get_tree().paused = true
	_relayout_wanted = false  # 닫혀 있는 동안 쌓인 잔여 플래그 정리(열며 어차피 새로 배치)
	_layout_book()
	_panel.visible = true
	UITheme.fade_in(_panel)
	_opened_ms = Time.get_ticks_msec()
	_tab_armed = -1        # 이전에 열렸을 때의 잔여 arming 정리(0.3.6)
	_scrim_armed = false
	AudioManager.play_sfx("res://assets/sfx/sfx_page_1.wav")
	_chapter = clampi(chapter, 0, CHAPTERS.size() - 1)
	_last_nav = "op%d" % _chapter
	_chron_idx = 0       # 일대기 챕터는 첫 장(목록|행적)부터
	_ctrl_idx = 0        # 조작 챕터는 안내 글부터(표식은 넘겨서)
	_set_idx = 0         # 설정 챕터는 차례(목차)부터 — 갈래가 많아 길잡이가 먼저(2026-07-26)
	_village_idx = 0     # 마을 챕터는 사람들부터(이룬 일은 넘겨서)
	_book.thickness_cf = float(_chapter)  # 페이지 두께 스택(§5) 초기 위치
	_apply_tab_state()
	_render_chapter()

## (구 진입점 호환 — 기존 호출부가 _open 을 부른다.)
func _open() -> void:
	open_journal(0)

## 일지가 열려 있나 — 다른 오버레이(Tutorial 등)가 겹침을 피할 때 본다.
func is_open() -> bool:
	return _panel != null and _panel.visible

## 복귀 치유(Fullscreen 이 부른다) — 전체화면/가시성 왕복 뒤 일지가 그려는 지는데 반응이 없는
## 폰 itch 사례(2026-07-26) 방어: 배치를 다시 재고 현재 챕터를 **새 컨트롤로** 다시 짓는다.
## 낡은 컨트롤이 어떤 상태로 굳었든 새로 지으면 무관해진다. 열려 있지 않으면 아무 것도 안 한다.
func heal_after_restore() -> void:
	if not is_open():
		return
	_tab_armed = -1        # 복귀 전 스와이프가 남긴 낡은 arming 해제(0.3.6)
	_scrim_armed = false
	for t in _tabs:        # 책갈피 표시 보험 — 복귀 후 탭이 안 보이던 관측(0.3.7 폰, 기전 미상) 방어
		(t as Control).visible = true
		(t as Control).queue_redraw()
	if _flipping:
		_force_end_flip()  # 매달린 넘김(뒤로가기로 숨겨진 사이 멎은 것)부터 걷어낸다
		return
	_layout_book()
	_apply_tab_state()
	_render_chapter()

## 매달린 넘김 강제 정리(워치독·복귀 치유 공용) — 덮개를 걷고 현재 챕터를 다시 짓는다.
func _force_end_flip() -> void:
	_flipping = false
	_tab_armed = -1
	_scrim_armed = false
	_flip_serial += 1  # 아직 매달려 있을 수 있는 옛 넘김 코루틴 무효화(await 뒤에서 스스로 물러남)
	for c in _book.get_children():
		if c is FlipDeck:
			(c as FlipDeck).queue_free()
	_relayout_wanted = false
	_layout_book()
	_apply_tab_state()
	if not _in_confirm:
		_render_chapter()

## 임시 진단 문자열(Fullscreen 프로브가 읽는다) — 원인이 확정되면 프로브와 함께 제거.
## tv = 탭 4개 각각 V(정상)/H(숨김)/X(해제됨), @ 뒤는 첫 탭의 화면 좌표. nv = 마지막 챕터 이동 출처.
func debug_state() -> String:
	var decks: int = 0
	for c in _book.get_children():
		if c is FlipDeck:
			decks += 1
	var tv: String = ""
	var tx: String = "-"
	for t in _tabs:
		if not is_instance_valid(t):
			tv += "X"
		elif not (t as Control).visible:
			tv += "H"
		else:
			tv += "V"
	if not _tabs.is_empty() and is_instance_valid(_tabs[0]):
		var gp: Vector2 = (_tabs[0] as Control).global_position
		tx = "%d,%d" % [int(gp.x), int(gp.y)]
	return "fl:%s dk:%d ch:%d sp:%d rp:%d nv:%s tv:%s@%s bw:%d" % ["1" if _flipping else "0",
		decks, _chapter, _set_idx, _repause_count, _last_nav, tv, tx,
		int(_book.size.x) if _book != null else -1]

func _close() -> void:
	_last_nav = "cl"
	get_tree().paused = false  # 일지를 덮으면 세계가 다시 흐른다(이동·연출 재개)
	AudioManager.play_sfx(AudioManager.CARD_CLOSE)  # 일지를 덮는 소리
	_panel.visible = false

func _on_scrim_input(event: InputEvent) -> void:
	# 뗄 때 기준(2026-07-27) — 뒤로가기 가장자리 스와이프의 "누름"이 스크림에 얹혀도 일지가 안 닫히게.
	# (뗌은 시스템이 가로채 안 오므로, 누름 기준이던 시절엔 스와이프만으로 닫혔다.)
	# 여기에 누름 선행 요구(0.3.6) — 누름 없이 도착한 유령 뗌이 일지를 닫는 것도 막는다.
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		_scrim_armed = true
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).canceled:
		_scrim_armed = false  # 취소 터치(뒤로가기 제스처)로는 일지를 닫지 않는다(0.3.7)
		return
	var released: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) \
		or (event is InputEventScreenTouch and not event.pressed)
	# 연 직후 250ms 는 무시 — 여는 클릭의 잔여 이벤트(합성 터치 등)가 바로 닫는 것 방지.
	if not released or Time.get_ticks_msec() - _opened_ms <= 250:
		return
	var armed: bool = _scrim_armed
	_scrim_armed = false
	if not armed:
		return
	# 책·챕터 탭 둘레의 여유 띠에선 닫지 않는다 — 탭을 노리다 살짝 빗나간 터치가
	# 일지를 닫아 버리던 것 방지(2026-07-12 사용자). 진짜 바깥(먼 검은 영역)만 닫는다.
	if _book != null:
		var guard := Rect2(_book.global_position, _book.size).grow(36.0)
		guard.size.x += 190.0   # 오른쪽 챕터 탭 기둥까지 감싼다
		if guard.has_point(event.position):
			return
	_close()

## 일지 크기 — 화면 90%·상한 1080×640(옛 장부와 동일 비율).
## 폭은 추가로 vp.x-200 을 넘지 않는다 — 챕터 탭(오른쪽 리본, 폭 ~104)이 화면 안에 들어올 조건.
## 기준 화면(1280)에선 상한 1080 이 정확히 이 조건이었지만, 글자 배율(>100%)로 논리 뷰포트가
## 좁아지면 조건이 깨져 탭이 잘렸다(2026-07-15 — 07-07 "에디터 임베드뷰 잘림"의 실제 정체).
func _layout_book() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var w: float = minf(vp.x * 0.9, minf(1080.0, vp.x - 200.0))
	var h: float = minf(vp.y * 0.86, 640.0)
	_book.size = Vector2(w, h)
	_book.position = (vp - Vector2(w, h)) * 0.5
	_book.relayout()
	# 페이지 내용 배치. ★ 자식(_box_l) 최소폭을 rect 기준으로 "먼저" 줄인다 — Control.set_size 는
	# 최소 크기 밑으로 못 줄어서, 자식 최소폭이 큰 채로 scroll.size 를 대입하면 축소가 막힌다
	# (재배치마다 20px 씩만 줄어드는 랫칫 — 뷰포트가 좁아질 때만 걸려 07-07 "임베드뷰 잘림"으로 오인).
	var scroll_size: Vector2 = _book.rect_l.size - Vector2(PAGE_PAD * 2.0, PAGE_PAD * 2.0)
	_box_l.custom_minimum_size.x = scroll_size.x - 20.0  # 우측 여백(스크롤바+값 라벨 잘림 방지)
	_scroll_l.position = _book.rect_l.position + Vector2(PAGE_PAD, PAGE_PAD)
	_scroll_l.size = scroll_size
	# 오른쪽 페이지: 내용(_box_r)은 위쪽, 넘김/덮기(_footer_r)는 바닥 고정 자리.
	var footer_h: float = 118.0
	_box_r.position = _book.rect_r.position + Vector2(PAGE_PAD, PAGE_PAD)
	_box_r.size = _book.rect_r.size - Vector2(PAGE_PAD * 2.0, PAGE_PAD * 2.0 + footer_h)
	_footer_r.position = _book.rect_r.position + Vector2(PAGE_PAD, _book.rect_r.size.y - PAGE_PAD - footer_h)
	_footer_r.size = Vector2(_book.rect_r.size.x - PAGE_PAD * 2.0, footer_h)
	var tab_gap: float = 64.0 if _touch_ui() else 44.0
	for i in range(_tabs.size()):
		var tab: Ribbon = _tabs[i]
		tab.position = Vector2(w - 4.0, 36.0 + float(i) * tab_gap)

# --- 챕터 (낱장 넘김) ---

## 챕터 책갈피를 누름 — 책장 넘김 리플(외부 핸드오프 handoff_book_flip 이식, 확정값 450ms·8장).
## 현재 두 페이지를 화면에서 캡처해 낱장 텍스처로 쓰고, 콘텐츠는 목표 챕터로 즉시 교체 —
## 같은 프레임에 FlipDeck 가 위를 덮어(p=0 = 이전 모습) 팝이 없다. 점프는 최단 방향 1회(스펙).
func _flip_to(idx: int) -> void:
	if _flipping or idx == _chapter:
		return
	_last_nav = "fl%d" % idx
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
	# 연출 세기 0(모션 줄이기) — 넘김 연출 없이 즉시 교체. 소리는 넘김 피드백으로 유지.
	if AppSettings.load_motion() <= 0.02:
		AudioManager.play_sfx_random(PAGE_SFX)
		_book.thickness_cf = cf_to
		swap.call()
		return
	_flipping = true
	_flip_started_ms = Time.get_ticks_msec()  # 폴링 워치독(_process) 기준점
	# 워치독(2026-07-27) — 아래 await(frame_post_draw)는 웹에서 화면이 숨겨지면(폰 뒤로가기)
	# 렌더 프레임이 멎어 그대로 매달린다. _flipping 이 true 로 굳으면 넘김·점프가 전부 잠기므로,
	# 넘김 정상 길이(0.45s)보다 넉넉히 지나도 안 끝났으면 강제 정리한다(타이머도 숨김 중엔 멎고
	# 복귀 후 이어 재므로, 사실상 "복귀 2초 뒤 자동 복구"가 된다).
	_flip_serial += 1
	var my_flip: int = _flip_serial
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if _flipping and _flip_serial == my_flip:
			_force_end_flip())
	AudioManager.play_sfx_random(PAGE_SFX)  # 장 집힐 때 1회
	var t0: int = Time.get_ticks_msec()
	await RenderingServer.frame_post_draw
	if not _flipping or _flip_serial != my_flip:
		return  # 매달린 사이 워치독이 정리했다 — 낡은 캡처·덮개를 얹지 않는다
	if Time.get_ticks_msec() - t0 > 1000:
		# 이 await 가 화면 숨김(뒤로가기)을 통과했다 — 스와이프가 남긴 유령 넘김이다(0.3.8).
		# 복귀 첫 렌더에서 폴링 워치독(_process)보다 먼저 깨는 경합은 없지만, 외출이 2.5초보다
		# 짧으면 워치독 문턱에 안 걸려 스왑이 완주한다(0.3.7 폰 ch:3 랜딩). 스왑 없이 중단 —
		# 챕터가 보존된다. 정상 넘김의 await 는 한 프레임(수십 ms)이라 오탐 없음.
		_force_end_flip()
		return
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
	deck.on_done = func() -> void:
		_flipping = false
		if _relayout_wanted:  # 넘김 중 밀린 리사이즈 반영
			_relayout_wanted = false
			_layout_book()
			if not _in_confirm:
				_render_chapter()
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
## 탭 길이 — 모든 탭이 같은 길이(글자별 재단은 열림/닫힘과 헷갈린다 — 2026-07-12 사용자).
## 가장 긴 챕터명("일대기")이 V 홈을 침범하지 않는 길이를 기준으로, 펼침(현재 챕터)만 더 길다.
func _apply_tab_state() -> void:
	var f: Font = _book.get_theme_default_font() if _book != null else null
	var base_len: float = 96.0 if _touch_ui() else 72.0
	if f != null and not _tabs.is_empty():
		var h: float = (_tabs[0] as Ribbon).ribbon_h
		var tfs: int = clampi(int(h * 0.48), 12, 19)
		var wmax: float = 0.0
		for ch in CHAPTERS:
			wmax = maxf(wmax, f.get_string_size(L10N.t(str(ch)), HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x)
		base_len = maxf(base_len, 9.0 + wmax + h * 0.85 + 10.0)
	for i in range(_tabs.size()):
		var tab: Ribbon = _tabs[i]
		tab.col = RED if i == _chapter else Color(RED.r, RED.g, RED.b, 0.62)
		tab.length = base_len + (26.0 if i == _chapter else 0.0)

func _render_chapter() -> void:
	match _chapter:
		CH_CHRONICLE:
			_show_chronicle()
		CH_VILLAGE:
			_show_village()
		CH_CONTROLS:
			_show_tutorial()
		CH_SETTINGS:
			_show_settings()

# --- 챕터: 일대기 ---

## 책 원칙: 세로 스크롤 금지("책 컨셉에 스크롤은 어긋난다" — 2026-07-07 사용자) → 마을처럼 펼침 넘김.
## 원정이 쌓이면 왼쪽 목록이 스크롤로 흐르던 것을 교체(2026-07-19 사용자).
## 펼침 0 = 목록 첫 장 | 행적 요약. 펼침 1.. = 목록 계속(좌 4|우 4).
const CHRON_PER_PAGE: int = 4   ## 목록 한 페이지 최대 원정 수(죽음 줄은 3줄로 접힐 수 있어 보수적으로)

## 일대기 챕터 펼침 수 — 첫 장(왼쪽 4) 이후 남는 원정을 펼침당 8(좌 4·우 4)씩.
func _chron_spreads() -> int:
	var rest: int = GameState.expedition_count - CHRON_PER_PAGE
	return 1 + maxi(0, ceili(float(rest) / float(CHRON_PER_PAGE * 2)))

func _show_chronicle() -> void:
	_clear(_box_l)
	_clear(_box_r)
	var n: int = GameState.expedition_count
	_box_l.add_child(_page_heading("원정 일대기", 32, INK))
	if _chron_idx == 0:
		if n <= 0:
			_box_l.add_child(_ink_label("아직 떠난 원정이 없다.", UITheme.FS_LABEL, INK_FADE))
		for exp in range(1, mini(n, CHRON_PER_PAGE) + 1):
			_box_l.add_child(_chronicle_line(exp))
		_box_r.add_child(_page_heading("행적", 32, INK))
		_box_r.add_child(UITheme.make_hairline(Color(INK.r, INK.g, INK.b, 0.35), 2.0))
		_box_r.add_child(_ledger_row("보낸 원정", L10N.t("%d회") % GameState.expedition_count))
		_box_r.add_child(_ledger_row("남긴 흔적", "%d" % GameState.traces.size()))
		_box_r.add_child(_ledger_row("죽은 자리", "%d" % GameState.deaths.size()))
		_box_r.add_child(_ledger_row("기린 자리", "%d" % GameState.mourn_count()))
		_box_r.add_child(_ledger_row("끝에 닿음", L10N.t("%d번") % GameState.arrivals.size()))
	else:
		var start: int = CHRON_PER_PAGE + (_chron_idx - 1) * CHRON_PER_PAGE * 2
		for i in range(start, mini(n, start + CHRON_PER_PAGE * 2)):
			var box: VBoxContainer = _box_l if i < start + CHRON_PER_PAGE else _box_r
			box.add_child(_chronicle_line(i + 1))
	if _chron_spreads() > 1:
		_spread_nav(_chron_idx, _chron_spreads(), _chron_prev, _chron_next)
	else:
		_add_close(_box_r)

func _chron_prev() -> void:
	if _flipping or _chron_idx <= 0:
		return
	_flip_page(-1, func() -> void:
		_chron_idx = maxi(0, _chron_idx - 1)
		_show_chronicle())

func _chron_next() -> void:
	if _flipping or _chron_idx >= _chron_spreads() - 1:
		return
	_flip_page(1, func() -> void:
		_chron_idx = mini(_chron_spreads() - 1, _chron_idx + 1)
		_show_chronicle())

# --- 챕터: 마을 (공훈 — 이룬 일이 사람을 부른다, 직능 해금. 2026-07-11 사용자 확정) ---

## 책 원칙: 세로 스크롤 금지("책 컨셉에 스크롤은 어긋난다" — 2026-07-07 사용자) → 펼침 넘김.
## 펼침 0 = 마을 사람들(직능 공훈, 좌 3|우 2). 펼침 1.. = 이룬 일(달성 공훈, 좌 4|우 4 — 넘치면 다음 펼침).
## 한 페이지에 다 담으면 왼쪽은 스크롤바가 뜨고 오른쪽은 바닥 고정 "일지를 덮는다" 위로 흘렀다(2026-07-13 사용자).
## 기록형 공훈(unlocks 없음)은 사람을 부르지 않는다 — 사람들에선 빼고, 달성하면 이룬 일에만.
const VILLAGE_PER_PAGE: int = 4   ## 이룬 일 한 페이지 최대 항목(한 펼침 = 좌우 8)
const VILLAGE_PEOPLE_L: int = 3   ## 사람들 펼침의 왼쪽 페이지 인원(나머지는 오른쪽)

## 마을 챕터 펼침 수 — 사람들 1 + 이룬 일 (항목 수에 따라 1 이상).
func _village_spreads() -> int:
	return 1 + maxi(1, ceili(float(GameState.feats_unlocked.size()) / float(VILLAGE_PER_PAGE * 2)))

func _show_village() -> void:
	_clear(_box_l)
	_clear(_box_r)
	if _village_idx == 0:
		_village_people()
	else:
		_village_records(_village_idx - 1)
	_spread_nav(_village_idx, _village_spreads(), _village_prev, _village_next)

func _village_prev() -> void:
	if _flipping or _village_idx <= 0:
		return
	_flip_page(-1, func() -> void:
		_village_idx = maxi(0, _village_idx - 1)
		_show_village())

func _village_next() -> void:
	if _flipping or _village_idx >= _village_spreads() - 1:
		return
	_flip_page(1, func() -> void:
		_village_idx = mini(_village_spreads() - 1, _village_idx + 1)
		_show_village())

## 펼침 0 — 마을에 온(올) 사람들. 직능별 해금 상태와 오는 조건(조건은 세계의 말 — Feats.cond).
## 항목 시각 구분(2026-07-13 사용자 — "어디까지가 누구 소개인지 감이 안 온다"):
## 이름 줄은 진한 잉크(항목의 머리), 소개는 들여쓰기+이름에 붙임(한 덩이), 항목 사이 옅은 괘선.
func _village_people() -> void:
	_box_l.add_child(_page_heading("마을", 32, INK))
	_box_l.add_child(_ink_label("원정 이야기는 마을에 금방 퍼진다.\n소문을 듣고, 하나둘 찾아온다.", UITheme.FS_SMALL, INK_FADE))
	_box_l.add_child(UITheme.make_hairline(Color(INK.r, INK.g, INK.b, 0.35), 2.0))
	var opened: Array = GameState.unlocked_vocations()
	var people: Array = []
	for f in Feats.LIST:
		if str(f.get("unlocks", "")) != "":
			people.append(f)
	var prev_box: VBoxContainer = null
	for i in range(people.size()):
		var box: VBoxContainer = _box_l if i < VILLAGE_PEOPLE_L else _box_r
		if box == prev_box:
			box.add_child(UITheme.make_hairline(Color(INK.r, INK.g, INK.b, 0.14), 1.0))
		prev_box = box
		box.add_child(_person_entry(people[i], opened))

## 사람 한 항목 — 이름 줄 + 들여 쓴 소개를 한 덩이로(항목 경계가 눈에 잡히게).
## 온 사람에겐 얻은 내력 한 줄(Feats.done) — 무엇을 해서 그가 왔는지 잊지 않게(2026-07-13 사용자).
func _person_entry(f: Dictionary, opened: Array) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var vid: String = str(f.get("unlocks", ""))
	var nm: String = L10N.t(Vocations.name_of(vid))
	if opened.has(vid):
		# 온 사람은 이름을 붉은 잉크로 — 잠긴 줄들 사이에서 한눈에 띈다.
		v.add_child(_rich_label(L10N.t("[color=#8a2f1b]%s[/color] · 마을에 있다") % nm, UITheme.FS_LABEL, INK))
		if str(f.get("done", "")) != "":
			v.add_child(_indent_small(str(f.get("done", ""))))
	else:
		v.add_child(_ink_label(L10N.t("%s · 아직 소식이 없다") % nm, UITheme.FS_LABEL, INK))
		v.add_child(_indent_small(str(f.get("cond", ""))))
	return v

## 항목 본문 들여쓰기(이름 줄 아래 작은 글) — 사람 소개·얻은 내력이 공유.
func _indent_small(txt: String) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 18)
	m.add_child(_ink_label(txt, UITheme.FS_SMALL, INK_FADE))
	return m

## 펼침 1.. — 이룬 일(달성한 공훈·기록, 달성 순서). pair = 이룬 일 몇 번째 펼침인가(0부터).
func _village_records(pair: int) -> void:
	_box_l.add_child(_page_heading("이룬 일", 32, INK))
	_box_l.add_child(UITheme.make_hairline(Color(INK.r, INK.g, INK.b, 0.35), 2.0))
	var done_ids: Array = GameState.feats_unlocked
	if done_ids.is_empty():
		_box_l.add_child(_ink_label("아직 적을 것이 없다.\n길이 하나씩 가르쳐 줄 것이다.", UITheme.FS_LABEL, INK_FADE))
		return
	var start: int = pair * VILLAGE_PER_PAGE * 2
	for i in range(start, mini(done_ids.size(), start + VILLAGE_PER_PAGE * 2)):
		var box: VBoxContainer = _box_l if i < start + VILLAGE_PER_PAGE else _box_r
		var done: Dictionary = Feats.by_id(str(done_ids[i]))
		box.add_child(_ink_label(str(done.get("name", "")), UITheme.FS_LABEL, RED))
		box.add_child(_ink_label(str(done.get("line", "")), UITheme.FS_SMALL, INK_FADE))

# --- 챕터: 조작 안내 (펼침 2장 — 안내 글 | 표식 읽기 범례, 양면 다 채움) ---

const CTRL_SPREADS: int = 2  ## 0=안내(네 갈래 설명), 1=표식 읽기(범례 7종)

func _show_tutorial() -> void:
	_clear(_box_l)
	_clear(_box_r)
	if _ctrl_idx == 0:
		_ctrl_guide()
	else:
		_ctrl_legend()
	_spread_nav(_ctrl_idx, CTRL_SPREADS, _ctrl_prev, _ctrl_next)

func _ctrl_prev() -> void:
	if _flipping or _ctrl_idx <= 0:
		return
	_flip_page(-1, func() -> void:
		_ctrl_idx = 0
		_show_tutorial())

func _ctrl_next() -> void:
	if _flipping or _ctrl_idx >= CTRL_SPREADS - 1:
		return
	_flip_page(1, func() -> void:
		_ctrl_idx = 1
		_show_tutorial())

## 안내 — 네 갈래 조작 설명을 양면에 둘씩(왼 2·오 2).
func _ctrl_guide() -> void:
	_box_l.add_child(_page_heading("조작 안내", 32, INK))
	_box_l.add_child(UITheme.make_hairline(Color(INK.r, INK.g, INK.b, 0.35), 2.0))
	_box_l.add_child(_rich_label(str(TUTORIAL_PAGES[0]), UITheme.FS_BODY, INK))
	_box_l.add_child(UITheme.make_hairline(Color(INK.r, INK.g, INK.b, 0.15), 1.0))
	_box_l.add_child(_rich_label(str(TUTORIAL_PAGES[1]), UITheme.FS_BODY, INK))
	_box_r.add_child(_rich_label(str(TUTORIAL_PAGES[2]), UITheme.FS_BODY, INK))
	_box_r.add_child(UITheme.make_hairline(Color(INK.r, INK.g, INK.b, 0.15), 1.0))
	_box_r.add_child(_rich_label(str(TUTORIAL_PAGES[3]), UITheme.FS_BODY, INK))

## 표식 읽기 — 범례 9종을 양면에 나눠(왼 4·오 5). 지도·단면 실제 표식의 축소판.
func _ctrl_legend() -> void:
	_box_l.add_child(_page_heading("표식 읽기", 32, INK))
	_box_l.add_child(UITheme.make_hairline(Color(INK.r, INK.g, INK.b, 0.35), 2.0))
	_box_l.add_child(_legend_row("main", "주요 지점", "그 자리에서 벌어지는 가장 큰 일. 큰 이중 고리로 눈에 띈다."))
	_box_l.add_child(_legend_row("collect", "살필 곳", "물이나 식량, 흔적, 작은 일이 있을 수 있다."))
	_box_l.add_child(_legend_row("done", "다 살핀 곳", "이미 살펴 흐려진 지점."))
	_box_l.add_child(_legend_row("ramp", "조사 남음", "이 자리에서 살필 수 있는 횟수. 찬 점이 남은 것."))
	_box_r.add_child(_legend_row("route", "밟은 길", "지난 원정대가 밟아 이어진 길."))
	_box_r.add_child(_legend_row("marker", "원정대", "지금 이 원정대가 선 자리."))
	_box_r.add_child(_legend_row("trace", "남긴 흔적", "이전 원정대가 남긴 물건. 색으로 물과 식량, 장막을 나눈다."))
	_box_r.add_child(_legend_row("death", "죽은 자리", "원정이 끝난 자리. 지나는 이가 기릴 수 있다."))
	_box_r.add_child(_legend_row("straggler", "뒤처진 이", "지난 원정에서 뒤처져 기다린다. 물을 나누면 거둘 수 있다."))

## 범례 한 줄 — 왼쪽 표식 그림 + 오른쪽 이름·뜻.
func _legend_row(kind: String, title: String, meaning: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var mark := LegendMark.new()
	mark.kind = kind
	mark.custom_minimum_size = Vector2(52, 48)
	row.add_child(mark)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	col.add_child(_ink_label(title, UITheme.FS_LABEL, INK))
	col.add_child(_ink_label(meaning, UITheme.FS_SMALL, INK_FADE))
	row.add_child(col)
	return row

# --- 챕터: 설정 (펼침 넘김 — 차례|언어·Credit · 소리|화면 · 이야기·여정|위험) ---

const SETTINGS_SPREADS: int = 3  ## 펼침 3장. 빈 면 없이 채운다(빈 공간 지적, 2026-07-26 사용자).

## 왼쪽·오른쪽 페이지 각각 한 부분. 넘김(이전/다음)과 덮기는 오른쪽 아래 슬림 줄로.
## 언어는 첫 펼침 오른쪽 — 열자마자 보이는 자리(어디 있는지 모르겠다는 지적, 2026-07-26 사용자).
## 웹에선 게임 끝내기·전체화면 토글을 숨긴다(브라우저가 관장 — Fullscreen autoload 가 자동 전체화면).
func _show_settings() -> void:
	_in_confirm = false
	_clear(_box_l)
	_clear(_box_r)
	match _set_idx:
		0:
			_sec_contents(_box_l)
			_sec_language(_box_r)
		1:
			_sec_sound(_box_l)
			_sec_screen(_box_r)
		_:
			_sec_story(_box_l)
			_box_l.add_child(_gap(18))
			_sec_journey(_box_l)
			_sec_danger(_box_r)
	_settings_nav()

func _settings_nav() -> void:
	_spread_nav(_set_idx, SETTINGS_SPREADS, _set_prev, _set_next)

## 오른쪽 페이지 아래 넘김 줄(설정·조작 공용) — 내용을 위로 붙이고, 헤어라인 아래에
## 이전/펼침 번호/다음 + 덮기. 헤어라인으로 넘김 영역을 뚜렷이 구분한다(놓치지 않게).
func _spread_nav(idx: int, total: int, prev_cb: Callable, next_cb: Callable) -> void:
	_clear(_footer_r)  # 바닥 고정 자리 — 내용 높이와 무관하게 매 펼침 같은 위치
	_footer_r.add_child(UITheme.make_hairline(Color(INK.r, INK.g, INK.b, 0.3), 1.5))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if idx > 0:
		row.add_child(_ink_btn("‹ 이전", prev_cb))
	var ind := _ink_label("%d / %d" % [idx + 1, total], UITheme.FS_LABEL, INK_FADE)
	ind.autowrap_mode = TextServer.AUTOWRAP_OFF  # "1 / 3" 이 좁은 폭에서 세로로 쪼개지지 않게
	row.add_child(ind)
	if idx < total - 1:
		row.add_child(_ink_btn("다음 ›", next_cb))
	_footer_r.add_child(row)
	_footer_r.add_child(_ink_btn("일지를 덮는다", _close))

func _set_prev() -> void:
	if _flipping or _set_idx <= 0:
		return
	_flip_page(-1, func() -> void:
		_set_idx = maxi(0, _set_idx - 1)
		_show_settings())

func _set_next() -> void:
	if _flipping or _set_idx >= SETTINGS_SPREADS - 1:
		return
	_flip_page(1, func() -> void:
		_set_idx = mini(SETTINGS_SPREADS - 1, _set_idx + 1)
		_show_settings())

## 차례(설정 챕터 첫 펼침) — 갈래가 많아 찾기 어렵다는 지적(2026-07-26 사용자).
## 항목을 누르면 그 펼침으로 넘김 연출과 함께 이동한다.
func _sec_contents(box: VBoxContainer) -> void:
	box.add_child(_page_heading("차례", 32, INK))
	box.add_child(UITheme.make_hairline(Color(INK.r, INK.g, INK.b, 0.35), 2.0))
	_toc_row(box, "소리", 1)
	_toc_row(box, "화면", 1)
	_toc_row(box, "이야기", 2)
	_toc_row(box, "여정", 2)
	_toc_row(box, L10N.t("위험").capitalize(), 2)  # 태그 단어와 키 공유(소문자 danger) — 목차에선 첫 글자만 올림
	box.add_child(_gap(10))
	box.add_child(_ink_label("가고 싶은 곳을 누르면\n그 장으로 넘어갑니다.", UITheme.FS_SMALL, INK_FADE))

## 언어 + Credit — 차례 맞은편(첫 펼침 오른쪽). 언어를 열자마자 보이는 자리에 둔다.
## 언어 이름은 각 언어 자신의 표기라 번역 표를 태우지 않는다(표에 키가 없어 그대로 나온다).
func _sec_language(box: VBoxContainer) -> void:
	box.add_child(_page_heading("언어 · Language", 32, INK))
	box.add_child(UITheme.make_hairline(Color(INK.r, INK.g, INK.b, 0.35), 2.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_lang_pill("한국어", "ko"))
	row.add_child(_lang_pill("English", "en"))
	box.add_child(row)
	box.add_child(_ink_label("지금 화면부터 바로 바뀝니다.", UITheme.FS_SMALL, INK_FADE))
	box.add_child(_gap(14))
	box.add_child(_page_heading("Credit", 24, INK))
	box.add_child(UITheme.make_hairline(Color(INK.r, INK.g, INK.b, 0.2), 1.0))
	box.add_child(_ink_label("See you on the other side", UITheme.FS_LABEL, INK))
	box.add_child(_ink_label("만든 이   soomin007", UITheme.FS_LABEL, INK))
	box.add_child(_ink_label("Fonts   MaruBuri · Cinzel (OFL)\nMusic   Suno · SFX   ElevenLabs · freesound.org\nEngine   Godot 4.6",
		UITheme.FS_SMALL, INK_FADE))

## 언어 pill — 지금 쓰는 언어는 잉크로 채워 표시.
func _lang_pill(label_txt: String, code: String) -> Button:
	var active: bool = (code == "en") == L10N.is_en()
	var pill: Button
	if active:
		pill = UITheme.make_pill(label_txt, PAPER, INK, INK)
	else:
		pill = UITheme.make_pill(label_txt, INK, Color(0, 0, 0, 0), Color(INK.r, INK.g, INK.b, 0.4))
	pill.pressed.connect(func() -> void: _switch_language(code))
	return pill

## 언어 바꾸기 — 일지는 즉시 다시 그리고, 밑의 화면도 안전하면 바로 새로 짓는다.
## (일지만 갈아입고 씬을 안 지으면 "돌아가 보니 여전히 옛 언어" — 2026-07-26 사용자 제보.)
func _switch_language(code: String) -> void:
	if AppSettings.load_language() == code:
		return
	AppSettings.set_language(code)
	_show_settings()
	_apply_tab_state()  # 탭 길이 재계산(언어마다 챕터명 폭이 다르다)
	for t in _tabs:     # 탭·리본 글자는 그리기 시점 번역(Ribbon._draw) — 새 언어로 다시 그린다
		(t as Control).queue_redraw()
	if _ribbon != null:
		_ribbon.queue_redraw()
	_reload_scene_for_language()

## 씬별 안전 가드 — 지도는 run 이 죽어 있으면 _ready 가 새 원정을 만들어 세이브를 오염시킨다
## (begin_run_in_place 함정, known_issues). 단면은 스냅샷 정밀 복원 설계(2026-07-10)라 다시 지어도 그대로.
## 목록 밖 씬(오프닝·막간·마을 안내)은 안 짓는다 — 다음 씬부터 새 언어.
func _reload_scene_for_language() -> void:
	var cs: Node = get_tree().current_scene
	if cs == null:
		return
	var alive: bool = GameState.current_run != null and GameState.current_run.alive
	var safe: bool = false
	match cs.scene_file_path:
		"res://scenes/main.tscn", "res://scenes/loadout.tscn":
			safe = true
		"res://scenes/map.tscn":
			safe = alive
		"res://scenes/expedition.tscn":
			safe = GameState.current_run != null
	if not safe:
		return
	if cs.has_method("stash_for_language_reload"):
		cs.stash_for_language_reload()
	get_tree().reload_current_scene.call_deferred()

## 세로 여백(고정 높이) — 페이지 안 소단락 구분용.
func _gap(h: int) -> Control:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, h)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sp

## 차례 한 줄 — 왼쪽 항목 이름(잉크 버튼, 줄 전체가 탭 영역), 오른쪽 펼침 번호(옅은 잉크).
func _toc_row(box: VBoxContainer, name_txt: String, target: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var b := _ink_btn(name_txt, func() -> void: _set_jump(target), UITheme.FS_BODY)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b)
	var num := _ink_label(str(target + 1), UITheme.FS_LABEL, INK_FADE)
	num.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(num)
	box.add_child(row)

## 차례에서 펼침으로 점프 — 거리만큼 낱장을 넘긴다(2장 이상은 리플, 챕터 점프와 같은 결).
func _set_jump(target: int) -> void:
	if _flipping or target == _set_idx:
		return
	_last_nav = "sj%d" % target
	var dist: int = absi(target - _set_idx)
	var dir: int = 1 if target > _set_idx else -1
	_run_flip(dir, dist, 0.45 if dist > 1 else 0.0, 0.5 if dist > 1 else 1.0, dist > 1,
		float(_chapter), float(_chapter), func() -> void:
			_set_idx = target
			_show_settings())

## 소리(음소거·배경음악·효과음). 음소거는 자기 줄로(헤딩 옆 두면 큰 글자 크기에서 페이지를 넘침).
func _sec_sound(box: VBoxContainer) -> void:
	box.add_child(_page_heading("소리", 32, INK))
	box.add_child(UITheme.make_hairline(Color(INK.r, INK.g, INK.b, 0.35), 2.0))
	var master: float = AppSettings.load_master_volume()
	var mute := UITheme.make_pill("소리 켜기" if master <= 0.0 else "전체 음소거", INK, Color(0, 0, 0, 0),
		Color(INK.r, INK.g, INK.b, 0.4))
	mute.pressed.connect(_toggle_mute)
	box.add_child(mute)
	_music_value = _add_volume_row(box, "배경음악", AppSettings.load_music_volume(), _on_music_changed, Callable())
	_sfx_value = _add_volume_row(box, "효과음", AppSettings.load_sfx_volume(), _on_sfx_changed, _on_sfx_drag_ended)

## 화면(전체화면·연출 세기·화면 크기).
func _sec_screen(box: VBoxContainer) -> void:
	box.add_child(_page_heading("화면", 32, INK))
	box.add_child(UITheme.make_hairline(Color(INK.r, INK.g, INK.b, 0.35), 2.0))
	if not OS.has_feature("web"):
		var fs_on: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		var fs := UITheme.make_pill("창 화면으로" if fs_on else "전체 화면으로", INK, Color(0, 0, 0, 0),
			Color(INK.r, INK.g, INK.b, 0.4))
		fs.pressed.connect(_toggle_fullscreen)
		box.add_child(fs)
	_add_motion_row(box, AppSettings.load_motion())
	_add_scale_row(box, AppSettings.load_text_scale())

## 이야기(오프닝 다시보기·조작 안내 다시보기).
func _sec_story(box: VBoxContainer) -> void:
	box.add_child(_page_heading("이야기", 32, INK))
	box.add_child(UITheme.make_hairline(Color(INK.r, INK.g, INK.b, 0.35), 2.0))
	var replay := UITheme.make_pill("오프닝 다시보기", INK, Color(0, 0, 0, 0), Color(INK.r, INK.g, INK.b, 0.4))
	replay.pressed.connect(_replay_opening)
	box.add_child(replay)
	# 조작 안내 다시보기 — 튜토리얼이 실제로 뜨는 지도·단면 화면에서만.
	var cs_path: String = ""
	if get_tree().current_scene != null:
		cs_path = get_tree().current_scene.scene_file_path
	if cs_path == "res://scenes/map.tscn" or cs_path == "res://scenes/expedition.tscn":
		var tut := UITheme.make_pill("조작 안내 다시보기", INK, Color(0, 0, 0, 0), Color(INK.r, INK.g, INK.b, 0.4))
		tut.pressed.connect(_replay_tutorial)
		box.add_child(tut)

## 여정(타이틀로·게임 끝내기). 타이틀+웹처럼 나갈 것이 없으면 비운다.
func _sec_journey(box: VBoxContainer) -> void:
	var on_title: bool = get_tree().current_scene != null \
		and get_tree().current_scene.scene_file_path == "res://scenes/main.tscn"
	var show_title: bool = not on_title
	var show_quit: bool = not OS.has_feature("web")
	if not show_title and not show_quit:
		return
	box.add_child(_page_heading("여정", 32, INK))
	box.add_child(UITheme.make_hairline(Color(INK.r, INK.g, INK.b, 0.35), 2.0))
	if show_title:
		var to_title := UITheme.make_pill("타이틀로 나간다", INK, Color(0, 0, 0, 0), Color(INK.r, INK.g, INK.b, 0.4))
		to_title.pressed.connect(_on_leave_to_title)
		box.add_child(to_title)
	if show_quit:
		var quit := UITheme.make_pill("게임을 끝낸다", INK, Color(0, 0, 0, 0), Color(INK.r, INK.g, INK.b, 0.4))
		quit.pressed.connect(_on_quit_pressed)
		box.add_child(quit)

## 위험 구역(세계 지우기).
func _sec_danger(box: VBoxContainer) -> void:
	box.add_child(_page_heading("위험 구역", 32, RED))
	box.add_child(UITheme.make_hairline(Color(RED.r, RED.g, RED.b, 0.5), 2.0))
	box.add_child(_ink_label("저장된 이 세계를 지운다.\n원정과 흔적, 죽은 자리가 모두 사라지고\n처음부터 다시 시작한다.",
		UITheme.FS_SMALL, INK_FADE))
	var wipe := UITheme.make_pill("저장 데이터 지우기", RED, Color(0, 0, 0, 0), Color(RED.r, RED.g, RED.b, 0.55))
	wipe.pressed.connect(_confirm_wipe)
	box.add_child(wipe)

## 확인 페이지(공용) — 왼쪽: 경고·제목·설명, 오른쪽: 머문다/실행. 지우기·타이틀로·끝내기가 공유.
func _show_confirm_page(warn: String, title: String, desc: String, yes_txt: String, yes_cb: Callable) -> void:
	_in_confirm = true
	# 배치 재동기화 — 웹은 전체화면 진입·브라우저 바 리사이즈로 _box_r 크기가 낡을 수 있다.
	# 다른 챕터는 위 정렬이라 티가 안 나지만 이 페이지만 세로 중앙(EXPAND)이라 버튼이
	# 페이지 바닥(푸터 자리)까지 가라앉았다(2026-07-14 폰 웹 제보 — 재배치가 치유함을 CDP 재현으로 확인).
	_layout_book()
	AudioManager.play_sfx_random(PAGE_SFX)
	_clear(_box_l)
	_clear(_box_r)
	_clear(_footer_r)  # 확인 페이지는 넘김/덮기 없음(머문다/실행만)
	_box_l.add_child(_ink_label(warn, UITheme.FS_SMALL, RED))
	_box_l.add_child(_page_heading(title, 32, INK))
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
	_show_confirm_page("되돌릴 수 없다", "이 세계를 지울까",
		L10N.t("모래폭풍이 모든 원정과 흔적을 쓸어 간다.\n처음부터 다시 시작한다.\n원정 %d번 · 흔적 %d개가 사라진다.") % [GameState.expedition_count, GameState.traces.size()],
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
		_show_confirm_page("지금 원정은 돌아오지 못한다", "타이틀로 나갈까",
			"길 위의 원정대는 모래에 묻히고,\n세계의 기록만 남는다.", "나간다", _go_title)
	else:
		_go_title()

func _go_title() -> void:
	_close()
	GameState.go_to_title()

## 게임 끝내기(데스크톱만) — 한 번 묻고 종료. 세계(세이브)는 남는다.
func _on_quit_pressed() -> void:
	var desc: String = "세계의 기록은 남는다.\n다음에 이어서 원정을 보낼 수 있다."
	if GameState.current_run != null and GameState.current_run.alive:
		desc = "길 위의 원정대는 모래에 묻히고,\n세계의 기록만 남는다."
	_show_confirm_page("게임을 끝낸다", "여기서 덮을까", desc, "끝낸다",
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

## 연출 세기 슬라이더 — 0(즉시·모션 줄이기) .. 1(기본). AppSettings 저장, Transition·책넘김이 읽는다.
func _add_motion_row(box: VBoxContainer, cur: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := _ink_label("연출", UITheme.FS_LABEL, INK)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var value := _ink_label(_pct(cur), UITheme.FS_SMALL, INK_FADE)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(value)
	box.add_child(row)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = cur
	slider.custom_minimum_size = Vector2(0, UITheme.SLIDER_H)
	UITheme.style_slider(slider, INK)
	slider.value_changed.connect(func(v: float) -> void:
		AppSettings.set_motion(v)
		value.text = _pct(v))
	box.add_child(slider)

## 화면 크기 — UI 전체 배율(content_scale_factor, 0.85~1.2). 글자만이 아니라 전부 커져서
## 라벨도 "화면 크기"(2026-07-16 사용자 — "글자 크기"는 실체와 어긋남). 값 표시는 즉시, 창 적용은 손 뗄 때만
## (드래그 중 매 틱 재배치가 슬라이더 밑을 흔드는 것 방지). 적용은 call_deferred — 배율이 바뀌면
## 리사이즈 훅(_on_viewport_resized)이 이 페이지를 다시 짓는데, 시그널 핸들러 안에서
## 자기 슬라이더가 해제되면 안 된다(2026-07-15 재도전 — 내력은 AppSettings 헤더).
func _add_scale_row(box: VBoxContainer, cur: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := _ink_label("화면 크기", UITheme.FS_LABEL, INK)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var value := _ink_label(_pct(cur), UITheme.FS_SMALL, INK_FADE)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(value)
	box.add_child(row)
	var slider := HSlider.new()
	slider.min_value = AppSettings.TEXT_SCALE_MIN
	slider.max_value = AppSettings.TEXT_SCALE_MAX
	slider.step = 0.05
	slider.value = cur
	slider.custom_minimum_size = Vector2(0, UITheme.SLIDER_H)
	UITheme.style_slider(slider, INK)
	slider.value_changed.connect(func(v: float) -> void:
		value.text = _pct(v))
	slider.drag_ended.connect(func(changed: bool) -> void:
		if changed:
			AppSettings.set_text_scale(slider.value)
			_apply_text_scale.call_deferred())
	box.add_child(slider)

## 저장된 글자 배율을 창에 적용 — 배율 변경이 뷰포트 리사이즈 신호를 내고,
## 훅(_on_viewport_resized)이 열린 일지를 새 배율로 재배치·재렌더한다.
func _apply_text_scale() -> void:
	AppSettings.apply_text_scale(get_window())

## 조작 안내 다시보기 — 일지를 덮고 튜토리얼을 처음부터 재무장한다(지도·단면 화면에서 다시 뜬다).
func _replay_tutorial() -> void:
	_close()
	Tutorial.replay()


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
	AudioManager.refresh_music_volume()  # 웹 샘플 베드는 Music 버스 밖 — 직접 갱신해야 바로 들린다
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

## 덮기 버튼 — 오른쪽 페이지 바닥 고정 자리(_footer_r)에. box 인자는 호환용(무시).
func _add_close(_box: VBoxContainer) -> void:
	_clear(_footer_r)
	_footer_r.add_child(_ink_btn("일지를 덮는다", _close))

## 장 제목(명조) — 붓 폰트는 폐지(2026-07-19 사용자, 일지 제목의 붓글씨가 안 어울리고 싸 보임).
## 본문과 같은 명조(기본 폰트)를 크기만 키워 장을 연다.
func _page_heading(txt: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = L10N.t(txt)  # 로컬라이제이션 관문
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	return l

## 장부 한 줄 — 항목은 왼쪽 잉크, 값은 오른쪽 붉은 잉크 숫자.
func _ledger_row(name_txt: String, value_txt: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var nm := _ink_label(name_txt, UITheme.FS_LABEL, INK)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(nm)
	row.add_child(_page_heading(value_txt, 24, RED))
	return row

## 양피지 위 잉크 라벨.
func _ink_label(txt: String, fs: int, col: Color, center: bool = false) -> Label:
	return UITheme.make_label(txt, fs, col, center)

## 색 강조 잉크 글 — BBCode([color=...]) 지원 RichTextLabel. 중요한 단어에 색을 얹어
## 문단들이 똑같이 보이지 않게 한다(2026-07-12 사용자). 폰트·자간은 기본 테마를 따른다.
func _rich_label(bb: String, fs: int, col: Color) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_size_override("normal_font_size", fs)
	r.add_theme_color_override("default_color", col)
	r.text = L10N.t(bb)  # 로컬라이제이션 관문(BBCode 포함 원문 그대로 키)
	return r

## 잉크 각인 버튼 — 상자 없이 글자만, hover 시 붉은 잉크.
func _ink_btn(txt: String, cb: Callable, size: int = UITheme.FS_LABEL) -> Button:
	var b := Button.new()
	b.text = L10N.t(txt)  # 로컬라이제이션 관문
	b.flat = false
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", size)
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
				L10N.t("%d번째 원정 · %s\n    건너편에서 모두와 다시 만났다.") % [exp, nm],
				UITheme.FS_LABEL, RED)
		return _ink_label(
			L10N.t("%d번째 원정 · %s\n    끝에 닿았다. 다음 원정대가 이곳으로 온다.") % [exp, nm],
			UITheme.FS_LABEL, INK)
	# ② 스러진 원정 — 장소·거리·사인.
	var death: Dictionary = _death_of(exp)
	if not death.is_empty():
		var node_id: String = str(death.get("node_id", ""))
		var place: String = L10N.t(str(MapGraph.node(node_id).get("name", "")))
		if place == "":
			place = L10N.t("이름 모를 곳")
		var leg: int = int(death.get("leg", 0))
		return _ink_label(
			L10N.t("%d번째 원정 · %s\n    %s에서 %d걸음째 스러졌다.%s") % [exp, nm, place, leg, _cause_text(node_id)],
			UITheme.FS_LABEL, INK)
	# ③ 아직 길 위 — 지금 진행 중인 원정(살아 있음). 그 외(옛 세이브 등)는 지워진 기록.
	if exp == GameState.expedition_count and GameState.current_run != null and GameState.current_run.alive:
		return _ink_label(
			L10N.t("%d번째 원정 · %s\n    아직 길 위에 있다.") % [exp, nm],
			UITheme.FS_LABEL, INK_FADE)
	return _ink_label(
		L10N.t("%d번째 원정 · %s\n    기록이 모래에 지워졌다.") % [exp, nm],
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
			return L10N.t(" 갈증이었다.")
		if tg.has("없다"):
			return L10N.t(" 식량이 없었다.")
		return ""
	return ""

func _clear(box: VBoxContainer) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
