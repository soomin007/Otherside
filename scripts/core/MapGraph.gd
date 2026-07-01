class_name MapGraph
extends RefCounted

## 탑뷰 지도의 고정 노드 그래프 (Slay the Spire 식 분기). 한 세계 = 같은 지도(고정 디자인).
## 목적지(end)까지 가는 길은 하나가 아니다 — 갈림과 합류가 있다.
##
## 노드 = 도착하면 벌어지는 일. 노드가 이벤트 풀(events)을 직접 가진다(콘텐츠의 유일한 집).
## 엣지(next) = 노드 사이 구간 → 다음 턴에 횡스크롤로 잇는다(노드 선택 → 전진 → 도착 이벤트 → 지도 복귀).
##
## 콘텐츠 일원화 완료: 옛 `Situations.LANDMARKS`(leg 기반)의 이벤트 풀을 모두 노드 events 로 이전했다.
##    선택 반영 체인(sets/sets_persist + requires)도 노드에 산다 — 같은 런 연쇄 + 다음 원정 변형.
##    일반 상황(CATALOG)·줍기(pickup_trace)는 Situations 에 남아 이동 중 카드·흔적 줍기로 쓰인다.
##
## 노드 필드:
##  kind: "start"(마을) / "cache"(자원 보충) / "blockage"(차단) / "storm"(폭풍) / "end"(목적지, 미정)
##  name / row(진행 층, 0=마을, 클수록 멀고 척박) / col(같은 row 내 가로 위치 0~1, 렌더용) / next(분기)
##  events: 도착 시 뜨는 이벤트 풀(Situations 와 같은 구조 — pick_event 재활용 가능). start/end 는 없음.
##    이벤트 = {id, threat, text, choices, requires?}. choice = {label, effect, needs?, action?, sets?, sets_persist?}.
## 거리 곡선(기획서 §1): 가까운 row 는 풍요(cache 위주), 먼 row 는 척박(위협 위주).
## 단일 진실: docs/design/SYOTOS_기획서_v0.1.md §5(두 레이어 — 탑뷰 지도).

const START_ID: String = "n0"

const NODES: Dictionary = {
	"n0": {
		"kind": "start", "name": "마을", "row": 0, "col": 0.5, "next": ["a1"],
	},
	"a1": {
		"kind": "cache", "name": "마른 강", "row": 1, "col": 0.5, "next": ["b1", "b2"],
		"events": [
			{
				"id": "river_dig", "threat": Threats.Kind.CONSUMPTION,
				"text": "한때 강이 흐르던 자리. 바닥이 쩍쩍 갈라졌다. 깊이 파면 물기가 남았을지도.",
				"choices": [
					{"label": "바닥을 판다", "effect": {"water": 4, "food": -1}, "sets_persist": ["river_dug"]},
					{"label": "그냥 지나친다", "effect": {}},
				],
			},
			{
				"id": "river_remains", "threat": Threats.Kind.CONSUMPTION,
				"text": "마른 강바닥에 부서진 수레와 빈 물통들이 박혀 있다.",
				"choices": [
					{"label": "물통을 뒤진다", "effect": {"water": 2}},
					{"label": "건드리지 않는다", "effect": {}},
				],
			},
			{
				"id": "river_dug_again", "requires": "river_dug", "threat": Threats.Kind.CONSUMPTION,
				"text": "이전 원정대가 파둔 구덩이가 그대로 있다. 더 깊이 파볼까.",
				"choices": [
					{"label": "더 깊이 판다", "effect": {"water": 5, "food": -2}, "sets_persist": ["river_dug"]},
					{"label": "이번엔 지나친다", "effect": {}},
				],
			},
		],
	},
	"b1": {
		"kind": "cache", "name": "버려진 야영지", "row": 2, "col": 0.28, "next": ["c1", "c2"],
		"events": [
			{
				"id": "camp_search", "threat": Threats.Kind.CONSUMPTION,
				"text": "지난 원정대의 야영지. 천막이 모래에 반쯤 묻혔다. 한 곳만 뒤질 시간이 있다.",
				"choices": [
					{"label": "식량 자루를 챙긴다", "effect": {"food": 3}},
					# 은신막을 챙기면 이번 런 폭풍이 든든해진다(같은 런 연쇄) + 다음 원정 야영지 변형(영속).
					{"label": "버려진 은신막을 챙긴다", "effect": {"shelter": 1}, "sets": ["camp_shelter_now"], "sets_persist": ["camp_shelter"]},
				],
			},
			{
				"id": "camp_ashes", "threat": Threats.Kind.CONSUMPTION,
				"text": "식은 모닥불 자리. 누군가 최근까지 여기 있었다. 온기가 가신 재뿐.",
				"choices": [
					{"label": "재를 헤집어 쓸 것을 찾는다", "effect": {"food": 2}},
					{"label": "묵념하고 지나친다", "effect": {}},
				],
			},
			{
				"id": "camp_revisit_shelter", "requires": "camp_shelter", "threat": Threats.Kind.CONSUMPTION,
				"text": "이전 원정대가 은신막을 떼어간 자리. 남은 천 조각이 바람에 떤다. 식량 자루는 아직 있다.",
				"choices": [
					{"label": "식량 자루를 챙긴다", "effect": {"food": 3}},
					{"label": "지나친다", "effect": {}},
				],
			},
		],
		"spots": [
			{"id": "camp_sacks", "label": "식량 자루", "at": Vector2(0.26, 0.66), "source": "cache", "effect": {"food": 2}, "text": "모래에 반쯤 묻힌 자루. 아직 상하지 않았다."},
			{"id": "camp_cold", "label": "식은 재", "at": Vector2(0.72, 0.6), "source": "empty", "text": "불은 오래전에 꺼졌다. 쓸 것이 없다."},
		],
	},
	"b2": {
		"kind": "blockage", "name": "갈라진 바닥", "row": 2, "col": 0.72, "next": ["c2"],
		"events": [
			{
				"id": "cracked_floor", "threat": Threats.Kind.BLOCKAGE,
				"text": "땅이 쩍 갈라졌다. 바닥은 보이지 않는다. 로프를 걸면 다음에도 건널 수 있다.",
				"choices": [
					{"label": "로프를 고정한다", "effect": {"rope": -1}, "needs": {"rope": 1}, "action": "bridge", "sets": ["rope_spent_now"]},
					{"label": "맨몸으로 무리해서 건넌다", "effect": {"water": -3, "food": -2}},
				],
			},
			{
				"id": "cracked_floor_gust", "threat": Threats.Kind.BLOCKAGE,
				"text": "갈라진 틈에서 모래바람이 솟구쳐 건너편이 흐릿하다. 로프를 걸면 다음에도 건널 수 있다.",
				"choices": [
					{"label": "로프를 고정한다", "effect": {"rope": -1}, "needs": {"rope": 1}, "action": "bridge", "sets": ["rope_spent_now"]},
					{"label": "바람 잦아들 때 맨몸으로 건넌다", "effect": {"water": -2, "food": -2}},
				],
			},
		],
		"spots": [
			{"id": "crack_flask", "label": "틈 아래", "at": Vector2(0.3, 0.66), "source": "cache", "effect": {"water": 2}, "text": "균열 턱에 걸린 물통. 조심히 집어 올린다."},
			{"id": "crack_dark", "label": "틈 속 어둠", "at": Vector2(0.68, 0.62), "source": "empty", "text": "바닥이 보이지 않는다. 손을 넣을 엄두가 안 난다."},
		],
	},
	"c1": {
		"kind": "cache", "name": "오아시스", "row": 3, "col": 0.3, "next": ["d1"],
		"events": [
			{
				"id": "oasis", "threat": Threats.Kind.CONSUMPTION,
				"text": "모래 둔덕 사이 작은 샘. 드물게도 맑은 물이 고여 빛난다.",
				"choices": [
					{"label": "물통을 가득 채운다", "effect": {"water": 5}},
					{"label": "몸을 적시고 쉰다", "effect": {"water": 3, "food": 1}},
				],
			},
		],
		"spots": [
			{"id": "oasis_shade", "label": "야자 그늘", "at": Vector2(0.72, 0.55), "source": "cache", "effect": {"food": 1}, "text": "그늘에서 숨을 고른다. 마른 대추야자 몇 알."},
			{"id": "oasis_edge", "label": "물가", "at": Vector2(0.24, 0.68), "source": "cache", "effect": {"water": 2}, "text": "가장자리에 고인 맑은 물. 물통을 조금 더 채운다."},
		],
	},
	"c2": {
		"kind": "storm", "name": "모래의 벽", "row": 3, "col": 0.72, "next": ["d1", "d2"],
		"events": [
			{
				"id": "sand_wall", "threat": Threats.Kind.STORM,
				"text": "앞이 온통 모래바람이다. 폭풍 구간이 길게 이어진다.",
				"choices": [
					{"label": "은신처를 치고 버틴다", "effect": {"shelter": -1}, "needs": {"shelter": 1}},
					{"label": "강행 돌파한다", "effect": {"water": -4, "food": -2}},
				],
			},
			{
				"id": "sand_wall_sheltered", "requires": "camp_shelter_now", "threat": Threats.Kind.STORM,
				"text": "야영지에서 챙긴 여분 은신막이 있다. 이번 폭풍은 한결 든든하게 버틴다.",
				"choices": [
					{"label": "여분 은신막을 친다", "effect": {}},
					{"label": "그래도 강행한다", "effect": {"water": -3}},
				],
			},
		],
	},
	"d1": {
		"kind": "cache", "name": "뼈의 들판", "row": 4, "col": 0.35, "next": ["e1"],
		"events": [
			{
				"id": "bones_gather", "threat": Threats.Kind.CONSUMPTION,
				"text": "원정대 여럿이 여기서 끝났다. 모래에 반쯤 묻힌 뼈와 물통들.",
				"choices": [
					{"label": "물통을 거둔다", "effect": {"water": 2, "food": 2}},
					{"label": "두 손 모으고 지나친다", "effect": {}, "sets_persist": ["bones_mourned"]},
				],
			},
			{
				"id": "bones_marker", "threat": Threats.Kind.CONSUMPTION,
				"text": "뼈 무더기 위에 누군가 돌을 쌓아 표식을 남겼다. 글씨는 모래에 지워졌다.",
				"choices": [
					{"label": "돌탑에 하나 더 얹는다", "effect": {}},
					{"label": "물통만 거두고 간다", "effect": {"water": 2}},
				],
			},
			{
				"id": "bones_revisit_mourn", "requires": "bones_mourned", "threat": Threats.Kind.CONSUMPTION,
				"text": "지난번 그냥 보낸 들판. 뼈들은 더 깊이 묻혔고, 물통 몇은 아직 빛난다.",
				"choices": [
					{"label": "이번엔 거둔다", "effect": {"water": 2, "food": 2}},
					{"label": "또 두 손 모은다", "effect": {}, "sets_persist": ["bones_mourned"]},
				],
			},
		],
	},
	"d2": {
		"kind": "cache", "name": "독 웅덩이", "row": 4, "col": 0.7, "next": ["e1"],
		"events": [
			{
				"id": "poison_pool", "threat": Threats.Kind.CONSUMPTION,
				"text": "고인 물에서 단내가 올라온다. 갈증엔 유혹이지만 탈이 날지도 모른다.",
				"choices": [
					{"label": "걸러서 조금만 마신다", "effect": {"water": 2}},
					{"label": "위험하다, 지나친다", "effect": {}},
				],
			},
		],
	},
	"e1": {
		"kind": "blockage", "name": "무너진 담", "row": 5, "col": 0.5, "next": ["f1"],
		"events": [
			{
				"id": "collapsed_wall", "threat": Threats.Kind.BLOCKAGE,
				"text": "거대한 담이 길을 막았다. 틈은 좁고 깊다. 로프를 걸면 다음에도 건널 수 있다.",
				"choices": [
					{"label": "로프를 고정한다", "effect": {"rope": -1}, "needs": {"rope": 1}, "action": "bridge"},
					{"label": "맨몸으로 무리해서 넘는다", "effect": {"water": -3, "food": -2}},
				],
			},
			{
				# 같은 런 연쇄: 앞 차단(b2)에서 로프를 이미 썼으면(rope_spent_now) 로프가 없다 — 맨몸뿐.
				"id": "collapsed_wall_noropeleft", "requires": "rope_spent_now", "threat": Threats.Kind.BLOCKAGE,
				"text": "또 막혔다. 로프는 앞선 틈에서 다 썼다. 이번엔 몸으로 부딪는 수밖에 없다.",
				"choices": [
					{"label": "맨몸으로 무리해서 넘는다", "effect": {"water": -3, "food": -2}},
				],
			},
		],
	},
	"f1": {
		"kind": "storm", "name": "폭풍의 문", "row": 6, "col": 0.5, "next": ["end"],
		"events": [
			{
				"id": "storm_gate", "threat": Threats.Kind.STORM,
				"text": "협곡 입구를 폭풍이 가로막았다. 모래가 살을 벤다.",
				"choices": [
					{"label": "은신처 치고 잦아들길 기다린다", "effect": {"shelter": -1}, "needs": {"shelter": 1}},
					{"label": "눈 감고 뚫고 간다", "effect": {"water": -5, "food": -2}},
				],
			},
			{
				"id": "storm_gate_eye", "threat": Threats.Kind.STORM,
				"text": "폭풍 한가운데 바람이 잠깐 멎는 눈이 보인다. 지금 달리면 통과할 수 있을지도.",
				"choices": [
					{"label": "은신처 치고 안전하게 간다", "effect": {"shelter": -1}, "needs": {"shelter": 1}},
					{"label": "폭풍의 눈으로 달린다", "effect": {"water": -3, "food": -1}},
				],
			},
		],
	},
	"end": {
		"kind": "end", "name": "???", "row": 7, "col": 0.5, "next": [],
	},
}

static func node(id: String) -> Dictionary:
	return NODES.get(id, {})

## 진행 층의 최댓값(렌더에서 y 정규화에 쓴다).
static func max_row() -> int:
	var m: int = 0
	for id in NODES:
		m = maxi(m, int(NODES[id].get("row", 0)))
	return m
