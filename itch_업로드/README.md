# itch 업로드 폴더 — 여기 있는 것만 쓰면 된다

페이지 개설에 필요한 재료 전부(빌드 zip 포함). 규칙·이유가 궁금하면 `docs/handoffs/itch_핸드오프.md`.
(2026-07-26, 베타 0.2 기준. `.gdignore` 는 Godot 이 이 폴더를 게임에 안 싣게 하는 장치 — 지우지 말 것.)

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
4. Uploads: 이 폴더의 `syotos_web_v0.2.zip` 업로드 → "This file will be played in the browser" 체크
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

- **Banner**: `배너_960x400.png` 업로드 · Align Center (로고가 들어 있으니 텍스트 제목 표시는 꺼도 된다)
- **Background image**: `배경_1920x1080.png` · Repeat None · Align Center · **Fixed ✔ (핵심!)**
  Fixed 를 안 켜면 그림이 문서 맨 위에 한 번 깔리고 스크롤하면 밀려 올라가 버린다(2026-07-26 실화면 확인).
  Fixed 를 켜면 화면에 고정되어 페이지 어디를 읽어도 배경이 깔려 있다.
- **Colors**: BG `#1B1410`(배경 그림 가장자리와 이어지는 따뜻한 어둠 — 그림 밖 여백과 경계선이 안 생긴다)
  · BG 2(본문 칸) `#141017` + **BG2 Alpha 오른쪽 끝(불투명)** · Text `#F6ECD4` · Link `#D6B278`
- **Font**: Serif · Size Large
- Screenshots 표시 위치(사이드바)도 여기서 정한다
- **맨 아래 빨간 Save 를 눌러야 확정된다** — 본문 칸이 여전히 흰 바탕에 검은 글씨면
  Save 를 안 눌렀거나 BG2/Text 가 아직 안 먹은 상태다. Save → 새로고침으로 확인.
- (선택) **Embed BG**: 게임 실행 칸(Run game 박스)의 배경 — 밋밋하면 `배경_1920x1080.png` 를 여기도.

## 이미지는 어디에 올리나 — 둘 다 쓴다

- **Screenshots 칸**: `스크린샷_01~06.png`. 확대(라이트박스)·정돈된 배치가 공짜로 따라온다.
- **본문(Description)**: `움짤_지도이동.gif` 를 소개문 첫 문단 아래에 편집기의 이미지 삽입 버튼으로
  넣는다(0.3MB). 언더테일류 "화려한 페이지"의 정체가 바로 이 본문 삽입 이미지들이다 —
  더 꾸미고 싶으면 섹션 구분 그림을 추가로 만들어 본문 사이사이에 끼우면 된다(요청 시 제작).

## 빌드

- `syotos_web_v0.2.zip` (이 폴더, git 미추적) — 0.2 = 영어판 + 직능 번역 수정 포함.
- 재빌드가 필요하면: `project.godot` 의 `config/version` 올리기 → 프로젝트 루트에서
  `godot --headless --path . --export-release "Web" build/web/index.html` →
  `Compress-Archive -Path build\web\* -DestinationPath itch_업로드\syotos_web_v0.2.zip -Force`
- itch 재업로드는 기존 파일 교체로(경로가 바뀌어 캐시 문제는 없다).
