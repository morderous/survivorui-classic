-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the game's own nameplates, on with this interface. V
-- turns the enemies' on and off, Shift-V the friends', each on its own (the
-- stock keys show one kind and hide the other). The keys are set once, as the
-- addon first starts, and saved with the game's bindings; changed after in
-- the game's Key Bindings, they stay as chosen. The game's Level Up! key, if
-- V took it, goes back to Y.

BINDING_HEADER_SUIC = "SurvivorUI Classic"
BINDING_NAME_SUIC_ENEMYPLATES = "Enemy nameplates on and off"
BINDING_NAME_SUIC_FRIENDPLATES = "Friendly nameplates on and off"

function SUIC_ToggleEnemyPlates()
	if NAMEPLATES_ON then
		HideNameplates()
		NAMEPLATES_ON = nil
	else
		ShowNameplates()
		NAMEPLATES_ON = 1
	end
end

function SUIC_ToggleFriendPlates()
	if FRIENDNAMEPLATES_ON then
		HideFriendNameplates()
		FRIENDNAMEPLATES_ON = nil
	else
		ShowFriendNameplates()
		FRIENDNAMEPLATES_ON = 1
	end
end

-- The game's Nameplate Layout (its 0.131): nil on a game without it.
local function Layout()
	local known, value = pcall(GetCVar, "nameplateLayout")
	return known and value or nil
end

function SUIC.RefreshPlateLayout()
	if Layout() then
		SetCVar("nameplateLayout", SUIC.DB().plateOverlap and "overlap" or "stack")
	end
end

SUIC.OnStart(function()
	local db = SUIC.DB()
	-- Overlapping for everyone, once; after that the box follows the game's
	-- option, which may have changed since.
	if Layout() then
		if db.layoutSet then
			db.plateOverlap = Layout() == "overlap"
		else
			db.layoutSet = true
			db.plateOverlap = true
			SUIC.RefreshPlateLayout()
		end
	end
	if db.plates then
		return
	end
	db.plates = true
	-- The enemies' plates on, the first time.
	if not NAMEPLATES_ON then
		ShowNameplates()
		NAMEPLATES_ON = 1
	end
	if SetBinding and SaveBindings then
		local levels = GetBindingAction and GetBindingAction("V")
		SetBinding("V", "SUIC_ENEMYPLATES")
		SetBinding("SHIFT-V", "SUIC_FRIENDPLATES")
		if levels == "AZS_OPENLEVELS" and not GetBindingKey("AZS_OPENLEVELS")
				and (GetBindingAction("Y") or "") == "" then
			SetBinding("Y", "AZS_OPENLEVELS")
		end
		SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1)
	end
end)

------------------------------------------------------------------------------
-- Which enemies' plates show (the options' Nameplates tab): your target only,
-- or the bosses, guardians and elites only (the game's list of them, by
-- name); with either on, your target always. A plate left out has its art
-- and bar made clear, the plate itself untouched: the client keeps it, and
-- its target's light (the target's plate the one at full alpha).
--
-- The client keeps a pool of plates and hands them from unit to unit as the
-- enemies come within 20 yards, go and die: in a crowd, every moment. So a
-- plate is judged again as the client shows it (its OnShow, the new unit's
-- name and bar already on it) and every frame after, else one handed on
-- shows its last unit's look for a moment.
--
-- The boss bar under the mouse lines its enemy's plate in white
-- (SUIC.LightPlate, BossBars.lua), shown whatever the two options leave out.

local scanned, plates = 0, {}
local important, importantAt = {}, nil
local lit                       -- the enemy's name to line, or nil
local line = CreateFrame("Frame", nil, UIParent)
line:SetBackdrop({
	edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
	tile = false, edgeSize = 1,
	insets = { left = 0, right = 0, top = 0, bottom = 0 },
})
line:SetBackdropBorderColor(1, 1, 1, 1)
line:Hide()

function SUIC.LightPlate(name)
	lit = name
	if not name then
		line:Hide()
	end
end

local function IsPlate(frame)
	local region = frame:GetRegions()
	return region and region.GetObjectType and region:GetObjectType() == "Texture"
		and region:GetTexture() == "Interface\\Tooltips\\Nameplate-Border"
end

local function Important()
	if AZS_UNITS_UPDATED ~= importantAt then
		importantAt = AZS_UNITS_UPDATED
		important = {}
		local units = AZS_UNITS or {}
		for index = 1, table.getn(units) do
			if units[index].name then
				important[units[index].name] = true
			end
		end
	end
	return important
end

-- A plate's parts, read once (the client never makes them anew): its
-- regions and its health bar, and its name.
local function Parts(plate)
	local parts = { plate:GetRegions() }
	for index = 1, table.getn(parts) do
		if parts[index]:GetObjectType() == "FontString" then
			plate.suicName = parts[index]
			break
		end
	end
	local children = { plate:GetChildren() }
	plate.suicBar = children[1]
	for index = 1, table.getn(children) do
		table.insert(parts, children[index])
	end
	plate.suicParts = parts
end

local function Clear(plate, alpha)
	if plate.suicAlpha == alpha then
		return
	end
	plate.suicAlpha = alpha
	local parts = plate.suicParts
	for index = 1, table.getn(parts) do
		parts[index]:SetAlpha(alpha)
	end
end

local function Filter(plate, db, target, names)
	local onlyTarget, onlyImportant = db.platesTarget, db.platesImportant
	if not (onlyTarget or onlyImportant) then
		Clear(plate, 1)
		return
	end
	local bar = plate.suicBar
	local r = bar and bar.GetStatusBarColor and bar:GetStatusBarColor()
	-- A friend's plate (green or blue) stays as it is.
	if r and r < 0.2 then
		Clear(plate, 1)
		return
	end
	local isTarget = target and plate:GetAlpha() == 1
	local name = (onlyImportant or lit) and plate.suicName and plate.suicName:GetText()
	local shown = isTarget or (name and (name == lit or (onlyImportant and names[name])))
	Clear(plate, shown and 1 or 0)
end

-- The line round the first plate of that name.
local function KeepLine()
	for index = 1, table.getn(plates) do
		local plate = plates[index]
		if plate:IsVisible() and plate.suicName and plate.suicName:GetText() == lit then
			local bar = plate.suicBar
			if line:GetParent() ~= bar then
				line:SetParent(bar)
				line:ClearAllPoints()
				line:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
				line:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
				line:SetFrameLevel(bar:GetFrameLevel() + 3)
			end
			line:Show()
			return
		end
	end
	line:Hide()
end

local function OnShown()
	Filter(this, SUIC.DB(), UnitExists("target"), Important())
end

local function Watch(plate)
	Parts(plate)
	local stock = plate:GetScript("OnShow")
	if stock then
		plate:SetScript("OnShow", function()
			stock()
			OnShown()
		end)
	else
		plate:SetScript("OnShow", OnShown)
	end
	table.insert(plates, plate)
	if plate:IsVisible() then
		Filter(plate, SUIC.DB(), UnitExists("target"), Important())
	end
end

local scanner = CreateFrame("Frame")
scanner:SetScript("OnUpdate", function()
	local count = WorldFrame:GetNumChildren()
	if count ~= scanned then
		local children = { WorldFrame:GetChildren() }
		for index = scanned + 1, count do
			if children[index] and IsPlate(children[index]) then
				Watch(children[index])
			end
		end
		scanned = count
	end
	local db, target, names = SUIC.DB(), UnitExists("target"), Important()
	for index = 1, table.getn(plates) do
		if plates[index]:IsVisible() then
			Filter(plates[index], db, target, names)
		end
	end
	if lit then
		KeepLine()
	end
end)
scanner:Hide()

SUIC.OnStart(function()
	scanner:Show()
end)
