class_name ExpeditionNamer
extends RefCounted

## 원정대 이름 — 조합형 서술(수식어 + 명사). 세계관(사막·갈증·모래) 밀착.
## 기본은 랜덤(Loadout 에서 표시·다시 뽑기), 플레이어가 직접 입력할 수도 있다.
## 순수 core — 노드·GameState 미참조. rng 를 주입받아 결정론적·테스트 가능(-s 검증).

const MODS: Array = [
	"붉은", "마른", "잿빛", "메마른", "부서진", "조용한",
	"먼", "굶주린", "늦은", "이름 없는", "마지막", "홀로 선",
]
const NOUNS: Array = [
	"모래", "강", "새벽", "바람", "그림자", "뼈", "발자국",
	"지평선", "우물", "등불", "나침반", "약속", "대오", "아이들",
]

## 랜덤 원정대 이름 하나. rng 는 호출부가 소유(결정론·테스트 가능).
static func random(rng: RandomNumberGenerator) -> String:
	match rng.randi_range(0, 2):
		0:
			return "%s %s 원정대" % [_pick(MODS, rng), _pick(NOUNS, rng)]
		1:
			# "{명사}의 {명사2}" — 두 명사는 되도록 다르게.
			var a: String = _pick(NOUNS, rng)
			var b: String = _pick(NOUNS, rng)
			var guard: int = 0
			while b == a and guard < 8:
				b = _pick(NOUNS, rng)
				guard += 1
			return "%s의 %s" % [a, b]
		_:
			return "%s %s" % [_pick(MODS, rng), _pick(NOUNS, rng)]

static func _pick(pool: Array, rng: RandomNumberGenerator) -> String:
	return str(pool[rng.randi_range(0, pool.size() - 1)])
