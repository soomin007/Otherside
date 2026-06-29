class_name Situations
extends RefCounted

## 횡스크롤 중 마주치는 "상황" 카드 - 읽고(판독) 한 가지 행동을 고른다(관리·대비).
## This War of Mine 식 정적 결정 화면. 페이싱: 걸음마다 동일 전진 대신 몇 걸음마다 결정을 얹는다.
##
## 두 종류:
##  1) CATALOG - 일반 상황(주로 소모). 2~4걸음 랜덤 간격으로 떠 잔잔한 결정을 깐다.
##  2) LANDMARKS - 아이코닉한 고정 지형. 정해진 걸음(leg)에 떠 페이싱의 앵커이자 위협 삼각형의 무대.
##     kind 로 성격을 가른다:
##       "cache"    - 자원 보충형(소모 완화). 정서적 장소.
##       "blockage" - 차단(틈). 로프 고정 시 영구 흔적(ROPE)을 남겨 다음 원정에서 무료 통과(가장 뿌듯한 흔적).
##       "storm"    - 폭풍 구간(span 걸음). 은신처로 버티거나 강행(대량 유실). 진입 전 _draw 가 띠로 예고.
##
## 순수 데이터 카탈로그. 효과(effect)는 자원 델타 {water/food/rope/shelter: int}.
## needs 가 있는 선택지는 그 자원이 모자라면 고를 수 없다(대비 자원의 희소성 -> 결정의 무게).
## action 은 자원 델타를 넘는 부수효과 신호("bridge" = 차단에 로프 고정 -> UI 가 그 leg 에 ROPE 흔적을 남긴다).
## 단서(threat)는 위협 삼각형(Threats.Kind)과 연결해 무엇을 대비하는지 읽히게 한다.
## 단일 진실: docs/design/SYOTOS_기획서_v0.1.md §4 위협 삼각형.

const CATALOG: Array = [
	{
		"id": "dry_stretch",
		"threat": Threats.Kind.CONSUMPTION,
		"text": "앞이 바싹 메말랐다. 한참 물 한 방울 없을 듯하다.",
		"choices": [
			{"label": "곧장 통과한다", "effect": {"water": -3}},
			{"label": "멀리 돌아 우회한다", "effect": {"water": -1, "food": -1}},
		],
	},
	{
		"id": "fork_road",
		"threat": Threats.Kind.CONSUMPTION,
		"text": "길이 둘로 갈린다. 메마른 지름길과 둘러 가는 먼 길.",
		"choices": [
			{"label": "지름길로 간다", "effect": {"water": -2}},
			{"label": "둘러 간다", "effect": {"food": -2}},
		],
	},
	{
		"id": "past_flask",
		"threat": Threats.Kind.CONSUMPTION,
		"text": "과거의 내가 물통을 두고 갔다. 곁의 표식: [ 또 · 봐 ]",
		"choices": [
			{"label": "집는다", "effect": {"water": 4}},
			{"label": "남겨둔다 (다음 나에게)", "effect": {}},
		],
	},
]

## 아이코닉한 고정 지형. 키 = leg(int), 값 = 지형(kind/name 포함).
## 자원형(cache)과 위협형(blockage/storm)이 번갈아 페이싱을 만든다. CATALOG 와 leg 가 겹치지 않게 둔다.
const LANDMARKS: Dictionary = {
	4: {
		"id": "dry_river",
		"name": "마른 강",
		"kind": "cache",
		"threat": Threats.Kind.CONSUMPTION,
		"text": "한때 강이 흐르던 자리. 바닥이 쩍쩍 갈라졌다. 깊이 파면 물기가 남았을지도.",
		"choices": [
			{"label": "바닥을 판다", "effect": {"water": 4, "food": -1}},
			{"label": "그냥 지나친다", "effect": {}},
		],
	},
	7: {
		"id": "cracked_floor",
		"name": "갈라진 바닥",
		"kind": "blockage",
		"threat": Threats.Kind.BLOCKAGE,
		"text": "땅이 쩍 갈라졌다. 바닥은 보이지 않는다. 로프를 걸면 다음에도 건널 수 있다.",
		"choices": [
			{"label": "로프를 고정한다", "effect": {"rope": -1}, "needs": {"rope": 1}, "action": "bridge"},
			{"label": "맨몸으로 무리해서 건넌다", "effect": {"water": -3, "food": -2}},
		],
	},
	10: {
		"id": "ruined_camp",
		"name": "버려진 야영지",
		"kind": "cache",
		"threat": Threats.Kind.CONSUMPTION,
		"text": "지난 원정대의 야영지. 천막이 모래에 반쯤 묻혔다. 한 곳만 뒤질 시간이 있다.",
		"choices": [
			{"label": "식량 자루를 챙긴다", "effect": {"food": 3}},
			{"label": "버려진 은신막을 챙긴다", "effect": {"shelter": 1}},
		],
	},
	13: {
		"id": "sand_wall",
		"name": "모래의 벽",
		"kind": "storm",
		"span": 3,
		"threat": Threats.Kind.STORM,
		"text": "앞이 온통 모래바람이다. 폭풍 구간이 길게 이어진다.",
		"choices": [
			{"label": "은신처를 치고 버틴다", "effect": {"shelter": -1}, "needs": {"shelter": 1}},
			{"label": "강행 돌파한다", "effect": {"water": -4, "food": -2}},
		],
	},
	17: {
		"id": "field_of_bones",
		"name": "뼈의 들판",
		"kind": "cache",
		"threat": Threats.Kind.CONSUMPTION,
		"text": "원정대 여럿이 여기서 끝났다. 모래에 반쯤 묻힌 뼈와 물통들.",
		"choices": [
			{"label": "물통을 거둔다", "effect": {"water": 2, "food": 2}},
			{"label": "두 손 모으고 지나친다", "effect": {}},
		],
	},
	21: {
		"id": "collapsed_wall",
		"name": "무너진 담",
		"kind": "blockage",
		"threat": Threats.Kind.BLOCKAGE,
		"text": "거대한 담이 길을 막았다. 틈은 좁고 깊다. 로프를 걸면 다음에도 건널 수 있다.",
		"choices": [
			{"label": "로프를 고정한다", "effect": {"rope": -1}, "needs": {"rope": 1}, "action": "bridge"},
			{"label": "맨몸으로 무리해서 넘는다", "effect": {"water": -3, "food": -2}},
		],
	},
	25: {
		"id": "storm_gate",
		"name": "폭풍의 문",
		"kind": "storm",
		"span": 4,
		"threat": Threats.Kind.STORM,
		"text": "협곡 입구를 폭풍이 가로막았다. 모래가 살을 벤다.",
		"choices": [
			{"label": "은신처 치고 잦아들길 기다린다", "effect": {"shelter": -1}, "needs": {"shelter": 1}},
			{"label": "눈 감고 뚫고 간다", "effect": {"water": -5, "food": -2}},
		],
	},
}

## 다음 일반 상황을 고른다. 직전과 같은 id 는 피한다(연속 중복 방지).
static func pick(rng: RandomNumberGenerator, last_id: String = "") -> Dictionary:
	var pool: Array = []
	for s in CATALOG:
		if str(s.get("id", "")) != last_id:
			pool.append(s)
	if pool.is_empty():
		pool = CATALOG
	var picked: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	return picked

## 해당 걸음의 고정 지형 (없으면 빈 Dictionary).
static func landmark(leg: int) -> Dictionary:
	return LANDMARKS.get(leg, {})

## 이미 로프가 걸린 차단 지점에 다시 왔을 때의 카드 - 과거의 내가 길을 열어뒀다(self-async 보상).
## 자원 소모 없이 통과한다. 차단의 정체성("가장 뿌듯한 흔적")을 죽음 너머에서 되돌려받는 순간.
static func crossed_blockage(feat: Dictionary) -> Dictionary:
	return {
		"id": str(feat.get("id", "")) + "_bridged",
		"name": str(feat.get("name", "")),
		"kind": "bridged",
		"threat": Threats.Kind.BLOCKAGE,
		"text": "과거의 내가 여기 로프를 걸어뒀다. 그대로 건넌다.",
		"choices": [
			{"label": "고맙게 건넌다", "effect": {}},
		],
	}

## 선택지가 지금 가능한지 (needs 충족 여부).
static func can_choose(choice: Dictionary, resources: Dictionary) -> bool:
	var needs: Dictionary = choice.get("needs", {})
	for key in needs:
		if int(resources.get(key, 0)) < int(needs[key]):
			return false
	return true
