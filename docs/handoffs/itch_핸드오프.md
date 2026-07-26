# itch.io 공개 핸드오프 — 베타 0.2 (영어판 포함)

itch.io 에 웹 빌드를 올려 더 넓은 사람들에게 공개하기 위한 준비 문서. (2026-07-26 작성·영어 이식 반영)
페이지 개설·업로드는 itch 계정이 필요해 사용자 몫이고, 붙여넣을 내용과 설정값은 전부 여기 준비돼 있다.
**영어 로컬라이제이션 완료(0.2)** — 첫 실행 시 OS 언어로 자동 선택(한국어 외 = 영어), 일지 설정에서 전환.

## 0. 대전제 — 완전 무료로만 배포한다 (라이선스)

- **BGM(Suno)·SFX(ElevenLabs) 모두 무료 플랜 생성물 = 비상업 사용만 허용.**
- 따라서 itch 페이지는 **가격 "No payments"** 로 설정한다. **후원(donations)·pay what you want 금지.**
- Suno 는 나중에 유료 구독해도 **이미 만든 곡에 소급 적용이 안 된다.** 수익화(후원 포함)나 앱 스토어
  출시를 하려면 그 시점에 유료 플랜에서 곡을 재생성하거나 다른 음원으로 교체해야 한다.
- ElevenLabs 무료 플랜은 **"AI 생성(ElevenLabs)" 표기가 의무.** 인게임 크레딧(타이틀 하단 "만든 이들")과
  아래 페이지 소개문에 반영돼 있다. 소개문에서 이 줄을 지우면 안 된다.

## 1. 역할 분담

**사용자 몫 (itch 계정 필요):**
- [ ] itch.io 계정 생성 → 새 프로젝트 생성
- [ ] URL 슬러그 결정 (§2 — 나중에 바꾸면 링크가 깨지니 신중히)
- [ ] §3 설정값 그대로 입력, §4 소개문 복붙, §5 이미지 업로드
- [ ] 빌드 zip 업로드 (경로는 §6 — Claude 가 만들어 둠. 영어 로컬라이제이션 완료(0.2)로 **업로드 가능**)
- [x] 영어 설문 폼 개설 완료 (2026-07-26): https://forms.gle/B8qrsZJY7Fse3ybi6 — 소개문 §4 반영됨
- [ ] 공개 전 검증 (§7 — 세이브 영속성 ✅ 07-26 확인, 남은 것 = 폰 브라우저 동작)

**Claude 완료 (이 커밋):**
- 인게임 크레딧·라이선스 고지 화면 (타이틀 하단 "베타 0.1 · 만든 이들")
- 버전 표기 (project.godot `config/version="0.1"`)
- 영어 설문 초안 (`feedback_form_en_v0.1.md`)
- 업로드용 zip 빌드 스크립트 절차 (§6)

**Claude 다음 후보 (별도 세션):**
- 커버 이미지 630×500 시안
- 영어 로컬라이제이션 (별도 대형 작업 — backlog 참고)
- itch 전용 threads ON 프리셋 실험 (§8)

## 2. 프로젝트 기본

- **Title:** See you on the other side
- **URL 슬러그 추천:** `see-you-on-the-other-side` (풀네임. 짧은 걸 원하면 `syotos` 도 가능하나
  약자는 검색성이 떨어진다. 주제목(세계의 이름)이 나중에 정해져도 부제는 유지되므로 풀네임이 안전.)
- **Classification:** Game
- **Kind of project:** HTML — "This file will be played in the browser" 체크한 zip 하나만 업로드
- **Release status:** In development (베타이므로. 정식 공개 때 Released 로)
- **Pricing:** **No payments** (§0 — 타협 불가)

## 3. 페이지 설정값

**Embed options:**
- Embed in page, 크기 **1280 × 720**
- [x] Fullscreen button
- [x] Mobile friendly (+ Orientation: **Landscape**)
- SharedArrayBuffer support: **끔** (현 빌드 threads OFF 라 불필요. §8 실험 전까지 건드리지 않는다)

**Metadata:**
- Genre: Adventure (또는 Interactive Fiction)
- Tags (최대 10): `roguelite`, `narrative`, `turn-based`, `atmospheric`, `singleplayer`,
  `2d`, `godot`, `desert`, `short`, `korean`
- AI generated content 공개(disclosure): **Yes** 로 체크하고 그래픽·오디오 명시
  (itch 규정상 필수. 텍스트·코드는 AI 보조로 사람이 작성 — 폼이 항목을 나누면 그렇게 구분해 표기)
- Language: **English, Korean**
- Multiplayer: No
- Accessibility: 해당 없음(현재)
- Community: **Comments** 켜기 (해외 피드백의 기본 창구가 된다)

## 4. 페이지 소개문 (복붙용)

### 영어 (메인)

> **"See you on the other side."**
>
> A quiet, turn-based roguelite about expeditions that almost never return.
>
> Each time the great sandstorm passes, an expedition sets out to stop the calamity
> on the far side of the desert. Almost all of them die. You are the overseer who
> sends them, again and again — and each time, you walk with a different leader.
>
> In this world, the storm erases all writing. Before dying, each expedition may
> leave behind **one single item** for the next. A rope across a chasm. A waterskin
> by a dry well. A marker on a grave. Your failures become the road.
>
> ---
>
> **BETA 0.2 — English & Korean.**
> The language is picked from your system on first launch, and can be changed
> any time in the journal's Settings.
>
> - Playable in browser, desktop and mobile (landscape).
> - A single run takes about 10–20 minutes. The story unfolds across many runs.
> - Free. Made by one person with Godot Engine.
>
> Music generated with Suno. Sound effects generated with ElevenLabs.
> Art created with AI image tools, curated and edited by hand.
>
> Feedback: comments below, or the 1-minute survey → https://forms.gle/B8qrsZJY7Fse3ybi6

### 한국어 (아래에 덧붙임)

> **"건너편에서 만나자."**
>
> 모래폭풍이 지나갈 때마다 원정대가 재앙을 멈추러 떠나고, 거의 다 돌아오지 못합니다.
> 당신은 그 원정대를 거듭 보내는 총괄자입니다. 매번 다른 대장과 함께 걷습니다.
>
> 폭풍이 글씨를 지우는 세계라서, 죽기 전에 남길 수 있는 건 물건 하나뿐입니다.
> 협곡에 걸어 둔 밧줄, 마른 우물가의 물주머니. 실패가 다음 원정대의 길이 됩니다.
>
> 베타 0.2, 한국어·영어. 브라우저에서 바로 플레이할 수 있습니다(폰은 가로 화면).
> 한 원정은 10~20분, 이야기는 여러 원정에 걸쳐 쌓입니다.
>
> 의견은 아래 댓글 또는 1분 설문으로: forms.gle/uqAhLzuZxVuZRJj76

- 소개문 수정 시 규칙: 한글 사이 em dash 금지, 세계관 어휘는 페이지에서는 풀어 쓴다(메타 채널).
- "BETA 0.1" 표기는 인게임 타이틀 하단 버전과 일치시킨다(빌드 올릴 때마다 확인).

## 5. 이미지·복붙 재료 → 전부 **프로젝트 루트 `itch_업로드/`** 폴더에 (2026-07-26 통합, 루트로 이동)

- 빌드 zip · 커버 630×500 · 배너 960×400(로고 포함) · 배경 1920×1080(테마용) · 영어 UI 스크린샷 6장 ·
  지도 이동 GIF(0.3MB) · 소개문 복붙 txt(영/한) + HTML 버전 · README(순서·테마 색상값·배너 위치 안내).
- **그 폴더의 README 대로만 하면 된다** — 이 문서는 규칙·이유(라이선스·검증)의 참고용.
- 폴더에 `.gdignore` 필수(루트라 Godot 임포트 대상 — 지우면 홍보 이미지가 게임 pck 에 실린다).

## 6. 빌드 업로드

```powershell
# 로컬 export (프로젝트 루트에서)
godot --headless --path . --export-release "Web" build/web/index.html
# zip (index.html 이 zip 루트에 오도록 내용물만 압축)
Compress-Archive -Path build\web\* -DestinationPath build\syotos_web_v0.2.zip -Force
```

- 최신 zip: **`itch_업로드\syotos_web_v0.2.zip`** (0.2 = 영어판 + 직능 번역 수정. v0.1 은 폐기).
- zip 은 `*.zip` gitignore 라 커밋되지 않는다(로컬 보관 — 지우면 위 명령으로 재생성).
- 업로드 시 "This file will be played in the browser" 체크.
- **버전을 올릴 때:** project.godot `config/version` 갱신 → 재 export → 새 zip 업로드(기존 파일 교체).
  itch 는 업로드마다 새 경로로 서빙하므로 Pages 같은 브라우저 캐시 문제는 없다.

## 7. 공개 전 검증 (사용자, 폰+PC 30분)

1. **동작:** 업로드 후 비공개(Draft/Restricted) 상태에서 PC·폰 브라우저로 열어
   한글 폰트·소리·전체화면·가로 잠금 확인 (Pages 배포 때와 같은 목록).
   itch 는 iframe 안에서 돌아서 전체화면 진입 동작이 Pages 와 다를 수 있다 — 첫 탭 전체화면이 안 먹으면 보고.
2. **세이브 영속성 — ✅ 확인됨(2026-07-26).** 0.2 → 0.3 zip 교체 업로드 후에도 세이브와 언어 설정이
   그대로 이어짐(사용자 실확인). itch 가 프로젝트마다 게임 주소(origin)를 고정해 주고, 브라우저
   저장소는 그 주소에 매이기 때문 — zip 을 갈아 끼워도 저장소는 그대로다.
   세이브 내보내기/가져오기 선행 조건은 해제(백로그에서 제거).
3. 이상 없으면 Public 으로 전환.

## 8. 나중에 — itch 전용 threads 실험 (선택)

- itch 는 SharedArrayBuffer 헤더 옵션이 있어 **threads ON 빌드가 가능**하다.
  성공하면 폰 웹 BGM "타닥" 잡음(known_issues — Pages 제약으로 SAMPLE 우회 중)이 근본 해결된다.
- 필요한 것: 별도 export 프리셋(Web-itch, thread_support=true) + AudioManager 의 웹 SAMPLE 우회를
  스레드 유무로 분기 + 페이지 설정에서 SharedArrayBuffer support 켜기 + 폰 실기기 확인.
- 실패해도 잃는 것 없음(기존 zip 유지). 착수 시 별도 세션에서.

## 9. 알아둘 것

- **`?dev=` 디버그 토큰은 itch 에서 안 통한다.** 게임이 iframe 으로 뜨는데 바깥 페이지 URL 파라미터가
  iframe 으로 전달되지 않는다. 배포 웹 디버깅이 필요하면 Pages 판(파라미터 동작)을 쓴다.
- Pages 판(soomin007.github.io/Otherside)과 itch 판은 **origin 이 달라 세이브가 서로 안 넘어간다.**
  이미 Pages 에서 플레이하던 지인들에게는 그대로 Pages 링크를 유지해 주는 게 낫다.
- itch 페이지 개설 후 이 문서 상단에 페이지 URL 을 기록할 것.
