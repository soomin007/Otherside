class_name ExpeditionRun
extends RefCounted

## 한 번의 원정(현재 진행 중)의 순수 상태 + 전진/소모/상황 로직. 노드·렌더링 무의존, 테스트 가능.
## 자원 = 수명 (기획서 §3): 걸음마다 닳고, 소모 자원이 바닥나면 고갈사(소모 위협 = 갈증).
##
## 페이싱: 매 걸음 자원이 닳고, 결정 상황이 떠 결정을 얹는다.
##  - 일반 상황: 2~4걸음 랜덤 간격(GAP_MIN..GAP_MAX) 으로 등장(Situations.CATALOG).
##  - 랜드마크: 정해진 걸음에 고정 등장(Situations.LANDMARKS) - 아이코닉한 장소가 페이싱의 앵커.
## 물은 걸음마다, 식량은 천천히 닳아 서로 다른 속도의 두 시계. 물이 보통 먼저 바닥나는 긴급한 시계.

const WATER_PER_STEP: int = 1  ## 물은 매 걸음 소모 (갈증의 시계)
const FOOD_EVERY: int = 2      ## 식량은 이 걸음 수마다 1 소모 (느린 배고픔)
const GAP_MIN: int = 2         ## 일반 상황 최소 간격 (걸음)
const GAP_MAX: int = 4         ## 일반 상황 최대 간격 (걸음)

var resources: Dictionary = {}        ## {"water": int, "food": int, "rope": int, "shelter": int}
var leg: int = 0                      ## 전진한 걸음 수
var alive: bool = true
var death_cause: String = ""          ## "" | "thirst" | "hunger"
var pending_situation: Dictionary = {} ## 지금 결정해야 할 상황 (비어 있으면 없음)

var rng := RandomNumberGenerator.new()
var _last_situation_id: String = ""
var _next_situation_leg: int = 0      ## 다음 일반 상황이 뜰 걸음
var _bridged: Dictionary = {}         ## 로프가 걸린 차단 leg 집합(leg->true). 차단=영구 지형 변화의 런타임 표현.

## bridged = 과거 원정에서 로프를 고정한 차단 leg 목록(GameState 가 ROPE 흔적에서 뽑아 주입).
## core 는 GameState 를 참조하지 않는다(순수성) - 영속 데이터는 생성자로 받는다.
func _init(starting: Dictionary = {}, bridged: Array = []) -> void:
	resources = starting.duplicate()
	for lg in bridged:
		_bridged[int(lg)] = true
	rng.randomize()
	_schedule_next()

func get_res(key: String) -> int:
	return int(resources.get(key, 0))

## 이 걸음의 차단에 이미 로프가 걸려 있나 (과거 원정 + 이번 원정에 새로 건 것 포함).
func is_bridged(lg: int) -> bool:
	return _bridged.has(lg)

## 이번 원정에 차단에 로프를 걸었다 - 같은 런의 렌더링이 즉시 반영하도록 표시한다.
func mark_bridged(lg: int) -> void:
	_bridged[lg] = true

## 한 걸음 전진 - 소모 자원을 차감하고 고갈을 판정한다. 살아남으면 랜드마크/일반 상황을 세운다.
func step() -> void:
	if not alive or not pending_situation.is_empty():
		return
	leg += 1
	resources["water"] = get_res("water") - WATER_PER_STEP
	if leg % FOOD_EVERY == 0:
		resources["food"] = get_res("food") - 1
	_check_death()
	if not alive:
		return
	# 랜드마크(고정 지형)가 일반 상황보다 우선. 어느 쪽이 떠도 다음 일반 상황 일정을 새로 잡는다.
	if Situations.LANDMARKS.has(leg):
		var feat: Dictionary = Situations.landmark(leg)
		# 이미 로프를 건 차단이면 과거의 내가 길을 열어둔 통과 카드로 대체(self-async 보상).
		if str(feat.get("kind", "cache")) == "blockage" and _bridged.has(leg):
			_set_pending(Situations.crossed_blockage(feat))
		else:
			_set_pending(feat)
	elif leg >= _next_situation_leg:
		_set_pending(Situations.pick(rng, _last_situation_id))

## 상황의 한 선택지를 적용한다 - 자원 델타 반영 후 고갈 판정. 선택이 곧 죽음일 수도 있다.
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
