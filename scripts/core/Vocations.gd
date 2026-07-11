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

## 직능 목록. 첫 항목(빈 id)은 특기도 약점도 없는 기본(평범).
## 설계(B): 각 특기는 **강점 하나 + 약점 하나**(트레이드오프)다. 그래야 순수 상위호환이 없고
## "평범"(대가 없는 무난한 시작)도 유효한 선택이 된다. 약점은 시작 자원을 0으로 만들지 않게
## 물 커브(desolation) 위주 + 작은 시작 물 감소만 쓴다. 수치는 1차안 — balance_sim/실플레이로 조정.
## desc 는 Loadout 직능 창(520px 컬럼)에 그대로 보인다 — 수동 \n(의미 단위·한 줄 ~26자).
## 효과가 직관적으로 읽혀야 한다(첫 화면에서 만나는 창) — 무엇이 얼마나 달라지는지 수치로 말하되,
## 내부 용어(DESOLATION 등)는 "먼 길에서 물이 덜/더 빨리 닳는다"로 풀어 쓴다.
const LIST: Array = [
	{
		"id": "", "name": "평범한 대장",
		"desc": "특기도 약점도 없다.\n어느 쪽으로도 치우치지 않은 시작.",
	},
	{
		"id": "pathfinder", "name": "길잡이",
		"desc": "먼 길에서 물이 훨씬 덜 닳는다.\n대신 가볍게 떠나 시작 물이 3 적다.",
		"desolation_bonus": 12,
		"start_bonus": {"water": -3},
	},
	{
		"id": "porter", "name": "짐꾼",
		"desc": "물 6, 식량 5를 더 지고 시작한다.\n대신 짐이 무거워\n먼 길에서 물이 더 빨리 닳는다.",
		"start_bonus": {"water": 6, "food": 5},
		"desolation_bonus": -6,
	},
	{
		"id": "waterwise", "name": "물지기",
		"desc": "물을 얻을 때마다 1을 더 얻는다.\n대신 먼 길에서 물이 더 빨리 닳는다.",
		"water_gain_bonus": 1,
		"desolation_bonus": -6,
	},
	{
		"id": "hardy", "name": "강골",
		"desc": "식량이 절반 속도로 닳는다.\n(두 걸음마다 1 → 네 걸음마다 1)\n대신 먼 길에서 물이 조금 더 빨리 닳는다.",
		"food_every_bonus": 2,
		"desolation_bonus": -3,
	},
	{
		"id": "keeper", "name": "유품지기",
		"desc": "물건을 남길 때 잃는 것이 1 적다.\n(물 4 → 3, 식량 3 → 2)\n대신 짐을 아껴 시작 물이 2 적다.",
		"leave_discount": 1,
		"start_bonus": {"water": -2},
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
