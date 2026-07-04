extends Node

## 오디오 매니저 (autoload: AudioManager) — BGM 베드 + 효과음(SFX).
## BGM: 잔잔 베드를 코어 루프 내내 재생. **끝을 다음 시작에 겹쳐 크로스페이드**해 이음매 없이 무한 루프
##      (파일 loop 대신 수동 크로스페이드 — 클릭·틈 없음). 곡 바꿈도 크로스페이드(폭풍·엔딩).
## SFX: 짧은 one-shot(겹침 허용). 발소리는 4변주 랜덤 회전(반복 티 방지).
## 볼륨은 Master 버스(AppSettings 관리). 웹 안전: AudioStreamPlayer + mp3/ogg/wav, 파일 없으면 무음.

# --- BGM 트랙 ---
const BED: String = "res://assets/bgm/Sand Erases the Words.mp3"      ## 코어 루프 잔잔 베드
const REUNION: String = "res://assets/bgm/Other Side.mp3"             ## 재회 엔딩 크레딧(한 번만)
const STORM: String = "res://assets/bgm/storm.ogg"                    ## 폭풍(뽑히면 이 이름으로)

const FADE: float = 1.5        ## 트랙 교체 크로스페이드(초)
const LOOP_XFADE: float = 4.0  ## 루프 이음매 크로스페이드(초) — 끝을 다음 시작에 겹친다
const QUIET_DB: float = -40.0

# --- SFX ---
const SFX_VOICES: int = 6   ## 동시에 겹칠 수 있는 최대 효과음
## 발소리 4변주(이동 중 랜덤 회전 — 반복 티 방지). 그 외 SFX 는 assets/sfx/ 참고.
const STEP_SET: Array = [
	"res://assets/sfx/sfx_step_1.wav", "res://assets/sfx/sfx_step_2.wav",
	"res://assets/sfx/sfx_step_3.wav", "res://assets/sfx/sfx_step_4.wav",
]

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _cur: AudioStreamPlayer   ## 지금 우세 BGM 플레이어
var _sfx: Array = []          ## SFX 보이스 풀
var _rng := RandomNumberGenerator.new()
var _loop_path: String = ""   ## 루프 대상 트랙(베드·폭풍). "" = 원샷(엔딩 크레딧)
var _xfading: bool = false    ## 루프 크로스페이드 진행 중

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_a = _make_player()
	_b = _make_player()
	_cur = _a
	for i in SFX_VOICES:
		_sfx.append(_make_player())
	play_track(BED)   # 시작부터 베드(페이드 인)

func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	add_child(p)
	return p

## 루프 트랙이 끝에 다다르면 미리 다음 회차를 겹쳐 재생(끊김 없는 이음매).
func _process(_dt: float) -> void:
	if _loop_path == "" or _xfading or _cur == null or not _cur.playing or _cur.stream == null:
		return
	var length: float = _cur.stream.get_length()
	if length > 0.0 and _cur.get_playback_position() >= length - LOOP_XFADE:
		_loop_crossfade()

# --- BGM ---

## 트랙을 크로스페이드로 튼다. **같은 곡 재생 중이면 무시**(씬 전환에 restart 안 함 = 연속).
## loop=true(기본): 끝에서 스스로 크로스페이드 루프. loop=false: 한 번만(엔딩 크레딧). 파일 없으면 무시.
func play_track(path: String, fade: float = FADE, loop: bool = true) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	if _cur.playing and _cur.stream != null and _cur.stream.resource_path == path:
		return  # 이미 이 곡 — 그대로 둔다
	var s: Resource = load(path)
	if s is AudioStreamMP3 or s is AudioStreamOggVorbis:
		s.loop = false   # 파일 loop 대신 수동 크로스페이드 루프(이음매 없음)
	_loop_path = path if loop else ""
	_xfading = false
	_crossfade(s, 0.0, fade)

## 스트림을 다른 플레이어에서 from_pos 부터 시작해 현재와 크로스페이드한다.
func _crossfade(s: Resource, from_pos: float, fade: float) -> void:
	var old: AudioStreamPlayer = _cur
	var nxt: AudioStreamPlayer = _b if _cur == _a else _a
	nxt.stream = s
	nxt.volume_db = QUIET_DB
	nxt.play(from_pos)
	_cur = nxt
	var t := create_tween().set_parallel(true)
	t.tween_property(nxt, "volume_db", 0.0, fade)
	if old.playing:
		t.tween_property(old, "volume_db", QUIET_DB, fade)
	t.chain().tween_callback(old.stop)

## 루프 이음매 — 같은 곡을 0부터 겹쳐 재생하고 크로스페이드(끝 페이드아웃 ↔ 시작 페이드인).
func _loop_crossfade() -> void:
	_xfading = true
	var old: AudioStreamPlayer = _cur
	var nxt: AudioStreamPlayer = _b if _cur == _a else _a
	nxt.stream = old.stream
	nxt.volume_db = QUIET_DB
	nxt.play(0.0)
	_cur = nxt
	var t := create_tween().set_parallel(true)
	t.tween_property(nxt, "volume_db", 0.0, LOOP_XFADE)
	t.tween_property(old, "volume_db", QUIET_DB, LOOP_XFADE)
	t.chain().tween_callback(_after_loop_xfade.bind(old))

func _after_loop_xfade(old: AudioStreamPlayer) -> void:
	old.stop()
	_xfading = false

## 코어 루프 베드로 (돌아)간다. 이미 베드면 아무 것도 안 함(연속 유지).
func play_bed() -> void:
	play_track(BED)

## 폭풍 구간 진입 — 위기곡으로 교체(에셋 없으면 무음, 베드 유지).
func play_storm() -> void:
	play_track(STORM)

## 재회 엔딩 크레딧곡 — 한 번만(루프 안 함).
func play_reunion() -> void:
	play_track(REUNION, FADE, false)

## 전부 서서히 끄기(암전·순환 엔딩 여운 등).
func fade_out(fade: float = FADE) -> void:
	_loop_path = ""
	for p in [_a, _b]:
		if p != null and p.playing:
			var t := create_tween()
			t.tween_property(p, "volume_db", QUIET_DB, fade)
			t.tween_callback(p.stop)

# --- SFX ---

## 짧은 효과음 one-shot(겹침 허용). 파일 없으면 무시.
func play_sfx(path: String, vol_db: float = 0.0) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	var voice: AudioStreamPlayer = _sfx[0]
	for p in _sfx:
		if not p.playing:
			voice = p
			break
	voice.stream = load(path)
	voice.volume_db = vol_db
	voice.play()

## 여러 후보 중 하나를 랜덤 재생(발소리 등 변주 — 반복 티 방지).
func play_sfx_random(paths: Array, vol_db: float = 0.0) -> void:
	if paths.is_empty():
		return
	play_sfx(str(paths[_rng.randi_range(0, paths.size() - 1)]), vol_db)

## 발소리 한 걸음(4변주 랜덤). 이동(step)마다 호출.
func play_step() -> void:
	play_sfx_random(STEP_SET)

## 종료 시 정리 — 재생 중 스트림 참조를 놓아 "리소스 사용 중" 누수 경고를 줄인다.
func _exit_tree() -> void:
	for p in ([_a, _b] + _sfx):
		if p != null:
			p.stop()
			p.stream = null
