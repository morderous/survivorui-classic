-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the tooltip's place. The tooltip of what is under the
-- mouse (an enemy, a frame) grows from the bottom right corner of a "Tooltip"
-- box: first just left of the column under the minimap, over the chat's
-- height; in Move frames, wherever it is let go. Tooltips the game puts
-- beside their button (the action bar's) stay beside it.

local anchor = CreateFrame("Frame", "SUICTooltipAnchor", UIParent)
anchor:SetWidth(180)
anchor:SetHeight(70)

local function Home(f)
	f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -236, 145)
end
Home(anchor)

if GameTooltip_SetDefaultAnchor then
	local stock = GameTooltip_SetDefaultAnchor
	GameTooltip_SetDefaultAnchor = function(tooltip, parent)
		stock(tooltip, parent)
		if SUIC.active then
			tooltip:ClearAllPoints()
			tooltip:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
		end
	end
end

SUIC.OnStart(function()
	SUIC.AddPiece("tooltip", "Tooltip", anchor, Home)
end)
