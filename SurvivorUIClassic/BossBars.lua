-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the boss bars, the game's own as they look, at the top
-- of the screen in the middle: the name in red over a long thin red bar in a
-- black line. Two things more than the game's: they move (Move frames), and
-- a click targets the enemy (the one targeted is framed in gold; hover for
-- its health in numbers). Every boss alive, the final boss first, then the
-- lair guardians awake or hurt (named in blue) and the elites (in gold), as
-- chosen, four of them at most (the bosses always); an enraged boss's name in
-- orange.
--
-- They stand in for the game's boss bars, which are put away while these are
-- on and given back as the game closes. From the game's addon API (AZS_UNITS).

local WIDTH = 278
local HEIGHT = 8
local NAME = 13                 -- the name's line, over the bar
local STEP = NAME + HEIGHT + 7  -- one boss and the room under it
local MOST = 12
local ORDER = { final = 1, boss = 2, guardian = 3, elite = 4 }
local KIND_NAMES = { final = "Final boss", boss = "Boss", guardian = "Lair guardian", elite = "Elite" }
local NAME_COLORS = {
	final = { 1, 0.42, 0.42 },
	boss = { 1, 0.42, 0.42 },
	guardian = { 0.45, 0.8, 1 },
	elite = { 1, 0.82, 0 },
}
local LINE = {
	edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
	tile = false, edgeSize = 1,
	insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

local holder = CreateFrame("Frame", "SUICBossBars", UIParent)
holder:SetWidth(WIDTH)
holder:SetHeight(STEP)

local function Home(f)
	f:SetPoint("TOP", UIParent, "TOP", 0, -46)
end
Home(holder)

local function EntryEnter()
	local unit = this.unit
	if not unit then
		return
	end
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
	GameTooltip:SetText(unit.name or "?")
	GameTooltip:AddLine(KIND_NAMES[unit.kind] or "", 1, 0.82, 0)
	local hpm = tonumber(unit.hpm) or 0
	if hpm > 0 then
		GameTooltip:AddLine(SUIC.Short(unit.hp).." / "..SUIC.Short(hpm).."  ("
			..math.floor((tonumber(unit.hp) or 0) / hpm * 100 + 0.5).."%)", 1, 1, 1)
	end
	if unit.kind ~= "guardian" and unit.state == 1 then
		GameTooltip:AddLine("Enraged", 1, 0.5, 0.15)
	end
	GameTooltip:AddLine("Click to target it.", 0.7, 0.7, 0.7)
	GameTooltip:Show()
end

local function EntryClick()
	if this.unit and TargetByName then
		TargetByName(this.unit.name, true)
	end
end

local entries = {}
for index = 1, MOST do
	local entry = CreateFrame("Button", nil, holder)
	entry:SetWidth(WIDTH)
	entry:SetHeight(NAME + HEIGHT + 2)
	entry:SetPoint("TOP", holder, "TOP", 0, -(index - 1) * STEP)
	entry:RegisterForClicks("LeftButtonUp")
	entry:SetScript("OnClick", EntryClick)
	entry:SetScript("OnEnter", EntryEnter)
	entry:SetScript("OnLeave", function() GameTooltip:Hide() end)
	entry.name = SUIC.Text(entry, "GameFontNormal")
	entry.name:SetPoint("TOP", entry, "TOP", 0, 0)
	local bar = CreateFrame("StatusBar", nil, entry)
	bar:SetWidth(WIDTH)
	bar:SetHeight(HEIGHT)
	bar:SetPoint("TOP", entry, "TOP", 0, -NAME)
	bar:SetStatusBarTexture(SUIC.STOCK_BAR)
	bar:SetStatusBarColor(0.82, 0.06, 0.06)
	bar:SetMinMaxValues(0, 1)
	local ground = bar:CreateTexture(nil, "BACKGROUND")
	ground:SetTexture(SUIC.FLAT)
	ground:SetVertexColor(0.16, 0.01, 0.01, 0.9)
	ground:SetAllPoints(bar)
	-- The black line round it; gold for the target.
	local edge = CreateFrame("Frame", nil, bar)
	edge:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
	edge:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
	edge:SetBackdrop(LINE)
	edge:SetBackdropBorderColor(0, 0, 0, 1)
	edge:SetFrameLevel(bar:GetFrameLevel() + 1)
	entry.bar, entry.edge = bar, edge
	entry:Hide()
	entries[index] = entry
end

-- A guardian asleep in its lair, unhurt, is no fight yet.
local function Wanted(unit, db)
	if unit.kind == "final" or unit.kind == "boss" then
		return true
	elseif unit.kind == "guardian" then
		return db.bossGuardians and (unit.state == 1 or (tonumber(unit.hp) or 0) < (tonumber(unit.hpm) or 0))
	end
	return db.bossElites and unit.kind == "elite"
end

local function Picked(db)
	local picked = {}
	local units = AZS_UNITS or {}
	for index = 1, table.getn(units) do
		local unit = units[index]
		if (tonumber(unit.hpm) or 0) > 0 and Wanted(unit, db) then
			table.insert(picked, unit)
		end
	end
	table.sort(picked, function(a, b)
		local oa, ob = ORDER[a.kind] or 5, ORDER[b.kind] or 5
		if oa ~= ob then
			return oa < ob
		end
		return (tonumber(a.id) or 0) < (tonumber(b.id) or 0)
	end)
	return picked
end

local function Fill(entry, unit, target)
	entry.unit = unit
	entry.bar:SetValue((tonumber(unit.hp) or 0) / tonumber(unit.hpm))
	entry.name:SetText(unit.name or "?")
	local color = NAME_COLORS[unit.kind] or NAME_COLORS.elite
	if unit.kind ~= "guardian" and unit.state == 1 then
		color = { 1, 0.55, 0.15 }
	end
	entry.name:SetTextColor(color[1], color[2], color[3])
	if target and target == unit.name then
		entry.edge:SetBackdropBorderColor(1, 0.82, 0, 1)
	else
		entry.edge:SetBackdropBorderColor(0, 0, 0, 1)
	end
	entry:Show()
end

local function Draw()
	local db = SUIC.DB()
	local picked = SUIC.InRun() and Picked(db) or {}
	local others = tonumber(db.bossMost) or 4
	local target = UnitExists("target") and UnitName("target")
	local shown, extra = 0, 0
	for index = 1, table.getn(picked) do
		local unit = picked[index]
		local boss = unit.kind == "final" or unit.kind == "boss"
		if not boss then
			extra = extra + 1
		end
		if shown < MOST and (boss or extra <= others) then
			shown = shown + 1
			Fill(entries[shown], unit, target)
		end
	end
	for index = shown + 1, MOST do
		entries[index].unit = nil
		entries[index]:Hide()
	end
	holder:SetHeight(math.max(1, shown) * STEP)
end

local elapsed = 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.2 then
		return
	end
	elapsed = 0
	Draw()
end)
ticker:Hide()

function SUIC.RefreshBossBars()
	local wanted = SUIC.DB().bossBars
	SUIC.SetGameShown("bosses", not wanted)
	if wanted then
		holder:Show()
		ticker:Show()
		Draw()
	else
		holder:Hide()
		ticker:Hide()
	end
end

SUIC.OnStart(function()
	SUIC.AddPiece("bosses", "Boss bars", holder, Home)
	SUIC.RefreshBossBars()
end)
