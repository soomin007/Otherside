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
## 거리 곡선(기획서 §1): 출발지(마을) 근처는 평화·풍요(cache 위주), 멀어질수록 척박·고달픔(위협 위주).
##  배치: 4 마른 강·8 야영지(풍요) → 12 차단·16 폭풍(중반) → 20 뼈의 들판·24 차단·28 폭풍의 문(척박).
##
## 선택 반영(기획서 §1, 제일 중요한 축): 한 선택이 "플래그"를 켜고, 그게 이후 이벤트를 바꾼다.
##  - sets: 런 한정 플래그(이번 원정 안에서만) — 같은 런 연쇄(앞 선택이 뒤 이벤트를 바꿈).
##  - sets_persist: 영속 플래그(세이브) — 다음 원정에 반영(재방문 변형 등). self-async.
##  - requires: 그 플래그(run 또는 persist)가 켜져 있을 때만 뜨는 변형 이벤트/상황.
##
## 이벤트 = {id, threat, text, choices, requires?}.
## choice = {label, effect, needs?, action?, sets?, sets_persist?}.
##  - effect: 자원 델타 {water/food/rope/shelter: int}.
##  - needs: 그 자원이 모자라면 못 고름(대비 자원의 희소성 -> 결정의 무게).
##  - action: 자원 델타를 넘는 부수효과("bridge" = 차단에 로프 고정 -> UI 가 그 leg 에 ROPE 흔적을 남긴다).
##  - sets / sets_persist: 켤 플래그 목록(런 / 영속).
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
		"text": "이전 원정대가 물통을 두고 갔다. 곁의 표식: [ 또 · 봐 ]",
		"choices": [
			{"label": "집는다", "effect": {"water": 4}},
			{"label": "남겨둔다 (다음 원정대에게)", "effect": {}},
		],
	},
]

## 아이코닉한 고정 지형. 키 = leg(int). 각 랜드마크는 events 풀을 가진다(같은 장소, 다른 사건).
## 거리 곡선대로 leg 순 배치: 가까울수록 풍요(cache), 멀수록 척박(위협). CATALOG 와 leg 가 겹치지 않게 둔다.
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
					{"label": "바닥을 판다", "effect": {"water": 4, "food": -1}, "sets_persist": ["river_dug"]},
					{"label": "그냥 지나친다", "effect": {}},
				],
			},
			{
				"id": "river_remains",
				"threat": Threats.Kind.CONSUMPTION,
				"text": "마른 강바닥에 부서진 수레와 빈 물통들이 박혀 있다.",
				"choices": [
					{"label": "물통을 뒤진다", "effect": {"water": 2}},
					{"label": "건드리지 않는다", "effect": {}},
				],
			},
			{
				"id": "river_dug_again",
				"requires": "river_dug",
				"threat": Threats.Kind.CONSUMPTION,
				"text": "지난번 내가 파둔 구덩이가 그대로 있다. 더 깊이 파볼까.",
				"choices": [
					{"label": "더 깊이 판다", "effect": {"water": 5, "food": -2}, "sets_persist": ["river_dug"]},
					{"label": "이번엔 지나친다", "effect": {}},
				],
			},
		],
	},
	8: {
		"id": "ruined_camp",
		"name": "버려진 야영지",
		"kind": "cache",
		"events": [
			{
				"id": "camp_search",
				"threat": Threats.Kind.CONSUMPTION,
				"text": "지난 원정대의 야영지. 천막이 모래에 반쯤 묻혔다. 한 곳만 뒤질 시간이 있다.",
				"choices": [
					{"label": "식량 자루를 챙긴다", "effect": {"food": 3}},
					# 은신막을 챙기면 이번 런 폭풍이 든든해진다(같은 런 연쇄) + 다음 원정 야영지 변형(영속).
					{"label": "버려진 은신막을 챙긴다", "effect": {"shelter": 1}, "sets": ["camp_shelter_now"], "sets_persist": ["camp_shelter"]},
				],
			},
			{
				"id": "camp_ashes",
				"threat": Threats.Kind.CONSUMPTION,
				"text": "식은 모닥불 자리. 누군가 최근까지 여기 있었다. 온기가 가신 재뿐.",
				"choices": [
					{"label": "재를 헤집어 쓸 것을 찾는다", "effect": {"food": 2}},
					{"label": "묵념하고 지나친다", "effect": {}},
				],
			},
			{
				"id": "camp_revisit_shelter",
				"requires": "camp_shelter",
				"threat": Threats.Kind.CONSUMPTION,
				"text": "내가 은신막을 떼어간 자리. 남은 천 조각이 바람에 떤다. 식량 자루는 아직 있다.",
				"choices": [
					{"label": "식량 자루를 챙긴다", "effect": {"food": 3}},
					{"label": "지나친다", "effect": {}},
				],
			},
		],
	},
	12: {
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
	16: {
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
			{
				# 같은 런 연쇄: 야영지(8)에서 여분 은신막을 챙겼으면(camp_shelter_now) 이 변형이 뜬다.
				"id": "sand_wall_sheltered",
				"requires": "camp_shelter_now",
				"threat": Threats.Kind.STORM,
				"text": "야영지에서 챙긴 여분 은신막이 있다. 이번 폭풍은 한결 든든하게 버틴다.",
				"choices": [
					{"label": "여분 은신막을 친다", "effect": {}},
					{"label": "그래도 강행한다", "effect": {"water": -3}},
				],
			},
		],
	},
	20: {
		"id": "field_of_bones",
		"name": "뼈의 들판",
		"kind": "cache",
		"events": [
			{
				"id": "bones_gather",
				"threat": Threats.Kind.CONSUMPTION,
				"text": "원정대 여럿이 여기서 끝났다. 모래에 반쯤 묻힌 뼈와 물통들.",
				"choices": [
					{"label": "물통을 거둔다", "effect": {"water": 2, "food": 2}},
					{"label": "두 손 모으고 지나친다", "effect": {}, "sets_persist": ["bones_mourned"]},
				],
			},
			{
				"id": "bones_marker",
				"threat": Threats.Kind.CONSUMPTION,
				"text": "뼈 무더기 위에 누군가 돌을 쌓아 표식을 남겼다. 글씨는 모래에 지워졌다.",
				"choices": [
					{"label": "돌탑에 하나 더 얹는다", "effect": {}},
					{"label": "물통만 거두고 간다", "effect": {"water": 2}},
				],
			},
			{
				"id": "bones_revisit_mourn",
				"requires": "bones_mourned",
				"threat": Threats.Kind.CONSUMPTION,
				"text": "지난번 그냥 보낸 들판. 뼈들은 더 깊이 묻혔고, 물통 몇은 아직 빛난다.",
				"choices": [
					{"label": "이번엔 거둔다", "effect": {"water": 2, "food": 2}},
					{"label": "또 두 손 모은다", "effect": {}, "sets_persist": ["bones_mourned"]},
				],
			},
		],
	},
	24: {
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
	28: {
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

## 다음 일반 상황을 고른다. 직전과 같은 id 는 피하고, requires 가 있으면 그 플래그가 켜졌을 때만 후보에 넣는다.
static func pick(rng: RandomNumberGenerator, last_id: String = "", flags: Dictionary = {}) -> Dictionary:
	var pool: Array = []
	for s in CATALOG:
		if str(s.get("id", "")) == last_id:
			continue
		var req: String = str(s.get("requires", ""))
		if req != "" and not flags.has(req):
			continue
		pool.append(s)
	if pool.is_empty():
		# 모두 걸러졌으면 requires 없는 일반 상황으로 폴백
		for s in CATALOG:
			if str(s.get("requires", "")) == "":
				pool.append(s)
	if pool.is_empty():
		pool = CATALOG
	var picked: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	return picked

## 해당 걸음의 고정 지형 (없으면 빈 Dictionary).
static func landmark(leg: int) -> Dictionary:
	return LANDMARKS.get(leg, {})

## 랜드마크 이벤트 풀에서 하나를 고른다. 켜진 플래그(flags = run ∪ persist)에 맞는
## 변형 이벤트(requires in flags)가 있으면 그것을 우선, 없으면 requires 없는 일반 풀에서 랜덤.
## 반환 Dictionary 에는 랜드마크 메타(name/kind/threat)를 머지해 카드 렌더가 그대로 쓰게 한다.
static func pick_event(feat: Dictionary, flags: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var events: Array = feat.get("events", [])
	if events.is_empty():
		return {}
	var matched: Array = []
	var base: Array = []
	for ev in events:
		var req: String = str(ev.get("requires", ""))
		if req == "":
			base.append(ev)
		elif flags.has(req):
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

## 이미 로프가 걸린 차단 지점에 다시 왔을 때의 카드 - 이전 원정대가 길을 열어뒀다(self-async 보상).
## 자원 소모 없이 통과한다. 차단의 정체성("가장 뿌듯한 흔적")을 죽음 너머에서 되돌려받는 순간.
static func crossed_blockage(feat: Dictionary) -> Dictionary:
	return {
		"id": str(feat.get("id", "")) + "_bridged",
		"name": str(feat.get("name", "")),
		"kind": "bridged",
		"threat": Threats.Kind.BLOCKAGE,
		"text": "이전 원정대가 여기 로프를 걸어뒀다. 그대로 건넌다.",
		"choices": [
			{"label": "고맙게 건넌다", "effect": {}},
		],
	}

## 과거 흔적을 마주친 줍기 카드 — 자원 종류별 보충. 집으면 GameState 가 uses 를 1 깎는다(action="pickup").
## 남겨두면 다음 원정대 몫으로 남는다(uses 유지). 흔적은 유한해서 몇 원정에 걸쳐 나눠 쓰다 소진된다.
static func pickup_trace(info: Dictionary) -> Dictionary:
	var kind: int = int(info.get("kind", TraceData.ObjectKind.WATER))
	var tags: Array = info.get("tags", [])
	var res_key: String = "water"
	var amount: int = 4
	var obj_name: String = "물통"
	match kind:
		TraceData.ObjectKind.FOOD:
			res_key = "food"
			amount = 3
			obj_name = "식량 자루"
		TraceData.ObjectKind.SHELTER:
			res_key = "shelter"
			amount = 1
			obj_name = "은신막"
	var tag_str: String = ""
	if not tags.is_empty():
		tag_str = "  곁의 표식: [ %s ]" % " · ".join(PackedStringArray(tags))
	return {
		"id": "pickup",
		"kind": "pickup",
		"threat": Threats.Kind.CONSUMPTION,
		"text": "이전 원정대가 남긴 %s. 아직 쓸 만하다.%s" % [obj_name, tag_str],
		"choices": [
			{"label": "집는다", "effect": {res_key: amount}, "action": "pickup", "trace_kind": kind},
			{"label": "남겨둔다 (다음 원정대에게)", "effect": {}},
		],
	}

## 선택지가 지금 가능한지 (needs 충족 여부).
static func can_choose(choice: Dictionary, resources: Dictionary) -> bool:
	var needs: Dictionary = choice.get("needs", {})
	for key in needs:
		if int(resources.get(key, 0)) < int(needs[key]):
			return false
	return true
