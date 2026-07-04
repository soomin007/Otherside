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
  **정정(2026-07-04): 이 줄이 project.godot 에서 사라져도 회귀 아님.** Godot 4.6 은 이 설정 **기본값이 이미 1(Linear)**이다(헤드리스 확인: 줄 없이도 실효값 1). 에디터에서 **F5/F6(씬 실행) 시 project.godot 를 재직렬화**하며 기본값과 같은 이 줄을 지우고 `[gui]`/`[display]` 순서를 바꾸기도 한다 — 실효값은 그대로라 무해. `M project.godot` 로 이 줄만 빠져 보여도 당황 말 것(무시하거나 `git checkout -- project.godot`). 명시는 문서·안전용으로 유지(HEAD 에는 =1 커밋됨).

- **증상:** UI 텍스트에 넣은 특수문자(`✕` U+2715, `−` U+2212 등)가 두부(□)로 뜬다. (2026-07-01)
  **원인:** 임베드 폰트(NanumGothic)에 그 글리프가 없음. 게임 폰트는 한글 + 기본 라틴/기호 위주라 장식 유니코드가 빠질 수 있다.
  **방지:** UI 문구는 **한글/기본 ASCII** 로. 아이콘이 필요하면 절차적 draw(`draw_line` 등)로 그리거나, 넣기 전 폰트에 글리프가 있는지 확인. (예: 가방 빼기를 `✕` 대신 "탭해서 빼기" 안내로 처리.)

## 씬 전환 / 노드 트리

- **증상:** `Parent node is busy adding/removing children, remove_child() can't be called at this time`.
  **원인:** 노드의 `_ready()` 안에서 `get_tree().change_scene_to_file()` 를 호출 — 트리가 씬을 붙이는 중이라 충돌.
  **방지:** `_ready` 중에는 씬을 바꾸지 않는다. 씬 전환과 상태 생성을 분리(예: `GameState.begin_run_in_place()` 는
  런만 만들고 전환 안 함). 꼭 _ready 에서 전환해야 하면 `change_scene_to_file.call_deferred(...)`.

- **증상:** 오버레이/배경(FULL_RECT Control)이 화면 중앙 정렬 안 되고 왼쪽 위(0,0)로 쏠리거나, 절차적 배경이 아예 안 그려짐. (2026-07-01)
  **원인:** `add_child` 직후 `_ready` 에선 그 Control 의 `size` 가 아직 0(레이아웃 패스 전). `CenterContainer` 는 size 0 이면 (0,0) 정렬, `_draw` 는 size 0 이면 아무것도 안 그린다.
  **방지:** `_ready` 에서 `size = get_viewport_rect().size` 로 즉시 확정하거나, `_draw` 에서 `get_viewport_rect().size` 를 쓴다. (Backdrop·SettingsPanel 이 이걸 겪음.)

- **증상:** 지도 이동 중 죽으면(예: 열병 "버틴다" 물 -5) 넘어간 단면의 사망 안내·[지도로] 화면 **위에 조사 튜토리얼**이 겹쳐 뜬다. (2026-07-03)
  **원인:** `Tutorial`(autoload CanvasLayer)이 **현재 씬 경로만** 보고 단계를 띄운다. 지도 튜토리얼을 이미 넘겨 `_step_idx` 가 expedition 단계인 채로 이동 중 사망→단면 전환되면, 씬이 일치해 "죽은 화면"인 줄 모르고 뜬다. **autoload 오버레이가 씬은 보는데 게임 상태(생존)는 안 봤다.**
  **방지:** 오버레이 게이트에 게임 상태도 넣는다 — `Tutorial._process` 에 `if GameState.current_run != null and not current_run.alive: _hide()`. 교훈: 씬 위에 얹는 autoload UI 는 씬 매칭만으론 부족, 그 씬이 "정상 상태"인지(사망·모달 등)도 게이트해야 한다.

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

## 배포 큐 / 타임아웃

- **증상:** push 후 웹 배포가 `Timeout reached, aborting`(Pages `deployment_queued` 에서 멈춤). (2026-07-02)
  **원인:** 짧은 간격으로 여러 번 push 하면 GitHub Pages 배포가 큐에 쌓여 concurrency 로 서로 경합·취소/타임아웃. **빌드 실패가 아니라 배포 대기 실패.**
  **방지:** 커밋을 **몰아서 한 번에 push**(코드·문서·세션로그를 연달아 개별 push 하지 말 것). 실패해도 다음 성공 배포가 최신 커밋을 통째로 배포하므로 최종 상태는 대개 정상. 빌드 자체가 ~19분(폰트·에셋) 걸리니 재확인은 배포 완료 후. `gh run list` 로 최신 success 커밋 확인.
  **오진·정정(2026-07-03):** `cancel-in-progress: true` 로 바꿨더니 **오히려 모든 배포가 실패**했다. Pages 배포는 `syncing_files` 도중 취소되면 그 배포가 "Deployment failed, try again later" 로 죽고, 이후 배포까지 연쇄로 실패한다(재실행해도 실패). → **`cancel-in-progress: false` 가 정답**(GitHub 공식 Pages 템플릿 기본값 — 진행 중 배포는 취소 말고 완주). 큐가 쌓여도 하나씩 완주하고 대기분은 최신만 남아 스킵되므로 손실 없음.
  **교훈:** 배포 큐 경합의 답은 "진행 중 취소"가 아니라 "완주 + 연속 push 자제(몰아서)". `syncing_files` 에서 죽으면 용량이 아니라 concurrency 취소를 의심(같은 크기 커밋이 하나는 성공/하나는 실패면 취소 경합).

- **증상(간헐적):** `cancel-in-progress: false` 인데도 `deploy` 잡이 `Deployment failed, try again later` 로 실패. 상태는 정상 흐름(waiting → queued → in_progress → failure)에 `description` 은 빈 문자열, ~10초 만에 죽는다. (2026-07-03)
  **원인:** 큐 경합·취소가 **아님**. build(export)는 성공하고 artifact 도 정상 업로드됐는데 `actions/deploy-pages` 가 GitHub Pages 백엔드 쪽 일시 장애로 실패. **같은 커밋·같은 워크플로가 직전엔 8초 만에 success** 였던 게 증거. 코드·설정 문제가 아니다.
  **방지·대응:** 손대지 말고 **재실행이 정답** — `gh run rerun <run-id> --failed`(실패한 deploy 잡만 다시 돌림, build artifact 재사용해 ~1분). 재실행 즉시 success 나면 GitHub 측 일시 장애로 확정. 워크플로/코드를 고치려 들지 말 것(멀쩡한 걸 건드려 새 문제만 만든다). 확인: `curl -s -o /dev/null -w "%{http_code}" https://soomin007.github.io/Otherside/` 가 200.
  **감별:** `Timeout reached`/`syncing_files` 에서 죽음 = 큐 경합(위 항목, 몰아서 push). `Deployment failed, try again later` + description 빈 채 in_progress 에서 즉사 = 일시 장애(재실행).

## 에셋 처리 (오디오·이미지 배치 변환)

- **증상:** 여러 파일을 ffmpeg 로 일괄 변환한 뒤 원본을 삭제했더니, **일부 파일이 변환 실패(출력 wav 미생성)했는데 원본까지 지워져 소스가 영구 손실**됐다. (2026-07-05, 효과음 crack·thirst)
  **원인:** ① 배치 루프에서 `2>$null` 로 ffmpeg 에러를 숨겨 실패를 못 봄. ② 실패 신호(volumedetect `max_volume` 미매칭 → gain 0.0, 특정 파일만 값이 이상)를 무시. ③ **출력 개수를 검증하기 전에** `Remove-Item *.mp3` 로 원본 일괄 삭제. 원본 mp3 가 손상/절단(생성기 결함)이면 변환·분석 둘 다 조용히 실패한다.
  **방지:** 일괄 변환 후 **원본 삭제 전에 출력 개수를 반드시 대조**(입력 N개 → 출력 N개인지). 에러를 숨기지 말고(`2>&1` 로 확인) 실패 파일을 로그. 이상 신호(gain 0.0 처럼 값이 튀는 것)는 그 파일을 의심. **소스는 최종 산출물 커밋·확인 뒤에 삭제**(또는 스크래치로 옮겨 보관). 손실되면 사용자 재생성뿐.
