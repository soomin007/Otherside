extends CanvasLayer

## 공훈 달성 토스트 (autoload) — 달성한 그 순간 화면 오른쪽 위에 안내 한 장이 배어 나온다
## (효과음 포함, 2026-07-14 사용자). 마을의 해금 연출(Loadout 모달 — 새 사람이 도착하는 서사)은
## 별개로 유지 — 이건 "그 걸음에서 이뤘다"는 즉시 피드백이다.
##
## 표시 전용: 어디에도 입력을 막지 않는다(전부 MOUSE_FILTER_IGNORE — 빈 컨테이너가
## 밑 버튼의 탭을 삼키던 계열 방지, known_issues 2026-07-14). 트리 pause 와 무관하게
## 흐른다(ALWAYS) — 남기기 화면 등 모달 중의 달성도 그대로 안내된다.

const SHOW_SECS: float = 2.8      ## 한 장이 머무는 시간
const FADE_SECS: float = 0.45     ## 배어 나옴/스러짐(연출 세기 반영)
const SLIDE_PX: float = 26.0      ## 오른쪽에서 배어 나오는 거리
const SFX_PATH: String = "res://assets/sfx/sfx_settings.wav"  ## 보류였던 확인음의 새 자리(audio_list ⏸)

var _queue: Array = []            ## 대기 중인 공훈 id — 연쇄 달성(다섯째 직능 + 다 모인 마을)은 한 장씩
var _busy: bool = false
var _panel: PanelContainer
var _eye: Label
var _name_lbl: Label

func _ready() -> void:
	layer = 105  # 게임 UI·일지(100) 위, 튜토리얼(110)·DEV(128) 아래
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	GameState.feat_achieved.connect(_on_feat)

func _build() -> void:
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.045, 0.032, 0.92)   # 어두운 각인 바탕 — 밝은 양피지 위에서도 읽힌다
	sb.border_color = Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.45)
	sb.border_width_bottom = 1                        # 각인 미학 — 상자 대신 밑선
	sb.set_content_margin_all(14.0)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 오른쪽 위, 일지 리본(y 50~96) 아래 — 어느 씬에서도 조작 요소가 없는 자리.
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_top = 108.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.visible = false
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	_eye = UITheme.make_label("이룬 일", 11, Color(UITheme.SAND.r, UITheme.SAND.g, UITheme.SAND.b, 0.8), false)
	_eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_eye)
	_name_lbl = UITheme.make_label("", UITheme.FS_LABEL, UITheme.FG, false)
	_name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF  # 공훈 이름은 한 줄(최장 "아무도 잃지 않은 원정")
	_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_name_lbl)

func _on_feat(fid: String) -> void:
	_queue.append(str(fid))
	if not _busy:
		_next()

func _next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	var f: Dictionary = Feats.by_id(str(_queue.pop_front()))
	if f.is_empty():
		_next()
		return
	_name_lbl.text = L10N.t(str(f.get("name", "")))
	AudioManager.play_sfx(SFX_PATH)
	_panel.visible = true
	_panel.offset_right = -12.0
	var m: float = AppSettings.load_motion()
	var tw: Tween = create_tween()  # ALWAYS 노드에 묶여 pause 중에도 흐른다
	if m <= 0.02:
		_panel.modulate.a = 1.0
	else:
		_panel.modulate.a = 0.0
		_panel.offset_right = -12.0 + SLIDE_PX
		tw.set_parallel(true)
		tw.tween_property(_panel, "modulate:a", 1.0, FADE_SECS * m).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(_panel, "offset_right", -12.0, FADE_SECS * m).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.set_parallel(false)
	tw.tween_interval(SHOW_SECS)
	if m > 0.02:
		tw.tween_property(_panel, "modulate:a", 0.0, FADE_SECS * m).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_panel.visible = false
		_next())
