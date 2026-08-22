-- config.lua — 暴雪设置面板 + 总开关 + 斜杠命令
local L = QuestSkin_L or setmetatable({}, { __index = function(_, k) return k end })

-- 创建设置面板
local panel = CreateFrame("Frame", "QuestSkinSettingsPanel", UIParent)
panel.name = "QuestSkin"

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("QuestSkin  " .. (L["Settings"] or "设置"))

local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
subtitle:SetText("Midnight 12.x  ·  极简细线重绘  ·  保留暴雪字体")
subtitle:SetTextColor(0.7, 0.7, 0.7)

-- 启用勾选
local cb = CreateFrame("CheckButton", "QuestSkinEnableCheck", panel, "InterfaceOptionsCheckButtonTemplate")
cb:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -20)
cb.Text:SetText(L["Enable QuestSkin"])
cb.tooltipText = L["Enable hint"]
cb.tooltipRequirement = L["Drag to move"]

local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
hint:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 6, -6)
hint:SetText(L["Enable hint"])
hint:SetTextColor(0.6, 0.6, 0.6)
hint:SetWidth(520)
hint:SetJustifyH("LEFT")

-- 暴露给 core.lua
QuestSkin_SettingsPanel = panel
QuestSkin_EnableCheck = cb

-- 同步勾选状态到 DB（core.lua 会在 ADDON_LOADED 后接管）
cb:SetScript("OnClick", function(self)
    QuestSkinDB = QuestSkinDB or {}
    QuestSkinDB.enabled = self:GetChecked()
    if QuestSkin and QuestSkin.ApplyEnabled then
        QuestSkin.ApplyEnabled(QuestSkinDB.enabled)
    end
end)

-- 注册到暴雪设置
local function RegisterSettings()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        category.ID = panel.name
        Settings.RegisterAddOnCategory(category)
        QuestSkin_SettingsCategory = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

-- 延迟注册，等 Blizzard_Settings 加载
local reg = CreateFrame("Frame")
reg:RegisterEvent("ADDON_LOADED")
reg:SetScript("OnEvent", function(_, _, name)
    if name == "QuestSkin" or name == "Blizzard_Settings" then
        RegisterSettings()
    end
end)
-- 若已加载直接注册
C_Timer.After(0, RegisterSettings)

-- 斜杠命令
SLASH_QUESTSKIN1 = "/questskin"
SLASH_QUESTSKIN2 = "/qs"
SlashCmdList["QUESTSKIN"] = function(msg)
    msg = (msg or ""):lower():trim()
    if msg == "on" then
        QuestSkinDB.enabled = true
        if QuestSkin.ApplyEnabled then QuestSkin.ApplyEnabled(true) end
        if QuestSkin_EnableCheck then QuestSkin_EnableCheck:SetChecked(true) end
        print("|cff88ff88QuestSkin|r: " .. L["Tracker hidden, QuestSkin active"])
    elseif msg == "off" then
        QuestSkinDB.enabled = false
        if QuestSkin.ApplyEnabled then QuestSkin.ApplyEnabled(false) end
        if QuestSkin_EnableCheck then QuestSkin_EnableCheck:SetChecked(false) end
        print("|cffff8888QuestSkin|r: " .. L["Tracker restored"])
    else
        if Settings and Settings.OpenToCategory and QuestSkin_SettingsCategory then
            Settings.OpenToCategory(QuestSkin_SettingsCategory:GetID())
        elseif InterfaceOptionsFrame_OpenToCategory then
            InterfaceOptionsFrame_OpenToCategory(panel)
            InterfaceOptionsFrame_OpenToCategory(panel)
        end
        print("|cff88ff88QuestSkin|r: /qs on | /qs off | /qs — 打开设置")
    end
end
