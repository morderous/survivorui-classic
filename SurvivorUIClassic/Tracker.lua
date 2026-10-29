-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the run tracker, after a Mythic+ timer, at the top of
-- the right column, a panel as the others.
--
-- Its title the zone, its Heroic level or Endless beside it. The hero's level
-- and the lives left; the time gone big in the middle against the second the
-- final boss comes; the run's bar, the unit frames' own in the tooltip's thin
-- border, with a skull for every boss. Then the kills and the elites slain;
-- the objectives, as a quest log's: each boss with a check and the second it
-- fell, an orange dot and its health while it is up (click to target it), a
-- dot and "in 1:23" for the next, a ring and its second for the rest; in
-- endless mode, the run's bar counts down to the next boss ("Next boss 4:50"
-- in it) and the list is the bosses slain alone; the guardians,
-- in red when all are slain, green while some hold their lairs, orange while
-- one fights, and under it each lair in the middle, in order: Up while its
-- guardian holds it, its health while it fights, the seconds until it fills
-- again once slain (hover for every lair); and, in the middle, the gold against the next cache's price. What is
-- done turns green.
--
-- It stands in for the game's clock and its kills and gold line, which are
-- put away while it is on. From the game's addon API (AZS_RUN, AZS_ZONE,
-- AZS_SCHEDULE, AZS_LAIRS); out of a run it hides.

local W = SUIC.WIDTH
local PAD = SUIC.PAD
local TOP = SUIC.TITLE + 4      -- the level's line
local LIST = TOP + 52           -- under the time and the run's bar
local ROW = 13
local INDENT = PAD + 14         -- the objectives' text, past their marks
local HEROIC = { "I", "II", "III", "IV", "V" }
local GREEN = { 0.3, 0.95, 0.3 }
local COLORS = {
	dead = GREEN,
	up = { 1, 0.5, 0.15 },
	next = { 1, 1, 1 },
	due = { 0.62, 0.62, 0.62 },
}
local WHITE = { 1, 1, 1 }

local frame = SUIC.Window("SUICTracker", "")

local level = SUIC.Text(frame, "GameFontNormalSmall")
level:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 2, -TOP)
local lives = SUIC.Text(frame, "GameFontHighlightSmall")
lives:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD - 2, -TOP)
local clock = SUIC.Text(frame, "GameFontHighlightLarge", 20)
local total = SUIC.Text(frame, "GameFontDisable", 11)
total:SetPoint("BOTTOMLEFT", clock, "BOTTOMRIGHT", 3, 2)

local BAR_WIDTH = W - 2 * PAD - 6
local timebar = SUIC.RowBar(frame, BAR_WIDTH, 9, true, SUIC.STOCK_BAR)
timebar:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 3, -TOP - 34)
timebar:SetStatusBarColor(0.2, 0.5, 1)

local skulls = {}
local function Skull(index)
	if not skulls[index] then
		local skull = timebar.over:CreateTexture(nil, "OVERLAY")
		skull:SetTexture(SUIC.SKULL)
		skulls[index] = skull
	end
	return skulls[index]
end

------------------------------------------------------------------------------
-- The objectives: rows made as they are needed, cells for the numbers.

local function LairsTip(owner)
	GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
	GameTooltip:SetText("Lairs")
	local lairs = AZS_GetLairs and AZS_GetLairs() or AZS_LAIRS or {}
	for index = 1, table.getn(lairs) do
		local lair = lairs[index]
		local state = lair.state or "?"
		local r, g, b = 0.6, 0.6, 0.6
		if state == "awake" then
			r, g, b = 1, 0.5, 0.15
		elseif state == "asleep" then
			r, g, b = 1, 1, 1
		end
		local name = (lair.name and lair.name ~= "") and lair.name or ("Lair "..(lair.index or index))
		GameTooltip:AddDoubleLine(name, state, 1, 0.82, 0, r, g, b)
	end
	GameTooltip:Show()
end

local function SpotEnter()
	if this.lairs then
		LairsTip(this)
	elseif this.target then
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetText(this.target)
		GameTooltip:AddLine("Click to target it.", 1, 1, 1)
		GameTooltip:Show()
	elseif this.tip then
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetText(this.tip)
		GameTooltip:Show()
	end
end

local function SpotClick()
	if this.target and TargetByName then
		TargetByName(this.target, true)
	end
end

local function Spot(width)
	local spot = CreateFrame("Button", nil, frame)
	spot:SetWidth(width)
	spot:SetHeight(ROW)
	spot:RegisterForClicks("LeftButtonUp")
	spot:SetScript("OnClick", SpotClick)
	spot:SetScript("OnEnter", SpotEnter)
	spot:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return spot
end

local function At(spot, y, x)
	spot:ClearAllPoints()
	spot:SetPoint("TOPLEFT", frame, "TOPLEFT", x or PAD, -y)
	spot.target, spot.lairs, spot.tip = nil, nil, nil
	spot:Show()
	return spot
end

local rows = {}
local function Line(index, y, mark, name, value, color)
	local row = rows[index]
	if not row then
		row = Spot(W - 2 * PAD)
		row.mark = SUIC.Mark(row)
		row.mark:SetPoint("LEFT", row, "LEFT", 1, 0)
		row.name = SUIC.Text(row, "GameFontHighlightSmall")
		row.name:SetPoint("LEFT", row, "LEFT", 14, 0)
		row.name:SetJustifyH("LEFT")
		row.name:SetHeight(ROW + 2)
		row.value = SUIC.Text(row, "GameFontHighlightSmall")
		row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
		rows[index] = row
	end
	At(row, y)
	SUIC.SetMark(row.mark, mark)
	row.value:SetText(value)
	row.name:SetWidth(math.max(40, W - 2 * PAD - 20 - row.value:GetStringWidth()))
	row.name:SetText(name)
	row.name:SetTextColor(color[1], color[2], color[3])
	row.value:SetTextColor(color[1], color[2], color[3])
	return row
end

-- Cells side by side: a gold label, its number at the right; the kills'
-- narrow, the slain's wide.
local KILLS = 56
local cells = {}
local function Cell(index, y, x, width, label, value)
	local cell = cells[index]
	if not cell then
		cell = Spot(width)
		cell.label = SUIC.Text(cell, "GameFontNormalSmall")
		cell.label:SetPoint("LEFT", cell, "LEFT", 0, 0)
		cell.value = SUIC.Text(cell, "GameFontHighlightSmall")
		cell.value:SetPoint("RIGHT", cell, "RIGHT", 0, 0)
		cells[index] = cell
	end
	cell:SetWidth(width)
	At(cell, y, x)
	cell.label:SetText(label)
	cell.value:SetText(value)
	return cell
end

-- The empty lairs' seconds to fill again, under the guardians' line.
local refill = SUIC.Text(frame, "GameFontHighlightSmall", 9)
refill:SetJustifyH("CENTER")
refill:SetWidth(W - 2 * PAD)
refill:Hide()

-- The gold against the next cache, in the middle.
local purse = Spot(W - 2 * PAD)
purse.text = SUIC.Text(purse, "GameFontHighlightSmall")
purse.text:SetPoint("CENTER", purse, "CENTER", 0, 0)
purse:Hide()

------------------------------------------------------------------------------
-- The second each boss fell, as seen: up, then dead. A new run starts over.

local seenUp, fellAt = {}, {}
local runSeen

local function Num(value)
	return tonumber(value) or 0
end

local function NewRun()
	if AZS_ZONE_UPDATED ~= runSeen then
		runSeen = AZS_ZONE_UPDATED
		seenUp, fellAt = {}, {}
	end
end

local function Health(name)
	local bosses = AZS_GetBosses and AZS_GetBosses() or {}
	for index = 1, table.getn(bosses) do
		local boss = bosses[index]
		if boss.name == name and Num(boss.hpm) > 0 then
			return math.floor(Num(boss.hp) / Num(boss.hpm) * 100 + 0.5).."%"
		end
	end
	return ""
end

-- In endless mode the run's bar, taller, counts down to the next boss: its
-- fill the share of the wait gone (the wait's length the countdown's height
-- when it began), "Next boss 4:50" in it, or the boss's name while one is up.
local wait = 0
local function EndlessBar(run)
	timebar:SetHeight(14)
	timebar:SetStatusBarColor(0.6, 0.35, 0.8)
	local bosses = AZS_GetBosses and AZS_GetBosses() or {}
	if table.getn(bosses) > 0 then
		timebar:SetValue(1)
		timebar.middle:SetText("|cffffa040"..(bosses[1].name or "?").." is here|r")
		wait = 0
		return
	end
	local left = Num(run.nb)
	if left < 0 or not run.nb then
		timebar:SetValue(1)
		timebar.middle:SetText("")
		return
	end
	if AZS_RUN_UPDATED and AZS_GetPhase and AZS_GetPhase() == "playing" then
		left = math.max(0, left - (GetTime() - AZS_RUN_UPDATED))
	end
	if left > wait then
		wait = left
	end
	timebar:SetValue(wait > 0 and (1 - left / wait) or 0)
	timebar.middle:SetText("Next boss  "..SUIC.Clock(left))
end

-- A Heroic run's affixes from III on, as the game names them (its 0.124:
-- AZS_ZONE.affixes, "sanguine,explosive"), in red at the level's right.
local function Affixes(info, heroic)
	if heroic < 3 or not info.affixes or info.affixes == "" then
		return ""
	end
	local names = {}
	for name in string.gfind(tostring(info.affixes), "[^,]+") do
		name = string.gsub(name, "^%s*(.-)%s*$", "%1")
		table.insert(names, string.upper(string.sub(name, 1, 1))..string.sub(name, 2))
	end
	return "|cffff6050"..table.concat(names, ", ").."|r"
end

local function DrawHead(run, info, now, length, endless)
	frame.title:SetText(info.zname or "")
	local heroic = Num(info.heroic)
	if endless then
		frame.note:SetText("|cffd080ffEndless|r")
	elseif heroic > 0 then
		frame.note:SetText("|cffff7a2eHeroic "..(HEROIC[heroic] or heroic).."|r")
	else
		frame.note:SetText("|cffaaaaaaNormal|r")
	end
	local lifeText = Num(run.lives) > 0 and ("  |cffd0d0d0Lives "..Num(run.lives).."|r") or ""
	level:SetText(run.lvl and ("Level "..run.lvl..lifeText) or "")
	lives:SetText(Affixes(info, heroic))
	clock:SetText(SUIC.Clock(now))
	if endless then
		clock:SetTextColor(0.82, 0.55, 1)
	else
		clock:SetTextColor(1, 1, 1)
	end
	if endless then
		total:SetText("")
		EndlessBar(run)
	elseif length <= 0 then
		total:SetText("")
		timebar:SetValue(1)
		timebar.middle:SetText("")
	else
		total:SetText("/ "..SUIC.Clock(length))
		timebar:SetHeight(9)
		timebar:SetValue(math.min(1, now / length))
		timebar:SetStatusBarColor(0.2, 0.5, 1)
		timebar.middle:SetText("")
	end
	-- The time and its total together in the middle.
	local wide = total:GetText() ~= "" and (total:GetStringWidth() + 3) or 0
	clock:ClearAllPoints()
	clock:SetPoint("TOP", frame, "TOP", -wide / 2, -TOP - 8)
end

-- The kills and the elites slain, side by side; the height they reach.
local function DrawCounts(run, y)
	local db = SUIC.DB()
	local count = 0
	local x = PAD + 2
	if db.trackerKills then
		count = count + 1
		Cell(count, y, x, KILLS, "Kills", Num(run.kills))
		x = x + KILLS + 10
	end
	if db.trackerElites then
		count = count + 1
		Cell(count, y, x, W - PAD - x, "Elites/Guardians Slain", Num(run.ek).." / "..Num(run.gk))
	end
	for index = count + 1, table.getn(cells) do
		cells[index]:Hide()
	end
	if count > 0 then
		return y + ROW + 3
	end
	return y
end

-- The bosses on the bar and in the list from y; the rows used.
local function DrawBosses(now, length, endless, y)
	local schedule = AZS_SCHEDULE or {}
	local count = table.getn(schedule)
	local listed = SUIC.DB().trackerBosses and not endless
	local used, nextFound = 0, false
	for index = 1, count do
		local boss = schedule[index]
		local state = boss.state or "due"
		local name = boss.name or "?"
		if state == "up" then
			seenUp[index] = true
		elseif state == "dead" and seenUp[index] and not fellAt[index] then
			fellAt[index] = now
		end
		local at = Num(boss.at)
		local kind = state
		if state == "due" and not nextFound and not endless then
			nextFound = true
			kind = "next"
		end
		local skull = Skull(index)
		if endless or length <= 0 then
			skull:Hide()
		else
			local size = Num(boss.final) == 1 and 15 or 12
			skull:SetWidth(size)
			skull:SetHeight(size)
			skull:ClearAllPoints()
			skull:SetPoint("CENTER", timebar, "LEFT", BAR_WIDTH * math.min(1, at / length), 0)
			local color = COLORS[kind] or COLORS.due
			skull:SetVertexColor(color[1], color[2], color[3])
			skull:Show()
		end
		if listed then
			used = used + 1
			local rowY = y + (used - 1) * ROW
			if kind == "dead" then
				Line(used, rowY, "done", name, SUIC.Clock(fellAt[index] or at), COLORS.dead)
			elseif kind == "up" then
				Line(used, rowY, "up", name, Health(name), COLORS.up).target = name
			elseif kind == "next" then
				Line(used, rowY, "dot", name, "in "..SUIC.Clock(at - now), COLORS.next)
			else
				Line(used, rowY, "ring", name, SUIC.Clock(at), COLORS.due)
			end
		end
	end
	for index = count + 1, table.getn(skulls) do
		skulls[index]:Hide()
	end
	return used
end

-- A guardian's health share by its id (AZS_GetGuardians), or nil.
local function GuardianShare(id)
	local guardians = AZS_GetGuardians and AZS_GetGuardians() or {}
	for index = 1, table.getn(guardians) do
		local guardian = guardians[index]
		if guardian.id == id and (tonumber(guardian.hpm) or 0) > 0 then
			return (tonumber(guardian.hp) or 0) / tonumber(guardian.hpm)
		end
	end
end

-- The lairs: how many hold a guardian, whether one fights, and each lair's
-- word in order: Up (held), its guardian's health (fighting), the seconds it
-- fills again in (slain: sent with the lairs, counted down since while the
-- run plays), "-" (empty, none yet or about to come).
local function Lairs()
	local lairs = AZS_GetLairs and AZS_GetLairs() or AZS_LAIRS or {}
	local since = 0
	if AZS_LAIRS_UPDATED and AZS_GetPhase and AZS_GetPhase() == "playing" then
		since = GetTime() - AZS_LAIRS_UPDATED
	end
	local held, awake, words = 0, false, {}
	for index = 1, table.getn(lairs) do
		local lair = lairs[index]
		if lair.state == "empty" then
			local left = (tonumber(lair.left) or -1) - since
			if left > 0 then
				table.insert(words, "|cffff6060"..SUIC.Clock(left).."|r")
			else
				table.insert(words, "|cff8a8a8a-|r")
			end
		elseif lair.state == "awake" then
			held = held + 1
			awake = true
			local share = GuardianShare(lair.id)
			table.insert(words, "|cffff8026"..(share and (math.floor(share * 100 + 0.5).."%") or "Fight").."|r")
		else
			held = held + 1
			table.insert(words, "|cff4cf24cUp|r")
		end
	end
	return table.getn(lairs), held, awake, words
end

local RED = { 1, 0.3, 0.3 }
local ORANGE = { 1, 0.5, 0.15 }

-- The rest under the bosses; the height they reach.
local function DrawRest(run, now, endless, used, y)
	local db = SUIC.DB()
	if endless then
		used = used + 1
		Line(used, y + (used - 1) * ROW, "done", "Bosses slain", Num(run.bk), GREEN)
	end
	local refills = false
	local all, held, awake, words = Lairs()
	if db.trackerGuardians and all > 0 then
		local color, mark = GREEN, "dot"
		if awake then
			color, mark = ORANGE, "up"
		elseif held == 0 then
			color, mark = RED, "ring"
		end
		used = used + 1
		local row = Line(used, y + (used - 1) * ROW, mark, "Guardians", held.." / "..all, color)
		row.mark:SetVertexColor(color[1], color[2], color[3])
		row.lairs = true
		if table.getn(words) > 0 then
			refill:ClearAllPoints()
			refill:SetPoint("TOP", frame, "TOPLEFT", W / 2, -(y + used * ROW))
			refill:SetText(table.concat(words, "  |cff606060|||r  "))
			refill:Show()
			refills = true
		end
	end
	if not refills then
		refill:Hide()
	end
	for index = used + 1, table.getn(rows) do
		rows[index]:Hide()
	end
	y = y + used * ROW + (refills and 11 or 0)
	if db.trackerGold then
		At(purse, y + 3)
		purse.text:SetText("|cffffd100Gold / Cache|r   "..Num(run.gold)
			..(run.chest and ("  |cffaaaaaa/ "..Num(run.chest).."|r") or ""))
		purse.tip = "Your gold, and what the next cache costs."
		y = y + ROW + 3
	else
		purse:Hide()
	end
	return y
end

local function Draw()
	NewRun()
	local run, info = AZS_RUN or {}, AZS_ZONE or {}
	local now = AZS_GetRunTime and AZS_GetRunTime() or Num(run.t)
	local length = Num(info.len)
	local endless = Num(run.endl) == 1
	DrawHead(run, info, now, length, endless)
	local y = DrawCounts(run, LIST + (endless and 5 or 0))
	local used = DrawBosses(now, length, endless, y)
	frame:SetHeight(DrawRest(run, now, endless, used, y) + 5)
end

local elapsed = 0
frame:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.1 then
		return
	end
	elapsed = 0
	Draw()
end)

-- Shown in a run, while it is wanted; the game's clock and its kills and gold
-- line away while it is.
local function Refresh()
	local wanted = SUIC.DB().tracker
	SUIC.SetGameShown("clock", not wanted)
	SUIC.SetGameShown("tally", not wanted)
	if wanted and SUIC.InRun() then
		if not frame:IsShown() then
			frame:Show()
			Draw()
		end
	else
		frame:Hide()
	end
end
SUIC.RefreshTracker = function()
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
	SUIC.ColumnHome("tracker")(frame)
	SUIC.AddPiece("tracker", "Run tracker", frame, SUIC.ColumnHome("tracker"))
	SUIC.OverCards(frame)
	watch:Show()
	Refresh()
end)
