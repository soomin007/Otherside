# 오디오 목록 (Suno 제작용) — See you on the other side

> 사용자가 Suno 로 뽑을 배경음악·효과음의 단일 목록. 게임의 실제 화면·순간·톤(00_START_HERE §4 루프, 기획서 §3 결말)에 맞춰 정리.
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
- Suno 는 2~4분을 생성 → **깔끔히 반복되는 구간만 잘라** 루프용 `.ogg` 로 쓴다(§3).
- 스타일 칸은 짧을수록 안정적(장르 + 무드 + 악기 + 템포 순). 아래 프롬프트는 그대로 붙여넣기용.

---

## 1. 배경음악 (BGM)

우선순위: **P0 = 핵심(먼저)**, P1 = 있으면 좋음, P2 = 여유 시.
추천 제작 순서: **B4 지도 → B5 전진 → B6 폭풍 → B8 남기기 → B10 재회 → B1 타이틀 → B7 죽음** (게임 감이 가장 빨리 사는 순서), 그다음 P1.

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

## 2. 효과음 (SFX)

> **솔직한 안내:** Suno 는 노래 생성기라 **짧은 기계음(버튼 탭 등)엔 부적합**. Suno 로 좋은 건 **앰비언트 베드·음악적 스팅어**다.
> 짧은 UI 원샷은 **jsfxr(sfxr.me)·freesound.org(CC0)** 권장. 아래는 필요한 효과음 전체 체크리스트 + Suno 적합 여부.

### Suno 로 뽑을 만한 것 (음악적 스팅어 · 앰비언트)
- **노드 공개 / 안개 걷힘(잉크 리빌):** 도착해 정체가 드러날 때. 짧은 반짝 스팅어.
  ```
  [Instrumental] short delicate reveal chime, single soft bell and a bowed harmonic, dry, no vocals, 3 seconds
  ```
- **재회 차임(결말):** 따뜻한 벨 한 번. B10 과 결.
  ```
  [Instrumental] short warm resolving chime, glassy bell and a soft string swell, tender, no vocals, 4 seconds
  ```
- **폭풍 돌풍 시작(경고):** 카드로 폭풍이 예고될 때. 짧은 바람 몰아침.
  ```
  [Instrumental] short gust of harsh sandstorm wind rising then holding, rattling grains, no music, no vocals, 4 seconds
  ```
- **남기기 확정(내려놓음):** 물건을 두는 순간. 낮고 부드러운 여운(=B8 축소판) — Suno 짧게 or freesound.

### Suno 부적합 → jsfxr / freesound (CC0) — 스펙만
전부 **건조·성글게. 종이·모래·나무 질감. 날카롭지 않게.** (톤은 §0)
- **UI:** 탭/버튼(짧은 마른 톡), 카드 열기·닫기(종이 스침), **가방 슬라이드**(아이템 담기 — 부드러운 스와이프+톡), 페이지 넘김, 설정 열기.
- **걸음·자원:** 모래 밟는 걸음 틱(전진), 물 한 모금, 자원 소모 미세 틱.
- **이벤트 결과:** 줍기(부드러운 획득 확인음), 로프 걸기·차단 통과(팽팽한 줄 당김), 자원 획득/손실 구분음.
- **위협:** 갈라진 틈(공허한 저음), 갈증 경고(낮은 경고, 요란하지 않게).
- **결말·죽음:** 순환 저음 울림(=B9 결), 죽음 임팩트(낮은 쿵+여운 — B7 로 대체 가능).

---

## 3. Godot / 웹 통합 메모 (넣기 전 참고)

- **포맷:** 음악은 `.ogg`(Vorbis, Godot 임포트에서 **Loop 켜기**), 짧은 SFX 는 `.wav`(AudioStreamWAV).
- **경량(웹 첫 로딩):** 음악은 모노 또는 저비트레이트(96~128kbps), **루프 구간만**. 과대 파일 금지(GL Compatibility 로딩 부담). SFX 는 짧고 작게.
- **루프 만들기:** Suno 생성물(2~4분)에서 이음매 없는 8~90s 구간만 잘라 쓰고, 시작·끝을 짧게 크로스페이드해 반복 티를 없앤다.
- **볼륨:** 이미 `AppSettings`(master bus) + 설정 슬라이더 있음. **Music / SFX 버스를 나누면** 각각 볼륨 조절 가능 — 원하면 Claude 가 배선.
- **배치 제안:** `assets/audio/bgm/`, `assets/audio/sfx/`. 파일명 규칙 유지(예: `bgm_04_map.ogg`, `sfx_pickup.wav`).

### 넣기 전에 Claude 가 미리 해둘 수 있는 것 (원하면 말만)
- `AudioManager` autoload: **씬별 BGM 자동 재생 + 크로스페이드**(타이틀→마을→지도→단면→엔딩), 이벤트 SFX 훅.
- **Music / SFX 오디오 버스** 분리 + `AppSettings` 연동(음량 저장/복원).
- 빈 파일 자리(placeholder) 배선 → **파일만 위 이름으로 넣으면 즉시 소리**가 나게.

> 요약: 위 B4·B5·B6·B8·B10 다섯 개만 있어도 게임의 정서가 확 산다. 거기서부터 늘려가면 된다.
