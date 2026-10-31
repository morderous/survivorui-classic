-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: your summons and totems, as the game's buffs, in a row
-- over the action bar's right half, from its right edge in: a kind an icon, how many are out over it
-- ("3/5" where the game keeps a limit, a totem's cap or a greater demon's),
-- the time the first of them goes under it, as a buff's duration. One that
-- stays the whole run shows its icon alone. Hover an icon for its name.
--
-- From the game's addon API (AZS_GetSummonGroups, AZS_GetTotems).

local SIZE = 26
local GAP = 5
local MOST = 12
local COUNT = 11                -- the count's line over the icons
-- How many of a kind the game lets out at once (its 0.110; Survivor UI's).
local LIMITS = { infernal = 1, doomguard = 1, felguard = 2, pit_lord = 2, water_elemental = 1, treant = 2, spirit_wolf = 2 }

local holder = CreateFrame("Frame", "SUICSummons", UIParent)
holder:SetWidth(4 * (SIZE + GAP))
holder:SetHeight(COUNT + SIZE + 14)

local function Home(f)
	f:SetPoint("BOTTOMRIGHT", MainMenuBar, "TOPRIGHT", -4, 6)
end

local function IconOf(icon)
	if not icon or icon == "" then
		return "Interface\\Icons\\INV_Misc_QuestionMark"
	elseif string.find(icon, "\\", 1, true) then
		return icon
	end
	return "Interface\\Icons\\"..icon
end

local function SlotEnter()
	if not this.name then
		return
	end
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:SetText(this.name)
	if this.out then
		GameTooltip:AddLine(this.out.." out"..(this.limit and (" of "..this.limit) or ""), 1, 1, 1)
	end
	if this.left then
		GameTooltip:AddLine("The first goes in "..SUIC.Clock(this.left), 0.8, 0.8, 0.8)
	end
	GameTooltip:Show()
end

local slots = {}
for index = 1, MOST do
	local slot = CreateFrame("Frame", nil, holder)
	slot:SetWidth(SIZE)
	slot:SetHeight(SIZE)
	slot:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -(index - 1) * (SIZE + GAP), -COUNT)
	slot:EnableMouse(true)
	slot:SetScript("OnEnter", SlotEnter)
	slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
	slot.icon = slot:CreateTexture(nil, "ARTWORK")
	slot.icon:SetAllPoints(slot)
	-- The count over the icon, outlined, clear of its art.
	slot.number = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	local font = slot.number:GetFont()
	slot.number:SetFont(font or STANDARD_TEXT_FONT, 9, "OUTLINE")
	slot.number:SetPoint("BOTTOM", slot, "TOP", 0, 1)
	slot.time = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	slot.time:SetPoint("TOP", slot, "BOTTOM", 0, -1)
	slot:Hide()
	slots[index] = slot
end

local function Fill(index, name, icon, count, limit, left)
	local slot = slots[index]
	slot.name, slot.out, slot.limit, slot.left = name, count, limit, left
	slot.icon:SetTexture(IconOf(icon))
	if limit then
		slot.number:SetText(count.."/"..limit)
	elseif count and count > 1 then
		slot.number:SetText(count)
	else
		slot.number:SetText("")
	end
	slot.time:SetText(left and SUIC.Clock(left) or "")
	slot:Show()
end

local function Draw()
	local shown = 0
	if SUIC.InRun() then
		local groups = AZS_GetSummonGroups and AZS_GetSummonGroups() or {}
		for index = 1, table.getn(groups) do
			local group = groups[index]
			if shown < MOST then
				shown = shown + 1
				local temporary = (tonumber(group.temporary) or 0) > 0
				Fill(shown, group.name, group.icon, tonumber(group.count) or 1,
					temporary and LIMITS[group.key] or nil, temporary and group.remaining or nil)
			end
		end
		local totems = AZS_GetTotems and AZS_GetTotems() or {}
		for index = 1, table.getn(totems) do
			local totem = totems[index]
			local count = tonumber(totem.count) or 0
			if count > 0 and shown < MOST then
				shown = shown + 1
				Fill(shown, totem.name, totem.icon, count, tonumber(totem.cap), totem.remaining)
			end
		end
	end
	for index = shown + 1, MOST do
		slots[index]:Hide()
	end
	holder:SetWidth(math.max(1, shown) * (SIZE + GAP))
end

local elapsed = 0
holder:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.1 then
		return
	end
	elapsed = 0
	Draw()
end)
holder:Hide()

function SUIC.RefreshSummons()
	if SUIC.DB().summons then
		holder:Show()
	else
		holder:Hide()
	end
end

SUIC.OnStart(function()
	Home(holder)
	SUIC.AddPiece("summons", "Summons and totems", holder, Home, nil, "RIGHT")
	SUIC.RefreshSummons()
end)
