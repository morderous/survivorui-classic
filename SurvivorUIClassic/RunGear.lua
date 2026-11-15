-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the armor and the weapons a run was played in, for Run
-- History (Lucas, 2026-11-15: "the whole equipment, with the set bonuses that
-- were on"). They stay as they are through a run, so they are read at its
-- end: a piece a slot worn, in the character pane's order, and the set they
-- make with its bonuses that were on, as a piece's tooltip says them:
--
--   Redemption (8/8)            the set's line: its name, how many are worn
--     Redemption Helm ...       its pieces
--   Set: +30% critical damage   a bonus that is on, in green
--   (8) Set: ...                one that is not, in grey
--
-- Its own file: RunHistory.lua is near the 200 locals a file may have in the
-- game's Lua.

local ARMOR_SLOTS = { 1, 3, 15, 5, 9, 10, 6, 7, 8, 16, 17, 18 }
local ICON, STEP = 20, 23
local scan = CreateFrame("GameTooltip", "SUICRunGearTip", nil, "GameTooltipTemplate")

-- The set a piece's tooltip tells of: { name, count, of, bonuses }, or nil.
local function SetOf(slot)
	scan:SetOwner(WorldFrame, "ANCHOR_NONE")
	scan:ClearLines()
	scan:SetInventoryItem("player", slot)
	local set
	for index = 2, scan:NumLines() do
		local line = getglobal("SUICRunGearTipTextLeft"..index)
		local words = line and line:GetText() or ""
		if not set then
			local _, _, name, count, of = string.find(words, "^(.-) ?%((%d+)/(%d+)%)$")
			if name and name ~= "" then
				set = { name = name, count = tonumber(count), of = tonumber(of), bonuses = {} }
			end
		elseif words ~= "" then
			-- Under the set's line, a green line is a bonus that is on.
			local r, g, b = line:GetTextColor()
			if r < 0.4 and g > 0.8 and b < 0.4 then
				table.insert(set.bonuses, words)
			end
		end
	end
	scan:Hide()
	return set
end

-- A worn piece's tooltip as it reads at the run's end, kept with the run: the
-- game's items change (an upgrade's stars, a patch's numbers), and a run's
-- should read as it was played (Lucas, 2026-11-15). A line a line, its color
-- before it as "rrggbb", its right half after a tab.
-- how: nil a worn piece's slot, "action" a spell's button, "link" an item's
-- link (a drop's).
function SUIC.RunTipOf(slot, how)
	scan:SetOwner(WorldFrame, "ANCHOR_NONE")
	scan:ClearLines()
	if how == "action" then
		scan:SetAction(slot)
	elseif how == "link" then
		scan:SetHyperlink(slot)
	else
		scan:SetInventoryItem("player", slot)
	end
	local lines = {}
	for index = 1, scan:NumLines() do
		local left = getglobal("SUICRunGearTipTextLeft"..index)
		local right = getglobal("SUICRunGearTipTextRight"..index)
		if left then
			local words = string.gsub(left:GetText() or "", "[\n\t]", " ")
			local other = right and right:GetText()
			local r, g, b = left:GetTextColor()
			table.insert(lines, string.format("%02x%02x%02x", r * 255, g * 255, b * 255)..words
				..((other and other ~= "") and ("\t"..string.gsub(other, "[\n\t]", " ")) or ""))
		end
	end
	scan:Hide()
	return table.getn(lines) > 0 and table.concat(lines, "\n") or nil
end

-- A tooltip under the mouse: the one kept with the run, else the item's as
-- the game has it now, else a title alone; under it the run's own numbers of
-- the thing, { name, number } each.
function SUIC.RunShowTip(owner, tip, item, title, numbers)
	if not (tip or item or title) then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	if tip then
		local first = true
		for line in string.gfind(tip, "[^\n]+") do
			local _, _, rr, gg, bb, words = string.find(line, "^(%x%x)(%x%x)(%x%x)(.*)$")
			if rr then
				local r, g, b = tonumber(rr, 16) / 255, tonumber(gg, 16) / 255, tonumber(bb, 16) / 255
				local _, _, left, right = string.find(words, "^(.-)\t(.*)$")
				if right then
					GameTooltip:AddDoubleLine(left, right, r, g, b, r, g, b)
				else
					GameTooltip:AddLine(words ~= "" and words or " ", r, g, b, (not first) and 1 or nil)
				end
				first = false
			end
		end
	elseif item then
		GameTooltip:SetHyperlink(item)
	else
		GameTooltip:SetText(title, 1, 1, 1)
	end
	if numbers and table.getn(numbers) > 0 then
		if tip or item then
			GameTooltip:AddLine(" ")
		end
		for index = 1, table.getn(numbers) do
			GameTooltip:AddDoubleLine(numbers[index][1], numbers[index][2], 1, 0.82, 0, 1, 1, 1)
		end
	end
	GameTooltip:Show()
end

-- The pieces worn, { slot, link, icon, tip } each, and the set they make.
function SUIC.RunGearSnapshot()
	local armor, set = {}, nil
	if not GetInventoryItemLink then
		return armor, nil
	end
	for index = 1, table.getn(ARMOR_SLOTS) do
		local slot = ARMOR_SLOTS[index]
		local link = GetInventoryItemLink("player", slot)
		if link then
			local kept, tip = pcall(SUIC.RunTipOf, slot)
			table.insert(armor, { slot = slot, link = link, icon = GetInventoryItemTexture("player", slot),
				tip = kept and tip or nil })
			if slot < 16 then
				local ok, found = pcall(SetOf, slot)
				if ok and found and not (set and set.count >= found.count) then
					set = found
				end
			end
		end
	end
	return armor, set
end

-- A name in the room it has, its last word always whole (a jewel's rank, as
-- "Ring of X VII"): the words between the first and the last cut to a letter
-- and a dot, one by one, then the first too.
local measure = SUIC.Text(UIParent, "GameFontHighlightSmall")
measure:Hide()

function SUIC.RunFitName(name, room)
	local function Fits(words)
		measure:SetText(words)
		return measure:GetStringWidth() <= room
	end
	if Fits(name) then
		return name
	end
	local parts = {}
	for word in string.gfind(name, "%S+") do
		table.insert(parts, word)
	end
	local count = table.getn(parts)
	local said = name
	for pass = 1, 2 do
		for index = pass == 1 and 2 or 1, pass == 1 and count - 1 or 1 do
			-- A word's first letter, whole where it is of more than a byte.
			local _, _, letter = string.find(parts[index], "^([%z\1-\127\194-\244][\128-\191]*)")
			if letter and string.len(parts[index]) > string.len(letter) + 1 then
				parts[index] = letter.."."
				said = table.concat(parts, " ")
				if Fits(said) then
					return said
				end
			end
		end
	end
	return said
end

-- The drawer of a page's equipment: Draw(run, top) draws it from top down and
-- says where it ends.
function SUIC.RunGear(parent, width)
	local heading = SUIC.Text(parent, "GameFontNormalSmall")
	local setName = SUIC.Text(parent, "GameFontHighlightSmall")
	setName:SetPoint("LEFT", heading, "RIGHT", 10, 0)
	local bonuses = SUIC.Text(parent, "GameFontHighlightSmall")
	bonuses:SetWidth(width)
	bonuses:SetJustifyH("LEFT")
	bonuses:SetJustifyV("TOP")
	local icons = {}

	local function Piece(index)
		local piece = icons[index]
		if not piece then
			piece = CreateFrame("Button", nil, parent)
			piece:SetWidth(ICON)
			piece:SetHeight(ICON)
			-- The piece's quality round its icon.
			piece.edge = piece:CreateTexture(nil, "BACKGROUND")
			piece.edge:SetTexture(SUIC.FLAT)
			piece.edge:SetPoint("TOPLEFT", piece, "TOPLEFT", -1, 1)
			piece.edge:SetPoint("BOTTOMRIGHT", piece, "BOTTOMRIGHT", 1, -1)
			piece.icon = piece:CreateTexture(nil, "ARTWORK")
			piece.icon:SetAllPoints(piece)
			piece.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			piece:SetScript("OnEnter", function() SUIC.RunShowTip(this, this.tip, this.item) end)
			piece:SetScript("OnLeave", function() GameTooltip:Hide() end)
			icons[index] = piece
		end
		return piece
	end

	return function(run, top)
		local armor = run.armor or {}
		local count = table.getn(armor)
		heading:ClearAllPoints()
		heading:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, top)
		heading:SetText(SUIC.T("Equipment"))
		for index = 1, count do
			local one = armor[index]
			local piece = Piece(index)
			local _, _, rr, gg, bb = string.find(one.link or "", "|c%x%x(%x%x)(%x%x)(%x%x)")
			local _, _, item = string.find(one.link or "", "(item:[%d:%-]+)")
			piece.item, piece.tip = item, one.tip
			piece.icon:SetTexture(one.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
			piece.edge:SetVertexColor((tonumber(rr or "ff", 16) or 255) / 255, (tonumber(gg or "ff", 16) or 255) / 255,
				(tonumber(bb or "ff", 16) or 255) / 255, 0.9)
			piece:ClearAllPoints()
			piece:SetPoint("TOPLEFT", parent, "TOPLEFT", 1 + (index - 1) * STEP, top - 17)
			piece:Show()
		end
		for index = count + 1, table.getn(icons) do
			icons[index]:Hide()
		end
		local set = run.set
		if count == 0 then
			setName:SetText("|cff808080"..SUIC.T("None kept with this run.").."|r")
		elseif set and set.name then
			setName:SetText(tostring(set.name).."  |cffffd100"..tostring(set.count or 0).."/"..tostring(set.of or 8).."|r")
		else
			setName:SetText("")
		end
		bonuses:ClearAllPoints()
		bonuses:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, top - 17 - ICON - 6)
		local lines = set and set.bonuses or {}
		if count == 0 then
			bonuses:SetText("")
			return top - 12
		elseif table.getn(lines) > 0 then
			bonuses:SetText("|cff1eff00"..table.concat(lines, "\n").."|r")
		else
			bonuses:SetText("|cff808080"..SUIC.T("No set bonus was on.").."|r")
		end
		-- Its words' height, wrapped; a line's at the least.
		local tall = bonuses:GetHeight() or 0
		return top - 17 - ICON - 6 - math.max(11, tall)
	end
end
