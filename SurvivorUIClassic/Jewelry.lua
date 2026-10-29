-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the jewelry worn this run. The neck, the two rings and
-- the two trinkets, each in its slot as the character pane shows them: the
-- piece's icon, its name in its quality's color and what it gives in short
-- ("+24% CRIT DMG  +10% CDR"), read off its tooltip. Hover a piece for its
-- tooltip. In a run only.

local SLOTS = {
	{ 2, "Neck", "Interface\\PaperDoll\\UI-PaperDoll-Slot-Neck" },
	{ 11, "Ring", "Interface\\PaperDoll\\UI-PaperDoll-Slot-Finger" },
	{ 12, "Ring", "Interface\\PaperDoll\\UI-PaperDoll-Slot-Finger" },
	{ 13, "Trinket", "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket" },
	{ 14, "Trinket", "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket" },
}
local WIDTH = 230
local ROW = 30
local TOP = 26

local panel = CreateFrame("Frame", "SUICJewelry", UIParent)
panel:SetWidth(WIDTH)
panel:SetHeight(TOP + table.getn(SLOTS) * ROW + 8)
panel:SetBackdrop(SUIC.BACKDROP)
panel:SetBackdropColor(0, 0, 0, 0.7)
panel:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
panel:Hide()

local function Home(f)
	f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -12, -420)
end
Home(panel)

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -9)
title:SetText("Jewelry")

------------------------------------------------------------------------------
-- What a piece gives, in short: each tooltip line with a number, its number
-- and its word, the more specific words first (CRIT DMG before CRIT).

local WORDS = {
	{ "stun", "STUN" }, { "root", "ROOT" }, { "shields you", "SHIELD" }, { "absorb", "ABSORB" },
	{ "explode", "BOOM" }, { "leap", "LEAP" }, { "splash", "SPLASH" }, { "bleed", "BLEED" },
	{ "strike again", "AGAIN" }, { "duration", "DUR" },
	{ "kill restores", "HP/KILL" }, { "kill heals", "HP/KILL" }, { "each kill", "HP/KILL" },
	{ "damage dealt heals", "LEECH" }, { "leech", "LEECH" },
	{ "critical strike damage", "CRIT DMG" }, { "critical damage", "CRIT DMG" },
	{ "critical strikes deal", "CRIT DMG" }, { "critical", "CRIT" }, { "crit", "CRIT" },
	{ "cooldown", "CDR" }, { "damage reduction", "DMG RED" }, { "damage taken", "DMG RED" },
	{ "armor", "DMG RED" }, { "area", "AREA" }, { "target", "TGT" }, { "twice", "ECHO" },
	{ "echo", "ECHO" }, { "movement", "SPD" }, { "speed", "SPD" }, { "per second", "REGEN" },
	{ "health", "HP" }, { "pickup", "PICK" }, { "pick up", "PICK" }, { "experience", "XP" },
	{ "gold", "GOLD" }, { "luck", "LUCK" }, { "heal", "HEAL" }, { "thorns", "THORNS" },
	{ "live", "LIFE" }, { "damage", "DMG" },
}
local MORE = { "more", "increase", "improve", "restore", "heals" }

local function Tag(text)
	local lower = string.lower(text)
	local word
	for index = 1, table.getn(WORDS) do
		if string.find(lower, WORDS[index][1], 1, true) then
			word = WORDS[index][2]
			break
		end
	end
	local _, _, value = string.find(text, "([%+%-]?%d+%.?%d*%%?)")
	if not (word and value) then
		return nil
	end
	local first = string.sub(value, 1, 1)
	if first ~= "+" and first ~= "-" then
		for index = 1, table.getn(MORE) do
			if string.find(lower, MORE[index], 1, true) then
				value = "+"..value
				break
			end
		end
	end
	return value.." "..word
end

local scan = CreateFrame("GameTooltip", "SUICJewelryTip", nil, "GameTooltipTemplate")
local known = {}                -- [item link] = short text

local function Short(slot, link)
	if known[link] then
		return known[link]
	end
	scan:SetOwner(WorldFrame, "ANCHOR_NONE")
	scan:ClearLines()
	scan:SetInventoryItem("player", slot)
	local tags = {}
	for index = 2, scan:NumLines() do
		local line = getglobal("SUICJewelryTipTextLeft"..index)
		local text = line and line:GetText()
		if text and string.find(text, "%d") then
			local tag = Tag(text)
			if tag then
				table.insert(tags, tag)
			end
		end
	end
	scan:Hide()
	known[link] = table.concat(tags, "  ")
	return known[link]
end

------------------------------------------------------------------------------
-- The rows.

local function RowEnter()
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	if GetInventoryItemLink("player", this.slot) then
		GameTooltip:SetInventoryItem("player", this.slot)
	else
		GameTooltip:SetText(this.label)
		GameTooltip:AddLine("Empty", 0.6, 0.6, 0.6)
	end
	GameTooltip:Show()
end

local rows = {}
for index = 1, table.getn(SLOTS) do
	local row = CreateFrame("Frame", nil, panel)
	row:SetWidth(WIDTH - 16)
	row:SetHeight(ROW - 2)
	row:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -TOP - (index - 1) * ROW)
	row:EnableMouse(true)
	row.slot, row.label, row.empty = SLOTS[index][1], SLOTS[index][2], SLOTS[index][3]
	row:SetScript("OnEnter", RowEnter)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetWidth(24)
	row.icon:SetHeight(24)
	row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, -1)
	row.name:SetWidth(WIDTH - 50)
	row.name:SetJustifyH("LEFT")
	row.gives = row:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
	row.gives:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 6, 1)
	row.gives:SetWidth(WIDTH - 50)
	row.gives:SetJustifyH("LEFT")
	rows[index] = row
end

local function Draw()
	for index = 1, table.getn(rows) do
		local row = rows[index]
		local link = GetInventoryItemLink("player", row.slot)
		if link then
			row.icon:SetTexture(GetInventoryItemTexture("player", row.slot))
			local _, _, color, name = string.find(link, "|c(%x+)|H.-|h%[(.-)%]|h")
			row.name:SetText("|c"..(color or "ffffffff")..(name or "?").."|r")
			row.gives:SetText(Short(row.slot, link))
		else
			row.icon:SetTexture(row.empty)
			row.name:SetText("|cff8a8a8a"..row.label.."|r")
			row.gives:SetText("")
		end
	end
end

local function Refresh()
	if SUIC.DB().jewelry and SUIC.InRun() then
		if not panel:IsShown() then
			panel:Show()
		end
		Draw()
	else
		panel:Hide()
	end
end
SUIC.RefreshJewelry = Refresh

local watch = CreateFrame("Frame")
watch:SetScript("OnEvent", function()
	if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then
		return
	end
	Refresh()
end)
local ticker = 0
watch:SetScript("OnUpdate", function()
	ticker = ticker + arg1
	if ticker < 1 then
		return
	end
	ticker = 0
	Refresh()
end)
watch:Hide()

SUIC.OnStart(function()
	SUIC.AddPiece("jewelry", "Jewelry", panel, Home)
	SUIC.OverCards(panel, true)
	watch:RegisterEvent("UNIT_INVENTORY_CHANGED")
	watch:RegisterEvent("PLAYER_ENTERING_WORLD")
	watch:Show()
	Refresh()
end)
