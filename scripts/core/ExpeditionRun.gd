class_name ExpeditionRun
extends RefCounted

## 한 번의 원정 상태 + 진행 로직. 노드 그래프(MapGraph)를 엣지 단위로 횡스크롤 전진한다.
## 루프: 지도에서 다음 노드를 고르면 begin_edge → step 으로 그 노드까지 전진 → 도착 시 노드 이벤트 → 지도 복귀(arrive).
## 자원 = 수명(기획서 §3): 걸음마다 닳고(거리 비례), 바닥나면 고갈사. leg = 원정 전체 누적 걸음(거리 곡선의 기준).
##
## 도착 노드 카드 우선순위(self-async): ① 로프 걸린 차단=무료 통과 ② 이전 원정대 흔적=줍기 ③ 노드 이벤트.
## 흔적/차단은 node_id 로 키잉된 과거 데이터(GameState 주입)를 본다. core 는 GameState 미참조(순수성 유지).

## 튜닝 손잡이 — 게임 중엔 아래 기본값으로 고정(정식 플레이는 절대 바꾸지 않는다).
## const 가 아니라 static var 인 이유: 밸런스 시뮬(tests/balance_sim.gd)이 값을 스윕해
## end 도달률·거리 곡선을 정량 비교할 수 있게 하기 위함. 시뮬은 스윕 후 반드시 기본값으로 원복한다.
## 수치를 바꾸면 docs/design/balance_notes.md·기획서 §4.3(거리 곡선)도 같은 커밋에서 갱신.
static var WATER_PER_STEP: int = 1     ## 물 기본 소모 (출발지 근처). 거리에 따라 늘어난다(water_cost).
static var DESOLATION_EVERY: int = 30  ## 이 걸음마다 물 소모 +1 (멀수록 척박 — 거리 곡선)
static var FOOD_EVERY: int = 2         ## 식량은 이 걸음 수마다 1 소모 (느린 배고픔)
static var GAP_MIN: int = 2            ## 엣지 안 일반 상황 최소 간격 (걸음)
static var GAP_MAX: int = 4            ## 엣지 안 일반 상황 최대 간격 (걸음)
static var EDGE_LEN: int = 5           ## 노드 사이 한 엣지의 걸음 수 (임시 고정 — 다음에 노드 간 거리로)
static var EARLY_SAFE_LEG: int = 6     ## 이 걸음 전(마을 근처 첫 엣지)엔 도구 위기(큰 대가) 억제 — 거리 곡선(가까울수록 평화, 기획 §1)
static var WEIGHT_FREE: int = 12       ## 이 무게까지는 무료(물 소모 안 늘어남)
static var WEIGHT_STEP: int = 4        ## 초과 무게 이만큼마다 걸음당 물 +1 (무거운 짐 = 목마름)

## 남길 때 잃는 양 = 다음 원정대가 줍기로 얻는 양(Situations.pickup_trace 와 대칭). 물건 하나 = 그만큼의 희생.
const LEAVE_COST: Dictionary = {"water": 4, "food": 3, "shelter": 1, "rope": 1}

var resources: Dictionary = {}        ## {"water": int, "food": int, "rope": int, "shelter": int}
var leg: int = 0                      ## 원정 전체 누적 걸음(거리 곡선)
var alive: bool = true
var death_cause: String = ""          ## "" | "thirst" | "hunger"
var pending_situation: Dictionary = {} ## 지금 결정해야 할 상황 (비어 있으면 없음)
var bequeathed: bool = false          ## 이번 원정에 "남기기"를 이미 썼나 (런당 1회)
var current_node: String = ""         ## 지금 서 있는 노드(지도 복귀의 기준)
var vocation_id: String = ""          ## 이번 원정 대장의 직능 id(저장·표시용, Vocations)
var _vocation: Dictionary = {}        ## 직능 정의 — 효과 파라미터의 출처(생성자에서 로드)
var carry_weight: int = 0             ## 가방 총 무게(무거우면 물 소모↑). Loadout 이 주입, 기본 0=무게 무시.

var rng := RandomNumberGenerator.new()
var _last_situation_id: String = ""
var _next_situation_leg: int = 0      ## 다음 일반 상황이 뜰 걸음
var _bridged: Dictionary = {}         ## 로프가 걸린 차단 노드(node_id→true) — 그 노드 도착 시 무료 통과
var _flags: Dictionary = {}           ## 켜진 플래그(run ∪ persist). 런 시작 시 영속 플래그 로드, 런 중 sets 로 추가.
var _traces: Dictionary = {}          ## 줍을 수 있는 과거 흔적(node_id→{kind,tags}) — 그 노드 도착 시 줍기 카드
var _target_node: String = ""         ## 이번 엣지의 목표 노드
var _edge_step: int = 0               ## 이번 엣지에서 전진한 걸음
var _edge_len: int = 0

## bridged_nodes/persist_flags/pickup_traces = 과거 원정에서 누적된 영속 데이터(GameState 주입). core 는 GameState 미참조(순수성).
## voc_id = 이번 원정 대장의 직능(Vocations). 기본 "" = 평범(효과 없음) → 기존 호출부(4인자)를 안 깨뜨린다.
func _init(starting: Dictionary = {}, bridged_nodes: Array = [], persist_flags: Array = [], pickup_traces: Dictionary = {}, voc_id: String = "", weight: int = 0) -> void:
	resources = starting.duplicate()
	vocation_id = voc_id
	carry_weight = weight
	_vocation = Vocations.by_id(voc_id)
	# 직능 시작 보너스(짐꾼 등) — 시작 자원에 1회 가산.
	var start_bonus: Dictionary = _vocation.get("start_bonus", {})
	for k in start_bonus:
		resources[k] = int(resources.get(k, 0)) + int(start_bonus[k])
	for nid in bridged_nodes:
		_bridged[str(nid)] = true
	for f in persist_flags:
		_flags[str(f)] = true
	_traces = pickup_traces.duplicate(true)
	current_node = MapGraph.START_ID
	rng.randomize()

func get_res(key: String) -> int:
	return int(resources.get(key, 0))

## 한 걸음의 물 소모 — 멀어질수록 커진다(거리 = 척박함의 기울기). 출발지 근처 1, 무인지대로 갈수록 늘어난다.
## 직능: 길잡이는 곡선 완화(desolation_bonus), 짐꾼은 무거워 기본 소모 +1(water_per_step_bonus).
func water_cost() -> int:
	var deso: int = DESOLATION_EVERY + int(_vocation.get("desolation_bonus", 0))
	var heavy: int = maxi(0, carry_weight - WEIGHT_FREE) / maxi(1, WEIGHT_STEP)  # 무거운 짐 → 걸음당 물↑
	return WATER_PER_STEP + int(_vocation.get("water_per_step_bonus", 0)) + heavy + int(leg / maxi(1, deso))

func is_bridged(node_id: String) -> bool:
	return _bridged.has(node_id)

func mark_bridged(node_id: String) -> void:
	_bridged[node_id] = true

func has_flag(f: String) -> bool:
	return _flags.has(f)

func set_flag(f: String) -> void:
	_flags[f] = true

# --- 남기기 (런당 1회, 죽음과 별개) ---

## 남기기 비용 — 직능 유품지기는 완화(leave_discount, 최소 1 보장: 공짜 남기기는 없다).
func leave_cost(key: String) -> int:
	var base: int = int(LEAVE_COST.get(key, 0))
	if base <= 0:
		return 0
	return maxi(1, base - int(_vocation.get("leave_discount", 0)))

## 지금 이 자원을 남길 수 있나 — 토큰 미사용 + 보유량 충분 + 생존 자원(물/식량)은 남기고도 살아남아야(>=1).
func can_leave(key: String) -> bool:
	if bequeathed:
		return false
	var cost: int = leave_cost(key)
	if cost <= 0 or get_res(key) < cost:
		return false
	if (key == "water" or key == "food") and get_res(key) - cost < 1:
		return false
	return true

## 물건을 남긴다 — 자원을 비용만큼 잃고(자기 수명 깎기) 토큰을 소진한다. 흔적 자체는 UI/GameState 가 만든다.
func do_leave(key: String) -> void:
	resources[key] = get_res(key) - leave_cost(key)
	bequeathed = true

# --- 노드 진행 (지도 ↔ 횡스크롤) ---

## 지도에서 고른 다음 노드로 향하는 엣지를 시작한다(횡스크롤 진입 시).
func begin_edge(target_id: String) -> void:
	_target_node = target_id
	_edge_len = EDGE_LEN
	_edge_step = 0
	_schedule_next()

## 이번 엣지의 목표 노드에 도착했나(이벤트/복귀 대기).
func arrived() -> bool:
	return _target_node != "" and _edge_step >= _edge_len

## 도착 처리 — 지도 복귀 시 현재 노드를 목표로 옮기고 엣지를 닫는다.
func arrive() -> void:
	if _target_node == "":
		return
	current_node = _target_node
	_target_node = ""
	_edge_step = 0
	_edge_len = 0

## 목적지(end)에 닿았나 — 지도 복귀(arrive) 후 판정.
func at_end() -> bool:
	return current_node == "end"

## 이번 엣지의 목표 노드 id = 지금 결정 중인 "도착한 노드"(엣지 진행 중이 아니면 빈 문자열).
## 흔적/로프/줍기를 어느 노드에 기록·적용할지의 기준.
func target_node_id() -> String:
	return _target_node

## 죽은 위치의 노드 — 도착해서 죽었으면 그 노드(_target_node), 이동 중(엣지) 죽었으면 떠나온 노드(current_node).
func death_node_id() -> String:
	return _target_node if arrived() else current_node

## 목표 노드까지 남은 걸음.
func edge_remaining() -> int:
	return maxi(0, _edge_len - _edge_step)

## 한 걸음 전진 — 소모 자원을 차감하고 고갈을 판정한다. 엣지 중엔 이동 중 상황, 도착하면 arrived()만 true(카드는 단면이 낸다).
func step() -> void:
	if not alive or not pending_situation.is_empty():
		return
	if _target_node == "" or arrived():
		return  # 엣지 시작 전(지도) 또는 이미 도착(복귀 대기)
	leg += 1
	_edge_step += 1
	resources["water"] = get_res("water") - water_cost()
	var food_every: int = FOOD_EVERY + int(_vocation.get("food_every_bonus", 0))  # 강골: 주기 ↑ → 배고픔 느림
	if food_every > 0 and leg % food_every == 0:
		resources["food"] = get_res("food") - 1
	_check_death()
	if not alive:
		return
	if _edge_step < _edge_len and leg >= _next_situation_leg:
		# 엣지 중(도착 전) 일반 상황 — 이동 중 자잘한 결정(맵 카드로 뜬다). 직전과 같은 id 는 피한다.
		var sit: Dictionary = Situations.pick(rng, _last_situation_id, _flags, leg < EARLY_SAFE_LEG, MapGraph.biome_of(_target_node))
		if not sit.is_empty():
			_set_pending(sit)
	# 도착(_edge_step >= _edge_len)이면 카드를 자동으로 안 띄운다 — 그 노드 단면(SectionRun)이 지점으로 낸다.

## 도착 노드의 "주요 지점" 카드를 계산해 반환한다 (부작용 없음 — 단면 SectionRun 이 쓴다).
## 우선순위: ① 로프 걸린 차단 무료 통과 ② 이전 원정대 흔적 줍기 ③ 노드 이벤트. 셋 다 없으면 빈 Dictionary.
func arrival_event() -> Dictionary:
	var node: Dictionary = MapGraph.node(_target_node)
	if str(node.get("kind", "")) == "blockage" and is_bridged(_target_node):
		return Situations.crossed_blockage(node)
	if _traces.has(_target_node):
		return Situations.pickup_trace(_traces[_target_node])
	return Situations.pick_event(node, _flags, rng)

## 카드 하나를 결정 대기로 올린다 — 단면의 주요 지점을 탭했을 때 ui 가 호출한다.
func raise_situation(ev: Dictionary) -> void:
	if not ev.is_empty():
		_set_pending(ev)

## 상황의 한 선택지를 적용한다 — 자원 델타 반영 후 고갈 판정. 선택이 곧 죽음일 수도 있다.
## 직능: 물지기는 물을 얻을 때(양수) 한 모금 더(water_gain_bonus). 잃을 때는 그대로.
func apply_choice(effect: Dictionary) -> void:
	var water_gain: int = int(_vocation.get("water_gain_bonus", 0))
	for key in effect:
		var delta: int = int(effect[key])
		if key == "water" and delta > 0 and water_gain > 0:
			delta += water_gain
		resources[key] = get_res(key) + delta
	pending_situation = {}
	_check_death()

func _set_pending(sit: Dictionary) -> void:
	pending_situation = sit
	_last_situation_id = str(sit.get("id", ""))
	_schedule_next()

func _schedule_next() -> void:
	_next_situation_leg = leg + rng.randi_range(GAP_MIN, GAP_MAX)

func _check_death() -> void:
	if get_res("water") <= 0:
		alive = false
		death_cause = "thirst"
	elif get_res("food") <= 0:
		alive = false
		death_cause = "hunger"
