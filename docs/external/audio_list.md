# 오디오 목록 (BGM = Suno · SFX = ElevenLabs) — See you on the other side

> **배경음악은 Suno, 효과음은 ElevenLabs(Sound Effects)로** 뽑는 단일 목록. 게임의 실제 화면·순간·톤(00_START_HERE §4 루프, 기획서 §3 결말)에 맞춰 정리.
> 뽑은 파일은 Claude 가 리네임·배선한다(이미지 에셋과 같은 방식). 통합 메모는 맨 아래 §3.

---

## 0. 사운드 정체성 (전체 톤 — 먼저 읽기)

**서늘·건조·고독·사막.** 모래폭풍이 글씨를 지우는 세계, 거의 다 죽는 원정대의 릴레이, 죽기 전 단 한 번의 남김.
정서 반전은 결말의 **재회**(작별인 줄 알았던 것이 재회가 된다) — **따뜻함은 오직 재회에만** 들어온다. 나머지는 담담하고 척박하게.

- **팔레트:** 성근 다크 앰비언트 드론, 사막 바람, 중동 리드(ney·duduk), 보잉 스트링, 펠트 피아노, 멀리서 울리는 프레임 드럼, 모래 알갱이 그래뉼러 텍스처.
- **금지:** 뚜렷한 보컬(무언의 숨·패드만 허용), 빠른 비트, 밝은 멜로디(재회 제외), 팝적 훅.
- **템포:** 대부분 50~65 bpm, 멜로디 최소.
- **레퍼런스 결:** 서울 2033(황량·텍스트 밀도), Reigns(짧은 런), Expedition 33(릴레이).

**Suno 공통 팁**
- 스타일 프롬프트 맨 앞에 `[Instrumental]`. 가사 칸은 비우거나 `no vocals`.
- **길이 (신경 안 써도 됨):** Suno v4.5 는 구조 태그(`[End]`/`[Outro]`)를 넣어도 **4~8분이 흔하다** — 길이 제어는 사실상 안 먹힌다. 하지만 **게임 BGM 은 루프라 길이는 문제가 안 된다.** 두 갈래(둘 다 사용자 음악 편집 불필요):
  - **통짜 그대로(제일 쉬움):** 4~5분 앰비언트를 그대로 넣고 게임이 반복 재생. 드론/앰비언트라 이음매도 거의 안 티난다. **매끈한 크로스페이드 루프는 `AudioManager` 가 코드로 처리.**
  - **특정 구간만:** 마음에 드는 구간 타임코드(예: `1:20~2:30`)만 알려주면 **Claude 가 ffmpeg 로 잘라 크로스페이드·`.ogg` 변환**한다.
  → 요약: 좋은 곡 하나 뽑는 데만 집중. 자르기·루프는 Claude 에게 넘긴다.
- 스타일 칸은 짧을수록 안정적(장르 + 무드 + 악기 + 템포 순). 아래 프롬프트는 그대로 붙여넣기용.

---

## 1. 배경음악 (BGM)

> **★ 최종 결정(2026-07-04): 화면별 곡 폐기 → 3트랙 방식.** 게임 무드가 하나(서늘·사막)라 화면마다 곡을 바꾸면 몰입만 깨진다. 대신:
> 1. **잔잔한 코어 베드** — 코어 루프(타이틀·마을·지도·전진·단면·죽음) 내내 *끊기지 않고 계속* 재생(화면 전환에 restart 안 함). `AudioManager` 가 크로스페이드 무한 루프. **✅ 제작됨(8분, 길이 무관 — 안 자름).**
> 2. **폭풍 긴장** — 폭풍 구간에서 베드를 크로스페이드로 잠깐 교체, 지나면 복귀. **⬜ 프롬프트 = 아래 "폭풍 긴장".**
> 3. **엔딩 크레딧** — **재회(진짜 엔딩)** 에서 크레딧곡(보컬 OK, 영화 크레딧 결 · "Love Me Again"). **순환 엔딩은 차갑게 베드 유지**(대비). **✅ 제작됨.**
>
> 아래 B1~B10 per-screen 프롬프트는 **참고용(여유 시 마을·죽음 등 확장)** — 필수는 위 3개뿐이다.

### 폭풍 긴장 (crisis / storm) — Suno 프롬프트 (⬜ 미제작)

- **어디서:** 폭풍 구간·폭풍 노드(모래의 벽·폭풍의 문). 베드를 크로스페이드로 교체. 길이 무관(루프).
- **역할:** 살을 베는 모래바람, 압박·불안. 액션 영화식 과장 말고 **서늘한 위협·질식감**(게임 팔레트 안에서).

```
[Instrumental] dark cinematic sandstorm tension, a wall of roaring desert wind rising, low dissonant drone with detuned bowed strings, rattling sand grains and faint metallic groans, a distant slow heartbeat pulse, oppressive and suffocating, no clear melody, no vocals, slowly building dread, loopable
```

변주(더 애절한 결 — 폭풍 속 리드):
```
[Instrumental] tense desert dread, a distant wailing ney over a low rumbling drone, howling wind and shifting sand, sparse trembling strings, cold and threatening, restrained, no drums or a faint pulse, no vocals, loopable
```
> 여느 때처럼 인스트루멘탈, 길이 신경 X(내가 루프·크로스페이드 처리). Suno 는 한 번에 2 take 주니 골라서.

### B1 · 타이틀 테마  · P0
- **어디서:** 타이틀 화면(Main). 첫인상. 루프 60~90s.
- **역할:** 서늘·고독하되 밑바닥에 아주 옅은 온기(재회 복선).
```
[Instrumental] sparse cinematic dark ambient, lone duduk over a low drone,
distant desert wind, mournful with a faint warmth beneath, no percussion, no vocals, 55 bpm, loopable
```
- 제목 예: *Sand Erases the Words*

### B2 · 오프닝 서사  · P1
- **어디서:** 첫 플레이 오프닝 슬라이드쇼(Opening, 5장). 원샷 2~3분(스킵 가능하니 루프 불필요).
- **역할:** 조용한 불안 → 서늘한 소개 → 옅은 애틋함. 말없이 세계를 깐다.
```
[Instrumental] minimal cinematic ambient, felt piano single notes, swelling bowed strings,
granular sand textures, breathy wordless pad, solemn and tender, very slow, building, no drums, no vocals
```
- 제목 예: *The One Who Sends Them*

### B3 · 마을 · 가방 꾸리기  · P1
- **어디서:** 마을/가방 화면(Loadout). 늙은 시장 상인, 출발 전 준비. 루프 60~90s.
- **역할:** 먼지 낀 정적, 떠나기 전 잠깐의 온기. 담담한 채비.
```
[Instrumental] quiet Middle-Eastern folk ambient, soft oud plucks, low ney flute,
faint room tone, warm dusty calm, slow, intimate, very soft hand drum or none, no vocals, loopable
```
- 제목 예: *The Old Trader's Stall*

### B4 · 지도 · 계획  · P0
- **어디서:** 탑뷰 지도(Map). 안개, 마커 이동, 갈 곳 고르기. 루프 90s.
- **역할:** 사색적 계획. 멀어질수록 옅은 긴장(거리 곡선). 레이어드 하기 좋게 성글게.
```
[Instrumental] contemplative dark ambient, slow evolving drone, sparse bowed-string swells,
tiny prepared-piano motes, cold and patient, subtle underlying tension, no beat, no vocals, loopable
```
- 제목 예: *Reading the Map*

### B5 · 전진 · 단면 탐색  · P0
- **어디서:** 이동 중(맵 마커 전진) + 도착 노드 단면 조사(Section). 루프 90s.
- **역할:** 한 걸음씩 밀어붙이는 베드. 걸음·자원 불안의 낮은 맥박. 멜로디 없음.
```
[Instrumental] tense minimal ambient, slow low pulse like distant footsteps in sand,
dry percussive taps, hollow drone, thirst and fatigue mood, no melody, no vocals, 50 bpm, loopable
```
- 제목 예: *One Step, Then Another*
- 참고: 여유 되면 **후반(척박) 변주** 한 판 더 — 위 프롬프트에 `harsher, more dissonant, sparser` 추가.

### B6 · 폭풍  · P0
- **어디서:** 폭풍 구간·폭풍 노드(모래의 벽·폭풍의 문). 짧은 루프 30~45s 또는 스팅어.
- **역할:** 위험·압박. 살을 베는 바람, 불협, 차오르는 긴장.
```
[Instrumental] harsh cinematic tension, roaring sandstorm wind wall, dissonant low strings,
rattling grains, rising dread, no clear melody, no vocals, unsettling, loopable
```
- 제목 예: *The Wall of Sand*

### B7 · 죽음  · P0
- **어디서:** 원정대 사망(고갈·위협). 원샷 15~30s (짧게, 여운 남기고 침묵).
- **역할:** 애도. 스러진 원정대 하나. 정보 0, 정서 100.
```
[Instrumental] short mournful sting, a single lamenting duduk phrase over a fading drone,
hollow and final, then silence, no percussion, no vocals
```
- 제목 예: *A Body in the Sand*

### B8 · 남기기  · P0 (정서 핵심)
- **어디서:** 남기기(BequeathPanel) — 물건 하나를 다음 원정대에게 두는 순간. 원샷/루프 40~60s.
- **역할:** 애틋함. 내 수명을 깎아 미래에 건네는 희생과 옅은 희망. 이 게임의 심장.
```
[Instrumental] tender bittersweet ambient, gentle felt-piano motif, warm low strings,
a fragile hopeful turn, intimate and sacrificial, very slow, no drums, no vocals
```
- 제목 예: *One Thing, Left Behind*

### B9 · 결말 · 순환  · P1
- **어디서:** 순환 엔딩(끝에 닿았으나 릴레이가 이어짐, 이번 원정대가 재앙의 자리에). 원샷 40~60s.
- **역할:** 차갑고 불가피함. 해소되지 않는 순환. 다음 원정대가 이곳으로 온다.
```
[Instrumental] cold solemn cinematic, circular unresolved motif, deep drone,
distant frame drum like a slow heartbeat, no release, austere, no vocals
```
- 제목 예: *The Relay Does Not Stop*

### B10 · 결말 · 재회  · P0 (정서 정점 — 유일한 온기)
- **어디서:** 재회 엔딩(흔적 충분 + 무사 도달 → 먼저 간 모든 원정대와 건너편에서 재회). 원샷 60~120s. 이 게임의 페이오프.
- **역할:** 카타르시스·온기·해소. 오래 참았던 긴장이 마침내 풀린다. 작별이 재회가 되는 순간.
```
[Instrumental] warm cathartic cinematic, ney and duduk in gentle harmony, blooming warm strings,
resolving warm chords, long-held tension finally released, tearful relief, slow build to warmth,
soft wordless choir or no vocals, no harsh percussion
```
- 제목 예: *See You on the Other Side*

---

## 2. 효과음 (SFX) — ElevenLabs Sound Effects

> **ElevenLabs 의 Sound Effects(text-to-SFX)로 만든다.** 짧은 자연어 설명을 넣으면 짧은 효과음이 나온다. 게임 SFX에 잘 맞는다(Suno는 BGM 전용).
> **팁:** ① 설명은 짧고 구체적으로(재료·질감·동작 단어: dry, soft, paper, sand, leather). ② Duration 0.3~3s 로 짧게. ③ Prompt influence 높이면 설명에 충실(사실적)·낮추면 창의적. ④ 바람·공허 같은 앰비언트는 Loop 옵션. ⑤ 출력은 `.mp3`(Godot 가 그대로 임포트, 필요 시 `.wav` 변환).
> **톤(§0 유지):** 건조·성글게. 종이·모래·가죽·나무 질감. 날카롭거나 만화 같지 않게. 과장 금지.

각 항목: 용도 + ElevenLabs 프롬프트(영어, 그대로 붙여넣기).

**UI**
- 탭 / 버튼: `soft dry muted tap, a minimal paper-like click, no reverb`
- 카드 열기: `soft parchment card sliding open, dry paper rustle, gentle`
- 카드 닫기: `soft parchment card closing, a brief dry paper shuffle`
- 가방에 담기(슬라이드): `a light cloth swipe followed by a soft leather thud, an item placed into a bag`
- 페이지 넘김: `a single old paper page turning, dry and quiet`
- 설정 열기: `a soft muted low ui tone, understated and warm`

**걸음 · 자원**
- 모래 걸음(전진): `a single footstep pressing into dry desert sand, soft close crunch`
- 물 한 모금: `a short quiet gulp of water from a metal flask`
- 자원 감소 틱: `a tiny dry subtle tick, minimal, almost imperceptible`

**이벤트 결과**
- 줍기(획득): `a soft warm confirmation tone, picking up a small item, gentle and brief`
- 로프 걸기 · 차단 통과: `a taut rope pulling tight and creaking, securing a line across a gap`
- 노드 공개 / 안개 걷힘(잉크 리빌): `delicate ink spreading across old parchment with a soft airy shimmer`
- 남기기(내려놓음): `setting a small object down onto sand, a soft final placement with low resonance`

**위협**
- 폭풍 돌풍 시작(경고): `a sudden gust of harsh sandstorm wind rising and holding, grains rattling` (Loop 가능)
- 갈라진 틈(공허): `a hollow low echo rising from a deep crack in the ground, empty and cold`
- 갈증 경고(낮게): `a low subtle warning drone, dry, tense but not alarming, short`

**결말 · 죽음**
- 죽음(스러짐): `a low mournful impact with a long fading resonance, a body settling into sand` (B7 음악 스팅어로 대체·중첩 가능)
- 재회 차임(결말): `a warm resolving bell shimmer, tender and hopeful, gently blooming` (더 멜로디컬하게 원하면 Suno 짧은 스팅어로도)
- 순환 저음 울림(결말): `a deep low resonant drone hit, cold and unresolved, slowly fading`

> 앰비언트성(폭풍 바람·틈 공허)은 Loop 켜서 배경 레이어로도 쓸 수 있다. 톤은 전부 §0 을 따른다.

---

## 3. Godot / 웹 통합 메모 (넣기 전 참고)

- **포맷:** 음악(Suno)은 `.ogg`(Vorbis, Godot 임포트에서 **Loop 켜기**). SFX(ElevenLabs)는 `.mp3` 그대로 임포트되나, 아주 짧고 자주 쓰는 건 `.wav`(AudioStreamWAV)로 변환하면 지연 없이 재생.
- **경량(웹 첫 로딩):** 음악은 모노 또는 저비트레이트(96~128kbps), **루프 구간만**. 과대 파일 금지(GL Compatibility 로딩 부담). SFX 는 짧고 작게.
- **루프 만들기:** Suno 생성물(길이 무관, 8분이 나와도)에서 이음매 없는 8~90s 구간만 잘라 쓰고, 시작·끝을 짧게 크로스페이드해 반복 티를 없앤다.
- **볼륨:** 이미 `AppSettings`(master bus) + 설정 슬라이더 있음. **Music / SFX 버스를 나누면** 각각 볼륨 조절 가능 — 원하면 Claude 가 배선.
- **배치 제안:** `assets/audio/bgm/`, `assets/audio/sfx/`. 파일명 규칙 유지(예: `bgm_04_map.ogg`, `sfx_pickup.wav`).

### 넣기 전에 Claude 가 미리 해둘 수 있는 것 (원하면 말만)
- `AudioManager` autoload: **씬별 BGM 자동 재생 + 크로스페이드**(타이틀→마을→지도→단면→엔딩), 이벤트 SFX 훅.
- **Music / SFX 오디오 버스** 분리 + `AppSettings` 연동(음량 저장/복원).
- 빈 파일 자리(placeholder) 배선 → **파일만 위 이름으로 넣으면 즉시 소리**가 나게.

> 요약: 위 B4·B5·B6·B8·B10 다섯 개만 있어도 게임의 정서가 확 산다. 거기서부터 늘려가면 된다.
