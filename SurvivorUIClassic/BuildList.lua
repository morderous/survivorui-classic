-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the build list, in the right column under the run
-- tracker. Its title the three numbers every spell grows by (Damage, Crit,
-- Crit Dmg, as the stats panel reads them) and the slots filled. The run's
-- six spell slots, filled or not, each spell with its icon, its name as the
-- game writes it, its biggest crit this run (Crits.lua), its cooldown and its
-- rank, the highest rank first; the racial apart at the bottom (it takes no
-- slot). The empty slots show, since how many are left matters at every card.
-- Hover a spell for its tooltip, its biggest crit for its crits and hits this
-- run.
--
-- From the game's addon API (AZS_SPELLS, your racial last): its spells sit on
-- the action bar in the list's order, the racial on button 12. In a run only.

local SLOTS = 6
local RACIAL_SLOT = 12
local W = SUIC.WIDTH
local PAD = SUIC.PAD
local ROW = 15
local TOP = SUIC.TITLE + 16
local EMPTY = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"
local RANK_COLUMN = 20
local CD_COLUMN = 34
local CRIT_COLUMN = 36
local NAME_ROOM = W - 2 * PAD - (ROW + 3) - RANK_COLUMN - CD_COLUMN - CRIT_COLUMN - 4

local panel = SUIC.Window("SUICBuildList", "Build")
panel:SetHeight(TOP + (SLOTS + 1) * ROW + 5 + 6)

-- The three numbers, a second line under the title, the rule under them.
local stats = SUIC.Text(panel, "GameFontHighlightSmall", 9)
stats:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -SUIC.TITLE + 2)
stats:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -SUIC.TITLE + 2)
stats:SetJustifyH("LEFT")
panel.rule:ClearAllPoints()
panel.rule:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -SUIC.TITLE - 12)
panel.rule:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -SUIC.TITLE - 12)

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

local function Pct(value)
	return math.floor(value * 100 + 0.5).."%"
end

local function SpellTip(row)
	if not row.slot then
		return
	end
	GameTooltip:SetOwner(row, "ANCHOR_LEFT")
	GameTooltip:SetAction(row.slot)
	GameTooltip:Show()
end

local function RowEnter()
	SpellTip(this)
end

-- The biggest crit's tooltip, as Survivor UI's Biggest Crits card: the head
-- lines in gold, the numbers under each in white, beside the panel on the
-- screen's roomier side. Read again while it is up; with nothing seen yet, the
-- spell's own.
local critHover

local function Head(label, value)
	GameTooltip:AddDoubleLine(label, value, 1, 0.82, 0, 1, 1, 1)
end

local function Line(label, value)
	GameTooltip:AddDoubleLine("   "..label, value, 0.75, 0.75, 0.75, 1, 1, 1)
end

local function CritCard(zone)
	local row = zone.row
	local one = row.key and SUIC.SpellRecord(row.key)
	if not one then
		SpellTip(row)
		return
	end
	GameTooltip:SetOwner(zone, "ANCHOR_NONE")
	GameTooltip:ClearAllPoints()
	if panel:GetCenter() < UIParent:GetCenter() then
		GameTooltip:SetPoint("TOPLEFT", panel, "TOPRIGHT", 6, 0)
	else
		GameTooltip:SetPoint("TOPRIGHT", panel, "TOPLEFT", -6, 0)
	end
	GameTooltip:SetText(row.spell or "?")
	Head("Critical strikes", one.crits)
	if one.crits > 0 then
		Line("Biggest", SUIC.Short(one.best))
		Line("Beaten last", SUIC.Clock((AZS_GetRunTime and AZS_GetRunTime() or 0) - one.bestAt).." ago")
		Line("Last", SUIC.Short(one.lastCrit))
		Line("Average", SUIC.Short(one.critSum / one.crits))
		Line("Smallest", SUIC.Short(one.least))
	end
	Head("Normal hits", one.hits)
	if one.hits > 0 then
		Line("Average", SUIC.Short(one.hitSum / one.hits))
		Line("Last", SUIC.Short(one.lastHit))
	end
	Head("Crit rate", Pct(one.crits / (one.crits + one.hits)))
	GameTooltip:Show()
end

local function CritEnter()
	critHover = this
	CritCard(this)
end

local function CritLeave()
	critHover = nil
	GameTooltip:Hide()
end

local rows = {}
for index = 1, SLOTS + 1 do
	local row = CreateFrame("Frame", nil, panel)
	row:SetWidth(W - 2 * PAD)
	row:SetHeight(ROW)
	local y = -TOP - (index - 1) * ROW
	if index > SLOTS then
		y = y - 5
	end
	row:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, y)
	row:EnableMouse(true)
	row:SetScript("OnEnter", RowEnter)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetWidth(ROW - 2)
	row.icon:SetHeight(ROW - 2)
	row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	row.name = SUIC.Text(row, "GameFontHighlightSmall")
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetWidth(NAME_ROOM)
	row.name:SetHeight(ROW)
	-- Three columns at the right, each a fixed width, its text in its
	-- middle: the biggest crit, the cooldown, the rank.
	row.rank = SUIC.Text(row, "GameFontNormalSmall")
	row.rank:SetPoint("CENTER", row, "RIGHT", -RANK_COLUMN / 2 + 1, 0)
	row.cd = SUIC.Text(row, "GameFontDisableSmall")
	row.cd:SetPoint("CENTER", row, "RIGHT", -RANK_COLUMN - CD_COLUMN / 2 + 1, 0)
	row.crit = SUIC.Text(row, "GameFontHighlightSmall")
	row.crit:SetPoint("CENTER", row, "RIGHT", -RANK_COLUMN - CD_COLUMN - CRIT_COLUMN / 2 + 1, 0)
	row.crit:SetTextColor(1, 0.55, 0.25)
	local zone = CreateFrame("Frame", nil, row)
	zone:SetWidth(CRIT_COLUMN)
	zone:SetHeight(ROW)
	zone:SetPoint("RIGHT", row, "RIGHT", -RANK_COLUMN - CD_COLUMN + 1, 0)
	zone:EnableMouse(true)
	zone:SetScript("OnEnter", CritEnter)
	zone:SetScript("OnLeave", CritLeave)
	zone.row = row
	rows[index] = row
end

-- A faint line between the columns: the name, the biggest crit, the
-- cooldown, the rank.
local DIVIDERS = { RANK_COLUMN - 3, RANK_COLUMN + CD_COLUMN - 3, RANK_COLUMN + CD_COLUMN + CRIT_COLUMN - 3 }
for index = 1, table.getn(DIVIDERS) do
	local line = panel:CreateTexture(nil, "ARTWORK")
	line:SetTexture(SUIC.FLAT)
	line:SetVertexColor(1, 1, 1, 0.08)
	line:SetWidth(1)
	line:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD - DIVIDERS[index], -TOP)
	line:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", -PAD - DIVIDERS[index], -TOP - (SLOTS + 1) * ROW - 5)
end

-- A line between the slots and the racial.
local rule = panel:CreateTexture(nil, "ARTWORK")
rule:SetTexture(SUIC.FLAT)
rule:SetVertexColor(0.6, 0.6, 0.6, 0.3)
rule:SetHeight(1)
rule:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -TOP - SLOTS * ROW - 2)
rule:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -TOP - SLOTS * ROW - 2)

local function Cooldown(entry)
	local seconds = tonumber(entry.cdmax) or 0
	if seconds <= 0 then
		return ""
	elseif seconds < 10 then
		return string.format("%.1fs", seconds)
	end
	return math.floor(seconds + 0.5).."s"
end

-- A name that fits its room: whole, else its words after the first cut to
-- three letters and a dot ("Demonic Emp."), else cut at the end.
local function Shorten(text, name)
	text:SetText(name)
	if text:GetStringWidth() <= NAME_ROOM then
		return
	end
	local first = true
	local short = string.gsub(name, "(%S+)", function(word)
		if first then
			first = false
			return word
		end
		if string.len(word) > 4 then
			return string.sub(word, 1, 3).."."
		end
		return word
	end)
	text:SetText(short)
	while text:GetStringWidth() > NAME_ROOM and string.len(short) > 4 do
		short = string.sub(short, 1, string.len(short) - 1)
		text:SetText(short..".")
	end
end

local function Fill(row, entry, slot, racial)
	row.slot = slot
	row.icon:SetTexture(GetActionTexture(slot) or EMPTY)
	row.spell = SpellName(slot) or entry.key or "?"
	Shorten(row.name, row.spell)
	if racial then
		row.name:SetTextColor(0.75, 0.75, 0.75)
	else
		row.name:SetTextColor(1, 1, 1)
	end
	row.rank:SetText(entry.rank and ("R"..entry.rank) or "")
	row.cd:SetText(Cooldown(entry))
	row.key = entry.key
	row:Show()
end

local function Empty(row)
	row.slot = nil
	row.icon:SetTexture(EMPTY)
	row.name:SetText("|cff8a8a8aEmpty|r")
	row.rank:SetText("")
	row.cd:SetText("")
	row.crit:SetText("")
	row.key = nil
	row:Show()
end

-- The three numbers and each spell's biggest crit, read again every second.
local function Numbers()
	local s = AZS_STATS
	if s and s.dmg then
		stats:SetText("|cffffd100Damage|r "..(s.dmg >= 1 and "+" or "")..Pct(s.dmg - 1)
			.."    |cffffd100Crit|r "..string.format("%.1f%%", (s.crit or 0) * 100)
			.."    |cffffd100Crit Dmg|r "..Pct(s.cm or 0))
	else
		stats:SetText("")
	end
	for index = 1, table.getn(rows) do
		local row = rows[index]
		local crit = row.key and SUIC.BiggestCrit(row.key)
		row.crit:SetText(crit and SUIC.Short(crit) or "")
	end
	if critHover then
		CritCard(critHover)
	end
end

-- The highest rank first, equal ranks in the game's order.
local function ByRank(a, b)
	local first, second = tonumber(a.entry.rank) or 0, tonumber(b.entry.rank) or 0
	if first ~= second then
		return first > second
	end
	return a.slot < b.slot
end

local function Draw()
	local spells = AZS_SPELLS or {}
	local total = table.getn(spells)
	-- The racial is the last one; a hero has one.
	local slotted = math.max(0, total - 1)
	local order = {}
	for index = 1, slotted do
		table.insert(order, { entry = spells[index], slot = index })
	end
	table.sort(order, ByRank)
	for index = 1, SLOTS do
		if order[index] then
			Fill(rows[index], order[index].entry, order[index].slot, false)
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
		panel.note:SetText("|cffff8080"..SLOTS.."/"..SLOTS.."|r")
	else
		panel.note:SetText(slotted.."/"..SLOTS)
	end
	Numbers()
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
SUIC.RefreshBuildList = function()
	Refresh()
	SUIC.SeatColumn()
end

local watch = CreateFrame("Frame")
watch:SetScript("OnEvent", function()
	if event == "CHAT_MSG_ADDON" and arg1 == "AZS" then
		Numbers()
		return
	elseif event == "CHAT_MSG_ADDON" and arg1 ~= "AZSSPELLS" and arg1 ~= "AZSZONE" then
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
	elseif wanted then
		Numbers()
	end
end)
watch:Hide()

SUIC.OnStart(function()
	SUIC.ColumnHome("build")(panel)
	SUIC.AddPiece("build", "Build list", panel, SUIC.ColumnHome("build"))
	SUIC.OverCards(panel)
	watch:RegisterEvent("CHAT_MSG_ADDON")
	watch:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
	watch:RegisterEvent("PLAYER_ENTERING_WORLD")
	watch:Show()
	Refresh()
end)
