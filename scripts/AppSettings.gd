class_name AppSettings
extends RefCounted

## 앱 설정 — 게임 세이브(GameState)와 별개로 `user://settings.cfg` 에 저장한다.
## 데이터 초기화(GameState.reset_save)는 세계만 지우고 이 설정은 건드리지 않는다.
## 지금은 음량(Master 버스)만. 접근성 등은 후속.
##
## 음량은 linear 0..1 로 저장하고, 적용 시 dB 로 변환한다. 0 이면 mute.

const PATH: String = "user://settings.cfg"
const SECTION: String = "audio"
const KEY_VOLUME: String = "master_volume"

## 저장된 마스터 음량(linear 0..1). 없거나 깨졌으면 1.0.
static func load_master_volume() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return 1.0
	return clampf(float(cfg.get_value(SECTION, KEY_VOLUME, 1.0)), 0.0, 1.0)

## 마스터 음량을 저장한다(다른 섹션 값은 보존).
static func save_master_volume(linear: float) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # 실패해도 빈 cfg 로 진행 (기존 값 유지 시도)
	cfg.set_value(SECTION, KEY_VOLUME, clampf(linear, 0.0, 1.0))
	cfg.save(PATH)

## 음량을 Master 버스에 적용 + 저장(슬라이더 조작 시).
static func set_master_volume(linear: float) -> void:
	var v := clampf(linear, 0.0, 1.0)
	_apply(v)
	save_master_volume(v)

## 저장된 음량을 Master 버스에 적용(앱 시작 시 1회).
static func apply_saved() -> void:
	_apply(load_master_volume())

static func _apply(v: float) -> void:
	var idx := AudioServer.get_bus_index("Master")
	if idx < 0:
		return
	var muted := v <= 0.0001
	AudioServer.set_bus_mute(idx, muted)
	if not muted:
		AudioServer.set_bus_volume_db(idx, linear_to_db(v))
