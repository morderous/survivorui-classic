-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: each spell's biggest crit this run, read off the combat
-- log, which the game writes in English whatever its language ("Your
-- Lightning Bolt crits Kobold Vermin for 168.", "Magma Totem's Magma Totem
-- crits...", "Searing Totem's Attack crits..."): kept by the spell's key as
-- the game's list names it, a totem's by its totem's when that is the build's.
-- A new run starts over. The build list shows them (BuildList.lua).

local best = {}
local runSeen

local EVENTS = {
	"CHAT_MSG_SPELL_SELF_DAMAGE", "CHAT_MSG_COMBAT_SELF_HITS",
	"CHAT_MSG_SPELL_PET_DAMAGE", "CHAT_MSG_COMBAT_PET_HITS",
}

local function InBuild(name)
	return name and SUIC.SpellSlot(name) ~= nil
end

local function Note(message)
	if not string.find(message, " crit", 1, true) then
		return
	end
	local _, _, ability, _, amount = string.find(message, "^Your (.+) crits (.+) for (%d+)")
	if not ability then
		local owner, spell
		_, _, owner, spell, _, amount = string.find(message, "^(.+)'s (.+) crits (.+) for (%d+)")
		if owner then
			ability = (not InBuild(spell) and InBuild(owner)) and owner or spell
		end
	end
	if not ability then
		_, _, _, amount = string.find(message, "^You crit (.+) for (%d+)")
		ability = amount and "Melee" or nil
	end
	amount = tonumber(amount)
	if ability and amount then
		local key = SUIC.KeyOf(ability)
		if not best[key] or amount > best[key] then
			best[key] = amount
		end
	end
end

-- The biggest crit this run of a spell by its key, or nil.
function SUIC.BiggestCrit(key)
	if AZS_ZONE_UPDATED ~= runSeen then
		runSeen = AZS_ZONE_UPDATED
		best = {}
	end
	return best[key]
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function()
	if arg1 then
		SUIC.BiggestCrit("")
		Note(arg1)
	end
end)

SUIC.OnStart(function()
	for index = 1, table.getn(EVENTS) do
		events:RegisterEvent(EVENTS[index])
	end
end)
