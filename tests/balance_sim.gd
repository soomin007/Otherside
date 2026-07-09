extends SceneTree

## 밸런스 시뮬레이터 — 순수 core 로 원정을 수천 번 굴려 통계를 뽑는다(화면 없이).
##
## 왜 되나: scripts/core/ 가 순수·결정론이라 렌더 없이 ExpeditionRun 을 정책(가상 플레이어)으로 끝까지 돌릴 수 있다.
## 무엇을 주나: 런 길이 분포·end 도달률·사인 분해·노드 도달 히스토그램 + 파라미터 스윕(손잡이 튜닝).
## 무엇을 못 주나: "재미"의 정성(긴장·정서·페이싱 체감)은 사람 몫. 이건 파탄·지배전략·죽은 콘텐츠를 미리 거른다.
##
## 실행: godot --headless --path . -s tests/balance_sim.gd
## 제약: GameState(autoload) 미참조 — 순수 core 만. 시작 자원 기본값은 GameState.START_RESOURCES 와 맞춰 둔다(아래 BASE).
##
## 정책(정책 간 격차 = 스킬 상/하한):
##  - GREEDY   생존-탐욕: 물/식량 보존 최대(장비로 큰 손실 막음). 잘 두는 상한.
##  - RANDOM   무작위: 기준선.
##  - RECKLESS 무모: 장비 안 쓰고 강행만. 못 두는 하한.
## 갈림(분기)은 모든 정책이 "블라인드"(강한 미지 — 도착 전엔 노드 정체를 모른다) → 무작위. 정직한 모델.

enum Policy { GREEDY, RANDOM, RECKLESS }

## GameState.START_RESOURCES 와 동기화(수치 바뀌면 같이). 스윕은 이 baseline 을 변주한다.
const BASE_START: Dictionary = {"water": 20, "food": 13, "rope": 1, "shelter": 1}
const RUNS: int = 500          ## 정책당 시뮬 판 수
const MAX_STEPS: int = 400     ## 무한 루프 방지(도달 못 하면 끊음)

func _init() -> void:
	print("=== 밸런스 시뮬레이터 (정책당 ", RUNS, "판) ===\n")

	print("[1] 정책 비교 — 기본 시작 자원 ", BASE_START)
	for pol in [Policy.GREEDY, Policy.RANDOM, Policy.RECKLESS]:
		_report(_policy_name(pol), _batch(pol, BASE_START, 1000))

	print("\n[2] 파라미터 스윕 — 시작 물 (정책=GREEDY, end 도달률·중앙값 leg)")
	for w in [12, 16, 20, 24, 28]:
		var start := BASE_START.duplicate()
		start["water"] = w
		var st := _batch(Policy.GREEDY, start, 5000 + w)
		print("  물 %2d → end 도달 %5.1f%% · 중앙 leg %2d · 평균 최종 노드 row %.1f · 갈증사 %.0f%%" % [
			w, st["reach_pct"], st["median_leg"], st["avg_row"], st["thirst_pct"]])

	print("\n[3] 2D 스윕 — DESOLATION_EVERY × STEPS_PER_UNIT (엣지 걸음=곡선 경로 길이×SPU. 손잡이 오버라이드 → 끝에 원복)")
	print("     각 칸: GREEDY end% (중앙leg · 최종row · 갈증%) | RECKLESS end%   [★=현재 기본값]")
	var deso_orig: int = ExpeditionRun.DESOLATION_EVERY
	var spu_orig: float = MapGraph.STEPS_PER_UNIT
	for spu in [0.027, 0.031, 0.035]:
		for deso in [24, 28, 30, 32]:
			ExpeditionRun.DESOLATION_EVERY = deso
			MapGraph.STEPS_PER_UNIT = spu
			var g: Dictionary = _batch(Policy.GREEDY, BASE_START, 70000 + deso * 100 + int(spu * 1000))
			var rk: Dictionary = _batch(Policy.RECKLESS, BASE_START, 75000 + deso * 100 + int(spu * 1000))
			var star: String = " ★" if (deso == deso_orig and absf(spu - spu_orig) < 0.0005) else ""
			print("  SPU %.3f · DESO %2d → GREEDY %5.1f%% (leg %2d · row %.1f · 갈증 %2.0f%%) | RECKLESS %4.1f%%%s" % [
				spu, deso, g["reach_pct"], g["median_leg"], g["avg_row"], g["thirst_pct"], rk["reach_pct"], star])
	ExpeditionRun.DESOLATION_EVERY = deso_orig
	MapGraph.STEPS_PER_UNIT = spu_orig

	print("\n[4] 콘텐츠 커버리지 — GREEDY 500판에서 각 도착 이벤트가 뜬 횟수(0 = 죽은 콘텐츠 의심)")
	_coverage_report()

	print("\n[5] 직능 비교 — GREEDY, 기본 시작 자원 위에 직능 보너스가 더해진다")
	var vi: int = 0
	for vid in Vocations.ids():
		var st: Dictionary = _batch(Policy.GREEDY, BASE_START, 82000 + vi * 137, vid)
		vi += 1
		print("  %-11s | end %5.1f%% | 중앙 leg %2d · row %.1f · 갈증 %2.0f%% · 배고픔 %2.0f%%" % [
			Vocations.name_of(vid), st["reach_pct"], st["median_leg"], st["avg_row"], st["thirst_pct"], st["hunger_pct"]])

	print("\n[6] 도구 장착 비교 (GREEDY) — 위기를 도구로 넘기는 효과 (도구 챙기면 물/식량 칸이 준다)")
	var loadouts: Array = [
		{"name": "주머니 비움", "res": {"water": 20, "food": 13, "rope": 1, "shelter": 1}},
		{"name": "+약초(주머니)", "res": {"water": 20, "food": 13, "rope": 1, "shelter": 1, "medicine": 1}},
		{"name": "+정화천(주머니)", "res": {"water": 20, "food": 13, "rope": 1, "shelter": 1, "filter": 1}},
	]
	var li: int = 0
	for lo in loadouts:
		var st: Dictionary = _batch(Policy.GREEDY, lo["res"], 91000 + li * 137)
		li += 1
		print("  %-16s | end %5.1f%% | 중앙 leg %2d · row %.1f · 갈증 %2.0f%% · 배고픔 %2.0f%%" % [
			str(lo["name"]), st["reach_pct"], st["median_leg"], st["avg_row"], st["thirst_pct"], st["hunger_pct"]])

	print("\n[7] 유령 흔적 영향 (GREEDY) — 시작 세계에 심긴 예비 원정대 흔적. 자원 유령은 uses 로 몇 판 뒤 소멸(여긴 매 판 적용 = 최대치 과장).")
	var g_bridged: Array = ["b2"]
	var g_pickups: Dictionary = {
		"a1": {"kind": TraceData.ObjectKind.WATER, "tags": []},
		"c1": {"kind": TraceData.ObjectKind.WATER, "tags": []},
		"c2": {"kind": TraceData.ObjectKind.SHELTER, "tags": []},
	}
	_report("무흔적", _batch(Policy.GREEDY, BASE_START, 93000))
	_report("b2로프만", _batch(Policy.GREEDY, BASE_START, 93000, "", g_bridged, {}))       # 영구 효과(steady state)
	_report("전체유령", _batch(Policy.GREEDY, BASE_START, 93000, "", g_bridged, g_pickups)) # 첫 세계 최대치(실제론 소멸)

	print("\n=== 끝 (수치는 정책 근사 — 최종 밸런스는 폰 플레이로) ===")
	quit()

# --- 배치 시뮬 ---

func _batch(policy: int, start: Dictionary, seed_base: int, voc_id: String = "", bridged: Array = [], pickups: Dictionary = {}) -> Dictionary:
	var legs: Array = []
	var reached: int = 0
	var deaths: Dictionary = {"thirst": 0, "hunger": 0, "": 0}
	var rows: Array = []
	for i in range(RUNS):
		var r: Dictionary = _run_once(policy, start, seed_base * 131 + i, voc_id, bridged, pickups)
		legs.append(int(r["leg"]))
		rows.append(int(r["row"]))
		if bool(r["reached_end"]):
			reached += 1
		var dc: String = str(r["death_cause"])
		deaths[dc] = int(deaths.get(dc, 0)) + 1
	legs.sort()
	rows.sort()
	return {
		"legs": legs,
		"reach_pct": 100.0 * reached / RUNS,
		"median_leg": legs[legs.size() / 2],
		"p10_leg": legs[int(legs.size() * 0.1)],
		"p90_leg": legs[int(legs.size() * 0.9)],
		"avg_leg": _avg(legs),
		"avg_row": _avg(rows),
		"thirst_pct": 100.0 * int(deaths.get("thirst", 0)) / RUNS,
		"hunger_pct": 100.0 * int(deaths.get("hunger", 0)) / RUNS,
		"deaths": deaths,
	}

func _report(label: String, st: Dictionary) -> void:
	print("  %-9s | end 도달 %5.1f%% | leg 중앙 %2d (p10 %2d · p90 %2d · 평균 %.1f) | 갈증 %.0f%% · 배고픔 %.0f%%" % [
		label, st["reach_pct"], st["median_leg"], st["p10_leg"], st["p90_leg"], st["avg_leg"],
		st["thirst_pct"], st["hunger_pct"]])

# --- 한 판 ---

func _run_once(policy: int, start: Dictionary, seed_val: int, voc_id: String = "", bridged: Array = [], pickups: Dictionary = {}) -> Dictionary:
	var run := ExpeditionRun.new(start.duplicate(), bridged, [], pickups, voc_id)
	run.rng.seed = seed_val
	var brng := RandomNumberGenerator.new()  ## 분기·정책 tie-break 용
	brng.seed = seed_val * 7 + 3
	var reached_end: bool = false
	var guard: int = 0

	while run.alive and guard < 40:
		guard += 1
		var cur: String = run.current_node
		var nexts: Array = MapGraph.node(cur).get("next", [])
		if nexts.is_empty():
			reached_end = (cur == "end")
			break
		var target: String = str(nexts[brng.randi_range(0, nexts.size() - 1)])  # 블라인드 분기
		run.begin_edge(target)
		# 엣지 전진 — 이동 중 상황은 정책으로 결정
		var s: int = 0
		while run.alive and not run.arrived() and s < MAX_STEPS:
			s += 1
			run.step()
			if not run.pending_situation.is_empty():
				_decide(run, run.pending_situation, policy, brng)
		if not run.alive:
			break
		# 단면 탐색은 arrive() 전에 — arrive() 가 _target_node 를 비워 arrival_event(캐시 보충 등)가 사라진다.
		# 실제 게임도 "도착 화면(단면)에서 결정 → 그 뒤 지도 복귀(arrive)" 순서다.
		_explore_section(run, MapGraph.node(target), policy, brng)
		run.arrive()  # 마커를 목표 노드로(가장 멀리 간 지점 반영, 죽었어도)
		if not run.alive:
			break
		if run.current_node == "end":
			reached_end = true
			break

	return {
		"leg": run.leg,
		"row": int(MapGraph.node(run.current_node).get("row", 0)),
		"alive": run.alive,
		"death_cause": run.death_cause,
		"reached_end": reached_end,
	}

## 도착 노드 단면 — 예산 소진까지 지점을 골라 조사(정책).
func _explore_section(run: ExpeditionRun, node: Dictionary, policy: int, brng: RandomNumberGenerator, seen: Dictionary = {}) -> void:
	var section := SectionRun.new(run, node)
	while not section.exhausted() and run.alive:
		var idx: int = _pick_spot(section, policy, brng)
		if idx < 0:
			break
		var res: Dictionary = section.probe(idx)
		if res.is_empty():
			break
		match str(res.get("type", "")):
			"event":
				var ev: Dictionary = res.get("event", {})
				var eid: String = str(ev.get("id", ""))
				if eid != "":
					seen[eid] = int(seen.get(eid, 0)) + 1
				_decide(run, ev, policy, brng)
			"delta":
				run.apply_choice(res.get("effect", {}))
				_set_flags(run, res)

## 조사할 지점 선택 — GREEDY 는 가치 높은 것 우선, 그 외 무작위.
func _pick_spot(section: SectionRun, policy: int, brng: RandomNumberGenerator) -> int:
	var open: Array = []
	for i in range(section.spot_count()):
		if section.can_probe(i):
			open.append(i)
	if open.is_empty():
		return -1
	if policy == Policy.GREEDY:
		var best: int = open[0]
		var best_v: float = _spot_value(section.get_spot(best))
		for i in open:
			var v: float = _spot_value(section.get_spot(i))
			if v > best_v:
				best_v = v
				best = i
		return best
	return open[brng.randi_range(0, open.size() - 1)]

func _spot_value(spot: Dictionary) -> float:
	var res: Dictionary = spot.get("_result", {})
	match str(res.get("type", "")):
		"event":
			# 주요 도착 이벤트(그 노드의 본 사건 — 폭풍·차단·줍기)는 반드시 본다(기존 튜닝 전제).
			if bool(res.get("main", false)):
				return 5.0
			# 보조 이벤트 지점은 최선 선택지의 순자원 값으로 매긴다 — 그리디가 손해·정서 지점을 물 캐시보다
			# 먼저 파는 왜곡을 막는다(실제 플레이어는 라벨 보고 물부터 집는다). 동점 시 살짝 우선(+0.1, 플래그·정보 값).
			var best: float = -1000.0
			for c in res.get("event", {}).get("choices", []):
				best = maxf(best, _score(c.get("effect", {})))
			return best + 0.1
		"delta": return _score(res.get("effect", {}))
		_: return -1.0        # empty 는 나중

# --- 결정(정책) ---

## 이벤트 하나의 선택지를 정책으로 골라 적용한다(효과 + 플래그 + 고갈 판정).
func _decide(run: ExpeditionRun, ev: Dictionary, policy: int, brng: RandomNumberGenerator) -> void:
	var choices: Array = ev.get("choices", [])
	if choices.is_empty():
		run.apply_choice({})
		return
	var opts: Array = []
	for c in choices:
		if Situations.can_choose(c, run.resources):
			opts.append(c)
	if opts.is_empty():
		opts = choices
	var pick: Dictionary = _choose(opts, policy, brng)
	run.apply_choice(pick.get("effect", {}))
	_set_flags(run, pick)

func _choose(opts: Array, policy: int, brng: RandomNumberGenerator) -> Dictionary:
	match policy:
		Policy.GREEDY:
			var best: Dictionary = opts[0]
			var best_v: float = _score(best.get("effect", {}))
			for c in opts:
				var v: float = _score(c.get("effect", {}))
				if v > best_v:
					best_v = v
					best = c
			return best
		Policy.RECKLESS:
			# 장비(needs) 안 쓰는 강행 선택지 우선. 없으면 첫 번째.
			for c in opts:
				if c.get("needs", {}).is_empty():
					return c
			return opts[0]
		_:
			return opts[brng.randi_range(0, opts.size() - 1)]

## 자원 델타 점수 — 생존 자원(물/식량) 무겁게, 장비는 가볍게. GREEDY 가 이걸 최대화.
func _score(effect: Dictionary) -> float:
	return float(int(effect.get("water", 0))) * 1.0 \
		+ float(int(effect.get("food", 0))) * 1.0 \
		+ float(int(effect.get("rope", 0))) * 0.3 \
		+ float(int(effect.get("shelter", 0))) * 0.3

func _set_flags(run: ExpeditionRun, src: Dictionary) -> void:
	for f in src.get("sets", []):
		run.set_flag(str(f))
	for f in src.get("sets_persist", []):
		run.set_flag(str(f))

# --- 콘텐츠 커버리지 ---

func _coverage_report() -> void:
	var seen: Dictionary = {}
	for i in range(RUNS):
		var run := ExpeditionRun.new(BASE_START.duplicate(), [], [], {})
		run.rng.seed = 90000 + i
		var brng := RandomNumberGenerator.new()
		brng.seed = i * 13 + 1
		var guard: int = 0
		while run.alive and guard < 40:
			guard += 1
			var nexts: Array = MapGraph.node(run.current_node).get("next", [])
			if nexts.is_empty():
				break
			var target: String = str(nexts[brng.randi_range(0, nexts.size() - 1)])
			run.begin_edge(target)
			var s: int = 0
			while run.alive and not run.arrived() and s < MAX_STEPS:
				s += 1
				run.step()
				if not run.pending_situation.is_empty():
					_decide(run, run.pending_situation, Policy.GREEDY, brng)
			if not run.alive:
				break
			_explore_section(run, MapGraph.node(target), Policy.GREEDY, brng, seen)
			run.arrive()
			if run.current_node == "end":
				break
	# 모든 노드 이벤트 id 나열 + 등장 횟수
	for nid in MapGraph.NODES:
		for ev in MapGraph.node(nid).get("events", []):
			var eid: String = str(ev.get("id", ""))
			var cnt: int = int(seen.get(eid, 0))
			var mark: String = "  ⚠ 안 뜸" if cnt == 0 else ""
			print("    %-24s %4d%s" % [eid, cnt, mark])
	print("    ─ 0 의 뜻: (a) 재방문 변형(_again/_revisit_/_sheltered 등) — 영속 플래그 필요, 단일 런 시뮬은 못 뜸")
	print("             (b) 그 노드까지 못 감(런이 짧아 도달 전 사망 — 예: f1 storm_gate*)")
	print("             (c) 탐욕 정책이 안 고르는 선택이 켜는 체인(예: 장막 챙김→sand_wall_sheltered)")

# --- util ---

func _avg(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var t: float = 0.0
	for v in arr:
		t += float(v)
	return t / arr.size()

func _policy_name(p: int) -> String:
	match p:
		Policy.GREEDY: return "생존탐욕"
		Policy.RECKLESS: return "무모강행"
		_: return "무작위"
