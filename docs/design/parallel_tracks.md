# 병행 작업 트랙 (여러 세션 분업 가이드)

여러 Claude 세션이 동시에 작업할 때, 파일 경계가 겹치지 않는 "트랙"으로 나눠 병행한다.
- **실시간 겹침 방지 = `ACTIVE_WORK.md`** (시작 시 파일 범위 claim, 끝나면 삭제).
- **이 문서 = 어떤 작업이 어떤 파일을 만지는지 미리 나눠둔 지도** (트랙 배정).
- **할 일의 단일 소스 = `backlog.md`** — 이 문서는 그 항목들을 "동시에 굴릴 수 있는 묶음"으로 재배열한 것.
- **현재 상태·전체 맥락 = `00_START_HERE.md`** (새 세션은 그것부터).

## 현재 상태 (2026-07-04)
- **완료:** C 오프닝 · D 가방(직능·도구·무게) · E 코어 ⑥ 결말 MVP · **실제 아트 에셋 교체 대부분**(지도/아이콘/단면/초상/오프닝/타이틀/아이템/손스케치 01~46 배선) · F 설정 음량 저장(`AppSettings`).
- **진행/부분:** B 비주얼(지도 렌더 개편 진행 중 — map-render 세션이 `Map.gd`) · A 콘텐츠(계속 확충 여지) · E 결말 심화(순환 물리 반영·재회 임계 밸런싱 남음).
- **지금 병행하기 좋은 것:** A(콘텐츠) · F(접근성) · 폭풍 3층(`StormFX`) · 오디오 배선(파일 대기). **지도는 map-render 가 잡는 중이라 피한다.**
→ 상세·최신은 항상 `backlog.md` + `00_START_HERE.md`. 이 스냅샷은 큰 그림용.

## 규칙
- 한 세션 = 한 트랙. 시작 시 `ACTIVE_WORK.md` 에 그 트랙의 파일 범위를 claim.
- 트랙끼리 파일이 안 겹치면 안전하게 병행. 겹치는 "공유 파일"(아래)은 순서를 맞추거나 한 세션만 만진다.
- **데이터(콘텐츠)와 구조(코드)를 분리** — 콘텐츠 확충은 구조 작업과 거의 안 겹친다.
- 커밋은 자기 트랙 파일만 명시 스테이징(`git add -A` 금지).

## 공유 파일 (여러 트랙이 건드릴 수 있음 — 조율 필요)
- `scripts/GameState.gd` — 라우팅·세이브·전역 상태. 코어 루프를 바꾸는 트랙(D 가방·E 코어)이 만짐.
- `scripts/ui/UITheme.gd` — 색·헬퍼. 비주얼 트랙(B)이 상수 추가 시.
- `scripts/core/MapGraph.gd` — 노드 데이터. 콘텐츠 트랙(A)의 홈이지만 구조 트랙도 필드 추가 가능.
- `scripts/ui/Main.gd` — 타이틀 진입점. 오프닝(C)이 연결.
- `docs/design/SYOTOS_기획서_v0.1.md`, `backlog.md`, `session_logs/` — 문서. 해당 절만/끝에 append.

## 트랙

### A. 콘텐츠 확충 (데이터만 — 가장 안전, 병행 쉬움)
- 범위: `scripts/core/MapGraph.gd`(노드 `events`/`spots`), `scripts/core/Situations.gd`(`CATALOG` 이동 중 상황), `docs/design/wordpool_v0.1.md`.
- 작업: 노드별 단면 지점(`spots`) 추가, 이벤트 풀·변형·플래그 체인(`sets`/`sets_persist`/`requires`) 확충, 일반 상황 다양화. **시스템은 완비 — 값만 추가**.
- 주의: 구조(필드)는 안 바꾸고 값만. 구조 트랙(D/E)과 *같은 노드* 동시 편집만 피하면 됨.

### B. 비주얼 (절차적 그림 — 나중 실제 에셋 교체)
- 범위: `scripts/ui/SectionArt.gd`(단면 그림), `scripts/ui/Map.gd`(`_draw` 지도), `scripts/ui/StormFX.gd`(폭풍 파티클), `scripts/ui/UITheme.gd`(팔레트/헬퍼).
- 작업: 단면 kind별 맞춤 아트, 지도 다듬기(노드 칩·카메라·이름 겹침), 폭풍 3층 연출. 전부 절차적 `draw_*`(웹 안전).
- 주의: **실제 그림 에셋(오프닝/단면)은 나중에 사용자가 ChatGPT 등으로 준비 → 그때 `SectionArt`/신규 스프라이트로 교체.** UITheme 상수는 공유(A/C 와 순서).

### C. 오프닝 시퀀스 (신규 — 거의 독립)
- 범위: 신규 `scenes/opening.tscn` + `scripts/ui/Opening.gd`(서사 슬라이드쇼), NPC 튜토리얼. `scripts/ui/Main.gd`(진입 연결만).
- 작업: 배경 서사 슬라이드쇼(**맥거핀 유지 — 재앙 정체 안 밝힘**) + 마을 시장 NPC 튜토리얼. backlog "오프닝 시퀀스".
- 주의: 대부분 신규 파일. Main.gd 진입 연결만 공유.

### D. 가방 꾸리기 (코어 루프 진입 — GameState 조율)
- 범위: 신규 준비 화면(`scenes/loadout.tscn` + `scripts/ui/Loadout.gd`), `scripts/GameState.gd`(`START_RESOURCES`→출발 전 선택).
- 작업: 제한 공간(가방 용량)에 책상 물품 직접 선택 + 프리셋/템플릿. 현재 고정 시작 자원 대체. backlog "가방 꾸리기".
- 주의: `GameState.begin_run_in_place`·`START_RESOURCES` 를 바꾸므로 **E(코어)와 순서 조율**.

### E. 코어 루프 마무리 (⑥ end + 밸런스)
- 범위: `scripts/core/ExpeditionRun.gd`, `scripts/GameState.gd`(도달 처리), 밸런스 수치.
- 작업: ⑥ 목적지(end) 도달 처리(**승리 조건 미정 — 사용자 상의 먼저, 맥거핀**), 페이싱·자원 수치 튜닝.
- 주의: GameState/ExpeditionRun 공유 → **D(가방)와 조율**(둘 중 하나씩).

### F. 설정·시스템 (독립)
- 범위: `scripts/ui/SettingsPanel.gd`, `scripts/AppSettings.gd`.
- 작업: 음량 저장/복원, 접근성 옵션. backlog "설정 확장".
- 주의: 거의 독립. UITheme 헬퍼만 공유.

## 병행 추천 조합 (겹침 최소)
- **A(콘텐츠) + B(비주얼) + C(오프닝) + F(설정)** = 서로 거의 안 겹침 → 4세션 동시 안전.
- **D(가방)·E(코어)** 는 GameState/ExpeditionRun 을 공유 → 둘 중 하나씩, 또는 순차. 위 4트랙과는 병행 가능.
