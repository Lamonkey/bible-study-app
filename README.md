# 好查经 ChaJing — macOS 原生经文快速检索

<p align="center"><img src="packaging/icon-source.png" width="160" alt="好查经图标"></p>

> 在学习主的话语、参加查经小组时，我时常需要翻阅圣经的不同章节。对于圣经书卷名字还不熟悉的我，
> 翻阅起来效率较低，于是按照我心中所想，做了这个方便查阅主话语的软件。
> 希望能帮助到和我一样刚开始仰慕主的弟兄姊妹，愿神与你们同在。

![搜索窗口](docs/ui/shots/search-result-verse.light.png)

macOS 应用，有 Dock 图标、主菜单和一个菜单栏图标。读经、查经时打开它，全局快捷键即生效；
按快捷键弹出主窗口的输入条，用**拼音首字母 / 拼音 / 中文书名 + 章:节**
精确定位简体和合本经文，回车打开阅读窗口，⌘回车复制经文。阅读窗口可以开任意多个，
方便同时对照几处经文。

关闭窗口、⌘Q、Dock 上的「退出」都只是把窗口收起来，app 留在后台，快捷键继续有效；
只有菜单栏图标（或「好查经」菜单）里的「退出好查经」才真正退出。系统注销/关机时会正常退出。

```
yhfy 4:24        约翰福音 4:24（拼音首字母）
yhfy 4 24        章节之间可用空格、冒号、全角冒号、点、逗号
yuehan 3 16      完整拼音（前缀即可）；同时命中约翰福音 / 约翰一书 3:16
yuehfy 4         首字母和完整拼音可以混用，每个音节按前缀匹配
约 4:24          中文简称
lq 13:4-8        中文简称的拼音首字母（林前 → lq，帖前 → tq，约一 → yy）
linqian 13       中文简称的完整拼音，同样按前缀逐音节匹配
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
| **按住 Space 再按 P** | 你要的组合键。系统级生效，需要「辅助功能」权限（首次启动会弹提示）。好查经自己在前台时不拦截。 |
| **⌥ Space** | 无需任何权限的备用快捷键，始终可用；再按一次收起搜索窗口。在别的 app（包括全屏 app）里按，搜索窗口直接浮在它上面，不切换桌面；esc / ⌘⏎ 之后焦点回到原来的 app。 |
| **⌘F** | 好查经在前台时（例如正在阅读窗口里）呼出搜索。点 Dock 图标、菜单栏图标或菜单「文件 → 搜索经文」也可以。 |

Space+P 的实现：Space 是普通输入键，所以 app 用事件 tap 把 Space 按下先"扣住"最多 0.35 秒；
这段时间内按了 P 就弹出搜索（Space 和 P 都不会传给前台 app），
否则原样补发 Space 给前台 app，正常打字不受影响。ChaJing 自己处于前台、或搜索窗口正在接收键盘输入时不拦截。

搜索窗口内：`↑ ↓`（或 `⌃N ⌃P`）选择，`⏎` 在最前面的阅读窗口里打开（没有则新建），
`⇧⏎` 或 `⌘D` 在新阅读窗口里打开，`⌘⏎` 复制所选经文到剪贴板，`esc` / `⌘W` 隐藏。

阅读窗口：`←` `→` 翻章，`⌘D`（或右上角 ⧉ 按钮）把当前经文复制到一个新窗口，
新窗口沿用原窗口大小并错开排列，想开几个就开几个；「窗口」菜单列出全部窗口。

## 构建 / 运行（需要 macOS 13+，Xcode 15+ 或 Swift 5.9 工具链）

```bash
cd chajing
make test        # 单元测试（匹配规则、解析、数据完整性）
make run         # swift build -c release，打包 dist/好查经.app 并打开
make install     # 拷贝到 /Applications
```

也可以 `open Package.swift` 用 Xcode 打开直接运行（scheme: ChaJing）。

首次运行 Space+P：系统弹出辅助功能提示 → 系统设置 → 隐私与安全性 → 辅助功能 → 打开 好查经。
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
  main.swift              NSApplication 启动（普通 app，有 Dock 图标和主菜单）
  AppDelegate.swift       主菜单、菜单栏图标、后台驻留、注册两种快捷键、权限轮询
  QueryParser.swift       "yhfy 4:24-26" -> 书名部分 + 章/节/节尾
  BookMatcher.swift       拼音音节/通配符/中文精确匹配（无模糊）
  SearchEngine.swift      组合解析与匹配，按章节存在性过滤
  BibleStore.swift        加载 cus.json
  SearchWindow.swift      主窗口（搜索，不激活应用的面板，可浮在全屏应用之上）+ 键盘导航
  SearchView.swift        SwiftUI 输入条 / 结果列表 / 经文预览 / 可点击的底部提示栏
  ReaderWindow.swift      阅读窗口（可多开、⌘D 复制、整章、高亮所选节、左右翻章）
  AboutWindow.swift       「关于」窗口
  UIRegion.swift          给界面部件命名，供离屏截图导出坐标（运行时无作用）
  GlobalHotkey.swift      Carbon 全局热键 ⌥Space
  SpaceChordMonitor.swift CGEventTap 实现的 Space+P 组合键
Tests/ChaJingTests/       XCTest；UISnapshotTests 离屏渲染界面截图（make ui-shots）
scripts/                  数据抓取/构建脚本、Python 参考实现、图标生成、虚拟机测试脚本
packaging/                Info.plist、图标原图与 AppIcon.icns
docs/ui/                  界面文档：app-map / wireflow / user-flow / storyboard 与截图
```

## 界面文档

`docs/ui/` 下有四份从源码和真实渲染生成的界面文档，用浏览器直接打开：

- `app-map.html` 界面地图：每个界面的渲染图，部件带编号（SW4.3 这类），反馈时按编号说话
- `wireflow.html` 界面流程：所有界面状态和它们之间的跳转
- `user-flow.html` 用户流程：按任务画的流程图
- `storyboard.html` 分镜故事板：七个使用场景逐帧走一遍

截图和部件坐标由 `make ui-shots` 离屏生成，不会弹出窗口。

## 许可证

代码以 [MIT](LICENSE) 许可证开源。经文为和合本，属公共领域。

作者：[Lamonkey](https://github.com/Lamonkey)
