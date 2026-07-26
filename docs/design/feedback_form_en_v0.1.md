# 피드백 설문 영어판 (구글 폼) v0.1 — itch.io 공개용

한국어판(`feedback_form_v0.1.md`)의 9문항을 그대로 옮긴 영어판. 폼은 사용자(구글 계정)가 직접 개설하고,
여기 초안을 복사해 붙인다.

**개설 완료 (2026-07-26): https://forms.gle/B8qrsZJY7Fse3ybi6**

- itch 페이지 소개문의 "Feedback" 줄에 이 링크를 쓴다(`itch_핸드오프.md` §4에 반영됨).
- 인게임 "의견 보내기" 버튼(`GameState.FEEDBACK_URL`)은 당분간 한국어 폼 유지.
  영어 로컬라이제이션이 들어갈 때 로케일별 URL 분기(`FEEDBACK_URL_EN`)로 바꾼다.

## 폼 설정 체크리스트 (한국어판과 동일 — EoY 교훈)

- [ ] 설정 → 응답 → **"로그인 필요" 끄기** (익명 응답 필수 — 해외 응답자는 구글 로그인 장벽이 더 크다)
- [ ] **이메일 수집 안 함**
- [ ] 응답 횟수 제한 없음
- [ ] 보내기 → 링크 → **URL 단축** 체크

## 폼 제목·설명 (복붙용)

제목:

> See you on the other side — Player Feedback

설명:

> Thank you for playing.
> This takes about a minute. Feel free to skip the written questions at the end.
> Responses are collected anonymously and will help us improve the game.

## 문항 (복붙용)

한국어판과 같은 구성: 9문항, 필수는 앞 6개(전부 객관식), 서술형 3개는 선택.

1. **How much have you played?** (Multiple choice, required)
   - Played once or twice
   - Played several runs
   - Reached an ending
   - Still playing after reaching an ending
2. **What did you play on?** (Multiple choice, required)
   - Phone
   - Computer
   - Both
3. **Overall, how was the game?** (Linear scale 1–5, required. 1 = Not for me, 5 = Loved it)
4. **How did the length of a single expedition feel?** (Multiple choice, required)
   - Too short
   - About right
   - A bit long
5. **How was the difficulty?** (Multiple choice, required)
   - On the easy side
   - About right
   - On the hard side
   - It varied a lot between expeditions
6. **Did the items and marks left by previous expeditions help you?** (Multiple choice, required)
   - They helped, and some stuck with me
   - They helped
   - Not that much
   - I'm not sure
7. **Was there a moment that stayed with you? Tell us about it.** (Paragraph, optional)
8. **Was anything frustrating or confusing?** (Paragraph, optional)
9. **Anything else you'd like to share?** (Paragraph, optional)

- 6번 = 핵심 기둥(선택 반영) 체감 측정, 4번 = 런 길이, 5번 = 밸런스 2차 입력. 한국어판과 문항 번호가
  일대일 대응이라 두 폼의 응답 분포를 합쳐 볼 수 있다.
- 문항 추가 금지(한국어판과 같은 원칙 — 길수록 응답이 준다).

## 주의

- 게임이 아직 한국어 전용이므로, 폼 설명이나 itch 페이지에 그 사실을 명시한다(응답자가 "글을 못 읽었다"는
  피드백을 3번 점수로 내는 것과 구분하기 위해 — 필요하면 8번 응답에서 걸러 읽는다).
- 영어 로컬라이제이션 공개 시점에 이 폼을 그대로 재사용한다(문항 변경 없음).
