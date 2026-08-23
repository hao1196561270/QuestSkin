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
cb.tooltipRequirement = nil

local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
hint:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 6, -6)
hint:SetText(L["Enable hint"])
hint:SetTextColor(0.6, 0.6, 0.6)
hint:SetWidth(520)
hint:SetJustifyH("LEFT")

-- 宽度滑条
local widthLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
widthLabel:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -18)
widthLabel:SetText("宽度")

local widthSlider = CreateFrame("Slider", "QuestSkin_WidthSlider", panel, "OptionsSliderTemplate")
widthSlider:SetPoint("TOPLEFT", widthLabel, "BOTTOMLEFT", 0, -8)
widthSlider:SetSize(220, 16)
widthSlider:SetMinMaxValues(200, 420)
widthSlider:SetValueStep(10)
widthSlider:SetObeyStepOnDrag(true)
_G[widthSlider:GetName() .. "Low"]:SetText("200")
_G[widthSlider:GetName() .. "High"]:SetText("420")
_G[widthSlider:GetName() .. "Text"]:SetText("260")
widthSlider:SetScript("OnValueChanged", function(self, v)
    v = math.floor(v/10)*10
    _G[self:GetName() .. "Text"]:SetText(tostring(v))
    if QuestSkin and QuestSkin.SetWidth then QuestSkin.SetWidth(v) end
end)
QuestSkin_WidthSlider = widthSlider

-- 高度滑条（最大高度，超出则滚轮滚动）
local heightLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
heightLabel:SetPoint("TOPLEFT", widthSlider, "BOTTOMLEFT", 0, -22)
heightLabel:SetText("最大高度")

local heightSlider = CreateFrame("Slider", "QuestSkin_HeightSlider", panel, "OptionsSliderTemplate")
heightSlider:SetPoint("TOPLEFT", heightLabel, "BOTTOMLEFT", 0, -8)
heightSlider:SetSize(220, 16)
heightSlider:SetMinMaxValues(180, 700)
heightSlider:SetValueStep(10)
heightSlider:SetObeyStepOnDrag(true)
_G[heightSlider:GetName() .. "Low"]:SetText("180")
_G[heightSlider:GetName() .. "High"]:SetText("700")
_G[heightSlider:GetName() .. "Text"]:SetText("420")
heightSlider:SetScript("OnValueChanged", function(self, v)
    v = math.floor(v/10)*10
    _G[self:GetName() .. "Text"]:SetText(tostring(v))
    if QuestSkin and QuestSkin.SetMaxHeight then QuestSkin.SetMaxHeight(v) end
end)
QuestSkin_HeightSlider = heightSlider

local sliderHint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
sliderHint:SetPoint("TOPLEFT", heightSlider, "BOTTOMLEFT", 0, -10)
sliderHint:SetText("超出最大高度时可用鼠标滚轮滚动，滚动条仅滚动时显现")
sliderHint:SetTextColor(0.55, 0.55, 0.55)
sliderHint:SetWidth(520)
sliderHint:SetJustifyH("LEFT")

-- 重置按钮
local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
resetBtn:SetPoint("TOPLEFT", sliderHint, "BOTTOMLEFT", 0, -14)
resetBtn:SetSize(120, 22)
resetBtn:SetText("重置位置/尺寸")
resetBtn:SetScript("OnClick", function()
    if QuestSkin and QuestSkin.ResetPosition then QuestSkin.ResetPosition() end
end)

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

-- 注册到暴雪设置（防重复：Settings API 每次调用都会新建一个条目）
local registered = false
local function RegisterSettings()
    if registered then return end
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category, layout = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        -- 注意：不要覆写 category.ID，GetID() 返回的是暴雪分配的数值ID
        Settings.RegisterAddOnCategory(category)
        QuestSkin_SettingsCategory = category
        QuestSkin_SettingsLayout = layout
        if QuestSkin then QuestSkin.SettingsCategory = category end
        registered = true
        return category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        registered = true
    end
end
-- 暴露给 core.lua 的打开入口（供标题栏按钮直接调用，兼容两种加载时序）
_G.QuestSkin_RegisterSettings = RegisterSettings
QuestSkin_RegisterSettings = RegisterSettings
QuestSkin = QuestSkin or {}
QuestSkin._RegisterSettings = RegisterSettings

-- 仅在 QuestSkin 加载时注册一次；不再监听 Blizzard_Settings 做二次注册
local reg = CreateFrame("Frame")
reg:RegisterEvent("ADDON_LOADED")
reg:SetScript("OnEvent", function(_, _, name)
    if name == "QuestSkin" then
        RegisterSettings()
        -- 同步滑条到存档值
        if QuestSkinDB then
            if QuestSkin_WidthSlider and QuestSkinDB.width then
                QuestSkin_WidthSlider:SetValue(QuestSkinDB.width)
                _G[QuestSkin_WidthSlider:GetName() .. "Text"]:SetText(tostring(QuestSkinDB.width))
            end
            if QuestSkin_HeightSlider and QuestSkinDB.maxHeight then
                QuestSkin_HeightSlider:SetValue(QuestSkinDB.maxHeight)
                _G[QuestSkin_HeightSlider:GetName() .. "Text"]:SetText(tostring(QuestSkinDB.maxHeight))
            end
        end
        reg:UnregisterEvent("ADDON_LOADED")
    end
end)
-- 兜底：若 ADDON_LOADED 已错过（重载后），下一帧再试一次（带 guard 不会重复）
C_Timer.After(0, function()
    RegisterSettings()
    if QuestSkinDB then
        if QuestSkin_WidthSlider and QuestSkinDB.width then QuestSkin_WidthSlider:SetValue(QuestSkinDB.width) end
        if QuestSkin_HeightSlider and QuestSkinDB.maxHeight then QuestSkin_HeightSlider:SetValue(QuestSkinDB.maxHeight) end
    end
end)

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
    elseif msg == "reset" then
        if QuestSkin and QuestSkin.ResetPosition then QuestSkin.ResetPosition() end
    elseif msg == "debug" then
        local nQ = 0
        if C_QuestLog and C_QuestLog.GetNumQuestWatches then
            local ok, v = pcall(C_QuestLog.GetNumQuestWatches)
            if ok then nQ = v or 0 end
        end
        local nA = 0
        local aList = ""
        if C_ContentTracking and C_ContentTracking.GetTrackedIDs then
            local t = 2
            if Enum and Enum.ContentTrackingType and Enum.ContentTrackingType.Achievement then t = Enum.ContentTrackingType.Achievement end
            local ok, ids = pcall(C_ContentTracking.GetTrackedIDs, t)
            if ok and ids then nA = #ids; aList = table.concat(ids, ",") end
        elseif GetTrackedAchievements then
            local ok, a1,a2,a3 = pcall(GetTrackedAchievements)
            if ok and a1 then nA = 1; if a2 then nA=2 end; if a3 then nA=3 end; aList = tostring(a1) end
        end
        local wm = WorldMapFrame and WorldMapFrame.IsShown and tostring(WorldMapFrame:IsShown()) or "nil"
        local wmVis = WorldMapFrame and WorldMapFrame.IsVisible and tostring(WorldMapFrame:IsVisible()) or "nil"
        local qm = QuestMapFrame and QuestMapFrame.IsShown and tostring(QuestMapFrame:IsShown()) or "nil"
        local mf = _G["MapFrame"] and _G["MapFrame"].IsShown and tostring(_G["MapFrame"]:IsShown()) or "nil"
        local enabled = QuestSkinDB and tostring(QuestSkinDB.enabled) or "nil"
        local shown = _G.QuestSkinFrame and tostring(_G.QuestSkinFrame:IsShown()) or "nil"
        print("|cff88ff88QuestSkin debug|r: enabled="..enabled.." frameShown="..shown.." WorldMap:IsShown="..wm.." IsVisible="..wmVis.." QuestMap:IsShown="..qm.." MapFrame:IsShown="..mf.." watches="..tostring(nQ).." achievements="..tostring(nA).." ["..aList.."]")
        if QuestSkin and QuestSkin.UpdateTracker then QuestSkin.UpdateTracker() end
        print("|cff88ff88QuestSkin debug|r: after UpdateTracker frameShown="..tostring(_G.QuestSkinFrame and _G.QuestSkinFrame:IsShown()))
    elseif msg == "refresh" then
        if QuestSkin and QuestSkin.UpdateTracker then QuestSkin.UpdateTracker(); print("|cff88ff88QuestSkin|r: 已刷新") end
    else
        -- 统一走 QS.OpenSettings，保证标题按钮/斜杠一致
        local opened = false
        if QuestSkin and QuestSkin.OpenSettings then
            local ok = pcall(QuestSkin.OpenSettings)
            if ok then opened = true end
        end
        if not opened then
            if Settings and Settings.OpenToCategory and QuestSkin_SettingsCategory then
                local cat = QuestSkin_SettingsCategory
                local ok = false
                if cat.GetID then ok = pcall(Settings.OpenToCategory, cat:GetID()) end
                if not ok and cat.ID then ok = pcall(Settings.OpenToCategory, cat.ID) end
                if not ok then pcall(Settings.OpenToCategory, cat) end
            elseif InterfaceOptionsFrame_OpenToCategory then
                pcall(InterfaceOptionsFrame_OpenToCategory, panel)
                pcall(InterfaceOptionsFrame_OpenToCategory, panel)
            end
        end
        print("|cff88ff88QuestSkin|r: /qs on | /qs off | /qs reset — 重置位置 | /qs debug — 诊断 | /qs refresh — 强制刷新 | /qs — 打开设置")
    end
end
