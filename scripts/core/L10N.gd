class_name L10N
extends RefCounted

## 로컬라이제이션 게이트웨이 (2026-07-26) — 게임의 모든 원문은 한국어(코드·데이터 그대로)이고,
## 영어는 표시 순간에만 이 게이트를 지나며 치환된다. 세이브·플래그·태그 등 내부 데이터는 항상 한국어 —
## 언어를 바꿔도 세이브 호환이 깨지지 않는다.
##
## 배선: UITheme.make_label / make_pill / EngravedItem / Bookmark 헬퍼가 t() 를 지나므로
## 대부분의 문구는 호출부 수정 없이 번역된다. 직접 그리기(draw_string)·직접 .text 대입만 t() 로 감싼다.
## 표에 없는 문자열은 원문 그대로 반환(안전 폴백) — 영어 화면에 한국어가 보이면 표 누락 신호다.

static var locale: String = "ko"  ## "ko" | "en"

static func t(s: String) -> String:
	if locale != "en" or s.is_empty():
		return s
	return LangEN.TABLE.get(s, s)

static func is_en() -> bool:
	return locale == "en"
