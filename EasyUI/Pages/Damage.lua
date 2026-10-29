--[[
	EasyUI - Page Compteur de dégâts
	Réglages essentiels de chaque fenêtre, dans le style EasyUI.
	Les réglages avancés restent accessibles (bouton « Options avancées »).
]]
local _, ns = ...

local function D() return _G.Details end

-- fenêtre sélectionnée
local selected = 1
local function Win()
	local d = D()
	return d and d.GetInstance and d:GetInstance(selected)
end

local function Windows()
	local t, d = {}, D()
	if d and d.tabela_instancias then
		for i in ipairs(d.tabela_instancias) do t[i] = "Fenêtre " .. i end
	end
	return t
end

local function StatusbarValues()
	local LSM = ns:GetLib("LibSharedMedia-3.0")
	return LSM and LSM:HashTable("statusbar") or {}
end
local function FontValues()
	local LSM = ns:GetLib("LibSharedMedia-3.0")
	return LSM and LSM:HashTable("font") or {}
end

local function SkinValues()
	local t, d = {}, D()
	for name in pairs(d and d.skins or {}) do t[name] = name end
	return t
end

-- réglage d'une fenêtre (désactivé si la fenêtre n'existe pas)
local function W(def)
	def.disabled = function() local w = Win() return not (w and w.baseframe) end
	return def
end

local function Options()
	local window = { type = "group", name = "Fenêtre", order = 1, args = {
		pick = {
			type = "select", name = "Fenêtre à régler", order = 1,
			values = Windows,
			get = function() return selected end,
			set = function(_, v) selected = v end,
		},
		open = {
			type = "execute", name = "Afficher / masquer les fenêtres", order = 2,
			func = function() D():ToggleWindows() end,
		},
		new = {
			type = "execute", name = "Nouvelle fenêtre", order = 3,
			func = function() D():CreateInstance(true) end,
		},
		advanced = {
			type = "execute", name = "Options avancées", order = 4,
			func = function()
				ns.frame:Hide()
				D():OpenOptionsWindow(Win() or D():GetInstance(1))
			end,
		},
		lookH = { type = "header", name = "Apparence de la fenêtre", order = 10 },
		skin = W({
			type = "select", name = "Thème", order = 11,
			values = SkinValues,
			get = function() local w = Win() return w and w.skin end,
			set = function(_, v) Win():ChangeSkin(v) end,
		}),
		scale = W({
			type = "range", name = "Échelle", order = 12, min = 0.6, max = 1.6, step = 0.05, isPercent = true,
			get = function() local w = Win() return w and w.window_scale or 1 end,
			set = function(_, v) Win():SetWindowScale(v, true) end,
		}),
		bgAlpha = W({
			type = "range", name = "Opacité du fond", order = 13, min = 0, max = 1, step = 0.05, isPercent = true,
			get = function() local w = Win() return w and w.bg_alpha or 0.7 end,
			set = function(_, v) Win():SetBackgroundAlpha(v) end,
		}),
		color = W({
			type = "color", name = "Couleur de la fenêtre", order = 14, hasAlpha = true,
			get = function()
				local w = Win()
				local c = w and w.color
				if c then return c[1], c[2], c[3], c[4] end
				return 1, 1, 1, 1
			end,
			set = function(_, r, g, b, a) Win():InstanceColor(r, g, b, a) end,
		}),
		lock = W({
			type = "toggle", name = "Verrouiller la fenêtre", order = 15,
			get = function() local w = Win() return w and w.isLocked end,
			set = function(_, v) Win():LockInstance(v) end,
		}),
		barsH = { type = "header", name = "Barres", order = 20 },
		barHeight = W({
			type = "range", name = "Hauteur des barres", order = 21, min = 8, max = 40, step = 1,
			get = function() local w = Win() return w and w.row_info.height or 14 end,
			set = function(_, v) Win():SetBarSettings(v) end,
		}),
		barSpace = W({
			type = "range", name = "Espace entre les barres", order = 22, min = 0, max = 10, step = 1,
			get = function() local w = Win() return w and w.row_info.space.between or 1 end,
			set = function(_, v) Win():SetBarSettings(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, v) end,
		}),
		texture = W({
			type = "select", name = "Texture des barres", order = 23, dialogControl = "LSM30_Statusbar",
			values = StatusbarValues,
			get = function() local w = Win() return w and w.row_info.texture end,
			set = function(_, v) Win():SetBarSettings(nil, v) end,
		}),
		classColor = W({
			type = "toggle", name = "Barres à la couleur de classe", order = 24,
			get = function() local w = Win() return w and w.row_info.texture_class_colors end,
			set = function(_, v) Win():SetBarSettings(nil, nil, v) end,
		}),
		textH = { type = "header", name = "Texte", order = 30 },
		font = W({
			type = "select", name = "Police", order = 31, dialogControl = "LSM30_Font",
			values = FontValues,
			get = function() local w = Win() return w and w.row_info.font_face end,
			set = function(_, v) Win():SetBarTextSettings(nil, v) end,
		}),
		fontSize = W({
			type = "range", name = "Taille du texte", order = 32, min = 7, max = 20, step = 1,
			get = function() local w = Win() return w and w.row_info.font_size or 11 end,
			set = function(_, v) Win():SetBarTextSettings(v) end,
		}),
	} }

	local general = { type = "group", name = "Général", order = 2, args = {
		speed = {
			type = "range", name = "Rafraîchissement (secondes)", order = 1, min = 0.05, max = 3, step = 0.05,
			get = function() return D().update_speed or 0.3 end,
			set = function(_, v) D():SetWindowUpdateSpeed(v) end,
		},
		dataH = { type = "header", name = "Données", order = 10 },
		reset = {
			type = "execute", name = "Effacer tous les combats", order = 11,
			confirm = true, confirmText = "Effacer tous les segments de combat enregistrés ?",
			func = function() D().tabela_historico:ResetAllCombatData() end,
		},
		themeH = { type = "header", name = "Style", order = 20 },
		theme = {
			type = "execute", name = "Appliquer le style EasyUI à toutes les fenêtres", order = 21, width = "full",
			func = function() ns:ApplyDamageTheme() end,
		},
	} }

	return { type = "group", name = "Compteur de dégâts", args = { window = window, general = general } }
end

-- Style EasyUI : barres plates, police EasyUI, fond sombre
function ns:ApplyDamageTheme()
	local d = D()
	if not d then return end
	for i in ipairs(d.tabela_instancias or {}) do
		local w = d:GetInstance(i)
		if w and w.baseframe then
			pcall(w.SetBarSettings, w, 18, "EasyUI")
			pcall(w.SetBarTextSettings, w, 11, self:CurrentFontName())
			pcall(w.SetBackgroundAlpha, w, 0.75)
		end
	end
	self:Print("Style EasyUI appliqué au compteur de dégâts.")
end

ns:RegisterPage({
	key = "damage",
	module = "damage",
	title = "Compteur de dégâts",
	subtitle = "Dégâts, soins, interruptions, morts... par combat, avec le détail par joueur et par sort.",
	icon = "Interface\\Icons\\Ability_Warrior_BattleShout",
	group = "modules",
	order = 37,

	build = function(page)
		ns:AddPageAction(page, "Afficher / masquer", 130, function() D():ToggleWindows() end, "accent")
		page.view = ns:CreateOptionsView(page.body, Options(), { key = "damage" })
	end,
})
