--[[
	EasyUI - Page Minimap
	Forme, bordures, boutons, coordonnées, fondu, zoom automatique, carte HUD.
]]
local _, ns = ...

-- Style EasyUI : minimap carrée, bordure fine, boutons au survol
function ns:ApplyMinimapTheme()
	local sm = self:GetAceAddon("SexyMap")
	if not sm then return end
	local shapes = sm:GetModule("Shapes", true)
	if shapes and shapes.ApplyShape then
		pcall(shapes.ApplyShape, shapes, "Interface\\AddOns\\EasyUI_Minimap\\SexyMap\\shapes\\square")
	end
	local borders = sm:GetModule("Borders", true)
	if borders and borders.db then
		-- retire les bordures décoratives et met un fond sombre à contour fin
		if borders.Clear then pcall(borders.Clear, borders) end
		local p = borders.db.profile
		p.hideBlizzard = true
		p.backdrop.show = true
		p.backdrop.scale = 1
		p.backdrop.alpha = 1
		p.backdrop.textureColor = { r = 0.06, g = 0.06, b = 0.07, a = 0.9 }
		p.backdrop.borderColor = { r = 0, g = 0, b = 0, a = 1 }
		p.backdrop.settings = {
			bgFile = ns.media.white, edgeFile = ns.media.white, edgeSize = 1, tile = false,
			insets = { left = 1, right = 1, top = 1, bottom = 1 },
		}
		if borders.Update then pcall(borders.Update, borders) end
		if borders.UpdateBackdrop then pcall(borders.UpdateBackdrop, borders) end
	end
	local ACR = self:GetLib("AceConfigRegistry-3.0")
	if ACR then ACR:NotifyChange("SexyMap") end
	self:Print("Style EasyUI appliqué à la minimap.")
end

ns:RegisterPage({
	key = "minimap",
	module = "minimap",
	title = "Minimap",
	subtitle = "Forme, bordures, boutons, coordonnées, fondu au survol, zoom automatique et carte HUD.",
	icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
	group = "modules",
	order = 52,

	build = function(page)
		ns:AddPageAction(page, "Style EasyUI", 110, function() ns:ApplyMinimapTheme() end)
		page.view = ns:CreateOptionsView(page.body, "SexyMap", {
			key = "minimap",
			hide = { Profiles = true },
		})
	end,
})
