#!/usr/bin/env python3
"""Fetch 简体和合本 chapter text from https://cus.ibibles.net/ into a local dir.

Usage:
    python3 scripts/fetch_ibibles.py [--out scripts/.cache/ibibles] [--delay 0.5]
    python3 scripts/build_data.py --from-ibibles scripts/.cache/ibibles

ibibles.net serves passages through its quote endpoint, e.g.
    https://cus.ibibles.net/quote.php?cus-joh/4:24     (single verse)
    https://cus.ibibles.net/quote.php?cus-joh/4        (whole chapter)
The HTML for a chapter contains lines like "4:24 神是个灵..." (one per verse);
this script strips tags and extracts "<chapter>:<verse> <text>" pairs, so it
tolerates layout differences as long as verse numbers stay in that form.

NOTE: the site could not be reached from the environment where this script was
written, so the URL pattern and parser are best-effort. If a request 404s, open
the site in a browser, look at the link for one chapter, and adjust BASE below.
"""
import argparse
import html
import os
import re
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from books import BOOKS  # noqa: E402

BASE = "https://cus.ibibles.net/quote.php?cus-{code}/{chapter}"
UA = "Mozilla/5.0 (ChaJing bible study app; personal use)"

TAG_RE = re.compile(r"<[^>]+>")
VERSE_RE = re.compile(r"(?:(?<=\s)|^)(\d{1,3}):(\d{1,3})\s*([^\r\n]*?)(?=\s+\d{1,3}:\d{1,3}\s|\s*$)")


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as resp:
        raw = resp.read()
    for enc in ("utf-8", "gb18030", "big5"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode("utf-8", "replace")


def parse_chapter(page, chapter):
    text = TAG_RE.sub(" ", page.replace("<br>", "\n").replace("<br/>", "\n").replace("<br />", "\n"))
    text = html.unescape(text)
    text = re.sub(r"[ \t　]+", " ", text)
    verses = {}
    for m in re.finditer(r"(\d{1,3}):(\d{1,3})\s+", text):
        ch, vs = int(m.group(1)), int(m.group(2))
        if ch != chapter:
            continue
        start = m.end()
        nxt = re.compile(r"\s\d{1,3}:\d{1,3}\s").search(text, start)
        end = nxt.start() if nxt else len(text)
        body = text[start:end].strip()
        body = re.split(r"\n\s*\n", body)[0].strip()
        if body and vs not in verses:
            verses[vs] = body
    return verses


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(HERE, ".cache", "ibibles"))
    ap.add_argument("--delay", type=float, default=0.5, help="seconds between requests")
    ap.add_argument("--only", help="only fetch this book code, e.g. joh")
    args = ap.parse_args()

    for (_bid, name, _abbr, _py, _al, code, nch) in BOOKS:
        if args.only and code != args.only:
            continue
        bdir = os.path.join(args.out, code)
        os.makedirs(bdir, exist_ok=True)
        for ch in range(1, nch + 1):
            path = os.path.join(bdir, f"{ch}.txt")
            if os.path.exists(path) and os.path.getsize(path) > 0:
                continue
            url = BASE.format(code=code, chapter=ch)
            try:
                page = fetch(url)
            except Exception as e:  # noqa: BLE001
                print(f"FAILED {name} {ch}: {url}: {e}")
                continue
            verses = parse_chapter(page, ch)
            if not verses:
                print(f"NO VERSES PARSED for {name} {ch}: {url} (saving raw html for inspection)")
                with open(path + ".html", "w", encoding="utf-8") as f:
                    f.write(page)
                continue
            with open(path, "w", encoding="utf-8") as f:
                for n in sorted(verses):
                    f.write(f"{n}\t{verses[n]}\n")
            print(f"{name} {ch}: {len(verses)} verses")
            time.sleep(args.delay)


if __name__ == "__main__":
    main()
