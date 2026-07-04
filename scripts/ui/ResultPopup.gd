class_name ResultPopup
extends Control

## 결과 팝업 (지도·단면 공유) — 조사·선택의 결과를 한 가지 모달로 통일해 보여준다.
## blind choice 정신(가보기 전엔 모른다)의 뒷면: 누르기 전엔 "?", 누른 뒤 여기서 무엇이 일어났는지 공개한다.
## 쓰임: 단면 지점 조사(자원/빈손), 도착 이벤트 선택 결과, 지도 이동 중 상황 선택 결과.
## 순수 표시용 — 자원·플래그 변경은 호출측(ExpeditionRun/GameState)이 이미 끝낸 뒤 결과만 넘긴다.

var _body_label: Label
var _delta_label: Label
var _cb: Callable

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

	var card := UITheme.make_card()
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UITheme.GAP)
	card.add_child(box)

	_body_label = UITheme.make_label("", UITheme.FS_BODY)
	box.add_child(_body_label)

	_delta_label = UITheme.make_label("", UITheme.FS_H2, UITheme.SAND)
	box.add_child(_delta_label)

	var btn := UITheme.make_button("계속")
	btn.pressed.connect(_on_close)
	box.add_child(btn)

## 결과를 띄운다. body=묘사(빈 문자열이면 숨김), effect=자원 델타(빈 Dictionary면 "달라진 건 없다").
## cb = "계속"을 누를 때 실행할 콜백(다음 단계로 잇기 — 이동 재개·죽음 처리 등).
func show_result(body: String, effect: Dictionary, cb: Callable = Callable()) -> void:
	_cb = cb
	_body_label.text = body
	_body_label.visible = body != ""
	if not effect.is_empty():
		_delta_label.text = UITheme.effect_hint(effect)
		_delta_label.add_theme_color_override("font_color", UITheme.SAND)
		_delta_label.visible = true
	elif body == "":
		# 묘사도 변화도 없을 때만 명시 (묘사가 있으면 그게 결과를 말한다).
		_delta_label.text = "달라진 건 없다."
		_delta_label.add_theme_color_override("font_color", UITheme.MUTED)
		_delta_label.visible = true
	else:
		_delta_label.visible = false
	UITheme.fade_in(self)
	UITheme.sand_puff(self)

func is_open() -> bool:
	return visible

func _on_close() -> void:
	var cb: Callable = _cb
	_cb = Callable()
	UITheme.fade_out(self, func() -> void:
		if cb.is_valid():
			cb.call())
