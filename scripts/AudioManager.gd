extends Node

## 오디오 매니저 (autoload: AudioManager) — BGM 베드 + 효과음(SFX).
## BGM: 잔잔 베드를 코어 루프 내내 끊김 없이 재생(씬 전환에도 유지, 같은 곡이면 restart 안 함).
##      곡 바꿈은 크로스페이드(폭풍·엔딩). 볼륨은 Master 버스(AppSettings 관리).
## SFX: 짧은 one-shot(겹침 허용). 발소리는 4변주 랜덤 회전(반복 티 방지).
## 웹 안전: AudioStreamPlayer + mp3/ogg/wav, 파일 없으면 조용히 무음.

# --- BGM 트랙 ---
const BED: String = "res://assets/bgm/Sand Erases the Words.mp3"      ## 코어 루프 잔잔 베드
const REUNION: String = "res://assets/bgm/Other Side.mp3"             ## 재회 엔딩 크레딧
const STORM: String = "res://assets/bgm/storm.ogg"                    ## 폭풍(뽑히면 이 이름으로)

const FADE: float = 1.5   ## 크로스페이드 길이(초)
const QUIET_DB: float = -40.0

# --- SFX ---
const SFX_VOICES: int = 6   ## 겹쳐 날 수 있는 최대 동시 효과음
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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_a = _make_player()
	_b = _make_player()
	_cur = _a
	for i in SFX_VOICES:
		_sfx.append(_make_player())
	play_track(BED)   # 시작부터 베드

func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	add_child(p)
	return p

# --- BGM ---

## 트랙을 크로스페이드로 튼다. **같은 곡 재생 중이면 무시**(씬 전환에 restart 안 함 = 연속).
## 파일이 없으면 조용히 무시(에셋 아직 없을 때 안전).
func play_track(path: String, fade: float = FADE) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	if _cur.playing and _cur.stream != null and _cur.stream.resource_path == path:
		return  # 이미 이 곡 — 그대로 둔다
	var s: Resource = load(path)
	if s is AudioStreamMP3 or s is AudioStreamOggVorbis:
		s.loop = true   # 게임 BGM 은 무한 루프
	var old: AudioStreamPlayer = _cur
	var nxt: AudioStreamPlayer = _b if _cur == _a else _a
	nxt.stream = s
	nxt.volume_db = QUIET_DB
	nxt.play()
	_cur = nxt
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(nxt, "volume_db", 0.0, fade)
	if old.playing:
		t.tween_property(old, "volume_db", QUIET_DB, fade)
	t.chain().tween_callback(old.stop)   # 페이드 끝나면 옛 플레이어 정지(무음이면 무해)

## 코어 루프 베드로 (돌아)간다. 이미 베드면 아무 것도 안 함(연속 유지).
func play_bed() -> void:
	play_track(BED)

## 폭풍 구간 진입 — 위기곡으로 교체(에셋 없으면 무음, 베드 유지).
func play_storm() -> void:
	play_track(STORM)

## 재회 엔딩 크레딧곡.
func play_reunion() -> void:
	play_track(REUNION)

## 전부 서서히 끄기(암전·순환 엔딩 여운 등).
func fade_out(fade: float = FADE) -> void:
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

## 종료 시 정리 — 재생 중 스트림 참조를 놓아 "리소스 사용 중" 누수 경고를 막는다.
func _exit_tree() -> void:
	for p in ([_a, _b] + _sfx):
		if p != null:
			p.stop()
			p.stream = null
