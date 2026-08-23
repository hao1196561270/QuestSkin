# QuestSkin

> **正式服 Midnight 12.x 极简任务追踪重绘插件** — 细线分隔 · 保留暴雪字体 · 宽度/高度可调 · 滚轮时才显现的滚动条

[![WoW](https://img.shields.io/badge/WoW-Midnight%2012.1-ffcc00)](https://warcraft.wiki.gg/wiki/Patch_12.1.0)
[![Interface](https://img.shields.io/badge/Interface-120100-blue)](https://warcraft.wiki.gg/wiki/TOC_format)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Lua](https://img.shields.io/badge/Lua-5.1-2C2D72)](https://www.lua.org/)

QuestSkin 完全重绘替代暴雪默认的 `ObjectiveTrackerFrame`（任务/成就/世界任务等追踪框），不做任何数值增强，**v1.0 严格纯美化**。地图打开时自动隐藏，避免与世界地图重叠。

---

## ✨ 特性

| 特性 | 说明 |
|---|---|
| **极简细线风** | 透明底 + 1px 淡白细线边框 + 块间 1px 分隔线，无毛玻璃/大色块，轻量不挡画面 |
| **保留暴雪字体** | 刻意不替换字体，仅重做颜色与间距：标题金色 `1,0.82,0`，进行中 `0.95,0.95,0.95`，已完成 `0.35,1,0.35` |
| **可拖动** | 按住框体任意位置左键拖动，坐标写入 `SavedVariables`，重载后保留 |
| **宽度/高度可调** | 设置面板滑条：宽度 `200–420`（默认 260），最大高度 `180–700`（默认 420） |
| **智能滚动条** | 超出最大高度时启用鼠标滚轮滚动；**滚动条平时隐藏，仅滚轮滚动时显现 1.2 秒后淡出**，不常驻遮挡 |
| **地图自适应** | 世界地图 `M` 打开时自动隐藏，关闭时自动恢复，彻底解决重叠错位 |
| **总开关** | 设置面板一键“禁用 QuestSkin，恢复官方追踪框”，避免卡死 |
| **零依赖** | 纯原生 WoW API，零 Ace3/Lib，加载快 |
| **中英本地化** | `locales/` 表结构，首发 `zhCN`，`enUS` 占位 |

---

## 📸 预览

<!-- TODO: 替换实机截图 — 建议截图：1) 空列表/有任务对比 2) 超追踪◆高亮 3) 地图打开自动隐藏 4) 设置面板宽度/高度滑条 -->

```
┌─────────────────────────────────┐
│ 任务  4              按住左键拖动 │  ← 标题栏（计数 + 提示）
├─────────────────────────────────┤  ← 1px 分隔线（0.08 透明度）
│ ▌ 不太谦虚的提议               │  ← 左侧 2px 指示线（有完成项则绿色）
│   ○ 收集 8 个毁灭的材料 0/8     │
│   ○ 与克拉苏斯对话 0/1          │
├ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┤  ← 块间细线
│ ▌ 克拉苏斯的魔法纲要            │
│   ● 已完成 1/1                  │
│ ...（超出则滚轮滚动）           │
└─────────────────────────────────┘
  1px 外边框  透明底  悬停 0.04 高亮
```

> 实际效果以游戏内为准；空列表显示 `暂无追踪任务（在任务日志中 Shift+点击追踪）`

---

## 📦 安装

### 方式 A：GitHub 下载（推荐）

1. 打开 https://github.com/hao1196561270/QuestSkin → `Code` → `Download ZIP`
2. 解压后将 `QuestSkin` 文件夹放入：

```
World of Warcraft/_retail_/Interface/AddOns/QuestSkin
```

3. 重启游戏，角色选择界面左下角 **插件** 勾选 `QuestSkin`

### 方式 B：Git 克隆

```powershell
cd "World of Warcraft/_retail_/Interface/AddOns"
git clone https://github.com/hao1196561270/QuestSkin.git
```

### 验证

进游戏后聊天框输入：

```
/qs
```

应打开设置面板；框体出现在屏幕右上 `TOPRIGHT -32,-200`。

---

## ⚙️ 设置

`ESC → 选项 → 插件 → QuestSkin` 或 `/qs`

| 项 | 操作 |
|---|---|
| **启用 QuestSkin** | 勾选后隐藏官方追踪框，显示极简重绘；取消则恢复官方 |
| **宽度** | 滑条 `200–420`，实时生效 |
| **最大高度** | 滑条 `180–700`，超出则滚轮滚动 |
| **重置位置/尺寸** | 一键回到默认锚点与尺寸 |

宽度/高度会写入 `QuestSkinDB.width` / `QuestSkinDB.maxHeight`，重载后保留。

---

## 🎮 使用

- **追踪任务**：任务日志 `L` 中对任务 `Shift+点击` 加入/移除追踪（Midnight 12.1 的 Watch 列表）
- **打开任务详情**：点击任意任务块
- **拖动**：按住框体任意位置左键拖动
- **滚动**：任务很多时，鼠标悬停框体滚轮滚动
- **开关**：

```
/qs on      # 启用
/qs off     # 禁用，恢复官方
/qs reset   # 重置位置与尺寸到默认值
/qs         # 打开设置面板
```

---

## 🧩 技术细节（给开发者）

### Midnight 12.1 兼容坑

| 坑 | 现象 | 对策 |
|---|---|---|
| `C_QuestLog.GetInfo().isWatched` 恒为 `nil` | 实测 `GetNumQuestLogEntries()=78` 全为 `nil`，导致 `任务 0` | 改用 `C_QuestLog.GetNumQuestWatches() + GetQuestIDForQuestWatchIndex(i)` 主路径，`GetNumQuestWatches()` 二级兜底，`isWatched` 仅作最后兜底（已在 `core.lua:GetWatchedQuests()` 实现） |
| `ObjectiveTrackerFrame` 顽固重现 | `hooksecurefunc(Show)` 单钩易被地图/战斗 taint 冲掉 | 双钩 `hooksecurefunc` + `HookScript(OnShow/OnHide)` + `UpdateTracker` 入口强检 `WorldMapFrame:IsShown()` + 0.4 秒轮询强制隐藏 |
| 换行高度算错导致裁切 | `GetStringHeight()` 在宽度未定时返回 0 | `UpdateTracker()` 先 `content:SetWidth(w-34)` 再 `CreateQuestBlock`，并加 `h<20` 保底 |
| 滚动条常驻遮挡 | `UIPanelScrollFrameTemplate` 背景丑 | 默认 `Hide()`，仅 `OnMouseWheel`/`OnEnter` 时 `Show()` 并 1.2 秒后 `UIFrameFadeOut` 淡出 |

### 关键 API

- `C_QuestLog.GetNumQuestWatches()` / `GetQuestIDForQuestWatchIndex(i)` / `GetTitleForQuestID(qid)` / `GetQuestObjectives(qid)`
- `GetQuestLogIndexByID` / `GetNumQuestLeaderBoards` / `GetQuestLogLeaderBoard`（降级）
- `Settings.RegisterCanvasLayoutCategory`（12.x）兼容 `InterfaceOptions_AddCategory`
- `WorldMapFrame:IsShown()` 地图自适应

### 事件

```
ADDON_LOADED (QuestSkin / Blizzard_WorldMap)
QUEST_WATCH_LIST_CHANGED, QUEST_LOG_UPDATE (节流 0.2s)
QUEST_ACCEPTED, QUEST_REMOVED, ZONE_CHANGED, ZONE_CHANGED_NEW_AREA
```

---

## 📁 结构

```
QuestSkin/
├── QuestSkin.toc          # Interface: 120100, SavedVariables: QuestSkinDB
├── core.lua               # 重绘核心：隐藏官方框、Watch 列表渲染、滚动、地图自适应
├── config.lua             # 设置面板 + 宽度/高度滑条 + 总开关 + /qs 命令
├── locales/
│   ├── init.lua           # L 表初始化 + __index fallback
│   ├── zhCN.lua           # 简体中文
│   └── enUS.lua           # 英文占位
├── LICENSE                # MIT
└── README.md
```

---

## ❓ FAQ

**Q：追踪了任务仍显示 `任务 0`？**  
A：Midnight 12.1 的 `isWatched` 已废弃，旧版会误判。请更新到最新 `core.lua`（已改用 Watch 列表），并 `/reload`。

**Q：设置里出现 3 个 QuestSkin？**  
A：旧版重复注册的 bug，已在 `config.lua` 加 `registered` 守卫修复，`/reload` 后只剩 1 个。

**Q：右侧显示不全/被裁？**  
A：`/qs reset` 重置到 `-32,-200`；或在设置里把宽度拉大到 `320+`；再不行把最大高度拉大，超出部分用滚轮查看。

**Q：打开地图重叠？**  
A：已修复为地图打开时自动隐藏，关地图自动恢复。若仍重叠，请 `/dump WorldMapFrame:IsShown()` 贴结果。

**Q：想改回官方？**  
A：`/qs off` 或设置里取消勾选。

---

## 🗓️ 更新日志

- **v1.0.0** — 首个正式版：地图动态 Ticker（`OnShow` 1.0s 轮询 / `OnHide` 5s 后取消，替代常驻 0.4s）、超追踪高亮（◆ 超追踪 / ◇ 普通追踪，标题与指示线联动）、精简 5 项右键菜单（分享/放弃/取消追踪…，移除 UIDropDownMenu/Share/BtW/Wowhead 路径）、成就追踪入 v1（`C_ContentTracking`/`GetTrackedAchievements`）、放弃按钮战斗中置灰（`InCombatLockdown`）
- **v0.1.3** — 地图兜底：`UpdateTracker` 强检 + `hooksecurefunc` 双钩 + 0.4s 轮询，地图打开必隐藏
- **v0.1.2** — Midnight 12.1 `isWatched=nil` 修复：改用 `GetNumQuestWatches` 列表，置顶防遮挡
- **v0.1.1** — 设置面板去重 + 宽度同步/滚动/锚点修复 + 滚轮支持
- **v0.1.0** — 初始骨架：Midnight 12.1 `120100`，极简细线重绘，纯原生 API

---

## 📄 许可

MIT © QuestSkin Contributors — 详见 [LICENSE](LICENSE)

---

## 🤝 贡献

欢迎提 Issue / PR：

- 报告请附：`/dump C_QuestLog.GetNumQuestWatches()` 输出 + 截图 + 复现步骤
- 建议请按设计树走：先提“想解决什么问题”，再定方案，避免直接堆功能

> GitHub：https://github.com/hao1196561270/QuestSkin
