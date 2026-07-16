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

## 화면 크기(설정 라벨, 옛 "글자 크기") = UI 전체 배율(Window.content_scale_factor). 1.0 기본, 0.85~1.2.
## 코드 식별자·설정 키(text_scale)는 저장 호환 때문에 그대로 둔다 — 표시 문구만 "화면 크기"(2026-07-16).
## 텍스트만 스케일하려면 FS_* 전면 라우팅이 필요해 크다 — 전체 배율이 일관·저위험(2026-07-07 결정).
## 그때 되돌린 원인(에디터 임베드뷰 스케일 충돌 의심 + 1.25 오버플로)은 상한 1.2 +
## 적용 직후 재배치(뷰포트 리사이즈 훅, 2026-07-14) + 실창 스크린샷 검증으로 재도전(2026-07-15).
const KEY_TEXT_SCALE: String = "text_scale"
const DEFAULT_TEXT_SCALE: float = 1.0
const TEXT_SCALE_MIN: float = 0.85
const TEXT_SCALE_MAX: float = 1.2

static var _text_scale_cache: float = -1.0

static func load_text_scale() -> float:
	if _text_scale_cache > 0.0:
		return _text_scale_cache
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		_text_scale_cache = DEFAULT_TEXT_SCALE
	else:
		_text_scale_cache = clampf(float(cfg.get_value(SECTION_DISPLAY, KEY_TEXT_SCALE, DEFAULT_TEXT_SCALE)), TEXT_SCALE_MIN, TEXT_SCALE_MAX)
	return _text_scale_cache

static func set_text_scale(v: float) -> void:
	_text_scale_cache = clampf(v, TEXT_SCALE_MIN, TEXT_SCALE_MAX)
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # 실패해도 빈 cfg 로 진행
	cfg.set_value(SECTION_DISPLAY, KEY_TEXT_SCALE, _text_scale_cache)
	cfg.save(PATH)

## 저장된 배율을 창에 적용(앱 시작 시 GameState, 슬라이더 조작 시 Bookmark 가 부른다 — 멱등).
## RefCounted 정적이라 트리 접근이 없다 — 호출부가 Window 를 넘긴다.
static func apply_text_scale(win: Window) -> void:
	if win != null:
		win.content_scale_factor = load_text_scale()

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
