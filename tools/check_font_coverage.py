#!/usr/bin/env python3
"""임베드 폰트 글리프 커버리지 감사 — 웹 배포 전 한글/기호 두부(□) 예방.

배경: 웹 export 는 시스템 폰트 폴백이 없어, 임베드 폰트에 없는 글리프가 두부로 깨진다.
데스크톱은 시스템 폰트가 메워 안 보이므로 배포 후에야 드러난다(known_issues 참고).

이 도구는 scripts/ 의 한글 포함 문자열 리터럴에서 쓰이는 모든 문자를 모아,
  - MaruBuri(기본 폰트 = 최종 폴백): 하나라도 빠지면 어디서든 두부 → FAIL(exit 1)
  - NanumBrush(붓글씨): 빠진 글리프는 UITheme._static_init 의 MaruBuri 폴백이 메운다(정보성)
를 검사한다.

사용: python tools/check_font_coverage.py   (필요: pip install fonttools)
"""
import glob
import re
import sys

try:
    from fontTools.ttLib import TTFont
except ImportError:
    print("fontTools 가 필요합니다: pip install fonttools")
    sys.exit(2)

FONTS = {
    "MaruBuri (기본/폴백)": "assets/fonts/MaruBuri-Regular.ttf",
    "NanumBrush (붓글씨)": "assets/fonts/NanumBrushScript-Regular.ttf",
}
HANGUL = re.compile(r"[가-힣]")
STRLIT = re.compile(r'"([^"]*)"')


def codepoints(path: str) -> set:
    return set(TTFont(path).getBestCmap().keys())


def collect_displayed_chars() -> dict:
    """한글이 든 문자열 리터럴 = 표시 텍스트로 간주하고 그 안의 모든 문자를 센다."""
    chars: dict = {}
    for f in glob.glob("scripts/**/*.gd", recursive=True):
        try:
            text = open(f, encoding="utf-8").read()
        except OSError:
            continue
        for m in STRLIT.finditer(text):
            s = m.group(1)
            if HANGUL.search(s):
                for ch in s:
                    if ord(ch) >= 0x20:
                        chars[ch] = chars.get(ch, 0) + 1
    return chars


def main() -> int:
    chars = collect_displayed_chars()
    maru = codepoints(FONTS["MaruBuri (기본/폴백)"])
    brush = codepoints(FONTS["NanumBrush (붓글씨)"])

    maru_missing = sorted(ch for ch in chars if ord(ch) not in maru)
    brush_missing = sorted(ch for ch in chars if ord(ch) not in brush)

    def fmt(cs):
        return " ".join(f"{c}(U+{ord(c):04X})" for c in cs) if cs else "없음"

    print(f"표시 문자열 고유 문자 {len(chars)}개 검사")
    print(f"[NanumBrush 미포함 {len(brush_missing)}개 — MaruBuri 폴백이 메움]")
    print(f"  {fmt(brush_missing)}")
    print(f"[MaruBuri(최종 폴백) 미포함 {len(maru_missing)}개]")
    print(f"  {fmt(maru_missing)}")

    if maru_missing:
        print("\nFAIL: 기본 폰트에 없는 글리프 = 폴백으로도 못 메움 = 웹 두부. 위 문자를 피하거나 폰트를 보강하라.")
        return 1
    print("\nPASS: 모든 표시 문자가 기본 폰트로 커버됨(웹 두부 없음).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
