-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the caches and the guardians' lairs on the minimap: a
-- loot bag for a cache and a red-eyed skull for a lair, the newer client's
-- minimap icons (Art\MinimapChest, Art\MinimapSkull), else a golden chest
-- (Survivor UI's own pin) and a battleground's red flag. A lair's mark whole
-- while its guardian holds it, beating while it fights, faint under a green
-- check once its guardian is slain, as a boss slain in the run tracker. One beyond the minimap's round edge sits on the edge, smaller and
-- fainter, pointing the way. Hover a pin for what it is.
-- It stands in for the game's one red flag, put away while these are on.
--
-- The game shares every cache (AZS_CHESTS) and every lair (AZS_GetLairs) with
-- its place in the world, in yards, and the hero's (AZS_GetPlayerPosition, else
-- AZS_RUN px, py); the pins go by those (Survivor UI's MapPins.lua, the same
-- reckoning).

local ART = "Interface\\AddOns\\SurvivorUIClassic\\Art\\"
local CHEST = ART.."PinCache"
local FLAG = "Interface\\WorldStateFrame\\HordeFlag"
local OWN_CHEST = ART.."MinimapChest"
local OWN_SKULL = ART.."MinimapSkull"
local CHEST_SIZE = 16
local FLAG_SIZE = 18
local EDGE = 0.7                -- a pin out of reach, its size and its alpha

-- The yards across the minimap at each zoom, outdoors and indoors, as the
-- 1.12 client draws it.
local OUTSIDE_YARDS = { [0] = 466.67, [1] = 400, [2] = 333.33, [3] = 266.67, [4] = 200, [5] = 133.33 }
local INSIDE_YARDS = { [0] = 300, [1] = 240, [2] = 180, [3] = 120, [4] = 80, [5] = 50 }

local function Setting(name)
	local ok, value = pcall(GetCVar, name)
	return ok and tonumber(value) or nil
end

-- Indoors when the zoom is the indoor setting's and the two differ.
local function Yards()
	local zoom = Minimap:GetZoom() or 0
	local outside, inside = Setting("minimapZoom"), Setting("minimapInsideZoom")
	local yards = OUTSIDE_YARDS
	if outside and inside and outside ~= inside and zoom == inside then
		yards = INSIDE_YARDS
	end
	return yards[zoom] or yards[0]
end

local pins = {}

local function PinEnter()
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	GameTooltip:SetText(this.title or "", 1, 0.82, 0)
	if this.note then
		GameTooltip:AddLine(this.note, 0.85, 0.85, 0.85)
	end
	if this.yards then
		GameTooltip:AddLine(math.floor(this.yards + 0.5).." yards away", 0.6, 0.6, 0.6)
	end
	GameTooltip:Show()
end

local function Pin(index)
	local pin = pins[index]
	if pin then
		return pin
	end
	pin = CreateFrame("Frame", nil, Minimap)
	pin:SetFrameLevel(Minimap:GetFrameLevel() + 4)
	pin.art = pin:CreateTexture(nil, "ARTWORK")
	pin.art:SetAllPoints(pin)
	pin.check = pin:CreateTexture(nil, "OVERLAY")
	pin.check:SetTexture(SUIC.CHECK)
	pin.check:SetVertexColor(0.3, 1, 0.3)
	pin.check:SetPoint("TOPLEFT", pin, "TOPLEFT", 1, -1)
	pin.check:SetPoint("BOTTOMRIGHT", pin, "BOTTOMRIGHT", -1, 1)
	pin.check:Hide()
	pin:EnableMouse(true)
	pin:SetScript("OnEnter", PinEnter)
	pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
	pins[index] = pin
	return pin
end

-- A pin east and south of the hero, in yards: on the minimap, or on its round
-- edge toward the place when beyond it.
local function Place(pin, east, south, perYard, radius, size)
	pin.yards = math.sqrt(east * east + south * south)
	local x, y = east * perYard, -south * perYard
	local far = math.sqrt(x * x + y * y)
	local alpha = 1
	if far > radius - size / 2 then
		size = math.floor(size * EDGE + 0.5)
		local reach = radius - size / 2
		x, y = x * reach / far, y * reach / far
		alpha = EDGE
	end
	pin:SetWidth(size)
	pin:SetHeight(size)
	pin:ClearAllPoints()
	pin:SetPoint("CENTER", Minimap, "CENTER", x, y)
	pin.alpha = alpha
	pin:Show()
end

local function Num(value)
	return tonumber(value)
end

-- The hero's place: the game's live one (its 0.132), in dungeons and raids too;
-- else the px and py it sends a few times a second.
local function Hero(run)
	local place = AZS_GetPlayerPosition and AZS_GetPlayerPosition()
	if place then
		return place.x, place.y
	end
	return Num(run.px), Num(run.py)
end

local function Draw()
	local shown = 0
	local run = AZS_RUN or {}
	local px, py = Hero(run)
	if SUIC.InRun() and px and py then
		local radius = Minimap:GetWidth() / 2
		local perYard = 2 * radius / Yards()
		local chests = AZS_CHESTS or {}
		for index = 1, table.getn(chests) do
			local chest = chests[index]
			local x, y = Num(chest.x), Num(chest.y)
			if x and y then
				shown = shown + 1
				local pin = Pin(shown)
				-- SetTexture answers nil for a file that is not there.
				if not pin.art:SetTexture(OWN_CHEST) then
					pin.art:SetTexture(CHEST)
				end
				pin.art:SetTexCoord(0, 1, 0, 1)
				pin.art:SetVertexColor(1, 1, 1)
				pin.art:SetAlpha(1)
				pin.check:Hide()
				pin.title, pin.note = "Cache", "Costs "..(Num(run.chest) or "?").." gold"
				Place(pin, py - y, px - x, perYard, radius, CHEST_SIZE)
				pin:SetAlpha(pin.alpha)
			end
		end
		local lairs = AZS_GetLairs and AZS_GetLairs() or {}
		local beat = 0.65 + 0.35 * math.sin(GetTime() * 6)
		for index = 1, table.getn(lairs) do
			local lair = lairs[index]
			local x, y = Num(lair.x), Num(lair.y)
			if x and y then
				shown = shown + 1
				local pin = Pin(shown)
				if not pin.art:SetTexture(OWN_SKULL) then
					pin.art:SetTexture(FLAG)
				end
				pin.art:SetTexCoord(0, 1, 0, 1)
				Place(pin, py - y, px - x, perYard, radius, FLAG_SIZE)
				pin.title = (lair.name and lair.name ~= "") and lair.name or "Lair"
				pin.art:SetAlpha(1)
				pin.check:Hide()
				if lair.state == "awake" then
					pin.note = "Fighting"
					pin.art:SetVertexColor(1, 0.6, 0.2)
					pin:SetAlpha(pin.alpha * beat)
				elseif lair.state == "asleep" then
					pin.note = "In its lair"
					pin.art:SetVertexColor(1, 1, 1)
					pin:SetAlpha(pin.alpha)
				else
					local left = Num(lair.left) or -1
					pin.note = "Slain"..(left > 0 and (", back in "..SUIC.Clock(left)) or "")
					pin.art:SetVertexColor(1, 1, 1)
					pin.art:SetAlpha(0.35)
					pin.check:Show()
					pin:SetAlpha(pin.alpha)
				end
			end
		end
	end
	for index = shown + 1, table.getn(pins) do
		pins[index]:Hide()
	end
end

local ticker = CreateFrame("Frame")
local elapsed = 0
ticker:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.05 then
		return
	end
	elapsed = 0
	Draw()
end)
ticker:Hide()

function SUIC.RefreshMapPins()
	local wanted = SUIC.DB().mapPins
	SUIC.SetGameShown("flag", not wanted)
	if wanted then
		ticker:Show()
	else
		ticker:Hide()
		for index = 1, table.getn(pins) do
			pins[index]:Hide()
		end
	end
end

SUIC.OnStart(function()
	SUIC.RefreshMapPins()
end)
