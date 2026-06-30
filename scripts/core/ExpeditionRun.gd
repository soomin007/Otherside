class_name ExpeditionRun
extends RefCounted

## 한 번의 원정 상태 + 진행 로직. 노드 그래프(MapGraph)를 엣지 단위로 횡스크롤 전진한다.
## 루프: 지도에서 다음 노드를 고르면 begin_edge → step 으로 그 노드까지 전진 → 도착 시 노드 이벤트 → 지도 복귀(arrive).
## 자원 = 수명(기획서 §3): 걸음마다 닳고(거리 비례), 바닥나면 고갈사. leg = 원정 전체 누적 걸음(거리 곡선의 기준).
##
## ⚠️ 노드화 진행 중: 흔적 줍기·차단 영구화의 노드 연동은 다음 단계. 이번 단계는 핵심 흐름(엣지 전진 + 도착 이벤트 + 일반 상황).
##   (생성자가 받는 bridged/pickup_traces 는 다음 단계용으로 보존만 한다.)

const WATER_PER_STEP: int = 1     ## 물 기본 소모 (출발지 근처). 거리에 따라 늘어난다(water_cost).
const DESOLATION_EVERY: int = 16  ## 이 걸음마다 물 소모 +1 (멀수록 척박 — 거리 곡선)
const FOOD_EVERY: int = 2         ## 식량은 이 걸음 수마다 1 소모 (느린 배고픔)
const GAP_MIN: int = 2            ## 엣지 안 일반 상황 최소 간격 (걸음)
const GAP_MAX: int = 4            ## 엣지 안 일반 상황 최대 간격 (걸음)
const EDGE_LEN: int = 5           ## 노드 사이 한 엣지의 걸음 수 (임시 고정 — 다음에 노드 간 거리로)

## 남길 때 잃는 양 = 다음 원정대가 줍기로 얻는 양(Situations.pickup_trace 와 대칭). 물건 하나 = 그만큼의 희생.
const LEAVE_COST: Dictionary = {"water": 4, "food": 3, "shelter": 1, "rope": 1}

var resources: Dictionary = {}        ## {"water": int, "food": int, "rope": int, "shelter": int}
var leg: int = 0                      ## 원정 전체 누적 걸음(거리 곡선)
var alive: bool = true
var death_cause: String = ""          ## "" | "thirst" | "hunger"
var pending_situation: Dictionary = {} ## 지금 결정해야 할 상황 (비어 있으면 없음)
var bequeathed: bool = false          ## 이번 원정에 "남기기"를 이미 썼나 (런당 1회)
var current_node: String = ""         ## 지금 서 있는 노드(지도 복귀의 기준)

var rng := RandomNumberGenerator.new()
var _last_situation_id: String = ""
var _next_situation_leg: int = 0      ## 다음 일반 상황이 뜰 걸음
var _bridged: Dictionary = {}         ## (보존) 로프가 걸린 차단 leg — 차단 노드화에서 사용 예정
var _flags: Dictionary = {}           ## 켜진 플래그(run ∪ persist). 런 시작 시 영속 플래그 로드, 런 중 sets 로 추가.
var _traces: Dictionary = {}          ## (보존) 줍을 수 있는 과거 흔적 — 흔적 노드화에서 사용 예정
var _target_node: String = ""         ## 이번 엣지의 목표 노드
var _edge_step: int = 0               ## 이번 엣지에서 전진한 걸음
var _edge_len: int = 0

## bridged/persist_flags/pickup_traces = 과거 원정에서 누적된 영속 데이터(GameState 주입). core 는 GameState 미참조(순수성).
func _init(starting: Dictionary = {}, bridged: Array = [], persist_flags: Array = [], pickup_traces: Dictionary = {}) -> void:
	resources = starting.duplicate()
	for lg in bridged:
		_bridged[int(lg)] = true
	for f in persist_flags:
		_flags[str(f)] = true
	_traces = pickup_traces.duplicate(true)
	current_node = MapGraph.START_ID
	rng.randomize()

func get_res(key: String) -> int:
	return int(resources.get(key, 0))

## 한 걸음의 물 소모 — 멀어질수록 커진다(거리 = 척박함의 기울기). 출발지 근처 1, 무인지대로 갈수록 늘어난다.
func water_cost() -> int:
	return WATER_PER_STEP + int(leg / DESOLATION_EVERY)

func is_bridged(lg: int) -> bool:
	return _bridged.has(lg)

func mark_bridged(lg: int) -> void:
	_bridged[lg] = true

func has_flag(f: String) -> bool:
	return _flags.has(f)

func set_flag(f: String) -> void:
	_flags[f] = true

# --- 남기기 (런당 1회, 죽음과 별개) ---

func leave_cost(key: String) -> int:
	return int(LEAVE_COST.get(key, 0))

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

## 이번 엣지의 목표 노드 id (엣지 진행 중이 아니면 빈 문자열).
func target_node_id() -> String:
	return _target_node

## 목표 노드까지 남은 걸음.
func edge_remaining() -> int:
	return maxi(0, _edge_len - _edge_step)

## 한 걸음 전진 — 소모 자원을 차감하고 고갈을 판정한다. 엣지 중엔 일반 상황, 끝에선 도착 노드 이벤트.
func step() -> void:
	if not alive or not pending_situation.is_empty():
		return
	if _target_node == "" or arrived():
		return  # 엣지 시작 전(지도) 또는 이미 도착(복귀 대기)
	leg += 1
	_edge_step += 1
	resources["water"] = get_res("water") - water_cost()
	if leg % FOOD_EVERY == 0:
		resources["food"] = get_res("food") - 1
	_check_death()
	if not alive:
		return
	if _edge_step >= _edge_len:
		# 목표 노드 도착 — 노드 이벤트(events 있으면. start/end 는 없음 → 바로 복귀 대기).
		var node: Dictionary = MapGraph.node(_target_node)
		var ev: Dictionary = Situations.pick_event(node, _flags, rng)
		if not ev.is_empty():
			_set_pending(ev)
	# 엣지 중 일반 상황(이동 중 자잘한 상황)은 다음 단계에서 맵 카드로 부활 — 지금은 도착 이벤트만.

## 상황의 한 선택지를 적용한다 — 자원 델타 반영 후 고갈 판정. 선택이 곧 죽음일 수도 있다.
func apply_choice(effect: Dictionary) -> void:
	for key in effect:
		resources[key] = get_res(key) + int(effect[key])
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
