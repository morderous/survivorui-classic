-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the hero's numbers in a panel on the screen during a
-- run, of the same make as the others (Lucas, 2026-11-03): its gold title,
-- each stat's name at the left and its number at the right in a color of its
-- own. Which stats show and each one's color are chosen in the options' Stats
-- panel tab, among fifteen colors. It moves (Move frames) and can stay over a
-- level's cards (Card choice).
--
-- From the game's addon API (AZS_STATS), as the character page reads it.

local ROW = 14
local WIDTH = 180

local function Pct(value)
	value = tonumber(value) or 0
	return string.format("%+.0f%%", value * 100)
end

local function Fixed(format, scale)
	return function(value)
		return string.format(format, (tonumber(value) or 0) * (scale or 1))
	end
end

-- Each stat: its name, its field in AZS_STATS, how it reads, shown at first,
-- its first color (an index in COLORS).
SUIC.STAT_LIST = {
	{ "Damage", "dmg", function(v) return Pct((tonumber(v) or 1) - 1) end, true, 15 },
	{ "Crit", "crit", Fixed("%.1f%%", 100), true, 6 },
	{ "Crit Dmg", "cm", Fixed("%.0f%%", 100), true, 6 },
	{ "Haste", "cd", function(v) return Pct(1 - (tonumber(v) or 1)) end, true, 3 },
	{ "Echo", "echo", Fixed("%.0f%%", 100), true, 9 },
	{ "Area", "area", function(v) return Pct((tonumber(v) or 1) - 1) end, true, 1 },
	{ "Targets", "cnt", Fixed("+%d"), false, 1 },
	{ "Health", "hp", Fixed("%.0f"), true, 7 },
	{ "Regen", "reg", Fixed("%.1f"), false, 1 },
	{ "Lifesteal", "lch", Fixed("%.1f%%", 100), false, 1 },
	{ "Armor", "arm", Fixed("%.0f%%", 100), true, 12 },
	{ "Kill Heal", "heal", Fixed("%.0f"), false, 1 },
	{ "Thorns", "thn", Fixed("%.0f%%", 100), false, 1 },
	{ "Lives", "liv", Fixed("%d"), false, 1 },
	{ "Pickup", "pick", Fixed("%.0f yd"), false, 1 },
	{ "Speed", "spd", function(v) return Pct((tonumber(v) or 1) - 1) end, true, 1 },
	{ "Experience", "xp", function(v) return Pct((tonumber(v) or 1) - 1) end, false, 1 },
	{ "Gold", "gold", function(v) return Pct((tonumber(v) or 1) - 1) end, false, 1 },
	{ "Luck", "luck", Pct, true, 13 },
	{ "Buff Power", "bp", Pct, false, 1 },
	{ "DoT Stacks", "dots", Fixed("%d"), false, 1 },
	{ "DoT Haste", "doth", Pct, false, 1 },
}

-- The fifteen colors a stat's number can wear.
SUIC.STAT_COLORS = {
	{ "White", 1, 1, 1 },
	{ "Grey", 0.62, 0.62, 0.62 },
	{ "Gold", 1, 0.82, 0 },
	{ "Yellow", 1, 0.95, 0.42 },
	{ "Orange", 1, 0.55, 0.1 },
	{ "Peach", 1, 0.67, 0.38 },
	{ "Red", 1, 0.35, 0.35 },
	{ "Pink", 1, 0.5, 0.78 },
	{ "Purple", 0.77, 0.54, 1 },
	{ "Violet", 0.54, 0.35, 1 },
	{ "Blue", 0.24, 0.5, 1 },
	{ "Light blue", 0.5, 0.78, 1 },
	{ "Cyan", 0.24, 0.94, 0.82 },
	{ "Mint", 0.5, 1, 0.63 },
	{ "Green", 0.35, 0.95, 0.45 },
}

-- A stat shown or not, and its color's index, as chosen or at first.
function SUIC.StatShown(index)
	local chosen = SUIC.DB().statsShown[SUIC.STAT_LIST[index][1]]
	if chosen == nil then
		return SUIC.STAT_LIST[index][4]
	end
	return chosen
end

function SUIC.StatColor(index)
	local chosen = tonumber(SUIC.DB().statsColors[SUIC.STAT_LIST[index][1]])
	if chosen and SUIC.STAT_COLORS[chosen] then
		return chosen
	end
	return SUIC.STAT_LIST[index][5]
end

local panel = SUIC.Window("SUICStatsPanel", "Stats", WIDTH)
panel:SetFrameStrata("MEDIUM")
local rows = {}

local function Home(f)
	f:SetPoint("LEFT", UIParent, "LEFT", 12, 120)
end
Home(panel)

local function Row(index)
	local row = rows[index]
	if row then
		return row
	end
	row = {}
	row.name = SUIC.Text(panel, "GameFontHighlightSmall")
	row.name:SetPoint("TOPLEFT", panel, "TOPLEFT", SUIC.PAD, -SUIC.TITLE - 4 - (index - 1) * ROW)
	row.name:SetTextColor(0.85, 0.85, 0.85)
	row.value = SUIC.Text(panel, "GameFontHighlightSmall")
	row.value:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -SUIC.PAD, -SUIC.TITLE - 4 - (index - 1) * ROW)
	rows[index] = row
	return row
end

local function Numbers()
	local s = AZS_STATS
	local shown = 0
	for index = 1, table.getn(SUIC.STAT_LIST) do
		local stat = SUIC.STAT_LIST[index]
		if SUIC.StatShown(index) then
			shown = shown + 1
			local row = Row(shown)
			row.name:SetText(stat[1])
			local value = s and s[stat[2]]
			row.value:SetText(value ~= nil and stat[3](value) or "-")
			local color = SUIC.STAT_COLORS[SUIC.StatColor(index)]
			row.value:SetTextColor(color[2], color[3], color[4])
			row.name:Show()
			row.value:Show()
		end
	end
	for index = shown + 1, table.getn(rows) do
		rows[index].name:Hide()
		rows[index].value:Hide()
	end
	panel:SetHeight(SUIC.TITLE + 10 + math.max(1, shown) * ROW)
	local level = tonumber(AZS_RUN and AZS_RUN.lvl)
	panel.note:SetText(level and ("Lv "..level) or "")
end

local function Refresh()
	local wanted = SUIC.DB().statsPanel and SUIC.InRun()
	if wanted then
		Numbers()
		panel:Show()
	else
		panel:Hide()
	end
end
SUIC.RefreshStatsPanel = Refresh

local ticker = CreateFrame("Frame")
local elapsed = 0
ticker:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.5 then
		return
	end
	elapsed = 0
	Refresh()
end)
ticker:Hide()

SUIC.OnStart(function()
	SUIC.AddPiece("stats", "Stats panel", panel, Home)
	SUIC.OverCards(panel, "stats")
	ticker:Show()
	Refresh()
end)
