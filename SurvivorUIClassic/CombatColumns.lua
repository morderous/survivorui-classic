-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: Survivor UI's combat numbers, as an option (the options'
-- Combat text tab), in place of the game's. The numbers scroll in columns by
-- the hero, each column a piece of Move frames: the damage you deal climbs on
-- the left, its crits on the right in gold, the healing rises over the hero and
-- the damage you take falls under it. Hits from one source close together add
-- up in one number (x3). Each with its source's icon and the damage meter's
-- color, as chosen.
--
-- The hits come from the combat log, the ones you take from the combat text's
-- own feed, the heals from the game's healing meter as it changes (a trickle
-- gathers until it is worth a number). CombatText.lua keeps the game's own
-- numbers away meanwhile.

local BARLOW = "Interface\\AddOns\\SurvivorUIClassic\\Fonts\\BarlowCondensed-SemiBold.ttf"
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local LIFE = 1.3                -- seconds on screen, a crit's a fifth more
local MOST = 48                 -- numbers alive at once
local GAP = 15                  -- between numbers that start together
local CRIT_SIZE, CRIT_POP, POP_TIME = 22, 30, 0.09
local HIT_SIZE, TICK_SIZE = 15, 13
local ADD_WINDOW = 0.5          -- hits this close together add up
local HEAL_SHARE = 0.02         -- a heal worth a number: this much of max health
local FADE_IN, FADE_OUT, FADE_LIFT = 0.10, 0.50, 10

-- Five grid squares out (Move frames' lines are 32 apart); the heals over the
-- hero, the hits taken under it.
local COLUMNS = {
	dealt = { key = "numbersDealt", name = "Damage numbers", x = -160, y = 0, rise = 1, reach = 170 },
	crit = { key = "numbersCrit", name = "Crit numbers", x = 160, y = 0, rise = 1, reach = 170 },
	taken = { key = "numbersTaken", name = "Damage taken", x = 0, y = -167, rise = -1, reach = 70 },
	heal = { key = "numbersHeal", name = "Healing", x = 0, y = 181, rise = 1, reach = 70 },
}
local ORDER = { "dealt", "crit", "taken", "heal" }
SUIC.NUMBER_PIECES = { "numbersDealt", "numbersCrit", "numbersTaken", "numbersHeal" }
local ADD_UP = { dealt = true, crit = true, heal = true, taken = true }

local layer = CreateFrame("Frame", "SUICNumbers", UIParent)
layer:SetAllPoints(UIParent)
layer:SetFrameStrata("HIGH")

local texts = {}
local live = 0
local stacks = {}               -- [column] = { at, count }: numbers started together
local lastOf = {}               -- [kind, crit, periodic and source] = the number shown last

local function On()
	local db = SUIC.DB()
	return db.ctColumns and db.combatText
end

local function FreeText()
	for index = 1, table.getn(texts) do
		if not texts[index].live then
			return texts[index]
		end
	end
	if table.getn(texts) >= MOST then
		return nil
	end
	local text = layer:CreateFontString(nil, "OVERLAY")
	text.icon = layer:CreateTexture(nil, "OVERLAY")
	text.icon:SetPoint("RIGHT", text, "LEFT", -3, 0)
	text.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	text.icon:Hide()
	table.insert(texts, text)
	return text
end

-- Set only when it must: the same face set again still costs a font lookup.
local function Face(text, size, flags)
	local share = tonumber(SUIC.DB().ctSize) or 1
	local key = size..flags..share
	if text.faceKey ~= key then
		text.faceKey = key
		text:SetFont(BARLOW, math.max(6, math.floor(size * share + 0.5)), flags)
	end
end

-- Where a column's numbers start: the middle of its piece, in the screen's units.
local function StartOf(kind)
	local frame = COLUMNS[kind].frame
	local x, y = frame:GetCenter()
	if not x then
		return GetScreenWidth() / 2 + COLUMNS[kind].x, GetScreenHeight() / 2 + COLUMNS[kind].y
	end
	local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return x * ratio, y * ratio
end

-- The meter's lookup goes through the spellbook, the talents and the items:
-- kept a while, so a fight of many hits asks once per source.
local iconCache, iconCacheAt = {}, 0
local function SourceIcon(source)
	if GetTime() - iconCacheAt > 30 then
		iconCache, iconCacheAt = {}, GetTime()
	end
	if iconCache[source] == nil then
		local icon = SUIC.IconOf(source)
		iconCache[source] = icon ~= QUESTION and icon or false
	end
	return iconCache[source]
end

-- The number's icon and the meter's color, as chosen.
local function Dress(text, kind, crit, source)
	local db = SUIC.DB()
	local dealt = kind == "dealt" or kind == "crit"
	if dealt and source and db.ctColors and SUIC.MeterColor then
		local color = SUIC.MeterColor(source)
		text:SetTextColor(color[1], color[2], color[3])
	end
	local icon = (dealt or kind == "heal") and source and db.ctIcons and SourceIcon(source)
	if icon then
		local edge = math.floor((crit and CRIT_SIZE or 16) * (tonumber(db.ctSize) or 1) + 0.5)
		text.icon:SetTexture(icon)
		text.icon:SetWidth(edge)
		text.icon:SetHeight(edge)
		text.icon:SetAlpha(1)
		text.icon:Show()
	else
		text.icon:Hide()
	end
end

local function Label(kind, sum, count)
	local label = SUIC.Short(sum)
	if kind == "taken" then
		label = "-"..label
	elseif kind == "heal" then
		label = "+"..label
	end
	if count > 1 then
		label = label.." |cffc8c8c8x"..count.."|r"
	end
	return label
end

-- In the number just shown from the same source, its sum and how many (x3).
local function AddUp(key, kind, amount)
	local text = lastOf[key]
	if not (SUIC.DB().ctAdd and ADD_UP[kind] and text and text.live and text.addKey == key and text.age < ADD_WINDOW) then
		return false
	end
	text.sum = text.sum + amount
	text.count = text.count + 1
	text:SetText(Label(kind, text.sum, text.count))
	return true
end

local function Spawn(kind, amount, crit, periodic, source)
	local db = SUIC.DB()
	amount = tonumber(amount)
	if not amount or (periodic and not db.ctPeriodic) or (kind == "taken" and not db.ctHitsTaken)
		or (kind == "heal" and not db.ctHeals) then
		return
	end
	-- The crits in a column of their own, on the right, or with the rest.
	if kind == "dealt" and crit and db.ctCritColumn then
		kind = "crit"
	end
	local key = kind..(crit and "!" or "")..(periodic and "~" or "")..(source or "")
	if AddUp(key, kind, amount) then
		return
	end
	local text = FreeText()
	if not text then
		return
	end
	text.sum, text.count, text.addKey = amount, 1, key
	lastOf[key] = text
	local column = COLUMNS[kind]
	local startX, startY = StartOf(kind)
	local now = GetTime()
	local stack = stacks[kind] or { at = 0, count = 0 }
	stacks[kind] = stack
	if now - stack.at < 0.12 then
		stack.count = math.mod(stack.count + 1, 5)
	else
		stack.count = 0
	end
	stack.at = now

	Face(text, crit and CRIT_POP or (periodic and TICK_SIZE or HIT_SIZE), crit and "THICKOUTLINE" or "OUTLINE")
	if kind == "taken" then
		text:SetTextColor(1, 0.22, 0.22)
	elseif kind == "heal" then
		text:SetTextColor(0.3, 1, 0.4)
	elseif crit then
		text:SetTextColor(1, 0.76, 0.08)
	elseif periodic then
		text:SetTextColor(0.8, 0.8, 0.8)
	else
		text:SetTextColor(1, 1, 1)
	end
	text:SetText(Label(kind, amount, 1))
	Dress(text, kind, crit, source)
	text.live = true
	text.crit = crit
	text.popped = nil
	text.life = crit and LIFE * 1.2 or LIFE
	text.age = 0
	-- Numbers that start together line up, the later ones a line behind.
	text.x = startX
	text.y = startY - column.rise * stack.count * GAP
	text.rise = column.reach * column.rise
	text:SetAlpha(0)
	text:Show()
	live = live + 1
end

-- In and out: alpha only, and a little lift; a font size set frame by frame
-- would cost.
layer:SetScript("OnUpdate", function()
	if live == 0 then
		return
	end
	for index = 1, table.getn(texts) do
		local text = texts[index]
		if text.live then
			text.age = text.age + arg1
			local t = text.age / text.life
			if text.crit and not text.popped and text.age >= POP_TIME then
				text.popped = true
				Face(text, CRIT_SIZE, "THICKOUTLINE")
			end
			if t >= 1 then
				text.live = nil
				text:Hide()
				text.icon:Hide()
				live = live - 1
			else
				local eased = 1 - (1 - t) * (1 - t) * 0.5 - 0.5 * (1 - t)
				local alpha, lift = 1, 0
				if t < FADE_IN then
					local part = t / FADE_IN
					alpha = part * part * (3 - 2 * part)
					lift = (1 - alpha) * FADE_LIFT
				elseif t > FADE_OUT then
					local part = (t - FADE_OUT) / (1 - FADE_OUT)
					alpha = 1 - part * part
				end
				local down = text.rise < 0 and -1 or 1
				text:ClearAllPoints()
				text:SetPoint("CENTER", UIParent, "BOTTOMLEFT", text.x, text.y + text.rise * eased - down * lift)
				text:SetAlpha(alpha)
				text.icon:SetAlpha(alpha)
			end
		end
	end
end)

------------------------------------------------------------------------------
-- The hits, from the combat log.

-- A demon's spell in the log's own words goes by the meter's name for it; the
-- hero holding the same spell keeps it. Keys as the game's list has them.
local PET_CASTS = {
	["Fireball"] = { "fireball", "Imp's Fireball" },
	["Firebolt"] = { "firebolt", "Imp's Firebolt" },
	["Inferno"] = { "inferno", "Infernal's Inferno" },
	["Hellfire"] = { "hellfire", "Infernal's Hellfire" },
	["Searing Pain"] = { "searing_pain", "Pit Lord's Felseeker" },
	["Shadow Bolt"] = { "shadow_bolt", "Doomguard's Shadow Bolt" },
}

-- The game's meter adds a hunter's beasts up in one line, Pets: the numbers go
-- by that name too, for its color and icon. Another class's summon only if the
-- meter has it so; a warlock's demons have a line each.
local BEASTS = { ["Wolf"] = true, ["Raptor"] = true }

local function InPets(name)
	local _, class = UnitClass("player")
	if class == "HUNTER" and BEASTS[name] then
		return true
	end
	local data = AZS_METER or {}
	local pets, own, summoned = false, false, false
	for index = 1, table.getn(data) do
		pets = pets or data[index].name == "Pets"
		own = own or data[index].name == name
	end
	if not pets or own then
		return false
	end
	local groups = AZS_GetSummonGroups and AZS_GetSummonGroups() or {}
	for index = 1, table.getn(groups) do
		summoned = summoned or groups[index].name == name
	end
	return summoned
end

local function Holds(key)
	for index = 1, table.getn(AZS_SPELLS or {}) do
		local entry = AZS_SPELLS[index]
		if (entry.key or entry[1]) == key then
			return true
		end
	end
	return false
end

-- The name a hit's source goes by in the meter: "Your Fireball" is Fireball,
-- "You" Melee, a pet its own name; the Searing Totem's shots come as a Fire
-- "Attack", Call of Flame's blast as a Fire Nova.
local function SourceOf(who, line)
	local _, _, spell = string.find(who or "", "^Your (.+)$")
	local name = spell or (who == "You" and "Melee") or who
	local _, _, owner = string.find(name, "^(.+)'s ")
	if not spell and InPets(owner or name) then
		return "Pets"
	end
	if name == "Attack" and string.find(line, " Fire damage", 1, true) and Holds("searing_totem") then
		return "Searing Totem"
	elseif name == "Fire Nova" and Holds("call_of_flame") and not Holds("fire_nova") then
		return "Call of Flame"
	end
	local cast = PET_CASTS[name]
	if cast and not Holds(cast[1]) then
		return cast[2]
	end
	return name
end

local function Parse(line)
	local _, who, target, amount
	if string.find(line, " crit", 1, true) then
		_, _, who, target, amount = string.find(line, "^(.-) crits (.+) for (%d+)")
		if not target then
			_, _, who, target, amount = string.find(line, "^(.-) crit (.+) for (%d+)")
		end
		if target then
			return amount, true, false, SourceOf(who, line)
		end
	end
	if string.find(line, " hit", 1, true) then
		_, _, who, target, amount = string.find(line, "^(.-) hits (.+) for (%d+)")
		if not target then
			_, _, who, target, amount = string.find(line, "^(.-) hit (.+) for (%d+)")
		end
		if target then
			return amount, false, false, SourceOf(who, line)
		end
	end
	-- "Kobold Vermin suffers 12 Fire damage from your Flame Shock."
	local spell
	_, _, target, amount, spell = string.find(line, "^(.+) suffers (%d+) .+ from your (.-)%.?$")
	if target then
		return amount, false, true, spell
	end
end

local TAKEN_TYPES = { DAMAGE = true, DAMAGE_CRIT = true, SPELL_DAMAGE = true }
local HEAL_TYPES = { HEAL = true, HEAL_CRIT = true, PERIODIC_HEAL = true }
SUIC.NUMBER_TYPES = { DAMAGE = true, DAMAGE_CRIT = true, SPELL_DAMAGE = true, HEAL = true, HEAL_CRIT = true, PERIODIC_HEAL = true }

local EVENTS = {
	"CHAT_MSG_COMBAT_SELF_HITS", "CHAT_MSG_SPELL_SELF_DAMAGE",
	"CHAT_MSG_COMBAT_PET_HITS", "CHAT_MSG_SPELL_PET_DAMAGE",
	"CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", "COMBAT_TEXT_UPDATE",
}

local listener = CreateFrame("Frame")
listener:SetScript("OnEvent", function()
	if event == "COMBAT_TEXT_UPDATE" then
		if TAKEN_TYPES[arg1] and tonumber(arg2) then
			Spawn("taken", arg2, arg1 == "DAMAGE_CRIT")
		elseif HEAL_TYPES[arg1] and not AZS_GetHealing then
			-- A heal: arg2 the healer, arg3 the health it gave.
			local amount = tonumber(arg3) or tonumber(arg2)
			if amount and amount > 0 then
				Spawn("heal", math.floor(amount + 0.5), arg1 == "HEAL_CRIT", arg1 == "PERIODIC_HEAL")
			end
		end
		return
	end
	local amount, crit, periodic, source = Parse(arg1 or "")
	if amount then
		Spawn("dealt", amount, crit, periodic, source)
	end
end)

-- The heals: the game's own never reach the combat text's feed, so they are
-- read from its healing meter, each source's health given this run, as it
-- changes: what a source gave since last shown, with its icon.
local healSeen, healPending = {}, {}
local healAt, healPrimed

local healWatch = CreateFrame("Frame")
healWatch:SetScript("OnUpdate", function()
	if not AZS_HEALING or AZS_HEALING_UPDATED == healAt then
		return
	end
	healAt = AZS_HEALING_UPDATED
	local on = healPrimed and On()
	local worth = math.max(1, HEAL_SHARE * (UnitHealthMax("player") or 0))
	for index = 1, table.getn(AZS_HEALING) do
		local line = AZS_HEALING[index]
		local name, given = line.name, tonumber(line.dmg)
		if name and given then
			local seen = healSeen[name]
			if not seen or given < seen then
				-- A source new since the last read, or a new run's.
				healPending[name] = (seen and given) or (healPrimed and given) or 0
			else
				healPending[name] = (healPending[name] or 0) + given - seen
			end
			healSeen[name] = given
			if healPending[name] >= worth then
				if on then
					Spawn("heal", math.floor(healPending[name] + 0.5), false, false, name)
				end
				healPending[name] = 0
			end
		end
	end
	healPrimed = true
end)

------------------------------------------------------------------------------
-- The columns in Move frames, once the option is first on.

local placed

local function Place()
	if placed then
		return
	end
	placed = true
	for index = 1, table.getn(ORDER) do
		local column = COLUMNS[ORDER[index]]
		local frame = CreateFrame("Frame", "SUIC"..column.key, UIParent)
		frame:SetWidth(120)
		frame:SetHeight(26)
		column.frame = frame
		local function Home(f)
			f:SetPoint("CENTER", UIParent, "CENTER", column.x, column.y)
		end
		Home(frame)
		SUIC.AddPiece(column.key, column.name, frame, Home)
	end
end

function SUIC.ApplyCombatColumns()
	local on = On()
	if on then
		Place()
	end
	for index = 1, table.getn(EVENTS) do
		if on then
			listener:RegisterEvent(EVENTS[index])
		else
			listener:UnregisterEvent(EVENTS[index])
		end
	end
end

-- A sample of every number as set (the options' Combat text tab), from the
-- meter's first source.
local sample = CreateFrame("Frame")
sample:Hide()
sample:SetScript("OnUpdate", function()
	this.age = this.age + arg1
	while this.steps[this.at] and this.steps[this.at][1] <= this.age do
		this.steps[this.at][2]()
		this.at = this.at + 1
	end
	if not this.steps[this.at] then
		this:Hide()
	end
end)

function SUIC.CombatSample()
	if not On() then
		return
	end
	local data = AZS_GetMeter and AZS_GetMeter() or {}
	local source = data[1] and data[1].name or "Melee"
	sample.steps = {
		{ 0, function() Spawn("dealt", 128, false, false, source) end },
		{ 0.05, function() Spawn("dealt", 131, false, false, source) end },
		{ 0.35, function() Spawn("dealt", 352, true, false, source) end },
		{ 0.5, function() Spawn("taken", 9) end },
		{ 0.6, function() Spawn("taken", 6) end },
		{ 0.8, function() Spawn("heal", 42, false, false, source) end },
	}
	sample.at, sample.age = 1, 0
	sample:Show()
end

SUIC.OnStart(function()
	SUIC.ApplyCombatColumns()
end)
