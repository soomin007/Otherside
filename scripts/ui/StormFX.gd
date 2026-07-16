class_name StormFX
extends Node2D

## 폭풍 시각 연출 2·3층 (기획서 §5 웹 제약, §4.1).
## 1층(반투명 그라데이션 띠)은 Expedition._draw_storm 가 그린다. 여기는:
##  - 중경(2층): 크고 느리고 옅은 모래 가스트 소량.
##  - 전경(3층): 가늘고 빠른 모래 알갱이.
##
## 웹 안전: **CPUParticles2D 만** 쓴다(셰이더/GPUParticles 금지 — EoY/기획서에서 확인).
## 텍스처는 절차적 소프트 점(이미지 자산 무의존, 경량). 파티클 수는 폰 기준으로 낮게(웹=폰 우선).
##
## 턴제: 화면상 폭풍 영역이 바뀌는 건 걸음마다이므로 Expedition 이 set_band() 로 갱신.
## 파티클은 엔진이 매 프레임 날린다(정적 화면에서도 바람이 분다).

const MID_AMOUNT: int = 10    ## 중경 입자 수 (적게)
const FORE_AMOUNT: int = 38   ## 전경 입자 수 (모바일에도 가볍게)
const WIND_DIR := Vector2(-1.0, 0.18)  ## 왼쪽으로(전진을 거스르듯) 살짝 아래로 부는 바람
## 빛 받은 모래 톤(배경보다 밝게) — 밝은 폭풍 아트 위에서도 대비가 남게(세션 7 교훈: 배경색과 같으면 대비 0).
const HAZE := Color(0.90, 0.84, 0.70)  ## 중경 = 은은한 발광 먼지 베일
const LIT := Color(0.96, 0.92, 0.80)   ## 전경 = 빛나는 모래 알갱이

var _mid: CPUParticles2D
var _fore: CPUParticles2D
var _motion: float = 1.0  ## 연출 세기(설정, 씬 진입 시점 값) — 입자 수 배율. 0이면 set_band 가 분출을 막는다.

func _init() -> void:
	_motion = AppSettings.load_motion()  # 슬라이더 변경은 다음 씬 진입부터(2026-07-16)
	var dot: ImageTexture = make_dot_texture(12)
	# 중경: 크고(scale↑) 느리고(velocity↓) 아주 옅게(alpha↓), 길게 떠 있음.
	_mid = _make_layer(maxi(1, int(MID_AMOUNT * _motion)), dot, 1.2, 2.2, 70.0, 150.0,
		Color(HAZE.r, HAZE.g, HAZE.b, 0.15), 2.0)
	# 전경: 작고 빠르고 또렷한 알갱이, 짧게. 움직임(스쳐 지나감)이 폭풍을 살린다.
	_fore = _make_layer(maxi(1, int(FORE_AMOUNT * _motion)), dot, 0.28, 0.5, 200.0, 330.0,
		Color(LIT.r, LIT.g, LIT.b, 0.55), 1.1)
	add_child(_mid)
	add_child(_fore)
	visible = false

func _make_layer(amount: int, tex: Texture2D, smin: float, smax: float,
		vmin: float, vmax: float, col: Color, life: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.amount = amount
	p.lifetime = life
	p.preprocess = life            # 보일 때 이미 차 있도록
	p.emitting = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(10.0, 10.0)  # set_band 에서 갱신
	p.direction = WIND_DIR
	p.spread = 22.0
	p.gravity = Vector2(0.0, 24.0)
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.scale_amount_min = smin
	p.scale_amount_max = smax
	p.color = col
	return p

## 화면상 폭풍 영역(Expedition Control 로컬 좌표). 폭/높이 0 이하면 숨기고 분출 정지.
## 연출 세기 0(끔)이어도 같은 경로로 숨긴다 — 1층 그라데이션(분위기)은 호출측이 따로 그려 남는다.
func set_band(band: Rect2) -> void:
	if _motion <= 0.02 or band.size.x <= 1.0 or band.size.y <= 1.0:
		if visible:
			visible = false
			_mid.emitting = false
			_fore.emitting = false
		return
	visible = true
	position = band.position + band.size * 0.5
	var ext: Vector2 = band.size * 0.5
	_mid.emission_rect_extents = ext
	_fore.emission_rect_extents = ext
	_mid.emitting = true
	_fore.emitting = true

## 절차적 소프트 점 텍스처 (중심 불투명 → 가장자리 투명). 셰이더 없이 모래 알갱이 느낌.
## 공개 static — 지도 드리프트 등 다른 모래 연출도 같은 알갱이를 쓴다.
static func make_dot_texture(sz: int) -> ImageTexture:
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var c: float = sz * 0.5
	for y in sz:
		for x in sz:
			var d: float = Vector2(x - c + 0.5, y - c + 0.5).length() / c
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = a * a  # 부드러운 감쇠
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)
