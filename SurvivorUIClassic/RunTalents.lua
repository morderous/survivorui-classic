-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: a run's talents, drawn for Run History's Build page as
-- small trees (Lucas, 2026-11-15): the class's three trees side by side
-- (TalentTrees.lua), each talent in its tier and column, the ones the hero
-- had lit with their rank, the rest dim. Over each tree, its name and its
-- points. A talent no tree has (the game renamed it since) goes in a row at
-- the heading's right. A class with no trees here, or a run whose talents'
-- names the trees do not know (another language's), gets a line a tree, its
-- talents in a row.
--
-- Its own file: RunHistory.lua is near the 200 locals a file may have in the
-- game's Lua.

local SIZE, STEP = 15, 16
local TREE_ROW = 33
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

local function Icon(file)
	if not file or file == "" then
		return QUESTION
	end
	if string.find(file, "\\", 1, true) then
		return file
	end
	return "Interface\\Icons\\"..file
end

-- The talents kept with a run, "0;Concussion;5;Spell_Fire_Fireball|...": the
-- tree, the name, the rank, the icon's file.
local function Kept(run)
	local list = {}
	for entry in string.gfind(run.talents or "", "[^|]+") do
		local _, _, tree, name, rank, icon = string.find(entry, "^(%d+);(.-);(%d+);(.*)$")
		if tree then
			table.insert(list, { tree = tonumber(tree) + 1, name = name, rank = tonumber(rank), icon = icon })
		end
	end
	return list
end

-- The drawer of a page's talents: Draw(run, top) draws them from top down and
-- says how many the run had.
function SUIC.RunTalents(parent, width)
	local spots, labels = {}, {}
	local across = math.floor(width / 3)

	local function Spot(index)
		local spot = spots[index]
		if not spot then
			spot = CreateFrame("Button", nil, parent)
			spot:SetWidth(SIZE)
			spot:SetHeight(SIZE)
			spot.icon = spot:CreateTexture(nil, "ARTWORK")
			spot.icon:SetAllPoints(spot)
			spot.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			spot.rank = spot:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
			local font = spot.rank:GetFont()
			spot.rank:SetFont(font or STANDARD_TEXT_FONT, 9, "OUTLINE")
			spot.rank:SetPoint("BOTTOMRIGHT", spot, "BOTTOMRIGHT", 2, -2)
			spot:SetScript("OnEnter", function()
				GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
				GameTooltip:SetText(this.words or "?", 1, 1, 1)
				GameTooltip:AddLine(SUIC.TF("Rank {1}", this.ranks or 0), 1, 0.82, 0)
				GameTooltip:Show()
			end)
			spot:SetScript("OnLeave", function() GameTooltip:Hide() end)
			spots[index] = spot
		end
		return spot
	end

	-- A talent's spot painted: lit with its rank, or dim with none.
	local function Paint(index, name, rank, top, icon, x, y)
		local spot = Spot(index)
		spot.words = SUIC.Native and SUIC.Native(name) or name
		spot.ranks = (rank or 0)..(top and ("/"..top) or "")
		spot.icon:SetTexture((icon and icon ~= "") and Icon(icon) or Icon(SUIC_TALENT_ICONS and SUIC_TALENT_ICONS[name]))
		if rank then
			spot.icon:SetVertexColor(1, 1, 1)
			spot.icon:SetAlpha(1)
			-- At its top rank in gold, as the game's own trees.
			spot.rank:SetText((top and rank >= top) and ("|cffffd100"..rank.."|r") or ("|cff40ff40"..rank.."|r"))
		else
			spot.icon:SetVertexColor(0.45, 0.45, 0.45)
			spot.icon:SetAlpha(0.45)
			spot.rank:SetText("")
		end
		spot:ClearAllPoints()
		spot:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
		spot:Show()
	end

	local function Label(index, words, x, y)
		local label = labels[index]
		if not label then
			label = SUIC.Text(parent, "GameFontHighlightSmall")
			label:SetJustifyH("LEFT")
			labels[index] = label
		end
		label:ClearAllPoints()
		label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
		label:SetText(words)
	end

	return function(run, top)
		local kept = Kept(run)
		local count = table.getn(kept)
		local trees = SUIC_TALENT_TREES and SUIC_TALENT_TREES[run.classKey or ""]
		local had, known = {}, 0
		for index = 1, count do
			had[kept[index].name] = kept[index]
		end
		if trees then
			for index = 1, table.getn(trees) do
				for each = 1, table.getn(trees[index]) do
					if had[trees[index][each][1]] then
						known = known + 1
					end
				end
			end
		end
		local used = 0
		for index = 1, 3 do
			Label(index, "", 0, top)
		end
		if count == 0 then
			-- Nothing kept: nothing drawn, the page says so.
		elseif trees and known * 2 >= count then
			for index = 1, table.getn(trees) do
				local tree = trees[index]
				local left = (index - 1) * across
				local points = 0
				for each = 1, table.getn(tree) do
					local talent = tree[each]
					local one = had[talent[1]]
					used = used + 1
					Paint(used, talent[1], one and one.rank, talent[4], one and one.icon,
						left + talent[3] * STEP, top - 14 - talent[2] * STEP)
					points = points + (one and one.rank or 0)
					had[talent[1]] = nil
				end
				local name = SUIC.Native and SUIC.Native(tree.name) or tree.name
				Label(index, "|cffffd100"..tostring(name).."|r  "..points, left, top)
			end
			-- What no tree has, in a row from the page's right, on the heading's line.
			local extra = 0
			for index = 1, count do
				local one = kept[index]
				if had[one.name] then
					used = used + 1
					extra = extra + 1
					Paint(used, one.name, one.rank, nil, one.icon, width - extra * STEP, top + 15)
				end
			end
		else
			local points, places = { 0, 0, 0 }, { 0, 0, 0 }
			for index = 1, count do
				local one = kept[index]
				if points[one.tree] then
					used = used + 1
					Paint(used, one.name, one.rank, nil, one.icon,
						places[one.tree] * (SIZE + 2), top - 13 - (one.tree - 1) * TREE_ROW)
					points[one.tree] = points[one.tree] + one.rank
					places[one.tree] = places[one.tree] + 1
				end
			end
			for index = 1, 3 do
				local name = run.trees and run.trees[index]
				Label(index, "|cffffd100"..tostring(name or SUIC.TF("Tree {1}", index)).."|r  "..SUIC.TF("{1} points", points[index]),
					0, top - (index - 1) * TREE_ROW)
			end
		end
		for index = used + 1, table.getn(spots) do
			spots[index]:Hide()
		end
		return count
	end
end
