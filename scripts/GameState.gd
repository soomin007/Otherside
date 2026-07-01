extends Node

## 전역 상태 + 씬 라우팅 + 저장/불러오기 (autoload 이름: GameState).
##
## 코어 루프 (기획서 §3): 지도(계획) → 횡스크롤(실행) → 죽음 → 지도 갱신 → 다음 원정.
## 플레이어 = 원정대 총괄자(매번 다른 대장을 보냄)이므로 한 세계의 모든 원정 기록(흔적/죽은 자리)은 한 세이브에 누적된다.
## 1차는 self-async — 이전 원정대(내 과거 런)의 흔적이 다음 원정대에게 남는다.

const SAVE_PATH: String = "user://otherside_save.json"  # 웹에선 브라우저 IndexedDB 에 영속
const SAVE_VERSION: int = 1

const SCENE_TITLE: String = "res://scenes/main.tscn"
const SCENE_MAP: String = "res://scenes/map.tscn"
const SCENE_EXPEDITION: String = "res://scenes/expedition.tscn"
const SCENE_OPENING: String = "res://scenes/opening.tscn"

# --- 한 세계에 누적되는 영속 데이터 (원정을 가로질러 살아남음) ---
var expedition_count: int = 0  ## 지금까지 보낸 원정 수
var traces: Array = []         ## 남긴 흔적들 — TraceData.to_dict() 의 배열 (self-async)
var deaths: Array = []         ## 죽은 자리 기록 — 지도 표식용
var flags: Array = []  ## 영속 플래그(self-async). choice 의 sets_persist 가 쌓여 다음 원정 변형 이벤트를 깬다.
var visited_nodes: Array = []  ## 방문한 노드 id (영속). 지도 안개 — 가본 곳 + 그 인접만 보인다(원정마다 더 드러남).
var opening_seen: bool = false ## 오프닝 서사를 봤나 (영속). 첫 플레이만 자동 재생, 이후 스킵.

# --- 현재 원정 한정 상태 (죽으면 리셋) ---
## 초기 자원 — 임시치. 자원 = 수명 (남기면 그만큼 잃는다). 밸런스는 폰 테스트로 검증 예정.
const START_RESOURCES: Dictionary = {"water": 20, "food": 13, "rope": 1, "shelter": 1}
const REUNION_TRACES: int = 8  ## 재회 엔딩 흔적 축적 임계(임시 — 밸런싱 핵심 튜닝, 기획서 §3 결말)
var current_run: ExpeditionRun = null  ## 진행 중인 원정의 순수 상태·로직 (core/ExpeditionRun)

func _ready() -> void:
	load_game()

# --- 코어 루프 전이 ---

func go_to_map() -> void:
	get_tree().change_scene_to_file(SCENE_MAP)

## 오프닝 서사 슬라이드쇼로 (타이틀에서 첫 플레이 시).
func go_to_opening() -> void:
	get_tree().change_scene_to_file(SCENE_OPENING)

## 오프닝을 봤다고 기록(영속). 이후 자동 재생 안 함.
func mark_opening_seen() -> void:
	if not opening_seen:
		opening_seen = true
		save_game()

## 씬 전환 없이 현재 원정만 새로 만든다 (직접 진입 안전장치 / 테스트용).
## 과거에 로프를 건 차단 노드(bridged_nodes)·줍을 수 있는 흔적(pickup_traces_by_node)을 주입해,
## 그 노드에 도착하면 무료 통과·줍기 카드가 뜨게 한다(self-async, 영구 지형 변화).
func begin_run_in_place() -> void:
	current_run = ExpeditionRun.new(START_RESOURCES, bridged_nodes(), flags, pickup_traces_by_node())
	expedition_count += 1
	_mark_visited(MapGraph.START_ID)

## 지도에서 고른 노드로 향하기 시작한다(엣지 시작, 씬 전환 없음). 마커 이동·소모는 Map 이 처리한다.
func begin_travel(target_id: String) -> void:
	if current_run != null:
		current_run.begin_edge(target_id)

## 목표 노드에 도착했을 때 그 노드 화면으로 전환한다 (Map 이 호출).
func go_to_expedition() -> void:
	get_tree().change_scene_to_file(SCENE_EXPEDITION)

## 노드에 도착해 지도로 돌아간다 (횡스크롤 → 지도). 현재 노드를 목표로 옮긴다.
func arrive_node() -> void:
	if current_run != null:
		current_run.arrive()
		_mark_visited(current_run.current_node)
	get_tree().change_scene_to_file(SCENE_MAP)

# --- 결말 (기획서 §3 결말: 순환과 재회) ---

## end 도달 시 엔딩 종류 — "reunion"(재회) = 흔적 충분 축적 + 무사 도달(alive), 아니면 "cycle"(순환).
## 밸런싱 북극성: 승리 = 한 번의 런이 아니라 여러 원정에 걸친 흔적 축적. REUNION_TRACES 가 돌파 난이도.
func ending_kind() -> String:
	if current_run != null and current_run.alive and traces.size() >= REUNION_TRACES:
		return "reunion"
	return "cycle"

## 순환 — 이 원정을 닫고 다음 원정을 처음부터 준비한다(흔적·방문 누적은 유지 → 다음이 더 멀리 간다).
func next_expedition() -> void:
	current_run = null
	go_to_map()

## 재회(진짜 엔딩) 후 — 타이틀로 돌아간다. 세이브(축적)는 유지된다.
func go_to_title() -> void:
	current_run = null
	get_tree().change_scene_to_file(SCENE_TITLE)

## 노드를 방문 기록에 더한다(영속). 지도 안개를 걷는다.
func _mark_visited(node_id: String) -> void:
	if node_id != "" and not visited_nodes.has(node_id):
		visited_nodes.append(node_id)
		save_game()

## 죽기 전 단 한 번 흔적을 남긴다 (기획서 §3). 남김 = 자기 수명 깎기.
func leave_trace(trace: TraceData) -> void:
	traces.append(trace.to_dict())

func record_death(leg: int, node_id: String = "") -> void:
	deaths.append({"leg": leg, "node_id": node_id, "expedition": expedition_count})

## 복원된 흔적을 TraceData 로 돌려준다 (지도/횡스크롤 렌더링용).
func loaded_traces() -> Array[TraceData]:
	var out: Array[TraceData] = []
	for raw in traces:
		if raw is Dictionary:
			out.append(TraceData.from_dict(raw))
	return out

## 과거에 로프를 고정한 차단 노드들(ROPE 흔적의 node_id). 다음 원정에서 그 노드에 도착하면 무료로 건넌다.
## 차단 = "영구 지형 변화"(기획서 §4)의 영속 표현. ExpeditionRun 에 주입된다.
func bridged_nodes() -> Array:
	var out: Array = []
	for raw in traces:
		if raw is Dictionary and int(raw.get("object_kind", -1)) == TraceData.ObjectKind.ROPE:
			var nid: String = str(raw.get("node_id", ""))
			if nid != "" and not out.has(nid):
				out.append(nid)
	return out

## 줍을 수 있는 흔적(자원 종류 WATER/FOOD/SHELTER + uses>0)을 node_id→{kind,tags} 로. 노드당 첫 흔적.
## ExpeditionRun 에 주입돼 그 노드 도착 시 줍기 카드를 띄운다.
func pickup_traces_by_node() -> Dictionary:
	var out: Dictionary = {}
	for raw in traces:
		if not (raw is Dictionary):
			continue
		var kind: int = int(raw.get("object_kind", -1))
		if kind != TraceData.ObjectKind.WATER and kind != TraceData.ObjectKind.FOOD and kind != TraceData.ObjectKind.SHELTER:
			continue
		if int(raw.get("uses", 0)) <= 0:
			continue
		var nid: String = str(raw.get("node_id", ""))
		if nid == "" or out.has(nid):
			continue
		var tg: Array = raw.get("tags", [])
		out[nid] = {"kind": kind, "tags": tg.duplicate()}
	return out

## 흔적을 한 번 쓴다 — uses 를 1 깎고, 0 이 되면 제거한다(node_id+kind 첫 매칭). 줍기 보충 직후 호출.
func use_trace(node_id: String, kind: int) -> void:
	for i in range(traces.size()):
		var t: Variant = traces[i]
		if not (t is Dictionary):
			continue
		if str(t.get("node_id", "")) == node_id and int(t.get("object_kind", -1)) == kind:
			var u: int = int(t.get("uses", 0)) - 1
			if u <= 0:
				traces.remove_at(i)
			else:
				t["uses"] = u
				traces[i] = t
			save_game()
			return

## 영속 플래그를 켠다(다음 원정의 변형 이벤트용). 선택의 sets_persist 가 여기로 쌓인다(중복 제외).
func add_persist_flags(new_flags: Array) -> void:
	var changed: bool = false
	for f in new_flags:
		var s: String = str(f)
		if not flags.has(s):
			flags.append(s)
			changed = true
	if changed:
		save_game()

# --- 저장 / 불러오기 (JSON, 웹 IndexedDB) ---

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"expedition_count": expedition_count,
		"traces": traces,
		"deaths": deaths,
		"flags": flags,
		"visited_nodes": visited_nodes,
		"opening_seen": opening_seen,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("세이브 열기 실패: %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(data))
	f.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("세이브 파싱 실패 — 무시")
		return
	var data: Dictionary = parsed
	expedition_count = int(data.get("expedition_count", 0))
	traces = data.get("traces", [])
	deaths = data.get("deaths", [])
	flags = data.get("flags", [])
	visited_nodes = data.get("visited_nodes", [])
	opening_seen = bool(data.get("opening_seen", false))

## 세이브 초기화 (새 세계). 빈 상태로 덮어쓴다 — 웹/데스크톱 모두 안전.
func reset_save() -> void:
	expedition_count = 0
	traces = []
	deaths = []
	flags = []
	visited_nodes = []
	opening_seen = false
	current_run = null
	save_game()
