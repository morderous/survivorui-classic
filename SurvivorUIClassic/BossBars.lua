-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the boss bars at the top of the screen in the middle,
-- of the plates' make (Lucas, 2026-11-03): the name over a rounded bar in its
-- kind's color, as the plates have it (the final boss orange, a boss purple,
-- a guardian blue, an elite green), edged in white, the health's share at its
-- right and the debuffs on the enemy inside it from the left. They move (Move
-- frames), and a click targets the enemy (the one targeted is edged in gold;
-- hover for its health in numbers). The bar under the mouse glows as a plate
-- does and lines its enemy's plate in white, to tell which one it is; a bar
-- glows too with the mouse on its enemy out in the world. Every boss alive,
-- the final boss first, then the lair guardians awake or hurt (named in blue)
-- and the elites (in gold), as chosen, four of them at most (the bosses
-- always); an enraged boss's name in orange.
--
-- They stand in for the game's boss bars, which are put away while these are
-- on and given back as the game closes. From the game's addon API (AZS_UNITS,
-- and AZS_GetDebuffs for a boss's or a guardian's debuffs; an elite's only
-- while it is your target).

local WIDTH = 278
local HEIGHT = 16
local NAME = 14                 -- the name's line, over the bar
local STEP = NAME + HEIGHT + 7  -- one boss and the room under it
local MOST = 12
local DEBUFF_SIZE = HEIGHT - 3
local DEBUFF_MOST = 10
local SHARE_ROOM = 34           -- the health's share, at the bar's right end
local ART = "Interface\\AddOns\\SurvivorUIClassic\\Art\\"
local ORDER = { final = 1, boss = 2, guardian = 3, elite = 4 }
local KIND_NAMES = { final = "Final boss", boss = "Boss", guardian = "Lair guardian", elite = "Elite" }
local NAME_COLORS = {
	final = { 1, 1, 1 },
	boss = { 1, 1, 1 },
	guardian = { 0.45, 0.8, 1 },
	elite = { 1, 0.82, 0 },
}
-- The plates' colors (Nameplates.lua).
local FILL_COLORS = {
	final = { 1.00, 0.50, 0.00 },
	boss = { 0.64, 0.21, 0.93 },
	guardian = { 0.00, 0.44, 0.87 },
	elite = { 0.12, 0.72, 0.12 },
}
local EDGES = { none = { 1, 1, 1 }, target = { 1, 0.82, 0 } }

local holder = CreateFrame("Frame", "SUICBossBars", UIParent)
holder:SetWidth(WIDTH)
holder:SetHeight(STEP)

local function Home(f)
	f:SetPoint("TOP", UIParent, "TOP", 0, -46)
end
Home(holder)

local hovered                   -- the bar under the mouse

local function Tint(strip, r, g, b)
	for index = 1, 3 do
		strip[index]:SetVertexColor(r, g, b, 1)
	end
end

local function Glow(entry, on)
	if on == entry.glowing then
		return
	end
	entry.glowing = on
	if on then
		SUIC.RoundLay(entry.glow, entry.bar, -HEIGHT / 2, WIDTH + HEIGHT, HEIGHT * 2, WIDTH + HEIGHT)
	else
		for index = 1, 3 do
			entry.glow[index]:Hide()
		end
	end
end

local function EntryEnter()
	local unit = this.unit
	if not unit then
		return
	end
	hovered = this
	Glow(this, true)
	SUIC.LightPlate(unit.name, unit.id)
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

local function EntryLeave()
	hovered = nil
	SUIC.LightPlate(nil)
	GameTooltip:Hide()
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
	entry:SetScript("OnLeave", EntryLeave)
	entry.name = SUIC.Text(entry, "GameFontNormal")
	entry.name:SetPoint("TOPLEFT", entry, "TOPLEFT", 4, 0)
	entry.kindName = SUIC.Text(entry, "GameFontNormalSmall")
	entry.kindName:SetPoint("LEFT", entry.name, "RIGHT", 5, 0)
	entry.kindName:SetTextColor(1, 0.55, 0.1)
	-- The bar: its line, its dark ground and its fill, of the plates' art;
	-- under it (on the entry) the glow, over it the share and the debuffs.
	local bar = CreateFrame("Frame", nil, entry)
	bar:SetWidth(WIDTH)
	bar:SetHeight(HEIGHT)
	bar:SetPoint("TOP", entry, "TOP", 0, -NAME - 1)
	bar:SetFrameLevel(entry:GetFrameLevel() + 1)
	entry.glow = SUIC.RoundStrip(entry, "BACKGROUND")
	for each = 1, 3 do
		entry.glow[each]:SetTexture(ART.."PlateGlow")
		entry.glow[each]:SetBlendMode("ADD")
		entry.glow[each]:SetVertexColor(1, 0.92, 0.70, 0.9)
		entry.glow[each]:Hide()
	end
	entry.line = SUIC.RoundStrip(bar, "BACKGROUND")
	entry.back = SUIC.RoundStrip(bar, "BORDER")
	entry.fill = SUIC.RoundStrip(bar, "ARTWORK")
	SUIC.RoundLay(entry.line, bar, -1, WIDTH + 2, HEIGHT + 2, WIDTH + 2)
	SUIC.RoundLay(entry.back, bar, 0, WIDTH, HEIGHT, WIDTH)
	Tint(entry.line, 1, 1, 1)
	Tint(entry.back, 0.06, 0.06, 0.06)
	local top = CreateFrame("Frame", nil, bar)
	top:SetAllPoints(bar)
	top:SetFrameLevel(bar:GetFrameLevel() + 2)
	entry.share = SUIC.Text(top, "GameFontHighlightSmall")
	entry.share:SetPoint("RIGHT", bar, "RIGHT", -6, 1)
	entry.bar, entry.top, entry.debuffs, entry.edge = bar, top, {}, "none"
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

-- The debuffs on the enemy: a boss's and a guardian's from the game, an
-- elite's while it is your target.
local function Debuffs(unit, target)
	if unit.kind ~= "elite" and AZS_GetDebuffs and unit.id then
		local ok, list = pcall(AZS_GetDebuffs, unit.id)
		if ok and type(list) == "table" then
			return list
		end
	end
	local list = {}
	if target and target == unit.name then
		for index = 1, DEBUFF_MOST do
			local texture, count = UnitDebuff("target", index)
			if not texture then
				break
			end
			list[index] = { icon = texture, stacks = count }
		end
	end
	return list
end

local function DebuffIcon(entry, index)
	local icon = entry.debuffs[index]
	if icon then
		return icon
	end
	icon = CreateFrame("Frame", nil, entry.top)
	icon:SetFrameLevel(entry.top:GetFrameLevel() + 1)
	icon:SetWidth(DEBUFF_SIZE)
	icon:SetHeight(DEBUFF_SIZE)
	icon:SetPoint("LEFT", entry.bar, "LEFT", 4 + (index - 1) * (DEBUFF_SIZE + 2), 0)
	icon.edge = icon:CreateTexture(nil, "BACKGROUND")
	icon.edge:SetTexture(SUIC.FLAT)
	icon.edge:SetVertexColor(0, 0, 0, 1)
	icon.edge:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
	icon.edge:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
	icon.art = icon:CreateTexture(nil, "ARTWORK")
	icon.art:SetAllPoints(icon)
	icon.art:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon.stacks = SUIC.Text(icon, "GameFontHighlightSmall")
	icon.stacks:SetFont(icon.stacks:GetFont() or STANDARD_TEXT_FONT, 9, "OUTLINE")
	icon.stacks:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -1)
	entry.debuffs[index] = icon
	return icon
end

local function FillDebuffs(entry, unit, target)
	local list = Debuffs(unit, target)
	local room = math.min(DEBUFF_MOST, math.floor((WIDTH - SHARE_ROOM - 4) / (DEBUFF_SIZE + 2)))
	local count = math.min(room, table.getn(list))
	for index = 1, count do
		local debuff = list[index]
		local icon = DebuffIcon(entry, index)
		icon.art:SetTexture(SUIC.DebuffArt(debuff.icon))
		local stacks = tonumber(debuff.stacks) or 0
		icon.stacks:SetText(stacks > 1 and stacks or "")
		icon:Show()
	end
	for index = count + 1, table.getn(entry.debuffs) do
		entry.debuffs[index]:Hide()
	end
end

local function Fill(entry, unit, target, mouse)
	entry.unit = unit
	local share = math.max(0, math.min(1, (tonumber(unit.hp) or 0) / tonumber(unit.hpm)))
	local across = math.floor(share * WIDTH * 2 + 0.5) / 2
	if across ~= entry.across then
		entry.across = across
		SUIC.RoundLay(entry.fill, entry.bar, 0, WIDTH, HEIGHT, across)
	end
	local percent = math.floor(share * 100 + 0.5)
	if percent == 0 and share > 0 then
		percent = 1
	end
	entry.share:SetText(percent.."%")
	if unit.kind ~= entry.kind then
		entry.kind = unit.kind
		local fill = FILL_COLORS[unit.kind] or FILL_COLORS.elite
		Tint(entry.fill, fill[1], fill[2], fill[3])
		entry.kindName:SetText(unit.kind == "final" and "Final boss" or "")
	end
	entry.name:SetText(unit.name or "?")
	local color = NAME_COLORS[unit.kind] or NAME_COLORS.elite
	if unit.kind ~= "guardian" and unit.state == 1 then
		color = { 1, 0.55, 0.15 }
	end
	entry.name:SetTextColor(color[1], color[2], color[3])
	if entry == hovered then
		SUIC.LightPlate(unit.name, unit.id)
	end
	Glow(entry, entry == hovered or (mouse and mouse == unit.name) or false)
	local edge = (target and target == unit.name) and "target" or "none"
	if edge ~= entry.edge then
		entry.edge = edge
		Tint(entry.line, EDGES[edge][1], EDGES[edge][2], EDGES[edge][3])
	end
	FillDebuffs(entry, unit, target)
	entry:Show()
end

local function Draw()
	local db = SUIC.DB()
	local picked = SUIC.InRun() and Picked(db) or {}
	local others = tonumber(db.bossMost) or 4
	local target = UnitExists("target") and UnitName("target")
	local mouse = not hovered and UnitExists("mouseover") and UnitName("mouseover")
	local shown, extra = 0, 0
	for index = 1, table.getn(picked) do
		local unit = picked[index]
		local boss = unit.kind == "final" or unit.kind == "boss"
		if not boss then
			extra = extra + 1
		end
		if shown < MOST and (boss or extra <= others) then
			shown = shown + 1
			Fill(entries[shown], unit, target, mouse)
		end
	end
	for index = shown + 1, MOST do
		if entries[index] == hovered then
			hovered = nil
			SUIC.LightPlate(nil)
		end
		entries[index].unit = nil
		entries[index]:Hide()
	end
	holder:SetHeight(math.max(1, shown) * STEP)
end

local elapsed = 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.1 then
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
