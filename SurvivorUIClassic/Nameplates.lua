-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the nameplates, on with this interface. V
-- turns the enemies' on and off, Shift-V the friends', each on its own (the
-- stock keys show one kind and hide the other). The keys are set once, as the
-- addon first starts, and saved with the game's bindings; changed after in
-- the game's Key Bindings, they stay as chosen. The game's Level Up! key, if
-- V took it, goes back to Y.

BINDING_HEADER_SUIC = "SurvivorUI Classic"
BINDING_NAME_SUIC_ENEMYPLATES = "Enemy nameplates on and off"
BINDING_NAME_SUIC_FRIENDPLATES = "Friendly nameplates on and off"

function SUIC_ToggleEnemyPlates()
	if NAMEPLATES_ON then
		HideNameplates()
		NAMEPLATES_ON = nil
	else
		ShowNameplates()
		NAMEPLATES_ON = 1
	end
end

function SUIC_ToggleFriendPlates()
	if FRIENDNAMEPLATES_ON then
		HideFriendNameplates()
		FRIENDNAMEPLATES_ON = nil
	else
		ShowFriendNameplates()
		FRIENDNAMEPLATES_ON = 1
	end
end

-- The game's Nameplate Layout (its 0.131): nil on a game without it.
local function Layout()
	local known, value = pcall(GetCVar, "nameplateLayout")
	return known and value or nil
end

function SUIC.RefreshPlateLayout()
	if Layout() then
		SetCVar("nameplateLayout", SUIC.DB().plateOverlap and "overlap" or "stack")
	end
end

SUIC.OnStart(function()
	local db = SUIC.DB()
	-- "Show only bosses, guardians and elites" (0.2.9) is the normal ones' switch off.
	if db.platesImportant then
		db.platesNormal = false
		db.platesImportant = nil
	end
	-- The friends' plates on, once for everyone (0.2.10, their new look).
	if not db.friendPlatesSet then
		db.friendPlatesSet = true
		if not FRIENDNAMEPLATES_ON then
			ShowFriendNameplates()
			FRIENDNAMEPLATES_ON = 1
		end
	end
	-- Overlapping for everyone, once; after that the box follows the game's
	-- option, which may have changed since.
	if Layout() then
		if db.layoutSet then
			db.plateOverlap = Layout() == "overlap"
		else
			db.layoutSet = true
			db.plateOverlap = true
			SUIC.RefreshPlateLayout()
		end
	end
	if db.plates then
		return
	end
	db.plates = true
	-- The enemies' plates on, the first time.
	if not NAMEPLATES_ON then
		ShowNameplates()
		NAMEPLATES_ON = 1
	end
	if SetBinding and SaveBindings then
		local levels = GetBindingAction and GetBindingAction("V")
		SetBinding("V", "SUIC_ENEMYPLATES")
		SetBinding("SHIFT-V", "SUIC_FRIENDPLATES")
		if levels == "AZS_OPENLEVELS" and not GetBindingKey("AZS_OPENLEVELS")
				and (GetBindingAction("Y") or "") == "" then
			SetBinding("Y", "AZS_OPENLEVELS")
		end
		SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1)
	end
end)

------------------------------------------------------------------------------
-- The plates' look (Lucas, 2026-11-02): the client's plate stays where the
-- client seats it, its art put away, and a bar of our own drawn on it in the
-- manner of the old plates: a thin black line with round ends round the bar,
-- the name over it, the health's share small inside. The rank and file in
-- red; the elites, the lair guardians, the bosses and the final boss in the
-- item qualities' colors (uncommon, rare, epic, legendary), each a little
-- larger. Your target's line is gold, as the boss bars frame it; the boss bar
-- under the mouse lines its enemy's in white (SUIC.LightPlate, BossBars.lua).
-- A friend's plate (the client colors it green or blue) the same way: a
-- member of the party (a co-op run's, party1 to party4 by name) in the
-- class's color, every other friend (pets, summons, totems) in mint, apart
-- from the elites' green. The raid mark, the client's own icon, left of the
-- bar.
--
-- Each enemy's kind is the game's: the world anchors of the elites, lair
-- guardians and bosses alive (the game's 0.139.2), read four times a second
-- and put on the screen ten times, each claiming the nearest plate of its
-- name; and the target's from AZS_UnitKind. A lair guardian is named as its
-- zone's elites, so the name alone can't tell the two. A plate no anchor
-- claims (the layout Stacking moves plates apart) goes by its name; without
-- anchors (an older game), by the game's list of them (AZS_UNITS).
--
-- Which enemies' plates show (the options' Nameplates tab): each kind on its
-- own, the normal ones, elites, guardians and bosses (all but the normal ones
-- by default, Lucas's choice), or your target only; your target's though its
-- kind is off if asked, and always the one the boss bar under the mouse lines. A plate left out
-- has its bar hidden, the plate itself untouched: the client keeps it, and
-- its target's light (the target's plate the one at full alpha).
--
-- The client keeps a pool of plates and hands them from unit to unit as the
-- enemies come within 20 yards, go and die: in a crowd, every moment. So each
-- plate is read again every frame (its name, its bar's color and health),
-- else one handed on shows its last unit's look for a moment.

local ROUND = "Interface\\AddOns\\SurvivorUIClassic\\Art\\PlateRound"
local END = 0.25                 -- each round end's share of the art across
local READ_EVERY = 0.25          -- the anchors' catalog
local CLAIM_EVERY = 0.1          -- their spots on the screen
local CLAIM_LASTS = 0.6          -- a plate's claim, unclaimed since
-- The client seats a plate's middle on its unit's overhead spot, 4 points
-- off at most (seen 2026-11-02).
local NEAR = 24                  -- the farthest a plate sits from there
local GOLD = { 1, 0.82, 0 }
local ART = "Interface\\AddOns\\SurvivorUIClassic\\Art\\"
-- The enemies' names a fifth smaller and their bars a tenth (Lucas,
-- 2026-11-02) than the first ones. A skull over the name, three of them,
-- each meaner: our plain bone one over an elite's, the minimap's for lairs
-- over a guardian's, and our infernal one over a boss's.
-- Each kind's plate raised over the rest by `rise` frame levels (Lucas: the
-- bosses in front, then the guardians, then the elites).
local KINDS = {
	normal   = { width = 81,  height = 8,  name = 8,  share = 7, color = { 0.77, 0.12, 0.12 } },
	elite    = { width = 95,  height = 9,  name = 9,  share = 7, color = { 0.12, 0.72, 0.12 },
		skull = "EliteSkull", skullSize = 14, rise = 10 },
	guardian = { width = 106, height = 10, name = 9,  share = 8, color = { 0.00, 0.44, 0.87 },
		skull = "MinimapSkull", skullSize = 16, rise = 20 },
	boss     = { width = 119, height = 11, name = 10, share = 8, color = { 0.64, 0.21, 0.93 },
		skull = "BossSkull", skullSize = 22, rise = 30 },
	final    = { width = 128, height = 11, name = 10, share = 8, color = { 1.00, 0.50, 0.00 },
		skull = "BossSkull", skullSize = 22, rise = 30 },
	-- The friends' bars 30% thinner and their names a fifth smaller, in a
	-- gold rim (Lucas, 2026-11-02).
	party    = { width = 81,  height = 5.5, name = 6.4, share = 5, rim = true },
	pet      = { width = 81,  height = 5.5, name = 6.4, share = 5, rim = true, color = { 0.30, 0.88, 0.62 } },
}
local FADE = 0.75                -- the rank and file's colors, behind the rest
-- Each kind's switch in the options (the final boss's is the bosses').
local KIND_KEYS = { normal = "platesNormal", elite = "platesElite", guardian = "platesGuardian",
	boss = "platesBoss", final = "platesBoss" }
-- The kinds as the anchors, AZS_UNITS and AZS_UnitKind name them.
local KIND_OF = { elite = "elite", guardian = "guardian", boss = "boss", finalBoss = "final", final = "final", normal = "normal" }
local QUERY = { kinds = { "elite", "guardian", "boss", "finalBoss" }, states = { "alive" } }

local scanned, looks = 0, {}
local visible, shownCount = {}, 0
local important, importantAt = {}, nil
local anchors, named = {}, {}    -- the anchors alive; their kinds by name
local party, partyWait = {}, 1   -- the party's classes by name, read once a second
local lit, litId                 -- the enemy to line: its name, its unit's id
local litLook, targetKind, targetName
local hovered, hoverWait = nil, 0 -- the plate under the mouse, looked for 20 times a second
local HOVER_RISE = 40

-- The tests find the plates here.
SUIC.Plates = looks

function SUIC.LightPlate(name, id)
	lit = name
	litId = name and id and tostring(id) or nil
end

-- Whether a unit's plate is on the screen with its bar drawn, by its unit's
-- id (an anchor's unitId): WorldMarks.lua leaves out its mark over an awake
-- lair guardian then.
function SUIC.PlateShows(unit)
	local now = GetTime()
	for index = 1, shownCount do
		local look = visible[index]
		if look.unit == unit and look.shown and look.claimName == look.named
				and now - look.claimAt < CLAIM_LASTS then
			return true
		end
	end
	return false
end

local function IsPlate(frame)
	local region = frame:GetRegions()
	return region and region.GetObjectType and region:GetObjectType() == "Texture"
		and region:GetTexture() == "Interface\\Tooltips\\Nameplate-Border"
end

-- A name's kind in a list, "mixed" for a name two kinds share.
local function Mark(list, name, kind)
	if list[name] and list[name] ~= kind then
		list[name] = "mixed"
	else
		list[name] = kind
	end
end

local function Important()
	if AZS_UNITS_UPDATED ~= importantAt then
		importantAt = AZS_UNITS_UPDATED
		important = {}
		local units = AZS_UNITS or {}
		for index = 1, table.getn(units) do
			if units[index].name then
				Mark(important, units[index].name, KIND_OF[units[index].kind] or "elite")
			end
		end
	end
	return important
end

local function KindByName(name)
	local kind = name and (named[name] or Important()[name])
	if kind == "mixed" then
		return "elite"
	end
	return kind or "normal"
end

local function ReadParty()
	party = {}
	for index = 1, 4 do
		local unit = "party"..index
		local name = UnitExists(unit) and UnitName(unit)
		if name then
			local _, class = UnitClass(unit)
			party[name] = class or "?"
		end
	end
end

local function ReadAnchors()
	local found, kinds, cursor = {}, {}, nil
	for page = 1, 4 do
		local ok, result = pcall(AZS_GetWorldAnchors, QUERY, cursor, 256)
		if not ok or not result or not result.entries then
			return
		end
		for index = 1, table.getn(result.entries) do
			local entry = result.entries[index]
			local kind = KIND_OF[entry.kind or ""]
			if kind and entry.name and entry.anchorId then
				table.insert(found, { id = entry.anchorId, kind = kind, name = entry.name,
					unit = entry.unitId and tostring(entry.unitId) })
				Mark(kinds, entry.name, kind)
			end
		end
		if not result.hasMore or not result.nextCursor then
			break
		end
		cursor = result.nextCursor
	end
	anchors, named = found, kinds
end

-- Each anchor on the screen claims the nearest plate of its name, one plate
-- each, in WorldFrame's units (the plates are its children).
local function Claim()
	local count = table.getn(anchors)
	if count == 0 or count > 256 or shownCount == 0 then
		return
	end
	local requests = {}
	for index = 1, count do
		requests[index] = { anchorId = anchors[index].id, attachment = "overhead", offset = { x = 0, y = 0, z = 0 } }
	end
	local ok, result = pcall(AZS_ProjectWorldAnchors, requests)
	local entries = ok and result and result.entries
	if not entries then
		return
	end
	local world, now, taken = WorldFrame:GetEffectiveScale(), GetTime(), {}
	for index = 1, count do
		local spot, anchor = entries[index], anchors[index]
		if spot and spot.state == "onScreen" and spot.x then
			local best, bestFar
			for each = 1, shownCount do
				local look = visible[each]
				if look.named == anchor.name and not taken[look] then
					local x, y = look.plate:GetCenter()
					if x then
						local scale = look.plate:GetEffectiveScale() / world
						local dx, dy = x * scale - spot.x, y * scale - spot.y
						local far = dx * dx + dy * dy
						if far <= NEAR * NEAR and (not bestFar or far < bestFar) then
							best, bestFar = look, far
						end
					end
				end
			end
			if best then
				taken[best] = true
				best.claim, best.claimName, best.claimAt, best.unit = anchor.kind, anchor.name, now, anchor.unit
			end
		end
	end
end

-- Three pieces of the rounded art: the left end, the middle, the right end.
local function Strip(parent, layer)
	local strip = {}
	for index = 1, 3 do
		strip[index] = parent:CreateTexture(nil, layer)
		strip[index]:SetTexture(ROUND)
	end
	strip[2]:SetTexCoord(END, 1 - END, 0, 1)
	return strip
end

local function Tint(strip, r, g, b, a)
	for index = 1, 3 do
		strip[index]:SetVertexColor(r, g, b, a)
	end
end

-- The line round the bar: black, your target's gold, the one the boss bar
-- lines white.
-- A friend's (the party's, a pet's) a rim of gold in its place (PlateGold, of
-- our own), to tell them from the enemies: the rim RIM of its art's height on
-- each side, the bar in its hollow.
local EDGES = { none = { 0, 0, 0 }, target = GOLD, lit = { 1, 1, 1 }, friend = { 0.78, 0.62, 0.26 } }
local RIM = 5 / 32
local FRIENDS = { party = true, pet = true }

-- Every piece's color at the plate's own alpha: the rank and file a little
-- faded behind the rest, your target never. The client dims every plate but
-- the target's with the plate's alpha, and in this game a frame's alpha takes
-- the place of its children's, not multiplied: so the fading is in the colors.
local function Paint(look)
	local a, edge = look.fade, EDGES[look.edge]
	local color = look.style.color or { look.r or 1, look.g or 1, look.b or 1 }
	Tint(look.line, edge[1], edge[2], edge[3], a)
	-- The rim a little dull, bright on your target.
	local shine = look.edge == "target" and 1 or 0.85
	Tint(look.gold, shine, shine, shine, a)
	Tint(look.back, 0.06, 0.06, 0.06, a)
	Tint(look.fill, color[1], color[2], color[3], a)
	look.name:SetTextColor(1, 1, 1, a)
	look.share:SetTextColor(1, 1, 1, a)
	look.skull:SetVertexColor(1, 1, 1, a)
	look.painted = true
end

local function Piece(piece, holder, left, width, height, from, to)
	if width < 0.5 then
		piece:Hide()
		return
	end
	piece:ClearAllPoints()
	piece:SetPoint("LEFT", holder, "LEFT", left, 0)
	piece:SetWidth(width)
	piece:SetHeight(height)
	if from then
		piece:SetTexCoord(from, to, 0, 1)
	end
	piece:Show()
end

-- A strip `width` across and `height` tall, `left` from its holder's left
-- edge, drawn `filled` across from its left: the ends as round as the height
-- has them, a fill short of the right end cut square.
local function Lay(strip, holder, left, width, height, filled)
	local cap = math.min(height, width) / 2
	local first = math.min(filled, cap)
	local middle = math.min(math.max(filled - cap, 0), width - 2 * cap)
	local last = math.max(filled - (width - cap), 0)
	Piece(strip[1], holder, left, first, height, 0, END * first / cap)
	Piece(strip[2], holder, left + cap, middle, height)
	Piece(strip[3], holder, left + width - cap, last, height, 1 - END, 1 - END + END * last / cap)
end

-- The client's raid icon, left of the bar, a little taller. The client sets
-- its anchor again when the window changes size, so it is put back each time
-- a mark shows.
local function PlaceRaid(look)
	local raid = look.stock.raid
	if not raid then
		return
	end
	local size = math.max(14, look.style.height + 8)
	raid:ClearAllPoints()
	raid:SetPoint("RIGHT", look.bar, "LEFT", -3, 0)
	raid:SetWidth(size)
	raid:SetHeight(size)
end

-- The bosses' plates over the guardians', theirs over the elites', and those
-- over the rest: in a crowd the plate that matters is in front; the one under
-- the mouse over them all. The game draws every frame by its own strata and
-- level, and a frame's level does not carry down to its children, so each one
-- is raised.
local function Raise(look)
	local rise = look.level + (look.style.rise or 0) + (look == hovered and HOVER_RISE or 0)
	look.plate:SetFrameLevel(rise)
	look:SetFrameLevel(rise + 1)
	look.bar:SetFrameLevel(rise + 2)
end

-- The soft glow round the bar of the plate under the mouse, as far out as
-- the bar is tall (the art's hollow is half its height).
local function Glow(look, on)
	if on then
		local style = look.style
		Lay(look.glow, look.bar, -style.height / 2, style.width + style.height, style.height * 2,
			style.width + style.height)
	else
		for index = 1, 3 do
			look.glow[index]:Hide()
		end
	end
end

local function Dress(look, kind)
	local style = KINDS[kind]
	look.kind, look.style = kind, style
	look.bar:SetWidth(style.width)
	look.bar:SetHeight(style.height)
	look.name:SetFont(look.face, style.name, "OUTLINE")
	if style.rim then
		local tall = style.height / (1 - 2 * RIM)
		local out = (tall - style.height) / 2
		Lay(look.gold, look.bar, -out, style.width + 2 * out, tall, style.width + 2 * out)
		Lay(look.line, look.bar, -1, style.width + 2, style.height + 2, 0)
	else
		Lay(look.gold, look.bar, 0, style.width, style.height, 0)
		Lay(look.line, look.bar, -1, style.width + 2, style.height + 2, style.width + 2)
	end
	Lay(look.back, look.bar, 0, style.width, style.height, style.width)
	Raise(look)
	Glow(look, look == hovered)
	if style.share then
		-- In the bar's middle up and down: the digits sit low in their line,
		-- an eighth of the font's size (seen 2026-11-02, the friends' thin bars).
		look.share:SetFont(look.face, style.share, "OUTLINE")
		look.share:ClearAllPoints()
		look.share:SetPoint("RIGHT", look.bar, "RIGHT", -3, style.share * 0.12)
		look.share:Show()
	else
		look.share:Hide()
	end
	if style.skull then
		look.skull:SetTexture(ART..style.skull)
		look.skull:SetWidth(style.skullSize)
		look.skull:SetHeight(style.skullSize)
		look.skull:Show()
	else
		look.skull:Hide()
	end
	look.across, look.percent, look.class, look.painted = nil, nil, nil, nil
	if look.marked then
		PlaceRaid(look)
	end
end

local function Skin(plate)
	local stock = { bar = plate:GetChildren() }
	if not (stock.bar and stock.bar.GetMinMaxValues) then
		return
	end
	-- The client's regions: border, glow, name, level, level icon, raid
	-- icon. The name is the first font string; the raid icon the last
	-- texture, kept. The rest put away for good: the client sets their text
	-- and shows them again, so a texture loses its art, a font string its width.
	local regions = { plate:GetRegions() }
	local count = table.getn(regions)
	if count > 0 and regions[count]:GetObjectType() == "Texture" then
		stock.raid = regions[count]
	end
	for index = 1, count do
		local region = regions[index]
		if region:GetObjectType() == "FontString" then
			stock.name = stock.name or region
			region:SetWidth(0.001)
		elseif index < count then
			region:SetTexture("")
			region:SetTexCoord(0, 0, 0, 0)
		end
	end
	if not stock.name then
		return
	end
	stock.bar:SetStatusBarTexture("")

	local look = CreateFrame("Frame", nil, plate)
	look:SetAllPoints(plate)
	look.plate, look.stock = plate, stock
	plate.suicLook = look
	look.level = plate:GetFrameLevel()
	look.face = stock.name:GetFont() or STANDARD_TEXT_FONT
	look.bar = CreateFrame("Frame", nil, look)
	look.bar:SetPoint("CENTER", look, "CENTER", 0, -4)
	look.line = Strip(look.bar, "BACKGROUND")
	look.back = Strip(look.bar, "BORDER")
	look.fill = Strip(look.bar, "ARTWORK")
	-- Under the bar (on the frame below it), its light added.
	look.glow = Strip(look, "BACKGROUND")
	for index = 1, 3 do
		look.glow[index]:SetTexture(ART.."PlateGlow")
		look.glow[index]:SetBlendMode("ADD")
		look.glow[index]:SetVertexColor(1, 0.92, 0.70, 0.9)
		look.glow[index]:Hide()
	end
	look.glow[2]:SetTexCoord(END, 1 - END, 0, 1)
	-- Over the bar's edge, the bar in its hollow.
	look.gold = Strip(look.bar, "OVERLAY")
	for index = 1, 3 do
		look.gold[index]:SetTexture(ART.."PlateGold")
	end
	look.gold[2]:SetTexCoord(END, 1 - END, 0, 1)
	look.name = SUIC.Text(look.bar, "GameFontHighlightSmall")
	look.name:SetPoint("BOTTOM", look.bar, "TOP", 0, 2)
	look.share = SUIC.Text(look.bar, "GameFontHighlightSmall")
	look.share:SetShadowOffset(0, 0)
	look.skull = look.bar:CreateTexture(nil, "OVERLAY")
	look.skull:SetPoint("BOTTOM", look.name, "TOP", 0, 0)
	look.shown, look.edge, look.fade = true, "none", 1
	Dress(look, "normal")
	table.insert(looks, look)
end

local function Update(look, db, hasTarget, now)
	local stock = look.stock
	local name = stock.name:GetText()
	if name ~= look.named then
		look.named = name
		look.name:SetText(name)
	end
	-- The target's plate: the one at full alpha, the others dimmed. With the
	-- target out of the plates' reach the client leaves them all at full
	-- alpha (seen 2026-11-02), so it takes being the only one, and its name.
	local isTarget = hasTarget and look.plate:GetAlpha() == 1 and name == targetName
	local r, g, b = stock.bar:GetStatusBarColor()
	local kind
	if r and r < 0.2 and ((g or 0) > 0.8 or (b or 0) > 0.8) then
		kind = party[name] and "party" or "pet"
	elseif look.claim and look.claimName == name and now - look.claimAt < CLAIM_LASTS then
		kind = look.claim
	elseif isTarget and targetKind then
		kind = targetKind
	else
		kind = KindByName(name)
	end
	if kind ~= look.kind then
		Dress(look, kind)
	end
	if kind == "party" and party[name] ~= look.class then
		look.class = party[name]
		look.r, look.g, look.b = SUIC.ClassColor(look.class)
		if not look.r then
			look.r, look.g, look.b = 0.45, 0.78, 1
		end
		look.painted = nil
	end

	local shown = true
	if KIND_KEYS[kind] and db.platesTarget then
		shown = isTarget or look == litLook
	elseif KIND_KEYS[kind] then
		shown = db[KIND_KEYS[kind]] or look == litLook or (isTarget and db.platesTargetAny)
	end
	if shown ~= look.shown then
		look.shown = shown
		if shown then
			look.bar:Show()
		else
			look.bar:Hide()
		end
		if stock.raid then
			stock.raid:SetAlpha(shown and 1 or 0)
		end
	end
	if not shown then
		return
	end

	local low, high = stock.bar:GetMinMaxValues()
	local share = 0
	if low and high and high > low then
		share = math.max(0, math.min(1, (stock.bar:GetValue() - low) / (high - low)))
	end
	local style = look.style
	local across = math.floor(share * style.width * 2 + 0.5) / 2
	if across ~= look.across then
		look.across = across
		Lay(look.fill, look.bar, 0, style.width, style.height, across)
	end
	if style.share then
		local percent = math.floor(share * 100 + 0.5)
		if percent == 0 and share > 0 then
			percent = 1
		end
		if percent ~= look.percent then
			look.percent = percent
			look.share:SetText(percent.."%")
		end
	end

	local edge = (look == litLook and "lit") or (isTarget and "target") or (FRIENDS[kind] and "friend") or "none"
	local fade = (kind == "normal" and not isTarget and look ~= litLook) and FADE or 1
	if edge ~= look.edge or fade ~= look.fade or not look.painted then
		look.edge, look.fade = edge, fade
		Paint(look)
	end

	local marked = stock.raid and stock.raid:IsShown() and true or false
	if marked and not look.marked then
		PlaceRaid(look)
	end
	look.marked = marked
end

-- The plate to line: the one its unit's anchor claimed, else the first of
-- its name.
local function Lit()
	if not lit then
		return nil
	end
	local first
	for index = 1, shownCount do
		local look = visible[index]
		if litId and look.unit == litId and look.claimName == look.named then
			return look
		end
		if not first and look.named == lit then
			first = look
		end
	end
	return first
end

-- The plate under the mouse, by hand (as Survivor Plates does): of the plates
-- with their bar drawn, the nearest one whose bar or name the mouse is on;
-- none with the mouse on a window.
local function UnderMouse()
	local focus = GetMouseFocus and GetMouseFocus()
	if focus and focus ~= WorldFrame and not focus.suicLook then
		return nil
	end
	local x, y = GetCursorPosition()
	local best, bestGap
	for index = 1, shownCount do
		local look = visible[index]
		if look.shown then
			local scale = look.bar:GetEffectiveScale()
			local atX, atY = x / scale, y / scale
			local left, right, bottom = look.bar:GetLeft(), look.bar:GetRight(), look.bar:GetBottom()
			local top = look.name:GetTop() or look.bar:GetTop()
			if left and bottom and top and atX >= left - 2 and atX <= right + 2
					and atY >= bottom - 2 and atY <= top + 2 then
				local gap = math.abs(atX - (left + right) / 2) + math.abs(atY - (top + bottom) / 2)
				if not bestGap or gap < bestGap then
					best, bestGap = look, gap
				end
			end
		end
	end
	return best
end

local function SetHovered(look)
	if look == hovered then
		return
	end
	local was = hovered
	hovered = look
	if was then
		Glow(was, false)
		Raise(was)
	end
	if look then
		Glow(look, true)
		Raise(look)
	end
end

-- The tests find the plate under the mouse here.
function SUIC.HoveredPlate()
	return hovered
end

local readWait, claimWait = READ_EVERY, CLAIM_EVERY
local scanner = CreateFrame("Frame")
scanner:SetScript("OnUpdate", function()
	local count = WorldFrame:GetNumChildren()
	if count ~= scanned then
		local children = { WorldFrame:GetChildren() }
		for index = scanned + 1, count do
			if children[index] and IsPlate(children[index]) then
				Skin(children[index])
			end
		end
		scanned = count
	end
	shownCount = 0
	local bright = 0
	for index = 1, table.getn(looks) do
		local plate = looks[index].plate
		if plate:IsVisible() then
			shownCount = shownCount + 1
			visible[shownCount] = looks[index]
			if plate:GetAlpha() == 1 then
				bright = bright + 1
			end
		end
	end
	partyWait = partyWait + arg1
	if partyWait >= 1 then
		partyWait = 0
		ReadParty()
	end
	if AZS_GetWorldAnchors and AZS_ProjectWorldAnchors then
		readWait = readWait + arg1
		if readWait >= READ_EVERY then
			readWait = 0
			ReadAnchors()
		end
		claimWait = claimWait + arg1
		if claimWait >= CLAIM_EVERY then
			claimWait = 0
			Claim()
		end
	end
	local hasTarget = UnitExists("target") and bright == 1
	targetName = hasTarget and UnitName("target") or nil
	targetKind = hasTarget and AZS_UnitKind and KIND_OF[AZS_UnitKind("target") or ""] or nil
	litLook = Lit()
	local db, now = SUIC.DB(), GetTime()
	for index = 1, shownCount do
		Update(visible[index], db, hasTarget, now)
	end
	hoverWait = hoverWait + arg1
	if hoverWait >= 0.05 then
		hoverWait = 0
		SetHovered(UnderMouse())
	end
end)
scanner:Hide()

SUIC.OnStart(function()
	scanner:Show()
end)
