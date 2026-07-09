class_name TraceData
extends RefCounted

## 흔적 — 죽기 전 단 한 번 남기는 물건 + 태그. 기획서 §3 "흔적 시스템(이 게임의 심장)".
## 1차 언어는 글이 아니라 물건. 태그는 단어 풀(WordPool)에서 골라 얹는 짧은 표식.
## 저장은 JSON 직렬화(웹 user:// = IndexedDB) — to_dict / from_dict 로 평범한 Dictionary와 오간다.
##
## object_kind 는 enum ObjectKind 의 값이지만 변수 타입은 int 로 둔다
## (Dictionary/JSON 왕복 시 enum 타입 대입 마찰을 피하기 위함).

## 새 종류는 반드시 뒤에 추가한다 — enum 값이 곧 세이브에 저장되는 정수라(직렬화), 순서가 바뀌면 기존 세이브가 깨진다.
enum ObjectKind {
	WATER,    ## 물통 — 소모(갈증) 대비
	FOOD,     ## 식량 — 소모(갈증) 대비
	ROPE,     ## 로프/사다리 — 차단 대비 (영구 지형 변화, 가장 뿌듯한 흔적)
	SHELTER,  ## 장막 — 폭풍 대비
	BODY,     ## 시체 자리 — 이전 원정대가 끝난 곳 (정보 0, 정서 100)
	MARK,     ## 빈 표식 — 물건 없이 태그만
	MEDICINE, ## 약초 — 열·탈진 대비 (주머니 도구). 남기고/줍기 가능.
	FLINT,    ## 부싯돌 — 언 밤의 불 (주머니 도구).
	FILTER,   ## 정화천 — 탁한 물 거름 (주머니 도구).
}

const PICKUP_USES: int = 3   ## 줍기형 흔적의 기본 사용 횟수 (다음 원정들이 나눠 쓰다 소진)

var object_kind: int = ObjectKind.MARK
var node_id: String = ""     ## 어느 노드에 남겼나 (지도 그래프의 공간 키 — 흔적 줍기·차단 영구화·죽음 표식이 이걸로 노드에 붙는다). 이동 중이면 떠나온 노드.
var to_node: String = ""     ## 이동 중 남겼으면 향하던 노드(엣지 node_id→to_node 위에 찍는다). "" = 노드에서 남김(node_id 그 자리).
var leg: int = 0             ## 몇 걸음째에 남겼나 (거리 — 표시·정렬용. 분기 맵에선 node_id 가 위치의 진실)
var position: float = 0.0    ## 엣지 위 진행률 (0.0~1.0) — to_node 가 있을 때 그 엣지의 어디쯤인지. 노드 남김은 0.
var tags: Array[String] = [] ## WordPool 에서 고른 태그들 (한두 개)
var uses: int = 0            ## 줍기 가능 횟수 (자원 흔적만, 0=줍기 대상 아님). 집을 때마다 1씩 소진.

func _init(p_kind: int = ObjectKind.MARK, p_leg: int = 0, p_tags: Array[String] = [], p_uses: int = 0) -> void:
	object_kind = p_kind
	leg = p_leg
	uses = p_uses
	tags.clear()
	for w in p_tags:
		tags.append(str(w))

func to_dict() -> Dictionary:
	return {
		"object_kind": object_kind,
		"node_id": node_id,
		"to_node": to_node,
		"leg": leg,
		"position": position,
		"tags": tags.duplicate(),
		"uses": uses,
	}

## 흔적 종류 → resources 키 (남기기·줍기 공용). ROPE 는 다리(bridged_nodes)로 따로 다루되 남기기 키는 있다. BODY/MARK 는 "".
static func kind_to_key(kind: int) -> String:
	match kind:
		ObjectKind.WATER: return "water"
		ObjectKind.FOOD: return "food"
		ObjectKind.ROPE: return "rope"
		ObjectKind.SHELTER: return "shelter"
		ObjectKind.MEDICINE: return "medicine"
		ObjectKind.FLINT: return "flint"
		ObjectKind.FILTER: return "filter"
		_: return ""

## 다음 원정대가 집어 쓸 수 있는 흔적인가 — 자원(물/식량/장막) + 주머니 도구(약초/부싯돌/정화천).
## ROPE 는 줍는 게 아니라 영구 다리로 남으니 제외. BODY/MARK 도 제외.
static func is_pickable(kind: int) -> bool:
	match kind:
		ObjectKind.WATER, ObjectKind.FOOD, ObjectKind.SHELTER, ObjectKind.MEDICINE, ObjectKind.FLINT, ObjectKind.FILTER:
			return true
		_:
			return false

## Dictionary(또는 JSON 파싱 결과)에서 흔적을 복원한다.
static func from_dict(d: Dictionary) -> TraceData:
	var t := TraceData.new()
	t.object_kind = int(d.get("object_kind", ObjectKind.MARK))
	t.node_id = str(d.get("node_id", ""))
	t.to_node = str(d.get("to_node", ""))
	t.leg = int(d.get("leg", 0))
	t.position = float(d.get("position", 0.0))
	t.uses = int(d.get("uses", 0))
	# Dictionary 에서 꺼낸 Array 는 untyped — Array[String] 에 직접 대입 금지 (전역 규칙 #4).
	t.tags.clear()
	for w in d.get("tags", []):
		t.tags.append(str(w))
	return t
