-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the jewelry worn this run, in the right column under the
-- build list. The neck, the two rings and the two trinkets, each in its slot:
-- the piece's icon, its name in its quality's color (on one line: a class
-- amulet too long, "Charm of the Fated Hour: Call of Flame", by its spell
-- alone, "Call of Flame"; else cut short) and what it gives in short ("+24%
-- CRIT DMG  +10% CDR"), read off its tooltip. Hover a piece for
-- its tooltip. In a run only.

local SLOTS = {
	{ 2, "Neck", "Interface\\PaperDoll\\UI-PaperDoll-Slot-Neck" },
	{ 11, "Ring", "Interface\\PaperDoll\\UI-PaperDoll-Slot-Finger" },
	{ 12, "Ring", "Interface\\PaperDoll\\UI-PaperDoll-Slot-Finger" },
	{ 13, "Trinket", "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket" },
	{ 14, "Trinket", "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket" },
}
local W = SUIC.WIDTH
local PAD = SUIC.PAD
local ROW = 22                  -- two lines: the name, what it gives just under
local TOP = SUIC.TITLE + 4

local panel = SUIC.Window("SUICJewelry", "Jewelry")
panel:SetHeight(TOP + table.getn(SLOTS) * ROW + 5)

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

local NAME_ROOM = W - 2 * PAD - ROW - 2

-- A piece's name on one line: whole, else a class amulet's spell alone (the
-- part after its colon), else cut with dots.
local function Fit(text, name, color)
	text:SetText("|c"..color..name.."|r")
	if text:GetStringWidth() <= NAME_ROOM then
		return
	end
	local _, _, spell = string.find(name, ": (.+)$")
	if spell then
		name = spell
		text:SetText("|c"..color..name.."|r")
	end
	while text:GetStringWidth() > NAME_ROOM and string.len(name) > 4 do
		name = string.sub(name, 1, string.len(name) - 1)
		text:SetText("|c"..color..name.."...|r")
	end
end

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
	row:SetWidth(W - 2 * PAD)
	row:SetHeight(ROW - 1)
	row:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -TOP - (index - 1) * ROW)
	row:EnableMouse(true)
	row.slot, row.label, row.empty = SLOTS[index][1], SLOTS[index][2], SLOTS[index][3]
	row:SetScript("OnEnter", RowEnter)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetWidth(ROW - 3)
	row.icon:SetHeight(ROW - 3)
	row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.name = SUIC.Text(row, "GameFontHighlightSmall")
	row.name:SetJustifyH("LEFT")
	row.name:SetWidth(NAME_ROOM + 20)
	row.name:SetHeight(12)
	row.gives = SUIC.Text(row, "GameFontGreenSmall", 7)
	row.gives:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -1)
	row.gives:SetJustifyH("LEFT")
	row.gives:SetWidth(W - 2 * PAD - ROW - 2)
	rows[index] = row
end

local function Draw()
	local worn = 0
	for index = 1, table.getn(rows) do
		local row = rows[index]
		local link = GetInventoryItemLink("player", row.slot)
		row.name:ClearAllPoints()
		if link then
			worn = worn + 1
			row.icon:SetTexture(GetInventoryItemTexture("player", row.slot))
			local _, _, color, name = string.find(link, "|c(%x+)|H.-|h%[(.-)%]|h")
			Fit(row.name, name or "?", color or "ffffffff")
			row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 5, 0)
			row.gives:SetText(Short(row.slot, link))
		else
			row.icon:SetTexture(row.empty)
			row.name:SetText("|cff8a8a8a"..row.label.."|r")
			row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
			row.gives:SetText("")
		end
	end
	panel.note:SetText(worn.." / "..table.getn(rows))
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
SUIC.RefreshJewelry = function()
	Refresh()
	SUIC.SeatColumn()
end

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
	SUIC.ColumnHome("jewelry")(panel)
	SUIC.AddPiece("jewelry", "Jewelry", panel, SUIC.ColumnHome("jewelry"))
	SUIC.OverCards(panel)
	watch:RegisterEvent("UNIT_INVENTORY_CHANGED")
	watch:RegisterEvent("PLAYER_ENTERING_WORLD")
	watch:Show()
	Refresh()
end)
