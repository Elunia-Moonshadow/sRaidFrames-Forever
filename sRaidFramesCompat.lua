--[[
	sRaidFrames Compatibility & Data Layer for World of Warcraft: Forever (1.60.x / 16001)
	Original Authors: Saroz, Nevcairiel, Stolenlegacy (sRaidFrames)
	WoW: Forever Port & Modernization: Elunia-Moonshadow
	License: GNU General Public License v2.0 (GPLv2) — see LICENSE.txt
]]
local addonName, NS = ...
NS = NS or {}
NS.funcs = NS.funcs or {}

local Compat = {}
NS.Compat = Compat
_G.sRaidFramesCompat = Compat

local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall
local strlower, strmatch, strfind, gsub = string.lower, string.match, string.find, string.gsub

-------------------------------------------------------------------------------
-- 1. Secret Value Guards (WoW 12.0 / Forever 1.60+ Security Architecture)
-------------------------------------------------------------------------------
local rawIsSecretValue = _G.issecretvalue
local rawIsSecretTable = _G.issecrettable
local rawCanAccessValue = _G.canaccessvalue

local function IsSecret(val)
	if val == nil then return false end
	if rawIsSecretValue and rawIsSecretValue(val) then
		return true
	end
	if rawCanAccessValue and not rawCanAccessValue(val) then
		return true
	end
	return false
end

local function IsSecretTable(tbl)
	if rawIsSecretTable and rawIsSecretTable(tbl) then
		return true
	end
	return false
end

Compat.IsSecret = IsSecret
Compat.IsSecretTable = IsSecretTable

-------------------------------------------------------------------------------
-- 2. Power Type Constants Compatibility
-------------------------------------------------------------------------------
local PowerType = _G.Enum and _G.Enum.PowerType
Compat.POWER_MANA        = _G.SPELL_POWER_MANA        or (PowerType and PowerType.Mana)       or 0
Compat.POWER_RAGE        = _G.SPELL_POWER_RAGE        or (PowerType and PowerType.Rage)       or 1
Compat.POWER_FOCUS       = _G.SPELL_POWER_FOCUS       or (PowerType and PowerType.Focus)      or 2
Compat.POWER_ENERGY      = _G.SPELL_POWER_ENERGY      or (PowerType and PowerType.Energy)     or 3
Compat.POWER_RUNIC_POWER = _G.SPELL_POWER_RUNIC_POWER or (PowerType and PowerType.RunicPower) or 6

-------------------------------------------------------------------------------
-- 3. Sound Compatibility (String -> SOUNDKIT ID)
-------------------------------------------------------------------------------
local SOUND_MAP = {
	["igPlayerInviteDecline"]      = (SOUNDKIT and SOUNDKIT.IG_PLAYER_INVITE_DECLINE)      or 880,
	["gsTitleOptionExit"]          = (SOUNDKIT and SOUNDKIT.GS_TITLE_OPTION_EXIT)          or 799,
	["igCharacterInfoTab"]         = (SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB)         or 841,
	["igMainMenuOption"]           = (SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION)            or 852,
	["igMainMenuOptionCheckBoxOn"] = (SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) or 856,
	["igMainMenuOptionCheckBoxOff"]= (SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF) or 857,
	["igMainMenuOpen"]             = (SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPEN)              or 850,
	["igMainMenuClose"]            = (SOUNDKIT and SOUNDKIT.IG_MAINMENU_CLOSE)             or 851,
}

function Compat.PlaySound(sound, channel)
	if not _G.PlaySound then return end
	local kitID = type(sound) == "string" and SOUND_MAP[sound] or sound
	if type(kitID) == "number" then
		pcall(_G.PlaySound, kitID, channel)
	elseif type(sound) == "string" then
		pcall(_G.PlaySound, sound, channel)
	end
end

-------------------------------------------------------------------------------
-- 4. AddOn Metadata & Loader Compatibility (C_AddOns)
-------------------------------------------------------------------------------
function Compat.GetAddOnMetadata(addon, field)
	if _G.C_AddOns and _G.C_AddOns.GetAddOnMetadata then
		return _G.C_AddOns.GetAddOnMetadata(addon, field)
	elseif _G.GetAddOnMetadata then
		return _G.GetAddOnMetadata(addon, field)
	end
	return nil
end

function Compat.LoadAddOn(addon)
	if _G.C_AddOns and _G.C_AddOns.LoadAddOn then
		return _G.C_AddOns.LoadAddOn(addon)
	elseif _G.LoadAddOn then
		return _G.LoadAddOn(addon)
	end
	return nil
end

-------------------------------------------------------------------------------
-- 5. Spell Info & Range Compatibility (C_Spell / GetSpellInfo)
-------------------------------------------------------------------------------
function Compat.GetSpellInfo(spellIdentifier)
	if not spellIdentifier or IsSecret(spellIdentifier) then return nil end
	if _G.C_Spell and _G.C_Spell.GetSpellInfo then
		local ok, info = pcall(_G.C_Spell.GetSpellInfo, spellIdentifier)
		if ok and info and not IsSecretTable(info) then
			local subtext = nil
			if _G.C_Spell.GetSpellSubtext then
				local okSub, sub = pcall(_G.C_Spell.GetSpellSubtext, spellIdentifier)
				if okSub and not IsSecret(sub) then subtext = sub end
			end
			return info.name, subtext, info.iconID or info.originalIconID, info.castTime or 0, info.minRange or 0, info.maxRange or 0, info.spellID
		end
	end
	if _G.GetSpellInfo then
		local ok, name, rank, icon, castTime, minRange, maxRange, spellID = pcall(_G.GetSpellInfo, spellIdentifier)
		if ok and name and not IsSecret(name) then
			return name, rank, icon, castTime or 0, minRange or 0, maxRange or 0, spellID
		end
	end
	return nil
end

function Compat.GetSpellName(spellIdentifier, bookType)
	if not spellIdentifier or IsSecret(spellIdentifier) then return nil end
	if _G.C_SpellBook and _G.C_SpellBook.GetSpellBookItemName and bookType then
		local bank = (_G.Enum and _G.Enum.SpellBookSpellBank and _G.Enum.SpellBookSpellBank.Player) or 0
		local ok, name, subName = pcall(_G.C_SpellBook.GetSpellBookItemName, spellIdentifier, bank)
		if ok and name then return name, subName end
	end
	if _G.GetSpellBookItemName and bookType then
		local ok, name, subName = pcall(_G.GetSpellBookItemName, spellIdentifier, bookType)
		if ok and name then return name, subName end
	end
	if _G.GetSpellName then
		local ok, name, subName = pcall(_G.GetSpellName, spellIdentifier, bookType)
		if ok and name then return name, subName end
	end
	local name, rank = Compat.GetSpellInfo(spellIdentifier)
	return name, rank
end

function Compat.IsSpellInRange(spellIdentifier, unit)
	if not spellIdentifier or not unit then return nil end
	if _G.C_Spell and _G.C_Spell.IsSpellInRange then
		local ok, res = pcall(_G.C_Spell.IsSpellInRange, spellIdentifier, unit)
		if ok and res ~= nil and not IsSecret(res) then
			return (res == true or res == 1)
		end
	end
	if _G.IsSpellInRange then
		local ok, res = pcall(_G.IsSpellInRange, spellIdentifier, unit)
		if ok and res ~= nil and not IsSecret(res) then
			return (res == true or res == 1)
		end
	end
	return nil
end

function Compat.IsSpellKnown(spellID)
	if not spellID then return false end
	if _G.C_SpellBook and _G.C_SpellBook.IsSpellKnown then
		local ok, res = pcall(_G.C_SpellBook.IsSpellKnown, spellID)
		if ok and res then return true end
	end
	if _G.IsPlayerSpell then
		local ok, res = pcall(_G.IsPlayerSpell, spellID)
		if ok and res then return true end
	end
	if _G.IsSpellKnown then
		local ok, res = pcall(_G.IsSpellKnown, spellID)
		if ok and res then return true end
	end
	return false
end

-------------------------------------------------------------------------------
-- 6. Unified Unit Aura API (C_UnitAuras / UnitBuff / UnitDebuff)
-- Returns: name, icon, count, dispelType, duration, expirationTime, source,
--          isStealable, spellId, isBossAura, auraInstanceID, isSecret
-------------------------------------------------------------------------------
local function UnpackAuraDataTable(aura)
	if not aura then return nil end
	if IsSecretTable(aura) then
		return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, true
	end
	local name = aura.name
	local icon = aura.icon
	local count = aura.applications or 0
	local dispelType = aura.dispelName
	local duration = aura.duration or 0
	local expirationTime = aura.expirationTime or 0
	local source = aura.sourceUnit
	local isStealable = aura.isStealable
	local spellId = aura.spellId
	local isBossAura = aura.isBossAura
	local auraInstanceID = aura.auraInstanceID

	local hasSecret = IsSecret(name) or IsSecret(icon) or IsSecret(count) or IsSecret(dispelType)
		or IsSecret(duration) or IsSecret(expirationTime) or IsSecret(source) or IsSecret(spellId)
		or IsSecret(isStealable) or IsSecret(isBossAura) or IsSecret(auraInstanceID)

	return name, icon, count, dispelType, duration, expirationTime, source, isStealable, spellId, isBossAura, auraInstanceID, hasSecret
end

local function UnpackLegacyUnitAura(...)
	local a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14 = ...
	if not a1 then return nil end
	-- Detect 8.0+ signature (where 2nd return is icon texture number/path and 3rd return is numeric stack count)
	-- vs pre-8.0 signature (where 2nd return was rank string/nil and 3rd return was icon texture)
	if type(a3) == "number" and (type(a4) == "string" or a4 == nil) and type(a5) == "number" then
		-- 8.0+ signature: name, icon, count, dispelType, duration, expirationTime, source, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff
		local hasSecret = IsSecret(a1) or IsSecret(a2) or IsSecret(a3) or IsSecret(a4) or IsSecret(a5) or IsSecret(a6) or IsSecret(a7) or IsSecret(a10)
		return a1, a2, a3 or 0, a4, a5 or 0, a6 or 0, a7, a8, a10, a12, nil, hasSecret
	else
		-- Legacy pre-8.0 signature: name, rank, icon, count, dispelType, duration, expirationTime, source, isStealable, shouldConsolidate, spellId, canApplyAura, isBossDebuff
		local hasSecret = IsSecret(a1) or IsSecret(a3) or IsSecret(a4) or IsSecret(a5) or IsSecret(a6) or IsSecret(a7) or IsSecret(a8) or IsSecret(a11)
		return a1, a3, a4 or 0, a5, a6 or 0, a7 or 0, a8, a9, a11, a13, nil, hasSecret
	end
end

function Compat.GetUnitBuff(unit, index, filter)
	if not unit or not index then return nil end
	local auraFilter = filter and ("HELPFUL|" .. filter) or "HELPFUL"
	if _G.C_UnitAuras and _G.C_UnitAuras.GetAuraDataByIndex then
		local ok, aura = pcall(_G.C_UnitAuras.GetAuraDataByIndex, unit, index, auraFilter)
		if ok then
			return UnpackAuraDataTable(aura)
		end
	elseif _G.C_UnitAuras and _G.C_UnitAuras.GetBuffDataByIndex then
		local ok, aura = pcall(_G.C_UnitAuras.GetBuffDataByIndex, unit, index, filter)
		if ok then
			return UnpackAuraDataTable(aura)
		end
	end
	if _G.UnitBuff then
		local ok, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13 = pcall(_G.UnitBuff, unit, index, filter)
		if ok and a1 then
			return UnpackLegacyUnitAura(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13)
		end
	end
	if _G.UnitAura then
		local ok, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13 = pcall(_G.UnitAura, unit, index, auraFilter)
		if ok and a1 then
			return UnpackLegacyUnitAura(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13)
		end
	end
	return nil
end

function Compat.GetUnitDebuff(unit, index, filter)
	if not unit or not index then return nil end
	local auraFilter = filter and ("HARMFUL|" .. filter) or "HARMFUL"
	if _G.C_UnitAuras and _G.C_UnitAuras.GetAuraDataByIndex then
		local ok, aura = pcall(_G.C_UnitAuras.GetAuraDataByIndex, unit, index, auraFilter)
		if ok then
			return UnpackAuraDataTable(aura)
		end
	elseif _G.C_UnitAuras and _G.C_UnitAuras.GetDebuffDataByIndex then
		local ok, aura = pcall(_G.C_UnitAuras.GetDebuffDataByIndex, unit, index, filter)
		if ok then
			return UnpackAuraDataTable(aura)
		end
	end
	if _G.UnitDebuff then
		local ok, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13 = pcall(_G.UnitDebuff, unit, index, filter)
		if ok and a1 then
			return UnpackLegacyUnitAura(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13)
		end
	end
	if _G.UnitAura then
		local ok, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13 = pcall(_G.UnitAura, unit, index, auraFilter)
		if ok and a1 then
			return UnpackLegacyUnitAura(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13)
		end
	end
	return nil
end

function Compat.FindUnitAuraByNameOrID(unit, targetNameOrID, isHarmful)
	if not unit or not targetNameOrID then return nil end
	local getter = isHarmful and Compat.GetUnitDebuff or Compat.GetUnitBuff
	local i = 1
	while i <= 40 do
		local name, icon, count, dispelType, duration, expirationTime, source, isStealable, spellId, isBossAura, auraInstanceID, isSecret = getter(unit, i)
		if not name then break end
		if not isSecret then
			if (type(targetNameOrID) == "number" and spellId == targetNameOrID) or (type(targetNameOrID) == "string" and name == targetNameOrID) then
				return name, icon, count, dispelType, duration, expirationTime, source, isStealable, spellId, isBossAura, auraInstanceID
			end
		end
		i = i + 1
	end
	return nil
end

-------------------------------------------------------------------------------
-- 7. Taint-Free Backdrop Support for Unit Frames & UI Widgets
-------------------------------------------------------------------------------
function Compat.EnsureBackdrop(frame)
	if not frame then return frame end
	if not frame.SetBackdrop and _G.BackdropTemplateMixin then
		_G.Mixin(frame, _G.BackdropTemplateMixin)
		if frame.OnBackdropLoaded then
			frame:OnBackdropLoaded()
		end
		frame:HookScript("OnSizeChanged", frame.OnBackdropSizeChanged)
	end
	return frame
end

-- Creates a non-secure child visual & backdrop frame for secure unit buttons so that
-- changing background/border colors or range alpha in combat NEVER taints the secure button!
function Compat.AttachSafeUnitBackdrop(unitButton)
	if not unitButton or unitButton._safeBackdropFrame then return unitButton end
	local lvl = unitButton:GetFrameLevel()

	local vf = CreateFrame("Frame", nil, unitButton)
	vf:SetAllPoints(unitButton)
	vf:SetFrameLevel(lvl)
	vf:EnableMouse(false)
	unitButton._visualFrame = vf

	local bg = CreateFrame("Frame", nil, vf, _G.BackdropTemplateMixin and "BackdropTemplate" or nil)
	Compat.EnsureBackdrop(bg)
	bg:SetAllPoints(vf)
	bg:SetFrameLevel(lvl > 0 and (lvl - 1) or 0)
	bg:EnableMouse(false)
	unitButton._safeBackdropFrame = bg

	unitButton.SetSafeFrameLevel = function(self, baseLvl)
		if not InCombatLockdown or not InCombatLockdown() then
			self:SetFrameLevel(baseLvl)
		end
		if bg.SetFrameLevel then bg:SetFrameLevel(baseLvl) end
		if vf.SetFrameLevel then vf:SetFrameLevel(baseLvl + 1) end
	end

	unitButton.SetVisualAlpha = function(self, a)
		if vf.SetAlpha then vf:SetAlpha(a) end
	end
	unitButton.SetVisualAlphaFromBoolean = function(self, secretBool, trueAlpha, falseAlpha)
		if vf.SetAlphaFromBoolean then
			pcall(vf.SetAlphaFromBoolean, vf, secretBool, trueAlpha, falseAlpha)
		end
	end

	unitButton.SetBackdrop = function(self, backdropInfo)
		if bg.SetBackdrop then bg:SetBackdrop(backdropInfo) end
	end
	unitButton.SetBackdropColor = function(self, r, g, b, a)
		if bg.SetBackdropColor then bg:SetBackdropColor(r, g, b, a) end
	end
	unitButton.SetBackdropBorderColor = function(self, r, g, b, a)
		if bg.SetBackdropBorderColor then bg:SetBackdropBorderColor(r, g, b, a) end
	end
	unitButton.GetBackdrop = function(self)
		if bg.GetBackdrop then return bg:GetBackdrop() end
		return nil
	end
	unitButton.GetBackdropColor = function(self)
		if bg.GetBackdropColor then return bg:GetBackdropColor() end
		return 0, 0, 0, 1
	end
	unitButton.GetBackdropBorderColor = function(self)
		if bg.GetBackdropBorderColor then return bg:GetBackdropBorderColor() end
		return 1, 1, 1, 1
	end
	return unitButton
end

-------------------------------------------------------------------------------
-- 7b. Dual-Name System (双名系统) Support for World of Warcraft: Forever
-------------------------------------------------------------------------------
-- In WoW: Forever, players can have a first name and a surname (dual-name system).
-- UnitName(unit) may return (first, surname) or "First-Surname" / "First Surname",
-- and NameUtil.FormatUnitNameForDisplay(unit) returns the formatted dual name.
function Compat.GetUnitDisplayName(unit, formatMode)
	if not unit then return nil end
	local ok, first, second = pcall(_G.UnitName, unit)
	if not ok or not first then return nil end
	if IsSecret(first) then
		return first
	end
	if first == "" then return nil end

	local formatted = nil
	if _G.NameUtil and _G.NameUtil.FormatUnitNameForDisplay then
		local okFmt, fmt = pcall(_G.NameUtil.FormatUnitNameForDisplay, unit)
		if okFmt and fmt and not IsSecret(fmt) and fmt ~= "" then
			formatted = fmt
		end
	end

	local hasSecond = (second and not IsSecret(second) and second ~= "")
	local mode = formatMode or "full"

	if mode == "first" then
		if strfind(first, " ") then
			return strmatch(first, "^([^ ]+)") or first
		elseif strfind(first, "%-") then
			return strmatch(first, "^([^%-]+)") or first
		end
		return first
	elseif mode == "surname" then
		if hasSecond then
			return second
		elseif formatted and strfind(formatted, " ") then
			return strmatch(formatted, " ([^ ]+)$") or formatted
		elseif strfind(first, " ") then
			return strmatch(first, " ([^ ]+)$") or first
		elseif strfind(first, "%-") then
			return strmatch(first, "%-([^%-]+)$") or first
		end
		return first
	else
		-- "full" (default: display full dual name "First Surname")
		if formatted then
			return formatted
		elseif hasSecond then
			return first .. " " .. second
		elseif strfind(first, "%-") then
			return (gsub(first, "%-", " "))
		end
		return first
	end
end

-- Returns all non-secret name variants for a unit so roster & DBM lookups match
-- whether queried by "First", "First Surname", or "First-Surname".
function Compat.GetUnitNameVariants(unit)
	local variants = {}
	if not unit then return variants end
	local ok, first, second = pcall(_G.UnitName, unit)
	if not ok or not first or IsSecret(first) or first == "" then
		return variants
	end
	variants[first] = true

	if _G.NameUtil and _G.NameUtil.FormatUnitNameForDisplay then
		local okFmt, fmt = pcall(_G.NameUtil.FormatUnitNameForDisplay, unit)
		if okFmt and fmt and not IsSecret(fmt) and fmt ~= "" then
			variants[fmt] = true
			variants[gsub(fmt, " ", "-")] = true
		end
	end

	if second and not IsSecret(second) and second ~= "" then
		variants[first .. " " .. second] = true
		variants[first .. "-" .. second] = true
	end

	if strfind(first, " ") then
		local f1 = strmatch(first, "^([^ ]+)")
		if f1 then variants[f1] = true end
		variants[gsub(first, " ", "-")] = true
	elseif strfind(first, "%-") then
		local f1 = strmatch(first, "^([^%-]+)")
		if f1 then variants[f1] = true end
		variants[gsub(first, "%-", " ")] = true
	end

	return variants
end

-------------------------------------------------------------------------------
-- 8. Priest Buff & Aura Database (Classic 60 / Turtle WoW / WoW: Forever)
-------------------------------------------------------------------------------
-- Priority tiers for Priest buffs:
--   2 = Active Combat/Healing/Defensive Priest buffs (Shield, Renew, PoM, Fear Ward, PI, Pain Supp, Guardian Spirit, Inspiration, Lightwell)
--   1 = Raid Priest buffs (Fortitude, Divine Spirit, Shadow Protection, Inner Fire, Levitate, Vampiric Embrace)
Compat.PriestBuffSpellIDs = {
	-- Power Word: Shield (真言术：盾 - all ranks)
	[17] = 2, [592] = 2, [600] = 2, [3747] = 2, [6065] = 2, [6066] = 2,
	[10898] = 2, [10899] = 2, [10900] = 2, [10901] = 2, [25217] = 2, [25218] = 2,
	-- Renew (恢复 - all ranks)
	[139] = 2, [6074] = 2, [6075] = 2, [6076] = 2, [6077] = 2, [6078] = 2,
	[10927] = 2, [10928] = 2, [10929] = 2, [25315] = 2, [25221] = 2, [25222] = 2,
	-- Prayer of Mending (愈合祷言)
	[33076] = 2, [33110] = 2, [401859] = 2, [401877] = 2,
	-- Penance (苦修 - Forever)
	[402261] = 2,
	-- Divine Aegis (神圣庇护 - Forever)
	[431622] = 2,
	-- Divine Grace (神圣恩典 - Forever)
	[1277370] = 2,
	-- Contingency Plan (应急预案 - Forever)
	[1277462] = 2,
	-- Desperate Prayer (绝望祷言)
	[13908] = 2,
	-- Fear Ward (防护恐惧结界 - Classic & Forever)
	[6346] = 2, [459699] = 2,
	-- Power Infusion (能量灌注)
	[10060] = 2,
	-- Pain Suppression (痛苦压制 - Classic & Forever)
	[33206] = 2, [402004] = 2, [402839] = 2,
	-- Guardian Spirit (守护之魂)
	[47788] = 2,
	-- Power Word: Barrier (真言术：障)
	[62618] = 2, [81782] = 2, [425207] = 2,
	-- Spirit of Redemption (救赎之魂)
	[20711] = 2, [27827] = 2,
	-- Inspiration (灵感 - all ranks)
	[14893] = 2, [15357] = 2, [15359] = 2,
	-- Lightwell Renew (光明之泉恢复 - all ranks)
	[7001] = 2, [27873] = 2, [27874] = 2,
	-- Abolish Disease (驱除疾病 HoT effect)
	[552] = 2,

	-- Power Word: Fortitude (真言术：韧 - all ranks)
	[1243] = 1, [1244] = 1, [1245] = 1, [2791] = 1, [10937] = 1, [10938] = 1, [25389] = 1,
	-- Prayer of Fortitude (坚韧祷言 - all ranks)
	[21562] = 1, [21564] = 1, [25392] = 1,
	-- Divine Spirit (神圣之灵 - all ranks)
	[14752] = 1, [14818] = 1, [14819] = 1, [27841] = 1, [25312] = 1,
	-- Prayer of Spirit (精神祷言 - all ranks)
	[27681] = 1, [32999] = 1,
	-- Shadow Protection (防护暗影 - all ranks)
	[976] = 1, [10957] = 1, [10958] = 1, [25433] = 1,
	-- Prayer of Shadow Protection (暗影防护祷言 - all ranks)
	[27683] = 1, [39374] = 1,
	-- Inner Fire (心灵之火)
	[588] = 1, [7128] = 1, [602] = 1, [1006] = 1, [10951] = 1, [10952] = 1,
	-- Touch of Weakness (虚弱之触)
	[2652] = 1, [19261] = 1, [19262] = 1, [19264] = 1, [19265] = 1, [19266] = 1,
	-- Shadowguard (暗影守卫)
	[18137] = 1, [19308] = 1, [19309] = 1, [19310] = 1, [19311] = 1, [19312] = 1,
	-- Inner Focus (心灵专注)
	[14751] = 1,
	-- Shadowform (暗影形态)
	[15473] = 1,
	-- Vampiric Embrace (吸血鬼的拥抱)
	[15286] = 1,
	-- Levitate (漂浮术)
	[1706] = 1,
}

-- Separate spell ID sets for Forever native AuraContainers (in-combat locked aura filtering)
Compat.PriestCombatBuffIDs = {}
Compat.PriestRaidBuffIDs = {}
Compat.AllPriestBuffIDs = {}
for id, prio in pairs(Compat.PriestBuffSpellIDs) do
	Compat.AllPriestBuffIDs[id] = true
	if prio >= 2 then
		Compat.PriestCombatBuffIDs[id] = true
	else
		Compat.PriestRaidBuffIDs[id] = true
	end
end

-- All-class Raid Buffs & Paladin Blessings (so Paladins see existing Might/Wisdom/Kings from any Paladin,
-- Druids see Mark/Gift of the Wild, Mages see Arcane Intellect, Priests see Fort/Spirit/Shadow, etc.)
Compat.PaladinRaidBuffIDs = {
	[19740] = true, [19834] = true, [19835] = true, [19836] = true, [19837] = true, [19838] = true, [25291] = true, -- Blessing of Might
	[25782] = true, [25916] = true, -- Greater Blessing of Might
	[19742] = true, [19850] = true, [19852] = true, [19853] = true, [19854] = true, [25290] = true, -- Blessing of Wisdom
	[25894] = true, [25918] = true, -- Greater Blessing of Wisdom
	[20217] = true, [25898] = true, -- Blessing / Greater Blessing of Kings
	[20911] = true, [20912] = true, [20913] = true, [20914] = true, [25899] = true, -- Blessing of Sanctuary
	[1044]  = true, -- Blessing of Freedom
	[19977] = true, [19978] = true, [19979] = true, [25890] = true, -- Blessing of Light
	[1038]  = true, [25895] = true, -- Blessing of Salvation
	[1328548] = true, -- Oath of Light (Forever)
	[1310909] = true, [1311593] = true, [1311597] = true, -- Light's Vigil (Forever)
}

Compat.DruidRaidBuffIDs = {
	[1126] = true, [5232] = true, [6756] = true, [5234] = true, [8907] = true, [9884] = true, [9885] = true, -- Mark of the Wild
	[21849] = true, [21850] = true, -- Gift of the Wild
	[467] = true, [782] = true, [1075] = true, [8914] = true, [9756] = true, [9910] = true, -- Thorns
}

Compat.MageRaidBuffIDs = {
	[1459] = true, [1460] = true, [1461] = true, [10156] = true, [10157] = true, -- Arcane Intellect
	[23028] = true, -- Arcane Brilliance
}

Compat.OtherClassRaidBuffIDs = {}
for id in pairs(Compat.PaladinRaidBuffIDs) do Compat.OtherClassRaidBuffIDs[id] = true end
for id in pairs(Compat.DruidRaidBuffIDs) do Compat.OtherClassRaidBuffIDs[id] = true end
for id in pairs(Compat.MageRaidBuffIDs) do Compat.OtherClassRaidBuffIDs[id] = true end

Compat.RaidBuffsByClass = {
	PRIEST  = Compat.PriestRaidBuffIDs,
	PALADIN = Compat.PaladinRaidBuffIDs,
	DRUID   = Compat.DruidRaidBuffIDs,
	MAGE    = Compat.MageRaidBuffIDs,
}

Compat.AllClassRaidBuffIDs = {}
for id in pairs(Compat.PriestRaidBuffIDs) do Compat.AllClassRaidBuffIDs[id] = true end
for id in pairs(Compat.OtherClassRaidBuffIDs) do Compat.AllClassRaidBuffIDs[id] = true end

function Compat.GetPlayerClassRaidBuffIDs(playerClass)
	return (playerClass and Compat.RaidBuffsByClass[playerClass]) or Compat.AllClassRaidBuffIDs
end

-- Key raid & external defensive cooldowns across classes in WoW: Forever
Compat.DefensiveBuffSpellIDs = {
	[871] = true, [15062] = true, [29061] = true, [1277424] = true, -- Shield Wall (盾墙)
	[12975] = true, [12976] = true, -- Last Stand (破釜沉舟)
	[642] = true, [659] = true, [1020] = true, [13874] = true, -- Divine Shield (圣盾术)
	[498] = true, [5573] = true, [13007] = true, [27778] = true, [27779] = true, [458312] = true,
	[458371] = true, [1213300] = true, -- Divine Protection (圣佑术)
	[1022] = true, [5599] = true, [10278] = true, [442948] = true, -- Blessing of Protection (保护祝福)
	[6940] = true, [20729] = true, -- Blessing of Sacrifice (牺牲祝福)
	[1328548] = true, -- Oath of Light (圣光誓言 - Forever)
	[1310909] = true, [1311593] = true, [1311597] = true, -- Light's Vigil (圣光守卫 - Forever)
	[4086] = true, [5277] = true, [15087] = true, -- Evasion (闪避)
	[20655] = true, [22812] = true, [428713] = true, [1289128] = true, -- Barkskin (树皮术)
	[29166] = true, [456195] = true, -- Innervate (激活)
	[11958] = true, [27619] = true, [45438] = true, -- Ice Block (寒冰屏障)
	[19263] = true, -- Deterrence (威慑)
	[462873] = true, -- Cloak of Shadows (暗影斗篷)
	[433255] = true, -- Shamanistic Rage (萨满之怒)
}

-- Combined combat buffs (Priest combat buffs + external/personal defensives)
Compat.ImportantCombatBuffIDs = {}
for id in pairs(Compat.PriestCombatBuffIDs) do Compat.ImportantCombatBuffIDs[id] = true end
for id in pairs(Compat.DefensiveBuffSpellIDs) do Compat.ImportantCombatBuffIDs[id] = true end

-- Compact pet HoT / heal / defensive buffs (Renew, PW:S, Rejuvenation, Regrowth, Mend Pet, etc.)
Compat.PetBuffSpellIDs = {}
for id in pairs(Compat.ImportantCombatBuffIDs) do Compat.PetBuffSpellIDs[id] = true end
local extraPetBuffs = {
	136, 3111, 3661, 3662, 13542, 13543, 13544, -- Mend Pet (治疗宠物)
	774, 1058, 1430, 2090, 2091, 3627, 8910, 9839, 9840, 9841, 25299, -- Rejuvenation (回春术)
	8936, 8938, 8939, 8940, 8941, 9750, 9856, 9857, 9858, -- Regrowth (愈合)
}
for _, id in ipairs(extraPetBuffs) do Compat.PetBuffSpellIDs[id] = true end

-- Food & drink spell IDs to exclude from player short-buff slots in Forever
Compat.FoodDrinkSpellIDs = {
	[430] = true, [431] = true, [432] = true, [433] = true, [434] = true, [435] = true, [1127] = true,
	[1129] = true, [1131] = true, [1133] = true, [1135] = true, [1137] = true, [2639] = true, [5004] = true,
	[5005] = true, [5006] = true, [5007] = true, [6410] = true, [7737] = true, [10250] = true, [10256] = true,
	[10257] = true, [18229] = true, [18230] = true, [18231] = true, [18232] = true, [18233] = true,
	[18234] = true, [22731] = true, [22734] = true, [24005] = true, [24355] = true, [24707] = true,
	[24800] = true, [24869] = true, [25660] = true, [25695] = true, [25696] = true, [25700] = true,
	[25702] = true, [25886] = true, [25888] = true, [26260] = true, [26261] = true, [26401] = true,
	[26402] = true, [26472] = true, [26473] = true, [26474] = true, [26475] = true, [28616] = true,
	[29007] = true, [29008] = true, [29073] = true, [167152] = true, [446713] = true, [446714] = true,
	[468767] = true, [470362] = true, [470369] = true, [1225769] = true, [1225771] = true, [1225772] = true,
	[1225774] = true, [1226808] = true, [1330734] = true,
}

-- Localized names for Priest buffs (lowercase for case-insensitive matching)
Compat.PriestBuffNames = {
	-- Combat / Healing / Defensive Priest Buffs (Priority 2)
	["真言术：盾"] = 2, ["真言術：盾"] = 2, ["power word: shield"] = 2,
	["恢复"] = 2, ["恢復"] = 2, ["renew"] = 2,
	["愈合祷言"] = 2, ["癒合禱言"] = 2, ["prayer of mending"] = 2,
	["苦修"] = 2, ["penance"] = 2,
	["神圣庇护"] = 2, ["神聖庇護"] = 2, ["divine aegis"] = 2,
	["神圣恩典"] = 2, ["神聖恩典"] = 2, ["divine grace"] = 2,
	["应急预案"] = 2, ["應急預案"] = 2, ["contingency plan"] = 2,
	["绝望祷言"] = 2, ["絕望禱言"] = 2, ["desperate prayer"] = 2,
	["防护恐惧结界"] = 2, ["防護恐懼結界"] = 2, ["fear ward"] = 2,
	["能量灌注"] = 2, ["power infusion"] = 2,
	["痛苦压制"] = 2, ["痛苦鎮壓"] = 2, ["pain suppression"] = 2,
	["守护之魂"] = 2, ["守護聖靈"] = 2, ["guardian spirit"] = 2,
	["真言术：障"] = 2, ["真言術：障"] = 2, ["power word: barrier"] = 2,
	["救赎之魂"] = 2, ["救贖之靈"] = 2, ["spirit of redemption"] = 2,
	["灵感"] = 2, ["靈感"] = 2, ["inspiration"] = 2,
	["光明之泉恢复"] = 2, ["光束泉恢復"] = 2, ["lightwell renew"] = 2,
	["驱除疾病"] = 2, ["驅除疾病"] = 2, ["abolish disease"] = 2,

	-- Raid / Stat Priest Buffs (Priority 1)
	["真言术：韧"] = 1, ["真言術：韌"] = 1, ["power word: fortitude"] = 1,
	["坚韧祷言"] = 1, ["堅韌禱言"] = 1, ["prayer of fortitude"] = 1,
	["神圣之灵"] = 1, ["神聖之靈"] = 1, ["divine spirit"] = 1,
	["精神祷言"] = 1, ["精神禱言"] = 1, ["prayer of spirit"] = 1,
	["防护暗影"] = 1, ["防護暗影"] = 1, ["shadow protection"] = 1,
	["暗影防护祷言"] = 1, ["暗影防護禱言"] = 1, ["prayer of shadow protection"] = 1,
	["心灵之火"] = 1, ["心靈之火"] = 1, ["inner fire"] = 1,
	["虚弱之触"] = 1, ["虛弱之觸"] = 1, ["touch of weakness"] = 1,
	["暗影守卫"] = 1, ["暗影守衛"] = 1, ["shadowguard"] = 1,
	["心灵专注"] = 1, ["心靈專注"] = 1, ["inner focus"] = 1,
	["暗影形态"] = 1, ["暗影形態"] = 1, ["shadowform"] = 1,
	["吸血鬼的拥抱"] = 1, ["吸血鬼的擁抱"] = 1, ["vampiric embrace"] = 1,
	["漂浮术"] = 1, ["漂浮術"] = 1, ["levitate"] = 1,
}

-- Priest-important debuffs (like Weakened Soul 虚弱灵魂) that must be shown even when "Only Dispellable" is checked
Compat.PriestImportantDebuffIDs = {
	[6788]  = true, -- Weakened Soul (虚弱灵魂)
	[2096]  = true, -- Mind Vision (心灵视界)
	[605]   = true, -- Mind Control (精神控制)
}

Compat.PriestImportantDebuffNames = {
	["虚弱灵魂"] = true, ["虛弱靈魂"] = true, ["weakened soul"] = true,
	["精神控制"] = true, ["mind control"] = true,
}

function Compat.GetPriestBuffPriority(name, spellId)
	if spellId and not IsSecret(spellId) and Compat.PriestBuffSpellIDs[spellId] then
		return Compat.PriestBuffSpellIDs[spellId]
	end
	if name and not IsSecret(name) then
		local prio = Compat.PriestBuffNames[name] or Compat.PriestBuffNames[strlower(name)]
		if prio then return prio end
	end
	return nil
end

function Compat.IsPriestImportantDebuff(name, spellId)
	if spellId and not IsSecret(spellId) and Compat.PriestImportantDebuffIDs[spellId] then
		return true
	end
	if name and not IsSecret(name) then
		if Compat.PriestImportantDebuffNames[name] or Compat.PriestImportantDebuffNames[strlower(name)] then
			return true
		end
	end
	return false
end

-------------------------------------------------------------------------------
-- 9. Important Boss & DBM Skill Warning Helper (WoW: Forever 16001)
-- Relies on client native `isBossAura`, live DBM-Core 12.1.24 callbacks,
-- and optional user-configured custom skills (no hardcoded Classic MC/BWL clutter).
-------------------------------------------------------------------------------
Compat.BossSkillSpellIDs = {}
Compat.BossSkillNames = {}

function Compat.IsImportantBossSkill(name, spellId, isBossAura, customTable)
	if isBossAura and not IsSecret(isBossAura) then
		return true
	end
	if spellId and not IsSecret(spellId) then
		if Compat.BossSkillSpellIDs[spellId] then return true end
		if customTable and customTable[spellId] then return true end
	end
	if name and not IsSecret(name) then
		local lower = strlower(name)
		if Compat.BossSkillNames[name] or Compat.BossSkillNames[lower] then return true end
		if customTable and (customTable[name] or customTable[lower]) then return true end
	end
	return false
end

Compat.OtherClassRaidBuffNames = {}
for id in pairs(Compat.OtherClassRaidBuffIDs) do
	local name = Compat.GetSpellInfo(id)
	if name and not IsSecret(name) then
		Compat.OtherClassRaidBuffNames[name] = true
		Compat.OtherClassRaidBuffNames[strlower(name)] = true
	end
end

Compat.RaidBuffNamesByClass = {}
for cls, idMap in pairs(Compat.RaidBuffsByClass) do
	local nameMap = {}
	for id in pairs(idMap) do
		local name = Compat.GetSpellInfo(id)
		if name and not IsSecret(name) then
			nameMap[name] = true
			nameMap[strlower(name)] = true
		end
	end
	Compat.RaidBuffNamesByClass[cls] = nameMap
end

function Compat.IsClassRaidBuff(name, spellId, playerClass)
	local idMap = Compat.GetPlayerClassRaidBuffIDs(playerClass)
	if spellId and not IsSecret(spellId) and idMap[spellId] then
		return true
	end
	local nameMap = playerClass and Compat.RaidBuffNamesByClass[playerClass]
	if nameMap and name and not IsSecret(name) then
		if nameMap[name] or nameMap[strlower(name)] then
			return true
		end
	elseif not nameMap then
		return Compat.IsAllClassRaidBuff(name, spellId)
	end
	return false
end

function Compat.IsAllClassRaidBuff(name, spellId)
	if spellId and not IsSecret(spellId) and Compat.AllClassRaidBuffIDs[spellId] then
		return true
	end
	if name and not IsSecret(name) then
		if Compat.OtherClassRaidBuffNames[name] or Compat.OtherClassRaidBuffNames[strlower(name)] then
			return true
		end
	end
	return false
end

-- Populate localized names from client spell database at load time
for id, prio in pairs(Compat.PriestBuffSpellIDs) do
	local name = Compat.GetSpellInfo(id)
	if name and not IsSecret(name) then
		Compat.PriestBuffNames[name] = prio
		Compat.PriestBuffNames[strlower(name)] = prio
	end
end

for id in pairs(Compat.PriestImportantDebuffIDs) do
	local name = Compat.GetSpellInfo(id)
	if name and not IsSecret(name) then
		Compat.PriestImportantDebuffNames[name] = true
		Compat.PriestImportantDebuffNames[strlower(name)] = true
	end
end

for id in pairs(Compat.BossSkillSpellIDs) do
	local name = Compat.GetSpellInfo(id)
	if name and not IsSecret(name) then
		Compat.BossSkillNames[name] = true
		Compat.BossSkillNames[strlower(name)] = true
	end
end
