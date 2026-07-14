extends Node

## 전역 상태 + 씬 라우팅 + 저장/불러오기 (autoload 이름: GameState).
##
## 코어 루프 (기획서 §3): 지도(계획) → 횡스크롤(실행) → 죽음 → 지도 갱신 → 다음 원정.
## 플레이어 = 원정대 총괄자(매번 다른 대장을 보냄)이므로 한 세계의 모든 원정 기록(흔적/죽은 자리)은 한 세이브에 누적된다.
## 1차는 self-async — 이전 원정대(내 과거 런)의 흔적이 다음 원정대에게 남는다.

const SAVE_PATH: String = "user://otherside_save.json"  # 웹에선 브라우저 IndexedDB 에 영속
const SAVE_VERSION: int = 2  ## v2(2026-07-10): 이어하기 저장(run·run_section) 추가. 로더는 키 부재에 관대해 v1 세이브 호환.

signal feat_achieved(feat_id: String)  ## 공훈을 방금 달성 — FeatToast 가 즉시 안내(효과음 포함, 2026-07-14 사용자)

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
var mourned_nodes: Array = []  ## 추모 표식을 남긴 죽은 자리 node_id (영속). 재회 조건의 축 하나(REUNION_MOURN).
var stragglers: Array = []     ## 낙오자가 기다리는 자리 [{node_id, origin:"seed"|"loss", expedition?, cause?}] (영속). 거두면 하나 제거, 대원 손실 자리에서 새로 생긴다(재회 축: REUNION_RESCUES). loss 는 어느 원정(expedition)에서 어떻게(cause) 뒤처졌는지 실어 거두기 카드가 출처를 말한다(2026-07-13).
var reunion_hints_shown: int = 0 ## 시장의 재회 옛말을 들려준 시점의 순환 도달 수 (영속). 순환 엔딩을 볼 때마다 다음 마을에서 한 번씩 다시 들려준다(사용자 확정 2026-07-09).
var expedition_names: Array = [] ## 원정별 이름 (인덱스 = 회차-1, 영속). 랜덤(ExpeditionNamer) 또는 직접 입력(Loadout).
var arrivals: Array = [] ## end 에 닿은 원정 기록 — {expedition:int, ending:"cycle"|"reunion"} (영속). 일대기(Bookmark)가 죽음만이 아니라 도달/재회도 보이게 한다.
var seeded: bool = false ## 유령 흔적(플레이어 이전 원정대들)을 심었나 (영속, 세계당 1회). 빈 세계 회피.
var feat_stats: Dictionary = {} ## 공훈 판정용 누적 통계 (영속) — thirst_deaths/hunger_deaths/heavy_departures. 파생 가능한 값(방문 최심 층·남긴 수)은 저장 안 함(feat_stats_snapshot 이 합성).
var feats_unlocked: Array = []  ## 달성한 공훈 id (영속, Feats.LIST). 달성한 공훈이 직능을 마을로 부른다(직능 해금 — 2026-07-11 사용자 확정).

# --- 현재 원정 한정 상태 (죽으면 리셋) ---
## 초기 자원 — 임시치. 자원 = 수명 (남기면 그만큼 잃는다). 밸런스는 폰 테스트로 검증 예정.
const START_RESOURCES: Dictionary = {"water": 20, "food": 13, "rope": 1, "shelter": 1}
const REUNION_RESCUES: int = 2 ## 재회에 필요한, 이번 런에 거둬 데리고 닿은 낙오자 수(2026-07-10 사용자 확정 — 옛 남김 4(REUNION_TRACES) 축을 교체). 낙오자 = 유령 씨앗 + 과거 런의 대원 손실 자리. 남기기의 가치는 생존 효용·기림으로 존속.
const REUNION_MOURN: int = 2   ## 재회에 필요한 기린(추모한) 죽은 자리 수(2026-07-09 사용자 확정). 추모 = 죽은 자리에 표식(MARK)을 남김(런당 1회의 남기기를 씀). 순환과 재회를 가르는 세 축 = 기림 + 구조 + 온전.
var current_run: ExpeditionRun = null  ## 진행 중인 원정의 순수 상태·로직 (core/ExpeditionRun)
var section_state: Dictionary = {}  ## 진행 중 단면 탐색 스냅샷(SectionRun.to_dict, 노드에 있을 때만) — 이어하기 정밀 복원용. Expedition 이 갱신, 세이브에 실린다.
var ending_kind_pending: String = ""  ## 엔딩 슬라이드쇼(Ending 오버레이)가 읽을 결말("cycle"/"reunion"). Expedition._show_ending 이 세팅.
var pending_expedition_name: String = ""  ## 폭풍 막간(Interlude)이 지명한 다음 원정대 이름 → Loadout 이 초기값으로 소비(비영속).
var pending_feat_notices: Array = []  ## 방금 달성한 공훈 id — Loadout 이 "마을에 새 얼굴" 안내로 소비(비영속).
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
	# 유령 낙오자 — 이전 원정들에서 뒤처진 이들(기획서 §3 재회 축 "구조"). 물이 있는 자리라 버텼다(개연성).
	# b1 이 핵심: b1 은 c1/c2 어느 갈래와도 한 경로에 묶여(재회 런의 2명 동선이 항상 성립) 교착을 막는다.
	for nid in ["b1", "c1", "d2"]:
		stragglers.append({"node_id": nid, "origin": "seed"})

## 플레이어가 남긴 흔적 수(유령 seed 제외). 옛 재회 축(REUNION_TRACES, 2026-07-10 폐기) — 지금은 표시·통계용.
func player_trace_count() -> int:
	var n: int = 0
	for t in traces:
		if t is Dictionary and not bool(t.get("seed", false)):
			n += 1
	return n

# --- 공훈 (업적 — 달성하면 마을에 새 직능이 온다, 2026-07-11 사용자 확정) ---

## 공훈 판정용 통계 스냅샷 — 저장된 카운터 + 파생값(방문 최심 층·남긴 수·도달 기록). Feats.check 가 읽는다.
## 도달 계열(arrivals_total·reunions·intact_arrivals)과 전 노드 방문은 기록형 공훈(명예 기록)의 근거(2026-07-13).
func feat_stats_snapshot() -> Dictionary:
	var reunions: int = 0
	var intact: int = 0
	for a in arrivals:
		if a is Dictionary:
			if str(a.get("ending", "")) == "reunion":
				reunions += 1
			if bool(a.get("intact", false)):
				intact += 1
	return {
		"thirst_deaths": int(feat_stats.get("thirst_deaths", 0)),
		"hunger_deaths": int(feat_stats.get("hunger_deaths", 0)),
		"heavy_departures": int(feat_stats.get("heavy_departures", 0)),
		"max_row_visited": _max_row_visited(),
		"traces_left": player_trace_count(),
		"arrivals_total": arrivals.size(),
		"reunions": reunions,
		"intact_arrivals": intact,
		"all_nodes_visited": 1 if _all_nodes_visited() else 0,
		"blockages_bridged": _blockages_bridged(),
		"vocations_full": 1 if Feats.vocations_open(feats_unlocked).size() >= Vocations.ids().size() - 1 else 0,
	}

func _bump_feat_stat(key: String) -> void:
	feat_stats[key] = int(feat_stats.get(key, 0)) + 1

## 차단 노드에 우리 로프가 남은 곳 수(유령 씨앗 제외) — 기록형 "길을 이어 놓은 원정"의 근거.
## 로프 고정(action bridge)도 남기기(로프)도 같은 ROPE 흔적으로 남는다 — 뒤 원정에게 길을 연 같은 일.
func _blockages_bridged() -> int:
	var seen: Dictionary = {}
	for raw in traces:
		if raw is Dictionary and int(raw.get("object_kind", -1)) == TraceData.ObjectKind.ROPE \
				and not bool(raw.get("seed", false)):
			var nid: String = str(raw.get("node_id", ""))
			if nid != "" and str(MapGraph.node(nid).get("kind", "")) == "blockage":
				seen[nid] = true
	return seen.size()

## 방문한 노드의 가장 깊은 층(MapGraph row) — 길잡이 공훈의 근거.
func _max_row_visited() -> int:
	var m: int = 0
	for nid in visited_nodes:
		m = maxi(m, int(MapGraph.node(str(nid)).get("row", 0)))
	return m

## 밟을 수 있는 모든 노드(목적지 제외)를 방문했나 — 기록형 공훈 "모든 길을 밟은 원정대들"의 근거.
## end 는 방문이 아니라 도달(arrivals)로 남는다. 갈래(b1/b2·c1/c2·d1/d2)를 다 밟아야 하니 본질적으로 여러 원정의 기록.
func _all_nodes_visited() -> bool:
	for nid in MapGraph.NODES:
		if str(MapGraph.NODES[nid].get("kind", "")) == "end":
			continue
		if not visited_nodes.has(str(nid)):
			return false
	return true

## 새로 달성한 공훈이 있으면 기록하고 안내 대기열에 얹는다. 저장은 호출측이 한다(중복 save 방지 —
## 이 함수를 부르는 자리는 전부 직후에 save_game/autosave 가 있다).
## 새 달성이 없을 때까지 반복한다 — "다 모인 마을"(vocations_full)처럼 달성 *결과*(feats_unlocked)에서
## 파생되는 기록은 같은 사건 안에서 연쇄로 이뤄져야 다음 사건으로 밀리지 않는다(2026-07-14).
## 종료 보장: feats_unlocked 는 늘기만 하고 LIST 크기로 유한.
func check_feats() -> void:
	while true:
		var stats: Dictionary = feat_stats_snapshot()
		var grew: bool = false
		for fid in Feats.achieved_ids(stats):
			if not feats_unlocked.has(fid):
				feats_unlocked.append(fid)
				pending_feat_notices.append(fid)
				feat_achieved.emit(str(fid))  # 즉시 안내(FeatToast) — 마을 모달(사람 도착 서사)과 별개
				grew = true
		if not grew:
			return

## 지금 고를 수 있는 직능 id 목록 — 평범("")은 항상 + 공훈으로 마을에 온 이들.
func unlocked_vocations() -> Array:
	var out: Array = [""]
	out.append_array(Feats.vocations_open(feats_unlocked))
	return out

## 방금 달성한 공훈 안내를 꺼내 간다(꺼내면 비운다) — Loadout 이 "마을에 새 얼굴"로 보여준다.
func take_feat_notices() -> Array:
	var out: Array = pending_feat_notices
	pending_feat_notices = []
	return out

# --- 낙오자 (재회 축 "구조" — 뒤처진 이를 거두어 데리고 닿는다, 기획서 §3) ---

## 낙오자가 기다리는 노드 id 목록(중복 제거) — 새 원정에 주입, 지도 마커에도 쓴다.
func straggler_nodes() -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for s in stragglers:
		if s is Dictionary:
			var nid: String = str(s.get("node_id", ""))
			if nid != "" and not seen.has(nid):
				seen[nid] = true
				out.append(nid)
	return out

## 낙오자 출처 요약(노드당 하나 — rescue 제거 순서와 같은 첫 항목) — 새 원정에 주입, 거두기 카드가 출처를 말한다.
## loss 출신은 그 원정의 이름을 싣는다(JSON 왕복으로 expedition 이 float 일 수 있어 int 캐스팅).
func straggler_briefs() -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for s in stragglers:
		if s is Dictionary:
			var nid: String = str(s.get("node_id", ""))
			if nid == "" or seen.has(nid):
				continue
			seen[nid] = true
			var brief: Dictionary = {"node_id": nid, "origin": str(s.get("origin", "seed"))}
			var exp: int = int(s.get("expedition", 0))
			if exp > 0:
				brief["name"] = expedition_name(exp)
			var cause: String = str(s.get("cause", ""))
			if cause != "":
				brief["cause"] = cause
			out.append(brief)
	return out

## 이 노드의 낙오자 하나를 거둔다(세계에서 제거, 행렬 +1 은 run.rescue_straggler 가). 같은 노드에 여럿이면 하나만.
func rescue_straggler(node_id: String) -> void:
	for i in range(stragglers.size()):
		var s: Dictionary = stragglers[i]
		if str(s.get("node_id", "")) == node_id:
			stragglers.remove_at(i)
			save_game()
			return

## 런이 끝날 때(죽음/도달) 이번 런의 대원 손실 자리를 낙오자로 심는다 — 내 실패가 다음에 구할 사람이 된다.
## 거둬서 데려가던 낙오자는 그 런과 운명을 같이한다(사용자 확정 2026-07-10) — 확신 없는 런에 함부로 태우지 마라.
func _harvest_stragglers() -> void:
	if current_run == null:
		return
	for site in current_run.loss_sites:
		if site is Dictionary:
			var nid: String = str(site.get("node_id", ""))
			if nid != "" and nid != MapGraph.START_ID:
				# 어느 원정에서 어떻게 뒤처졌는지도 심는다 — 거두기 카드가 얼굴(원정 이름·사연)을 얻는다.
				stragglers.append({"node_id": nid, "origin": "loss", "expedition": expedition_count, "cause": str(site.get("cause", ""))})
	current_run.loss_sites = []

## 재회 관문의 교착 방지 — 한 경로로 REUNION_RESCUES 명을 거둘 수 있는 낙오자 배치를 보장한다.
## (거둔 낙오자를 데려간 런이 순환 도달로 소진시키면 세계가 빌 수 있다.) 부족하면 b1 부터 다시 심는다 —
## b1 은 어느 갈래(c1/c2·d1/d2)와도 한 경로에 묶인다. 서사: 폭풍이 지날 때마다 또 누군가 뒤처진다.
func _ensure_stragglers() -> void:
	if _has_routable_rescues():
		return
	for nid in ["b1", "c1"]:
		stragglers.append({"node_id": nid, "origin": "seed"})
		if _has_routable_rescues():
			break
	save_game()

## 서로 다른 두 노드에 낙오자가 있고, 한 런의 경로로 둘 다 지날 수 있는가(REUNION_RESCUES=2 기준).
func _has_routable_rescues() -> bool:
	var nodes: Array = straggler_nodes()
	for i in range(nodes.size()):
		for j in range(nodes.size()):
			if i != j and _path_exists(str(nodes[i]), str(nodes[j])):
				return true
	return false

## MapGraph 의 next 방향으로 from → to 경로가 있는가(BFS).
func _path_exists(from_id: String, to_id: String) -> bool:
	var stack: Array = [from_id]
	var seen: Dictionary = {from_id: true}
	while not stack.is_empty():
		var cur: String = str(stack.pop_back())
		if cur == to_id:
			return true
		for nx in MapGraph.node(cur).get("next", []):
			var s: String = str(nx)
			if not seen.has(s):
				seen[s] = true
				stack.append(s)
	return false

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
	_ensure_stragglers()  # 재회 관문 교착 방지 — 거둘 수 있는 낙오자 동선이 항상 존재하게
	current_run = ExpeditionRun.new(resources, bridged_nodes(), flags, pickup_traces_by_node(), voc_id, carry_weight, straggler_briefs())
	expedition_count += 1
	# 이번 원정대 이름 — 지정 없으면 랜덤(begin_run_in_place·디버그 진입 등). 인덱스 = 회차-1 로 정렬.
	var nm: String = name
	if nm == "":
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		nm = ExpeditionNamer.random(rng)
	expedition_names.append(nm)
	if carry_weight > ExpeditionRun.WEIGHT_FREE:
		_bump_feat_stat("heavy_departures")  # 무거운 짐을 지고 떠났다 — 짐꾼 공훈의 근거
	check_feats()
	_mark_visited(MapGraph.START_ID)
	autosave_run()  # 출발 즉시 이어하기 슬롯에 실린다(꾸리기 결과 보존)

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
		autosave_run()

# --- 이어하기 (서스펜드 저장 — 한 슬롯·상시 자동 저장·런 종료 시 삭제·시점 선택 없음) ---

## 길 위에 이어갈 원정이 있나 — 타이틀이 "이어서 간다" 게이트로 쓴다.
func has_resumable_run() -> bool:
	return current_run != null and current_run.alive

## 진행 중 상태를 저장한다. section = 단면 탐색 스냅샷(노드에 있을 때만, 지도에선 비워서 지운다).
func autosave_run(section: Dictionary = {}) -> void:
	section_state = section
	save_game()

## 떠났던 자리에서 잇는다 — 노드 도착 상태면 그 노드 화면, 아니면(엣지 위·지도) 지도로.
func resume_run() -> void:
	if current_run == null:
		return
	if current_run.target_node_id() != "" and current_run.arrived():
		Transition.go(SCENE_EXPEDITION)
	else:
		Transition.go(SCENE_MAP)

## 목표 노드에 도착했을 때 그 노드 화면으로 전환한다 (Map 이 호출).
func go_to_expedition() -> void:
	Transition.go(SCENE_EXPEDITION)

## 노드에 도착해 지도로 돌아간다 (횡스크롤 → 지도). 현재 노드를 목표로 옮긴다.
func arrive_node() -> void:
	if current_run != null:
		current_run.arrive()
		_mark_visited(current_run.current_node)
		autosave_run()  # 노드를 떠난다 — 단면 스냅샷은 비우고(기본 {}) 위치만 싣는다
	Transition.go(SCENE_MAP)

# --- 결말 (기획서 §3 결말: 순환과 재회) ---

## end 도달 시 엔딩 종류 — "reunion"(재회) = 기림 + 구조 + 온전한 도달, 아니면 "cycle"(순환).
## (엔딩은 살아 도착해야만 뜨므로 alive 는 사실상 잉여 — 방어적으로만 유지. 순환과 재회를 가르는 건
##  전부 사람이다(2026-07-10 사용자 확정, 옛 남김 4 축은 폐기):
##  ① 기림(REUNION_MOURN) — 죽은 이를 기렸는가 ② 구조(REUNION_RESCUES) — 뒤처진 이를 거두어
##  이번 런에 데리고 닿았는가 ③ 온전한 도달 — 걷는 이를 아무도 잃지 않았는가(is_intact).
##  축적이 만든 세계(다리·스태시)라야 온전히 걸을 수 있으니, 남기기의 가치는 조건에서 빠져도 존속한다.)
## 밸런싱 북극성: 승리 = 한 번의 런이 아니라 여러 원정에 걸친 축적(지식·다리·스태시·기림). RESCUES/MOURN 이 돌파 난이도.
func ending_kind() -> String:
	if current_run != null and current_run.alive and current_run.is_intact() \
			and current_run.party_gained >= REUNION_RESCUES and mourn_count() >= REUNION_MOURN:
		return "reunion"
	return "cycle"

## end 에 닿았다고 기록한다 (Expedition 엔딩 패널이 뜰 때 1회). ending = ending_kind() 결과("cycle"/"reunion").
## 일대기(Bookmark)가 죽음만이 아니라 "도달/재회"도 보이게 한다. 같은 원정 중복 기록은 막는다.
func mark_arrival(ending: String) -> void:
	for a in arrivals:
		if a is Dictionary and int(a.get("expedition", -1)) == expedition_count:
			return
	# intact = 행렬 손실 0 도달 — 기록형 공훈 "아무도 잃지 않은 원정"의 근거(옛 세이브 기록엔 없음 → false).
	arrivals.append({"expedition": expedition_count, "ending": ending, "intact": current_run != null and current_run.is_intact()})
	_harvest_stragglers()  # 도달한 런의 손실 자리도 낙오자로 남는다(뒤처진 이는 여전히 길 위에 있다)
	check_feats()  # 기록형 공훈(끝까지 간 원정·아무도 잃지 않은 원정·건너편의 재회) — 도달 즉시 판정
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
	_harvest_stragglers()  # 방어적 — 죽음/도달 기록이 놓친 손실 자리가 있어도 런을 닫기 전에 심는다
	current_run = null
	section_state = {}
	save_game()  # 이어하기 슬롯 비우기 — 닫힌 런은 되살릴 수 없다(서스펜드 전용)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	pending_expedition_name = ExpeditionNamer.random(rng)
	Transition.go(SCENE_INTERLUDE)

## 재회(진짜 엔딩) 후 — 타이틀로 돌아간다. 세이브(축적)는 유지된다.
func go_to_title() -> void:
	current_run = null
	section_state = {}
	save_game()  # 이어하기 슬롯 비우기
	Transition.go(SCENE_TITLE)

## 노드를 방문 기록에 더한다(영속). 지도 안개를 걷는다.
func _mark_visited(node_id: String) -> void:
	if node_id != "" and not visited_nodes.has(node_id):
		visited_nodes.append(node_id)
		check_feats()  # 깊은 층 첫 도달(길잡이 공훈) — 같은 save 에 실리게 저장 전에
		save_game()

## 죽기 전 단 한 번 흔적을 남긴다 (기획서 §3). 남김 = 자기 수명 깎기.
func leave_trace(trace: TraceData) -> void:
	traces.append(trace.to_dict())
	check_feats()  # 남긴 수 갱신(유품지기 공훈) — 같은 save 에 실리게 저장 전에
	save_game()  # 남김은 되돌릴 수 없는 결정 — 즉시 영속(이어하기 런 상태도 함께 실린다)

# --- 추모 (죽은 자리 기리기 — 재회 조건의 두 번째 축, 기획서 §3 결말) ---

## 이 노드에 죽은 이가 있나 — 죽음 기록(deaths) 또는 시체 흔적(BODY, 유령 포함: 첫 세계 d1 도 기릴 수 있다).
func is_death_site(node_id: String) -> bool:
	if node_id == "":
		return false
	for d in deaths:
		if d is Dictionary and str(d.get("node_id", "")) == node_id:
			return true
	for t in traces:
		if t is Dictionary and int(t.get("object_kind", -1)) == TraceData.ObjectKind.BODY \
				and str(t.get("node_id", "")) == node_id:
			return true
	return false

func is_mourned(node_id: String) -> bool:
	return mourned_nodes.has(node_id)

## 죽은 자리를 기렸다고 기록(영속). 저장은 호출측(BequeathPanel._commit)이 남기기와 묶어 한 번에.
func mark_mourned(node_id: String) -> void:
	if node_id != "" and not mourned_nodes.has(node_id):
		mourned_nodes.append(node_id)

func mourn_count() -> int:
	return mourned_nodes.size()

## 이 종류("cycle"/"reunion")의 도달 기록이 있나 — 시장 옛말(재회 암시) 게이트 등에 쓴다.
func has_arrival_of(kind: String) -> bool:
	for a in arrivals:
		if a is Dictionary and str(a.get("ending", "")) == kind:
			return true
	return false

## 순환으로 끝에 닿은 횟수 — 시장 옛말은 순환을 볼 때마다 다음 마을에서 한 번씩 들려준다.
func cycle_arrival_count() -> int:
	var n: int = 0
	for a in arrivals:
		if a is Dictionary and str(a.get("ending", "")) == "cycle":
			n += 1
	return n

## 시장의 재회 옛말을 들려줬다고 기록(영속) — 지금까지의 순환 도달 수만큼 소화한 것으로.
func mark_reunion_hint_shown() -> void:
	reunion_hints_shown = cycle_arrival_count()
	save_game()

func record_death(leg: int, node_id: String = "", cause: String = "") -> void:
	deaths.append({"leg": leg, "node_id": node_id, "expedition": expedition_count})
	_harvest_stragglers()  # 죽은 런의 손실 자리를 낙오자로 심는다(데려가던 낙오자는 런과 운명을 같이한다)
	# 공훈 통계 — 사인별 카운트(물지기·강골 해금 근거). 저장은 호출측(Expedition._die → save_game).
	if cause == "thirst":
		_bump_feat_stat("thirst_deaths")
	elif cause == "hunger":
		_bump_feat_stat("hunger_deaths")
	check_feats()

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
		if not TraceData.is_pickable(kind):   # 자원(물/식량/장막) + 주머니 도구만 줍기 대상
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
			"mourned_nodes": mourned_nodes,
			"stragglers": stragglers,
			"reunion_hints_shown": reunion_hints_shown,
		"expedition_names": expedition_names,
		"arrivals": arrivals,
		"seen_choices": seen_choices,
		"seeded": seeded,
		"feat_stats": feat_stats,
		"feats_unlocked": feats_unlocked,
		# 이어하기(서스펜드) — 살아 있는 진행 중 원정만 싣는다. 죽음/도달로 런이 닫히면 다음 저장에서 비워진다.
		# 자유 세이브/로드 아님(사용자 확정 2026-07-10): 한 슬롯, 상시 자동 저장, 시점 선택 없음.
		"run": current_run.to_dict() if (current_run != null and current_run.alive) else {},
		"run_section": section_state if (current_run != null and current_run.alive) else {},
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
	mourned_nodes = data.get("mourned_nodes", [])
	stragglers = data.get("stragglers", [])
	reunion_hints_shown = int(data.get("reunion_hints_shown", 0))
	expedition_names = data.get("expedition_names", [])
	arrivals = data.get("arrivals", [])
	seen_choices = data.get("seen_choices", {})
	seeded = bool(data.get("seeded", false))
	feat_stats = data.get("feat_stats", {})   # JSON 왕복 후 값은 float — 읽는 쪽(snapshot)이 int() 캐스팅
	feats_unlocked = data.get("feats_unlocked", [])
	# 이어하기 — 길 위에 원정이 있었으면 되살린다(타이틀이 "이어서 간다"를 띄운다).
	var run_data: Dictionary = data.get("run", {})
	if not run_data.is_empty():
		current_run = ExpeditionRun.from_dict(run_data)
	section_state = data.get("run_section", {})

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
	mourned_nodes = []
	stragglers = []
	section_state = {}
	reunion_hints_shown = 0
	expedition_names = []
	arrivals = []
	current_run = null
	seen_choices.clear()
	feat_stats = {}
	feats_unlocked = []
	pending_feat_notices = []
	_plant_seeds()      # 새 세계에도 유령 흔적을 다시 심는다(빈 세계 회피)
	seeded = true
	save_game()
