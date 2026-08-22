-- core.lua — QuestSkin v1.0 极简重绘核心
-- 约定：v1.0 严格纯美化，不做进度百分比等功能增强
local ADDON = "QuestSkin"
local L = QuestSkin_L or setmetatable({}, { __index = function(_, k) return k end })

QuestSkin = QuestSkin or {}
local QS = QuestSkin

-- 默认存档（-32 更保险，避免不同分辨率下右侧被裁切）
local defaults = {
    enabled = true,
    point = "TOPRIGHT",
    relativePoint = "TOPRIGHT",
    x = -32,
    y = -200,
    width = 260,
    maxHeight = 420,
}

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

-- 拖动保存
frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint()
    QuestSkinDB.point = point
    QuestSkinDB.relativePoint = relativePoint
    QuestSkinDB.x = x
    QuestSkinDB.y = y
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

local headerHint = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
headerHint:SetPoint("RIGHT", 0, 0)
headerHint:SetTextColor(0.5, 0.5, 0.5)
headerHint:SetText(L["Drag to move"])

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

local function CreateQuestBlock(questID, title, objectives, index, anchorY)
    local b = CreateFrame("Button", nil, content)
    b:SetPoint("TOPLEFT", 0, anchorY)
    b:SetPoint("TOPRIGHT", 0, anchorY)
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnClick", function() OpenQuestLog(questID) end)
    b:SetScript("OnEnter", function(self)
        self.hl:Show()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        GameTooltip:AddLine(L["Drag to move"] .. " | " .. L["Quests"], 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip:Hide() end)

    -- hover 高亮（极淡）
    local hl = b:CreateTexture(nil, "BACKGROUND")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.04)
    hl:Hide()
    b.hl = hl

    -- 左侧 2px 指示线 + 标题颜色：追踪中黄，已完成绿
    -- 判定：全部目标 finished 或 C_QuestLog.IsComplete 视为已完成
    local isComplete = false
    if C_QuestLog and C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID) then
        isComplete = true
    elseif objectives and #objectives > 0 then
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
        accent:SetColorTexture(COLOR_ACCENT_TRACKING.r, COLOR_ACCENT_TRACKING.g, COLOR_ACCENT_TRACKING.b, 0.9)
    end

    local titleFS = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleFS:SetPoint("TOPLEFT", 8, -6)
    titleFS:SetPoint("TOPRIGHT", -6, -6)
    titleFS:SetJustifyH("LEFT")
    titleFS:SetWordWrap(true) -- Q21 A 自动换行
    -- 保留暴雪字体，仅改颜色：黄=追踪中，绿=已完成
    if isComplete then
        titleFS:SetTextColor(COLOR_TITLE_COMPLETE.r, COLOR_TITLE_COMPLETE.g, COLOR_TITLE_COMPLETE.b)
    else
        titleFS:SetTextColor(COLOR_TITLE_TRACKING.r, COLOR_TITLE_TRACKING.g, COLOR_TITLE_TRACKING.b)
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

local function GetWatchedQuests()
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
        local n = C_QuestLog.GetNumQuestWatches()
        if n and n > 0 then
            for i = 1, n do
                local qid = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
                push(qid)
            end
            if #out > 0 then return out end
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
        local num = C_QuestLog.GetNumQuestLogEntries()
        for i = 1, num do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader and info.isWatched and info.questID then
                table.insert(out, { questID = info.questID, title = info.title })
            end
        end
        if #out > 0 then return out end
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

local function UpdateTracker()
    if not QuestSkinDB or not QuestSkinDB.enabled then return end
    -- 地图打开期间强制隐藏，避免重叠错位（兜底：钩子未生效时也生效）
    if WorldMapFrame and WorldMapFrame:IsShown() then
        frame:Hide()
        return
    end
    ClearBlocks()
    -- 若之前因地图隐藏，这里要恢复显示
    if not frame:IsShown() then frame:Show() end
    -- 先同步宽度，避免换行高度计算时宽度不对导致“显示不全”
    local w = QuestSkinDB.width or defaults.width
    content:SetWidth(w - 34)
    frame:SetWidth(w)

    local watched = GetWatchedQuests()
    headerText:SetText(string.format("%s  %d", L["Quests"], #watched))

    if #watched == 0 then
        local b = CreateFrame("Frame", nil, content)
        b:SetPoint("TOPLEFT", 0, 0)
        b:SetPoint("TOPRIGHT", 0, 0)
        b:SetHeight(28)
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetAllPoints()
        fs:SetJustifyH("CENTER")
        fs:SetTextColor(COLOR_EMPTY.r, COLOR_EMPTY.g, COLOR_EMPTY.b)
        fs:SetText(L["No tracked quests"])
        table.insert(blocks, b)
        content:SetHeight(28)
        frame:SetHeight(60)
        scroll:SetVerticalScroll(0)
        return
    end

    local y = 0
    local gap = 8 -- Q7 布局间距：块间距
    for i, q in ipairs(watched) do
        local objs = GetObjectives(q.questID)
        local b, h = CreateQuestBlock(q.questID, q.title, objs, i, y)
        -- 防御：GetStringHeight 在布局前可能返回 0，保底高度
        if h < 20 then h = 40 end
        table.insert(blocks, b)
        y = y - (h + gap)
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
        if WorldMapFrame and WorldMapFrame:IsShown() then frame:Hide() end
        UpdateTracker()
    else
        frame:Hide()
        if ObjectiveTrackerFrame then ObjectiveTrackerFrame:Show() end
    end
    if QuestSkin_EnableCheck then QuestSkin_EnableCheck:SetChecked(enabled) end
end

-- 地图打开/关闭时自动显隐，避免错位重叠（双保险：Hook + UpdateTracker 兜底）
local function SetupMapHandling()
    if not WorldMapFrame then return false end
    if frame._mapHooked then return true end
    -- HookScript 可能因 taint 失败，改用 hooksecurefunc 更稳
    hooksecurefunc(WorldMapFrame, "Show", function()
        if QuestSkinDB and QuestSkinDB.enabled then frame:Hide() end
    end)
    hooksecurefunc(WorldMapFrame, "Hide", function()
        if QuestSkinDB and QuestSkinDB.enabled then frame:Show(); UpdateTracker() end
    end)
    WorldMapFrame:HookScript("OnShow", function()
        if QuestSkinDB and QuestSkinDB.enabled then frame:Hide() end
    end)
    WorldMapFrame:HookScript("OnHide", function()
        if QuestSkinDB and QuestSkinDB.enabled then frame:Show(); UpdateTracker() end
    end)
    frame._mapHooked = true
    if WorldMapFrame:IsShown() and QuestSkinDB and QuestSkinDB.enabled then frame:Hide() end
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
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then
            QuestSkinDB = QuestSkinDB or {}
            for k, v in pairs(defaults) do if QuestSkinDB[k] == nil then QuestSkinDB[k] = v end end
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
        -- 节流：QUEST_LOG_UPDATE 很频繁
        if ev._timer then return end
        ev._timer = true
        C_Timer.After(0.2, function()
            ev._timer = nil
            UpdateTracker()
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
-- 兜底轮询：地图打开期间强制保持隐藏（防止 Hook 被 taint 拦截时仍能生效）
C_Timer.NewTicker(0.4, function()
    if not QuestSkinDB or not QuestSkinDB.enabled then return end
    if not WorldMapFrame then return end
    if WorldMapFrame:IsShown() then
        if frame:IsShown() then frame:Hide() end
    else
        if not frame:IsShown() then
            frame:Show()
            UpdateTracker()
        end
    end
end)

QS.UpdateTracker = UpdateTracker
_G.QuestSkinFrame = frame
