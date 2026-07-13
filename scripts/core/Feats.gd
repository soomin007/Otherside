class_name Feats
extends RefCounted

## 공훈(업적) — 이룬 일이 마을에 새 사람(직능 대장 후보)을 부른다. 2026-07-11 사용자 확정:
## 직능 선택은 첫 화면에서 다 열어두지 않고, 과제의 보상으로 해금한다(첫 원정 = 평범한 대장 고정).
## 겪은 일이 그 직능의 쓸모를 먼저 가르친다 — 해금 자체가 온보딩(예: 갈증으로 죽어 본 뒤 물지기가 온다).
##
## 순수 데이터·판정(GameState/ui 미참조). check 는 통계 스냅샷(stats)만 받는다 — -s 단위 테스트 가능.
## stats 키(전부 int, GameState.feat_stats_snapshot 이 만든다):
##  thirst_deaths     갈증으로 스러진 원정 수
##  hunger_deaths     굶주림으로 스러진 원정 수
##  heavy_departures  무료 무게(ExpeditionRun.WEIGHT_FREE)를 넘는 짐으로 출발한 원정 수
##  max_row_visited   방문한 노드의 가장 깊은 층(MapGraph row)
##  traces_left       남긴 흔적 수(유령 seed 제외 — GameState.player_trace_count)
##
## 문구 규칙: 보이는 글(name/cond/line)은 세계의 말·담담한 평서체, 수동 줄바꿈. 숫자 조건은 사람 말로.
## cond = 아직 안 온 사람 소개 + 무엇이 그를 움직이는지. "~하면 온다" 같은 규칙 낭독 금지
## (2026-07-12 사용자 — 번역투). 문장 꼴은 서로 다르게(같은 틀 반복 금지).
## 조건 수치는 1차안 — 폰 체감으로 튜닝(바꾸면 기획서 §직능 해금도 같이).
##
## 기록형 공훈(2026-07-13): `unlocks` 가 없는 명예 기록 — 사람을 부르지 않고 일지 "마을" 챕터
## "이룬 일"에만 쌓인다. cond 없음 = **달성 전엔 어디에도 안 보인다**(재회 같은 결말의 존재를
## 미리 새지 않게 — 기획서 §3 비공개 정책과 같은 축). 통계 키는 GameState.feat_stats_snapshot 파생값.

const LIST: Array = [
	{
		"id": "walked_deep", "unlocks": "pathfinder",
		"name": "멀리 가 본 이",
		"cond": "길눈 밝은 떠돌이가 있다.\n들판 너머 소식이 닿아야 움직인단다.",
		"line": "먼 데서 돌아온 이가 마을에 남았다.\n\"길은 물이 마르는 순서대로 외우는 걸세.\"",
		"stat": "max_row_visited", "at_least": 4,
	},
	{
		"id": "heavy_back", "unlocks": "porter",
		"name": "짐을 진 이",
		"cond": "힘 좋은 젊은이가 있다.\n무겁게 진 원정을 보면 어깨가 근질거린단다.",
		"line": "짐꾼이 마을에 왔다.\n\"질 수 있는 만큼이 아니라,\n져야 하는 만큼 지는 거요.\"",
		"stat": "heavy_departures", "at_least": 1,
	},
	{
		"id": "thirst_learned", "unlocks": "waterwise",
		"name": "갈증을 아는 이",
		"cond": "물길을 읽는 노인이 있다.\n갈증에 스러진 원정이 거듭되는 걸\n못 본 체하지 못하는 사람이다.",
		"line": "물지기가 마을에 왔다.\n\"물은 아껴 마시는 게 아니라,\n아는 만큼 담는 걸세.\"",
		"stat": "thirst_deaths", "at_least": 2,
	},
	{
		"id": "hunger_learned", "unlocks": "hardy",
		"name": "주림을 견딘 이",
		"cond": "굶는 법을 아는 사내가 있다.\n주림에 쓰러진 원정 소식이 거듭되면\n그제야 짐을 꾸린단다.",
		"line": "강골이 마을에 왔다.\n\"주림은 이기는 게 아니라 늦추는 거다.\"",
		"stat": "hunger_deaths", "at_least": 2,
	},
	{
		"id": "left_three", "unlocks": "keeper",
		"name": "세 번 남긴 이",
		"cond": "죽은 이들의 짐을 지켜 온 사람이 있다.\n세 번을 남긴 원정대라야\n제 일을 맡길 만하다 여긴단다.",
		"line": "유품지기가 마을에 왔다.\n\"두고 가는 법을 아는 사람은 드물지.\"",
		"stat": "traces_left", "at_least": 3,
	},
	# --- 기록형(명예 기록) — 직능 보상 없음, 달성해야 비로소 보인다 ---
	{
		"id": "rec_reached",
		"name": "끝까지 간 원정",
		"line": "원정 하나가 끝까지 걸었다.\n돌아오지는 못했다.",
		"stat": "arrivals_total", "at_least": 1,
	},
	{
		"id": "rec_intact",
		"name": "아무도 잃지 않은 원정",
		"line": "다 함께 떠나 다 함께 닿았다.\n행렬에 빈자리가 없었다.",
		"stat": "intact_arrivals", "at_least": 1,
	},
	{
		"id": "rec_all_paths",
		"name": "모든 길을 밟은 원정대들",
		"line": "지도의 어느 자리에도\n원정대의 발자국이 닿았다.\n어느 한 원정의 일이 아니다.",
		"stat": "all_nodes_visited", "at_least": 1,
	},
	{
		"id": "rec_reunion",
		"name": "건너편의 재회",
		"line": "먼저 간 모든 원정대가\n건너편에서 기다리고 있었다.",
		"stat": "reunions", "at_least": 1,
	},
]

static func by_id(id: String) -> Dictionary:
	for f in LIST:
		if str(f.get("id", "")) == id:
			return f
	return {}

## 이 공훈이 지금 통계로 달성인가.
static func achieved(feat: Dictionary, stats: Dictionary) -> bool:
	return int(stats.get(str(feat.get("stat", "")), 0)) >= int(feat.get("at_least", 1))

## 지금 통계로 달성인 공훈 id 목록(정의 순서 유지).
static func achieved_ids(stats: Dictionary) -> Array:
	var out: Array = []
	for f in LIST:
		if achieved(f, stats):
			out.append(str(f.get("id", "")))
	return out

## 달성한 공훈 id 목록 → 열린 직능 id 목록(Vocations.LIST 순서, 평범("")은 항상 열려 있어 제외).
static func vocations_open(unlocked_feat_ids: Array) -> Array:
	var opened: Dictionary = {}
	for fid in unlocked_feat_ids:
		var f: Dictionary = by_id(str(fid))
		if not f.is_empty():
			opened[str(f.get("unlocks", ""))] = true
	var out: Array = []
	for vid in Vocations.ids():
		if str(vid) != "" and opened.has(str(vid)):
			out.append(str(vid))
	return out
