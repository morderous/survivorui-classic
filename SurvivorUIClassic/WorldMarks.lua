-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: marks on the world itself, from the game's 0.139.2
-- world anchors (AZS_GetWorldAnchors, AZS_ProjectWorldAnchors,
-- AZS_GetDownedPartyMembers), as Survivor UI's WorldMarks.lua, each its own
-- switch (the options, World markers):
--
-- - Friends down (co-op): over each, a gold cross, their name and how far.
-- - Caches: the minimap's loot bag over each one still there, with how far;
--   with Light beams, in a column of gold light, the bag floating near its top.
-- - Lairs: the minimap's skull and the guardian's name over a lair whose
--   guardian sleeps there (grey); awake, over the guardian itself (orange),
--   following it out of the lair (left out while its nameplate shows, which
--   names it already); slain, back over the lair, greyed, with the
--   time until the lair is claimed again in red (AZS_LAIRS' left).
-- - Arrows: on a ring round the hero, wider than tall, toward the friends
--   down, the caches and the lairs out of sight, the nearest few, with how far.
-- - Explosive orbs (the Explosive affix): a pulsing mark over each.
--
-- The catalog is read four times a second; the places every frame, after the
-- camera (AZS_RegisterWorldAnchorFrameHandler), so nothing trails. Caches and
-- lairs take only "position", units "overhead" too; a place off the screen
-- comes without x and y; the answers come in the requests' order. An anchor's
-- offset may be any number of yards, so any spot of the world is one anchor
-- and an offset away: the hero's own (AZS_GetPlayerPosition), and a point six
-- yards from it toward what an arrow points at; the line between the two on
-- the screen is the arrow's way.

local ART = "Interface\\AddOns\\SurvivorUIClassic\\Art\\"
local READ_EVERY = 0.25
local CELLS = 8                  -- the arrow sheet: 8 x 8 arrows, each turned 360/64 more
-- The arrows' ring round the hero: a share of the screen's width across, of
-- its height up and down (the combat text's columns stand close by the hero).
local RING_WIDE, RING_TALL = 0.3, 0.3
local WAY = 6                    -- yards from the hero, for an arrow's way
local MOST_ARROWS = 6
local KINDS = { "guardian", "cache", "guardianLair" }
local ORB = "Explosive Orb"
local GOLD = { 1.00, 0.82, 0.00 }
local RESPAWN = { 1.00, 0.28, 0.22 }  -- an empty lair's time, as the run tracker's
local ICONS = { cache = "MinimapChest", lair = "MinimapSkull", downed = "HealCross" }
local DEFAULTS = { worldDowned = true, worldCaches = true, worldLairs = true, worldArrows = true, worldOrbs = true,
	worldBeams = true }
-- A cache's beam (Lucas, 2026-11-02, after the world markers of the game's
-- live client): a column of light BEAM_TALL yards up and BEAM_WIDE across, a
-- pool POOL_WIDE across on the ground, the bag floating near the top. Ours,
-- drawn flat over the world, so nothing hides behind it: dimmed where the
-- hero stands in front.
local BEAM_TALL, BEAM_WIDE, POOL_WIDE = 6, 2.4, 3.4
local BEAM_COLOR = { 1.00, 0.77, 0.27 }

local function On(key)
	local value = SUIC.DB()[key]
	if value == nil then
		return DEFAULTS[key]
	end
	return value
end

function SUIC.WorldOn(key)
	return On(key) and true or false
end

function SUIC.SetWorld(key, on)
	SUIC.DB()[key] = on and true or false
end

if not (AZS_GetWorldAnchors and AZS_ProjectWorldAnchors and AZS_RegisterWorldAnchorFrameHandler) then
	return
end

------------------------------------------------------------------------------
-- What there is: the catalog's anchors, the friends down.

local spots = {}                 -- this read's: { anchor, attachment, lift, look, ... }
local heroAt                     -- { x, y, z } from AZS_GetPlayerPosition, read each frame
local base                       -- an anchor that stays put, for spots by offset: { id, x, y, z }

local function Field(entry, name, index)
	if entry[name] ~= nil then
		return entry[name]
	end
	return entry[index]
end

local function Read(query, into)
	local cursor
	for page = 1, 8 do
		local ok, result = pcall(AZS_GetWorldAnchors, query, cursor, 256)
		if not ok or not result then
			return
		end
		local entries = result.entries or {}
		for index = 1, table.getn(entries) do
			table.insert(into, entries[index])
		end
		if not result.hasMore or not result.nextCursor then
			return
		end
		cursor = result.nextCursor
	end
end

-- Whether the run has the Explosive affix (AZS_ZONE.affixes, "sanguine,explosive").
local function Explosive()
	return string.find(string.lower(tostring(AZS_ZONE and AZS_ZONE.affixes or "")), "explosive", 1, true) ~= nil
end

-- When each empty lair is claimed again (AZS_LAIRS' "left", seconds from its line).
local function Refills()
	local refill = {}
	local since = AZS_LAIRS_UPDATED and (GetTime() - AZS_LAIRS_UPDATED) or 0
	for index = 1, table.getn(AZS_LAIRS or {}) do
		local lair = AZS_LAIRS[index]
		local left = tonumber(Field(lair, "left", 5))
		if left then
			refill[tonumber(Field(lair, "index", 1)) or index] = GetTime() + left - since
		end
	end
	return refill
end

-- A lair's spot: asleep over the lair, awake over its guardian, slain over the
-- lair with its time.
local function LairSpot(entry, guardians, refill)
	local guardian = entry.state == "awake" and entry.occupantUnitId and guardians[tonumber(entry.occupantUnitId)]
	if entry.state == "empty" then
		return { anchor = entry.anchorId, attachment = "position", lift = 3, look = "lair", name = entry.name,
			empty = true, refill = refill[tonumber(entry.lairIndex)] }, entry
	elseif guardian then
		return { anchor = guardian.anchorId, attachment = "overhead", lift = 0.6, look = "lair", arrow = true,
			name = entry.name, awake = true, unit = tostring(guardian.unitId) }, guardian
	elseif entry.state == "asleep" or entry.state == "awake" then
		return { anchor = entry.anchorId, attachment = "position", lift = 3, look = "lair", arrow = true,
			name = entry.name, awake = entry.state == "awake" }, entry
	end
end

local function ReadAll()
	local entries = {}
	Read({ kinds = KINDS }, entries)
	if On("worldOrbs") and Explosive() then
		Read({ kinds = { "enemy" }, states = { "alive" } }, entries)
	end
	spots = {}
	base = nil
	local guardians = {}
	for index = 1, table.getn(entries) do
		local entry = entries[index]
		if entry.kind == "guardian" and entry.state == "alive" and entry.unitId then
			guardians[tonumber(entry.unitId)] = entry
		end
	end
	local refill = Refills()
	for index = 1, table.getn(entries) do
		local entry = entries[index]
		local spot, at
		if entry.kind == "cache" then
			base = base or { id = entry.anchorId, x = entry.x, y = entry.y, z = entry.z }
			if entry.state == "present" and On("worldCaches") then
				local beam = On("worldBeams")
				spot, at = { anchor = entry.anchorId, attachment = "position", lift = beam and BEAM_TALL * 0.8 or 1.2,
					look = "cache", arrow = true, beam = beam }, entry
			end
		elseif entry.kind == "guardianLair" then
			base = base or { id = entry.anchorId, x = entry.x, y = entry.y, z = entry.z }
			if On("worldLairs") then
				spot, at = LairSpot(entry, guardians, refill)
			end
		elseif entry.kind == "enemy" and (entry.name == ORB or entry.name == SUIC.T(ORB)) then
			spot, at = { anchor = entry.anchorId, attachment = "overhead", lift = 0.6, look = "orb" }, entry
		end
		if spot then
			spot.x, spot.y, spot.z = at.x, at.y, at.z
			table.insert(spots, spot)
		end
	end
	-- The friends down, by the game's own list: the anchor when ready, else
	-- their spot by offset from another one.
	local ok, downed = pcall(AZS_GetDownedPartyMembers)
	if ok and downed and On("worldDowned") then
		for index = 1, table.getn(downed) do
			local friend = downed[index]
			if friend.positionAvailable then
				local spot = { look = "downed", arrow = true, name = friend.name, x = friend.x, y = friend.y, z = friend.z, lift = 2.5 }
				if friend.anchorStatus == "ready" and friend.anchorId then
					spot.anchor, spot.attachment = friend.anchorId, "position"
				end
				table.insert(spots, spot)
			end
		end
	end
end

------------------------------------------------------------------------------
-- What is drawn: a spot's mark and words; an arrow on the ring.

local layer = CreateFrame("Frame", "SUICWorldMarks", UIParent)
layer:SetAllPoints(UIParent)
layer:SetFrameStrata("LOW")
layer:Hide()

local marks, arrows = {}, {}

-- The beams under the nameplates' bars: a child of WorldFrame, on the world's
-- own strata as the plates are (the game draws by strata, then level), placed
-- in WorldFrame's units, as the places come.
local beams = CreateFrame("Frame", "SUICWorldBeams", WorldFrame)
beams:SetAllPoints(WorldFrame)
beams:Hide()
local lights = {}

local function Light(index)
	local light = lights[index]
	if light then
		return light
	end
	light = {}
	light.pool = beams:CreateTexture(nil, "BORDER")
	light.pool:SetTexture(ART.."CachePool")
	light.pool:SetBlendMode("ADD")
	light.beam = beams:CreateTexture(nil, "ARTWORK")
	light.beam:SetTexture(ART.."CacheBeam")
	light.beam:SetBlendMode("ADD")
	lights[index] = light
	return light
end

local function HideLights(first)
	for index = first, table.getn(lights) do
		lights[index].pool:Hide()
		lights[index].beam:Hide()
	end
end

-- A beam from its spot on the ground (low) to BEAM_TALL yards up (high), as
-- wide as the ground's yards there; the pool squashed as the camera tilts (a
-- yard up looks shorter than a yard across as the camera looks down).
local function PaintLight(light, low, high, hero, phase)
	local yard = low.uiUnitsPerYard
	local tall = high.y - low.y
	if not yard or yard <= 0 or tall <= 1 then
		light.pool:Hide()
		light.beam:Hide()
		return
	end
	local wide = BEAM_WIDE * yard
	light.beam:ClearAllPoints()
	light.beam:SetPoint("BOTTOM", beams, "BOTTOMLEFT", low.x, low.y)
	light.beam:SetWidth(wide)
	light.beam:SetHeight(tall)
	local up = math.min(1, tall / (BEAM_TALL * yard))
	local squash = math.max(0.25, math.sqrt(1 - up * up))
	local pool = POOL_WIDE * yard
	light.pool:ClearAllPoints()
	light.pool:SetPoint("CENTER", beams, "BOTTOMLEFT", low.x, low.y)
	light.pool:SetWidth(pool)
	light.pool:SetHeight(pool * squash)
	local a = 0.85 + 0.15 * math.sin(GetTime() * 2.2 + phase)
	if hero and hero.x and math.abs(hero.x - low.x) < wide * 0.7 and hero.y < high.y
			and hero.y > low.y - 3 * yard and (hero.cameraDepth or 0) < (low.cameraDepth or 0) then
		a = a * 0.35
	end
	light.beam:SetVertexColor(BEAM_COLOR[1], BEAM_COLOR[2], BEAM_COLOR[3], a)
	light.pool:SetVertexColor(BEAM_COLOR[1], BEAM_COLOR[2], BEAM_COLOR[3], a * 0.8)
	light.pool:Show()
	light.beam:Show()
end

local function Words(parent, size)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
	text:SetShadowColor(0, 0, 0, 1)
	text:SetShadowOffset(1, -1)
	return text
end

local function Mark(index)
	local mark = marks[index]
	if mark then
		return mark
	end
	mark = CreateFrame("Frame", nil, layer)
	mark:SetWidth(1)
	mark:SetHeight(1)
	mark.icon = mark:CreateTexture(nil, "ARTWORK")
	mark.name = Words(mark, 11)
	mark.yards = Words(mark, 10)
	marks[index] = mark
	return mark
end

local function Arrow(index)
	local arrow = arrows[index]
	if arrow then
		return arrow
	end
	arrow = CreateFrame("Frame", nil, layer)
	arrow:SetWidth(1)
	arrow:SetHeight(1)
	arrow.point = arrow:CreateTexture(nil, "ARTWORK")
	arrow.point:SetTexture(ART.."GuardianArrow")
	arrow.point:SetWidth(26)
	arrow.point:SetHeight(26)
	arrow.point:SetPoint("CENTER", arrow, "CENTER", 0, 0)
	arrow.icon = arrow:CreateTexture(nil, "OVERLAY")
	arrow.icon:SetWidth(18)
	arrow.icon:SetHeight(18)
	arrow.yards = Words(arrow, 10)
	arrows[index] = arrow
	return arrow
end

-- The arrow sheet's cell nearest to an angle (radians, clockwise from up).
local function Point(texture, angle)
	local cells = CELLS * CELLS
	local k = math.mod(math.floor(angle / (2 * math.pi) * cells + 0.5), cells)
	if k < 0 then
		k = k + cells
	end
	local column, line = math.mod(k, CELLS), math.floor(k / CELLS)
	texture:SetTexCoord(column / CELLS, (column + 1) / CELLS, line / CELLS, (line + 1) / CELLS)
end

local function Clock(seconds)
	seconds = math.max(0, math.floor(seconds + 0.5))
	return string.format("%d:%02d", math.floor(seconds / 60), math.mod(seconds, 60))
end

local function Yards(value)
	return SUIC.TF("{1} yd", math.floor(value + 0.5))
end

-- An icon of the minimap's or ours, at a size, in the mark's middle.
local function Icon(mark, art, size)
	mark.icon:SetTexture(ART..art)
	mark.icon:SetWidth(size)
	mark.icon:SetHeight(size)
	mark.icon:SetPoint("CENTER", mark, "CENTER", 0, 0)
	mark.icon:Show()
end

-- Each look's mark and words. A mark is placed by its middle at x, y.
local function Paint(mark, spot, x, y, yards)
	local icon, name, below = mark.icon, mark.name, mark.yards
	name:Hide()
	below:Hide()
	mark:ClearAllPoints()
	mark:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
	icon:ClearAllPoints()
	icon:SetVertexColor(1, 1, 1, 1)
	local look = spot.look
	if look == "orb" then
		Icon(mark, "AffixExplosive", 26 * (1 + 0.15 * math.sin(GetTime() * 7)))
		icon:SetVertexColor(1, 0.55, 0.2, 1)
	elseif look == "downed" then
		Icon(mark, "HealCross", 26 * (1 + 0.12 * math.sin(GetTime() * 5)))
		icon:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
	else
		Icon(mark, ICONS[look], look == "lair" and 24 or 22)
	end
	if spot.name then
		name:SetText(spot.name)
		if look == "downed" then
			name:SetTextColor(1, 0.36, 0.30)
		elseif spot.awake then
			name:SetTextColor(1, 0.62, 0.22)
		else
			name:SetTextColor(0.75, 0.75, 0.75)
		end
		name:ClearAllPoints()
		name:SetPoint("BOTTOM", icon, "TOP", 0, 1)
		name:Show()
	end
	if spot.empty then
		icon:SetVertexColor(0.6, 0.6, 0.6, 0.6)
		name:SetTextColor(0.55, 0.55, 0.55)
		local left = spot.refill and spot.refill - GetTime()
		below:SetText(left and left > 0 and Clock(left) or SUIC.T("soon"))
		below:SetTextColor(RESPAWN[1], RESPAWN[2], RESPAWN[3])
		yards = nil
		below:Show()
	elseif yards and look ~= "orb" then
		below:SetText(Yards(yards))
		below:SetTextColor(1, 1, 1)
		below:Show()
	end
	below:ClearAllPoints()
	below:SetPoint("TOP", mark, "CENTER", 0, -13)
	mark:Show()
end

-- An arrow on the ring round the hero's spot (hx, hy), where the line toward
-- dx, dy meets it.
local function PaintArrow(arrow, spot, hx, hy, dx, dy, yards)
	local length = math.sqrt(dx * dx + dy * dy)
	if length < 0.001 then
		arrow:Hide()
		return
	end
	dx, dy = dx / length, dy / length
	local wide, tall = UIParent:GetWidth() * RING_WIDE, UIParent:GetHeight() * RING_TALL
	local reach = 1 / math.sqrt((dx / wide) * (dx / wide) + (dy / tall) * (dy / tall))
	arrow:ClearAllPoints()
	arrow:SetPoint("CENTER", UIParent, "BOTTOMLEFT", hx + dx * reach, hy + dy * reach)
	Point(arrow.point, math.atan2(dx, dy))
	if spot.look == "downed" then
		arrow.point:SetVertexColor(1, 0.36, 0.30, 1)
		arrow.icon:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
	else
		arrow.point:SetVertexColor(1, 0.82, 0.2, 1)
		arrow.icon:SetVertexColor(1, 1, 1, 1)
	end
	arrow.icon:SetTexture(ART..(ICONS[spot.look] or "MinimapChest"))
	arrow.icon:ClearAllPoints()
	-- The icon and the yards on the inner side, toward the middle.
	arrow.icon:SetPoint("CENTER", arrow, "CENTER", -dx * 24, -dy * 24)
	arrow.yards:SetText(Yards(yards))
	arrow.yards:ClearAllPoints()
	arrow.yards:SetPoint("TOP", arrow.icon, "BOTTOM", 0, -1)
	arrow:Show()
end

------------------------------------------------------------------------------
-- Each frame, after the camera: the spots and the arrows where the game says.

local function Distance(spot)
	if not heroAt or not spot.x then
		return nil
	end
	local dx, dy, dz = spot.x - heroAt.x, spot.y - heroAt.y, (spot.z or 0) - (heroAt.z or 0)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- The request for a world spot, by offset from the anchor that stays put.
local function Spot(wx, wy, wz)
	return { anchorId = base.id, attachment = "position", offset = { x = wx - base.x, y = wy - base.y, z = wz - base.z } }
end

local function HideFrom(list, first)
	for index = first, table.getn(list) do
		list[index]:Hide()
	end
end

-- The arrows: the nearest spots out of sight, each by its way from the hero's
-- spot on the screen (hero, projected).
local function DrawArrows(away, hero, ratio)
	for index = 1, table.getn(away) do
		away[index].yards = Distance(away[index]) or 0
	end
	table.sort(away, function(a, b)
		if (a.look == "downed") ~= (b.look == "downed") then
			return a.look == "downed"
		end
		return a.yards < b.yards
	end)
	local ways, requests = {}, {}
	for index = 1, math.min(table.getn(away), MOST_ARROWS) do
		local spot = away[index]
		local dx, dy = spot.x - heroAt.x, spot.y - heroAt.y
		local length = math.sqrt(dx * dx + dy * dy)
		if length > 0.5 then
			table.insert(ways, spot)
			table.insert(requests, Spot(heroAt.x + dx / length * WAY, heroAt.y + dy / length * WAY, heroAt.z))
		end
	end
	local pointed = 0
	if table.getn(requests) > 0 then
		local ok, answer = pcall(AZS_ProjectWorldAnchors, requests)
		local points = ok and answer and answer.entries or {}
		local hx, hy = hero.x * ratio, hero.y * ratio
		for index = 1, table.getn(ways) do
			local point = points[index]
			if point and point.x and point.y then
				pointed = pointed + 1
				PaintArrow(Arrow(pointed), ways[index], hx, hy, point.x * ratio - hx, point.y * ratio - hy, ways[index].yards)
			end
		end
	end
	return pointed
end

local function Draw()
	local requests, wanted = {}, {}
	for index = 1, table.getn(spots) do
		local spot = spots[index]
		if spot.unit and SUIC.PlateShows(spot.unit) then
			-- its nameplate names it (Nameplates.lua)
		elseif spot.anchor then
			table.insert(requests, { anchorId = spot.anchor, attachment = spot.attachment, offset = { x = 0, y = 0, z = spot.lift or 0 } })
			table.insert(wanted, spot)
		elseif base and spot.x then
			table.insert(requests, Spot(spot.x, spot.y, spot.z + (spot.lift or 0)))
			table.insert(wanted, spot)
		end
	end
	-- Each beam's foot and top.
	local lit = {}
	for index = 1, table.getn(wanted) do
		local spot = wanted[index]
		if spot.beam then
			table.insert(requests, { anchorId = spot.anchor, attachment = "position", offset = { x = 0, y = 0, z = 0 } })
			table.insert(requests, { anchorId = spot.anchor, attachment = "position", offset = { x = 0, y = 0, z = BEAM_TALL } })
			table.insert(lit, table.getn(requests) - 1)
		end
	end
	-- The hero's spot, for the arrows' way and the beams it stands in front of.
	local heroIndex
	if base and heroAt and (On("worldArrows") or table.getn(lit) > 0) then
		table.insert(requests, Spot(heroAt.x, heroAt.y, heroAt.z))
		heroIndex = table.getn(requests)
	end
	if table.getn(requests) == 0 or table.getn(requests) > 256 then
		HideFrom(marks, 1)
		HideFrom(arrows, 1)
		HideLights(1)
		return
	end
	local ok, result = pcall(AZS_ProjectWorldAnchors, requests)
	local entries = ok and result and result.entries or {}
	local ratio = WorldFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local shown, away = 0, {}
	for index = 1, table.getn(wanted) do
		local entry, spot = entries[index], wanted[index]
		if entry and entry.state == "onScreen" and entry.x then
			shown = shown + 1
			-- A beam's bag floats up and down a little.
			local bob = spot.beam and 2 * math.sin(GetTime() * 2.2 + index) or 0
			Paint(Mark(shown), spot, entry.x * ratio, entry.y * ratio + bob, entry.playerDistance or Distance(spot))
		elseif spot.arrow and entry and (entry.state == "offscreen" or entry.state == "behindCamera") then
			table.insert(away, spot)
		end
	end
	HideFrom(marks, shown + 1)
	local hero = heroIndex and entries[heroIndex]
	local glowing = 0
	for index = 1, table.getn(lit) do
		local low, high = entries[lit[index]], entries[lit[index] + 1]
		if low and high and low.state == "onScreen" and high.state == "onScreen" and low.x and high.x then
			glowing = glowing + 1
			PaintLight(Light(glowing), low, high, hero and hero.state == "onScreen" and hero or nil, index)
		end
	end
	HideLights(glowing + 1)
	local pointed = 0
	if hero and hero.state == "onScreen" and hero.x then
		pointed = DrawArrows(away, hero, ratio)
	end
	HideFrom(arrows, pointed + 1)
end

local function Showing()
	return SUIC.active and AZS_GetPhase and AZS_GetPhase() == "playing"
end

AZS_RegisterWorldAnchorFrameHandler(function()
	if not Showing() then
		if layer:IsShown() then
			layer:Hide()
			beams:Hide()
		end
		return
	end
	if not layer:IsShown() then
		layer:Show()
		beams:Show()
	end
	local ok, p = pcall(AZS_GetPlayerPosition)
	heroAt = ok and p and p.x and { x = p.x, y = p.y, z = p.z or 0 } or nil
	Draw()
end)

-- The catalog, four times a second.
local waited = READ_EVERY
local reader = CreateFrame("Frame")
reader:SetScript("OnUpdate", function()
	waited = waited + arg1
	if waited < READ_EVERY then
		return
	end
	waited = 0
	if Showing() then
		ReadAll()
	end
end)
