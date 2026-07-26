# itch 업로드 폴더 — 여기 있는 것만 쓰면 된다

페이지 개설에 필요한 재료 전부(빌드 zip 포함). 규칙·이유가 궁금하면 `docs/handoffs/itch_핸드오프.md`.
(2026-07-26, 베타 0.3 기준. `.gdignore` 는 Godot 이 이 폴더를 게임에 안 싣게 하는 장치 — 지우지 말 것.)

## ⚠️ 복붙 주의

- 소개문은 `소개문_영어.txt`·`소개문_한국어.txt` 를 **통째로 복사**해 붙인다.
  (핸드오프 md 의 `>` 는 인용 표시일 뿐 붙여넣는 내용이 아니다.)
- 소개문 자리는 **일부 HTML 태그도 받는다**(h2·b·img·a·hr 등 허용 목록만, script/style 은 삭제됨).
  구조 잡힌 본문을 원하면 `소개문_본문.html` 의 내용을 쓰고, 편집기에 HTML 입구가 안 보이면
  txt 를 붙인 뒤 툴바(제목·굵게)로 같은 구조를 만들면 된다. 효과는 동일하다.

## 순서 (약 20분)

1. itch.io 가입 → Dashboard → Create new project
2. Title: `See you on the other side` · URL: `see-you-on-the-other-side`
3. Kind of project: **HTML** · Pricing: **No payments** (후원 금지 — 라이선스, 핸드오프 §0)
4. Uploads: 이 폴더의 `syotos_web_v0.3.zip` 업로드 → "This file will be played in the browser" 체크
5. Embed: 1280 × 720 · Fullscreen button ✔ · Mobile friendly ✔ (Orientation: Landscape)
6. Details: 소개문 복붙(영어 먼저, 아래 한국어) · Genre: Adventure · Tags: roguelite, narrative,
   turn-based, atmospheric, singleplayer, 2d, godot, desert, short, korean
   · **AI generated content: Yes**(그래픽·오디오 명시) · Language: English, Korean
7. Cover image: `커버_630x500.png` · Screenshots: `스크린샷_01~06.png` 6장
8. **Save & view page → 페이지에서 "Edit theme"** (아래 "배너는 어디서 넣나" 참고) → 배너·배경·색 적용
9. Draft(비공개) 상태로 폰·PC 검증(핸드오프 §7 — 특히 재업로드 후 세이브 유지)
10. 이상 없으면 Public

## 배너는 어디서 넣나 (입력 폼에 없는 이유)

배너·배경·색은 **Details 입력 폼이 아니라 페이지 테마 편집기**에 있다:
프로젝트를 저장하고 **페이지 보기(View page)** 로 가면 상단에 **"Edit theme"** 버튼이 뜬다.
누르면 왼쪽에 테마 패널이 열린다 — 여기서:

- **Banner**: `배너_960x400.png` 업로드 · Align Center (로고가 들어 있으니 텍스트 제목 표시는 꺼도 된다.
  가장자리가 #141017 로 녹아 있어 네모로 딱 잘려 보이지 않는다 — 교체 후 반드시 재업로드)
- **Background image**: `배경_2560x1440.png` · Repeat None · Align Center · **Fixed ✔ (핵심!)**
  Fixed = 배경을 문서가 아니라 화면에 고정 — 본문이 아무리 길어도 배경은 항상 화면만큼만 보인다
  (반복이 필요 없는 이유). itch 는 배경을 창 크기에 맞춰 늘려 주지 않으므로(원본 고정) 이 파일은:
  ① **그림 띠는 좌우 끝 720px 씩만, 가운데 1120px 는 민바닥** — 배경도 본문 칸도 둘 다 화면
  중앙 정렬이라, 창 폭과 무관하게 본문(중앙 ~750px) 양옆에 항상 어둠 채널이 남는다
  ("가운데 어두운 부분을 넓혀야" 피드백 반영. 왼쪽 = 노을의 대장, 오른쪽 = 폭풍 벽).
  ② 모든 가장자리를 **#141017 로 완전 용해** — 작은 창에서는 여백부터 잘려 나가는데
  잘린 자리가 전부 같은 색이라 어떤 해상도에서도 경계선이 없다.
  ③ **위쪽은 특히 길게 용해** — 페이지 상단(배너 높이)에선 양옆도 거의 배경색이라 배너의 녹은
  가장자리와 색이 이어지고, 그림은 스크롤 중간부터 배어 나온다(상단 색 안 맞는다는 피드백 반영).
- **Colors**: **전부 `#141017` 로 통일** — BG · BG 2(본문 칸, Alpha 오른쪽 끝 불투명) 모두.
  배경 그림의 용해 색과 같아서 경계선이 어디에도 안 생긴다. Text `#F6ECD4` · Link `#D6B278`
- **Font**: Serif · Size Large
- Screenshots 표시 위치(사이드바)도 여기서 정한다
- **맨 아래 빨간 Save 를 눌러야 확정된다.** ⚠️ **이미지를 재업로드하면 Fixed 같은 옵션이
  초기화될 수 있다** — 배경을 갈아 끼운 뒤 스크롤에 배경이 밀려 올라가면 Fixed 를 다시 체크(2026-07-26 실사례).
- **Embed BG**: `임베드배경_1280x720.png` — 게임 실행 칸(Run game 박스)이 기본 회색 상자라
  페이지에서 제일 이질적이다. 이걸 올리면 실행 전 대기 칸도 세계의 사막으로 바뀐다(권장).

## 이미지는 어디에 올리나 — 둘 다 쓴다

- **Screenshots 칸**: `스크린샷_01~06.png`. 확대(라이트박스)·정돈된 배치가 공짜로 따라온다.
- **본문(Description)**: 편집기의 이미지 삽입 버튼으로 다음을 끼운다(언더테일류 "화려한 페이지"의
  정체가 바로 이 본문 삽입 이미지들이다). 셋 다 가장자리가 본문 칸 색으로 녹아 있어 액자 없이 앉는다:
  - `움짤_지도이동.gif` — 영어 소개 첫 문단(이탤릭 한 줄) 아래
  - `본문띠_남긴다.png` — "one single item" 문단 아래(남기기 = 핵심 메커닉 그림)
  - `본문띠_행렬.png` — 영어 소개 끝(Feedback 줄 아래), 영/한 섹션 사이 구분 그림 겸용

## 빌드

- `syotos_web_v0.3.zip` (이 폴더, git 미추적) — 0.3 = 언어 전환 즉시 적용 + 설정 재편(언어가 첫 화면).
- 재빌드가 필요하면: `project.godot` 의 `config/version` 올리기 → 프로젝트 루트에서
  `godot --headless --path . --export-release "Web" build/web/index.html` →
  `Compress-Archive -Path build\web\* -DestinationPath itch_업로드\syotos_web_v0.3.zip -Force`
- itch 재업로드는 기존 파일 교체로(경로가 바뀌어 캐시 문제는 없다).
