class_name Vocations
extends RefCounted

## 원정대장 직능 — 매 원정 다른 사람이 간다(서사 §2). 출발 전 이번 대장의 특기 하나를 고르면 그 원정의 결이 달라진다.
## 순수 데이터·파라미터(GameState/ui 미참조). 효과는 ExpeditionRun 이 생성자로 주입된 id 로 훅한다.
## UI(Loadout 선택)·저장(GameState)은 이 정의를 읽어 쓴다 — 콘텐츠의 단일 집.
##
## 설계: 전부 "자원=수명" 곡선에 직접 훅되는 효과(거리 곡선·소모·획득·남기기). 강행 피해 완화 등
## 이벤트 레벨 효과는 아이템-이벤트 연동(방향 C, 후속)에서 다룬다. 새 위협은 늘리지 않는다(맥거핀·스코프).
##
## 효과 파라미터(없으면 0/없음):
##  desolation_bonus:  물 거리 가속 완화 — water_cost 의 DESOLATION_EVERY 에 더한다(클수록 후반 덜 가혹).
##  water_per_step_bonus: 걸음당 기본 물 소모 증가(무거운 짐).
##  start_bonus:       시작 자원 가산(생성자에서 1회).
##  water_gain_bonus:  물을 얻을 때(양수 effect) 추가로 +N.
##  food_every_bonus:  식량 소모 주기 증가 — FOOD_EVERY 에 더한다(배고픔 느려짐).
##  leave_discount:    남기기 비용 감소(최소 1 보장).

const DEFAULT_ID: String = ""

## 직능 목록. 첫 항목(빈 id)은 특기 없는 기본. 수치는 balance_sim 으로 조정.
const LIST: Array = [
	{
		"id": "", "name": "평범한 대장",
		"desc": "특기랄 게 없다. 무엇에도 치우치지 않는다.",
	},
	{
		"id": "pathfinder", "name": "길잡이",
		"desc": "메마른 길을 읽는다. 물이 더디게 닳아 더 멀리 간다.",
		"desolation_bonus": 12,
	},
	{
		"id": "porter", "name": "짐꾼",
		"desc": "남보다 많이 지고 나선다. 든든히 출발하지만, 무거운 짐이 뒤로 갈수록 목을 죈다.",
		"start_bonus": {"water": 6, "food": 5},
		"desolation_bonus": -6,
	},
	{
		"id": "waterwise", "name": "물지기",
		"desc": "한 방울도 허투루 흘리지 않는다. 물을 얻을 때마다 한 모금 더 챙긴다.",
		"water_gain_bonus": 1,
	},
	{
		"id": "hardy", "name": "강골",
		"desc": "주린 배를 오래 견딘다. 식량이 천천히 준다.",
		"food_every_bonus": 2,
	},
	{
		"id": "keeper", "name": "유품지기",
		"desc": "물려주는 손이 가볍다. 남기는 데 드는 것이 적다.",
		"leave_discount": 1,
	},
]

## id 로 직능 정의를 찾는다. 없으면 기본(평범한 대장).
static func by_id(id: String) -> Dictionary:
	for v in LIST:
		if str(v.get("id", "")) == id:
			return v
	return LIST[0]

## 고를 수 있는 직능 id 목록(UI 용, 순서 유지).
static func ids() -> Array:
	var out: Array = []
	for v in LIST:
		out.append(str(v.get("id", "")))
	return out

static func name_of(id: String) -> String:
	return str(by_id(id).get("name", ""))
