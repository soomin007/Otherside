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
const SCENE_LOADOUT: String = "res://scenes/loadout.tscn"
const SCENE_INTERLUDE: String = "res://scenes/interlude.tscn"
const SCENE_VILLAGE_INTRO: String = "res://scenes/village_intro.tscn"

# --- 한 세계에 누적되는 영속 데이터 (원정을 가로질러 살아남음) ---
var expedition_count: int = 0  ## 지금까지 보낸 원정 수
var traces: Array = []         ## 남긴 흔적들 — TraceData.to_dict() 의 배열 (self-async)
var deaths: Array = []         ## 죽은 자리 기록 — 지도 표식용
var flags: Array = []  ## 영속 플래그(self-async). choice 의 sets_persist 가 쌓여 다음 원정 변형 이벤트를 깬다.
var visited_nodes: Array = []  ## 방문한 노드 id (영속). 지도 안개 — 가본 곳 + 그 인접만 보인다(원정마다 더 드러남).
var opening_seen: bool = false ## 오프닝 서사를 봤나 (영속). 첫 플레이만 자동 재생, 이후 스킵.
var opening_replay: bool = false ## 설정 "오프닝 다시보기"로 재생 중(비영속) — 끝나면 마을이 아니라 타이틀로.
var record_seen: bool = false  ## 시장이 원정 기록지를 건넸나 (영속). give_record 로 켜면 책갈피(Bookmark)가 상시 뜬다.
var controls_tutorial_seen: bool = false ## 첫 원정 조작 오버레이 튜토리얼을 봤나 (영속). Tutorial autoload 자동재생 게이트.
var village_intro_seen: bool = false ## 첫 원정 마을 단면 탐색 연습을 봤나 (영속). Loadout 이 첫 출발 때 한 번 VillageIntro 로 보낸다.
var expedition_names: Array = [] ## 원정별 이름 (인덱스 = 회차-1, 영속). 랜덤(ExpeditionNamer) 또는 직접 입력(Loadout).
var arrivals: Array = [] ## end 에 닿은 원정 기록 — {expedition:int, ending:"cycle"|"reunion"} (영속). 일대기(Bookmark)가 죽음만이 아니라 도달/재회도 보이게 한다.
var seeded: bool = false ## 유령 흔적(플레이어 이전 원정대들)을 심었나 (영속, 세계당 1회). 빈 세계 회피.

# --- 현재 원정 한정 상태 (죽으면 리셋) ---
## 초기 자원 — 임시치. 자원 = 수명 (남기면 그만큼 잃는다). 밸런스는 폰 테스트로 검증 예정.
const START_RESOURCES: Dictionary = {"water": 20, "food": 13, "rope": 1, "shelter": 1}
const REUNION_TRACES: int = 4  ## 재회 흔적 임계. 8→4(2026-07-09). 카운트=player_trace_count(의도적으로 남긴 것+로프/다리, 비-seed). 죽음(시체)은 deaths 배열이라 0 기여. 4 = 무사 도달용 세계 만들기(다리+스태시 ~3런) 동안 자연히 채워지는 수 → 그리드 대신 "공략 지식"이 관문.
var current_run: ExpeditionRun = null  ## 진행 중인 원정의 순수 상태·로직 (core/ExpeditionRun)
var ending_kind_pending: String = ""  ## 엔딩 슬라이드쇼(Ending 오버레이)가 읽을 결말("cycle"/"reunion"). Expedition._show_ending 이 세팅.
var pending_expedition_name: String = ""  ## 폭풍 막간(Interlude)이 지명한 다음 원정대 이름 → Loadout 이 초기값으로 소비(비영속).
## blind choice — 겪어본 선택지 ("event_id#idx"→true). 그 선택지 결과를 이후 노출한다(학습).
## 영속(세이브 포함) — 한 번 본 결과는 다음 원정에도 보인다. requires 로 열린 새 변형 이벤트는 event_id 가 달라
## 자동으로 "안 본 것"(blind)이 된다 → "이전 선택으로 새로 나온 선택지만 처음처럼"이 선택지 단위 키로 공짜로 성립.
## 지도·단면 두 씬이 공유하므로 여기(autoload)에 둔다.
var seen_choices: Dictionary = {}

func _ready() -> void:
	load_game()
	ensure_seeded()

## 유령 흔적을 아직 안 심었으면 심는다(세계당 1회). 새 세계·기존 세이브 모두 첫 로드 때 한 번.
func ensure_seeded() -> void:
	if seeded:
		return
	_plant_seeds()
	seeded = true
	save_game()

## 플레이어 이전 원정대들이 남긴 것 — 빈 세계 회피(기획서 §3, 사용자 확정 2026-07-07).
## 정직한 표식만(오인·거짓 없음 — 신뢰는 우리 게임 주축 아님). 자원 흔적은 uses 로 몇 번 쓰면 사라진다("3번쯤").
## 재회 카운트에선 제외(seed=true) — 재회는 플레이어가 잘 남긴 것으로만 연다.
func _plant_seeds() -> void:
	var seeds: Array = [
		{"object_kind": TraceData.ObjectKind.WATER, "node_id": "a1", "tags": ["여기", "안전"], "uses": 3},
		{"object_kind": TraceData.ObjectKind.ROPE, "node_id": "b2", "tags": ["건너", "조심"], "uses": 0},
		{"object_kind": TraceData.ObjectKind.WATER, "node_id": "c1", "tags": ["앞", "갈증"], "uses": 3},
		{"object_kind": TraceData.ObjectKind.SHELTER, "node_id": "c2", "tags": ["폭풍", "곧"], "uses": 3},
		{"object_kind": TraceData.ObjectKind.BODY, "node_id": "d1", "tags": ["끝", "미안"], "uses": 0},
	]
	for s in seeds:
		var t: Dictionary = s
		t["seed"] = true
		t["leg"] = 0
		t["position"] = 0.0
		traces.append(t)

## 재회 카운트용 흔적 수. 유령(seed) 제외, 플레이어가 남긴 것만. 죽음은 deaths 배열이라 여기 안 들어감(시체는 재회에 0 기여).
func player_trace_count() -> int:
	var n: int = 0
	for t in traces:
		if t is Dictionary and not bool(t.get("seed", false)):
			n += 1
	return n

# --- 코어 루프 전이 ---

func go_to_map() -> void:
	Transition.go(SCENE_MAP)

## 오프닝 서사 슬라이드쇼로 (타이틀에서 첫 플레이 시).
func go_to_opening() -> void:
	Transition.go(SCENE_OPENING)

## 마을(가방 꾸리기)로 — 매 원정 출발 전. 여기서 시작 자원을 고른다.
func go_to_loadout() -> void:
	Transition.go(SCENE_LOADOUT)

## 첫 원정 마을 단면 탐색 연습(VillageIntro) — Loadout 출발 뒤 지도 전에 한 번(첫 원정만).
func go_to_village_intro() -> void:
	Transition.go(SCENE_VILLAGE_INTRO)

func mark_village_intro_seen() -> void:
	if not village_intro_seen:
		village_intro_seen = true
		save_game()

## 오프닝을 봤다고 기록(영속). 이후 자동 재생 안 함.
func mark_opening_seen() -> void:
	if not opening_seen:
		opening_seen = true
		save_game()

## 씬 전환 없이 현재 원정만 새로 만든다 (직접 진입 안전장치 / 테스트용).
## 과거에 로프를 건 차단 노드(bridged_nodes)·줍을 수 있는 흔적(pickup_traces_by_node)을 주입해,
## 그 노드에 도착하면 무료 통과·줍기 카드가 뜨게 한다(self-async, 영구 지형 변화).
func begin_run_in_place() -> void:
	begin_run_with(START_RESOURCES)

## 가방에서 고른 시작 자원으로 새 원정을 만든다 (마을/Loadout 에서 호출). START_RESOURCES 대체.
func begin_run_with(resources: Dictionary, name: String = "", voc_id: String = "", carry_weight: int = 0) -> void:
	current_run = ExpeditionRun.new(resources, bridged_nodes(), flags, pickup_traces_by_node(), voc_id, carry_weight)
	expedition_count += 1
	# 이번 원정대 이름 — 지정 없으면 랜덤(begin_run_in_place·디버그 진입 등). 인덱스 = 회차-1 로 정렬.
	var nm: String = name
	if nm == "":
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		nm = ExpeditionNamer.random(rng)
	expedition_names.append(nm)
	_mark_visited(MapGraph.START_ID)

## n번째(1-based) 원정의 이름. 없으면(기존 세이브 등) 기본 문구.
func expedition_name(n: int) -> String:
	var i: int = n - 1
	if i >= 0 and i < expedition_names.size():
		var nm: String = str(expedition_names[i])
		if nm != "":
			return nm
	return "이름 없는 원정대"

## 지금 진행 중(또는 마지막) 원정의 이름.
func current_expedition_name() -> String:
	return expedition_name(expedition_count)

## 시장이 원정 기록지를 건넨다 (첫 원정) — 이후 책갈피(Bookmark)가 상시 뜬다.
func give_record() -> void:
	if not record_seen:
		record_seen = true
		save_game()

## 첫 원정 조작 오버레이 튜토리얼을 봤다고 기록 (영속). Tutorial 이 완료/스킵 시 호출.
func mark_controls_tutorial_seen() -> void:
	if not controls_tutorial_seen:
		controls_tutorial_seen = true
		save_game()

## 지도에서 고른 노드로 향하기 시작한다(엣지 시작, 씬 전환 없음). 마커 이동·소모는 Map 이 처리한다.
func begin_travel(target_id: String) -> void:
	if current_run != null:
		current_run.begin_edge(target_id)

## 목표 노드에 도착했을 때 그 노드 화면으로 전환한다 (Map 이 호출).
func go_to_expedition() -> void:
	Transition.go(SCENE_EXPEDITION)

## 노드에 도착해 지도로 돌아간다 (횡스크롤 → 지도). 현재 노드를 목표로 옮긴다.
func arrive_node() -> void:
	if current_run != null:
		current_run.arrive()
		_mark_visited(current_run.current_node)
	Transition.go(SCENE_MAP)

# --- 결말 (기획서 §3 결말: 순환과 재회) ---

## end 도달 시 엔딩 종류 — "reunion"(재회) = 흔적 충분 축적 + 무사 도달(alive), 아니면 "cycle"(순환).
## 밸런싱 북극성: 승리 = 한 번의 런이 아니라 여러 원정에 걸친 흔적 축적. REUNION_TRACES 가 돌파 난이도.
func ending_kind() -> String:
	if current_run != null and current_run.alive and player_trace_count() >= REUNION_TRACES:
		return "reunion"
	return "cycle"

## end 에 닿았다고 기록한다 (Expedition 엔딩 패널이 뜰 때 1회). ending = ending_kind() 결과("cycle"/"reunion").
## 일대기(Bookmark)가 죽음만이 아니라 "도달/재회"도 보이게 한다. 같은 원정 중복 기록은 막는다.
func mark_arrival(ending: String) -> void:
	for a in arrivals:
		if a is Dictionary and int(a.get("expedition", -1)) == expedition_count:
			return
	arrivals.append({"expedition": expedition_count, "ending": ending})
	save_game()

## 순환 — 이 원정을 닫고 다음 원정을 처음부터 준비한다(흔적·방문 누적은 유지 → 다음이 더 멀리 간다).
## 죽음·순환 모두 여기(go_to_interlude)로 모여, 폭풍 막간을 거쳐 마을로 간다.
func next_expedition() -> void:
	go_to_interlude()

## 원정이 끝났다(죽음/순환). 다음 원정으로 넘어가기 전, 폭풍이 세계를 한 번 쓸고 지나가는 막간(Interlude)을 연다.
## 시간이 흘렀음(불규칙·긴 간격)과 "매번 다른 이가 간다"를 연출로 보이고, 다음 원정대를 지명한 뒤 마을(Loadout)로.
## 원정 주기의 시계 = 폭풍(기획서 §2·§3). "매년"이 아니라 폭풍이 지날 때마다 떠난다.
## (막간은 순수 연출 — 흔적 uses·안개를 실제로 깎지 않는다. 시간 기반 흔적 소멸은 별도 결정 후 후속.)
func go_to_interlude() -> void:
	current_run = null
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	pending_expedition_name = ExpeditionNamer.random(rng)
	Transition.go(SCENE_INTERLUDE)

## 재회(진짜 엔딩) 후 — 타이틀로 돌아간다. 세이브(축적)는 유지된다.
func go_to_title() -> void:
	current_run = null
	Transition.go(SCENE_TITLE)

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
		if not TraceData.is_pickable(kind):   # 자원(물/식량/은신막) + 주머니 도구만 줍기 대상
			continue
		if int(raw.get("uses", 0)) <= 0:
			continue
		if str(raw.get("to_node", "")) != "":   # 엣지 위 흔적은 지나며 줍는다(노드 도착 픽업에서 제외)
			continue
		var nid: String = str(raw.get("node_id", ""))
		if nid == "" or out.has(nid):
			continue
		var tg: Array = raw.get("tags", [])
		out[nid] = {"kind": kind, "tags": tg.duplicate()}
	return out

## 엣지 위 자원 흔적(node_id→to_node, uses>0)을 (from,to)→{kind,tags} 로. 이동 중 그 지점을 지나면 줍기 카드.
func edge_pickup_traces() -> Array:
	var out: Array = []
	for raw in traces:
		if not (raw is Dictionary):
			continue
		var kind: int = int(raw.get("object_kind", -1))
		if not TraceData.is_pickable(kind):   # 자원 + 주머니 도구만 줍기 대상
			continue
		if int(raw.get("uses", 0)) <= 0 or str(raw.get("to_node", "")) == "":
			continue
		var tg: Array = raw.get("tags", [])
		out.append({
			"from": str(raw.get("node_id", "")), "to": str(raw.get("to_node", "")),
			"position": float(raw.get("position", 0.0)), "kind": kind, "tags": tg.duplicate(),
		})
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

## 엣지 위 흔적을 한 번 쓴다 — node_id+to_node+kind 매칭(엣지 픽업 전용, 같은 노드의 노드 흔적과 안 헷갈리게).
func use_trace_edge(node_id: String, to_node: String, kind: int) -> void:
	for i in range(traces.size()):
		var t: Variant = traces[i]
		if not (t is Dictionary):
			continue
		if str(t.get("node_id", "")) == node_id and str(t.get("to_node", "")) == to_node and int(t.get("object_kind", -1)) == kind:
			var u: int = int(t.get("uses", 0)) - 1
			if u <= 0:
				traces.remove_at(i)
			else:
				t["uses"] = u
				traces[i] = t
			save_game()
			return

## blind choice — 이번 런에 이 선택지를 이미 눌러봤나(같은 상황 id + 같은 선택지 index). 겪었으면 결과를 노출한다.
func has_seen_choice(event_id: String, idx: int) -> bool:
	return seen_choices.has("%s#%d" % [event_id, idx])

## 선택지를 눌렀다고 기록한다(그 선택지만 — 선택지 단위). event_id 가 비면 식별 불가라 무시한다.
func mark_choice_seen(event_id: String, idx: int) -> void:
	if event_id != "":
		seen_choices["%s#%d" % [event_id, idx]] = true

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
		"record_seen": record_seen,
		"controls_tutorial_seen": controls_tutorial_seen,
			"village_intro_seen": village_intro_seen,
		"expedition_names": expedition_names,
		"arrivals": arrivals,
		"seen_choices": seen_choices,
		"seeded": seeded,
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
	record_seen = bool(data.get("record_seen", false))
	controls_tutorial_seen = bool(data.get("controls_tutorial_seen", false))
	village_intro_seen = bool(data.get("village_intro_seen", false))
	expedition_names = data.get("expedition_names", [])
	arrivals = data.get("arrivals", [])
	seen_choices = data.get("seen_choices", {})
	seeded = bool(data.get("seeded", false))

## 세이브 초기화 (새 세계). 빈 상태로 덮어쓴다 — 웹/데스크톱 모두 안전.
func reset_save() -> void:
	expedition_count = 0
	traces = []
	deaths = []
	flags = []
	visited_nodes = []
	opening_seen = false
	record_seen = false
	controls_tutorial_seen = false
	village_intro_seen = false
	expedition_names = []
	arrivals = []
	current_run = null
	seen_choices.clear()
	_plant_seeds()      # 새 세계에도 유령 흔적을 다시 심는다(빈 세계 회피)
	seeded = true
	save_game()
