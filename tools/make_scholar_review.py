"""Writes docs/SCHOLAR_REVIEW.md: every fiqh / hadith question with its answer and reference,
for review by qualified scholars before release.  python3 tools/make_scholar_review.py"""
import json, re, os
ROOT = os.path.join(os.path.dirname(__file__), "..")
src = open(os.path.join(ROOT, "scripts/pcg/FiqhData.gd"), encoding="utf-8").read()
consts = {}
for name in ["FARD", "WAJIB", "SUNNAH", "SUNNAH_M", "YES", "NO"]:
    m = re.search(r"^const %s := (\[.*\])$" % name, src, re.M)
    consts[name] = m.group(1)


def block(name, end):
    a = src.index("const %s := " % name) + len("const %s := " % name)
    b = src.index(end, a)
    t = src[a:b].strip()
    t = "\n".join(l for l in t.splitlines() if not l.strip().startswith("#"))
    for k, v in consts.items():
        t = re.sub(r"(?<![\w\"])%s(?![\w\"])" % k, v, t)
    t = re.sub(r",(\s*[\]}])", r"\1", t)
    return json.loads(t)


schools = block("SCHOOLS", "\nconst SCHOOL_ORDER")
books = block("BOOKS", "\n\nconst FARD")
topics = block("TOPICS", "\n\n## Questions with several")
multi = block("MULTI", "\n\n## Questions about well-known")
hadq = block("HADITH_Q", "\n\n\n## [topic index")
out = ["# Scholar review list (fiqh and hadith questions)", "",
       "Please check every answer below. Mark mistakes and send the list back; the game is updated from it.",
       "Each line: question (school) -> RIGHT answer | other options shown | reference.", ""]
for t in topics:
    out.append("## " + t["q"][0])
    out.append("Urdu: " + t["q"][1] + "  |  Arabic: " + t["q"][2])
    for school, key in t["ans"].items():
        others = [v[0] for k, v in t["opts"].items() if k != key]
        ref = books[school][1]
        extra = ", ".join(t.get("refs", [])) + ("; Bukhari " + ", ".join(map(str, t["hadith"])) if t.get("hadith") else "")
        out.append("- **%s**: %s  (others: %s)  — %s %s" % (schools[school][0], t["opts"][key][0], " / ".join(others), ref, extra))
    out.append("")
out.append("# Choose-all questions")
for m in multi:
    right = [m["a"][i][0] for i in m["correct"]]
    wrong = [a[0] for i, a in enumerate(m["a"]) if i not in m["correct"]]
    out.append("- (%s) %s -> RIGHT: %s | WRONG: %s" % (schools[m["school"]][0], m["q"][0], "; ".join(right), "; ".join(wrong)))
out += ["", "# Hadith questions (Sahih al-Bukhari, text shown in the game from the dataset)"]
for h in hadq:
    out.append("- Bukhari %d: %s -> %s (others: %s)" % (h["hadith"], h["q"][0], h["a"][0][0], " / ".join(a[0] for a in h["a"][1:])))
open(os.path.join(ROOT, "docs/SCHOLAR_REVIEW.md"), "w", encoding="utf-8").write("\n".join(out) + "\n")
print("topics", len(topics), "multi", len(multi), "hadith", len(hadq))
