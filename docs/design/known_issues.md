# Known Issues — 반복하지 말 함정 (증상 → 원인 → 재발 방지)

> 버그·설계 함정·작업 실수를 발견하면 여기에 적는다. 세션 시작 루틴에서 먼저 읽어 예방.
> 게임 버그뿐 아니라 프로세스 실수(도구 오용, 커밋 누락)도 포함.

## 웹 export

- **증상:** 셰이더/GPUParticles 가 웹 빌드에서 깨지거나 안 보임.
  **원인:** GL Compatibility 렌더러 + 웹 export 가 이들을 제대로 지원하지 않음 (EoY 에서 확인).
  **방지:** 셰이더·GPUParticles 절대 금지. 폭풍은 CPUParticles2D + 3층 레이어. `CLAUDE.md` 웹 제약 참고.

- **증상:** GitHub Pages 배포 빌드가 멈추거나 SharedArrayBuffer 관련으로 깨짐.
  **원인:** Threads 지원 ON 이면 COOP/COEP cross-origin isolation 헤더가 필요한데 Pages 설정이 까다로움.
  **방지:** export 프리셋 "Web" 에서 Threads Support **끄기** + `ensure_cross_origin_isolation_headers` ON (반영됨).

## GDScript (전역 규칙 위반 흔한 패턴)

- **증상:** 런타임에 `Trying to assign an array of type "Array" to a variable of type "Array[T]"`.
  **원인:** Dictionary/`Dictionary.get`/JSON 파싱에서 나온 untyped Array 를 `Array[String]` 등에 직접 대입.
  **방지:** `for` 루프로 요소별 `append(T(value))`. 예: `TraceData.from_dict` 의 tags 복원 참고.
