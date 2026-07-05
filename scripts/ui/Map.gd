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
const BAND: Rect2 = Rect2(230.0, 112.0, 1016.0, 571.0)  # 1016/571 = 양피지 비율(1.779) 유지
const MAP_W: float = 820.0   ## 스펙 MAP 좌표 공간(NODE_PX 기준) — 밴드 크기와 무관
## 노드 절대 배치(§1) — MAP 좌표 x·y = 중심, z = 정사각 표시 크기(px). 시각 데이터라 core(MapGraph)가 아닌 여기에.
const NODE_PX: Dictionary = {
	"n0": Vector3(52, 300, 100), "a1": Vector3(120, 362, 82),
	"b1": Vector3(255, 128, 86), "b2": Vector3(200, 360, 84),
	"c1": Vector3(415, 92, 86), "c2": Vector3(350, 298, 82),
	"d1": Vector3(525, 172, 84), "d2": Vector3(465, 360, 82),
	"e1": Vector3(642, 322, 84), "f1": Vector3(650, 205, 88),
	"end": Vector3(778, 272, 60),
}
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
const LABEL_HALO: Color = Color(0.914, 0.839, 0.686)   ## 라벨 크림 후광 rgb(233,214,175)(§2)
const LABEL_DIM: Color = Color(0.290, 0.196, 0.071)    ## #4a3212 방문·미답 라벨
const LABEL_MK: Color = Color(0.541, 0.184, 0.106)     ## #8a2f1b 선택 가능·현재 라벨

var _title_eye: Label         ## "EXPEDITION · MAP" 에이브로우(§7)
var _title_lbl: Label         ## "지도 · 탐험"
var _guide: Label
var _moving: bool = false
var _move_timer: float = 0.0
var _sit_panel: Control       ## 이동 중 상황 카드 모달
var _sit_box: VBoxContainer   ## 카드 내용(매번 갈아끼움)
var _leave_btn: Button        ## "남기기" — 이동 중에도 물건 하나 두고 계속 (런당 1회)
var _bequeath: BequeathPanel  ## 남기기 모달 (공유 컴포넌트 — 도착 화면과 같은 것)
var _result_popup: ResultPopup ## 선택 결과 팝업 (공유)
var _bg_tex: Texture2D
var _bg_tex_land: Texture2D   ## 가로(데스크톱) 화면용 — 세로 원본을 90도 회전한 것. 없으면 세로본 fallback
var _icon_tex: Dictionary = {}   ## 노드 id -> Texture2D (로드 성공한 것만)
var _sketch_tex: Dictionary = {} ## 손스케치 key -> Texture2D (로드 성공한 것만). 비면 지형지물 안 그림
var _reveal_id: String = ""      ## 이번에 잉크로 그려지며 나타날 노드(방금 도착/시작한 곳)
var _reveal_t: float = 0.0       ## reveal 애니 경과 시간
var _splashes: Array = []        ## 이동 중 걸음마다 번지는 잉크 얼룩 [{pos,t}] — _process 가 나이 먹이고 _draw 가 렌더
var _hovered_node: String = ""   ## 마우스가 올라간 도달 가능 노드(호버 시 클릭 원 확대). 터치엔 없음
var _dragging: bool = false       ## 누름~뗌 사이 드래그 추적(임계 넘으면 탭 취소 — 오터치 방지)
var _drag_start_y: float = 0.0    ## 드래그 시작 지점 y(스크린)
var _drag_moved: float = 0.0      ## 드래그 누적 이동(임계 넘으면 탭 아님)
## 손그림 채점 원 캐시·타이머 — 랜덤 생성은 _draw 밖에서 한 번(프레임마다 흔들리면 안 됨), _draw 는 캐시만 렌더.
var _label_pool_tex: GradientTexture2D  ## 라벨 뒤 크림 빛 웅덩이(방사) — 낙서·배경 위 가독성(상자 없이)
var _circle_cache: Dictionary = {}   ## key(노드 id 또는 "__hover") -> PackedVector2Array(중심 기준 오프셋, 잉크 거칠기 baked)
var _circle_cur_id: String = ""      ## 현재 채점 원이 걸린 노드
var _circle_cur_t: float = 0.0       ## current 원 경과(그려짐→점멸)
var _hover_t: float = 0.0            ## hover 원 그려짐 경과(호버 바뀔 때 0 으로)

func _ready() -> void:
	if GameState.current_run == null or not GameState.current_run.alive:
		GameState.begin_run_in_place()
	AudioManager.play_bed()  # 폭풍 노드에서 돌아왔으면 베드로 복귀(이미 베드면 무시 — 연속 유지)

	if ResourceLoader.exists(BG_PATH):
		_bg_tex = load(BG_PATH)
		# 가로 화면(데스크톱)용 — 세로 원본(720x1280)을 90도 돌려 가로(1280x720)로. 나침반이 방사대칭이라 회전 티 안 남.
		var _bimg: Image = _bg_tex.get_image()
		if _bimg != null:
			_bimg.rotate_90(CLOCKWISE)
			_bg_tex_land = ImageTexture.create_from_image(_bimg)
	for id in ICON_PATHS:
		var path: String = str(ICON_PATHS[id])
		if ResourceLoader.exists(path):
			_icon_tex[str(id)] = load(path)
	for k in SKETCH_PATHS:
		var spath: String = str(SKETCH_PATHS[k])
		if ResourceLoader.exists(spath):
			_sketch_tex[str(k)] = load(spath)

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

	_build_chrome()
	resized.connect(_layout_chrome)
	call_deferred("_layout_chrome")

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
	# 남기기 — 좌 칼럼 하단(각인 key). 이동 중에도 상시(고갈사 전에 남길 기회).
	var leave := EngravedItem.new()
	leave.init_item("남기기", 20, true)
	leave.pressed.connect(_on_leave_pressed)
	add_child(leave)
	_leave_btn = leave

## 크롬 배치 — STAGE 좌표(제목 230,46 · 안내문 제목 오른쪽 · 남기기 좌 칼럼 하단) → 화면 px. 리사이즈마다.
func _layout_chrome() -> void:
	if _title_eye == null:
		return
	var st := _stage_rect()
	var sc: float = st.size.x / STAGE_W
	_title_eye.position = st.position + Vector2(230.0, 24.0) * sc
	_title_lbl.position = st.position + Vector2(228.0, 44.0) * sc
	_guide.position = st.position + Vector2(474.0, 62.0) * sc
	_leave_btn.size = Vector2((COL_L_W + 24.0) * sc, 54.0)
	_leave_btn.position = st.position + Vector2(COL_L_X - 12.0, 638.0) * sc

## _ready 마무리 — 남기기·결과 팝업(공유 컴포넌트)·잉크 reveal·채점 원 초기화.
func _after_ready_setup() -> void:
	# 남기기·결과 팝업 = 공유 컴포넌트(도착 화면과 같은 것).
	_bequeath = BequeathPanel.new()
	_bequeath.committed.connect(_on_bequeath_done)
	_bequeath.cancelled.connect(_on_bequeath_done)
	add_child(_bequeath)
	_result_popup = ResultPopup.new()
	add_child(_result_popup)
	# 방금 도착(또는 시작)한 노드가 잉크로 번지듯 나타난다 — 지도 재진입마다 현재 노드에 재생.
	if GameState.current_run != null:
		_reveal_id = GameState.current_run.current_node
	_reveal_t = 0.0
	# 현재 위치 채점 원 — 이 지도 방문의 현재 노드에 한 번 생성(그려짐→점멸은 _process 가 진행).
	_circle_cur_id = _current_node_id()
	_circle_cache[_circle_cur_id] = _gen_grading_circle()
	_circle_cur_t = 0.0
	_refresh_hud()
	queue_redraw()

func _guide_text() -> String:
	if _moving:
		return "나아가는 중..."
	if _current_node_id() == "end":
		return "목적지에 닿았다. (여기까지가 Phase 0)"
	return "갈 곳을 고르세요. 가봐야 무엇이 있는지 압니다."

func _current_node_id() -> String:
	if GameState.current_run != null:
		return GameState.current_run.current_node
	return MapGraph.START_ID

func _is_revealed(id: String) -> bool:
	return GameState.visited_nodes.has(id)

func _refresh_hud() -> void:
	var run: ExpeditionRun = GameState.current_run
	if run == null:
		return
	AudioManager.warn_thirst(run.get_res("water"))  # 물이 임계로 떨어지는 순간 경고음 1회
	_update_leave_btn(run)
	queue_redraw()  # 좌 칼럼(지닌 것)이 _draw 에서 자원을 직접 읽는다

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
	if _sit_panel.visible or _bequeath.is_open() or _result_popup.is_open():
		return
	_moving = false
	if _guide != null:
		_guide.text = "멈춰 선다."
	_bequeath.open(run, run.current_node)  # 이동 중=마지막 밟은 노드에 남긴다(death_node_id 와 일관)

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
	_refresh_hud()
	# 이 걸음이 닿은 자리에 잉크가 번진다(잉크처럼 퍼지는 이동).
	if run.alive:
		_splashes.append({"pos": _marker_pos(_map_area()), "t": 0.0})
	if not run.alive or run.arrived():
		_moving = false
		GameState.go_to_expedition()  # 도착(또는 도중 고갈사) → 그 노드 화면
	elif not run.pending_situation.is_empty():
		_moving = false
		_show_situation_card()  # 이동 중 마주친 상황 — 결정하면 이동을 잇는다

func _gui_input(event: InputEvent) -> void:
	if _moving or (_sit_panel != null and _sit_panel.visible) or (_bequeath != null and _bequeath.is_open()) or (_result_popup != null and _result_popup.is_open()):
		if _hovered_node != "":
			_hovered_node = ""
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
			var hit: String = _reachable_at(event.position, area)
			if hit != "":
				GameState.begin_travel(hit)
				_moving = true
				_move_timer = 0.0
				_hovered_node = ""
				if _guide != null:
					_guide.text = "나아가는 중..."
		return
	# 끄는 중 — 누적 이동만 추적(임계 넘으면 위에서 탭 취소). 화면은 fit 이라 팬 없음.
	if _dragging and (event is InputEventMouseMotion or event is InputEventScreenDrag):
		_drag_moved = maxf(_drag_moved, absf(event.position.y - _drag_start_y))
		return
	# 호버 — 마우스가 올라간 도달 가능 노드(그 원이 커진다). 데스크톱 전용.
	if event is InputEventMouseMotion:
		var hov: String = _reachable_at((event as InputEventMouseMotion).position, area)
		if hov != _hovered_node:
			_hovered_node = hov
			if hov != "":
				_circle_cache["__hover"] = _gen_grading_circle()  # 목적지에 올릴 때마다 새 손그림 원
				_hover_t = 0.0
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
	var card := UITheme.make_card()
	center.add_child(card)
	_sit_box = VBoxContainer.new()
	_sit_box.add_theme_constant_override("separation", UITheme.GAP)
	card.add_child(_sit_box)

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
		var btn := UITheme.make_button("", false)
		btn.text = UITheme.choice_text(choice, enabled, seen)
		if enabled:
			btn.pressed.connect(_on_situation_choice.bind(event_id, i, str(choice.get("label", "")), effect, choice.get("sets", []), choice.get("sets_persist", [])))
		else:
			btn.disabled = true
		_sit_box.add_child(btn)
	_sit_panel.visible = true

func _on_situation_choice(event_id: String, idx: int, label: String, effect: Dictionary, sets: Array, sets_persist: Array) -> void:
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
	_sit_panel.visible = false
	_refresh_hud()
	# blind choice 뒷면 — 결과(자원 변화)를 팝업으로 공개하고, 닫으면 이동을 잇는다.
	_result_popup.show_result(label, effect, _after_situation)

## 이동 중 상황의 결과 팝업을 닫은 뒤 — 죽었으면 그 자리 노드 화면, 아니면 이동 재개.
func _after_situation() -> void:
	var run: ExpeditionRun = GameState.current_run
	if run == null:
		return
	if not run.alive:
		GameState.go_to_expedition()  # 결정이 곧 죽음 → 그 자리 노드 화면
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

## MAP 좌표(820×461) → 화면 배율 — 밴드 확대분(1.24)까지 포함.
func _mscale() -> float:
	return _sscale() * BAND.size.x / MAP_W

## 노드 중심(화면 px) — 스펙 절대좌표(§1)를 밴드에 비례 매핑.
func _node_screen(id: String, area: Rect2) -> Vector2:
	var v: Vector3 = NODE_PX.get(id, Vector3(410, 230, 80))
	return area.position + Vector2(v.x, v.y) * (area.size.x / MAP_W)

## 노드 표시 크기(화면 px) — 스펙 per-node size(§1), 밴드 확대 비례.
func _node_size(id: String) -> float:
	var v: Vector3 = NODE_PX.get(id, Vector3(0, 0, 80))
	return v.z * _mscale()

## 엣지 A→B 곡선 위의 점(t∈[0,1]). 도착 노드 biome 으로 굴곡 결정 — 결정론적(id 해시, 매 프레임 동일).
## 경로 렌더·마커·점선이 모두 이 함수를 공유해야 마커가 그려진 곡선을 정확히 탄다.
func _edge_point(from_id: String, to_id: String, t: float, area: Rect2) -> Vector2:
	var p0: Vector2 = _node_screen(from_id, area)
	var p1: Vector2 = _node_screen(to_id, area)
	var base: Vector2 = p0.lerp(p1, t)
	var dist: float = p0.distance_to(p1)
	if dist < 1.0:
		return base
	var perp: Vector2 = Vector2(-(p1.y - p0.y), p1.x - p0.x) / dist  # 엣지에 수직(방향 무관 → 가로/세로 자동 대응)
	var sgn: float = 1.0 if (_id_hash(to_id) % 2 == 0) else -1.0     # 굴곡 방향 고정(노드별 결정론)
	var amp: float = 0.0
	var shape: float = 0.0
	match MapGraph.biome_of(to_id):
		"river":   # 강줄기를 따라 한 번 사행(S 굽이) — 시작·끝은 노드에 정확히 붙는다(sin τt: t=0,0.5,1 → 0)
			amp = dist * 0.13
			shape = sin(t * TAU)
		"rock":    # 바위·산을 돌아간다(한쪽 볼록)
			amp = dist * 0.20
			shape = sin(t * PI)
		"storm":   # 폭풍·사구에 흔들리는 지그재그
			amp = dist * 0.15
			shape = sin(t * PI * 3.0)
		_:         # flats — 완만한 미세 굴곡
			amp = dist * 0.08
			shape = sin(t * PI)
	return base + perp * (amp * shape * sgn)

## 엣지 곡선을 EDGE_SAMPLES 로 나눈 폴리라인(경로 실선/점선 렌더용).
func _edge_polyline(from_id: String, to_id: String, area: Rect2) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	for i in range(EDGE_SAMPLES + 1):
		pts.append(_edge_point(from_id, to_id, float(i) / float(EDGE_SAMPLES), area))
	return pts

## 노드 id 의 결정론적 해시(문자 코드 합) — 곡선 굴곡 방향 고정용(Math.random 금지: 매 프레임 동일해야).
func _id_hash(s: String) -> int:
	var h: int = 0
	for i in range(s.length()):
		h += s.unicode_at(i)
	return h

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
	var step_done: float = float(ExpeditionRun.EDGE_LEN - run.edge_remaining())
	var frac: float = clampf(_move_timer / STEP_INTERVAL, 0.0, 1.0)
	return clampf((step_done + frac) / float(ExpeditionRun.EDGE_LEN), 0.0, 1.0)

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
	var sc: float = _sscale()   # STAGE 스케일(칼럼·크롬)
	var ms: float = _mscale()   # MAP 스케일(노드·라벨 — 밴드 확대 포함)

	# 좌 칼럼(§6) — "지닌 것" + 미니 범례 + 통계. 각인형(헤어라인+텍스트, 상자 없음). 우 칼럼은 지도 확대로 폐지.
	_draw_col_left(font, sc)

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
				# 이름은 아이콘 아래(스펙 §2: 17px·???는 19px 상당, 밴드 확대 비례). 크림 후광 + 상태색.
				var lcol: Color = LABEL_MK if (str(id) == cur or id in nexts) else LABEL_DIM
				var lfs: int = maxi(9, int((19.0 if str(id) == "end" else 17.0) * ms))
				_draw_map_label(font, p + Vector2(-75.0 * ms, ns * 0.5 + 10.0 * ms), str(MapGraph.NODES[id].get("name", "")), 150.0 * ms, lfs, lcol)
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
	_draw_arrows(area)  # 갈림에서 원정대가 실제 간 방향 화살표(선택의 자취)

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

## 노드별 흔적 마커 — 죽음 X·로프 다리·자원 점. 가본 노드에만(흔적은 가본 곳에서만 생긴다). 한 노드에 여러 개면 옆으로 쌓는다.
func _draw_traces(area: Rect2) -> void:
	var per_node: Dictionary = {}
	for tr in GameState.loaded_traces():
		var nid: String = tr.node_id
		if nid == "" or not MapGraph.NODES.has(nid) or not _is_revealed(nid):
			continue
		var idx: int = int(per_node.get(nid, 0))
		per_node[nid] = idx + 1
		var base: Vector2 = _node_screen(nid, area)
		var half: float = _node_size(nid) * 0.5
		_draw_trace_marker(base + Vector2(-half - 4.0 - float(idx) * 12.0, half + 6.0), tr.object_kind)

func _draw_trace_marker(p: Vector2, kind: int) -> void:
	match kind:
		TraceData.ObjectKind.BODY:
			# 죽은 자리 — 원정대가 남긴 해골 스케치(있으면), 없으면 작은 X.
			var skull: Texture2D = _sketch_tex.get("skull", null)
			if skull != null:
				_draw_sketch(skull, p, 18.0)
			else:
				var s: float = 4.5
				draw_line(p + Vector2(-s, -s), p + Vector2(s, s), UITheme.DANGER, 2.0)
				draw_line(p + Vector2(-s, s), p + Vector2(s, -s), UITheme.DANGER, 2.0)
		TraceData.ObjectKind.ROPE:
			draw_line(p + Vector2(-5.0, 0.0), p + Vector2(5.0, 0.0), UITheme.SAND, 2.5)  # 로프 다리
		TraceData.ObjectKind.WATER:
			draw_circle(p, 3.5, Color(0.55, 0.78, 0.97))
		TraceData.ObjectKind.FOOD:
			draw_circle(p, 3.5, Color(0.88, 0.72, 0.42))
		TraceData.ObjectKind.SHELTER:
			draw_circle(p, 3.5, Color(0.70, 0.85, 0.70))
		_:
			draw_circle(p, 2.5, UITheme.MUTED)

# --- 여백 칼럼(§6) — 각인형: 헤어라인 + 텍스트, 상자 없음 ---

## 스펙 헤어라인 — 왼쪽이 밝고 오른쪽으로 잦아드는 1px 모래선(3단 근사).
func _draw_hairline(x: float, y: float, w: float) -> void:
	var s := UITheme.SAND
	draw_line(Vector2(x, y), Vector2(x + w * 0.4, y), Color(s.r, s.g, s.b, 0.32), 1.0, true)
	draw_line(Vector2(x + w * 0.4, y), Vector2(x + w * 0.75, y), Color(s.r, s.g, s.b, 0.14), 1.0, true)
	draw_line(Vector2(x + w * 0.75, y), Vector2(x + w, y), Color(s.r, s.g, s.b, 0.04), 1.0, true)

## 좌 "지닌 것" — 자원 4행(값 Cinzel·이름·효과) + 주머니(도구). STAGE (36,150) w172(§6).
func _draw_col_left(font: Font, sc: float) -> void:
	var run: ExpeditionRun = GameState.current_run
	if run == null:
		return
	var st := _stage_rect()
	var x: float = st.position.x + COL_L_X * sc
	var w: float = COL_L_W * sc
	var y: float = st.position.y + 158.0 * sc
	draw_string(EN_TITLE_FONT, Vector2(x, y), "CARRIED", HORIZONTAL_ALIGNMENT_LEFT, w, maxi(8, int(10.0 * sc)), Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.6))
	y += 26.0 * sc
	draw_string(font, Vector2(x, y), "지닌 것", HORIZONTAL_ALIGNMENT_LEFT, w, maxi(12, int(22.0 * sc)), UITheme.FG)
	y += 14.0 * sc
	_draw_hairline(x, y, w)
	var rows: Array = [
		["water", "물", "걸음마다 줆"],
		["food", "식량", "굶으면 쇠약"],
		["rope", "로프", "차단을 넘음"],
		["shelter", "은신막", "폭풍을 견딤"],
	]
	for r in rows:
		y += 30.0 * sc
		# 한 줄: 값(Cinzel) + 이름(왼쪽) + 효과(오른쪽 끝) — 스펙 .jres 구성.
		draw_string(EN_TITLE_FONT, Vector2(x, y), str(run.get_res(str(r[0]))), HORIZONTAL_ALIGNMENT_LEFT, 30.0 * sc, maxi(11, int(21.0 * sc)), UITheme.SAND)
		draw_string(font, Vector2(x + 36.0 * sc, y), str(r[1]), HORIZONTAL_ALIGNMENT_LEFT, w - 36.0 * sc, maxi(10, int(17.0 * sc)), Color(0.910, 0.875, 0.804))
		draw_string(font, Vector2(x, y), str(r[2]), HORIZONTAL_ALIGNMENT_RIGHT, w, maxi(8, int(11.5 * sc)), Color(0.529, 0.475, 0.376))
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

	# 미니 범례 — 꼭 필요한 것만(우 칼럼 폐지, 사용자 지시): 갈 수 있는 곳·죽은 자리·위험.
	y += 18.0 * sc
	_draw_hairline(x, y, w)
	var fs: int = maxi(9, int(13.0 * sc))
	var tcol := Color(0.75, 0.70, 0.62)
	var sym_w: float = 26.0 * sc
	y += 24.0 * sc
	draw_line(Vector2(x, y - 4.0 * sc), Vector2(x + 20.0 * sc, y - 4.0 * sc), RED_PATH, 2.4, true)
	draw_string(font, Vector2(x + sym_w, y), "갈 수 있는 곳", HORIZONTAL_ALIGNMENT_LEFT, w - sym_w, fs, tcol)
	y += 21.0 * sc
	var skull: Texture2D = _sketch_tex.get("skull", null)
	if skull != null:
		_draw_sketch(skull, Vector2(x + 9.0 * sc, y - 5.0 * sc), 17.0 * sc)
	else:
		draw_line(Vector2(x + 3.0 * sc, y - 9.0 * sc), Vector2(x + 13.0 * sc, y), UITheme.DANGER, 2.0, true)
		draw_line(Vector2(x + 3.0 * sc, y), Vector2(x + 13.0 * sc, y - 9.0 * sc), UITheme.DANGER, 2.0, true)
	draw_string(font, Vector2(x + sym_w, y), "죽은 자리", HORIZONTAL_ALIGNMENT_LEFT, w - sym_w, fs, tcol)
	var warn: Texture2D = _sketch_tex.get("warn", null)
	if warn != null:
		y += 21.0 * sc
		_draw_sketch(warn, Vector2(x + 9.0 * sc, y - 5.0 * sc), 17.0 * sc)
		draw_string(font, Vector2(x + sym_w, y), "위험", HORIZONTAL_ALIGNMENT_LEFT, w - sym_w, fs, tcol)
	# 통계 한 줄(컴팩트).
	y += 24.0 * sc
	draw_string(font, Vector2(x, y), "원정 %d · 흔적 %d · 죽음 %d" % [GameState.expedition_count, GameState.traces.size(), GameState.deaths.size()], HORIZONTAL_ALIGNMENT_LEFT, w, maxi(8, int(11.5 * sc)), Color(0.529, 0.475, 0.376))

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

## 현재 위치 태그 "원정대"(§2, 14px 상당) — 삼각형은 절차적(draw_colored_polygon), 글자는 후광 라벨. 노드 위 중앙.
func _draw_expedition_tag(font: Font, center: Vector2, sc: float) -> void:
	var tri: PackedVector2Array = PackedVector2Array([center + Vector2(-4.0, 0.0) * sc, center + Vector2(4.0, 0.0) * sc, center + Vector2(0.0, -5.0) * sc])
	draw_colored_polygon(tri, LABEL_MK)
	_draw_map_label(font, center + Vector2(-75.0 * sc, 2.0), "원정대", 150.0 * sc, maxi(9, int(14.0 * sc)), LABEL_MK)
