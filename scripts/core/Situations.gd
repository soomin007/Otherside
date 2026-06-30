class_name Situations
extends RefCounted

## 횡스크롤 중 마주치는 "상황" 카드 - 읽고(판독) 한 가지 행동을 고른다(관리·대비).
## This War of Mine 식 정적 결정 화면. 페이싱: 걸음마다 동일 전진 대신 몇 걸음마다 결정을 얹는다.
##
## 두 종류:
##  1) CATALOG - 일반 상황(주로 소모). 2~4걸음 랜덤 간격으로 떠 잔잔한 결정을 깐다.
##  2) LANDMARKS - 아이코닉한 고정 지형. 정해진 걸음(leg)에 떠 페이싱의 앵커이자 위협 삼각형의 무대.
##     랜드마크 = 정체성(id/name/kind) + 이벤트 풀(events). 도착할 때마다 풀에서 하나가 뜬다(같은 장소, 다른 사건).
##     kind: "cache"(자원 보충형) / "blockage"(차단, 틈) / "storm"(폭풍 구간, span 걸음).
##
## 이벤트 = {id, threat, text, choices, requires?}.
##  - requires: 과거에 이 랜드마크에서 그 choice_id 를 골랐을 때만 뜨는 변형 이벤트(재방문 반영). 없으면 일반 풀.
## choice = {label, effect, needs?, action?, choice_id?}.
##  - effect: 자원 델타 {water/food/rope/shelter: int}.
##  - needs: 그 자원이 모자라면 못 고름(대비 자원의 희소성 -> 결정의 무게).
##  - action: 자원 델타를 넘는 부수효과("bridge" = 차단에 로프 고정 -> UI 가 그 leg 에 ROPE 흔적을 남긴다).
##  - choice_id: 이 선택을 GameState.landmark_log 에 기록 -> 다음 원정에서 requires 로 변형 이벤트를 깬다(self-async).
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

## 아이코닉한 고정 지형. 키 = leg(int). 각 랜드마크는 events 풀을 가진다(같은 장소, 다른 사건).
## 자원형(cache)과 위협형(blockage/storm)이 번갈아 페이싱을 만든다. CATALOG 와 leg 가 겹치지 않게 둔다.
const LANDMARKS: Dictionary = {
	4: {
		"id": "dry_river",
		"name": "마른 강",
		"kind": "cache",
		"events": [
			{
				"id": "river_dig",
				"threat": Threats.Kind.CONSUMPTION,
				"text": "한때 강이 흐르던 자리. 바닥이 쩍쩍 갈라졌다. 깊이 파면 물기가 남았을지도.",
				"choices": [
					{"label": "바닥을 판다", "effect": {"water": 4, "food": -1}, "choice_id": "dug"},
					{"label": "그냥 지나친다", "effect": {}, "choice_id": "passed"},
				],
			},
			{
				"id": "river_remains",
				"threat": Threats.Kind.CONSUMPTION,
				"text": "마른 강바닥에 부서진 수레와 빈 물통들이 박혀 있다.",
				"choices": [
					{"label": "물통을 뒤진다", "effect": {"water": 2}, "choice_id": "scavenged"},
					{"label": "건드리지 않는다", "effect": {}, "choice_id": "passed"},
				],
			},
			{
				"id": "river_dug_again",
				"requires": "dug",
				"threat": Threats.Kind.CONSUMPTION,
				"text": "지난번 내가 파둔 구덩이가 그대로 있다. 더 깊이 파볼까.",
				"choices": [
					{"label": "더 깊이 판다", "effect": {"water": 5, "food": -2}, "choice_id": "dug"},
					{"label": "이번엔 지나친다", "effect": {}, "choice_id": "passed"},
				],
			},
		],
	},
	7: {
		"id": "cracked_floor",
		"name": "갈라진 바닥",
		"kind": "blockage",
		"threat": Threats.Kind.BLOCKAGE,
		"events": [
			{
				"id": "cracked_floor",
				"threat": Threats.Kind.BLOCKAGE,
				"text": "땅이 쩍 갈라졌다. 바닥은 보이지 않는다. 로프를 걸면 다음에도 건널 수 있다.",
				"choices": [
					{"label": "로프를 고정한다", "effect": {"rope": -1}, "needs": {"rope": 1}, "action": "bridge"},
					{"label": "맨몸으로 무리해서 건넌다", "effect": {"water": -3, "food": -2}},
				],
			},
		],
	},
	10: {
		"id": "ruined_camp",
		"name": "버려진 야영지",
		"kind": "cache",
		"events": [
			{
				"id": "camp_search",
				"threat": Threats.Kind.CONSUMPTION,
				"text": "지난 원정대의 야영지. 천막이 모래에 반쯤 묻혔다. 한 곳만 뒤질 시간이 있다.",
				"choices": [
					{"label": "식량 자루를 챙긴다", "effect": {"food": 3}, "choice_id": "took_food"},
					{"label": "버려진 은신막을 챙긴다", "effect": {"shelter": 1}, "choice_id": "took_shelter"},
				],
			},
			{
				"id": "camp_ashes",
				"threat": Threats.Kind.CONSUMPTION,
				"text": "식은 모닥불 자리. 누군가 최근까지 여기 있었다. 온기가 가신 재뿐.",
				"choices": [
					{"label": "재를 헤집어 쓸 것을 찾는다", "effect": {"food": 2}, "choice_id": "took_food"},
					{"label": "묵념하고 지나친다", "effect": {}, "choice_id": "mourned"},
				],
			},
			{
				"id": "camp_revisit_shelter",
				"requires": "took_shelter",
				"threat": Threats.Kind.CONSUMPTION,
				"text": "내가 은신막을 떼어간 자리. 남은 천 조각이 바람에 떤다. 식량 자루는 아직 있다.",
				"choices": [
					{"label": "식량 자루를 챙긴다", "effect": {"food": 3}, "choice_id": "took_food"},
					{"label": "지나친다", "effect": {}, "choice_id": "mourned"},
				],
			},
		],
	},
	13: {
		"id": "sand_wall",
		"name": "모래의 벽",
		"kind": "storm",
		"span": 3,
		"threat": Threats.Kind.STORM,
		"events": [
			{
				"id": "sand_wall",
				"threat": Threats.Kind.STORM,
				"text": "앞이 온통 모래바람이다. 폭풍 구간이 길게 이어진다.",
				"choices": [
					{"label": "은신처를 치고 버틴다", "effect": {"shelter": -1}, "needs": {"shelter": 1}},
					{"label": "강행 돌파한다", "effect": {"water": -4, "food": -2}},
				],
			},
		],
	},
	17: {
		"id": "field_of_bones",
		"name": "뼈의 들판",
		"kind": "cache",
		"events": [
			{
				"id": "bones_gather",
				"threat": Threats.Kind.CONSUMPTION,
				"text": "원정대 여럿이 여기서 끝났다. 모래에 반쯤 묻힌 뼈와 물통들.",
				"choices": [
					{"label": "물통을 거둔다", "effect": {"water": 2, "food": 2}, "choice_id": "gathered"},
					{"label": "두 손 모으고 지나친다", "effect": {}, "choice_id": "mourned"},
				],
			},
			{
				"id": "bones_marker",
				"threat": Threats.Kind.CONSUMPTION,
				"text": "뼈 무더기 위에 누군가 돌을 쌓아 표식을 남겼다. 글씨는 모래에 지워졌다.",
				"choices": [
					{"label": "돌탑에 하나 더 얹는다", "effect": {}, "choice_id": "stacked"},
					{"label": "물통만 거두고 간다", "effect": {"water": 2}, "choice_id": "gathered"},
				],
			},
			{
				"id": "bones_revisit_mourn",
				"requires": "mourned",
				"threat": Threats.Kind.CONSUMPTION,
				"text": "지난번 그냥 보낸 들판. 뼈들은 더 깊이 묻혔고, 물통 몇은 아직 빛난다.",
				"choices": [
					{"label": "이번엔 거둔다", "effect": {"water": 2, "food": 2}, "choice_id": "gathered"},
					{"label": "또 두 손 모은다", "effect": {}, "choice_id": "mourned"},
				],
			},
		],
	},
	21: {
		"id": "collapsed_wall",
		"name": "무너진 담",
		"kind": "blockage",
		"threat": Threats.Kind.BLOCKAGE,
		"events": [
			{
				"id": "collapsed_wall",
				"threat": Threats.Kind.BLOCKAGE,
				"text": "거대한 담이 길을 막았다. 틈은 좁고 깊다. 로프를 걸면 다음에도 건널 수 있다.",
				"choices": [
					{"label": "로프를 고정한다", "effect": {"rope": -1}, "needs": {"rope": 1}, "action": "bridge"},
					{"label": "맨몸으로 무리해서 넘는다", "effect": {"water": -3, "food": -2}},
				],
			},
		],
	},
	25: {
		"id": "storm_gate",
		"name": "폭풍의 문",
		"kind": "storm",
		"span": 4,
		"threat": Threats.Kind.STORM,
		"events": [
			{
				"id": "storm_gate",
				"threat": Threats.Kind.STORM,
				"text": "협곡 입구를 폭풍이 가로막았다. 모래가 살을 벤다.",
				"choices": [
					{"label": "은신처 치고 잦아들길 기다린다", "effect": {"shelter": -1}, "needs": {"shelter": 1}},
					{"label": "눈 감고 뚫고 간다", "effect": {"water": -5, "food": -2}},
				],
			},
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

## 랜드마크 이벤트 풀에서 하나를 고른다. 과거 선택(past = 그 leg 의 지난 choice_id)에 맞는
## 변형 이벤트(requires == past)가 있으면 그것을 우선, 없으면 requires 없는 일반 풀에서 랜덤.
## 반환 Dictionary 에는 랜드마크 메타(name/kind/threat)를 머지해 카드 렌더가 그대로 쓰게 한다.
static func pick_event(feat: Dictionary, past: String, rng: RandomNumberGenerator) -> Dictionary:
	var events: Array = feat.get("events", [])
	if events.is_empty():
		return {}
	var matched: Array = []
	var base: Array = []
	for ev in events:
		var req: String = str(ev.get("requires", ""))
		if req == "":
			base.append(ev)
		elif past != "" and req == past:
			matched.append(ev)
	var pool: Array = matched if not matched.is_empty() else base
	if pool.is_empty():
		pool = events
	var chosen: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	var out: Dictionary = chosen.duplicate(true)
	out["name"] = feat.get("name", "")
	out["kind"] = feat.get("kind", "cache")
	if not out.has("threat"):
		out["threat"] = feat.get("threat", Threats.Kind.CONSUMPTION)
	return out

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
