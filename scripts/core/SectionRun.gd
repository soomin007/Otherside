class_name SectionRun
extends RefCounted

## 도착 노드의 "그림 단면 탐색" 상태·로직 (순수 core — ExpeditionRun 만 참조, GameState/ui 무참조).
## This War of Mine 결: 단면 안 여러 "지점" 중 제한된 조사 횟수(예산)만 조사한다(나머지는 포기).
##
## 지점 두 출처:
##  - 주요 지점(동적): 노드의 도착 카드(로프 무료통과 > 흔적 줍기 > 노드 이벤트 = ExpeditionRun.arrival_event). 있으면 하나.
##  - 보조 지점(정적): node.spots 중 requires 통과분(자원 캐시/작은 이벤트/빈손).
## 조사는 부작용 없이 "결과 디스크립터"를 반환한다. 실제 자원·플래그·흔적 변경은 ui 가 기존 경로(apply_choice/_on_choice/GameState)로 한다.

const SECTION_PROBES: int = 2   ## 기본 예산(노드가 probes 로 오버라이드)

var node_id: String = ""
var kind: String = ""
var budget: int = 0
var spots: Array = []   ## 각: {label:String, at:Vector2, done:bool, _result:Dictionary}

func _init(run: ExpeditionRun, node: Dictionary) -> void:
	node_id = run.target_node_id()
	kind = str(node.get("kind", ""))
	# 주요 지점 — 도착 카드(이벤트/차단/줍기)가 있으면 하나.
	var main_ev: Dictionary = run.arrival_event()
	if not main_ev.is_empty():
		var main_at: Vector2 = node.get("main_at", _default_main_at(kind))
		spots.append({
			"label": _main_label(main_ev),
			"at": main_at,
			"done": false,
			"_result": {"type": "event", "event": main_ev},
		})
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
	budget = mini(int(node.get("probes", SECTION_PROBES)), spots.size())

func spot_count() -> int:
	return spots.size()

func get_spot(i: int) -> Dictionary:
	if i < 0 or i >= spots.size():
		return {}
	var spot: Dictionary = spots[i]
	return spot

func budget_left() -> int:
	return budget

func can_probe(i: int) -> bool:
	if i < 0 or i >= spots.size() or budget <= 0:
		return false
	var spot: Dictionary = spots[i]
	return not bool(spot.get("done", false))

## 지점을 조사한다 — done 표시, 예산 -1, 결과 디스크립터를 반환한다. (조사 불가면 빈 Dictionary.)
func probe(i: int) -> Dictionary:
	if not can_probe(i):
		return {}
	var spot: Dictionary = spots[i]
	spot["done"] = true
	spots[i] = spot
	budget -= 1
	var result: Dictionary = spot.get("_result", {})
	return result

## 지금까지 조사한 지점 수 (첫 도착 안내 표시 판단용 — 0이면 아직 아무것도 안 봤다).
func probed_count() -> int:
	var n: int = 0
	for i in range(spots.size()):
		var spot: Dictionary = spots[i]
		if bool(spot.get("done", false)):
			n += 1
	return n

## 더 조사할 게 없다 — 예산 소진이거나 모든 지점을 봤다.
func exhausted() -> bool:
	if budget <= 0:
		return true
	for i in range(spots.size()):
		var spot: Dictionary = spots[i]
		if not bool(spot.get("done", false)):
			return false
	return true

# --- 내부 ---

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
