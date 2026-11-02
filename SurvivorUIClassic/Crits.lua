-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: each spell's crits and hits this run, read off the combat
-- log, which the game writes in English whatever its language ("Your
-- Lightning Bolt crits Kobold Vermin for 168.", "Magma Totem's Magma Totem
-- crits...", "Searing Totem's Attack crits..."): kept by the spell's key as
-- the game's list names it, a totem's by its totem's when that is the build's.
-- A new run starts over. The build list shows the biggest crit, and the rest
-- as its tooltip (BuildList.lua).

local seen = {}                 -- [key] = its crits' and its normal hits' numbers
local runSeen

local EVENTS = {
	"CHAT_MSG_SPELL_SELF_DAMAGE", "CHAT_MSG_COMBAT_SELF_HITS",
	"CHAT_MSG_SPELL_PET_DAMAGE", "CHAT_MSG_COMBAT_PET_HITS",
}

-- A line's three ways: the hero's spell, a pet's or a totem's, the hero's melee.
local CRIT = { "^Your (.+) crits (.+) for (%d+)", "^(.+)'s (.+) crits (.+) for (%d+)", "^You crit (.+) for (%d+)" }
local HIT = { "^Your (.+) hits (.+) for (%d+)", "^(.+)'s (.+) hits (.+) for (%d+)", "^You hit (.+) for (%d+)" }

local function InBuild(name)
	return name and SUIC.SpellSlot(name) ~= nil
end

local function Read(message, ways)
	local _, _, ability, _, amount = string.find(message, ways[1])
	if not ability then
		local owner, spell
		_, _, owner, spell, _, amount = string.find(message, ways[2])
		if owner then
			ability = (not InBuild(spell) and InBuild(owner)) and owner or spell
		end
	end
	if not ability then
		_, _, _, amount = string.find(message, ways[3])
		ability = amount and "Melee" or nil
	end
	return ability, tonumber(amount)
end

local function Record(ability, amount, crit)
	local key = SUIC.KeyOf(ability)
	local one = seen[key]
	if not one then
		one = { crits = 0, critSum = 0, hits = 0, hitSum = 0 }
		seen[key] = one
	end
	if crit then
		one.crits = one.crits + 1
		one.critSum = one.critSum + amount
		one.lastCrit = amount
		one.least = math.min(one.least or amount, amount)
		if not one.best or amount > one.best then
			one.best = amount
			one.bestAt = AZS_GetRunTime and AZS_GetRunTime() or 0
		end
	else
		one.hits = one.hits + 1
		one.hitSum = one.hitSum + amount
		one.lastHit = amount
	end
end

-- The game's own feed of the hero's hits, each saying its meter line (its
-- 0.139), kept a second for the combat log's line to find it.
local hits = {}
local cursor

local function ReadHits()
	local result = AZS_GetCombatTextEvents(cursor, 256)
	if not result then
		cursor = nil
		return
	end
	cursor = result.cursor
	local now = GetTime()
	local events = result.events or {}
	for index = 1, table.getn(events) do
		local hit = events[index]
		if hit.kind == "damage" and hit.meterSource then
			table.insert(hits, { at = now, amount = hit.amount, crit = hit.critical, ability = hit.abilityName,
				meter = hit.meterSource, key = hit.meterSourceKey })
		end
	end
	while hits[1] and now - hits[1].at > 1 do
		table.remove(hits, 1)
	end
end

-- The meter's line for a line of the combat log, when it is not the spell the
-- line names: a Flametongue Weapon's Fire Nova, a demon's own spell. Nil for the
-- spell itself and for a hit not found: by its amount and crit, the same spell's
-- first.
function SUIC.HitLine(name, line)
	if not AZS_GetCombatTextEvents then
		return nil
	end
	local _, _, amount = string.find(line, " for (%d+)")
	amount = tonumber(amount)
	if not amount then
		return nil
	end
	ReadHits()
	local crit = string.find(line, " crit", 1, true) ~= nil
	local found
	for index = table.getn(hits), 1, -1 do
		local hit = hits[index]
		if hit.amount == amount and (not hit.crit) == (not crit) then
			found = found or hit
			if hit.ability == name then
				found = hit
				break
			end
		end
	end
	if not found or found.meter == found.ability or found.meter == SUIC.MeterName(found.key) then
		return nil
	end
	return found.meter
end

local function Note(message)
	local crit = string.find(message, " crit", 1, true)
	if not crit and not string.find(message, " hit", 1, true) then
		return
	end
	local ability, amount = Read(message, crit and CRIT or HIT)
	if ability and amount then
		Record(SUIC.HitLine(ability, message) or ability, amount, crit)
	end
end

-- What this run has seen of a spell by its key, or nil.
function SUIC.SpellRecord(key)
	if AZS_ZONE_UPDATED ~= runSeen then
		runSeen = AZS_ZONE_UPDATED
		seen = {}
	end
	return seen[key]
end

-- The biggest crit this run of a spell by its key, or nil.
function SUIC.BiggestCrit(key)
	local one = SUIC.SpellRecord(key)
	return one and one.best
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function()
	if arg1 then
		SUIC.SpellRecord("")
		Note(arg1)
	end
end)

SUIC.OnStart(function()
	for index = 1, table.getn(EVENTS) do
		events:RegisterEvent(EVENTS[index])
	end
end)
