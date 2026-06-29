class_name Situations
extends RefCounted

## 횡스크롤 중 마주치는 "상황" 카드 - 읽고(판독) 한 가지 행동을 고른다(관리·대비).
## This War of Mine 식 정적 결정 화면. 페이싱의 핵심: 걸음마다 동일한 전진 대신, 몇 걸음마다 결정을 얹는다.
##
## 두 종류:
##  1) CATALOG - 일반 상황. 2~4걸음 랜덤 간격으로 떠 길에 잔잔한 결정을 깐다.
##  2) LANDMARKS - 아이코닉한 장소. 정해진 걸음(leg)에 고정으로 떠 페이싱의 앵커가 된다(여러 런에 걸쳐 학습되는 지형).
##
## 순수 데이터 카탈로그. 효과(effect)는 자원 델타 {water/food/rope/shelter: int}.
## 단서(threat)는 위협 삼각형(Threats.Kind)과 연결해 무엇을 대비하는지 읽히게 한다.
## needs 가 있는 선택지는 그 자원이 모자라면 고를 수 없다(대비 자원의 희소성 -> 결정의 무게).

const CATALOG: Array = [
	{
		"id": "rift",
		"threat": Threats.Kind.BLOCKAGE,
		"text": "길이 쩍 벌어졌다. 바닥은 보이지 않는다.",
		"choices": [
			{"label": "로프를 건다", "effect": {"rope": -1}, "needs": {"rope": 1}},
			{"label": "맨몸으로 건넌다", "effect": {"water": -2}},
		],
	},
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
		"id": "storm_omen",
		"threat": Threats.Kind.STORM,
		"text": "바람에 모래가 섞였다. 곧 폭풍이 온다.",
		"choices": [
			{"label": "은신처를 친다", "effect": {"shelter": -1}, "needs": {"shelter": 1}},
			{"label": "강행한다", "effect": {"water": -2, "food": -1}},
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

## 아이코닉한 장소 - 정해진 걸음에 고정으로 등장. 키 = leg(int), 값 = 상황(name 필드 포함).
const LANDMARKS: Dictionary = {
	4: {
		"id": "dry_river",
		"name": "마른 강",
		"threat": Threats.Kind.CONSUMPTION,
		"text": "한때 강이 흐르던 자리. 바닥이 쩍쩍 갈라졌다. 깊이 파면 물기가 남았을지도.",
		"choices": [
			{"label": "바닥을 판다", "effect": {"water": 4, "food": -1}},
			{"label": "그냥 지나친다", "effect": {}},
		],
	},
	10: {
		"id": "ruined_camp",
		"name": "버려진 야영지",
		"threat": Threats.Kind.CONSUMPTION,
		"text": "지난 원정대의 야영지. 천막이 모래에 반쯤 묻혔다. 한 곳만 뒤질 시간이 있다.",
		"choices": [
			{"label": "식량 자루를 챙긴다", "effect": {"food": 3}},
			{"label": "버려진 은신막을 챙긴다", "effect": {"shelter": 1}},
		],
	},
	17: {
		"id": "field_of_bones",
		"name": "뼈의 들판",
		"threat": Threats.Kind.CONSUMPTION,
		"text": "원정대 여럿이 여기서 끝났다. 모래에 반쯤 묻힌 뼈와 물통들.",
		"choices": [
			{"label": "물통을 거둔다", "effect": {"water": 2, "food": 2}},
			{"label": "두 손 모으고 지나친다", "effect": {}},
		],
	},
	25: {
		"id": "storm_gate",
		"name": "폭풍의 문",
		"threat": Threats.Kind.STORM,
		"text": "협곡 입구를 폭풍이 가로막았다. 모래가 살을 벤다.",
		"choices": [
			{"label": "은신처 치고 잦아들길 기다린다", "effect": {"shelter": -1}, "needs": {"shelter": 1}},
			{"label": "눈 감고 뚫고 간다", "effect": {"water": -3, "food": -2}},
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

## 해당 걸음의 랜드마크 상황 (없으면 빈 Dictionary).
static func landmark(leg: int) -> Dictionary:
	return LANDMARKS.get(leg, {})

## 선택지가 지금 가능한지 (needs 충족 여부).
static func can_choose(choice: Dictionary, resources: Dictionary) -> bool:
	var needs: Dictionary = choice.get("needs", {})
	for key in needs:
		if int(resources.get(key, 0)) < int(needs[key]):
			return false
	return true
