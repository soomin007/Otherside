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
var flags: Array = []  ## 영속 플래그(self-async). choice 의 sets_persist 가 쌓여 다음 원정 변형 이벤트를 깬다.

# --- 현재 원정 한정 상태 (죽으면 리셋) ---
## 초기 자원 — 임시치. 자원 = 수명 (남기면 그만큼 잃는다). 밸런스는 폰 테스트로 검증 예정.
const START_RESOURCES: Dictionary = {"water": 20, "food": 13, "rope": 1, "shelter": 1}
var current_run: ExpeditionRun = null  ## 진행 중인 원정의 순수 상태·로직 (core/ExpeditionRun)

func _ready() -> void:
	load_game()

# --- 코어 루프 전이 ---

func go_to_map() -> void:
	get_tree().change_scene_to_file(SCENE_MAP)

## 씬 전환 없이 현재 원정만 새로 만든다 (직접 진입 안전장치 / 테스트용).
## 과거에 로프를 건 차단(bridged_legs)을 주입해, 그 틈을 무료로 건너게 한다(영구 지형 변화).
func begin_run_in_place() -> void:
	current_run = ExpeditionRun.new(START_RESOURCES, bridged_legs(), flags)
	expedition_count += 1

## 다음 원정을 떠난다 (지도 → 횡스크롤). 새 ExpeditionRun 을 만들고 씬을 바꾼다.
func start_expedition() -> void:
	begin_run_in_place()
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

## 과거에 로프를 고정한 차단 지점들(ROPE 흔적의 leg). 다음 원정에서 그 틈을 무료로 건넌다.
## 차단 = "영구 지형 변화"(기획서 §4)의 영속 표현. ExpeditionRun 에 주입된다.
func bridged_legs() -> Array:
	var out: Array = []
	for raw in traces:
		if raw is Dictionary and int(raw.get("object_kind", -1)) == TraceData.ObjectKind.ROPE:
			out.append(int(raw.get("leg", 0)))
	return out

## 영속 플래그를 켠다(다음 원정의 변형 이벤트용). 선택의 sets_persist 가 여기로 쌓인다(중복 제외).
func add_persist_flags(new_flags: Array) -> void:
	var changed: bool = false
	for f in new_flags:
		var s: String = str(f)
		if not flags.has(s):
			flags.append(s)
			changed = true
	if changed:
		save_game()

# --- 저장 / 불러오기 (JSON, 웹 IndexedDB) ---

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"expedition_count": expedition_count,
		"traces": traces,
		"deaths": deaths,
		"flags": flags,
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
	flags = data.get("flags", [])

## 세이브 초기화 (새 세계). 빈 상태로 덮어쓴다 — 웹/데스크톱 모두 안전.
func reset_save() -> void:
	expedition_count = 0
	traces = []
	deaths = []
	flags = []
	current_run = null
	save_game()
