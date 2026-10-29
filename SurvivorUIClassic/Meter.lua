-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the damage meter, at the bottom of the right column. A
-- panel of bars, the most first: the spell's icon, its place and name, its
-- damage, its damage a second and its share. Its title picks the page:
-- Damage Done, Healing, the last boss fight's damage, or the party's heroes.
-- Hover a line for its numbers. It grows with its lines, up to the most set.
--
-- It stands in for the game's meter, which is put away while it is on and
-- given back as the game closes. From the game's addon API (AZS_GetMeter,
-- AZS_GetHealing, AZS_GetBossMeter, AZS_GetPartyMeter).

local W = SUIC.WIDTH
local PAD = SUIC.PAD
local LINE = 14                 -- a bar's height
local STEP = 17                 -- a bar and the room under it
local FONT = 10                 -- its texts' size untouched (the options' Font size), a thin black shadow
-- The numbers in three columns at the bars' right, each its text in its
-- middle, as the build list's: the total, the damage a second, the share.
local SHARE_COLUMN = 30
local RATE_COLUMN = 34
local AMOUNT_COLUMN = 38
local TOP = SUIC.TITLE + 4
local MOST = 15
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

local MODES = {
	{ key = "damage", name = "Damage Done", rate = "dps" },
	{ key = "dps", name = "DPS", rate = "dps" },
	{ key = "healing", name = "Healing", rate = "hps" },
	{ key = "bosses", name = "Boss Damage", rate = "dps" },
	{ key = "party", name = "Party", rate = "dps" },
}

-- One color per source, in the order they first show: twelve hues far from
-- each other, so neighbours never look alike (Survivor UI's meter's).
local PALETTE = {
	{ 0.93, 0.70, 0.15 }, { 0.85, 0.20, 0.25 }, { 0.25, 0.45, 0.95 }, { 0.30, 0.75, 0.30 },
	{ 0.65, 0.35, 0.90 }, { 0.95, 0.50, 0.10 }, { 0.15, 0.70, 0.70 }, { 0.95, 0.40, 0.70 },
	{ 0.65, 0.85, 0.20 }, { 0.60, 0.40, 0.25 }, { 0.45, 0.75, 1.00 }, { 0.55, 0.55, 0.70 },
}

local panel = SUIC.Window("SUICMeter", "Damage Done")

-- The title opens the pages' menu; a small arrow says so.
local title = CreateFrame("Button", nil, panel)
title:SetHeight(16)
title:SetWidth(130)
title:SetPoint("TOPLEFT", panel, "TOPLEFT", SUIC.PAD - 2, -4)
local arrow = title:CreateTexture(nil, "OVERLAY")
arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
arrow:SetWidth(14)
arrow:SetHeight(14)
arrow:SetPoint("LEFT", panel.title, "RIGHT", 1, 0)

-- The small lines folded into one, Others, at the bottom: the button beside
-- the title, a minus while they fold (the options' Damage meter tab, the share
-- under which a line folds).
local fold = CreateFrame("Button", nil, panel)
fold:SetWidth(14)
fold:SetHeight(14)
fold:SetPoint("LEFT", arrow, "RIGHT", 2, 0)
fold:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_TOP")
	GameTooltip:SetText("Others")
	GameTooltip:AddLine("The lines under "..(tonumber(SUIC.DB().meterFoldShare) or 10).."% of the total, folded into one.", 1, 1, 1, 1)
	GameTooltip:AddLine(SUIC.DB().meterFold and "On: click to show them all." or "Off: click to fold them.", 0.7, 0.7, 0.7)
	GameTooltip:Show()
end)
fold:SetScript("OnLeave", function() GameTooltip:Hide() end)
local function PaintFold()
	if SUIC.DB().meterFold then
		fold:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
		fold:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-Down")
	else
		fold:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
		fold:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Down")
	end
	fold:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
end
PaintFold()

------------------------------------------------------------------------------
-- Icons and colors.

-- A source's icon: Icons.lua's search (a pet's, a weapon's, a build spell's
-- button, a talent's, an item's).
local IconOf = SUIC.IconOf

local colors, given = {}, 0
local function ColorOf(name)
	if not colors[name] then
		given = given + 1
		colors[name] = PALETTE[math.mod(given - 1, table.getn(PALETTE)) + 1]
	end
	return colors[name]
end

local function ClassColor(class)
	local color = RAID_CLASS_COLORS and class and RAID_CLASS_COLORS[string.upper(class)]
	if color then
		return { color.r, color.g, color.b }
	end
	return { 0.7, 0.7, 0.7 }
end

------------------------------------------------------------------------------
-- The lines.

local function LineEnter()
	local entry = this.entry
	if not entry then
		return
	end
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	if entry.folded then
		GameTooltip:SetText(entry.name)
		for index = 1, table.getn(entry.folded) do
			local each = entry.folded[index]
			GameTooltip:AddDoubleLine(each.name or "?", SUIC.Short(each.dmg).."  "
				..math.floor((tonumber(each.share) or 0) * 100 + 0.5).."%", 1, 1, 1, 0.8, 0.8, 0.8)
		end
		GameTooltip:Show()
		return
	end
	GameTooltip:SetText(entry.name or "?")
	GameTooltip:AddDoubleLine("Total", SUIC.Short(entry.dmg), 1, 0.82, 0, 1, 1, 1)
	GameTooltip:AddDoubleLine("Per second", SUIC.Short(entry.dps), 1, 0.82, 0, 1, 1, 1)
	GameTooltip:AddDoubleLine("Share", math.floor((tonumber(entry.share) or 0) * 100 + 0.5).."%", 1, 0.82, 0, 1, 1, 1)
	if entry.top and entry.top ~= "" then
		GameTooltip:AddDoubleLine("Best spell", entry.top, 1, 0.82, 0, 1, 1, 1)
	end
	GameTooltip:Show()
end

local lines = {}
for index = 1, MOST do
	local line = SUIC.RowBar(panel, W - 2 * PAD - LINE - 3, LINE)
	line:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + LINE + 3, -TOP - 1 - (index - 1) * STEP)
	line:EnableMouse(true)
	line:SetScript("OnEnter", LineEnter)
	line:SetScript("OnLeave", function() GameTooltip:Hide() end)
	line.icon = line:CreateTexture(nil, "ARTWORK")
	line.icon:SetWidth(LINE + 1)
	line.icon:SetHeight(LINE + 1)
	line.icon:SetPoint("RIGHT", line, "LEFT", -2, 0)
	line.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	local font = line.left:GetFont()
	line.left:SetFont(font, FONT)
	line.right:Hide()
	line.amount = line.over:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	line.amount:SetPoint("CENTER", line, "RIGHT", -SHARE_COLUMN - RATE_COLUMN - AMOUNT_COLUMN / 2, 0)
	line.rate = line.over:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	line.rate:SetPoint("CENTER", line, "RIGHT", -SHARE_COLUMN - RATE_COLUMN / 2, 0)
	line.rate:SetTextColor(0.75, 0.75, 0.75)
	line.share = line.over:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	line.share:SetPoint("CENTER", line, "RIGHT", -SHARE_COLUMN / 2, 0)
	local texts = { line.left, line.amount, line.rate, line.share }
	for each = 1, table.getn(texts) do
		texts[each]:SetFont(font, FONT)
		texts[each]:SetShadowColor(0, 0, 0, 1)
		texts[each]:SetShadowOffset(1, -1)
	end
	line.left:SetWidth(W - 2 * PAD - LINE - 8 - SHARE_COLUMN - RATE_COLUMN - AMOUNT_COLUMN)
	line.texts = texts
	line:Hide()
	lines[index] = line
end

-- The lines' texts at the size chosen (the options' Damage meter tab).
function SUIC.ApplyMeterFont()
	local size = tonumber(SUIC.DB().meterFont) or FONT
	for index = 1, MOST do
		local texts = lines[index].texts
		for each = 1, table.getn(texts) do
			local font = texts[each]:GetFont()
			texts[each]:SetFont(font, size)
		end
	end
end

local function Mode()
	local key = SUIC.DB().meterMode
	for index = 1, table.getn(MODES) do
		if MODES[index].key == key then
			return MODES[index]
		end
	end
	return MODES[1]
end

-- The DPS page (Survivor UI's): each spell's damage a second, on the same
-- clock as the run's, so the column adds up to it.
local function PerSecond(lines, total, rate)
	local per = (total or 0) > 0 and (rate or 0) / total or 0
	local shown = {}
	for index = 1, table.getn(lines or {}) do
		local line = lines[index]
		table.insert(shown, { name = line.name, dmg = (tonumber(line.dmg) or 0) * per, share = line.share,
			proc = line.proc, perSecond = true })
	end
	return shown, total, rate
end

-- The damage a second right now: the run's total as it climbs over the last
-- five seconds of the run's clock; nil before five seconds are seen.
local recent = {}
local function NowRate(total)
	local at = AZS_GetRunTime and AZS_GetRunTime() or 0
	local last = recent[table.getn(recent)]
	if last and (at < last.at or total < last.total) then
		recent = {}
		last = nil
	end
	if not last or at > last.at then
		table.insert(recent, { at = at, total = total })
	end
	while table.getn(recent) > 1 and recent[1].at < at - 5 do
		table.remove(recent, 1)
	end
	local span = at - recent[1].at
	if span < 1 then
		return nil
	end
	return (total - recent[1].total) / span
end

local function Data(mode)
	if mode.key == "dps" and AZS_GetMeter then
		return PerSecond(AZS_GetMeter())
	elseif mode.key == "healing" and AZS_GetHealing then
		return AZS_GetHealing()
	elseif mode.key == "bosses" and AZS_GetBossMeter then
		return AZS_GetBossMeter()
	elseif mode.key == "party" and AZS_GetPartyMeter then
		return AZS_GetPartyMeter()
	elseif AZS_GetMeter then
		return AZS_GetMeter()
	end
	return {}, 0, 0
end

-- A proc's tag, as Survivor UI's meter has them: a neck's own damage (the
-- jewelry codex's necks, or a class amulet, "Amulet of the Inferno:
-- Consecration"), a talent's (the game's talents), the rest a proc's (a
-- ring's, a trinket's).
local NECKS = {
	["Amulet of Vek'nilash"] = true, ["Amulet of the Darkmoon"] = true, ["Animated Chain Necklace"] = true,
	["Choker of Enlightenment"] = true, ["Choker of the Fire Lord"] = true, ["Jeklik's Opaline Talisman"] = true,
	["Malice Stone Pendant"] = true, ["Mark of Fordring"] = true, ["Medallion of Steadfast Might"] = true,
	["Onyxia Tooth Pendant"] = true, ["Pendant of the Fallen Dragon"] = true, ["Prestor's Talisman of Connivery"] = true,
	["Pristine Enchanted South Seas Kelp"] = true, ["Talvash's Enhancing Necklace"] = true, ["The Eye of Hakkar"] = true,
	["Woven Ivy Necklace"] = true,
}

local function Tag(entry)
	local name = entry.name or ""
	if tonumber(entry.proc) ~= 1 then
		return ""
	elseif NECKS[name] or string.find(name, ": ", 1, true) then
		return " |cff8a8a8a(neck)|r"
	elseif SUIC_TALENT_ICONS and SUIC_TALENT_ICONS[name] then
		return " |cff8a8a8a(talent)|r"
	end
	return " |cff8a8a8a(proc)|r"
end

local function Fill(line, entry, index, top, mode)
	line.entry = entry
	local color
	if entry.folded then
		color = { 0.5, 0.5, 0.5 }
		line.icon:SetTexture(IconOf(entry.folded[1].name))
		line.icon:Show()
	elseif mode.key == "party" then
		color = ClassColor(entry.class)
		line.icon:Hide()
	else
		color = ColorOf(entry.name or "?")
		line.icon:SetTexture(IconOf(entry.name))
		line.icon:Show()
	end
	line:SetStatusBarColor(color[1], color[2], color[3], 0.85)
	line:SetValue(top > 0 and (tonumber(entry.dmg) or 0) / top or 0)
	line.amount:SetText(SUIC.Short(entry.dmg))
	-- The DPS page's lines are a second's already: no second column there.
	if entry.perSecond or (entry.folded and entry.folded[1].perSecond) then
		line.rate:SetText("")
	else
		line.rate:SetText(SUIC.Short(entry.dps))
	end
	line.share:SetText(math.floor((tonumber(entry.share) or 0) * 100 + 0.5).."%")
	if entry.folded then
		line.left:SetText(entry.name)
	else
		line.left:SetText(index..". "..(entry.name or "?")..Tag(entry))
	end
	line:Show()
end

-- The pieces at the screen's bottom the column stays over: on a narrow screen
-- (4:3, 5:4) the action bar's right end, and the summons over it, reach under
-- the column.
local UNDER = { "MainMenuBar", "SUICSummons", "SUICTalentTimers", "SUICLevelUp" }

local function Floor()
	local floor = 8
	local left, right = panel:GetLeft(), panel:GetRight()
	local own = panel:GetEffectiveScale()
	for index = 1, table.getn(UNDER) do
		local frame = getglobal(UNDER[index])
		if left and frame and frame:IsVisible() and frame:GetLeft() then
			local ratio = frame:GetEffectiveScale() / own
			if frame:GetRight() * ratio > left and frame:GetLeft() * ratio < right then
				floor = math.max(floor, frame:GetTop() * ratio + 6)
			end
		end
	end
	return floor
end

-- In the column, the lines that fit above the screen's bottom edge (or above
-- the action bar, when it reaches under the column); moved, all it is set to.
local function Room()
	local top = panel:GetTop()
	if SUIC.DB().pos.meter or not top then
		return MOST
	end
	return math.max(1, math.floor((top - Floor() - TOP - 4) / STEP))
end

-- With the fold on, the lines under the share folded into one, Others, at
-- the bottom (the party's heroes stay each on their own); and past the lines
-- that fit, the rest folded there too.
local function Folded(data, mode, most)
	if not SUIC.DB().meterFold or mode.key == "party" then
		return data
	end
	local under = (tonumber(SUIC.DB().meterFoldShare) or 10) / 100
	local kept, others = {}, {}
	for index = 1, table.getn(data) do
		local entry = data[index]
		if (tonumber(entry.share) or 0) < under or table.getn(kept) >= most - 1 then
			table.insert(others, entry)
		else
			table.insert(kept, entry)
		end
	end
	if table.getn(others) < 2 then
		return data
	end
	local sum = { name = "Others ("..table.getn(others)..")", dmg = 0, dps = 0, share = 0, folded = others,
		perSecond = others[1].perSecond }
	for index = 1, table.getn(others) do
		sum.dmg = sum.dmg + (tonumber(others[index].dmg) or 0)
		sum.dps = sum.dps + (tonumber(others[index].dps) or 0)
		sum.share = sum.share + (tonumber(others[index].share) or 0)
	end
	table.insert(kept, sum)
	return kept
end

local function Draw()
	PaintFold()
	local mode = Mode()
	local data, sum, perSecond = Data(mode)
	data = data or {}
	panel.title:SetText(mode.name)
	title:SetWidth(panel.title:GetStringWidth() + 20)
	if mode.key == "dps" then
		-- Now (green above the average, orange under) and on average.
		local now = NowRate(sum or 0)
		local color = "ffffff"
		if now then
			color = now >= (perSecond or 0) and "73f280" or "ff9a4d"
		end
		panel.note:SetText("|cffffd100NOW|r |cff"..color..(now and SUIC.Short(now) or "...").."|r   |cffffd100AVG|r "..SUIC.Short(perSecond or 0))
	else
		panel.note:SetText(SUIC.Short(perSecond or 0).." "..mode.rate.."  |cffaaaaaa"..SUIC.Short(sum or 0).."|r")
	end
	local most = math.min(MOST, tonumber(SUIC.DB().meterLines) or SUIC.Default("meterLines"), Room())
	local top = data[1] and (tonumber(data[1].dmg) or 0) or 0
	data = Folded(data, mode, most)
	for index = 1, MOST do
		local entry = data[index]
		if entry and index <= most then
			Fill(lines[index], entry, index, top, mode)
		else
			lines[index].entry = nil
			lines[index]:Hide()
		end
	end
	-- As tall as its lines, filled or not.
	panel:SetHeight(TOP + most * STEP + 4)
end

------------------------------------------------------------------------------
-- The page, from the title's menu.

local menu = CreateFrame("Frame", "SUICMeterMenu", UIParent, "UIDropDownMenuTemplate")
local function PickMode(key)
	SUIC.DB().meterMode = key
	Draw()
end
local function MenuInit()
	for index = 1, table.getn(MODES) do
		local mode = MODES[index]
		UIDropDownMenu_AddButton({ text = mode.name, func = PickMode, arg1 = mode.key,
			checked = SUIC.DB().meterMode == mode.key })
	end
end
fold:SetScript("OnClick", function()
	SUIC.DB().meterFold = not SUIC.DB().meterFold
	PaintFold()
	Draw()
end)

title:SetScript("OnClick", function()
	UIDropDownMenu_Initialize(menu, MenuInit, "MENU")
	ToggleDropDownMenu(1, nil, menu, this, 0, 0)
end)

local elapsed = 0
panel:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.5 then
		return
	end
	elapsed = 0
	Draw()
end)

local function Refresh()
	local wanted = SUIC.DB().meter
	SUIC.SetGameShown("meter", not wanted)
	if wanted and SUIC.InRun() then
		if not panel:IsShown() then
			panel:Show()
			Draw()
		end
	else
		panel:Hide()
	end
end
SUIC.RefreshMeter = function()
	Refresh()
	SUIC.SeatColumn()
end

local watch = CreateFrame("Frame")
local ticker = 0
watch:SetScript("OnUpdate", function()
	ticker = ticker + arg1
	if ticker < 0.5 then
		return
	end
	ticker = 0
	Refresh()
end)
watch:Hide()

SUIC.OnStart(function()
	SUIC.ColumnHome("meter")(panel)
	SUIC.AddPiece("meter", "Damage meter", panel, SUIC.ColumnHome("meter"))
	SUIC.ApplyMeterFont()
	SUIC.OverCards(panel)
	watch:Show()
	Refresh()
end)
