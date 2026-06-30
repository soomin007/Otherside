# See you on the other side

비동기 로그라이트 (Godot 4.6, 2D, 웹 배포). 매년 원정대가 떠나고 거의 다 죽는다.
**플레이어는 원정대를 거듭 보내는 총괄자** — 죽기 전 단 한 번 다음 원정대에게 *물건*을 남긴다. 모래폭풍이 글씨를
지우는 세계라 말이 아닌 물건만 남는다.

> 중심 질문: *누군가 결국 닿을 것을 알 때, 미래의 나를 위해 지금의 나는 무엇을 포기하는가.*

Clair Obscur 형식의 부제. 앞 주제목은 세계관 구체화 후 결정.

## 구조

```
project.godot          # Godot 4.6, GL Compatibility, autoload=GameState
scenes/                # main(타이틀) · map(탑뷰 지도) · expedition(횡스크롤 단면)
scripts/
  GameState.gd         # autoload: 전역 상태 + 씬 라우팅 + 세이브(JSON, user://)
  core/                # 순수 데이터·로직 (노드/렌더링 무의존) — Threats, WordPool, TraceData
  ui/                  # 렌더링·입력 (씬 스크립트)
docs/design/           # 기획서·단어풀 (단일 진실) + backlog + known_issues
session_logs/          # 세션별 작업 기록
.github/workflows/     # GitHub Pages 자동 배포 (Godot 웹 export)
```

**아키텍처 원칙:** `scripts/core/` (순수 로직) ↔ `scripts/ui/`+`scenes/` (렌더링) 분리.
core 는 ui 를 import 하지 않는다. 상세는 `CLAUDE.md`.

## 개발

```bash
# 에디터 열기
Godot_v4.6.1-stable_win64.exe --path .
# 파싱·임포트 검증 (헤드리스)
godot --headless --path . --import
# 부팅 스모크 테스트 (에러/경고 0 이어야 함)
godot --headless --path . --quit-after 5
```

## 배포 (웹 → GitHub Pages)

`.github/workflows/deploy.yml` 이 `main` push 시 Godot 웹 export 후 Pages 에 배포한다.
**선행 작업(사용자):** GitHub 저장소 생성 → 원격 연결 → Settings → Pages → Source: "GitHub Actions".

상세 사양은 `docs/design/SYOTOS_기획서_v0.1.md`.
