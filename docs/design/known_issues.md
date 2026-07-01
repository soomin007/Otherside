# Known Issues — 반복하지 말 함정 (증상 → 원인 → 재발 방지)

> 버그·설계 함정·작업 실수를 발견하면 여기에 적는다. 세션 시작 루틴(`00_START_HERE.md` §8)에서 먼저 읽어 예방.
> 게임 버그뿐 아니라 프로세스 실수(도구 오용, 커밋 누락)도 포함.

## 웹 export

- **증상:** 웹 배포본에서 **모든 한글이 두부(□)로 깨짐**. (2026-06-30 확인)
  **원인:** Godot 기본/폴백 폰트에 한글 글리프가 없음. 게임 텍스트가 전부 한국어라 사실상 읽을 수 없음(블로커).
  **방지:** 한글 글리프 포함 오픈 폰트(Noto Sans KR 등 OFL)를 `assets/fonts/` 에 넣고 프로젝트 기본 테마 폰트로 지정.
  **배포할 때마다 폰 브라우저에서 한글이 실제로 보이는지 확인.**

- **증상:** cold 캐시 export(.godot 없음, 즉 CI)에서 `Error loading custom project font ... .fontdata` 에러.
  **원인:** `gui/theme/custom_font` 가 프로젝트 로드 시점에 해석되는데, 그때 폰트가 아직 임포트되지 않음(.godot/imported 없음).
  **방지:** export 전에 `godot --headless --path . --import` 를 먼저 실행(deploy.yml 에 "Import resources" 단계 추가). warm 캐시면 export 깨끗.

- **증상:** 재배포했는데 브라우저(특히 데스크톱)에서 옛 빌드가 보임. 폰은 되는데 데스크톱만 안 되는 등 기기별 차이. (2026-06-30 폰트 적용 후 확인)
  **원인:** Godot 웹 export 산출물 파일명이 매 빌드 동일(index.wasm/index.pck) → 브라우저·CDN 이 옛 파일을 캐시. 기기마다 캐시 상태가 달라 차이 발생.
  **방지:** 폰트 문제가 아님. 강력 새로고침(Ctrl+Shift+R) 또는 시크릿 창으로 확인. 빌드 변경(폰트·에셋) 후 기기별 차이가 보이면 캐시부터 의심.

- **증상:** 셰이더/GPUParticles 가 웹 빌드에서 깨지거나 안 보임.
  **원인:** GL Compatibility 렌더러 + 웹 export 가 이들을 제대로 지원하지 않음 (EoY 에서 확인).
  **방지:** 셰이더·GPUParticles 절대 금지. 폭풍은 CPUParticles2D + 3층 레이어. `CLAUDE.md` 웹 제약 참고.

- **증상:** GitHub Pages 배포 빌드가 멈추거나 SharedArrayBuffer 관련으로 깨짐.
  **원인:** Threads 지원 ON 이면 COOP/COEP cross-origin isolation 헤더가 필요한데 Pages 설정이 까다로움.
  **방지:** export 프리셋 "Web" 에서 Threads Support **끄기** + `ensure_cross_origin_isolation_headers` ON (반영됨).

## 렌더링 / 텍스트

- **증상:** 한글 글씨가 뜨긴 하나 가장자리가 약간 깨져/계단져 보임(특히 폰·고해상도). (2026-07-01 1차 조치)
  **원인:** `rendering/textures/canvas_textures/default_texture_filter=0`(Nearest) + `stretch=canvas_items`/`aspect=expand`.
  폰 해상도마다 논리 캔버스(600폭)가 **비정수 배율**로 확대되는데, 폰트 글리프 아틀라스를 Nearest 로 샘플링하면 확대된 글자가 계단처럼 깨진다.
  **방지:** `default_texture_filter=1`(Linear). 이 프로젝트는 픽셀아트 스프라이트가 없어(전부 절차적 `draw_*`+폰트+부드러운 절차 텍스처) Linear 가 모든 요소에 더 낫다. 픽셀아트를 도입하면 그 스프라이트만 노드별 `texture_filter`로 Nearest 지정.
  여전히 흐리면 폰트 MSDF 임포트가 다음 레버(웹/GL Compatibility 실기기 검증 필수).

- **증상:** UI 텍스트에 넣은 특수문자(`✕` U+2715, `−` U+2212 등)가 두부(□)로 뜬다. (2026-07-01)
  **원인:** 임베드 폰트(NanumGothic)에 그 글리프가 없음. 게임 폰트는 한글 + 기본 라틴/기호 위주라 장식 유니코드가 빠질 수 있다.
  **방지:** UI 문구는 **한글/기본 ASCII** 로. 아이콘이 필요하면 절차적 draw(`draw_line` 등)로 그리거나, 넣기 전 폰트에 글리프가 있는지 확인. (예: 가방 빼기를 `✕` 대신 "탭해서 빼기" 안내로 처리.)

## 씬 전환 / 노드 트리

- **증상:** `Parent node is busy adding/removing children, remove_child() can't be called at this time`.
  **원인:** 노드의 `_ready()` 안에서 `get_tree().change_scene_to_file()` 를 호출 — 트리가 씬을 붙이는 중이라 충돌.
  **방지:** `_ready` 중에는 씬을 바꾸지 않는다. 씬 전환과 상태 생성을 분리(예: `GameState.begin_run_in_place()` 는
  런만 만들고 전환 안 함). 꼭 _ready 에서 전환해야 하면 `change_scene_to_file.call_deferred(...)`.

## 검증 / 헤드리스

- **증상:** `godot --headless -s res://test.gd` 로 스크립트를 돌리면 `Identifier not found: GameState`(또는 다른 autoload)
  컴파일 에러가 나고, 프로세스가 종료되지 않고 멈춘다(여러 개 띄우면 프로젝트 락으로 서로 더 막힘). (2026-06-30 확인)
  **원인:** `-s` 는 커스텀 `SceneTree`/`MainLoop` 를 실행하는데, 이 컨텍스트에선 **autoload 노드가 등록되지 않는다.**
  그래서 autoload(`GameState` 등)를 참조하는 스크립트는 로드 자체가 실패한다. 정식 부팅 경로(autoload 등록됨)와 다르다.
  **방지:** autoload 에 의존하는 코드는 `-s` 단독 스크립트로 테스트하지 말 것. 파싱·컴파일은 `--import`,
  실행 경로는 `--quit-after N`(정식 부팅) 으로 검증한다(둘 다 정상 종료·에러 0 이어야 함). 또 헤드리스 godot 을
  여러 개 동시에 띄우지 말 것 — 프로젝트 락으로 hang. 멈추면 `Stop-Process -Name godot -Force` 로 정리.

## GDScript (전역 규칙 위반 흔한 패턴)

- **증상:** 런타임에 `Trying to assign an array of type "Array" to a variable of type "Array[T]"`.
  **원인:** Dictionary/`Dictionary.get`/JSON 파싱에서 나온 untyped Array 를 `Array[String]` 등에 직접 대입.
  **방지:** `for` 루프로 요소별 `append(T(value))`. 예: `TraceData.from_dict` 의 tags 복원 참고.
