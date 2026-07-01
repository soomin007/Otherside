class_name Situations
extends RefCounted

## 횡스크롤 중 마주치는 "상황" 카드 - 읽고(판독) 한 가지 행동을 고른다(관리·대비).
## This War of Mine 식 정적 결정 화면. 페이싱: 걸음마다 동일 전진 대신 몇 걸음마다 결정을 얹는다.
##
## 콘텐츠 두 갈래:
##  1) CATALOG - 일반 상황(주로 소모). 이동 중 2~4걸음 랜덤 간격으로 떠 잔잔한 결정을 깐다.
##  2) 노드 이벤트 풀 - 도착 시 그 노드(`MapGraph.NODES[].events`)에서 하나가 뜬다(같은 장소, 다른 사건).
##     랜드마크 정체(id/name/kind)는 노드가 가진다. kind: "cache"/"blockage"/"storm"/"start"/"end".
##     (⑤ 일원화: 옛 leg 기반 `LANDMARKS` 폐기 — 콘텐츠의 집은 이제 노드 하나. `pick_event` 가 노드 events 를 읽는다.)
##
## 거리 곡선(기획서 §1): 출발지(마을) 근처는 평화·풍요(cache 위주), 멀어질수록 척박·고달픔(위협 위주).
##  배치는 `MapGraph.NODES` 의 row(진행 층)로: 0=마을 → 커질수록 척박(차단·폭풍).
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
##  - action: 자원 델타를 넘는 부수효과("bridge" = 차단에 로프 고정 -> UI 가 그 노드에 ROPE 흔적, "pickup" = 흔적 줍기).
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
	{
		"id": "old_tracks",
		"threat": Threats.Kind.CONSUMPTION,
		"text": "모래에 반쯤 지워진 발자국. 이전 원정대도 여기까지는 왔던 모양이다. 자국은 한쪽으로 휘어 사라진다.",
		"choices": [
			{"label": "발자국을 따라간다", "effect": {"water": -1}},
			{"label": "곧장 내 길로 간다", "effect": {}},
		],
	},
	{
		"id": "scavenge_wreck",
		"threat": Threats.Kind.CONSUMPTION,
		"text": "부서진 수레가 모래에 처박혀 있다. 뒤지면 뭔가 나올지도, 시간만 버릴지도.",
		"choices": [
			{"label": "뒤져 본다", "effect": {"food": 2, "water": -1}},
			{"label": "지나친다", "effect": {}},
		],
	},
	{
		"id": "sun_hammer",
		"threat": Threats.Kind.CONSUMPTION,
		"text": "해가 정수리를 두드린다. 그늘 한 점 없다. 잠깐 쉴지 계속 밀어붙일지.",
		"choices": [
			{"label": "그늘 없이 계속 간다", "effect": {"water": -2}},
			{"label": "천을 둘러쓰고 천천히 간다", "effect": {"water": -1, "food": -1}},
		],
	},
	{
		"id": "loose_sand",
		"threat": Threats.Kind.CONSUMPTION,
		"text": "발이 푹푹 빠지는 고운 모래밭. 한 걸음이 두 걸음 같다.",
		"choices": [
			{"label": "곧장 가로지른다", "effect": {"water": -1, "food": -1}},
			{"label": "단단한 가장자리로 돌아간다", "effect": {"food": -2}},
		],
	},
	{
		"id": "mirage",
		"threat": Threats.Kind.CONSUMPTION,
		"text": "멀리 물빛이 어른거린다. 아지랑이인지 진짜인지 알 수 없다.",
		"choices": [
			{"label": "혹시 몰라 다가가 본다", "effect": {"water": -2}},
			{"label": "속지 않고 길을 지킨다", "effect": {}},
		],
	},
	# --- requires 연쇄: 앞선 선택이 켠 런 플래그가 있을 때만 뜨는 이동 중 상황 ---
	{
		# 독 웅덩이(d2)에서 탁한 물을 마셨으면(pool_drank) 이동 중 탈이 난다.
		"id": "gut_turn",
		"requires": "pool_drank",
		"threat": Threats.Kind.CONSUMPTION,
		"text": "아까 그 물이 속에서 뒤척인다. 식은땀이 난다. 멈춰 게워낼지 참고 갈지.",
		"choices": [
			{"label": "멈춰서 게워내고 간다", "effect": {"food": -2}},
			{"label": "이 악물고 계속 간다", "effect": {"water": -2}},
		],
	},
	{
		# 앞선 차단(b2)에서 로프를 이미 썼으면(rope_spent_now) 로프가 아쉬운 얕은 골을 만난다.
		"id": "no_rope_ledge",
		"requires": "rope_spent_now",
		"threat": Threats.Kind.CONSUMPTION,
		"text": "얕은 골이 앞을 가른다. 로프가 있었으면 단숨에 건넜을 텐데, 앞선 틈에서 다 썼다.",
		"choices": [
			{"label": "돌아서 얕은 데로 건넌다", "effect": {"water": -1, "food": -1}},
			{"label": "미끄러운 벽을 조심조심 내려간다", "effect": {"water": -2}},
		],
	},
]

## 아이코닉한 고정 지형. 키 = leg(int). 각 랜드마크는 events 풀을 가진다(같은 장소, 다른 사건).
## 거리 곡선대로 leg 순 배치: 가까울수록 풍요(cache), 멀수록 척박(위협). CATALOG 와 leg 가 겹치지 않게 둔다.
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
