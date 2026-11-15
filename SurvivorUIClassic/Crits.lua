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

-- A swarm sends tens of thousands of hits a second (Buncha's, 2026-11-10: the
-- game at 0.1 fps in endless, the numbers still on). Past so many lines in one
-- frame, each handler takes the rest of that frame's lines the cheap way
-- (CombatColumns.lua: one number with no source; here: only a crit that could
-- be a spell's best), so a frame's work stops growing with the swarm.
SUIC.LINES_A_FRAME = 200
local lineCount = {}

-- True for a line past the frame's share of the handler named.
function SUIC.Overflow(key)
	local now = GetTime()
	local one = lineCount[key]
	if not one then
		one = { at = now, n = 0 }
		lineCount[key] = one
	elseif one.at ~= now then
		one.at, one.n = now, 0
	end
	one.n = one.n + 1
	return one.n > SUIC.LINES_A_FRAME
end

-- The smallest of the spells' biggest crits this run: a crit under it beats
-- none of them.
local critFloor, critFloorFresh
local function CritFloor()
	if not critFloorFresh then
		critFloor, critFloorFresh = nil, true
		for _, one in pairs(seen) do
			if one.best and (not critFloor or one.best < critFloor) then
				critFloor = one.best
			end
		end
	end
	return critFloor or 0
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
			critFloorFresh = nil
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

------------------------------------------------------------------------------
-- The hero's hits by the meter's line, for the damage meter's detail of a
-- source (Meter.lua), which the game's meter API has no count of: each hit of
-- the game's feed counted under the line the meter puts it on ("Frenzy" for
-- the Multi-Shot it fires), four times over: the whole run; since the meter's
-- Reset; the boss fight (while the game says one is on; a new fight starts it
-- over); and second by second, for the last ones. Each count: n, the hits;
-- crits; sum, their damage as dealt (whole, even past the enemy's last
-- health: more than the meter's total); best, the biggest. Only while the
-- meter asks for it (on). The pets come all as one line, "Pets".
local blows = {
	lines = {},                     -- [the line's name] = { run, since, boss, now = the seconds' ring }
	SECONDS = 128,                  -- the ring: more than the meter's longest window
	window = { n = 0, crits = 0, sum = 0, best = 0 },
}
SUIC.Blows = blows

local function Fresh()
	return { n = 0, crits = 0, sum = 0, best = 0 }
end

-- Once a frame: a new run starts all over, a new boss fight its own count.
function blows.Frame(now)
	blows.at = now
	blows.second = math.floor(now)
	local context = SUIC.MeterFeed and SUIC.MeterFeed.Context()
	local run = context and context.runId
	if run ~= blows.run then
		blows.run, blows.lines, blows.fight, blows.lost = run, {}, nil, nil
	end
	local fight = context and context.encounter
	blows.fighting = type(fight) == "table" and fight.state == "active"
	if blows.fighting and fight.encounterId ~= blows.fight then
		blows.fight = fight.encounterId
		for _, line in pairs(blows.lines) do
			line.boss = nil
		end
	end
end

local function Count(tally, amount, crit)
	tally.n = tally.n + 1
	tally.sum = tally.sum + amount
	if crit then
		tally.crits = tally.crits + 1
	end
	if amount > tally.best then
		tally.best = amount
	end
end

function blows.Seen(name, amount, crit, now)
	if blows.at ~= now then
		blows.Frame(now)
	end
	if not blows.run then
		return
	end
	local line = blows.lines[name]
	if not line then
		line = { run = Fresh(), since = Fresh(), now = {} }
		blows.lines[name] = line
	end
	Count(line.run, amount, crit)
	Count(line.since, amount, crit)
	if blows.fighting then
		if not line.boss then
			line.boss = Fresh()
		end
		Count(line.boss, amount, crit)
	end
	-- This second's count, in the place an old second's had.
	local second = blows.second
	local place = math.mod(second, blows.SECONDS) + 1
	local bucket = line.now[place]
	if not bucket then
		bucket = Fresh()
		line.now[place] = bucket
	end
	if bucket.at ~= second then
		bucket.at, bucket.n, bucket.crits, bucket.sum, bucket.best = second, 0, 0, 0, 0
	end
	Count(bucket, amount, crit)
end

-- The meter's Reset: the counts since it start over.
function blows.Mark()
	for _, line in pairs(blows.lines) do
		line.since = Fresh()
	end
end

-- A line's count by its name: span "run", "since" (Reset), "boss", or "now"
-- with the seconds back. Nil for a line no hit of this run was seen on; a
-- count of none where the span has none. The table is the meter's to read,
-- not to keep.
function blows.Of(name, span, seconds)
	local now = GetTime()
	if blows.at ~= now then
		blows.Frame(now)
	end
	local line = blows.lines[name]
	if not line then
		return nil
	end
	local sum = blows.window
	sum.n, sum.crits, sum.sum, sum.best = 0, 0, 0, 0
	if span ~= "now" then
		return line[span] or sum
	end
	local from = math.floor(now) - (seconds or 30)
	for place = 1, blows.SECONDS do
		local bucket = line.now[place]
		if bucket and bucket.at > from then
			sum.n, sum.crits, sum.sum = sum.n + bucket.n, sum.crits + bucket.crits, sum.sum + bucket.sum
			if bucket.best > sum.best then
				sum.best = bucket.best
			end
		end
	end
	return sum
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

-- Each enemy's last hit's place, by the enemy's name: where a hit goes that
-- no line of the feed answers for (a tick, a pet's, one read too late).
feed.lastOf = {}

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
		-- Hits the game let go before they were read: the counts are short.
		local dropped = tonumber(result.droppedCount) or 0
		if dropped > 0 and dropped ~= feed.dropped then
			blows.lost = true
		end
		feed.dropped = dropped
		local events = result.events or {}
		local count = table.getn(events)
		for index = 1, count do
			local one = events[index]
			local amount = tonumber(one.amount)
			if one.kind == "damage" and one.meterSource and amount then
				if blows.on then
					blows.Seen(one.meterSource, amount, one.critical, now)
				end
				local hit = table.remove(feed.spare) or {}
				hit.at, hit.amount, hit.crit, hit.ability = now, amount, one.critical, one.abilityName
				hit.meter, hit.key = one.meterSource, one.meterSourceKey
				hit.id, hit.target, hit.held = one.anchorId, one.targetName, nil
				if one.anchorId and one.targetName then
					feed.lastOf[one.targetName] = one.anchorId
				end
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

-- The place in the world of a combat log line's hit (the game's 0.138), for
-- the combat numbers over the enemies (CombatColumns.lua): the last hit of its
-- amount and crit on that target not yet given out; a hit not found goes where
-- that enemy was last hit. Nil without the feed, and for an enemy never hit.
function SUIC.HitAnchor(target, amount, crit)
	amount = tonumber(amount)
	if not (AZS_GetCombatTextEvents and amount) then
		return nil
	end
	if feed.readAt ~= GetTime() then
		feed.Read()
	end
	local list = feed.byAmount[Key(amount, crit)]
	if not list then
		return target and feed.lastOf[target]
	end
	local stop = math.max(list.head, list.tail - feed.LOOK + 1)
	for index = list.tail, stop, -1 do
		local hit = list[index]
		if hit.id and not hit.held and hit.target == target then
			hit.held = true
			return hit.id
		end
	end
	return target and feed.lastOf[target]
end

-- The feed read now, where this frame has not yet: for the meter's counts,
-- which want every hit, not only those a combat log's line asks after.
function SUIC.ReadHits()
	if blows.on and AZS_GetCombatTextEvents and feed.readAt ~= GetTime() then
		feed.Read()
	end
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
		critFloorFresh = nil
	end
	return seen[key]
end

-- The biggest crit this run of a spell by its key, or nil.
function SUIC.BiggestCrit(key)
	local one = SUIC.SpellRecord(key)
	return one and one.best
end

-- Past the frame's share of lines, a line is read only when it is a crit that
-- could be a spell's best: the plain finds first.
local function Worth(message)
	if not string.find(message, " crit", 1, true) then
		return false
	end
	local at = string.find(message, " for ", 1, true)
	if not at then
		return false
	end
	local _, _, amount = string.find(message, "^(%d+)", at + 5)
	amount = tonumber(amount)
	return amount ~= nil and amount > CritFloor()
end

-- A Hunter's White Devilsaur (an achievement's look): the wolf and the raptor
-- each take its look and its name, "White Devilsaur hits Kobold Vermin for
-- 991.", while the game's meter still has them as Wolf and Raptor, and nothing
-- else says the look is on. So the combat log's first such line of a run says
-- it: the meter then has the two as one line by that name (Meter.lua).
local PET_LOOK = "White Devilsaur"
local petLook = {}

-- The look one's own pets wear this run, or nil.
function SUIC.PetLook()
	if petLook.run ~= nil and petLook.run == AZS_ZONE_UPDATED then
		return PET_LOOK
	end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function()
	if arg1 then
		if event == "CHAT_MSG_COMBAT_PET_HITS" and petLook.run ~= AZS_ZONE_UPDATED and string.find(arg1, "^White Devilsaur ") then
			petLook.run = AZS_ZONE_UPDATED
		end
		SUIC.SpellRecord("")
		if SUIC.Overflow("crits") and not Worth(arg1) then
			return
		end
		Note(arg1)
	end
end)

SUIC.OnStart(function()
	for index = 1, table.getn(EVENTS) do
		events:RegisterEvent(EVENTS[index])
	end
end)
