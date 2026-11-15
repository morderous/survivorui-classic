-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: what stands round the Build panel (BarPanel.lua; Lucas,
-- 2026-11-14), the three pieces that stood loose over the action bar. At the
-- panel's left the talents' clocks, at its right the summons and totems:
-- icons alone, in columns filled from the bottom up, a column more at the
-- right of the last where one is full (the talents' columns end at the
-- panel, the summons' start at it). The Level Up! button, which stood far up
-- the screen, on the panel's top, in its middle.
--
-- Each is still its own piece (TalentTimers.lua, Summons.lua, LevelUp.lua,
-- which lay their own icons: SUIC.SIDE_ROWS to a column), with its option,
-- its size and its box in Move frames: a piece moved there stays where it was
-- put. With the panel off, the three stand where they did before it.

SUIC.SIDE_ROWS = 3        -- icons to a column: the panel's height
local BESIDE = 6          -- from the panel's side to the icons
local FOOT = 2            -- the columns' feet over the panel's bottom
local OVER = 6            -- the Level Up! button over the panel's top
local KEYS = {
	talents = { frame = "SUICTalentTimers", piece = "talentTimers" },
	summons = { frame = "SUICSummons", piece = "summons" },
	levelup = { frame = "SUICLevelUp", piece = "levelup" },
}

local function On()
	return SUIC.BarPanelUp and SUIC.BarPanelUp() or false
end

-- The icons in columns (the pieces ask as they draw): the panel up.
function SUIC.SideColumns()
	return On()
end

-- A piece's place round the panel (its Home asks); false with the panel off,
-- and the piece stands where it did before.
function SUIC.ShelfSeat(frame, key)
	if not On() then
		return false
	end
	if key == "talents" then
		frame:SetPoint("BOTTOMRIGHT", MainMenuBar, "BOTTOMLEFT", -BESIDE, FOOT)
	elseif key == "summons" then
		frame:SetPoint("BOTTOMLEFT", MainMenuBar, "BOTTOMRIGHT", BESIDE, FOOT)
	else
		frame:SetPoint("BOTTOM", MainMenuBar, "TOP", 0, OVER)
	end
	return true
end

-- The panel up or down (BarPanel.lua tells): the three seated again, those
-- not moved in Move frames.
function SUIC.RefreshShelf()
	local places = SUIC.DB().pos or {}
	for key, spot in pairs(KEYS) do
		local frame = getglobal(spot.frame)
		if frame and not places[spot.piece] then
			frame:ClearAllPoints()
			if not SUIC.ShelfSeat(frame, key) and frame.suicHome then
				frame.suicHome(frame)
			end
		end
	end
end
