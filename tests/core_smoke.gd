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
	_test_party_intact()
	_test_stragglers()
	_test_feats()
	_test_run_serialization()

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

## 행렬(연출 파티) — 위험한 순간 판정과 온전(재회 축 ③) 불변식.
func _test_party_intact() -> void:
	var run: ExpeditionRun = _fresh()
	_ok(run.party_left() == 1 + ExpeditionRun.PARTY_MATES, "행렬: 시작 인원 = 대장+대원")
	_ok(run.is_intact(), "행렬: 시작은 온전")
	# ① 위기에 당함 — 물+식량 합 ≥4 이고 물 ≥3 (열병 강행 -5 등).
	run.apply_choice({"water": -5})
	_ok(run.party_lost == 1, "행렬: 큰 물 손실(-5) = 위험한 순간 → 대원 1 손실")
	var notes: Array = run.take_loss_notes()
	_ok(notes.size() == 1, "행렬: 손실 서사 1건 발생")
	_ok(run.take_loss_notes().is_empty(), "행렬: 서사는 꺼내면 비워진다")
	# 신중한 우회(합 4, 물 2)는 위험한 순간이 아니다.
	run.apply_choice({"water": -2, "food": -2})
	_ok(run.party_lost == 1, "행렬: 신중한 우회(물-2·식량-2)는 손실 없음")
	# 물이 안 끼면(식량만 커도) 아니다.
	run.apply_choice({"food": -4})
	_ok(run.party_lost == 1, "행렬: 식량만 큰 손실은 위험한 순간 아님")
	# ② 바닥 스침 — 물이 처음 ≤2 로 떨어지면 1회만.
	var low: ExpeditionRun = _fresh({"water": 4, "food": 99, "rope": 0, "shelter": 0})
	low.apply_choice({"water": -2})
	_ok(low.party_lost == 1, "행렬: 물 첫 바닥 스침(≤2) → 대원 1 손실")
	low.apply_choice({"water": 3})
	low.apply_choice({"water": -3})
	_ok(low.party_lost == 1, "행렬: 물 바닥 스침은 런당 1회만")
	_ok(not low.is_intact(), "행렬: 손실 후엔 온전 아님")
	# 고갈사가 먼저면 손실을 세지 않는다(죽음이 말한다).
	var doomed: ExpeditionRun = _fresh({"water": 5, "food": 99, "rope": 0, "shelter": 0})
	doomed.apply_choice({"water": -5})
	_ok(not doomed.alive and doomed.take_loss_notes().is_empty(), "행렬: 고갈사 순간엔 손실 서사 없음")
	# 손실 상한 = 대원 수(대장은 마지막까지 걷는다).
	var worn: ExpeditionRun = _fresh()
	for i in range(ExpeditionRun.PARTY_MATES + 2):
		worn.apply_choice({"water": -5})
	_ok(worn.party_lost == ExpeditionRun.PARTY_MATES, "행렬: 손실은 대원 수까지만")
	_ok(worn.party_left() == 1, "행렬: 마지막엔 대장 홀로")

## 공훈(Feats) — 순수 판정: 문턱 경계·직능 매핑·정의 무결성(직능 id 실존·중복 해금 없음).
func _test_feats() -> void:
	var none: Dictionary = {"thirst_deaths": 0, "hunger_deaths": 0, "heavy_departures": 0, "max_row_visited": 0, "traces_left": 0}
	_ok(Feats.achieved_ids(none).is_empty(), "공훈: 빈 통계 = 달성 없음")
	var below: Dictionary = {"thirst_deaths": 1, "hunger_deaths": 1, "heavy_departures": 0, "max_row_visited": 3, "traces_left": 2}
	_ok(Feats.achieved_ids(below).is_empty(), "공훈: 문턱 미만은 전부 잠김(경계 -1)")
	var all_hit: Dictionary = {"thirst_deaths": 2, "hunger_deaths": 2, "heavy_departures": 1, "max_row_visited": 4, "traces_left": 3}
	_ok(Feats.achieved_ids(all_hit).size() == Feats.LIST.size(), "공훈: 문턱 정확히 = 전부 달성(경계 0)")
	var opened: Array = Feats.vocations_open(Feats.achieved_ids(all_hit))
	_ok(opened.size() == Vocations.ids().size() - 1, "공훈: 전부 달성이면 평범 외 전 직능이 열린다")
	var seen_voc: Dictionary = {}
	var sound: bool = true
	for f in Feats.LIST:
		var vid: String = str(f.get("unlocks", ""))
		if vid == "" or str(Vocations.by_id(vid).get("id", "x")) != vid or seen_voc.has(vid):
			sound = false
		seen_voc[vid] = true
	_ok(sound, "공훈: 해금 직능 id 실존 + 한 직능 한 공훈")
	_ok(Feats.vocations_open(["thirst_learned"]) == ["waterwise"], "공훈: 갈증 공훈 → 물지기만 연다")

## 이어하기 직렬화 — 실제 JSON 왕복 후 상태가 보존되고, rng 까지 복원돼 같은 미래를 걷는가.
func _test_run_serialization() -> void:
	var run: ExpeditionRun = ExpeditionRun.new({"water": 30, "food": 20, "rope": 1, "shelter": 1}, ["b2"], ["river_dug"], {}, "", 0, ["c1"])
	run.begin_edge("a1")
	for i in range(3):
		run.step()
		if not run.pending_situation.is_empty():
			run.apply_choice({})
	run.apply_choice({"water": -5})  # 위험한 순간 — 행렬·손실 자리도 직렬화 대상에 포함시킨다
	var parsed: Variant = JSON.parse_string(JSON.stringify(run.to_dict()))
	var d: Dictionary = parsed
	var back: ExpeditionRun = ExpeditionRun.from_dict(d)
	_ok(back.get_res("water") == run.get_res("water") and back.get_res("food") == run.get_res("food"), "이어하기: 자원 보존(JSON 왕복)")
	_ok(back.leg == run.leg and back.current_node == run.current_node and back.target_node_id() == run.target_node_id(), "이어하기: 위치·엣지 보존")
	_ok(back.party_lost == run.party_lost and back.loss_sites.size() == run.loss_sites.size(), "이어하기: 행렬·손실 자리 보존")
	_ok(back.has_flag("river_dug") and back.is_bridged("b2"), "이어하기: 플래그·다리 보존")
	_ok(back.bequeathed == run.bequeathed, "이어하기: 남기기 토큰 보존")
	# rng 결정론 — 같은 스냅샷에서 복원한 둘이 같은 미래를 걷는다(같은 걸음에 같은 상황).
	var a: ExpeditionRun = ExpeditionRun.from_dict(d)
	var b: ExpeditionRun = ExpeditionRun.from_dict(d)
	var same: bool = true
	for i in range(8):
		a.step()
		b.step()
		if str(a.pending_situation.get("id", "")) != str(b.pending_situation.get("id", "")):
			same = false
		if not a.pending_situation.is_empty():
			a.apply_choice({})
		if not b.pending_situation.is_empty():
			b.apply_choice({})
	_ok(same and a.leg == b.leg and a.get_res("water") == b.get_res("water"), "이어하기: rng 결정론(복원본 둘이 같은 미래)")
	# 단면 스냅샷 — 살핀 지점·예산·게이트가 JSON 왕복 후 보존된다(정밀 복원).
	var host: ExpeditionRun = ExpeditionRun.new({"water": 99, "food": 99})
	host.begin_edge("a1")
	_advance(host)
	var sec: SectionRun = SectionRun.new(host, MapGraph.node("a1"))
	for i in range(sec.spot_count()):
		if sec.can_probe(i):
			sec.probe(i)
			break
	var sparsed: Variant = JSON.parse_string(JSON.stringify(sec.to_dict()))
	var sd: Dictionary = sparsed
	var sec2: SectionRun = SectionRun.from_dict(sd)
	_ok(sec2.budget_left() == sec.budget_left() and sec2.probed_count() == sec.probed_count(), "이어하기: 단면 예산·조사 보존")
	var first_spot: Dictionary = sec2.get_spot(0)
	_ok(sec2.spot_count() == sec.spot_count() and first_spot.get("at") is Vector2, "이어하기: 지점 좌표 복원(Vector2)")
	_ok(sec2.has_unresolved_threat() == sec.has_unresolved_threat(), "이어하기: 위협 게이트 보존")

## 낙오자(재회 축 "구조") — 카드·도착 우선순위·거두기·손실 자리 기록 불변식.
func _test_stragglers() -> void:
	# 카드 모양 — 거두기(물 나눔, needs 3, action=rescue)와 지나치기.
	var ev: Dictionary = Situations.straggler_event()
	_ok(str(ev.get("id", "")) == "straggler", "낙오자: 카드 id = straggler")
	var c0: Dictionary = ev["choices"][0]
	_ok(str(c0.get("action", "")) == "rescue" and int(c0["effect"].get("water", 0)) == -2, "낙오자: 거두기 = 물 -2 + rescue")
	_ok(not Situations.can_choose(c0, {"water": 2}), "낙오자: 물 2 로는 못 거둔다(나누면 내가 못 산다)")
	# 도착 우선순위 — 낙오자 노드에 닿으면 사람이 무엇보다 먼저다.
	var run: ExpeditionRun = ExpeditionRun.new({"water": 99, "food": 99}, [], [], {}, "", 0, ["a1"])
	run.begin_edge("a1")
	_advance(run)
	_ok(run.arrived(), "낙오자: a1 도착")
	_ok(str(run.arrival_event().get("id", "")) == "straggler", "낙오자: 도착 카드 = 낙오자")
	# 거두면 행렬 +1, 그 노드의 카드는 사라진다.
	run.apply_choice({"water": -2})
	run.rescue_straggler("a1")
	_ok(run.party_gained == 1 and run.party_left() == 2 + ExpeditionRun.PARTY_MATES, "낙오자: 거두면 행렬 +1")
	_ok(str(run.arrival_event().get("id", "")) != "straggler", "낙오자: 거둔 노드엔 카드 없음")
	run.party_lost = 1
	_ok(not run.is_intact(), "낙오자: 구조가 손실을 상쇄하지 않는다(온전은 별도)")
	# 손실 자리 기록 — 위험한 순간의 자리가 남는다(런이 끝나면 GameState 가 낙오자로 심는다).
	var lossy: ExpeditionRun = ExpeditionRun.new({"water": 99, "food": 99})
	lossy.begin_edge("a1")
	_advance(lossy)
	lossy.apply_choice({"water": -5})
	_ok(lossy.loss_sites.size() == 1 and str(lossy.loss_sites[0]["node_id"]) == "a1", "낙오자: 손실 자리 = 그 노드")

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
	# 추모 표식 — 자원 무변, 런당 1회의 남기기 토큰을 공유·소진.
	var m: ExpeditionRun = _fresh()
	_ok(m.can_leave_mark(), "추모: 토큰 미사용이면 기릴 수 있음")
	var w0: int = m.get_res("water")
	m.do_leave_mark()
	_ok(m.get_res("water") == w0 and m.bequeathed, "추모: 자원 무변 + 토큰 소진")
	_ok(not m.can_leave("water") and not m.can_leave_mark(), "추모: 같은 런에 남기기/기림 모두 잠김(토큰 공유)")

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
