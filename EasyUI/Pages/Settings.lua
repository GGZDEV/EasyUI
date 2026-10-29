--[[
	EasyUI - Page Options
]]
local _, ns = ...

local PALETTE = {
	gold    = { "Or", 1.00, 0.82, 0.00 },
	emerald = { "Émeraude", 0.10, 0.84, 0.63 },
	blue    = { "Bleu", 0.20, 0.66, 1.00 },
	violet  = { "Violet", 0.64, 0.42, 1.00 },
	pink    = { "Rose", 1.00, 0.45, 0.62 },
	orange  = { "Orange", 1.00, 0.55, 0.15 },
	red     = { "Rouge", 0.95, 0.30, 0.30 },
	silver  = { "Argent", 0.85, 0.87, 0.92 },
}

local pendingScale
local function ApplyUIScale(v)
	pendingScale = v
	ns:After(0.3, function()
		if pendingScale and not InCombatLockdown() then
			SetCVar("useUiScale", "1")
			SetCVar("uiScale", pendingScale)
			pendingScale = nil
		end
	end)
end

local function SetAccent(r, g, b)
	ns.db.accent = { r = r, g = g, b = b }
	ns.db.useClassColor = false
	ns:UpdateAccent()
end

local function Options()
	local db = ns.db
	return { type = "group", name = "Options", args = {
		look = { type = "group", name = "Apparence", order = 1, args = {
			accentH = { type = "header", name = "Couleur d'accent", order = 1 },
			palette = {
				type = "select", name = "Palette", order = 2,
				values = function()
					local t = { custom = "Personnalisée" }
					for k, v in pairs(PALETTE) do t[k] = v[1] end
					return t
				end,
				sorting = { "gold", "emerald", "blue", "violet", "pink", "orange", "red", "silver", "custom" },
				get = function()
					local a = db.accent
					for k, v in pairs(PALETTE) do
						if math.abs(v[2] - a.r) < 0.01 and math.abs(v[3] - a.g) < 0.01 and math.abs(v[4] - a.b) < 0.01 then return k end
					end
					return "custom"
				end,
				set = function(_, k) local v = PALETTE[k] if v then SetAccent(v[2], v[3], v[4]) end end,
				disabled = function() return db.useClassColor end,
			},
			custom = {
				type = "color", name = "Couleur personnalisée", order = 3,
				get = function() return db.accent.r, db.accent.g, db.accent.b end,
				set = function(_, r, g, b) SetAccent(r, g, b) end,
				disabled = function() return db.useClassColor end,
			},
			classColor = {
				type = "toggle", name = "Couleur de ma classe", order = 4,
				get = function() return db.useClassColor end,
				set = function(_, v) db.useClassColor = v ns:UpdateAccent() end,
			},
			fontH = { type = "header", name = "Police", order = 6 },
			font = {
				type = "select", name = "Police de l'interface EasyUI", order = 7, dialogControl = "LSM30_Font",
				desc = "Rechargement de l'interface nécessaire.",
				values = function()
					local t = {}
					for _, f in ipairs(ns.fonts) do t[f.name] = f.path end
					return t
				end,
				get = function()
					for _, f in ipairs(ns.fonts) do if f.key == (db.font or ns.DEFAULT_FONT) then return f.name end end
				end,
				set = function(_, name)
					for _, f in ipairs(ns.fonts) do
						if f.name == name then db.font = f.key end
					end
					ns:AskReload()
				end,
			},
			wizard = {
				type = "execute", name = "Assistant de configuration", order = 8,
				desc = "Relance l'assistant du premier lancement (couleur, police, échelle, style).",
				func = function() ns:ShowSetupWizard() end,
			},
			windowH = { type = "header", name = "Fenêtre EasyUI", order = 10 },
			scale = {
				type = "range", name = "Échelle du panneau", order = 11, min = 0.6, max = 1.4, step = 0.05, isPercent = true,
				get = function() return db.scale end,
				set = function(_, v) db.scale = v ns.frame:SetScale(v) end,
			},
			recenter = {
				type = "execute", name = "Recentrer la fenêtre", order = 12,
				func = function() db.point = nil ns:RestorePosition() end,
			},
		} },

		style = { type = "group", name = "Style des modules", order = 2, args = {
			info = { type = "description", order = 0, fontSize = "medium",
				name = "Donne le même look sombre et épuré à toute l'interface." },
			applyAll = {
				type = "execute", name = "Appliquer le style EasyUI partout", order = 1, width = "full",
				desc = "Barres d'incantation, sacs et temps de recharge.",
				func = function()
					ns:ApplyQuartzTheme()
					ns:ApplyBagnonTheme()
					ns:ApplyCooldownTheme()
				end,
			},
			buttons = {
				type = "toggle", name = "Boutons d'action modernes", order = 2,
				desc = "Icônes rognées, bordure fine, raccourcis lisibles. Désactiver nécessite un rechargement.",
				get = function() return db.skin.buttons end,
				set = function(_, v) db.skin.buttons = v if v then ns:SkinActionButtons() else ns:AskReload() end end,
			},
			windows = {
				type = "toggle", name = "Fenêtres des modules au style EasyUI", order = 3,
				desc = "Liste des cadres, éditeur de click-casting... Rechargement nécessaire.",
				get = function() return db.skin.windows end,
				set = function(_, v) db.skin.windows = v ns:AskReload() end,
			},
			bagnon = {
				type = "toggle", name = "Sacs au fond plat", order = 4,
				desc = "Remplace la bordure arrondie des sacs par une bordure fine.",
				get = function() return db.skin.bagnon end,
				set = function(_, v) db.skin.bagnon = v if v then ns:ApplyBagnonTheme() else ns:AskReload() end end,
			},
		} },

		ui = { type = "group", name = "Interface", order = 3, args = {
			uiScale = {
				type = "range", name = "Échelle de l'interface", order = 1, min = 0.64, max = 1, step = 0.01,
				get = function() return tonumber(GetCVar("uiScale")) or 1 end,
				set = function(_, v) ApplyUIScale(v) end,
			},
			pixel = {
				type = "execute", name = "Pixel perfect", order = 2,
				desc = "Un pixel de l'interface = un pixel de l'écran (768 / hauteur de la résolution).",
				func = function()
					local h = tonumber((GetCVar("gxResolution") or ""):match("%d+x(%d+)"))
					if h then ApplyUIScale(math.max(0.64, math.min(1, 768 / h))) end
				end,
			},
			castbar = {
				type = "toggle", name = "Masquer la barre d'incantation du jeu", order = 3, width = "full",
				desc = "La barre d'incantation EasyUI la remplace. Désactiver nécessite un rechargement.",
				get = function() return db.hideGameCastbar end,
				set = function(_, v) db.hideGameCastbar = v if not v then ns:AskReload() end end,
			},
			minimapH = { type = "header", name = "Minimap", order = 10 },
			minimap = {
				type = "toggle", name = "Bouton EasyUI sur la minimap", order = 11,
				get = function() return not db.minimap.hide end,
				set = function(_, v) db.minimap.hide = not v ns:UpdateMinimapButton() end,
			},
			otherIcons = {
				type = "toggle", name = "Masquer les autres boutons des modules", order = 12,
				get = function() return db.hideAddonMinimapIcons end,
				set = function(_, v)
					db.hideAddonMinimapIcons = v
					local LDBIcon = ns:GetLib("LibDBIcon-1.0")
					local bt = ns:GetAceAddon("Bartender4")
					if bt and bt.db and bt.db.profile.minimapIcon then
						bt.db.profile.minimapIcon.hide = v
						if LDBIcon then if v then LDBIcon:Hide("Bartender4") else LDBIcon:Show("Bartender4") end end
					end
				end,
			},
		} },

		edit = { type = "group", name = "Mode édition", order = 4, args = {
			info = { type = "description", order = 0, fontSize = "medium",
				name = "Ce qui devient déplaçable quand tu actives le mode édition (/eui edit ou clic droit sur le bouton de la minimap)." },
			bartender = { type = "toggle", name = "Barres d'action", order = 1,
				get = function() return db.editMode.bartender end, set = function(_, v) db.editMode.bartender = v end },
			quartz = { type = "toggle", name = "Barres d'incantation", order = 2,
				get = function() return db.editMode.quartz end, set = function(_, v) db.editMode.quartz = v end },
			bagnon = { type = "toggle", name = "Sacs", order = 3,
				get = function() return db.editMode.bagnon end, set = function(_, v) db.editMode.bagnon = v end },
			blizzard = { type = "toggle", name = "Cadres Blizzard", order = 4,
				get = function() return db.editMode.blizzard end, set = function(_, v) db.editMode.blizzard = v end },
			moveanything = { type = "toggle", name = "Ouvrir la liste complète des cadres", order = 5,
				get = function() return db.editMode.moveanything end, set = function(_, v) db.editMode.moveanything = v end },
			gridH = { type = "header", name = "Grille", order = 10 },
			grid = { type = "toggle", name = "Afficher la grille", order = 11,
				get = function() return db.grid.show end, set = function(_, v) db.grid.show = v ns:UpdateGrid() end },
			gridSize = { type = "range", name = "Taille des cases", order = 12, min = 8, max = 128, step = 4,
				get = function() return db.grid.size end, set = function(_, v) db.grid.size = v ns:UpdateGrid() end },
			framesH = { type = "header", name = "Cadres Blizzard concernés", order = 20 },
			frames = {
				type = "multiselect", name = "Cadres", order = 21,
				values = function()
					local t = {}
					for _, e in ipairs(ns.editFrames) do t[e[1]] = e[2] end
					return t
				end,
				get = function(_, k) return not db.editMode.skipFrames[k] end,
				set = function(_, k, v) db.editMode.skipFrames[k] = (not v) or nil end,
			},
		} },

		modules = { type = "group", name = "Modules", order = 5, args = (function()
			local args = {
				info = { type = "description", order = 0, fontSize = "medium",
					name = "Un module désactivé n'est pas chargé du tout (il ne consomme rien). Changer un module recharge l'interface." },
			}
			for i, m in ipairs(ns.modules) do
				args[m.key] = {
					type = "toggle", name = m.title, desc = m.desc, order = i,
					get = function() return ns:ModuleEnabled(m.key) end,
					set = function(_, v) ns:SetModuleEnabled(m.key, v) end,
				}
			end
			return args
		end)() },

		reset = { type = "group", name = "Réinitialisation", order = 9, args = {
			info = { type = "description", order = 0, fontSize = "medium",
				name = "Remet les réglages du panneau EasyUI par défaut (couleurs, fenêtre, mode édition). Les réglages des barres, sacs, etc. ne sont pas touchés." },
			resetAll = {
				type = "execute", name = "Réinitialiser EasyUI", order = 1,
				confirm = true, confirmText = "Réinitialiser les réglages d'EasyUI et recharger l'interface ?",
				func = function() EasyUIDB = nil ReloadUI() end,
			},
		} },
	} }
end

ns:RegisterPage({
	key = "settings",
	title = "Options",
	subtitle = "Apparence, style des modules, échelle de l'interface, minimap et mode édition.",
	icon = "Interface\\Icons\\INV_Misc_Gear_01",
	group = "system",
	order = 90,

	build = function(page)
		page.view = ns:CreateOptionsView(page.body, Options(), { key = "settings" })
	end,
})
