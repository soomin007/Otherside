# LangEN.gd 생성기 — 번역 JSON(들)을 합쳐 scripts/core/LangEN.gd 의 const TABLE 을 만든다.
# 사용: python tools/gen_lang_en.py <merged_or_multiple.json ...>
# 뒤에 오는 파일이 앞의 같은 키를 덮어쓴다(오버라이드는 마지막에).
# 키는 게임 코드 리터럴과 바이트 일치해야 한다 — 검증은 scratchpad 의 ko_strings.json 대조 스크립트로.
import json, io, sys, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "scripts", "core", "LangEN.gd")

def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")

table = {}
for p in sys.argv[1:]:
    with io.open(p, encoding="utf-8") as f:
        table.update(json.load(f))

lines = [
    "class_name LangEN",
    "extends RefCounted",
    "",
    "## 영어 번역 표 — 한국어 원문(코드·데이터의 리터럴과 바이트 단위 일치) → 영어.",
    "## ⚠️ tools/gen_lang_en.py 가 생성한다. 손으로 고칠 땐 값(영어)만 고치고 키는 절대 건드리지 말 것",
    "## (키가 원문과 1글자라도 다르면 그 문구는 조용히 한국어로 남는다). 항목 수: %d" % len(table),
    "",
    "const TABLE: Dictionary = {",
]
for k in sorted(table.keys()):
    v = table[k]
    if not isinstance(v, str) or v == "":
        continue
    lines.append('\t"%s": "%s",' % (esc(k), esc(v)))
lines.append("}")
lines.append("")

with io.open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(lines))
print("wrote", OUT, len(table), "entries")
