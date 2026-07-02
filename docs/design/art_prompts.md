# 아트 프롬프트 — 외부 이미지 생성용 (See you on the other side)

> **목적:** 게임에 그림이 필요한 모든 요소를, 외부 이미지 생성기(Midjourney / DALL·E / Stable Diffusion 등)로 직접 뽑아 넣을 수 있게 프롬프트 예시로 정리한다.
> 현재 코드의 비주얼은 전부 절차적 `draw_*`(placeholder)다 — 이 문서의 이미지로 하나씩 교체해 간다.
> **프롬프트는 영어**(생성기 표준). 한국어는 용도·배치 설명. 뽑은 뒤 넣는 법은 맨 아래 §적용.

---

## 0. 공통 아트 디렉션 (모든 프롬프트에 공유)

**세계:** 끝없는 사막, 주기적 모래폭풍이 글씨를 지우는 땅. 재앙을 멈추러 원정대가 거듭 떠나고 거의 다 죽는다. 재앙의 정체는 끝까지 안 밝힌다(맥거핀 — 괴물·형상 금지). 정서는 **서늘하고 쓸쓸하되 품위 있게**, 처절하지만 조용하다.

**공통 스타일 토큰 (프롬프트에 붙여 쓰기):**
```
muted desert palette, sand beige and sepia and faded ochre, dusty haze,
painterly semi-realistic, cinematic soft light, melancholic and desolate mood,
weathered and timeworn, low saturation, no text, no logo, no UI, no frame
```
**네거티브(공통):**
```
bright saturated colors, cartoon, anime, cute, neon, modern city, vehicles,
people faces in focus, text, watermark, signature, ui elements, monster, creature
```

**팔레트 참고(코드 UITheme 와 맞춤):** 모래 베이지 `#D2BC78`, 세피아 잉크 `#452F1C`, 양피지 `#D1BC91`, 밤하늘 남색 `#0C0D18`, 어스름 모래 `#2B2119`. 채도 낮게, 먼지 낀 대기.

**웹 export 제약:** PNG. 과대 해상도 금지(첫 로딩 느림 — GL Compatibility). 아래 각 요소의 권장 크기 지킬 것. **인물·사물 초상은 투명 배경(alpha)**, 배경·지도는 불투명.

**인물 원칙:** 얼굴을 특정하지 않는다(매 원정 *다른 사람*이 감 — 익명성이 정서). 후드·역광·실루엣·먼 거리로 얼굴을 흐린다.

---

## 1. 지도 (가장 중요 — 위치·거리·분위기)

**용도:** 탑뷰 지도 화면(`scenes/map.tscn`)의 **배경 지형 이미지**. 노드 마커·경로선·원정대 마커·안개는 **코드가 이 이미지 위에 얹는다** → 이미지엔 UI·점·선·글자를 넣지 말고 **지형과 분위기만**. 노드 자리에 "여기 뭔가 있겠다" 싶은 랜드마크 힌트만 은은하게.

**구도:** **세로(모바일) 9:16**, 위에서 비스듬히 내려다본 3/4 top-down(위성사진 + 고지도 하이브리드). **하단 = 출발(마을), 상단 = 끝(재앙).** 아래에서 위로 갈수록 **풍요→척박, 따뜻→서늘**. 거리가 곧 난이도·정서의 기울기다.

**세로 7단(하단→상단) 지형/분위기** — 게임 노드(`MapGraph`)와 맞춤:

| 세로 위치 | 노드 | 지형·분위기(이미지에 담을 것) |
|---|---|---|
| 맨 아래(출발) | 마을 | 작은 사막 오아시스 도시, 야자·우물·흙벽 집, 유일하게 온기 |
| 그 위 | 마른 강 | 갈라진 마른 강바닥이 구불구불, 물 없는 물길 |
| 중하 (갈래) | 버려진 야영지 / 갈라진 바닥 | 왼: 버려진 천막 잔해 · 오른: 지면을 가르는 깊은 균열(협곡) |
| 중 (갈래) | 오아시스 / 모래의 벽 | 왼: 마지막 작은 초록 오아시스 · 오른: 거대한 모래언덕(바람에 흩날리는 능선) |
| 중상 (갈래) | 뼈의 들판 / 독 웅덩이 | 왼: 모래에 반쯤 묻힌 짐승·사람 백골 · 오른: 탁하고 단내 나는 웅덩이 |
| 상 | 무너진 담 | 무너진 고대 성벽·돌더미가 길을 막음 |
| 그 위 | 폭풍의 문 | 좁은 협곡 입구를 삼킨 거대한 모래폭풍 벽 |
| 맨 위(끝) | ??? | 폭풍에 완전히 가려 아무것도 안 보임 — 미지·불길 (형상 금지) |

**프롬프트 예시:**
```
Top-down 3/4 aerial view of an endless desert expedition map, vertical 9:16 composition.
Bottom: a small warm oasis town with wells and mud-brick houses. Moving upward the land grows
harsher and colder: a dry cracked riverbed, abandoned tent ruins, a deep chasm, great wind-blown
sand dunes, a field of half-buried bones, a murky poisoned pool, collapsed ancient walls, and at
the very top a narrow canyon swallowed by a towering wall of sandstorm fading into unknown haze.
Faint winding paths suggest routes between landmarks. Old cartography feel meets satellite imagery,
muted desert palette, sand beige and sepia and faded ochre, dusty haze, painterly semi-realistic,
cinematic soft light, melancholic and desolate, low saturation, no text, no markers, no UI, no grid.
```
**네거티브:** 공통 + `map markers, dotted lines, grid, labels, compass rose, roads, icons`.
**권장 크기:** 세로 긴 이미지, 예 1080×1920(또는 배수). 노드가 위→아래 세로 배치라 세로 여유 중요.
**배치 노트:** 코드가 `col`(0~1 좌우)·`row`(0~7 상하)로 노드를 얹는다. 이미지의 랜드마크 위치를 위 표의 좌/오른(갈래)과 대략 맞추면 자연스럽다. 지형만, 마커 없음.

**대안(사용자 선호 시):** "3D 위성사진" 강조 →
```
Photorealistic satellite view of a vast desert, soft aerial perspective, dune shadows at
low sun angle, subtle terrain relief, sepia and sand tones, hazy atmosphere, ...
```

---

## 2. 단면 배경 (도착 노드 화면 — kind별 6종)

**용도:** 도착 노드 "단면 탐색" 화면(`scenes/expedition.tscn`, 현재 `SectionArt` 절차적)의 배경. **가로로 펼쳐진 측단면**(옆에서 본 한 장소). 조사 지점(붉은 원)·라벨은 코드가 위에 얹으니 **장소 분위기만**.

**구도:** **가로 16:9 정도**, 지평선/지면이 화면 아래 ~70%. 측면 풍경.

| kind | 장소 | 프롬프트 핵심 |
|---|---|---|
| `start` | 마을 | small desert camp, tents, a well, warm lantern glow at dusk |
| `cache` | 폐허·오아시스·야영지 | a weathered ruin / small oasis with a few palms / abandoned campsite in sand |
| `blockage` | 갈라진 바닥·무너진 담 | a deep chasm splitting the ground / a collapsed stone wall blocking the path |
| `storm` | 모래의 벽·폭풍의 문 | an approaching wall of sandstorm, swirling dust, ominous |
| `end` | 재앙의 자리 | a mysterious veiled place fully hidden by sandstorm, unknowable, no creature |
| `dunes` | 기본 사막 | endless rolling dunes under a pale sky |

**프롬프트 예시(cache — 폐허):**
```
Side view of a weathered desert ruin, crumbling stone arch half-buried in sand, a lone dry well,
horizon low in frame, wide 16:9, muted sand and sepia palette, dusty haze, painterly semi-realistic,
cinematic soft light, melancholic desolate mood, low saturation, no text, no ui, no people.
```
**권장 크기:** 가로 1280×720 정도. 각 kind 1장(총 6장). 필요하면 노드별 변주.

---

## 3. 인물·사물 초상 (마을 준비 화면)

**용도:** 마을 준비(`Loadout`) 화면·시장 인트로 모달의 초상(현재 `Figures` 절차적 — 사용자 지적대로 조악). **투명 배경 PNG**, 흉상(가슴 위). 어두운 카드/배경 위에 얹힘.

**구도:** 세로 초상, 인물은 화면 대부분, **투명 배경**.

### 3a. 시장 (market)
말하는 이가 시장임이 한눈에 — 사막 교역 도시의 나이 든 상인.
```
Bust portrait of an old desert market trader, weathered sun-worn face, long grey beard,
wrapped turban and layered dusty robes, kind but tired eyes, warm lantern side light,
painterly semi-realistic, muted sepia and sand palette, plain transparent background,
melancholic dignified mood, no text, no ui.
```

### 3b. 원정대장 (leader) — 얼굴은 흐리게(익명)
```
Bust portrait of a hooded desert expedition leader seen slightly backlit, face shadowed under a
worn hood and cloth wraps, travel-worn gear, anonymous and resolute, dust in the air,
painterly semi-realistic, muted sand and sepia palette, plain transparent background,
solemn quiet mood, no visible face detail, no text, no ui.
```

### 3c. 배낭 (pack) — 사물
```
A worn leather-and-canvas expedition backpack, buckled straps, a bedroll and waterskin lashed on,
dusty and travel-used, three-quarter view, painterly semi-realistic, muted sand and sepia palette,
plain transparent background, soft light, no text, no ui.
```
**권장 크기:** 각 ~800×1000(초상), 배낭은 ~800×800. PNG 투명.

---

## 4. 공통 배경 (타이틀 · 마을 · 오프닝)

**용도:** 다크 UI 화면 뒤 배경(현재 `Backdrop` 절차적 — 밤하늘→모래 지평선 + 마을 실루엣). UI 가 위에 얹히므로 **중앙은 비교적 비우고**, 아래 지평선·먼 도시 실루엣 위주.
```
Wide desert night background, deep indigo sky fading to warm sand near a low horizon, faint stars,
a distant silhouette of a small desert city with domes and minarets along the horizon, empty calm
center for UI, dusty atmosphere, muted palette, painterly, cinematic, melancholic, no text, no ui.
```
**권장 크기:** 세로 1080×1920(모바일) 또는 화면비 대응. 중앙 여백 유지.

---

## 5. 오프닝 삽화 (서사 5장, 선택)

**용도:** 첫 플레이 오프닝(`Opening`, 현재 텍스트만). 각 슬라이드 뒤 삽화 1장씩(선택). 담담·서늘, 재앙 형상 금지.

| 장 | 문구(현재) | 삽화 프롬프트 핵심 |
|---|---|---|
| 1 | 해마다 원정대가 떠난다 | a lone caravan setting out into vast dunes at dawn, small against the desert |
| 2 | 거의 다 죽는다 | scattered footprints and a fallen pack half-buried in sand, no bodies shown |
| 3 | 모래폭풍이 글을 지운다 | a sandstorm erasing tracks and writing on stone, dust swallowing the land |
| 4 | 너는 그들을 거듭 보내는 자 | a distant overseer figure watching many faint paths into the desert |
| 5 | 죽기 전 단 한 번 남긴다 | a single object (a waterskin) left in the sand with a small carved mark |

각 프롬프트에 §0 공통 토큰 + `vertical composition, storytelling illustration` 붙이기.

---

## 6. 타이틀 키아트 (선택)

**용도:** 타이틀 화면 상단(로고는 코드 텍스트 유지, 그 뒤/위 키아트).
```
Key art for a desert roguelite, a lone silhouette facing an endless dune sea under a vast pale sky,
a faint far-off veil of sandstorm on the horizon, sense of distance and quiet dread, muted sepia,
painterly cinematic, melancholic, no text, no logo, negative space at top for a title.
```

---

## 7. 폰트 (텍스트 미감 — "굴림체 느낌" 개선)

이미지가 아니라 폰트지만 미감의 큰 부분. 현재 `assets/fonts/NanumGothic-Regular.ttf`(고딕, 밋밋).
- **본문 추천:** 세리프(명조) 계열이 사막·고전·서사 톤에 맞음 — **본명조 / 나눔명조(Nanum Myeongjo) / Noto Serif KR**. 전부 OFL(임베드 가능).
- **제목 추천:** 좀 더 무게 있는 명조 볼드 or 붓 느낌.
- **줄간격:** 코드에서 `line_spacing` 8 로 넉넉히 조정함(`UITheme.make_label`).
- **적용:** `project.godot`의 `gui/theme/custom_font` 를 새 ttf 로 교체(웹 두부 방지 위해 한글 글리프 포함 확인 — `known_issues` 참고). MSDF 임포트는 웹/GL 실기기 검증 필수.

---

## 적용 (뽑은 이미지 넣기)

1. `assets/art/` 에 PNG 저장(초상은 투명 PNG).
2. 절차적 draw 를 이미지로 교체 — 각 파일에 "나중 에셋 교체 여지" 주석이 있는 지점:
   - 지도: `scripts/ui/Map.gd`의 배경 draw → `TextureRect`(맨 뒤) 위에 노드/경로 draw 유지.
   - 단면: `scripts/ui/SectionArt.gd`의 `draw_section` → kind별 `Texture2D` blit.
   - 초상: `scripts/ui/Figures.gd` → `TextureRect`(kind별 텍스처)로 교체.
   - 배경: `scripts/ui/Backdrop.gd` → 배경 텍스처.
3. 웹 export 후 폰/시크릿 창에서 로딩·선명도 확인(경량 유지).

> **팁:** 한 세트를 같은 생성기·같은 스타일 토큰·같은 시드 계열로 뽑아야 톤이 통일된다. 지도 → 단면 → 초상 순으로, §0 공통 토큰을 매번 붙일 것.
