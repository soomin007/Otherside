class_name ExpeditionRun
extends RefCounted

## 한 번의 원정(현재 진행 중)의 순수 상태 + 전진/소모 로직. 노드·렌더링 무의존, 테스트 가능.
## 자원 = 수명 (기획서 §3): 걸음마다 닳고, 소모 자원이 바닥나면 고갈사(소모 위협 = 갈증).
##
## 이 프로토타입의 목적 = "걸음마다 닳는 자원" 페이싱 검증. 물은 걸음마다, 식량은 천천히 닳아
## 서로 다른 속도의 두 시계를 만든다. 물이 보통 먼저 바닥나는 긴급한 시계.

const WATER_PER_STEP: int = 1  ## 물은 매 걸음 소모 (갈증의 시계)
const FOOD_EVERY: int = 2      ## 식량은 이 걸음 수마다 1 소모 (느린 배고픔)

var resources: Dictionary = {}  ## {"water": int, "food": int, "rope": int, "shelter": int}
var leg: int = 0                ## 전진한 걸음 수
var alive: bool = true
var death_cause: String = ""    ## "" | "thirst" | "hunger"

func _init(starting: Dictionary = {}) -> void:
	resources = starting.duplicate()

func get_res(key: String) -> int:
	return int(resources.get(key, 0))

## 한 걸음 전진 — 소모 자원을 차감하고 고갈을 판정한다. 죽으면 alive=false, death_cause 설정.
func step() -> void:
	if not alive:
		return
	leg += 1
	resources["water"] = get_res("water") - WATER_PER_STEP
	if leg % FOOD_EVERY == 0:
		resources["food"] = get_res("food") - 1
	if get_res("water") <= 0:
		alive = false
		death_cause = "thirst"
	elif get_res("food") <= 0:
		alive = false
		death_cause = "hunger"
