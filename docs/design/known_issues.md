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

- **증상:** 문서/참고용으로 프로젝트 하위에 둔 png(캡처·핸드오프 아트)가 **웹 pck 에 실려 용량을 불림**. (2026-07-06 확인)
  **원인:** Godot 은 프로젝트 하위 모든 폴더의 리소스를 임포트해 export 에 포함한다. `docs/` 같은 순수 문서 폴더도 예외 없음 — png 를 두면 임포트돼 pck 에 들어간다.
  **방지:** 게임이 로드하지 않는 폴더(문서·핸드오프·원본 소스)에는 **빈 `.gdignore` 파일**을 둔다 — Godot 이 그 폴더+하위 전체를 임포트 대상에서 뺀다. 이 프로젝트는 `assets_src/`·`docs/handoffs/` 에 배치됨. (참고: `.gdignore` 는 Godot 임포트만 막고 git 추적과 무관 — 리포에서 빼려면 `.gitignore` 는 별도.)

- **증상:** 웹 배포본 BGM 에 규칙적 "타닥/틱" 클릭이 계속 깔린다(폰+이어폰서 뚜렷, **타이틀 정적 화면에서도**). 원본(Suno·파일)은 깨끗. (2026-07-06 사용자 제보)
  **원인:** export 프리셋 **Threads Support OFF**(Pages COOP/COEP 제약) → 웹에서 스트리밍 ogg(BGM)를 **메인 스레드가 실시간 디코드·믹싱**. 기본 출력 버퍼(`audio/driver/output_latency` 15ms)가 짧아 브라우저 오디오 콜백과 어긋나며 언더런 = 클릭. **오디오 파일 문제 아님**(파일을 2번 교체해도 무변화 → 재생 경로 문제로 확정).
  **진단 팁:** ① 원본 clean·배포본만 = 재생 단계. ② 파일 교체 무효과 = 내용 무관. ③ 정적 화면에서도 = 씬 부하 아님. → 남는 건 재생 경로(Threads/버퍼). ffmpeg `showwavespic`/`showspectrumpic` 로 파일을 "눈으로 들어" 원본과 대조하면 파일 vs 재생을 가른다.
  **시도·결과(2026-07-06, 전부 실기기 확인):**
  - ① 버퍼 확대 `driver/output_latency.web=60` → **무효**(타닥 그대로). 단순 언더런이 아니란 뜻.
  - ② `thread_support` ON → **Pages 에서 사이트가 안 뜸.** 실기기 에러: "The following features required to run Godot projects on the Web are missing: **Cross-Origin Isolation / SharedArrayBuffer**." `ensure_cross_origin_isolation_headers=true`(coi-serviceworker 우회)를 켜 놨는데도 이 환경(폰 크롬 시크릿)에선 미작동 → 즉시 revert. **GitHub Pages 는 커스텀 헤더(COOP/COEP)를 못 보내고 SW 우회도 불안정 → Pages+threads 는 사실상 불가.** `thread_support` 는 계속 OFF 로 둔다.
  **현재 채택(2026-07-06):** (b) **베드 BGM 을 브라우저 네이티브 SAMPLE 재생**(`PLAYBACK_TYPE_SAMPLE` + Master 버스)으로 바꿈(`AudioManager._bed`) → Godot 메인스레드 믹서를 우회. **실기기 결과: 타닥이 연속 → "가끔씩"으로 대폭 감소**(잔여는 아직 스트림인 SFX·발소리·바람·폭풍·엔딩곡에서 추정). Pages 자동배포 유지가 개발 중엔 최우선이라 **개발 내내 이 방식으로 가고, 완전 제거(threads)는 출시 임박에 호스트 이전으로 처리**하기로 확정.
  - ⚠️ SAMPLE+Master 트레이드오프(미보강): Music 볼륨 슬라이더가 베드에 **실시간** 반영 안 됨(씬 전환 때 `_apply_bed_volume` 재적용은 됨), 8분 뒤 루프 이음매(심리스 아님). 필요해지면 보강.
  **불가 확인:** (a) 호스트 이전(itch.io SAB·Cloudflare/Netlify `_headers`) = threads 가능 → 완전 깨끗하지만 매 배포 수동/별도 파이프라인이라 개발 단계엔 부적합. **교훈: 웹 배포본에서만 나는 오디오 잡음은 재생 경로(Threads/버퍼)부터 의심. GitHub Pages 에선 threads 를 켜지 말 것(SharedArrayBuffer 미지원 → 사이트가 죽는다). no-threads 에선 스트림 믹서 대신 SAMPLE 재생이 우회로.**
  **최종 확정(2026-07-06):** PC 웹 = 완전 깨끗, 폰 웹 = 타이틀 정적 화면에서도 가끔·씬 전환 때 조금 더 → **순수 폰 CPU 성능 문제로 확정**(약한 CPU 가 렌더·로직에 밀려 메인스레드 오디오 버퍼를 못 채움). 잔여 "가끔"은 아직 스트림인 SFX·바람 등 + 베드 SAMPLE 도 폰에선 드물게. **사용자 결정 = 웹은 지금(SAMPLE 우회)대로 두고, 근본 해결은 앱 출시 때.** `AudioManager` 는 `OS.has_feature("web")` 게이트로 **네이티브(앱) = 원래 스트림 재생 = 타닥 없음** 이 이미 보장됨(backlog "웹 BGM 폰 타닥" 참고). **이 타닥은 더 파헤치지 말 것 — 원인·결론 다 났다.**

- **증상:** 웹 로딩 화면(가로 안내 문구가 뜨는 그 화면)에 의도한 시간대별 로딩 이미지 대신 **타이틀 키아트만** 뜸. 로딩 이미지를 바꿔도 반영 안 됨(시크릿 탭에서도 동일). (2026-07-07)
  **원인:** `head_include` JS 가 로딩 배경을 `document.body` 에 깔았으나, Godot 웹 템플릿의 **불투명 `#status` 오버레이**(`background-color:#08070a`, full-rect)가 body 를 완전히 덮고 그 위 `#status-splash`(=boot_splash 키아트, fullsize)가 화면을 채운다. body 배경(로딩 webp)은 한 번도 보이지 않음. "이미지가 안 바뀐다"가 아니라 **배경 적용 대상이 처음부터 틀렸다.**
  **재발 방지:** 웹 로딩 배경은 `document.body` 가 아니라 **`#status` 자체**에 적용하고, 키아트를 감추려면 `#status-splash{display:none!important}`. `#status` 는 로딩 끝에 `remove()` 되므로 잔재 없음.

## 렌더링 / 텍스트

- **증상:** 대사·안내문이 "이어지는/군", "지나치/지 말게"처럼 **음절 중간에서 잘려** 줄바꿈된다. (2026-07-09 시장 대사 — 사용자 반복 지적)
  **원인:** `make_label`의 `AUTOWRAP_WORD_SMART`는 CJK를 음절 사이 아무 데서나 끊는다(Godot Label엔 keep-all 이 없다). 자동 줄바꿈에 맡긴 긴 한글 한 줄은 반드시 어딘가 어색하게 깨진다.
  **방지:** **사용자에게 보이는 여러 줄 한글(대사·내레이션·팝업)은 수동 `\n`으로 의미 단위 분할.** 한 줄 ~26자 이내(COLUMN_W 520·FS_BODY 기준, 30자부터 잘림). 오프닝 `SLIDES`·`Loadout.MARKET_PAGES`가 표준 예. 새 문구를 넣으면 스크린샷으로 실제 렌더 확인까지.

- **증상:** 한글 글씨가 뜨긴 하나 가장자리가 약간 깨져/계단져 보임(특히 폰·고해상도). (2026-07-01 1차 조치)
  **원인:** `rendering/textures/canvas_textures/default_texture_filter=0`(Nearest) + `stretch=canvas_items`/`aspect=expand`.
  폰 해상도마다 논리 캔버스(600폭)가 **비정수 배율**로 확대되는데, 폰트 글리프 아틀라스를 Nearest 로 샘플링하면 확대된 글자가 계단처럼 깨진다.
  **방지:** `default_texture_filter=1`(Linear). 이 프로젝트는 픽셀아트 스프라이트가 없어(전부 절차적 `draw_*`+폰트+부드러운 절차 텍스처) Linear 가 모든 요소에 더 낫다. 픽셀아트를 도입하면 그 스프라이트만 노드별 `texture_filter`로 Nearest 지정.
  여전히 흐리면 폰트 MSDF 임포트가 다음 레버(웹/GL Compatibility 실기기 검증 필수).
  **정정(2026-07-04): 이 줄이 project.godot 에서 사라져도 회귀 아님.** Godot 4.6 은 이 설정 **기본값이 이미 1(Linear)**이다(헤드리스 확인: 줄 없이도 실효값 1). 에디터에서 **F5/F6(씬 실행) 시 project.godot 를 재직렬화**하며 기본값과 같은 이 줄을 지우고 `[gui]`/`[display]` 순서를 바꾸기도 한다 — 실효값은 그대로라 무해. `M project.godot` 로 이 줄만 빠져 보여도 당황 말 것(무시하거나 `git checkout -- project.godot`). 명시는 문서·안전용으로 유지(HEAD 에는 =1 커밋됨).

- **증상:** UI 텍스트에 넣은 특수문자(`✕` U+2715, `−` U+2212 등)가 두부(□)로 뜬다. (2026-07-01)
  **원인:** 임베드 폰트(NanumGothic)에 그 글리프가 없음. 게임 폰트는 한글 + 기본 라틴/기호 위주라 장식 유니코드가 빠질 수 있다.
  **방지:** UI 문구는 **한글/기본 ASCII** 로. 아이콘이 필요하면 절차적 draw(`draw_line` 등)로 그리거나, 넣기 전 폰트에 글리프가 있는지 확인. (예: 가방 빼기를 `✕` 대신 "탭해서 빼기" 안내로 처리.)

- **증상:** 한글 라벨이 통째로 두부(□)로 깨짐 — 타이틀 통계 등. (2026-07-05)
  **원인:** 영문 전용 폰트(**Cinzel**)를 한글 텍스트 라벨에 지정(`FontVariation.base_font` 포함). 라틴 폰트엔 한글 글리프가 없고, Godot 은 브라우저와 달리 자동 폰트 fallback 이 없어 그대로 두부.
  **방지:** 한글이 들어가는 라벨엔 **한글 포함 폰트(마루부리=기본, `get_theme_default_font()`)** 를 base 로. Cinzel 은 **영문 로고·숫자·기호 전용.** FontVariation 으로 자간만 줄 때도 `base_font` 는 한글 폰트로 지정.

- **증상:** UI 미감(레이아웃·색·폰트 렌더)을 확인하려는데 헤드리스 스크린샷이 안 나온다(`get_viewport().get_texture().get_image()` 가 null). (2026-07-05)
  **원인:** `--headless` 는 dummy 렌더러라 실제 렌더 이미지가 없다.
  **방지:** **창 모드**로 잠깐 띄워 캡처 — 임시 `tools/shot.tscn`(Node: 대상 씬 instantiate → 몇 프레임 대기 → `get_image().save_png("user://..")` → quit)를 `godot --path . res://tools/shot.tscn`(--headless 없이) 로. 창이 1~2초 뜬다. 세이브 오염 방지(`begin_run_in_place` 는 save 안 함, 노드 클릭 금지). **외부 HTML 디자인 대조**는 `chrome --headless=new --screenshot=out.png --window-size=1280,720 --virtual-time-budget=6000 "file:///..."` 로 원본을 렌더해 픽셀 비교(짐작 금지).

- **증상:** 스톰 노드 단면에서 중앙 "폭풍의 눈"(메인 이벤트 마커)과 지점 버튼(f1 돌무더기·c2 바람 그늘)이 **완전히 포개짐**. (2026-07-07)
  **원인:** `SectionRun._default_main_at("storm")` = `Vector2(0.5, 0.42)` 인데 MapGraph 의 c2 `wall_burrow`·f1 `gate_cairn` spot `at` 이 정확히 같은 `(0.5, 0.42)` 로 저작됨. 메인 마커와 spot 이 같은 정규화 좌표계를 쓰는데 우연히 동일값이라 겹침.
  **재발 방지:** 노드 spot 의 `at` 은 그 kind 의 `_default_main_at`(blockage `(0.5,0.5)`·storm `(0.5,0.42)`·기타 `(0.5,0.55)`)과, 그리고 같은 노드 다른 spot 과 **최소 0.1 이상** 떨어뜨린다. 이 스윕은 `tests/core_smoke.gd` 의 `_test_spot_coordinates` 로 자동화됨(2026-07-15) — 지점을 추가·이동하면 core_smoke 만 돌리면 걸린다.

- **증상:** 단면 지점이 데스크톱(16:9)에선 지형지물 위에 정확히 앉는데 폰에선 어긋나 보임. (2026-07-15)
  **원인:** stretch aspect 가 `expand` 라 폰(약 20:9)에선 단면 아트가 cover 크롭으로 위아래가 잘린다. 지점 `at` 은 화면 정규화 좌표라 화면 위아래 끝일수록 그림과의 대응이 비율에 따라 밀린다(y 0.84 지점은 20:9 에서 그림 기준 약 0.1 어긋남).
  **재발 방지:** 웅덩이처럼 **점 같은 지형지물엔 y 0.3~0.75 안**에서 지점을 앉힌다. 화면 끝 좌표(y 0.8+)는 해안선·모래밭처럼 넓은 지형에만 쓴다. 확인은 스크린샷 드라이버를 16:9 와 폰 비율(1280×590) 두 번 돌려서.

## 씬 전환 / 노드 트리

- **증상:** `Parent node is busy adding/removing children, remove_child() can't be called at this time`.
  **원인:** 노드의 `_ready()` 안에서 `get_tree().change_scene_to_file()` 를 호출 — 트리가 씬을 붙이는 중이라 충돌.
  **방지:** `_ready` 중에는 씬을 바꾸지 않는다. 씬 전환과 상태 생성을 분리(예: `GameState.begin_run_in_place()` 는
  런만 만들고 전환 안 함). 꼭 _ready 에서 전환해야 하면 `change_scene_to_file.call_deferred(...)`.

- **증상:** 오버레이/배경(FULL_RECT Control)이 화면 중앙 정렬 안 되고 왼쪽 위(0,0)로 쏠리거나, 절차적 배경이 아예 안 그려짐. (2026-07-01)
  **원인:** `add_child` 직후 `_ready` 에선 그 Control 의 `size` 가 아직 0(레이아웃 패스 전). `CenterContainer` 는 size 0 이면 (0,0) 정렬, `_draw` 는 size 0 이면 아무것도 안 그린다.
  **방지:** `_ready` 에서 `size = get_viewport_rect().size` 로 즉시 확정하거나, `_draw` 에서 `get_viewport_rect().size` 를 쓴다. (Backdrop 등 FULL_RECT 오버레이가 이걸 겪음.)

- **증상:** 지도 이동 중 죽으면(예: 열병 "버틴다" 물 -5) 넘어간 단면의 사망 안내·[지도로] 화면 **위에 조사 튜토리얼**이 겹쳐 뜬다. (2026-07-03)
  **원인:** `Tutorial`(autoload CanvasLayer)이 **현재 씬 경로만** 보고 단계를 띄운다. 지도 튜토리얼을 이미 넘겨 `_step_idx` 가 expedition 단계인 채로 이동 중 사망→단면 전환되면, 씬이 일치해 "죽은 화면"인 줄 모르고 뜬다. **autoload 오버레이가 씬은 보는데 게임 상태(생존)는 안 봤다.**
  **방지:** 오버레이 게이트에 게임 상태도 넣는다 — `Tutorial._process` 에 `if GameState.current_run != null and not current_run.alive: _hide()`. 교훈: 씬 위에 얹는 autoload UI 는 씬 매칭만으론 부족, 그 씬이 "정상 상태"인지(사망·모달 등)도 게이트해야 한다.

- **증상:** 지도 이동 중 설정(일지)을 열었는데 **이동이 계속돼 노드 도착 → 씬 전환이 일지 밑에서 진행**, 다음 씬(단면)의 조사 튜토리얼 하이라이트가 **설정창 위에** 떴다. (2026-07-06 사용자 제보)
  **원인:** 일지(Bookmark, autoload 오버레이)는 화면에 얹히기만 할 뿐 밑의 세계를 안 멈췄다 — `Map._process` 이동이
  계속 흘러 도착·전환까지 진행. 게다가 Tutorial(레이어 110) > Bookmark(100) 이라 튜토리얼이 일지 위에 그려진다.
  **방지(이중):** ① **일지가 열리면 `get_tree().paused = true`** — "오버레이 밑에서 세계가 흐르는" 계열 전체 차단.
  덮으면 해제. 상시 동작이 필요한 autoload(Bookmark·AudioManager·Transition·Tutorial·Debug)는 전부
  `PROCESS_MODE_ALWAYS` 라 일지 조작·음악·전환은 그대로. ② Tutorial 게이트에 `Bookmark.is_open()` 추가(일지 위
  겹침 자체 금지) + 전환 중(`Transition.busy()`) 일지 열기 금지. **교훈: 전체 화면 모달을 얹을 땐 "밑의 세계가
  계속 흐르는가"를 반드시 물을 것 — 새 모달·오버레이 추가 시 트리 pause 또는 진행 게이트를 명시적으로 결정.**
  (참고: 상황 카드·남기기는 이동을 스스로 멈추는 설계, 가방 인벤토리는 "이동은 계속" 이 의도된 예외.)

- **증상:** 게임 도중(지도)에 일지 설정에서 "저장 데이터 지우기"를 실행하면 **화면이 완전히 무반응**(폰 웹에선 "게임이 죽었다"로 보임). 에러는 0. (2026-07-06 사용자 제보)
  **원인:** `reset_save()` 가 `current_run = null` + `record_seen = false` 로 만든 채 **그 씬에 그대로 남겨둠.**
  지도의 모든 입력(노드 탭·가방·남기기)이 null 가드에 걸려 조용한 no-op 이 되고, 일지 리본(record_seen 게이트)마저
  사라져 되돌아갈 길이 없다 — 크래시가 아니라 **소프트락**. 가드는 크래시를 막지만 소프트락은 못 막는다.
  **방지:** 상태를 파괴하는 동작(세계 지우기)은 **그 상태에 기대는 씬을 함께 정리**한다 — `Bookmark._do_reset` 이
  타이틀로 라우팅(DEV 오버레이 "세이브 초기화 → 타이틀"과 같은 패턴). 재현·검증 팁: 이런 버그는 "프로세스가
  살아있나"만으론 못 잡는다 — **"조작이 먹나"까지 확인**(씬 라우팅 결과를 assert).

- **증상:** 웹(데스크톱 브라우저)에서 지도 이동 중 상황 카드가 연속으로 뜰 때, **두 번째 카드가 화면 하단으로 치우쳐** 뜬 사례. (2026-07-06 사용자 제보, 간헐)
  **원인(추정 — 네이티브 재현 불가):** CenterContainer 안 카드의 오토랩 라벨이 최소 높이를 늦게 반영하는
  **웹 레이아웃 레이스.** 데스크톱·폰 종횡비 재현 드라이버 3종 전부 정중앙(기하 구조는 건전).
  **방지:** 모달 표시 직후 `UITheme.recenter_modal.call_deferred(panel)` — 카드 크기를 최소로 리셋하고
  컨테이너 재정렬(정상일 땐 무해한 no-op). 지도/단면 상황 카드·결과 팝업 3곳 배선. **웹에서 재발하면
  스크린샷 확보 후 이 항목 갱신**(그때는 레이스가 아니라 다른 원인).

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
  **자동화(2026-07-05):** `deploy.yml` push 트리거에 **`paths-ignore`**(`**.md`·`docs/**`·`session_logs/**`·`ACTIVE_WORK.md`·`.gitignore`)를 넣었다. **문서·세션로그만 바뀐 push 는 배포가 아예 안 돈다** → 손으로 `[skip ci]` 안 적어도 자동 스킵되고, 배포 횟수·큐 경합·불필요한 실행이 줄었다(웹 빌드에 안 들어가는 것들이라 사이트 영향 0). 코드·에셋이 하나라도 섞이면 정상 배포. (수동 `[skip ci]` 도 여전히 native 로 유효 — 둘이 상호보완.)
  **오진·정정(2026-07-03):** `cancel-in-progress: true` 로 바꿨더니 **오히려 모든 배포가 실패**했다. Pages 배포는 `syncing_files` 도중 취소되면 그 배포가 "Deployment failed, try again later" 로 죽고, 이후 배포까지 연쇄로 실패한다(재실행해도 실패). → **`cancel-in-progress: false` 가 정답**(GitHub 공식 Pages 템플릿 기본값 — 진행 중 배포는 취소 말고 완주). 큐가 쌓여도 하나씩 완주하고 대기분은 최신만 남아 스킵되므로 손실 없음.
  **교훈:** 배포 큐 경합의 답은 "진행 중 취소"가 아니라 "완주 + 연속 push 자제(몰아서)". `syncing_files` 에서 죽으면 용량이 아니라 concurrency 취소를 의심(같은 크기 커밋이 하나는 성공/하나는 실패면 취소 경합).

- **증상(간헐적):** `cancel-in-progress: false` 인데도 `deploy` 잡이 `Deployment failed, try again later` 로 실패. 상태는 정상 흐름(waiting → queued → in_progress → failure)에 `description` 은 빈 문자열, ~10초 만에 죽는다. (2026-07-03)
  **원인:** 큐 경합·취소가 **아님**. build(export)는 성공하고 artifact 도 정상 업로드됐는데 `actions/deploy-pages` 가 GitHub Pages 백엔드 쪽 일시 장애로 실패. **같은 커밋·같은 워크플로가 직전엔 8초 만에 success** 였던 게 증거. 코드·설정 문제가 아니다.
  **방지·대응:** 손대지 말고 **재실행이 정답** — `gh run rerun <run-id> --failed`(실패한 deploy 잡만 다시 돌림, build artifact 재사용해 ~1분). 재실행 즉시 success 나면 GitHub 측 일시 장애로 확정. 워크플로/코드를 고치려 들지 말 것(멀쩡한 걸 건드려 새 문제만 만든다). 확인: `curl -s -o /dev/null -w "%{http_code}" https://soomin007.github.io/Otherside/` 가 200.
  **자동화(2026-07-05):** `deploy` 잡에 **자동 재시도(최대 3회, 20초·45초 백오프)**를 넣었다(`deploy.yml`). 일시 장애면 2·3차에서 조용히 성공해 **실패 메일이 안 온다** → 이제 손으로 rerun 할 일이 거의 없다. 그래도 3차까지 다 실패하면(=진짜 문제) 잡이 실패하며 메일이 온다 — 그때만 조사. 즉 "메일이 온다 = 진짜 봐야 할 실패"로 신호가 깨끗해졌다.
  **감별:** `Timeout reached`/`syncing_files` 에서 죽음 = 큐 경합(위 항목, 몰아서 push). `Deployment failed, try again later` + description 빈 채 in_progress 에서 즉사 = 일시 장애(재실행).

## 에셋 처리 (오디오·이미지 배치 변환)

- **증상:** 여러 파일을 ffmpeg 로 일괄 변환한 뒤 원본을 삭제했더니, **일부 파일이 변환 실패(출력 wav 미생성)했는데 원본까지 지워져 소스가 영구 손실**됐다. (2026-07-05, 효과음 crack·thirst)
  **원인:** ① 배치 루프에서 `2>$null` 로 ffmpeg 에러를 숨겨 실패를 못 봄. ② 실패 신호(volumedetect `max_volume` 미매칭 → gain 0.0, 특정 파일만 값이 이상)를 무시. ③ **출력 개수를 검증하기 전에** `Remove-Item *.mp3` 로 원본 일괄 삭제. 원본 mp3 가 손상/절단(생성기 결함)이면 변환·분석 둘 다 조용히 실패한다.
  **방지:** 일괄 변환 후 **원본 삭제 전에 출력 개수를 반드시 대조**(입력 N개 → 출력 N개인지). 에러를 숨기지 말고(`2>&1` 로 확인) 실패 파일을 로그. 이상 신호(gain 0.0 처럼 값이 튀는 것)는 그 파일을 의심. **소스는 최종 산출물 커밋·확인 뒤에 삭제**(또는 스크래치로 옮겨 보관). 손실되면 사용자 재생성뿐.

- **증상:** BGM ogg 안에 **theora 영상 스트림이 딸려 들어감** — 오디오 파일인데 ffprobe 상 video(theora 360×360)+audio(vorbis) 두 스트림. 폰+이어폰에서 배경음악에 규칙적 "타닥타닥" 잡음 원인 의심. (2026-07-06)
  **원인:** mp3 원본에 박힌 **앨범 커버 이미지**를, `ffmpeg -i in.mp3 -c:a libvorbis ... out.ogg`(=`-vn` 없음)로 변환할 때 ffmpeg 가 그 커버를 theora 영상으로 트랜스코딩해 ogg 에 함께 mux 한다. 오디오 페이지 사이에 영상 페이지가 인터리브된다(용량은 대개 작지만 명백한 결함).
  **방지:** mp3→ogg 변환은 **반드시 `-vn`**(영상 제외): `ffmpeg -i in.mp3 -vn -c:a libvorbis -q:a 2 out.ogg`. 변환 후 `ffprobe -show_entries stream=codec_type` 로 **audio 만** 있는지 확인. (godot-audio-pipeline 스킬 §2 에 반영함. 이미 섞인 파일은 원본에서 `-vn` 로 재인코딩해 교체.)

## 프로세스 / 도구

- **증상:** `godot --headless --script check.gd` 로 게임 스크립트를 `load()` 검증하면 `Identifier not found: GameState/AudioManager` 컴파일 에러. (2026-07-05)
  **원인:** `--script` 모드(커스텀 SceneTree)에선 **autoload 싱글톤이 등록되지 않아** autoload 를 참조하는 모든 스크립트가 가짜로 컴파일 실패한다.
  **방지:** 파싱·컴파일 검증은 **씬을 직접 띄워서**(`godot --headless --path . --quit-after 5 <scene.tscn>`) 한다. 런타임 로드 전용 스크립트(Ending 등)는 임시 .tscn 을 만들어 붙이고 검증 후 삭제.

- **증상:** 웹 배포본에서 **오디오가 완전 무음**(자동재생 정책과 무관 — 한참 플레이해도 안 남). 데스크톱은 정상. (2026-07-05 폰 확인)
  **원인:** 웹(스레드 없음) 빌드의 기본 오디오 재생은 "샘플"(JS 쪽 Web Audio 버퍼) 방식인데, 이 경로는 **코드로 만든 커스텀 버스(Music/SFX)로 보낸 소리를 재생하지 못한다.** 버스 분리 직후 첫 웹 테스트에서 드러남.
  **방지:** ① `AudioStreamPlayer.playback_type = PLAYBACK_TYPE_STREAM` 강제(네이티브 믹서 경로 — 버스·크로스페이드 전부 정상). ② 버스는 코드 생성 대신 `default_bus_layout.tres` 로 등록(시동 때 로드, 코드 생성은 폴백으로만). **오디오 구조를 바꾸면 반드시 웹 실기기에서 소리 확인.**

- **증상:** 웹에서 붓글씨(나눔손글씨) 표제의 **가운뎃점(·)이 두부(□)**. 데스크톱은 정상. (2026-07-05, 일지 설정 챕터 "화면 · 이야기")
  **원인:** 붓 폰트에 `·` 글리프가 없음. 데스크톱은 시스템 폰트가 폴백으로 메우지만 웹은 임베드 폰트뿐이라 두부.
  **방지:** 붓 폰트(BRUSH_FONT) 텍스트엔 **한글·기본 문장부호만**. 특수문자(·—…† 등)를 쓰려면 본문 폰트(마루부리)로 확인 후. 새 표제 추가 시 웹에서 글리프 확인.
  **해결(2026-07-07):** 근본 해결 — `UITheme._static_init` 이 붓 폰트에 **MaruBuri 폴백**을 지정(`BRUSH_FONT.fallbacks`). 붓에 없는 글리프(·—…←→ 및 이후 무엇이든)는 두부 대신 명조로 렌더된다. 커버리지 감사는 `tools/check_font_coverage.py`(MaruBuri 미포함=FAIL) — 배포 전 실행. 스캔 결과 붓 미포함은 이 5개뿐, MaruBuri 는 표시 문자 전부 커버.

- **증상:** 웹에서 "탭 전환·최소화 시 음소거" 같은 백그라운드 반응을 GDScript(포커스 알림)로 구현했는데 전혀 동작 안 함. (2026-07-06)
  **원인:** 탭이 숨겨지면 브라우저가 렌더 루프(requestAnimationFrame)를 정지 → **엔진 프레임이 멈춰 GDScript 가 실행될 기회가 없다.** 오디오만 독립적으로 계속 재생.
  **방지:** 백그라운드 상태에 반응해야 하는 동작은 **export 프리셋 head_include 의 페이지 JS**로(예: `visibilitychange` → AudioContext suspend/resume). 엔진 안 코드로는 불가능.

- **증상:** `DisplayServer.screen_set_orientation` 으로 웹 가로 잠금 시도 — 아무 일도 안 일어남. (2026-07-06 실기기)
  **원인:** 웹 DisplayServer 에 해당 기능 구현이 없음(안드로이드/iOS 네이티브 전용).
  **방지:** 웹에선 `JavaScriptBridge.eval("screen.orientation.lock(''landscape'')...")` 로 브라우저 API 직접 호출. 전체화면 상태에서만 받아들여지므로 전체화면 진입 후 지연 호출·재시도.

- **증상:** 커밋 메시지 첫 줄/끝에 `@` 가 리터럴로 섞임(예: `@ fix(...): ...` … 끝줄 `@`). (2026-07-08)
  **원인:** **Bash 도구는 Git Bash(POSIX sh)** 인데 PowerShell here-string 문법 `git commit -m @'…'@` 를 씀 → `@` 가 그냥 인자 문자로 붙는다(PowerShell 전용 문법을 sh 에서 오용).
  **방지:** Bash 도구에서 여러 줄 커밋 메시지는 **POSIX heredoc** 으로: `git commit -F - <<'EOF'` … `EOF`(닫는 EOF 는 0열). `@'…'@` 는 PowerShell 도구에서만. 한 번 push 된 메시지는 force-push 정정이 auto 모드에서 막히니 **처음부터 올바른 문법으로**.

- **증상:** `project.godot` config/description 에 확정 정체성과 어긋난 옛 문구("후대는 곧 나 자신이며, 미래의 나에게")가 살아 있었다. (2026-07-09)
  **원인:** 정체성이 "총괄자+매 원정 다른 대장, 흔적=이전/다음 원정대"로 확정(`00_START_HERE` §9.1)됐는데, 초기에 쓴 프로젝트 메타 설명은 "과거의 나" 모델 그대로 방치. 코드·기획서 본문은 갱신했어도 메타데이터·주변 카피는 놓치기 쉽다. (같은 세션에서 원정 주기 "매년"도 여러 파일에 흩어져 있었음.)
  **방지:** 핵심 설정(정체성·주기 등)을 바꾸면 본문뿐 아니라 `project.godot`·`README`·`handoffs/*`·인게임 크레딧까지 **전수 grep 으로 훑는다**(예: "매년"·"후대는 곧 나"). 한 계열 고침은 한 번에 — 부분만 고치면 새 드리프트를 남긴다.

- **증상:** 외부 테스트 공략이 "시체(죽은 자리)도 재회 카운트에 든다"고 안내("다리 1 + 시체 1개당 1 + 남긴 것 1개당 1"). 따라 하면 흔적이 임계에 못 미쳐 재회 대신 순환이 뜬다. (2026-07-09)
  **원인:** 재회 카운트(`player_trace_count`)는 `traces`의 비-seed 항목만 센다. 죽음은 `record_death`가 `deaths` 배열에만 넣고 `traces`엔 안 넣는다 → **시체는 재회에 0 기여**(정보·정서 전용, 의도된 설계). "죽은 자리도 흔적"이라는 서사적 표현을 카운트 규칙으로 오독.
  **방지:** 재회 카운트 = *남기기(leave_trace)로 남긴 것 + 로프 고정 다리*(비-seed)뿐. 죽음은 절대 안 낀다. "흔적"을 셀 때 `deaths`(죽은 자리)와 `traces`(남긴 것)를 구분. 같은 정정에서 임계 8→4(무사 도달 준비 ~3런 동안 자연히 차게 = 그리드 대신 지식이 관문). 공략(외부 HTML)은 무게·마을 결정까지 정해지면 한 번에 재발행 예정.
  **⚠ 갱신(2026-07-10):** 흔적 카운트 축(`REUNION_TRACES`) 자체가 폐기됐다. 현행 재회 = **기림 2 + 낙오자 2 구조(이번 런에 데리고 닿기) + 온전한 도달(행렬 손실 0)** — 기획서 §3. 옛 공략·문서의 "흔적 4개" 안내는 전부 무효. 공략 재발행 시 세 축 기준으로.

- **증상:** 64비트 정수(RNG seed/state)를 JSON 세이브에 그대로 실으면 로드 후 값이 미묘하게 달라진다(결정론 깨짐, 재현 불가 버그로 보임). (2026-07-10, 이어하기 저장 구현 중 사전 차단)
  **원인:** `JSON.parse_string` 은 모든 숫자를 double 로 읽는다 — 2^53 을 넘는 정수는 정밀도가 깨진다. RNG state 는 풀 64비트 값이라 거의 항상 걸린다.
  **방지:** 큰 정수는 **문자열로 직렬화**하고 `String.to_int()` 로 복원(`ExpeditionRun.to_dict` 의 rng_seed/rng_state 참고). 복원 순서도 중요 — seed 대입이 state 를 파생시키므로 **seed 먼저, state 나중**. 일반 int 필드도 JSON 왕복 후엔 float 이므로 `int()` 명시 캐스팅.

- **증상(알려진 엣지, 수용):** 죽음 화면에서 "남기기"를 누르기 전에 탭이 죽으면 그 남기기 기회는 사라진다(죽음·낙오자 수확은 이미 기록됨 — 이어하기 저장은 살아 있는 런만 싣는다). (2026-07-10)
  **원인:** 죽은 런은 되살릴 수 없어야(서스펜드 원칙) 죽는 순간 슬롯이 비워진다. 죽음 화면의 남기기는 그 사이 좁은 창.
  **방지:** v1 수용(창이 몇 초로 좁고, 남기기는 보너스). 불만 나오면 "죽은 런 + 남기기 미사용" 상태만 따로 실어 죽음 화면 복원을 검토.

- **증상:** 부팅 스모크(`--headless --quit-after 5`) 종료 시 `WARNING: ObjectDB instances leaked` + `ERROR: 2 resources still in use`. "에러/경고 0" 기준을 형식상 어긴다. (2026-07-11 확인, 변경 없는 HEAD 에서도 재현)
  **원인:** 타이틀 BGM(`assets/bgm/Sand Erases the Words.ogg`)이 재생 중인 채 `--quit-after` 가 프로세스를 끊어 `AudioStreamPlaybackOggVorbis` 등 오디오 재생 객체가 해제 순서를 못 탄 것(--verbose 로 확인). 실행 중 누수가 아니라 종료 시점 잔류 — 게임플레이·웹 배포에 영향 없음.
  **방지:** 부팅 스모크에서 이 두 줄(오디오 잔류)만은 무해로 간주하고, 그 외 에러/경고가 새로 생겼는지를 본다. 없애려면 AudioManager 에 종료 훅(`NOTIFICATION_WM_CLOSE_REQUEST` 등에서 stop)을 다는 선택지가 있으나 급하지 않음.

- **증상:** 막간 삽화 프롬프트(§15)를 세로 1080×1920 + 가로 16:9 두 벌(6장)로 작성 — 게임은 가로 고정이라 세로판이 전부 불필요했다. 사용자 지적으로 정정. (2026-07-11)
  **원인:** 세션 시작 루틴 생략 — `00_START_HERE.md` §의 "방향 = 가로 고정(2026-07-05), 모든 풀스크린 아트 16:9"를 안 읽고, 오프닝 에셋의 옛 세로+가로 이중 패턴(가로 고정 결정 이전 유물)을 관성적으로 따랐다.
  **방지:** 풀스크린 아트 프롬프트는 **16:9 가로 한 장만**(세로판·`_가로` 접미사 이중화 금지 — 24~28 가로판은 결정 이전 유물). 질문 답변으로 시작한 세션이라도 작업으로 전환되는 순간 시작 루틴(특히 `00_START_HERE.md`)을 밟는다.

- **증상:** 폰(터치)에서 지도 흔적 아이콘을 탭해도 표식 두루마리가 **안 열림**(데스크톱은 정상). (2026-07-12 사용자 제보 2회)
  **원인:** Godot 은 기본으로 터치를 마우스로도 에뮬레이트한다(`emulate_mouse_from_touch`) — 탭 한 번에
  `InputEventScreenTouch` 와 에뮬레이트된 `InputEventMouseButton` 이 **둘 다** `_gui_input` 에 들어온다.
  버튼(Control)은 내부에서 중복을 걸러주지만, **커스텀 `_gui_input` 의 토글 로직은 두 번 실행**돼
  두루마리가 열리자마자 닫혔다(같은 흔적 재탭 = 접기 토글). 노드 선택은 `_moving` 가드가 우연히 중복을 삼켜 멀쩡해 보였다.
  **방지:** 터치 기기(`DisplayServer.is_touchscreen_available()`)에선 커스텀 `_gui_input` 에서 마우스 이벤트를
  무시하고 ScreenTouch/ScreenDrag 만 처리한다(Map._gui_input 상단 가드). **토글류 커스텀 입력을 만들면 반드시
  터치 이중 이벤트를 의심할 것** — "폰에서만 안 된다 + 토글"이면 십중팔구 이것.

- **증상:** 폰 웹에서 일지 확인 페이지("타이틀로 나갈까")의 "나간다" 버튼이 **완전 무반응**(일지도 안 닫힘). 같은 페이지 "아니, 머문다"는 눌림. 데스크톱은 정상. (2026-07-14 사용자 제보)
  **원인(이중):** ① 웹은 전체화면 진입·브라우저 바 등으로 뷰포트 리사이즈가 잦은데, 일지 `_box_r` 크기가 낡은 채 남는 경우가 있다(리사이즈가 넘김(`_flipping`) 중 도착하면 `_on_viewport_resized` 가 그냥 버렸음). 일반 챕터는 내용이 위 정렬이라 안 보이지만, **확인 페이지만 세로 중앙 정렬(EXPAND 스페이서)이라 버튼이 페이지 바닥까지 가라앉는다.** ② 가라앉은 자리는 확인 페이지가 비워 둔 `_footer_r` 컨테이너 밑 — **Godot Container 의 기본 `mouse_filter=PASS` 는 "투명"이 아니다.** PASS 는 픽킹을 가로채 *부모 체인으로만* 올려보내므로, 밑에 깔린 형제(버튼)는 탭을 영영 못 받는다. 크래시·에러 0 의 조용한 죽은 영역.
  **재현·진단:** 데스크톱(에디터)에선 7가지 조합(마우스/터치×지도/단면×연출0)으로도 재현 불가. **배포 웹 빌드를 headless Chrome + CDP(터치 에뮬레이션·1560×720)로 몰고, IndexedDB(`/userfs`·`FILE_DATA`)에 세이브를 시딩**해 사용자 상태를 복제하니 첫 시도에 재현. 뷰포트를 강제 리사이즈하면 버튼이 제자리로 튀어 오름(= 낡은 배치 확정).
  **방지:** ① 형제 위에 겹칠 수 있는 빈/장식 컨테이너는 `MOUSE_FILTER_IGNORE`(자식 버튼은 계속 받는다 — 픽킹은 컨테이너 몸통만 빠짐). ② 리사이즈를 게이트로 버리지 말 것 — 미뤘다가(`_relayout_wanted`) 게이트 해제 시 반영. ③ 세로 중앙 정렬 페이지는 열기 직전 `_layout_book()` 재동기화. **교훈: "폰 웹에서만 무반응 + 에러 0"이면 (a) 컨테이너 PASS 픽킹 가로채기, (b) 리사이즈로 낡은 배치를 의심. 웹 전용 버그는 CDP+세이브 시딩으로 재현 가능하다.**

- **증상(프로세스 실수):** 사용자가 만들어 옮겨둔 GPT 원본들을 투명 변환 뒤 **삭제**했다(2026-07-12). 그 여파로 리본(69)이 사라졌는데 "미생성"으로 추측했고, 지적받자 이번엔 위치 태그(65)를 리본으로 오인해 65를 파괴할 뻔했다(사용자 정정 두 번 만에 복구).
  **원인:** ① 원본 보관 컨벤션(`assets_src/arts_originals/` — pck 에 안 실리는 소스 폴더)이 이미 있는데 확인하지 않고 "웹 용량"만 생각해 지웠다. ② 파일 수가 발주 목록과 안 맞을 때 사용자에게 묻지 않고 두 번이나 추측으로 메웠다.
  **방지:** 사용자 제공 원본은 **절대 삭제하지 않는다** — 변환 후 `assets_src/arts_originals/` 로 이동. **개수·식별이 목록과 안 맞으면 추측하지 말고 사용자에게 확인**한다.
