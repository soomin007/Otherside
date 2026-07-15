class_name SectionRun
extends RefCounted

## 도착 노드의 "그림 단면 탐색" 상태·로직 (순수 core — ExpeditionRun 만 참조, GameState/ui 무참조).
## This War of Mine 결: 단면 안 여러 "지점" 중 제한된 조사 횟수(예산)만 조사한다(나머지는 포기).
##
## 지점 두 출처:
##  - 주요 지점(동적): 노드의 도착 카드(로프 무료통과 > 흔적 줍기 > 노드 이벤트 = ExpeditionRun.arrival_event). 있으면 하나.
##  - 보조 지점(정적): node.spots 중 requires 통과분(자원 캐시/작은 이벤트/빈손).
## 조사는 부작용 없이 "결과 디스크립터"를 반환한다. 실제 자원·플래그·흔적 변경은 ui 가 기존 경로(apply_choice/_on_choice/GameState)로 한다.
##
## 필수 위협(mandatory): 주요 지점이 진짜 위협(폭풍/차단, 이미 로프 걸린 무료 통과 제외)이면 반드시 마주해야 떠날 수 있다.
##  기획서 §4 위협 삼각형 — 폭풍=노출 시 사망/유실, 차단=못 지나가 소진. "위협은 원래 치르는 것"이라 스킵 불가.
##  구현: 필수 위협은 예산 한 칸을 미리 차지하되(위협 노드는 보조 탐색 −1 = 기존 정직 플레이와 동일, 밸런스 무변동)
##       예산과 무관하게 항상 조사 가능 → 보조 지점을 먼저 다 파도 위협을 못 여는 소프트락이 없다.
##  ui(Expedition._on_advance)는 has_unresolved_threat() 면 "떠난다"를 막는다. 소모·줍기 주요 지점은 선택(포기 가능).
##
## 두 단계 단면(2026-07-09, 사용자 확정): 주요 지점이 "통과"(필수 위협 폭풍/차단 or 로프 다리 bridged)면
##  그게 게이트(gate_idx)다 — 열기 전엔 보조 지점이 보이지 않는다(먼저 치르고, 넘은 뒤에 둘러본다).
##  게이트 조사는 예산 무료("free"). 다리 통과는 떠나기를 막지 않는다(위협이 아니라 이전 원정대의 보답).
##  줍기가 주요인 노드는 게이트 없음 — 줍기가 위협을 가리는 우선순위는 확정 의도(arrival_event 주석).

const SECTION_PROBES: int = 2   ## 기본 예산(노드가 probes 로 오버라이드)

var node_id: String = ""
var kind: String = ""
var budget: int = 0
var budget_start: int = 0   ## 초기 예산(램프 UI 가 "몇 중 몇 남음"을 그리는 데 씀)
var gate_idx: int = -1      ## 통과 게이트 지점 인덱스(-1=게이트 없음). done 전엔 보조 지점 숨김.
var spots: Array = []   ## 각: {label:String, at:Vector2, done:bool, _result:Dictionary}

## run == null 은 from_dict(이어하기 복원) 전용 — 빈 껍데기를 만들고 저장본으로 채운다.
func _init(run: ExpeditionRun = null, node: Dictionary = {}) -> void:
	if run == null:
		return
	node_id = run.target_node_id()
	kind = str(node.get("kind", ""))
	# 주요 지점 — 도착 카드(이벤트/차단/줍기)가 있으면 하나.
	var main_ev: Dictionary = run.arrival_event()
	if not main_ev.is_empty():
		var main_at: Vector2 = node.get("main_at", _default_main_at(kind))
		if str(main_ev.get("kind", "")) == "straggler":
			# 낙오자는 카드 문구("바람을 피한 그늘에")대로 노드의 그늘 자리에 웅크린다(2026-07-15).
			main_at = node.get("straggler_at", main_at)
		var mand: bool = _is_mandatory_threat(main_ev)
		var bridge: bool = str(main_ev.get("kind", "")) == "bridged"
		spots.append({
			"label": _main_label(main_ev),
			"at": main_at,
			"done": false,
			"mandatory": mand,           # 진짜 위협(폭풍/차단)이면 반드시 마주해야 떠난다
			"free": mand or bridge,      # 통과(위협·다리)는 예산 무료 — 다리 통과가 예산을 낭비하던 함정도 제거
			"_result": {"type": "event", "event": main_ev, "main": true},  # 노드의 본 사건(밸런스 시뮬이 우선순위에 씀)
		})
		if mand or bridge:
			gate_idx = 0  # 두 단계: 통과를 열기 전엔 보조 지점이 안 보인다
	# 보조 지점 — node.spots 중 requires 통과분.
	for sp in node.get("spots", []):
		var spot: Dictionary = sp
		var req: String = str(spot.get("requires", ""))
		if req != "" and not run.has_flag(req):
			continue
		spots.append({
			"label": str(spot.get("label", "살핀다")),
			"at": spot.get("at", Vector2(0.5, 0.5)),
			"done": false,
			"_result": _spot_result(spot),
		})
	# 예산 = 선택형(보조) 지점에만 적용. 필수 위협이 있으면 예산 한 칸을 미리 차지한다 — 위협 노드는
	# 선택 탐색이 한 칸 줄어 기존 정직 플레이와 같은 조사량(멀수록 척박, 밸런스 무변동). 스킵 익스플로잇만 제거.
	# 대신 필수 위협은 예산과 무관하게 항상 마주 가능(can_probe/probe 참조) → 보조를 먼저 다 파도 소프트락 없음.
	var optional_count: int = 0
	var has_mandatory: bool = false
	for s in spots:
		if bool(s.get("mandatory", false)):
			has_mandatory = true
		else:
			optional_count += 1
	var probes: int = int(node.get("probes", SECTION_PROBES))
	if has_mandatory:
		probes -= 1
	budget = mini(maxi(0, probes), optional_count)
	budget_start = budget

# --- 직렬화 (이어하기 저장 — 단면 탐색 도중의 정밀 복원) ---

## 스냅샷(JSON 안전: Vector2 → [x, y]). 지점의 _result(이벤트 카드 포함)까지 통째로 실어,
## 복원 시 _init 을 다시 태우지 않는다 — 도착 카드(rng 추첨)가 다시 뽑히는 것을 막는다(같은 노드, 같은 사건).
func to_dict() -> Dictionary:
	var sp: Array = []
	for s in spots:
		var e: Dictionary = (s as Dictionary).duplicate(true)
		var at: Vector2 = e.get("at", Vector2(0.5, 0.5))
		e["at"] = [at.x, at.y]
		sp.append(e)
	return {
		"node_id": node_id, "kind": kind,
		"budget": budget, "budget_start": budget_start, "gate_idx": gate_idx,
		"spots": sp,
	}

## 스냅샷 복원 — JSON 왕복의 float 를 명시 캐스팅하고 [x, y]를 Vector2 로 되돌린다.
static func from_dict(d: Dictionary) -> SectionRun:
	var sec := SectionRun.new()
	sec.node_id = str(d.get("node_id", ""))
	sec.kind = str(d.get("kind", ""))
	sec.budget = int(d.get("budget", 0))
	sec.budget_start = int(d.get("budget_start", 0))
	sec.gate_idx = int(d.get("gate_idx", -1))
	for e in d.get("spots", []):
		var s: Dictionary = (e as Dictionary).duplicate(true)
		var at: Array = s.get("at", [0.5, 0.5])
		s["at"] = Vector2(float(at[0]), float(at[1]))
		sec.spots.append(s)
	return sec

func spot_count() -> int:
	return spots.size()

func get_spot(i: int) -> Dictionary:
	if i < 0 or i >= spots.size():
		return {}
	var spot: Dictionary = spots[i]
	return spot

func budget_left() -> int:
	return budget

## 두 단계 가시성 — 게이트(통과)가 있으면 열기 전까지 보조 지점이 보이지 않는다.
func is_spot_visible(i: int) -> bool:
	if i < 0 or i >= spots.size():
		return false
	if gate_idx < 0 or i == gate_idx:
		return true
	var gate: Dictionary = spots[gate_idx]
	return bool(gate.get("done", false))

## 게이트(통과)를 이미 열었나 — ui 가 "건너온 자리를 둘러본다" 안내에 쓴다.
func gate_opened() -> bool:
	if gate_idx < 0:
		return false
	var gate: Dictionary = spots[gate_idx]
	return bool(gate.get("done", false))

func can_probe(i: int) -> bool:
	if i < 0 or i >= spots.size():
		return false
	var spot: Dictionary = spots[i]
	if bool(spot.get("done", false)):
		return false
	if not is_spot_visible(i):
		return false  # 게이트 뒤 보조 지점은 통과 전엔 조사 불가(두 단계)
	# 통과(필수 위협·다리)는 예산과 무관하게 항상 조사 가능(마주하기 전엔 떠날 수 없으므로 막히면 안 된다).
	if bool(spot.get("free", false)):
		return true
	return budget > 0

## 지점을 조사한다 — done 표시, (선택형이면) 예산 -1, 결과 디스크립터를 반환한다. (조사 불가면 빈 Dictionary.)
func probe(i: int) -> Dictionary:
	if not can_probe(i):
		return {}
	var spot: Dictionary = spots[i]
	spot["done"] = true
	spots[i] = spot
	if not bool(spot.get("free", false)):
		budget -= 1  # 통과(위협·다리)는 예산을 쓰지 않는다 — 선택형 지점만 예산 차감
	var result: Dictionary = spot.get("_result", {})
	return result

## 아직 마주하지 않은 필수 위협(폭풍/차단)이 있나 — 있으면 ui 가 "떠난다"를 막는다(위협 스킵 방지).
func has_unresolved_threat() -> bool:
	for spot in spots:
		if bool(spot.get("mandatory", false)) and not bool(spot.get("done", false)):
			return true
	return false

## 마주하지 않은 필수 위협의 종류(Threats.Kind int) — ui 안내 문구용. 없으면 -1.
func unresolved_threat_kind() -> int:
	for spot in spots:
		if bool(spot.get("mandatory", false)) and not bool(spot.get("done", false)):
			var ev: Dictionary = spot.get("_result", {}).get("event", {})
			return int(ev.get("threat", -1))
	return -1

## 지금까지 조사한 지점 수 (첫 도착 안내 표시 판단용 — 0이면 아직 아무것도 안 봤다).
func probed_count() -> int:
	var n: int = 0
	for i in range(spots.size()):
		var spot: Dictionary = spots[i]
		if bool(spot.get("done", false)):
			n += 1
	return n

## 더 조사할 게 없다 — 지금 조사 가능한 지점이 하나도 없다.
## can_probe 가 예산·가시성(두 단계)·free(위협/다리) 전부를 알므로 그 합성으로 정의한다:
## 필수 위협이 남았으면 그게 조사 가능이라 false, 게이트 뒤 숨은 보조는 게이트를 열면 드러나며 재평가된다.
func exhausted() -> bool:
	for i in range(spots.size()):
		if can_probe(i):
			return false
	return true

# --- 내부 ---

## 이 주요 지점이 반드시 마주해야 하는 위협인가 — 폭풍/차단만.
## 이미 로프 걸린 무료 통과(bridged)는 위협이 아니라 이전 원정대의 보답이라 제외. 줍기·소모 이벤트도 선택(포기 가능).
func _is_mandatory_threat(ev: Dictionary) -> bool:
	if str(ev.get("kind", "")) == "bridged":
		return false
	var th: int = int(ev.get("threat", Threats.Kind.CONSUMPTION))
	return th == Threats.Kind.STORM or th == Threats.Kind.BLOCKAGE

func _spot_result(spot: Dictionary) -> Dictionary:
	var source: String = str(spot.get("source", "empty"))
	if source == "event":
		return {"type": "event", "event": spot.get("event", {})}
	if source == "cache":
		return {
			"type": "delta",
			"effect": spot.get("effect", {}),
			"text": str(spot.get("text", "")),
			"sets": spot.get("sets", []),
			"sets_persist": spot.get("sets_persist", []),
		}
	return {"type": "empty", "text": str(spot.get("text", "아무것도 없다."))}

## 주요 지점 라벨 — 이벤트 이름이 있으면 그걸, 없으면 일반 문구.
func _main_label(ev: Dictionary) -> String:
	var nm: String = str(ev.get("name", ""))
	return nm if nm != "" else "살펴본다"

## 주요 지점 기본 위치(노드가 main_at 로 오버라이드하지 않을 때).
func _default_main_at(k: String) -> Vector2:
	match k:
		"blockage": return Vector2(0.5, 0.5)
		"storm": return Vector2(0.5, 0.42)
		_: return Vector2(0.5, 0.55)
