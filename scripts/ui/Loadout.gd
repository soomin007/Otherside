extends Control

## 마을 · 원정 준비 — 매 원정 출발 전. 두 단계로 나눈다:
##  1) 원정대를 꾸린다 — 이름 + 대장 특기(직능) + 챙길 도구 하나. (중앙 컬럼 폼)
##  2) 배낭을 챙긴다 — 창고 사진(39) 디에게틱: 찍혀 있는 물건에 각인 라벨, 탭하면 가방으로
##     포물선을 그리며 날아가 담긴다(합산 = 시작 자원). 핸드오프 §2/§19, 가로 창고 = 사용자 확정(2026-07-05).
## 첫 원정엔 시장 NPC(초상)가 규칙을 안내하고 기록지를 건넨다.

const BAG_SLOTS: int = 6
const PRESET: Array = ["water", "water", "food", "food", "rope", "shelter"]  ## 표준 구성 (아이템 정의는 core/Items.gd)

## 첫 원정 시장 인트로 — 규칙을 한 번 쭉 설명하고 마지막에 기록지를 건넨다(give_record). Opening 슬라이드식.
## ⚠ 대사 줄바꿈은 수동 \n — autowrap(WORD_SMART)은 한글을 음절 사이 아무 데서나 끊는다("이어지는/군").
##   의미 단위로 끊고 한 줄 ~26자 이내(COLUMN_W 520 · FS_BODY 기준, BBCode 태그는 셈에서 제외). 오프닝 SLIDES 와 같은 규칙.
## ⚠ 말투는 실제 사람(늙은 장사꾼)의 구어로 — 규칙서 낭독 금지, 시스템 용어(자원·릴레이 등) 입에 올리지 않기.
##   문장 성분을 생략하지 않는다("딱 질 만큼만 지게" 같은 목적어 빠진 말 금지 — 2026-07-17 사용자).
## 중요한 낱말은 [color=...] 강조 — 전부 모래색(SAND #D6B278) 한 가지만. 대사 안 여러 색(자원색 틴트)은
## 정신 사납다(2026-07-17 사용자). 색 구분은 창고 라벨·슬롯 점 몫, 대사는 단색 강조.
const MARKET_PAGES: Array = [
	"시장: 잘 왔네. 채비를 도와줌세.",
	"시장: 가방은 [color=#D6B278]여섯 칸[/color]뿐일세.\n[color=#D6B278]물[/color]하고 [color=#D6B278]먹을 것[/color]부터 챙기게. 그게 목숨이야.\n폭풍용 [color=#D6B278]장막[/color]과 [color=#D6B278]로프[/color]도\n분명 쓸 일이 있을 것이네.",
	"시장: 짐을 챙길 때는\n필요한 만큼만 챙기게.\n무거운 짐은 [color=#D6B278]물[/color]을 더 마시게 하거든.\n어깨가 가벼워야 오래 걷는 법이지.",
	"시장: 어디로 향할지는\n자네에게 달려 있네.\n먼 곳일수록 시간도 오래 걸리고,\n그만큼 [color=#D6B278]물[/color]과 [color=#D6B278]식량[/color]도 많이 필요하겠지.",
	"시장: 가다가 닿는 곳마다\n[color=#D6B278]두 군데[/color] 정도는 살펴볼 여유가 있을 걸세.\n그 시간 동안은 자유롭게 둘러보게.",
	"시장: 아, 그리고 원정이 끝나기 전에\n[color=#D6B278]딱 한 번, 물건 하나[/color]를 길에 남길 수 있네.\n자네가 끝내 닿지 못할 때를 대비해\n다음 원정대에게 전하는 걸세.\n무엇을 어디에 언제 둘지 잘 생각해 보게.",
	"시장: 이 기록지를 가져가게.\n떠난 이들의 이야기가 여기 적힐 걸세.\n화면 귀퉁이 [color=#D6B278]책갈피[/color]를 누르면 언제든 볼 수 있네.",
]

## 순환 엔딩을 볼 때마다 다음 마을에서 한 번 — 시장의 재회 옛말(사용자 확정: 반복 노출).
## 다른 결말의 존재와 방법(기림+구조+온전)을 사람 말로 암시한다. 숫자는 안 밝힘(돌파 난이도가 정서 튜닝, 기획서 §3).
## 게이트: cycle_arrival_count() > reunion_hints_shown (재회를 이미 봤으면 안 띄움).
const REUNION_HINT_PAGES: Array = [
	"시장: 끝에 닿았다 왔다지.\n그런데도 원정은 끝나질 않는군.",
	"시장: 옛말이 하나 있긴 하지.\n잠든 이들을 [color=#D6B278]기리고[/color], 뒤처진 이들을 [color=#D6B278]거두고[/color],\n[color=#D6B278]한 사람도 잃지 않고[/color] 닿은 원정만이\n밀어내지 않고 지나간다고.",
	"시장: 왠지 자네도 알 것 같네만.\n죽은 자리를 지나치지 말고,\n길에 웅크린 이가 보이거든 거두게.\n옛말이 다 헛말은 아닐 걸세.",
]

## 첫 원정 시장 인트로 — 오프닝 뒤 한 박자 뜸을 두고 서서히 나타난다(마을에 도착한 여운).
const MARKET_INTRO_DELAY: float = 1.3  ## 나타나기까지 뜸(초)
const MARKET_INTRO_FADE: float = 1.1   ## 페이드 인(초)

## 창고 사진(39) 속 물건들의 정규화 좌표(u — 원본 1680×944 기준 중심)와 히트 영역(w·h px).
## 사진에 찍힌 8종 전부 라벨·클릭 대상: 가방 물품 5종 + 주머니 도구 3종(pouch — 한 개만, 탭하면 교체).
## 버튼은 라벨 위로 길게 뻗어 "그림을 눌러도" 담긴다. 라벨 v 는 테이블 앞판(물건 바로 아래) 높이로 통일.
const PHOTO_ITEMS: Array = [
	{"key": "water",    "u": 0.101, "w": 140.0, "h": 250.0},
	{"key": "food",     "u": 0.259, "w": 140.0, "h": 250.0},
	{"key": "jerky",    "u": 0.372, "w": 140.0, "h": 250.0},
	{"key": "rope",     "u": 0.497, "w": 140.0, "h": 250.0, "delta": "험지 통과"},
	{"key": "shelter",  "u": 0.634, "w": 140.0, "h": 250.0, "delta": "폭풍 버팀"},
	{"key": "medicine", "u": 0.755, "w": 112.0, "h": 240.0, "pouch": true, "name": "약초", "delta": "열·탈진 다스림"},  # 약초 다발 그림이 커서 히트 영역도 넓게
	{"key": "flint",    "u": 0.835, "w": 88.0, "h": 160.0, "pouch": true, "delta": "언 밤의 불"},
	# 정화천 그림 실측 = 사진 px x1102~1268·y408~520 (폭 165). 폭을 그림에 맞추되 부싯돌 히트(우변 1113)와
	# 안 겹치게 중심을 살짝 오른쪽(0.930)으로 — 좌측 접힌 그림자 끝 ~10px 만 양보.
	{"key": "filter",   "u": 0.930, "w": 152.0, "h": 180.0, "pouch": true, "delta": "탁한 물 거름"},
]
const PHOTO_LABEL_V: float = 0.775   ## 라벨 세로 위치(사진 정규화) — 테이블 앞판

## 사진 라벨 이름의 자원색 틴트(밝은 판) — 슬롯 색 점(SLOT_CHIP)과 같은 색 언어.
const PHOTO_NAME_TINT: Dictionary = {
	"water": Color(0.62, 0.80, 0.90), "food": Color(0.90, 0.76, 0.48), "jerky": Color(0.85, 0.62, 0.38),
	"rope": Color(0.88, 0.78, 0.58), "shelter": Color(0.78, 0.82, 0.58),
	"medicine": Color(0.70, 0.86, 0.62), "flint": Color(0.80, 0.80, 0.84), "filter": Color(0.80, 0.72, 0.88),
}
const FLY_DUR: float = 0.42          ## 담기 비행 시간(스펙 420ms)
const FLY_APEX: float = 110.0        ## 포물선 정점 = 목표보다 이만큼 위(스펙)
const EN_TITLE_FONT := preload("res://assets/fonts/Cinzel.ttf")  ## 에이브로우 영문 전용

var _step: int = 1
var _step_root: Control            ## 단계 전체 루트 — _show_step 이 통째로 갈아끼운다(1=컬럼, 2=디에게틱)
var _col: VBoxContainer            ## 단계 1 콘텐츠 컨테이너(스크롤 안)

var _bag: Array = []               ## 담은 물품 key 배열(최대 BAG_SLOTS) — 단계 넘어 유지
var _bag_box: Container            ## step2 가방 슬롯 줄(담은 아이템이 여기 아이콘으로 들어간다)
var _preview: Label                ## step2 위젯
var _depart_btn: Button            ## step2 위젯
var _bg_tex: Texture2D             ## 창고 사진 — cover 매핑(라벨 좌표)에 필요
var _item_btns: Dictionary = {}    ## key -> {btn, delta(Label), base(String), pouch(bool)} — 담김 ×N·상태 갱신
var _count_n: Label                ## "가방 N / 6" 의 N (Cinzel 24 sand)
var _diegetic: Control             ## step2 사진 위 라벨 레이어(리사이즈 시 재배치)
var _pouch_box: Container          ## 주머니 도구 한 칸(가방 옆) — 창고에서 집은 도구가 들어온다
var _bag_row: HBoxContainer        ## 하단 가방 줄 전체(그림·카운트·슬롯·주머니) — _fit_bag_row 가 폭에 맞춰 줄인다
var _bl_box: HBoxContainer         ## 하단 좌 버튼 묶음(뒤로·기본 채비) — 가방 줄 가용 폭 계산용
var _slot_lock: bool = false       ## 빼기 바스러짐 동안 담기/빼기 잠금(재배열을 연출 뒤로 미루는 창)

var _pending_name: String = ""     ## 이번 원정대 이름 — 랜덤 초기값, 편집·다시 뽑기 가능
var _pending_vocation: String = "" ## 이번 대장의 직능 id (기본 "" = 평범)
var _voc_open: Array = []          ## 지금 고를 수 있는 직능 id(공훈 해금 순서) — 드롭다운 인덱스의 진실
var _pending_tool: String = ""     ## 주머니 도구 하나 (기본 "" = 없음). 가방 6칸과 별개
var _voc_desc: Label               ## step1 위젯 (직능 설명 갱신)
var _name_edit: LineEdit           ## step1 위젯
var _rng := RandomNumberGenerator.new()
var _market_panel: Control         ## 시장 대화 모달(있을 때만) — 첫 원정 인트로/첫 순환 후 옛말 공용
var _market_label: RichTextLabel   ## 대사 글 — 중요한 낱말 색 강조(BBCode)
var _market_idx: int = 0
var _market_pages: Array = []      ## 지금 흐름의 대사(MARKET_PAGES 또는 REUNION_HINT_PAGES)
var _market_flow: String = ""      ## "intro"(기록지 건네기) / "hint"(재회 옛말)
var _market_ready: bool = false    ## 페이드 인 완료 전엔 입력 무시(실수로 넘김 방지)
var _market_tw: Tween              ## 대사 사이 페이드(연타 시 킬)
var _feat_panel: Control           ## 공훈 연출 모달(있을 때만) — 새 얼굴/새 기록(시장 대화와 같은 각인 톤)
var _feat_queue: Array = []        ## 아직 안 보여준 "방금 달성" 공훈 id — 여러 건이면 한 장씩
var _feat_ready: bool = false      ## 페이드 인 완료 전 입력 무시(실수 닫힘 방지)

func _ready() -> void:
	_rng.randomize()
	AudioManager.set_wind(0.0)  # 마을 안(창고) = 무풍. 바람은 성문을 나서면(지도부터) 분다
	# 배경 — 마을 창고(램프 밝힌 준비 테이블, 가로 16:9 사진). 물건이 찍혀 있는 디에게틱 무대(핸드오프 §19, 사용자 확정).
	# 없으면 옛 가방 그림 → 절차적 마을 배경 순 fallback(웹 안전).
	var bg_path: String = ""
	for p in ["res://assets/arts/39_배경_창고_가로.png", "res://assets/arts/22_배경_가방.png"]:
		if ResourceLoader.exists(p):
			bg_path = p
			break
	if bg_path != "":
		_bg_tex = load(bg_path)
		var tr := TextureRect.new()
		tr.texture = _bg_tex
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # 화면 꽉 채우기(cover)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)
	else:
		var bg := Backdrop.new()  # fallback: 사막 밤 + 마을 실루엣
		bg.scene_kind = "village"
		add_child(bg)

	# 폭풍 막간(Interlude)이 지명한 이름이 있으면 그걸 초기값으로(연속성) — 없으면(첫 원정·디버그) 랜덤. 소비 후 비운다.
	if GameState.pending_expedition_name != "":
		_pending_name = GameState.pending_expedition_name
		GameState.pending_expedition_name = ""
	else:
		_pending_name = ExpeditionNamer.random(_rng)
	_bag = PRESET.duplicate()  # 처음엔 표준 구성(빠른 출발)
	resized.connect(_layout_photo_labels)  # 창 크기 변화 → 사진 라벨 재배치(단계 2 아닐 땐 no-op)
	_show_step(1)
	# 씬 등장 stagger(스펙 inScatter) — 컬럼 요소가 위에서부터 차례로 "모래가 모여 형체를 이루듯".
	# 진입 시 1회(단계 전환엔 없음 — 같은 화면의 재구성). 배경 사진·스크림 띠는 베일 페이드가 담당.
	var di: int = 0
	for c in _col.get_children():
		var ctrl := c as Control
		if ctrl == null:
			continue
		Transition.appear(ctrl, minf(0.02 + 0.04 * float(di), 0.30))
		di += 1

	# 방금 달성한 공훈 — 시장 대화가 없으면 바로, 있으면 대화가 끝난 뒤 연출(마을에 새 얼굴/새 기록).
	_feat_queue = GameState.take_feat_notices()
	# 첫 원정이면 시장이 규칙을 쭉 설명하고 기록지를 건넨다(책갈피가 켜진다).
	if GameState.expedition_count == 0 and not GameState.record_seen:
		_show_market_intro()
	elif GameState.cycle_arrival_count() > GameState.reunion_hints_shown and not GameState.has_arrival_of("reunion"):
		# 순환 엔딩을 볼 때마다 그다음 마을에서 한 번 — 시장이 재회의 옛말을 들려준다(이미 재회를 봤으면 불필요).
		_show_market_hint()
	elif not _feat_queue.is_empty():
		_show_feat_panel()

## 단계 전환 — 단계 루트를 통째로 갈아끼운다(1=중앙 컬럼, 2=창고 사진 디에게틱). _pending_* 은 멤버라 단계 넘어 유지된다.
func _show_step(n: int) -> void:
	_step = n
	_bag_box = null
	_preview = null
	_depart_btn = null
	_name_edit = null
	_voc_desc = null
	_count_n = null
	_diegetic = null
	_pouch_box = null
	_bag_row = null
	_bl_box = null
	_item_btns.clear()
	if _step_root != null:
		_step_root.queue_free()
	_step_root = Control.new()
	_step_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_step_root.add_to_group("ui_scatter")  # 전환 OUT 때 UI 층만 흩어짐(배경 사진은 남는다)
	add_child(_step_root)
	if n == 1:
		_build_step1()
	else:
		_build_step2()

## 절차적 초상(Figures) — 단계 상단에 얹는다.
func _portrait(kind: String, h: float) -> Figures:
	var fig := Figures.new()
	fig.kind = kind
	fig.custom_minimum_size = Vector2(0, h)
	fig.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return fig

# --- 단계 1: 원정대를 꾸린다 (중앙 컬럼 — 폼 위주라 컬럼이 낫다. 디에게틱은 단계 2) ---

func _build_step1() -> void:
	# UI 가독성 — 컬럼 뒤 어두운 세로 띠(사진 위 글씨 보호). 스크롤 아래.
	var band := ColorRect.new()
	band.color = Color(0.05, 0.05, 0.07, 0.95)
	band.anchor_left = 0.5
	band.anchor_right = 0.5
	band.anchor_top = 0.0
	band.anchor_bottom = 1.0
	band.offset_left = -(UITheme.COLUMN_W * 0.5 + UITheme.PAD)
	band.offset_right = UITheme.COLUMN_W * 0.5 + UITheme.PAD
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 클릭은 위 스크롤/버튼으로 통과
	_step_root.add_child(band)

	# 스크롤 컬럼 — 콘텐츠가 화면보다 길어도 아래 버튼까지 도달(중앙 최대폭). 휠은 부드럽게(SmoothScroll).
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(UITheme.PAD))
	_step_root.add_child(margin)
	var scroll := SmoothScroll.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER  # 막대 숨김(끌기·휠 스크롤은 유지) — 2026-07-12 사용자
	margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 14)
	_col.custom_minimum_size = Vector2(UITheme.COLUMN_W, 0)
	center.add_child(_col)

	_col.add_child(_portrait("leader", 150.0))
	_col.add_child(UITheme.make_label("원정대를 꾸린다", UITheme.FS_H1))
	_col.add_child(UITheme.make_label(_npc_line(), UITheme.FS_SMALL, UITheme.SAND))

	# 원정대 이름 — 랜덤 초기값 + 다시 뽑기 + 직접 입력(애착·서사).
	_col.add_child(_section_label("원정대 이름"))
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	_name_edit = LineEdit.new()
	_name_edit.text = _pending_name
	_name_edit.placeholder_text = "원정대 이름"
	_name_edit.custom_minimum_size = Vector2(0, UITheme.BTN_H_SM)
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.add_theme_font_size_override("font_size", UITheme.FS_LABEL)  # 혼자 크던 것 다른 라벨과 맞춤
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER  # 가운데 정렬
	_name_edit.text_changed.connect(_on_name_edited)
	_style_field(_name_edit)
	name_row.add_child(_name_edit)
	var reroll := UITheme.make_engraved_button("다시 뽑기", 14, false)
	reroll.custom_minimum_size = Vector2(160, UITheme.BTN_H_SM)
	reroll.pressed.connect(_reroll_name)
	name_row.add_child(reroll)
	_col.add_child(name_row)

	# 이번 대장의 특기(직능) — 공훈으로 마을에 온 이들만 후보(2026-07-11 사용자 확정: 직능 해금).
	# 첫 화면 인지 부하를 줄인다: 아무도 안 왔으면(평범뿐) 섹션 자체를 숨기고 평범한 대장으로 간다.
	# (챙길 도구는 배낭 화면의 창고에서 직접 집는다 — 사진에 찍힌 도구 3종.)
	_voc_open = GameState.unlocked_vocations()
	if not _voc_open.has(_pending_vocation):
		_pending_vocation = ""  # 잠긴 직능이 남아 있으면(옛 세이브 등) 평범으로
	if _voc_open.size() > 1:
		_col.add_child(_section_label("이번 대장의 특기"))
		var voc := OptionButton.new()
		voc.custom_minimum_size = Vector2(340, UITheme.BTN_H_SM)
		voc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # 컬럼 폭 다 채우지 말고 내용 폭 + 가운데(빈 공간 축소)
		for i in range(_voc_open.size()):
			voc.add_item(Vocations.name_of(str(_voc_open[i])))
			if str(_voc_open[i]) == _pending_vocation:
				voc.select(i)
		voc.item_selected.connect(_on_voc_selected)
		_style_select(voc)
		_col.add_child(voc)
		_voc_desc = UITheme.make_label(str(Vocations.by_id(_pending_vocation).get("desc", "")), UITheme.FS_SMALL, UITheme.SAND)
		_col.add_child(_voc_desc)

	var nxt := UITheme.make_engraved_button("배낭 챙기기 →", 20, true)
	nxt.pressed.connect(_show_step.bind(2))
	_col.add_child(nxt)
	# 웹 브라우저 주소창이 하단을 가려도 마지막 버튼까지 스크롤로 도달하도록 여유(전체화면 실패 대비).
	var tail := Control.new()
	tail.custom_minimum_size = Vector2(0, UITheme.SAFE * 2.5)
	_col.add_child(tail)

# --- 단계 2: 배낭을 챙긴다 (창고 디에게틱 — 사진 속 물건에 각인 라벨, 탭하면 가방으로 날아간다. 핸드오프 §2/§19) ---

func _build_step2() -> void:
	# 사진 위 글씨 가독성 — 상하단 그라디언트 스크림(README Legibility). 셰이더 금지라 GradientTexture2D.
	_step_root.add_child(_make_scrim(true))
	_step_root.add_child(_make_scrim(false))

	# 헤더 — 에이브로우(Cinzel 영문 전용) + 제목 + 부제.
	var head := VBoxContainer.new()
	head.set_anchors_preset(Control.PRESET_TOP_WIDE)
	head.offset_top = UITheme.SAFE
	head.add_theme_constant_override("separation", 3)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_step_root.add_child(head)
	var eye := UITheme.make_label("VILLAGE · LOADOUT", 11, Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.9))
	var efv := FontVariation.new()
	efv.base_font = EN_TITLE_FONT
	efv.set_spacing(TextServer.SPACING_GLYPH, 4)  # 스펙 .32em ≈ 11px*0.32
	eye.add_theme_font_override("font", efv)
	head.add_child(eye)
	var title := UITheme.make_label("배낭을 챙긴다", UITheme.FS_H1)
	_shadow(title)
	head.add_child(title)
	var sub := UITheme.make_label("가방은 여섯 칸. 담은 만큼이 이번 원정의 목숨이다.", UITheme.FS_SMALL, Color(0.788, 0.718, 0.565))
	_shadow(sub)
	head.add_child(sub)

	# 사진 속 물건 라벨 레이어 — cover 매핑으로 물건 바로 아래(테이블 앞판)에 각인. 리사이즈마다 재배치.
	_diegetic = Control.new()
	_diegetic.set_anchors_preset(Control.PRESET_FULL_RECT)
	_diegetic.mouse_filter = Control.MOUSE_FILTER_PASS
	_step_root.add_child(_diegetic)
	for it in PHOTO_ITEMS:
		var entry: Dictionary = it
		_diegetic.add_child(_make_photo_label(entry))

	# 하단 가방 줄 — 한 줄 컴팩트: 열린 가방 그림 + "가방 N / 6"(N=Cinzel) + 아이콘 슬롯 6칸(탭하면 뺀다).
	# 사진 라벨(테이블 앞판, y≈600까지)과 안 겹치게 낮고 얇게. 슬롯은 아이콘만(이름은 툴팁).
	# ⚠ CenterContainer 를 안 쓴다 — Container 는 재정렬(fit_child_in_rect)마다 자식 scale 을 1로
	# 리셋해 _fit_bag_row 의 배율 축소가 못 산다(2026-07-16). _step_root(평범한 Control) 직속으로 두고
	# 위치(옛 띠: 위 -128 · 아래 -34 의 중앙)·크기·스케일을 _fit_bag_row 가 직접 잡는다.
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 10)
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 빈 영역이 하단 버튼 클릭을 막지 않게(자식 버튼은 받음)
	_step_root.add_child(brow)
	_bag_row = brow
	var bag_art: String = "res://assets/arts/transparent/38_배경_열린가방.png"
	if ResourceLoader.exists(bag_art):
		var art := TextureRect.new()
		art.texture = load(bag_art)
		art.custom_minimum_size = Vector2(64, 64)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		brow.add_child(art)
	var mid := VBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 1)
	brow.add_child(mid)
	var crow := HBoxContainer.new()
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	crow.add_theme_constant_override("separation", 6)
	mid.add_child(crow)
	var c1 := UITheme.make_label("가방", UITheme.FS_SMALL, UITheme.MUTED)
	c1.autowrap_mode = TextServer.AUTOWRAP_OFF  # HBox 안에서 "가/방" 세로 줄바꿈 방지
	_shadow(c1)
	crow.add_child(c1)
	_count_n = UITheme.make_label(str(_bag.size()), 22, UITheme.SAND)  # 숫자만 Cinzel(스펙 — 한글 두부 방지, known_issues §42)
	_count_n.autowrap_mode = TextServer.AUTOWRAP_OFF
	_shadow(_count_n)
	var cfv := FontVariation.new()
	cfv.base_font = EN_TITLE_FONT
	_count_n.add_theme_font_override("font", cfv)
	crow.add_child(_count_n)
	var c2 := UITheme.make_label("/ %d" % BAG_SLOTS, UITheme.FS_SMALL, UITheme.MUTED)
	c2.autowrap_mode = TextServer.AUTOWRAP_OFF
	_shadow(c2)
	crow.add_child(c2)
	var hint := UITheme.make_label("담은 물건은 다시 눌러서 제거", 11, Color(UITheme.MUTED.r, UITheme.MUTED.g, UITheme.MUTED.b, 0.85))
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_shadow(hint)
	mid.add_child(hint)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(8, 0)
	brow.add_child(gap)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 5)
	brow.add_child(slots)
	_bag_box = slots
	# 주머니(도구 한 칸) — 가방 6칸과 별개. 창고에서 도구를 집으면 여기로 들어온다.
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(14, 0)
	brow.add_child(gap2)
	var pcol := VBoxContainer.new()
	pcol.alignment = BoxContainer.ALIGNMENT_CENTER
	pcol.add_theme_constant_override("separation", 1)
	brow.add_child(pcol)
	var plab := UITheme.make_label("주머니", 11, UITheme.MUTED)
	plab.autowrap_mode = TextServer.AUTOWRAP_OFF
	_shadow(plab)
	pcol.add_child(plab)
	_pouch_box = HBoxContainer.new()
	pcol.add_child(_pouch_box)

	# 자원 미리보기 — 담은 합계 한 줄(가방 줄 아래, 맨 밑).
	_preview = UITheme.make_label("", UITheme.FS_SMALL, UITheme.FG)
	_shadow(_preview)
	_preview.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_preview.offset_top = -32.0
	_preview.offset_bottom = -8.0
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_step_root.add_child(_preview)

	# 하단 좌 — 뒤로·표준 구성(각인형). 하단 우 — 떠난다(대표). 나중에 add = 위에 그려져 클릭 우선.
	var bl := HBoxContainer.new()
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.offset_left = 8.0
	bl.offset_top = -76.0
	bl.offset_bottom = -8.0
	_step_root.add_child(bl)
	_bl_box = bl
	var back := EngravedItem.new()
	back.init_item("← 뒤로", 16, false)
	back.pressed.connect(_show_step.bind(1))
	bl.add_child(back)
	var preset_btn := EngravedItem.new()
	preset_btn.init_item("기본 채비", 16, false)
	preset_btn.pressed.connect(_apply_preset)
	bl.add_child(preset_btn)
	var depart := EngravedItem.new()
	depart.init_item("떠난다", 22, true)
	depart.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	depart.offset_left = -226.0
	depart.offset_top = -84.0
	depart.offset_right = -10.0
	depart.offset_bottom = -8.0
	depart.pressed.connect(_depart)
	_step_root.add_child(depart)
	_depart_btn = depart

	_refresh()
	call_deferred("_layout_photo_labels")  # 첫 프레임엔 size 미확정 — 레이아웃 후 배치

## 시장 NPC 한 마디 — 첫 원정이면 규칙 안내, 이후엔 짧게.
func _npc_line() -> String:
	if GameState.expedition_count == 0:
		return "시장: 무엇을 지고, 누가 이끌지 정하게.\n물과 식량이 곧 목숨일세."
	return "시장: 또 떠나는군. 부디 조심히 가게."

func _add_item(key: String) -> void:
	if _bag.size() >= BAG_SLOTS:
		return
	_bag.append(key)
	_refresh()

## 가방에서 빼기 — 그 자리에서 물건이 모래로 바스러진 *뒤에* 뒤 칸들이 앞으로 당겨진다(사용자 지적:
## 즉시 재배열되면 바스러짐이 어색). 연출 동안 담기/빼기를 잠깐 잠근다(_slot_lock, 0.45s).
func _remove_slot(idx: int, slot: Control) -> void:
	if _slot_lock or idx < 0 or idx >= _bag.size():
		return
	_slot_lock = true
	var key: String = str(_bag[idx])
	_bag.remove_at(idx)
	slot.modulate.a = 0.0  # 원본 칸은 즉시 숨김 — 같은 자리에서 고스트가 바스러진다(이중상 방지)
	_refresh_meta()        # 수치·라벨은 즉시 갱신, 슬롯 재배열만 연출 뒤로
	_crumble_at(key, slot.get_global_rect().get_center(), _after_slot_crumble)

func _after_slot_crumble() -> void:
	_slot_lock = false
	_refresh()  # 이제 뒤 칸들이 앞으로 당겨진다

## 바스러짐 연출 — 아이콘 잔상이 커지며 모래 퍼프와 함께 흩어진다. 끝나면 on_done.
func _crumble_at(key: String, gpos: Vector2, on_done: Callable = Callable()) -> void:
	var ghost := ItemIcon.new()
	ghost.key = key
	ghost.size = Vector2(52, 52)
	ghost.pivot_offset = ghost.size * 0.5
	ghost.z_index = 50
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ghost)
	ghost.global_position = gpos - ghost.size * 0.5
	UITheme.sand_puff_at(self, gpos, 14)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(ghost, "scale", Vector2(1.35, 1.35), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(ghost, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var tail := t.chain()
	tail.tween_callback(ghost.queue_free)
	if on_done.is_valid():
		tail.tween_callback(on_done)

func _apply_preset() -> void:
	if _slot_lock:
		return
	_bag = PRESET.duplicate()
	_refresh()

func _refresh() -> void:
	if _bag_box == null:
		return  # 단계 1 에선 가방 UI 가 없다 (핸들러가 안전하게 no-op)
	for c in _bag_box.get_children():
		_bag_box.remove_child(c)
		c.queue_free()
	for i in range(_bag.size()):
		_bag_box.add_child(_make_slot_filled(i, str(_bag[i])))
	for i in range(BAG_SLOTS - _bag.size()):
		_bag_box.add_child(_make_slot_empty())

	# 주머니 칸 — 집은 도구(탭하면 되돌림) 또는 빈칸.
	if _pouch_box != null:
		for c in _pouch_box.get_children():
			_pouch_box.remove_child(c)
			c.queue_free()
		if _pending_tool != "":
			_pouch_box.add_child(_make_pouch_slot(_pending_tool))
		else:
			_pouch_box.add_child(_make_slot_empty())

	_refresh_meta()

## 수치·라벨 상태만 갱신(슬롯 재배열 없이) — 빼기 바스러짐 동안에도 즉시 반영되는 부분.
func _refresh_meta() -> void:
	if _preview == null:
		return
	var res: Dictionary = _bag_resources()
	var wgt: int = Items.bag_weight(_bag)  # 주머니 도구는 무게에서 뺀다(가방 6칸과 별개 보험 슬롯 — 절벽 방지)
	var pen: int = maxi(0, wgt - ExpeditionRun.WEIGHT_FREE) / maxi(1, ExpeditionRun.WEIGHT_STEP)
	var pen_str: String = "  · 짐이 무거워 걸음마다 물 +%d" % pen if pen > 0 else ""
	_preview.text = "물 %d · 식량 %d · %s · 무게 %d%s" % [
		int(res["water"]), int(res["food"]), Items.tools_summary(res), wgt, pen_str]
	if _count_n != null:
		_count_n.text = str(_bag.size())
	# 사진 라벨 상태 — 설명 글은 고정(담을 때 글이 바뀌는 게 어색 — 2026-07-12 사용자, 담긴 수는
	# 가방 슬롯이 보여준다). 가방이 차면 흐리게+잠금만.
	var full: bool = _bag.size() >= BAG_SLOTS
	for key in _item_btns:
		var info: Dictionary = _item_btns[key]
		var btn: Button = info["btn"]
		var dl: Label = info["delta"]
		dl.text = str(info["base"])
		if bool(info.get("pouch", false)):
			btn.disabled = false
			btn.modulate.a = 1.0
		else:
			btn.disabled = full
			btn.modulate.a = 0.42 if full else 1.0
	if _depart_btn != null:
		_depart_btn.disabled = int(res["water"]) <= 0 and int(res["food"]) <= 0
		_depart_btn.modulate.a = 0.35 if _depart_btn.disabled else 1.0

# --- 가방 슬롯 (담은 아이템 = 아이콘, 빈칸 = 움푹한 자리) ---

## 담긴 칸 — 아이템 아이콘만(하단 한 줄 컴팩트 — 이름은 툴팁). 탭하면 뺀다.
func _make_slot_filled(idx: int, key: String) -> Control:
	var slot := Button.new()
	slot.custom_minimum_size = Vector2(76, 76)
	slot.add_theme_stylebox_override("normal", _slot_stylebox(true))
	slot.add_theme_stylebox_override("hover", _slot_stylebox(true))
	slot.add_theme_stylebox_override("pressed", _slot_stylebox(true))
	slot.add_theme_stylebox_override("focus", _slot_stylebox(true))
	slot.tooltip_text = "%s  (다시 눌러서 제거)" % Items.label_of(key)
	slot.pressed.connect(_remove_slot.bind(idx, slot))
	slot.add_child(_slot_icon(key))
	return slot

## 주머니 칸 — 집은 도구 아이콘. 탭하면 창고로 되돌린다(주머니 비움).
func _make_pouch_slot(key: String) -> Control:
	var slot := Button.new()
	slot.custom_minimum_size = Vector2(76, 76)
	slot.add_theme_stylebox_override("normal", _slot_stylebox(true))
	slot.add_theme_stylebox_override("hover", _slot_stylebox(true))
	slot.add_theme_stylebox_override("pressed", _slot_stylebox(true))
	slot.add_theme_stylebox_override("focus", _slot_stylebox(true))
	slot.tooltip_text = "%s  (다시 눌러서 제거)" % Items.label_of(key)
	slot.pressed.connect(_clear_pouch_from.bind(slot))
	slot.add_child(_slot_icon(key))
	return slot

## 슬롯 색 점 — 세피아 톤이 다 비슷해 물통/자루가 안 갈리던 것을 색으로 가른다(2026-07-12 사용자).
## 색은 지도 흔적 점(물=청록·식량=황토·장막=올리브)과 같은 언어.
const SLOT_CHIP: Dictionary = {
	"water": Color(0.33, 0.58, 0.70), "food": Color(0.76, 0.55, 0.22), "jerky": Color(0.66, 0.42, 0.20),
	"rope": Color(0.80, 0.68, 0.44), "shelter": Color(0.58, 0.64, 0.36),
	"medicine": Color(0.52, 0.66, 0.42), "flint": Color(0.62, 0.62, 0.66), "filter": Color(0.63, 0.52, 0.70),
}

class SlotChip extends Control:
	var chip: Color = Color.WHITE
	func _draw() -> void:
		var c: Vector2 = size * 0.5
		draw_circle(c, size.x * 0.5, Color(0.12, 0.09, 0.06, 0.9))
		draw_circle(c, size.x * 0.5 - 1.6, chip)

## 슬롯 안 아이템 아이콘 — 가죽 틀 안감 안쪽으로 물러난다(꽉 채우면 칸보다 커 보임 — 2026-07-12 사용자)
## + 오른아래 자원색 점(한눈에 무엇이 담겼는지).
func _slot_icon(key: String) -> Control:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := ItemIcon.new()
	icon.key = key
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 13.0
	icon.offset_top = 13.0
	icon.offset_right = -13.0
	icon.offset_bottom = -13.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(icon)
	var chip := SlotChip.new()
	chip.chip = SLOT_CHIP.get(key, Color(0.7, 0.7, 0.7))
	chip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	chip.offset_left = -25.0
	chip.offset_top = -25.0
	chip.offset_right = -11.0
	chip.offset_bottom = -11.0
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(chip)
	return holder

## 주머니 비우기 — 도구가 그 자리에서 모래로 바스러진 뒤 칸이 빈다(가방 빼기와 같은 흐름).
func _clear_pouch_from(slot: Control) -> void:
	if _slot_lock or _pending_tool == "":
		return
	_slot_lock = true
	var key: String = _pending_tool
	_pending_tool = ""
	slot.modulate.a = 0.0
	_refresh_meta()
	_crumble_at(key, slot.get_global_rect().get_center(), _after_slot_crumble)

## 빈칸 — 움푹한 자리(안 눌림).
func _make_slot_empty() -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(76, 76)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override("panel", _slot_stylebox(false))
	return slot

## 슬롯 칸 — 가죽 틀 텍스처(킷 70/71: 담김=밝은 안감, 빈칸=움푹 어둠). 없으면 StyleBoxFlat fallback.
func _slot_stylebox(filled: bool) -> StyleBox:
	var path: String = "res://assets/arts/transparent/70_소품_슬롯담김.png" if filled \
		else "res://assets/arts/transparent/71_소품_슬롯빈.png"
	if ResourceLoader.exists(path):
		var tb := StyleBoxTexture.new()
		tb.texture = load(path)   # Godot 리소스 캐시가 중복 로드를 막는다
		tb.set_content_margin_all(9)
		return tb
	var sb := StyleBoxFlat.new()
	if filled:
		sb.bg_color = Color(0.24, 0.18, 0.11, 0.82)  # 담긴 칸(배낭이 살짝 비치게)
		sb.border_color = Color(0.60, 0.45, 0.26)
	else:
		sb.bg_color = Color(0.09, 0.07, 0.05, 0.45)   # 빈칸(더 비침)
		sb.border_color = Color(0.34, 0.27, 0.18, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(4)
	return sb

# --- 창고 사진 라벨 + 가방으로 날아가는 담기 (핸드오프 §2 인터랙션) ---

## 사진 물건 각인 라벨 — 이름(ivory) + 델타(sand). 버튼이 물건 그림까지 덮어 그림을 눌러도 담긴다.
## hover 시 물건 전체를 감싸는 아주 옅은 모래빛(스펙 라벨 배경의 확장). 텍스트는 버튼 하단(테이블 앞판)에 붙는다.
## 게임은 같은 물건을 여러 개 담을 수 있어(표준 구성 = 물통×2·식량×2) 스펙의 "담김 1회" 대신 ×N 표기를 쓴다.
func _make_photo_label(entry: Dictionary) -> Control:
	var key: String = str(entry.get("key", ""))
	var item: Dictionary = Items.by_key(key)
	var pouch: bool = bool(entry.get("pouch", false))
	var btn := Button.new()
	# flat=true 는 스타일박스 장식을 아예 안 그린다(hover 모래빛이 안 보이던 원인) —
	# flat 끄고 normal 을 빈 스타일박스로: 외형은 같고 hover 만 그려진다.
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.custom_minimum_size = Vector2(float(entry.get("w", 140.0)), float(entry.get("h", 250.0)))
	btn.size = btn.custom_minimum_size  # 컨테이너 밖 절대 배치 — size 직접 확정(정렬 계산용)
	btn.tooltip_text = str(item.get("desc", ""))
	var emp := StyleBoxEmpty.new()
	for st in ["normal", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(st, emp)
	# hover = 햇빛 웅덩이 — 경계 없는 방사 글로우(네모 상자는 각인 미학과 어긋남).
	btn.add_theme_stylebox_override("hover", UITheme.sun_glow_stylebox(0.24))
	btn.pressed.connect(_pick_item.bind(key, btn))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_bottom = -6.0
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_END  # 텍스트는 하단(테이블 앞판) — 위는 그림 히트 영역
	v.add_theme_constant_override("separation", 0)
	# 이름 라벨 = 자원색 틴트(밝은 판) — 어두운 사진 위에서 물/식량/도구가 색으로 갈린다(2026-07-12 사용자).
	var tint: Color = PHOTO_NAME_TINT.get(key, UITheme.FG)
	var nm := UITheme.make_label(str(entry.get("name", item.get("label", ""))), 18 if pouch else 20, tint)
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF  # 좁은 버튼에서 세로 줄바꿈 방지(넘치면 좌우로 삐져나옴 — 한 줄 유지)
	_shadow(nm)
	v.add_child(nm)
	var base: String = str(entry.get("delta", UITheme.effect_hint(item.get("start", {}))))
	var dl := UITheme.make_label(base, 12 if pouch else 13, UITheme.SAND)
	dl.autowrap_mode = TextServer.AUTOWRAP_OFF
	_shadow(dl)
	v.add_child(dl)
	btn.add_child(v)
	# hover — 이름이 모래빛으로(배경 틴트만으론 약했음).
	btn.mouse_entered.connect(_hover_label.bind(key, true))
	btn.mouse_exited.connect(_hover_label.bind(key, false))
	_item_btns[key] = {"btn": btn, "delta": dl, "name": nm, "base": base, "pouch": pouch}
	return btn

## 라벨 hover — 이름 모래빛 점등(잠긴 라벨은 무시).
func _hover_label(key: String, on: bool) -> void:
	if not _item_btns.has(key):
		return
	var info: Dictionary = _item_btns[key]
	var btn: Button = info["btn"]
	if btn.disabled:
		return
	var nm: Label = info["name"]
	nm.add_theme_color_override("font_color", UITheme.SAND if on else Color(PHOTO_NAME_TINT.get(key, UITheme.FG)))

## 사진 라벨 재배치 — 배경 cover(화면 채움·넘침 크롭) 매핑으로 사진 좌표(u,v)→화면 px. 단계 2 아닐 땐 no-op.
func _layout_photo_labels() -> void:
	if _diegetic == null:
		return
	var r: Rect2 = _photo_rect()
	for it in PHOTO_ITEMS:
		var entry: Dictionary = it
		var key: String = str(entry.get("key", ""))
		if not _item_btns.has(key):
			continue
		var info: Dictionary = _item_btns[key]
		var btn: Control = info["btn"]
		var c: Vector2 = r.position + Vector2(float(entry.get("u", 0.5)), PHOTO_LABEL_V) * r.size
		# 가방 줄(하단 128px 띠)이 라벨을 덮지 않게 위로 민다(2026-07-12 사용자 — 슬롯 확대 후 겹침).
		c.y = minf(c.y, size.y - 158.0)
		# 텍스트 블록(버튼 하단)이 사진 좌표 c 에 오도록 — 버튼 몸통은 위로 뻗어 물건 그림을 덮는다.
		btn.position = Vector2(c.x - btn.size.x * 0.5, c.y + 30.0 - btn.size.y)
	_fit_bag_row()

## 하단 가방 줄을 좌(뒤로·기본 채비)·우(떠난다) 사이 폭에 맞춘다 — 화면 배율 >100% 로 논리 뷰포트가
## 좁아지면(120% 데스크톱 = 1067px) 중앙 줄이 양끝 버튼을 침범하던 것(2026-07-16 사용자 제보).
## 컨테이너 배치는 무스케일 크기 기준이라, pivot 을 가운데 두고 시각 스케일만 줄인다(중앙 유지·입력 정상).
func _fit_bag_row() -> void:
	if _bag_row == null or _bl_box == null or _depart_btn == null:
		return
	var need: Vector2 = _bag_row.get_combined_minimum_size()
	if need.x <= 0.0:
		return
	# 가용 폭 = 떠난다 왼쪽 끝(size.x-226) − 좌 묶음 오른쪽 끝(8+폭) − 양쪽 숨통 20.
	var avail: float = (size.x - 226.0) - (8.0 + _bl_box.get_combined_minimum_size().x) - 20.0
	var sc: float = clampf(avail / need.x, 0.7, 1.0)
	_bag_row.size = need
	_bag_row.pivot_offset = need * 0.5
	_bag_row.scale = Vector2(sc, sc)
	# 옛 CenterContainer 띠(위 -128 · 아래 -34)의 중앙(size.y-81)에, 가로는 화면 중앙에 앉힌다.
	_bag_row.position = Vector2(size.x * 0.5, size.y - 81.0) - need * 0.5

## 배경 사진이 cover 로 그려지는 rect(화면을 채우고 넘침은 크롭) — 라벨 좌표 매핑의 기준.
func _photo_rect() -> Rect2:
	var tw: float = 1680.0
	var th: float = 944.0
	if _bg_tex != null:
		tw = float(_bg_tex.get_width())
		th = float(_bg_tex.get_height())
	var sc: float = maxf(size.x / tw, size.y / th)
	var drawn: Vector2 = Vector2(tw, th) * sc
	return Rect2((size - drawn) * 0.5, drawn)

## 상/하단 그라디언트 스크림 — 사진 위 글씨 가독성(README Legibility). GradientTexture2D = 웹 안전.
func _make_scrim(top: bool) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	if top:
		g.colors = PackedColorArray([Color(0.0, 0.0, 0.0, 0.66), Color(0.0, 0.0, 0.0, 0.0)])
	else:
		g.colors = PackedColorArray([Color(0.0, 0.0, 0.0, 0.0), Color(0.035, 0.024, 0.016, 0.8)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.0, 0.0)
	gt.fill_to = Vector2(0.0, 1.0)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if top:
		tr.set_anchors_preset(Control.PRESET_TOP_WIDE)
		tr.offset_bottom = 140.0
	else:
		tr.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		tr.offset_top = -240.0
	return tr

## 라벨/헤더 그림자 — 밝은 사진 위 글씨 필수 그림자(README).
func _shadow(lbl: Label) -> void:
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.add_theme_constant_override("shadow_outline_size", 5)

## 사진 라벨(또는 그림)을 탭 — 그 물건이 가방 빈 칸(도구는 주머니)으로 포물선을 그리며 날아가 담긴다.
func _pick_item(key: String, from: Control) -> void:
	if _slot_lock:
		return  # 빼기 바스러짐 중 — 슬롯 배열이 잠깐 잠겨 있다(0.45s)
	if key in Items.POUCH_TOOLS:
		_pick_pouch(key, from)
		return
	if _bag.size() >= BAG_SLOTS:
		return
	AudioManager.play_sfx("res://assets/sfx/sfx_bag_add.wav")
	var fly := ItemIcon.new()
	fly.key = key
	fly.size = Vector2(64, 64)
	fly.pivot_offset = fly.size * 0.5
	fly.z_index = 50
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fly)
	var start: Vector2 = from.get_global_rect().get_center()
	var target: Vector2 = start
	var idx: int = _bag.size()  # 다음 빈 칸(담긴 칸 뒤에 빈 칸이 온다)
	if _bag_box != null and idx < _bag_box.get_child_count():
		target = (_bag_box.get_child(idx) as Control).get_global_rect().get_center()
	fly.global_position = start - fly.size * 0.5
	UITheme.sand_puff_at(self, start, 9)  # 출발 작은 퍼프(스펙 9입자)
	var t := create_tween()
	t.tween_method(_fly_step.bind(fly, start, target), 0.0, 1.0, FLY_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(_finish_pick.bind(key, fly, target))

## 비행 보간(스펙 키프레임) — 55% 정점(목표 위 110px·scale .72·rot -10°) → 끝(scale .22·rot -22°·투명 .1).
func _fly_step(t: float, fly: Control, a: Vector2, b: Vector2) -> void:
	if not is_instance_valid(fly):
		return
	var x: float = lerpf(a.x, b.x, t)
	var apex: float = b.y - FLY_APEX
	var y: float
	var s: float
	var rot: float
	var al: float = 1.0
	if t < 0.55:
		var u: float = t / 0.55
		y = lerpf(a.y, apex, u)
		s = lerpf(1.0, 0.72, u)
		rot = lerpf(0.0, -10.0, u)
	else:
		var u: float = (t - 0.55) / 0.45
		y = lerpf(apex, b.y, u)
		s = lerpf(0.72, 0.22, u)
		rot = lerpf(-10.0, -22.0, u)
		al = lerpf(1.0, 0.1, u)
	fly.global_position = Vector2(x, y) - fly.size * 0.5
	fly.scale = Vector2(s, s)
	fly.rotation_degrees = rot
	fly.modulate.a = al

## 비행 끝 — 도착 큰 퍼프(스펙 18입자), 날던 아이콘을 치우고 실제로 가방에 담는다.
func _finish_pick(key: String, fly: Control, target: Vector2) -> void:
	if is_instance_valid(fly):
		fly.queue_free()
	UITheme.sand_puff_at(self, target, 18)
	_add_item(key)

## 주머니 도구를 집음 — 주머니 칸(한 개)으로 날아간다. 이미 다른 도구가 있으면 교체(이전 것은 창고로).
func _pick_pouch(key: String, from: Control) -> void:
	if _pending_tool == key:
		return  # 이미 주머니에 있음
	AudioManager.play_sfx("res://assets/sfx/sfx_bag_add.wav")
	var fly := ItemIcon.new()
	fly.key = key
	fly.size = Vector2(64, 64)
	fly.pivot_offset = fly.size * 0.5
	fly.z_index = 50
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fly)
	var start: Vector2 = from.get_global_rect().get_center()
	var target: Vector2 = start
	if _pouch_box != null and _pouch_box.get_child_count() > 0:
		target = (_pouch_box.get_child(0) as Control).get_global_rect().get_center()
	fly.global_position = start - fly.size * 0.5
	UITheme.sand_puff_at(self, start, 9)
	var t := create_tween()
	t.tween_method(_fly_step.bind(fly, start, target), 0.0, 1.0, FLY_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(_finish_pouch.bind(key, fly, target))

func _finish_pouch(key: String, fly: Control, target: Vector2) -> void:
	if is_instance_valid(fly):
		fly.queue_free()
	UITheme.sand_puff_at(self, target, 18)
	_pending_tool = key
	_refresh()

## 가방 물품 합산 → 시작 자원(core/Items.gd 카탈로그의 start 델타 합).
func _bag_resources() -> Dictionary:
	var res: Dictionary = Items.resources_of(_bag)
	if _pending_tool != "":
		res[_pending_tool] = int(res.get(_pending_tool, 0)) + 1  # 주머니 도구 하나(가방 칸 밖)
	return res

func _depart() -> void:
	var wgt: int = Items.bag_weight(_bag)  # 주머니 도구는 무게 미포함(보험 슬롯 — 표준 가방 15가 무료 상한에 붙어 도구 하나로 절벽 넘던 함정 방지)
	GameState.begin_run_with(_bag_resources(), _pending_name.strip_edges(), _pending_vocation, wgt)
	# 첫 원정만 — 마을 단면 탐색 연습(안전·무보상)을 거쳐 지도로. 이후엔 곧장 지도.
	if not GameState.village_intro_seen:
		GameState.go_to_village_intro()
	else:
		GameState.go_to_map()

# --- 원정대 이름 / 직능 / 도구 (단계 1 핸들러) ---

func _on_name_edited(text: String) -> void:
	_pending_name = text

func _reroll_name() -> void:
	_pending_name = ExpeditionNamer.random(_rng)
	if _name_edit != null:
		_name_edit.text = _pending_name

## 직능 선택 — OptionButton 인덱스는 _voc_open(해금된 직능) 순서와 같다. 설명을 갱신한다.
func _on_voc_selected(idx: int) -> void:
	if idx < 0 or idx >= _voc_open.size():
		return
	_pending_vocation = str(_voc_open[idx])
	if _voc_desc != null:
		_voc_desc.text = str(Vocations.by_id(_pending_vocation).get("desc", ""))

## (옛 "마을에 새 얼굴" 인라인 안내 한 줄은 공훈 연출 모달(_show_feat_panel)로 승격 — 2026-07-13.)

## (주머니 도구 선택은 단계 1 드롭다운에서 배낭 화면의 창고 집기로 이전 — 2026-07-05 사용자 확정.)

## 단계 1 섹션 라벨 — 얇은 헤어라인 + 모래빛 작은 제목(각인 톤).
func _section_label(txt: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var hair := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([
		Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.0),
		Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.4),
		Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.0),
	])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.0, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	hair.texture = gt
	hair.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hair.custom_minimum_size = Vector2(0, 1)
	hair.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(hair)
	var lbl := UITheme.make_label(txt, UITheme.FS_SMALL, Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.8))
	box.add_child(lbl)
	return box

## 드롭다운(직능 등) 꾸미기 — 투명한 몸통 + 모래빛 밑선(각인 톤), 펼침 메뉴는 가죽 패널.
func _style_select(ob: OptionButton) -> void:
	ob.add_theme_font_size_override("font_size", UITheme.FS_LABEL)
	ob.add_theme_color_override("font_color", UITheme.FG)
	ob.add_theme_color_override("font_hover_color", UITheme.SAND)
	var nsb := _field_stylebox(0.28)
	var hsb := _field_stylebox(0.6)
	ob.add_theme_stylebox_override("normal", nsb)
	ob.add_theme_stylebox_override("hover", hsb)
	ob.add_theme_stylebox_override("pressed", hsb)
	ob.add_theme_stylebox_override("focus", hsb)
	var pop: PopupMenu = ob.get_popup()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.141, 0.102, 0.067, 0.98)     # 가죽 leather
	psb.border_color = Color(0.549, 0.420, 0.239)        # leather-border
	psb.set_border_width_all(1)
	psb.set_corner_radius_all(10)
	psb.set_content_margin_all(8)
	pop.add_theme_stylebox_override("panel", psb)
	pop.add_theme_font_size_override("font_size", UITheme.FS_LABEL)
	pop.add_theme_color_override("font_color", UITheme.FG)
	pop.add_theme_color_override("font_hover_color", UITheme.SAND)
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.13)
	isb.set_corner_radius_all(6)
	pop.add_theme_stylebox_override("hover", isb)

## 입력 필드(이름) 꾸미기 — 드롭다운과 같은 톤.
func _style_field(le: LineEdit) -> void:
	le.add_theme_color_override("font_color", UITheme.FG)
	le.add_theme_stylebox_override("normal", _field_stylebox(0.28))
	le.add_theme_stylebox_override("focus", _field_stylebox(0.6))

## 필드 공통 스타일 — 거의 투명한 바탕 + 모래빛 밑선 1px(각인형 — 상자로 안 읽히게, 둥근 모서리 자제).
func _field_stylebox(line_alpha: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.03, 0.3)
	sb.border_color = Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, line_alpha)
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	return sb

# --- 시장 대화 (초상 + 대사) — 첫 원정 인트로(규칙+기록지) / 첫 순환 후 옛말(재회 암시) 공용 ---

func _show_market_intro() -> void:
	_market_pages = MARKET_PAGES
	_market_flow = "intro"
	_show_market_panel()

## 순환 도달 후 마을에서 한 번 — 재회의 옛말(기림+구조+온전 암시). 보여준 만큼 reunion_hints_shown 영속.
func _show_market_hint() -> void:
	_market_pages = REUNION_HINT_PAGES
	_market_flow = "hint"
	_show_market_panel()

func _show_market_panel() -> void:
	_market_idx = 0
	# 인트로 동안 꾸리기 폼은 숨긴다 — 카드 상자를 없앤 각인 대사가 폼 글씨와 겹치지 않게.
	# (서사로도 맞다: 시장이 먼저 말을 걸고, 대화가 끝나면 채비가 시작된다.)
	if _step_root != null:
		_step_root.visible = false
	_market_panel = Control.new()
	_market_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_market_panel)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = UITheme.SCRIM
	dim.gui_input.connect(_on_market_input)
	_market_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_market_panel.add_child(center)
	# 각인형 대사 상자 — 가죽 카드 폐기(양산형 웹 카드 금지), 스크림 위 초상+헤어라인+대사+각인 버튼.
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(UITheme.COLUMN_W, 0)
	box.add_theme_constant_override("separation", UITheme.GAP)
	UITheme.attach_dark_pool(box)  # 상자 대신 방사 어둠 — 밑의 꾸리기 폼 글씨와 안 섞이게
	center.add_child(box)
	# 시장 초상 — 말하는 이가 시장임을 알게 한다.
	var fig := Figures.new()
	fig.kind = "market"
	fig.custom_minimum_size = Vector2(0, 160.0)
	fig.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(fig)
	box.add_child(UITheme.make_hairline(Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.35), 2.0))
	_market_label = _make_market_label()
	_set_market_text(str(_market_pages[0]))
	box.add_child(_market_label)
	box.add_child(UITheme.make_hairline(Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.35), 2.0))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	var skip := EngravedItem.new()
	skip.init_item("건너뛰기", 15, false)
	skip.pressed.connect(_finish_market)
	row.add_child(skip)
	var nxt := EngravedItem.new()
	nxt.init_item("다음", 18, true)
	nxt.pressed.connect(_market_advance)
	row.add_child(nxt)
	box.add_child(row)
	# 오프닝 뒤 한 박자 뜸 → 서서히 등장. 페이드 인 끝나기 전엔 입력 무시(_market_ready).
	_market_panel.modulate.a = 0.0
	_market_ready = false
	var t := create_tween()
	t.tween_interval(MARKET_INTRO_DELAY)
	t.tween_property(_market_panel, "modulate:a", 1.0, MARKET_INTRO_FADE)
	t.tween_callback(func(): _market_ready = true)

func _on_market_input(event: InputEvent) -> void:
	if not _market_ready:
		return  # 페이드 인 중 — 실수 입력 무시
	var tap: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if tap:
		_market_advance()

func _market_advance() -> void:
	if not _market_ready:
		return
	_market_idx += 1
	if _market_idx >= _market_pages.size():
		_finish_market()
		return
	if _market_label == null:
		return
	# 대사 사이 부드러운 전환 — 탁 바뀌지 않고 잦아들었다 배어난다(오프닝 슬라이드와 같은 결).
	if _market_tw != null and _market_tw.is_valid():
		_market_tw.kill()  # 연타 — 진행 중 페이드는 끊고 바로 다음 대사로
	_market_tw = _market_label.create_tween()
	_market_tw.tween_property(_market_label, "modulate:a", 0.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_market_tw.tween_callback(func() -> void: _set_market_text(str(_market_pages[_market_idx])))
	_market_tw.tween_property(_market_label, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## 시장 대사 글 — 색 강조(BBCode) 지원 RichTextLabel(일지 _rich_label 과 같은 결). 폰트는 기본 테마.
func _make_market_label() -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_size_override("normal_font_size", UITheme.FS_BODY)
	r.add_theme_color_override("default_color", UITheme.FG)
	r.add_theme_constant_override("line_separation", 8)  # make_label 의 line_spacing 8 과 같은 호흡
	return r

## 대사 갈아끼우기 — 가운데 정렬은 [center] 태그로(옛 Label 의 가운데 정렬 유지).
func _set_market_text(bb: String) -> void:
	if _market_label != null:
		_market_label.text = "[center]" + bb + "[/center]"

func _finish_market() -> void:
	if not _market_ready:
		return  # 페이드 인 중 스킵 방지
	if _market_flow == "hint":
		GameState.mark_reunion_hint_shown()  # 이번 순환 몫의 옛말 소화 — 다음 순환을 보면 또 들려준다
	else:
		GameState.give_record()  # 기록지 = 책갈피(Bookmark)를 켠다
	if _market_panel != null:
		_market_panel.queue_free()
		_market_panel = null
	if not _feat_queue.is_empty():
		_show_feat_panel()  # 대화 다음 순서 — 방금 달성한 공훈 연출(채비 폼은 그 뒤에)
	elif _step_root != null:
		UITheme.fade_in(_step_root)  # 대화가 끝나면 채비 폼이 스르륵 나타난다

# --- 공훈 연출 (방금 이룬 일 — 마을에 새 얼굴이 오거나, 오래 남을 기록이 된다. 2026-07-13) ---

## 직능 공훈 = 새 인물 등장(사람 그림 + 도착의 말), 기록형 = 이야기 한 장(일지 "마을" 챕터에 쌓인다).
## 시장 대화와 같은 각인 톤(스크림 + 방사 어둠 + 헤어라인). 여러 건이면 한 장씩 이어서 보여준다.
func _show_feat_panel() -> void:
	var f: Dictionary = {}
	while not _feat_queue.is_empty() and f.is_empty():
		f = Feats.by_id(str(_feat_queue.pop_front()))
	if f.is_empty():
		if _step_root != null and not _step_root.visible:
			UITheme.fade_in(_step_root)
		return
	if _step_root != null:
		_step_root.visible = false
	_feat_panel = Control.new()
	_feat_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_feat_panel)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = UITheme.SCRIM
	dim.gui_input.connect(_on_feat_input)
	_feat_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 탭은 스크림이 받는다(어디를 눌러도 넘어감)
	_feat_panel.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(UITheme.COLUMN_W, 0)
	box.add_theme_constant_override("separation", UITheme.GAP)
	UITheme.attach_dark_pool(box)
	center.add_child(box)
	var vid: String = str(f.get("unlocks", ""))
	if vid != "":
		# 새 얼굴 — 사람 그림이 서고, 그가 도착의 말을 건넨다(등장감). 그림은 공훈별로 둘을 번갈아.
		box.add_child(UITheme.make_label("이룬 일이 소문이 되어\n마을에 새 얼굴을 불렀다.", UITheme.FS_SMALL, UITheme.SAND))
		var fig := Figures.new()
		fig.kind = "villager_a" if str(f.get("id", "")).hash() % 2 == 0 else "villager_b"
		fig.custom_minimum_size = Vector2(0, 170.0)
		fig.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(fig)
	else:
		# 기록 — 사람 대신 이야기가 남는다.
		box.add_child(UITheme.make_label("마을이 오래 기억할 일이 생겼다.", UITheme.FS_SMALL, UITheme.SAND))
		box.add_child(UITheme.make_label(str(f.get("name", "")), UITheme.FS_BODY, UITheme.SAND))
	box.add_child(UITheme.make_hairline(Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.35), 2.0))
	box.add_child(UITheme.make_label(str(f.get("line", "")), UITheme.FS_BODY))
	box.add_child(UITheme.make_hairline(Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.35), 2.0))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var ok := EngravedItem.new()
	ok.init_item("맞이한다" if vid != "" else "마음에 새겨 둔다", 18, true)
	ok.pressed.connect(_close_feat_panel)
	row.add_child(ok)
	box.add_child(row)
	_feat_panel.modulate.a = 0.0
	_feat_ready = false
	var t := create_tween()
	t.tween_interval(0.4)
	t.tween_property(_feat_panel, "modulate:a", 1.0, MARKET_INTRO_FADE)
	t.tween_callback(func(): _feat_ready = true)

func _on_feat_input(event: InputEvent) -> void:
	if not _feat_ready:
		return
	var tap: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if tap:
		_close_feat_panel()

func _close_feat_panel() -> void:
	if not _feat_ready:
		return
	if _feat_panel != null:
		_feat_panel.queue_free()
		_feat_panel = null
	if not _feat_queue.is_empty():
		_show_feat_panel()  # 다음 장 — 여러 건을 한 장씩
	elif _step_root != null:
		UITheme.fade_in(_step_root)
