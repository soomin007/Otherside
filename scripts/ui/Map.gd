extends Control

## 탑뷰 지도 — 데스 스트랜딩식 탐험. 맵 자체가 게임 인터페이스다(별도 이동 씬 없음).
## 미지("?") 노드를 누르면 마커가 그 노드로 *맵 위에서 실제 이동*하며 자원이 닳고, 도착하면 그 노드 화면으로 넘어간다.
## 가본 노드만 정체(이름·종류)가 드러나고, 갈 수 있는 다음은 "?", 그 너머는 안 보인다(강한 미지).
## 이동 중 자잘한 상황·랜드마크 단면 탐색·지형 비주얼은 다음 단계.

const NODE_R: float = 13.0
const STEP_INTERVAL: float = 0.65  ## 이동 한 걸음의 시간(초) — 느긋하게(잉크 번짐·발자국을 음미)
const SPLASH_DUR: float = 0.8      ## 걸음마다 번지는 잉크 얼룩이 피어 사라지기까지(초)
const EDGE_SAMPLES: int = 18       ## 엣지 곡선을 그릴 때 나눌 샘플 수(경로·마커가 같은 곡선을 공유)
const DRAG_THRESH: float = 10.0    ## 이만큼 넘게 끌면 팬(스크롤), 미만이면 탭(노드 선택)
const REVEAL_DUR: float = 0.55     ## 방문 시 잉크 reveal 애니 길이(초)

# --- STAGE 좌표계 (핸드오프 MAP_지도화면.md §0 + 사용자 확대 지시) ---
## 화면 전체를 고정 캔버스 1280×720(STAGE)으로 보고 contain 스케일 — 모든 스펙 px 가 이 기준.
## 밴드는 스펙(230,150,820×461)에서 **우 칼럼 제거·안내문 상향으로 1.24배 확대**(2026-07-05 사용자
## "지도를 좀 더 크게"). 노드 좌표(NODE_PX)는 스펙 MAP 공간(820×461) 그대로 두고 밴드에 비례 매핑.
const STAGE_W: float = 1280.0
const STAGE_H: float = 720.0
const BAND: Rect2 = Rect2(216.0, 100.0, 1040.0, 585.0)  # 1040/585 = 양피지 비율(1.778) 유지 — 지도가 좁아 확대(2026-07-12 사용자)
const MAP_W: float = 820.0   ## 스펙 MAP 좌표 공간(= MapGraph.MAP_W, LAYOUT 기준) — 밴드 크기와 무관
## 노드 절대 배치(§1) — MAP 좌표 x·y = 중심, z = 정사각 표시 크기(px). 시각 데이터라 core(MapGraph)가 아닌 여기에.
## 노드 좌표·크기는 MapGraph.LAYOUT/NODE_SIZE 로 이전(core 단일 진실 — 경로 길이 계산과 렌더가 같은 값 공유).
## Map 은 MapGraph.pos/node_size/edge_point 로 읽어 화면에 비례 매핑만 한다.
const COL_L_X: float = 36.0     ## 좌 "지닌 것" 칼럼(STAGE §6)
const COL_L_W: float = 172.0
const COL_R_X: float = 1072.0   ## 우 "범례" 칼럼(STAGE §6)
const COL_R_W: float = 176.0
const EN_TITLE_FONT := preload("res://assets/fonts/Cinzel.ttf")  ## 에이브로우·수치 전용(영문/숫자)

## 지도 배경 + 노드별 손그림 아이콘(투명 변환본). 노드 id → 아이콘 1:1(이름 일치).
## 로드 실패 시 절차적 심볼(_draw_landmark_symbol)로 fallback — 에셋 없어도 깨지지 않는다.
const BG_PATH: String = "res://assets/arts/01_지도_양피지.png"
const ICON_PATHS: Dictionary = {
	"n0": "res://assets/arts/transparent/02_아이콘_마을.png",
	"a1": "res://assets/arts/transparent/03_아이콘_마른강.png",
	"b1": "res://assets/arts/transparent/04_아이콘_버려진야영지.png",
	"b2": "res://assets/arts/transparent/05_아이콘_갈라진바닥.png",
	"c1": "res://assets/arts/transparent/06_아이콘_오아시스.png",
	"c2": "res://assets/arts/transparent/07_아이콘_모래의벽.png",
	"d1": "res://assets/arts/transparent/08_아이콘_뼈의들판.png",
	"d2": "res://assets/arts/transparent/09_아이콘_독웅덩이.png",
	"e1": "res://assets/arts/transparent/10_아이콘_무너진담.png",
	"f1": "res://assets/arts/transparent/11_아이콘_폭풍의문.png",
	"end": "res://assets/arts/transparent/12_아이콘_미지.png",
}

## 원정대 손스케치(§12 art_prompts) — 방문한 구간에 원정대가 지도에 그려넣은 약도·표식. 흰→투명 변환본.
## 있으면 배치, 없으면 안 그림(백지). biome 키(river/rock/flats/storm) + 메모 키(skull).
const SKETCH_PATHS: Dictionary = {
	"river": "res://assets/arts/transparent/40_낙서_강.png",
	"rock": "res://assets/arts/transparent/41_낙서_산.png",
	"flats": "res://assets/arts/transparent/42_낙서_사구.png",
	"storm": "res://assets/arts/transparent/43_낙서_폭풍.png",
	"skull": "res://assets/arts/transparent/44_낙서_해골.png",
	"warn": "res://assets/arts/transparent/45_낙서_경고.png",
	"arrow": "res://assets/arts/transparent/46_낙서_화살표.png",
}

## 화살표 손스케치 원본이 가리키는 방향(우상향) — 이만큼 빼서 목표 방향으로 회전한다. 스샷 보고 튜닝.
const ARROW_BASE: float = -0.5

## UI 킷(2026-07-12, §16 발주분) — 사람 픽토그램·지도 기호. 잉크판(양피지 위)·`_밝음`(어두운 칼럼 위).
## 로드 실패 시 각 자리의 기존 절차적 draw 로 fallback — 에셋 없어도 깨지지 않는다.
const KIT_PATHS: Dictionary = {
	"leader": "res://assets/arts/transparent/60_사람_대장.png",
	"mate_a": "res://assets/arts/transparent/58_사람_대원갑.png",
	"mate_b": "res://assets/arts/transparent/59_사람_대원을.png",
	"straggler": "res://assets/arts/transparent/61_사람_낙오자.png",
	"leader_lit": "res://assets/arts/transparent/60_사람_대장_밝음.png",
	"mate_a_lit": "res://assets/arts/transparent/58_사람_대원갑_밝음.png",
	"mate_b_lit": "res://assets/arts/transparent/59_사람_대원을_밝음.png",
	"straggler_lit": "res://assets/arts/transparent/61_사람_낙오자_밝음.png",
	"mound_lit": "res://assets/arts/transparent/62_사람_스러짐_밝음.png",
	"trace_ring": "res://assets/arts/transparent/63_기호_흔적점.png",
	"rope_bridge": "res://assets/arts/transparent/64_기호_로프다리.png",
	"party_tag": "res://assets/arts/transparent/65_기호_위치태그.png",
	"overflow": "res://assets/arts/transparent/66_기호_넘침배지.png",
}

# 고지도·양피지 팔레트 — UITheme 로 승격(지도·단면 공유). alias 로 기존 참조 유지.
const PAPER: Color = UITheme.PAPER
const PAPER_EDGE: Color = UITheme.PAPER_EDGE
const INK: Color = UITheme.INK
const INK_FADE: Color = UITheme.INK_FADE
const ROUTE: Color = UITheme.ROUTE
const MARKER_INK: Color = UITheme.MARKER_INK

# --- "살아있는 잉크" (핸드오프 MAP_지도화면.md §2~4) ---
## 손그림 채점 원(§4.1): 240 viewBox·중심(120,120)·기준 반지름 74 로 생성한 폴리라인을
## 노드 크기에 맞춰 스케일. current 는 밝은 주홍으로 그려진 뒤 점멸, hover 는 잉크색으로 그려짐.
const NCIRC_BOX: float = 240.0        ## 생성 좌표계(viewBox) 한 변
const NCIRC_R: float = 74.0           ## 기준 반지름(240 기준)
const NCIRC_STEP: float = 0.11        ## 각 스텝(rad) — 곡률 샘플 간격
const NCIRC_WMAX: float = 3.7         ## 리본 half-width 최대(240 기준) — 중간이 굵음
const NCIRC_WMIN: float = 0.9         ## 리본 half-width 최소 — 처음·끝이 가늘음
const NCIRC_SCALE_FRAC: float = 1.68  ## 원이 놓이는 박스 = 노드 크기의 168%(§4.2)
const CIRC_DRAW_CUR: float = 0.55     ## current 원 그려짐 시간(초, §4.2 drawpen)
const CIRC_DRAW_HOV: float = 0.42     ## hover 원 그려짐 시간(초)
const CIRC_PULSE: float = 2.2         ## current 원 점멸 주기(초, cpulse)

const CIRC_CURRENT: Color = Color(0.984, 0.149, 0.0)   ## #fb2600 현재 위치(밝은 주홍)
const CIRC_HOVER: Color = Color(0.290, 0.184, 0.094)   ## #4a2f18 목적지 잉크원
const RED_PATH: Color = Color(0.824, 0.235, 0.118)     ## #d23c1e 선택 가능한 붉은 길(§3)
## 남긴 자원 점 안료색 — 세피아 양피지 위 형광점 금지(죽은 픽셀처럼 보임). 잉크에 갠 안료 톤으로,
## 색 구분(물=청록·식량=황토·장막=올리브)은 유지. 마커·범례가 공유한다.
const TRACE_WATER: Color = Color(0.25, 0.44, 0.55)
const TRACE_FOOD: Color = Color(0.63, 0.44, 0.19)
const TRACE_SHELTER: Color = Color(0.45, 0.51, 0.30)
const TRACE_TOOL: Color = Color(0.52, 0.42, 0.58)      ## 남긴 주머니 도구(약초·부싯돌·정화천) — 흙빛 삼색과 구분되는 자줏빛
const MAX_TRACE_MARKERS: int = 4                       ## 노드당 보이는 흔적 마커 상한 — 넘치면 (상한-1)개 + "+K" 로 정리(무한 스택 방지)
const TRACE_MARK_INK: Color = Color(0.40, 0.24, 0.15)  ## 흔적 표식 단어 — 낡은 붉은 잉크(죽은 자가 긁어 쓴 결)
const LABEL_HALO: Color = Color(0.914, 0.839, 0.686)   ## 라벨 크림 후광 rgb(233,214,175)(§2)
const LABEL_DIM: Color = Color(0.290, 0.196, 0.071)    ## #4a3212 방문·미답 라벨
const LABEL_MK: Color = Color(0.541, 0.184, 0.106)     ## #8a2f1b 선택 가능·현재 라벨

var _title_eye: Label         ## "EXPEDITION · MAP" 에이브로우(§7)
var _title_lbl: Label         ## "지도 · 탐험"
var _guide: Label
var _col_left: LeftColumn     ## 좌 "지닌 것" 칼럼 — 별도 Control(전환 흩어짐 참여, 분위기 (c))
var _moving: bool = false
var _move_timer: float = 0.0
var _sit_panel: Control       ## 이동 중 상황 카드 모달
var _sit_box: VBoxContainer   ## 카드 내용(매번 갈아끼움)
var _leave_btn: Button        ## "남기기" — 이동 중에도 물건 하나 두고 계속 (런당 1회)
var _bequeath: BequeathPanel  ## 남기기 모달 (공유 컴포넌트 — 도착 화면과 같은 것)
var _result_popup: ResultPopup ## 선택 결과 팝업 (공유)
var _inventory: InventoryOverlay  ## 인벤토리 오버레이(§9) — 좌 칼럼 "가방 열기 →"
var _bag_btn: EngravedItem    ## "가방 열기 →" (좌 칼럼 하단, 남기기 위)
var _bg_tex: Texture2D
var _bg_tex_land: Texture2D   ## 가로(데스크톱) 화면용 — 세로 원본을 90도 회전한 것. 없으면 세로본 fallback
var _icon_tex: Dictionary = {}   ## 노드 id -> Texture2D (로드 성공한 것만)
var _sketch_tex: Dictionary = {} ## 손스케치 key -> Texture2D (로드 성공한 것만). 비면 지형지물 안 그림
var _kit_tex: Dictionary = {}    ## UI 킷 key -> Texture2D (로드 성공한 것만). 없으면 절차적 fallback
var _reveal_id: String = ""      ## 이번에 잉크로 그려지며 나타날 노드(방금 도착/시작한 곳)
var _reveal_t: float = 0.0       ## reveal 애니 경과 시간
var _splashes: Array = []        ## 이동 중 걸음마다 번지는 잉크 얼룩 [{pos,t}] — _process 가 나이 먹이고 _draw 가 렌더
var _hovered_node: String = ""   ## 마우스가 올라간 도달 가능 노드(호버 시 클릭 원 확대). 터치엔 없음
var _active_trace: String = ""    ## 표식 단어가 펼쳐진 노드(흔적 아이콘 호버/탭). 평소엔 아이콘만
var _trace_open_t: float = 0.0    ## 두루마리 펼침 경과(초) — _active_trace 가 바뀔 때 0 으로
var _trace_hitboxes: Array = []   ## [{pos, nid}] — 흔적 아이콘 호버·탭 히트박스(_draw_traces 가 갱신)
var _edge_pickup: Dictionary = {} ## 지금 뜬 이동 중 엣지 줍기 카드의 흔적({from,to,kind,tags}) — 비면 일반 상황
var _edge_offered: Dictionary = {} ## 이번 이동에서 이미 제안한 엣지 흔적 키(재제안 방지) — 이동 시작 시 비움
var _dragging: bool = false       ## 누름~뗌 사이 드래그 추적(임계 넘으면 탭 취소 — 오터치 방지)
var _drag_start_y: float = 0.0    ## 드래그 시작 지점 y(스크린)
var _drag_moved: float = 0.0      ## 드래그 누적 이동(임계 넘으면 탭 아님)
## 손그림 채점 원 캐시·타이머 — 랜덤 생성은 _draw 밖에서 한 번(프레임마다 흔들리면 안 됨), _draw 는 캐시만 렌더.
var _label_pool_tex: GradientTexture2D  ## 라벨 뒤 크림 빛 웅덩이(방사) — 낙서·배경 위 가독성(상자 없이)
var _drift: CPUParticles2D              ## 지도 띠 위 모래 드리프트 — 현 위치 진행도(환경 강도) 반영
var _card_storm: StormFX                ## 이동 중 폭풍 상황 카드 배경의 모래 파티클(2·3층) — 폭풍 카드일 때만
var _card_haze: TextureRect             ## 폭풍 카드 1층(옅은 모래 헤이즈) — 지연 생성
var _circle_cache: Dictionary = {}   ## key(노드 id 또는 "__hover") -> PackedVector2Array(중심 기준 오프셋, 잉크 거칠기 baked)
var _circle_cur_id: String = ""      ## 현재 채점 원이 걸린 노드
var _circle_cur_t: float = 0.0       ## current 원 경과(그려짐→점멸)
var _hover_t: float = 0.0            ## hover 원 그려짐 경과(호버 바뀔 때 0 으로)
var _view: Rect2 = Rect2(0.0, 0.0, 820.0, 461.25)  ## 지도 뷰 창(MAP 좌표) — 가본 만큼 조여진다(_map_view_target 추종)

func _ready() -> void:
	if GameState.current_run == null or not GameState.current_run.alive:
		GameState.begin_run_in_place()
	# 이어하기 복귀 — 엣지 위에서 끊겼으면(카드가 열려 있었으면 카드부터) 걸음을 잇는다.
	# 패널들이 _ready 뒤에 만들어지므로 한 프레임 미룬다.
	_resume_mid_edge.call_deferred()
	AudioManager.play_bed()  # 폭풍 노드에서 돌아왔으면 베드로 복귀(이미 베드면 무시 — 연속 유지)
	# 위치 반영 환경 강도 — 현 위치가 깊을수록(진행 row) 돌풍이 잦고 모래가 세게 흐른다(분위기 시스템 (b)).
	var env_prog: float = MapGraph.progress(_current_node_id())
	AudioManager.set_wind(env_prog)

	if ResourceLoader.exists(BG_PATH):
		_bg_tex = load(BG_PATH)
		# 가로 화면(데스크톱)용 — 세로 원본(720x1280)을 90도 돌려 가로(1280x720)로.
		# 반시계 방향: 시계 방향이면 원본의 나침반 그림이 좌하단(마른 강 노드 자리)에 와서 정확히 가려진다
		# → 180도 반대(반시계)로 돌려 나침반을 우상단 여백으로 보낸다(사용자 지시, 2026-07-06).
		var _bimg: Image = _bg_tex.get_image()
		if _bimg != null:
			_bimg.rotate_90(COUNTERCLOCKWISE)
			_bg_tex_land = ImageTexture.create_from_image(_bimg)
	for id in ICON_PATHS:
		var path: String = str(ICON_PATHS[id])
		if ResourceLoader.exists(path):
			_icon_tex[str(id)] = load(path)
	for k in SKETCH_PATHS:
		var spath: String = str(SKETCH_PATHS[k])
		if ResourceLoader.exists(spath):
			_sketch_tex[str(k)] = load(spath)
	for k in KIT_PATHS:
		var kpath: String = str(KIT_PATHS[k])
		if ResourceLoader.exists(kpath):
			_kit_tex[str(k)] = load(kpath)

	# 라벨 빛 웅덩이 텍스처 — 한 번 생성해 _draw 가 재사용.
	var pg := Gradient.new()
	pg.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	pg.colors = PackedColorArray([
		Color(LABEL_HALO.r, LABEL_HALO.g, LABEL_HALO.b, 0.62),
		Color(LABEL_HALO.r, LABEL_HALO.g, LABEL_HALO.b, 0.34),
		Color(LABEL_HALO.r, LABEL_HALO.g, LABEL_HALO.b, 0.0),
	])
	_label_pool_tex = GradientTexture2D.new()
	_label_pool_tex.gradient = pg
	_label_pool_tex.fill = GradientTexture2D.FILL_RADIAL
	_label_pool_tex.fill_from = Vector2(0.5, 0.5)
	_label_pool_tex.fill_to = Vector2(0.98, 0.5)
	_label_pool_tex.width = 128
	_label_pool_tex.height = 64

	_build_drift(env_prog)  # 크롬보다 먼저 — 모래는 글씨·버튼 아래로 흐른다
	_build_chrome()
	resized.connect(_layout_chrome)
	call_deferred("_layout_chrome")
	# 씬 등장 stagger(스펙 inScatter) — 각인 크롬만 순차 등장(제목→칼럼→안내→가방→남기기).
	# 양피지 지도는 루트 _draw(배경 취급) — 걷힘은 베일 페이드가 담당한다.
	Transition.appear(_title_eye, 0.06)
	Transition.appear(_title_lbl, 0.10)
	Transition.appear(_col_left, 0.14)
	Transition.appear(_guide, 0.18)
	Transition.appear(_bag_btn, 0.24)
	Transition.appear(_leave_btn, 0.30)

	_build_situation_panel()
	_after_ready_setup()

## 크롬(§7·§8) — 제목(에이브로우+타이틀)·설정·하단 안내+남기기. 전부 각인형, 위치는 STAGE 좌표(_layout_chrome).
func _build_chrome() -> void:
	_title_eye = UITheme.make_label("EXPEDITION · MAP", 11, Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.7), false)
	var efv := FontVariation.new()
	efv.base_font = EN_TITLE_FONT
	efv.set_spacing(TextServer.SPACING_GLYPH, 4)  # 스펙 .34em
	_title_eye.add_theme_font_override("font", efv)
	_title_eye.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(_title_eye)
	_title_lbl = UITheme.make_label("지도 · 탐험", UITheme.FS_H1, UITheme.FG, false)
	_title_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	_title_lbl.add_theme_constant_override("shadow_offset_y", 2)
	_title_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(_title_lbl)
	# 안내문 — 제목 오른쪽(지도를 키우려 하단에서 상향, 사용자 지시). 설정은 기록 일지 안으로 통합(별도 버튼 없음).
	_guide = UITheme.make_label(_guide_text(), UITheme.FS_SMALL, Color(0.706, 0.643, 0.533), false)  # #b4a488
	_guide.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(_guide)
	# 가방 열기(§6 좌 칼럼 하단) — 인벤토리 오버레이(§9).
	_bag_btn = EngravedItem.new()
	_bag_btn.init_item("가방 열기 →", 15, false)
	_bag_btn.pressed.connect(_on_bag_pressed)
	add_child(_bag_btn)
	# 남기기 — 좌 칼럼 하단(각인 key). 이동 중에도 상시(고갈사 전에 남길 기회).
	var leave := EngravedItem.new()
	leave.init_item("남기기", 20, true)
	leave.pressed.connect(_on_leave_pressed)
	add_child(leave)
	_leave_btn = leave
	# 좌 "지닌 것" 칼럼 — 루트 _draw 에서 분리한 Control(내용은 LeftColumn._draw). 배치는 _layout_chrome.
	_col_left = LeftColumn.new()
	add_child(_col_left)
	# 전환 OUT 때 크롬만 흩어짐 — 양피지 지도(루트 _draw)는 배경이라 베일 페이드가 담당(Transition 원칙).
	for chrome: Control in [_title_eye, _title_lbl, _guide, _col_left, _bag_btn, _leave_btn]:
		chrome.add_to_group("ui_scatter")

## 가방 열기 — 인벤토리 오버레이(정보 열람 — 이동은 계속 흐른다).
func _on_bag_pressed() -> void:
	var run: ExpeditionRun = GameState.current_run
	if run == null or _inventory == null or _inventory.is_open():
		return
	_inventory.open(run)

## 지도 띠 위 모래 드리프트 — 남기기 화면과 같은 원리(진행도 → 양·속도·짙기). 웹 안전: CPUParticles2D 소량.
## 배치·크기는 _layout_chrome 이 지도 띠에 맞춘다(리사이즈 추종).
func _build_drift(prog: float) -> void:
	_drift = CPUParticles2D.new()
	_drift.texture = StormFX.make_dot_texture(10)
	_drift.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_drift.direction = Vector2(-1.0, 0.14)   # 전진(오른쪽)을 거스르는 바람 — StormFX 와 같은 결
	_drift.spread = 14.0
	_drift.gravity = Vector2(0.0, 5.0)
	_drift.lifetime = 3.6
	_drift.preprocess = 3.6                  # 들어오면 이미 불고 있던 바람
	_drift.scale_amount_min = 0.5
	_drift.scale_amount_max = 1.1
	_drift.amount = int(lerpf(12.0, 50.0, prog))
	_drift.initial_velocity_min = lerpf(26.0, 70.0, prog)
	_drift.initial_velocity_max = lerpf(60.0, 170.0, prog)
	# 밝은 모래색은 양피지와 같은 계열이라 안 보인다(대비 0) — 어두운 세피아 알갱이로,
	# 종이 위를 스치는 모래 그늘처럼. 남기기 화면(어두운 배경)은 밝은 모래색이 맞고 여긴 반대.
	_drift.color = Color(0.42, 0.31, 0.18, lerpf(0.25, 0.45, prog))
	add_child(_drift)

## 크롬 배치 — STAGE 좌표(제목 230,46 · 안내문 제목 오른쪽 · 남기기 좌 칼럼 하단) → 화면 px. 리사이즈마다.
func _layout_chrome() -> void:
	if _title_eye == null:
		return
	var st := _stage_rect()
	var sc: float = st.size.x / STAGE_W
	if _drift != null:
		var band := _map_area()
		_drift.position = band.position + band.size * 0.5
		_drift.emission_rect_extents = band.size * 0.5
	if _card_storm != null and _card_haze != null and _card_haze.visible:
		_card_storm.set_band(Rect2(Vector2.ZERO, size))  # 폭풍 카드 중 리사이즈 추종
	_title_eye.position = st.position + Vector2(230.0, 24.0) * sc
	_title_lbl.position = st.position + Vector2(228.0, 44.0) * sc
	_guide.position = st.position + Vector2(474.0, 62.0) * sc
	_bag_btn.size = Vector2((COL_L_W + 24.0) * sc, 46.0)
	_bag_btn.position = st.position + Vector2(COL_L_X - 12.0, 580.0) * sc
	_leave_btn.size = Vector2((COL_L_W + 24.0) * sc, 54.0)
	_leave_btn.position = st.position + Vector2(COL_L_X - 12.0, 638.0) * sc
	# 좌 칼럼 — STAGE (36,140) w172, 내용 높이 ~344(첫 베이스라인 158 → 통계 479 + 여유).
	_col_left.position = st.position + Vector2(COL_L_X, 140.0) * sc
	_col_left.size = Vector2(COL_L_W, 344.0) * sc
	_col_left.sc = sc
	_col_left.queue_redraw()

## _ready 마무리 — 남기기·결과 팝업(공유 컴포넌트)·잉크 reveal·채점 원 초기화.
func _after_ready_setup() -> void:
	# 남기기·결과 팝업 = 공유 컴포넌트(도착 화면과 같은 것).
	_bequeath = BequeathPanel.new()
	_bequeath.committed.connect(_on_bequeath_done)
	_bequeath.cancelled.connect(_on_bequeath_done)
	add_child(_bequeath)
	_result_popup = ResultPopup.new()
	add_child(_result_popup)
	_inventory = InventoryOverlay.new()
	add_child(_inventory)
	# 방금 도착(또는 시작)한 노드가 잉크로 번지듯 나타난다 — 지도 재진입마다 현재 노드에 재생.
	if GameState.current_run != null:
		_reveal_id = GameState.current_run.current_node
	_reveal_t = 0.0
	# 현재 위치 채점 원 — 이 지도 방문의 현재 노드에 한 번 생성(그려짐→점멸은 _process 가 진행).
	_circle_cur_id = _current_node_id()
	_circle_cache[_circle_cur_id] = _gen_grading_circle()
	_circle_cur_t = 0.0
	_view = _map_view_target()  # 지도 진입 시엔 글라이드 없이 곧장 — 새 노드가 열릴 때만 넓어진다
	_refresh_hud()
	queue_redraw()

func _guide_text() -> String:
	if _moving:
		return "나아가는 중..."
	if _current_node_id() == "end":
		return "목적지에 닿았다."
	return "길은 가 본 만큼만 보인다."

func _current_node_id() -> String:
	if GameState.current_run != null:
		return GameState.current_run.current_node
	return MapGraph.START_ID

func _is_revealed(id: String) -> bool:
	return GameState.visited_nodes.has(id)

## 지금 서 있는 노드에서 바로 갈 수 있는 다음 노드인가(미방문 "?" 포함) — 흔적 표식 forward 노출용.
func _is_next_choice(id: String) -> bool:
	return id in MapGraph.node(_current_node_id()).get("next", [])

func _refresh_hud() -> void:
	var run: ExpeditionRun = GameState.current_run
	if run == null:
		return
	AudioManager.warn_thirst(run.get_res("water"))  # 물이 임계로 떨어지는 순간 경고음 1회
	_update_leave_btn(run)
	queue_redraw()
	if _col_left != null:
		_col_left.queue_redraw()  # 좌 칼럼(지닌 것)이 _draw 에서 자원을 직접 읽는다

## 남기기 버튼 상태 — 이미 남겼으면 잠그고, 아니면 남길 수 있는 자원이 하나라도 있을 때만 활성.
func _update_leave_btn(run: ExpeditionRun) -> void:
	if _leave_btn == null:
		return
	if run.bequeathed:
		_leave_btn.disabled = true
		_leave_btn.text = "남겼다"
	else:
		_leave_btn.disabled = not _any_leavable(run)
		_leave_btn.text = "남기기"

func _any_leavable(run: ExpeditionRun) -> bool:
	for key in ["water", "food", "rope", "shelter"]:
		if run.can_leave(key):
			return true
	return false

## 남기기 — 이동 중이면 멈추고, 마지막 밟은 노드에 물건을 둔다(런당 1회). 남긴 뒤 이동을 잇는다.
func _on_leave_pressed() -> void:
	var run: ExpeditionRun = GameState.current_run
	if run == null or not run.alive or run.bequeathed:
		return
	if _sit_panel.visible or _bequeath.is_open() or _result_popup.is_open() or (_inventory != null and _inventory.is_open()):
		return
	_moving = false
	if _guide != null:
		_guide.text = "멈춰 선다."
	# node_id=떠나온 노드(줍기 키), 이동 중이면 BequeathPanel 이 엣지 위 실제 지점(to_node·position)도 찍는다.
	_bequeath.open(run, run.current_node)

## 남기기 패널이 닫힌 뒤 (남겼든 취소든) — 이동 중이었으면 이어서 나아간다.
func _on_bequeath_done() -> void:
	var run: ExpeditionRun = GameState.current_run
	_refresh_hud()
	if run != null and run.alive and run.target_node_id() != "" and not run.arrived():
		_moving = true
		_move_timer = 0.0
		if _guide != null:
			_guide.text = "나아가는 중..."
	elif _guide != null:
		_guide.text = _guide_text()

# --- 이동 (맵 위에서 실제로) ---

func _process(delta: float) -> void:
	# 걸음 잉크 얼룩 나이 먹이기 — 다 자란 건 버린다. 남아 있으면 계속 다시 그린다(피어오르는 중).
	if not _splashes.is_empty():
		var kept: Array = []
		for sp in _splashes:
			sp["t"] = float(sp["t"]) + delta
			if float(sp["t"]) < SPLASH_DUR:
				kept.append(sp)
		_splashes = kept
		queue_redraw()
	# reveal 애니가 진행 중이면 다시 그린다(이동 중이 아니어도).
	if _reveal_t < REVEAL_DUR:
		_reveal_t += delta
		queue_redraw()
	# 흔적 두루마리 펼침 애니 — 다 펼쳐질 때까지만 다시 그린다.
	if _active_trace != "" and _trace_open_t < 0.3:
		_trace_open_t += delta
		queue_redraw()
	# 지도 뷰 — 가본 만큼 조여진 창을 부드럽게 따라간다(새 노드가 열리면 지도가 넓어지는 감각).
	var tv: Rect2 = _map_view_target()
	if not (_view.position.is_equal_approx(tv.position) and _view.size.is_equal_approx(tv.size)):
		if AppSettings.load_motion() <= 0.02:
			_view = tv
		else:
			var k: float = clampf(delta * 3.0, 0.0, 1.0)
			_view = Rect2(_view.position.lerp(tv.position, k), _view.size.lerp(tv.size, k))
			if _view.position.distance_to(tv.position) < 0.5 and absf(_view.size.x - tv.size.x) < 0.5:
				_view = tv
		queue_redraw()
	if not _moving:
		# 정지 시 — 현재 채점 원이 그려진 뒤 점멸(살아있는 잉크). hover 원 그려짐도 진행.
		# 점멸이 무한이라 지도가 계속 다시 그려진다(정지 중). 2D 벡터 렌더라 데스크톱은 가벼움 — 폰 배터리는 플레이테스트에서 확인.
		var run: ExpeditionRun = GameState.current_run
		if run != null and run.alive:
			_circle_cur_t += delta
			if _hovered_node != "":
				_hover_t += delta
			queue_redraw()
		return
	queue_redraw()  # 이동 중엔 매 프레임 다시 그린다(마커가 곡선 위를 부드럽게 미끄러진다)
	_move_timer += delta
	if _move_timer < STEP_INTERVAL:
		return
	_move_timer = 0.0
	var run: ExpeditionRun = GameState.current_run
	if run == null:
		_moving = false
		return
	run.step()
	AudioManager.play_step()   # 모래 발소리(4변주 랜덤)
	GameState.autosave_run()   # 걸음마다 이어하기 저장 — 폰 브라우저가 탭을 죽여도 이 걸음까지는 남는다
	_refresh_hud()
	# 이 걸음이 닿은 자리에 잉크가 번진다(잉크처럼 퍼지는 이동).
	if run.alive:
		_splashes.append({"pos": _marker_pos(_map_area()), "t": 0.0})
	if not run.alive or run.arrived():
		_moving = false
		GameState.go_to_expedition()  # 도착(또는 도중 고갈사) → 그 노드 화면 (남은 손실 서사는 그 화면이 보여준다)
	else:
		# 이 걸음이 행렬에서 사람을 앗아갔으면(물·식량 바닥 스침) — 멈춰 서서 알린다.
		var loss_note: String = _take_loss_note(run)
		if loss_note != "":
			_moving = false
			_result_popup.show_result("", {}, _after_loss_note, loss_note, UITheme.DANGER, ResultPopup.party_state(run, "lose"))
			return
		# 이동 중 엣지 위 자원 흔적을 지나면 줍기 카드(자연 상황이 없을 때만 — 상황을 덮지 않게).
		if run.pending_situation.is_empty():
			var ep: Dictionary = _edge_pickup_here(run)
			if not ep.is_empty():
				_raise_edge_pickup(run, ep)
		if not run.pending_situation.is_empty():
			_moving = false
			_show_situation_card()  # 이동 중 마주친 상황/줍기 — 결정하면 이동을 잇는다

func _gui_input(event: InputEvent) -> void:
	# 터치 기기에선 에뮬레이트된 마우스 이벤트를 무시 — 탭 한 번에 ScreenTouch 와 MouseButton 이
	# 둘 다 들어와 흔적 두루마리 토글이 2번 실행(열리자마자 닫힘)되던 원인(2026-07-12 폰 제보).
	if DisplayServer.is_touchscreen_available() and (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	if _moving or (_sit_panel != null and _sit_panel.visible) or (_bequeath != null and _bequeath.is_open()) or (_result_popup != null and _result_popup.is_open()) or (_inventory != null and _inventory.is_open()):
		if _hovered_node != "" or _active_trace != "":
			_hovered_node = ""
			_active_trace = ""
			queue_redraw()
		return
	var area := _map_area()
	# 누름 시작 — 탭 후보로 잡아둔다(뗄 때 안 밀렸으면 노드 선택).
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_dragging = true
		_drag_start_y = event.position.y
		_drag_moved = 0.0
		return
	# 뗌 — 임계 미만이면 탭(노드 선택). 많이 밀렸으면 오터치로 보고 무시.
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed):
		_dragging = false
		if _drag_moved < DRAG_THRESH:
			# 흔적 아이콘 탭 → 표식 단어 펼치기/접기(라우팅 아님, 터치 우선).
			var trh: String = _trace_at(event.position)
			if trh != "":
				_active_trace = "" if _active_trace == trh else trh
				_trace_open_t = 0.0
				queue_redraw()
				return
			var hit: String = _reachable_at(event.position, area)
			if hit != "":
				GameState.begin_travel(hit)
				_moving = true
				_move_timer = 0.0
				_hovered_node = ""
				_active_trace = ""
				_edge_offered.clear()   # 새 엣지 — 지나며 줍기 제안 이력 초기화
				if _guide != null:
					_guide.text = "나아가는 중..."
		return
	# 끄는 중 — 누적 이동만 추적(임계 넘으면 위에서 탭 취소). 화면은 fit 이라 팬 없음.
	if _dragging and (event is InputEventMouseMotion or event is InputEventScreenDrag):
		_drag_moved = maxf(_drag_moved, absf(event.position.y - _drag_start_y))
		return
	# 호버 — 마우스가 올라간 도달 가능 노드(그 원이 커진다). 데스크톱 전용.
	if event is InputEventMouseMotion:
		var mpos: Vector2 = (event as InputEventMouseMotion).position
		var trh: String = _trace_at(mpos)   # 데스크톱: 흔적 아이콘 호버 시 표식 펼침
		if trh != _active_trace:
			_active_trace = trh
			_trace_open_t = 0.0
			queue_redraw()
		var hov: String = _reachable_at(mpos, area)
		if hov != _hovered_node:
			_hovered_node = hov
			if hov != "":
				_circle_cache["__hover"] = _gen_grading_circle()  # 목적지에 올릴 때마다 새 손그림 원
				_hover_t = 0.0
				AudioManager.play_circle_draw()  # 원이 그려지기 시작하는 소리(옅게)
			queue_redraw()

## 좌표 위의 도달 가능 노드 id(없으면 ""). 판정 반경 = 그 노드 크기 기준(터치 여유 포함).
func _reachable_at(pos: Vector2, area: Rect2) -> String:
	for nx in MapGraph.node(_current_node_id()).get("next", []):
		var nx_s: String = str(nx)
		var p: Vector2 = _node_screen(nx_s, area)
		if pos.distance_to(p) <= maxf(_node_size(nx_s) * 0.62, 30.0):
			return nx_s
	return ""

# --- 이동 중 상황 카드 ---

func _build_situation_panel() -> void:
	_sit_panel = Control.new()
	_sit_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sit_panel.visible = false
	add_child(_sit_panel)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = UITheme.SCRIM
	_sit_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sit_panel.add_child(center)
	# 각인 모달(가죽 카드 폐기) — 방사 어둠 + 헤어라인. 내용(_sit_box)만 상황마다 갈아끼운다.
	var parts: Array = UITheme.make_engraved_modal()
	center.add_child(parts[0])
	_sit_box = parts[1]

## 폭풍 상황 카드 배경에 시각 폭풍 3층(1층 헤이즈 + 2·3층 파티클)을 켜고 끈다.
## 카드 모달의 어둠(dim) 위·내용(center) 아래에 끼워, 폭풍이 카드 뒤에서 몰아치게 한다.
## 어두운 scrim 위라 밝은 모래 입자 대비가 잘 산다. Expedition 단면과 같은 StormFX·헤이즈를 공유.
func _set_card_storm(on: bool) -> void:
	if on and _card_storm == null:
		# 1층 헤이즈 — 위 짙고 아래 옅은 따뜻한 모래 베일(Expedition._make_storm_haze 와 같은 결).
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 1.0])
		g.colors = PackedColorArray([Color(0.72, 0.63, 0.47, 0.16), Color(0.72, 0.63, 0.47, 0.05)])
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill_from = Vector2(0.5, 0.0)
		tex.fill_to = Vector2(0.5, 1.0)
		tex.width = 16
		tex.height = 128
		_card_haze = TextureRect.new()
		_card_haze.texture = tex
		_card_haze.set_anchors_preset(Control.PRESET_FULL_RECT)
		_card_haze.stretch_mode = TextureRect.STRETCH_SCALE
		_card_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sit_panel.add_child(_card_haze)
		_sit_panel.move_child(_card_haze, 1)   # dim(0) 위, center 아래
		_card_storm = StormFX.new()
		_sit_panel.add_child(_card_storm)
		_sit_panel.move_child(_card_storm, 2)  # 헤이즈 위, center 아래
	if _card_storm == null:
		return
	_card_haze.visible = on
	if on:
		_card_storm.set_band(Rect2(Vector2.ZERO, size))  # 화면 전체 = 폭풍 영역
	else:
		_card_storm.set_band(Rect2())                    # 숨김 + 분출 정지

## 이동 중 마주친 상황 카드 — 읽고 한 가지를 고른다(관리·대비). 결정하면 이동을 잇는다(죽으면 그 자리 노드 화면).
func _show_situation_card() -> void:
	var run: ExpeditionRun = GameState.current_run
	if run == null:
		return
	var sit: Dictionary = run.pending_situation
	for c in _sit_box.get_children():
		_sit_box.remove_child(c)
		c.queue_free()
	if _guide != null:
		_guide.text = "멈춰 선다."
	var threat_kind: int = int(sit.get("threat", Threats.Kind.CONSUMPTION))
	AudioManager.play_situation_card(threat_kind)  # 카드 열림 — 위협 종류별 소리(폭풍 돌풍·갈라진 울림·양피지)
	_set_card_storm(threat_kind == Threats.Kind.STORM)  # 폭풍 위협이면 카드 뒤로 시각 폭풍 3층
	var threat_info: Dictionary = Threats.info(threat_kind)
	_sit_box.add_child(UITheme.make_label("[ %s ]" % str(threat_info.get("label", "상황")), UITheme.FS_SMALL, UITheme.SAND))
	_sit_box.add_child(UITheme.make_label(str(sit.get("text", "")), UITheme.FS_BODY))
	var event_id: String = str(sit.get("id", ""))
	var choices: Array = sit.get("choices", [])
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var effect: Dictionary = choice.get("effect", {})
		var enabled: bool = Situations.can_choose(choice, run.resources)
		var seen: bool = GameState.has_seen_choice(event_id, i)  # 겪어본 선택지만 결과 노출
		var btn := UITheme.make_engraved_button(UITheme.choice_text(choice, enabled, seen), 17, false)
		if enabled:
			btn.pressed.connect(_on_situation_choice.bind(event_id, i, str(choice.get("label", "")), effect, choice.get("sets", []), choice.get("sets_persist", []), choice.get("then", {})))
		else:
			btn.disabled = true
		_sit_box.add_child(btn)
	_sit_panel.visible = true
	UITheme.recenter_modal.call_deferred(_sit_panel)  # 웹 하단 치우침 방어(레이아웃 레이스)

func _on_situation_choice(event_id: String, idx: int, label: String, effect: Dictionary, sets: Array, sets_persist: Array, then: Dictionary = {}) -> void:
	var run: ExpeditionRun = GameState.current_run
	if run == null:
		return
	GameState.mark_choice_seen(event_id, idx)  # 이 선택지를 겪었다 — 다음 대면 때 결과가 보인다(런 한정)
	run.apply_choice(effect)
	for f in sets:
		run.set_flag(str(f))
	for f in sets_persist:
		run.set_flag(str(f))
	if not sets_persist.is_empty():
		GameState.add_persist_flags(sets_persist)
	# 후속 장면(then) — 이야기가 같은 걸음에서 한 박자 더 이어진다(2026-07-12 사용자: 한 턴짜리 금지).
	# raise 를 autosave 앞에 — 여기서 끊겨도 이어하기가 후속 장면부터 잇는다(_resume_mid_edge).
	if run.alive and not then.is_empty():
		run.raise_situation(then)
	# 이동 중 엣지 줍기였으면 — 집었으면(효과=+자원) 그 흔적 uses 소진, 남겨뒀으면 그대로(이번 이동엔 재제안 안 함).
	if not _edge_pickup.is_empty():
		if not effect.is_empty():
			GameState.use_trace_edge(str(_edge_pickup["from"]), str(_edge_pickup["to"]), int(_edge_pickup["kind"]))
			AudioManager.play_sfx(AudioManager.PICKUP)  # 지나며 이전 원정대의 흔적을 줍는다
		_edge_pickup = {}
	_sit_panel.visible = false
	_set_card_storm(false)  # 카드 닫힘 — 폭풍 파티클 분출 정지
	GameState.autosave_run()  # 결정은 되돌릴 수 없다 — 즉시 이어하기 저장
	_refresh_hud()
	# blind choice 뒷면 — 결과(자원 변화)를 팝업으로 공개하고, 닫으면 이동을 잇는다.
	var sit_loss: String = _take_loss_note(run)
	_result_popup.show_result(label, effect, _after_situation, sit_loss, UITheme.DANGER,
		ResultPopup.party_state(run, "lose") if sit_loss != "" else {})

## 이어하기 복귀(지도 진입 한 프레임 뒤) — 엣지 위에서 끊긴 원정을 잇는다.
## 평소 지도 진입(노드에서 복귀·출발 전)엔 is_mid_edge 가 false 라 아무것도 안 한다.
func _resume_mid_edge() -> void:
	var run: ExpeditionRun = GameState.current_run
	if run == null or not run.alive or not run.is_mid_edge() or _moving:
		return
	if not run.pending_situation.is_empty():
		_show_situation_card()  # 카드가 열린 채 끊겼다 — 결정부터. 닫으면 이동이 이어진다.
	else:
		_moving = true

## 방금 걸음/선택이 행렬에서 사람을 앗아갔으면 그 서사를 꺼낸다. 죽었으면 버린다(죽음 화면이 말한다).
func _take_loss_note(run: ExpeditionRun) -> String:
	var notes: Array = run.take_loss_notes()
	if not run.alive or notes.is_empty():
		return ""
	return "\n".join(PackedStringArray(notes))

## 손실 팝업을 닫은 뒤 — 같은 걸음에 상황 카드도 떴으면 카드로, 아니면 이동을 잇는다.
func _after_loss_note() -> void:
	var run: ExpeditionRun = GameState.current_run
	if run == null or not run.alive:
		return
	if not run.pending_situation.is_empty():
		_show_situation_card()
	else:
		_moving = true

## 지금 걷는 엣지 위에서 지나친 자원 흔적을 찾는다(진행률 넘어섰고 아직 이번 이동에 제안 안 한 것). 없으면 {}.
func _edge_pickup_here(run: ExpeditionRun) -> Dictionary:
	var from_id: String = run.current_node
	var to_id: String = run.target_node_id()
	if to_id == "":
		return {}
	var frac: float = run.edge_fraction()
	for ep in GameState.edge_pickup_traces():
		if str(ep["from"]) != from_id or str(ep["to"]) != to_id:
			continue
		if float(ep["position"]) > frac:
			continue  # 아직 안 지났다
		var key: String = _edge_key(from_id, to_id, int(ep["kind"]))
		if _edge_offered.has(key):
			continue
		return ep
	return {}

## 엣지 줍기 카드를 띄운다(상황 카드 흐름 재사용) — 흔적을 기록하고 이번 이동에 다시 제안 안 하게 표시.
func _raise_edge_pickup(run: ExpeditionRun, ep: Dictionary) -> void:
	var ev: Dictionary = Situations.pickup_trace({"kind": int(ep["kind"]), "tags": ep["tags"]})
	run.raise_situation(ev)
	_edge_pickup = ep
	_edge_offered[_edge_key(str(ep["from"]), str(ep["to"]), int(ep["kind"]))] = true

func _edge_key(from_id: String, to_id: String, kind: int) -> String:
	return "%s>%s:%d" % [from_id, to_id, kind]

## 이동 중 상황의 결과 팝업을 닫은 뒤 — 죽었으면 그 자리 노드 화면, 후속 장면이 걸려 있으면
## 그 카드부터(이야기가 이어진다), 아니면 이동 재개.
func _after_situation() -> void:
	var run: ExpeditionRun = GameState.current_run
	if run == null:
		return
	if not run.alive:
		GameState.go_to_expedition()  # 결정이 곧 죽음 → 그 자리 노드 화면
		return
	if not run.pending_situation.is_empty():
		_show_situation_card()  # 후속 장면(then) — 같은 걸음에서 이야기 한 박자 더
		return
	_moving = true   # 아직 도착 전 — 이동을 잇는다
	_move_timer = 0.0
	if _guide != null:
		_guide.text = "나아가는 중..."

# --- 렌더 ---

## 배경(과 노드)이 놓이는 rect — 화면 창에 배경 이미지를 종횡비 유지로 온전히(contain) 넣은 영역.
## 창을 꽉 안 채워도 된다: 남는 여백은 나중에 범례·설정 등 UI 자리로 둔다. 배경·노드가 이 rect 를 공유한다.
## STAGE(1280×720)를 화면에 contain — 스펙 px 는 전부 이 rect 기준으로 비율 스케일(§0).
func _stage_rect() -> Rect2:
	var sc: float = minf(size.x / STAGE_W, size.y / STAGE_H)
	var dr: Vector2 = Vector2(STAGE_W, STAGE_H) * sc
	return Rect2((size - dr) * 0.5, dr)

## STAGE 스케일(스펙 px → 화면 px 배율).
func _sscale() -> float:
	return minf(size.x / STAGE_W, size.y / STAGE_H)

## 지도 띠(양피지) rect — 스펙 §0: STAGE (230,150) 820×461.
func _map_area() -> Rect2:
	var st := _stage_rect()
	var sc: float = _sscale()
	return Rect2(st.position + BAND.position * sc, BAND.size * sc)

## 튜토리얼 하이라이트가 짚을 실제 화면 rect(전역 좌표). idx = 전역 STEP 인덱스.
func tutorial_highlight_rect(idx: int) -> Rect2:
	if idx == 1 and _leave_btn != null and _leave_btn.is_inside_tree():
		return _leave_btn.get_global_rect().grow(10.0)
	return _map_area()  # idx 0(과 기타) = 지도(배경+노드) 영역

## MAP 좌표(820×461) → 화면 배율 — 밴드 확대분 + 뷰 줌(가본 만큼 확대) 포함.
func _mscale() -> float:
	return _sscale() * BAND.size.x / maxf(60.0, _view.size.x)

## 지도 뷰(MAP 좌표의 보이는 창) — "가본 곳들만 나오는 크기"로 조여서, 새 노드가 드러날 때마다
## 지도가 넓어지는 것처럼 느껴지게 한다(2026-07-12 사용자 확정 — 자유 핀치 줌 대신 자동 확장).
## 줌 상한 VIEW_ZOOM_MAX(아이콘 과대 방지), 전체 지도 밖으로는 안 나간다. _process 가 부드럽게 따라간다.
const VIEW_ZOOM_MAX: float = 1.6
func _map_view_target() -> Rect2:
	var aspect: float = BAND.size.y / BAND.size.x
	var cur: String = _current_node_id()
	var nexts: Array = MapGraph.node(cur).get("next", [])
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	var n: int = 0
	for id in MapGraph.NODES:
		var s: String = str(id)
		if not (_is_revealed(s) or s in nexts):
			continue
		var p: Vector2 = MapGraph.pos(s)
		mn = mn.min(p)
		mx = mx.max(p)
		n += 1
	var full := Rect2(0.0, 0.0, MAP_W, MAP_W * aspect)
	if n < 2:
		return full
	mn -= Vector2(100.0, 85.0)   # 노드 아이콘·흔적 스택·라벨 여유(맵 단위)
	mx += Vector2(100.0, 100.0)
	var w: float = mx.x - mn.x
	var h: float = mx.y - mn.y
	if h / w > aspect:
		w = h / aspect
	else:
		h = w * aspect
	w = clampf(w, MAP_W / VIEW_ZOOM_MAX, MAP_W)
	h = w * aspect
	var c: Vector2 = (mn + mx) * 0.5
	var origin: Vector2 = c - Vector2(w, h) * 0.5
	origin.x = clampf(origin.x, 0.0, MAP_W - w)
	origin.y = clampf(origin.y, 0.0, MAP_W * aspect - h)
	return Rect2(origin, Vector2(w, h))

## 노드 중심(화면 px) — 스펙 절대좌표(§1)를 뷰 창 기준으로 밴드에 매핑.
func _node_screen(id: String, area: Rect2) -> Vector2:
	return area.position + (MapGraph.pos(id) - _view.position) * (area.size.x / _view.size.x)

## 노드 표시 크기(화면 px) — MapGraph.NODE_SIZE(스펙 px), 밴드 확대 비례. 0.85 = 아이콘이 커서 축소(2026-07-12 사용자).
func _node_size(id: String) -> float:
	return MapGraph.node_size(id) * _mscale() * 0.85

## 엣지 A→B 곡선 위의 점(t∈[0,1], 화면 px). MapGraph.edge_point(스펙 좌표, core 단일 진실)를 화면에 스케일.
## 경로 렌더·마커·점선·경로 길이(걸음 수)가 모두 core 곡선 공식 하나를 공유한다.
func _edge_point(from_id: String, to_id: String, t: float, area: Rect2) -> Vector2:
	return area.position + (MapGraph.edge_point(from_id, to_id, t) - _view.position) * (area.size.x / _view.size.x)

## 엣지 곡선을 EDGE_SAMPLES 로 나눈 폴리라인(경로 실선/점선 렌더용).
func _edge_polyline(from_id: String, to_id: String, area: Rect2) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	for i in range(EDGE_SAMPLES + 1):
		pts.append(_edge_point(from_id, to_id, float(i) / float(EDGE_SAMPLES), area))
	return pts

## 노드 id 해시(곡선 굴곡 방향)는 MapGraph.id_hash 로 이전 — 곡선 공식과 함께 core 에 산다.

## 발자국 — 밟은 길 곡선을 따라 좌우 번갈아 찍힌 자취. upto(0~1)까지만 그린다(이동 중엔 마커까지 실시간).
func _draw_footprints(pts: PackedVector2Array, upto: float = 1.0) -> void:
	var n: int = pts.size()
	if n < 2:
		return
	var total: float = 0.0
	for i in range(n - 1):
		total += pts[i].distance_to(pts[i + 1])
	var limit: float = total * clampf(upto, 0.0, 1.0)
	var col := Color(INK.r, INK.g, INK.b, 0.6)
	var spacing: float = 13.0
	var walked: float = 0.0            # 지금까지 따라온 호길이
	var next_foot: float = spacing * 0.6   # 첫 발자국은 노드에서 살짝 떨어져
	var side: float = 1.0
	for i in range(n - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var seg: float = a.distance_to(b)
		if seg < 0.001:
			continue
		var dir: Vector2 = (b - a) / seg
		var nrm: Vector2 = Vector2(-dir.y, dir.x)
		while next_foot <= walked + seg:
			if next_foot > limit:
				return  # 마커가 아직 여기까지 안 왔다(이동 중 실시간)
			var pos: float = next_foot - walked
			var foot: Vector2 = a + dir * pos + nrm * (side * 3.0)
			draw_line(foot - dir * 2.2, foot + dir * 2.2, col, 2.4)  # 발바닥 = 진행 방향 짧은 자국
			side = -side
			next_foot += spacing
		walked += seg

## 이번 엣지 진행률(0~1) — 밟은 걸음 + 걸음 사이 프레임 보간(마커·실시간 발자국이 공유).
func _edge_progress(run: ExpeditionRun) -> float:
	var elen: int = maxi(1, run.edge_len())
	var step_done: float = float(elen - run.edge_remaining())
	var frac: float = clampf(_move_timer / STEP_INTERVAL, 0.0, 1.0)
	return clampf((step_done + frac) / float(elen), 0.0, 1.0)

## 플레이어 마커 위치 — 길 위(target 있음)면 엣지 곡선 위(멈춰 있어도 그 자리), 아니면 현재 노드.
## _moving 이 아니라 target 유무로 판정 — 상황 카드로 멈춘 동안 마커가 출발지로 되돌아가던 버그 방지.
func _marker_pos(area: Rect2) -> Vector2:
	var run: ExpeditionRun = GameState.current_run
	if run == null:
		return _node_screen(MapGraph.START_ID, area)
	var tgt: String = run.target_node_id()
	if tgt == "":
		return _node_screen(run.current_node, area)
	return _edge_point(run.current_node, tgt, _edge_progress(run), area)

func _draw() -> void:
	var rect: Vector2 = size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return
	var area := _map_area()
	if area.size.y < 60.0 or area.size.x < 60.0:
		return
	var font: Font = get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font

	# 지도 배경 — 양피지 띠(스펙 §0: 밴드에 정확히, 회전 가로본). 없으면 절차적 양피지 fallback(웹 안전).
	if _bg_tex_land != null or _bg_tex != null:
		_draw_bg_cover(area)
	else:
		draw_rect(area, PAPER)
		_draw_terrain(area)
		_draw_paper_edge(area)
	_draw_biomes(area)  # 지형지물 잉크 — 배경 위, 경로·노드 아래(세계의 지리, 텍스처 유무 무관)

	var cur: String = _current_node_id()
	var nexts: Array = MapGraph.node(cur).get("next", [])
	var ms: float = _mscale()   # MAP 스케일(노드·라벨 — 밴드 확대 포함)
	# 좌 "지닌 것" 칼럼은 별도 Control(LeftColumn) — 전환 흩어짐 참여를 위해 루트 _draw 에서 분리(2026-07-14).

	# 길 — 가본 노드에서 나가는 트레일. 밟은 길은 진한 실선, 미지로 향하는 길은 점선.
	for id in MapGraph.NODES:
		if not _is_revealed(id):
			continue
		var from_cur: bool = (id == cur)
		for nx in MapGraph.node(id).get("next", []):
			var nx_s: String = str(nx)
			if not (_is_revealed(nx_s) or nx_s in nexts):
				continue
			# 지형 곡선 — 두 노드를 잇는 엣지를 biome 에 맞춰 굽이치게(강=사행/바위=우회/폭풍=흔들림).
			var pts: PackedVector2Array = _edge_polyline(str(id), nx_s, area)
			if from_cur and nx_s in nexts:
				# 지금 갈 수 있는 다음 길 — 붉게(§3). 터치엔 호버가 없으니 이 붉은 길이 "여기로 갈 수 있다" 어포던스.
				_draw_red_path(pts, _node_size(nx_s))
			elif _is_revealed(nx_s):
				# 밟은 길 — 옅은 실선 위에 발자국(원정대가 지나간 자취).
				draw_polyline(pts, Color(ROUTE.r, ROUTE.g, ROUTE.b, 0.4), 1.5)
				_draw_footprints(pts)
			else:
				_draw_dashed_poly(pts, INK_FADE, 2.0)

	# 노드 — 가본 곳은 손그림 장소 심볼+이름, 갈 수 있는 미지는 "?", 나머지는 안 보임.
	for id in MapGraph.NODES:
		var revealed: bool = _is_revealed(id)
		var reachable: bool = id in nexts
		if not (revealed or reachable):
			continue
		var p: Vector2 = _node_screen(str(id), area)
		var ns: float = _node_size(str(id))  # 스펙 per-node 크기(§1)
		if reachable and not _moving and str(id) == _hovered_node:
			# 목적지 호버 — 잉크 손그림 원이 그려진다(§4.2). 평소엔 원 없음: 붉은 길이 "갈 수 있다" 신호(터치 우선).
			_draw_grading_circle(p, ns, CIRC_HOVER, clampf(_hover_t / CIRC_DRAW_HOV, 0.0, 1.0), 1.0, "__hover")
		if revealed:
			_draw_landmark(str(id), str(MapGraph.NODES[id].get("kind", "")), p, ns)
			# 위험 노드(차단·폭풍)엔 원정대가 남긴 경고 표식(방문한 곳만, 아이콘 오른쪽 위).
			var warn_tex: Texture2D = _sketch_tex.get("warn", null)
			var knd: String = str(MapGraph.NODES[id].get("kind", ""))
			if warn_tex != null and (knd == "blockage" or knd == "storm"):
				_draw_sketch(warn_tex, p + Vector2(ns * 0.42, -ns * 0.42), ns * 0.42)
			if font != null:
				# 이름은 아이콘 아래. 옛 스펙 17px 은 너무 컸다(2026-07-12 사용자 — 범례 글씨 크기 수준으로). 크림 후광 + 상태색.
				var lcol: Color = LABEL_MK if (str(id) == cur or id in nexts) else LABEL_DIM
				var lfs: int = maxi(9, int((13.0 if str(id) == "end" else 11.0) * ms))
				# 현재 노드는 채점 원(반지름 ≈ ns×0.55 + 손떨림)이 라벨 줄을 긋고 지나간다(마을 등 큰 노드에서
				# 글자가 원에 깔림, 2026-07-16) — 서 있는 동안만 원 밖으로 내린다.
				var ly: float = ns * 0.5 + 10.0 * ms
				if str(id) == cur:
					ly = ns * 0.58 + 12.0 * ms
				_draw_map_label(font, p + Vector2(-75.0 * ms, ly), _node_display_name(str(id)), 150.0 * ms, lfs, lcol)
				if str(id) == cur:
					# 현재 위치 태그 "원정대" — 노드 위. 삼각형은 절차적으로(장식 유니코드 두부 방지, known_issues §38).
					_draw_expedition_tag(font, p + Vector2(0.0, -ns * 0.5 - 8.0 * ms), ms)
		else:
			# 갈 수 있는 미지 — 노드 크기에 비례한 옅은 원 + 큼직한 "?"(스펙 ??? 19px 상당).
			draw_circle(p, ns * 0.26, Color(INK_FADE.r, INK_FADE.g, INK_FADE.b, 0.20))
			if font != null:
				var qfs: int = maxi(12, int(24.0 * ms))
				draw_string(font, p + Vector2(-qfs * 0.28, qfs * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, qfs, INK_FADE)

	# 흔적 — 이전 원정대들이 노드에 남긴 것(누적된 길/죽음의 역사, self-async).
	_draw_traces(area)
	_draw_stragglers(area)  # 뒤처진 이가 기다리는 자리(재회 축 "구조") — 재회 런의 동선 계획 근거
	_draw_arrows(area)  # 갈림에서 원정대가 실제 간 방향 화살표(선택의 자취)
	# 범례 — 지도 위 바닥 한 줄(좌 칼럼에서 이사). 뷰 줌과 무관하게 고정 크기(화면 요소지 지도 요소가 아님).
	_draw_map_legend(font, _sscale() * BAND.size.x / MAP_W, area)

	# 이동 중 — 지금 걷는 엣지(미방문 노드로 향함)에 마커가 지나온 만큼만 발자국이 실시간으로 남는다.
	if _moving and GameState.current_run != null and GameState.current_run.target_node_id() != "":
		var run: ExpeditionRun = GameState.current_run
		_draw_footprints(_edge_polyline(run.current_node, run.target_node_id(), area), _edge_progress(run))
	# 걸음 잉크 얼룩 — 지나온 자리마다 번져 사라진다(잉크처럼 퍼지는 이동). 마커보다 먼저(아래에) 그린다.
	for sp in _splashes:
		var st: float = clampf(float(sp["t"]) / SPLASH_DUR, 0.0, 1.0)
		draw_circle(sp["pos"], lerpf(3.0, 13.0, st), Color(MARKER_INK.r, MARKER_INK.g, MARKER_INK.b, lerpf(0.32, 0.0, st)))
	# 원정대 마커 — 길 위(이동 중·상황 카드로 멈춤·도착 직후)엔 잉크 방울, 노드에 서 있을 때만 채점 원.
	# (예전엔 _moving 으로만 갈라 상황 카드/도착 시점에 출발지 채점 원이 되살아났다 — 버그 수정.)
	var mp: Vector2 = _marker_pos(area)
	var run_m: ExpeditionRun = GameState.current_run
	var at_node: bool = run_m == null or run_m.target_node_id() == ""
	if not at_node:
		# 원정대 — 길 위에선 대장 한 사람만 걷는다(줄줄이 행렬은 경로 대비 크고 조잡 — 2026-07-12 사용자 폐지).
		var walker: Texture2D = _kit_tex.get("leader", null)
		if walker != null and run_m != null:
			var ahead: Vector2 = _edge_point(run_m.current_node, run_m.target_node_id(), minf(_edge_progress(run_m) + 0.04, 1.0), area)
			draw_circle(mp, 5.0 * ms, Color(MARKER_INK.r, MARKER_INK.g, MARKER_INK.b, 0.16))  # 발밑 잉크 얼룩(위치 표시)
			_draw_sketch_flip(walker, mp + Vector2(0.0, -11.0 * ms), 26.0 * ms, ahead.x < mp.x)
		else:
			draw_circle(mp, 9.0, Color(MARKER_INK.r, MARKER_INK.g, MARKER_INK.b, 0.22))
			draw_circle(mp, 5.5, MARKER_INK)
			draw_arc(mp, 10.0, 0.0, TAU, 22, MARKER_INK, 1.5)
	else:
		if _circle_cur_id != cur:
			# 서 있는 노드가 바뀌었다(도착 후 재진입 등) — 그 노드의 채점 원을 새로 긋는다.
			_circle_cur_id = cur
			_circle_cache[_circle_cur_id] = _gen_grading_circle()
			_circle_cur_t = 0.0
		var dp: float = clampf(_circle_cur_t / CIRC_DRAW_CUR, 0.0, 1.0)
		dp = 1.0 - pow(1.0 - dp, 2.0)                       # ease-out 그려짐
		var pulse: float = 1.0
		if _circle_cur_t > CIRC_DRAW_CUR:
			var ph: float = fmod(_circle_cur_t - CIRC_DRAW_CUR, CIRC_PULSE) / CIRC_PULSE
			pulse = 0.75 - 0.25 * cos(ph * TAU)             # .5↔1 부드러운 점멸
		_draw_grading_circle(mp, _node_size(_circle_cur_id), CIRC_CURRENT, dp, pulse, _circle_cur_id)

## 양피지 띠 렌더 — 회전 가로본(1280×720, 비율 1.778)을 밴드(820×461, 1.779)에 그대로.
## 비율 차 0.1% 미만이라 왜곡 없이 정확히 들어간다(§0 "비율 유지, 잘림 없음").
func _draw_bg_cover(area: Rect2) -> void:
	var tex: Texture2D = _bg_tex_land if _bg_tex_land != null else _bg_tex
	draw_texture_rect(tex, area, false)

## 양피지 지형결 — 은은한 등고선(결정론 sin 곡선). 사막 지도의 결.
func _draw_terrain(area: Rect2) -> void:
	var line_col := Color(INK.r, INK.g, INK.b, 0.06)
	var rows: int = 7
	for i in range(1, rows):
		var base_y: float = area.position.y + area.size.y * float(i) / float(rows)
		var pts: PackedVector2Array = []
		var steps: int = 24
		for s in range(steps + 1):
			var t: float = float(s) / float(steps)
			var x: float = area.position.x + area.size.x * t
			var y: float = base_y + sin(t * TAU * 1.5 + float(i) * 1.3) * 7.0 + sin(t * TAU * 3.0) * 3.0
			pts.append(Vector2(x, y))
		draw_polyline(pts, line_col, 1.5)

## 원정대 손스케치 — 방문한(revealed) 엣지 구간에 그 지형(biome)의 약도를 얹는다(원정대가 지도에 그려넣음).
## 에셋(§12 손스케치)이 없으면 아무것도 안 그린다(백지 — 옛 절차적 지형지물은 폐기). 노드 아이콘·경로와 안 겹치게 엣지 중간에.
func _draw_biomes(area: Rect2) -> void:
	if _sketch_tex.is_empty():
		return
	var cur: String = _current_node_id()
	var nexts: Array = MapGraph.node(cur).get("next", [])
	var sz: float = 68.0 * _mscale()  # 지형 낙서 크기 — 노드보다 살짝 작게(스펙 dd 폭들의 중간값 감각)
	for id in MapGraph.NODES:
		if not _is_revealed(id):
			continue
		for nx in MapGraph.node(id).get("next", []):
			var nx_s: String = str(nx)
			if not (_is_revealed(nx_s) or nx_s in nexts):
				continue
			var tex: Texture2D = _sketch_tex.get(MapGraph.biome_of(nx_s), null)
			if tex != null:
				# 직선(chord) 중간에 장애물(지형)을 두면, 곡선(경로)이 그 옆으로 우회한다 — "피해 돌아가는 길".
				var mid: Vector2 = (_node_screen(str(id), area) + _node_screen(nx_s, area)) * 0.5
				_draw_sketch(tex, mid, sz)

## 손스케치 텍스처를 중심점에 종횡비 유지로 얹는다(긴 변 = target).
func _draw_sketch(tex: Texture2D, center: Vector2, target: float) -> void:
	var tw: float = float(tex.get_width())
	var th: float = float(tex.get_height())
	if tw <= 0.0 or th <= 0.0:
		return
	var sc: float = target / maxf(tw, th)
	var wh: Vector2 = Vector2(tw * sc, th * sc)
	draw_texture_rect(tex, Rect2(center - wh * 0.5, wh), false)

## 손스케치를 세로 크기 기준으로, 필요 시 좌우 반전해 얹는다(행렬 — 걷는 방향 맞춤). target_h = 높이(px).
func _draw_sketch_flip(tex: Texture2D, center: Vector2, target_h: float, flip_h: bool) -> void:
	var tw: float = float(tex.get_width())
	var th: float = float(tex.get_height())
	if tw <= 0.0 or th <= 0.0:
		return
	var sc: float = target_h / th
	var wh: Vector2 = Vector2(tw * sc, th * sc)
	draw_set_transform(center, 0.0, Vector2(-1.0 if flip_h else 1.0, 1.0))
	draw_texture_rect(tex, Rect2(-wh * 0.5, wh), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 손스케치를 rot 만큼 회전해 얹는다(화살표 방향 맞춤용).
func _draw_sketch_rot(tex: Texture2D, center: Vector2, target: float, rot: float) -> void:
	var tw: float = float(tex.get_width())
	var th: float = float(tex.get_height())
	if tw <= 0.0 or th <= 0.0:
		return
	var sc: float = target / maxf(tw, th)
	var wh: Vector2 = Vector2(tw * sc, th * sc)
	draw_set_transform(center, rot, Vector2.ONE)
	draw_texture_rect(tex, Rect2(-wh * 0.5, wh), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 화살표 — 갈림 노드에서 원정대가 실제 간 방향(방문한 next 로)을 엣지 초입에 회전해 얹는다.
func _draw_arrows(area: Rect2) -> void:
	var arrow: Texture2D = _sketch_tex.get("arrow", null)
	if arrow == null:
		return
	var sz: float = 42.0 * _mscale()  # 화살표 낙서(스펙 dd_arrow w60 언저리)
	for id in MapGraph.NODES:
		if not _is_revealed(id):
			continue
		var node_nexts: Array = MapGraph.node(id).get("next", [])
		if node_nexts.size() < 2:
			continue  # 갈림(분기)에서만 — 외길엔 안 그린다(발자국으로 충분)
		for nx in node_nexts:
			var nx_s: String = str(nx)
			if not _is_revealed(nx_s):
				continue  # 실제 간 곳(방문)만
			var a: Vector2 = _edge_point(str(id), nx_s, 0.24, area)
			var b: Vector2 = _edge_point(str(id), nx_s, 0.4, area)
			_draw_sketch_rot(arrow, a, sz, (b - a).angle() - ARROW_BASE)

## 양피지 가장자리 — 낡아 그을린 테두리(비네팅 대용, 셰이더 없이).
func _draw_paper_edge(area: Rect2) -> void:
	draw_rect(area, PAPER_EDGE, false, 3.0)
	var inset: float = 6.0
	draw_rect(Rect2(area.position + Vector2(inset, inset), area.size - Vector2(inset, inset) * 2.0), Color(PAPER_EDGE.r, PAPER_EDGE.g, PAPER_EDGE.b, 0.3), false, 1.5)

## 노드 아이콘 — 손그림 텍스처를 노드 위에 얹는다(종횡비 유지). 없으면 절차적 심볼 fallback.
func _draw_landmark(id: String, kind: String, p: Vector2, icon_max: float) -> void:
	var tex: Texture2D = _icon_tex.get(id, null)
	if tex == null:
		_draw_landmark_symbol(kind, p)
		return
	var tw: float = float(tex.get_width())
	var th: float = float(tex.get_height())
	if tw <= 0.0 or th <= 0.0:
		_draw_landmark_symbol(kind, p)
		return
	# 잉크 reveal — 방금 도착한 노드는 작고 흐리게 시작해 커지며 진해진다(웹 안전, modulate+scale).
	var rt: float = 1.0
	if id == _reveal_id and _reveal_t < REVEAL_DUR:
		rt = smoothstep(0.0, 1.0, clampf(_reveal_t / REVEAL_DUR, 0.0, 1.0))
	var eff: float = icon_max * lerpf(0.72, 1.0, rt)
	var scale: float = eff / maxf(tw, th)
	var sz: Vector2 = Vector2(tw * scale, th * scale)
	draw_texture_rect(tex, Rect2(p - sz * 0.5, sz), false, Color(1.0, 1.0, 1.0, rt))

## 손그림 장소 심볼 (kind별) — 세피아 잉크. 점이 아니라 "장소"로 읽히게. (아이콘 로드 실패 시 fallback)
func _draw_landmark_symbol(kind: String, p: Vector2) -> void:
	match kind:
		"start":  # 마을 — 작은 천막
			var roof: PackedVector2Array = [p + Vector2(-9, 6), p + Vector2(0, -9), p + Vector2(9, 6)]
			draw_polyline(roof, INK, 2.0)
			draw_line(p + Vector2(-9, 6), p + Vector2(9, 6), INK, 2.0)
		"cache":  # 자원 — 우물(이중 원)
			draw_arc(p, 8.0, 0.0, TAU, 20, INK, 2.0)
			draw_circle(p, 2.5, INK)
		"blockage":  # 차단 — 갈라진 틈(지그재그)
			var zz: PackedVector2Array = [p + Vector2(-8, -7), p + Vector2(-2, 0), p + Vector2(-6, 3), p + Vector2(2, 8)]
			draw_polyline(zz, INK, 2.0)
		"storm":  # 폭풍 — 소용돌이(나선 두 겹)
			draw_arc(p, 8.0, 0.4, 0.4 + TAU * 0.8, 18, INK, 2.0)
			draw_arc(p, 4.5, 1.0, 1.0 + TAU * 0.7, 14, INK, 2.0)
		"end":  # 목적지 — 깃발
			draw_line(p + Vector2(-1, 9), p + Vector2(-1, -9), INK, 2.0)
			var flag: PackedVector2Array = [p + Vector2(-1, -9), p + Vector2(9, -5), p + Vector2(-1, -1)]
			draw_colored_polygon(flag, INK)
		_:
			draw_circle(p, 5.0, INK)

## 점선(곡선) — 미지로 향하는 길(아직 안 밟음). 폴리라인 샘플을 따라 dash/gap 을 세그먼트 넘어 이어 배치.
func _draw_dashed_poly(pts: PackedVector2Array, col: Color, w: float) -> void:
	var dash: float = 7.0
	var gap: float = 5.0
	var acc: float = 0.0        # 현재 dash/gap 구간에서 채운 길이
	var draw_on: bool = true    # 지금 그리는 중인가(dash) 쉬는 중인가(gap)
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var seg: float = a.distance_to(b)
		if seg < 0.01:
			continue
		var dir: Vector2 = (b - a) / seg
		var pos: float = 0.0
		while pos < seg:
			var target: float = dash if draw_on else gap
			var step: float = minf(target - acc, seg - pos)
			if draw_on:
				draw_line(a + dir * pos, a + dir * (pos + step), col, w)
			pos += step
			acc += step
			if acc >= target - 0.001:
				draw_on = not draw_on
				acc = 0.0

## 노드별 흔적 마커 — 죽음 X·로프 다리·자원 점. 가본 노드에만(흔적은 가본 곳에서만 생긴다).
## 낙오자 마커 — 그 노드에 뒤처진 이가 기다린다(재회 축 "구조"). 보임 규칙은 흔적과 동일(방문 + 다음 노드).
## 위치 = 아이콘 오른쪽 옆구리 — 왼쪽의 흔적 스택과 안 겹친다.
func _draw_stragglers(area: Rect2) -> void:
	var ms: float = _mscale()
	for nid in GameState.straggler_nodes():
		var s: String = str(nid)
		if not MapGraph.NODES.has(s):
			continue
		if not _is_revealed(s) and not _is_next_choice(s):
			continue
		var base: Vector2 = _node_screen(s, area)
		var half: float = _node_size(s) * 0.5
		_draw_person(base + Vector2(half + 12.0 * ms, -2.0 * ms), ms)
	# 그들이 선 자리 — 순환을 본 세계에선 end 곁에 서 있는 사람이 보인다(순환의 물리적 반영, 2026-07-15).
	# 왼쪽 옆구리 + 선 자세 — 오른쪽의 웅크린 낙오자(구조 대상)와 자리·자세 둘 다로 구별된다.
	if GameState.cycle_arrival_count() > 0 and (_is_revealed("end") or _is_next_choice("end")):
		var ebase: Vector2 = _node_screen("end", area)
		var ehalf: float = _node_size("end") * 0.5
		_draw_stander(ebase + Vector2(-(ehalf + 12.0 * ms), -2.0 * ms), ms)

## 노드 표시 이름 — 순환을 한 번이라도 본 세계에선 end 가 "???"를 벗는다(플레이어가 이미 아는 진실을
## 지도가 계속 감추지 않는다). 재회 순례의 목적지가 계획 화면에 상주하는 효과.
func _node_display_name(id: String) -> String:
	if id == "end" and GameState.cycle_arrival_count() > 0:
		return "그들이 선 자리"
	return str(MapGraph.NODES[id].get("name", ""))

## 서 있는 사람 — 밀려나 재앙의 자리에 선 이전 순환 원정대(절차적 실루엣, 웅크린 낙오자와 구별).
func _draw_stander(at: Vector2, ms: float) -> void:
	var ink := Color(0.36, 0.24, 0.16, 0.92)
	draw_circle(at, 13.0 * ms, Color(0.86, 0.66, 0.38, 0.18))  # 옅은 온기 무리(사람 신호 계열)
	draw_circle(at + Vector2(0.0, -8.5 * ms), 2.6 * ms, ink)
	draw_line(at + Vector2(0.0, -5.5 * ms), at + Vector2(0.0, 4.6 * ms), ink, 1.9 * ms, true)
	# 두른 천 — 어깨에서 곧게 떨어지는 획 둘(선 자세).
	draw_line(at + Vector2(-2.6 * ms, -3.6 * ms), at + Vector2(-3.0 * ms, 3.0 * ms), ink, 1.4 * ms, true)
	draw_line(at + Vector2(2.6 * ms, -3.6 * ms), at + Vector2(3.0 * ms, 3.0 * ms), ink, 1.4 * ms, true)
	draw_line(at + Vector2(-1.4 * ms, 4.6 * ms), at + Vector2(-1.8 * ms, 8.2 * ms), ink, 1.5 * ms, true)
	draw_line(at + Vector2(1.4 * ms, 4.6 * ms), at + Vector2(1.8 * ms, 8.2 * ms), ink, 1.5 * ms, true)

## 손그림 사람(웅크린 낙오자) — 킷 텍스처(잉크판/밝음판), 없으면 절차적 실루엣 fallback.
## lit=true 는 어두운 배경(좌 칼럼 범례)용 아이보리판.
func _draw_person(at: Vector2, ms: float, lit: bool = false) -> void:
	var tex: Texture2D = _kit_tex.get("straggler_lit" if lit else "straggler", null)
	if tex != null:
		if not lit:
			draw_circle(at, 14.0 * ms, Color(0.86, 0.66, 0.38, 0.18))  # 옅은 온기 무리(사람이 있다는 신호)
		_draw_sketch(tex, at, 25.0 * ms)   # 사용자: 작아서 안 보임 → 확대(2026-07-12)
		return
	var ink := Color(0.36, 0.24, 0.16, 0.92) if not lit else Color(0.91, 0.87, 0.80, 0.92)
	if not lit:
		draw_circle(at, 9.5 * ms, Color(0.86, 0.66, 0.38, 0.18))
	draw_circle(at + Vector2(0.0, -6.5 * ms), 2.6 * ms, ink)
	# 웅크린 몸 — 어깨에서 바닥으로 퍼지는 획 셋(둘러쓴 천).
	draw_line(at + Vector2(-3.2 * ms, -3.2 * ms), at + Vector2(-4.4 * ms, 4.2 * ms), ink, 1.6 * ms, true)
	draw_line(at + Vector2(0.0, -3.6 * ms), at + Vector2(0.0, 4.6 * ms), ink, 1.8 * ms, true)
	draw_line(at + Vector2(3.2 * ms, -3.2 * ms), at + Vector2(4.4 * ms, 4.2 * ms), ink, 1.6 * ms, true)

## 위치 = 아이콘 왼쪽 옆구리(세로 중앙) — 라벨(아이콘 아래)·경고 표식(오른쪽 위)·원정대 태그(위)를 전부 피한다.
## (예전 왼쪽 아래(half+6)는 라벨 글자 줄과 정확히 겹쳤다 — 2026-07-06 사용자 지적.) 여러 개면 위로 쌓는다.
func _draw_traces(area: Rect2) -> void:
	var ms: float = _mscale()
	_trace_hitboxes.clear()
	var active_marks: Array = []          # 활성(호버/탭) 흔적 표식: [{x, y, tags}]
	# 노드에 쌓이는 흔적은 노드별로 모아 우선순위로 정리한다(오래 쌓이면 겹쳐 안 읽히던 것 방지).
	# 엣지 위 흔적(이동 중 남김)은 경로를 따라 흩어져 있어 겹침이 없어 그대로 즉시 그린다.
	var node_groups: Dictionary = {}      # nid -> Array[{tr, seq}]  (seq = 남긴 순서, 클수록 최근)
	var seq: int = 0
	for tr in GameState.loaded_traces():
		var nid: String = tr.node_id
		if nid == "" or not MapGraph.NODES.has(nid):
			continue
		# 방문한 노드 + 바로 갈 수 있는 다음 노드(미방문 "?"도)에 표식을 보인다 — 경로 전에 읽게(정체는 감춘 채).
		if not _is_revealed(nid) and not _is_next_choice(nid):
			continue
		if tr.to_node != "" and MapGraph.NODES.has(tr.to_node):
			# 이동 중 남긴 것 — 엣지 node_id→to_node 위 실제 지점(양 끝 노드에 안 겹치게 살짝 안쪽).
			var ep: Vector2 = _edge_point(nid, tr.to_node, clampf(tr.position, 0.06, 0.94), area)
			_draw_trace_marker(ep, tr.object_kind, ms)
			_trace_hitboxes.append({"pos": ep, "nid": nid})
			if nid == _active_trace and not tr.tags.is_empty():
				active_marks.append({"x": ep.x, "y": ep.y + 26.0 * ms, "tags": tr.tags})
		else:
			if not node_groups.has(nid):
				node_groups[nid] = []
			node_groups[nid].append({"tr": tr, "seq": seq})
		seq += 1
	# 노드별 스택 — 우선순위(다리 > 아직 줄 수 있는 자원/도구 > 시체·소진·표식), 같은 층은 최근 먼저.
	# 최대 MAX 개만 보이고, 넘치면 (MAX-1)개 + "+K" 로 정리한다(노드당 마커가 무한히 높아지지 않게).
	for nid in node_groups:
		var group: Array = node_groups[nid]
		group.sort_custom(_trace_sort)
		var base: Vector2 = _node_screen(nid, area)
		var half: float = _node_size(nid) * 0.5
		var total: int = group.size()
		var shown: int = total if total <= MAX_TRACE_MARKERS else MAX_TRACE_MARKERS - 1
		for i in range(shown):
			var entry: Dictionary = group[i]
			var tr: TraceData = entry["tr"]
			var rp: Vector2 = base + Vector2(-half - 9.0 * ms, 2.0 * ms - float(i) * 15.0 * ms)
			_draw_trace_marker(rp, tr.object_kind, ms)
			_trace_hitboxes.append({"pos": rp, "nid": nid})   # 호버·탭 히트박스
			if nid == _active_trace and not tr.tags.is_empty():
				# 아이콘 스택 바로 아래 — 두루마리가 차례로 펼쳐진다(2026-07-12 사용자: 노드 이름 밑 흐린 글씨 폐지).
				active_marks.append({"x": rp.x, "y": base.y + (28.0 + float(i) * 30.0) * ms, "tags": tr.tags})
		if total > shown:   # 넘친 것 — "+K" 로 요약(그 자리에 더 있다는 표시)
			var op: Vector2 = base + Vector2(-half - 9.0 * ms, 2.0 * ms - float(shown) * 15.0 * ms)
			_draw_trace_overflow(op, total - shown, ms)
	# 활성 흔적의 표식 단어 — 가죽 두루마리가 아이콘 아래로 펼쳐진다(호버/탭으로만).
	# 바닥(범례 띠) 근처에선 아래(큰 y)부터 자리를 잡고 위로 차곡차곡 — 클램프로 겹치지 않게.
	if not active_marks.is_empty():
		var font: Font = get_theme_default_font()
		if font != null:
			var open: float = clampf(_trace_open_t / 0.22, 0.0, 1.0)
			open = 1.0 - pow(1.0 - open, 2.0)   # ease-out 펼침
			var sfs: int = maxi(9, int(12.5 * ms))
			var sh: float = float(sfs) * 1.95 + 6.0 * ms
			active_marks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) > float(b["y"]))
			var cap: float = area.end.y - 46.0 * ms
			for m in active_marks:
				var yy: float = minf(float(m["y"]), cap)
				cap = yy - sh
				_draw_trace_scroll(font, Vector2(float(m["x"]), yy), m["tags"], ms, open, area)

## 흔적 스택 정렬 — 우선순위 높은(행동 가능한·최근) 것을 노드 가까이(아래) 둔다. a 가 앞(더 중요)이면 true.
func _trace_sort(a: Dictionary, b: Dictionary) -> bool:
	var pa: int = _trace_priority(a["tr"])
	var pb: int = _trace_priority(b["tr"])
	if pa != pb:
		return pa > pb
	return int(a["seq"]) > int(b["seq"])   # 같은 우선순위면 최근(늦게 남긴) 것 먼저

## 흔적 표시 우선순위 — 클수록 먼저 보인다. 다리(영구·행동) > 아직 줄 수 있는 자원/도구 > 시체·소진·표식(정보·정서).
func _trace_priority(tr: TraceData) -> int:
	if tr.object_kind == TraceData.ObjectKind.ROPE:
		return 3
	if TraceData.is_pickable(tr.object_kind) and tr.uses > 0:
		return 2
	return 1

## 넘친 흔적 요약 — "+K" 작은 잉크 글씨(그 자리에 더 있다는 표시). 노드당 마커가 무한히 높아지지 않게.
func _draw_trace_overflow(p: Vector2, count: int, ms: float) -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		return
	var bg: Texture2D = _kit_tex.get("overflow", null)
	if bg != null:
		_draw_sketch(bg, p, 24.0 * ms)  # 크림 얼룩 배지(구운 것) — 숫자는 폰트가 쓴다. 확대(2026-07-12)
	else:
		draw_circle(p, 7.5 * ms, Color(LABEL_HALO.r, LABEL_HALO.g, LABEL_HALO.b, 0.42))
	var txt: String = "+%d" % count
	var fs: int = maxi(8, int(11.0 * ms))
	var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, p + Vector2(-tw * 0.5, float(fs) * 0.34), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TRACE_MARK_INK)

## 흔적 표식 단어(WordPool 태그) — 갈색 가죽 두루마리가 펼쳐지고 그 위에 크림 글씨(2026-07-12 사용자).
## 이 게임의 심장(기획서 §3): 태그 = 다음 원정대와의 소통. 평소엔 아이콘만, 호버/탭 때만 펼친다.
## open = 펼침 진행(0~1, 가운데서 양옆으로). 지도 밖으로 삐지지 않게 area 안으로 민다.
func _draw_trace_scroll(font: Font, center: Vector2, tags: Array, ms: float, open: float, area: Rect2) -> void:
	var text: String = "[ %s ]" % " · ".join(PackedStringArray(tags))
	var fs: int = maxi(9, int(12.5 * ms))
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var full_w: float = tw + 34.0 * ms
	var h: float = float(fs) * 1.95
	# 지도 안으로 — 가장자리 흔적도 두루마리가 잘리지 않게 중심을 민다(세로는 호출측이 배정).
	center.x = clampf(center.x, area.position.x + full_w * 0.5 + 8.0, area.end.x - full_w * 0.5 - 8.0)
	var wgt: float = full_w * (0.22 + 0.78 * clampf(open, 0.0, 1.0))
	var r := Rect2(center - Vector2(wgt * 0.5, h * 0.5), Vector2(wgt, h))
	var leather := Color(0.286, 0.196, 0.118, 0.95)
	var edge := Color(0.173, 0.110, 0.063, 0.95)
	draw_rect(Rect2(r.position + Vector2(1.5, 2.5), r.size), Color(0.0, 0.0, 0.0, 0.22))  # 낙하 그림자
	draw_rect(r, leather)
	draw_rect(Rect2(r.position, Vector2(r.size.x, h * 0.18)), Color(1.0, 1.0, 1.0, 0.05))  # 윗면 하이라이트(가죽 결)
	draw_rect(r, edge, false, maxf(1.0, 1.3 * ms))
	# 양끝 말림(롤) — 세로로 도톰한 축.
	var roll := Color(0.357, 0.247, 0.149, 0.98)
	var roll_w: float = 6.5 * ms
	var rl := Rect2(Vector2(r.position.x - roll_w * 0.5, r.position.y - h * 0.07), Vector2(roll_w, h * 1.14))
	var rr := Rect2(Vector2(r.end.x - roll_w * 0.5, r.position.y - h * 0.07), Vector2(roll_w, h * 1.14))
	draw_rect(rl, roll)
	draw_rect(rr, roll)
	draw_rect(rl, edge, false, 1.0)
	draw_rect(rr, edge, false, 1.0)
	if open > 0.5:
		var ta: float = clampf((open - 0.5) / 0.5, 0.0, 1.0)
		draw_string(font, Vector2(center.x - tw * 0.5, center.y + float(fs) * 0.36), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.918, 0.855, 0.729, ta))

## 흔적 아이콘 히트테스트 — 위치에 흔적 아이콘이 있으면 그 노드 id(호버·탭 판정 공용).
func _trace_at(pos: Vector2) -> String:
	var best: String = ""
	# 터치(폰)는 손가락 오차만큼 판정을 넉넉히(2026-07-12 — 흔적 표식이 안 열린다는 제보 방어).
	var best_d: float = (38.0 if DisplayServer.is_touchscreen_available() else 28.0) * _mscale()
	for hb in _trace_hitboxes:
		var d: float = pos.distance_to(hb["pos"])
		if d <= best_d:
			best_d = d
			best = str(hb["nid"])
	return best

func _draw_trace_marker(p: Vector2, kind: int, ms: float = 1.0) -> void:
	match kind:
		TraceData.ObjectKind.BODY:
			# 죽은 자리 — 원정대가 남긴 해골 스케치(있으면), 없으면 작은 X.
			var skull: Texture2D = _sketch_tex.get("skull", null)
			if skull != null:
				_draw_sketch(skull, p, 18.0 * ms)
			else:
				var s: float = 4.5 * ms
				draw_line(p + Vector2(-s, -s), p + Vector2(s, s), UITheme.DANGER, 2.0)
				draw_line(p + Vector2(-s, s), p + Vector2(s, -s), UITheme.DANGER, 2.0)
		TraceData.ObjectKind.ROPE:
			var rb: Texture2D = _kit_tex.get("rope_bridge", null)
			if rb != null:
				_draw_sketch(rb, p, 30.0 * ms)  # 로프 다리(말뚝 두 개에 걸린 밧줄, 후광 구움) — 확대(2026-07-12)
			else:
				draw_line(p + Vector2(-5.0 * ms, 0.0), p + Vector2(5.0 * ms, 0.0), UITheme.SAND, 2.5)
		TraceData.ObjectKind.WATER:
			_draw_resource_dot(p, TRACE_WATER, ms)
		TraceData.ObjectKind.FOOD:
			_draw_resource_dot(p, TRACE_FOOD, ms)
		TraceData.ObjectKind.SHELTER:
			_draw_resource_dot(p, TRACE_SHELTER, ms)
		TraceData.ObjectKind.MEDICINE, TraceData.ObjectKind.FLINT, TraceData.ObjectKind.FILTER:
			_draw_resource_dot(p, TRACE_TOOL, ms)   # 남긴 주머니 도구 — 호버하면 표식·줍기 카드가 무엇인지 알려준다
		_:
			draw_circle(p, 2.5 * ms, UITheme.MUTED)

## 자원 점 — 잉크 링+크림 후광(킷 텍스처, 구운 것) 위에 안료색 점(자원 색 구분은 코드가 찍는다).
## 킷 없으면 기존 절차적(웅덩이+점+링) fallback.
func _draw_resource_dot(p: Vector2, pigment: Color, ms: float) -> void:
	var ring: Texture2D = _kit_tex.get("trace_ring", null)
	if ring != null:
		_draw_sketch(ring, p, 31.0 * ms)   # 확대(2026-07-12)
		draw_circle(p, 4.6 * ms, pigment)
		return
	draw_circle(p, 8.5 * ms, Color(LABEL_HALO.r, LABEL_HALO.g, LABEL_HALO.b, 0.45))
	draw_circle(p, 4.2 * ms, pigment)
	draw_arc(p, 4.6 * ms, 0.0, TAU, 20, Color(INK.r, INK.g, INK.b, 0.75), maxf(1.0, 1.3 * ms), true)

# --- 여백 칼럼(§6) — 각인형: 헤어라인 + 텍스트, 상자 없음 ---

## 스펙 헤어라인 — 왼쪽이 밝고 오른쪽으로 잦아드는 1px 모래선(3단 근사).
## 좌 "지닌 것" 칼럼 — 자원 4행(값 Cinzel·이름) + 행렬 + 주머니 + 통계. STAGE (36,140) w172(§6).
## 루트 _draw 에서 분리한 각인 크롬 Control(2026-07-14, backlog 분위기 (c)): 전환 흩어짐(ui_scatter)은
## CanvasItem 단위라 루트에 그리면 지도(배경)와 한 몸 — 분리해야 크롬만 흩어진다. 배치는 _layout_chrome.
class LeftColumn extends Control:
	const EN_TITLE_FONT := preload("res://assets/fonts/Cinzel.ttf")  ## 수치 전용(preload 캐시 공유)
	var sc: float = 1.0  ## STAGE 스케일 — Map._layout_chrome 이 넣어준다

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE  # 정보 표시 전용 — 지도 입력(루트 _gui_input)을 막지 않는다

	## 내용·간격은 옛 Map._draw_col_left 그대로 — 좌표만 로컬(콘트롤 상단 = STAGE 140, 첫 베이스라인 158 → 18·sc).
	func _draw() -> void:
		var run: ExpeditionRun = GameState.current_run
		if run == null:
			return
		var font: Font = get_theme_default_font()
		if font == null:
			font = ThemeDB.fallback_font
		if font == null:
			return
		var x: float = 0.0
		var w: float = size.x
		var y: float = 18.0 * sc
		draw_string(EN_TITLE_FONT, Vector2(x, y), "CARRIED", HORIZONTAL_ALIGNMENT_LEFT, w, maxi(8, int(10.0 * sc)), Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.6))
		y += 26.0 * sc
		draw_string(font, Vector2(x, y), "지닌 것", HORIZONTAL_ALIGNMENT_LEFT, w, maxi(12, int(22.0 * sc)), UITheme.FG)
		y += 14.0 * sc
		_draw_hairline(x, y, w)
		var rows: Array = [
			["water", "물"],
			["food", "식량"],
			["rope", "로프"],
			["shelter", "장막"],
		]
		for r in rows:
			y += 30.0 * sc
			# 한 줄: 값(Cinzel) + 이름 — 효과 설명 글은 뺐다(2026-07-12 사용자, 뜻은 튜토리얼·일지가 맡는다).
			draw_string(EN_TITLE_FONT, Vector2(x, y), str(run.get_res(str(r[0]))), HORIZONTAL_ALIGNMENT_LEFT, 30.0 * sc, maxi(11, int(21.0 * sc)), UITheme.SAND)
			draw_string(font, Vector2(x + 36.0 * sc, y), str(r[1]), HORIZONTAL_ALIGNMENT_LEFT, w - 36.0 * sc, maxi(10, int(17.0 * sc)), Color(0.910, 0.875, 0.804))
		# 행렬 — 함께 걷는 사람 수(연출 파티). 위험한 순간마다 줄어든다. 잃은 뒤엔 붉게(온전함이 깨졌다).
		y += 30.0 * sc
		var party_color: Color = UITheme.SAND if run.is_intact() else UITheme.DANGER
		draw_string(EN_TITLE_FONT, Vector2(x, y), str(run.party_left()), HORIZONTAL_ALIGNMENT_LEFT, 30.0 * sc, maxi(11, int(21.0 * sc)), party_color)
		draw_string(font, Vector2(x + 36.0 * sc, y), "행렬", HORIZONTAL_ALIGNMENT_LEFT, w - 36.0 * sc, maxi(10, int(17.0 * sc)), Color(0.910, 0.875, 0.804))
		# 행렬 줄 — 단순 실루엣(대장은 크게), 잃은 자리는 낮은 무더기. 세밀한 픽토그램 원화는
		# 이 크기에서 뭉개져 뭘 그렸는지 안 읽혔다(2026-07-12 사용자) — 작게 보는 용은 절차 실루엣.
		y += 30.0 * sc
		var slots: int = 1 + ExpeditionRun.PARTY_MATES + run.party_gained
		var step_x: float = minf(26.0 * sc, (w - 18.0 * sc) / maxf(1.0, float(slots)))
		var left_cnt: int = run.party_left()
		var ivory := Color(0.910, 0.875, 0.804, 0.95)
		for i in range(slots):
			var fx: float = x + 9.0 * sc + step_x * float(i)
			if i < left_cnt:
				var pc: Color = ivory if i == 0 else Color(ivory.r, ivory.g, ivory.b, 0.7)
				if i > 0 and i >= left_cnt - run.party_gained:
					# 거둔 이 — 따뜻한 모래빛(거두기 팝업과 같은 색 언어). 행렬 끝에서 함께 걷는 게 보인다.
					pc = Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.9)
				_draw_person_glyph(Vector2(fx, y - 8.0 * sc), (22.0 if i == 0 else 17.0) * sc, pc)
			else:
				_draw_mound_glyph(Vector2(fx, y - 8.0 * sc), 16.0 * sc, Color(0.60, 0.53, 0.42, 0.8))
		y += 14.0 * sc
		_draw_hairline(x, y, w)
		y += 24.0 * sc
		draw_string(font, Vector2(x, y), "주머니", HORIZONTAL_ALIGNMENT_LEFT, w, maxi(9, int(13.0 * sc)), Color(0.62, 0.56, 0.46))
		var tools: Array = []
		for tk in Items.POUCH_TOOLS:
			if int(run.get_res(str(tk))) > 0:
				tools.append(Items.label_of(str(tk)))
		var tl: String = (" · ".join(PackedStringArray(tools))) if not tools.is_empty() else "비었다"
		y += 21.0 * sc
		draw_string(font, Vector2(x, y), tl, HORIZONTAL_ALIGNMENT_LEFT, w, maxi(9, int(15.0 * sc)), Color(0.788, 0.718, 0.565))

		# 통계 한 줄(컴팩트). 범례는 지도 위 바닥 한 줄로 이사(2026-07-12 사용자 — _draw_map_legend).
		y += 18.0 * sc
		_draw_hairline(x, y, w)
		y += 24.0 * sc
		draw_string(font, Vector2(x, y), "원정 %d · 흔적 %d · 죽음 %d" % [GameState.expedition_count, GameState.traces.size(), GameState.deaths.size()], HORIZONTAL_ALIGNMENT_LEFT, w, maxi(8, int(11.5 * sc)), Color(0.529, 0.475, 0.376))

	func _draw_hairline(x: float, y: float, w: float) -> void:
		var s := UITheme.SAND
		draw_line(Vector2(x, y), Vector2(x + w * 0.4, y), Color(s.r, s.g, s.b, 0.32), 1.0, true)
		draw_line(Vector2(x + w * 0.4, y), Vector2(x + w * 0.75, y), Color(s.r, s.g, s.b, 0.14), 1.0, true)
		draw_line(Vector2(x + w * 0.75, y), Vector2(x + w, y), Color(s.r, s.g, s.b, 0.04), 1.0, true)

	## 작은 사람 실루엣(머리 + 몸 캡슐) — 행렬 줄. 작은 크기에서도 사람으로 읽힌다.
	func _draw_person_glyph(at: Vector2, h: float, col: Color) -> void:
		draw_circle(at + Vector2(0.0, -h * 0.30), h * 0.17, col)
		draw_line(at + Vector2(0.0, -h * 0.06), at + Vector2(0.0, h * 0.40), col, h * 0.36, true)

	## 스러진 자리 — 낮은 모래 무더기(반원).
	func _draw_mound_glyph(at: Vector2, h: float, col: Color) -> void:
		var pts: PackedVector2Array = PackedVector2Array()
		for k in range(9):
			var a: float = PI + PI * float(k) / 8.0
			pts.append(at + Vector2(cos(a) * h * 0.42, h * 0.40 + sin(a) * h * 0.34))
		draw_colored_polygon(pts, col)

## 지도 위 범례 — 양피지 바닥 왼쪽 한 줄(잉크 톤). 좌 칼럼에서 이사(2026-07-12 사용자 — 지도 확대와 한 몸).
func _draw_map_legend(font: Font, ms: float, area: Rect2) -> void:
	if font == null:
		return
	var fs: int = maxi(9, int(11.0 * ms))
	var tcol := Color(LABEL_DIM.r, LABEL_DIM.g, LABEL_DIM.b, 0.9)
	var lx: float = area.position.x + 34.0 * ms
	var ly: float = area.end.y - 30.0 * ms   # 양피지 그을린 테두리·장식선 위로 올린다
	var gap: float = 17.0 * ms
	# 폭 측정 → 크림 배경 띠 — 지도 그림에 범례가 묻히지 않게(2026-07-12 사용자).
	var total: float = 24.0 * ms + _legend_tw(font, "갈 수 있는 곳", fs) + gap
	if _sketch_tex.get("skull", null) != null:
		total += 17.0 * ms
	total += _legend_tw(font, "죽은 자리", fs) + gap
	total += 17.0 * ms + _legend_tw(font, "뒤처진 이", fs) + gap
	if _sketch_tex.get("warn", null) != null:
		total += 17.0 * ms + _legend_tw(font, "위험", fs) + gap
	total += 42.0 * ms + _legend_tw(font, "남긴 물·식량·장막", fs)
	var band := Rect2(lx - 12.0 * ms, ly - fs * 1.2, total + 24.0 * ms, fs * 1.2 + 10.0 * ms)
	draw_rect(band, Color(LABEL_HALO.r, LABEL_HALO.g, LABEL_HALO.b, 0.62))
	draw_rect(band, Color(INK.r, INK.g, INK.b, 0.28), false, 1.0)
	# 갈 수 있는 곳 — 붉은 길 토막.
	draw_line(Vector2(lx, ly - fs * 0.32), Vector2(lx + 18.0 * ms, ly - fs * 0.32), RED_PATH, 2.4, true)
	lx += 24.0 * ms
	lx = _legend_text(font, lx, ly, "갈 수 있는 곳", fs, tcol) + gap
	# 죽은 자리 — 해골 낙서.
	var skull: Texture2D = _sketch_tex.get("skull", null)
	if skull != null:
		_draw_sketch(skull, Vector2(lx + 7.0 * ms, ly - fs * 0.32), 15.0 * ms)
		lx += 17.0 * ms
	lx = _legend_text(font, lx, ly, "죽은 자리", fs, tcol) + gap
	# 뒤처진 이 — 웅크린 사람.
	_draw_person(Vector2(lx + 7.0 * ms, ly - fs * 0.32), ms * 0.62)
	lx += 17.0 * ms
	lx = _legend_text(font, lx, ly, "뒤처진 이", fs, tcol) + gap
	# 위험 표식.
	var warn: Texture2D = _sketch_tex.get("warn", null)
	if warn != null:
		_draw_sketch(warn, Vector2(lx + 7.0 * ms, ly - fs * 0.32), 15.0 * ms)
		lx += 17.0 * ms
		lx = _legend_text(font, lx, ly, "위험", fs, tcol) + gap
	# 남긴 자원 점 셋 — 글 순서대로 물·식량·장막(색↔자원 대응).
	var trace_cols: Array = [TRACE_WATER, TRACE_FOOD, TRACE_SHELTER]
	for i in trace_cols.size():
		var tc: Color = trace_cols[i]
		_draw_resource_dot(Vector2(lx + (6.0 + 13.0 * float(i)) * ms, ly - fs * 0.32), tc, ms * 0.62)
	lx += 42.0 * ms
	_legend_text(font, lx, ly, "남긴 물·식량·장막", fs, tcol)

## 범례 글씨 한 토막 — 그린 끝 x 를 돌려준다(다음 항목이 이어 붙게).
func _legend_text(font: Font, x: float, y: float, text: String, fs: int, col: Color) -> float:
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	return x + _legend_tw(font, text, fs)

func _legend_tw(font: Font, text: String, fs: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

# --- "살아있는 잉크" 헬퍼 (핸드오프 MAP_지도화면.md §2~4) ---

## 손그림 채점 O 생성(§4.1) — 240 viewBox·중심(0,0) 기준 오프셋 폴리라인. 잉크 거칠기(점별 미세 노이즈)를 구워 넣는다.
## _draw 밖에서만 호출(랜덤이라 프레임마다 흔들리면 안 됨). 결과를 _circle_cache 에 담아 _draw 가 재사용한다.
func _gen_grading_circle() -> PackedVector2Array:
	var r_base: float = NCIRC_R + randf_range(-4.0, 4.0)
	var tilt: float = randf_range(-0.25, 0.25)              # 기울기(rad)
	var sq: float = 0.90 + randf() * 0.14                    # 가로눌림(정원≈1)
	var turns: float = 1.14 + randf() * 0.22                 # >1 이라 끝이 시작을 지나쳐 겹친다
	var start: float = PI * 0.5 - 0.1 + randf_range(-0.25, 0.25)  # 대략 아래에서 시작
	var end_a: float = start + TAU * turns                   # 시계방향(각 증가, y-down)
	var wob_f: float = 1.6 + randf() * 1.4
	var wob_p: float = randf() * 6.0
	var wob2: float = 0.6 + randf() * 1.0
	var pts: PackedVector2Array = PackedVector2Array()
	var a: float = start
	while a <= end_a:
		var t: float = (a - start) / (end_a - start)
		var rr: float = r_base + sin(a * wob_f + wob_p) * 3.0 + sin(a * 4.3 + 1.0) * wob2
		if t > 0.9:
			rr *= 1.0 + (t - 0.9) * (0.6 + randf() * 0.5)   # 꼬리 바깥으로 삐침
		if t < 0.05:
			rr *= 1.06
		var ex: float = cos(a) * rr * sq
		var ey: float = sin(a) * rr
		var px: float = ex * cos(tilt) - ey * sin(tilt)
		var py: float = ex * sin(tilt) + ey * cos(tilt)
		# 잉크 거칠기 — 미세 노이즈 offset(셰이더 대체, §11). 한 번 구워 넣으므로 프레임마다 동일.
		px += randf_range(-0.7, 0.7)
		py += randf_range(-0.7, 0.7)
		pts.append(Vector2(px, py))
		a += NCIRC_STEP
	return pts

## 채점 원 렌더 — 캐시된 오프셋을 노드 크기에 맞춰 스케일, 가변 리본(중간 굵음)으로 진행도(progress)까지만 그린다.
## alpha = 점멸/페이드 배수. id = _circle_cache 키(노드 id 또는 "__hover").
func _draw_grading_circle(center: Vector2, node_size: float, col: Color, progress: float, alpha: float, id: String) -> void:
	var offs: PackedVector2Array = _circle_cache.get(id, PackedVector2Array())
	var n: int = offs.size()
	if n < 3:
		return
	var scale: float = node_size * NCIRC_SCALE_FRAC / NCIRC_BOX
	var count: int = clampi(int(2.0 + clampf(progress, 0.0, 1.0) * float(n - 2)), 2, n)
	var c: Color = Color(col.r, col.g, col.b, col.a * clampf(alpha, 0.0, 1.0))
	# 세그먼트마다 사각 리본(quad) — 자기교차 나선도 겹쳐 그려져 안전(한 폴리곤 삼각화 문제 회피).
	for i in range(count - 1):
		var pa: Vector2 = center + offs[i] * scale
		var pb: Vector2 = center + offs[i + 1] * scale
		var dir: Vector2 = offs[i + 1] - offs[i]
		if dir.length() < 0.0001:
			continue
		var nrm: Vector2 = Vector2(-dir.y, dir.x).normalized()
		var ha: float = _ribbon_hw(i, n) * scale
		var hb: float = _ribbon_hw(i + 1, n) * scale
		var quad: PackedVector2Array = PackedVector2Array([pa + nrm * ha, pb + nrm * hb, pb - nrm * hb, pa - nrm * ha])
		draw_colored_polygon(quad, c)

## 리본 half-width(§4.1b) — 처음·끝은 가늘고 중간이 굵게(sin^0.65).
func _ribbon_hw(i: int, n: int) -> float:
	var t: float = minf(1.0, float(i) / float(maxi(1, n - 1)))
	return NCIRC_WMIN + (NCIRC_WMAX - NCIRC_WMIN) * pow(sin(t * PI), 0.65)

## 붉은 선택길(§3) — 넓고 옅은 밑 글로우 위에 진한 붉은 선(셰이더 없이 두 겹).
func _draw_red_path(pts: PackedVector2Array, icon_size: float) -> void:
	if pts.size() < 2:
		return
	var w: float = clampf(icon_size * 0.045, 2.6, 5.0)
	draw_polyline(pts, Color(RED_PATH.r, RED_PATH.g, RED_PATH.b, 0.22), w * 2.4)
	draw_polyline(pts, RED_PATH, w)

## 지도 라벨 — 크림 빛 웅덩이(방사, 상자 없음) + 후광(§2) 위에 상태색 글자.
## 웅덩이가 뒤의 낙서·배경 결을 은은하게 밀어내 이름이 항상 읽힌다(사용자 가독성 지적, 2026-07-05).
func _draw_map_label(font: Font, pos: Vector2, text: String, width: float, fs: int, col: Color) -> void:
	if font == null:
		return
	if _label_pool_tex != null:
		# 실제 글자 폭에 맞춘 타원 웅덩이 — 텍스트보다 사방 한 뼘 넓게.
		var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pw: float = minf(width, tw + fs * 2.6)
		var ph: float = fs * 2.4
		draw_texture_rect(_label_pool_tex, Rect2(pos.x + (width - pw) * 0.5, pos.y - fs * 0.35 - ph * 0.5, pw, ph), false)
	var halo: Color = Color(LABEL_HALO.r, LABEL_HALO.g, LABEL_HALO.b, 0.5)
	for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1)]:
		draw_string(font, pos + off, text, HORIZONTAL_ALIGNMENT_CENTER, width, fs, halo)
	var halo2: Color = Color(LABEL_HALO.r, LABEL_HALO.g, LABEL_HALO.b, 0.22)
	for off in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		draw_string(font, pos + off, text, HORIZONTAL_ALIGNMENT_CENTER, width, fs, halo2)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, fs, col)

## 현재 위치 태그 "원정대"(§2, 14px 상당) — 붉은 페넌트(킷 텍스처, 없으면 절차 삼각형) + 후광 라벨. 노드 위 중앙.
func _draw_expedition_tag(font: Font, center: Vector2, sc: float) -> void:
	var pt: Texture2D = _kit_tex.get("party_tag", null)
	if pt != null:
		# 깃발 안 채움(2026-07-12 사용자) — 테두리 그림 뒤에 같은 잉크의 면(위 사각 + 아래 V 홈).
		var tc: Vector2 = center + Vector2(0.0, -17.0 * sc)
		var tw: float = float(pt.get_width())
		var th: float = float(pt.get_height())
		if tw > 0.0 and th > 0.0:
			var s: float = (15.0 * sc) / maxf(tw, th)
			var wh: Vector2 = Vector2(tw * s, th * s)
			var tl: Vector2 = tc - wh * 0.5
			draw_colored_polygon(PackedVector2Array([
				tl + Vector2(wh.x * 0.16, wh.y * 0.08),
				tl + Vector2(wh.x * 0.84, wh.y * 0.08),
				tl + Vector2(wh.x * 0.86, wh.y * 0.92),
				tl + Vector2(wh.x * 0.50, wh.y * 0.58),
				tl + Vector2(wh.x * 0.14, wh.y * 0.92),
			]), Color(LABEL_MK.r, LABEL_MK.g, LABEL_MK.b, 0.72))
		_draw_sketch(pt, tc, 15.0 * sc)
	else:
		var tri: PackedVector2Array = PackedVector2Array([center + Vector2(-4.0, 0.0) * sc, center + Vector2(4.0, 0.0) * sc, center + Vector2(0.0, -5.0) * sc])
		draw_colored_polygon(tri, LABEL_MK)
	_draw_map_label(font, center + Vector2(-75.0 * sc, 2.0), "원정대", 150.0 * sc, maxi(9, int(14.0 * sc)), LABEL_MK)
