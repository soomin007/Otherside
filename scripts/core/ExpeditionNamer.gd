class_name ExpeditionNamer
extends RefCounted

## 원정대 이름 — 조합형 서술(수식어 + 명사). 세계관(사막·갈증·모래) 밀착.
## 기본은 랜덤(Loadout 에서 표시·다시 뽑기), 플레이어가 직접 입력할 수도 있다.
## 순수 core — 노드·GameState 미참조. rng 를 주입받아 결정론적·테스트 가능(-s 검증).

## 풀 확장(2026-07-13): 수식어 12→24 · 명사 14→28. 명사에 게임 속 사물(돌탑·깃발·두레박·샘·물길·천막)을
## 섞었다 — 원정대 이름이 길에서 만나는 것들과 공명한다. 전부 관형형/명사라 어느 조합도 어법이 성립.
const MODS: Array = [
	"붉은", "마른", "잿빛", "메마른", "부서진", "조용한",
	"먼", "굶주린", "늦은", "이름 없는", "마지막", "홀로 선",
	"목마른", "빛바랜", "떠도는", "지워진", "남겨진", "길 잃은",
	"동트는", "저무는", "숨죽인", "낡은", "먼지 쓴", "바람 탄",
]
const NOUNS: Array = [
	"모래", "강", "새벽", "바람", "그림자", "뼈", "발자국",
	"지평선", "우물", "등불", "나침반", "약속", "대오", "아이들",
	"폭풍", "샘", "물길", "돌탑", "깃발", "두레박", "천막",
	"모닥불", "이정표", "메아리", "먼동", "밤길", "별", "맹세",
]

## 랜덤 원정대 이름 하나. rng 는 호출부가 소유(결정론·테스트 가능).
## 옛 "{명사}의 {명사}" 꼴은 "{수식어} {명사}의 {명사}"로 교체(2026-07-13 사용자 —
## "~한 ~의 ~"는 좋고, 관형어만 겹치는 꼴은 별로). 어떤 패턴도 "~의 ~의"를 만들지 않는다.
static func random(rng: RandomNumberGenerator) -> String:
	if L10N.is_en():
		return _random_en(rng)
	match rng.randi_range(0, 2):
		0:
			return "%s %s 원정대" % [_pick(MODS, rng), _pick(NOUNS, rng)]
		1:
			# "{수식어} {명사}의 {명사2}" — 두 명사는 되도록 다르게.
			var a: String = _pick(NOUNS, rng)
			var b: String = _pick(NOUNS, rng)
			var guard: int = 0
			while b == a and guard < 8:
				b = _pick(NOUNS, rng)
				guard += 1
			return "%s %s의 %s" % [_pick(MODS, rng), a, b]
		_:
			return "%s %s" % [_pick(MODS, rng), _pick(NOUNS, rng)]

## 영어 이름 — 한국어 어순("A의 B")을 그대로 옮길 수 없어 패턴별로 영문 어순을 다시 짠다(2026-07-26).
## 조각 번역은 L10N 표(한국어 조각 → 영어 소문자), 이름이므로 단어 첫 글자를 올린다.
## 이름은 생성 시점 언어로 저장된다 — 언어를 바꿔도 이미 지어진 이름은 그대로(고유명사 취급).
static func _random_en(rng: RandomNumberGenerator) -> String:
	match rng.randi_range(0, 2):
		0:
			return "The %s %s Expedition" % [_en(_pick(MODS, rng)), _en(_pick(NOUNS, rng))]
		1:
			var a: String = _pick(NOUNS, rng)
			var b: String = _pick(NOUNS, rng)
			var guard: int = 0
			while b == a and guard < 8:
				b = _pick(NOUNS, rng)
				guard += 1
			return "%s of the %s %s" % [_en(b), _en(_pick(MODS, rng)), _en(a)]
		_:
			return "The %s %s" % [_en(_pick(MODS, rng)), _en(_pick(NOUNS, rng))]

static func _en(w: String) -> String:
	return L10N.t(w).capitalize()

static func _pick(pool: Array, rng: RandomNumberGenerator) -> String:
	return str(pool[rng.randi_range(0, pool.size() - 1)])
