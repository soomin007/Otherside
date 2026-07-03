# 아트 프롬프트 — 복사해서 바로 쓰는 완성형 (See you on the other side)

> **쓰는 법:** 아래 각 코드블록을 **통째로 복사** → GPT / DALL·E / Midjourney 에 그대로 붙여넣기. 스타일·글자금지·배경 문구가 **이미 다 들어있다**(조합할 필요 없음).
> **2026-07-02 교훈(첫 22장 전부 실패):** ① 생성기는 투명 배경을 못 만들고 체커보드를 *그림으로* 그린다 → **"흰 배경"이라 적힌 건 흰 배경으로 뽑고, 넣기 전에 흰색→투명 변환한다(§적용, 코드로 일괄 가능).** ② "글자 금지"를 무시하고 라벨을 박는다 → 박히면 그 부분 크롭. ③ 작게 나온다 → **권장 크기 이상**으로.
> **팔레트 참고:** 모래 베이지 `#D2BC78`, 세피아 `#452F1C`, 양피지 `#D1BC91`, 밤하늘 남색 `#0C0D18`.

---

## ★ 파일 관리 & 진행 현황 (다음 세션은 여기부터)

**파일명 규칙:** `NN_카테고리_이름.png` — 번호대 예약(아래 표). 사용자가 뽑아 넣으면 **Claude 가 이 이름으로 리네임·정리**한다(GPT 자동 파일명 그대로 두지 않는다). 흰 배경으로 뽑은 아이콘·초상은 넣기 전 흰색→투명 변환(§적용).

| 번호 | 요소 | 프롬프트 | 상태 |
|---|---|---|---|
| 01 | 지도 양피지 배경 | §1 | ✅ 완료 (불투명, 그대로 사용) |
| 02 | 아이콘 마을 | §2 | ✅ 완료 (흰배경 → 투명 변환 대기) |
| 03 | 아이콘 마른 강 | §2 | ✅ 완료 |
| 04 | 아이콘 버려진 야영지 | §2 | ✅ 완료 |
| 05 | 아이콘 갈라진 바닥 | §2 | ✅ 완료 |
| 06 | 아이콘 오아시스 | §2 | ✅ 완료 |
| 07 | 아이콘 모래의 벽 | §2 | ✅ 완료 |
| 08 | 아이콘 뼈의 들판 | §2 | ✅ 완료 |
| 09 | 아이콘 독 웅덩이 | §2 | ✅ 완료 (흰→투명, `Map.gd` 배선) |
| 10 | 아이콘 무너진 담 | §2 | ✅ 완료 |
| 11 | 아이콘 폭풍의 문 | §2 | ✅ 완료 |
| 12 | 아이콘 ??? (끝) | §2 | ✅ 완료 |
| 13~18 | 단면 배경 6종 (start/cache/blockage/storm/end/dunes) | §3 | ✅ 완료 (불투명, `SectionArt.gd` 배선 — cover 맞춤 + 절차적 fallback) |
| 19~21 | 초상 3종 (시장/대장/배낭) | §4 | ✅ 완료 (흰→투명, `Figures.gd` 배선 — contain 맞춤 + 절차적 fallback) |
| 22 | 가방 화면 배경 | §5 | ✅ 완료 (불투명, `Loadout.gd` 배경 TextureRect cover) |
| 23 | 공통 화면 배경 | §6 | ✅ 완료 (불투명, `Backdrop.gd` cover — 타이틀·오프닝 공용) |
| 24~28 | 오프닝 삽화 5장 | §7 | ✅ 완료 (불투명, `Opening.gd` 슬라이드별 삽화 + 크로스페이드) |
| 29 | 타이틀 키아트 | §8 | ✅ 완료 (불투명, `Main.gd` 배경 TextureRect cover + 스크림) |
| 30~37 | 아이템 삽화 8종 (물통/식량/말린고기/로프/은신막/약초/부싯돌/정화천) | §9 | ✅ 완료 (흰→투명 변환·`ItemIcon.gd` 배선, 가방 슬롯 아이콘 확인) |
| 38 | 열린 가방(위에서 본 빈 배낭) — 가방 슬롯 뒤 배경 | §10 | ⬜ 선택 (흰→투명, `Loadout.gd` 배선됨·없으면 배낭 초상 21 재활용) |
| 29가로 | 타이틀 키아트 **가로판**(데스크톱) — `29_타이틀_키아트_가로.png` | §11 | ⬜ (방향 자동 교체 배선됨·없으면 세로본) |
| 23가로 | 공통 배경 **가로판**(데스크톱) — `23_배경_공통_가로.png` | §11 | ⬜ |
| 40~43 | 지도 손스케치 **지형** 4종 (강/산/사구/폭풍) | §12 | ⬜ 신규 (흰→투명, `Map.gd` 가 biome별 엣지에 배치·없으면 안 그림) |
| 44~46 | 지도 손스케치 **메모** 3종 (해골/경고/화살표) | §12 | ⬜ 신규 (원정대 낙서 — 죽은 자리·위험 노드 등) |

**01~29 배선 완료.** 다음은 **아이템 삽화 8종(§9, 30~37)** — 가방 챙기기 화면 슬롯에 들어간다. `ItemIcon.gd` 가 이미 배선돼 있어(없으면 절차적 글리프) 뽑아서 `transparent/` 로 흰→투명 변환만 하면 자동 반영. 그 외 남은 것은 폰/웹 시각 확인·톤 조정(스크림 알파 Opening 0.5·Main 0.35, cover/contain).

---

## 1. 지도 양피지 배경 (불투명 · 세로 1080×1920 이상) — `01_지도_양피지.png`

```
An aged parchment map background for a fantasy game, empty and plain, hand-drawn cartography in the
style of the Lord of the Rings maps, weathered vellum texture with subtle stains and burnt edges, a
faint decorative border and a small compass rose in one corner, muted sepia and sand tones, vertical
portrait composition. Muted desert palette, low saturation, dusty and timeworn. Absolutely no text,
no words, no letters, no labels, no numbers, no watermark, no signature, no landmarks, no icons,
no photo, no satellite, no 3d render.
```

---

## 2. 지도 아이콘 (흰 배경 → 투명 · 각 512×512 이상) — 11개(02~12), 하나씩 복사

> 방문한 지역만 지도에 잉크로 그려지듯 나타나게 하려면 **아이콘을 하나씩 따로** 뽑아야 한다.
> **파일명:** 아래 순서대로 `02_아이콘_마을` ~ `12_아이콘_미지`. (02~08 완료, **09~12 남음**.)

### 마을
```
A hand-drawn 2.5D fantasy map icon of a tiny desert oasis town with a dome, a well and palm trees,
in Lord of the Rings cartography style, ink linework with light sepia wash, slightly oblique bird's-eye
view, a single small weathered object centered with generous margin on a plain solid pure white
background (#FFFFFF). Muted sepia and sand palette, low saturation, timeworn. Absolutely no text,
no words, no letters, no labels, no numbers, no watermark, no checkerboard, no grid, no scenery,
no ground plane.
```

### 마른 강
```
A hand-drawn 2.5D fantasy map icon of a dry winding cracked riverbed, in Lord of the Rings cartography
style, ink linework with light sepia wash, slightly oblique bird's-eye view, a single small weathered
object centered with generous margin on a plain solid pure white background (#FFFFFF). Muted sepia and
sand palette, low saturation, timeworn. Absolutely no text, no words, no letters, no labels, no numbers,
no watermark, no checkerboard, no grid, no scenery, no ground plane.
```

### 버려진 야영지
```
A hand-drawn 2.5D fantasy map icon of a small cluster of tattered abandoned tents, in Lord of the Rings
cartography style, ink linework with light sepia wash, slightly oblique bird's-eye view, a single small
weathered object centered with generous margin on a plain solid pure white background (#FFFFFF). Muted
sepia and sand palette, low saturation, timeworn. Absolutely no text, no words, no letters, no labels,
no numbers, no watermark, no checkerboard, no grid, no scenery, no ground plane.
```

### 갈라진 바닥
```
A hand-drawn 2.5D fantasy map icon of a jagged deep chasm splitting the ground, in Lord of the Rings
cartography style, ink linework with light sepia wash, slightly oblique bird's-eye view, a single small
weathered object centered with generous margin on a plain solid pure white background (#FFFFFF). Muted
sepia and sand palette, low saturation, timeworn. Absolutely no text, no words, no letters, no labels,
no numbers, no watermark, no checkerboard, no grid, no scenery, no ground plane.
```

### 오아시스
```
A hand-drawn 2.5D fantasy map icon of a small green oasis with a few palm trees around a pool, in Lord
of the Rings cartography style, ink linework with light sepia wash, slightly oblique bird's-eye view, a
single small weathered object centered with generous margin on a plain solid pure white background
(#FFFFFF). Muted sepia and sand palette, low saturation, timeworn. Absolutely no text, no words,
no letters, no labels, no numbers, no watermark, no checkerboard, no grid, no scenery, no ground plane.
```

### 모래의 벽
```
A hand-drawn 2.5D fantasy map icon of great wind-blown sand dunes drawn as ridged mounds, in Lord of the
Rings cartography style, ink linework with light sepia wash, slightly oblique bird's-eye view, a single
small weathered object centered with generous margin on a plain solid pure white background (#FFFFFF).
Muted sepia and sand palette, low saturation, timeworn. Absolutely no text, no words, no letters,
no labels, no numbers, no watermark, no checkerboard, no grid, no scenery, no ground plane.
```

### 뼈의 들판
```
A hand-drawn 2.5D fantasy map icon of a scatter of bones and a ribcage half-buried in sand, in Lord of
the Rings cartography style, ink linework with light sepia wash, slightly oblique bird's-eye view, a
single small weathered object centered with generous margin on a plain solid pure white background
(#FFFFFF). Muted sepia and sand palette, low saturation, timeworn. Absolutely no text, no words,
no letters, no labels, no numbers, no watermark, no checkerboard, no grid, no scenery, no ground plane.
```

### 독 웅덩이
```
A hand-drawn 2.5D fantasy map icon of a murky dark pool ringed by dead reeds, in Lord of the Rings
cartography style, ink linework with light sepia wash, slightly oblique bird's-eye view, a single small
weathered object centered with generous margin on a plain solid pure white background (#FFFFFF). Muted
sepia and sand palette, low saturation, timeworn. Absolutely no text, no words, no letters, no labels,
no numbers, no watermark, no checkerboard, no grid, no scenery, no ground plane.
```

### 무너진 담
```
A hand-drawn 2.5D fantasy map icon of a broken ancient stone wall with rubble, in Lord of the Rings
cartography style, ink linework with light sepia wash, slightly oblique bird's-eye view, a single small
weathered object centered with generous margin on a plain solid pure white background (#FFFFFF). Muted
sepia and sand palette, low saturation, timeworn. Absolutely no text, no words, no letters, no labels,
no numbers, no watermark, no checkerboard, no grid, no scenery, no ground plane.
```

### 폭풍의 문
```
A hand-drawn 2.5D fantasy map icon of a narrow canyon gate swallowed by a swirling sandstorm, in Lord of
the Rings cartography style, ink linework with light sepia wash, slightly oblique bird's-eye view, a
single small weathered object centered with generous margin on a plain solid pure white background
(#FFFFFF). Muted sepia and sand palette, low saturation, timeworn. Absolutely no text, no words,
no letters, no labels, no numbers, no watermark, no checkerboard, no grid, no scenery, no ground plane.
```

### ??? (끝, 미지)
```
A hand-drawn 2.5D fantasy map icon of an ominous blank veil of swirling storm, unknowable with no
definite shape, in Lord of the Rings cartography style, ink linework with light sepia wash, a single
small weathered object centered with generous margin on a plain solid pure white background (#FFFFFF).
Muted sepia and sand palette, low saturation, timeworn. Absolutely no text, no words, no letters,
no labels, no numbers, no watermark, no checkerboard, no grid, no scenery, no ground plane, no creature.
```

---

## 3. 단면 배경 (불투명 · 가로 1600×900 이상) — 6종, 하나씩 복사

> 도착 노드 화면 배경. 조사 지점·글씨는 코드가 위에 얹으니 **장소 분위기만.**

### 마을 (start)
```
A wide 16:9 side view of a small desert camp at dusk, a few tents, a stone well, warm lantern glow, low
horizon in the lower third, a full background scene filling the frame. Muted desert palette of sand beige
and sepia, dusty haze, painterly semi-realistic, cinematic soft light, low saturation, melancholic mood.
Absolutely no text, no words, no letters, no labels, no watermark, no white background, no isolated
object, no people in focus.
```

### 폐허·오아시스·야영지 (cache)
```
A wide 16:9 side view of a weathered desert ruin, a crumbling stone arch half-buried in sand beside a
lone dry well, low horizon in the lower third, a full background scene filling the frame. Muted desert
palette of sand beige and sepia, dusty haze, painterly semi-realistic, cinematic soft light, low
saturation, melancholic desolate mood. Absolutely no text, no words, no letters, no labels, no watermark,
no white background, no isolated object, no people.
```

### 갈라진 바닥·무너진 담 (blockage)
```
A wide 16:9 side view of a deep chasm splitting the desert ground, jagged edges and darkness below, low
horizon, a full background scene filling the frame. Muted desert palette of sand beige and sepia, dusty
haze, painterly semi-realistic, cinematic soft light, low saturation, ominous desolate mood. Absolutely
no text, no words, no letters, no labels, no watermark, no white background, no isolated object,
no people.
```

### 모래의 벽·폭풍의 문 (storm)
```
A wide 16:9 side view of an approaching towering wall of sandstorm sweeping across the desert, swirling
dust, low horizon, a full background scene filling the frame. Muted desert palette of sand beige and
sepia, heavy dusty haze, painterly semi-realistic, cinematic soft light, low saturation, ominous
threatening mood. Absolutely no text, no words, no letters, no labels, no watermark, no white background,
no isolated object, no people.
```

### 재앙의 자리 (end)
```
A wide 16:9 side view of a mysterious place fully veiled and hidden by a swirling sandstorm, unknowable
with no visible shape, low horizon, a full background scene filling the frame. Muted desert palette,
heavy dusty haze, painterly semi-realistic, low saturation, ominous dreadful mystery mood. Absolutely
no text, no words, no letters, no labels, no watermark, no white background, no isolated object,
no people, no creature, no monster.
```

### 기본 사막 (dunes)
```
A wide 16:9 side view of endless rolling desert dunes under a pale washed-out sky, low horizon, a full
background scene filling the frame. Muted desert palette of sand beige and sepia, dusty haze, painterly
semi-realistic, cinematic soft light, low saturation, quiet desolate mood. Absolutely no text, no words,
no letters, no labels, no watermark, no white background, no isolated object, no people.
```

---

## 4. 인물·사물 초상 (흰 배경 → 투명) — 3종, 하나씩 복사

> 마을 준비·시장 화면의 흉상/사물. 어두운 카드 위에 얹힌다. 얼굴은 흐리게(매 원정 다른 사람).

### 시장 (market)
```
A bust portrait of an old desert market trader, weathered sun-worn face, long grey beard, wrapped turban
and layered dusty robes, kind but tired eyes, warm lantern side light, the figure centered with generous
margin on a plain solid pure white background (#FFFFFF). Painterly semi-realistic, muted sepia and sand
palette, low saturation, melancholic dignified mood. Absolutely no text, no words, no letters, no labels,
no numbers, no watermark, no checkerboard, no scenery.
```

### 원정대장 (leader, 익명)
```
A bust portrait of a hooded desert expedition leader seen slightly backlit, the face shadowed and hidden
under a worn hood and cloth wraps, travel-worn gear, anonymous and resolute, dust in the air, the figure
centered with generous margin on a plain solid pure white background (#FFFFFF). Painterly semi-realistic,
muted sand and sepia palette, low saturation, solemn quiet mood, no visible face detail. Absolutely
no text, no words, no letters, no labels, no numbers, no watermark, no checkerboard, no scenery.
```

### 배낭 (pack, 사물)
```
A single worn leather-and-canvas expedition backpack, buckled straps, a bedroll and waterskin lashed on,
dusty and travel-used, three-quarter view, centered with generous margin on a plain solid pure white
background (#FFFFFF). Painterly semi-realistic, muted sand and sepia palette, low saturation, soft light.
Absolutely no text, no words, no letters, no labels, no numbers, no watermark, no checkerboard,
no scenery, no ground, no desk.
```

---

## 5. 가방 준비 화면 배경 (불투명 · 세로 1080×1920)

> Loadout 화면 UI 뒤에 깔린다. **중앙~상단은 어둡고 비어야** 글씨가 읽힌다(배낭·물품은 가장자리·하단).

```
A top-down slightly oblique view of a worn wooden desk at night, an open expedition backpack of leather
and canvas laid out, supplies scattered around the edges (waterskins, dried food, a coil of rope, a flint,
a folded tarp), warm lantern glow from one side, the center and upper area kept dark and empty as negative
space, deep shadows, vertical portrait composition, a full background scene filling the frame. Muted sand
and sepia palette, dusty, painterly semi-realistic, cinematic soft light, low saturation, melancholic
quiet mood. Absolutely no text, no words, no letters, no labels, no watermark, no white background,
no bright center, no people.
```

---

## 6. 공통 화면 배경 (타이틀·마을·오프닝, 불투명 · 세로 1080×1920)

```
A wide desert night background, deep indigo sky fading to warm sand near a low horizon, faint stars, a
distant silhouette of a small desert city with domes and minarets along the horizon, the center left calm
and empty as negative space, dusty atmosphere, a full background scene filling the frame. Muted palette,
painterly, cinematic, low saturation, melancholic mood. Absolutely no text, no words, no letters,
no labels, no watermark, no white background, no bright center, no people.
```

---

## 7. 오프닝 삽화 (선택, 불투명 · 세로 1080×1920) — 5장, 하나씩 복사

### 1장 — 해마다 원정대가 떠난다
```
A storytelling illustration, vertical composition, a lone caravan setting out into vast desert dunes at
dawn, tiny and small against the endless sand, a full background scene. Muted desert palette of sand and
sepia, dusty haze, painterly semi-realistic, cinematic soft light, low saturation, melancholic desolate
mood. Absolutely no text, no words, no letters, no labels, no watermark, no white background.
```

### 2장 — 거의 다 죽는다
```
A storytelling illustration, vertical composition, scattered footprints and a fallen expedition pack
half-buried in the sand, no bodies shown, a full background scene. Muted desert palette of sand and sepia,
dusty haze, painterly semi-realistic, low saturation, sorrowful desolate mood. Absolutely no text,
no words, no letters, no labels, no watermark, no white background, no people.
```

### 3장 — 모래폭풍이 글을 지운다
```
A storytelling illustration, vertical composition, a sandstorm sweeping across the land and erasing tracks
and carvings on stone, dust swallowing everything, a full background scene. Muted desert palette, heavy
dusty haze, painterly semi-realistic, low saturation, ominous mood. Absolutely no text, no words,
no letters, no labels, no watermark, no white background.
```

### 4장 — 너는 그들을 거듭 보내는 자
```
A storytelling illustration, vertical composition, a distant lone overseer figure standing and watching
many faint paths leading away into the desert, seen from behind and far, a full background scene. Muted
desert palette, dusty haze, painterly semi-realistic, low saturation, solemn quiet mood. Absolutely
no text, no words, no letters, no labels, no watermark, no white background, no face detail.
```

### 5장 — 죽기 전 단 한 번 남긴다
```
A storytelling illustration, vertical composition, a single waterskin left resting in the sand with a
small carved mark beside it, close and quiet, a full background scene. Muted desert palette of sand and
sepia, dusty haze, painterly semi-realistic, low saturation, tender melancholic mood. Absolutely no text,
no words, no letters, no labels, no watermark, no white background, no people.
```

---

## 8. 타이틀 키아트 (선택, 불투명 · 세로 또는 화면비)

```
Key art for a desert roguelite game, a lone silhouette facing an endless sea of dunes under a vast pale
sky, a faint far-off veil of sandstorm on the horizon, a sense of distance and quiet dread, empty
negative space at the top, a full background scene filling the frame. Muted sepia and sand palette,
painterly cinematic, low saturation, melancholic mood. Absolutely no text, no words, no letters,
no labels, no title, no logo, no watermark, no white background.
```

---

## 9. 아이템 삽화 (흰 배경 → 투명 · 각 512×512 이상) — 8종, 하나씩 복사

> 가방 챙기기 화면의 가방 슬롯에 들어가는 물품 아이콘. **단일 사물**을 흰 배경 가운데(넉넉한 여백)로.
> 파일명 순서: `30_아이템_물통` ~ `37_아이템_정화천`. 넣기 전 흰색→투명 변환(§적용). 톤은 §4 초상과 통일.

### 물통 (water)
```
A single worn leather-and-hide desert waterskin canteen plugged with a wooden stopper, dusty and
travel-used, three-quarter view, a single object centered with generous margin on a plain solid pure
white background (#FFFFFF). Painterly semi-realistic, muted sand and sepia palette, low saturation,
soft light. Absolutely no text, no words, no letters, no labels, no numbers, no watermark,
no checkerboard, no scenery, no ground, no shadow, no second object.
```

### 식량 자루 (food)
```
A single small burlap ration sack bulging with dried food, coarse cloth, rope-tied neck, dusty and
worn, a single object centered with generous margin on a plain solid pure white background (#FFFFFF).
Painterly semi-realistic, muted sand and sepia palette, low saturation, soft light. Absolutely no text,
no words, no letters, no labels, no numbers, no watermark, no checkerboard, no scenery, no ground,
no shadow, no second object.
```

### 말린 고기 (jerky)
```
A small bundle of dried jerky meat strips tied with cord, dark salted meat, a single object centered
with generous margin on a plain solid pure white background (#FFFFFF). Painterly semi-realistic, muted
sepia and dark red-brown palette, low saturation, soft light. Absolutely no text, no words, no letters,
no labels, no numbers, no watermark, no checkerboard, no scenery, no ground, no shadow, no second object.
```

### 로프 (rope)
```
A single neatly coiled worn hemp rope, wound into a loop, frayed ends, dusty, top three-quarter view, a
single object centered with generous margin on a plain solid pure white background (#FFFFFF). Painterly
semi-realistic, muted sand and sepia palette, low saturation, soft light. Absolutely no text, no words,
no letters, no labels, no numbers, no watermark, no checkerboard, no scenery, no ground, no shadow,
no second object.
```

### 은신막 (shelter)
```
A single folded weathered canvas tarp shelter cloth, rolled and tied with cord, dusty desert tones, a
single object centered with generous margin on a plain solid pure white background (#FFFFFF). Painterly
semi-realistic, muted sand and sepia palette, low saturation, soft light. Absolutely no text, no words,
no letters, no labels, no numbers, no watermark, no checkerboard, no scenery, no ground, no shadow,
no second object.
```

### 약초 꾸러미 (medicine)
```
A single small bundle of dried desert medicinal herbs tied with twine, muted green-grey leaves and
stems, a single object centered with generous margin on a plain solid pure white background (#FFFFFF).
Painterly semi-realistic, muted sage-green and sepia palette, low saturation, soft light. Absolutely
no text, no words, no letters, no labels, no numbers, no watermark, no checkerboard, no scenery,
no ground, no shadow, no second object.
```

### 부싯돌 (flint)
```
A single flint stone with a curved steel striker resting against it, angular grey flint, worn steel, a
single object centered with generous margin on a plain solid pure white background (#FFFFFF). Painterly
semi-realistic, muted grey and sepia palette, low saturation, soft light. Absolutely no text, no words,
no letters, no labels, no numbers, no watermark, no checkerboard, no scenery, no ground, no shadow,
no second object.
```

### 정화천 (filter)
```
A single folded fine linen filtering cloth for straining water, damp-stained pale cloth, a single object
centered with generous margin on a plain solid pure white background (#FFFFFF). Painterly semi-realistic,
muted off-white and sepia palette, low saturation, soft light. Absolutely no text, no words, no letters,
no labels, no numbers, no watermark, no checkerboard, no scenery, no ground, no shadow, no second object.
```

---

## 10. 열린 가방 배경 (선택, 흰 배경 → 투명 · 세로 800×1000 이상) — `38_배경_열린가방.png`

> 가방 챙기기 화면의 6칸 슬롯 **뒤에 깔리는** 열린 배낭. 위에서 내려다본 **빈** 배낭이라 슬롯(아이템)이 그 '안'에
> 놓인 것처럼 보인다. 가운데(입구)는 어둡고 비어야 슬롯이 읽힌다. 없으면 배낭 초상(21)을 재활용한다.

```
A top-down view of a single open empty leather-and-canvas expedition backpack seen from directly above,
the flap open and the dark empty interior facing up, buckled straps and a rolled bedroll around the rim,
dusty and travel-used, the center kept dark and empty, a single object centered with generous margin on
a plain solid pure white background (#FFFFFF). Painterly semi-realistic, muted sand and sepia palette,
low saturation, soft light. Absolutely no text, no words, no letters, no labels, no numbers, no watermark,
no checkerboard, no scenery, no ground, no shadow, no items inside.
```

---

## 11. 데스크톱 가로판 배경 (불투명 · 가로 1920×1080 이상) — 2종

> 세로 배경을 가로 화면에 cover 하면 위아래가 잘려 **구도(인물·도시)가 사라진다.** 그래서 데스크톱(가로)용
> **16:9 가로 구도**를 따로 뽑는다. 파일명 = 세로본 + `_가로` 접미사. 방향 감지 배선 완료 — 있으면 가로 화면에서
> 자동 사용, 없으면 세로본 fallback. **중앙~상단은 비워** UI(제목·버튼)가 얹힌다.

### 타이틀 키아트 가로판 — `29_타이틀_키아트_가로.png`
```
Key art for a desert roguelite game, wide 16:9 landscape composition, a lone hooded silhouette standing
small on a rocky ridge in the lower-left third facing an endless sea of dunes stretching to the right, a
faint far-off veil of sandstorm on the horizon, vast pale hazy sky, a sense of distance and quiet dread,
the upper-center kept open and empty as negative space for a title. Muted sepia and sand palette,
painterly cinematic, low saturation, melancholic mood, a full background scene filling the frame.
Absolutely no text, no words, no letters, no title, no logo, no watermark, no white background.
```

### 공통 배경 가로판 — `23_배경_공통_가로.png`
```
A wide 16:9 landscape desert night background, deep indigo sky fading to warm sand near a low horizon,
faint stars, a distant silhouette of a small desert city with domes and minarets sitting to the right
along the horizon, the left and center kept calm, dark and empty as negative space, dusty atmosphere, a
full background scene filling the frame. Muted palette, painterly, cinematic, low saturation, melancholic
mood. Absolutely no text, no words, no letters, no labels, no watermark, no white background, no people.
```

---

## 12. 지도 손스케치 (원정대 낙서, 흰 배경 → 투명 · 각 512×512 이상) — 7종, 하나씩 복사

> **컨셉:** 이전 원정대원이 양피지 지도 위에 펜으로 슥슥 그려 남긴 약도·표식. 방문한 구간에 나타난다(안개 걷힘 = 지도가 채워짐). `Map.gd` 가 biome별로 엣지에 지형 스케치를, 죽은 자리·위험 노드에 메모를 배치한다(없으면 안 그림).
> 파일명: 지형 `40_낙서_강`·`41_낙서_산`·`42_낙서_사구`·`43_낙서_폭풍`, 메모 `44_낙서_해골`·`45_낙서_경고`·`46_낙서_화살표`. 넣기 전 흰색→투명 변환(§적용).
> **작고 거칠게** — 지도 아이콘(§2)보다 빠르고 성긴 손그림. 세피아 한 색, 텍스트 절대 없음, 흰 배경만.

### 강 (river) — `40_낙서_강`
```
A tiny hand-drawn ink sketch of a winding river, quick loose pen strokes on a plain white background, a
simple meandering double line with a few short ripple marks, explorer's field-map doodle style, single
sepia-brown ink color, minimal and rough with lots of empty white space around it. Absolutely no text,
no letters, no numbers, no labels, no watermark, plain white background only.
```

### 산·바위 (rock) — `41_낙서_산`
```
A tiny hand-drawn ink sketch of a small mountain range, three or four simple triangular peaks with a few
short hatching lines for shading, quick loose pen strokes on a plain white background, explorer's
field-map doodle style, single sepia-brown ink color, minimal and rough. Absolutely no text, no letters,
no numbers, no labels, no watermark, plain white background only.
```

### 사구 (flats) — `42_낙서_사구`
```
A tiny hand-drawn ink sketch of rolling desert sand dunes, two or three soft overlapping curved lines,
quick loose pen strokes on a plain white background, explorer's field-map doodle style, single
sepia-brown ink color, minimal and rough. Absolutely no text, no letters, no numbers, no labels, no
watermark, plain white background only.
```

### 폭풍 (storm) — `43_낙서_폭풍`
```
A tiny hand-drawn ink sketch of a sandstorm swirl, a simple spiral with a few short curved motion strokes
around it, quick loose pen strokes on a plain white background, explorer's field-map doodle style, single
sepia-brown ink color, minimal and rough. Absolutely no text, no letters, no numbers, no labels, no
watermark, plain white background only.
```

### 해골 (죽음) — `44_낙서_해골`
```
A tiny hand-drawn ink sketch of a small human skull marking a death spot on a map, simple rough pen
outline, quick loose strokes on a plain white background, explorer's field-map doodle style, single
sepia-brown ink color, minimal. Absolutely no text, no letters, no numbers, no labels, no watermark,
plain white background only.
```

### 경고 (위험) — `45_낙서_경고`
```
A tiny hand-drawn ink sketch of a danger mark, a rough X inside a hastily drawn circle with a couple of
jagged slash strokes, nervous quick pen strokes on a plain white background, explorer's field-map doodle
style, single sepia-brown ink color, minimal. Absolutely no text, no letters, no numbers, no labels, no
watermark, plain white background only.
```

### 화살표 (방향) — `46_낙서_화살표`
```
A tiny hand-drawn ink sketch of a direction arrow, a single rough curved arrow pointing forward, quick
loose pen strokes on a plain white background, explorer's field-map doodle style, single sepia-brown ink
color, minimal. Absolutely no text, no letters, no numbers, no labels, no watermark, plain white
background only.
```

---

## 폰트 (이미지 아님 — 텍스트 미감)

현재 `assets/fonts/NanumGothic-Regular.ttf`(고딕, 밋밋). 게임 톤엔 명조/붓이 더 맞다. OFL·상업가능·한글 포함:

| 스타일 | 폰트 | 용도 |
|---|---|---|
| 정통 명조(서사·품격) | **나눔명조 / 본명조(Noto Serif KR)** | 본문 안정적, 1순위 |
| 부드러운 명조 | **마루 부리** | 붓끝 살아있는 명조, 본문·제목 |
| 붓·손글씨 | **나눔손글씨 붓 / 배민 을지로** | 제목·지명·시장 대사용(본문 X) |
| 깔끔 고딕 | **프리텐다드 / 스포카 한 산스** | UI 가독·현대감 |

적용: ttf 를 `assets/fonts/` 에 넣고 `project.godot` 의 `gui/theme/custom_font` 교체. **웹 두부(□) 방지 위해 한글 글리프 포함 확인.** ttf 만 주면 배선까지 해준다.

---

## 적용 (뽑은 이미지 넣기)

### 흰 배경 → 투명 변환 (§2 아이콘, §4 초상·사물)
흰 배경으로 뽑은 것은 넣기 전에 흰색을 투명으로 바꾼다(순백 단색이라 깨끗이 떨어진다).
- **도구 준비·검증 완료(2026-07-03):** `scripts/tools/alpha_key.gd` — 흰 배경 컬러키(밝기+채도 판별로
  세피아·모래·뼈는 남기고 순백만 제거) + alpha 대비 스냅(사각 헤일로 방지) + 여백 크롭. 02~08 로 검증됨.
  - 실행: `godot --headless --path . -s scripts/tools/alpha_key.gd` → `assets/arts/` 의 `_아이콘_`/`_초상_`
    파일 전부 변환, 결과는 `assets/arts/transparent/` 에(원본 보존). 특정 파일만: `-- <경로> ...`.
  - 손잡이(결과 보고 조정): `WHITE_LO/HI`(배경 밝기 문턱)·`CHROMA_MAX`(그림 판별 채도)·`ALPHA_LO/HI`(잔여 스냅).
- **검증 미리보기:** `scripts/tools/alpha_preview.gd -- <출력.png>` → transparent/ 를 어두운 배경에 합성한
  그리드 시트(흰 배경 뷰어로 안 보이는 진짜 투명·경계·하이라이트 구멍 확인). 아이콘 늘 때마다 재확인.
- **수동 대안:** remove.bg(무료)·Photoshop·GIMP 매직완드.
- **글자가 박혀 나오면** 그 부분 먼저 크롭.

### 절차적 draw → 이미지 교체 지점
- 지도 배경: `scripts/ui/Map.gd` → `TextureRect`(맨 뒤). 아이콘은 개별 텍스처(reveal 애니메이션).
- 단면: `scripts/ui/SectionArt.gd` `draw_section` → kind별 `Texture2D`.
- 초상: `scripts/ui/Figures.gd` → `TextureRect`.
- 화면 배경: `scripts/ui/Backdrop.gd` → 배경 텍스처.
- 가방 화면 배경(§5): `scripts/ui/Loadout.gd` 의 어두운 띠(`ColorRect`) → 배경 `TextureRect`.

### 톤 통일
한 세트를 **같은 생성기·같은 시드 계열**로 뽑아야 통일된다. 지도 → 단면 → 초상 순 권장. 웹 export 는 권장 크기 근처로(과대해상도 금지 — GL Compatibility 로딩).
