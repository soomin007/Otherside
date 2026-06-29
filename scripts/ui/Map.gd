extends Control

## 탑뷰 지도 — 누적된 길 / 죽음의 역사 / 남긴 흔적의 점. 여기서 이번 원정을 계획하고 출발한다.
## "후대가 곧 나" 라는 구조의 시각화이자 주제를 보여주는 창.
## Phase 0 플레이스홀더 — 안개 걷힘 / 경로 / 죽은 자리 / 흔적 점 렌더링은 추후.

func _ready() -> void:
	var col := UITheme.build_column(self, 20)

	col.add_child(UITheme.make_label("지도 · 원정 계획", UITheme.FS_H1))

	col.add_child(UITheme.make_label(
		"이 세계에 놓인 흔적 %d개\n죽은 자리 %d곳" % [GameState.traces.size(), GameState.deaths.size()],
		UITheme.FS_LABEL, UITheme.MUTED))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	col.add_child(spacer)

	var embark := UITheme.make_button("출발")
	embark.pressed.connect(_on_embark_pressed)
	col.add_child(embark)

func _on_embark_pressed() -> void:
	GameState.start_expedition()
