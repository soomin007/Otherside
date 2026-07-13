class_name ResultPopup
extends Control

## 결과 팝업 (지도·단면 공유) — 조사·선택의 결과를 한 가지 모달로 통일해 보여준다.
## blind choice 정신(가보기 전엔 모른다)의 뒷면: 누르기 전엔 "?", 누른 뒤 여기서 무엇이 일어났는지 공개한다.
## 쓰임: 단면 지점 조사(자원/빈손), 도착 이벤트 선택 결과, 지도 이동 중 상황 선택 결과.
## 순수 표시용 — 자원·플래그 변경은 호출측(ExpeditionRun/GameState)이 이미 끝낸 뒤 결과만 넘긴다.

var _body_label: Label
var _delta_label: Label
var _loss_art: LossArt  ## 손실의 순간 원화(62_사람_스러짐 밝음판) — note 위에 크게(2026-07-13 사용자)
var _note_label: Label   ## 행렬 손실 등 무거운 한 줄 — 델타 아래 붉게(비어 있으면 숨김)
var _party_strip: PartyStrip  ## 행렬 실루엣 줄(손실·구조의 순간) — note 아래(없으면 숨김)
var _cb: Callable
var _closing: bool = false  ## "계속" 연타 방지 — 첫 탭의 닫힘 콜백이 유실되지 않게

## 스러진 자리 원화 — 세밀한 잉크 원화는 큰 자리에만 쓴다는 규칙에 맞는 크기(폭 전체·높이 ~110).
const LOSS_ART_PATH: String = "res://assets/arts/transparent/62_사람_스러짐_밝음.png"

## 손실 원화 그리기 — 원화는 무더기가 왼쪽, 알갱이 꼬리가 오른쪽(320×69). 통짜 가운데 정렬이면
## 무더기가 왼쪽으로 치우쳐 보인다(2026-07-13 사용자) — 무더기 중심이 상자 가운데에 오게 그린다.
class LossArt extends Control:
	var tex: Texture2D
	const MOUND_X: float = 0.38  ## 원화 속 무더기 중심(가로 정규화, 실측 — 봉우리 0.34·본체 질량중심 0.41)
	func _init() -> void:
		clip_contents = true  # 오른쪽 알갱이 꼬리가 상자 폭을 넘으면 잘라낸다
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if tex == null:
			return
		var tw: float = float(tex.get_width())
		var th: float = float(tex.get_height())
		if tw <= 0.0 or th <= 0.0:
			return
		var sc: float = size.y / th
		var w: float = tw * sc
		draw_texture_rect(tex, Rect2(Vector2(size.x * 0.5 - w * MOUND_X, 0.0), Vector2(w, size.y)), false)

## 행렬 실루엣 줄 — 손실/구조의 순간을 사람으로 보여준다(지도 좌 칼럼 행렬 줄과 같은 그림 언어).
## mode "lose" = 방금 스러진 자리가 무너져 모래 무더기가 된다, "gain" = 새 사람이 행렬 끝에 배어 들어온다.
## 모션 줄이기 설정이면 연출 없이 결과 상태로 바로 선다.
class PartyStrip extends Control:
	var slots: int = 5      ## 자리 수(대장 1 + 대원 4 + 거둔 이)
	var left: int = 5       ## 지금 걷는 사람 수(party_left)
	var gained: int = 0     ## 거둔 이 수(행렬 끝, 모래빛)
	var mode: String = "lose"
	var _t: float = 1.0     ## 연출 진행(0→1)
	const DUR: float = 0.9
	const IVORY := Color(0.910, 0.875, 0.804, 0.95)
	const MOUND := Color(0.60, 0.53, 0.42, 0.8)

	func play() -> void:
		_t = 0.0 if AppSettings.load_motion() > 0.02 else 1.0
		queue_redraw()

	func _process(dt: float) -> void:
		if _t < 1.0:
			_t = minf(1.0, _t + dt / DUR)
			queue_redraw()

	func _draw() -> void:
		if slots <= 0:
			return
		var e: float = 1.0 - pow(1.0 - _t, 3.0)  # ease-out
		var step: float = minf(38.0, size.x / float(slots + 1))
		var x0: float = size.x * 0.5 - step * float(slots - 1) * 0.5
		var cy: float = size.y * 0.62
		for i in range(slots):
			var p := Vector2(x0 + step * float(i), cy)
			if mode == "lose" and i == left:
				# 방금 스러진 자리 — 사람이 가라앉으며 무더기가 된다.
				_person(p + Vector2(0.0, 10.0 * e), 24.0, Color(0.75, 0.42, 0.34, 1.0 - e))
				_mound(p, 20.0, Color(MOUND.r, MOUND.g, MOUND.b, MOUND.a * e))
			elif mode == "gain" and i == left - 1:
				# 방금 들어선 사람 — 행렬 끝에 배어 들어온다(구조 팝업의 모래색과 같은 결).
				_person(p + Vector2(0.0, 6.0 * (1.0 - e)), 24.0, Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.95 * e))
			elif i < left:
				var pc: Color = IVORY if i == 0 else Color(IVORY.r, IVORY.g, IVORY.b, 0.7)
				if i > 0 and i >= left - gained:
					pc = Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.9)
				_person(p, 30.0 if i == 0 else 24.0, pc)
			else:
				_mound(p, 20.0, MOUND)

	## 작은 사람 실루엣(머리 + 몸 캡슐) — Map.LeftColumn._draw_person_glyph 과 같은 형태 언어.
	func _person(at: Vector2, h: float, col: Color) -> void:
		draw_circle(at + Vector2(0.0, -h * 0.30), h * 0.17, col)
		draw_line(at + Vector2(0.0, -h * 0.06), at + Vector2(0.0, h * 0.40), col, h * 0.36, true)

	## 스러진 자리 — 낮은 모래 무더기(반원).
	func _mound(at: Vector2, h: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for a in range(9):
			var ang: float = PI + PI * float(a) / 8.0
			pts.append(at + Vector2(cos(ang) * h * 0.55, h * 0.34 + sin(ang) * h * 0.42))
		draw_colored_polygon(pts, col)

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = UITheme.SCRIM
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# 각인 모달(가죽 카드 폐기) — 방사 어둠 + 헤어라인 + 각인 "계속".
	var parts: Array = UITheme.make_engraved_modal()
	center.add_child(parts[0])
	var box: VBoxContainer = parts[1]

	_body_label = UITheme.make_label("", UITheme.FS_BODY)
	box.add_child(_body_label)

	_delta_label = UITheme.make_label("", UITheme.FS_H2, UITheme.SAND)
	box.add_child(_delta_label)

	# 손실 원화 — 바람에 흩어지는 모래 무더기(스러진 자리). 손실 팝업에서만 보인다(없으면 실루엣 줄만).
	_loss_art = LossArt.new()
	if ResourceLoader.exists(LOSS_ART_PATH):
		_loss_art.tex = load(LOSS_ART_PATH)
	_loss_art.custom_minimum_size = Vector2(0, 110)
	_loss_art.visible = false
	box.add_child(_loss_art)

	_note_label = UITheme.make_label("", UITheme.FS_BODY, UITheme.DANGER)
	box.add_child(_note_label)

	_party_strip = PartyStrip.new()
	_party_strip.custom_minimum_size = Vector2(0, 52)
	_party_strip.visible = false
	_party_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_party_strip)

	var btn := UITheme.make_engraved_button("계속", 18, true)
	btn.pressed.connect(_on_close)
	box.add_child(btn)

## 결과를 띄운다. body=묘사(빈 문자열이면 숨김), effect=자원 델타(빈 Dictionary면 "달라진 건 없다").
## cb = "계속"을 누를 때 실행할 콜백(다음 단계로 잇기 — 이동 재개·죽음 처리 등).
## note = 무거운 한 줄(행렬 손실·구조 등) — 델타 아래. 기본 붉게(손실), note_color 로 바꿀 수 있다(구조=모래색).
## note 가 있으면 "달라진 건 없다"는 생략(이미 일어난 일이 말한다).
## party = 행렬 실루엣 줄(party_state 로 만든다, 빈 Dictionary 면 숨김) — 손실/구조를 사람으로 보여준다.
func show_result(body: String, effect: Dictionary, cb: Callable = Callable(), note: String = "", note_color: Color = UITheme.DANGER, party: Dictionary = {}) -> void:
	_cb = cb
	_closing = false
	move_to_front()  # 연속 모달에서 새로 뜬 팝업이 다른 패널 아래에 깔리지 않게 — 항상 맨 위
	_body_label.text = body
	_body_label.visible = body != ""
	_note_label.text = note
	_note_label.visible = note != ""
	_note_label.add_theme_color_override("font_color", note_color)
	_party_strip.visible = not party.is_empty()
	_loss_art.visible = not party.is_empty() and str(party.get("mode", "lose")) == "lose" and _loss_art.tex != null
	if not party.is_empty():
		_party_strip.slots = int(party.get("slots", 5))
		_party_strip.left = int(party.get("left", 5))
		_party_strip.gained = int(party.get("gained", 0))
		_party_strip.mode = str(party.get("mode", "lose"))
		_party_strip.play()
	if not effect.is_empty():
		_delta_label.text = UITheme.effect_hint(effect)
		_delta_label.add_theme_color_override("font_color", UITheme.SAND)
		_delta_label.visible = true
		# 자원 변화 소리 — 물을 얻으면 한 모금, 그 외엔 작은 표시음.
		if int(effect.get("water", 0)) > 0:
			AudioManager.play_sfx(AudioManager.WATER)
		else:
			AudioManager.play_sfx(AudioManager.RESOURCE, -4.0)
	elif body == "" and note == "":
		# 묘사도 변화도 없을 때만 명시 (묘사가 있으면 그게 결과를 말한다).
		_delta_label.text = "달라진 건 없다."
		_delta_label.add_theme_color_override("font_color", UITheme.MUTED)
		_delta_label.visible = true
	else:
		_delta_label.visible = false
	UITheme.fade_in(self)
	UITheme.sand_puff(self)
	UITheme.recenter_modal.call_deferred(self)  # 웹 하단 치우침 방어(레이아웃 레이스)

## 지금 행렬 상태를 실루엣 줄 인자로 만든다 — 손실("lose")/구조("gain") 팝업의 호출측 헬퍼.
static func party_state(run: ExpeditionRun, mode: String) -> Dictionary:
	if run == null:
		return {}
	return {
		"slots": 1 + ExpeditionRun.PARTY_MATES + run.party_gained,
		"left": run.party_left(),
		"gained": run.party_gained,
		"mode": mode,
	}

func is_open() -> bool:
	return visible

func _on_close() -> void:
	if _closing:
		return  # 연타 — 두 번째 fade_out 이 첫 번째를 죽여 콜백(이동 재개 등)이 유실되는 것 방지
	_closing = true
	var cb: Callable = _cb
	_cb = Callable()
	UITheme.fade_out(self, func() -> void:
		if cb.is_valid():
			cb.call())
