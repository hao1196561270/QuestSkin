-- locales/init.lua — 初始化本地化表
QuestSkin_L = QuestSkin_L or {}
local L = QuestSkin_L
-- fallback: 未翻译的 key 返回自身
setmetatable(L, {
    __index = function(_, k) return k end
})
