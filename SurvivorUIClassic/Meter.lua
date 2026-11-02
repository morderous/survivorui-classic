-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the damage meter, at the bottom of the right column. A
-- panel of bars, the most first: the spell's icon, its place and name, then
-- the page's number and the share. Its title picks the page: Damage Done, DPS,
-- Healing, the last boss fight's damage, or the party's heroes; those last
-- three with the damage or healing a second as well.
-- Hover a line for its numbers. It stands as tall as the lines set; those that
-- do not fit roll by the wheel or the scroll bar at its right.
-- The arrow beside the title, Reset, starts Damage Done and DPS over from
-- that moment; a new run starts them over by itself.
--
-- It stands in for the game's meter, which is put away while it is on and
-- given back as the game closes. From the game's addon API (AZS_GetMeter,
-- AZS_GetHealing, AZS_GetBossMeter, AZS_GetPartyMeter).

local W = SUIC.WIDTH
local PAD = SUIC.PAD
local LINE = 14                 -- a bar's height
local STEP = 17                 -- a bar and the room under it
local FONT = 10                 -- its texts' size (the options' Font size)
-- White in Barlow, outlined, over the bars' colors; a name in letters it lacks
-- in the game's own font. Barlow Condensed reads small: two points up.
local BARLOW = "Interface\\AddOns\\SurvivorUIClassic\\Fonts\\BarlowCondensed-SemiBold.ttf"
local BARLOW_BUMP = 2
-- The numbers in columns at the bars' right, each its text in its middle, as
-- the build list's: the page's number, the damage a second where it has one,
-- the share.
local SHARE_COLUMN = 30
local RATE_COLUMN = 34
local AMOUNT_COLUMN = 38
local TOP = SUIC.TITLE + 4
local MOST = 15
-- The scroll bar, in line with the title's rule; the lines give it this much
-- of their width while it shows.
local ROLL_WIDTH, ROLL_ROOM = 7, 7
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

local MODES = {
	{ key = "damage", name = "Damage Done", rate = "dps" },
	{ key = "dps", name = "DPS", rate = "dps" },
	{ key = "healing", name = "Healing", rate = "hps", three = true },
	{ key = "bosses", name = "Boss Damage", rate = "dps", three = true },
	{ key = "party", name = "Party", rate = "dps", three = true },
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

-- Reset, beside the fold button: the character pane's turning arrow, cut to
-- its framed square to stand as tall as the + beside it. On the Damage Done
-- and DPS pages; the others are the game's as they come.
local reset = CreateFrame("Button", "SUICMeterReset", panel)
reset:SetWidth(14)
reset:SetHeight(14)
reset:SetPoint("LEFT", fold, "RIGHT", 2, 0)
reset:SetNormalTexture("Interface\\Buttons\\UI-RotationLeft-Button-Up")
reset:SetPushedTexture("Interface\\Buttons\\UI-RotationLeft-Button-Down")
reset:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
reset:GetNormalTexture():SetTexCoord(0.09375, 0.90625, 0.09375, 0.875)
reset:GetPushedTexture():SetTexCoord(0.09375, 0.90625, 0.09375, 0.875)
reset:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_TOP")
	GameTooltip:SetText("Reset")
	GameTooltip:AddLine("Damage Done and DPS count from now on.", 1, 1, 1, 1)
	GameTooltip:AddLine("A new run starts them over by itself.", 0.7, 0.7, 0.7, 1)
	GameTooltip:Show()
end)
reset:SetScript("OnLeave", function() GameTooltip:Hide() end)

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

-- For the combat numbers: a source in the color its line has here.
SUIC.MeterColor = ColorOf

local function ClassColor(class)
	local r, g, b = SUIC.ClassColor(class)
	if r then
		return { r, g, b }
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
	line.right:Hide()
	line.gameFont = line.left:GetFont()
	line.amount = line.over:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	line.rate = line.over:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	line.rate:SetPoint("CENTER", line, "RIGHT", -SHARE_COLUMN - RATE_COLUMN / 2, 0)
	line.share = line.over:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	line.share:SetPoint("CENTER", line, "RIGHT", -SHARE_COLUMN / 2, 0)
	line.share:SetTextColor(1, 0.9, 0.3)
	line.texts = { line.left, line.amount, line.rate, line.share }
	line:Hide()
	lines[index] = line
end

-- The lines' texts at the size chosen (the options' Damage meter tab).
function SUIC.ApplyMeterFont()
	local size = (tonumber(SUIC.DB().meterFont) or FONT) + BARLOW_BUMP
	for index = 1, MOST do
		local texts = lines[index].texts
		for each = 1, table.getn(texts) do
			texts[each]:SetFont(BARLOW, size, "OUTLINE")
			texts[each]:SetShadowOffset(0, 0)
		end
		lines[index].said = nil
	end
end

-- The columns of a page: the second only where it has one. The name has the
-- rest, on one line: a text given a width would break in two. With the scroll
-- bar there, the lines leave it room.
local arranged, arrangedRolling
local function Arrange(mode, rolling)
	if arranged == mode and arrangedRolling == rolling then
		return
	end
	arranged, arrangedRolling = mode, rolling
	local columns = SHARE_COLUMN + AMOUNT_COLUMN + (mode.three and RATE_COLUMN or 0)
	local room = rolling and ROLL_ROOM or 0
	for index = 1, MOST do
		local line = lines[index]
		line:SetWidth(W - 2 * PAD - LINE - 3 - room)
		line.amount:ClearAllPoints()
		line.amount:SetPoint("CENTER", line, "RIGHT", AMOUNT_COLUMN / 2 - columns, 0)
		line.room = W - 2 * PAD - LINE - 8 - columns - room
		line.said = nil
		if mode.three then
			line.rate:Show()
		else
			line.rate:Hide()
		end
	end
end

-- The name on one line, cut short with dots to its room. The tag goes first.
local function SayName(line, name, tag)
	local text = name..tag
	if line.said == text then
		return
	end
	line.said = text
	local size = (tonumber(SUIC.DB().meterFont) or FONT) + BARLOW_BUMP
	if string.find(text, "[\128-\255]") then
		line.left:SetFont(line.gameFont, size - BARLOW_BUMP, "OUTLINE")
	else
		line.left:SetFont(BARLOW, size, "OUTLINE")
	end
	line.left:SetText(text)
	if line.left:GetStringWidth() <= line.room then
		return
	end
	local kept = string.len(name)
	while kept > 1 do
		kept = kept - 1
		line.left:SetText(string.sub(name, 1, kept).."...")
		if line.left:GetStringWidth() <= line.room then
			return
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

-- Reset: the game's numbers cover the whole run, so the meter keeps what each
-- spell stood at when Reset was pressed, and shows what came after (Survivor
-- UI's). Kept with the run it was pressed in.
local base = nil                -- { run = AZS_ZONE_UPDATED, at = run second, sources = { [name] = damage } }

local function TakeBase()
	local data = AZS_GetMeter and AZS_GetMeter() or {}
	base = { run = AZS_ZONE_UPDATED, at = AZS_GetRunTime and AZS_GetRunTime() or 0, sources = {} }
	for index = 1, table.getn(data) do
		base.sources[data[index].name or "?"] = tonumber(data[index].dmg) or 0
	end
end

-- The game's lines, or what came after Reset: each spell's damage less what
-- it had then, the most first, its share and damage a second from there.
local function SinceReset()
	local data, total, rate = AZS_GetMeter()
	if base and base.run ~= AZS_ZONE_UPDATED then
		base = nil
	end
	if not base then
		return data, total, rate
	end
	local span = (AZS_GetRunTime and AZS_GetRunTime() or 0) - base.at
	local shown, sum = {}, 0
	for index = 1, table.getn(data or {}) do
		local entry = data[index]
		local dmg = (tonumber(entry.dmg) or 0) - (base.sources[entry.name or "?"] or 0)
		if dmg > 0 then
			table.insert(shown, { name = entry.name, dmg = dmg, dps = span > 0 and dmg / span or 0, proc = entry.proc })
			sum = sum + dmg
		end
	end
	table.sort(shown, function(a, b) return a.dmg > b.dmg end)
	for index = 1, table.getn(shown) do
		shown[index].share = shown[index].dmg / sum
	end
	return shown, sum, span > 0 and sum / span or 0
end

reset:SetScript("OnClick", function()
	TakeBase()
end)

local function Data(mode)
	if mode.key == "dps" and AZS_GetMeter then
		return PerSecond(SinceReset())
	elseif mode.key == "healing" and AZS_GetHealing then
		return AZS_GetHealing()
	elseif mode.key == "bosses" and AZS_GetBossMeter then
		return AZS_GetBossMeter()
	elseif mode.key == "party" and AZS_GetPartyMeter then
		return AZS_GetPartyMeter()
	elseif AZS_GetMeter then
		return SinceReset()
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
		return " |cffd0d0d0(neck)|r"
	elseif (SUIC_TALENT_ICONS and SUIC_TALENT_ICONS[name]) or SUIC.MeterTalent(name) then
		return " |cffd0d0d0(talent)|r"
	end
	return " |cffd0d0d0(proc)|r"
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
	line.rate:SetText(SUIC.Short(entry.dps))
	line.share:SetText(math.floor((tonumber(entry.share) or 0) * 100 + 0.5).."%")
	if entry.folded then
		SayName(line, entry.name, "")
	else
		SayName(line, index..". "..(entry.name or "?"), Tag(entry))
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
-- the bottom (the party's heroes stay each on their own).
local function Folded(data, mode)
	if not SUIC.DB().meterFold or mode.key == "party" then
		return data
	end
	local under = (tonumber(SUIC.DB().meterFoldShare) or 10) / 100
	local kept, others = {}, {}
	for index = 1, table.getn(data) do
		local entry = data[index]
		if (tonumber(entry.share) or 0) < under then
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

-- The scroll bar: there while the lines do not all fit, the thumb as long as
-- the share of them that shows.
local roll = CreateFrame("Slider", nil, panel)
roll:SetOrientation("VERTICAL")
roll:SetWidth(ROLL_WIDTH)
roll:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -TOP - 1)
roll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 6)
roll:SetFrameLevel(panel:GetFrameLevel() + 8)
roll:SetMinMaxValues(0, 1)
roll:SetValueStep(1)
roll:EnableMouse(true)
roll:EnableMouseWheel(true)
local track = roll:CreateTexture(nil, "BACKGROUND")
track:SetTexture(SUIC.FLAT)
track:SetVertexColor(0, 0, 0, 0.5)
track:SetAllPoints(roll)
local thumb = roll:CreateTexture(nil, "OVERLAY")
thumb:SetTexture(SUIC.FLAT)
thumb:SetVertexColor(0.55, 0.55, 0.55, 1)
thumb:SetWidth(ROLL_WIDTH - 2)
thumb:SetHeight(16)
roll:SetThumbTexture(thumb)
roll:SetScript("OnEnter", function() thumb:SetVertexColor(0.9, 0.82, 0.5, 1) end)
roll:SetScript("OnLeave", function() thumb:SetVertexColor(0.55, 0.55, 0.55, 1) end)
roll:Hide()

local function ShowRoll(skip, most, shown)
	if most == 0 then
		roll:Hide()
		return
	end
	roll.quiet = true
	roll:SetMinMaxValues(0, most)
	roll:SetValue(skip)
	roll.quiet = nil
	thumb:SetHeight(math.max(14, math.floor(shown * STEP * shown / (shown + most))))
	roll:Show()
end

local function Draw()
	PaintFold()
	local mode = Mode()
	if mode.key == "damage" or mode.key == "dps" then
		reset:Show()
	else
		reset:Hide()
	end
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
	elseif mode.key == "damage" then
		-- The total alone: what the lines under it add up to.
		panel.note:SetText(SUIC.Short(sum or 0))
	else
		panel.note:SetText(SUIC.Short(perSecond or 0).." "..mode.rate.."  |cffaaaaaa"..SUIC.Short(sum or 0).."|r")
	end
	local most = math.min(MOST, tonumber(SUIC.DB().meterLines) or SUIC.Default("meterLines"), Room())
	local top = data[1] and (tonumber(data[1].dmg) or 0) or 0
	data = Folded(data, mode)
	-- Rolled down, the first lines out of sight and as many more in at the
	-- bottom, never past the last; the bars keep the top line's measure.
	panel.most = math.max(0, table.getn(data) - most)
	local skip = math.min(panel.scrolled or 0, panel.most)
	Arrange(mode, panel.most > 0)
	ShowRoll(skip, panel.most, most)
	for index = 1, MOST do
		local entry = data[index + skip]
		if entry and index <= most then
			Fill(lines[index], entry, index + skip, top, mode)
		else
			lines[index].entry = nil
			lines[index]:Hide()
		end
	end
	-- As tall as its lines, filled or not.
	panel:SetHeight(TOP + most * STEP + 4)
end

-- The lines set (the options' Damage meter tab): moved, its title stays where
-- it is and the bottom edge goes.
function SUIC.SetMeterLines(value)
	local db = SUIC.DB()
	local old = tonumber(db.meterLines) or SUIC.Default("meterLines")
	db.meterLines = value
	SUIC.KeepTop("meter", (value - old) * STEP)
	Draw()
end

-- The line under the mouse now holds another source: its numbers closed, open
-- again on the next line the mouse goes to.
local function Roll(to)
	panel.scrolled = math.max(0, math.min(panel.most or 0, to))
	Draw()
	GameTooltip:Hide()
end

local function Wheel()
	Roll(math.min(panel.scrolled or 0, panel.most or 0) - (arg1 or 0))
end

roll:SetScript("OnValueChanged", function()
	if not this.quiet then
		Roll(math.floor(this:GetValue() + 0.5))
	end
end)
roll:SetScript("OnMouseWheel", Wheel)
panel:EnableMouseWheel(true)
panel:SetScript("OnMouseWheel", Wheel)
for index = 1, MOST do
	lines[index]:EnableMouseWheel(true)
	lines[index]:SetScript("OnMouseWheel", Wheel)
end

------------------------------------------------------------------------------
-- The page, from the title's menu.

local menu = CreateFrame("Frame", "SUICMeterMenu", UIParent, "UIDropDownMenuTemplate")
local function PickMode(key)
	SUIC.DB().meterMode = key
	panel.scrolled = 0
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
