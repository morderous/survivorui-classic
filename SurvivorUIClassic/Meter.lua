-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the damage meter, at the bottom of the right column. A
-- panel of bars, the most first: the spell's icon, its place and name, then
-- the amount, the amount a second and the share. It stands in levels: the
-- party by hero, a hero's sources, a source's detail. A click on a line goes
-- down one, a right click goes up one; alone, the top is one's own sources.
-- Its title is the way down to the level shown, each step of it a click back
-- there. Under the title, two selectors: what is counted, damage or healing,
-- and over what: the run, the last boss fight, or the last seconds.
-- At its foot, the amount a second and the total, each named. In the detail
-- of a source of one's own damage, over the foot: its hits, its crits, the
-- average hit and the biggest, counted off the game's feed of hits (Crits.lua).
-- Hover a line, a button or the foot for what it says. It stands as tall as
-- the lines set; those that do not fit roll by the wheel or the scroll bar.
-- At the title's right: the small lines folded into one, Others; Reset, which
-- starts one's own damage of the run over (a new run does by itself); and +,
-- a second window with buttons of its own, closed by its -.
--
-- It stands in for the game's meter, which is put away while it is on and
-- given back as the game closes. From the game's meter API v1 (the feed,
-- below). In a game without it there are no levels: the title picks one of
-- five pages (Damage Done, DPS, Healing, Boss Damage, Party), from
-- AZS_GetMeter, AZS_GetHealing, AZS_GetBossMeter and AZS_GetPartyMeter.

local W = SUIC.WIDTH
local PAD = SUIC.PAD
local LINE = 14                 -- a bar's height
local STEP = 17                 -- a bar and the room under it
local FONT = 8                  -- its texts' size (the options' Font size)
-- White in Barlow, outlined, over the bars' colors; a name in letters it lacks
-- in the game's own font. Barlow Condensed reads small: two points up.
local BARLOW = "Interface\\AddOns\\SurvivorUIClassic\\Fonts\\BarlowCondensed-SemiBold.ttf"
local BARLOW_BUMP = 2
-- The numbers in columns at the bars' right, each its text in its middle, as
-- the build list's: the page's number, the damage a second where it has one,
-- the share.
local SHARE_COLUMN = 30
local RATE_COLUMN = 34
local AMOUNT_COLUMN = 38
local TOP = SUIC.TITLE + 4
local STRIP = 21                -- the selectors' and the columns' names' row (with the feed)
local HEADS = 12                -- the columns' names' height, in that row
local FOOT = 17                 -- the numbers at the foot (with the feed)
local MOST = 15
-- The scroll bar, in line with the title's rule; the lines give it this much
-- of their width while it shows.
local ROLL_WIDTH, ROLL_ROOM = 7, 7
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

-- The pages of a game without the meter API v1.
local MODES = {
	{ key = "damage", name = "Damage Done", rate = "dps" },
	{ key = "dps", name = "DPS", rate = "dps" },
	{ key = "healing", name = "Healing", rate = "hps", three = true },
	{ key = "bosses", name = "Boss Damage", rate = "dps", three = true },
	{ key = "party", name = "Party", rate = "dps", three = true, party = true },
}

-- One color per source, in the order they first show: twelve hues far from
-- each other, so neighbours never look alike (Survivor UI's meter's).
local PALETTE = {
	{ 0.93, 0.70, 0.15 }, { 0.85, 0.20, 0.25 }, { 0.25, 0.45, 0.95 }, { 0.30, 0.75, 0.30 },
	{ 0.65, 0.35, 0.90 }, { 0.95, 0.50, 0.10 }, { 0.15, 0.70, 0.70 }, { 0.95, 0.40, 0.70 },
	{ 0.65, 0.85, 0.20 }, { 0.60, 0.40, 0.25 }, { 0.45, 0.75, 1.00 }, { 0.55, 0.55, 0.70 },
}

------------------------------------------------------------------------------
-- The windows: the main one, in the right column, and with the feed a second
-- one, opened by the main one's +. Every function below works on the window
-- in hand, set by Use: a script of a frame takes its own window first.

local windows = {}
local win                       -- the window in hand
local panel, lines, nav         -- its frame, its lines, where it stands

local function Use(window)
	win = window
	panel, lines, nav = window.panel, window.lines, window.nav
end

------------------------------------------------------------------------------
-- Icons and colors.

-- A source's icon: Icons.lua's search (a pet's, a weapon's, a build spell's
-- button, a talent's, an item's).
local IconOf = SUIC.IconOf

local colors, given = {}, 0
local function ColorOf(name)
	if not colors[name] then
		given = given + 1
		colors[name] = PALETTE[math.mod(given - 1, table.getn(PALETTE)) + 1]
	end
	return colors[name]
end

-- For the combat numbers: a source in the color its line has here.
SUIC.MeterColor = ColorOf

local function ClassColor(class)
	local r, g, b = SUIC.ClassColor(class)
	if r then
		return { r, g, b }
	end
	return { 0.7, 0.7, 0.7 }
end

------------------------------------------------------------------------------
-- The lines.

local function LineEnter()
	local entry = this.entry
	if not entry then
		return
	end
	local at = this.window.nav
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	if entry.folded then
		GameTooltip:SetText(entry.name)
		for index = 1, table.getn(entry.folded) do
			local each = entry.folded[index]
			GameTooltip:AddDoubleLine(SUIC.Native(each.name or "?"), SUIC.Short(each.dmg).."  "
				..math.floor((tonumber(each.share) or 0) * 100 + 0.5).."%", 1, 1, 1, 0.8, 0.8, 0.8)
		end
		GameTooltip:Show()
		return
	end
	GameTooltip:SetText(SUIC.Native(entry.name or "?"))
	GameTooltip:AddDoubleLine(SUIC.T("Total"), SUIC.Short(entry.dmg), 1, 0.82, 0, 1, 1, 1)
	GameTooltip:AddDoubleLine(SUIC.T("Per second"), SUIC.Short(entry.dps), 1, 0.82, 0, 1, 1, 1)
	GameTooltip:AddDoubleLine(SUIC.T("Share"), math.floor((tonumber(entry.share) or 0) * 100 + 0.5).."%", 1, 0.82, 0, 1, 1, 1)
	if entry.top and entry.top ~= "" then
		GameTooltip:AddDoubleLine(SUIC.T("Best spell"), SUIC.Native(entry.top), 1, 0.82, 0, 1, 1, 1)
	end
	-- With the levels: what a click does here.
	if at.level and at.level ~= "detail" and entry.key then
		GameTooltip:AddLine(SUIC.T("Click to open it."), 0.6, 0.6, 0.6)
	end
	if at.level and at.level ~= at.top then
		GameTooltip:AddLine(SUIC.T("Right-click to go back."), 0.6, 0.6, 0.6)
	end
	GameTooltip:Show()
end

local function HideTip()
	GameTooltip:Hide()
end

-- The lines' texts at the size chosen (the options' Damage meter tab).
function SUIC.ApplyMeterFont()
	local size = (tonumber(SUIC.DB().meterFont) or FONT) + BARLOW_BUMP
	for each = 1, table.getn(windows) do
		local all = windows[each].lines
		for index = 1, MOST do
			local texts = all[index].texts
			for text = 1, table.getn(texts) do
				texts[text]:SetFont(BARLOW, size, "OUTLINE")
				texts[text]:SetShadowOffset(0, 0)
			end
			all[index].said = nil
		end
	end
end

-- The columns of a page: the second only where it has one. The name has the
-- rest, on one line: a text given a width would break in two. With the scroll
-- bar there, the lines leave it room.
local function Arrange(mode, rolling)
	if panel.arranged == mode and panel.arrangedRolling == rolling then
		return
	end
	panel.arranged, panel.arrangedRolling = mode, rolling
	local columns = SHARE_COLUMN + AMOUNT_COLUMN + (mode.three and RATE_COLUMN or 0)
	local room = rolling and ROLL_ROOM or 0
	for index = 1, MOST do
		local line = lines[index]
		line:SetWidth(W - 2 * PAD - LINE - 3 - room)
		line.amount:ClearAllPoints()
		line.amount:SetPoint("CENTER", line, "RIGHT", AMOUNT_COLUMN / 2 - columns, 0)
		line.room = W - 2 * PAD - LINE - 8 - columns - room
		line.said = nil
		if mode.three then
			line.rate:Show()
		else
			line.rate:Hide()
		end
	end
end

-- The name on one line, cut short with dots to its room: all there is up to
-- the amount's own text, which stands in the middle of its column. The tag
-- goes first.
local function SayName(line, name, tag)
	local text = name..tag
	local room = math.floor(line.room + math.max(0, (AMOUNT_COLUMN - line.amount:GetStringWidth()) / 2 - 3))
	if line.said == text and line.saidRoom == room then
		return
	end
	line.said, line.saidRoom = text, room
	local size = (tonumber(SUIC.DB().meterFont) or FONT) + BARLOW_BUMP
	if string.find(text, "[\128-\255]") then
		line.left:SetFont(line.gameFont, size - BARLOW_BUMP, "OUTLINE")
	else
		line.left:SetFont(BARLOW, size, "OUTLINE")
	end
	line.left:SetText(text)
	if line.left:GetStringWidth() <= room then
		return
	end
	-- The name whole with no tag, before any letter goes.
	line.left:SetText(name)
	if line.left:GetStringWidth() <= room then
		return
	end
	local kept = SUIC.Length(name)
	while kept > 1 do
		kept = kept - 1
		line.left:SetText(SUIC.Cut(name, kept).."...")
		if line.left:GetStringWidth() <= room then
			return
		end
	end
end

local function Mode()
	local key = SUIC.DB().meterMode
	for index = 1, table.getn(MODES) do
		if MODES[index].key == key then
			return MODES[index]
		end
	end
	return MODES[1]
end

-- The DPS page (Survivor UI's): each spell's damage a second, on the same
-- clock as the run's, so the column adds up to it.
local function PerSecond(lines, total, rate)
	local per = (total or 0) > 0 and (rate or 0) / total or 0
	local shown = {}
	for index = 1, table.getn(lines or {}) do
		local line = lines[index]
		table.insert(shown, { name = line.name, dmg = (tonumber(line.dmg) or 0) * per, share = line.share,
			proc = line.proc, perSecond = true })
	end
	return shown, total, rate
end

-- The damage a second right now: the run's total as it climbs over the last
-- five seconds of the run's clock; nil before five seconds are seen.
local recent = {}
local function NowRate(total)
	local at = AZS_GetRunTime and AZS_GetRunTime() or 0
	local last = recent[table.getn(recent)]
	if last and (at < last.at or total < last.total) then
		recent = {}
		last = nil
	end
	if not last or at > last.at then
		table.insert(recent, { at = at, total = total })
	end
	while table.getn(recent) > 1 and recent[1].at < at - 5 do
		table.remove(recent, 1)
	end
	local span = at - recent[1].at
	if span < 1 then
		return nil
	end
	return (total - recent[1].total) / span
end

-- Reset: the game's numbers cover the whole run, so the meter keeps what each
-- spell stood at when Reset was pressed, and shows what came after (Survivor
-- UI's). Kept with the run it was pressed in.
local base = nil                -- { run = AZS_ZONE_UPDATED, at = run second, sources = { [name] = damage } }

local function TakeBase()
	local data = AZS_GetMeter and AZS_GetMeter() or {}
	base = { run = AZS_ZONE_UPDATED, at = AZS_GetRunTime and AZS_GetRunTime() or 0, sources = {} }
	for index = 1, table.getn(data) do
		base.sources[data[index].name or "?"] = tonumber(data[index].dmg) or 0
	end
end

-- The game's lines, or what came after Reset: each spell's damage less what
-- it had then, the most first, its share and damage a second from there.
local function SinceReset()
	local data, total, rate = AZS_GetMeter()
	if base and base.run ~= AZS_ZONE_UPDATED then
		base = nil
	end
	if not base then
		return data, total, rate
	end
	local span = (AZS_GetRunTime and AZS_GetRunTime() or 0) - base.at
	local shown, sum = {}, 0
	for index = 1, table.getn(data or {}) do
		local entry = data[index]
		local dmg = (tonumber(entry.dmg) or 0) - (base.sources[entry.name or "?"] or 0)
		if dmg > 0 then
			table.insert(shown, { name = entry.name, dmg = dmg, dps = span > 0 and dmg / span or 0, proc = entry.proc })
			sum = sum + dmg
		end
	end
	table.sort(shown, function(a, b) return a.dmg > b.dmg end)
	for index = 1, table.getn(shown) do
		shown[index].share = shown[index].dmg / sum
	end
	return shown, sum, span > 0 and sum / span or 0
end

------------------------------------------------------------------------------
-- The feed: the game's meter API v1 (AZS_GetMeterContext, AZS_GetMeterSnapshot,
-- AZS_CreateMeterCheckpoint), read into the lines the bars are drawn from.
-- Three levels: the party by hero, a hero's sources, a source's detail; each
-- for damage or healing, over the run, the boss fight or the last seconds.
-- A game without it (an old version, by the launcher's Time Machine) has the
-- four old functions below, as before.

local Feed = {}
SUIC.MeterFeed = Feed
local NOW_SECONDS = 30          -- the period "now": the run's last seconds (5 jumped about too much)
-- Refusals that only say there is nothing yet: no boss met, no party, the
-- party's numbers not in.
local QUIET = { NO_ENCOUNTER = true, NO_PARTY = true, NOT_READY = true }
local ASKED = { "metric", "scope", "ownerId", "period", "groupBy", "windowSeconds", "healingPerspective", "checkpointId" }
-- run: the run the answers kept are of; kept: [the asking] = { snap = the
-- last good answer, code = the last refusal, wait = not asked again before,
-- at = asked at }; checkpoint: Reset's, { id, run }.
local feed = { kept = {} }

function Feed.Has()
	return AZS_GetMeterSnapshot ~= nil and AZS_GetMeterContext ~= nil
end

-- Reset's checkpoint given back to the game.
function Feed.Forget()
	local checkpoint = feed.checkpoint
	feed.checkpoint = nil
	if checkpoint and AZS_ReleaseMeterCheckpoint then
		pcall(AZS_ReleaseMeterCheckpoint, checkpoint.id)
	end
end

-- The run's context (asked with no argument at all: the game refuses even a
-- nil), once a frame. A new run forgets the old one's answers and its Reset.
function Feed.Context()
	if not Feed.Has() then
		return nil
	end
	local now = GetTime()
	if feed.contextAt == now then
		return feed.context
	end
	local ok, context = pcall(AZS_GetMeterContext)
	if not (ok and type(context) == "table" and type(context.runId) == "string" and context.runId ~= "") then
		context = nil
	elseif context.runId ~= feed.run then
		feed.run = context.runId
		feed.kept = {}
		Feed.Forget()
	end
	feed.contextAt, feed.context = now, context
	return context
end

-- A snapshot asked for: the answer, or the last good one to the same asking
-- with the refusal's code beside it (nil and the code when there was none).
-- A refused asking waits as long as the game says before it is sent again.
function Feed.Ask(query)
	local context = Feed.Context()
	if not context then
		return nil, "NO_RUN"
	end
	query.apiVersion = 1
	query.runId = context.runId
	query.windowSeconds = query.windowSeconds or 0
	local key = ""
	for index = 1, table.getn(ASKED) do
		key = key..tostring(query[ASKED[index]]).."|"
	end
	local slot = feed.kept[key]
	if not slot then
		slot = {}
		feed.kept[key] = slot
	end
	local now = GetTime()
	if slot.at == now or (slot.wait and now < slot.wait) then
		return slot.snap, slot.code
	end
	slot.at = now
	local ok, snap, problem = pcall(AZS_GetMeterSnapshot, query)
	if ok and type(snap) == "table" and type(snap.rows) == "table" then
		slot.snap, slot.code, slot.wait = snap, nil, nil
		return snap
	end
	problem = ok and type(problem) == "table" and problem or {}
	slot.code = problem.code or "RAISED"
	slot.wait = now + (tonumber(problem.retryAfterSeconds) or 1)
	return slot.snap, slot.code
end

-- What is wanted, as the game's query. want: metric "damage" or "healing";
-- period "run", "boss" or "now"; owner, a hero's id (nil: one's own);
-- sinceReset, to count from Reset where the period is the run.
local function Query(want, scope, groupBy)
	local query = { metric = want.metric or "damage", scope = scope, groupBy = groupBy, period = "run", windowSeconds = 0 }
	if scope ~= "party" and want.owner then
		query.scope, query.ownerId = "owner", want.owner
	end
	if want.period == "boss" then
		query.period = "encounter"
	elseif want.period == "now" then
		query.windowSeconds = NOW_SECONDS
	end
	if query.metric == "healing" then
		query.healingPerspective = "received"
	end
	if want.sinceReset and feed.checkpoint and query.period == "run" and query.windowSeconds == 0 then
		query.checkpointId = feed.checkpoint.id
	end
	return query
end

-- A checkpoint the game no longer has is let go, and the whole run asked for.
local function Answer(want, scope, groupBy)
	if not Feed.Context() then
		return nil, "NO_RUN"
	end
	local query = Query(want, scope, groupBy)
	local snap, code = Feed.Ask(query)
	if code and query.checkpointId and (code == "INVALID_ARGUMENT" or string.find(code, "CHECKPOINT", 1, true)) then
		Feed.Forget()
		snap, code = Feed.Ask(Query(want, scope, groupBy))
	end
	return snap, code
end

local function Windowed(snap)
	return (tonumber(snap.query and snap.query.windowSeconds) or 0) > 0
end

-- A row's amount and its amount a second (the totals' too). Asked with a
-- window, displayAmount and share are still the whole period's: the window's
-- are windowAmount and recentRate.
local function Amount(row, window)
	if window then
		local recent = row.recentRate
		return tonumber(row.windowAmount or (recent and recent.amount)) or 0, tonumber(recent and recent.value) or 0
	end
	local rate = row.displayRate
	return tonumber(row.displayAmount) or 0, tonumber(rate and rate.value) or 0
end

-- What set a proc off: the row's own first origin (the detail's rows), or its
-- members' among the contributions.
local function Origin(row, snap, holder)
	local keys = row.originSourceKeys
	if keys and keys[1] then
		return keys[1]
	end
	if not row.memberIds then
		return nil
	end
	if not holder.members then
		holder.members = {}
		for _, each in pairs(snap.contributions or {}) do
			if type(each) == "table" and each.rowId then
				holder.members[each.rowId] = each
			end
		end
	end
	for index = 1, table.getn(row.memberIds) do
		local member = holder.members[row.memberIds[index]]
		keys = member and member.originSourceKeys
		if keys and keys[1] then
			return keys[1]
		end
	end
end

-- The line a row goes to, as the game's own meter names them: a proc by what
-- set it off ("Frenzy", not the Multi-Shot it fires), a pet's or a totem's
-- blows by the pet or the totem, the rest by the source. Gives the name, 1 for
-- a proc, the source named, and the pet's or totem's name where it is one's.
-- One's own wolf and raptor in the look of a White Devilsaur (Crits.lua) go by
-- that name, the two as one line: the game still has them as Wolf and Raptor.
local LOOKS = { wolf = true, raptor = true }
local function Named(row, snap, holder)
	local sources = snap.sources or {}
	local source = sources[row.sourceKey]
	local actor = row.actorId and snap.actors and snap.actors[row.actorId]
	local minion = actor and actor.kind ~= "hero" and actor.parentActorId and actor.name
	if minion and actor.kind == "pet" and LOOKS[actor.petFamilyKey or ""] and SUIC.PetLook then
		local context = Feed.Context()
		if context and row.ownerId == context.localOwnerId then
			minion = SUIC.PetLook() or minion
		end
	end
	if row.procClassification == "proc" then
		local origin = Origin(row, snap, holder)
		local from = origin and sources[origin]
		local name = (from and from.name) or (origin and SUIC.MeterName(origin))
		if name then
			return name, 1, from or source, minion
		end
		return (source and source.name) or tostring(row.sourceKey or "?"), 1, source, minion
	end
	if minion then
		return minion, 0, nil, minion
	end
	return (source and source.name) or tostring(row.sourceKey or "?"), 0, source, nil
end

-- The lines the most first, each with its share of them all.
local function Rank(lines, sum)
	table.sort(lines, function(a, b)
		if a.dmg ~= b.dmg then
			return a.dmg > b.dmg
		end
		return tostring(a.name) < tostring(b.name)
	end)
	for index = 1, table.getn(lines) do
		lines[index].share = sum > 0 and lines[index].dmg / sum or 0
	end
	return lines
end

-- A snapshot's rows as the bars' lines: name, dmg, dps, share, proc. Rows of
-- one name are one line (a Shaman's every totem is an actor of its own), a
-- proc apart from what is not one, told by its tag. key says the line to
-- Feed.Detail; owner narrows a party's rows to one hero's.
local function SourceLines(snap, owner)
	local window = Windowed(snap)
	local lines, byKey, holder, sum = {}, {}, {}, 0
	for index = 1, table.getn(snap.rows) do
		local row = snap.rows[index]
		local amount, rate = Amount(row, window)
		if amount > 0 and (not owner or row.ownerId == owner) then
			local name, proc, source = Named(row, snap, holder)
			local key = (proc == 1 and "proc|" or "line|")..name
			local line = byKey[key]
			if not line then
				line = { name = name, key = key, dmg = 0, dps = 0, proc = proc, owner = row.ownerId,
					sourceKey = source and source.sourceKey, icon = source and source.icon and source.icon.path }
				byKey[key] = line
				table.insert(lines, line)
			end
			line.dmg = line.dmg + amount
			line.dps = line.dps + rate
			sum = sum + amount
		end
	end
	return Rank(lines, sum)
end

-- What a level gives: its lines, the total, the total a second, and the
-- refusal's code where the lines are an older answer's (or none). No lines at
-- all (nil) when the game gave nothing it can be read from.
local function Give(snap, code, lines)
	if not snap then
		if QUIET[code] then
			return {}, 0, 0, code
		end
		return nil, nil, nil, code
	end
	local total, rate = Amount(snap.totals or {}, Windowed(snap))
	return lines, total, rate, code
end

-- The party, a line a hero: name, class, owner (their id, for Feed.Sources).
-- want.top asks for each one's best spell too.
function Feed.Party(want)
	local snap, code = Answer(want, "party", "owner")
	if not snap then
		return Give(nil, code)
	end
	local window = Windowed(snap)
	local lines, sum = {}, 0
	for index = 1, table.getn(snap.rows) do
		local row = snap.rows[index]
		local amount, rate = Amount(row, window)
		local actor = snap.actors and snap.actors[row.ownerId]
		if amount > 0 and row.ownerId then
			table.insert(lines, { name = (actor and actor.name) or tostring(row.ownerId), key = row.ownerId, owner = row.ownerId,
				class = actor and actor.classKey, dmg = amount, dps = rate, proc = 0 })
			sum = sum + amount
		end
	end
	Rank(lines, sum)
	local spells = want.top and table.getn(lines) > 0 and Answer(want, "party", "actor_source")
	if spells then
		for index = 1, table.getn(lines) do
			local best = SourceLines(spells, lines[index].owner)[1]
			lines[index].top = best and best.name
		end
	end
	return Give(snap, code, lines)
end

-- A hero's sources (want.owner; one's own without it).
function Feed.Sources(want)
	local snap, code = Answer(want, "self", "actor_source")
	return Give(snap, code, snap and SourceLines(snap))
end

-- One line of Feed.Sources (want.key, the line's key) opened: its rows by
-- source, pet or totem, school, and whether over time; alike rows as one. The
-- shares are of the line, and so are the total and the total a second. twin,
-- on the lines: another line has the same name, a proc's beside a plain one.
function Feed.Detail(want)
	local snap, code = Answer(want, "self", "detail")
	if not snap then
		return Give(nil, code)
	end
	local window = Windowed(snap)
	local lines, byKey, holder, sum, perSecond = {}, {}, {}, 0, 0
	for index = 1, table.getn(snap.rows) do
		local row = snap.rows[index]
		local amount, rate = Amount(row, window)
		if amount > 0 then
			local name, proc, _, minion = Named(row, snap, holder)
			-- The same name on two lines, a proc and not one: twin.
			if (proc == 1 and "line|" or "proc|")..name == want.key then
				lines.twin = true
			end
			if (proc == 1 and "proc|" or "line|")..name == want.key then
				local source = snap.sources and snap.sources[row.sourceKey]
				local spell = (source and source.name) or tostring(row.sourceKey or "?")
				local key = spell.."|"..tostring(minion).."|"..tostring(row.schoolMask).."|"..tostring(row.periodicity).."|"
					..tostring(row.creditKind)
				local line = byKey[key]
				if not line then
					line = { name = spell, key = key, dmg = 0, dps = 0, proc = proc, owner = row.ownerId, actor = minion or nil,
						school = row.schoolMask, periodic = row.periodicity == "periodic", credit = row.creditKind,
						sourceKey = row.sourceKey, icon = source and source.icon and source.icon.path }
					byKey[key] = line
					table.insert(lines, line)
				end
				line.dmg = line.dmg + amount
				line.dps = line.dps + rate
				sum = sum + amount
				perSecond = perSecond + rate
			end
		end
	end
	return Rank(lines, sum), sum, perSecond, code
end

-- Reset by the game's own checkpoint (the run's id alone): the run's lines
-- count from it, the one before let go. False where the game has none to give.
function Feed.Reset()
	local context = AZS_CreateMeterCheckpoint and Feed.Context()
	if not context then
		return false
	end
	local ok, made = pcall(AZS_CreateMeterCheckpoint, context.runId)
	if not (ok and type(made) == "table" and type(made.checkpointId) == "string") then
		return false
	end
	Feed.Forget()
	feed.kept = {}
	feed.checkpoint = { id = made.checkpointId, run = context.runId, at = made.atRunSeconds }
	return true
end

-- A page of a game without the feed.
local function Data(mode)
	if mode.key == "dps" and AZS_GetMeter then
		return PerSecond(SinceReset())
	elseif mode.key == "healing" and AZS_GetHealing then
		return AZS_GetHealing()
	elseif mode.key == "bosses" and AZS_GetBossMeter then
		return AZS_GetBossMeter()
	elseif mode.key == "party" and AZS_GetPartyMeter then
		return AZS_GetPartyMeter()
	elseif AZS_GetMeter then
		return SinceReset()
	end
	return {}, 0, 0
end

------------------------------------------------------------------------------
-- The levels, with the feed. Kept in the settings: the metric and the period
-- (meterMetric and meterPeriod; the second window's in meter2). For the run
-- only, a window's own: the level, the hero and the source opened; a new run
-- is back at the top.

local METRICS = { damage = "Damage", healing = "Healing" }
local PERIODS = { run = "Run", boss = "Boss", now = "Now" }
-- How a level is drawn: the party's lines in their classes' colors, with no
-- icon and never folded; rate, the word of the amount a second.
local PARTY_VIEW = { three = true, party = true }
local SOURCE_VIEW = { three = true }
-- A window's nav: level, "party", "sources" or "detail"; top, the highest
-- there is, "party" or, alone, "sources"; owner, ownerName: the hero opened
-- (owner nil: one's own); key, name: the source opened; run: the run all this
-- is of; alone: the game said there is no party.

-- The way: trail[1..trail.n], each { name, level }.
local trail = { n = 0, {}, {}, {} }
local function Step(name, level)
	trail.n = trail.n + 1
	trail[trail.n].name, trail[trail.n].level = name, level
end

-- Where the window in hand keeps its metric and its period.
local function Kept()
	local db = SUIC.DB()
	if win.main then
		return db, "meterMetric", "meterPeriod"
	end
	if type(db.meter2) ~= "table" then
		db.meter2 = {}
	end
	return db.meter2, "metric", "period"
end

local function View()
	local at, metric, period = Kept()
	return METRICS[at[metric]] and at[metric] or "damage", PERIODS[at[period]] and at[period] or "run"
end

-- Where the meter stands, set right for this moment: nil out of a run.
local function Where()
	local context = Feed.Context()
	if not context then
		return nil
	end
	if nav.run ~= context.runId then
		nav.run, nav.level, nav.owner, nav.ownerName, nav.key, nav.name, nav.alone = context.runId, nil, nil, nil, nil, nil, nil
		panel.scrolled = 0
	end
	local party = context.partyState ~= nil and context.partyState ~= "solo" and not nav.alone
	nav.top = party and "party" or "sources"
	if not party then
		nav.owner, nav.ownerName = nil, nil
	end
	if not nav.level or (nav.level == "party" and not party) then
		nav.level = nav.top
	end
	return nav
end

-- The level's lines: how they are drawn, the lines, the total, the total a
-- second, and whether Reset counts here (one's own damage of the run); the
-- way to the level goes into the trail: "Party", the hero, the source; alone
-- it starts at the metric's word, not at the hero's name. A refused asking
-- gives the last good answer, or no lines.
local function Levels()
	local metric, period = View()
	local view = SOURCE_VIEW
	PARTY_VIEW.rate = metric == "healing" and "HPS" or "DPS"
	SOURCE_VIEW.rate = PARTY_VIEW.rate
	trail.n = 0
	if not Where() then
		Step(SUIC.T(METRICS[metric]), "sources")
		return view, {}, 0, 0, false
	end
	local want = { metric = metric, period = period, top = true }
	local lines, total, rate, code
	if nav.level == "party" then
		lines, total, rate, code = Feed.Party(want)
		if code == "NO_PARTY" then
			nav.alone = true
			Where()
		end
	end
	local resets = false
	if nav.top == "party" then
		Step(SUIC.T("Party"), "party")
	end
	if nav.level == "party" then
		view = PARTY_VIEW
	else
		Step(nav.ownerName or SUIC.T(METRICS[metric]), "sources")
		want.owner, want.key = nav.owner, nav.key
		want.sinceReset = not nav.owner and metric == "damage"
		resets = want.sinceReset and period == "run"
		if nav.level == "detail" then
			Step(SUIC.Native(nav.name or "?"), "detail")
			lines, total, rate = Feed.Detail(want)
		else
			if resets and base and base.run == AZS_ZONE_UPDATED then
				-- A Reset the game could not take, kept the old way.
				lines, total, rate = SinceReset()
			else
				lines, total, rate = Feed.Sources(want)
			end
		end
	end
	return view, lines or {}, total or 0, rate or 0, resets
end

-- A proc's tag, as Survivor UI's meter has them: a neck's own damage (the
-- jewelry codex's necks, or a class amulet, "Amulet of the Inferno:
-- Consecration"), a talent's (the game's talents), the rest a proc's (a
-- ring's, a trinket's).
local NECKS = {
	["Amulet of Vek'nilash"] = true, ["Amulet of the Darkmoon"] = true, ["Animated Chain Necklace"] = true,
	["Choker of Enlightenment"] = true, ["Choker of the Fire Lord"] = true, ["Jeklik's Opaline Talisman"] = true,
	["Malice Stone Pendant"] = true, ["Mark of Fordring"] = true, ["Medallion of Steadfast Might"] = true,
	["Onyxia Tooth Pendant"] = true, ["Pendant of the Fallen Dragon"] = true, ["Prestor's Talisman of Connivery"] = true,
	["Pristine Enchanted South Seas Kelp"] = true, ["Talvash's Enhancing Necklace"] = true, ["The Eye of Hakkar"] = true,
	["Woven Ivy Necklace"] = true,
}

local function Tag(entry)
	local name = entry.name or ""
	if tonumber(entry.proc) ~= 1 then
		return ""
	elseif NECKS[name] or string.find(name, ": ", 1, true) then
		return " |cffd0d0d0("..SUIC.T("neck")..")|r"
	elseif (SUIC_TALENT_ICONS and SUIC_TALENT_ICONS[name]) or SUIC.MeterTalent(name) then
		return " |cffd0d0d0("..SUIC.T("talent")..")|r"
	end
	return " |cffd0d0d0("..SUIC.T("proc")..")|r"
end

local function Fill(line, entry, index, top, mode)
	line.entry = entry
	local color
	if entry.folded then
		color = { 0.5, 0.5, 0.5 }
		line.icon:SetTexture(IconOf(entry.folded[1].name))
		line.icon:Show()
	elseif mode.party then
		color = ClassColor(entry.class)
		line.icon:Hide()
	else
		color = ColorOf(entry.name or "?")
		-- The game's own icon of the source where the search finds none.
		local icon = IconOf(entry.name)
		if entry.icon and (not icon or icon == QUESTION) then
			icon = entry.icon
		end
		line.icon:SetTexture(icon)
		line.icon:Show()
	end
	line:SetStatusBarColor(color[1], color[2], color[3], 0.85)
	line:SetValue(top > 0 and (tonumber(entry.dmg) or 0) / top or 0)
	line.amount:SetText(SUIC.Short(entry.dmg))
	line.rate:SetText(SUIC.Short(entry.dps))
	line.share:SetText(math.floor((tonumber(entry.share) or 0) * 100 + 0.5).."%")
	if entry.folded then
		SayName(line, entry.name, "")
	else
		SayName(line, index..". "..SUIC.Native(entry.name or "?"), Tag(entry))
	end
	line:Show()
end

-- The pieces at the screen's bottom the column stays over: on a narrow screen
-- (4:3, 5:4) the action bar's right end, and the summons over it, reach under
-- the column.
local UNDER = { "MainMenuBar", "SUICSummons", "SUICTalentTimers", "SUICLevelUp" }

local function Floor()
	local floor = 8
	local left, right = panel:GetLeft(), panel:GetRight()
	local own = panel:GetEffectiveScale()
	for index = 1, table.getn(UNDER) do
		local frame = getglobal(UNDER[index])
		if left and frame and frame:IsVisible() and frame:GetLeft() then
			local ratio = frame:GetEffectiveScale() / own
			if frame:GetRight() * ratio > left and frame:GetLeft() * ratio < right then
				floor = math.max(floor, frame:GetTop() * ratio + 6)
			end
		end
	end
	return floor
end

-- In the column, the lines that fit above the screen's bottom edge (or above
-- the action bar, when it reaches under the column); moved, all it is set to.
-- The second window stands where it is put: all it is set to.
local function Room()
	local top = panel:GetTop()
	if not win.main or SUIC.DB().pos.meter or not top then
		return MOST
	end
	return math.max(1, math.floor((top - Floor() - panel.head - panel.foot - 4) / STEP))
end

-- With the fold on, the lines under the share folded into one, Others, at
-- the bottom (the party's heroes stay each on their own).
local function Folded(data, mode)
	if not SUIC.DB().meterFold or mode.party then
		return data
	end
	local under = (tonumber(SUIC.DB().meterFoldShare) or 10) / 100
	local kept, others = {}, {}
	for index = 1, table.getn(data) do
		local entry = data[index]
		if (tonumber(entry.share) or 0) < under then
			table.insert(others, entry)
		else
			table.insert(kept, entry)
		end
	end
	if table.getn(others) < 2 then
		return data
	end
	local sum = { name = SUIC.TF("Others ({1})", table.getn(others)), dmg = 0, dps = 0, share = 0, folded = others,
		perSecond = others[1].perSecond }
	for index = 1, table.getn(others) do
		sum.dmg = sum.dmg + (tonumber(others[index].dmg) or 0)
		sum.dps = sum.dps + (tonumber(others[index].dps) or 0)
		sum.share = sum.share + (tonumber(others[index].share) or 0)
	end
	table.insert(kept, sum)
	return kept
end

-- The scroll bar: there while the lines do not all fit, the thumb as long as
-- the share of them that shows.
local function ShowRoll(skip, most, shown)
	local roll = win.roll
	if most == 0 then
		roll:Hide()
		return
	end
	roll.quiet = true
	roll:SetMinMaxValues(0, most)
	roll:SetValue(skip)
	roll.quiet = nil
	roll.thumb:SetHeight(math.max(14, math.floor(shown * STEP * shown / (shown + most))))
	roll:Show()
end

------------------------------------------------------------------------------
-- The header, with the feed. The title is the way down to the level shown:
-- "Party > a hero > a source" (alone, "Damage > a source"), each step before
-- the last a click back to it; at its right, the fold button, Reset and +
-- (the second window: its -). Under the title's rule, at the left, two
-- selectors, each a small list: what is counted (Damage, Healing) and over what
-- (Run, Boss, Now); in the same row, at the right, the three columns' names
-- (Total, DPS, %), a faint line at each column's left. At the foot, the
-- numbers, each named.

local function PaintCrumb(crumb, over)
	if crumb.last then
		crumb.text:SetTextColor(1, 0.82, 0)
	elseif over then
		crumb.text:SetTextColor(1, 1, 1)
	else
		crumb.text:SetTextColor(0.72, 0.66, 0.5)
	end
end

-- The way written in the room the title has: the steps before the last cut
-- by a letter, the longest first, down to four each; then the last one.
local function SayWay(room)
	local crumbs = win.crumbs
	local key = room.."|"
	for index = 1, trail.n do
		key = key..trail[index].name.."|"..trail[index].level.."|"
	end
	if key == panel.wayKey then
		return
	end
	panel.wayKey = key
	local kept = {}
	for index = 1, 3 do
		local crumb = crumbs[index]
		if index <= trail.n then
			crumb.level, crumb.name, crumb.last = trail[index].level, trail[index].name, index == trail.n
			kept[index] = SUIC.Length(crumb.name)
			crumb:Show()
		else
			crumb:Hide()
		end
	end
	for try = 1, 80 do
		local width, longest = 0, nil
		for index = 1, trail.n do
			local crumb = crumbs[index]
			local name = crumb.name
			if kept[index] < SUIC.Length(name) then
				name = SUIC.Cut(name, kept[index]).."..."
			end
			crumb.text:SetText((index > 1 and "|cff808080 > |r" or "")..name)
			PaintCrumb(crumb)
			crumb:SetWidth(crumb.text:GetStringWidth() + 1)
			width = width + crumb:GetWidth()
			if index < trail.n and kept[index] > 4 and (not longest or kept[index] > kept[longest]) then
				longest = index
			end
		end
		longest = longest or trail.n
		if width <= room or kept[longest] <= 3 then
			return
		end
		kept[longest] = kept[longest] - 1
	end
end

-- The two selectors of the row: a small framed box each, with the word set
-- and a small arrow; a click opens a menu of its choices. Its frame brighter
-- under the mouse.
local BOX = {
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 8, edgeSize = 8,
	insets = { left = 2, right = 2, top = 2, bottom = 2 },
}
local TAB_HEIGHT = 17
-- What each choice says under the mouse; {1}, the seconds of "now".
local TAB_TIPS = {
	damage = "The damage dealt, by source.",
	healing = "The healing received, by source.",
	run = "The whole run. Your own damage counts from Reset, once pressed.",
	boss = "The last boss fight only.",
	now = "The last {1} seconds only.",
}
local TAB_NAMES = { damage = "Damage", healing = "Healing", run = "Run", boss = "Boss", now = "Now" }
local KINDS = { metric = { "damage", "healing" }, period = { "run", "boss", "now" } }

local function PaintPick(pick)
	if pick.over then
		pick:SetBackdropColor(0.2, 0.17, 0.08, 0.95)
		pick:SetBackdropBorderColor(1, 1, 1, 1)
		pick.text:SetTextColor(1, 1, 1)
	else
		pick:SetBackdropColor(0.12, 0.1, 0.04, 0.9)
		pick:SetBackdropBorderColor(0.85, 0.7, 0.25, 1)
		pick.text:SetTextColor(1, 0.88, 0.45)
	end
end

-- Each selector with the word set, as wide as it.
local function PaintPicks()
	local metric, period = View()
	for index = 1, 2 do
		local pick = win.picks[index]
		pick.value = index == 1 and metric or period
		pick.text:SetText(SUIC.T(TAB_NAMES[pick.value]))
		pick:SetWidth(pick.text:GetStringWidth() + 23)
		PaintPick(pick)
	end
	-- The first column's name gives way to selectors that reach under it (a
	-- language of long words).
	local reach = win.picks[1]:GetWidth() + 3 + win.picks[2]:GetWidth()
	local name = W - 2 * PAD + 4 - SHARE_COLUMN - RATE_COLUMN - AMOUNT_COLUMN / 2 - win.heads[1]:GetStringWidth() / 2
	if reach > name - 3 then
		win.heads[1]:Hide()
	else
		win.heads[1]:Show()
	end
end

-- Under the mouse: every choice and what it shows, the one set in gold.
local function PickEnter()
	this.over = true
	PaintPick(this)
	GameTooltip:SetOwner(this, "ANCHOR_TOP")
	GameTooltip:SetText(SUIC.T(this.kind == "metric" and "What is counted" or "Over what"))
	local choices = KINDS[this.kind]
	for index = 1, table.getn(choices) do
		local key = choices[index]
		if key == this.value then
			GameTooltip:AddLine(SUIC.T(TAB_NAMES[key]), 1, 0.82, 0)
		else
			GameTooltip:AddLine(SUIC.T(TAB_NAMES[key]), 1, 1, 1)
		end
		GameTooltip:AddLine(SUIC.TF(TAB_TIPS[key], NOW_SECONDS), 0.72, 0.72, 0.72, 1)
	end
	GameTooltip:AddLine(SUIC.T("Click to choose."), 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

local function PickLeave()
	this.over = nil
	PaintPick(this)
	GameTooltip:Hide()
end

-- The fold button: a small glyph of two bars over three dots (Survivor UI's),
-- gold while the small lines fold into one, Others.
local function PaintFold()
	local fold = win.fold
	local on = SUIC.DB().meterFold
	local r, g, b = 0.6, 0.6, 0.6
	if fold.over then
		r, g, b = 1, 1, on and 0.6 or 1
	elseif on then
		r, g, b = 1, 0.82, 0
	end
	for index = 1, table.getn(fold.parts) do
		fold.parts[index]:SetVertexColor(r, g, b, 1)
	end
end

local function FoldTip()
	GameTooltip:SetOwner(this, "ANCHOR_TOP")
	GameTooltip:SetText(SUIC.T("Others"))
	GameTooltip:AddLine(SUIC.TF("The lines under {1}% of the total, folded into one.", tonumber(SUIC.DB().meterFoldShare) or 10), 1, 1, 1, 1)
	GameTooltip:AddLine(SUIC.T(SUIC.DB().meterFold and "On: click to show them all." or "Off: click to fold them."), 0.7, 0.7, 0.7)
	GameTooltip:Show()
end

-- The numbers at the foot: the amount a second and the total of what the
-- lines show, each under its name.
local function SayFoot(mode, sum, perSecond)
	local foot = win.foot
	local metric = View()
	win.heads[1]:SetText(SUIC.T("Total"))
	win.heads[2]:SetText(mode.rate)
	win.heads[3]:SetText("%")
	foot.rateName:SetText(mode.rate)
	foot.rate:SetText(SUIC.Short(perSecond or 0))
	foot.totalName:SetText(SUIC.T(metric == "healing" and "Total healing" or "Total damage"))
	foot.total:SetText(SUIC.Short(sum or 0))
end

-- Over what the foot's numbers are, as the period and Reset have it.
local SPAN = { boss = "in the last boss fight", now = "in the last {1} seconds" }
local function FootEnter()
	Use(this.window)
	local metric, period = View()
	local healing = metric == "healing"
	local span = SPAN[period]
	if not span then
		span = (not healing and not nav.owner and nav.level ~= "party" and feed.checkpoint) and "since Reset" or "over the whole run"
	end
	GameTooltip:SetOwner(this, "ANCHOR_TOP")
	GameTooltip:SetText(SUIC.T(METRICS[metric]))
	GameTooltip:AddDoubleLine(healing and "HPS" or "DPS", SUIC.T(period == "now" and "a second, right now" or "a second on average"), 1, 0.82, 0, 1, 1, 1)
	GameTooltip:AddDoubleLine(SUIC.T(healing and "Total healing" or "Total damage"), SUIC.TF(span, NOW_SECONDS), 1, 0.82, 0, 1, 1, 1)
	GameTooltip:AddLine(SUIC.T("Both are of the lines shown above."), 0.7, 0.7, 0.7, 1)
	GameTooltip:Show()
end

-- The hits, over the foot, in the detail of a source of one's own damage:
-- how many, how many of them crits, the average one and the biggest, over what
-- the selector says. From Crits.lua's count of the game's feed of hits by the
-- meter's line, which is all that says them: the meter API gives amounts, no
-- counts. So only one's own, and not where the count cannot tell the line: a
-- pet's (the feed has all the pets as one, "Pets": a note says so) or a name
-- on two lines. Gives the lines' rows it stands on: it takes the last two, so
-- the window stays as tall.
local BLOW_ROWS = 2
local function SayBlows(data, resets)
	local blows = win.blows
	local metric, period = View()
	local tally, note
	if nav.level == "detail" and not nav.owner and metric == "damage" and SUIC.Blows then
		local span = period
		if period == "run" then
			span = (resets and (feed.checkpoint or (base and base.run == AZS_ZONE_UPDATED))) and "since" or "run"
		end
		SUIC.ReadHits()
		-- The feed has a Hunter's beasts as one, "Pets": the two in the look of a
		-- White Devilsaur, one line here, are just that.
		local name = nav.name
		if SUIC.PetLook and name == SUIC.PetLook() then
			name = "Pets"
		end
		tally = not data.twin and SUIC.Blows.Of(name, span, NOW_SECONDS) or nil
		note = not tally and not data.twin and data[1] ~= nil and data[1].actor ~= nil
		blows.span = span
	end
	local rows = (tally or note) and BLOW_ROWS or 0
	if panel.blowRows ~= rows then
		panel.blowRows = rows
		win.roll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 6 + panel.foot + rows * STEP)
	end
	blows.tally = tally and true or false
	if rows == 0 then
		blows:Hide()
		return 0
	end
	local cells = blows.cells
	for index = 1, 4 do
		if tally then
			cells[index].name:Show()
			cells[index].value:Show()
		else
			cells[index].name:Hide()
			cells[index].value:Hide()
		end
	end
	if tally then
		blows.words:Hide()
		blows.n, blows.crits, blows.sum, blows.best = tally.n, tally.crits, tally.sum, tally.best
		cells[1].value:SetText(tally.n)
		if tally.n > 0 then
			cells[2].value:SetText(tally.crits.." ("..math.floor(tally.crits / tally.n * 100 + 0.5).."%)")
			cells[3].value:SetText(SUIC.Short(tally.sum / tally.n))
			cells[4].value:SetText(SUIC.Short(tally.best))
		else
			cells[2].value:SetText("0")
			cells[3].value:SetText("-")
			cells[4].value:SetText("-")
		end
	else
		blows.words:SetText(SUIC.T("No hit counts here: the game does not say which pet a hit is from."))
		blows.words:Show()
	end
	blows:Show()
	return rows
end

local BLOW_NAMES = { "Hits", "Crits", "Average hit", "Biggest hit" }
local BLOW_TIPS = {
	"every hit of yours on this line",
	"the critical ones, and their share",
	"a hit's damage on average",
	"the hardest single hit",
}
local BLOW_SPANS = { run = "over the whole run", since = "since Reset", boss = "in the last boss fight", now = "in the last {1} seconds" }

local function BlowsEnter()
	Use(this.window)
	if not this.tally then
		return
	end
	GameTooltip:SetOwner(this, "ANCHOR_TOP")
	GameTooltip:SetText(SUIC.Native(nav.name or "?"))
	GameTooltip:AddLine(SUIC.TF("Your hits, {1}.", SUIC.TF(BLOW_SPANS[this.span] or BLOW_SPANS.run, NOW_SECONDS)), 1, 1, 1, 1)
	for index = 1, 4 do
		GameTooltip:AddDoubleLine(SUIC.T(BLOW_NAMES[index]), SUIC.T(BLOW_TIPS[index]), 1, 0.82, 0, 1, 1, 1)
	end
	GameTooltip:AddLine(SUIC.T("A hit counts whole, even past an enemy's last health: hits times average can be more than the total."), 0.7, 0.7, 0.7, 1)
	if SUIC.Blows and SUIC.Blows.lost then
		GameTooltip:AddLine(SUIC.T("Some hits came too fast to count: the real numbers are higher."), 1, 0.6, 0.3, 1)
	end
	GameTooltip:Show()
end

-- The header and the lines seated for a game with the feed (the way, the
-- buttons, the foot) or without it (the title and its menu, the note).
local function Seat(leveled)
	if panel.seated == leveled then
		return
	end
	panel.seated = leveled
	panel.head = TOP + (leveled and STRIP or 0)
	panel.foot = leveled and FOOT or 0
	for index = 1, MOST do
		lines[index]:ClearAllPoints()
		lines[index]:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + LINE + 3, -panel.head - 1 - (index - 1) * STEP)
	end
	win.roll:ClearAllPoints()
	win.roll:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -panel.head - 1)
	win.roll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 6 + panel.foot)
	panel.blowRows = 0
	win.fold:ClearAllPoints()
	if win.reset then
		win.reset:ClearAllPoints()
	end
	if leveled then
		if win.pick then
			win.pick:Hide()
		end
		panel.title:SetText("")
		panel.note:SetText("")
		win.strip:Show()
		win.foot:Show()
		win.corner:Show()
		-- From the right: + (or -), Reset, the fold.
		if win.reset then
			win.reset:SetPoint("RIGHT", win.corner, "LEFT", -2, 0)
			win.fold:SetPoint("RIGHT", win.reset, "LEFT", -3, 0)
		else
			win.fold:SetPoint("RIGHT", win.corner, "LEFT", -3, 0)
		end
	else
		win.pick:Show()
		win.strip:Hide()
		win.foot:Hide()
		win.blows:Hide()
		win.corner:Hide()
		for index = 1, 3 do
			win.crumbs[index]:Hide()
		end
		win.fold:SetPoint("LEFT", win.arrow, "RIGHT", 3, 0)
		win.reset:SetPoint("LEFT", win.fold, "RIGHT", 3, 0)
		win.fold:Show()
	end
end

local function Draw()
	-- mode: a level's view with the feed, a page without it.
	local leveled = Feed.Has()
	local mode, data, sum, perSecond, name, resets
	Seat(leveled)
	PaintFold()
	if leveled then
		mode, data, sum, perSecond, resets = Levels()
	else
		mode = Mode()
		data, sum, perSecond = Data(mode)
		data = data or {}
		name, resets = SUIC.T(mode.name), mode.key == "damage" or mode.key == "dps"
	end
	if win.reset then
		if resets then
			win.reset:Show()
		else
			win.reset:Hide()
		end
	end
	-- Under the top level a right click on the panel goes up one too; at the
	-- top the panel lets the mouse through, as before.
	local deep = (leveled and nav.level and nav.level ~= nav.top) or false
	if panel.deep ~= deep then
		panel.deep = deep
		panel:EnableMouse(deep)
	end
	if leveled then
		-- The fold has nothing to fold among the party's heroes.
		if mode.party then
			win.fold:Hide()
		else
			win.fold:Show()
		end
		SayWay(W - 2 * PAD - 56)
		PaintPicks()
		SayFoot(mode, sum, perSecond)
	else
		panel.title:SetText(name)
		win.pick:SetWidth(panel.title:GetStringWidth() + 20)
		if mode.key == "dps" then
			-- Now (green above the average, orange under) and on average.
			local now = NowRate(sum or 0)
			local color = "ffffff"
			if now then
				color = now >= (perSecond or 0) and "73f280" or "ff9a4d"
			end
			panel.note:SetText("|cffffd100"..SUIC.T("NOW").."|r |cff"..color..(now and SUIC.Short(now) or "...").."|r   |cffffd100"
				..SUIC.T("AVG").."|r "..SUIC.Short(perSecond or 0))
		elseif mode.key == "damage" then
			-- The total alone: what the lines under it add up to.
			panel.note:SetText(SUIC.Short(sum or 0))
		else
			panel.note:SetText(SUIC.Short(perSecond or 0).." "..mode.rate.."  |cffaaaaaa"..SUIC.Short(sum or 0).."|r")
		end
	end
	local most = math.min(MOST, tonumber(SUIC.DB().meterLines) or SUIC.Default("meterLines"), Room())
	-- The hits' block stands on the last lines' rows.
	local taken = leveled and SayBlows(data, resets) or 0
	most = math.max(1, most - taken)
	local top = data[1] and (tonumber(data[1].dmg) or 0) or 0
	data = Folded(data, mode)
	-- Rolled down, the first lines out of sight and as many more in at the
	-- bottom, never past the last; the bars keep the top line's measure.
	panel.most = math.max(0, table.getn(data) - most)
	local skip = math.min(panel.scrolled or 0, panel.most)
	Arrange(mode, panel.most > 0)
	ShowRoll(skip, panel.most, most)
	for index = 1, MOST do
		local entry = data[index + skip]
		if entry and index <= most then
			Fill(lines[index], entry, index + skip, top, mode)
		else
			lines[index].entry = nil
			lines[index]:Hide()
		end
	end
	if leveled then
		for index = 1, 3 do
			win.dividers[index]:SetHeight(most * STEP)
		end
	end
	-- As tall as its lines, filled or not.
	panel:SetHeight(panel.head + (most + taken) * STEP + 4 + panel.foot)
end

-- Every window that shows, drawn; the window in hand stays the same.
local function DrawAll()
	local was = win
	for index = 1, table.getn(windows) do
		if windows[index].panel:IsShown() then
			Use(windows[index])
			Draw()
		end
	end
	if was then
		Use(was)
	end
end

-- The lines set (the options' Damage meter tab): moved, its title stays where
-- it is and the bottom edge goes.
function SUIC.SetMeterLines(value)
	local db = SUIC.DB()
	local old = tonumber(db.meterLines) or SUIC.Default("meterLines")
	db.meterLines = value
	SUIC.KeepTop("meter", (value - old) * STEP)
	SUIC.KeepTop("meter2", (value - old) * STEP)
	DrawAll()
end

-- The line under the mouse now holds another source: its numbers closed, open
-- again on the next line the mouse goes to.
local function Roll(to)
	panel.scrolled = math.max(0, math.min(panel.most or 0, to))
	Draw()
	GameTooltip:Hide()
end

local function Wheel()
	Use(this.window)
	Roll(math.min(panel.scrolled or 0, panel.most or 0) - (arg1 or 0))
end

local function RollMoved()
	if not this.quiet then
		Use(this.window)
		Roll(math.floor(this:GetValue() + 0.5))
	end
end

------------------------------------------------------------------------------
-- From a level to another: a click on a line goes down one (a hero's sources,
-- a source's detail), a right click on a line or on the panel goes up one, a
-- click on a step of the way goes back to it. The lines start at the top
-- again.

local function GoTo(level)
	nav.level = level
	panel.scrolled = 0
	Draw()
	GameTooltip:Hide()
end

local function Down(entry)
	if not (entry and Feed.Has() and Where()) or entry.folded then
		return
	end
	if nav.level == "party" and entry.owner then
		local context = Feed.Context()
		nav.owner = entry.owner ~= context.localOwnerId and entry.owner or nil
		nav.ownerName = entry.name
		GoTo("sources")
	elseif nav.level == "sources" and entry.key then
		nav.key, nav.name = entry.key, entry.name
		GoTo("detail")
	end
end

local function Up()
	if not (Feed.Has() and Where()) then
		return
	end
	if nav.level == "detail" then
		nav.key, nav.name = nil, nil
		GoTo("sources")
	elseif nav.level == "sources" and nav.top == "party" then
		nav.owner, nav.ownerName = nil, nil
		GoTo("party")
	end
end

local function CrumbClick()
	Use(this.window)
	if this.last or not (Feed.Has() and Where()) then
		return
	end
	if this.level == "party" and nav.top == "party" then
		nav.owner, nav.ownerName, nav.key, nav.name = nil, nil, nil, nil
		GoTo("party")
	elseif this.level == "sources" and nav.level == "detail" then
		nav.key, nav.name = nil, nil
		GoTo("sources")
	end
end

local function LineClick()
	Use(this.window)
	if arg1 == "RightButton" then
		Up()
	elseif arg1 == "LeftButton" then
		Down(this.entry)
	end
end

local function PanelClick()
	if arg1 == "RightButton" then
		Use(this.window)
		Up()
	end
end

-- The metric ("damage", "healing") and the period ("run", "boss", "now") of
-- the window in hand set, either or both. Another metric closes a source's
-- detail: the source is the old metric's.
local function SetView(metric, period)
	local at, metricKey, periodKey = Kept()
	if METRICS[metric] and metric ~= at[metricKey] then
		at[metricKey] = metric
		if nav.level == "detail" then
			nav.level, nav.key, nav.name = "sources", nil, nil
		end
	end
	if PERIODS[period] then
		at[periodKey] = period
	end
	panel.scrolled = 0
	Draw()
end

-- A selector's choices: a small framed list of its own under it (the game's
-- menu is far too big here), the one set in gold. A click chooses and closes
-- it; so does a click on the selector again, or the mouse away for a moment.
local ROW_HEIGHT = 15
local choices = CreateFrame("Frame", "SUICMeterChoices", UIParent)
choices:SetFrameStrata("DIALOG")
choices:SetBackdrop(BOX)
choices:SetBackdropColor(0.06, 0.05, 0.03, 0.96)
choices:SetBackdropBorderColor(0.85, 0.7, 0.25, 1)
choices:Hide()
choices.rows = {}

local function PaintChoice(row, over)
	if row.key == choices.owner.value then
		row.text:SetTextColor(1, 0.82, 0)
	elseif over then
		row.text:SetTextColor(1, 1, 1)
	else
		row.text:SetTextColor(0.75, 0.75, 0.75)
	end
	if over then
		row.wash:Show()
	else
		row.wash:Hide()
	end
end

local function ChoiceClick()
	local key = this.key
	Use(choices.owner.window)
	choices:Hide()
	SetView(METRICS[key] and key or nil, PERIODS[key] and key or nil)
end

for index = 1, 3 do
	local row = CreateFrame("Button", "SUICMeterChoice"..index, choices)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint("TOPLEFT", choices, "TOPLEFT", 3, -3 - (index - 1) * ROW_HEIGHT)
	row:SetPoint("TOPRIGHT", choices, "TOPRIGHT", -3, -3 - (index - 1) * ROW_HEIGHT)
	row.wash = row:CreateTexture(nil, "BACKGROUND")
	row.wash:SetTexture(SUIC.FLAT)
	row.wash:SetVertexColor(1, 1, 1, 0.1)
	row.wash:SetAllPoints(row)
	row.wash:Hide()
	row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.text:SetPoint("LEFT", row, "LEFT", 5, 0)
	row:RegisterForClicks("LeftButtonUp")
	row:SetScript("OnClick", ChoiceClick)
	row:SetScript("OnEnter", function() PaintChoice(this, true) end)
	row:SetScript("OnLeave", function() PaintChoice(this) end)
	choices.rows[index] = row
end

-- Whether the mouse is over a frame, by the screen's own measure.
local function Over(frame)
	local x, y = GetCursorPosition()
	local scale = frame:GetEffectiveScale()
	local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
	if not (left and scale and x) then
		return false
	end
	return x >= left * scale and x <= right * scale and y >= bottom * scale and y <= top * scale
end

choices:SetScript("OnUpdate", function()
	if Over(this) or Over(this.owner) or not this.owner:IsVisible() then
		this.away = this.owner:IsVisible() and 0 or 1
	else
		this.away = (this.away or 0) + arg1
	end
	if this.away >= 0.6 then
		this:Hide()
	end
end)

local function PickClick()
	GameTooltip:Hide()
	if choices:IsShown() and choices.owner == this then
		choices:Hide()
		return
	end
	choices.owner, choices.away = this, 0
	local list = KINDS[this.kind]
	local width = this:GetWidth()
	for index = 1, 3 do
		local row = choices.rows[index]
		if list[index] then
			row.key = list[index]
			row.text:SetText(SUIC.T(TAB_NAMES[row.key]))
			width = math.max(width, row.text:GetStringWidth() + 18)
			PaintChoice(row)
			row:Show()
		else
			row:Hide()
		end
	end
	-- In the window's own size (a piece can be made bigger or smaller), by its
	-- scale: it stays the screen's own child, over everything, and its rows
	-- over it, so the clicks reach them and not the lines underneath.
	choices:SetScale(this:GetEffectiveScale() / UIParent:GetEffectiveScale())
	choices:SetFrameStrata("DIALOG")
	choices:SetFrameLevel(20)
	for index = 1, 3 do
		choices.rows[index]:SetFrameStrata("DIALOG")
		choices.rows[index]:SetFrameLevel(22)
	end
	choices:ClearAllPoints()
	choices:SetPoint("TOPLEFT", this, "BOTTOMLEFT", 0, 1)
	choices:SetWidth(width)
	choices:SetHeight(table.getn(list) * ROW_HEIGHT + 6)
	choices:Show()
end

-- The main window's, for the options and the like; other, the second
-- window's, where it is open.
function SUIC.SetMeterView(metric, period, other)
	local window = windows[other and 2 or 1]
	if window then
		Use(window)
		SetView(metric, period)
	end
end

local function FoldClick()
	SUIC.DB().meterFold = not SUIC.DB().meterFold
	DrawAll()
	FoldTip()
end

local function ResetClick()
	if Feed.Reset() then
		base = nil
	else
		TakeBase()
	end
	if SUIC.Blows then
		SUIC.Blows.Mark()
	end
	DrawAll()
end

------------------------------------------------------------------------------
-- A window built: its panel, lines, scroll bar, header and foot.

local function BuildLines(window)
	local frame = window.panel
	for index = 1, MOST do
		local line = SUIC.RowBar(frame, W - 2 * PAD - LINE - 3, LINE)
		line.window = window
		line:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + LINE + 3, -TOP - 1 - (index - 1) * STEP)
		line:EnableMouse(true)
		line:EnableMouseWheel(true)
		line:SetScript("OnEnter", LineEnter)
		line:SetScript("OnLeave", HideTip)
		line:SetScript("OnMouseWheel", Wheel)
		line:SetScript("OnMouseUp", LineClick)
		line.icon = line:CreateTexture(nil, "ARTWORK")
		line.icon:SetWidth(LINE + 1)
		line.icon:SetHeight(LINE + 1)
		line.icon:SetPoint("RIGHT", line, "LEFT", -2, 0)
		line.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		line.right:Hide()
		line.gameFont = line.left:GetFont()
		line.amount = line.over:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		line.rate = line.over:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		line.rate:SetPoint("CENTER", line, "RIGHT", -SHARE_COLUMN - RATE_COLUMN / 2, 0)
		line.share = line.over:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		line.share:SetPoint("CENTER", line, "RIGHT", -SHARE_COLUMN / 2, 0)
		line.share:SetTextColor(1, 0.9, 0.3)
		line.texts = { line.left, line.amount, line.rate, line.share }
		line:Hide()
		window.lines[index] = line
	end
end

local function BuildRoll(window)
	local frame = window.panel
	local roll = CreateFrame("Slider", nil, frame)
	roll.window = window
	roll:SetOrientation("VERTICAL")
	roll:SetWidth(ROLL_WIDTH)
	roll:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -TOP - 1)
	roll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
	roll:SetFrameLevel(frame:GetFrameLevel() + 8)
	roll:SetMinMaxValues(0, 1)
	roll:SetValueStep(1)
	roll:EnableMouse(true)
	roll:EnableMouseWheel(true)
	local track = roll:CreateTexture(nil, "BACKGROUND")
	track:SetTexture(SUIC.FLAT)
	track:SetVertexColor(0, 0, 0, 0.5)
	track:SetAllPoints(roll)
	roll.thumb = roll:CreateTexture(nil, "OVERLAY")
	roll.thumb:SetTexture(SUIC.FLAT)
	roll.thumb:SetVertexColor(0.55, 0.55, 0.55, 1)
	roll.thumb:SetWidth(ROLL_WIDTH - 2)
	roll.thumb:SetHeight(16)
	roll:SetThumbTexture(roll.thumb)
	roll:SetScript("OnEnter", function() this.thumb:SetVertexColor(0.9, 0.82, 0.5, 1) end)
	roll:SetScript("OnLeave", function() this.thumb:SetVertexColor(0.55, 0.55, 0.55, 1) end)
	roll:SetScript("OnValueChanged", RollMoved)
	roll:SetScript("OnMouseWheel", Wheel)
	roll:Hide()
	window.roll = roll
end

-- The way's steps and the row of buttons; name, the frames' names' start.
local function BuildHead(window, name)
	local frame = window.panel
	window.crumbs = {}
	for index = 1, 3 do
		local crumb = CreateFrame("Button", name.."Crumb"..index, frame)
		crumb.window = window
		crumb:SetHeight(16)
		crumb:SetWidth(10)
		if index == 1 then
			crumb:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -4)
		else
			crumb:SetPoint("LEFT", window.crumbs[index - 1], "RIGHT", 0, 0)
		end
		crumb.text = crumb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		crumb.text:SetPoint("LEFT", crumb, "LEFT", 0, 0)
		crumb:SetScript("OnClick", CrumbClick)
		crumb:SetScript("OnEnter", function() PaintCrumb(this, true) end)
		crumb:SetScript("OnLeave", function() PaintCrumb(this) end)
		crumb:Hide()
		window.crumbs[index] = crumb
	end
	local strip = CreateFrame("Frame", nil, frame)
	strip:SetHeight(TAB_HEIGHT)
	strip:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD - 2, -SUIC.TITLE - 3)
	strip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD + 2, -SUIC.TITLE - 3)
	strip:Hide()
	window.strip = strip
	window.picks = {}
	for index = 1, 2 do
		local kind = index == 1 and "metric" or "period"
		local pick = CreateFrame("Button", name.."Pick_"..kind, strip)
		pick.window, pick.kind = window, kind
		pick:SetHeight(TAB_HEIGHT)
		pick:SetWidth(50)
		pick:SetBackdrop(BOX)
		if index == 1 then
			pick:SetPoint("LEFT", strip, "LEFT", 0, 0)
		else
			pick:SetPoint("LEFT", window.picks[1], "RIGHT", 3, 0)
		end
		pick.text = pick:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		pick.text:SetPoint("LEFT", pick, "LEFT", 6, 0)
		local arrow = pick:CreateTexture(nil, "OVERLAY")
		arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
		arrow:SetWidth(12)
		arrow:SetHeight(12)
		arrow:SetPoint("RIGHT", pick, "RIGHT", -3, 0)
		pick:SetScript("OnClick", PickClick)
		pick:SetScript("OnEnter", PickEnter)
		pick:SetScript("OnLeave", PickLeave)
		window.picks[index] = pick
	end
	-- The three columns' own names over them, and a faint line at each
	-- column's left, down the lines (the build list's).
	window.heads = {}
	local at = { AMOUNT_COLUMN / 2 - SHARE_COLUMN - AMOUNT_COLUMN - RATE_COLUMN, -SHARE_COLUMN - RATE_COLUMN / 2, -SHARE_COLUMN / 2 }
	for index = 1, 3 do
		local head = SUIC.Text(strip, "GameFontNormalSmall", 9)
		head:SetPoint("BOTTOM", window.lines[1], "TOPRIGHT", at[index], 2)
		head:SetTextColor(0.62, 0.62, 0.62)
		window.heads[index] = head
	end
	local rules = CreateFrame("Frame", nil, strip)
	rules:SetAllPoints(frame)
	rules:SetFrameLevel(frame:GetFrameLevel() + 6)
	window.dividers = {}
	local left = { -SHARE_COLUMN - RATE_COLUMN - AMOUNT_COLUMN, -SHARE_COLUMN - RATE_COLUMN, -SHARE_COLUMN }
	for index = 1, 3 do
		local divider = rules:CreateTexture(nil, "OVERLAY")
		divider:SetTexture(SUIC.FLAT)
		divider:SetVertexColor(1, 1, 1, 0.08)
		divider:SetWidth(1)
		divider:SetHeight(STEP)
		divider:SetPoint("TOP", window.lines[1], "TOPRIGHT", left[index], 2)
		window.dividers[index] = divider
	end
end

-- The fold's glyph, 11 by 8: a long bar, a shorter one, three dots under.
local GLYPH = { { 2, -3, 11, 2 }, { 2, -6, 7, 2 }, { 2, -9, 2, 2 }, { 6, -9, 2, 2 }, { 10, -9, 2, 2 } }

-- The buttons at the title's right and the foot.
local function BuildEnds(window)
	local frame = window.panel
	local fold = CreateFrame("Button", nil, frame)
	fold.window = window
	fold:SetWidth(15)
	fold:SetHeight(14)
	fold.parts = {}
	for index = 1, table.getn(GLYPH) do
		local part = fold:CreateTexture(nil, "OVERLAY")
		part:SetTexture(SUIC.FLAT)
		part:SetPoint("TOPLEFT", fold, "TOPLEFT", GLYPH[index][1], GLYPH[index][2])
		part:SetWidth(GLYPH[index][3])
		part:SetHeight(GLYPH[index][4])
		fold.parts[index] = part
	end
	fold:SetScript("OnEnter", function()
		this.over = true
		Use(this.window)
		PaintFold()
		FoldTip()
	end)
	fold:SetScript("OnLeave", function()
		this.over = nil
		Use(this.window)
		PaintFold()
		GameTooltip:Hide()
	end)
	fold:SetScript("OnClick", FoldClick)
	window.fold = fold

	local foot = CreateFrame("Frame", nil, frame)
	foot.window = window
	foot:SetHeight(FOOT - 2)
	foot:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 5)
	foot:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 5)
	foot:EnableMouse(true)
	local wash = foot:CreateTexture(nil, "BACKGROUND")
	wash:SetTexture(SUIC.FLAT)
	wash:SetVertexColor(1, 1, 1, 0.06)
	wash:SetAllPoints(foot)
	foot.rateName = foot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	foot.rateName:SetPoint("LEFT", foot, "LEFT", 4, 0)
	foot.rate = foot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	foot.rate:SetPoint("LEFT", foot.rateName, "RIGHT", 4, 0)
	foot.total = foot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	foot.total:SetPoint("RIGHT", foot, "RIGHT", -4, 0)
	foot.totalName = foot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	foot.totalName:SetPoint("RIGHT", foot.total, "LEFT", -4, 0)
	foot:SetScript("OnEnter", FootEnter)
	foot:SetScript("OnLeave", HideTip)
	foot:Hide()
	window.foot = foot
	frame.foot = 0

	-- The hits' block, over the foot: two rows of two numbers, each named.
	local blows = CreateFrame("Frame", nil, frame)
	blows.window = window
	blows:SetHeight(BLOW_ROWS * STEP - 2)
	blows:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 5 + FOOT)
	blows:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 5 + FOOT)
	blows:EnableMouse(true)
	wash = blows:CreateTexture(nil, "BACKGROUND")
	wash:SetTexture(SUIC.FLAT)
	wash:SetVertexColor(1, 1, 1, 0.06)
	wash:SetAllPoints(blows)
	blows.cells = {}
	for index = 1, 4 do
		local cell = {}
		local y = index <= 2 and 8 or -8
		cell.name = blows:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		cell.value = blows:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		if math.mod(index, 2) == 1 then
			cell.name:SetPoint("LEFT", blows, "LEFT", 4, y)
			cell.value:SetPoint("LEFT", cell.name, "RIGHT", 4, 0)
		else
			cell.value:SetPoint("RIGHT", blows, "RIGHT", -4, y)
			cell.name:SetPoint("RIGHT", cell.value, "LEFT", -4, 0)
		end
		cell.name:SetText(SUIC.T(BLOW_NAMES[index]))
		blows.cells[index] = cell
	end
	blows.words = blows:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	blows.words:SetPoint("LEFT", blows, "LEFT", 4, 0)
	blows.words:SetWidth(W - 20)
	blows.words:SetJustifyH("LEFT")
	blows.words:SetTextColor(0.72, 0.72, 0.72)
	blows.words:Hide()
	blows:SetScript("OnEnter", BlowsEnter)
	blows:SetScript("OnLeave", HideTip)
	blows:SetScript("OnMouseUp", PanelClick)
	blows:Hide()
	window.blows = blows
end

-- The corner's button: the main window's +, the second's -.
local function Corner(window, sign, tip, text, click)
	local frame = window.panel
	local corner = CreateFrame("Button", frame:GetName().."Corner", frame)
	corner.window = window
	corner:SetWidth(14)
	corner:SetHeight(14)
	corner:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD + 2, -5)
	corner:SetNormalTexture("Interface\\Buttons\\UI-"..sign.."Button-Up")
	corner:SetPushedTexture("Interface\\Buttons\\UI-"..sign.."Button-Down")
	corner:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
	corner.tip, corner.words = tip, text
	corner:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		GameTooltip:SetText(SUIC.T(this.tip))
		GameTooltip:AddLine(SUIC.T(this.words), 1, 1, 1, 1)
		GameTooltip:Show()
	end)
	corner:SetScript("OnLeave", HideTip)
	corner:SetScript("OnClick", click)
	corner:Hide()
	window.corner = corner
end

local function Build(name, main)
	local window = { main = main, lines = {}, nav = {} }
	window.panel = SUIC.Window(name, main and "Damage Done" or "")
	local frame = window.panel
	frame.window = window
	-- For a test's driver: the lines and where the window stands.
	frame.nav, frame.lines = window.nav, window.lines
	frame.head = TOP
	BuildLines(window)
	BuildRoll(window)
	BuildHead(window, name)
	BuildEnds(window)
	frame.feet, frame.blows = window.foot, window.blows
	frame:EnableMouseWheel(true)
	frame:SetScript("OnMouseWheel", Wheel)
	frame:SetScript("OnMouseUp", PanelClick)
	table.insert(windows, window)
	return window
end

------------------------------------------------------------------------------
-- The main window, and what it alone has: Reset, and in a game without the
-- feed the title's menu of pages.

local main = Build("SUICMeter", true)
Use(main)

-- The title opens the pages' menu; a small arrow says so.
main.pick = CreateFrame("Button", nil, main.panel)
main.pick:SetHeight(16)
main.pick:SetWidth(130)
main.pick:SetPoint("TOPLEFT", main.panel, "TOPLEFT", SUIC.PAD - 2, -4)
main.arrow = main.pick:CreateTexture(nil, "OVERLAY")
main.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
main.arrow:SetWidth(14)
main.arrow:SetHeight(14)
main.arrow:SetPoint("LEFT", main.panel.title, "RIGHT", 1, 0)

-- Reset: the character pane's turning arrow, cut to its framed square. On
-- one's own damage of the run (without the feed, on the Damage Done and DPS
-- pages); the rest is the game's as it comes.
local reset = CreateFrame("Button", "SUICMeterReset", main.panel)
reset.window = main
reset:SetWidth(14)
reset:SetHeight(14)
reset:SetNormalTexture("Interface\\Buttons\\UI-RotationLeft-Button-Up")
reset:SetPushedTexture("Interface\\Buttons\\UI-RotationLeft-Button-Down")
reset:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
reset:GetNormalTexture():SetTexCoord(0.09375, 0.90625, 0.09375, 0.875)
reset:GetPushedTexture():SetTexCoord(0.09375, 0.90625, 0.09375, 0.875)
reset:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_TOP")
	GameTooltip:SetText(SUIC.T("Reset"))
	if Feed.Has() then
		GameTooltip:AddLine(SUIC.T("Your damage of the run counts from now on."), 1, 1, 1, 1)
	else
		GameTooltip:AddLine(SUIC.T("Damage Done and DPS count from now on."), 1, 1, 1, 1)
	end
	GameTooltip:AddLine(SUIC.T("A new run starts them over by itself."), 0.7, 0.7, 0.7, 1)
	GameTooltip:Show()
end)
reset:SetScript("OnLeave", HideTip)
reset:SetScript("OnClick", ResetClick)
main.reset = reset

local menu = CreateFrame("Frame", "SUICMeterMenu", UIParent, "UIDropDownMenuTemplate")
local function PickMode(key)
	SUIC.DB().meterMode = key
	main.panel.scrolled = 0
	DrawAll()
end
local function MenuInit()
	for index = 1, table.getn(MODES) do
		local mode = MODES[index]
		UIDropDownMenu_AddButton({ text = SUIC.T(mode.name), func = PickMode, arg1 = mode.key,
			checked = SUIC.DB().meterMode == mode.key })
	end
end
main.pick:SetScript("OnClick", function()
	UIDropDownMenu_Initialize(menu, MenuInit, "MENU")
	ToggleDropDownMenu(1, nil, menu, this, 0, 0)
end)

------------------------------------------------------------------------------
-- The second window (with the feed): opened and closed by the main one's +,
-- closed by its own -. Its metric, its period and whether it is open are kept
-- (meter2); it shows while the main one does. At first at the main one's
-- left; moved as any piece ("Damage meter 2").

local second

local function Refresh()
	local db = SUIC.DB()
	local wanted = db.meter
	SUIC.SetGameShown("meter", not wanted)
	-- The hits are counted (Crits.lua) only for a meter that shows them.
	if SUIC.Blows then
		SUIC.Blows.on = (wanted and Feed.Has()) and true or false
	end
	local shown = (wanted and SUIC.InRun()) and true or false
	local both = (shown and second ~= nil and Feed.Has() and type(db.meter2) == "table" and db.meter2.open) and true or false
	local changed = (main.panel:IsShown() and true or false) ~= shown
	if shown then
		main.panel:Show()
	else
		main.panel:Hide()
	end
	if second then
		changed = changed or (second.panel:IsShown() and true or false) ~= both
		if both then
			second.panel:Show()
		else
			second.panel:Hide()
		end
	end
	-- A window just shown is drawn at once.
	if changed and shown then
		DrawAll()
	end
end

local function OpenSecond(open)
	local db = SUIC.DB()
	if type(db.meter2) ~= "table" then
		db.meter2 = {}
	end
	db.meter2.open = open and true or false
	if open and not second then
		second = Build("SUICMeter2", false)
		Corner(second, "Minus", "Close", "Closes this window. The + of the damage meter opens it again.", function()
			OpenSecond(false)
		end)
		second.panel:SetPoint("TOPRIGHT", main.panel, "TOPLEFT", -4, 0)
		SUIC.AddPiece("meter2", "Damage meter 2", second.panel, function(frame)
			frame:SetPoint("TOPRIGHT", main.panel, "TOPLEFT", -4, 0)
		end)
		SUIC.ApplyMeterFont()
		SUIC.OverCards(second.panel, "meter")
	end
	Refresh()
end

Corner(main, "Plus", "Second window",
	"Opens another meter window, with its own Damage or Healing and its own Run, Boss or Now. Click again, or its -, to close it.",
	function()
		local kept = SUIC.DB().meter2
		OpenSecond(not (second and type(kept) == "table" and kept.open))
	end)

local elapsed = 0
main.panel:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.5 then
		return
	end
	elapsed = 0
	DrawAll()
end)

SUIC.RefreshMeter = function()
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
	if SUIC.ReadHits then
		SUIC.ReadHits()
	end
end)
watch:Hide()

SUIC.OnStart(function()
	SUIC.ColumnHome("meter")(main.panel)
	SUIC.AddPiece("meter", "Damage meter", main.panel, SUIC.ColumnHome("meter"))
	SUIC.ApplyMeterFont()
	SUIC.OverCards(main.panel, "meter")
	local kept = SUIC.DB().meter2
	if Feed.Has() and type(kept) == "table" and kept.open then
		OpenSecond(true)
	end
	watch:Show()
	Refresh()
end)
