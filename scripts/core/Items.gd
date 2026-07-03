class_name Items
extends RefCounted

## 가방 아이템 카탈로그 — 자원(물/식량) + 도구(로프/은신막/약초/부싯돌/정화천) + 부작용 아이템. 단일 진실.
##
## 60초식 "이 위기엔 이 도구": resources dict 의 키가 곧 아이템(보유량). 위기 이벤트가
##  needs(그 도구를 가졌나) 로 안전 선택지를 열고 effect(도구 -1) 로 소비한다. can_choose/apply_choice 가 임의 키를 다룬다.
## core 순수 데이터 — GameState/ui 미참조. Loadout(담기)·HUD(표시)·Situations/MapGraph(이벤트)가 읽는다.
##
## 정의: key(resources 키) · label(한글) · start(가방에 담을 때 시작 자원 델타) · desc(가방 설명).

const CATALOG: Array = [
	# 자원 — 매 걸음/주기 소모(수명).
	{"key": "water", "label": "물통", "start": {"water": 7}, "desc": "걸음마다 닳는 목숨."},
	{"key": "food", "label": "식량 자루", "start": {"food": 6}, "desc": "천천히 닳는 양식."},
	# 부작용 아이템 — 식량은 크지만 짜서 시작 물이 준다(트레이드오프).
	{"key": "jerky", "label": "말린 고기", "start": {"food": 9, "water": -2}, "desc": "오래가는 식량. 대신 짜서 더 마른 목."},
	# 위협 대비 도구 — 보유하면 특정 위기에서 안전 선택지가 열린다(needs), 쓰면 소진(effect).
	{"key": "rope", "label": "로프", "start": {"rope": 1}, "desc": "갈라진 틈 건너기. 다음 원정에도 남음."},
	{"key": "shelter", "label": "은신막", "start": {"shelter": 1}, "desc": "폭풍 버티기."},
	{"key": "medicine", "label": "약초 꾸러미", "start": {"medicine": 1}, "desc": "열·탈진 다스리기."},
	{"key": "flint", "label": "부싯돌", "start": {"flint": 1}, "desc": "언 밤의 불 피우기."},
	{"key": "filter", "label": "정화천", "start": {"filter": 1}, "desc": "탁한 물 걸러 마시기."},
]

## resources 가 가질 수 있는 모든 자원/도구 키(초기화·순회용).
const RES_KEYS: Array = ["water", "food", "rope", "shelter", "medicine", "flint", "filter"]

## HUD "보유 도구" 로 보여줄 키(물/식량 제외 — 그 둘은 큰 수치로 따로 보여준다).
const TOOL_KEYS: Array = ["rope", "shelter", "medicine", "flint", "filter"]

## 주머니 도구 — 가방 6칸과 별개로 원정마다 하나 챙기는 선택형 도구(위기 대응 보험). Loadout 이 OptionButton 으로 고른다.
## 로프·은신막은 가방(6칸)에 두어 기존 밸런스를 지키고, 신규 도구만 주머니로 물/식량과의 칸 경쟁에서 뗀다.
const POUCH_TOOLS: Array = ["medicine", "flint", "filter"]

const TOOL_LABEL: Dictionary = {
	"rope": "로프", "shelter": "은신막", "medicine": "약초", "flint": "부싯돌", "filter": "정화천",
}

## 아이템 무게 — 가방 총 무게가 크면 걸음당 물 소모가 는다(ExpeditionRun.WEIGHT_FREE/STEP). 물/식량·말린고기가 무겁다.
const WEIGHT: Dictionary = {
	"water": 3, "food": 3, "jerky": 5, "rope": 1, "shelter": 2, "medicine": 1, "flint": 1, "filter": 1,
}

static func by_key(key: String) -> Dictionary:
	for it in CATALOG:
		if str(it.get("key", "")) == key:
			return it
	return {}

static func label_of(key: String) -> String:
	return str(by_key(key).get("label", key))

static func weight_of(key: String) -> int:
	return int(WEIGHT.get(key, 1))

## 담은 아이템 key 목록의 총 무게(주머니 도구는 호출측에서 따로 더한다).
static func bag_weight(bag: Array) -> int:
	var w: int = 0
	for key in bag:
		w += weight_of(str(key))
	return w

## 담은 아이템 key 목록 → 시작 자원 dict(모든 RES_KEYS 0 초기화 후 start 합산).
static func resources_of(bag: Array) -> Dictionary:
	var res: Dictionary = {}
	for k in RES_KEYS:
		res[k] = 0
	for key in bag:
		var it: Dictionary = by_key(str(key))
		var start: Dictionary = it.get("start", {})
		for rk in start:
			res[rk] = int(res.get(rk, 0)) + int(start[rk])
	return res

## 보유 도구 요약 문자열(HUD) — 0 인 건 뺀다. 예 "로프 1 · 약초 1". 하나도 없으면 "(도구 없음)".
static func tools_summary(resources: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in TOOL_KEYS:
		var n: int = int(resources.get(key, 0))
		if n > 0:
			parts.append("%s %d" % [str(TOOL_LABEL.get(key, key)), n])
	return " · ".join(parts) if not parts.is_empty() else "(도구 없음)"
