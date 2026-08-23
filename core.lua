-- core.lua — QuestSkin v1.0 极简重绘核心
-- 约定：v1.0 严格纯美化，不做进度百分比等功能增强
local ADDON = "QuestSkin"
local L = QuestSkin_L or setmetatable({}, { __index = function(_, k) return k end })

QuestSkin = QuestSkin or {}
local QS = QuestSkin

-- 默认存档（-32 更保险，避免不同分辨率下右侧被裁切）
local defaults = {
    version = 1,
    enabled = true,
    point = "TOPRIGHT",
    relativePoint = "TOPRIGHT",
    x = -32,
    y = -200,
    width = 260,
    maxHeight = 420,
}
local function MigrateDB(db)
    db = db or {}
    if db.version == nil then db.version = 0 end
    if db.version < defaults.version then
        if type(db.width) ~= "number" then db.width = defaults.width
        else db.width = math.max(200, math.min(420, db.width)) end
        if type(db.maxHeight) ~= "number" then db.maxHeight = defaults.maxHeight
        else db.maxHeight = math.max(180, math.min(700, db.maxHeight)) end
        if type(db.x) ~= "number" then db.x = defaults.x end
        if type(db.y) ~= "number" then db.y = defaults.y end
        if type(db.point) ~= "string" then db.point = defaults.point end
        if type(db.relativePoint) ~= "string" then db.relativePoint = defaults.relativePoint end
        -- 保证顶部锚点，从上到下展开
        if db.point and not db.point:find("TOP") then db.point, db.relativePoint = defaults.point, defaults.relativePoint; db.x, db.y = defaults.x, defaults.y end
        if db.enabled == nil then db.enabled = defaults.enabled end
        db.version = defaults.version
    end
    for k, v in pairs(defaults) do if db[k] == nil then db[k] = v end end
    db.width = math.max(200, math.min(420, db.width))
    db.maxHeight = math.max(180, math.min(700, db.maxHeight))
    if db.point and not db.point:find("TOP") then db.point, db.relativePoint = defaults.point, defaults.relativePoint; db.x, db.y = defaults.x, defaults.y end
    return db
end
QS.MigrateDB = MigrateDB
-- 前向声明：动态 Ticker + 避免前向引用 luacheck 警告
local StartMapTicker, StopMapTicker
local GetWatchedQuests

-- 打开设置面板（供标题栏“设置”按钮调用）— 兼容 Midnight 12.x Settings + 旧 InterfaceOptions
function QS.OpenSettings()
    -- 若尚未注册，尝试立即注册（处理早于 ADDON_LOADED 的点击，或 core/config 加载顺序问题）
    if not QuestSkin_SettingsCategory then
        if QS._RegisterSettings then pcall(QS._RegisterSettings) end
        if _G.QuestSkin_RegisterSettings then pcall(_G.QuestSkin_RegisterSettings) end
        if _G.QuestSkin_SettingsCategory then QuestSkin_SettingsCategory = _G.QuestSkin_SettingsCategory end
        if _G.QuestSkin and _G.QuestSkin.SettingsCategory then QuestSkin_SettingsCategory = _G.QuestSkin.SettingsCategory end
    end
    -- 1) 新 Settings API（12.x 推荐）
    if Settings and Settings.OpenToCategory and QuestSkin_SettingsCategory then
        local cat = QuestSkin_SettingsCategory
        -- 优先用 GetID() 数值ID，其次尝试直接传 category 对象，兼容不同版本
        local tried = false
        if cat.GetID then
            local ok, id = pcall(cat.GetID, cat)
            if ok and id then
                local ok2 = pcall(Settings.OpenToCategory, id)
                if ok2 then return end
                tried = true
            end
        end
        if cat.ID and not tried then
            local ok = pcall(Settings.OpenToCategory, cat.ID)
            if ok then return end
        end
        -- 最后尝试直接传 category
        local ok = pcall(Settings.OpenToCategory, cat)
        if ok then return end
    end
    -- 2) 尝试通过全局面板直接打开（兜底）
    if QuestSkin_SettingsPanel then
        if Settings and Settings.OpenToCategory then
            -- 暴雪新面板有时需要先显示 SettingsPanel
            if _G.SettingsPanel then
                pcall(function() _G.SettingsPanel:Show() end)
            end
            if QuestSkin_SettingsCategory then
                pcall(Settings.OpenToCategory, QuestSkin_SettingsCategory:GetID())
                return
            end
        end
        if InterfaceOptionsFrame_OpenToCategory then
            pcall(InterfaceOptionsFrame_OpenToCategory, QuestSkin_SettingsPanel)
            pcall(InterfaceOptionsFrame_OpenToCategory, QuestSkin_SettingsPanel)
            return
        end
        -- 兜底：直接显示面板（非标准但可见）
        pcall(function() QuestSkin_SettingsPanel:Show() end)
        return
    end
    -- 3) 终极兜底：走斜杠命令逻辑
    if SlashCmdList and SlashCmdList["QUESTSKIN"] then
        pcall(SlashCmdList["QUESTSKIN"], "")
    end
end

-- 主容器（可拖动）
local frame = CreateFrame("Frame", "QuestSkinFrame", UIParent, "BackdropTemplate")
frame:SetSize(defaults.width, 100)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetFrameStrata("MEDIUM")
frame:SetFrameLevel(80)
frame:Raise()
-- 极简：只有 1px 细线边框，无填充
frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
frame:SetBackdropColor(0, 0, 0, 0.0)          -- 透明底
frame:SetBackdropBorderColor(1, 1, 1, 0.12)   -- 细线

-- 拖动保存（归一化为顶部锚点，保证从上到下展开不居中）
local function SaveFramePosition()
    if not QuestSkinDB then return end
    local left, top = frame:GetLeft(), frame:GetTop()
    if not left or not top then
        local point, _, relativePoint, x, y = frame:GetPoint()
        QuestSkinDB.point, QuestSkinDB.relativePoint, QuestSkinDB.x, QuestSkinDB.y = point, relativePoint, x, y
        return
    end
    local uiW, uiH = UIParent:GetWidth(), UIParent:GetHeight()
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    -- 转为 UIParent 坐标
    left, top = left * scale, top * scale
    local isLeft = (left + frame:GetWidth()*scale/2) < uiW/2
    if isLeft then
        QuestSkinDB.point, QuestSkinDB.relativePoint = "TOPLEFT", "TOPLEFT"
        QuestSkinDB.x, QuestSkinDB.y = left, top - uiH
    else
        QuestSkinDB.point, QuestSkinDB.relativePoint = "TOPRIGHT", "TOPRIGHT"
        QuestSkinDB.x, QuestSkinDB.y = left + frame:GetWidth()*scale - uiW, top - uiH
    end
end

frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveFramePosition()
end)

-- 标题栏
local header = CreateFrame("Frame", nil, frame)
header:SetPoint("TOPLEFT", 8, -8)
header:SetPoint("TOPRIGHT", -8, -8)
header:SetHeight(18)

local headerText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
headerText:SetPoint("LEFT", 0, 0)
headerText:SetTextColor(0.9, 0.9, 0.9)
headerText:SetText(L["Quests"] .. "  0")

-- 右上角“设置”按钮（替代原“按住左键拖动”提示）— 极简细线风
local headerSettingsBtn = CreateFrame("Button", nil, header, "BackdropTemplate")
headerSettingsBtn:SetPoint("RIGHT", 0, 0)
headerSettingsBtn:SetSize(36, 16)
headerSettingsBtn:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
headerSettingsBtn:SetBackdropColor(1, 1, 1, 0.06)
headerSettingsBtn:SetBackdropBorderColor(1, 1, 1, 0.12)
local headerBtnText = headerSettingsBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
headerBtnText:SetPoint("CENTER", 0, 0)
headerBtnText:SetTextColor(0.85, 0.85, 0.85)
headerBtnText:SetText(L["Settings"])
headerSettingsBtn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(1, 1, 1, 0.12)
    self:SetBackdropBorderColor(1, 0.82, 0, 0.35)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["Settings"])
    GameTooltip:Show()
end)
headerSettingsBtn:SetScript("OnLeave", function(self)
    self:SetBackdropColor(1, 1, 1, 0.06)
    self:SetBackdropBorderColor(1, 1, 1, 0.12)
    GameTooltip:Hide()
end)
headerSettingsBtn:SetScript("OnClick", function()
    if QS and QS.OpenSettings then
        QS.OpenSettings()
    else
        -- 兜底：直接走斜杠逻辑
        if SlashCmdList and SlashCmdList["QUESTSKIN"] then
            pcall(SlashCmdList["QUESTSKIN"], "")
        end
    end
end)
-- 防止按钮点击触发外层拖动
headerSettingsBtn:RegisterForClicks("LeftButtonUp")
headerSettingsBtn:SetFrameLevel(header:GetFrameLevel() + 2)

-- 标题栏拖动（按钮区域除外，保留框体可拖动体验）
header:EnableMouse(true)
header:RegisterForDrag("LeftButton")
header:SetScript("OnDragStart", function() frame:StartMoving() end)
header:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    SaveFramePosition()
end)

-- 分隔线（标题下）
local sep = header:CreateTexture(nil, "ARTWORK")
sep:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
sep:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -6)
sep:SetHeight(1)
sep:SetColorTexture(1, 1, 1, 0.08)

-- 内容容器（ScrollFrame，固定宽+超出滚动）
local scroll = CreateFrame("ScrollFrame", "QuestSkinScrollFrame", frame, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -6)
scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -26, 8) -- 26 给滚动条留空

local content = CreateFrame("Frame", nil, scroll)
content:SetSize(defaults.width - 34, 1)
scroll:SetScrollChild(content)
-- 极简滚动条：默认隐藏，仅滚轮时显现
if scroll.ScrollBar then
    scroll.ScrollBar:Hide()
    scroll.ScrollBar:SetAlpha(0.85)
    if scroll.ScrollBar.Background then scroll.ScrollBar.Background:Hide() end
    if scroll.ScrollBar.Track then scroll.ScrollBar.Track:Hide() end
end
-- 滚动条自动隐藏定时器
local scrollFadeTimer = nil
local function ShowScrollBarTemporarily()
    if not scroll.ScrollBar then return end
    if scroll:GetVerticalScrollRange() == 0 then return end
    scroll.ScrollBar:Show()
    scroll.ScrollBar:SetAlpha(0.85)
    if scrollFadeTimer then scrollFadeTimer:Cancel() end
    scrollFadeTimer = C_Timer.NewTimer(1.2, function()
        -- 淡出
        if scroll.ScrollBar then
            UIFrameFadeOut(scroll.ScrollBar, 0.4, 0.85, 0)
            C_Timer.After(0.45, function()
                if scroll.ScrollBar then scroll.ScrollBar:Hide(); scroll.ScrollBar:SetAlpha(0.85) end
            end)
        end
    end)
end
-- 鼠标滚轮滚动（仅此时显示滚动条）
scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", function(self, delta)
    local max = self:GetVerticalScrollRange()
    if max == 0 then return end
    local cur = self:GetVerticalScroll()
    local step = 40
    local next = math.max(0, math.min(max, cur - delta * step))
    self:SetVerticalScroll(next)
    ShowScrollBarTemporarily()
end)
-- 鼠标移入也短暂提示可滚动
scroll:SetScript("OnEnter", function() ShowScrollBarTemporarily() end)

local blocks = {} -- 当前渲染的块

local function ClearBlocks()
    for _, b in ipairs(blocks) do b:Hide(); b:SetParent(nil) end
    wipe(blocks)
end

-- 颜色（保留暴雪字体，只改颜色与间距）
-- 需求：追踪中黄、已完成绿（标题与左侧指示线联动）
local COLOR_TITLE_TRACKING = { r=1, g=0.82, b=0 }   -- 追踪中：黄/金
local COLOR_TITLE_COMPLETE = { r=0.35, g=1, b=0.35 } -- 已完成：绿
local COLOR_ACCENT_TRACKING = { r=1, g=0.82, b=0 }   -- 左侧 2px 黄
local COLOR_ACCENT_COMPLETE = { r=0.35, g=1, b=0.35 } -- 左侧 2px 绿
local COLOR_OBJ_INCOMPLETE = { r=0.95, g=0.95, b=0.95 }
local COLOR_OBJ_COMPLETE   = { r=0.35, g=1, b=0.35 }
local COLOR_EMPTY = { r=0.5, g=0.5, b=0.5 }

local function GetSuperTrackedID()
    if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        local ok, id = pcall(C_SuperTrack.GetSuperTrackedQuestID)
        if ok then return id end
    end
    if C_QuestLog and C_QuestLog.GetSuperTrackedQuestID then
        local ok, id = pcall(C_QuestLog.GetSuperTrackedQuestID)
        if ok then return id end
    end
    return nil
end

local function SetSuperTrackedID(qid)
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
        pcall(C_SuperTrack.SetSuperTrackedQuestID, qid)
        return true
    end
    if C_QuestLog and C_QuestLog.SetSuperTrackedQuestID then
        pcall(C_QuestLog.SetSuperTrackedQuestID, qid)
        return true
    end
    return false
end

local function ClearSuperTracked()
    if C_SuperTrack and C_SuperTrack.ClearSuperTrackedQuestID then
        pcall(C_SuperTrack.ClearSuperTrackedQuestID)
        return true
    end
    -- 降级：设为 0 等同清除
    return SetSuperTrackedID(0)
end

local function ToggleSuperTrack(questID)
    local cur = GetSuperTrackedID()
    if cur and cur == questID then
        ClearSuperTracked()
    else
        SetSuperTrackedID(questID)
    end
end

local function OpenQuestLog(questID)
    if QuestMapFrame_OpenToQuestDetails then
        if not QuestMapFrame:IsShown() then ShowUIPanel(QuestMapFrame) end
        QuestMapFrame_OpenToQuestDetails(questID)
    elseif ToggleQuestLog then
        ToggleQuestLog()
    elseif QuestLogEx then -- 兼容
        QuestLogEx:ShowQuest(questID)
    end
end

local function OpenQuestMap(questID)
    -- 优先在世界地图中定位该任务
    SetSuperTrackedID(questID)
    if WorldMapFrame and not WorldMapFrame:IsShown() then
        ShowUIPanel(WorldMapFrame)
    end
    if QuestMapFrame_OpenToQuestDetails then
        pcall(QuestMapFrame_OpenToQuestDetails, questID)
    end
end

local function IsQuestWatchedInternal(questID)
    if not questID then return false end
    if C_QuestLog and C_QuestLog.IsQuestWatched then
        local ok, v = pcall(C_QuestLog.IsQuestWatched, questID)
        if ok and v ~= nil then return v and true or false end
    end
    -- 降级：遍历 Watch 列表
    local watched = GetWatchedQuests()
    for _, q in ipairs(watched) do
        if q.questID == questID then return true end
    end
    return false
end

local function AddQuestWatchInternal(questID)
    if C_QuestLog and C_QuestLog.AddQuestWatch then
        pcall(C_QuestLog.AddQuestWatch, questID)
        return
    end
    local idx = GetQuestLogIndexByID and GetQuestLogIndexByID(questID)
    if idx and AddQuestWatch then pcall(AddQuestWatch, idx) end
end

local function RemoveQuestWatchInternal(questID)
    if C_QuestLog and C_QuestLog.RemoveQuestWatch then
        pcall(C_QuestLog.RemoveQuestWatch, questID)
        return
    end
    local idx = GetQuestLogIndexByID and GetQuestLogIndexByID(questID)
    if idx and RemoveQuestWatch then pcall(RemoveQuestWatch, idx) end
end

local function ToggleQuestWatchInternal(questID)
    if IsQuestWatchedInternal(questID) then
        RemoveQuestWatchInternal(questID)
    else
        AddQuestWatchInternal(questID)
    end
end

local function AbandonQuestInternal(questID)
    -- Q12A: 战斗中禁止放弃，避免 taint
    if InCombatLockdown and InCombatLockdown() then
        print("|cffff8888QuestSkin|r: 战斗中无法放弃任务")
        return
    end
    local idx = GetQuestLogIndexByID and GetQuestLogIndexByID(questID)
    if not idx then return end
    pcall(SelectQuestLogEntry, idx)
    pcall(SetAbandonQuest)
    local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID) or GetQuestLogTitle and GetQuestLogTitle(idx) or ""
    if StaticPopup_Show then
        local shown = pcall(StaticPopup_Show, "ABANDON_QUEST", title)
        if not shown then
            pcall(StaticPopup_Show, "ABANDON_QUEST")
        end
    end
end

-- Wowhead 复制（复刻 EnhanceQoL 健壮实现：AutoFocus + Highlight + CursorPosition）
local function QS_ShowCopyURL(url)
    if type(url) ~= "string" or url == "" then return end
    if not StaticPopupDialogs["QUESTSKIN_COPY_URL"] then
        StaticPopupDialogs["QUESTSKIN_COPY_URL"] = {
            text = "Wowhead 链接 (Ctrl+C 复制)",
            button1 = OKAY or "确定",
            hasEditBox = true,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
            OnShow = function(self, data)
                local eb = self.editBox or self.GetEditBox and self:GetEditBox()
                if not eb then return end
                eb:SetAutoFocus(true)
                eb:SetText(data or "")
                eb:HighlightText()
                eb:SetCursorPosition(0)
            end,
            OnAccept = function(self) end,
            EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
        }
    end
    StaticPopup_Show("QUESTSKIN_COPY_URL", nil, nil, url)
end

local function CopyWowheadLink(questID)
    local url = ("https://www.wowhead.com/quest=%d"):format(questID)
    QS_ShowCopyURL(url)
end

-- BtWQuests 开启任务链（兼容 v2.63.1 真入口 SelectFromLink/GetQuestItem，无 ShowChainForQuest 时回退）
local function OpenBtWChain(questID)
    if not questID then return end
    -- 1) 历史符号
    if BtWQuests and BtWQuests.ShowChainForQuest then
        local ok = pcall(BtWQuests.ShowChainForQuest, questID)
        if ok then return end
    end
    -- 2) 真入口：Database:GetQuestItem → Frame:SelectItem
    if BtWQuestsDatabase and BtWQuestsFrame and BtWQuestsFrame.SelectItem then
        local ok, item = pcall(function()
            local chars = BtWQuestsCharacters and BtWQuestsCharacters:GetPlayer()
            return BtWQuestsDatabase:GetQuestItem(questID, chars)
        end)
        if ok and item and item.item then
            pcall(function() BtWQuestsFrame:SelectCharacter(UnitName("player"), GetRealmName()) end)
            local ok2 = pcall(BtWQuestsFrame.SelectItem, BtWQuestsFrame, item.item)
            if ok2 then return end
        end
    end
    -- 3) 链接回退：garrmission 超链
    if BtWQuestsDatabase and BtWQuestsFrame and BtWQuestsFrame.SelectFromLink then
        local link = string.format("|Hgarrmission:btwquests:quest:%d|h", questID)
        local ok = pcall(BtWQuestsFrame.SelectFromLink, BtWQuestsFrame, link, true)
        if ok then return end
    end
    -- 4) 未安装或失败提示
    print("|cff888888QuestSkin|r: 未安装 BtWQuests 或无法打开任务链 QuestID "..tostring(questID))
end

-- ========== 右键原生风格菜单（MenuUtil / UIDropDownMenu / 自绘兜底） ==========
local QuestSkinContextMenu = nil
local function HideQuestSkinContextMenu()
    if QuestSkinContextMenu then QuestSkinContextMenu:Hide() end
    if _G.QuestSkinContextMenuOverlay then _G.QuestSkinContextMenuOverlay:Hide() end
end

local function EnsureQuestSkinContextMenu()
    if QuestSkinContextMenu then return QuestSkinContextMenu end
    local m = CreateFrame("Frame", "QuestSkinContextMenu", UIParent, "BackdropTemplate")
    m:SetFrameStrata("TOOLTIP")
    m:SetFrameLevel(120)
    m:SetClampedToScreen(true)
    m:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    m:SetBackdropColor(0, 0, 0, 0.92)
    m:SetBackdropBorderColor(1, 1, 1, 0.12)
    m:SetSize(220, 10)
    m:Hide()
    m:SetScript("OnHide", function() if _G.QuestSkinContextMenuOverlay then _G.QuestSkinContextMenuOverlay:Hide() end end)
    tinsert(UISpecialFrames, "QuestSkinContextMenu")
    m.buttons = {}
    m.separators = {}

    -- 全屏透明遮罩：点击外部关闭
    local overlay = CreateFrame("Button", "QuestSkinContextMenuOverlay", UIParent)
    overlay:SetAllPoints(UIParent)
    overlay:SetFrameStrata("TOOLTIP")
    overlay:SetFrameLevel(119)
    overlay:EnableMouse(true)
    overlay:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    overlay:Hide()
    overlay:SetScript("OnClick", HideQuestSkinContextMenu)
    _G.QuestSkinContextMenuOverlay = overlay

    QuestSkinContextMenu = m
    return m
end

local function AddContextMenuButton(menu, y, text, func, opts)
    opts = opts or {}
    local idx = #menu.buttons + 1
    local b = menu.buttons[idx]
    if not b then
        b = CreateFrame("Button", nil, menu, "BackdropTemplate")
        b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = nil })
        b:SetBackdropColor(0, 0, 0, 0)
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", 10, 0)
        fs:SetPoint("RIGHT", -10, 0)
        fs:SetJustifyH("LEFT")
        b.text = fs
        b:SetScript("OnEnter", function(self)
            if self.isTitle or self.isDisabled then return end
            self:SetBackdropColor(1, 0.82, 0, 0.12)
        end)
        b:SetScript("OnLeave", function(self) self:SetBackdropColor(0, 0, 0, 0) end)
        menu.buttons[idx] = b
    end
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", 4, y)
    b:SetPoint("TOPRIGHT", -4, y)
    b:SetHeight(opts.isSeparator and 8 or 20)
    b.isTitle = opts.isTitle
    b.isDisabled = opts.isDisabled
    b:EnableMouse(not opts.isTitle and not opts.isDisabled)

    if opts.isSeparator then
        b:SetBackdropColor(0, 0, 0, 0)
        if not b.sep then
            local t = b:CreateTexture(nil, "ARTWORK")
            t:SetPoint("LEFT", 8, 0)
            t:SetPoint("RIGHT", -8, 0)
            t:SetHeight(1)
            t:SetColorTexture(1, 1, 1, 0.10)
            b.sep = t
        end
        b.sep:Show()
        b.text:SetText("")
        b:SetScript("OnClick", nil)
        return 8
    else
        if b.sep then b.sep:Hide() end
        b.text:SetText(text)
        if opts.isTitle then
            b.text:SetTextColor(1, 0.82, 0, 1)
            b.text:SetFontObject(GameFontNormalSmall)
            b:SetBackdropColor(0, 0, 0, 0)
        elseif opts.isDisabled then
            b.text:SetTextColor(0.5, 0.5, 0.5, 1)
        else
            b.text:SetTextColor(0.95, 0.95, 0.95, 1)
        end
        b:SetScript("OnClick", function()
            HideQuestSkinContextMenu()
            if func and not opts.isTitle and not opts.isDisabled then pcall(func) end
        end)
        b:RegisterForClicks("LeftButtonUp")
        return 20
    end
end

local function AddContextMenuSeparator(menu, y)
    return AddContextMenuButton(menu, y, "", nil, { isSeparator = true })
end

local function ShowCustomQuestMenu(questID, title, anchor)
    -- v1.0 精简版（Q7B/Q16A）：仅 5 项，删共享/BtW/Wowhead，删 add 死代码
    local menu = EnsureQuestSkinContextMenu()
    for _, b in ipairs(menu.buttons) do b:Hide() end
    if menu.separators then for _, s in ipairs(menu.separators) do s:Hide() end end
    wipe(menu.buttons)
    menu.buttons = {}
    local y = -6
    local h = 0
    local function add2(text, func, opts)
        local b = CreateFrame("Button", nil, menu, "BackdropTemplate")
        b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = nil })
        b:SetBackdropColor(0, 0, 0, 0)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 4, y)
        b:SetPoint("TOPRIGHT", -4, y)
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", 10, 0)
        fs:SetPoint("RIGHT", -10, 0)
        fs:SetJustifyH("LEFT")
        b.text = fs
        local isSep = opts and opts.isSeparator
        local isTitle = opts and opts.isTitle
        if isSep then
            b:SetHeight(8)
            local t = b:CreateTexture(nil, "ARTWORK")
            t:SetPoint("LEFT", 8, 0)
            t:SetPoint("RIGHT", -8, 0)
            t:SetHeight(1)
            t:SetColorTexture(1, 1, 1, 0.10)
            b:SetHeight(8)
            y = y - 10
            h = h + 10
        else
            b:SetHeight(20)
            fs:SetText(text)
            if isTitle then
                fs:SetTextColor(1, 0.82, 0, 1)
                fs:SetFontObject(GameFontNormalSmall)
            else
                fs:SetTextColor(0.95, 0.95, 0.95, 1)
            end
            -- 战斗中放弃置灰（Q12A）
            local isDisabled = opts and opts.isDisabled
            if isDisabled then
                fs:SetTextColor(0.5, 0.5, 0.5, 1)
                b:EnableMouse(false)
            else
                b:SetScript("OnEnter", function(self) if not isTitle then self:SetBackdropColor(1, 0.82, 0, 0.12) end end)
                b:SetScript("OnLeave", function(self) self:SetBackdropColor(0, 0, 0, 0) end)
                b:SetBackdropColor(0, 0, 0, 0)
                b:RegisterForClicks("LeftButtonUp")
                b:SetScript("OnClick", function()
                    HideQuestSkinContextMenu()
                    if func then pcall(func) end
                end)
            end
            y = y - 22
            h = h + 22
        end
        b:Show()
        table.insert(menu.buttons, b)
        return b
    end

    add2(title or ("Quest "..tostring(questID)), nil, { isTitle = true })
    add2("", nil, { isSeparator = true })
    add2("焦点", function() ToggleSuperTrack(questID) end)
    add2("打开任务细节", function() OpenQuestLog(questID) end)
    add2("打开任务地图", function() OpenQuestMap(questID) end)
    local watched = IsQuestWatchedInternal(questID)
    add2(watched and "取消追踪" or "追踪", function() ToggleQuestWatchInternal(questID); C_Timer.After(0.1, function() if QS and QS.UpdateTracker then QS.UpdateTracker() end end) end)
    local inCombat = InCombatLockdown and InCombatLockdown()
    add2("放弃", function() AbandonQuestInternal(questID) end, { isDisabled = inCombat })

    -- BtWQuests + Wowhead（按需常驻，未装则点击提示）
    add2("", nil, { isSeparator = true })
    add2("BtWQuests", nil, { isTitle = true })
    add2("开启任务链", function() OpenBtWChain(questID) end)
    add2("", nil, { isSeparator = true })
    add2("复制 Wowhead 链接", function() CopyWowheadLink(questID) end)

    menu:SetHeight(h + 12)
    menu:SetWidth(220)
    menu:ClearAllPoints()
    -- 定位：优先锚点右侧，超屏则翻到左侧；无锚点则跟随鼠标
    if anchor and anchor.GetCenter then
        local scale = UIParent:GetEffectiveScale()
        local ancScale = anchor:GetEffectiveScale()
        local x, y2 = GetCursorPosition()
        x = x / scale; y2 = y2 / scale
        menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x + 10, y2 - 10)
        -- 若超出右边界，改锚到鼠标左侧
        C_Timer.After(0, function()
            if menu:GetRight() and menu:GetRight() > UIParent:GetRight() - 10 then
                menu:ClearAllPoints()
                menu:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", x - 10, y2 - 10)
            end
            if menu:GetBottom() and menu:GetBottom() < 10 then
                menu:ClearAllPoints()
                menu:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x + 10, y2 + 10)
            end
        end)
    else
        menu:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    menu:Show()
    if _G.QuestSkinContextMenuOverlay then _G.QuestSkinContextMenuOverlay:Show() end
end

local function ShowQuestContextMenu(questID, title, anchor)
    if not questID then return end
    title = title or (C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID) or ("Quest "..tostring(questID)))

    -- 1) 优先 MenuUtil（12.x 推荐，Q9B：仅保留 MenuUtil + 自绘，删 UIDropDownMenu）
    if MenuUtil and MenuUtil.CreateContextMenu then
        local ok = pcall(function()
            MenuUtil.CreateContextMenu(anchor or UIParent, function(owner, root)
                root:CreateTitle(title)
                root:CreateDivider()
                root:CreateButton("焦点", function() ToggleSuperTrack(questID) end)
                root:CreateButton("打开任务细节", function() OpenQuestLog(questID) end)
                root:CreateButton("打开任务地图", function() OpenQuestMap(questID) end)
                local watched = IsQuestWatchedInternal(questID)
                root:CreateButton(watched and "取消追踪" or "追踪", function() ToggleQuestWatchInternal(questID); C_Timer.After(0.1, function() if QS and QS.UpdateTracker then QS.UpdateTracker() end end) end)
                -- Q12A: 战斗中放弃禁用
                if InCombatLockdown and InCombatLockdown() then
                    root:CreateButton("放弃 |cff888888(战斗中)|r", function() end)
                else
                    root:CreateButton("放弃", function() AbandonQuestInternal(questID) end)
                end
                root:CreateDivider()
                root:CreateTitle("BtWQuests")
                root:CreateButton("开启任务链", function() OpenBtWChain(questID) end)
                root:CreateDivider()
                root:CreateButton("复制 Wowhead 链接", function() CopyWowheadLink(questID) end)
            end)
        end)
        if ok then return end
    end

    -- 2) 兜底：自绘薄线菜单
    ShowCustomQuestMenu(questID, title, anchor)
end

local function CreateQuestBlock(questID, title, objectives, index, anchorY)
    local b = CreateFrame("Button", nil, content)
    b:SetPoint("TOPLEFT", 0, anchorY)
    b:SetPoint("TOPRIGHT", 0, anchorY)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            ShowQuestContextMenu(questID, title, self)
        else
            OpenQuestLog(questID)
        end
    end)
    b:SetScript("OnEnter", function(self)
        self.hl:Show()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        GameTooltip:AddLine(L["Quests"], 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip:Hide() end)

    -- hover 高亮（极淡）
    local hl = b:CreateTexture(nil, "BACKGROUND")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.04)
    hl:Hide()
    b.hl = hl

    -- 左侧 2px 指示线 + 标题颜色：仅超追踪的那一个黄，已完成绿，其余白
    local isComplete = false
    if C_QuestLog and C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID) then
        isComplete = true
    elseif objectives and #objectives > 0 then
        isComplete = true
        for _, o in ipairs(objectives) do if not o.finished then isComplete = false; break end end
    end
    -- 超追踪判定（当前在地图上高亮的单任务）
    local superID = GetSuperTrackedID()
    local isSuperTracked = (superID and superID == questID)

    local accent = b:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", 0, 0)
    accent:SetWidth(2)
    if isComplete then
        accent:SetColorTexture(COLOR_ACCENT_COMPLETE.r, COLOR_ACCENT_COMPLETE.g, COLOR_ACCENT_COMPLETE.b, 0.9)
    elseif isSuperTracked then
        accent:SetColorTexture(COLOR_ACCENT_TRACKING.r, COLOR_ACCENT_TRACKING.g, COLOR_ACCENT_TRACKING.b, 0.9)
    else
        accent:SetColorTexture(1, 1, 1, 0.18) -- 非超追踪的进行中：淡白，不抢眼
    end

    -- 右侧追踪切换按钮（无方框遮罩，仅 ◆/◇ 符号，hover 仅变色）
    local trackBtn = CreateFrame("Button", nil, b)
    trackBtn:SetSize(18, 18)
    trackBtn:SetPoint("TOPRIGHT", -4, -4)
    trackBtn:SetFrameLevel(b:GetFrameLevel() + 5)
    trackBtn:RegisterForClicks("LeftButtonUp")
    local btnIcon = trackBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btnIcon:SetPoint("CENTER", 0, 0)
    if isSuperTracked then
        btnIcon:SetText("◆")
        btnIcon:SetTextColor(COLOR_TITLE_TRACKING.r, COLOR_TITLE_TRACKING.g, COLOR_TITLE_TRACKING.b)
    else
        btnIcon:SetText("◇")
        btnIcon:SetTextColor(0.7, 0.7, 0.7)
    end
    trackBtn.icon = btnIcon
    trackBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if isSuperTracked then
            GameTooltip:SetText("取消追踪")
        else
            GameTooltip:SetText("设为追踪目标")
        end
        GameTooltip:AddLine(title, 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
        if isSuperTracked then
            self.icon:SetTextColor(1, 1, 1)
        else
            self.icon:SetTextColor(COLOR_TITLE_TRACKING.r, COLOR_TITLE_TRACKING.g, COLOR_TITLE_TRACKING.b)
        end
    end)
    trackBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        if isSuperTracked then
            self.icon:SetTextColor(COLOR_TITLE_TRACKING.r, COLOR_TITLE_TRACKING.g, COLOR_TITLE_TRACKING.b)
        else
            self.icon:SetTextColor(0.7, 0.7, 0.7)
        end
    end)
    trackBtn:SetScript("OnClick", function(self)
        ToggleSuperTrack(questID)
        C_Timer.After(0.05, function() if QS and QS.UpdateTracker then QS.UpdateTracker() end end)
    end)

    local titleFS = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleFS:SetPoint("TOPLEFT", 8, -6)
    titleFS:SetPoint("TOPRIGHT", -26, -6)
    titleFS:SetJustifyH("LEFT")
    titleFS:SetWordWrap(true) -- Q21 A 自动换行
    if isComplete then
        titleFS:SetTextColor(COLOR_TITLE_COMPLETE.r, COLOR_TITLE_COMPLETE.g, COLOR_TITLE_COMPLETE.b)
    elseif isSuperTracked then
        titleFS:SetTextColor(COLOR_TITLE_TRACKING.r, COLOR_TITLE_TRACKING.g, COLOR_TITLE_TRACKING.b)
    else
        titleFS:SetTextColor(0.95, 0.95, 0.95) -- 非超追踪：近白
    end
    titleFS:SetText(title or ("Quest " .. tostring(questID)))
    titleFS:SetSpacing(2)

    local y = - (titleFS:GetStringHeight() + 10)

    -- 目标行
    local objFSList = {}
    if objectives and #objectives > 0 then
        for _, obj in ipairs(objectives) do
            local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("TOPLEFT", 14, y)
            fs:SetPoint("TOPRIGHT", -6, y)
            fs:SetJustifyH("LEFT")
            fs:SetWordWrap(true)
            fs:SetSpacing(1)
            local col = obj.finished and COLOR_OBJ_COMPLETE or COLOR_OBJ_INCOMPLETE
            fs:SetTextColor(col.r, col.g, col.b)
            -- 前缀圆点
            local prefix = obj.finished and "● " or "○ "
            fs:SetText(prefix .. (obj.text or ""))
            y = y - (fs:GetStringHeight() + 4)
            table.insert(objFSList, fs)
        end
    else
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", 14, y)
        fs:SetPoint("TOPRIGHT", -6, y)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetTextColor(COLOR_EMPTY.r, COLOR_EMPTY.g, COLOR_EMPTY.b)
        fs:SetText("—")
        y = y - (fs:GetStringHeight() + 4)
    end

    -- 底部细分隔线（块之间，极简）
    local line = b:CreateTexture(nil, "ARTWORK")
    line:SetPoint("BOTTOMLEFT", 8, 0)
    line:SetPoint("BOTTOMRIGHT", -6, 0)
    line:SetHeight(1)
    line:SetColorTexture(1, 1, 1, 0.06)

    local h = math.abs(y) + 6
    b:SetHeight(h)
    return b, h
end

GetWatchedQuests = function()
    local out = {}
    -- Midnight 12.1 实测：C_QuestLog.GetInfo().isWatched 已恒为 nil（你 dump 的 78 行全为 nil），
    -- 必须走 Watch 列表 API
    local function push(qid)
        if not qid or qid == 0 then return end
        local title
        if C_QuestLog and C_QuestLog.GetTitleForQuestID then
            title = C_QuestLog.GetTitleForQuestID(qid)
        end
        if not title and GetQuestLogTitle then
            local idx = GetQuestLogIndexByID and GetQuestLogIndexByID(qid)
            if idx then title = GetQuestLogTitle(idx) end
        end
        title = title or ("Quest " .. tostring(qid))
        table.insert(out, { questID = qid, title = title })
    end

    -- 1) 优先：C_QuestLog.GetNumQuestWatches / GetQuestIDForQuestWatchIndex（12.1 仍保留）
    if C_QuestLog and C_QuestLog.GetNumQuestWatches and C_QuestLog.GetQuestIDForQuestWatchIndex then
        local ok, n = pcall(C_QuestLog.GetNumQuestWatches)
        if ok and n then
            if n > 0 then
                for i = 1, n do
                    local ok2, qid = pcall(C_QuestLog.GetQuestIDForQuestWatchIndex, i)
                    if ok2 then push(qid) end
                end
                if #out > 0 then return out end
            end
        end
    end
    -- 2) 全局 GetNumQuestWatches（兼容旧客户端）
    if GetNumQuestWatches and GetQuestIDForQuestWatchIndex then
        local ok, n = pcall(GetNumQuestWatches)
        if ok and n and n > 0 then
            for i = 1, n do
                local ok2, qid = pcall(GetQuestIDForQuestWatchIndex, i)
                if ok2 then push(qid) end
            end
            if #out > 0 then return out end
        end
    end
    -- 3) 旧路径兜底：isWatched（若未来暴雪修回）
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        local ok, num = pcall(C_QuestLog.GetNumQuestLogEntries)
        if ok and num and num > 0 then
            for i = 1, num do
                local ok2, info = pcall(C_QuestLog.GetInfo, i)
                if ok2 and info and not info.isHeader and info.isWatched and info.questID then
                    table.insert(out, { questID = info.questID, title = info.title })
                end
            end
            if #out > 0 then return out end
        end
    end
    return out
end

local function GetObjectives(questID)
    if C_QuestLog and C_QuestLog.GetQuestObjectives then
        local t = C_QuestLog.GetQuestObjectives(questID)
        if t then return t end
    end
    -- fallback: leaderboard
    local out = {}
    local idx = GetQuestLogIndexByID and GetQuestLogIndexByID(questID)
    if idx then
        local num = GetNumQuestLeaderBoards and GetNumQuestLeaderBoards(idx) or 0
        for i = 1, num do
            local text, type, finished = GetQuestLogLeaderBoard(i, idx)
            if text then table.insert(out, { text = text, type = type, finished = finished }) end
        end
    end
    return out
end

-- ========= 成就追踪（Midnight 12.x：C_ContentTracking 替代旧 GetTrackedAchievements） =========
local ACHIEVEMENT_TRACK_TYPE = 2 -- Enum.ContentTrackingType.Achievement
do
    if Enum and Enum.ContentTrackingType and Enum.ContentTrackingType.Achievement then
        ACHIEVEMENT_TRACK_TYPE = Enum.ContentTrackingType.Achievement
    end
end

local function IsAchievementCompleted(aid)
    if GetAchievementInfo then
        local ok, _, _, _, completed = pcall(GetAchievementInfo, aid)
        if ok and completed then return true end
    end
    -- 兼容：部分版本 completed 在第 4 位，也可通过 C_AchievementInfo 兜底
    if C_AchievementInfo and C_AchievementInfo.IsValidAchievement then
        -- 无直接完成判定，仍以 GetAchievementInfo 为准
    end
    return false
end

local function GetWatchedAchievements()
    local out = {}
    local function push(aid)
        if not aid or aid == 0 then return end
        -- 已完成的不追踪（用户要求）
        if IsAchievementCompleted(aid) then return end
        local title
        -- 优先 C_ContentTracking.GetTitle (12.x 新)
        if C_ContentTracking and C_ContentTracking.GetTitle then
            local ok, t = pcall(C_ContentTracking.GetTitle, ACHIEVEMENT_TRACK_TYPE, aid)
            if ok and t and t ~= "" then title = t end
        end
        if not title and GetAchievementInfo then
            local ok, _, name = pcall(GetAchievementInfo, aid)
            if ok and name and name ~= "" then title = name end
        end
        title = title or ("Achievement " .. tostring(aid))
        table.insert(out, { achievementID = aid, title = title })
    end
    -- 1) 新 API：C_ContentTracking.GetTrackedIDs
    if C_ContentTracking and C_ContentTracking.GetTrackedIDs then
        local ok, ids = pcall(C_ContentTracking.GetTrackedIDs, ACHIEVEMENT_TRACK_TYPE)
        if ok and ids and type(ids) == "table" and #ids > 0 then
            for _, aid in ipairs(ids) do push(aid) end
            if #out > 0 then return out end
        end
    end
    -- 2) 旧 API：GetTrackedAchievements (10.1.5 前)
    if GetTrackedAchievements then
        local ok, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10 = pcall(GetTrackedAchievements)
        if ok then
            local ids = {a1,a2,a3,a4,a5,a6,a7,a8,a9,a10}
            for _, aid in ipairs(ids) do if aid then push(aid) end end
            if #out > 0 then return out end
        end
    end
    -- 3) 兼容：GetNumTrackedAchievements + GetTrackedAchievements 循环
    if GetNumTrackedAchievements and GetTrackedAchievements then
        local ok, n = pcall(GetNumTrackedAchievements)
        if ok and n and n > 0 then
            for i = 1, n do
                -- 旧 API 无索引参数，但以防有
                local ok2, aid = pcall(GetTrackedAchievements)
                if ok2 and aid then push(aid) end
            end
        end
    end
    return out
end

local function GetAchievementObjectives(achievementID)
    local out = {}
    -- 尝试 criteria 列表
    local numCriteria = 0
    if GetAchievementNumCriteria then
        local ok, n = pcall(GetAchievementNumCriteria, achievementID)
        if ok and n then numCriteria = n end
    end
    if numCriteria > 0 and GetAchievementCriteriaInfo then
        for i = 1, numCriteria do
            local ok, desc, ctype, completed, qty, reqQty = pcall(GetAchievementCriteriaInfo, achievementID, i)
            if ok and desc and desc ~= "" then
                table.insert(out, { text = desc, finished = completed and true or false, qty = qty, req = reqQty })
            end
        end
        if #out > 0 then return out end
    end
    -- 降级：C_ContentTracking.GetObjectiveText (若可用)
    if C_ContentTracking and C_ContentTracking.GetObjectiveText then
        -- ContentTracking 的 objective 需通过 targetType/id，这里尝试直接用 trackable
        -- 先尝试通过 GetCurrentTrackingTarget 获取
        local ok, title = pcall(C_ContentTracking.GetTitle, ACHIEVEMENT_TRACK_TYPE, achievementID)
        if ok and title then
            -- 无细分进度时返回标题本身
        end
    end
    return out
end

local function OpenAchievement(achievementID)
    if not achievementID then return end
    -- 优先直接打开成就面板并选中
    if AchievementFrame and AchievementFrame:IsShown() == false then
        if ShowUIPanel then ShowUIPanel(AchievementFrame) end
    end
    -- wow 11+ 可能用 Settings 或新面板
    if C_ContentTracking and C_ContentTracking.GetTitle then
        -- 仅打开面板，不强制选中（避免 taint）
    end
    if AchievementFrame_SelectAchievement then
        pcall(AchievementFrame_SelectAchievement, achievementID)
    elseif AchievementFrameDisplayAchievement then
        pcall(AchievementFrameDisplayAchievement, achievementID)
    else
        if ToggleAchievementFrame then pcall(ToggleAchievementFrame) end
    end
end

local function CreateAchievementBlock(achievementID, title, objectives, index, anchorY)
    local b = CreateFrame("Button", nil, content)
    b:SetPoint("TOPLEFT", 0, anchorY)
    b:SetPoint("TOPRIGHT", 0, anchorY)
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnClick", function() OpenAchievement(achievementID) end)
    b:SetScript("OnEnter", function(self)
        self.hl:Show()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        GameTooltip:AddLine(L["Achievements"], 0.7, 0.7, 0.7, true)
        if objectives and #objectives > 0 then
            for _, o in ipairs(objectives) do
                local c = o.finished and "|cff55ff55" or "|cffffcc00"
                GameTooltip:AddLine(c .. (o.finished and "● " or "○ ") .. (o.text or ""), 1,1,1, true)
            end
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip:Hide() end)
    local hl = b:CreateTexture(nil, "BACKGROUND")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.04)
    hl:Hide()
    b.hl = hl

    local isComplete = false
    if GetAchievementInfo then
        local ok, _, _, _, completed = pcall(GetAchievementInfo, achievementID)
        if ok and completed then isComplete = true end
    end
    if not isComplete and objectives and #objectives > 0 then
        isComplete = true
        for _, o in ipairs(objectives) do if not o.finished then isComplete = false; break end end
    end
    local accent = b:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", 0, 0)
    accent:SetWidth(2)
    if isComplete then
        accent:SetColorTexture(COLOR_ACCENT_COMPLETE.r, COLOR_ACCENT_COMPLETE.g, COLOR_ACCENT_COMPLETE.b, 0.9)
    else
        accent:SetColorTexture(1, 1, 1, 0.18)
    end
    local titleFS = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleFS:SetPoint("TOPLEFT", 8, -6)
    titleFS:SetPoint("TOPRIGHT", -6, -6)
    titleFS:SetJustifyH("LEFT")
    titleFS:SetWordWrap(true)
    if isComplete then
        titleFS:SetTextColor(COLOR_TITLE_COMPLETE.r, COLOR_TITLE_COMPLETE.g, COLOR_TITLE_COMPLETE.b)
    else
        titleFS:SetTextColor(0.95, 0.95, 0.95)
    end
    -- 成就前缀图标感：用 ◆ 区分任务
    titleFS:SetText("◆ " .. (title or ("Achievement " .. tostring(achievementID))))
    titleFS:SetSpacing(2)
    local y = - (titleFS:GetStringHeight() + 10)
    if objectives and #objectives > 0 then
        for _, obj in ipairs(objectives) do
            local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("TOPLEFT", 14, y)
            fs:SetPoint("TOPRIGHT", -6, y)
            fs:SetJustifyH("LEFT")
            fs:SetWordWrap(true)
            fs:SetSpacing(1)
            local col = obj.finished and COLOR_OBJ_COMPLETE or COLOR_OBJ_INCOMPLETE
            fs:SetTextColor(col.r, col.g, col.b)
            local prefix = obj.finished and "● " or "○ "
            local txt = prefix .. (obj.text or "")
            if obj.qty and obj.req and obj.req > 1 then
                txt = txt .. string.format(" %d/%d", obj.qty, obj.req)
            end
            fs:SetText(txt)
            y = y - (fs:GetStringHeight() + 4)
        end
    else
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", 14, y)
        fs:SetPoint("TOPRIGHT", -6, y)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetTextColor(COLOR_EMPTY.r, COLOR_EMPTY.g, COLOR_EMPTY.b)
        fs:SetText("—")
        y = y - (fs:GetStringHeight() + 4)
    end
    local line = b:CreateTexture(nil, "ARTWORK")
    line:SetPoint("BOTTOMLEFT", 8, 0)
    line:SetPoint("BOTTOMRIGHT", -6, 0)
    line:SetHeight(1)
    line:SetColorTexture(1, 1, 1, 0.06)
    local h = math.abs(y) + 6
    b:SetHeight(h)
    return b, h
end

local function IsFrameEffectivelyShown(f)
    if not f or not f.IsShown then return false end
    local ok, shown = pcall(function() return f:IsShown() end)
    if not ok or not shown then return false end
    if f.IsVisible then
        local ok2, vis = pcall(function() return f:IsVisible() end)
        if ok2 and not vis then return false end
    end
    if f.GetAlpha then
        local ok3, a = pcall(function() return f:GetAlpha() end)
        if ok3 and a and a < 0.05 then return false end
    end
    return true
end

local function IsAnyMapShown()
    -- v1.0: 仅判 WorldMap/QuestMap，避免 MapCanvas 常驻导致的误藏（Q8A/Q9B）
    if IsFrameEffectivelyShown(WorldMapFrame) then return true end
    if IsFrameEffectivelyShown(QuestMapFrame) then return true end
    return false
end

local function UpdateTracker()
    if not QuestSkinDB or not QuestSkinDB.enabled then return end
    if IsAnyMapShown() then
        frame:Hide()
        return
    end
    ClearBlocks()
    if not frame:IsShown() then frame:Show() end
    -- 先同步宽度，避免换行高度计算时宽度不对导致“显示不全”
    local w = QuestSkinDB.width or defaults.width
    content:SetWidth(w - 34)
    frame:SetWidth(w)

    local watchedQuests = GetWatchedQuests()
    local watchedAchievements = GetWatchedAchievements()
    local nQ, nA = #watchedQuests, #watchedAchievements
    -- 标题：有成就则显示“任务 N · 成就 M”，否则保持兼容
    if nA == 0 then
        headerText:SetText(string.format("%s  %d", L["Quests"], nQ))
    elseif nQ == 0 then
        headerText:SetText(string.format("%s  %d", L["Achievements"], nA))
    else
        headerText:SetText(string.format("%s %d · %s %d", L["Quests"], nQ, L["Achievements"], nA))
    end

    if nQ == 0 and nA == 0 then
        local b = CreateFrame("Frame", nil, content)
        b:SetPoint("TOPLEFT", 0, 0)
        b:SetPoint("TOPRIGHT", 0, 0)
        b:SetHeight(28)
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetAllPoints()
        fs:SetJustifyH("CENTER")
        fs:SetTextColor(COLOR_EMPTY.r, COLOR_EMPTY.g, COLOR_EMPTY.b)
        fs:SetText(L["No tracked content"] or L["No tracked quests"])
        table.insert(blocks, b)
        content:SetHeight(28)
        frame:SetHeight(60)
        scroll:SetVerticalScroll(0)
        return
    end

    local y = 0
    local gap = 8 -- Q7 布局间距：块间距

    local function CreateSectionHeader(text, anchorY)
        local b = CreateFrame("Frame", nil, content)
        b:SetPoint("TOPLEFT", 0, anchorY)
        b:SetPoint("TOPRIGHT", 0, anchorY)
        b:SetHeight(18)
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", 6, 0)
        fs:SetText(text)
        fs:SetTextColor(0.65, 0.65, 0.65)
        fs:SetFontObject(GameFontNormalSmall)
        -- 右侧淡线
        local line = b:CreateTexture(nil, "ARTWORK")
        line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
        line:SetPoint("RIGHT", -6, 0)
        line:SetHeight(1)
        line:SetColorTexture(1, 1, 1, 0.08)
        table.insert(blocks, b)
        return b, 18
    end

    if nQ > 0 then
        local hb, hh = CreateSectionHeader(L["Quests"], y)
        y = y - (hh + 6)
        for i, q in ipairs(watchedQuests) do
            local objs = GetObjectives(q.questID)
            local b, h = CreateQuestBlock(q.questID, q.title, objs, i, y)
            if h < 20 then h = 40 end
            table.insert(blocks, b)
            y = y - (h + gap)
        end
    end
    if nA > 0 then
        -- 若前面已有任务，中间多留 10px 间距
        if nQ > 0 then y = y - 4 end
        local hb, hh = CreateSectionHeader(L["Achievements"], y)
        y = y - (hh + 6)
        for i, a in ipairs(watchedAchievements) do
            local objs = GetAchievementObjectives(a.achievementID)
            local b, h = CreateAchievementBlock(a.achievementID, a.title, objs, i, y)
            if h < 20 then h = 40 end
            table.insert(blocks, b)
            y = y - (h + gap)
        end
    end
    local totalH = math.abs(y) + 6
    content:SetHeight(totalH)
    -- 外框高度 = 标题 + 分隔 + 内容 + 边距；上限取设置里的 maxHeight 与屏幕 85% 的较小值
    local configuredMax = QuestSkinDB.maxHeight or defaults.maxHeight
    local screenCap = UIParent:GetHeight() * 0.85
    local maxH = math.min(configuredMax, screenCap)
    local wantH = totalH + 46
    local finalH = math.min(wantH, maxH)
    frame:SetHeight(finalH)
    -- 滚动逻辑：超出则启用滚轮，滚动条默认隐藏（仅滚轮时显现）
    scroll:SetVerticalScroll(0)
    if scroll.ScrollBar then scroll.ScrollBar:Hide(); scroll.ScrollBar:SetAlpha(0.85) end
    scroll:EnableMouseWheel(wantH > maxH)
end

-- 官方框显隐
local hooked = false
local function HookObjectiveTracker()
    if hooked or not ObjectiveTrackerFrame then return end
    hooksecurefunc(ObjectiveTrackerFrame, "Show", function(self)
        if QuestSkinDB and QuestSkinDB.enabled then self:Hide() end
    end)
    hooked = true
end

function QS.ApplyEnabled(enabled)
    QuestSkinDB.enabled = enabled and true or false
    if enabled then
        HookObjectiveTracker()
        if ObjectiveTrackerFrame then ObjectiveTrackerFrame:Hide() end
        frame:Show()
        -- 地图打开时自动隐藏，避免与地图右侧重叠错位
        if IsAnyMapShown() then frame:Hide() end
        UpdateTracker()
        if StartMapTicker then StartMapTicker() end
    else
        frame:Hide()
        if ObjectiveTrackerFrame then ObjectiveTrackerFrame:Show() end
        if StopMapTicker then StopMapTicker() end
    end
    if QuestSkin_EnableCheck then QuestSkin_EnableCheck:SetChecked(enabled) end
end

-- 地图打开/关闭时自动显隐，避免错位重叠（多帧 + hooksecurefunc 双保险）
local function SetupMapHandling()
    local hooked = false
    local function hookOne(f)
        if not f then return end
        if f._qsHooked then return end
        pcall(function() hooksecurefunc(f, "Show", function()
            if QuestSkinDB and QuestSkinDB.enabled and IsFrameEffectivelyShown(f) then frame:Hide(); if StartMapTicker then StartMapTicker() end end
        end) end)
        pcall(function() hooksecurefunc(f, "Hide", function()
            if QuestSkinDB and QuestSkinDB.enabled then frame:Show(); UpdateTracker(); if StopMapTicker then StopMapTicker() end end
        end) end)
        pcall(function() f:HookScript("OnShow", function()
            if QuestSkinDB and QuestSkinDB.enabled and IsFrameEffectivelyShown(f) then frame:Hide(); if StartMapTicker then StartMapTicker() end end
        end) end)
        pcall(function() f:HookScript("OnHide", function()
            if QuestSkinDB and QuestSkinDB.enabled then frame:Show(); UpdateTracker(); if StopMapTicker then StopMapTicker() end end
        end) end)
        f._qsHooked = true
        hooked = true
    end
    hookOne(WorldMapFrame)
    hookOne(QuestMapFrame)
    if frame._mapHooked and hooked == false then return true end
    frame._mapHooked = true
    if IsAnyMapShown() and QuestSkinDB and QuestSkinDB.enabled then frame:Hide() end
    return true
end

-- 事件
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
ev:RegisterEvent("QUEST_LOG_UPDATE")
ev:RegisterEvent("QUEST_ACCEPTED")
ev:RegisterEvent("QUEST_REMOVED")
ev:RegisterEvent("ZONE_CHANGED")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
-- 成就追踪（Midnight 新 ContentTracking + 旧兼容）
pcall(function() ev:RegisterEvent("CONTENT_TRACKING_UPDATE") end)
pcall(function() ev:RegisterEvent("CONTENT_TRACKING_LIST_UPDATE") end)
pcall(function() ev:RegisterEvent("TRACKABLE_INFO_UPDATE") end)
pcall(function() ev:RegisterEvent("TRACKED_ACHIEVEMENT_UPDATE") end)
pcall(function() ev:RegisterEvent("TRACKED_ACHIEVEMENT_LIST_CHANGED") end)
pcall(function() ev:RegisterEvent("ACHIEVEMENT_EARNED") end)
pcall(function() ev:RegisterEvent("CRITERIA_UPDATE") end)
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then
            QuestSkinDB = MigrateDB(QuestSkinDB)
            -- 归一化旧存档的居中/底部锚点为顶部锚点，保证从上到下展开
            if QuestSkinDB.point and not QuestSkinDB.point:find("TOP") then
                QuestSkinDB.point, QuestSkinDB.relativePoint = defaults.point, defaults.relativePoint
                QuestSkinDB.x, QuestSkinDB.y = defaults.x, defaults.y
            end
            -- 恢复位置与宽度
            frame:ClearAllPoints()
            frame:SetPoint(QuestSkinDB.point, UIParent, QuestSkinDB.relativePoint, QuestSkinDB.x, QuestSkinDB.y)
            frame:SetWidth(QuestSkinDB.width)
            content:SetWidth(QuestSkinDB.width - 34)
            if QuestSkin_EnableCheck then QuestSkin_EnableCheck:SetChecked(QuestSkinDB.enabled) end
            QS.ApplyEnabled(QuestSkinDB.enabled)
            HookObjectiveTracker()
            SetupMapHandling()
            C_Timer.After(0.5, UpdateTracker)
        elseif arg1 == "Blizzard_WorldMap" then
            SetupMapHandling()
        end
    elseif QuestSkinDB and QuestSkinDB.enabled then
        -- 节流：QUEST_LOG_UPDATE 很频繁 — 改为 pending 合并，避免 0.2s 内二次事件被直接丢弃
        if ev._timer then
            ev._pending = true
            return
        end
        ev._timer = true
        ev._pending = false
        C_Timer.After(0.2, function()
            ev._timer = nil
            UpdateTracker()
            -- 若期间有 pending，再补一次
            if ev._pending then
                ev._pending = false
                ev._timer = true
                C_Timer.After(0.2, function()
                    ev._timer = nil
                    UpdateTracker()
                end)
            end
        end)
    end
end)

-- 宽度调整
function QS.SetWidth(w)
    w = math.max(200, math.min(420, w or defaults.width))
    QuestSkinDB.width = w
    frame:SetWidth(w)
    content:SetWidth(w - 34)
    UpdateTracker()
end

-- 高度调整（最大高度，放不下时出现滚轮滚动条）
function QS.SetMaxHeight(h)
    h = math.max(180, math.min(700, h or defaults.maxHeight))
    QuestSkinDB.maxHeight = h
    UpdateTracker()
end

-- 重置位置到默认（修复“显示不全/被裁切”时用 /qs reset）
function QS.ResetPosition()
    QuestSkinDB.point = defaults.point
    QuestSkinDB.relativePoint = defaults.relativePoint
    QuestSkinDB.x = defaults.x
    QuestSkinDB.y = defaults.y
    QuestSkinDB.width = defaults.width
    QuestSkinDB.maxHeight = defaults.maxHeight
    frame:ClearAllPoints()
    frame:SetPoint(defaults.point, UIParent, defaults.relativePoint, defaults.x, defaults.y)
    frame:SetWidth(defaults.width)
    content:SetWidth(defaults.width - 34)
    frame:SetClampedToScreen(true)
    -- 同步设置面板滑条（若已创建）
    if QuestSkin_WidthSlider then QuestSkin_WidthSlider:SetValue(defaults.width) end
    if QuestSkin_HeightSlider then QuestSkin_HeightSlider:SetValue(defaults.maxHeight) end
    UpdateTracker()
    print("|cff88ff88QuestSkin|r: 已重置位置到右上 -32,-200，宽度 260 高度 420")
end

-- 启动时也尝试挂钩地图（WorldMapFrame 启动即存在，Blizzard_WorldMap 懒加载再补一次）
C_Timer.After(1, SetupMapHandling)
-- 超追踪切换时刷新黄/绿标记
local superEv = CreateFrame("Frame")
superEv:RegisterEvent("SUPER_TRACKING_CHANGED")
superEv:SetScript("OnEvent", function()
    if QuestSkinDB and QuestSkinDB.enabled then UpdateTracker() end
end)
-- 动态 Ticker（Q13B）：仅地图期间 1.0s 轮询，地图关闭 5s 后取消，避免常驻耗电
local mapTicker = nil
local hideCancelTimer = nil
StartMapTicker = function()
    if hideCancelTimer then hideCancelTimer:Cancel(); hideCancelTimer = nil end
    if mapTicker then return end
    mapTicker = C_Timer.NewTicker(1.0, function()
        if not QuestSkinDB or not QuestSkinDB.enabled then
            if mapTicker then mapTicker:Cancel(); mapTicker = nil end
            return
        end
        if IsAnyMapShown() then
            if frame:IsShown() then frame:Hide() end
        else
            if not frame:IsShown() then
                frame:Show()
                UpdateTracker()
            end
        end
    end)
end
StopMapTicker = function()
    if mapTicker then
        -- 延迟 5s 取消，避免地图快速开关抖动
        if hideCancelTimer then hideCancelTimer:Cancel() end
        hideCancelTimer = C_Timer.NewTimer(5, function()
            if mapTicker then mapTicker:Cancel(); mapTicker = nil end
            hideCancelTimer = nil
        end)
    end
end
-- 初始不启动，仅地图 Show 时触发；此处兜底若启动时已处地图中
C_Timer.After(1, function()
    if IsAnyMapShown() then StartMapTicker() end
end)

QS.StartMapTicker = StartMapTicker
QS.StopMapTicker = StopMapTicker
QS.UpdateTracker = UpdateTracker
_G.QuestSkinFrame = frame
