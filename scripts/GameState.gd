extends Node

## 전역 상태 + 씬 라우팅 + 저장/불러오기 (autoload 이름: GameState).
##
## 코어 루프 (기획서 §3): 지도(계획) → 횡스크롤(실행) → 죽음 → 지도 갱신 → 다음 원정.
## "후대 = 나 자신" 이므로 한 세계의 모든 원정 기록(흔적/죽은 자리)은 한 세이브에 누적된다.
## 1차는 self-async — 내 과거 런의 흔적이 곧 미래의 나에게 남기는 흔적이다.

const SAVE_PATH: String = "user://otherside_save.json"  # 웹에선 브라우저 IndexedDB 에 영속
const SAVE_VERSION: int = 1

const SCENE_TITLE: String = "res://scenes/main.tscn"
const SCENE_MAP: String = "res://scenes/map.tscn"
const SCENE_EXPEDITION: String = "res://scenes/expedition.tscn"

# --- 한 세계에 누적되는 영속 데이터 (원정을 가로질러 살아남음) ---
var expedition_count: int = 0  ## 지금까지 보낸 원정 수
var traces: Array = []         ## 남긴 흔적들 — TraceData.to_dict() 의 배열 (self-async)
var deaths: Array = []         ## 죽은 자리 기록 — 지도 표식용

# --- 현재 원정 한정 상태 (죽으면 리셋) ---
var current_leg: int = 0
var carried: Dictionary = {}   ## 자원 인벤토리 {"water": n, ...}. 자원 = 수명 (남기면 그만큼 잃는다)

func _ready() -> void:
	load_game()

# --- 코어 루프 전이 ---

func go_to_map() -> void:
	get_tree().change_scene_to_file(SCENE_MAP)

## 다음 원정을 떠난다 (지도 → 횡스크롤). 초기 자원은 임시치 — 밸런스는 폰 테스트로 검증 예정.
func start_expedition() -> void:
	current_leg = 0
	carried = {"water": 3, "food": 2, "rope": 1, "shelter": 1}
	expedition_count += 1
	get_tree().change_scene_to_file(SCENE_EXPEDITION)

## 죽기 전 단 한 번 흔적을 남긴다 (기획서 §3). 남김 = 자기 수명 깎기.
func leave_trace(trace: TraceData) -> void:
	traces.append(trace.to_dict())

func record_death(leg: int) -> void:
	deaths.append({"leg": leg, "expedition": expedition_count})

## 복원된 흔적을 TraceData 로 돌려준다 (지도/횡스크롤 렌더링용).
func loaded_traces() -> Array[TraceData]:
	var out: Array[TraceData] = []
	for raw in traces:
		if raw is Dictionary:
			out.append(TraceData.from_dict(raw))
	return out

# --- 저장 / 불러오기 (JSON, 웹 IndexedDB) ---

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"expedition_count": expedition_count,
		"traces": traces,
		"deaths": deaths,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("세이브 열기 실패: %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(data))
	f.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("세이브 파싱 실패 — 무시")
		return
	var data: Dictionary = parsed
	expedition_count = int(data.get("expedition_count", 0))
	traces = data.get("traces", [])
	deaths = data.get("deaths", [])

## 세이브 초기화 (새 세계). 빈 상태로 덮어쓴다 — 웹/데스크톱 모두 안전.
func reset_save() -> void:
	expedition_count = 0
	traces = []
	deaths = []
	current_leg = 0
	carried = {}
	save_game()
