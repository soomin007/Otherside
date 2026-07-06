class_name UITheme
extends RefCounted

## 모바일 우선 UI 시스템 — 사이즈·색·레이아웃 헬퍼를 한 곳에.
##
## 체감 크기의 핵심: 논리 해상도(base)가 작아야 폰 세로에서 요소가 크게 보인다.
## stretch=canvas_items, aspect=expand 에서 "제약 축 = base 값"이다.
## 세로폰에선 가로가 제약 축 → 논리 가로폭 = base 가로폭(600). 그래서 600 으로 디자인하면
## 폰 세로 화면을 600 폭 캔버스로 보는 셈이라 글자·버튼이 충분히 크다(1280 이면 절반으로 줄어듦).
## 가로/데스크톱은 세로 base 가 제약 축이라 영향 없음.
##
## 레이아웃 원칙: 콘텐츠는 "중앙 정렬 + 최대폭 컬럼". 세로폰에선 거의 꽉 차고, 가로에선 가운데 카드처럼.

# --- 색 ---
# 디자인 핸드오프(design_handoff_expedition_ui) 팔레트 — 차가운 회청 → 따뜻한 가죽·아이보리로 통일.
const BG := Color(0.031, 0.027, 0.039)           ## 배경 무대(디자인 bg-black #08070A) — 전환 시 드러나는 검은 무대
const BG_TOP := Color(0.039, 0.027, 0.020)       ## 공통 배경 위 — 따뜻한 어둠(디자인 bg-deep #0a0705)
const BG_BOT := Color(0.165, 0.110, 0.063)       ## 공통 배경 지평선 부근 — 어스름 모래(디자인 bg-deep #2a1c10)
const SAND_FLOOR := Color(0.21, 0.165, 0.12)     ## 지평선 아래 모래 바닥
const HORIZON := Color(0.64, 0.5, 0.33, 0.55)    ## 지평선 hairline
const FG := Color(0.965, 0.925, 0.831)           ## 기본 밝은 글자 — 따뜻한 아이보리(디자인 ivory #F6ECD4)
const SAND := Color(0.839, 0.698, 0.471)         ## 모래색 — 강조(디자인 sand #D6B278)
const MUTED := Color(0.62, 0.62, 0.69)           ## 흐린 회색 — 보조 설명
const DANGER := Color(0.878, 0.420, 0.380)       ## 위험 — 초기화 등(디자인 danger #E06B61)
const PANEL := Color(0.141, 0.102, 0.067)        ## 카드·버튼 면 — 따뜻한 가죽(디자인 leather #241A11)
const LEATHER_HI := Color(0.180, 0.129, 0.078)   ## 가죽 패널 상단(디자인 leather-hi #2E2114) — 그라디언트 도입 시(현재 단색 StyleBox 라 예비)
const PANEL_BORDER := Color(0.549, 0.420, 0.239) ## 카드·버튼 테두리 — 가죽(디자인 leather-border #8C6B3D)
const SCRIM := Color(0.024, 0.020, 0.039, 0.66)  ## 모달 뒤 어둡게(디자인 스크림 rgba(6,5,10,.66))

# --- 고지도·양피지 팔레트 (지도·단면이 공유) ---
const PAPER := Color(0.82, 0.74, 0.57)       ## 빛바랜 양피지 바탕
const PAPER_EDGE := Color(0.58, 0.48, 0.32)  ## 가장자리(낡아 그을린)
const INK := Color(0.27, 0.19, 0.11)         ## 세피아 잉크 — 심볼·이름·테두리
const INK_FADE := Color(0.50, 0.41, 0.29)    ## 빛바랜 — 미방문·미지
const ROUTE := Color(0.38, 0.28, 0.16)       ## 밟은 길(트레일)
const MARKER_INK := Color(0.55, 0.20, 0.12)  ## 원정대 마커(붉은 세피아)

# --- 타입 스케일 (base 600 세로 기준, 폰에서 읽기 편한 크기) ---
const FS_DISPLAY: int = 42   ## 타이틀 로고
const FS_H1: int = 28        ## 화면 제목 / 상황 이름
const FS_H2: int = 23        ## 자원 수치 등 큰 강조
const FS_BODY: int = 22      ## 본문(읽는 텍스트) / 주요 버튼
const FS_LABEL: int = 18     ## 일반 라벨 / 보조 버튼
const FS_SMALL: int = 15     ## 보조 설명
const FS_TINY: int = 12      ## 지도 눈금 등 캔버스 미세 텍스트

# --- 붓 폰트 (나눔손글씨 붓) — 지도 내용(지명 등) 전용. UI 제목엔 안 쓴다(본문·제목은 명조). ---
const BRUSH_FONT: FontFile = preload("res://assets/fonts/NanumBrushScript-Regular.ttf")

# --- 터치 / 레이아웃 ---
const BTN_H: float = 76.0      ## 주요 버튼 높이
const BTN_H_SM: float = 60.0   ## 보조 버튼 높이
const SLIDER_H: float = 48.0   ## 슬라이더 두께
const COLUMN_W: float = 520.0  ## 콘텐츠 최대폭
const PAD: float = 32.0        ## 화면 가장자리 여백
const CARD_PAD: float = 28.0   ## 카드 안쪽 여백
const GAP: int = 18            ## 위젯 간격
const SAFE: float = 24.0       ## 노치/모서리 안전 여백

# --- 레이아웃 헬퍼 ---

## 화면 중앙의 최대폭 컬럼을 만들어 반환한다. 위젯을 여기에 쌓으면
## 세로폰에선 거의 꽉 차고 가로에선 가운데 정렬된다. 반환된 VBox 가 콘텐츠 컨테이너.
static func build_column(host: Control, gap: int = GAP) -> VBoxContainer:
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_set_margin(mc, int(PAD))
	host.add_child(mc)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	mc.add_child(cc)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", gap)
	col.custom_minimum_size = Vector2(COLUMN_W, 0)
	cc.add_child(col)
	return col

## 카드(둥근 패널 + 테두리 + 안쪽 여백). 모달 콘텐츠를 떠다니는 텍스트가 아니라 읽기 좋은 면 위에 둔다.
## ⚠️ 게임 화면 사용 금지(2026-07-06 각인 전수 전환) — 모달은 make_engraved_modal, 버튼은 make_engraved_button.
##    남겨둔 이유: 개발용 UI(DEV 오버레이류)나 임시 도구에서만.
static func make_card(width: float = COLUMN_W) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = PANEL_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(CARD_PAD)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(width, 0)
	return p

## ⚠️ 게임 화면 사용 금지(2026-07-06 각인 전수 전환) — make_engraved_button 사용. 개발용 UI 전용.
## 풀폭 버튼(터치 타깃 보장). primary=true 면 크고 본문 크기, false 면 낮고 라벨 크기.
static func make_button(text: String, primary: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, BTN_H if primary else BTN_H_SM)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", FS_BODY if primary else FS_LABEL)
	b.clip_text = true
	# 불투명 면·테두리 — 어두운 배경(Backdrop) 위에서 배경이 비쳐 흐릿해 보이는 걸 막는다.
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = PANEL_BORDER  # 가죽 테두리(디자인 leather-border #8C6B3D) — 버튼도 가죽 프레임으로 뚜렷하게
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	b.add_theme_stylebox_override("normal", sb)
	var hov: StyleBoxFlat = sb.duplicate()
	hov.bg_color = PANEL.lightened(0.06)
	hov.border_color = SAND
	b.add_theme_stylebox_override("hover", hov)
	var pr: StyleBoxFlat = sb.duplicate()
	pr.bg_color = PANEL.darkened(0.08)
	b.add_theme_stylebox_override("pressed", pr)
	var dis: StyleBoxFlat = sb.duplicate()
	dis.bg_color = Color(PANEL.r, PANEL.g, PANEL.b, 0.55)
	dis.border_color = Color(SAND.r, SAND.g, SAND.b, 0.14)
	b.add_theme_stylebox_override("disabled", dis)
	b.add_theme_color_override("font_color", FG)
	b.add_theme_color_override("font_disabled_color", Color(FG.r, FG.g, FG.b, 0.4))
	return b

## 자동 줄바꿈 라벨. 컬럼/카드 안에 넣으면 그 폭에서 줄바꿈된다.
static func make_label(text: String, size: int = FS_BODY, color: Color = FG, center: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", 8)  # 여러 줄 본문 줄간격 넉넉히(기본 3은 답답)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

# --- 전환 애니 (모래처럼 스스슥 — 툭 튀어나옴 없이) ---
const FADE_DUR: float = 0.4  ## 팝업·오버레이 페이드 기본 길이(초) — 체감되게 넉넉히

## 모달·오버레이가 스르륵 나타난다(투명도 0→1). visible 을 직접 켜지 말고 이걸 쓴다.
static func fade_in(node: CanvasItem, dur: float = FADE_DUR) -> void:
	_kill_fade(node)
	node.modulate.a = 0.0
	node.visible = true
	var tw: Tween = node.create_tween()
	tw.tween_property(node, "modulate:a", 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	node.set_meta("_fade_tw", tw)

## 모달이 스르륵 사라진다(투명도 1→0 후 hide). 끝나면 on_done 실행(닫힘 콜백/시그널을 여기 넘긴다).
static func fade_out(node: CanvasItem, on_done: Callable = Callable(), dur: float = FADE_DUR) -> void:
	_kill_fade(node)
	var tw: Tween = node.create_tween()
	tw.tween_property(node, "modulate:a", 0.0, dur * 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		node.visible = false
		node.modulate.a = 1.0
		if on_done.is_valid():
			on_done.call())
	node.set_meta("_fade_tw", tw)

## 각인 버튼(공용 축약) — 호버 시 모래 밑줄이 펴지는 텍스트 버튼. key=대표(밝은 글자·상시 밑줄).
## 게임 화면의 버튼 표준: 가죽 상자 버튼(make_button)은 쓰지 않는다(2026-07-06 전수 전환).
static func make_engraved_button(text: String, px: int = 18, key: bool = false) -> EngravedItem:
	var b := EngravedItem.new()
	b.init_item(text, px, key)
	return b

## 각인 모달 골격 — 가죽 카드(make_card) 대체: 방사 어둠 + 위아래 헤어라인. 스크림 위에 얹는다.
## 반환 [0]=바깥 박스(CenterContainer 에 add), [1]=내용 박스(여기에 채움 — 갈아끼워도 헤어라인은 남는다).
static func make_engraved_modal(width: float = COLUMN_W) -> Array:
	var outer := VBoxContainer.new()
	outer.custom_minimum_size = Vector2(width, 0)
	outer.add_theme_constant_override("separation", GAP)
	attach_dark_pool(outer)
	outer.add_child(make_hairline(Color(SAND.r, SAND.g, SAND.b, 0.35), 2.0))
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", GAP)
	outer.add_child(inner)
	outer.add_child(make_hairline(Color(SAND.r, SAND.g, SAND.b, 0.35), 2.0))
	return [outer, inner]

## 각인형 모달의 방사 어둠 뒷배경 — 상자(카드) 없이 뒤를 가라앉혀 글을 세운다
## (EngravedItem 항목 어둠·타이틀 로고 어둠과 같은 결 — 가장자리가 부드러워 상자로 안 읽힘).
## box 의 draw 에 연결해 자기 rect 보다 넓게 그린다(컨테이너 draw 는 자식보다 먼저 = 뒤에 깔림).
static func attach_dark_pool(box: Control, expand: float = 1.55, alpha: float = 0.85) -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([
		Color(0.0, 0.0, 0.0, 1.0),
		Color(0.0, 0.0, 0.0, 0.55),
		Color(0.0, 0.0, 0.0, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.98, 0.5)
	tex.width = 256
	tex.height = 128
	box.draw.connect(func() -> void:
		var w: float = box.size.x * expand
		var h: float = box.size.y * expand * 1.15
		box.draw_texture_rect(tex, Rect2((box.size.x - w) * 0.5, (box.size.y - h) * 0.5, w, h), false,
			Color(1.0, 1.0, 1.0, alpha)))
	box.queue_redraw()

## 모달 카드 재중앙 정렬 — 웹에서 간헐적으로 CenterContainer 가 낡은 레이아웃으로 카드를
## 하단에 앉히는 문제(2026-07-06 웹 데스크톱 제보 — 오토랩 라벨의 늦은 최소 높이 반영 레이스로 추정) 방어.
## 표시 직후 call_deferred 로 불러 카드 크기를 최소로 리셋하고 컨테이너를 다시 정렬시킨다(정상일 땐 무해).
static func recenter_modal(panel: Control) -> void:
	if panel == null or not panel.visible:
		return
	for c in panel.get_children():
		var cc := c as CenterContainer
		if cc == null:
			continue
		for ch in cc.get_children():
			var card := ch as Control
			if card != null:
				card.reset_size()
		cc.queue_sort()

## 같은 노드의 진행 중 페이드를 죽인다 — 겹쳐 뜨는 팝업에서 늦게 끝난 옛 fade_out 이
## 새로 연 팝업을 몰래 숨기는(visible=false) 경합 방지.
static func _kill_fade(node: CanvasItem) -> void:
	if not node.has_meta("_fade_tw"):
		return
	var old: Tween = node.get_meta("_fade_tw")
	if old != null and old.is_valid():
		old.kill()

## 모래 한 줌이 바람에 흩날린다 — 팝업이 뜰 때 카드 위로 뿌린다(CPUParticles2D, 웹 안전·one_shot).
## parent = 팝업 루트(Control). 화면 중앙에서 바람 방향(오른쪽 위)으로 날려 페이드아웃한다.
static func sand_puff(parent: Control) -> void:
	var vp: Vector2 = parent.get_viewport_rect().size
	var p := CPUParticles2D.new()
	p.amount = 44
	p.lifetime = 0.95
	p.one_shot = true
	p.explosiveness = 0.7
	p.position = vp * 0.5
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(vp.x * 0.3, vp.y * 0.2)
	p.direction = Vector2(1.0, -0.15)
	p.spread = 24.0
	p.gravity = Vector2(14.0, 10.0)
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 155.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.color = SAND
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	ramp.colors = PackedColorArray([
		Color(SAND.r, SAND.g, SAND.b, 0.0),
		Color(SAND.r, SAND.g, SAND.b, 0.85),
		Color(SAND.r, SAND.g, SAND.b, 0.0),
	])
	p.color_ramp = ramp
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

## 국소 모래 퍼프(핸드오프 puff) — 지정 지점에서 위쪽 반구로 분출 + 살짝 부양(ay<0).
## 물건 상호작용용: 배낭 담기(출발 9·도착 18), 남기기(그 물건이 모래로 흩어짐, 40).
static func sand_puff_at(parent: Node, gpos: Vector2, n: int) -> void:
	var p := CPUParticles2D.new()
	p.amount = n
	p.lifetime = 0.7
	p.lifetime_randomness = 0.5
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector2(0.0, -1.0)
	p.spread = 75.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 240.0
	p.gravity = Vector2(0.0, -70.0)  # 스펙 ay -0.02/frame ≈ -72px/s² (살짝 떠오름)
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.8
	p.color = SAND
	var ramp2 := Gradient.new()
	ramp2.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	ramp2.colors = PackedColorArray([
		Color(SAND.r, SAND.g, SAND.b, 0.0),
		Color(SAND.r, SAND.g, SAND.b, 0.9),
		Color(SAND.r, SAND.g, SAND.b, 0.0),
	])
	p.color_ramp = ramp2
	parent.add_child(p)
	p.global_position = gpos
	p.emitting = true
	p.finished.connect(p.queue_free)

## 햇빛 웅덩이 hover — 경계 없는 방사 글로우(둥근 상자 대신, 그 자리에 볕이 드는 느낌).
## Button 의 hover 스타일박스로 쓴다. StyleBoxTexture 가 버튼 rect 에 맞춰 늘어나 타원 글로우가 된다.
static func sun_glow_stylebox(alpha: float = 0.2) -> StyleBoxTexture:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([
		Color(SAND.r, SAND.g, SAND.b, alpha),
		Color(SAND.r, SAND.g, SAND.b, alpha * 0.42),
		Color(SAND.r, SAND.g, SAND.b, 0.0),
	])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.98, 0.5)
	gt.width = 128
	gt.height = 128
	var sb := StyleBoxTexture.new()
	sb.texture = gt
	return sb

static func _set_margin(mc: MarginContainer, v: int) -> void:
	for s in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + s, v)

# --- 선택지 라벨 (blind choice) ---
## 지도(이동 중 상황)·단면(도착 카드)이 공유. 결과를 미리 보여줄지(seen)·조건만 보여줄지(needs)를 한곳에서 정한다.

const RES_KO: Dictionary = {"water": "물", "food": "식량", "rope": "로프", "shelter": "은신처", "medicine": "약초", "flint": "부싯돌", "filter": "정화천"}

## 자원 델타를 읽기 쉬운 한 줄로 ("물 -2 · 식량 +1"). 빈 효과는 "그대로".
static func effect_hint(effect: Dictionary) -> String:
	if effect.is_empty():
		return "그대로"
	var parts: PackedStringArray = []
	for key in effect:
		var v: int = int(effect[key])
		var sign_str: String = "+" if v > 0 else ""
		parts.append("%s %s%d" % [str(RES_KO.get(key, key)), sign_str, v])
	return " · ".join(parts)

## needs(자원 게이트)를 짧게 ("로프", "물 3 · 식량 2"). 양이 1 이면 자원명만.
static func needs_bare(needs: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in needs:
		var v: int = int(needs[key])
		if v <= 1:
			parts.append(str(RES_KO.get(key, key)))
		else:
			parts.append("%s %d" % [str(RES_KO.get(key, key)), v])
	return " · ".join(parts)

## 선택지 버튼 텍스트 (blind choice — 가보기 전엔 결과를 모른다).
##  enabled=false → 자원 부족(needs 로 무엇이 모자란지 신호).
##  seen=true    → 이번 런에 눌러본 선택지 → 결과(effect)를 노출한다(학습).
##  seen=false + needs 있음 → 조건만 노출("로프 필요"). 가진 것이 있어야 고르므로 조건은 알아야 한다.
##  seen=false + needs 없음 → "?" — 눌러봐야 안다.
static func choice_text(choice: Dictionary, enabled: bool, seen: bool) -> String:
	var label: String = str(choice.get("label", ""))
	var needs: Dictionary = choice.get("needs", {})
	if not enabled:
		if needs.is_empty():
			return "%s   (자원 부족)" % label
		return "%s   (%s 부족)" % [label, needs_bare(needs)]
	if seen:
		return "%s   (%s)" % [label, effect_hint(choice.get("effect", {}))]
	if not needs.is_empty():
		return "%s   (%s 필요)" % [label, needs_bare(needs)]
	return "%s   (?)" % label

# --- 다듬기 헬퍼 (설정 등 정적 화면용) ---

## 얇은 가로 구분선(ColorRect) — 기본 HSeparator 대신 색·두께를 통제한다.
static func make_hairline(color: Color = Color(SAND.r, SAND.g, SAND.b, 0.18), thickness: float = 1.0) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, thickness)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r

## 면/테두리를 가진 버튼(pill) — 기본 회색 크롬 대신 의도된 모양. fill 을 투명하게 주면 외곽선 버튼.
static func make_pill(text: String, fg: Color, fill: Color, border: Color, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, BTN_H if primary else BTN_H_SM)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", FS_BODY if primary else FS_LABEL)
	b.clip_text = true
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg.r, fg.g, fg.b, 0.35))
	var solid: bool = fill.a > 0.05
	b.add_theme_stylebox_override("normal", _pill_sb(fill, border))
	b.add_theme_stylebox_override("hover", _pill_sb(
		fill.lightened(0.07) if solid else Color(border.r, border.g, border.b, 0.12),
		border.lightened(0.12)))
	b.add_theme_stylebox_override("pressed", _pill_sb(
		fill.darkened(0.10) if solid else Color(border.r, border.g, border.b, 0.20), border))
	b.add_theme_stylebox_override("disabled", _pill_sb(
		Color(fill.r, fill.g, fill.b, fill.a * 0.4), Color(border.r, border.g, border.b, border.a * 0.4)))
	b.add_theme_stylebox_override("focus", _pill_sb(Color(0, 0, 0, 0), SAND))
	return b

static func _pill_sb(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1 if border.a > 0.01 else 0)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(12)
	return sb

## 모래색 슬라이더 — 얇은 트랙 + 채움 + 모래알 그래버. 기본 밋밋한 슬라이더 대체.
## col 로 색을 바꿀 수 있다(설정 장부의 잉크 슬라이더 등). 기본은 모래색.
static func style_slider(s: HSlider, col: Color = SAND) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(col.r, col.g, col.b, 0.16)
	track.set_corner_radius_all(4)
	track.content_margin_top = 3.0
	track.content_margin_bottom = 3.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(4)
	fill.content_margin_top = 3.0
	fill.content_margin_bottom = 3.0
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var dot: ImageTexture = _grain_texture(22, col)
	s.add_theme_icon_override("grabber", dot)
	s.add_theme_icon_override("grabber_highlight", dot)

## 모래알(부드러운 원) 텍스처 — 셰이더 없이 절차적. 슬라이더 그래버 등.
static func _grain_texture(sz: int, col: Color) -> ImageTexture:
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var c: float = sz * 0.5
	for y in sz:
		for x in sz:
			var d: float = Vector2(x - c + 0.5, y - c + 0.5).length() / c
			var a: float = smoothstep(0.0, 1.0, clampf(1.0 - d, 0.0, 1.0) * 1.3)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)
