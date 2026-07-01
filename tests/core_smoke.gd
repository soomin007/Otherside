extends SceneTree

## 순수 core 회귀 스모크 테스트 — 커밋된 불변식 가드.
##
## 목적: 여러 병렬 세션이 core(ExpeditionRun/SectionRun/Situations/MapGraph)를 자주 고친다.
##       핵심 불변식을 커밋된 테스트로 고정해 조용한 회귀를 막는다(매번 일회용 -s 를 버리지 않도록).
##
## 실행: godot --headless --path . -s tests/core_smoke.gd   (에러/실패 0 이어야 함)
## 제약: GameState(autoload) 를 참조하지 않는다 — -s 컨텍스트엔 autoload 가 없다(known_issues 참고).
##       그래서 검증 대상은 "순수 결정론 core"뿐. 세이브·라우팅(GameState)·UI 는 부팅/스크린샷으로 따로 본다.

var _fail: int = 0

func _init() -> void:
	_test_mapgraph_integrity()
	_test_water_cost_curve()
	_test_edge_progression()
	_test_death_by_thirst()
	_test_arrival_event_priority()
	_test_flag_chain_variants()
	_test_catalog_requires_filter()
	_test_section_budget()
	_test_bequeath_gate()

	if _fail == 0:
		print("=== core_smoke: ALL PASS ===")
	else:
		print("=== core_smoke: FAIL ", _fail, " ===")
	quit(1 if _fail > 0 else 0)

# --- helpers ---

func _ok(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		print("FAIL: ", label)
		_fail += 1

func _fresh(starting: Dictionary = {}, bridged: Array = [], flags: Array = [], traces: Dictionary = {}) -> ExpeditionRun:
	var start: Dictionary = starting if not starting.is_empty() else {"water": 99, "food": 99, "rope": 2, "shelter": 2}
	return ExpeditionRun.new(start, bridged, flags, traces)

## 도착 또는 사망까지 전진(이동 중 상황은 효과 없이 통과).
func _advance(run: ExpeditionRun, max_steps: int = 40) -> void:
	var n: int = 0
	while run.alive and not run.arrived() and n < max_steps:
		run.step()
		if not run.pending_situation.is_empty():
			run.apply_choice({})
		n += 1

# --- tests ---

func _test_mapgraph_integrity() -> void:
	var nodes: Dictionary = MapGraph.NODES
	_ok(nodes.has(MapGraph.START_ID), "그래프: START_ID(%s) 존재" % MapGraph.START_ID)
	_ok(nodes.has("end"), "그래프: end 노드 존재")
	var bad_next: int = 0
	var bad_field: int = 0
	for id in nodes:
		var node: Dictionary = nodes[id]
		for key in ["kind", "name", "row", "col"]:
			if not node.has(key):
				bad_field += 1
				print("  · 필드 누락: ", id, ".", key)
		for nx in node.get("next", []):
			if not nodes.has(str(nx)):
				bad_next += 1
				print("  · 끊긴 엣지: ", id, " → ", nx)
	_ok(bad_next == 0, "그래프: 모든 next 대상 노드가 존재(끊긴 엣지 0)")
	_ok(bad_field == 0, "그래프: 모든 노드 kind/name/row/col 보유")
	# end 도달 가능성(BFS)
	var seen: Dictionary = {MapGraph.START_ID: true}
	var stack: Array = [MapGraph.START_ID]
	while not stack.is_empty():
		var cur: String = stack.pop_back()
		for nx in MapGraph.node(cur).get("next", []):
			var s: String = str(nx)
			if not seen.has(s):
				seen[s] = true
				stack.append(s)
	_ok(seen.has("end"), "그래프: START 에서 end 까지 도달 가능")

func _test_water_cost_curve() -> void:
	var run: ExpeditionRun = _fresh()
	run.leg = 0
	_ok(run.water_cost() == 1, "물 소모 곡선: leg0 → 1")
	run.leg = ExpeditionRun.DESOLATION_EVERY      # 16
	_ok(run.water_cost() == 2, "물 소모 곡선: leg16 → 2 (멀수록 척박)")
	run.leg = ExpeditionRun.DESOLATION_EVERY * 2  # 32
	_ok(run.water_cost() == 3, "물 소모 곡선: leg32 → 3")

func _test_edge_progression() -> void:
	var run: ExpeditionRun = _fresh()
	run.begin_edge("a1")
	_ok(run.edge_remaining() == ExpeditionRun.EDGE_LEN, "엣지 전진: 시작 시 남은 걸음 = EDGE_LEN")
	_ok(run.target_node_id() == "a1", "엣지 전진: target_node_id = a1")
	_advance(run)
	_ok(run.arrived(), "엣지 전진: EDGE_LEN 걸음 후 도착")
	_ok(run.edge_remaining() == 0, "엣지 전진: 도착 시 남은 걸음 0")
	run.arrive()
	_ok(run.current_node == "a1", "엣지 전진: arrive() 후 현재 노드 = a1")

func _test_death_by_thirst() -> void:
	# 물 3, 소모 1/걸음(출발지) → 3걸음째 고갈. 도착(5걸음) 전에 죽는다.
	var run: ExpeditionRun = _fresh({"water": 3, "food": 99, "rope": 0, "shelter": 0})
	run.begin_edge("a1")
	_advance(run)
	_ok(not run.alive, "고갈사: 물 3으로 도착 전 사망")
	_ok(run.death_cause == "thirst", "고갈사: 사인 = thirst")
	_ok(run.death_node_id() == MapGraph.START_ID, "고갈사: 이동 중 사 → 떠나온 노드(n0)에 시체")

func _test_arrival_event_priority() -> void:
	# ① 로프 걸린 차단(b2) = 무료 통과 (흔적이 같이 있어도 통과가 우선)
	var r1: ExpeditionRun = _fresh({"water": 99, "food": 99}, ["b2"], [], {"b2": {}})
	r1.begin_edge("b2")
	var ev1: Dictionary = r1.arrival_event()
	_ok(str(ev1.get("kind", "")) == "bridged", "도착 우선순위 ①: 로프 걸린 차단 = 무료 통과(흔적보다 우선)")

	# ② 흔적 줍기 (cache 노드 a1 에 흔적)
	var r2: ExpeditionRun = _fresh({"water": 99, "food": 99}, [], [], {"a1": {}})
	r2.begin_edge("a1")
	var ev2: Dictionary = r2.arrival_event()
	_ok(str(ev2.get("id", "")) == "pickup", "도착 우선순위 ②: 흔적 있으면 줍기 카드")

	# ③ 아무것도 없으면 노드 이벤트
	var r3: ExpeditionRun = _fresh({"water": 99, "food": 99})
	r3.begin_edge("a1")
	var ev3: Dictionary = r3.arrival_event()
	var eid: String = str(ev3.get("id", ""))
	_ok(eid.begins_with("river") or eid != "", "도착 우선순위 ③: 흔적·로프 없으면 노드 이벤트(%s)" % eid)

func _test_flag_chain_variants() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# a1: river_dug 켜지면 재방문 변형
	var a1: Dictionary = MapGraph.node("a1")
	var base := Situations.pick_event(a1, {}, rng)
	_ok(str(base.get("id", "")) != "river_dug_again", "플래그 체인: a1 플래그 없음 → 변형 아님")
	var variant := Situations.pick_event(a1, {"river_dug": true}, rng)
	_ok(str(variant.get("id", "")) == "river_dug_again", "플래그 체인: a1 + river_dug → river_dug_again")
	# f1: pool_drank 켜지면 폭풍 변형(지난 세션 체인)
	var f1: Dictionary = MapGraph.node("f1")
	var ill := Situations.pick_event(f1, {"pool_drank": true}, rng)
	_ok(str(ill.get("id", "")) == "storm_gate_ill", "플래그 체인: f1 + pool_drank → storm_gate_ill")

func _test_catalog_requires_filter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var leaked: bool = false
	for i in range(300):
		var sid: String = str(Situations.pick(rng, "", {}).get("id", ""))
		if sid == "gut_turn" or sid == "no_rope_ledge":
			leaked = true
			break
	_ok(not leaked, "CATALOG 필터: 플래그 없으면 requires 상황 안 뜸(300회)")
	var saw: bool = false
	for i in range(300):
		if str(Situations.pick(rng, "", {"pool_drank": true}).get("id", "")) == "gut_turn":
			saw = true
			break
	_ok(saw, "CATALOG 필터: pool_drank 켜면 gut_turn 후보로 뜸")

func _test_section_budget() -> void:
	# b1(야영지): 주요 지점(도착 이벤트) 1 + 정적 spots 2 = 3, 예산 min(2,3)=2
	var run: ExpeditionRun = _fresh()
	run.begin_edge("b1")
	var section := SectionRun.new(run, MapGraph.node("b1"))
	_ok(section.spot_count() == 3, "단면: b1 지점 수 = 3(주요1+보조2)")
	_ok(section.budget_left() == 2, "단면: 예산 = min(probes 2, 지점 3) = 2")
	var d0: Dictionary = section.probe(0)
	_ok(not d0.is_empty() and d0.has("type"), "단면: probe(0) 결과 디스크립터 반환")
	section.probe(1)
	_ok(section.budget_left() == 0 and section.exhausted(), "단면: 2회 조사 후 예산 소진·exhausted")
	_ok(section.probe(2).is_empty(), "단면: 예산 0 이면 더 조사 불가")

func _test_bequeath_gate() -> void:
	var run: ExpeditionRun = _fresh({"water": 20, "food": 13, "rope": 1, "shelter": 1})
	_ok(run.can_leave("water"), "남기기: 물 20 → 남길 수 있음")
	run.do_leave("water")
	_ok(run.get_res("water") == 20 - run.leave_cost("water"), "남기기: 비용만큼 물 차감")
	_ok(not run.can_leave("food"), "남기기: 런당 1회 — 이미 남겼으면 또 못 남김")
	# 생존 게이트: 남기면 죽는(<1) 자원은 못 남김
	var poor: ExpeditionRun = _fresh({"water": 4, "food": 13, "rope": 0, "shelter": 0})
	_ok(not poor.can_leave("water"), "남기기: 물 4(비용 4) → 남기면 0 이라 잠금(생존 게이트)")
