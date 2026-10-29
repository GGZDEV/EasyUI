local addonName, addon = "Clique", _G.Clique

-- EasyUI : librairies optionnelles (fournies par le client ou un autre addon)
local LibSerialize = LibStub("LibSerialize", true)
local LibDeflate = LibStub("LibDeflate", true)

function addon:CanImportExport()
	LibSerialize = LibSerialize or LibStub("LibSerialize", true)
	LibDeflate = LibDeflate or LibStub("LibDeflate", true)
	return LibSerialize ~= nil and LibDeflate ~= nil
end

function addon:GetExportString()
	if not self:CanImportExport() then return "" end
	local data = addon.db.profile.bindings
	local serialized = LibSerialize:Serialize(data)
	local compressed = LibDeflate:CompressDeflate(serialized)
	local encoded = LibDeflate:EncodeForPrint(compressed)

	return string.format("CL01:%s", encoded)
end

function addon:DecodeExportString(text)
	if not self:CanImportExport() then return end
	local header = string.sub(text, 1, 5)
	if header ~= "CL01:" then return end

	local payload = string.sub(text, 6, string.len(text))
	local decoded = LibDeflate:DecodeForPrint(payload)
	if not decoded then return end
	local decompressed = LibDeflate:DecompressDeflate(decoded)
	if not decompressed then return end
	local success, data = LibSerialize:Deserialize(decompressed)
	if not success then return end
	return data
end

function addon:ImportBindings(importBindings)
	self.db.profile.bindings = importBindings
	self.bindings = self.db.profile.bindings
	addon:Printf("Importing new bindings into current profile")
	self:FireMessage("BINDINGS_CHANGED")
end
