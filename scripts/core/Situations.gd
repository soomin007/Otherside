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
## choice = {label, effect, needs?, action?, sets?, sets_persist?, then?}.
##  - effect: 자원 델타 {water/food/rope/shelter: int}.
##  - needs: 그 자원이 모자라면 못 고름(대비 자원의 희소성 -> 결정의 무게).
##  - action: 자원 델타를 넘는 부수효과("bridge" = 차단에 로프 고정 -> UI 가 그 노드에 ROPE 흔적, "pickup" = 흔적 줍기).
##  - sets / sets_persist: 켤 플래그 목록(런 / 영속).
##  - then: 후속 장면(이벤트 dict) — 이 선택 직후 같은 걸음에서 바로 이어지는 두 번째 카드
##    (2026-07-12 사용자: 이벤트를 한 턴짜리로 끝내지 말고 이야기를 이어가라). 체인의 순 대가는
##    기존 단일 카드와 같게 저작한다(밸런스 중립). 후속 장면의 id 는 별개 → blind choice 도 새로 시작.
##    ⚠ 발견을 "줍는다/안 줍는다"의 선택으로 내지 않는다 — 안 챙길 이유가 없는 선택은 가짜다
##    (2026-07-12 사용자). 발견의 효과는 장면이 그냥 주고(양쪽 선택 모두 포함), 선택은
##    방식·정서·진짜 딜레마(품을 들일까·애도할까)에만 쓴다.
## 단일 진실: docs/design/SYOTOS_기획서_v0.1.md §4 위협 삼각형.
##
## 대가 문법(2026-07-12 사용자 확정 — 선택 결과의 방향·크기를 서사에서 예측할 수 있어야 한다).
## 문구를 새로 쓰거나 고칠 때 지킨다(MapGraph 노드 이벤트·spots 도 동일):
##  - 방향: 물 = 더위·강행·땀·성치 않은 몸. 식량 = 시간·우회·기다림·노동. 도구 = 해당 위기 무효(소모 1).
##  - 크기: ±1~2 = "조금·잠시·몇 모금", 3 = "축난다·목이 탄다", 4 이상 = 심각함을 본문이 예고.
##  - 결과가 확정이면 도박처럼 쓰지 않는다("나올지도" 금지 — 무엇이 나오는지 암시한다).
##  - 오인·거짓 암시 금지 — 흔적 정직 원칙(기획서)과 같은 축. 예고한 대가와 딴판인 결과를 주지 않는다.
##  - 예고를 조건문 나열("~하면 ~한다")로 쓰지 않는다(2026-07-12 사용자 — 반복이 규칙서처럼 읽힘).
##    감각 묘사·명사문·대구로 변주: "약 없이 버틸 열이 아니다", "지름길엔 그늘 한 점 없고".

## 지형 개연성 — 이벤트 biome 태그가 현재 지형과 일치하면 이 배수만큼 자주 뜬다(가중, 완전 고정은 아님).
const BIOME_MATCH_MULT: int = 3

const CATALOG: Array = [
	{
		"id": "dry_stretch", "biome": ["flats"],
		"threat": Threats.Kind.CONSUMPTION,
		"text": "앞이 바싹 메말랐다.\n한참 물 한 방울 없을 듯하다.\n지름길엔 그늘 한 점 없고,\n돌아가는 길은 한나절이 멀다.",
		"choices": [
			{"label": "곧장 가로지른다", "effect": {"water": -3}},
			{"label": "멀리 돌아 우회한다", "effect": {"water": -1, "food": -1}},
		],
	},
	{
		"id": "fork_road",
		"threat": Threats.Kind.CONSUMPTION,
		"text": "길이 둘로 갈린다.\n메마른 지름길과,\n반나절을 더 도는 먼 길.",
		"choices": [
			{"label": "지름길로 간다", "effect": {"water": -1}, "then": {
				"id": "shortcut_dune", "threat": Threats.Kind.CONSUMPTION,
				"text": "지름길 한가운데,\n바람이 쌓아 올린 모래 둔덕이\n길을 통째로 삼켰다.\n지름길은 공짜가 아니었다.",
				"choices": [
					{"label": "둔덕을 타 넘는다", "effect": {"water": -1}},
					{"label": "가장자리로 비켜 돌아간다", "effect": {"food": -1}},
				],
			}},
			{"label": "둘러 간다", "effect": {"food": -2}},
		],
	},
	{
		"id": "past_flask", "biome": ["river"],
		"threat": Threats.Kind.CONSUMPTION,
		"text": "이전 원정대가 물통을 두고 갔다.\n곁의 표식: [ 또 · 봐 ]",
		"choices": [
			{"label": "집는다", "effect": {"water": 4}},
			{"label": "남겨둔다 (다음 원정대에게)", "effect": {}},
		],
	},
	{
		"id": "old_tracks", "biome": ["river"],
		"threat": Threats.Kind.CONSUMPTION,
		"text": "모래에 반쯤 지워진 발자국.\n이전 원정대도\n여기까지는 왔던 모양이다.\n자국은 내 길에서 벗어나\n한쪽으로 휘어 사라진다.",
		"choices": [
			{"label": "잠시 벗어나 따라가 본다", "effect": {"water": -1}, "then": {
				"id": "old_tracks_end", "threat": Threats.Kind.CONSUMPTION,
				"text": "발자국은 낮은 바위 그늘에서 끊긴다.\n먼저 간 이가 쉬어 간 자리다.\n재도 뼈도 없다.\n다시 일어나 걸었다는 뜻이다.",
				"choices": [
					{"label": "같은 그늘에서 잠시 숨을 고른다", "effect": {}},
					{"label": "그가 간 방향으로 마저 걷는다", "effect": {}},
				],
			}},
			{"label": "곧장 내 길로 간다", "effect": {}},
		],
	},
	{
		"id": "scavenge_wreck", "biome": ["river"],
		"threat": Threats.Kind.CONSUMPTION,
		"text": "부서진 수레가 모래에 처박혀 있다.\n짐칸에 먹을 것이 남은 눈치다.\n그늘 한 점 없는 땡볕 아래서다.",
		"choices": [
			{"label": "뒤져 본다", "effect": {"food": 2, "water": -1}},
			{"label": "지나친다", "effect": {}},
		],
	},
	{
		"id": "sun_hammer", "biome": ["flats"],
		"threat": Threats.Kind.CONSUMPTION,
		"text": "해가 정수리를 두드린다.\n그늘 한 점 없다.\n잠깐 쉴지 계속 밀어붙일지.",
		"choices": [
			{"label": "그늘 없이 계속 간다", "effect": {"water": -2}},
			{"label": "천을 둘러쓰고 천천히 간다", "effect": {"water": -1, "food": -1}},
		],
	},
	{
		"id": "loose_sand", "biome": ["flats"],
		"threat": Threats.Kind.CONSUMPTION,
		"text": "발이 푹푹 빠지는 고운 모래밭.\n한 걸음이 두 걸음 같다.",
		"choices": [
			{"label": "곧장 가로지른다", "effect": {"water": -1, "food": -1}},
			{"label": "단단한 가장자리로 돌아간다", "effect": {"food": -2}},
		],
	},
	{
		"id": "mirage", "biome": ["flats"],
		"threat": Threats.Kind.CONSUMPTION,
		"text": "멀리 물빛이 어른거린다.\n아지랑이인지 진짜인지 알 수 없다.",
		"choices": [
			{"label": "혹시 몰라 다가가 본다", "effect": {"water": -1}, "then": {
				"id": "mirage_shore", "threat": Threats.Kind.CONSUMPTION,
				"text": "물빛이 있던 자리엔\n소금기만 허옇게 낀 바닥뿐이다.\n어느새 길에서 꽤 벗어났다.",
				"choices": [
					{"label": "서둘러 길을 되짚는다", "effect": {"water": -1}},
					{"label": "그늘을 골라 천천히 되짚는다", "effect": {"food": -1}},
				],
			}},
			{"label": "속지 않고 길을 지킨다", "effect": {}},
		],
	},
	# --- 도구 위기(60초식): 맞는 도구가 없으면 큰 대가. 도구가 곧 그 위기의 보험.
	#     crisis=true 는 일반 회전(pick)에서 빠지고 "위기 순간"(pick_crisis, ExpeditionRun 이 엣지마다
	#     정함)에만 나온다 — 위기는 위기끼리 몰려서 온다(2026-07-12 사용자 확정). ---
	{
		"id": "fever", "crisis": true,
		"threat": Threats.Kind.CONSUMPTION,
		"text": "몸이 불덩이 같다.\n열이 오르고 다리가 풀린다.\n약 없이 버틸 열이 아니다.",
		"choices": [
			{"label": "약초로 열을 다스린다", "effect": {"medicine": -1}, "needs": {"medicine": 1}},
			{"label": "이 악물고 버틴다", "effect": {"water": -5}},
		],
	},
	{
		"id": "frozen_night", "crisis": true, "biome": ["storm"],
		"threat": Threats.Kind.CONSUMPTION,
		"text": "해가 지자 모래가 얼어붙는다.\n이가 딱딱 부딪히고 손끝이 곱는다.\n불 없이는 뼛속까지 갉히는 밤이다.",
		"choices": [
			{"label": "부싯돌로 불을 피운다", "effect": {"flint": -1}, "needs": {"flint": 1}},
			{"label": "떨며 밤을 버틴다", "effect": {"water": -4, "food": -2}},
		],
	},
	{
		"id": "murky_spring", "weight": 1, "biome": ["river"],
		"threat": Threats.Kind.CONSUMPTION,
		"text": "고인 물웅덩이를 만났다.\n물빛이 탁하지만, 목은 타들어간다.",
		"choices": [
			{"label": "정화천에 걸러 마신다", "effect": {"filter": -1, "water": 3}, "needs": {"filter": 1}},
			{"label": "그냥 들이켠다", "effect": {"water": 2}, "sets": ["pool_drank"]},
			{"label": "미련 없이 지나친다", "effect": {}},
		],
	},
	{
		"id": "twisted_ankle", "crisis": true, "biome": ["rock"],
		"threat": Threats.Kind.CONSUMPTION,
		"text": "무너진 비탈에서 발을 헛디뎠다.\n발목이 시큰거린다.\n절뚝이는 걸음엔\n땡볕 길이 갑절이다.",
		"choices": [
			{"label": "약초로 싸매고 간다", "effect": {"medicine": -1}, "needs": {"medicine": 1}},
			{"label": "절뚝이며 계속 간다", "effect": {"water": -4}},
		],
	},
	{
		"id": "sand_squall", "crisis": true, "biome": ["storm"],
		"threat": Threats.Kind.STORM,
		"text": "느닷없이 모래바람이 몰아친다.\n짧지만 살을 벤다.\n맨몸으로 맞을 바람이 아니다.",
		"choices": [
			{"label": "장막을 펴 버틴다", "effect": {"shelter": -1}, "needs": {"shelter": 1}},
			{"label": "몸을 낮추고 견딘다", "effect": {"water": -4}},
		],
	},
	# --- requires 연쇄: 앞선 선택이 켠 런 플래그가 있을 때만 뜨는 이동 중 상황 ---
	{
		# 독 웅덩이(d2)에서 탁한 물을 마셨으면(pool_drank) 이동 중 탈이 난다.
		"id": "gut_turn",
		"requires": "pool_drank",
		"threat": Threats.Kind.CONSUMPTION,
		"text": "아까 그 물이 속에서 뒤척인다.\n식은땀이 난다.\n멈춰 게워낼지 참고 갈지.",
		"choices": [
			{"label": "멈춰서 게워내고 간다", "effect": {"food": -2}},
			{"label": "이 악물고 계속 간다", "effect": {"water": -2}},
		],
	},
	{
		# self-async 메아리: a1 에서 강바닥을 팠으면(river_dug 영속) 다음 원정의 강 지형 이동 중에 그 자국을 만난다.
		"id": "dig_marks", "requires": "river_dug", "biome": ["river"],
		"threat": Threats.Kind.CONSUMPTION,
		"text": "강바닥을 따라 파헤친 자국이\n점점이 이어진다.\n이전 원정대가\n물길을 더듬던 손자국이다.",
		"choices": [
			{"label": "자국이 끝난 자리를 마저 판다", "effect": {"water": 2, "food": -1}},
			{"label": "자국만 눈에 담고 간다", "effect": {}},
		],
	},
	# --- 바위 지형(rock) 이동 상황 — b2 갈라진 바닥·e1 무너진 담으로 향할 때(rock 편중 보강) ---
	{
		"id": "rockfall", "biome": ["rock"],
		"threat": Threats.Kind.CONSUMPTION,
		"text": "좁은 바위 협곡.\n위쪽 돌들이 아슬아슬하게 얹혀 있다.\n잘못 건드리면 쏟아진다.",
		"choices": [
			{"label": "숨죽여 빠르게 지난다", "effect": {"water": -2}},
			{"label": "먼 바깥쪽으로 돌아간다", "effect": {"food": -2}},
		],
	},
	{
		"id": "narrow_ledge", "biome": ["rock"],
		"threat": Threats.Kind.CONSUMPTION,
		"text": "바위 턱이 실낱처럼 좁아진다.\n한쪽은 벽, 한쪽은 낭떠러지.",
		"choices": [
			{"label": "벽에 붙어 조심조심 건넌다", "effect": {"water": -1, "food": -1}},
			{"label": "짐을 하나씩 옮기며 천천히 지난다", "effect": {"food": -2}},
		],
	},
	{
		"id": "cut_rock", "crisis": true, "biome": ["rock"],
		"threat": Threats.Kind.CONSUMPTION,
		"text": "날 선 바위에 손과 정강이가 쓸렸다.\n상처가 벌겋게 부어오른다.\n천 쪼가리로 덮을 상처가 아니다.",
		"choices": [
			{"label": "약초로 상처를 싸맨다", "effect": {"medicine": -1}, "needs": {"medicine": 1}},
			{"label": "천으로 대충 묶고 간다", "effect": {"water": -4}},
		],
	},
	# --- 위협 다양화 — 이동 중에도 차단·폭풍이 스친다(소모 일색 보강). 대비 자원(로프·장막)의 쓸 곳을 넓힌다 ---
	{
		# 이동 중 차단(첫 종). 로프는 소모하지 않고 "가진 것"의 값을 만든다 — 다리 걸기(영구)와 경쟁하지 않게.
		"id": "rope_gully", "biome": ["rock"],
		"threat": Threats.Kind.BLOCKAGE,
		"text": "길이 얕은 골로 뚝 끊긴다.\n내려갔다 오를 수는 있어 보인다.\n로프가 있으면 한결 수월하다.",
		"choices": [
			{"label": "로프를 걸어 내려갔다 회수한다", "effect": {}, "needs": {"rope": 1}},
			{"label": "맨손으로 기어 내려갔다 오른다", "effect": {"water": -2}},
		],
	},
	{
		# 폭풍 지형의 일반 이동 상황(기존 폭풍은 도구 위기 weight 1 뿐) — 폭풍 엣지가 폭풍답게.
		"id": "grit_wind", "biome": ["storm"],
		"threat": Threats.Kind.STORM,
		"text": "바람에 모래가 섞이기 시작한다.\n숨을 쉴 때마다\n이 사이에 모래가 씹힌다.",
		"choices": [
			{"label": "천으로 코와 입을 감싸고 천천히 간다", "effect": {"water": -1}},
			{"label": "눈을 가늘게 뜨고 빠르게 벗어난다", "effect": {"water": -2}},
		],
	},
	{
		# storm 일반 2번째(2026-07-16) — grit_wind 하나뿐이라 폭풍 엣지에서 같은 카드가 반복되던 것 보강.
		"id": "sand_tide", "biome": ["storm"],
		"threat": Threats.Kind.STORM,
		"text": "길 위로 모래가\n개울처럼 흘러내린다.\n발목까지 차오르는 모래를\n헤치며 가야 한다.",
		"choices": [
			{"label": "정강이로 헤치며 곧장 간다", "effect": {"water": -2}},
			{"label": "모래가 얕은 등성이로 돌아간다", "effect": {"water": -1, "food": -1}},
		],
	},
	# --- 정서 카드(정보 0, 정서 100) — 이전 원정대의 흔적을 스친다. 자원보다 결이 목적. 태그는 wordpool 안에서만 ---
	{
		"id": "sand_marker",
		"threat": Threats.Kind.CONSUMPTION,
		"text": "모래 위에 돌을 세워 만든 표식.\n곁에 긁어 새긴 자국: [ 앞 · 없다 ]",
		"choices": [
			{"label": "새겨진 대로 마음에 새기고 간다", "effect": {}},
			{"label": "돌 하나를 더 얹고 간다", "effect": {}},
		],
	},
	{
		"id": "buried_flask",
		"threat": Threats.Kind.CONSUMPTION,
		"text": "모래에 반쯤 묻힌 빈 물통.\n바닥에 서툰 글씨가 긁혀 있다:\n[ 여기 · 끝 ]",
		"choices": [
			{"label": "잠시 손을 얹었다 간다", "effect": {}},
			{"label": "빈 물통을 챙겨 둔다", "effect": {}},
		],
	},
	{
		# 정서 카드 3(2026-07-16) — 폭풍이 글씨를 지우는 세계 규칙을 지나가듯 보여준다. 태그 없음(못다 새긴 것이 핵).
		"id": "half_scratched",
		"threat": Threats.Kind.CONSUMPTION,
		"text": "길가 바위에 긁다 만 자국.\n한 글자를 이루지 못한 채\n선 몇 개로 끊겼다.\n폭풍이 먼저 왔는지\n힘이 먼저 다했는지.",
		"choices": [
			{"label": "끊긴 선 위에 손가락을 얹어 본다", "effect": {}},
			{"label": "못다 새긴 말을 짐작하며 간다", "effect": {}},
		],
	},
	{
		# 정서 카드 4(2026-07-16) — 물건이 절반을 말한다(나란한 그릇 = 함께한 두 사람). 태그는 wordpool 안에서만.
		"id": "two_bowls",
		"threat": Threats.Kind.CONSUMPTION,
		"text": "바위 그늘에 나무 그릇 두 개가\n나란히 엎어져 있다.\n모래가 반쯤 삼켰어도\n나란한 것은 그대로다.\n곁의 표식: [ 고맙다 ]",
		"choices": [
			{"label": "모래를 털고 바로 놓아 준다", "effect": {}},
			{"label": "나란한 채로 두고 간다", "effect": {}},
		],
	},
	# --- 후반 전용(min_prog) 가혹 이동 상황 — 진행도 높을수록만 등장(멀수록 척박, 거리 곡선). 대가가 초반보다 크다 ---
	{
		"id": "scorched_waste", "min_prog": 0.55, "biome": ["flats"],
		"threat": Threats.Kind.CONSUMPTION,
		"text": "지평선까지 타버린 땅.\n열기가 아지랑이로 일렁이고\n그늘 한 점 없다.\n여기서부턴 아무도 없는 땅이다.",
		"choices": [
			{"label": "쉬지 않고 가로지른다", "effect": {"water": -4}},
			{"label": "천을 적셔 두르고 천천히 간다", "effect": {"water": -2, "food": -2}},
		],
	},
	{
		"id": "dry_riverbed", "min_prog": 0.55, "biome": ["river"],
		"threat": Threats.Kind.CONSUMPTION,
		"text": "물길인 줄 알았던 자리가\n바싹 말라 갈라졌다.\n틈 아래엔 아직 물기가 비치고,\n앞은 한참 마른 구간이다.",
		"choices": [
			{"label": "품을 들여 바닥을 판다", "effect": {"water": -1, "food": -1}},
			{"label": "목마른 채 계속 간다", "effect": {"water": -3}},
		],
	},
	{
		"id": "collapsing_gorge", "min_prog": 0.6, "biome": ["rock"],
		"threat": Threats.Kind.CONSUMPTION,
		"text": "협곡 벽이 삭아 내린다.\n발밑에서 돌이 쏟아지고,\n길이 무너지는 소리가 뒤를 쫓는다.\n내달리는 쪽은 숨이 타고,\n고르는 쪽은 해가 진다.",
		"choices": [
			{"label": "무너지기 전에 내달린다", "effect": {"water": -3, "food": -1}},
			{"label": "단단한 바위만 골라 신중히 간다", "effect": {"food": -3}},
		],
	},
	{
		# 후반 전용 storm(2026-07-16) — min_prog 구역에 storm 만 없었다(flats·river·rock 은 있음).
		"id": "veiled_sun", "min_prog": 0.55, "biome": ["storm"],
		"threat": Threats.Kind.STORM,
		"text": "날린 모래가 해를 가려\n한낮이 저물녘처럼 어둡다.\n길잡이 삼을 것 하나 없는 땅.\n걸음마다 방향을 되짚는다.",
		"choices": [
			{"label": "감에 기대어 서둘러 가로지른다", "effect": {"water": -3}},
			{"label": "바람의 결을 읽으며 천천히 간다", "effect": {"water": -1, "food": -2}},
		],
	},
]

## 아이코닉한 고정 지형. 키 = leg(int). 각 랜드마크는 events 풀을 가진다(같은 장소, 다른 사건).
## 거리 곡선대로 leg 순 배치: 가까울수록 풍요(cache), 멀수록 척박(위협). CATALOG 와 leg 가 겹치지 않게 둔다.
## 다음 일반 상황을 고른다. 직전과 같은 id 는 피하고, requires 가 있으면 그 플래그가 켜졌을 때만 후보에 넣는다.
## early=true(마을 근처 초반 구간)면 도구 위기(weight 1, 큰 대가)를 후보에서 뺀다 — 거리 곡선(가까울수록 평화,
## 기획 §1). 시작 물이 얕은 첫 엣지에 열병(-5) 등이 떠 즉사하는 걸 막는다. 일반 상황(weight 기본 3)은 그대로.
## biome(향하는 엣지의 지형, "" = 무시)면 그 지형에 맞는 이벤트를 자주(BIOME_MATCH_MULT 가중), 다른 지형 전용은 제외.
## progress(0=마을~1=목적지, 향하는 노드의 MapGraph.progress) — 후반 전용(min_prog) 상황을 게이트한다.
##  초반엔 온화한 상황만, 후반(척박)엔 가혹한 상황도 뜬다(거리 곡선 §1·§4.3 — 등장 시기에 맞는 난이도).
static func pick(rng: RandomNumberGenerator, last_id: String = "", flags: Dictionary = {}, early: bool = false, biome: String = "", progress: float = 0.0) -> Dictionary:
	var pool: Array = []
	for s in CATALOG:
		if bool(s.get("crisis", false)):
			continue  # 위기는 일반 회전에 안 섞인다 — 위기 순간(pick_crisis)에만(2026-07-12 사용자)
		if str(s.get("id", "")) == last_id:
			continue
		var req: String = str(s.get("requires", ""))
		if req != "" and not flags.has(req):
			continue
		# 후반 전용(min_prog) — 진행도가 낮으면(마을 근처) 제외. 초반 온화·후반 가혹(거리 곡선 §1).
		if progress < float(s.get("min_prog", 0.0)):
			continue
		# weight 만큼 후보에 복제 — 도구 위기(weight 1)는 일반 상황(기본 3)보다 드물게 뜬다(빈도 가중).
		var w: int = maxi(1, int(s.get("weight", 3)))
		if early and w <= 1:
			continue  # 초반엔 도구 위기(weight 1) 제외 — 마을 근처는 평화(위 주석)
		# 지형 개연성 — 이벤트 biome 태그가 현재 지형과 맞으면 자주(가중), 안 맞는 지형 전용은 제외. 태그 없으면 어디서나.
		var tags: Array = s.get("biome", [])
		if not tags.is_empty() and biome != "":
			if biome in tags:
				w *= BIOME_MATCH_MULT
			else:
				continue
		for _i in range(w):
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

## 위기 카드 하나 — "위기 순간"(ExpeditionRun 이 엣지마다 정함)에만 호출된다. 위기는 위기끼리
## 몰려서 오고(2026-07-12 사용자 확정), 일반 회전(pick)에는 절대 안 섞인다.
## 지형 일관성은 엄격(biome 전용 위기는 그 지형에서만, fever 는 어디서나): rock=발목/베임,
## storm=언 밤/돌풍, flats/river=열병. last_id = 직전 위기(2연속일 때 같은 위기 반복 방지).
## 후보가 없으면 빈 Dictionary(호출측이 위기 순간을 건너뛴다 — 지형을 깨면서까지 안 낸다).
static func pick_crisis(rng: RandomNumberGenerator, biome: String = "", last_id: String = "") -> Dictionary:
	var pool: Array = []
	for s in CATALOG:
		if not bool(s.get("crisis", false)):
			continue
		if str(s.get("id", "")) == last_id:
			continue
		var tags: Array = s.get("biome", [])
		if not tags.is_empty() and biome != "" and not (biome in tags):
			continue
		pool.append(s)
	if pool.is_empty():
		return {}
	return pool[rng.randi_range(0, pool.size() - 1)]

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

## 낙오자를 만난 카드 — 이전 원정에서 뒤처진 이가 버티고 있다(재회 축: 거두어 데리고 온전히 닿기).
## 거두면 물을 나눠 줘야 한다(needs 3: 나누고도 내가 살아야 한다) — 사람을 거두는 것도 남김의 문법(자기희생).
## 지나치면 그 자리에 남는다(다음 원정대 몫). action="rescue" 는 UI 가 받아 행렬 +1 + 세계에서 제거.
## brief(2026-07-13) = GameState.straggler_briefs 가 주입한 출처 {origin, name?, cause?}.
## 과거 런의 손실 출신(loss)은 어느 원정에서 어떻게 뒤처졌는지 카드가 말한다 — 내 실패가 얼굴을 얻는다.
## 거두기 선택의 then = 거둔 이가 행렬에 드는 한 박자(정서 0/0, 스토리 먼저 — 기획서 §4.2 ⑤).
static func straggler_event(brief: Dictionary = {}) -> Dictionary:
	var nm: String = str(brief.get("name", ""))
	var text: String = "바람을 피한 그늘에\n사람이 웅크리고 있다.\n지난 원정에서 뒤처진 이가,\n여기까지 버티고 있었다."
	var word: String = "그는 물을 아주 조금씩\n오래 나눠 마신다.\n어느 원정이었는지 물어도\n고개만 젓는다.\n걸음만은 아직 원정대의 것이다."
	if nm != "":
		var fell: String = L10N.t("다친 몸으로 뒤처진 채,")
		match str(brief.get("cause", "")):
			"thirst": fell = L10N.t("물이 끊겨 뒤처진 채,")
			"hunger": fell = L10N.t("굶주려 뒤처진 채,")
		text = L10N.t("바람을 피한 그늘에\n사람이 웅크리고 있다.\n'%s' 원정의 사람이다.\n%s\n여기까지 버티고 있었다.") % [nm, fell]
		word = L10N.t("그는 물을 아주 조금씩\n오래 나눠 마신다.\n그러고는 갈라진 목소리로\n한 마디를 꺼낸다.\n\"%s... 우리 이름이었소.\"") % nm
	return {
		"id": "straggler",
		"kind": "straggler",
		"name": "웅크린 사람",
		"threat": Threats.Kind.CONSUMPTION,
		"text": text,
		"choices": [
			{"label": "물을 나눠 주고 행렬에 거둔다", "effect": {"water": -2}, "needs": {"water": 3}, "action": "rescue", "then": {
				"id": "straggler_word", "threat": Threats.Kind.CONSUMPTION,
				"text": word,
				"choices": [
					{"label": "행렬 가운데에 자리를 내준다", "effect": {}},
					{"label": "곁에서 보폭을 맞춘다", "effect": {}},
				],
			}},
			{"label": "지금은 지나친다 (다음 원정대가 거둔다)", "effect": {}},
		],
	}

## 이미 로프가 걸린 차단 지점에 다시 왔을 때의 카드 - 이전 원정대가 길을 열어뒀다(self-async 보상).
## 자원 소모 없이 통과한다. 차단의 정체성("가장 뿌듯한 흔적")을 죽음 너머에서 되돌려받는 순간.
static func crossed_blockage(feat: Dictionary) -> Dictionary:
	return {
		"id": str(feat.get("id", "")) + "_bridged",
		"name": str(feat.get("name", "")),
		"kind": "bridged",
		"threat": Threats.Kind.BLOCKAGE,
		"text": "이전 원정대가 여기 로프를 걸어뒀다.\n그대로 건넌다.",
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
			obj_name = "장막"
		# 주머니 도구 유품 — 남긴 도구 1 = 줍기 1(대칭). 자원과 같은 줍기 흐름.
		TraceData.ObjectKind.MEDICINE:
			res_key = "medicine"
			amount = 1
			obj_name = "약초 꾸러미"
		TraceData.ObjectKind.FLINT:
			res_key = "flint"
			amount = 1
			obj_name = "부싯돌"
		TraceData.ObjectKind.FILTER:
			res_key = "filter"
			amount = 1
			obj_name = "정화천"
	var tag_str: String = ""
	if not tags.is_empty():
		var tags_disp: Array = []
		for tg in tags:
			tags_disp.append(L10N.t(str(tg)))  # 태그는 데이터(한국어) — 표시만 번역
		tag_str = L10N.t("\n곁의 표식: [ %s ]") % " · ".join(PackedStringArray(tags_disp))
	return {
		"id": "pickup",
		"kind": "pickup",
		"threat": Threats.Kind.CONSUMPTION,
		"text": L10N.t("이전 원정대가 남긴 %s.\n아직 쓸 만하다.%s") % [L10N.t(obj_name), tag_str],
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
