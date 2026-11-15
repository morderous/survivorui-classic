-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the runs kept as they end (0.2.23). This file keeps
-- them and shows them in a window (/suic history, the Build panel's button).
--
-- A run is kept when it ends: won, fallen, or left from the menu. Each one is
-- some 4 kB in the saved file (no tooltips kept, unlike Survivor UI's), the
-- last hundred by default, in a saved variable of their own
-- (SurvivorUIClassicRuns) so the settings stay small and resetting them does
-- not take the runs.
--
-- The game has no event for a run's end: its phase is looked at twice a
-- second (dead, victory), and its own end message (AZS_END, read with
-- AZS_GetRunSummary) brings the end screen's numbers and the runs left from
-- the menu. As Survivor UI's Run History does (its RunHistory.lua), whose
-- runs this one neither reads nor writes: the two never run together.
--
-- A run kept:
--   at (time()), result ("victory", "dead", "left"), hero, race, class,
--   classKey, zone, heroic, hyper, affixes, mods,
--   time, level, kills, elites, guardians, bosses, gold, caches, magnets,
--   taken, damage, dps, healing, talentXp, talents ("0;Name;5;Icon|..."),
--   trees { the three trees' names },
--   build[] { key, name, rank, icon, cd, racial, dmg, share, crit },
--   sources[] { name, dmg, share, proc, icon },
--   jewelry[] { slot, link, icon },
--   loot[] { name, color, count, new, at, item, icon }, marks,
--   schedule[] { name, at, fell, final, state },
--   stats { [the game's key] = number },
--   party[] { name, class, dmg, dps, me }   (co-op only),
--   pinned (true: never dropped to make room),
--   endless ("going", "dead", "left") and won { time, level, kills, ... }:
--   a run gone on past its victory is kept as it ended, its numbers at the
--   victory in won.

local KEEP = 100                -- the runs kept, by default (historyKeep)
local SOURCES = 10
local LOOT = 12
local JEWELRY_SLOTS = { 2, 11, 12, 13, 14 }
local HYPER_LONGEST = 720       -- a Hyper run's final boss comes by then (480 to 600 s; 960 on without)

local function Num(value)
	return tonumber(value) or 0
end

-- A whole number, and a share to three places: the saved file's room.
local function Whole(value)
	return math.floor(Num(value) + 0.5)
end

local function Share(value)
	return math.floor(Num(value) * 1000 + 0.5) / 1000
end

local function Runs()
	if type(SurvivorUIClassicRuns) ~= "table" then
		SurvivorUIClassicRuns = {}
	end
	local saved = SurvivorUIClassicRuns
	saved.version = saved.version or 1
	if type(saved.runs) ~= "table" then
		saved.runs = {}
	end
	return saved.runs
end

-- The runs kept, the newest first.
function SUIC.RunHistory()
	return Runs()
end

------------------------------------------------------------------------------
-- The party: in one, and down in one (not the run's end).

local function Down()
	local revive = AZS_GetRevive and AZS_GetRevive()
	return type(revive) == "table" and Num(revive.down) == 1
end

local function InParty()
	if GetNumPartyMembers and Num(GetNumPartyMembers()) > 0 then
		return true
	end
	if type(AZS_PARTY) == "table" and table.getn(AZS_PARTY) > 0 then
		return true
	end
	return Down()
end

------------------------------------------------------------------------------
-- The run's pieces, each read on its own: one failing leaves the rest.

-- Hyper Mode (the game's 0.143): the game sends no field for it; the final
-- boss comes in half the time. Its own field, should it ever send one, first.
local function Hyper(zone)
	if zone.hyper ~= nil then
		return Num(zone.hyper) == 1 or nil
	end
	local length = Num(zone.len)
	if length <= 0 and AZS_RUN then
		length = Num(AZS_RUN.fin)
	end
	return (length > 0 and length <= HYPER_LONGEST) or nil
end

-- The damage by source, the most first, with the run's total and its total a
-- second: the meter API v1 (Meter.lua's feed), else the game's older meter.
local function Damage()
	local feed = SUIC.MeterFeed
	if feed and feed.Has and feed.Has() then
		local ok, lines, total, rate = pcall(feed.Sources, { metric = "damage", period = "run" })
		if ok and type(lines) == "table" then
			return lines, Num(total), Num(rate)
		end
	end
	if AZS_GetMeter then
		local ok, lines, total, rate = pcall(AZS_GetMeter)
		if ok and type(lines) == "table" then
			local list = {}
			for index = 1, table.getn(lines) do
				local line = lines[index]
				table.insert(list, { name = line.name, dmg = Num(line.dmg), share = Num(line.share), proc = Num(line.proc) })
			end
			return list, Num(total), Num(rate)
		end
	end
	return {}, 0, 0
end

local function Healing()
	local feed = SUIC.MeterFeed
	if feed and feed.Has and feed.Has() then
		local ok, lines, total = pcall(feed.Sources, { metric = "healing", period = "run" })
		if ok and type(lines) == "table" then
			return Num(total)
		end
	end
	if AZS_GetHealing then
		local ok, _, total = pcall(AZS_GetHealing)
		if ok then
			return Num(total)
		end
	end
	return nil
end

-- A source's color in the damage meter, as "rrggbb": kept with the run, so
-- its pages show it in the colors it was played in. Asked at the run's end
-- alone, of sources the meter has colored already.
local function Hex(name)
	local color = name and SUIC.MeterColor and SUIC.MeterColor(name)
	if not color then
		return nil
	end
	return string.format("%02x%02x%02x", color[1] * 255, color[2] * 255, color[3] * 255)
end

-- The build: the game's spells in their order, the racial last, each with
-- its damage (the meter's lines of its key, procs apart) and its biggest crit.
local function Build(lines)
	local spells = AZS_SPELLS or {}
	local count = table.getn(spells)
	local build = {}
	for index = 1, count do
		local spell = spells[index]
		local key = spell.key
		local slot = index == count and 12 or index
		local name
		if SUIC.SpellName then
			local ok, found = pcall(SUIC.SpellName, slot)
			name = ok and found or nil
		end
		local one = {
			key = key, name = name or spell.spell or key, rank = Num(spell.rank),
			icon = GetActionTexture and GetActionTexture(slot) or nil,
			cd = Num(spell.cdmax), racial = (index == count and count > 1) or nil,
			crit = key and SUIC.BiggestCrit and SUIC.BiggestCrit(key) or nil,
		}
		-- Its tooltip as it reads now, kept with the run (RunGear.lua).
		local kept, tip = pcall(SUIC.RunTipOf, slot, "action")
		one.tip = kept and tip or nil
		-- The meter's key of a spell: "ability:auto_shot:r4".
		local head = key and ("ability:"..key..":")
		for at = 1, table.getn(lines) do
			local line = lines[at]
			local source = line.sourceKey
			if head and line.proc ~= 1 and type(source) == "string"
				and (source == key or string.sub(source, 1, string.len(head)) == head) then
				one.dmg = (one.dmg or 0) + Num(line.dmg)
				one.color = one.color or Hex(line.name)
				one.share = (one.share or 0) + Num(line.share)
			end
		end
		one.dmg = one.dmg and Whole(one.dmg)
		one.share = one.share and Share(one.share)
		table.insert(build, one)
	end
	return build
end

local function Jewelry()
	local list = {}
	for index = 1, table.getn(JEWELRY_SLOTS) do
		local slot = JEWELRY_SLOTS[index]
		local link = GetInventoryItemLink("player", slot)
		if link then
			-- Its tooltip as it reads now, kept with the run (RunGear.lua).
			local kept, tip = pcall(SUIC.RunTipOf, slot)
			table.insert(list, { slot = slot, link = link, icon = GetInventoryItemTexture("player", slot),
				tip = kept and tip or nil })
		end
	end
	return list
end

-- The bosses as the game schedules them, each with the second it fell as the
-- run tracker saw it (Tracker.lua).
local function Schedule()
	local list = {}
	local fell = SUIC.BossFell and SUIC.BossFell() or {}
	local schedule = AZS_SCHEDULE or {}
	for index = 1, table.getn(schedule) do
		local boss = schedule[index]
		table.insert(list, {
			name = boss.name, at = Num(boss.at), state = boss.state,
			final = Num(boss.final) == 1 or nil,
			fell = fell[index],
		})
	end
	return list
end

-- The hero's talents as the game has them, the tree first, then the name,
-- the rank and the icon's file: "0;Concussion;5;Spell_Fire_Fireball|...". Read every 15 sec in a run too: the run over,
-- the game may no longer give them.
local talentsHeld

local function Talents()
	if not (AZS_GetMeterLoadout and AZS_GetMeterContext) then
		return nil
	end
	local ok, context = pcall(AZS_GetMeterContext)
	if not (ok and type(context) == "table" and context.runId) then
		return nil
	end
	local done, loadout = pcall(AZS_GetMeterLoadout, { apiVersion = 1, runId = context.runId, ownerId = context.localOwnerId })
	if not (done and type(loadout) == "table") then
		return nil
	end
	local list = {}
	local talents = loadout.talents or {}
	for index = 1, table.getn(talents) do
		local talent = talents[index]
		local source = loadout.sources and loadout.sources[talent.sourceKey]
		local _, _, tree = string.find(talent.treeKey or "", "(%d+)$")
		if source and tree then
			-- The icon's file alone: its folder is the same for all.
			local path = source.icon and source.icon.path or ""
			local _, _, file = string.find(path, "([^\\/]+)$")
			local name = string.gsub(tostring(source.name or "?"), "[;|]", " ")
			table.insert(list, tree..";"..name..";"..Num(talent.rank)..";"..(file or ""))
		end
	end
	table.sort(list)
	return table.getn(list) > 0 and table.concat(list, "|") or nil
end

-- A co-op run: each hero's damage. nil alone.
local function Party()
	local feed = SUIC.MeterFeed
	if not (feed and feed.Has and feed.Has() and InParty()) then
		return nil
	end
	local context = feed.Context()
	local ok, lines = pcall(feed.Party, { metric = "damage", period = "run" })
	if not (ok and type(lines) == "table" and table.getn(lines) > 1) then
		return nil
	end
	local list = {}
	for index = 1, table.getn(lines) do
		local line = lines[index]
		table.insert(list, {
			name = line.name, class = line.class, dmg = Whole(line.dmg), dps = Whole(line.dps),
			me = (context and line.owner == context.localOwnerId) or nil,
		})
	end
	return list
end

-- The run's numbers, the ones the end screen gives again (Settle).
local function Numbers(record)
	local run = AZS_RUN or {}
	record.time = Num(run.t)
	record.level = Num(run.lvl)
	record.kills = Num(run.kills)
	record.elites = Num(run.ek)
	record.guardians = Num(run.gk)
	record.bosses = Num(run.bk)
	record.taken = Num(run.taken)
	record.gold = Num(run.ge)
	record.caches = Num(run.ck)
end

-- The run as it stands.
local function Snapshot(result)
	local zone = AZS_ZONE or {}
	local _, classKey = UnitClass("player")
	local record = {
		at = time(),
		result = result,
		hero = zone.hero or UnitName("player"),
		race = zone.rname or UnitRace("player"),
		class = zone.cname or UnitClass("player"),
		classKey = classKey,
		zone = zone.zname or GetZoneText(),
		heroic = tonumber(zone.heroic),
		hyper = Hyper(zone),
		affixes = (zone.affixes and zone.affixes ~= "") and tostring(zone.affixes) or nil,
		mods = (zone.mods and zone.mods ~= "") and tostring(zone.mods) or nil,
	}
	Numbers(record)
	local lines, total, rate = Damage()
	record.damage, record.dps = Whole(total), Whole(rate)
	local healed = Healing()
	record.healing = healed and Whole(healed)
	record.sources = {}
	for index = 1, math.min(SOURCES, table.getn(lines)) do
		local line = lines[index]
		table.insert(record.sources, {
			name = line.name, dmg = Whole(line.dmg), share = Share(line.share),
			proc = line.proc == 1 or nil, icon = line.icon or (SUIC.IconOf and SUIC.IconOf(line.name)) or nil,
			color = Hex(line.name),
		})
	end
	record.build = Build(lines)
	record.jewelry = Jewelry()
	if SUIC.RunGearSnapshot then
		record.armor, record.set = SUIC.RunGearSnapshot()
	end
	record.loot = SUIC.RunLoot and SUIC.RunLoot(LOOT) or {}
	for index = 1, table.getn(record.loot) do
		local drop = record.loot[index]
		if drop.item then
			local kept, tip = pcall(SUIC.RunTipOf, drop.item, "link")
			drop.tip = kept and tip or nil
		end
	end
	record.marks = SUIC.RunMarks and SUIC.RunMarks() or nil
	record.schedule = Schedule()
	if type(AZS_STATS) == "table" then
		record.stats = {}
		for key, value in pairs(AZS_STATS) do
			if type(value) == "number" then
				record.stats[key] = value
			end
		end
	end
	record.party = Party()
	record.talents = Talents() or talentsHeld
	-- The three trees' names, which the client's own talent calls do know.
	if GetTalentTabInfo then
		record.trees = {}
		for tree = 1, 3 do
			local ok, name = pcall(GetTalentTabInfo, tree)
			record.trees[tree] = ok and name or nil
		end
	end
	return record
end

------------------------------------------------------------------------------
-- Keeping.

-- The talent experience the run gave, from the game's line as it ends:
-- "Your Shamans earn 31475 talent experience." It can come just before the
-- run is kept, or just after.
local pendingTalent             -- { amount, at }: come before the run was kept
local awaitingTalent            -- the run kept, its line not come yet

local function TalentFor(record)
	if pendingTalent and math.abs(time() - pendingTalent.at) < 30 then
		record.talentXp = pendingTalent.amount
		awaitingTalent = nil
	else
		awaitingTalent = record
	end
	pendingTalent = nil
end

-- Past the count chosen the oldest runs go, but not the one just kept nor a
-- pinned one.
local Trim
function SUIC.TrimRunHistory()
	Trim()
end

Trim = function()
	local runs = Runs()
	local count = tonumber(SUIC.DB().historyKeep) or KEEP
	local index = table.getn(runs)
	while table.getn(runs) > count and index > 1 do
		if not runs[index].pinned then
			table.remove(runs, index)
		end
		index = index - 1
	end
end

local function Same(a, b)
	return a and b and a.time == b.time and a.kills == b.kills
end

-- The run kept last, kept again a moment later: its clock went on as long as
-- the computer's did between the two (a new run's starts again from 0).
local function SameRun(last, record)
	if not (last and not last.endless and last.zone == record.zone and last.hero == record.hero) then
		return false
	end
	local apart = Num(record.at) - Num(last.at)
	return apart >= 0 and apart < 120 and math.abs((Num(record.time) - Num(last.time)) - apart) <= 3
end

local RESULT_WORDS = { victory = "@run:Victory", dead = "@run:Fallen", left = "@run:Left" }
local RESULT_COLORS = { victory = "|cff40ff40", dead = "|cffff5040", left = "|cffe6c860" }

-- The word for a run's result, in the player's language.
function SUIC.RunResultWord(result)
	return SUIC.T(RESULT_WORDS[result] or "@run:Left")
end

-- A run in a line of the chat: its result, class, zone and length.
local function Say(words, record)
	SUIC.Print(SUIC.TF(words, (RESULT_COLORS[record.result] or RESULT_COLORS.left)..SUIC.RunResultWord(record.result).."|r",
		tostring(record.class or "?"), tostring(record.zone or "?"), SUIC.Clock(record.time)))
end

local function Keep(record)
	local runs = Runs()
	local last = runs[1]
	-- The same run kept already (a reload on the end screen): not again.
	if last and last.zone == record.zone and Same(last, record) then
		return false
	end
	TalentFor(record)
	-- The same run a moment ago (an end message the game sends again and
	-- again): this moment in its place, not one run more.
	if SameRun(last, record) then
		record.pinned = last.pinned
		runs[1] = record
		return true
	end
	table.insert(runs, 1, record)
	Trim()
	if SUIC.RunHistoryKept then
		SUIC.RunHistoryKept()
	end
	Say("Run saved: {1}, {2}, {3}, {4}.", record)
	return true
end

-- The run kept at its victory, while it goes on in endless mode: the same
-- zone, endless on, its clock past the victory's, its end not kept yet.
local function EndlessOf()
	local last = Runs()[1]
	local run, zone = AZS_RUN, AZS_ZONE or {}
	if not (last and run and last.result == "victory" and Num(run.endl) == 1) then
		return nil
	end
	if last.endless and last.endless ~= "going" then
		return nil
	end
	local won = last.won or last
	if (zone.zname or GetZoneText()) ~= last.zone or Num(run.t) < Num(won.time) then
		return nil
	end
	return last
end

local WON_FIELDS = { "time", "level", "kills", "elites", "guardians", "bosses", "taken", "gold", "caches", "magnets", "damage", "dps", "healing" }

-- An endless run's moment: the run kept at its victory taken again as it
-- stands now, the victory's numbers set aside in won.
local function Endless(entry, state)
	local won = entry.won
	if not won then
		won = { at = entry.at }
		for index = 1, table.getn(WON_FIELDS) do
			won[WON_FIELDS[index]] = entry[WON_FIELDS[index]]
		end
	end
	local record = Snapshot("victory")
	record.won = won
	record.endless = state
	record.pinned = entry.pinned
	record.talentXp = entry.talentXp
	Runs()[1] = record
	return record
end

local captured
local endlessWait = 0
local lastKept                  -- the run just kept by the watcher, the game's numbers awaited
local summaryAt                 -- the game's last end settled (its AZS_END_UPDATED)
-- A co-op hero down: the game sends its end message every 0.2 s while down,
-- the run going on. The last one is held here until the hero is up again
-- (dropped) or the run is over.
local heldEnd
local settledAt                 -- when (GetTime) it was

local END_RESULTS = { defeat = "dead", victory = "victory", left = "left" }
-- The end screen's damage is not taken: it counts the overkill (some four
-- times the meter's, seen 2026-10-20).
local SUMMARY_FIELDS = {
	time = "t", level = "lvl", kills = "kills", elites = "elites", guardians = "guardians", bosses = "bosses",
	taken = "taken", gold = "gold", caches = "chests", magnets = "magnets",
}

local function Wanted(result)
	local which = SUIC.DB().historyWhich or "all"
	return which == "all" or (which == "victories" and result == "victory")
end

-- The game's own end of the run: the run the watcher just kept brought to the
-- end screen's numbers; an endless run's moment brought to its end; else a
-- run the watcher did not see end (left from the menu), kept now.
local function Settle(summary)
	local result = END_RESULTS[summary.result] or "dead"
	local record = lastKept
	lastKept = nil
	if not (record and math.abs(time() - Num(record.at)) < 60) then
		record = nil
		local last = Runs()[1]
		if Num(summary.endl) == 1 and result ~= "victory" then
			if last and last.endless == "going" and math.abs(time() - Num(last.at)) < 30 then
				record = last
				record.endless = result
			end
		elseif Wanted(result) then
			record = Snapshot(result)
			if not Keep(record) then
				record = nil
			end
		end
	end
	if not record then
		return
	end
	for field, key in pairs(SUMMARY_FIELDS) do
		if summary[key] ~= nil then
			record[field] = Num(summary[key])
		end
	end
	if record.endless then
		record.endless = result == "victory" and record.endless or result
	else
		record.result = result
	end
end

local watcher = CreateFrame("Frame")
watcher:Hide()
local elapsed, talentsWait = 0, 0
watcher:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.5 then
		return
	end
	local step = elapsed
	elapsed = 0
	local phase = AZS_GetPhase and AZS_GetPhase()
	if (SUIC.DB().historyWhich or "all") == "none" then
		return
	end
	-- The game's end, come since the last look.
	if AZS_GetRunSummary and AZS_END_UPDATED and AZS_END_UPDATED ~= summaryAt then
		summaryAt = AZS_END_UPDATED
		heldEnd = AZS_GetRunSummary()
	end
	local party = InParty()
	if heldEnd then
		local inRun = phase ~= nil and phase ~= "ready"
		if party and inRun and Down() then
			-- Down in a party, the run on: not the end yet.
		elseif party and (phase == "playing" or phase == "choosing" or phase == "paused") then
			-- Brought back: the run goes on.
			heldEnd = nil
		else
			Settle(heldEnd)
			heldEnd = nil
			captured = true
			settledAt = GetTime()
		end
	end
	-- In a party a hero down is not the run's end, though the phase says dead
	-- while down: only the game's end message, once the hero is no longer down
	-- (heldEnd, above), says the run is over.
	if phase == "dead" and party then
		return
	end
	if phase == "dead" or phase == "victory" then
		if not captured then
			captured = true
			local entry = phase == "dead" and EndlessOf()
			if entry then
				lastKept = Endless(entry, "dead")
			elseif Wanted(phase) then
				local record = Snapshot(phase)
				if Keep(record) then
					lastKept = record
				end
			end
		end
	elseif phase == "playing" or phase == "choosing" or phase == "paused" then
		-- A run going on, but not in the moment the game's end came in (its
		-- message can come a moment before the phase turns).
		if phase == "playing" and not (settledAt and GetTime() - settledAt < 5) then
			captured = nil
			awaitingTalent = nil
			lastKept = nil
		end
		if phase == "playing" then
			talentsWait = talentsWait - step
			if talentsWait <= 0 then
				talentsWait = 15
				talentsHeld = Talents() or talentsHeld
			end
		end
		local entry = EndlessOf()
		if entry then
			endlessWait = endlessWait - step
			if not entry.endless or endlessWait <= 0 then
				endlessWait = 10
				Endless(entry, "going")
			end
		end
	elseif phase == "ready" then
		captured = nil
		talentsHeld = nil
		-- An endless run left from the menu: its last moment stands.
		local last = Runs()[1]
		if last and last.endless == "going" then
			last.endless = "left"
		end
	end
end)

local talent = CreateFrame("Frame")
talent:SetScript("OnEvent", function()
	local _, _, amount = string.find(arg1 or "", "(%d+) talent experience")
	if not amount then
		return
	end
	if awaitingTalent and not awaitingTalent.talentXp then
		awaitingTalent.talentXp = tonumber(amount)
		awaitingTalent = nil
	else
		pendingTalent = { amount = tonumber(amount), at = time() }
	end
end)

------------------------------------------------------------------------------
-- The window: the runs in a list at the left, as the game's quest log has its
-- quests, and the one chosen at the right, a tab a subject.

local WIDTH, HEIGHT = 676, 632
local LIST_LEFT, LIST_TOP, LIST_WIDTH = 22, -40, 266
local ROW, ROWS = 32, 16
local PANE_LEFT = LIST_LEFT + LIST_WIDTH + 30
local PANE_WIDTH = WIDTH - PANE_LEFT - 24
local HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"
local HEROIC = { "I", "II", "III", "IV", "V" }

local window = SUIC.Dialog("SUICRunHistory", "Run History", WIDTH, HEIGHT)
local chosen = 1                -- the run shown, its place in the list
local tabChosen = 1             -- and the tab
local offset = 0                -- the rows scrolled past
local rows = {}
local Draw

local function Result(run)
	return (RESULT_COLORS[run.result] or RESULT_COLORS.dead)..SUIC.RunResultWord(run.result).."|r"
end

-- How long ago: "just now", "18 min ago", "3 h ago", "2 days ago". Not a
-- date: the game's date() is UTC, not the player's clock.
local function Ago(at)
	local seconds = time() - Num(at)
	if seconds < 60 then
		return SUIC.T("just now")
	elseif seconds < 3600 then
		return SUIC.TF("{1} min ago", math.floor(seconds / 60))
	elseif seconds < 86400 then
		return SUIC.TF("{1} h ago", math.floor(seconds / 3600))
	end
	local days = math.floor(seconds / 86400)
	return days == 1 and SUIC.T("1 day ago") or SUIC.TF("{1} days ago", days)
end

-- The run's difficulty after its zone: Heroic in orange, Hyper in blue, as
-- the run tracker writes them.
local function Difficulty(run, short)
	local said = ""
	local heroic = Num(run.heroic)
	if heroic > 0 then
		said = said.."  |cffff7a2e"..SUIC.TF("Heroic {1}", HEROIC[heroic] or heroic).."|r"
	end
	if run.hyper then
		said = said.."  |cff5cd6ff"..SUIC.T("Hyper").."|r"
	end
	if run.endless and not short then
		said = said.."  "..SUIC.T("|cffd080ffEndless|r")
	end
	return said
end

-- The list's frame, a line down its right.
local list = CreateFrame("Frame", nil, window)
list:SetPoint("TOPLEFT", window, "TOPLEFT", LIST_LEFT, LIST_TOP)
list:SetWidth(LIST_WIDTH)
list:SetHeight(ROW * ROWS)
list:EnableMouseWheel(true)
local divider = window:CreateTexture(nil, "ARTWORK")
divider:SetTexture(SUIC.FLAT)
divider:SetVertexColor(1, 1, 1, 0.08)
divider:SetWidth(1)
divider:SetPoint("TOPLEFT", list, "TOPRIGHT", 16, 0)
divider:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 16, 0)

local function Most()
	return math.max(0, table.getn(Runs()) - ROWS)
end

-- The list's scroll bar: there only with more runs than rows.
local scroll = CreateFrame("Slider", nil, list)
scroll:SetOrientation("VERTICAL")
scroll:SetWidth(10)
scroll:SetPoint("TOPLEFT", list, "TOPRIGHT", 2, 0)
scroll:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 2, 0)
scroll:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
local trough = scroll:CreateTexture(nil, "BACKGROUND")
trough:SetTexture(SUIC.FLAT)
trough:SetVertexColor(1, 1, 1, 0.05)
trough:SetAllPoints(scroll)
scroll:SetMinMaxValues(0, 0)
scroll:SetValueStep(1)
scroll:SetValue(0)
scroll:SetScript("OnValueChanged", function()
	local value = math.floor(this:GetValue() + 0.5)
	if value ~= offset then
		offset = value
		Draw()
	end
end)
list:SetScript("OnMouseWheel", function()
	offset = math.max(0, math.min(Most(), offset - arg1))
	scroll:SetValue(offset)
	Draw()
end)

for index = 1, ROWS do
	local row = CreateFrame("Button", nil, list)
	row:SetWidth(LIST_WIDTH)
	row:SetHeight(ROW - 2)
	row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(index - 1) * ROW)
	row:SetHighlightTexture(HIGHLIGHT, "ADD")
	row.selected = row:CreateTexture(nil, "BACKGROUND")
	row.selected:SetTexture(HIGHLIGHT)
	row.selected:SetBlendMode("ADD")
	row.selected:SetVertexColor(1, 0.82, 0)
	row.selected:SetAllPoints(row)
	row.selected:Hide()
	row.top = SUIC.Text(row, "GameFontHighlightSmall")
	row.top:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -3)
	row.top:SetJustifyH("LEFT")
	row.top:SetWidth(LIST_WIDTH - 54)
	row.top:SetHeight(12)
	row.clock = SUIC.Text(row, "GameFontHighlightSmall")
	row.clock:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -3)
	row.sub = SUIC.Text(row, "GameFontNormalSmall")
	row.sub:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 6, 3)
	row.sub:SetJustifyH("LEFT")
	row.sub:SetHeight(12)
	row.ago = SUIC.Text(row, "GameFontDisableSmall")
	row.ago:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -6, 3)
	row:SetScript("OnClick", function()
		chosen = this.place
		Draw()
	end)
	rows[index] = row
end

-- Nothing kept yet: said in the list's place.
local none = SUIC.Text(window, "GameFontDisable")
none:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -6)
none:SetWidth(LIST_WIDTH - 12)
none:SetJustifyH("LEFT")

-- How many runs are kept, at the window's foot.
local counted = SUIC.Text(window, "GameFontDisableSmall")
counted:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", LIST_LEFT + 6, 22)

local close = CreateFrame("Button", "SUICRunHistoryClose", window, "UIPanelButtonTemplate")
close:SetWidth(72)
close:SetHeight(22)
close:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -20, 18)
close:SetText(CLOSE or "Close")
close:SetScript("OnClick", function() window:Hide() end)

-- The tabs over the run chosen, each a button with a word of what it shows.
local TABS = {
	{ "Summary", "The run's numbers." },
	{ "Build", "The spells, the jewelry and the talents the run ended with." },
	{ "Damage", "The run's damage by source, and each hero's in a party." },
	{ "Loot", "What the run dropped, its marks, and when each boss fell." },
}
local tabs = {}
for index = 1, table.getn(TABS) do
	local tab = CreateFrame("Button", "SUICRunHistoryTab"..index, window, "UIPanelButtonTemplate")
	tab:SetWidth(80)
	tab:SetHeight(20)
	tab:SetPoint("TOPLEFT", window, "TOPLEFT", PANE_LEFT + (index - 1) * 84, LIST_TOP)
	tab.words, tab.tip = TABS[index][1], TABS[index][2]
	tab:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		GameTooltip:SetText(SUIC.T(this.words), 1, 1, 1)
		GameTooltip:AddLine(SUIC.T(this.tip), 1, 0.82, 0, 1)
		GameTooltip:Show()
	end)
	tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
	tab.index = index
	tab:SetScript("OnClick", function()
		tabChosen = this.index
		Draw()
	end)
	tabs[index] = tab
end

-- The run chosen: its hero, where and how it went, then its numbers, each
-- with its name.
local pane = CreateFrame("Frame", nil, window)
pane:SetPoint("TOPLEFT", window, "TOPLEFT", PANE_LEFT, LIST_TOP - 30)
pane:SetWidth(PANE_WIDTH)
pane:SetHeight(HEIGHT + LIST_TOP - 80)
local hero = SUIC.Text(pane, "GameFontNormalLarge")
hero:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
local outcome = SUIC.Text(pane, "GameFontNormalLarge")
outcome:SetPoint("TOPRIGHT", pane, "TOPRIGHT", 0, 0)
local who = SUIC.Text(pane, "GameFontHighlightSmall")
who:SetPoint("TOPLEFT", hero, "BOTTOMLEFT", 0, -4)
local where = SUIC.Text(pane, "GameFontNormalSmall")
where:SetPoint("TOPLEFT", who, "BOTTOMLEFT", 0, -4)
local ago = SUIC.Text(pane, "GameFontDisableSmall")
ago:SetPoint("TOPRIGHT", outcome, "BOTTOMRIGHT", 0, -4)
local endless = SUIC.Text(pane, "GameFontHighlightSmall")
endless:SetPoint("TOPLEFT", where, "BOTTOMLEFT", 0, -4)
local rule = SUIC.Rule(pane)
rule:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -70)
rule:SetPoint("TOPRIGHT", pane, "TOPRIGHT", 0, -70)

local function Count(value)
	return tostring(Whole(value))
end

-- The Summary's numbers: its name, the run's field, how it is written.
local NUMBERS = {
	{ "Run time", "time", SUIC.Clock }, { "Level", "level", Count },
	{ "Kills", "kills", Count }, { "Elites", "elites", Count },
	{ "Guardians", "guardians", Count }, { "Bosses", "bosses", Count },
	{ "Total damage", "damage", SUIC.Short }, { "DPS", "dps", SUIC.Short },
	{ "Healing", "healing", SUIC.Short }, { "Damage taken", "taken", SUIC.Short },
	{ "Gold", "gold", Count }, { "Caches", "caches", Count },
	{ "Marks", "marks", Count }, { "Talent XP", "talentXp", Count },
}
local COLUMN = PANE_WIDTH / 2
local summary = CreateFrame("Frame", nil, pane)
summary:SetAllPoints(pane)

-- A soft band behind a row, across its page: every other row has one.
local function Band(page, y, height)
	local band = page:CreateTexture(nil, "BACKGROUND")
	band:SetTexture(SUIC.FLAT)
	band:SetVertexColor(1, 1, 1, 0.045)
	band:SetHeight(height)
	band:SetPoint("TOPLEFT", page, "TOPLEFT", -2, y)
	band:SetPoint("TOPRIGHT", page, "TOPRIGHT", 2, y)
end

local cells = {}
for index = 1, table.getn(NUMBERS) do
	local column = math.mod(index - 1, 2)
	local line = math.floor((index - 1) / 2)
	local cell = {}
	if column == 0 and math.mod(line, 2) == 0 then
		Band(summary, -84 - line * 22 + 5, 22)
	end
	cell.name = SUIC.Text(summary, "GameFontNormalSmall")
	cell.name:SetPoint("TOPLEFT", pane, "TOPLEFT", column * (COLUMN + 8), -84 - line * 22)
	cell.value = SUIC.Text(summary, "GameFontHighlight")
	cell.value:SetPoint("TOPRIGHT", pane, "TOPLEFT", column * (COLUMN + 8) + COLUMN - 8, -84 - line * 22)
	-- A line under each, soft, as the build list's.
	local under = summary:CreateTexture(nil, "ARTWORK")
	under:SetTexture(SUIC.FLAT)
	under:SetVertexColor(1, 1, 1, 0.08)
	under:SetHeight(1)
	under:SetPoint("TOPLEFT", cell.name, "BOTTOMLEFT", 0, -4)
	under:SetWidth(COLUMN - 8)
	cells[index] = cell
end

------------------------------------------------------------------------------
-- The Build tab: the run's spells with their numbers, a column a number with
-- its name over it; the jewelry worn; the talents, a line a tree.

local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local SPELL_ROW, SPELL_ROWS = 17, 7
local build = CreateFrame("Frame", nil, pane)
build:SetAllPoints(pane)
build:Hide()

local function Heading(words, y)
	local heading = SUIC.Text(build, "GameFontNormalSmall")
	heading:SetPoint("TOPLEFT", build, "TOPLEFT", 0, y)
	heading.words = words
	return heading
end

-- A tooltip's zone with an icon in it.
local function IconButton(size)
	local button = CreateFrame("Button", nil, build)
	button:SetWidth(size)
	button:SetHeight(size)
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetAllPoints(button)
	button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return button
end

-- A color kept as "rrggbb", else the meter's palette's at that place, else a
-- soft gold.
local function Shade(hex, index)
	local _, _, r, g, b = string.find(hex or "", "^(%x%x)(%x%x)(%x%x)$")
	if r then
		return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
	end
	local color = index and SUIC.MeterShade and SUIC.MeterShade(index)
	if color then
		return color[1], color[2], color[3]
	end
	return 0.62, 0.45, 0.14
end

-- The spells' columns, from the pane's right: its name, where it ends, and
-- its numbers' color (the rank's gold, the cooldown's blue, the share's peach
-- and the crit's yellow, as the Build panel and the character page have them).
local SPELL_COLUMNS = {
	{ "Biggest crit", 0, "|cffffe566" }, { "Share", -68, "|cffffab61" }, { "Damage", -106, "|cffffffff" },
	{ "CD", -160, "|cff99d9ff" }, { "Rank", -200, "|cffffd100" },
}
local SPELLS_TOP = -78
local spellsHeading = Heading("Spells", SPELLS_TOP)
local columnNames = {}
for index = 1, table.getn(SPELL_COLUMNS) do
	local name = SUIC.Text(build, "GameFontDisableSmall")
	name:SetPoint("TOPRIGHT", build, "TOPRIGHT", SPELL_COLUMNS[index][2], SPELLS_TOP)
	columnNames[index] = name
end
local spellRows = {}
for index = 1, SPELL_ROWS do
	local row = CreateFrame("Frame", nil, build)
	row:SetHeight(SPELL_ROW)
	row:SetPoint("TOPLEFT", build, "TOPLEFT", 0, SPELLS_TOP - 15 - (index - 1) * SPELL_ROW)
	row:SetPoint("RIGHT", build, "RIGHT", 0, 0)
	-- Every other row on a soft band.
	if math.mod(index, 2) == 1 then
		local band = row:CreateTexture(nil, "BACKGROUND")
		band:SetTexture(SUIC.FLAT)
		band:SetVertexColor(1, 1, 1, 0.045)
		band:SetAllPoints(row)
	end
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetWidth(SPELL_ROW - 3)
	row.icon:SetHeight(SPELL_ROW - 3)
	row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	row.name = SUIC.Text(row, "GameFontHighlightSmall")
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetWidth(100)
	row.name:SetHeight(12)
	row.cells = {}
	for column = 1, table.getn(SPELL_COLUMNS) do
		local cell = SUIC.Text(row, "GameFontHighlightSmall")
		cell:SetPoint("RIGHT", row, "RIGHT", SPELL_COLUMNS[column][2], 0)
		row.cells[column] = cell
	end
	local under = row:CreateTexture(nil, "ARTWORK")
	under:SetTexture(SUIC.FLAT)
	under:SetVertexColor(1, 1, 1, 0.08)
	under:SetHeight(1)
	under:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
	under:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
	row:EnableMouse(true)
	row:SetScript("OnEnter", function() SUIC.RunShowTip(this, this.tip, nil, this.title, this.numbers) end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	spellRows[index] = row
end

-- The jewelry: a piece a slot, in two columns, its tooltip under the mouse.
local JEWELRY_TOP = SPELLS_TOP - 15 - SPELL_ROWS * SPELL_ROW - 6
local JEWELRY_ROW = 17
local JEWELRY_NAMES = { [2] = "Neck", [11] = "Ring", [12] = "Ring", [13] = "Trinket", [14] = "Trinket" }
local JEWELRY_EMPTY = { [2] = "Neck", [11] = "Finger", [12] = "Finger", [13] = "Trinket", [14] = "Trinket" }
local jewelryHeading = Heading("Jewelry", JEWELRY_TOP)
local pieces = {}
for index = 1, table.getn(JEWELRY_SLOTS) do
	local piece = IconButton(JEWELRY_ROW - 3)
	local column = math.mod(index - 1, 2)
	local line = math.floor((index - 1) / 2)
	if column == 0 and math.mod(line, 2) == 0 then
		Band(build, JEWELRY_TOP - 15 - line * JEWELRY_ROW + 1, JEWELRY_ROW)
	end
	piece:SetPoint("TOPLEFT", build, "TOPLEFT", column * (PANE_WIDTH / 2 + 4), JEWELRY_TOP - 15 - line * JEWELRY_ROW)
	piece.name = SUIC.Text(build, "GameFontHighlightSmall")
	piece.name:SetPoint("LEFT", piece, "RIGHT", 4, 0)
	piece.name:SetJustifyH("LEFT")
	piece.name:SetWidth(PANE_WIDTH / 2 - JEWELRY_ROW - 6)
	piece.name:SetHeight(12)
	piece.slot = JEWELRY_SLOTS[index]
	piece:SetScript("OnEnter", function() SUIC.RunShowTip(this, this.tip, this.item) end)
	pieces[index] = piece
end

-- The talents: the class's three trees, small (RunTalents.lua).
-- Under the jewelry, the armor and the weapons with their set (RunGear.lua);
-- the talents start where they end.
local GEAR_TOP = JEWELRY_TOP - 15 - 3 * JEWELRY_ROW - 6
local drawGear = SUIC.RunGear(build, PANE_WIDTH)
local talentsHeading = Heading("Talents", GEAR_TOP)
local noTalents = SUIC.Text(build, "GameFontDisableSmall")
noTalents:SetPoint("LEFT", talentsHeading, "RIGHT", 8, 0)
local drawTalents = SUIC.RunTalents(build, PANE_WIDTH)

local function DrawBuild(run)
	spellsHeading:SetText(SUIC.T(spellsHeading.words))
	jewelryHeading:SetText(SUIC.T(jewelryHeading.words))
	talentsHeading:SetText(SUIC.T(talentsHeading.words))
	for index = 1, table.getn(SPELL_COLUMNS) do
		columnNames[index]:SetText(SUIC.T(SPELL_COLUMNS[index][1]))
	end
	local spells = run.build or {}
	-- A run kept before its colors were: a spell in its source's color, by name.
	local places = {}
	for index = 1, table.getn(run.sources or {}) do
		local name = run.sources[index].name
		if name and not places[name] then
			places[name] = index
		end
	end
	local order = {}
	for index = 1, table.getn(spells) do
		order[index] = spells[index]
	end
	table.sort(order, function(a, b)
		if (a.racial and 1 or 0) ~= (b.racial and 1 or 0) then
			return not a.racial
		elseif Num(a.rank) ~= Num(b.rank) then
			return Num(a.rank) > Num(b.rank)
		end
		local mine = a.dmg or (places[a.name or ""] and run.sources[places[a.name]].dmg) or 0
		local theirs = b.dmg or (places[b.name or ""] and run.sources[places[b.name]].dmg) or 0
		if mine ~= theirs then
			return mine > theirs
		end
		return tostring(a.name) < tostring(b.name)
	end)
	spells = order
	for index = 1, SPELL_ROWS do
		local row, spell = spellRows[index], spells[index]
		if spell then
			row.icon:SetTexture(spell.icon or (SUIC.IconOf and SUIC.IconOf(spell.name)) or QUESTION)
			row.name:SetText(tostring(spell.name or "?"))
			if spell.racial then
				row.name:SetTextColor(0.75, 0.75, 0.75)
			elseif spell.color or places[spell.name or ""] then
				-- Its color in the run's meter, a touch lighter so it reads on black.
				local at = places[spell.name or ""]
				local r, g, b = Shade(spell.color or run.sources[at].color, at)
				row.name:SetTextColor(r * 0.85 + 0.15, g * 0.85 + 0.15, b * 0.85 + 0.15)
			else
				row.name:SetTextColor(1, 1, 1)
			end
			-- A spell whose damage the meter has under its name alone (a totem's):
			-- that line's numbers.
			local line = (not spell.dmg) and places[spell.name or ""] and run.sources[places[spell.name]]
			local dmg, share = spell.dmg or (line and line.dmg), spell.share or (line and line.share)
			local said = {
				spell.crit and SUIC.Short(spell.crit), share and string.format("%.0f%%", share * 100),
				dmg and SUIC.Short(dmg), Num(spell.cd) > 0 and string.format("%.1fs", spell.cd),
				(not spell.racial) and spell.rank and tostring(spell.rank),
			}
			for column = 1, table.getn(SPELL_COLUMNS) do
				row.cells[column]:SetText(said[column] and (SPELL_COLUMNS[column][3]..said[column].."|r") or "|cff808080-|r")
			end
			-- Under the mouse: the spell's tooltip as the run had it, and its numbers.
			row.tip, row.title, row.numbers = spell.tip, tostring(spell.name or "?"), {}
			for column = table.getn(SPELL_COLUMNS), 1, -1 do
				if said[column] then
					table.insert(row.numbers, { SUIC.T(SPELL_COLUMNS[column][1]), said[column] })
				end
			end
			row:Show()
		else
			row:Hide()
		end
	end
	local worn = {}
	for _, piece in pairs(run.jewelry or {}) do
		worn[piece.slot] = piece
	end
	for index = 1, table.getn(pieces) do
		local piece = pieces[index]
		local one = worn[piece.slot]
		if one and one.link then
			local _, _, color, name = string.find(one.link, "|c(%x+)|H.-|h%[(.-)%]|h")
			local _, _, item = string.find(one.link, "(item:[%d:%-]+)")
			piece.item, piece.tip = item, one.tip
			piece.icon:SetTexture(one.icon or QUESTION)
			piece.icon:SetVertexColor(1, 1, 1)
			piece.name:SetText("|c"..(color or "ffffffff")..SUIC.RunFitName(name or "?", PANE_WIDTH / 2 - JEWELRY_ROW - 8).."|r")
		else
			piece.item, piece.tip = nil, nil
			piece.icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-"..JEWELRY_EMPTY[piece.slot])
			piece.icon:SetVertexColor(0.6, 0.6, 0.6)
			piece.name:SetText("|cff8a8a8a"..SUIC.T(JEWELRY_NAMES[piece.slot]).."|r")
		end
	end
	local under = drawGear(run, GEAR_TOP) - 8
	talentsHeading:ClearAllPoints()
	talentsHeading:SetPoint("TOPLEFT", build, "TOPLEFT", 0, under)
	local had = drawTalents(run, under - 15)
	noTalents:SetText(had == 0 and SUIC.T("None kept with this run.") or "")
end

------------------------------------------------------------------------------
-- The Damage tab: the run's damage by source, a bar a source, the most
-- first; its totals, each with its name; and in a co-op run the party, a bar
-- a hero.

local SOURCE_ROW = 16
local damage = CreateFrame("Frame", nil, pane)
damage:SetAllPoints(pane)
damage:Hide()

local function DamageHeading(y)
	local heading = SUIC.Text(damage, "GameFontNormalSmall")
	heading:SetPoint("TOPLEFT", damage, "TOPLEFT", 0, y)
	return heading
end

-- A column's name over the bars, where the column ends from the pane's right.
local function ColumnName(y, x)
	local name = SUIC.Text(damage, "GameFontDisableSmall")
	name:SetPoint("TOPRIGHT", damage, "TOPRIGHT", x, y)
	return name
end

-- A bar with an icon before it, its name on it, two numbers at its right.
local function DamageBar(y)
	local bar = SUIC.RowBar(damage, PANE_WIDTH - SOURCE_ROW - 2, SOURCE_ROW - 3)
	bar:SetPoint("TOPLEFT", damage, "TOPLEFT", SOURCE_ROW + 2, y)
	bar.icon = damage:CreateTexture(nil, "ARTWORK")
	bar.icon:SetWidth(SOURCE_ROW - 3)
	bar.icon:SetHeight(SOURCE_ROW - 3)
	bar.icon:SetPoint("RIGHT", bar, "LEFT", -2, 0)
	bar.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	bar.left:SetWidth(PANE_WIDTH - 150)
	bar.amount = SUIC.Text(bar.over, "GameFontHighlightSmall")
	bar.amount:SetPoint("RIGHT", bar, "RIGHT", -50, 0)
	bar:EnableMouse(true)
	bar:SetScript("OnEnter", function() SUIC.RunShowTip(this, nil, nil, this.title, this.numbers) end)
	bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return bar
end

local SOURCES_TOP = -78
local doneHeading = DamageHeading(SOURCES_TOP)
local doneDamage, doneShare = ColumnName(SOURCES_TOP, -50), ColumnName(SOURCES_TOP, -3)
local sourceBars = {}
for index = 1, SOURCES do
	sourceBars[index] = DamageBar(SOURCES_TOP - 15 - (index - 1) * SOURCE_ROW)
end
local noSources = SUIC.Text(damage, "GameFontDisableSmall")
noSources:SetPoint("TOPLEFT", damage, "TOPLEFT", 0, SOURCES_TOP - 17)

-- The totals under the bars, each with its name.
local TOTALS_TOP = SOURCES_TOP - 15 - SOURCES * SOURCE_ROW - 6
local totals = SUIC.Text(damage, "GameFontHighlightSmall")
totals:SetPoint("TOPLEFT", damage, "TOPLEFT", 0, TOTALS_TOP)

local PARTY_TOP = TOTALS_TOP - 24
local PARTY = 5
local partyHeading = DamageHeading(PARTY_TOP)
local partyDamage, partyRate = ColumnName(PARTY_TOP, -50), ColumnName(PARTY_TOP, -3)
local partyBars = {}
for index = 1, PARTY do
	partyBars[index] = DamageBar(PARTY_TOP - 15 - (index - 1) * SOURCE_ROW)
	partyBars[index].icon:Hide()
end

local function DrawDamage(run)
	doneHeading:SetText(SUIC.T("Damage done"))
	doneDamage:SetText(SUIC.T("Damage"))
	doneShare:SetText(SUIC.T("Share"))
	local sources = run.sources or {}
	local most = sources[1] and Num(sources[1].dmg) or 0
	for index = 1, SOURCES do
		local bar, source = sourceBars[index], sources[index]
		if source then
			bar.icon:SetTexture(source.icon or QUESTION)
			bar.icon:Show()
			bar:SetValue(most > 0 and Num(source.dmg) / most or 0)
			bar:SetStatusBarColor(Shade(source.color, index))
			-- A talent's or an item's own damage, told apart as the meter does.
			bar.left:SetText(tostring(source.name or "?")..(source.proc and ("  |cffb0b0b0"..SUIC.T("proc").."|r") or ""))
			bar.amount:SetText(SUIC.Short(source.dmg))
			bar.right:SetText(string.format("%.0f%%", Num(source.share) * 100))
			-- Under the mouse, as the damage meter's line.
			bar.title = tostring(source.name or "?")
			bar.numbers = {
				{ SUIC.T("Total"), SUIC.Short(source.dmg) },
				{ SUIC.T("Per second"), SUIC.Short(Num(source.dmg) / math.max(1, Num(run.time))) },
				{ SUIC.T("Share"), string.format("%.0f%%", Num(source.share) * 100) },
			}
			bar:Show()
		else
			bar:Hide()
			bar.icon:Hide()
		end
	end
	noSources:SetText(table.getn(sources) == 0 and SUIC.T("None kept with this run.") or "")
	local said = "|cffffd100"..SUIC.T("Total damage").."|r "..SUIC.Short(Num(run.damage))
		.."    |cffffd100"..SUIC.T("DPS").."|r "..SUIC.Short(Num(run.dps))
	if run.healing then
		said = said.."    |cffffd100"..SUIC.T("Healing").."|r "..SUIC.Short(run.healing)
	end
	totals:SetText(said)
	local party = run.party or {}
	local best = 0
	for index = 1, table.getn(party) do
		best = math.max(best, Num(party[index].dmg))
	end
	local any = table.getn(party) > 0
	partyHeading:SetText(any and SUIC.T("Party") or "")
	partyDamage:SetText(any and SUIC.T("Damage") or "")
	partyRate:SetText(any and SUIC.T("DPS") or "")
	for index = 1, PARTY do
		local bar, hero = partyBars[index], party[index]
		if hero then
			local r, g, b = SUIC.ClassColor(hero.class)
			bar:SetValue(best > 0 and Num(hero.dmg) / best or 0)
			bar:SetStatusBarColor((r or 0.7) * 0.7, (g or 0.7) * 0.7, (b or 0.7) * 0.7)
			bar.left:SetText(tostring(hero.name or "?")..(hero.me and ("  |cffb0b0b0"..SUIC.T("you").."|r") or ""))
			bar.amount:SetText(SUIC.Short(hero.dmg))
			bar.right:SetText(SUIC.Short(hero.dps))
			bar.title = tostring(hero.name or "?")
			bar.numbers = { { SUIC.T("Total"), SUIC.Short(hero.dmg) }, { SUIC.T("Per second"), SUIC.Short(hero.dps) } }
			bar:Show()
		else
			bar:Hide()
		end
	end
end

------------------------------------------------------------------------------
-- The Loot tab: what the run dropped, the newest first, with its marks; and
-- its bosses, when each was due and when it fell.

local LOOT_ROW = 15
local loot = CreateFrame("Frame", nil, pane)
loot:SetAllPoints(pane)
loot:Hide()

local function LootText(template, point, x, y, page)
	page = page or loot
	local text = SUIC.Text(page, template)
	text:SetPoint(point, page, point, x, y)
	return text
end

local LOOT_TOP = -78
local lootHeading = LootText("GameFontNormalSmall", "TOPLEFT", 0, LOOT_TOP)
local lootMarks = SUIC.Text(loot, "GameFontHighlightSmall")
lootMarks:SetPoint("LEFT", lootHeading, "RIGHT", 12, 0)
local lootCount = LootText("GameFontDisableSmall", "TOPRIGHT", -50, LOOT_TOP)
local lootAt = LootText("GameFontDisableSmall", "TOPRIGHT", -3, LOOT_TOP)
local noLoot = LootText("GameFontDisableSmall", "TOPLEFT", 0, LOOT_TOP - 17)
local lootRows = {}
for index = 1, LOOT do
	local row = CreateFrame("Button", nil, loot)
	if math.mod(index, 2) == 1 then
		local band = row:CreateTexture(nil, "BACKGROUND")
		band:SetTexture(SUIC.FLAT)
		band:SetVertexColor(1, 1, 1, 0.045)
		band:SetAllPoints(row)
	end
	row:SetHeight(LOOT_ROW)
	row:SetPoint("TOPLEFT", loot, "TOPLEFT", 0, LOOT_TOP - 15 - (index - 1) * LOOT_ROW)
	row:SetPoint("RIGHT", loot, "RIGHT", 0, 0)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetWidth(LOOT_ROW - 3)
	row.icon:SetHeight(LOOT_ROW - 3)
	row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	row.name = SUIC.Text(row, "GameFontHighlightSmall")
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetWidth(PANE_WIDTH - 120)
	row.name:SetHeight(12)
	row.count = SUIC.Text(row, "GameFontHighlightSmall")
	row.count:SetPoint("RIGHT", row, "RIGHT", -50, 0)
	row.at = SUIC.Text(row, "GameFontHighlightSmall")
	row.at:SetPoint("RIGHT", row, "RIGHT", -3, 0)
	row:SetScript("OnEnter", function() SUIC.RunShowTip(this, this.tip, this.item) end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	lootRows[index] = row
end

-- The bosses, when each was due and when it fell, in a frame of their own:
-- under the Summary's numbers in its tab; in the full view under the damage,
-- which goes under the numbers (Lucas, 2026-11-15).
local bossPage = CreateFrame("Frame", nil, pane)
bossPage:SetWidth(PANE_WIDTH)
bossPage:SetHeight(140)
local BOSSES_TOP = 0
local BOSSES = 6
local bossHeading = LootText("GameFontNormalSmall", "TOPLEFT", 0, BOSSES_TOP, bossPage)
local bossDue = LootText("GameFontDisableSmall", "TOPRIGHT", -60, BOSSES_TOP, bossPage)
local bossFell = LootText("GameFontDisableSmall", "TOPRIGHT", -3, BOSSES_TOP, bossPage)
local bossRows = {}
for index = 1, BOSSES do
	local row = {}
	local y = BOSSES_TOP - 15 - (index - 1) * LOOT_ROW
	if math.mod(index, 2) == 1 then
		Band(bossPage, y + 2, LOOT_ROW)
	end
	row.name = LootText("GameFontHighlightSmall", "TOPLEFT", 0, y, bossPage)
	row.due = LootText("GameFontHighlightSmall", "TOPRIGHT", -60, y, bossPage)
	row.fell = LootText("GameFontHighlightSmall", "TOPRIGHT", -3, y, bossPage)
	bossRows[index] = row
end
-- Under them, the bosses killed after the victory, in endless mode, and the
-- whole run's elites and guardians.
local bossTotals = LootText("GameFontHighlightSmall", "TOPLEFT", 0, BOSSES_TOP - 15 - BOSSES * LOOT_ROW - 6, bossPage)
bossTotals:SetJustifyH("LEFT")

local function DrawLoot(run)
	lootHeading:SetText(SUIC.T("Loot"))
	lootMarks:SetText(run.marks and ("|cffffd100"..SUIC.T("Marks").."|r "..Count(run.marks)) or "")
	lootCount:SetText(SUIC.T("Count"))
	lootAt:SetText(SUIC.T("@loot:At"))
	local items = run.loot or {}
	for index = 1, LOOT do
		local row, item = lootRows[index], items[index]
		if item then
			row.item, row.tip = item.item, item.tip
			row.icon:SetTexture(item.icon or (SUIC.LootIcon and SUIC.LootIcon(item.name, item.item))
				or "Interface\\Icons\\INV_Misc_Bag_10")
			row.name:SetText("|c"..(item.color or "ffffffff")..tostring(item.name or "?").."|r"
				..(item.new and ("  |cff40ff40"..SUIC.T("@loot:New").."|r") or ""))
			row.count:SetText(tostring(item.count or 1))
			row.at:SetText(item.at and SUIC.Clock(item.at) or "|cff808080-|r")
			row:Show()
		else
			row:Hide()
		end
	end
	noLoot:SetText(table.getn(items) == 0 and SUIC.T("Nothing dropped in this run.") or "")
end

local function DrawBosses(run)
	bossHeading:SetText(SUIC.T("Bosses"))
	bossDue:SetText(SUIC.T("Due at"))
	bossFell:SetText(SUIC.T("Fell at"))
	local schedule = run.schedule or {}
	for index = 1, BOSSES do
		local row, boss = bossRows[index], schedule[index]
		if boss then
			row.name:SetText((boss.final and "|cffff8040" or "")..tostring(boss.name or "?")..(boss.final and "|r" or ""))
			row.due:SetText(SUIC.Clock(boss.at))
			if boss.fell then
				row.fell:SetText("|cff40ff40"..SUIC.Clock(boss.fell).."|r")
			elseif boss.state == "dead" then
				row.fell:SetText("|cff40ff40"..SUIC.T("@boss:Fell").."|r")
			else
				row.fell:SetText("|cff808080-|r")
			end
		else
			row.name:SetText("")
			row.due:SetText("")
			row.fell:SetText("")
		end
	end
	local said = ""
	if run.endless and run.won then
		said = SUIC.T("|cffd080ffEndless|r").." |cffffd100"..SUIC.T("bosses killed").."|r "
			..Count(math.max(0, Num(run.bosses) - Num(run.won.bosses))).."\n"
	end
	bossTotals:SetText(said.."|cffffd100"..SUIC.T("Elites killed").."|r "..Count(run.elites)
		.."    |cffffd100"..SUIC.T("Guardians killed").."|r "..Count(run.guardians)
		.."    |cff808080"..SUIC.T("(whole run)").."|r")
end

------------------------------------------------------------------------------
-- The tabs' pages, one at a time or, in the full view, all four at once: two
-- by two at the list's right, each under its name.

local PAGE_HEIGHT = 536         -- a page's room in the full view, its name's line with it
local FULL_WIDTH = PANE_LEFT + 2 * PANE_WIDTH + 24 + 24
-- The lower pages' tops, the lower pages' rows (380 down), the foot.
local FULL_HEIGHT = 70 + (PAGE_HEIGHT - 58) + 380 + 55
-- Each page's place in the full view: its column, and how far down its top
-- goes (its rows start 78 under its top, the hero's lines' room).
-- The damage right under the Summary's numbers, the bosses under it.
local FULL_PLACES = { { 0, 0 }, { 1, 0 }, { 0, -194 }, { 1, -PAGE_HEIGHT + 58 } }
local pageFrames = { summary, build, damage, loot }
local pageNames = {}
for index = 2, 4 do
	local name = SUIC.Text(pane, "GameFontNormal")
	local place = FULL_PLACES[index]
	name:SetPoint("TOPLEFT", pane, "TOPLEFT", place[1] * (PANE_WIDTH + 24), place[2] - 56)
	pageNames[index] = name
end

local function Full()
	return SUIC.DB().historyFull and true or false
end

local arranged
local function Arrange()
	local full = Full()
	if arranged == full then
		return
	end
	arranged = full
	for index = 2, 4 do
		local frame, place = pageFrames[index], FULL_PLACES[index]
		frame:ClearAllPoints()
		frame:SetWidth(PANE_WIDTH)
		frame:SetHeight(pane:GetHeight())
		if full then
			frame:SetPoint("TOPLEFT", pane, "TOPLEFT", place[1] * (PANE_WIDTH + 24), place[2])
			pageNames[index]:Show()
		else
			frame:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
			pageNames[index]:Hide()
		end
	end
	if full then
		window:SetWidth(FULL_WIDTH)
		window:SetHeight(FULL_HEIGHT)
		-- On a small screen the whole window smaller, so it all fits.
		local fit = math.min(1, (UIParent:GetHeight() - 20) / FULL_HEIGHT, (UIParent:GetWidth() - 20) / FULL_WIDTH)
		window:SetScale(math.max(0.5, fit))
	else
		window:SetWidth(WIDTH)
		window:SetHeight(HEIGHT)
		window:SetScale(1)
	end
end

-- The window's foot, under the run chosen: Pin, Delete and Full view, each a
-- button with a word of what it does.
local function FootButton(name, width, tip)
	local button = CreateFrame("Button", name, window, "UIPanelButtonTemplate")
	button:SetWidth(width)
	button:SetHeight(22)
	button.tip = tip
	button:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		GameTooltip:SetText(this:GetText() or "", 1, 1, 1)
		GameTooltip:AddLine(SUIC.T(this.tip), 1, 0.82, 0, 1)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return button
end

local pin = FootButton("SUICRunHistoryPin", 58, "A pinned run stays when the oldest runs go to make room.")
pin:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", PANE_LEFT, 18)
pin:SetScript("OnClick", function()
	local run = Runs()[chosen]
	if run then
		run.pinned = (not run.pinned) or nil
		Draw()
	end
end)

-- Delete asks once more on the button itself: a second click, within five
-- seconds, takes the run away.
local doomed, doomedAt
local delete = FootButton("SUICRunHistoryDelete", 98, "Takes this run out of the Run History for good. Click twice.")
delete:SetPoint("LEFT", pin, "RIGHT", 4, 0)
delete:SetScript("OnClick", function()
	local runs = Runs()
	local run = runs[chosen]
	if not run then
		return
	end
	if doomed == run and GetTime() - doomedAt < 5 then
		table.remove(runs, chosen)
		doomed = nil
	else
		doomed, doomedAt = run, GetTime()
	end
	Draw()
end)

local fullView = FootButton("SUICRunHistoryFull", 78, "All of the run on one screen: Summary, Build, Damage and Loot side by side. Click again for the tabs.")
fullView:SetPoint("RIGHT", close, "LEFT", -4, 0)
fullView:SetScript("OnClick", function()
	local db = SUIC.DB()
	db.historyFull = (not db.historyFull) or nil
	Draw()
end)

local function DrawRun(run)
	local r, g, b = SUIC.ClassColor(run.classKey)
	hero:SetText(tostring(run.hero or "?"))
	hero:SetTextColor(r or 1, g or 0.82, b or 0)
	outcome:SetText(Result(run))
	who:SetText(SUIC.TF("Level {1} {2} {3}", Count(run.level), tostring(run.race or ""), tostring(run.class or "")))
	where:SetText(tostring(run.zone or "?")..Difficulty(run))
	ago:SetText(Ago(run.at))
	if run.endless and run.won then
		-- Still going as it was last kept: left, until its end says otherwise.
		local ended = RESULT_COLORS[run.endless] and run.endless or nil
		endless:SetText(SUIC.TF("|cffd080ffEndless|r: {1} at {2}. |cff40ff40Victory|r at {3}.",
			(RESULT_COLORS[ended] or RESULT_COLORS.left)..SUIC.RunResultWord(ended).."|r",
			SUIC.Clock(run.time), SUIC.Clock(run.won.time)))
	else
		endless:SetText("")
	end
	local full = Full()
	local drawn = { false, DrawBuild, DrawDamage, DrawLoot }
	for index = 2, 4 do
		if full or tabChosen == index then
			pageFrames[index]:Show()
			drawn[index](run)
			pageNames[index]:SetText(SUIC.T(TABS[index][1]))
		else
			pageFrames[index]:Hide()
		end
	end
	if not (full or tabChosen == 1) then
		summary:Hide()
		bossPage:Hide()
		return
	end
	summary:Show()
	for index = 1, table.getn(NUMBERS) do
		local number = NUMBERS[index]
		local value = run[number[2]]
		cells[index].name:SetText(SUIC.T(number[1]))
		cells[index].value:SetText(value ~= nil and number[3](value) or "|cff808080-|r")
	end
	bossPage:ClearAllPoints()
	if full then
		-- Under the damage's last line: its totals, or its party's last hero.
		local heroes = math.min(PARTY, table.getn(run.party or {}))
		local under = heroes > 0 and (PARTY_TOP - 15 - heroes * SOURCE_ROW) or (TOTALS_TOP - 14)
		bossPage:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, FULL_PLACES[3][2] + under - 14)
	else
		bossPage:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -84 - 7 * 22 - 10)
	end
	bossPage:Show()
	DrawBosses(run)
end

Draw = function()
	local runs = Runs()
	local count = table.getn(runs)
	Arrange()
	offset = math.max(0, math.min(Most(), offset))
	chosen = math.max(1, math.min(count, chosen))
	scroll:SetMinMaxValues(0, Most())
	scroll:SetValue(offset)
	if count > ROWS then
		scroll:Show()
	else
		scroll:Hide()
	end
	for index = 1, ROWS do
		local row = rows[index]
		local place = offset + index
		local run = runs[place]
		if run then
			row.place = place
			-- Endless on the top line: the zone's has no room for it.
			row.top:SetText(Result(run).."  "..tostring(run.class or "?").."  |cffb0b0b0"..SUIC.TF("Level {1}", Count(run.level)).."|r"
				..(run.endless and ("  "..SUIC.T("|cffd080ffEndless|r")) or ""))
			row.clock:SetText(SUIC.Clock(run.time))
			row.ago:SetText((run.pinned and ("|cffffd100"..SUIC.T("Pinned").."|r  ") or "")..Ago(run.at))
			-- The zone's line ends where the time ago starts.
			row.sub:SetWidth(math.max(60, LIST_WIDTH - 20 - row.ago:GetStringWidth()))
			row.sub:SetText(tostring(run.zone or "?")..Difficulty(run, true))
			if place == chosen then
				row.selected:Show()
			else
				row.selected:Hide()
			end
			row:Show()
		else
			row:Hide()
		end
	end
	for index = 1, table.getn(tabs) do
		tabs[index]:SetText(SUIC.T(tabs[index].words))
		if index == tabChosen then
			tabs[index]:LockHighlight()
			tabs[index]:SetTextColor(1, 0.82, 0)
		else
			tabs[index]:UnlockHighlight()
			tabs[index]:SetTextColor(0.6, 0.6, 0.6)
		end
	end
	fullView:SetText(SUIC.T("Full view"))
	if Full() then
		fullView:LockHighlight()
	else
		fullView:UnlockHighlight()
	end
	if count == 0 then
		none:SetText(SUIC.T("No runs kept yet. A run is kept here as it ends."))
		counted:SetText("")
		pane:Hide()
		pin:Hide()
		delete:Hide()
		for index = 1, table.getn(tabs) do
			tabs[index]:Hide()
		end
		return
	end
	none:SetText("")
	counted:SetText(count == 1 and SUIC.T("1 run kept") or SUIC.TF("{1} runs kept", count))
	for index = 1, table.getn(tabs) do
		if Full() then
			tabs[index]:Hide()
		else
			tabs[index]:Show()
		end
	end
	local run = runs[chosen]
	pin:SetText(run.pinned and SUIC.T("Unpin") or SUIC.T("Pin"))
	pin:Show()
	if doomed == run and GetTime() - doomedAt < 5 then
		delete:SetText("|cffff5040"..SUIC.T("Really delete?").."|r")
	else
		doomed = nil
		delete:SetText(SUIC.T("Delete"))
	end
	delete:Show()
	pane:Show()
	DrawRun(runs[chosen])
end

-- A run kept with the window open: in the list at once.
function SUIC.RunHistoryKept()
	if window:IsShown() then
		Draw()
	end
end

window:SetScript("OnShow", function()
	window.heading:SetText(SUIC.T("Run History"))
	Draw()
end)

-- /suic history and the Build panel's button: the window, open or shut.
function SUIC.ToggleRunHistory()
	if window:IsShown() then
		window:Hide()
	else
		chosen, offset = 1, 0
		window:Show()
	end
end

SUIC.OnStart(function()
	Runs()
	talent:RegisterEvent("CHAT_MSG_SYSTEM")
	watcher:Show()
end)
