-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: a damage source's icon, by its name as the meter and
-- the combat log write it (Survivor UI's Meter.lua, the same search): a
-- swing the weapon in hand, a shot the ranged one; a pet its own ("Imp",
-- "Felguard"), a pet's spell its spell's ("Imp's Fireball"); a spell of the
-- build its action button's; a summon out its own; then the game's talents,
-- the spellbook, the client's talents and the worn items. Found icons are
-- kept; a miss is asked again after a while, as talents and items come.

local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

local PETS = {
	["Imp"] = "Spell_Shadow_SummonImp",
	["Succubus"] = "Spell_Shadow_SummonSuccubus",
	["Voidwalker"] = "Spell_Shadow_SummonVoidWalker",
	["Felhunter"] = "Spell_Shadow_SummonFelHunter",
	["Felguard"] = "Spell_Shadow_Metamorphosis",
	["Infernal"] = "Spell_Shadow_SummonInfernal",
	["Doomguard"] = "Spell_Shadow_AntiMagicShell",
	["Pit Lord"] = "Spell_Shadow_RitualOfSacrifice",
	["Felseeker"] = "Spell_Fire_SoulBurn",
	["Water Elemental"] = "Spell_Frost_SummonWaterElemental",
	["Spirit Wolf"] = "Spell_Nature_SpiritWolf",
	["Treant"] = "Spell_Nature_ForceOfNature",
	["Wolf"] = "Ability_Hunter_Pet_Wolf",
	["Raptor"] = "Ability_Hunter_Pet_Raptor",
	["Pets"] = "Ability_Hunter_BeastCall",        -- the game's meter's one line for a hunter's beasts
}

-- What pets cast that the hero may not have.
local PET_SPELLS = {
	["Fireball"] = "Spell_Fire_FlameBolt",
	["Firebolt"] = "Spell_Fire_FireBolt",
	["Inferno"] = "Spell_Fire_Fireball02",
}

-- A burst under a name of its own: the icon of the spell it comes from.
local BORROWED = {
	["Corpse Explosion"] = { "Seed of Corruption", "Shadowform" },
	["Noxious Cloud"] = { "Toxic Bloom" },
}

local MELEE = { ["Melee"] = true, ["Attack"] = true, ["Auto Attack"] = true }
local RANGED = { ["Auto Shot"] = true, ["Shoot"] = true, ["Shot"] = true, ["Auto Shoot"] = true }

local SPELL_KEYS = {
	["shadow word: pain"] = "sw_pain", ["power word: shield"] = "pw_shield",
	["demoralizing shout"] = "demo_shout", ["hunter's mark"] = "hunters_mark", ["rockbiter weapon"] = "rockbiter",
	["soulfire"] = "soul_fire",
}

-- A spell's key as the game's list names it: "holy_wrath" for "Holy Wrath".
function SUIC.KeyOf(name)
	local lower = string.lower(name or "")
	if SPELL_KEYS[lower] then
		return SPELL_KEYS[lower]
	end
	return (string.gsub(string.gsub(lower, "[^%a ]", ""), " ", "_"))
end

-- The build spell's place in the game's list (by its key, else its letters
-- alone: a button's tooltip calls soul_fire "Soulfire"), and its button.
function SUIC.SpellSlot(name)
	local spells = AZS_SPELLS or {}
	local count = table.getn(spells)
	local key = SUIC.KeyOf(name)
	local letters = string.gsub(key, "[^%a]", "")
	for index = 1, count do
		local own = tostring(spells[index].key or "")
		if own == key or string.gsub(own, "[^%a]", "") == letters then
			return index, (index == count) and 12 or index
		end
	end
end

local function Icon(name)
	return name and ("Interface\\Icons\\"..name) or nil
end

local function FromSummons(name)
	local summons = AZS_GetSummons and AZS_GetSummons() or {}
	for index = 1, table.getn(summons) do
		local summon = summons[index]
		if summon.name == name and summon.icon then
			return summon.icon
		end
	end
end

local function FromSpellbook(name)
	if not (GetNumSpellTabs and GetSpellTabInfo and GetSpellName and GetSpellTexture) then
		return nil
	end
	for tab = 1, GetNumSpellTabs() do
		local _, _, offset, count = GetSpellTabInfo(tab)
		for index = (offset or 0) + 1, (offset or 0) + (count or 0) do
			if GetSpellName(index, "spell") == name then
				return GetSpellTexture(index, "spell")
			end
		end
	end
end

local function FromTalents(name)
	if not (GetNumTalentTabs and GetNumTalents and GetTalentInfo) then
		return nil
	end
	for tab = 1, GetNumTalentTabs() do
		for index = 1, GetNumTalents(tab) do
			local talent, texture = GetTalentInfo(tab, index)
			if talent == name then
				return texture
			end
		end
	end
end

-- A worn piece whose name the source's starts with, or is.
local function FromItems(name)
	local lower = string.lower(name)
	for slot = 1, 19 do
		local link = GetInventoryItemLink("player", slot)
		local _, _, item = string.find(link or "", "%[(.-)%]")
		if item and item ~= "" then
			local itemLower = string.lower(item)
			if lower == itemLower or string.find(lower, itemLower, 1, true) == 1 or string.find(itemLower, lower, 1, true) then
				return GetInventoryItemTexture("player", slot)
			end
		end
	end
end

local known, missedAt = {}, {}

-- The run's sources as the game's meter has them (its 0.132), in the game's
-- language: by key and by name. Read again now and then, as a card brings more.
local sources = { byKey = {}, byName = {} }
local sourcesAt = 0

local function Sources()
	local now = GetTime()
	if now - sourcesAt >= 5 and AZS_GetMeterContext and AZS_GetMeterLoadout then
		sourcesAt = now
		local context = AZS_GetMeterContext()
		local loadout = context and context.runId
			and AZS_GetMeterLoadout({ apiVersion = 1, runId = context.runId, ownerId = context.localOwnerId })
		if loadout and loadout.sources then
			sources = { byKey = loadout.sources, byName = {} }
			for _, source in pairs(loadout.sources) do
				if source.name then
					sources.byName[source.name] = source
				end
			end
		end
	end
	return sources
end

-- Whether the meter's line of this name is a talent's.
function SUIC.MeterTalent(name)
	local source = Sources().byName[name]
	return source ~= nil and source.kind == "talent"
end

-- The name the meter gives a source key's own spell, if it knows it.
function SUIC.MeterName(key)
	local source = Sources().byKey[key]
	return source and source.name
end

function SUIC.IconOf(name)
	if not name or name == "" then
		return QUESTION
	end
	if MELEE[name] then
		return GetInventoryItemTexture("player", 16) or QUESTION
	elseif RANGED[name] then
		return GetInventoryItemTexture("player", 18) or GetInventoryItemTexture("player", 16) or QUESTION
	end
	if PETS[name] then
		return Icon(PETS[name])
	end
	local _, _, owner, spell = string.find(name, "^(.-)'s (.+)$")
	if owner and PETS[owner] then
		return Icon(PET_SPELLS[spell]) or SUIC.IconOf(spell) or Icon(PETS[owner])
	end
	-- A spell of the build: its button's, read each time.
	local _, slot = SUIC.SpellSlot(name)
	local texture = slot and GetActionTexture(slot)
	if texture then
		return texture
	end
	if known[name] then
		return known[name]
	end
	local source = Sources().byName[name]
	if source and source.icon and source.icon.path then
		known[name] = source.icon.path
		return known[name]
	end
	if missedAt[name] and GetTime() - missedAt[name] < 10 then
		return QUESTION
	end
	texture = FromSummons(name)
		or Icon(SUIC_TALENT_ICONS and SUIC_TALENT_ICONS[name])
		or FromSpellbook(name) or FromTalents(name) or FromItems(name)
		or Icon(PET_SPELLS[name])
	if not texture and BORROWED[name] then
		for index = 1, table.getn(BORROWED[name]) do
			local other = SUIC.IconOf(BORROWED[name][index])
			if other ~= QUESTION then
				texture = other
				break
			end
		end
	end
	if texture then
		known[name] = texture
		return texture
	end
	missedAt[name] = GetTime()
	return QUESTION
end
