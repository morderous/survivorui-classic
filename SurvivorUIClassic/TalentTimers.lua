-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the talents' clocks, a row of icons over the action
-- bar's left half, from its left edge in, the summons and totems at its right: a second life's wait (Divine Intervention, Cheat Death), a
-- heal's, a proc's, and a summoning talent's next demon or wave. Waiting, an
-- icon is darkened under its count, as an action button cooling down (tenths
-- under ten seconds); ready, it is bright, a gold light breathing in it. The
-- summons' size, its icons in line with theirs. Hover one for its
-- name. A wait under five seconds (a proc's limit) is left out.
--
-- From the game's addon API (AZS_GetTimers, its 0.115).

local SIZE = 26
local GAP = 5
local MOST = 10
local SHORTEST = 5

local holder = CreateFrame("Frame", "SUICTalentTimers", UIParent)
holder:SetWidth(SIZE)
holder:SetHeight(SIZE + 14)

local function Home(f)
	f:SetPoint("BOTTOMLEFT", MainMenuBar, "TOPLEFT", 4, 6)
end

local function IconOf(icon)
	if not icon or icon == "" then
		return "Interface\\Icons\\INV_Misc_QuestionMark"
	elseif string.find(icon, "\\", 1, true) then
		return icon
	end
	return "Interface\\Icons\\"..icon
end

local function TimeText(seconds)
	if seconds >= 60 then
		return math.floor(seconds / 60 + 0.5).."m"
	elseif seconds >= 10 then
		return tostring(math.floor(seconds))
	end
	return string.format("%.1f", math.max(0.1, seconds))
end

local function SlotEnter()
	if not this.name then
		return
	end
	GameTooltip:SetOwner(this, "ANCHOR_TOP")
	GameTooltip:SetText(this.name)
	if this.left and this.left > 0 then
		GameTooltip:AddLine((this.summon and "Next in " or "Ready in ")..SUIC.Clock(this.left), 1, 1, 1)
	else
		GameTooltip:AddLine("Ready", 0.3, 1, 0.3)
	end
	GameTooltip:Show()
end

local slots = {}
for index = 1, MOST do
	local slot = CreateFrame("Frame", nil, holder)
	slot:SetWidth(SIZE)
	slot:SetHeight(SIZE)
	slot:SetPoint("TOPLEFT", holder, "TOPLEFT", (index - 1) * (SIZE + GAP), 0)
	slot:EnableMouse(true)
	slot:SetScript("OnEnter", SlotEnter)
	slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
	slot.icon = slot:CreateTexture(nil, "ARTWORK")
	slot.icon:SetAllPoints(slot)
	slot.dim = slot:CreateTexture(nil, "OVERLAY")
	slot.dim:SetTexture(SUIC.FLAT)
	slot.dim:SetVertexColor(0, 0, 0, 0.6)
	slot.dim:SetAllPoints(slot)
	-- The action button's border, glowing gold while ready.
	slot.glow = slot:CreateTexture(nil, "OVERLAY")
	slot.glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
	slot.glow:SetBlendMode("ADD")
	slot.glow:SetVertexColor(1, 0.82, 0.2)
	slot.glow:SetAllPoints(slot)
	local over = CreateFrame("Frame", nil, slot)
	over:SetAllPoints(slot)
	over:SetFrameLevel(slot:GetFrameLevel() + 2)
	slot.time = over:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	local font = slot.time:GetFont()
	slot.time:SetFont(font or STANDARD_TEXT_FONT, 14, "OUTLINE")
	slot.time:SetPoint("CENTER", slot, "CENTER", 0, 0)
	slot.time:SetTextColor(1, 0.86, 0.1)
	slot:Hide()
	slots[index] = slot
end

local function Draw()
	local shown = 0
	if SUIC.InRun() then
		local timers = AZS_GetTimers and AZS_GetTimers() or {}
		for index = 1, table.getn(timers) do
			local timer = timers[index]
			local summon = timer.kind == "summon"
			if shown < MOST and (summon or (tonumber(timer.duration) or 0) >= SHORTEST) then
				shown = shown + 1
				local slot = slots[shown]
				local left = tonumber(timer.remaining) or 0
				slot.name, slot.left, slot.summon = timer.name, left, summon
				slot.icon:SetTexture(IconOf(timer.icon))
				if left > 0 and not timer.ready then
					slot.dim:Show()
					slot.glow:Hide()
					slot.time:SetText(TimeText(left))
					if left <= 2 then
						slot.time:SetTextColor(1, 0.2, 0.15)
					else
						slot.time:SetTextColor(1, 0.86, 0.1)
					end
				else
					slot.dim:Hide()
					slot.glow:Show()
					slot.glow:SetAlpha(0.55 + 0.45 * math.sin(GetTime() * 4))
					slot.time:SetText("")
				end
				slot:Show()
			end
		end
	end
	for index = shown + 1, MOST do
		slots[index]:Hide()
	end
	-- As wide as its icons, held by its left edge: it grows inward.
	holder:SetWidth(math.max(1, shown) * (SIZE + GAP) - GAP)
end

local elapsed = 0
holder:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.05 then
		return
	end
	elapsed = 0
	Draw()
end)
holder:Hide()

function SUIC.RefreshTalentTimers()
	if SUIC.DB().talentTimers then
		holder:Show()
	else
		holder:Hide()
	end
end

SUIC.OnStart(function()
	Home(holder)
	SUIC.AddPiece("talentTimers", "Talent cooldowns", holder, Home, nil, "LEFT")
	SUIC.RefreshTalentTimers()
end)
