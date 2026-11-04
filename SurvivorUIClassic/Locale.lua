-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: its own words in the game's language, for the languages
-- it speaks (Locale_ru.lua: Russian, its game terms the game's own words).
-- English is the key; in any other language, or until the language is
-- known, a text stays English.
--
--   SUIC.T("Build list")              "Список заклинаний"
--   SUIC.TF("{1} gold", 120)          "120 золота"
--
-- Two texts that read the same in English and not in another language are
-- told apart by a word before them, "@color:Gold": shown without it.
--
-- The language: the game's meter API names it (AZS_GetMeterCapabilities,
-- languageCode, the game's 0.139), before any run too. A game without it is
-- told by the hero's race as the game names it (AZS_ZONE.rname), as Survivor
-- UI does. Texts set before it was known are put in it by a pass over the
-- addon's frames (Retell), each keeping its English.
--
-- The game's fonts write Cyrillic (its Friz Quadrata has it); Barlow, the
-- numbers' and the meter's, does not: a text in letters it lacks takes the
-- game's font (SUIC.Plain).

SUIC.WORDS = SUIC.WORDS or {}   -- [language] = { [english] = its text } (Locale_ru.lua)

-- The race names of the languages spoken, and of the one that shares some of
-- Russian's ("Орк" is Orc in both): only a name of one language says which.
-- From Survivor UI's LocaleData.lua (the game's translation tables).
local RACES = {
	ru = { "Человек", "Орк", "Дворф", "Ночной эльф", "Нежить", "Таурен", "Гном", "Тролль" },
	uk = { "Людина", "Орк", "Дворф", "Нічний ельф", "Нежить", "Таурен", "Гном", "Троль" },
}

local language          -- "ru"...: nil for English, or not known yet
local raceSeen

local function FromGame()
	if not AZS_GetMeterCapabilities then
		return nil
	end
	local ok, capabilities = pcall(AZS_GetMeterCapabilities)
	if ok and type(capabilities) == "table" and type(capabilities.languageCode) == "string"
		and capabilities.languageCode ~= "" then
		return capabilities.languageCode
	end
	return nil
end

local function FromRace()
	local race = AZS_ZONE and AZS_ZONE.rname
	if not race or race == raceSeen then
		return
	end
	raceSeen = race
	local matches, which = 0, nil
	for code, names in pairs(RACES) do
		for index = 1, table.getn(names) do
			if names[index] == race then
				matches, which = matches + 1, code
			end
		end
	end
	if matches == 1 then
		language = which
	elseif matches == 0 then
		language = nil
	end
end

local function Detect()
	local code = FromGame()
	if code then
		language = code ~= "en" and code or nil
	else
		FromRace()
	end
	return language
end

-- The game's language as the game codes it ("ru"): nil for English, or until
-- it is known.
function SUIC.Language()
	return language
end

-- The words of the game's language, if the addon speaks it.
local function Words()
	return language and SUIC.WORDS[language]
end

function SUIC.Spoken()
	return Words() ~= nil
end

function SUIC.T(text)
	local words = Words()
	local found = words and text and words[text]
	if found then
		return found
	end
	if text and string.sub(text, 1, 1) == "@" then
		local _, _, rest = string.find(text, "^@%a+:(.*)$")
		return rest or text
	end
	return text
end

-- A text with values in it, {1} to {9} where each goes, so a language can put
-- them in its own order.
function SUIC.TF(text, ...)
	local values = arg
	return (string.gsub(SUIC.T(text), "{(%d)}", function(index)
		local value = values[tonumber(index)]
		return value ~= nil and tostring(value) or ""
	end))
end

-- A name of the game's (a spell, a pet) as the game writes it in its
-- language, where the client gives it in English (its spellbook, its combat
-- log): the game's own names (SUIC.NAMES, from its translation tables, as
-- Survivor UI's LocaleData.lua has them). A name not known, or already in the
-- language, comes back as it was.
SUIC.NAMES = SUIC.NAMES or {}   -- [language] = { [its name] = English }
local natives, loose, nativesOf = {}, {}, nil

local function Loose(name)
	return (string.gsub(string.lower(name), "[^%a%d]", ""))
end

function SUIC.Native(name)
	if not name or not Words() then
		return name
	end
	if nativesOf ~= language then
		nativesOf, natives, loose = language, {}, {}
		for native, english in pairs(SUIC.NAMES[language] or {}) do
			if not natives[english] then
				natives[english] = native
				loose[Loose(english)] = native
			end
		end
	end
	local native = natives[name] or loose[Loose(name)]
	if not native then
		-- A pet's own spell as the combat log names it: "Imp's Fireball".
		local _, _, pet, spell = string.find(name, "^(.-)'s (.+)$")
		if pet and natives[pet] then
			native = SUIC.TF("{1}'s {2}", natives[pet], natives[spell] or spell)
		end
	end
	return native or name
end

-- The English of a text of the game's among the English names given: the
-- game's own label ("Здоровье") read back ("Health"). Unknown, it comes back
-- as it was.
function SUIC.EnglishOf(text, names)
	if not text or not Words() then
		return text
	end
	for index = 1, table.getn(names) do
		if SUIC.T(names[index]) == text then
			return names[index]
		end
	end
	return text
end

-- The first bytes of a text, at most count of them, never half a letter
-- (Cyrillic's are two bytes).
function SUIC.CutBytes(text, count)
	text = text or ""
	if count >= string.len(text) then
		return text
	end
	local byte = string.byte(text, count + 1)
	while count > 0 and byte and byte >= 128 and byte < 192 do
		count = count - 1
		byte = string.byte(text, count + 1)
	end
	return string.sub(text, 1, count)
end

-- How many letters a text has, and its first count of them, a letter of
-- several bytes kept whole where string.sub would cut it.
function SUIC.Length(text)
	local _, count = string.gsub(text or "", "[^\128-\191]", "")
	return count
end

function SUIC.Cut(text, count)
	text = text or ""
	local index, chars, length = 1, 0, string.len(text)
	while index <= length and chars < count do
		local byte = string.byte(text, index)
		index = index + (byte >= 240 and 4 or byte >= 224 and 3 or byte >= 192 and 2 or 1)
		chars = chars + 1
	end
	return string.sub(text, 1, index - 1)
end

-- A font string in Barlow given its text: the game's font where Barlow lacks
-- the letters (anything past ASCII), Barlow else.
function SUIC.Plain(text)
	return text ~= nil and string.find(text, "[\128-\255]") ~= nil
end

------------------------------------------------------------------------------
-- The texts already on screen as the language turns up, put in it: every
-- font string of the addon's frames whose text is one of its words. The
-- guide stays English for now, all of it. Each keeps its English, so the game
-- set back to English puts that back.

local function Ours(frame)
	local at = frame
	while at do
		if at == UIParent or at == WorldFrame then
			return false
		end
		local name = at:GetName()
		if name then
			return string.find(name, "^SUIC") ~= nil and string.find(name, "^SUICGuide") == nil
		end
		at = at:GetParent()
	end
	return false
end

local function Retell(frame)
	local regions = { frame:GetRegions() }
	for index = 1, table.getn(regions) do
		local region = regions[index]
		if region.GetObjectType and region:GetObjectType() == "FontString" then
			local text = region:GetText()
			if text then
				local english = region.suicEnglish
				if not (english and (text == english or text == region.suicShown)) then
					english = text
				end
				local shown = SUIC.T(english)
				if shown ~= text then
					region:SetText(shown)
				end
				if shown ~= english then
					region.suicEnglish, region.suicShown = english, shown
				end
			end
		end
	end
	-- A button's own text (Reset, Done).
	if frame.GetFontString and frame:GetObjectType() == "Button" then
		local text = frame:GetText()
		if text then
			local english = frame.suicEnglish
			if not (english and (text == english or text == frame.suicShown)) then
				english = text
			end
			local shown = SUIC.T(english)
			if shown ~= text then
				frame:SetText(shown)
			end
			if shown ~= english then
				frame.suicEnglish, frame.suicShown = english, shown
			end
		end
	end
end

local spoken = false
local function RetellAll()
	local now = Words() or false
	if now == spoken then
		return
	end
	spoken = now
	local frame = EnumerateFrames and EnumerateFrames()
	while frame do
		if Ours(frame) then
			Retell(frame)
		end
		frame = EnumerateFrames(frame)
	end
	if SUIC.OnLanguage then
		for index = 1, table.getn(SUIC.OnLanguage) do
			SUIC.OnLanguage[index]()
		end
	end
end

-- Pieces that keep a text of their own (a cache) ask to be told.
SUIC.OnLanguage = {}

Detect()

local watch = CreateFrame("Frame")
local zoneSeen, lastLook = nil, 0
watch:RegisterEvent("PLAYER_ENTERING_WORLD")
watch:SetScript("OnEvent", function()
	Detect()
	RetellAll()
end)
-- Read again as each run begins (the game set to another language between
-- runs) and now and then.
watch:SetScript("OnUpdate", function()
	local now = GetTime()
	if AZS_ZONE_UPDATED == zoneSeen and now - lastLook < 5 then
		return
	end
	zoneSeen, lastLook = AZS_ZONE_UPDATED, now
	Detect()
	RetellAll()
end)
