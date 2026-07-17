extends Node

## 오디오 매니저 (autoload: AudioManager) — BGM 베드 + 효과음(SFX).
## BGM: 잔잔 베드를 코어 루프 내내 재생. **끝을 다음 시작에 겹쳐 크로스페이드**해 이음매 없이 무한 루프
##      (파일 loop 대신 수동 크로스페이드 — 클릭·틈 없음). 곡 바꿈도 크로스페이드(폭풍·엔딩).
## SFX: 짧은 one-shot(겹침 허용). 발소리는 4변주 랜덤 회전(반복 티 방지).
## 버스: BGM 은 Music, 효과음은 SFX 버스(둘 다 여기서 코드로 생성, Master 로 send).
##       볼륨은 AppSettings 가 버스별로 적용·저장. 웹 안전: AudioStreamPlayer + mp3/ogg/wav, 파일 없으면 무음.

# --- 오디오 버스 (Music / SFX — 설정에서 따로 조절) ---
const BUS_MUSIC: String = "Music"
const BUS_SFX: String = "SFX"

# --- BGM 트랙 ---
# 웹 용량 때문에 전 곡 ogg 약 96kbps(2026-07-05, 사용자 A/B 확인). 원본 mp3 = assets_src/bgm_original(.gdignore, 앱 배포 시 원본 탑재 후보).
const BED: String = "res://assets/bgm/Sand Erases the Words.ogg"      ## 코어 루프 잔잔 베드
const REUNION: String = "res://assets/bgm/Other Side.ogg"             ## 재회 엔딩 크레딧(한 번만)
const STORM: String = "res://assets/bgm/The Wall of Sand.ogg"         ## 폭풍(폭풍 biome 노드에서 교체)
const CYCLE: String = "res://assets/bgm/The Unresolved.ogg"           ## 순환 엔딩(슬라이드+암전 겸용)

const FADE: float = 1.5        ## 트랙 교체 크로스페이드(초)
const LOOP_XFADE: float = 4.0  ## 루프 이음매 크로스페이드(초) — 끝을 다음 시작에 겹친다
const QUIET_DB: float = -40.0

# --- SFX ---
const SFX_VOICES: int = 6   ## 동시에 겹칠 수 있는 최대 효과음
## 발소리 3변주(이동 중 랜덤 회전 — 반복 티 방지). 3번은 결이 안 맞아 제거(사용자, 2026-07-05).
const STEP_SET: Array = [
	"res://assets/sfx/sfx_step_1.wav", "res://assets/sfx/sfx_step_2.wav",
	"res://assets/sfx/sfx_step_4.wav",
]
const STEP_DB: float = -7.0   ## 발소리 볼륨 — 걸음마다 나므로 낮게 깔리게(사용자 피드백)
## 배선된 효과음 경로(전체 목록·프롬프트 = docs/external/audio_list.md §2)
const TAP: String = "res://assets/sfx/sfx_tap.wav"
const CARD_OPEN: String = "res://assets/sfx/sfx_card_open.wav"
const CARD_CLOSE: String = "res://assets/sfx/sfx_card_close.wav"
const WATER: String = "res://assets/sfx/sfx_water.wav"
const RESOURCE: String = "res://assets/sfx/sfx_resource.wav"
const PICKUP: String = "res://assets/sfx/sfx_pickup.wav"
const ROPE: String = "res://assets/sfx/sfx_rope.wav"
const REVEAL: String = "res://assets/sfx/sfx_reveal.wav"
## 손그림 원(호버) 6변주 — freesound "Marker Circle"(tubbsmedia, CC0) 분할. 원마다 다른 획 소리.
const DRAW_SET: Array = [
	"res://assets/sfx/sfx_draw_1.wav", "res://assets/sfx/sfx_draw_2.wav",
	"res://assets/sfx/sfx_draw_3.wav", "res://assets/sfx/sfx_draw_4.wav",
	"res://assets/sfx/sfx_draw_5.wav", "res://assets/sfx/sfx_draw_6.wav",
]
const STORM_GUST: String = "res://assets/sfx/sfx_storm_gust.wav"
const CRACK: String = "res://assets/sfx/sfx_crack.wav"
const THIRST: String = "res://assets/sfx/sfx_thirst.wav"
const DEATH: String = "res://assets/sfx/sfx_death.wav"
const REUNION_CHIME: String = "res://assets/sfx/sfx_reunion_chime.wav"
const CYCLE_HIT: String = "res://assets/sfx/sfx_cycle.wav"

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _cur: AudioStreamPlayer   ## 지금 우세 BGM 플레이어
var _sfx: Array = []          ## SFX 보이스 풀
var _rng := RandomNumberGenerator.new()
var _loop_path: String = ""   ## 루프 대상 트랙(베드·폭풍). "" = 원샷(엔딩 크레딧)
var _xfading: bool = false    ## 루프 크로스페이드 진행 중
var _thirst_low: bool = false ## 갈증 경고를 이미 울렸나(물이 임계 위로 회복하면 리셋)

## 웹(Threads OFF) 메인스레드 믹서 글리치('타닥') 회피 — 베드곡은 브라우저 네이티브 SAMPLE 재생(Master 버스).
## 스트림(폭풍·엔딩)과 배타적: 한쪽 켜면 다른 쪽 끈다. (2026-07-06)
var _bed: AudioStreamPlayer
## 웹에서만 SAMPLE 우회. 네이티브(데스크톱·모바일 앱)는 스레드 오디오가 정상이라 원래 스트림 재생(크로스페이드·버스 볼륨·심리스 루프) 유지.
var _use_sample_bed: bool = false

# --- 환경음 (위치 반영 바람 — 후반일수록 잦고 세게) ---
## 연속 바람 루프 에셋이 없어 돌풍(sfx_storm_gust) 을 간헐 스케줄로 재사용한다 — 성근 사운드
## 정체성(§0)에도 맞고 베드 BGM 과 안 싸운다. 변주는 피치·볼륨 랜덤(파일 하나로 반복 티 방지).
var _wind: AudioStreamPlayer  ## 전용 플레이어 — SFX 보이스 풀을 안 뺏는다
var _wind_level: float = 0.0  ## 0(마을·타이틀) = 무풍 ~ 1(목적지 부근). MapGraph.progress 값
var _wind_wait: float = 0.0   ## 다음 돌풍까지(초)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_ensure_buses()
	AppSettings.apply_saved()   # 버스 생성 직후 저장 음량 적용(첫 프레임 풀 볼륨 방지)
	_a = _make_player(BUS_MUSIC)
	_b = _make_player(BUS_MUSIC)
	_cur = _a
	for i in SFX_VOICES:
		_sfx.append(_make_player(BUS_SFX))
	get_tree().node_added.connect(_on_node_added)  # 모든 버튼 공통 탭 소리(자동 배선)
	_use_sample_bed = OS.has_feature("web")  # 웹만 SAMPLE 우회. 네이티브는 원래 스트림 재생.
	play_bed()

## Music / SFX 버스 확보 — 기본은 default_bus_layout.tres 가 시동 때 등록한다(웹 샘플 경로도 인식).
## 레이아웃이 없거나 깨졌을 때만 코드로 보강(멱등 — 있으면 건너뜀).
func _ensure_buses() -> void:
	for bus_name in [BUS_MUSIC, BUS_SFX]:
		if AudioServer.get_bus_index(str(bus_name)) < 0:
			var idx: int = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, str(bus_name))
			AudioServer.set_bus_send(idx, "Master")

func _make_player(bus_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus_name
	# 웹(스레드 없음) 기본은 "샘플" 재생 — JS 쪽 경로라 커스텀 버스(Music/SFX)로 보낸 소리가
	# 안 나온다(2026-07-05 폰에서 전체 무음 확인). 스트림 = 네이티브 믹서 경로 강제 → 버스·크로스페이드 전부 정상.
	p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(p)
	return p

## 루프 트랙이 끝에 다다르면 미리 다음 회차를 겹쳐 재생(끊김 없는 이음매) + 바람 스케줄.
func _process(dt: float) -> void:
	if _wind_level > 0.0:
		_wind_wait -= dt
		if _wind_wait <= 0.0:
			_gust()
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

## 코어 루프 베드로 (돌아)간다. 웹 타닥 회피를 위해 스트림 믹서가 아니라 **브라우저 네이티브 SAMPLE 재생**.
## 이미 베드가 울리는 중이면 재시작 안 함(연속 유지). 폭풍·엔딩 스트림은 끈다.
func play_bed() -> void:
	if not _use_sample_bed:
		play_track(BED)   # 네이티브(데스크톱): 원래 스트림 크로스페이드 — 글리치 없고 버스 볼륨·연속 유지 그대로
		return
	_stop_stream_tracks()   # 폭풍·엔딩 스트림 끄기
	if _bed == null:
		_bed = AudioStreamPlayer.new()
		_bed.bus = "Master"   # ⚠️ 커스텀 버스(Music)면 웹 샘플 재생이 무음 → Master 로 보낸다
		_bed.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE
		add_child(_bed)
	_apply_bed_volume()
	if _bed.playing:
		return   # 이미 베드 — 연속 유지(멱등)
	if not ResourceLoader.exists(BED):
		return
	var s: Resource = load(BED)
	if s is AudioStreamOggVorbis or s is AudioStreamMP3:
		s.loop = true   # 네이티브 루프(심리스는 아님 — 8분 뒤 이음매, 후속 과제)
	_bed.stream = s
	_bed.play()

## Music 설정 음량을 베드 플레이어에 직접 적용(Master 버스라 Music 버스 볼륨이 안 먹는다).
func _apply_bed_volume() -> void:
	if _bed == null:
		return
	var lin: float = clampf(AppSettings.load_music_volume(), 0.0, 1.0)
	_bed.volume_db = -80.0 if lin <= 0.0001 else linear_to_db(lin)

## 설정의 음악 슬라이더 변경을 즉시 반영 — 웹 샘플 베드는 Music 버스 밖(Master 직결)이라 버스 볼륨이
## 안 닿아, 조정해도 다음 play_bed(씬 전환)까지 그대로였다(2026-07-17 사용자 제보). 슬라이더가 부른다.
## 네이티브(스트림 경로)는 버스 볼륨이 실시간이라 여기선 할 일이 없다(_bed == null → no-op).
func refresh_music_volume() -> void:
	_apply_bed_volume()

## 스트림 BGM(폭풍·엔딩) 정리 — 루프 상태도 해제.
func _stop_stream_tracks() -> void:
	_loop_path = ""
	_xfading = false
	for p in [_a, _b]:
		if p != null and p.playing:
			p.stop()

## 폭풍·엔딩 스트림으로 갈아탈 때 베드 샘플을 멈춘다(배타적).
func _stop_bed() -> void:
	if _bed != null and _bed.playing:
		_bed.stop()

## 폭풍 구간 진입 — 위기곡으로 교체(에셋 없으면 무음, 베드 유지).
func play_storm() -> void:
	_stop_bed()
	play_track(STORM)

## 재회 엔딩 크레딧곡 — 한 번만(루프 안 함). 엔딩은 곡이 주인공 — 바람을 끈다.
func play_reunion() -> void:
	_stop_bed()
	set_wind(0.0)
	play_track(REUNION, FADE, false)

## 순환 엔딩곡 — 슬라이드부터 암전·안내까지 계속(루프). 나갈 때 타이틀이 베드로 크로스페이드.
func play_cycle() -> void:
	_stop_bed()
	set_wind(0.0)
	play_track(CYCLE)

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

## 발소리 한 걸음(3변주 랜덤). 이동(step)마다 호출.
func play_step() -> void:
	play_sfx_random(STEP_SET, STEP_DB)

## 지도 호버 — 손그림 원이 그려지는 소리(6변주 랜덤 — 원 모양이 매번 다르듯 획 소리도 다르게).
func play_circle_draw() -> void:
	play_sfx_random(DRAW_SET, -6.0)

## 모든 버튼 공통 탭 — 트리에 새로 들어오는 BaseButton 의 pressed 에 자동 연결.
## 자기 소리를 가진 버튼은 meta "no_tap" 으로 제외 가능. autoload 순서상 AudioManager 가
## 마지막이라 먼저 만들어진 디버그(DEV) 버튼들은 빠지는데, 개발용이라 오히려 알맞다.
func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.has_meta("no_tap"):
		var b: BaseButton = n
		if not b.pressed.is_connected(_play_tap):
			b.pressed.connect(_play_tap)

func _play_tap() -> void:
	play_sfx(TAP, -6.0)   # 살짝 낮게 — 다른 효과음 밑에 깔리는 기본 감촉

## 상황 카드 열림 — 위협 종류에 맞는 소리(폭풍=돌풍, 차단=갈라진 울림, 그 외=양피지 카드).
func play_situation_card(threat_kind: int) -> void:
	match threat_kind:
		Threats.Kind.STORM:
			play_sfx(STORM_GUST, -4.0)
		Threats.Kind.BLOCKAGE:
			play_sfx(CRACK, -4.0)
		_:
			play_sfx(CARD_OPEN)

# --- 환경음 (위치 반영 바람) ---

## 바람 세기(0~1) — 씬 진입 때 현 위치의 `MapGraph.progress` 를 넣는다. 0 = 무풍(마을·타이틀).
## 후반일수록 돌풍이 잦고(간격 26→8s) 세게(-22→-8dB) 분다. 무풍→바람 전환 첫 돌풍은 이르게(도착의 공기).
func set_wind(level: float) -> void:
	var was: float = _wind_level
	_wind_level = clampf(level, 0.0, 1.0)
	if _wind_level > 0.0 and was <= 0.0:
		_wind_wait = _rng.randf_range(2.0, 6.0)

## 돌풍 한 번 — 피치·볼륨 랜덤 변주(파일 하나라 반복 티 방지). 이미 부는 중이면 다음 차례로 미룬다.
func _gust() -> void:
	_wind_wait = lerpf(26.0, 8.0, _wind_level) * _rng.randf_range(0.7, 1.35)
	if not ResourceLoader.exists(STORM_GUST):
		return
	if _wind == null:
		_wind = _make_player(BUS_SFX)
	if _wind.playing:
		return
	_wind.stream = load(STORM_GUST)
	_wind.pitch_scale = _rng.randf_range(0.82, 1.12)
	_wind.volume_db = lerpf(-22.0, -8.0, _wind_level) + _rng.randf_range(-1.5, 1.5)
	_wind.play()

## 갈증 경고 — 물이 임계(3) 이하로 "떨어지는 순간" 한 번만. 회복하면 리셋(지도·단면 공용).
func warn_thirst(water: int) -> void:
	if water <= 3:
		if not _thirst_low:
			_thirst_low = true
			play_sfx(THIRST)
	else:
		_thirst_low = false

# 웹 백그라운드 음소거는 여기(GDScript)서 못 한다 — 탭이 숨으면 엔진 프레임 루프가 멈춰
# 코드가 실행될 기회가 없다. export 프리셋 head_include 의 페이지 JS(visibilitychange →
# AudioContext suspend/resume)가 담당한다. (known_issues 2026-07-06)

## 종료 시 정리 — 재생 중 스트림 참조를 놓아 "리소스 사용 중" 누수 경고를 줄인다.
func _exit_tree() -> void:
	for p in ([_a, _b, _wind, _bed] + _sfx):
		if p != null:
			p.stop()
			p.stream = null
