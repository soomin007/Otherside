extends Node

## BGM 매니저 (autoload: AudioManager) — 잔잔 베드를 코어 루프 내내 끊김 없이 재생.
## 씬 전환에도 유지(autoload) + 같은 곡이면 restart 안 함(연속). 곡 바꿈은 크로스페이드(폭풍·엔딩).
## 볼륨은 Master 버스(AppSettings 가 관리). 웹 안전: AudioStreamPlayer + mp3/ogg, 파일 없으면 조용히 무음.
##
## 3트랙(기획 audio_list): 잔잔 베드 / 폭풍(위기) / 엔딩(재회=Other Side). 폭풍·엔딩 훅은 아래 헬퍼로 준비.

const BED: String = "res://assets/bgm/Sand Erases the Words.mp3"      ## 코어 루프 잔잔 베드
const REUNION: String = "res://assets/bgm/Other Side.mp3"             ## 재회 엔딩 크레딧
const STORM: String = "res://assets/bgm/storm.ogg"                    ## 폭풍(뽑히면 이 이름으로)

const FADE: float = 1.5   ## 크로스페이드 길이(초)
const QUIET_DB: float = -40.0

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _cur: AudioStreamPlayer   ## 지금 우세 플레이어

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = _make_player()
	_b = _make_player()
	_cur = _a
	play_track(BED)   # 시작부터 베드

func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	add_child(p)
	return p

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

# --- 상황별 헬퍼 (씬/이벤트에서 호출) ---

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
