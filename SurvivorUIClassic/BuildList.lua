-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the build list. The run's six spell slots, filled or
-- not, each spell with its icon, its name as the game writes it, its cooldown
-- and its rank; the racial apart at the bottom (it takes no slot). The empty
-- slots show, since how many are left matters at every card. Hover a spell
-- for its tooltip.
--
-- From the game's addon API (AZS_SPELLS, your racial last): its spells sit on
-- the action bar in the list's order, the racial on button 12. In a run only.

local SLOTS = 6
local RACIAL_SLOT = 12
local WIDTH = 210
local ROW = 22
local TOP = 26
local EMPTY = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"

local panel = CreateFrame("Frame", "SUICBuildList", UIParent)
panel:SetWidth(WIDTH)
panel:SetHeight(TOP + (SLOTS + 1) * ROW + 14)
panel:SetBackdrop(SUIC.BACKDROP)
panel:SetBackdropColor(0, 0, 0, 0.7)
panel:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
panel:Hide()

local function Home(f)
	f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -12, -230)
end
Home(panel)

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -9)
title:SetText("Build")
local count = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
count:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -11)

-- The spell's name as its button's tooltip gives it, in the game's language.
local scan = CreateFrame("GameTooltip", "SUICScanTip", nil, "GameTooltipTemplate")
local function SpellName(slot)
	scan:SetOwner(WorldFrame, "ANCHOR_NONE")
	scan:ClearLines()
	scan:SetAction(slot)
	local line = getglobal("SUICScanTipTextLeft1")
	local name = line and line:GetText()
	scan:Hide()
	return name
end

local function RowEnter()
	if not this.slot then
		return
	end
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	GameTooltip:SetAction(this.slot)
	GameTooltip:Show()
end

local rows = {}
for index = 1, SLOTS + 1 do
	local row = CreateFrame("Frame", nil, panel)
	row:SetWidth(WIDTH - 16)
	row:SetHeight(ROW - 2)
	local y = -TOP - (index - 1) * ROW
	if index > SLOTS then
		y = y - 6
	end
	row:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)
	row:EnableMouse(true)
	row:SetScript("OnEnter", RowEnter)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetWidth(18)
	row.icon:SetHeight(18)
	row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetWidth(110)
	row.rank = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	row.rank:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	row.cd = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	row.cd:SetPoint("RIGHT", row, "RIGHT", -42, 0)
	rows[index] = row
end

-- A line between the slots and the racial.
local rule = panel:CreateTexture(nil, "ARTWORK")
rule:SetTexture(SUIC.FLAT)
rule:SetVertexColor(0.6, 0.6, 0.6, 0.35)
rule:SetHeight(1)
rule:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -TOP - SLOTS * ROW - 1)
rule:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -TOP - SLOTS * ROW - 1)

local function Cooldown(entry)
	local seconds = tonumber(entry.cdmax) or 0
	if seconds <= 0 then
		return ""
	elseif seconds < 10 then
		return string.format("%.1fs", seconds)
	end
	return math.floor(seconds + 0.5).."s"
end

local function Fill(row, entry, slot, racial)
	row.slot = slot
	row.icon:SetTexture(GetActionTexture(slot) or EMPTY)
	local name = SpellName(slot) or entry.key or "?"
	if racial then
		name = name.." |cff8a8a8a(racial)|r"
	end
	row.name:SetText(name)
	row.rank:SetText(entry.rank and ("Rank "..entry.rank) or "")
	row.cd:SetText(Cooldown(entry))
	row:Show()
end

local function Empty(row)
	row.slot = nil
	row.icon:SetTexture(EMPTY)
	row.name:SetText("|cff8a8a8aEmpty|r")
	row.rank:SetText("")
	row.cd:SetText("")
	row:Show()
end

local function Draw()
	local spells = AZS_SPELLS or {}
	local total = table.getn(spells)
	-- The racial is the last one; a hero has one.
	local slotted = math.max(0, total - 1)
	for index = 1, SLOTS do
		if index <= slotted then
			Fill(rows[index], spells[index], index, false)
		else
			Empty(rows[index])
		end
	end
	if total > 0 then
		Fill(rows[SLOTS + 1], spells[total], RACIAL_SLOT, true)
	else
		rows[SLOTS + 1]:Hide()
	end
	if slotted >= SLOTS then
		count:SetText("|cffff8080"..SLOTS.." / "..SLOTS.."|r")
	else
		count:SetText(slotted.." / "..SLOTS)
	end
end

local function Refresh()
	if SUIC.DB().buildList and SUIC.InRun() and AZS_SPELLS and table.getn(AZS_SPELLS) > 0 then
		if not panel:IsShown() then
			panel:Show()
		end
		Draw()
	else
		panel:Hide()
	end
end
SUIC.RefreshBuildList = Refresh

local watch = CreateFrame("Frame")
watch:SetScript("OnEvent", function()
	if event == "CHAT_MSG_ADDON" and arg1 ~= "AZSSPELLS" and arg1 ~= "AZSZONE" then
		return
	end
	Refresh()
end)
-- The phase comes and goes with no event of its own: a slow look too.
local ticker = 0
watch:SetScript("OnUpdate", function()
	ticker = ticker + arg1
	if ticker < 1 then
		return
	end
	ticker = 0
	-- IsShown gives 1 or nil.
	local wanted = SUIC.DB().buildList and SUIC.InRun() and true or false
	if wanted ~= (panel:IsShown() and true or false) then
		Refresh()
	end
end)
watch:Hide()

SUIC.OnStart(function()
	SUIC.AddPiece("build", "Build list", panel, Home)
	SUIC.OverCards(panel, true)
	watch:RegisterEvent("CHAT_MSG_ADDON")
	watch:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
	watch:RegisterEvent("PLAYER_ENTERING_WORLD")
	watch:Show()
	Refresh()
end)
