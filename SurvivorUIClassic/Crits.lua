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
--
-- A swarm's hits come by the thousand in one frame, each with its line
-- (Buncha's, 2026-11-10: the game stopped responding). Each line looking
-- through every hit of the last second made a frame's work grow as the square
-- of its hits, so the hits are kept twice: in a ring, oldest first, to let
-- them go after their second; and by amount and crit, in short lists, where a
-- line finds its hit among the few of its own amount, looking at so many at
-- most. The feed is read once a frame (and again for a line whose hit is not
-- there yet), and the hits' tables are given out again.
local feed = {
	ring = {}, first = 1, last = 0,     -- the hits, oldest first
	byAmount = {},                      -- [amount, -1 - amount for a crit] = { head, tail, hits }
	spare = {}, spareLists = {},        -- tables to give out again
	asked = {},                         -- the last line's answer, for the same line asked again
	KEEP = 1,                           -- seconds a hit waits for its line
	MOST = 4096,                        -- hits kept at most
	LOOK = 32,                          -- hits a line looks at, at most
	READS = 16,                         -- reads of 256 hits a frame, at most
}

local function Key(amount, crit)
	return crit and -1 - amount or amount
end

-- The oldest hit let go, from its list too: it is the oldest there.
function feed.DropOldest()
	local hit = feed.ring[feed.first]
	feed.ring[feed.first] = nil
	feed.first = feed.first + 1
	local list = feed.byAmount[hit.amountKey]
	if list then
		list[list.head] = nil
		list.head = list.head + 1
		if list.head > list.tail then
			feed.byAmount[hit.amountKey] = nil
			table.insert(feed.spareLists, list)
		end
	end
	table.insert(feed.spare, hit)
end

function feed.Read()
	local now = GetTime()
	feed.readAt = now
	for _ = 1, feed.READS do
		local result = AZS_GetCombatTextEvents(feed.cursor, 256)
		if not result then
			feed.cursor = nil
			break
		end
		feed.cursor = result.cursor
		local events = result.events or {}
		local count = table.getn(events)
		for index = 1, count do
			local one = events[index]
			local amount = tonumber(one.amount)
			if one.kind == "damage" and one.meterSource and amount then
				local hit = table.remove(feed.spare) or {}
				hit.at, hit.amount, hit.crit, hit.ability = now, amount, one.critical, one.abilityName
				hit.meter, hit.key = one.meterSource, one.meterSourceKey
				hit.amountKey = Key(amount, hit.crit)
				feed.last = feed.last + 1
				feed.ring[feed.last] = hit
				local list = feed.byAmount[hit.amountKey]
				if not list then
					list = table.remove(feed.spareLists) or {}
					list.head, list.tail = 1, 0
					feed.byAmount[hit.amountKey] = list
				end
				list.tail = list.tail + 1
				list[list.tail] = hit
			end
		end
		if count < 256 then
			break
		end
	end
	while feed.first <= feed.last and (now - feed.ring[feed.first].at > feed.KEEP
		or feed.last - feed.first >= feed.MOST) do
		feed.DropOldest()
	end
end

-- The last hit of its amount and crit, that spell's when there is one.
function feed.Last(amount, crit, name)
	local list = feed.byAmount[Key(amount, crit)]
	if not list then
		return nil
	end
	local found
	local stop = math.max(list.head, list.tail - feed.LOOK + 1)
	for index = list.tail, stop, -1 do
		local hit = list[index]
		if hit.ability == name then
			return hit
		end
		found = found or hit
	end
	return found
end

function feed.Line(name, line)
	local _, _, amount = string.find(line, " for (%d+)")
	amount = tonumber(amount)
	if not amount then
		return nil
	end
	-- Read once a frame (GetTime holds for the frame).
	if feed.readAt ~= GetTime() then
		feed.Read()
	end
	local crit = string.find(line, " crit", 1, true) ~= nil
	local found = feed.Last(amount, crit, name)
	if not found then
		feed.Read()
		found = feed.Last(amount, crit, name)
	end
	if not found or found.meter == found.ability or found.meter == SUIC.MeterName(found.key) then
		return nil
	end
	return found.meter
end

-- The meter's line for a line of the combat log, when it is not the spell the
-- line names: a Flametongue Weapon's Fire Nova, a demon's own spell. Nil for the
-- spell itself and for a hit not found: by its amount and crit, the same spell's
-- first. The same line asked again in the same frame (the combat numbers and
-- this file each ask) has the same answer, kept.
function SUIC.HitLine(name, line)
	if not AZS_GetCombatTextEvents then
		return nil
	end
	local asked, now = feed.asked, GetTime()
	if asked.line == line and asked.name == name and asked.at == now then
		return asked.answer
	end
	local answer = feed.Line(name, line)
	asked.line, asked.name, asked.at, asked.answer = line, name, now, answer
	return answer
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
