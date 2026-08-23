-- .luacheckrc — QuestSkin v1.0 (Q14A)
std = "lua51"
globals = {
  "QuestSkin", "QuestSkin_L", "QuestSkinDB",
  "QuestSkin_SettingsPanel", "QuestSkin_EnableCheck", "QuestSkin_SettingsCategory", "QuestSkin_SettingsLayout",
  "QuestSkin_WidthSlider", "QuestSkin_HeightSlider", "QuestSkin_RegisterSettings", "QuestSkinFrame",
  -- WoW API
  "CreateFrame", "UIParent", "GameTooltip", "GameFontNormalSmall", "GameFontHighlightSmall", "GameFontNormalLarge",
  "Settings", "SettingsPanel", "InterfaceOptions_AddCategory", "InterfaceOptionsFrame_OpenToCategory",
  "C_QuestLog", "C_SuperTrack", "C_ContentTracking", "C_Timer", "C_AchievementInfo", "C_AddOns",
  "Enum", "WorldMapFrame", "QuestMapFrame", "ObjectiveTrackerFrame", "AchievementFrame",
  "GetQuestLogIndexByID", "GetQuestLogTitle", "GetNumQuestLeaderBoards", "GetQuestLogLeaderBoard",
  "GetAchievementInfo", "GetAchievementNumCriteria", "GetAchievementCriteriaInfo",
  "GetTrackedAchievements", "GetNumTrackedAchievements",
  "SelectQuestLogEntry", "SetAbandonQuest", "QuestMapFrame_OpenToQuestDetails", "ToggleQuestLog",
  "ShowUIPanel", "StaticPopup_Show", "StaticPopup_FindVisible", "StaticPopupDialogs",
  "hooksecurefunc", "UISpecialFrames", "UIPanelScrollFrameTemplate", "UIFrameFadeOut",
  "InCombatLockdown", "IsInGroup", "GetCursorPosition",
  "SLASH_QUESTSKIN1", "SLASH_QUESTSKIN2", "SlashCmdList",
  "MenuUtil", "QuestMapQuestOptionsDropDown", "UIDropDownMenu_Initialize", "ToggleDropDownMenu",
}
ignore = { "212/self", "212/_", "211", "213" }
max_line_length = 200
