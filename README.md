# QuestSkin

正式服 **Midnight 12.x** 极简任务追踪重绘插件 — **细线分隔 · 保留暴雪字体**。

> v1.0 严格纯美化，不做功能增强。重绘路线：隐藏官方 `ObjectiveTrackerFrame`，自建 `QuestSkinFrame`。

## 设计共识（已闭合）

| 项 | 决策 |
|---|---|
| 平台 | 正式服 12.x · `Interface: 120100` |
| 技术 | 纯原生 API（零 Ace3 依赖） |
| 视觉 | 极简无底板：1px 细线边框 + 块间细分隔线，透明底；重做颜色体系与布局间距；刻意保留暴雪默认字体 |
| 模块 | 全部追踪模块统一风格 |
| 数据源 | 严格跟随暴雪“已追踪”列表（`C_QuestLog.GetInfo().isWatched`） |
| 交互 | 仅展示 + 点击打开任务日志 |
| 位置 | 原地替换官方框，可拖动，坐标存 `SavedVariables` |
| 尺寸 | 固定宽度 260（200–400 可扩展），超出滚动 |
| 标题 | 保留“任务 N”标题栏 |
| 换行 | 长文本自动换行 |
| 配置 | 暴雪设置面板 + 总开关「一键恢复官方」 |
| 语言 | `locales/` 表结构，首发 `zhCN` |

## 安装

1. 将 `QuestSkin` 文件夹放入 `World of Warcraft/_retail_/Interface/AddOns/`
2. 重启游戏，角色界面勾选 `QuestSkin`
3. 进游戏后 `/qs` 打开设置，或 `ESC → 选项 → 插件 → QuestSkin`

## 使用

- **拖动**：按住追踪框任意位置左键拖动
- **打开任务**：点击任意任务块打开任务详情
- **开关**：`/qs on` / `/qs off` 或设置面板勾选
- **追踪**：在任务日志中 `Shift+点击` 任务以加入/移除追踪

## 结构

```
QuestSkin/
├── QuestSkin.toc
├── core.lua            # 重绘核心：隐藏官方框、渲染已追踪任务、滚动容器
├── config.lua          # Settings API 面板 + /qs 命令
└── locales/
    ├── init.lua
    ├── zhCN.lua
    └── enUS.lua
```

## 兼容

- 12.1.0 `120100` 实测框架为 `Blizzard_ObjectiveTracker` 的 `ObjectiveTrackerFrame`（Manager/Module/Container/Block 分层）[wow-ui-source](https://github.com/Gethe/wow-ui-source)
- 无官方皮肤 API，Edit Mode 仅暴露透明度/字号 [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/Objective_Tracker) — 故采用自建渲染 + `hooksecurefunc` 隐藏官方框

## 许可

MIT — 见 [LICENSE](LICENSE)
