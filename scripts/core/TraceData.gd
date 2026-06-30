class_name TraceData
extends RefCounted

## 흔적 — 죽기 전 단 한 번 남기는 물건 + 태그. 기획서 §3 "흔적 시스템(이 게임의 심장)".
## 1차 언어는 글이 아니라 물건. 태그는 단어 풀(WordPool)에서 골라 얹는 짧은 표식.
## 저장은 JSON 직렬화(웹 user:// = IndexedDB) — to_dict / from_dict 로 평범한 Dictionary와 오간다.
##
## object_kind 는 enum ObjectKind 의 값이지만 변수 타입은 int 로 둔다
## (Dictionary/JSON 왕복 시 enum 타입 대입 마찰을 피하기 위함).

enum ObjectKind {
	WATER,    ## 물통 — 소모(갈증) 대비
	FOOD,     ## 식량 — 소모(갈증) 대비
	ROPE,     ## 로프/사다리 — 차단 대비 (영구 지형 변화, 가장 뿌듯한 흔적)
	SHELTER,  ## 은신처 — 폭풍 대비
	BODY,     ## 시체 자리 — 이전 원정대가 끝난 곳 (정보 0, 정서 100)
	MARK,     ## 빈 표식 — 물건 없이 태그만
}

const PICKUP_USES: int = 3   ## 줍기형 흔적의 기본 사용 횟수 (다음 원정들이 나눠 쓰다 소진)

var object_kind: int = ObjectKind.MARK
var leg: int = 0              ## 몇 구간째에 남겼나 (횡스크롤 전진 거리)
var position: float = 0.0    ## 구간 내 위치 (0.0~1.0, 추후 정의)
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
		"leg": leg,
		"position": position,
		"tags": tags.duplicate(),
		"uses": uses,
	}

## Dictionary(또는 JSON 파싱 결과)에서 흔적을 복원한다.
static func from_dict(d: Dictionary) -> TraceData:
	var t := TraceData.new()
	t.object_kind = int(d.get("object_kind", ObjectKind.MARK))
	t.leg = int(d.get("leg", 0))
	t.position = float(d.get("position", 0.0))
	t.uses = int(d.get("uses", 0))
	# Dictionary 에서 꺼낸 Array 는 untyped — Array[String] 에 직접 대입 금지 (전역 규칙 #4).
	t.tags.clear()
	for w in d.get("tags", []):
		t.tags.append(str(w))
	return t
