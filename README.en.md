# Bible Study App (好查经 ChaJing)

[中文说明](README.md)

A native macOS app for looking up Bible verses fast during Bible study. Press a global
shortcut, type a few letters, and the passage is in front of you.

**This app is for people who read Chinese.** The interface is Simplified Chinese only and
the bundled text is the Chinese Union Version (和合本, Simplified). The whole point of the
app is a search method built around Chinese: you find a book by the pinyin initials of its
Chinese name. English Bibles do not have this problem, so an English interface or English
translations are not planned. This page exists so the project can be found and understood;
pull requests are welcome all the same.

<p align="center"><img src="packaging/icon-source.png" width="140" alt="App icon"></p>

![Search window](docs/ui/shots/search-result-verse.light.png)

## Why

> While studying the Word and attending a Bible study group, I often needed to flip between
> chapters. I was still unfamiliar with the names of the books, so finding a passage was
> slow. I built this the way I wished it worked. I hope it helps brothers and sisters who,
> like me, are just beginning to seek the Lord. God be with you.

## What it does

- **Global shortcut ⌥Space** brings up the search window over whatever you are doing,
  including full-screen apps, without switching Spaces. Press it again, or esc, to put it
  away and get your keyboard focus back. No system permissions are required.
- **Pinyin-initial search.** `yhfy 4:24` finds 约翰福音 (John) 4:24. Full pinyin
  (`yuehan 3 16`), mixed (`yuehfy 4`), Chinese names (`约翰福音 4:24`), standard Chinese
  abbreviations (`约 4:24`, `林前 13:4-8`) and the pinyin initials of those abbreviations
  (`lq 13:4-8` for 林前, 1 Corinthians) all work. `*` matches any number of syllables and
  `?` matches one.
- **No fuzzy matching, on purpose.** A query either matches by the rules or returns
  nothing, so results stay short. Books that lack the requested chapter or verse are
  dropped: `yh 4:24` leaves only John, because 1 John 4 has 21 verses.
- **Several reader windows at once.** ⏎ opens the passage, ⇧⏎ or ⌘D opens it in a new
  window, and ⌘D in a reader duplicates it, so you can compare passages side by side.
  ← and → move between chapters.
- **⌘⏎ copies** the selected verses with their reference.
- **Stays out of the way.** It lives in the menu bar. Closing windows, ⌘Q and Quit from the
  Dock only put the windows away; choose 退出好查经 from the menu-bar icon to really quit.
- Fully offline. It collects nothing. See [PRIVACY.md](PRIVACY.md).

## Build

Requires macOS 13 or later and Xcode 15 or later (or the Swift 5.9 toolchain).

```bash
make test     # unit tests: matching rules, query parsing, bundled data
make run      # release build, assemble dist/好查经.app, open it
make install  # copy it to /Applications
```

The project is a Swift Package (AppKit + SwiftUI, no third-party dependencies). `make icon`
rebuilds the app icon from `packaging/icon-source.png`, and `make ui-shots` renders the UI
offscreen into `docs/ui/shots/` for the design documents in `docs/ui/`.

## Scripture text

Chinese Union Version, public domain. The bundled Simplified text was converted from the
Traditional text with OpenCC: 66 books, 31,103 verses. See the Chinese README for how to
regenerate it.

## License

[MIT](LICENSE). Author: [Lamonkey](https://github.com/Lamonkey)
