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
	_test_edge_distance()
	_test_death_by_thirst()
	_test_arrival_event_priority()
	_test_flag_chain_variants()
	_test_catalog_requires_filter()
	_test_biome_weighting()
	_test_progress_gating()
	_test_section_budget()
	_test_section_mandatory_threat()
	_test_section_bridged_gate()
	_test_bequeath_gate()
	_test_tool_bequest()
	_test_vocations()
	_test_items()
	_test_weight()

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
	run.leg = ExpeditionRun.DESOLATION_EVERY      # 현재 기본값 30 (튜닝 손잡이)
	_ok(run.water_cost() == 2, "물 소모 곡선: leg=DESOLATION_EVERY → 2 (멀수록 척박)")
	run.leg = ExpeditionRun.DESOLATION_EVERY * 2
	_ok(run.water_cost() == 3, "물 소모 곡선: leg=DESOLATION_EVERY*2 → 3")

func _test_edge_progression() -> void:
	var run: ExpeditionRun = _fresh()
	run.begin_edge("a1")
	var expect: int = MapGraph.edge_steps("n0", "a1")
	_ok(run.edge_remaining() == expect, "엣지 전진: 시작 시 남은 걸음 = edge_steps(n0,a1)=%d" % expect)
	_ok(run.edge_len() == expect, "엣지 전진: edge_len() = edge_steps")
	_ok(run.target_node_id() == "a1", "엣지 전진: target_node_id = a1")
	_advance(run)
	_ok(run.arrived(), "엣지 전진: 경로 걸음 후 도착")
	_ok(run.edge_remaining() == 0, "엣지 전진: 도착 시 남은 걸음 0")
	run.arrive()
	_ok(run.current_node == "a1", "엣지 전진: arrive() 후 현재 노드 = a1")

## 엣지 걸음 수 = 곡선 반영 경로 길이 비례(직선거리 아님). 가까우면 짧고, 멀면 길다.
func _test_edge_distance() -> void:
	# 곡선 경로 길이 >= 직선거리(사행·지그재그는 더 길다)
	var straight: float = MapGraph.pos("n0").distance_to(MapGraph.pos("a1"))
	var curved: float = MapGraph.edge_length("n0", "a1")
	_ok(curved >= straight - 0.5, "엣지 거리: 곡선 경로 길이(%.0f) >= 직선거리(%.0f)" % [curved, straight])
	# 가까운 엣지(a1→b2, 짧음)가 먼 엣지(a1→b1, 김)보다 걸음 적다 — 거리 비례의 핵심
	var near: int = MapGraph.edge_steps("a1", "b2")
	var far: int = MapGraph.edge_steps("a1", "b1")
	_ok(near < far, "엣지 거리: 가까운 a1→b2(%d걸음) < 먼 a1→b1(%d걸음)" % [near, far])
	# 모든 엣지 걸음이 [EDGE_MIN, EDGE_MAX] 안(즉사·순간이동 방지)
	var all_in: bool = true
	for id in MapGraph.NODES:
		for nx in MapGraph.node(id).get("next", []):
			var s: int = MapGraph.edge_steps(id, str(nx))
			if s < MapGraph.EDGE_MIN or s > MapGraph.EDGE_MAX:
				all_in = false
				print("  · 범위 밖 엣지 ", id, "→", nx, " = ", s)
	_ok(all_in, "엣지 거리: 모든 엣지 걸음이 [%d, %d] 안" % [MapGraph.EDGE_MIN, MapGraph.EDGE_MAX])

func _test_death_by_thirst() -> void:
	# 물 = (n0→a1 걸음 수 − 1), 소모 1/걸음(출발지) → 마지막 걸음 전에 고갈. 도착 전 이동 중 사(엣지 길이 무관하게 견고).
	var elen: int = MapGraph.edge_steps("n0", "a1")
	var run: ExpeditionRun = _fresh({"water": elen - 1, "food": 99, "rope": 0, "shelter": 0})
	run.begin_edge("a1")
	_advance(run)
	_ok(not run.alive, "고갈사: 물 %d(도착 %d걸음 전)로 도착 전 사망" % [elen - 1, elen])
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

func _test_biome_weighting() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# biome="flats" 구간엔 다른 지형 전용(river/rock/storm)은 절대 안 뜬다(개연성 — 안 맞는 지형 전용 제외).
	var off_biome: Dictionary = {
		"past_flask": true, "old_tracks": true, "scavenge_wreck": true, "murky_spring": true,
		"twisted_ankle": true, "frozen_night": true, "sand_squall": true,
	}
	var leaked: bool = false
	for i in range(400):
		var sid: String = str(Situations.pick(rng, "", {}, false, "flats").get("id", ""))
		if off_biome.has(sid):
			leaked = true
			break
	_ok(not leaked, "biome 가중: flats 구간엔 river/rock/storm 전용 안 뜸(400회)")
	# biome="" (지형 무시) → 전 지형 이벤트가 후보(기존 동작 회귀). river 전용도 뜬다.
	var saw_river: bool = false
	for i in range(400):
		var sid2: String = str(Situations.pick(rng, "", {}, false, "").get("id", ""))
		if sid2 == "past_flask" or sid2 == "murky_spring":
			saw_river = true
			break
	_ok(saw_river, "biome 가중: biome 무시면 전 지형 후보(기존 동작 회귀)")

## 진행도 게이트 — 후반 전용(min_prog) 이동 상황은 초반(마을 근처)엔 안 뜨고 후반(척박)에만 뜬다.
func _test_progress_gating() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	# 초반(progress 0.0)엔 후반 전용(scorched_waste, min_prog 0.55) 안 뜬다
	var early_leaked: bool = false
	for i in range(500):
		if str(Situations.pick(rng, "", {}, false, "flats", 0.0).get("id", "")) == "scorched_waste":
			early_leaked = true
			break
	_ok(not early_leaked, "진행도 게이트: 초반(0.0)엔 후반 전용(scorched_waste) 안 뜸(500회)")
	# 후반(progress 0.7, flats)엔 뜬다
	var late_seen: bool = false
	for i in range(500):
		if str(Situations.pick(rng, "", {}, false, "flats", 0.7).get("id", "")) == "scorched_waste":
			late_seen = true
			break
	_ok(late_seen, "진행도 게이트: 후반(0.7)엔 후반 전용(scorched_waste) 등장")

func _test_section_budget() -> void:
	# b1(야영지): 주요 지점(도착 이벤트, 있으면 1) + requires 안 걸린 정적 spots.
	# 콘텐츠(spots)가 늘어도 안 깨지게 노드에서 기대값을 계산한다.
	var run: ExpeditionRun = _fresh()
	run.begin_edge("b1")
	var node: Dictionary = MapGraph.node("b1")
	var expected: int = 0
	if not run.arrival_event().is_empty():
		expected += 1
	for sp in node.get("spots", []):
		var req: String = str(sp.get("requires", ""))
		if req == "" or run.has_flag(req):
			expected += 1
	var section := SectionRun.new(run, node)
	_ok(section.spot_count() == expected, "단면: b1 지점 수 = %d(주요+requires통과 보조)" % expected)
	_ok(section.budget_left() == mini(2, expected), "단면: 예산 = min(probes 2, 지점 %d)" % expected)
	var d0: Dictionary = section.probe(0)
	_ok(not d0.is_empty() and d0.has("type"), "단면: probe(0) 결과 디스크립터 반환")
	section.probe(1)
	_ok(section.budget_left() == 0 and section.exhausted(), "단면: 2회 조사 후 예산 소진·exhausted")
	_ok(section.probe(2).is_empty(), "단면: 예산 0 이면 더 조사 불가")

## 필수 위협(폭풍/차단) 게이트 — 두 단계(2026-07-09): 통과를 열기 전엔 보조 지점이 숨고,
## 통과는 예산 무료·마주 전엔 떠날 수 없다(스킵 치즈 방지).
func _test_section_mandatory_threat() -> void:
	# e1(무너진 담, blockage): 주요 지점 = 필수 위협(게이트). 보조 4지점(전부 requires 없음).
	var run: ExpeditionRun = _fresh()
	run.begin_edge("e1")
	var node: Dictionary = MapGraph.node("e1")
	var section := SectionRun.new(run, node)
	_ok(section.has_unresolved_threat(), "단면(위협): e1 도착 시 마주 안 한 필수 위협 있음")
	# 예산은 보조(선택형) 지점만 센다 — 필수 위협은 예산 밖.
	var optional: int = 0
	for sp in node.get("spots", []):
		var req: String = str(sp.get("requires", ""))
		if req == "" or run.has_flag(req):
			optional += 1
	_ok(section.budget_left() == mini(1, optional), "단면(위협): 예산 = min(probes-1, 보조 %d) — 필수 위협이 한 칸 차지" % optional)
	_ok(section.gate_idx == 0 and not section.gate_opened(), "단면(위협/2단계): 위협이 게이트")
	# 두 단계 — 통과를 열기 전엔 보조가 숨고 조사도 불가.
	var leaked: int = 0
	for i in range(1, section.spot_count()):
		if section.is_spot_visible(i) or section.can_probe(i):
			leaked += 1
	_ok(leaked == 0, "단면(위협/2단계): 통과 전 보조 지점 숨김·조사 불가")
	_ok(not section.exhausted(), "단면(위협/2단계): 게이트가 남아 exhausted 아님")
	# 게이트(위협) 조사 — 예산 무료, 이후 보조가 드러난다.
	var b0: int = section.budget_left()
	section.probe(0)
	_ok(section.budget_left() == b0, "단면(위협): 위협 조사는 예산 무료")
	_ok(not section.has_unresolved_threat(), "단면(위협): 필수 위협 조사 후 떠날 수 있음")
	var revealed: int = 0
	for i in range(1, section.spot_count()):
		if section.is_spot_visible(i):
			revealed += 1
	_ok(revealed == section.spot_count() - 1, "단면(위협/2단계): 통과 후 보조 전부 드러남")
	# 보조 조사로 예산 소진.
	for i in range(1, section.spot_count()):
		if section.can_probe(i):
			section.probe(i)
	_ok(section.budget_left() == 0 and section.exhausted(), "단면(위협): 보조 조사로 예산 소진·exhausted")

## 로프 다리(bridged) 게이트 — 통과가 보조를 여는 게이트이되 예산 무료, 떠나기는 안 막는다(보답이지 위협 아님).
func _test_section_bridged_gate() -> void:
	var run: ExpeditionRun = _fresh({}, ["e1"])   # e1 에 이전 원정대의 로프가 걸린 세계
	run.begin_edge("e1")
	var node: Dictionary = MapGraph.node("e1")
	var section := SectionRun.new(run, node)
	_ok(str(run.arrival_event().get("kind", "")) == "bridged", "단면(다리): e1 도착 카드 = bridged")
	_ok(section.gate_idx == 0, "단면(다리/2단계): 다리 통과가 게이트")
	_ok(not section.has_unresolved_threat(), "단면(다리): 위협 아님 — 떠나기 안 막음")
	_ok(section.budget_left() == 2, "단면(다리): 예산 2 유지(통과가 예산을 안 차지)")
	var hidden: bool = true
	for i in range(1, section.spot_count()):
		if section.is_spot_visible(i):
			hidden = false
	_ok(hidden, "단면(다리/2단계): 통과 전 보조 숨김")
	var b0: int = section.budget_left()
	section.probe(0)
	_ok(section.budget_left() == b0, "단면(다리): 통과 조사는 예산 무료(옛 예산 낭비 함정 제거)")
	_ok(section.gate_opened() and section.spot_count() > 1 and section.is_spot_visible(1), "단면(다리/2단계): 통과 후 보조 드러남")

func _test_bequeath_gate() -> void:
	var run: ExpeditionRun = _fresh({"water": 20, "food": 13, "rope": 1, "shelter": 1})
	_ok(run.can_leave("water"), "남기기: 물 20 → 남길 수 있음")
	run.do_leave("water")
	_ok(run.get_res("water") == 20 - run.leave_cost("water"), "남기기: 비용만큼 물 차감")
	_ok(not run.can_leave("food"), "남기기: 런당 1회 — 이미 남겼으면 또 못 남김")
	# 생존 게이트: 남기면 죽는(<1) 자원은 못 남김
	var poor: ExpeditionRun = _fresh({"water": 4, "food": 13, "rope": 0, "shelter": 0})
	_ok(not poor.can_leave("water"), "남기기: 물 4(비용 4) → 남기면 0 이라 잠금(생존 게이트)")

## 도구 유품 — 주머니 도구도 자원처럼 남기고/줍는다(TraceData 매핑·비용·줍기 카드 대칭).
func _test_tool_bequest() -> void:
	_ok(TraceData.kind_to_key(TraceData.ObjectKind.MEDICINE) == "medicine", "도구 유품: kind_to_key MEDICINE=medicine")
	_ok(TraceData.is_pickable(TraceData.ObjectKind.FLINT), "도구 유품: FLINT 줍기 대상")
	_ok(not TraceData.is_pickable(TraceData.ObjectKind.ROPE), "도구 유품: ROPE 는 줍기 아님(다리로 남음)")
	var run: ExpeditionRun = _fresh({"water": 99, "food": 99, "medicine": 1, "flint": 1})
	_ok(run.leave_cost("medicine") == 1, "도구 유품: 약초 남기기 비용 1")
	_ok(run.can_leave("medicine"), "도구 유품: 약초 1 보유 → 남길 수 있음")
	run.do_leave("medicine")
	_ok(run.get_res("medicine") == 0 and run.bequeathed, "도구 유품: 약초 남기면 0·토큰 소진")
	_ok(not run.can_leave("flint"), "도구 유품: 이미 남겼으면 또 못 남김(런당 1회)")
	# 줍기 카드 — 부싯돌 흔적을 집으면 부싯돌 +1(대칭).
	var card: Dictionary = Situations.pickup_trace({"kind": TraceData.ObjectKind.FLINT, "tags": []})
	var choices: Array = card.get("choices", [])
	var first: Dictionary = choices[0]
	var eff: Dictionary = first.get("effect", {})
	_ok(int(eff.get("flint", 0)) == 1 and str(first.get("action", "")) == "pickup", "도구 유품: 부싯돌 흔적 줍기 → 부싯돌 +1(action=pickup)")

func _test_vocations() -> void:
	# 짐꾼 — 시작 자원 넉넉(물+6·식+5), 대신 후반 곡선이 더 가혹(무거운 짐 → desolation 악화)
	var porter: ExpeditionRun = ExpeditionRun.new({"water": 20, "food": 13}, [], [], {}, "porter")
	_ok(porter.get_res("water") == 26 and porter.get_res("food") == 18, "직능 짐꾼: 시작 물+6·식+5")
	var plain: ExpeditionRun = ExpeditionRun.new({"water": 20, "food": 13})
	porter.leg = 24
	plain.leg = 24
	_ok(porter.water_cost() > plain.water_cost(), "직능 짐꾼: 먼 거리(leg24) 물 소모 더 큼(무거운 짐)")
	# 길잡이 — 먼 거리서 물 소모 곡선 완화
	var path: ExpeditionRun = ExpeditionRun.new({"water": 20, "food": 13}, [], [], {}, "pathfinder")
	path.leg = 36
	plain.leg = 36
	_ok(path.water_cost() < plain.water_cost(), "직능 길잡이: 먼 거리(leg36) 물 소모 완화")
	# 물지기 — 물 얻을 때 +1, 잃을 땐 그대로
	var ww: ExpeditionRun = ExpeditionRun.new({"water": 10, "food": 10}, [], [], {}, "waterwise")
	ww.apply_choice({"water": 2})
	_ok(ww.get_res("water") == 13, "직능 물지기: 물 +2 획득 → 실제 +3")
	ww.apply_choice({"water": -2})
	_ok(ww.get_res("water") == 11, "직능 물지기: 물 잃을 땐 보너스 없음")
	# 강골 — 식량 소모 주기 늘어남(기본 2 → 4). 이동 중 상황은 억제하고 순수 소모만 본다(결정론).
	# 4걸음을 확실히 전진하도록 긴 엣지(a1→b1, 8걸음)에서 돌린다(짧은 엣지는 4걸음 전에 도착).
	var hardy: ExpeditionRun = ExpeditionRun.new({"water": 99, "food": 20}, [], [], {}, "hardy")
	hardy.current_node = "a1"
	hardy.begin_edge("b1")
	hardy._next_situation_leg = 9999
	for i in range(4):
		hardy.step()
	_ok(hardy.get_res("food") == 19, "직능 강골: 4걸음에 식량 -1(주기 4, 기본이면 -2)")
	# 유품지기 — 남기기 비용 완화(물 4→3), 로프는 최소 1 보장(공짜 없음)
	var keeper: ExpeditionRun = ExpeditionRun.new({"water": 20, "food": 13}, [], [], {}, "keeper")
	_ok(keeper.leave_cost("water") == 3, "직능 유품지기: 물 남기기 비용 4→3")
	_ok(keeper.leave_cost("rope") == 1, "직능 유품지기: 로프 1→최소 1(공짜 남기기 없음)")
	# 기본(평범) — 효과 없음(회귀 가드)
	_ok(plain.leave_cost("water") == 4, "직능 없음(평범): 남기기 비용 기본 유지")

func _test_items() -> void:
	# 가방 합산(Items.resources_of): 물통2 + 약초 → 물14·약초1
	var res: Dictionary = Items.resources_of(["water", "water", "medicine"])
	_ok(int(res["water"]) == 14 and int(res.get("medicine", 0)) == 1, "Items: 물통2+약초 → 물14·약초1")
	# 부작용 아이템 — 말린 고기 식+9·물-2
	var jr: Dictionary = Items.resources_of(["jerky"])
	_ok(int(jr["food"]) == 9 and int(jr["water"]) == -2, "Items: 말린 고기 식+9·물-2(부작용)")
	# 도구 위기(fever) needs 게이트 — 약초 있으면 안전 선택지 가능, 없으면 잠김
	var fever: Dictionary = {}
	for s in Situations.CATALOG:
		if str(s.get("id", "")) == "fever":
			fever = s
			break
	_ok(not fever.is_empty(), "Items: fever 위기 이벤트 존재")
	var cure: Dictionary = fever.get("choices", [])[0]
	_ok(Situations.can_choose(cure, {"medicine": 1}), "Items: 약초 있으면 fever 치료 선택 가능")
	_ok(not Situations.can_choose(cure, {"medicine": 0}), "Items: 약초 없으면 fever 치료 선택 잠김")

func _test_weight() -> void:
	var base: ExpeditionRun = ExpeditionRun.new({"water": 20})
	# 무게 FREE(12) 이하 — 물 소모 안 늘어남
	var light: ExpeditionRun = ExpeditionRun.new({"water": 20}, [], [], {}, "", 8)
	_ok(light.water_cost() == base.water_cost(), "무게: FREE(12) 이하는 물 소모 불변")
	# 무게 초과 — STEP(4)마다 걸음당 물 +1 (무게 20 → 초과 8 → +2)
	var heavy: ExpeditionRun = ExpeditionRun.new({"water": 20}, [], [], {}, "", 20)
	_ok(heavy.water_cost() == base.water_cost() + 2, "무게: 초과분 STEP당 물 +1 (무게20 → +2)")
	# Items 무게 합산
	_ok(Items.bag_weight(["water", "water", "rope"]) == 7, "무게: 물통2+로프 = 3+3+1 = 7")
