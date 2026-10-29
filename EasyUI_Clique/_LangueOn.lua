-- EasyUI : ce module charge ses traductions françaises (AceLocale lit GAME_LOCALE)
local loc = GetLocale()
EasyUI_SavedGameLocale = GAME_LOCALE
if loc == "enUS" or loc == "enGB" then GAME_LOCALE = "frFR" end
