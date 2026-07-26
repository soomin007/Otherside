# itch 업로드 폴더 — 여기 있는 것만 쓰면 된다

페이지 개설에 필요한 재료 전부. 규칙·이유가 궁금하면 [`../itch_핸드오프.md`](../itch_핸드오프.md).
(2026-07-26, 베타 0.2 기준)

## ⚠️ 복붙 주의

- 소개문은 `소개문_영어.txt`·`소개문_한국어.txt` 를 **통째로 복사**해 붙인다.
- 핸드오프 md 에 있던 `>` 기호는 **붙여넣는 내용이 아니다** — 문서에서 인용 표시일 뿐이다.
  txt 파일에는 기호 없이 본문만 들어 있으니 txt 쪽을 쓰면 된다.
- 영어 소개문을 위에, 한국어를 아래에. 굵게(제목 줄)는 붙인 뒤 itch 편집기 툴바로.

## 순서 (약 20분)

1. itch.io 가입 → Dashboard → Create new project
2. Title: `See you on the other side` · URL: `see-you-on-the-other-side`
3. Kind of project: **HTML** · Pricing: **No payments** (후원 금지 — 라이선스, 핸드오프 §0)
4. Uploads: `build\syotos_web_v0.2.zip` 업로드 → "This file will be played in the browser" 체크
5. Embed: 1280 × 720 · Fullscreen button ✔ · Mobile friendly ✔ (Orientation: Landscape)
6. Details: 소개문 두 txt 복붙 · Genre: Adventure · Tags: roguelite, narrative, turn-based,
   atmospheric, singleplayer, 2d, godot, desert, short, korean
   · **AI generated content: Yes**(그래픽·오디오 명시) · Language: English, Korean
7. 이미지: 아래 파일들을 자리에 맞게
8. Theme(오른쪽 꾸미기 패널): 아래 "테마" 값 적용
9. Save & view page → 비공개(Draft) 상태로 폰·PC 검증(핸드오프 §7 — 특히 재업로드 후 세이브 유지)
10. 이상 없으면 Public

## 파일 → 자리

| 파일 | 어디에 |
|---|---|
| `커버_630x500.png` | Cover image |
| `배너_960x400.png` | Theme → Banner (상단 배너. 로고가 들어 있으니 Title 표시는 꺼도 된다) |
| `배경_1920x1080.png` | Theme → Background image (Fill/Cover, 반복 없음) |
| `스크린샷_01~06.png` | Screenshots (01 타이틀 · 02 지도 · 03 단면 · 04 꾸리기 · 05 막간 · 06 오프닝) |
| `움짤_지도이동.gif` | Screenshots 맨 앞에 올리거나, 소개문 첫 문단 아래에 이미지로 삽입(0.3MB) |
| `소개문_영어.txt` / `소개문_한국어.txt` | Details → Description (영어 먼저, 아래 한국어) |

## 테마 (게임 팔레트 그대로)

- Background color: `#141017` (게임 배경 어둠)
- Text color: `#F6ECD4` (아이보리 — 배경 이미지를 쓰면 글상자 밖 텍스트용)
- Link / Button color: `#D6B278` (모래색)
- Font: 기본(Serif 옵션이 있으면 Serif가 게임 결에 맞다)
- Screenshots: 사이드바 표시 ✔ (본문 왼쪽이 길어 보이는 걸 막아 준다)
- itch 는 일반 계정에 커스텀 CSS 를 안 준다 — 위 배너·배경·색으로 충분히 게임 결이 난다.

## 빌드

- zip: 프로젝트 루트 `build\syotos_web_v0.2.zip` (git 미추적 — 없으면 핸드오프 §6 두 줄로 재생성)
- 재업로드 시: `project.godot` 의 `config/version` 올리기 → export → zip → 기존 파일 교체
