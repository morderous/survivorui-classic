-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the action bar as a panel of the same make as the
-- others, "Build" (Lucas, 2026-11-14: the spells go off on their own, so the
-- bar is a board of what the hero has, not buttons to press). The game's own
-- buttons stand in it, in the game's order: the six spells, a soft line, the
-- racial (the game's button 12). The bar's stone and its gryphons go.
--
-- A button's icon stays in sight all through its cooldown (Cooldowns.lua): no
-- dark over it, a gold line at its foot running down, the seconds small in a
-- corner from three up. An empty socket says so.
--
-- Under each spell's icon, in its middle, its rank (R3) and, in grey, its
-- cooldown (at the game's floor in green with the hourglass, as the build
-- list's). The mouse on them tells each by its name. The spell's share of
-- the damage is the damage meter's alone (Lucas, 2026-11-15).
--
-- The top line, no title on it: the hero's Damage, Crit, Crit Dmg and Luck in
-- its middle, the mouse on Luck telling the odds of an epic and of a
-- legendary. Beside the racial, the game's character and talent buttons,
-- small, one over the other. The panel's foot: the level, the experience bar
-- in a thin border, a line at each fifth, and its numbers.
--
-- The game's bar is the frame all of it hangs from (MainMenuBar, the Action
-- bar piece of Move frames, its size too), made the panel's size so what
-- stands on the bar (the talents' clocks, the summons) stands on the panel.
-- Off in the options' Action bar tab, at once: the art, the buttons and the
-- experience bar go back where the game had them.
--
-- The spells stay where the game lays them while the panel is up (as Survivor
-- UI's bar): every piece reads the bar in the game's order, the racial last.

local SLOTS = 6
local RACIAL = 12
local BUTTONS = { 1, 2, 3, 4, 5, 6, 12 }
local STOCK_HEIGHT = 66   -- the game's bar (AZS_MAIN_BAR_HEIGHT)
local STOCK_WIDTH = 397   -- and its width (AZS_MAIN_BAR_WIDTH)
local PAD = 7             -- the buttons under the title's rule
local BUTTON = 36
local PITCH = 49          -- from a spell's left to the next one's
local LEFT = 14           -- the first spell from the panel's left
local RACIAL_X = LEFT + SLOTS * PITCH + 10
local MICRO_X = RACIAL_X + BUTTON + 9   -- the three small buttons, beside the racial
local MICRO_W, MICRO_H = 20, 22
local MICRO_GAP = 4
local MICROS = 3
local WIDTH = MICRO_X + MICRO_W + 9
local FOOT = 18           -- the panel's foot: the level and the experience bar
local LINE = 12           -- a line of words under a spell
local FONT = 10
local BUTTON_Y = FOOT + 3 + 2 * LINE + 4   -- the buttons' feet over the panel's bottom
local PANEL_HEIGHT = BUTTON_Y + BUTTON + PAD + SUIC.TITLE
local AWAY = -4000        -- off the screen: a piece of the game's that shows itself again
local GREEN = { 0.35, 0.95, 0.45 }   -- as the build list's floor
local GOLD = { 1, 0.82, 0 }
local GREY = { 0.62, 0.6, 0.55 }
local ART_PATH = "Interface\\AddOns\\SurvivorUIClassic\\Art\\"

-- The game's art of the bar, put away while the panel is up.
local ART = {
	"MainMenuBarTexture0", "MainMenuBarTexture1", "MainMenuBarTexture2", "MainMenuBarTexture3",
	"AZS_MainMenuBarTexture4", "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap", "AZS_RacialRim",
	"BonusActionBarTexture0", "BonusActionBarTexture1",
	"MainMenuXPBarTexture0", "MainMenuXPBarTexture1", "MainMenuXPBarTexture2",
}

local bar = MainMenuBar
if not bar then
	function SUIC.RefreshBarPanel() end
	return
end

local panel = SUIC.Window("SUICBarPanel", "Build", WIDTH)
panel:SetParent(bar)
panel:SetHeight(PANEL_HEIGHT)
panel:ClearAllPoints()
panel:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
-- Under the game's buttons, which are the art frame's.
panel:SetFrameLevel(bar:GetFrameLevel())
-- No title and no count (Lucas, 2026-11-14): the top line is the numbers'.
panel.title:Hide()
panel.note:Hide()

local up = false

------------------------------------------------------------------------------
-- The sockets: each button's place, dark, in the game's own slot ring, "Empty"
-- in it; a button with a spell covers its socket.

local onPanel = {}        -- [the game's button] = true, the ones in the panel

-- A button's left from the panel's.
local function SlotX(id)
	if id == RACIAL then
		return RACIAL_X
	end
	return LEFT + (id - 1) * PITCH
end

local function Socket(id)
	local button = getglobal("ActionButton"..id)
	if not button then
		return
	end
	onPanel[button] = true
	local bonus = getglobal("BonusActionButton"..id)
	if bonus then
		onPanel[bonus] = true
	end
	local ground = panel:CreateTexture(nil, "BACKGROUND")
	ground:SetTexture(SUIC.FLAT)
	ground:SetVertexColor(0, 0, 0, 0.55)
	ground:SetWidth(BUTTON)
	ground:SetHeight(BUTTON)
	ground:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", SlotX(id), BUTTON_Y)
	local ring = panel:CreateTexture(nil, "ARTWORK")
	ring:SetTexture("Interface\\Buttons\\UI-Quickslot2")
	ring:SetWidth(64)
	ring:SetHeight(64)
	ring:SetPoint("CENTER", ground, "CENTER", 0, -1)
	ring:SetVertexColor(1, 1, 1, 0.7)
	if id ~= RACIAL then
		local empty = SUIC.Text(panel, "GameFontDisableSmall", 8)
		empty:SetPoint("CENTER", ground, "CENTER", 0, 0)
		empty:SetText(SUIC.T("Empty"))
	end
end

for index = 1, table.getn(BUTTONS) do
	Socket(BUTTONS[index])
end

-- A soft line between the spells and the racial, as the build list's columns
-- have them.
local divider = panel:CreateTexture(nil, "ARTWORK")
divider:SetTexture(SUIC.FLAT)
divider:SetVertexColor(1, 1, 1, 0.08)
divider:SetWidth(1)
divider:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", RACIAL_X - 12, FOOT + 4)
divider:SetPoint("TOPLEFT", panel, "TOPLEFT", RACIAL_X - 12, -SUIC.TITLE - 3)

-- The shelf asks (Shelf.lua): the panel up.
function SUIC.BarPanelUp()
	return up
end

-- Cooldowns.lua asks: a button whose icon stays in sight.
function SUIC.OnPanel(button)
	return up and onPanel[button] or false
end

------------------------------------------------------------------------------
-- Each spell's own, under its icon: its rank and its cooldown.

local columns = {}        -- [the button's id] = its pieces

local function ColumnTip()
	local column = this.column
	if not column.spell then
		return
	end
	GameTooltip:SetOwner(this, "ANCHOR_NONE")
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("BOTTOM", column.button, "TOP", 0, 6)
	GameTooltip:AddLine(column.spell, 1, 0.82, 0)
	for index = 1, table.getn(column.words) do
		GameTooltip:AddLine(column.words[index], 1, 1, 1, 1)
	end
	GameTooltip:Show()
	this.over = true
end

local function ColumnUntip()
	if this.over then
		this.over = nil
		GameTooltip:Hide()
	end
end

local function Column(id)
	local button = getglobal("ActionButton"..id)
	if not button then
		return
	end
	local column = { button = button, words = {} }
	local x = SlotX(id)
	-- The mouse's ground, the two lines under the button.
	local zone = CreateFrame("Frame", nil, panel)
	zone:SetWidth(PITCH)
	zone:SetHeight(BUTTON_Y - FOOT - 2)
	zone:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", x - (PITCH - BUTTON) / 2, FOOT + 2)
	zone.column = column
	zone:EnableMouse(true)
	zone:SetScript("OnEnter", ColumnTip)
	zone:SetScript("OnLeave", ColumnUntip)
	zone:SetScript("OnHide", ColumnUntip)
	column.zone = zone
	column.rank = SUIC.Text(zone, "GameFontHighlightSmall", FONT)
	column.rank:SetPoint("TOP", panel, "BOTTOMLEFT", x + BUTTON / 2, BUTTON_Y - 4)
	column.cd = SUIC.Text(zone, "GameFontHighlightSmall", FONT)
	column.cd:SetPoint("TOP", panel, "BOTTOMLEFT", x + BUTTON / 2, BUTTON_Y - 4 - LINE)
	column.glass = zone:CreateTexture(nil, "OVERLAY")
	column.glass:SetTexture(ART_PATH.."FloorHourglass")
	column.glass:SetWidth(9)
	column.glass:SetHeight(9)
	column.glass:SetPoint("LEFT", column.cd, "RIGHT", 1, 0)
	column.glass:Hide()
	columns[id] = column
end

for index = 1, table.getn(BUTTONS) do
	Column(BUTTONS[index])
end

-- A text set only when it changes, its color with it.
local function Say(text, words, color)
	words = words or ""
	if words ~= text.said or color ~= text.color then
		text.said, text.color = words, color
		text:SetText(words)
		color = color or GREY
		text:SetTextColor(color[1], color[2], color[3])
	end
end

local function Blank(id)
	local column = columns[id]
	if column then
		column.spell = nil
		Say(column.rank, "")
		Say(column.cd, "")
		column.glass:Hide()
	end
end

local function Fill(id, entry, racial)
	local column = columns[id]
	if not column then
		return
	end
	local words = {}
	column.spell = SUIC.Native((SUIC.SpellName and SUIC.SpellName(id)) or string.gsub(entry.key or "?", "_", " "))
	local rank = tonumber(entry.rank)
	if racial then
		Say(column.rank, SUIC.T("Racial"))
	elseif rank then
		Say(column.rank, SUIC.TF("R{1}", rank), GOLD)
		table.insert(words, SUIC.TF("Rank {1}. It goes up with this spell's cards at a level-up.", rank))
	else
		Say(column.rank, "")
	end
	local seconds, floor = SUIC.TrueCooldown(entry.key, entry.cdmax)
	if seconds <= 0 then
		Say(column.cd, "")
		column.glass:Hide()
	elseif floor then
		Say(column.cd, SUIC.CooldownWords(seconds), GREEN)
		column.glass:Show()
		table.insert(words, SUIC.TF("At its fastest: {1}, the game's floor. More haste or cooldown cards do nothing for this spell.", SUIC.CooldownWords(floor)))
	else
		Say(column.cd, SUIC.CooldownWords(seconds))
		column.glass:Hide()
		table.insert(words, SUIC.TF("It goes off every {1}, your haste, talents and cooldown cards counted.", SUIC.CooldownWords(seconds)))
	end
	column.words = words
end

------------------------------------------------------------------------------
-- The top line: the hero's numbers (the build list's three, and Luck) in its
-- middle; the mouse on Luck tells the odds, as the character page works them
-- out (SUIC.CardOdds: m = 1 + luck + 1% a level, 30% at most; amulets m + 0.5).

local STATS_FONT = 11
local stats = SUIC.Text(panel, "GameFontHighlightSmall", STATS_FONT)
local luck = SUIC.Text(panel, "GameFontHighlightSmall", STATS_FONT)
luck:SetPoint("LEFT", stats, "RIGHT", 10, 0)
local luckZone = CreateFrame("Frame", nil, panel)
luckZone:SetPoint("TOPLEFT", luck, "TOPLEFT", -4, 5)
luckZone:SetPoint("BOTTOMRIGHT", luck, "BOTTOMRIGHT", 4, -5)
luckZone:EnableMouse(true)

local function Pct(value)
	return math.floor(value * 100 + 0.5).."%"
end

local function Level()
	return tonumber(AZS_RUN and AZS_RUN.lvl) or UnitLevel("player") or 1
end

-- A stat's number in the color the stats panel gives it (StatsPanel.lua, the
-- player's choice in the options or its first one), as a color code.
local function Tint(name)
	local list = SUIC.STAT_LIST or {}
	for index = 1, table.getn(list) do
		if list[index][1] == name then
			local color = SUIC.STAT_COLORS[SUIC.StatColor(index)]
			return string.format("|cff%02x%02x%02x", color[2] * 255, color[3] * 255, color[4] * 255)
		end
	end
	return "|cffffffff"
end

local function Odd(value)
	return string.format("%.1f%%", value * 100)
end

luckZone:SetScript("OnEnter", function()
	local s = AZS_STATS
	if not (s and SUIC.CardOdds) then
		return
	end
	local value = tonumber(s.luck) or 0
	local m = 1 + value + math.min(Level() * 0.01, 0.3)
	local cards, neck = SUIC.CardOdds(m), SUIC.CardOdds(m + 0.5)
	GameTooltip:SetOwner(this, "ANCHOR_TOP")
	GameTooltip:SetText(SUIC.T("Luck").." "..string.format("%+.0f%%", value * 100), 1, 0.82, 0)
	-- No formula here (Lucas, 2026-11-14): the odds, and that an amulet has more.
	GameTooltip:AddLine(SUIC.T("Spells, rings and trinkets"), 1, 1, 1, 1)
	GameTooltip:AddDoubleLine(SUIC.T("Legendary"), Odd(cards[5]), 1, 0.5, 0, 1, 1, 1)
	GameTooltip:AddDoubleLine(SUIC.T("Epic"), Odd(cards[4]), 0.64, 0.21, 0.93, 1, 1, 1)
	GameTooltip:AddDoubleLine(SUIC.T("Rare"), Odd(cards[3]), 0.2, 0.55, 1, 1, 1, 1)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(SUIC.T("Amulets, which roll with 50% more Luck"), 1, 1, 1, 1)
	GameTooltip:AddDoubleLine(SUIC.T("Legendary"), Odd(neck[5]), 1, 0.5, 0, 1, 1, 1)
	GameTooltip:AddDoubleLine(SUIC.T("Epic"), Odd(neck[4]), 0.64, 0.21, 0.93, 1, 1, 1)
	GameTooltip:AddDoubleLine(SUIC.T("Rare"), Odd(neck[3]), 0.2, 0.55, 1, 1, 1, 1)
	GameTooltip:AddLine(" ")
	local none = 1 - cards[5]
	GameTooltip:AddLine(SUIC.TF("A legendary among a level-up's 3 cards: {1}", Odd(1 - none * none * none)), 1, 0.5, 0, 1)
	GameTooltip:Show()
end)
luckZone:SetScript("OnLeave", function() GameTooltip:Hide() end)

local function Numbers()
	local s = AZS_STATS
	local said, lucky = "", ""
	if s and s.dmg and SUIC.InRun() then
		said = "|cffffd100"..SUIC.T("Damage").."|r "..Tint("Damage")..(s.dmg >= 1 and "+" or "")..Pct(s.dmg - 1)
			.."|r   |cffffd100"..SUIC.T("Crit").."|r "..Tint("Crit")..string.format("%.1f%%", (s.crit or 0) * 100)
			.."|r   |cffffd100"..SUIC.T("Crit Dmg").."|r "..Tint("Crit Dmg")..Pct(s.cm or 0).."|r"
		lucky = "|cffffd100"..SUIC.T("Luck").."|r "..Tint("Luck")..string.format("%+.0f%%", (tonumber(s.luck) or 0) * 100).."|r"
	end
	if said ~= stats.said or lucky ~= luck.said then
		stats.said, luck.said = said, lucky
		stats:SetText(said)
		luck:SetText(lucky)
		-- The two as one line, in the panel's middle.
		local whole = (stats:GetStringWidth() or 0) + 10 + (luck:GetStringWidth() or 0)
		stats:ClearAllPoints()
		stats:SetPoint("LEFT", panel, "TOP", -whole / 2, -12)
	end
end

-- The micro buttons' art is a tall one, the button in its lower part.
local function Small(art, place, words, binding, click)
	local button = CreateFrame("Button", nil, panel)
	button:SetWidth(MICRO_W)
	button:SetHeight(MICRO_H)
	-- The three in the middle of the panel's body, between its rule and its foot.
	local middle = (FOOT + 2 + PANEL_HEIGHT - SUIC.TITLE) / 2
	local top = middle + (MICROS * MICRO_H + (MICROS - 1) * MICRO_GAP) / 2
	button:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", MICRO_X, top - (place - 1) * (MICRO_H + MICRO_GAP))
	local face = button:CreateTexture(nil, "ARTWORK")
	face:SetTexture("Interface\\Buttons\\UI-MicroButton"..art.."-Up")
	face:SetTexCoord(0, 1, 0.4, 1)
	face:SetAllPoints(button)
	button.face = face
	local light = button:CreateTexture(nil, "HIGHLIGHT")
	light:SetTexture("Interface\\Buttons\\UI-MicroButton-Hilight")
	light:SetTexCoord(0, 1, 0.4, 1)
	light:SetAllPoints(button)
	light:SetBlendMode("ADD")
	button:SetScript("OnClick", click)
	button:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		local said = getglobal(words) or ""
		if MicroButtonTooltipText then
			said = MicroButtonTooltipText(said, binding)
		end
		GameTooltip:SetText(said, 1, 1, 1)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return button
end

local character = Small("Character", 1, "CHARACTER_BUTTON", "TOGGLECHARACTER0", function()
	if ToggleCharacter then
		ToggleCharacter("PaperDollFrame")
	end
end)
-- The hero's face on it, as the game's has.
local face = character:CreateTexture(nil, "OVERLAY")
face:SetWidth(13)
face:SetHeight(15)
face:SetPoint("CENTER", character, "CENTER", 0, -1)
face:SetTexCoord(0.2, 0.8, 0.07, 0.93)
character.portrait = face
Small("-Talents", 2, "TALENTS_BUTTON", "TOGGLETALENTS", function()
	if ToggleTalentFrame then
		ToggleTalentFrame()
	end
end)
-- Run History (RunHistory.lua), under the talents: the quest log's button,
-- with a word of what it opens.
local history = Small("-Quest", 3, "", nil, function()
	if SUIC.ToggleRunHistory then
		SUIC.ToggleRunHistory()
	end
end)
history:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_TOP")
	GameTooltip:SetText(SUIC.T("Run History"), 1, 1, 1)
	GameTooltip:AddLine(SUIC.T("The runs you ended, each with its numbers."), 1, 0.82, 0, 1)
	GameTooltip:Show()
end)

------------------------------------------------------------------------------
-- The panel's foot: the level, the game's experience bar in a thin border
-- of the tooltip's, a line at each fifth, and its numbers.

local level = SUIC.Text(panel, "GameFontNormalSmall", FONT)
level:SetPoint("LEFT", panel, "BOTTOMLEFT", SUIC.PAD, FOOT / 2 + 2)
local XP_LEFT, XP_RIGHT, XP_HEIGHT = 66, 76, 7
-- The game writes its numbers again at every change, in its own size: off
-- the screen, these in their place.
local xpWords = SUIC.Text(panel, "GameFontHighlightSmall", FONT)
xpWords:SetPoint("RIGHT", panel, "BOTTOMRIGHT", -SUIC.PAD, FOOT / 2 + 2)
local footRule = panel:CreateTexture(nil, "ARTWORK")
footRule:SetTexture(SUIC.FLAT)
footRule:SetVertexColor(1, 1, 1, 0.08)
footRule:SetHeight(1)
footRule:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 6, FOOT + 2)
footRule:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, FOOT + 2)
-- The parts' lines, over the bar.
local parts = CreateFrame("Frame", nil, panel)
parts:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", XP_LEFT, FOOT / 2 + 2 - XP_HEIGHT / 2)
parts:SetWidth(WIDTH - XP_LEFT - XP_RIGHT)
parts:SetHeight(XP_HEIGHT)
local trough = panel:CreateTexture(nil, "ARTWORK")
trough:SetTexture(SUIC.FLAT)
trough:SetVertexColor(0, 0, 0, 0.6)
trough:SetAllPoints(parts)
for index = 1, 4 do
	local line = parts:CreateTexture(nil, "OVERLAY")
	line:SetTexture(SUIC.FLAT)
	line:SetVertexColor(0, 0, 0, 1)
	line:SetWidth(2)
	line:SetHeight(XP_HEIGHT)
	line:SetPoint("CENTER", parts, "LEFT", index * (WIDTH - XP_LEFT - XP_RIGHT) / 5, 0)
end
local edge = CreateFrame("Frame", nil, parts)
edge:SetPoint("TOPLEFT", parts, "TOPLEFT", -3, 3)
edge:SetPoint("BOTTOMRIGHT", parts, "BOTTOMRIGHT", 3, -3)
edge:SetBackdrop({
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 8, edgeSize = 8,
	insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
edge:SetBackdropBorderColor(0.65, 0.65, 0.65, 1)

------------------------------------------------------------------------------
-- The game's pieces seated in the panel, and back as the game had them.

local kept = {}           -- [piece] = its points as the game laid them
local wasShown = {}       -- [art's name] = shown before the panel
local wasXp = {}          -- the experience bar's size and level before

local function Seat(piece, point, relativePoint, x, y)
	if not piece then
		return
	end
	if not kept[piece] and piece.GetNumPoints then
		local points = {}
		for index = 1, piece:GetNumPoints() do
			local at, relative, relativeTo, px, py = piece:GetPoint(index)
			table.insert(points, { at, relative, relativeTo, px, py })
		end
		kept[piece] = points
	end
	piece:ClearAllPoints()
	piece:SetPoint(point, bar, relativePoint, x, y)
end

local function Unseat(piece)
	local points = piece and kept[piece]
	if not points or table.getn(points) == 0 then
		return
	end
	piece:ClearAllPoints()
	for index = 1, table.getn(points) do
		local at = points[index]
		piece:SetPoint(at[1], at[2], at[3], at[4], at[5])
	end
end

local SEATED = { "CharacterMicroButton", "MainMenuExpBar", "MainMenuBarMaxLevelBar", "MainMenuBarExpText" }
for index = 1, table.getn(BUTTONS) do
	table.insert(SEATED, "ActionButton"..BUTTONS[index])
	table.insert(SEATED, "BonusActionButton"..BUTTONS[index])
end

local function Raise()
	for index = 1, table.getn(ART) do
		local name = ART[index]
		local art = getglobal(name)
		if art then
			wasShown[name] = art:IsShown() and true or false
			art:Hide()
		end
	end
	bar:SetHeight(PANEL_HEIGHT)
	bar:SetWidth(WIDTH)
	for index = 1, table.getn(BUTTONS) do
		local id = BUTTONS[index]
		Seat(getglobal("ActionButton"..id), "BOTTOMLEFT", "BOTTOMLEFT", SlotX(id), BUTTON_Y)
		if id ~= RACIAL then
			Seat(getglobal("BonusActionButton"..id), "BOTTOMLEFT", "BOTTOMLEFT", SlotX(id), BUTTON_Y)
		end
	end
	-- The game's two buttons show themselves again: off the screen, the small
	-- ones in the title in their place (the talents' follows the character's).
	Seat(CharacterMicroButton, "BOTTOMLEFT", "BOTTOMLEFT", AWAY, 0)
	Seat(MainMenuBarMaxLevelBar, "BOTTOMLEFT", "BOTTOMLEFT", AWAY, 0)
	local xp = MainMenuExpBar
	if xp then
		wasXp.width, wasXp.height, wasXp.level = xp:GetWidth(), xp:GetHeight(), xp:GetFrameLevel()
		Seat(xp, "BOTTOMLEFT", "BOTTOMLEFT", XP_LEFT, FOOT / 2 + 2 - XP_HEIGHT / 2)
		xp:SetWidth(WIDTH - XP_LEFT - XP_RIGHT)
		xp:SetHeight(XP_HEIGHT)
		xp:SetFrameLevel(panel:GetFrameLevel() + 1)
		parts:SetFrameLevel(panel:GetFrameLevel() + 3)
		edge:SetFrameLevel(panel:GetFrameLevel() + 4)
	end
	Seat(MainMenuBarExpText, "BOTTOMLEFT", "BOTTOMLEFT", AWAY, 0)
	panel:Show()
end

local function Lower()
	panel:Hide()
	for index = 1, table.getn(ART) do
		local name = ART[index]
		local art = getglobal(name)
		if art and wasShown[name] then
			art:Show()
		end
	end
	bar:SetHeight(AZS_MAIN_BAR_HEIGHT or STOCK_HEIGHT)
	bar:SetWidth(AZS_MAIN_BAR_WIDTH or STOCK_WIDTH)
	local xp = MainMenuExpBar
	if xp and wasXp.width then
		xp:SetWidth(wasXp.width)
		xp:SetHeight(wasXp.height)
		xp:SetFrameLevel(wasXp.level)
	end
	for index = 1, table.getn(SEATED) do
		Unseat(getglobal(SEATED[index]))
	end
	-- Its numbers, should the game not have told where they stood: on the bar.
	local said = MainMenuBarExpText
	if said and xp and not (kept[said] and table.getn(kept[said]) > 0) then
		said:ClearAllPoints()
		said:SetPoint("CENTER", xp, "CENTER", 0, 1)
	end
end

-- The option, at once (and the addon's start).
function SUIC.RefreshBarPanel()
	local on = (SUIC.active and SUIC.DB().barPanel) and true or false
	if on == up then
		return
	end
	up = on
	if on then
		Raise()
	else
		Lower()
	end
	-- The bar moved in Move frames keeps its place; the cooldowns their look.
	if SUIC.ApplyPositions then
		SUIC.ApplyPositions()
	end
	if SUIC.RefreshCooldowns then
		SUIC.RefreshCooldowns()
	end
	if SUIC.RefreshShelf then
		SUIC.RefreshShelf()
	end
end

------------------------------------------------------------------------------
-- All of it read again each second.

local function Draw()
	local spells = AZS_SPELLS or {}
	local total = SUIC.InRun() and table.getn(spells) or 0
	local slotted = math.max(0, total - 1)
	for index = 1, SLOTS do
		if index <= slotted then
			Fill(index, spells[index], false)
		else
			Blank(index)
		end
	end
	if total > 0 then
		Fill(RACIAL, spells[total], true)
	else
		Blank(RACIAL)
	end
	Numbers()
	local now = SUIC.TF("Level {1}", Level())
	if now ~= level.said then
		level.said = now
		level:SetText(now)
	end
	local xp = (UnitXP("player") or 0).." / "..(UnitXPMax("player") or 0)
	if xp ~= xpWords.said then
		xpWords.said = xp
		xpWords:SetText(xp)
	end
	if SetPortraitTexture then
		SetPortraitTexture(character.portrait, "player")
	end
end

local wait = 1
panel:SetScript("OnUpdate", function()
	wait = wait + arg1
	if wait < 1 then
		return
	end
	wait = 0
	Draw()
end)

------------------------------------------------------------------------------
-- The spells locked on the bar while the panel is up: a spell dragged off its
-- button, or picked up with a shift-click, would leave the panel, the build
-- list and the hourglass reading the wrong button. Every drag, drop and
-- shift-click on the bar goes through these two.

local stockPickup, stockPlace = PickupAction, PlaceAction
local lockSaid

if stockPickup then
	PickupAction = function(id)
		if up then
			if not lockSaid then
				lockSaid = true
				SUIC.Print(SUIC.T("The spells stay on the bar where the game lays them."))
			end
			return
		end
		return stockPickup(id)
	end
end
if stockPlace then
	PlaceAction = function(id)
		if up then
			return
		end
		return stockPlace(id)
	end
end

SUIC.OnStart(function()
	SUIC.RefreshBarPanel()
end)
