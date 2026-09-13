#!/usr/bin/env python3
"""Build Sources/ChaJing/Resources/cus.json (简体和合本) for the ChaJing app.

Two input modes:

  1. --from-ibibles DIR   Use chapter files fetched by fetch_ibibles.py
                          (DIR/<code>/<chapter>.txt, one "verse<TAB>text" per line).
  2. (default)            Fall back to the public-domain CUV text shipped in the
                          `chinese-bible-search` npm package (traditional, from
                          springbible.fhl.net) and convert it to simplified with
                          OpenCC.  Requires: pip install opencc-python-reimplemented

Output schema (Sources/ChaJing/Resources/cus.json):
  {
    "version": "CUS", "source": "...",
    "books": [ { "id", "name", "abbr", "aliases", "pinyin": [syllables],
                 "chapters": [ [verse1, verse2, ...], ... ] } ]
  }
"""
import argparse
import json
import os
import re
import sys
import tarfile
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from books import BOOKS, book_dicts  # noqa: E402

OUT = os.path.join(HERE, "..", "Sources", "ChaJing", "Resources", "cus.json")

# Traditional abbreviations used by the npm package, in canonical book order.
TRAD_ABBRS = [
    "創", "出", "利", "民", "申", "書", "士", "得", "撒上", "撒下", "王上", "王下", "代上", "代下",
    "拉", "尼", "斯", "伯", "詩", "箴", "傳", "歌", "賽", "耶", "哀", "結", "但", "何", "珥", "摩",
    "俄", "拿", "彌", "鴻", "哈", "番", "該", "亞", "瑪", "太", "可", "路", "約", "徒", "羅",
    "林前", "林後", "加", "弗", "腓", "西", "帖前", "帖後", "提前", "提後", "多", "門", "來", "雅",
    "彼前", "彼後", "約一", "約二", "約三", "猶", "啟",
]
NPM_TARBALL = "https://registry.npmjs.org/chinese-bible-search/-/chinese-bible-search-0.0.7.tgz"


def empty_books():
    books = book_dicts()
    for b in books:
        b["chapters"] = [[] for _ in range(b.pop("chapterCount"))]
        b.pop("code")
    return books


def load_from_npm(cache_dir):
    import opencc  # type: ignore

    os.makedirs(cache_dir, exist_ok=True)
    tgz = os.path.join(cache_dir, "chinese-bible-search.tgz")
    if not os.path.exists(tgz):
        print("downloading", NPM_TARBALL)
        urllib.request.urlretrieve(NPM_TARBALL, tgz)
    with tarfile.open(tgz) as tf:
        js = tf.extractfile("package/bibleText.js").read().decode("utf-8")

    conv = opencc.OpenCC("t2s")
    abbr_to_idx = {a: i for i, a in enumerate(TRAD_ABBRS)}
    books = empty_books()
    line_re = re.compile(r"^\s*'([^\d']+?)(\d+):(\d+)\s(.*)',?\s*$")
    count = 0
    for line in js.splitlines():
        m = line_re.match(line)
        if not m:
            continue
        abbr, ch, vs, text = m.group(1), int(m.group(2)), int(m.group(3)), m.group(4)
        idx = abbr_to_idx[abbr]
        chapters = books[idx]["chapters"]
        while len(chapters) < ch:
            chapters.append([])
        verses = chapters[ch - 1]
        while len(verses) < vs:
            verses.append("")
        verses[vs - 1] = conv.convert(text.replace("\\'", "'"))
        count += 1
    print(f"parsed {count} verses from npm package")
    return books, "Chinese Union Version (traditional text from springbible.fhl.net via npm chinese-bible-search, converted to simplified with OpenCC)"


def load_from_ibibles(dirpath):
    books = empty_books()
    count = 0
    for (bid, _name, _abbr, _py, _al, code, nch) in BOOKS:
        bdir = os.path.join(dirpath, code)
        for ch in range(1, nch + 1):
            path = os.path.join(bdir, f"{ch}.txt")
            if not os.path.exists(path):
                raise SystemExit(f"missing chapter file {path}; run fetch_ibibles.py first")
            verses = books[bid - 1]["chapters"][ch - 1]
            with open(path, encoding="utf-8") as f:
                for line in f:
                    line = line.rstrip("\n")
                    if not line:
                        continue
                    n, text = line.split("\t", 1)
                    n = int(n)
                    while len(verses) < n:
                        verses.append("")
                    verses[n - 1] = text
                    count += 1
    print(f"parsed {count} verses from {dirpath}")
    return books, "圣经 简体和合本 (cus.ibibles.net)"


def validate(books):
    problems = []
    for b in books:
        for ci, verses in enumerate(b["chapters"], 1):
            if not verses:
                problems.append(f"{b['name']} {ci}: no verses")
            for vi, v in enumerate(verses, 1):
                if not v:
                    problems.append(f"{b['name']} {ci}:{vi}: empty verse")
    return problems


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--from-ibibles", metavar="DIR", help="directory produced by fetch_ibibles.py")
    ap.add_argument("--cache", default=os.path.join(HERE, ".cache"))
    ap.add_argument("--out", default=OUT)
    args = ap.parse_args()

    if args.from_ibibles:
        books, source = load_from_ibibles(args.from_ibibles)
    else:
        books, source = load_from_npm(args.cache)

    problems = validate(books)
    for p in problems[:20]:
        print("warning:", p)
    if len(problems) > 20:
        print(f"... {len(problems) - 20} more warnings")

    data = {"version": "CUS", "source": source, "books": books}
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    total = sum(len(c) for b in books for c in b["chapters"])
    print(f"wrote {args.out}: {len(books)} books, {total} verses")


if __name__ == "__main__":
    main()
