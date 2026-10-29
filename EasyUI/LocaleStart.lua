--[[
	EasyUI - Langue des modules
	Le client est en anglais mais l'interface EasyUI est en français :
	pendant le chargement des modules, on demande les traductions françaises
	(AceLocale lit GAME_LOCALE). LocaleEnd.lua remet la valeur d'origine.
]]
local _, ns = ...

-- Tables privées des modules intégrés : chaque module d'origine garde la sienne
-- (comme quand il était un addon séparé).
EasyUIPriv = EasyUIPriv or setmetatable({}, { __index = function(t, k)
	local v = {}
	rawset(t, k, v)
	return v
end })
