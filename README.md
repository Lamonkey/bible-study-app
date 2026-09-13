# 查经 ChaJing — macOS 原生经文快速检索

菜单栏小工具：按快捷键在屏幕中央弹出输入条，用**拼音首字母 / 拼音 / 中文书名 + 章:节**
精确定位简体和合本经文，回车打开阅读窗口，⌘回车复制经文。

```
yhfy 4:24        约翰福音 4:24（拼音首字母）
yhfy 4 24        章节之间可用空格、冒号、全角冒号、点、逗号
yuehan 3 16      完整拼音（前缀即可）；同时命中约翰福音 / 约翰一书 3:16
yuehfy 4         首字母和完整拼音可以混用，每个音节按前缀匹配
约 4:24          中文简称
约翰福音 4:24    中文全名（子串精确匹配）
林前 13:4-8      节范围
*fy 3:16         * 匹配任意个音节，? 匹配一个音节
```

**没有模糊匹配**：书名部分要么按规则精确命中，要么不出结果，避免结果过多难以锁定。
另外，候选书卷如果没有该章或该节会被自动排除，所以 `yh 4:24` 只剩约翰福音
（约翰一书 4 章只有 21 节，约翰二书只有 1 章）。

## 快捷键

| 快捷键 | 说明 |
| --- | --- |
| **按住 Space 再按 P** | 你要的组合键。系统级生效，需要「辅助功能」权限（首次启动会弹提示）。 |
| **⌥ Space** | 无需任何权限的备用快捷键，始终可用。 |
| 菜单栏图标 | 点击「打开查经搜索」 |

Space+P 的实现：Space 是普通输入键，所以 app 用事件 tap 把 Space 按下先"扣住"最多 0.35 秒；
这段时间内按了 P 就弹出搜索（Space 和 P 都不会传给前台 app），
否则原样补发 Space 给前台 app，正常打字不受影响。ChaJing 自己处于前台时不拦截。

输入条内：`↑ ↓`（或 `⌃N ⌃P`）选择，`⏎` 打开阅读窗口，`⌘⏎` 复制所选经文到剪贴板，`esc` 关闭。
阅读窗口：`←` `→` 翻章。

## 构建 / 运行（需要 macOS 13+，Xcode 15+ 或 Swift 5.9 工具链）

```bash
cd chajing
make test        # 单元测试（匹配规则、解析、数据完整性）
make run         # swift build -c release，打包 dist/ChaJing.app 并打开
make install     # 拷贝到 /Applications
```

也可以 `open Package.swift` 用 Xcode 打开直接运行（scheme: ChaJing）。

首次运行 Space+P：系统弹出辅助功能提示 → 系统设置 → 隐私与安全性 → 辅助功能 → 打开 ChaJing。
`make app` 使用 ad-hoc 签名，每次重新构建后权限可能需要重新勾选一次（把旧条目删掉再加）。

## 经文数据

`Sources/ChaJing/Resources/cus.json`（约 3 MB）随 app 打包，结构：

```json
{ "version": "CUS", "source": "...",
  "books": [ { "id": 43, "name": "约翰福音", "abbr": "约", "aliases": [],
               "pinyin": ["yue","han","fu","yin"],
               "chapters": [ ["verse 1:1", "verse 1:2", ...], ... ] } ] }
```

数据来源两种方式（`scripts/`）：

1. **cus.ibibles.net（你指定的来源）**
   ```bash
   python3 scripts/fetch_ibibles.py            # 逐章抓取到 scripts/.cache/ibibles/
   python3 scripts/build_data.py --from-ibibles scripts/.cache/ibibles
   make app
   ```
   注意：写这个脚本的环境无法访问 cus.ibibles.net，脚本里的 URL 形式
   （`quote.php?cus-joh/4`）和解析是按 ibibles.net 已知格式写的、未经实际验证。
   若抓取报 404 或"NO VERSES PARSED"，在浏览器里点开任意一章看链接格式，改脚本顶部的 `BASE` 即可。
2. **当前打包的默认数据**：和合本文本（公共领域，来自 springbible.fhl.net，经 npm 包
   `chinese-bible-search` 分发），用 OpenCC 繁转简生成，共 66 卷 31,103 节。
   重新生成：`pip install opencc-python-reimplemented && make data`。

`scripts/chajing_cli.py` 是匹配规则的 Python 参考实现，和 Swift 版规则一致，
可在任何平台快速验证：`python3 scripts/chajing_cli.py "yhfy 4:24"`、`--test` 跑断言。

## 代码结构

```
Sources/ChaJing/
  main.swift              NSApplication 启动（菜单栏 app，无 Dock 图标）
  AppDelegate.swift       状态栏菜单、注册两种快捷键、权限轮询
  QueryParser.swift       "yhfy 4:24-26" -> 书名部分 + 章/节/节尾
  BookMatcher.swift       拼音音节/通配符/中文精确匹配（无模糊）
  SearchEngine.swift      组合解析与匹配，按章节存在性过滤
  BibleStore.swift        加载 cus.json
  SearchPanel.swift       Spotlight 风格浮动面板 + 键盘导航
  SearchView.swift        SwiftUI 输入条 / 结果列表 / 经文预览
  ReaderWindow.swift      阅读窗口（整章、高亮所选节、左右翻章）
  GlobalHotkey.swift      Carbon 全局热键 ⌥Space
  SpaceChordMonitor.swift CGEventTap 实现的 Space+P 组合键
Tests/ChaJingTests/       XCTest
scripts/                  数据抓取/构建脚本、Python 参考实现
packaging/Info.plist      LSUIElement=true
```
