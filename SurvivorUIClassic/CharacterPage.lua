-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the character page in one panel, of the same make as
-- the others. The item slots stand at its two sides, the hero between them.
-- At the hero's left the odds luck gives, at the right the three numbers that
-- weigh most, each hovered for its formula. Under the hero the other numbers
-- in four small panels by kind, the game's Run Stats box folded in. All six
-- panels as wide, in two rows: the top two, shorter, stand over the first and
-- the last of the bottom four. The page's tabs and the ammo slot go. Hold the
-- mouse on the hero and pull to turn it.
--
-- The rows under the hero are the game's own, only moved: it keeps writing
-- their numbers and tooltips (AZS_Update). The panel lives on the page: as it
-- shows, everything goes to its place, and as it hides (off, or the window
-- closed) everything goes back.
--
-- The formulas, read in the game's 0.130.1 exe (game\mod.rs, game\upgrades.rs):
--   Damage = 1 + 3% a level after the first + every other bonus, all added; a
--     hit is the spell's base times it.
--   Crit starts at 5% and Crit Dmg at 200%; a hit under the chance is
--     multiplied by Crit Dmg; past 100% the rest is added to Crit Dmg.
--   Haste: every cooldown times 1 / (1 + the bonuses, added), which the game
--     shows as 1 minus that. Each spell has a shortest wait of its own.
--   Luck: m = 1 + luck + the level's 1% (30% at most); the weights Common 60,
--     Uncommon 25m, Rare 10m^2, Epic 4m^3, Legendary m^4, each card rolled on
--     its own. Rings and trinkets as the cards ("Cards" here), amulets ("Neck")
--     with m + 0.5, and a guardian's hoard or a boss 0.25 more on both.

local LEFT, TOP = 11, -11       -- where the game's art starts in its frame
local WIDTH, HEIGHT = 620, 484
local SLOT, STEP = 37, 45       -- an item slot, and from one to the next
local SIDE = 10                 -- the slots' inset from the panel's sides
local FIRST = -63               -- the first slot's top
local MIDDLE = SIDE + SLOT + 6  -- the hero and the numbers, clear of the slots
local MODEL_TOP, GROUPS_TOP = -58, -292
local PANEL_HEIGHT = 134        -- the bottom four
local TOP_HEIGHT = 84           -- the top two
local MODEL_WIDTH = 280         -- the hero grows with the frame's width: wider, the feet are cut
local WEAPONS_TOP = GROUPS_TOP - PANEL_HEIGHT - 6
local WEAPON_GAP = 5
local GROUP_GAP = 4
local INSET = 6                 -- a row's inset from its small panel
local ROW = 13                  -- a row at most: more rows, closer
local TEXT_SIZE = 10
local TOP_TEXT = TEXT_SIZE + 2  -- the top two's
local SIDE_TOP = GROUPS_TOP + 4 + TOP_HEIGHT    -- their foot just over the bottom four
local MAIN_ROW = 17             -- a row of the three main numbers
local ODDS_ROW = 14
local GOLD = { 1, 0.82, 0 }
local GREEN = { 0.35, 0.95, 0.45 }
local PEACH = { 1, 0.67, 0.38 }  -- Crit Dmg and Crit, a pair: softer than a legendary's orange
local RING = "Interface\\AddOns\\SurvivorUIClassic\\Art\\PortraitRing"
local RING_SIZE = 68            -- its hole a little under the portrait, on the portrait's edge
local PORTRAIT_SIZE = 56
local PORTRAIT_X, PORTRAIT_Y = 26, -24
local RUN_ROW_WIDTH = 156       -- the game's width for its Run Stats rows
local LUCK_COLOR = { 0.35, 0.9, 0.55 }
local TURN = 0.01               -- the hero's turn for each unit the mouse pulls

local LEFT_SLOTS = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist" }
local RIGHT_SLOTS = { "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1" }
local WEAPON_SLOTS = { "MainHand", "SecondaryHand", "Ranged" }
-- Kept away: the tabs of Character, Skills and Honor, and the ammo slot, never
-- used here. The Pet tab stays the game's to show.
local GONE = { "CharacterFrameTab1", "CharacterFrameTab4", "CharacterFrameTab5", "CharacterAmmoSlot" }
-- The game's rows in its two blocks, each frame's number by name.
local GAME_ROWS = {
	CharacterStatFrame1 = "Health", CharacterStatFrame2 = "Damage", CharacterStatFrame3 = "Haste",
	CharacterStatFrame4 = "Crit", CharacterStatFrame5 = "Crit Dmg", CharacterArmorFrame = "Armor",
	CharacterAttackFrame = "Area", CharacterAttackPowerFrame = "Targets", CharacterDamageFrame = "Echo",
	CharacterRangedAttackFrame = "Speed", CharacterRangedAttackPowerFrame = "Regen", CharacterRangedDamageFrame = "Pickup",
}
-- The small panels, left to right. A row the game adds later joins Bonus.
local GROUPS = {
	{ title = "Bonus", spare = true, rows = { "Buff Power", "DoT Stacks", "DoT Haste", "Vs Elites", "Execute",
		"Vs Controlled", "Vs Afflicted", "Shielded", "Melee", "Pet Damage" } },
	{ title = "Utility", rows = { "Speed", "Pickup", "Experience", "Gold" } },
	{ title = "Defense", rows = { "Armor", "Health", "Regen", "Lifesteal", "Kill Heal", "Thorns", "Lives" } },
	{ title = "Offense", rows = { "Haste", "Echo", "Area", "Targets" } },
}
-- Shown in the panels at the hero's sides instead: the game's rows put away.
local ABOVE = { Damage = true, Crit = true, ["Crit Dmg"] = true, Luck = true }
-- The rarities in the luck panel, the rarest first: its color, the weight's place.
local RARITIES = {
	{ { 1, 0.5, 0 }, 5 },
	{ { 0.64, 0.21, 0.93 }, 4 },
	{ { 0.2, 0.55, 1 }, 3 },
}
-- Every rarity, for the formula in the tooltip.
local WEIGHTS = {
	{ "Common", "60", { 0.62, 0.62, 0.62 } }, { "Uncommon", "25 x m", { 0.12, 1, 0 } },
	{ "Rare", "10 x m^2", { 0.2, 0.55, 1 } }, { "Epic", "4 x m^3", { 0.64, 0.21, 0.93 } },
	{ "Legendary", "m^4", { 1, 0.5, 0 } },
}

local panel, ring
local kept = {}                 -- each thing moved: how the game had it
local art = {}                  -- the game's art on the page, hidden
local stockWidth
local groupWidth = math.floor((WIDTH - 2 * MIDDLE - (table.getn(GROUPS) - 1) * GROUP_GAP) / table.getn(GROUPS))

-- A frame's points as the game had them, once.
local function Keep(frame)
	if kept[frame] then
		return
	end
	local points = {}
	for index = 1, frame:GetNumPoints() do
		local point, relative, relativePoint, x, y = frame:GetPoint(index)
		table.insert(points, { point, relative, relativePoint, x, y })
	end
	kept[frame] = { points = points }
end

local function Seat(frame, point, relative, relativePoint, x, y)
	if not frame then
		return
	end
	Keep(frame)
	frame:ClearAllPoints()
	frame:SetPoint(point, relative, relativePoint, x, y)
end

local function Resize(frame, width, height)
	if not frame then
		return
	end
	Keep(frame)
	-- Only what is resized gets its size back: set on a font string, its
	-- measured width would cut its text from then on.
	local was = kept[frame]
	was.width, was.height = was.width or frame:GetWidth(), was.height or frame:GetHeight()
	frame:SetWidth(width)
	if height then
		frame:SetHeight(height)
	end
end

-- A row's text at the small panels' size.
local function Small(text)
	if not text then
		return
	end
	Keep(text)
	local was = kept[text]
	if not was.font then
		was.font = { text:GetFont() }
		text:SetFont(was.font[1] or STANDARD_TEXT_FONT, TEXT_SIZE, was.font[3])
	end
end

local function FindArt(frame)
	local regions = { frame:GetRegions() }
	for index = 1, table.getn(regions) do
		if regions[index]:GetObjectType() == "Texture" then
			table.insert(art, regions[index])
		end
	end
end

------------------------------------------------------------------------------
-- The numbers at the hero's sides.

local function Signed(value)
	return string.format("%+.0f%%", value * 100)
end

local function Percent(value)
	return string.format("%.1f%%", value * 100)
end

local function Level()
	return tonumber(AZS_RUN and AZS_RUN.lvl) or UnitLevel("player") or 1
end

local function LevelBonus(level)
	return math.min(level * 0.01, 0.3)
end

-- The five rarities' odds, Common to Legendary, and their weights.
local function Odds(m)
	local weights = { 60, 25 * m, 10 * m * m, 4 * m * m * m, m * m * m * m }
	local total = 0
	for index = 1, 5 do
		total = total + weights[index]
	end
	local odds = {}
	for index = 1, 5 do
		odds[index] = weights[index] / total
	end
	return odds, weights
end

local function Note(text, r, g, b)
	GameTooltip:AddLine(text, r or 1, g or 0.82, b or 0, 1)
end

local function Part(label, value)
	GameTooltip:AddDoubleLine(label, value, 0.8, 0.8, 0.8, 1, 1, 1)
end

-- What the three give together over time: a hit, its crits and its pace.
local function Together(s)
	local chance, double = tonumber(s.crit), tonumber(s.cm)
	local average = 1 + chance * (double - 1)
	local pace = 1 / tonumber(s.cd)
	GameTooltip:AddLine(" ")
	Note(string.format("Together: %.2f x %.2f x %.2f = x%.2f your spells' base damage over time.",
		tonumber(s.dmg), average, pace, tonumber(s.dmg) * average * pace), LUCK_COLOR[1], LUCK_COLOR[2], LUCK_COLOR[3])
end

local function DamageTip(s)
	local level = Level()
	local byLevel = 0.03 * (level - 1)
	local gear = tonumber(s.gdmg) or 0
	Note(string.format("Every hit is the spell's base x %.2f.", tonumber(s.dmg)), 1, 1, 1)
	Note("Every source is added first, then it multiplies once, so a new +10% counts for less the more you have.")
	GameTooltip:AddLine(" ")
	Part("Base", "100%")
	Part("Level "..level.." (3% a level)", Signed(byLevel))
	Part("Worn gear", Signed(gear))
	Part("Talents, jewelry, buffs", Signed(tonumber(s.dmg) - 1 - byLevel - gear))
	Together(s)
end

local function CritTip(s)
	local chance, double = tonumber(s.crit), tonumber(s.cm)
	local gear = tonumber(s.gcrit) or 0
	Note(string.format("A hit strikes critically this often, for %.0f%% of its damage.", double * 100), 1, 1, 1)
	Note(string.format("Average hit: 1 + %.1f%% x (%.0f%% - 100%%) = x%.2f.", chance * 100, double * 100, 1 + chance * (double - 1)))
	Note("Past 100%, the rest adds to Crit Dmg.")
	GameTooltip:AddLine(" ")
	Part("Base", "5%")
	Part("Worn gear", Signed(gear))
	Part("Talents, jewelry, buffs", Signed(chance - 0.05 - gear))
	Together(s)
end

local function CritDmgTip(s)
	local chance, double = tonumber(s.crit), tonumber(s.cm)
	local gear = tonumber(s.gcm) or 0
	Note(string.format("A critical hit deals %.0f%% of its damage.", double * 100), 1, 1, 1)
	Note(string.format("Average hit: 1 + %.1f%% x (%.0f%% - 100%%) = x%.2f.", chance * 100, double * 100, 1 + chance * (double - 1)))
	Note("Crit past 100% adds here.")
	GameTooltip:AddLine(" ")
	Part("Base", "200%")
	Part("Worn gear", Signed(gear))
	Part("Talents, jewelry, buffs", Signed(double - 2 - gear))
	Together(s)
end

-- Under the game's own words on its Haste row, which stays in Offense.
local function HasteWords(s)
	local wait = tonumber(s.cd)
	return string.format("\n\nCooldown = base / (1 + bonuses), the bonuses added: %s here, shown as %s. Spells come %.2f times as often. "
		.."Each spell has a shortest wait of its own.", Signed(1 / wait - 1), Signed(1 - wait), 1 / wait)
end

local MAIN = {
	{ "Damage", function(s) return Signed(tonumber(s.dmg) - 1) end, DamageTip, GREEN },
	{ "Crit Dmg", function(s) return string.format("%.0f%%", tonumber(s.cm) * 100) end, CritDmgTip, PEACH },
	{ "Crit", function(s) return Percent(tonumber(s.crit)) end, CritTip, PEACH },
}

-- Beside the window, going down: above the panels it would run off the screen.
local function BesideWindow(owner)
	GameTooltip:SetOwner(owner, "ANCHOR_NONE")
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("TOPLEFT", panel, "TOPRIGHT", 8, SIDE_TOP)
end

local function StatEnter()
	local s = AZS_STATS
	if not s then
		return
	end
	BesideWindow(this)
	GameTooltip:SetText(this.stat[1].." "..this.stat[2](s), GOLD[1], GOLD[2], GOLD[3])
	this.stat[3](s)
	GameTooltip:Show()
end

local function LuckEnter()
	local s = AZS_STATS
	if not s then
		return
	end
	local luck, level = tonumber(s.luck) or 0, Level()
	local m = 1 + luck + LevelBonus(level)
	local odds, weights = Odds(m)
	BesideWindow(this)
	GameTooltip:SetText("Luck "..Signed(luck), LUCK_COLOR[1], LUCK_COLOR[2], LUCK_COLOR[3])
	Note("Every roll: m = 1 + luck + 1% a level (30% at most).", 1, 1, 1)
	Note(string.format("Level %d: m = 1 + %.2f + %.2f = %.2f", level, luck, LevelBonus(level), m))
	GameTooltip:AddLine(" ")
	Note("Each rarity's weight, and its share of them all:")
	for index = 5, 1, -1 do
		local row = WEIGHTS[index]
		GameTooltip:AddDoubleLine(row[1].."  "..row[2].." = "..string.format("%.1f", weights[index]), Percent(odds[index]),
			row[3][1], row[3][2], row[3][3], 1, 1, 1)
	end
	GameTooltip:AddLine(" ")
	Note("Cards: a level-up's spell cards, and rings and trinkets.", 1, 1, 1)
	Note("Neck: amulets, which roll with m + 0.5.", 1, 1, 1)
	Note("From a guardian's hoard or a boss, rings, trinkets and amulets add 0.25 to m; from a cache you buy, nothing.")
	Note("Each card rolls on its own, and luck has no cap.")
	local none = 1 - odds[5]
	Note("A legendary among a level-up's 3 cards: "..Percent(1 - none * none * none), 1, 0.5, 0)
	GameTooltip:Show()
end

local function DrawSides()
	local s = AZS_STATS
	for index = 1, table.getn(panel.stats) do
		local row = panel.stats[index]
		row.value:SetText(s and row.stat[2](s) or "-")
	end
	local luck = s and tonumber(s.luck) or 0
	local m = 1 + luck + LevelBonus(Level())
	local plain, amulet = Odds(m), Odds(m + 0.5)
	panel.luck.note:SetText(s and Signed(luck) or "")
	for index = 1, table.getn(RARITIES) do
		local rarity, row = RARITIES[index], panel.luck.rows[index]
		row.plain:SetText(s and Percent(plain[rarity[2]]) or "-")
		row.amulet:SetText(s and Percent(amulet[rarity[2]]) or "-")
	end
end

------------------------------------------------------------------------------
-- The rows under the hero.

local function KeyOf(row)
	local _, _, key = string.find(row.label and row.label:GetText() or "", "^(.-):")
	return key
end

-- Every row in its small panel, by the name the game gave it. The Run Stats
-- rows are made as the game needs them, so they are looked over each time.
local function SeatRows()
	local found, spare = {}, {}
	for name, key in pairs(GAME_ROWS) do
		found[key] = getglobal(name)
	end
	local rows = AZS_MORE_ROWS or {}
	for index = 1, table.getn(rows) do
		local row = rows[index]
		local key = KeyOf(row)
		if key and panel.known[key] then
			found[key] = row
		else
			table.insert(spare, row)
		end
		row:SetWidth(groupWidth - 2 * INSET)
		Small(row.label)
		Small(row.value)
	end
	for key in pairs(ABOVE) do
		if found[key] then
			found[key]:Hide()
		end
	end
	local lists, most = {}, 1
	for index = 1, table.getn(GROUPS) do
		local group = GROUPS[index]
		local list = {}
		for each = 1, table.getn(group.rows) do
			local row = found[group.rows[each]]
			if row and row:IsShown() then
				table.insert(list, row)
			end
		end
		if group.spare then
			for each = 1, table.getn(spare) do
				if spare[each]:IsShown() then
					table.insert(list, spare[each])
				end
			end
		end
		lists[index] = list
		most = math.max(most, table.getn(list))
	end
	-- The longest list sets the step: past what fits, the rows stand closer.
	local head = SUIC.TITLE + 4
	local step = math.min(ROW, (PANEL_HEIGHT - head - INSET) / most)
	for index = 1, table.getn(GROUPS) do
		local group, list = GROUPS[index], lists[index]
		for each = 1, table.getn(list) do
			local row = list[each]
			if not GAME_ROWS[row:GetName()] then
				row:SetParent(group.frame)
				row:SetFrameLevel(group.frame:GetFrameLevel() + 1)
			end
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", group.frame, "TOPLEFT", INSET, -head - (each - 1) * step)
		end
	end
	if AZSMoreStats then
		AZSMoreStats:Hide()
	end
	-- Armor by what it does, and Haste with its formula. The game writes them
	-- again with each update, just before this.
	local armor = CharacterArmorFrame
	local armorValue = CharacterArmorFrameStatText and CharacterArmorFrameStatText:GetText()
	if armor and armorValue then
		CharacterArmorFrameLabel:SetText("Dmg Reduction:")
		armor.azsTitle = "Dmg Reduction "..armorValue
	end
	local haste = CharacterStatFrame3
	if haste and haste.azsText and AZS_STATS and not string.find(haste.azsText, "Cooldown = base", 1, true) then
		haste.azsText = haste.azsText..HasteWords(AZS_STATS)
	end
	DrawSides()
end

local function Stand()
	stockWidth = stockWidth or CharacterFrame:GetWidth()
	CharacterFrame:SetWidth(LEFT + WIDTH + 12)
	for index = 1, table.getn(art) do
		art[index]:Hide()
	end
	for index = 1, table.getn(LEFT_SLOTS) do
		Seat(getglobal("Character"..LEFT_SLOTS[index].."Slot"), "TOPLEFT", panel, "TOPLEFT", SIDE, FIRST - (index - 1) * STEP)
		Seat(getglobal("Character"..RIGHT_SLOTS[index].."Slot"), "TOPLEFT", panel, "TOPLEFT", WIDTH - SIDE - SLOT, FIRST - (index - 1) * STEP)
	end
	local weapons = table.getn(WEAPON_SLOTS)
	local first = (WIDTH - weapons * SLOT - (weapons - 1) * WEAPON_GAP) / 2
	for index = 1, weapons do
		Seat(getglobal("Character"..WEAPON_SLOTS[index].."Slot"), "TOPLEFT", panel, "TOPLEFT",
			first + (index - 1) * (SLOT + WEAPON_GAP), WEAPONS_TOP)
	end
	Seat(CharacterModelFrame, "TOP", panel, "TOP", 0, MODEL_TOP)
	Resize(CharacterModelFrame, MODEL_WIDTH, MODEL_TOP - GROUPS_TOP - 4)
	Seat(CharacterModelFrameRotateLeftButton, "TOPLEFT", panel, "TOPLEFT", MIDDLE, MODEL_TOP - 4)
	Seat(CharacterNameText, "TOP", panel, "TOP", 0, -12)
	Seat(CharacterLevelText, "TOP", panel, "TOP", 0, -30)
	Seat(CharacterFrameCloseButton, "TOPRIGHT", panel, "TOPRIGHT", 3, 3)
	-- The portrait inside the ring, one circle.
	Seat(CharacterFramePortrait, "CENTER", panel, "TOPLEFT", PORTRAIT_X, PORTRAIT_Y)
	Resize(CharacterFramePortrait, PORTRAIT_SIZE, PORTRAIT_SIZE)
	-- The name in the class's color.
	if CharacterNameText then
		Keep(CharacterNameText)
		local was = kept[CharacterNameText]
		if not was.color then
			was.color = { CharacterNameText:GetTextColor() }
		end
		local _, class = UnitClass("player")
		local r, g, b = SUIC.ClassColor(class)
		if r then
			CharacterNameText:SetTextColor(r, g, b)
		end
	end
	for name in pairs(GAME_ROWS) do
		local row = getglobal(name)
		if row then
			Resize(row, groupWidth - 2 * INSET)
			Seat(getglobal(name.."Label"), "LEFT", row, "LEFT", 0, 0)
			Seat(getglobal(name.."StatText"), "RIGHT", row, "RIGHT", 0, 0)
			Small(getglobal(name.."Label"))
			Small(getglobal(name.."StatText"))
		end
	end
	SeatRows()
	-- Kept away, though the game's own code shows them again.
	for index = 1, table.getn(GONE) do
		local thing = getglobal(GONE[index])
		if thing and not thing.suicGone then
			thing.suicGone, thing.suicShown = true, thing:IsShown()
			thing:Hide()
			thing.Show = function() end
		end
	end
end

local function PutBack()
	for frame, was in pairs(kept) do
		frame:ClearAllPoints()
		for index = 1, table.getn(was.points) do
			local point = was.points[index]
			frame:SetPoint(point[1], point[2], point[3], point[4], point[5])
		end
		if was.width then
			frame:SetWidth(was.width)
			frame:SetHeight(was.height)
		end
		if was.font then
			frame:SetFont(was.font[1] or STANDARD_TEXT_FONT, was.font[2], was.font[3])
		end
		if was.color then
			frame:SetTextColor(was.color[1], was.color[2], was.color[3])
		end
	end
	kept = {}
	for index = 1, table.getn(art) do
		art[index]:Show()
	end
	for name in pairs(GAME_ROWS) do
		local row = getglobal(name)
		if row then
			row:Show()
		end
	end
	if CharacterArmorFrameLabel then
		CharacterArmorFrameLabel:SetText("Armor:")
	end
	local rows = AZS_MORE_ROWS or {}
	for index = 1, table.getn(rows) do
		rows[index]:SetParent(AZSMoreStats)
		rows[index]:SetWidth(RUN_ROW_WIDTH)
	end
	for index = 1, table.getn(GONE) do
		local thing = getglobal(GONE[index])
		if thing and thing.suicGone then
			thing.suicGone = nil
			thing.Show = nil
			if thing.suicShown then
				thing:Show()
			end
		end
	end
	if stockWidth then
		CharacterFrame:SetWidth(stockWidth)
	end
end

-- A small panel, its title in its middle. Column 0 to 3.
local function SmallPanel(title, column, top, level, height)
	local frame = SUIC.Window(nil, title, groupWidth)
	frame:SetParent(panel)
	frame:SetFrameLevel(level)
	frame:SetHeight(height)
	frame:SetPoint("TOPLEFT", panel, "TOPLEFT", MIDDLE + column * (groupWidth + GROUP_GAP), top)
	frame.title:ClearAllPoints()
	frame.title:SetPoint("TOP", frame, "TOP", 0, -7)
	frame:Show()
	return frame
end

local function BuildMain()
	local frame = SmallPanel("Main stats", table.getn(GROUPS) - 1, SIDE_TOP, PaperDollFrame:GetFrameLevel() + 4, TOP_HEIGHT)
	panel.stats = {}
	for index = 1, table.getn(MAIN) do
		local stat = MAIN[index]
		local row = CreateFrame("Frame", nil, frame)
		row:SetWidth(groupWidth - 2 * INSET)
		row:SetHeight(MAIN_ROW)
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", INSET, -SUIC.TITLE - 4 - (index - 1) * MAIN_ROW)
		row:EnableMouse(true)
		row.stat = stat
		row.name = SUIC.Text(row, "GameFontNormal", TOP_TEXT)
		row.name:SetPoint("LEFT", row, "LEFT", 0, 0)
		row.name:SetText(stat[1])
		row.name:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
		row.value = SUIC.Text(row, "GameFontNormal", TOP_TEXT)
		row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
		row.value:SetTextColor(stat[4][1], stat[4][2], stat[4][3])
		row:SetScript("OnEnter", StatEnter)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		panel.stats[index] = row
	end
end

local function BuildLuck()
	local frame = SmallPanel("Luck", 0, SIDE_TOP, PaperDollFrame:GetFrameLevel() + 4, TOP_HEIGHT)
	panel.luck = frame
	frame:EnableMouse(true)
	frame:SetScript("OnEnter", LuckEnter)
	frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
	frame.note:SetTextColor(LUCK_COLOR[1], LUCK_COLOR[2], LUCK_COLOR[3])
	-- Two columns, each its head and the three rarities' odds in their colors.
	local plainAt, amuletAt = math.floor(groupWidth * 0.28), math.floor(groupWidth * 0.72)
	local top = -SUIC.TITLE - 3
	local heads = { { "Cards", plainAt }, { "Neck", amuletAt } }
	for index = 1, table.getn(heads) do
		local head = SUIC.Text(frame, "GameFontNormal", TOP_TEXT)
		head:SetPoint("TOP", frame, "TOPLEFT", heads[index][2], top)
		head:SetText(heads[index][1])
		head:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	end
	frame.rows = {}
	for index = 1, table.getn(RARITIES) do
		local color = RARITIES[index][1]
		local y = top - 14 - (index - 1) * ODDS_ROW
		local row = {}
		row.plain = SUIC.Text(frame, "GameFontHighlightSmall", TOP_TEXT)
		row.plain:SetPoint("TOP", frame, "TOPLEFT", plainAt, y)
		row.plain:SetTextColor(color[1], color[2], color[3])
		row.amulet = SUIC.Text(frame, "GameFontHighlightSmall", TOP_TEXT)
		row.amulet:SetPoint("TOP", frame, "TOPLEFT", amuletAt, y)
		row.amulet:SetTextColor(color[1], color[2], color[3])
		frame.rows[index] = row
	end
end

-- Hold the mouse on the hero and pull to turn it, on this page and the game's
-- (Survivor UI's).
local function Turnable(model)
	model:EnableMouse(true)
	model:SetScript("OnMouseDown", function()
		this.suicFrom = GetCursorPosition()
	end)
	model:SetScript("OnMouseUp", function()
		this.suicFrom = nil
	end)
	local stock = model:GetScript("OnUpdate")
	model:SetScript("OnUpdate", function()
		if stock then
			stock()
		end
		if this.suicFrom then
			local x = GetCursorPosition()
			this.rotation = (this.rotation or 0) + (x - this.suicFrom) * TURN
			this.suicFrom = x
			this:SetRotation(this.rotation)
		end
	end)
end

local function Build()
	panel = SUIC.Window("SUICCharacter", nil, WIDTH)
	panel:SetParent(PaperDollFrame)
	panel:SetFrameLevel(math.max(0, PaperDollFrame:GetFrameLevel() - 1))
	panel:SetHeight(HEIGHT)
	panel:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", LEFT, TOP)
	panel:EnableMouse(true)
	panel.rule:ClearAllPoints()
	panel.rule:SetPoint("TOPLEFT", panel, "TOPLEFT", 64, -52)
	panel.rule:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -52)
	panel.known = {}
	for key in pairs(ABOVE) do
		panel.known[key] = true
	end
	for index = 1, table.getn(GROUPS) do
		local group = GROUPS[index]
		group.frame = SmallPanel(group.title, index - 1, GROUPS_TOP, panel:GetFrameLevel() + 1, PANEL_HEIGHT)
		for each = 1, table.getn(group.rows) do
			panel.known[group.rows[each]] = true
		end
	end
	BuildMain()
	BuildLuck()
	-- The portrait's ring, our own art: the game's went with its page.
	local over = CreateFrame("Frame", nil, panel)
	over:SetAllPoints(panel)
	over:SetFrameLevel(PaperDollFrame:GetFrameLevel() + 2)
	ring = over:CreateTexture(nil, "OVERLAY")
	ring:SetTexture(RING)
	ring:SetWidth(RING_SIZE)
	ring:SetHeight(RING_SIZE)
	ring:SetPoint("CENTER", panel, "TOPLEFT", PORTRAIT_X, PORTRAIT_Y)
	if CharacterModelFrame then
		Turnable(CharacterModelFrame)
	end
	FindArt(PaperDollFrame)
	if CharacterAttributesFrame then
		FindArt(CharacterAttributesFrame)
	end
	panel:SetScript("OnShow", Stand)
	panel:SetScript("OnHide", PutBack)
	if AZS_UpdateMore then
		local stockMore = AZS_UpdateMore
		AZS_UpdateMore = function()
			stockMore()
			if panel:IsVisible() then
				SeatRows()
			end
		end
	end
end

function SUIC.RefreshCharacterPage()
	if not panel then
		return
	end
	if SUIC.DB().characterPage then
		panel:Show()
	else
		panel:Hide()
		-- The game's Run Stats box back at once, the page being open.
		if AZS_STATS and AZS_UpdateMore and PaperDollFrame:IsVisible() then
			AZS_UpdateMore()
		end
	end
end

SUIC.OnStart(function()
	if not PaperDollFrame or not CharacterFrame then
		return
	end
	Build()
	-- In front of the pieces that stay on the screen.
	CharacterFrame:SetFrameStrata("HIGH")
	SUIC.RefreshCharacterPage()
end)
