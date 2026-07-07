class_name AppSettings
extends RefCounted

## 앱 설정 — 게임 세이브(GameState)와 별개로 `user://settings.cfg` 에 저장한다.
## 데이터 초기화(GameState.reset_save)는 세계만 지우고 이 설정은 건드리지 않는다.
## 음량 3개: Master(전체 음소거용) + Music(배경음악) + SFX(효과음). 버스는 AudioManager 가 생성.
##
## 음량은 linear 0..1 로 저장하고, 적용 시 dB 로 변환한다. 0 이면 해당 버스 mute.

const PATH: String = "user://settings.cfg"
const SECTION: String = "audio"
const KEY_VOLUME: String = "master_volume"
const KEY_MUSIC: String = "music_volume"
const KEY_SFX: String = "sfx_volume"

## 연출(모션) 세기 — 0 = 전환·책넘김을 즉시(모션 줄이기), 1 = 기본. Transition·Bookmark 가 지속시간에 곱한다.
const SECTION_DISPLAY: String = "display"
const KEY_MOTION: String = "motion"
const DEFAULT_MOTION: float = 1.0

## 배경음악 기본값을 낮게 — Suno 마스터링이 커서 효과음(-4dB 피크)이 묻힌다.
const DEFAULT_MUSIC: float = 0.7
const DEFAULT_SFX: float = 1.0

# --- 읽기 ---

static func load_master_volume() -> float:
	return _load_key(KEY_VOLUME, 1.0)

static func load_music_volume() -> float:
	return _load_key(KEY_MUSIC, DEFAULT_MUSIC)

static func load_sfx_volume() -> float:
	return _load_key(KEY_SFX, DEFAULT_SFX)

## 연출 세기 0..1 (기본 1). 0 이면 전환을 즉시 처리한다.
## 전환·등장마다(등장은 요소별로) 읽히므로 정적 캐시 — 파일 반복 읽기 회피. set_motion 이 캐시를 갱신한다.
static var _motion_cache: float = -1.0

static func load_motion() -> float:
	if _motion_cache >= 0.0:
		return _motion_cache
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		_motion_cache = DEFAULT_MOTION
	else:
		_motion_cache = clampf(float(cfg.get_value(SECTION_DISPLAY, KEY_MOTION, DEFAULT_MOTION)), 0.0, 1.0)
	return _motion_cache

static func set_motion(v: float) -> void:
	_motion_cache = clampf(v, 0.0, 1.0)
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # 실패해도 빈 cfg 로 진행
	cfg.set_value(SECTION_DISPLAY, KEY_MOTION, _motion_cache)
	cfg.save(PATH)

static func _load_key(key: String, def: float) -> float:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return def
	return clampf(float(cfg.get_value(SECTION, key, def)), 0.0, 1.0)

# --- 쓰기 + 버스 적용 (슬라이더 조작 시) ---

static func set_master_volume(linear: float) -> void:
	_set_key(KEY_VOLUME, "Master", linear)

static func set_music_volume(linear: float) -> void:
	_set_key(KEY_MUSIC, "Music", linear)

static func set_sfx_volume(linear: float) -> void:
	_set_key(KEY_SFX, "SFX", linear)

static func _set_key(key: String, bus: String, linear: float) -> void:
	var v := clampf(linear, 0.0, 1.0)
	_apply(bus, v)
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # 실패해도 빈 cfg 로 진행 (기존 값 유지 시도)
	cfg.set_value(SECTION, key, v)
	cfg.save(PATH)

## 저장된 음량 전부를 버스에 적용(앱 시작 시. AudioManager 가 버스 생성 직후에도 부른다 — 멱등).
static func apply_saved() -> void:
	_apply("Master", load_master_volume())
	_apply("Music", load_music_volume())
	_apply("SFX", load_sfx_volume())

static func _apply(bus: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	var muted := v <= 0.0001
	AudioServer.set_bus_mute(idx, muted)
	if not muted:
		AudioServer.set_bus_volume_db(idx, linear_to_db(v))
