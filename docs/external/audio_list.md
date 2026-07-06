# 오디오 — 최종 상태 + 프롬프트 보관 (See you on the other side)

> BGM = Suno, SFX = ElevenLabs(Sound Effects)로 제작. 이 문서 하나가 오디오 전체의 **최종 상태**와
> **재생성용 프롬프트 보관소**다. 파일은 Claude 가 리네임·정규화·배선한다(이미지 에셋과 같은 방식).
>
> **읽는 법:** 지금 상태만 알고 싶으면 §0 만 보면 된다. §1 은 실제 게임에 들어간 구조, §2 는 파일 목록.
> §3~5 는 곡·소리를 다시 뽑거나 확장하고 싶을 때만 여는 프롬프트/톤 보관이다.

---

## 0. 한눈에 — 오디오 종결됨 (2026-07-06)

**제작·구현 모두 완료. 새로 뽑을 것도, 남은 필수 작업도 없다.**

| 항목 | 상태 |
|------|------|
| BGM 4곡 | ✅ 제작·배선·포맷(ogg ~96k) 완료 |
| SFX 30개 | ✅ 제작·정규화(-4dB)·배선 완료 |
| 오디오 버스(Music/SFX) + 설정 슬라이더 + 전체 음소거 | ✅ 완료 |
| 위치 반영 바람 환경음(진행도 비례) | ✅ 완료 (`sfx_storm_gust` 재사용) |
| 웹 배포본 "타닥" 잡음 | ✅ **원인 규명 종결 — 아래 참고. 더 파지 말 것.** |

### 웹 "타닥" 결론 (세션 9~16, 종결)
- **증상:** 웹 배포본 BGM 에 규칙적 클릭음. **폰에서만**, 데스크톱 웹·네이티브는 깨끗.
- **원인 확정:** GitHub Pages 는 Threads 를 못 켜서(SharedArrayBuffer 미지원) 웹 오디오를 메인 스레드가 처리 →
  **폰 CPU 가 약해 생기는 언더런.** 파일·버퍼·threads 전부 아님(다 시도해 소거).
- **현재 대응:** 웹만 베드곡을 `PLAYBACK_TYPE_SAMPLE`(브라우저 Web Audio 직접 재생)로 우회 →
  타닥 "연속 → 가끔"으로 대폭 감소. 네이티브 데스크톱은 원래대로 스트림 재생(`OS.has_feature("web")` 게이트).
- **근본 해결:** 앱(네이티브) 출시 때 원본/네이티브 경로로 자연 해소 — 이미 게이트로 보장됨.
- 상세 전말·시도 로그: `docs/design/known_issues.md` "웹 오디오 타닥" 항목.

### 선택적 보강 (원하면 · 급하지 않음)
- 잔여 "가끔" 더 줄이기 = 스트림인 SFX·발소리·바람도 SAMPLE 처리(코드).
- SAMPLE+Master 트레이드오프: Music 슬라이더가 베드에 실시간 반영 안 됨(씬 전환 때만). 8분 루프 이음매 심리스화.
- 전용 바람 루프 에셋 승격(현재는 간헐 돌풍 재사용 — §0 성근 정체성엔 이대로도 충분).

---

## 1. 채택된 구조 (실제 게임에 들어간 것)

### BGM = 3트랙 방식 (화면별 곡은 폐기)
게임 무드가 하나(서늘·사막)라 화면마다 곡을 바꾸면 몰입이 깨진다 → 화면별 10곡 계획을 버리고 3트랙으로:

1. **코어 베드** — 타이틀·마을·지도·전진·단면·죽음 내내 *끊기지 않고* 재생. 화면 전환에 restart 안 함.
   `AudioManager` 가 크로스페이드 무한 루프. → `Sand Erases the Words.ogg` (8분, 길이 무관 — 안 자름).
2. **폭풍 긴장** — 폭풍 biome 노드 진입 시 베드를 크로스페이드로 잠깐 교체, 지나면 복귀. → `The Wall of Sand.ogg`.
3. **엔딩 2곡** (둘 다 슬라이드쇼):
   - **재회**(따뜻한 슬라이드 + 크레딧) → `Other Side.ogg`. 이 게임 유일한 온기.
   - **순환**(차가운 슬라이드 + 암전 여운, 한 곡으로 통합) → `The Unresolved.ogg`.
     곡을 게임이 안 자른다 — 슬라이드부터 암전·"아무 키나" 안내까지 흐르고 타이틀 복귀 때 베드로 크로스페이드.

### SFX 배선 (2026-07-05 완료)
- **공통 탭:** 모든 버튼이 트리 추가 시 자동 연결(`AudioManager._on_node_added`, meta `no_tap` 으로 제외).
- **걸음:** 지도 step 마다 발소리 3변주 랜덤(`play_step`, -7dB).
- **위협/상황 카드:** 폭풍 돌풍 / 차단 crack / 그 외 card_open (`play_situation_card`).
- **결과 팝업:** 물 획득 = water, 그 외 자원 변화 = resource.
- **이벤트:** 조사 reveal · 줍기 pickup · 로프 rope · 남기기 leave · 가방 담기 bag_add.
- **장부·일지:** 열닫 card_open/close · 챕터 넘김 page(3변주).
- **결말:** 죽음 death · 재회 마지막 슬라이드 chime · 순환 암전 cycle.
- **경고:** 물 ≤ 3 진입 시 갈증 경고 1회(`warn_thirst`).
- **바람 환경음:** 새 에셋 없이 `sfx_storm_gust` 를 간헐 돌풍 스케줄러로 재사용
  (`set_wind(level)`, level = `MapGraph.progress`). 후반일수록 잦고(26→8s) 세게(-22→-8dB), 피치 0.82~1.12 랜덤.
  마을·타이틀 = 무풍, 엔딩곡 진입 시 자동 무풍.

### 버스·볼륨
- Music / SFX 버스 분리, `AppSettings` 가 버스별 음량 저장·복원, 설정창에 슬라이더 2개 + 전체 음소거.
- 배경음악 기본 70%(효과음 묻힘 방지).

---

## 2. 제작된 파일 목록

### BGM — `assets/bgm/` (ogg ~96kbps · 원본 mp3 = `assets_src/bgm_original/`, .gdignore)
- `Sand Erases the Words.ogg` — 코어 베드
- `The Wall of Sand.ogg` — 폭풍 긴장
- `Other Side.ogg` — 재회 엔딩·크레딧
- `The Unresolved.ogg` — 순환 엔딩(슬라이드+암전 겸용)

### SFX — `assets/sfx/` (wav, 모노 44.1k, 피크 -4dB · 원본 = `assets_src/sfx_original/`)
- **UI:** `sfx_tap` · `sfx_card_open` · `sfx_card_close` · `sfx_bag_add` · `sfx_page_1~3` · `sfx_settings`(⏸ 보류)
- **원 그리기:** `sfx_draw_1~6` (지도 호버 손그림 원 6변주 · freesound "Marker Circle" CC0 분할)
- **걸음·자원:** `sfx_step_1·2·4` (3변주) · `sfx_water` · `sfx_resource`
- **이벤트:** `sfx_pickup` · `sfx_rope` · `sfx_reveal` · `sfx_leave`
- **위협:** `sfx_storm_gust` · `sfx_crack` · `sfx_thirst`
- **결말:** `sfx_death` · `sfx_reunion_chime` · `sfx_cycle`

> **⚠️ 재생성 후보(당장은 이대로):** `sfx_resource`·`sfx_reveal`·`sfx_cycle` 은 원본이 매우 조용해 +27~32dB 보강했다.
> 폰·스피커로 들어 노이즈가 거슬릴 때만 §5 프롬프트로 재생성. (파일 노이즈는 재생성만이 답 — 볼륨 조절로 안 됨.)
> **⏸ 보류:** `sfx_settings` 는 설정이 장부(양피지 소리)로 바뀌며 자리를 잃음. 특별한 확인음 등으로 재활용 후보.

---

## 3. 사운드 정체성 (톤 — 재생성 시 먼저 읽기)

**서늘·건조·고독·사막.** 모래폭풍이 글씨를 지우는 세계, 거의 다 죽는 원정대의 릴레이, 죽기 전 단 한 번의 남김.
정서 반전은 결말의 **재회**(작별인 줄 알았던 것이 재회가 된다) — **따뜻함은 오직 재회에만**. 나머지는 담담하고 척박하게.

- **팔레트:** 성근 다크 앰비언트 드론, 사막 바람, 중동 리드(ney·duduk), 보잉 스트링, 펠트 피아노, 멀리서 울리는 프레임 드럼, 모래 알갱이 그래뉼러 텍스처.
- **금지:** 뚜렷한 보컬(무언의 숨·패드만 허용), 빠른 비트, 밝은 멜로디(재회 제외), 팝적 훅.
- **템포:** 대부분 50~65 bpm, 멜로디 최소.
- **레퍼런스 결:** 서울 2033(황량·텍스트 밀도), Reigns(짧은 런), Expedition 33(릴레이).

---

## 4. 재생성용 프롬프트 — 채택된 BGM 4곡

> 다시 뽑거나 다듬고 싶을 때만. 스타일 프롬프트 맨 앞 `[Instrumental]`, 가사 칸은 비우거나 `no vocals`.
> 길이는 신경 쓸 것 없음 — 게임 BGM 은 루프라 Claude 가 ffmpeg 로 구간 잘라 크로스페이드·ogg 변환한다.

### 코어 베드 (`Sand Erases the Words`)
```
[Instrumental] sparse cinematic dark ambient, lone duduk over a low drone,
distant desert wind, mournful with a faint warmth beneath, no percussion, no vocals, 55 bpm, loopable
```
> ⚠️ 이 곡에 광대역 프레임드럼/모래 타격이 작곡돼 있어 폰 타닥과 겹쳐 들릴 수 있다(웹 타닥 자체는 CPU 문제로 별개).
> 재생성 시 `no percussion, no hits` 를 더 강하게, 또는 무타악기 순수 드론으로.

### 폭풍 긴장 (`The Wall of Sand`)
```
[Instrumental] dark cinematic sandstorm tension, a wall of roaring desert wind rising, low dissonant drone with detuned bowed strings, rattling sand grains and faint metallic groans, a distant slow heartbeat pulse, oppressive and suffocating, no clear melody, no vocals, slowly building dread, loopable
```
변주(더 애절한 결 — 폭풍 속 우는 ney):
```
[Instrumental] tense desert dread, a distant wailing ney over a low rumbling drone, howling wind and shifting sand, sparse trembling strings, cold and threatening, restrained, no drums or a faint pulse, no vocals, loopable
```

### 순환 엔딩 (`The Unresolved`) — 슬라이드+암전 한 곡
```
[Instrumental] cold solemn cinematic ambient, a lone piano motif circling and unresolved over a deep drone, distant frame drum like a slow heartbeat, a single faint warm note hidden underneath hinting at another way, austere and lingering, very slow, no vocals, loopable
```

### 재회 엔딩 (`Other Side`) — 정서 정점, 유일한 온기
```
[Instrumental] warm cathartic cinematic, ney and duduk in gentle harmony, blooming warm strings,
resolving warm chords, long-held tension finally released, tearful relief, slow build to warmth,
soft wordless choir or no vocals, no harsh percussion
```

---

## 5. 재생성용 프롬프트 — SFX (ElevenLabs)

> **핵심 요령:** ElevenLabs 는 `tick`·`tap` 만 쓰면 여러 번 반복되는 기계음(타다다닥)으로 만든다.
> 일회성 소리는 반드시 **`a single one-shot ...` + `one hit only` + `not repeating` + `no rhythm, no sequence` + `very short`**.
> Duration 0.3~3s, 톤은 §3(건조·성글게, 종이·모래·가죽·나무). 다 뽑아 오면 Claude 가 -4dB 정규화·wav 변환·배선.

**UI**
- 탭/버튼(`sfx_tap`): `a single one-shot soft muted tap on paper, one hit only, not repeating, no rhythm, very short, dry`
- 카드 열기(`sfx_card_open`): `a single one-shot soft parchment card sliding open once, one motion only, not repeating, dry paper rustle, short`
- 카드 닫기(`sfx_card_close`): `a single one-shot soft parchment card closing once, one motion only, not repeating, brief dry paper, short`
- 가방 담기(`sfx_bag_add`): `a single one-shot light cloth swipe then a soft leather thud, one item placed once, not repeating, short`
- 페이지 넘김(`sfx_page`): `a single one-shot old paper page turning once, one page only, not repeating, dry and quiet, short`

**걸음·자원**
- 모래 걸음(`sfx_step`): `a single one-shot footstep pressing into dry desert sand once, one step only, not repeating, soft close crunch`
- 물 한 모금(`sfx_water`): `a single one-shot short quiet gulp of water from a metal flask, one sip only, not repeating`
- ⚠️ 자원 감소(`sfx_resource`): `a single one-shot tiny dry soft blip, one hit only, not repeating, no ticking, no rhythm, minimal and short`

**이벤트**
- 줍기(`sfx_pickup`): `a single one-shot soft warm confirmation, picking up one small item, one hit only, not repeating, gentle and brief`
- 로프(`sfx_rope`): `a single one-shot taut rope pulling tight and creaking once, secured across a gap, one motion, not repeating`
- ⚠️ 노드 공개(`sfx_reveal`): `a single one-shot delicate ink bloom on parchment with a soft airy shimmer, one reveal only, not repeating, short`
- 남기기(`sfx_leave`): `a single one-shot small object set down onto sand once, one soft placement with low resonance, not repeating`

**위협 (지속 ~2s, 앰비언트)**
- 폭풍 돌풍(`sfx_storm_gust`): `one sustained gust of harsh sandstorm wind rising and holding for about 2 seconds, grains rattling, single continuous swell, not looping`
- 갈라진 틈(`sfx_crack`): `a single hollow low echo rising once from a deep crack in the ground, empty and cold, one sustained tail, not repeating`
- 갈증 경고(`sfx_thirst`): `a single low subtle warning drone, one sustained tone about 1.5 seconds, dry and tense but not alarming, not repeating`

**결말**
- 죽음(`sfx_death`): `a single one-shot low mournful impact with a long fading resonance, a body settling into sand once, not repeating`
- 재회 차임(`sfx_reunion_chime`): `a single one-shot warm resolving bell shimmer, one gentle bloom, tender and hopeful, not repeating`
- ⚠️ 순환 울림(`sfx_cycle`): `a single one-shot deep low resonant drone hit, one strike, cold and unresolved, slowly fading, not repeating`

---

## 6. 폐기된 아이디어 (참고 보관 — 되살릴 일 없으면 무시)

- **화면별 BGM 10곡(구 B1~B10):** 타이틀·오프닝·마을·지도·전진·폭풍·죽음·남기기·순환·재회 per-screen 곡.
  → **§1 의 3트랙 방식으로 대체**(2026-07-04). 무드가 하나라 화면마다 곡을 바꾸면 몰입만 깨져서 폐기.
  나중에 특정 화면(예: 마을·남기기)만 전용 곡으로 확장하고 싶으면 이 방향을 되살릴 수 있으나, 프롬프트 전문은
  git 이력(이 파일의 2026-07-06 이전 버전)에 있다. 굳이 여기 남기지 않는다.
- **발소리 3번(`sfx_step_3`):** 결이 안 맞아 삭제, 3변주(1·2·4)로 운용.

---

## 7. Godot / 웹 통합 메모

- **포맷:** BGM = `.ogg` ~96kbps(웹 용량 28.5→13MB, A/B 로 음질 차이 없음 확인). 루프는 파일 loop 대신
  `AudioManager` 수동 크로스페이드라 임포트 Loop 불필요. SFX = `.wav`(AudioStreamWAV, 지연 없이 재생).
- **경량(웹 첫 로딩):** GL Compatibility 로딩 부담 때문에 과대 파일 금지. 음악은 저비트레이트 루프 구간만, SFX 는 짧고 작게.
- **웹 재생 함정:** no-threads(Pages) 환경에선 스트림 믹서에 폰 타닥 위험 → 베드는 웹 전용 SAMPLE 재생.
  오디오 구조를 바꾸면 **반드시 웹 실기기에서 소리 확인**(데스크톱은 멀쩡해도 폰에서 깨질 수 있음).
- **배치:** `assets/bgm/`, `assets/sfx/`. 파일명 규칙 유지.
