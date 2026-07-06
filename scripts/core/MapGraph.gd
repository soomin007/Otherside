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
##  biome: 그 노드 일대의 지형 — "river"(강바닥·물가) / "rock"(바위·균열) / "storm"(폭풍·사구) / "flats"(평지·사막).
##    kind(도착 위협)와 직교하는 축. 이 하나로 ① 노드로 향하는 엣지 곡선 모양(Map._edge_point)
##    ② 양피지 지형지물 잉크(Map._draw_biomes) ③ 이동 중 이벤트 개연성(Situations.pick biome 가중)을 함께 정한다.
##    엣지 A→B 의 성격 = 도착 노드 B 의 biome("향하는 곳의 지형을 따라간다"). start/end 는 없으면 "flats" 폴백.
##  events: 도착 시 뜨는 이벤트 풀(Situations 와 같은 구조 — pick_event 재활용 가능). start/end 는 없음.
##    이벤트 = {id, threat, text, choices, requires?}. choice = {label, effect, needs?, action?, sets?, sets_persist?}.
## 거리 곡선(기획서 §1): 가까운 row 는 풍요(cache 위주), 먼 row 는 척박(위협 위주).
## 단일 진실: docs/design/SYOTOS_기획서_v0.1.md §5(두 레이어 — 탑뷰 지도).

const START_ID: String = "n0"

const NODES: Dictionary = {
	"n0": {
		"kind": "start", "name": "마을", "row": 0, "col": 0.5, "next": ["a1"], "biome": "flats",
	},
	"a1": {
		"kind": "cache", "name": "마른 강", "row": 1, "col": 0.5, "next": ["b1", "b2"], "biome": "river",
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
		"spots": [
			{"id": "river_puddle", "label": "갈라진 바닥", "at": Vector2(0.26, 0.64), "source": "cache", "effect": {"water": 2}, "text": "금 간 바닥 틈에 흙탕물이 조금 고였다. 걸러서 담는다."},
			{"id": "river_wreck", "label": "부서진 수레", "at": Vector2(0.72, 0.6), "source": "empty", "text": "수레는 오래전에 부서졌다. 쓸 만한 건 이미 누가 가져갔다."},
			{"id": "river_reeds", "label": "마른 갈대", "at": Vector2(0.5, 0.72), "source": "event", "event": {"id": "river_chew", "threat": Threats.Kind.CONSUMPTION, "text": "갈라진 바닥에 마른 갈대 뿌리가 얽혀 있다. 씹으면 요기는 되지만 물기가 빠진다.", "choices": [{"label": "씹어 넘긴다", "effect": {"food": 1, "water": -1}}, {"label": "뱉고 간다", "effect": {}}]}},
			{"id": "river_arrow", "label": "새긴 화살표", "at": Vector2(0.52, 0.4), "source": "event", "event": {"id": "river_arrow", "threat": Threats.Kind.CONSUMPTION, "text": "강바닥 바위에 이전 원정대가 화살표를 새겼다. 물길 반대편 마른 둔덕을 가리킨다. 믿어도 될지.", "choices": [{"label": "가리킨 쪽을 잠깐 뒤진다", "effect": {"water": 2, "food": -2}}, {"label": "믿지 않고 곧장 간다", "effect": {}}]}},
		],
	},
	"b1": {
		"kind": "cache", "name": "버려진 야영지", "row": 2, "col": 0.28, "next": ["c1", "c2"], "biome": "flats",
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
			{"id": "camp_tent", "label": "무너진 천막", "at": Vector2(0.5, 0.42), "source": "event", "event": {"id": "camp_tent_take", "threat": Threats.Kind.CONSUMPTION, "text": "무너진 천막 골조에 성한 은신막 한 장이 걸려 있다. 떼어 가면 폭풍에 든든하지만 짐이 된다.", "choices": [{"label": "떼어 챙긴다", "effect": {"shelter": 1}, "sets": ["camp_shelter_now"], "sets_persist": ["camp_shelter"]}, {"label": "둔다 (짐을 줄인다)", "effect": {}}]}},
			{"id": "camp_well", "label": "야영지 우물", "at": Vector2(0.74, 0.72), "source": "event", "event": {"id": "camp_well_draw", "threat": Threats.Kind.CONSUMPTION, "text": "우물 바닥에 물이 조금 남았다. 두레박 줄이 삭아 길어 올리기 수고롭다.", "choices": [{"label": "식량을 헐어 힘써 길어 올린다", "effect": {"water": 2, "food": -2}}, {"label": "삭은 줄이라 둔다", "effect": {}}]}},
		],
	},
	"b2": {
		"kind": "blockage", "name": "갈라진 바닥", "row": 2, "col": 0.72, "next": ["c2"], "biome": "rock",
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
			{
				"id": "cracked_floor_bones", "threat": Threats.Kind.BLOCKAGE,
				"text": "틈 가장자리에 오래된 뼈 몇이 걸려 있다. 누군가 여기서 미끄러졌다. 로프를 걸면 다음에도 건널 수 있다.",
				"choices": [
					{"label": "로프를 고정한다", "effect": {"rope": -1}, "needs": {"rope": 1}, "action": "bridge", "sets": ["rope_spent_now"]},
					{"label": "조심조심 맨몸으로 건넌다", "effect": {"water": -3, "food": -2}},
				],
			},
		],
		"spots": [
			{"id": "crack_flask", "label": "틈 아래", "at": Vector2(0.3, 0.66), "source": "cache", "effect": {"water": 2}, "text": "균열 턱에 걸린 물통. 조심히 집어 올린다."},
			{"id": "crack_dark", "label": "틈 속 어둠", "at": Vector2(0.68, 0.62), "source": "empty", "text": "바닥이 보이지 않는다. 손을 넣을 엄두가 안 난다."},
			{"id": "crack_scrap", "label": "틈에 걸린 것", "at": Vector2(0.5, 0.36), "source": "event", "event": {"id": "crack_rope_scrap", "threat": Threats.Kind.BLOCKAGE, "text": "틈 벽에 낡은 밧줄 토막이 걸려 있다. 몸을 기울이면 닿을 듯도 하다.", "choices": [{"label": "기울여 잡아 뺀다", "effect": {"rope": 1, "water": -1}}, {"label": "위험하다, 둔다", "effect": {}}]}},
			{"id": "crack_ledge", "label": "균열 벽", "at": Vector2(0.2, 0.46), "source": "event", "event": {"id": "crack_ledge_climb", "threat": Threats.Kind.BLOCKAGE, "text": "균열 벽을 타 넘으면 질러갈 수 있다. 바위가 무르고 미끄럽다.", "choices": [{"label": "조심히 타 넘는다", "effect": {"water": -2}}, {"label": "안전하게 돌아간다", "effect": {"food": -1}}]}},
		],
	},
	"c1": {
		"kind": "cache", "name": "오아시스", "row": 3, "col": 0.3, "next": ["d1"], "biome": "river",
		"events": [
			{
				"id": "oasis", "threat": Threats.Kind.CONSUMPTION,
				"text": "모래 둔덕 사이 작은 샘. 드물게도 맑은 물이 고여 빛난다.",
				"choices": [
					{"label": "물통을 가득 채운다", "effect": {"water": 5}},
					{"label": "몸을 적시고 쉰다", "effect": {"water": 3, "food": 1}},
				],
			},
			{
				"id": "oasis_calm", "threat": Threats.Kind.CONSUMPTION,
				"text": "샘가에 바람이 자고, 물낯이 거울처럼 고요하다. 잠시 숨을 고른다.",
				"choices": [
					{"label": "물통을 채우고 간다", "effect": {"water": 4}},
					{"label": "충분히 쉬었다 간다", "effect": {"water": 2, "food": 2}},
				],
			},
			{
				# self-async: 샘을 파 넓히면 영속(oasis_widened) → 다음 원정 재방문 변형(oasis_deeper). 같은 런엔 물 비축(water_stocked) → f1 폭풍의 문 완화.
				"id": "oasis_widen", "threat": Threats.Kind.CONSUMPTION,
				"text": "샘이 얕다. 둘레를 파 물길을 넓히면 더 고이겠지만, 파는 데 기운이 든다.",
				"choices": [
					{"label": "둘레를 파 물길을 넓힌다", "effect": {"water": 4, "food": -1}, "sets": ["water_stocked"], "sets_persist": ["oasis_widened"]},
					{"label": "고인 만큼만 뜨고 간다", "effect": {"water": 2}},
				],
			},
			{
				"id": "oasis_deeper", "requires": "oasis_widened", "threat": Threats.Kind.CONSUMPTION,
				"text": "이전 원정대가 파 넓혀둔 샘. 물이 더 깊이 고였다.",
				"choices": [
					{"label": "물통을 넉넉히 채운다", "effect": {"water": 5}, "sets": ["water_stocked"]},
					{"label": "몸을 적시고 쉰다", "effect": {"water": 3, "food": 1}},
				],
			},
		],
		"spots": [
			{"id": "oasis_shade", "label": "야자 그늘", "at": Vector2(0.72, 0.55), "source": "cache", "effect": {"food": 1}, "text": "그늘에서 숨을 고른다. 마른 대추야자 몇 알."},
			{"id": "oasis_edge", "label": "물가", "at": Vector2(0.24, 0.68), "source": "cache", "effect": {"water": 3}, "text": "가장자리에 고인 맑은 물. 물통을 넉넉히 채운다."},
			{"id": "oasis_pooled", "label": "넓혀둔 웅덩이", "at": Vector2(0.5, 0.4), "source": "cache", "requires": "oasis_widened", "effect": {"water": 3}, "text": "이전 원정대가 파 넓힌 자리에 물이 그득 고였다. 재방문의 보답."},
			{"id": "oasis_dig", "label": "물가 진흙", "at": Vector2(0.86, 0.42), "source": "cache", "effect": {}, "sets": ["oasis_widened"], "sets_persist": ["oasis_widened"], "text": "물가 진흙을 파 우물을 넓혀 둔다. 지금 손에 쥐는 물은 없지만, 다음에 올 이들 몫이 깊어진다."},
			{"id": "oasis_palm", "label": "야자 꼭대기", "at": Vector2(0.52, 0.72), "source": "event", "event": {"id": "oasis_palm_climb", "threat": Threats.Kind.CONSUMPTION, "text": "야자 꼭대기에 열매가 매달려 있다. 오르면 딸 수 있지만 기운이 빠진다.", "choices": [{"label": "올라가 딴다", "effect": {"food": 1, "water": -1}}, {"label": "둔다", "effect": {}}]}},
		],
	},
	"c2": {
		"kind": "storm", "name": "모래의 벽", "row": 3, "col": 0.72, "next": ["d1", "d2"], "biome": "storm",
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
			{
				# self-async: 묻힌 천막을 파내 은신막을 얻으면 영속(wall_tent_taken) → 다음 원정 재방문 변형(wall_revisit).
				"id": "wall_dig_tent", "threat": Threats.Kind.STORM,
				"text": "모래 둔덕에 천막 한 귀퉁이가 삐져나와 있다. 파내면 은신막이 될지도. 파는 동안 바람에 시달린다.",
				"choices": [
					{"label": "천막을 파낸다", "effect": {"shelter": 1, "water": -1}, "sets_persist": ["wall_tent_taken"]},
					{"label": "몸을 낮추고 버틴다", "effect": {"water": -3}},
				],
			},
			{
				"id": "wall_revisit", "requires": "wall_tent_taken", "threat": Threats.Kind.STORM,
				"text": "이전 원정대가 천막을 떼어간 자리. 기둥 자국과 마른 열매 몇 알만 남았다.",
				"choices": [
					{"label": "남은 것을 챙긴다", "effect": {"food": 1}},
					{"label": "지나친다", "effect": {}},
				],
			},
		],
		"spots": [
			{"id": "wall_tarp", "label": "바람에 걸린 천", "at": Vector2(0.24, 0.62), "source": "cache", "effect": {"water": 2, "food": 1}, "text": "모래 둔덕에 걸린 천 자락. 앞선 원정대가 두고 간 물통과 마른 열매가 싸여 있었다."},
			{"id": "wall_roar", "label": "모래바람 속", "at": Vector2(0.74, 0.58), "source": "empty", "text": "바람이 앞을 삼킨다. 발을 들일 엄두가 안 난다."},
			{"id": "wall_burrow", "label": "바람 그늘", "at": Vector2(0.5, 0.42), "source": "event", "event": {"id": "wall_burrow", "threat": Threats.Kind.STORM, "text": "바람 그늘에 몸을 묻을 모래 굴을 팔 수 있다. 물을 쓰지만 폭풍을 덜 맞고 지난다.", "choices": [{"label": "굴을 파 몸을 숨겨 지난다", "effect": {"water": -1}}, {"label": "맞바람에 강행한다", "effect": {"water": -3, "food": -1}}]}},
			{"id": "wall_bundle", "label": "굴러온 덤불", "at": Vector2(0.72, 0.72), "source": "event", "event": {"id": "wall_bundle_dig", "threat": Threats.Kind.STORM, "text": "바람에 굴러온 마른 덤불 뭉치. 모래를 헤집으면 누군가 싼 마른 열매가 나올 듯도 하다.", "choices": [{"label": "바람 맞으며 헤집는다", "effect": {"food": 2, "water": -2}}, {"label": "지나친다", "effect": {}}]}},
		],
	},
	"d1": {
		"kind": "cache", "name": "뼈의 들판", "row": 4, "col": 0.35, "next": ["e1"], "biome": "flats",
		"events": [
			{
				"id": "bones_gather", "threat": Threats.Kind.CONSUMPTION,
				"text": "원정대 여럿이 여기서 끝났다. 모래에 반쯤 묻힌 뼈와 물통들.",
				"choices": [
					{"label": "물통을 거둔다", "effect": {"water": 3, "food": 2}},
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
		"spots": [
			{"id": "bones_flask", "label": "흩어진 물통", "at": Vector2(0.28, 0.66), "source": "cache", "effect": {"water": 3}, "text": "뼈 사이에 굴러다니는 물통들. 아직 몇 모금 남았다."},
			{"id": "bones_pile", "label": "뼈 무더기", "at": Vector2(0.7, 0.62), "source": "empty", "text": "모래에 반쯤 묻힌 뼈들. 두 손을 모으고 지나친다."},
			{"id": "bones_offer", "label": "돌 표식", "at": Vector2(0.5, 0.42), "source": "cache", "effect": {}, "sets": ["bones_mourned"], "sets_persist": ["bones_mourned"], "text": "뼈 사이 돌 표식에 돌 하나를 얹어 애도한다. 이름 모를 원정대에게."},
			{"id": "bones_pick", "label": "눌린 배낭", "at": Vector2(0.72, 0.72), "source": "event", "event": {"id": "bones_pick_through", "threat": Threats.Kind.CONSUMPTION, "text": "뼈 무더기 아래 가죽 배낭이 눌려 있다. 헤집으면 뭔가 나올지도.", "choices": [{"label": "헤집어 뒤진다", "effect": {"food": 2, "water": -2}}, {"label": "고이 지나친다", "effect": {}}]}},
		],
	},
	"d2": {
		"kind": "cache", "name": "독 웅덩이", "row": 4, "col": 0.7, "next": ["e1"], "biome": "river",
		"events": [
			{
				"id": "poison_pool", "threat": Threats.Kind.CONSUMPTION,
				"text": "고인 물에서 단내가 올라온다. 갈증엔 유혹이지만 탈이 날지도 모른다.",
				"choices": [
					{"label": "정화천에 걸러 안전하게 마신다", "effect": {"water": 4, "filter": -1}, "needs": {"filter": 1}},
					{"label": "걸러서 조금만 마신다", "effect": {"water": 2}, "sets": ["pool_drank"]},
					{"label": "위험하다, 지나친다", "effect": {}},
				],
			},
			{
				"id": "pool_carcass", "threat": Threats.Kind.CONSUMPTION,
				"text": "웅덩이 옆에 짐승 사체가 삭고 있다. 물맛이 왜 그런지 알 것 같다.",
				"choices": [
					{"label": "그래도 조금 걸러 마신다", "effect": {"water": 2}, "sets": ["pool_drank"]},
					{"label": "미련 없이 지나친다", "effect": {}},
				],
			},
			{
				"id": "poison_pool_bird", "threat": Threats.Kind.CONSUMPTION,
				"text": "웅덩이에 새 한 마리가 죽어 떠 있다. 물을 마신 대가일까. 그래도 목은 탄다.",
				"choices": [
					{"label": "정화천에 걸러 마신다", "effect": {"water": 4, "filter": -1}, "needs": {"filter": 1}},
					{"label": "위험하다, 지나친다", "effect": {}},
				],
			},
		],
		"spots": [
			{"id": "pool_reeds", "label": "마른 갈대", "at": Vector2(0.26, 0.66), "source": "cache", "effect": {"food": 1}, "text": "웅덩이 가장자리 마른 갈대. 뿌리를 씹으면 요기는 된다."},
			{"id": "pool_sweet", "label": "단내 나는 물", "at": Vector2(0.72, 0.6), "source": "empty", "text": "가까이서 보니 물빛이 탁하다. 손대지 않는 게 낫겠다."},
			{"id": "pool_tracks", "label": "물가 발자국", "at": Vector2(0.5, 0.38), "source": "event", "event": {"id": "pool_prints", "threat": Threats.Kind.CONSUMPTION, "text": "웅덩이 가장자리에 발자국이 어지럽다. 여럿이 여기서 물을 마셨고, 그중 몇은 되돌아가지 않았다.", "choices": [{"label": "발자국을 따라 잠깐 살핀다", "effect": {"food": 1}}, {"label": "지체 없이 간다", "effect": {}}]}},
			{"id": "pool_drink", "label": "탁한 물", "at": Vector2(0.2, 0.46), "source": "event", "event": {"id": "pool_tempt_drink", "threat": Threats.Kind.CONSUMPTION, "text": "탁하지만 물은 물이다. 목이 타들어간다. 그냥 마실지, 참을지.", "choices": [{"label": "그냥 들이켠다", "effect": {"water": 2}, "sets": ["pool_drank"]}, {"label": "참고 지나친다", "effect": {}}]}},
		],
	},
	"e1": {
		"kind": "blockage", "name": "무너진 담", "row": 5, "col": 0.5, "next": ["f1"], "biome": "rock",
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
		"spots": [
			{"id": "wall_pack", "label": "틈에 낀 배낭", "at": Vector2(0.26, 0.68), "source": "cache", "effect": {"water": 2, "food": 2}, "text": "무너진 틈에 배낭이 끼어 있다. 물통과 식량이 남았다."},
			{"id": "wall_beyond", "label": "담 너머", "at": Vector2(0.74, 0.64), "source": "empty", "text": "담 너머는 보이지 않는다. 넘어봐야 안다."},
			{"id": "wall_scramble", "label": "무너진 담", "at": Vector2(0.5, 0.42), "source": "event", "event": {"id": "wall_scramble", "threat": Threats.Kind.BLOCKAGE, "text": "무너진 담을 기어오르면 넘을 수 있다. 돌이 무르다.", "choices": [{"label": "기어 넘는다", "effect": {"water": -2}}, {"label": "틈으로 돌아 넘는다", "effect": {"food": -2}}]}},
			{"id": "wall_stash", "label": "벽돌 틈", "at": Vector2(0.72, 0.74), "source": "event", "event": {"id": "wall_hidden_stash", "threat": Threats.Kind.BLOCKAGE, "text": "벽돌 사이에 천으로 싼 꾸러미가 보인다. 손을 넣기엔 틈이 좁다.", "choices": [{"label": "팔을 긁혀가며 꺼낸다", "effect": {"food": 2, "water": -2}}, {"label": "포기한다", "effect": {}}]}},
		],
	},
	"f1": {
		"kind": "storm", "name": "폭풍의 문", "row": 6, "col": 0.5, "next": ["end"], "biome": "storm",
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
			{
				# 같은 런 연쇄: 앞서 독 웅덩이(d2)의 탁한 물을 마셨으면(pool_drank) 탈이 나 폭풍이 더 가혹하다.
				"id": "storm_gate_ill", "requires": "pool_drank", "threat": Threats.Kind.STORM,
				"text": "속이 뒤집힌다. 아까 그 물이 탈이 났다. 폭풍 앞에서 다리가 풀린다.",
				"choices": [
					{"label": "은신처 치고 최대한 버틴다", "effect": {"shelter": -1}, "needs": {"shelter": 1}},
					{"label": "이 악물고 뚫는다", "effect": {"water": -6, "food": -3}},
				],
			},
			{
				# 같은 런 연쇄: 오아시스(c1)에서 물을 비축했으면(water_stocked) 폭풍의 문 강행이 덜 가혹하다.
				"id": "storm_gate_stocked", "requires": "water_stocked", "threat": Threats.Kind.STORM,
				"text": "앞서 채운 물이 아직 넉넉하다. 폭풍 앞에서도 조금은 든든하다.",
				"choices": [
					{"label": "은신처 치고 안전하게 간다", "effect": {"shelter": -1}, "needs": {"shelter": 1}},
					{"label": "물을 아끼지 않고 강행한다", "effect": {"water": -3, "food": -1}},
				],
			},
		],
		"spots": [
			{"id": "gate_relic", "label": "앞선 이의 유품", "at": Vector2(0.24, 0.62), "source": "cache", "effect": {"water": 4}, "text": "협곡 입구에 여럿의 물통이 반쯤 묻혀 있다. 여기까지 온 원정대가 있었다."},
			{"id": "gate_mouth", "label": "협곡 입구", "at": Vector2(0.74, 0.58), "source": "empty", "text": "폭풍이 입구를 삼켰다. 그 너머는 아무도 모른다."},
			{"id": "gate_cairn", "label": "돌무더기", "at": Vector2(0.5, 0.42), "source": "empty", "text": "문 앞에 돌무더기. 여기까지 온 원정대들이 하나씩 쌓았다. 곁에 긁힌 표식: [ 마지막 · 또 ]"},
			{"id": "gate_stock", "label": "마지막 물", "at": Vector2(0.72, 0.72), "source": "event", "event": {"id": "gate_last_water", "threat": Threats.Kind.STORM, "text": "폭풍에 들기 전 마지막 물. 지금 힘내 마셔둘지, 한 모금 아껴 담아 둘지.", "choices": [{"label": "지금 마셔 힘을 낸다", "effect": {}}, {"label": "한 모금 아껴 담아 둔다", "effect": {}, "sets": ["water_stocked"], "sets_persist": ["water_stocked"]}]}},
		],
	},
	"end": {
		"kind": "end", "name": "???", "row": 7, "col": 0.5, "next": [],
	},
}

static func node(id: String) -> Dictionary:
	return NODES.get(id, {})

## 노드 일대의 지형. 없으면 "flats"(평지) 폴백 — start/end/미지정. 곡선·지형지물·이벤트 개연성이 공유.
static func biome_of(id: String) -> String:
	return str(NODES.get(id, {}).get("biome", "flats"))

## 진행 층의 최댓값(렌더에서 y 정규화에 쓴다).
static func max_row() -> int:
	var m: int = 0
	for id in NODES:
		m = maxi(m, int(NODES[id].get("row", 0)))
	return m

## 노드의 여정 진행도(0=마을 ~ 1=목적지 층) — "험지에 가까울수록 세게"의 공용 척도.
## 환경 강도(남기기 모래 드리프트·지도 드리프트·바람 환경음)가 전부 이 값을 공유한다.
static func progress(node_id: String) -> float:
	if not NODES.has(node_id):
		return 0.0
	return float(int(NODES[node_id].get("row", 0))) / float(maxi(1, max_row()))

# --- 지도 배치 좌표 + 곡선 반영 엣지 길이 (Map 렌더와 공유하는 단일 진실) ---
## 노드의 지도상 절대 좌표(스펙 MAP 공간 MAP_W 폭). Map._node_screen 이 화면 크기에 비례 매핑한다.
## row/col 은 논리 층/가로위치(거리 곡선·안개)용 — 실제 배치·경로 길이의 진실은 이 LAYOUT 이다.
const MAP_W: float = 820.0
const LAYOUT: Dictionary = {
	"n0": Vector2(52, 300), "a1": Vector2(120, 362),
	"b1": Vector2(255, 128), "b2": Vector2(200, 360),
	"c1": Vector2(415, 92), "c2": Vector2(350, 298),
	"d1": Vector2(525, 172), "d2": Vector2(465, 360),
	"e1": Vector2(642, 322), "f1": Vector2(650, 205),
	"end": Vector2(778, 272),
}
## 노드 표시 크기(Map 렌더용, 스펙 px). 배치 좌표와 함께 사는 게 자연스러워 여기 둔다.
const NODE_SIZE: Dictionary = {
	"n0": 100.0, "a1": 82.0, "b1": 86.0, "b2": 84.0, "c1": 86.0, "c2": 82.0,
	"d1": 84.0, "d2": 82.0, "e1": 84.0, "f1": 88.0, "end": 60.0,
}

static func pos(id: String) -> Vector2:
	return LAYOUT.get(id, Vector2(410, 230))

static func node_size(id: String) -> float:
	return float(NODE_SIZE.get(id, 80.0))

## 노드 id 의 결정론적 해시(문자 코드 합) — 곡선 굴곡 방향 고정(매 프레임·시뮬 동일, 렌더와 공유).
static func id_hash(s: String) -> int:
	var h: int = 0
	for i in range(s.length()):
		h += s.unicode_at(i)
	return h

## 엣지 A→B 곡선 위의 점(t∈[0,1], 스펙 좌표). 도착 노드 biome 으로 굴곡 결정 — 지형을 따라 굽이친다.
## Map._edge_point 가 이걸 화면에 스케일해 렌더 → 곡선·마커·경로 길이가 모두 한 공식을 공유(단일 진실).
static func edge_point(from_id: String, to_id: String, t: float) -> Vector2:
	var p0: Vector2 = pos(from_id)
	var p1: Vector2 = pos(to_id)
	var base: Vector2 = p0.lerp(p1, t)
	var dist: float = p0.distance_to(p1)
	if dist < 1.0:
		return base
	var perp: Vector2 = Vector2(-(p1.y - p0.y), p1.x - p0.x) / dist  # 엣지에 수직(방향 무관)
	var sgn: float = 1.0 if (id_hash(to_id) % 2 == 0) else -1.0      # 굴곡 방향 고정(노드별 결정론)
	var amp: float = 0.0
	var shape: float = 0.0
	match biome_of(to_id):
		"river":   # 강줄기를 따라 사행(S 굽이) — 직선보다 길다
			amp = dist * 0.13
			shape = sin(t * TAU)
		"rock":    # 바위를 돌아간다(한쪽 볼록)
			amp = dist * 0.20
			shape = sin(t * PI)
		"storm":   # 폭풍·사구에 흔들리는 지그재그 — 잔파동이 많아 가장 길다
			amp = dist * 0.15
			shape = sin(t * PI * 3.0)
		_:         # flats — 완만한 미세 굴곡(거의 직선)
			amp = dist * 0.08
			shape = sin(t * PI)
	return base + perp * (amp * shape * sgn)

const EDGE_SAMPLES: int = 18
## 곡선 호 길이(스펙 px) — 직선거리가 아니라 실제 굽이친 경로 길이. edge_steps 의 근거.
static func edge_length(from_id: String, to_id: String) -> float:
	var total: float = 0.0
	var prev: Vector2 = edge_point(from_id, to_id, 0.0)
	for i in range(1, EDGE_SAMPLES + 1):
		var p: Vector2 = edge_point(from_id, to_id, float(i) / float(EDGE_SAMPLES))
		total += prev.distance_to(p)
		prev = p
	return total

## 걸음 수 환산 — 곡선 경로 길이(px) × 배율. 가까운 노드는 적게, 먼 노드는 많이.
## STEPS_PER_UNIT/EDGE_MIN/MAX = 튜닝 손잡이(static var, balance_sim 스윕 후 원복). 수치 바꾸면 balance_notes·기획서 §4.3 갱신.
static var STEPS_PER_UNIT: float = 0.027   ## px당 걸음 — balance_sim: DESO30서 GREEDY ~11%(기존 EDGE_LEN=5 완주율 보존). 곡선이 직선보다 길어 0.031→0%였다.
static var EDGE_MIN: int = 2                ## 가장 가까운 엣지도 최소 이만큼(도착이 순간이동처럼 안 되게)
static var EDGE_MAX: int = 11               ## 가장 먼 엣지 상한(후반 한 엣지 즉사 방지)
static func edge_steps(from_id: String, to_id: String) -> int:
	return clampi(int(round(edge_length(from_id, to_id) * STEPS_PER_UNIT)), EDGE_MIN, EDGE_MAX)
