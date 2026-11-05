-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: a spell's cooldown at the game's floor. The build list
-- writes it as it is (SUIC.TrueCooldown), in green with a small hourglass
-- (BuildList.lua), and a small gold hourglass sits at the foot of the spell's
-- action button while it is there, as quick as it gets: more haste or a
-- cooldown card does nothing for it then. As Survivor UI's FloorHourglass.lua
-- (Lucas, 2026-11-05).
--
-- The game's rule (its exe 0.141.0, read 2026-11-05): a spell's cooldown is
-- its base x 1.4 x its cards x its talents x the haste, never under a floor
-- of 0.25 sec; Hellfire's is 0.5, Divine Shield's 4 to 4.4 (4 with any bonus
-- to the shield's length). Eight spells (the game's family 11: OWN_WAY,
-- below) work theirs out another way, a least of their own over how often
-- they proc, which can go under 0.25: no floor is told for them, and no
-- hourglass.
--
-- The cooldown the game sends (AZS_SPELLS, cdmax) has the floor in, but to
-- one decimal, a tie to the even: 0.25 comes as 0.2. No other spell goes
-- under 0.25, so a 0.2 is the floor's 0.25. Hellfire's 0.5 is its floor or up
-- to 0.05 over it (0.5 to 0.55 all come as 0.5). Divine Shield's hourglass is
-- only at 4.0, the lowest it can be: the game does not tell the shield's
-- length for sure.
--
-- The hourglass hangs from the button's bottom edge, mostly over the button,
-- over its cooldown numbers (Cooldowns.lua). The spells sit on the action bar
-- in AZS_SPELLS's order, the racial (the last) on button 12. On or off in the
-- options' Action bar tab.

local ART = "Interface\\AddOns\\SurvivorUIClassic\\Art\\"
local FLOOR = 0.25
local FLOORS = { hellfire = 0.5, divine_shield = 4 }
-- The game's family 11, the whole of it (its table of 115 spells walked):
-- each its own least, over its proc rate (bloodrage 8, lightwell 6,
-- soul_fire 3, polymorph 3, seal_fate 2, hunters_mark 2); redemption and
-- faerie_fire have no cooldown (0 sent).
local OWN_WAY = {
	bloodrage = true, lightwell = true, soul_fire = true, polymorph = true,
	seal_fate = true, hunters_mark = true, redemption = true, faerie_fire = true,
}
local SIZE = 14          -- the hourglass's side, at the bar's own size
local BELOW = 3          -- how far it reaches under the button's bottom edge
local RACIAL_SLOT = 12

-- A spell's cooldown, by its key in AZS_SPELLS and the cdmax the game sent,
-- as near as the game tells it, and its floor while it is at it (else nil):
-- a 0.2 is the floor's 0.25. Unknown keys (nil) and OWN_WAY's as sent.
function SUIC.TrueCooldown(key, cdmax)
	cdmax = tonumber(cdmax) or 0
	if not key or cdmax <= 0 or OWN_WAY[key] then
		return cdmax, nil
	end
	local floor = FLOORS[key] or FLOOR
	if cdmax < floor + 0.001 then
		return floor, floor
	end
	return cdmax, nil
end

-- Over the button, a little clear of it.
local function Tip()
	local mark = this
	mark.over = true
	GameTooltip:SetOwner(mark, "ANCHOR_NONE")
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("BOTTOM", mark:GetParent(), "TOP", 0, 6)
	local name = SUIC.SpellName and SUIC.SpellName(mark.slot)
	GameTooltip:AddLine(SUIC.Native(name or string.gsub(mark.key or "?", "_", " ")), 1, 0.82, 0)
	local seconds = SUIC.CooldownWords and SUIC.CooldownWords(mark.floor) or (mark.floor.."s")
	GameTooltip:AddLine(SUIC.TF("At its fastest: {1}, the game's floor. More haste or cooldown cards do nothing for this spell.", seconds), 1, 1, 1, 1)
	GameTooltip:Show()
end

local function Untip()
	if this.over then
		this.over = nil
		GameTooltip:Hide()
	end
end

local marks = {}         -- [action button] = its hourglass

local function Mark(button)
	local mark = marks[button]
	if mark then
		return mark
	end
	mark = CreateFrame("Frame", nil, button)
	mark:SetWidth(SIZE)
	mark:SetHeight(SIZE)
	mark:SetPoint("BOTTOM", button, "BOTTOM", 0, -BELOW)
	mark.art = mark:CreateTexture(nil, "OVERLAY")
	mark.art:SetAllPoints(mark)
	mark.art:SetTexture(ART.."FloorHourglass")
	mark:EnableMouse(true)
	mark:SetScript("OnEnter", Tip)
	mark:SetScript("OnLeave", Untip)
	mark:SetScript("OnHide", Untip)
	mark:Hide()
	marks[button] = mark
	return mark
end

-- Over the button's cooldown sweep and its numbers (Cooldowns.lua), each a
-- frame of its own, the numbers' made at the first cooldown.
local function Lift(mark, button)
	local level = button:GetFrameLevel() + 4
	local counter = button.suicCounter
	if counter and counter:GetFrameLevel() >= level then
		level = counter:GetFrameLevel() + 1
	end
	if mark:GetFrameLevel() ~= level then
		mark:SetFrameLevel(level)
	end
end

local frame = CreateFrame("Frame")
local wait = 0
frame:SetScript("OnUpdate", function()
	wait = wait + arg1
	if wait < 0.25 then
		return
	end
	wait = 0
	local lit = {}
	local spells = AZS_SPELLS
	if spells and SUIC.DB().floorHourglass and SUIC.InRun() then
		local count = table.getn(spells)
		for index = 1, count do
			local entry = spells[index] or {}
			local _, floor = SUIC.TrueCooldown(entry.key, entry.cdmax)
			local slot = index
			if index == count then
				slot = RACIAL_SLOT
			end
			local button = floor and getglobal("ActionButton"..slot)
			if button and button:IsVisible() then
				local mark = Mark(button)
				mark.key, mark.floor, mark.slot = entry.key, floor, slot
				Lift(mark, button)
				mark:Show()
				lit[mark] = true
			end
		end
	end
	for _, mark in pairs(marks) do
		if not lit[mark] then
			mark:Hide()
		end
	end
end)

-- The option, at the next look.
function SUIC.RefreshFloorHourglass()
	wait = 1
end
