class_name ExpeditionRun
extends RefCounted

## 한 번의 원정(현재 진행 중)의 순수 상태 + 전진/소모/상황 로직. 노드·렌더링 무의존, 테스트 가능.
## 자원 = 수명 (기획서 §3): 걸음마다 닳고, 소모 자원이 바닥나면 고갈사(소모 위협 = 갈증).
##
## 페이싱: 매 걸음 자원이 닳고, SITUATION_EVERY 걸음마다 "상황"(Situations)이 떠 결정을 얹는다.
## 물은 걸음마다, 식량은 천천히 닳아 서로 다른 속도의 두 시계. 물이 보통 먼저 바닥나는 긴급한 시계.

const WATER_PER_STEP: int = 1  ## 물은 매 걸음 소모 (갈증의 시계)
const FOOD_EVERY: int = 2      ## 식량은 이 걸음 수마다 1 소모 (느린 배고픔)
const SITUATION_EVERY: int = 3 ## 이 걸음 수마다 상황 카드 1장 (읽고 결정)

var resources: Dictionary = {}        ## {"water": int, "food": int, "rope": int, "shelter": int}
var leg: int = 0                      ## 전진한 걸음 수
var alive: bool = true
var death_cause: String = ""          ## "" | "thirst" | "hunger"
var pending_situation: Dictionary = {} ## 지금 결정해야 할 상황 (비어 있으면 없음)

var rng := RandomNumberGenerator.new()
var _last_situation_id: String = ""

func _init(starting: Dictionary = {}) -> void:
	resources = starting.duplicate()
	rng.randomize()

func get_res(key: String) -> int:
	return int(resources.get(key, 0))

## 한 걸음 전진 — 소모 자원을 차감하고 고갈을 판정한다. 살아남고 주기가 되면 상황 카드를 세운다.
func step() -> void:
	if not alive or not pending_situation.is_empty():
		return
	leg += 1
	resources["water"] = get_res("water") - WATER_PER_STEP
	if leg % FOOD_EVERY == 0:
		resources["food"] = get_res("food") - 1
	_check_death()
	if alive and leg % SITUATION_EVERY == 0:
		pending_situation = Situations.pick(rng, _last_situation_id)
		_last_situation_id = str(pending_situation.get("id", ""))

## 상황의 한 선택지를 적용한다 — 자원 델타 반영 후 고갈 판정. 선택이 곧 죽음일 수도 있다.
func apply_choice(effect: Dictionary) -> void:
	for key in effect:
		resources[key] = get_res(key) + int(effect[key])
	pending_situation = {}
	_check_death()

func _check_death() -> void:
	if get_res("water") <= 0:
		alive = false
		death_cause = "thirst"
	elif get_res("food") <= 0:
		alive = false
		death_cause = "hunger"
