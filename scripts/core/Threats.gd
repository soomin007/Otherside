class_name Threats
extends RefCounted

## 위협 삼각형 — 기획서 §4.
## 셋은 각자 다른 근육을 쓰고, 한정된 "남김 한 번"을 두고 서로 경쟁한다.
## 이 파일은 기획서 표를 코드로 옮긴 읽기 전용 데이터다.
## 단일 진실: docs/design/SYOTOS_기획서_v0.1.md §4. 표가 바뀌면 여기도 같이 바꾼다.

enum Kind {
	CONSUMPTION, ## 소모(갈증) — 시간 압박. 물통/식량으로 막음. 천천히 고갈.
	BLOCKAGE,    ## 차단(틈/벽) — 공간 차단. 로프/사다리 고정으로 막음. 못 지나가 그 자리서 소진.
	STORM,       ## 폭풍 — 위치 강제. 은신처로 막음. 폭풍 중 노출 시 사망/유실. (세계 법칙 = 위협)
}

## 위협별 메타데이터. 키 = Kind(int). 값 = Dictionary.
##   muscle: 쓰는 근육 / counters: 막는 물건(TraceData.ObjectKind 대응) / death: 죽는 방식
const INFO: Dictionary = {
	Kind.CONSUMPTION: {
		"id": "consumption",
		"label": "소모",
		"muscle": "시간 압박",
		"counters": ["water", "food"],
		"death": "천천히 고갈",
	},
	Kind.BLOCKAGE: {
		"id": "blockage",
		"label": "차단",
		"muscle": "공간 차단",
		"counters": ["rope"],
		"death": "못 지나가 그 자리서 소진",
	},
	Kind.STORM: {
		"id": "storm",
		"label": "폭풍",
		"muscle": "위치/타이밍",
		"counters": ["shelter"],
		"death": "폭풍 중 노출 시 사망/유실",
	},
}

static func info(kind: Kind) -> Dictionary:
	return INFO.get(kind, {})

static func all_kinds() -> Array:
	return INFO.keys()
