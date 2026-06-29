# Known Issues — 반복하지 말 함정 (증상 → 원인 → 재발 방지)

> 버그·설계 함정·작업 실수를 발견하면 여기에 적는다. 세션 시작 루틴에서 먼저 읽어 예방.
> 게임 버그뿐 아니라 프로세스 실수(도구 오용, 커밋 누락)도 포함.

## 웹 export

- **증상:** 웹 배포본에서 **모든 한글이 두부(□)로 깨짐**. (2026-06-30 확인)
  **원인:** Godot 기본/폴백 폰트에 한글 글리프가 없음. 게임 텍스트가 전부 한국어라 사실상 읽을 수 없음(블로커).
  **방지:** 한글 글리프 포함 오픈 폰트(Noto Sans KR 등 OFL)를 `assets/fonts/` 에 넣고 프로젝트 기본 테마 폰트로 지정.
  **배포할 때마다 폰 브라우저에서 한글이 실제로 보이는지 확인.**

- **증상:** cold 캐시 export(.godot 없음, 즉 CI)에서 `Error loading custom project font ... .fontdata` 에러.
  **원인:** `gui/theme/custom_font` 가 프로젝트 로드 시점에 해석되는데, 그때 폰트가 아직 임포트되지 않음(.godot/imported 없음).
  **방지:** export 전에 `godot --headless --path . --import` 를 먼저 실행(deploy.yml 에 "Import resources" 단계 추가). warm 캐시면 export 깨끗.

- **증상:** 셰이더/GPUParticles 가 웹 빌드에서 깨지거나 안 보임.
  **원인:** GL Compatibility 렌더러 + 웹 export 가 이들을 제대로 지원하지 않음 (EoY 에서 확인).
  **방지:** 셰이더·GPUParticles 절대 금지. 폭풍은 CPUParticles2D + 3층 레이어. `CLAUDE.md` 웹 제약 참고.

- **증상:** GitHub Pages 배포 빌드가 멈추거나 SharedArrayBuffer 관련으로 깨짐.
  **원인:** Threads 지원 ON 이면 COOP/COEP cross-origin isolation 헤더가 필요한데 Pages 설정이 까다로움.
  **방지:** export 프리셋 "Web" 에서 Threads Support **끄기** + `ensure_cross_origin_isolation_headers` ON (반영됨).

## 씬 전환 / 노드 트리

- **증상:** `Parent node is busy adding/removing children, remove_child() can't be called at this time`.
  **원인:** 노드의 `_ready()` 안에서 `get_tree().change_scene_to_file()` 를 호출 — 트리가 씬을 붙이는 중이라 충돌.
  **방지:** `_ready` 중에는 씬을 바꾸지 않는다. 씬 전환과 상태 생성을 분리(예: `GameState.begin_run_in_place()` 는
  런만 만들고 전환 안 함). 꼭 _ready 에서 전환해야 하면 `change_scene_to_file.call_deferred(...)`.

## GDScript (전역 규칙 위반 흔한 패턴)

- **증상:** 런타임에 `Trying to assign an array of type "Array" to a variable of type "Array[T]"`.
  **원인:** Dictionary/`Dictionary.get`/JSON 파싱에서 나온 untyped Array 를 `Array[String]` 등에 직접 대입.
  **방지:** `for` 루프로 요소별 `append(T(value))`. 예: `TraceData.from_dict` 의 tags 복원 참고.
