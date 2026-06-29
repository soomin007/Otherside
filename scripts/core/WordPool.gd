class_name WordPool
extends RefCounted

## 흔적 태그용 제약 단어 풀 — 기획서 §3 "태그 = 제약 단어 풀".
## 원칙: 유한·빈약·조합형. 물건이 의미의 절반을 말하므로 태그는 짧게 한두 개만 얹는다.
## 단일 진실: docs/design/wordpool_v0.1.md (v0.1, 총 27단어).
## 확장은 사후 — 빌드 후 폰 테스트에서 "하고 싶은 말인데 단어가 없네" 할 때 그 단어만 추가한다.

const DIRECTION: Array = ["앞", "뒤", "위", "아래", "여기", "건너", "돌아가", "못", "가"]
const WARNING: Array = ["조심", "위험", "갈증", "추위", "폭풍", "함정", "없다", "끝", "안전"]
const TIME: Array = ["곧", "멀다", "늦다", "아직", "다시", "마지막"]
const GREETING: Array = ["또", "봐", "간다", "미안", "고맙다"]

## `못`은 독립 부정 연산자 — 다른 단어에 붙어 의미를 뒤집는다 (못+가, 못+건너, 못+믿다 등).
const NEGATION: String = "못"

## 전체 단어 (카테고리 합). const 배열 연결은 피하고 런타임에 합친다.
static func all() -> Array:
	var out: Array = []
	out.append_array(DIRECTION)
	out.append_array(WARNING)
	out.append_array(TIME)
	out.append_array(GREETING)
	return out

static func is_valid(word: String) -> bool:
	return all().has(word)
