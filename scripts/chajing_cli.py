#!/usr/bin/env python3
"""Command-line reference implementation of the ChaJing query logic.

Mirrors Sources/ChaJing/QueryParser.swift + BookMatcher.swift so the matching
rules can be exercised without Xcode:

    python3 scripts/chajing_cli.py "yhfy 4:24"
    python3 scripts/chajing_cli.py "yuehan 3 16"
    python3 scripts/chajing_cli.py "约 4:24"
    python3 scripts/chajing_cli.py --test      # run the built-in assertions

Rules (no fuzzy matching):
  * Name part = leading run of non-digit characters.
  * Chinese name: exact substring of the book name / alias, or exact abbreviation.
  * Latin name: pinyin (of the full name or of the abbreviation), matched syllable
    by syllable. Each query chunk must be a
    prefix of the corresponding syllable ("yhfy", "yuehan", "yuehfy" all hit
    约翰福音). "*" matches any number of whole syllables, "?" exactly one.
    A query may stop early (prefix of the book), but never skips or reorders.
  * Numbers: "4:24", "4 24", "4.24", "4：24", "4:24-26" -> chapter / verse range.
    A chapter or verse that does not exist in a candidate book drops that book.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

NUM_RE = re.compile(r"^\s*(\d+)(?:\s*[:：.,，、\s]\s*(\d+)(?:\s*[-~—至到]\s*(\d+))?)?\s*$")
NAME_RE = re.compile(r"^([^\d]*)")


def parse_query(q):
    q = q.strip()
    name = NAME_RE.match(q).group(1)
    rest = q[len(name):]
    name = name.strip().lower()
    chapter = verse = verse_end = None
    if rest.strip():
        m = NUM_RE.match(rest)
        if not m:
            return None
        chapter = int(m.group(1))
        verse = int(m.group(2)) if m.group(2) else None
        verse_end = int(m.group(3)) if m.group(3) else None
    return name, chapter, verse, verse_end


def has_cjk(s):
    return any("一" <= c <= "鿿" for c in s)


def pinyin_match(q, syls, qi=0, si=0):
    """True if q[qi:] matches syllables syls[si:] under the rules above."""
    if qi == len(q):
        return True
    c = q[qi]
    if c == "*":
        for s2 in range(si, len(syls) + 1):
            if pinyin_match(q, syls, qi + 1, s2):
                return True
        return False
    if si == len(syls):
        return False
    if c == "?":
        return pinyin_match(q, syls, qi + 1, si + 1)
    syl = syls[si]
    for k in range(1, len(syl) + 1):
        if qi + k > len(q) or q[qi:qi + k] != syl[:k]:
            break
        if pinyin_match(q, syls, qi + k, si + 1):
            return True
    return False


def match_books(name, books):
    """Return [(rank, book)] sorted; rank 0 is strongest."""
    hits = []
    if not name:
        return [(3, b) for b in books]
    if has_cjk(name):
        for b in books:
            names = [b["name"]] + b.get("aliases", [])
            if name == b["abbr"] or name in names:
                hits.append((0, b))
            elif any(n.startswith(name) for n in names):
                hits.append((1, b))
            elif any(name in n for n in names):
                hits.append((2, b))
        hits.sort(key=lambda h: (h[0], h[1]["id"]))
        return hits
    if not re.fullmatch(r"[a-z*?]+", name):
        return []
    for b in books:
        # Full name and standard abbreviation (林前 -> "lq" / "linqian") are both
        # matched; the better rank wins.
        best = None
        for syls in (b["pinyin"], abbr_pinyin(b)):
            if not syls or not pinyin_match(name, syls):
                continue
            initials = "".join(s[0] for s in syls)
            full = "".join(syls)
            if name == initials or name == full:
                rank = 0
            elif initials.startswith(name) or full.startswith(name):
                rank = 1
            else:
                rank = 2
            if best is None or rank < best:
                best = rank
        if best is not None:
            hits.append((best, b))
    hits.sort(key=lambda h: (h[0], h[1]["id"]))
    return hits


def abbr_pinyin(b):
    """Pinyin syllables of the abbreviation, found by locating each of its characters
    in the book name in order: ["lin", "qian"] for 林前 (哥林多前书)."""
    name, syls = b["name"], b["pinyin"]
    if len(name) != len(syls):
        return []
    out, pos = [], 0
    for ch in b["abbr"]:
        i = name.find(ch, pos)
        if i < 0:
            return []
        out.append(syls[i])
        pos = i + 1
    return out


def search(q, books):
    parsed = parse_query(q)
    if parsed is None:
        return []
    name, ch, vs, ve = parsed
    results = []
    for rank, b in match_books(name, books):
        chapters = b["chapters"]
        if ch is not None:
            if ch < 1 or ch > len(chapters):
                continue
            if vs is not None and (vs < 1 or vs > len(chapters[ch - 1])):
                continue
        results.append((rank, b, ch, vs, ve))
    return results


def load_books():
    with open(os.path.join(HERE, "..", "Sources", "ChaJing", "Resources", "cus.json"), encoding="utf-8") as f:
        return json.load(f)["books"]


def run_tests(books):
    def names(q):
        return [b["name"] for _, b, *_ in search(q, books)]

    assert names("yhfy") == ["约翰福音"]
    assert names("yhfy 4:24")[0] == "约翰福音"
    assert names("yhfy 4 24") == ["约翰福音"]
    assert names("yhfy4:24") == ["约翰福音"]
    assert names("yuehan") == ["约翰福音", "约翰一书", "约翰二书", "约翰三书"]
    assert names("yuehfy") == ["约翰福音"]
    assert names("yh 4:24") == ["约翰福音"], names("yh 4:24")   # 约翰一书 4 only has 21 verses
    assert names("yh 4:21") == ["约翰福音", "约翰一书"]
    assert names("y*fy") == ["约翰福音"]
    assert names("*fy") == ["西番雅书", "马太福音", "马可福音", "路加福音", "约翰福音"]  # xi-FAN-YA also fits
    assert names("?han") == ["约翰福音", "约翰一书", "约翰二书", "约翰三书"]
    assert names("mt") == ["马太福音"]
    assert names("lq") == ["哥林多前书"]                # pinyin initials of the abbreviation 林前
    assert names("linqian") == ["哥林多前书"]
    assert names("lq 13:4-8") == ["哥林多前书"]
    assert names("lqs") == []                          # 林前 has no 书 syllable
    assert names("tq") == ["帖撒罗尼迦前书", "提摩太前书"]
    assert names("yue")[0] == "约翰福音"                # abbreviation 约 ranks first, like "约"
    assert names("约翰福音 4:24") == ["约翰福音"]
    assert names("约 4:24") == ["约翰福音", "约书亚记"]   # abbreviation first, then 约书亚记 4:24 (exists)
    assert names("约")[:1] == ["约翰福音"]           # abbreviation ranks first
    assert "约书亚记" in names("约")
    assert names("福音") == ["马太福音", "马可福音", "路加福音", "约翰福音"]
    assert names("林前 13") == ["哥林多前书"]
    assert names("约翰壹书") == ["约翰一书"]
    assert names("yhfy 4:24-26") == ["约翰福音"]
    assert names("yhfy 99") == []
    assert names("yhfy 4:999") == []
    assert names("yhfy 4:24:") == []                  # malformed numbers -> nothing
    assert names("zzz") == []
    assert names("yhfyx") == []                       # no fuzzy tolerance
    p = parse_query("yhfy 4:24-26")
    assert p == ("yhfy", 4, 24, 26), p
    assert parse_query("约翰福音") == ("约翰福音", None, None, None)
    print("all tests passed")


def main():
    books = load_books()
    if len(sys.argv) > 1 and sys.argv[1] == "--test":
        run_tests(books)
        return
    q = " ".join(sys.argv[1:])
    for rank, b, ch, vs, ve in search(q, books):
        if ch is None:
            print(f"[{rank}] {b['name']} ({b['abbr']}) {len(b['chapters'])}章")
            continue
        verses = b["chapters"][ch - 1]
        if vs is None:
            print(f"[{rank}] {b['name']} {ch}  ({len(verses)}节)  {verses[0][:40]}...")
            continue
        end = min(ve or vs, len(verses))
        for n in range(vs, end + 1):
            print(f"[{rank}] {b['name']} {ch}:{n}  {verses[n - 1]}")


if __name__ == "__main__":
    main()
