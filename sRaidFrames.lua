--[[
	sRaidFrames (WoW: Forever Edition)
	Original Authors: Saroz, Nevcairiel, Stolenlegacy
	WoW: Forever Port & Modernization: Elunia-Moonshadow
	License: GNU General Public License v2.0 (GPLv2) — see LICENSE.txt
]]
local select, next, pairs, ipairs, tinsert, tconcat, tremove, tsort, tonumber, tostring, ceil, floor, fmod, max, min =
      select, next, pairs, ipairs, table.insert, table.concat, table.remove, table.sort, tonumber, tostring, math.ceil, math.floor, math.fmod, math.max, math.min
local strlower, strmatch, strfind, gsub, strsplit = string.lower, string.match, string.find, string.gsub, strsplit
local pcall, type, time, GetTime = pcall, type, time, GetTime

local Compat = _G.sRaidFramesCompat
local IsSecret = Compat.IsSecret
local IsSecretTable = Compat.IsSecretTable
local GetSpellInfo = Compat.GetSpellInfo
local GetUnitBuff = Compat.GetUnitBuff
local GetUnitDebuff = Compat.GetUnitDebuff
local GetAddOnMetadata = Compat.GetAddOnMetadata

local InCombatLockdown, IsInInstance, CheckInteractDistance =
      InCombatLockdown, IsInInstance, CheckInteractDistance
local GetNumGroupMembers, GetRaidRosterInfo, IsInRaid =
      GetNumGroupMembers, GetRaidRosterInfo, IsInRaid
local IsInGroup = _G.IsInGroup or function() return GetNumGroupMembers and GetNumGroupMembers() > 0 end
local UnitIsGroupLeader = _G.UnitIsGroupLeader or _G.IsRaidLeader or function() return false end
local UnitIsGroupAssistant = _G.UnitIsGroupAssistant or _G.IsRaidOfficer or function() return false end
local UnitIsRaidOfficer = _G.UnitIsRaidOfficer or _G.UnitIsGroupAssistant or function() return false end
local IsEveryoneAssistant = _G.IsEveryoneAssistant or function() return false end
local GetSpecialization = _G.GetSpecialization or function() return 0 end
local rawUnitHasVehicleUI = _G.UnitHasVehicleUI or function() return false end
local function UnitHasVehicleUI(unit)
	if not unit or IsSecret(unit) then return false end
	local ok, res = pcall(rawUnitHasVehicleUI, unit)
	return ok and not IsSecret(res) and res and true or false
end
local UnitGetIncomingHeals = _G.UnitGetIncomingHeals or function() return 0 end

local UnitClass, UnitInRange, UnitIsVisible, UnitIsUnit, UnitName, UnitIsDead, UnitIsGhost, UnitIsConnected, UnitIsAFK =
      UnitClass, UnitInRange, UnitIsVisible, UnitIsUnit, UnitName, UnitIsDead, UnitIsGhost, UnitIsConnected, UnitIsAFK
local UnitHealth, UnitHealthMax, UnitPowerType, UnitPower, UnitPowerMax, UnitAffectingCombat, UnitRace =
      UnitHealth, UnitHealthMax, UnitPowerType, UnitPower, UnitPowerMax, UnitAffectingCombat, UnitRace
local UnitExists, UnitInRaid, UnitGUID, UnitLevel, IsAltKeyDown = UnitExists, UnitInRaid, UnitGUID, UnitLevel, IsAltKeyDown
local GetRaidTargetIndex = GetRaidTargetIndex

local PowerBarColor, RAID_CLASS_COLORS = PowerBarColor, RAID_CLASS_COLORS

local L = LibStub("AceLocale-3.0"):GetLocale("sRaidFrames")
local LGIST = LibStub:GetLibrary("LibGroupInSpecT-1.1", true) or LibStub:GetLibrary("LibGroupInSpecT-1.0", true)
local ResInfo = LibStub("LibResInfo-1.0", true)
local Media = LibStub("LibSharedMedia-3.0")
local Banzai = LibStub("LibBanzai-2.0", true)
local LDB = LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub("LibDBIcon-1.0", true)
local createLDBLauncher

Media:Register("statusbar", "Otravi", "Interface\\AddOns\\sRaidFrames\\textures\\otravi")
Media:Register("statusbar", "Smooth", "Interface\\AddOns\\sRaidFrames\\textures\\smooth")
Media:Register("statusbar", "Striped", "Interface\\AddOns\\sRaidFrames\\textures\\striped")
Media:Register("statusbar", "BantoBar", "Interface\\AddOns\\sRaidFrames\\textures\\bantobar")

sRaidFrames = LibStub("AceAddon-3.0"):NewAddon("sRaidFrames",
	"AceEvent-3.0",
	"AceTimer-3.0",
	"AceBucket-3.0",
	"AceConsole-3.0"
)

local addonName, NS = ...
NS = NS or {}
NS.funcs = NS.funcs or {}
local privateFuncs = NS.funcs

local sRaidFrames = sRaidFrames
sRaidFrames.noop = function() end

local SpellCache = setmetatable({}, {
	__index = function(tbl, id)
		local name = GetSpellInfo(id)
		if name and not IsSecret(name) then
			tbl[id] = name
			return name
		end
		return nil
	end
})

local DISPEL_BORDER_COLORS = {
	Magic   = { r = 0.20, g = 0.60, b = 1.00 },
	Curse   = { r = 0.60, g = 0.00, b = 1.00 },
	Disease = { r = 0.60, g = 0.40, b = 0.00 },
	Poison  = { r = 0.00, g = 0.60, b = 0.00 },
}

local defaults = { profile = {
	Locked				= false,
	HideBlizzard		= true,
	HealthFormat		= 'percent',
	HideMaxHealth		= false,
	Invert 				= false,
	Scale				= 1,
	FrameWidth			= 90,
	HealthBarHeight		= 12,
	PowerBarHeight		= 4,
	FontSize			= 10,
	AuraIconSize		= 13,
	ShowClassIcon		= true,
	ShowTankIcons		= true,
	ShowLeaderIcon		= true,
	ShowPartyPortrait	= true,
	Border				= true,
	Texture				= "Otravi",
	BuffType			= "both",
	ShowOnlyDispellable	= true,
	NameFormat			= "full",
	ShowPriestBuffs		= true,
	PriestBuffFilter	= "class",
	DispelIconBorder	= true,
	ShowBossDebuffs		= true,
	DBMWarningDuration	= 6,
	BossWhitelist		= {},
	ShowInParty			= true,
	ShowSelfInParty		= false,
	PartyGrowth			= "down",
	BackgroundColor		= {r = 0.22, g = 0.35, b = 0.50, a = 0.92},
	classspelltable 	= {['*'] = {IsFiltered = false}},
	BorderColor			= {r = 1, g = 1, b = 1, a = 1},
	HealthTextColor		= {r = 1, g = 1, b = 1, a = 1},
	HealthBarColorByClass = false,
	HealthFrequentUpdates = true,
	Growth				= {["default"] = "down"},
	Spacing				= 0,
	PartySpacing		= 8,
	PartySortOrder		= "tank_dps_healer",
	PartyPetMode		= "attached",
	RaidPetMode			= "attached",
	ShowPetBuffs		= true,
	ShowGroupTitles		= true,
	UnitTooltipMethod	= "notincombat",
	BuffTooltipMethod 	= "always",
	DebuffTooltipMethod = "always",
	UnitTooltipType		= "ctra",
	BorderTexture		= "Blizzard Tooltip",
	BuffFilter			= {},
	BuffDisplayOptions	= {},
	DebuffFilter		= {},
	DebuffWhitelist		= {},
	PowerFilter			= {
		[Compat.POWER_MANA] = true,
		[Compat.POWER_RAGE] = false,
		[Compat.POWER_FOCUS] = false,
		[Compat.POWER_ENERGY] = false,
		[Compat.POWER_RUNIC_POWER] = false,
	},
	RangeCheck 			= true,
	RangeLimit			= 38,
	RangeFrequency		= 0.2,
	RangeAlpha 			= 0.5,
	ReadyCheck			= true,
	AggroCheck			= true,
	HighlightTarget		= true,
	HighlightHeals		= true,
	ShowHealPrediction	= true,
	HighlightDebuffs 	= "onlyself",
	Layout				= "CTRA_WithBorders",
	GroupSetup			= L["By group"],
	GroupSetups			= {},
	Positions			= { ['*'] = {} },
	StatusMaps			= {},
	HideInArena			= true,
	Show				= true,
	BuffDisplay			= {default="own"},
	minimapIcon 		= { hide = false },
	VehicleSwitch		= true,
	VehiclePower		= true,
	VehicleStatus		= false,
	debufftimer			= {max=30, show=true},
	bufftimer			= {max=30, show=true},
}}

sRaidFrames.CONFIG_VERSION = 3

function sRaidFrames:OnInitialize()
	-- convert Ace2 -> Ace3 config
	if sRaidFramesDB and sRaidFramesDB.currentProfile then
		if not sRaidFramesDB.profileKeys then
			sRaidFramesDB.profileKeys = {}
		end
		for k, v in pairs(sRaidFramesDB.currentProfile) do
			local new_value = v
			if v == "char" then
				new_value = k
			end
			sRaidFramesDB.profileKeys[k] = new_value
		end
		sRaidFramesDB.currentProfile = nil

		for key, data in pairs(sRaidFramesDB.profiles) do
			if key:find("^char/") then
				local new_key = key:match("^char/(.+)")
				sRaidFramesDB.profiles[new_key] = data
				sRaidFramesDB.profiles[key] = nil
			end
		end
	end

	local optFunc = function()
		LibStub("AceConfigDialog-3.0"):Open("sRaidFrames")
	end
	self:RegisterChatCommand("srf", optFunc)

	self.db = LibStub("AceDB-3.0"):New("sRaidFramesDB", defaults)
	self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileEnable")
	self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileEnable")
	self.db.RegisterCallback(self, "OnProfileReset", "OnProfileEnable")

	sRaidFrames.options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	sRaidFrames.options.args.profiles.order = 1000
	LibStub("AceConfig-3.0"):RegisterOptionsTable("sRaidFrames", sRaidFrames.options)

	-- Upgrade Config
	local cv = self.db.profile.configVersion or 0

	if cv < 1 then
		for k,v in pairs(self.db.profile.StatusMaps) do
			if k:find("^Buff_") then
				self.db.profile.StatusMaps[k] = nil
			end
		end
	end

	if cv < 2 then
		for k,v in pairs(self.db.profile.StatusMaps) do
			if not v.options then
				v.options = {}
			end
		end
	end

	if cv < 3 then
		self.db.profile.ShowPriestBuffs = true
		self.db.profile.ShowBossDebuffs = true
		self.db.profile.DispelIconBorder = true
		self.db.profile.NameFormat = self.db.profile.NameFormat or "full"
		if self.db.profile.ShowOnlyDispellable == 1 then
			self.db.profile.ShowOnlyDispellable = true
		end
		if self.db.profile.BuffType == "debuffs" then
			self.db.profile.BuffType = "both"
		end
	end

	self.db.profile.configVersion = sRaidFrames.CONFIG_VERSION

	self.opt = self.db.profile

	-- Init variables
	self.enabled = false
	self.frames, self.groupframes = {}, {}
	self.res, self.RangeChecks = {}, {}
	self.FramesByUnit = {}
	self.statusstate = {}
	self.statusElements = {}
	self.validateStatusElements = {}
	self.vehicleUpdate = {}
	self.unitClassCache = {}
	self.dbmWarnings = {}
	self.dbmTimerMap = {}

	if self.opt.BuffBlacklist then
		for i, k in pairs(self.opt.BuffBlacklist) do
			if k then
				self.opt.BuffDisplayOptions[strlower(i)] = 0
				self.opt.BuffBlacklist[i] = nil
			end
		end
		self.opt.BuffBlacklist = nil
	end
	if type(self.opt.BuffDisplay) ~= "table" then
		self.opt.BuffDisplay = {default=self.opt.BuffDisplay}
	end
	if self.opt.CombatBuffBlacklist then
		for i, k in pairs(self.opt.CombatBuffBlacklist) do
			if k then
				self.opt.BuffDisplayOptions[strlower(i)] = 2
				self.opt.CombatBuffBlacklist[i] = nil
			end
		end
		self.opt.CombatBuffBlacklist = nil
	end
	for i, k in pairs(self.opt.BuffFilter) do
		if i ~= strlower(i) then
			self.opt.BuffFilter[strlower(i)] = k
			self.opt.BuffFilter[i] = nil
		end
	end
	if self.opt.Growth and not self.opt.Growth["default"] then
		local growth = self.opt.Growth
		self.opt.Growth = {}
		self.opt.Growth["default"] = growth
	end

	self.cooldownSpells = {}
	self.cooldownSpells["WARLOCK"] = SpellCache[20707] -- Soulstone Resurrection
	self.cooldownSpells["DRUID"] = SpellCache[20484] -- Rebirth
	self.cooldownSpells["SHAMAN"] = SpellCache[20608] -- Reincarnation

	self.dispellers = {["PRIEST"]=true, ["SHAMAN"]=true, ["PALADIN"]=true, ["MONK"]=true, ["DRUID"]=true, ["MAGE"]=true}
	self.cleanseTypes = {}

	local statusSpellTable = {
		[35079] = 35079, -- Misdirection
		[5384]  = 5384,  -- Feign Death
		[3411]  = 3411,  -- Intervene
		[20711] = 20711, -- Spirit of Redemption
		[27827] = 20711, -- Spirit of Redemption
		[871]   = 871,   -- Shield Wall
		[1277424] = 871, -- Shield Wall (Forever)
		[12975] = 12975, -- Last Stand
		[45438] = 45438, -- Ice Block
		[11958] = 45438, -- Ice Block (Classic)
		[27619] = 45438, -- Ice Block (Classic)
		[40733] = 40733, -- Divine Shield
		[642]   = 40733, -- Divine Shield (Classic)
		[1020]  = 40733, -- Divine Shield (Classic)
		[1856]  = 1856,  -- Vanish
		[39666] = 39666, -- Cloak of Shadows
		[462873] = 39666, -- Cloak of Shadows (Forever)
		[66]    = 66,    -- Invisibility
		[1784]  = 1784,  -- Stealth
		[38541] = 38541, -- Evasion
		[5277]  = 38541, -- Evasion (Classic)
		[10060] = 10060, -- Power Infusion
		[32182] = 32182, -- Heroism
		[2825]  = 2825,  -- Bloodlust
		[6346]  = 6346,  -- Fear Ward
		[459699] = 6346, -- Fear Ward (Forever)
		[15473] = 15473, -- Shadowform
		[498]   = 498,   -- Divine Protection
		[5573]  = 498,   -- Divine Protection
		[1022]  = 1022,  -- Blessing / Hand of Protection
		[5599]  = 1022,  -- Blessing of Protection
		[10278] = 1022,  -- Blessing of Protection
		[442948] = 1022, -- Blessing of Protection (Forever)
		[22812] = 22812, -- Barkskin
		[20655] = 22812, -- Barkskin (Forever)
		[428713] = 22812, -- Barkskin (Forever)
		[1289128] = 22812, -- Barkskin (Forever)
		[33206] = 33206, -- Pain Suppression
		[402004] = 33206, -- Pain Suppression (Forever)
		[402839] = 33206, -- Pain Suppression (Forever)
		[61336] = 61336, -- Survival Instincts
		[55233] = 55233, -- Vampiric Blood
		[48792] = 48792, -- Icebound Fortitude
		[48707] = 48707, -- Anti-Magic Shell
		[47788] = 47788, -- Guardian Spirit
	}
	self.statusSpellTable = {}
	self.statusSpellByID = {}
	for spellID, canonicalID in pairs(statusSpellTable) do
		self.statusSpellByID[spellID] = canonicalID
		local spell = SpellCache[spellID]
		if spell then
			self.statusSpellTable[spell] = canonicalID
		end
	end
	if sRaidFramesDB.classspelltable then
		self.opt.classspelltable = sRaidFramesDB.classspelltable
		sRaidFramesDB.classspelltable = nil
	end
	if not sRaidFramesDB.CustomStatuses then
		sRaidFramesDB.CustomStatuses = {}
	end
	for c in pairs(sRaidFramesDB.CustomStatuses) do
		local spell = SpellCache[c]
		if spell then
			self.statusSpellTable[spell] = c
			self.statusSpellByID[c] = c
		else
			sRaidFramesDB.CustomStatuses[c] = nil
		end
	end

	self.specMap = {
		[0] = "unknown",
		[250] = "tank", [251] = "melee", [252] = "melee",
		[102] = "caster", [103] = "melee", [104] = "tank", [105] = "healer",
		[268] = "tank", [269] = "melee", [270] = "healer",
		[65] = "healer", [66] = "tank", [70] = "melee",
		[256] = "healer", [257] = "healer", [258] = "caster",
		[262] = "caster", [263] = "melee", [264] = "healer",
		[71] = "melee", [72] = "melee", [73] = "tank",
	}

	-- Boss & DBM skill warnings (highest priority alerts)
	self:AddStatusMap("BossWarning", 90, {"border", "statusbar"}, L["! BOSS SKILL !"], {r = 1, g = 0.15, b = 0, a = 1})
	self:AddStatusMap("BossDebuff", 68, {"border", "statusbar"}, L["Boss Debuff"], {r = 1, g = 0.35, b = 0, a = 1})

	self:AddStatusMap("ReadyCheck_Pending", 80, {"background"}, L["Ready?"], {r = 0.1, g = 0.1, b = 0.1})
	self:AddStatusMap("ReadyCheck_Ready", 80, {"background"}, L["Ready!"], {r = 0, g = 0.6, b = 0, a = 0.8})
	self:AddStatusMap("ReadyCheck_NotReady", 80, {"background"}, L["Not Ready"], {r = 0.7, g = 0, b = 0, a = 0.8})

	self:AddStatusMap("Death", 70, {"background"}, L["Dead"], {r = 0.1, g = 0.1, b = 0.1, a = 1})

	-- Spirit of Redemption
	self:AddStatusMap("Buff_20711", 65, {"statusbar"}, L["Dead"], {r=1,g=0,b=0,a=1})

	self:AddStatusMap("Aggro", 50, {"border"}, L["Aggro"], {r = 1, g = 0, b = 0})
	self:AddStatusMap("Target", 55, {"border"}, L["Target"], {r = 1, g = 0.75, b = 0})
	self:AddStatusMap("Raid Icon: Star", 60, {"statusbar"}, L["Star"], {r = 1, g=1, b=0}, true)
	self:AddStatusMap("Raid Icon: Circle", 60, {"statusbar"}, L["Circle"], {r = 1, g=0.5, b=0,a=1}, true)
	self:AddStatusMap("Raid Icon: Diamond", 60, {"statusbar"}, L["Diamond"], {r = 1, g=0, b=1,a=1}, true)
	self:AddStatusMap("Raid Icon: Triangle", 60, {"statusbar"}, L["Triangle"], {r=0, g=1, b=0,a=1}, true)
	self:AddStatusMap("Raid Icon: Moon", 60, {"statusbar"}, L["Moon"], {r=1, g=1, b=1,a =1}, true)
	self:AddStatusMap("Raid Icon: Square", 60, {"statusbar"}, L["Square"], {r=0.4156862745098, g=0.8078431372549, b=0.96470588235294, a=1}, true)
	self:AddStatusMap("Raid Icon: Cross", 60, {"statusbar"}, L["Cross"], {r=1, g=0, b=0, a=1}, true)
	self:AddStatusMap("Raid Icon: Skull", 60, {"statusbar"}, L["Skull"], {r=1, g=1, b=1, a=1}, true)

	self:AddStatusMap("Debuff_Curse", 55, {"background"}, L["Cursed"], {r=1, g=0, b=0.75, a=0.5})
	self:AddStatusMap("Debuff_Magic", 54, {"background"}, L["Magic"], {r=1, g=0, b=0, a=0.5})
	self:AddStatusMap("Debuff_Disease", 53, {"background"}, L["Diseased"], {r=1, g=1, b=0, a=0.5})
	self:AddStatusMap("Debuff_Poison", 52, {"background"}, L["Poisoned"], {r=0, g=0.5, b=0, a=0.5})

	-- Shield Wall
	self:AddStatusMap("Buff_871", 53, {"statusbar"}, SpellCache[871] or "Shield Wall", {r=1,g=1,b=1,a=1})
	-- Last Stand
	self:AddStatusMap("Buff_12975", 52, {"statusbar"}, SpellCache[12975] or "Last Stand", {r=1,g=1,b=1,a=1})
	-- Vanish
	self:AddStatusMap("Buff_1856", 51, {"statusbar"}, L["Vanished"], {r=0,g=1,b=0,a=1})
	-- Invisibility
	self:AddStatusMap("Buff_66", 51, {"statusbar"}, SpellCache[66] or "Invisibility", {r=0,g=1,b=0,a=1})
	-- Evasion
	self:AddStatusMap("Buff_38541", 50, {"statusbar"}, SpellCache[5277] or SpellCache[38541] or "Evasion", {r=1,g=1,b=0,a=1})
	-- Stealth
	self:AddStatusMap("Buff_1784", 50, {"statusbar"}, L["Stealthed"], {r=1,g=1,b=1,a=1})
	-- Ice Block
	self:AddStatusMap("Buff_45438", 50, {"statusbar"}, SpellCache[11958] or SpellCache[45438] or "Ice Block", {r=1,g=1,b=1,a=1})
	-- Divine Protection
	self:AddStatusMap("Buff_498", 53, {"statusbar"}, SpellCache[498] or "Divine Protection", {r=1,g=1,b=1,a=1})
	-- Hand / Blessing of Protection
	self:AddStatusMap("Buff_1022", 53, {"statusbar"}, L["Protection"], {r=1,g=1,b=1,a=1})
	-- Barkskin
	self:AddStatusMap("Buff_22812", 52, {"statusbar"}, SpellCache[22812] or "Barkskin", {r=1,g=1,b=1,a=1})
	-- Pain Suppression
	self:AddStatusMap("Buff_33206", 53, {"statusbar"}, SpellCache[402004] or SpellCache[33206] or "Pain Suppression", {r=1,g=1,b=1,a=1})
	-- Anti-Magic Shell
	self:AddStatusMap("Buff_48707", 52, {"statusbar"}, SpellCache[48707] or "Anti-Magic Shell", {r=1,g=1,b=1,a=1})
	-- Icebound Fortitude
	self:AddStatusMap("Buff_48792", 53, {"statusbar"}, L["IBF"], {r=1,g=1,b=1,a=1})
	-- Vampiric Blood
	self:AddStatusMap("Buff_55233", 52, {"statusbar"}, SpellCache[55233] or "Vampiric Blood", {r=1,g=1,b=1,a=1})
	-- Survival Instincts
	self:AddStatusMap("Buff_61336", 52, {"statusbar"}, SpellCache[61336] or "Survival Instincts", {r=1,g=1,b=1,a=1})
	-- Guardian Spirit
	self:AddStatusMap("Buff_47788", 53, {"statusbar"}, L["Guardian"], {r=1,g=1,b=1,a=1})

	-- Feign Death
	self:AddStatusMap("Buff_5384", 50, {"statusbar"}, SpellCache[5384] or "Feign Death", {r=0,g=1,b=0,a=1})
	-- Cloak of Shadows
	self:AddStatusMap("Buff_39666", 50, {"statusbar"}, SpellCache[462873] or SpellCache[39666] or "Cloak of Shadows", {r=1,g=1,b=1,a=1})
	-- Divine Shield
	self:AddStatusMap("Buff_40733", 50, {"statusbar"}, SpellCache[642] or SpellCache[40733] or "Divine Shield", {r=1,g=1,b=1,a=1})
	-- Power Infusion
	self:AddStatusMap("Buff_10060", 50, {"statusbar"}, L["Infused"], {r=1,g=1,b=1,a=1})

	-- Misdirection
	self:AddStatusMap("Buff_35079", 45, {"statusbar"}, SpellCache[35079] or "Misdirection", {r=0,g=1,b=0,a=1})
	-- Intervene
	self:AddStatusMap("Buff_3411", 45, {"statusbar"}, SpellCache[3411] or "Intervene", {r=0,g=1,b=0,a=1})
	-- Fear Ward
	self:AddStatusMap("Buff_6346", 40, {"statusbar"}, SpellCache[6346] or "Fear Ward", {r=1,g=1,b=0,a=1})
	-- Heroism
	self:AddStatusMap("Buff_32182", 39, {"statusbar"}, SpellCache[32182] or "Heroism", {r=1,g=1,b=1,a=1})
	-- Bloodlust
	self:AddStatusMap("Buff_2825", 39, {"statusbar"}, SpellCache[2825] or "Bloodlust", {r=1,g=1,b=1,a=1})

	self:AddStatusMap("Heal", 36, {"statusbar"}, L["Inc. heal"], {r = 0, g = 1, b = 0})
	-- Shadowform
	self:AddStatusMap("Buff_15473", 35, {"statusbar"}, SpellCache[15473] or "Shadowform", {r=1,g=0,b=0.75,a=1})

	self:AddStatusMap("Vehicle", 56, {"statusbar"}, L["On Vehicle"], {r=1,g=1,b=1,a=1})

	self:RegisterStatusElement("border", L["Border"],
		function(self, frame, status)
			if status == nil then
				frame:SetBackdropBorderColor(self.opt.BorderColor.r, self.opt.BorderColor.g, self.opt.BorderColor.b, self.opt.BorderColor.a or 1)
			else
				frame:SetBackdropBorderColor(status.color.r, status.color.g, status.color.b, status.color.a or 1)
			end
		end
	)

	self:RegisterStatusElement("background", L["Background"],
		function(self, frame, status)
			if status == nil then
				frame:SetBackdropColor(self.opt.BackgroundColor.r, self.opt.BackgroundColor.g, self.opt.BackgroundColor.b, self.opt.BackgroundColor.a or 1)
			else
				frame:SetBackdropColor(status.color.r, status.color.g, status.color.b, status.color.a or 1)
			end
		end
	)

	self:RegisterStatusElement("statusbar", L["Status bar"],
		function(self, frame, status)
			if status == nil then
				frame.statustext:SetText(nil)
			else
				frame.statustext:SetText(status.text)
				frame.statustext:SetTextColor(status.color.r, status.color.g, status.color.b, status.color.a or 1)
			end
		end
	)

	self.master = CreateFrame("Frame", "sRaidFrame", UIParent)
	self.master:SetMovable(true)
	self.master:SetScale(self.opt.Scale)

	self.master:SetHeight(200)
	self.master:SetWidth(200)
	self:UpdateVisibilityDriver()

	self:DefaultGroupSetups()

	self:chatUpdateFilterMenu()
	self:chatUpdateBuffMenu()
	self:chatUpdateDebuffMenu()
	self:chatUpdateStatusElements()

	createLDBLauncher()
end

function sRaidFrames:ToggleVisibility()
	if privateFuncs.IsInCombat() or not self.opt then return end
	self.opt.Show = not self.opt.Show
	self:UpdateVisibilityDriver()
	self:HideBlizzard()
	self:UpdateRoster()
end

function sRaidFrames:UpdateVisibilityDriver()
	if privateFuncs.IsInCombat() then
		self:ScheduleLeaveCombatAction("UpdateVisibilityDriver")
		return
	end
	if not self.master then return end
	if not self.opt.Show then
		RegisterAttributeDriver(self.master, "state-visibility", "hide")
	elseif self.opt.ShowInParty then
		RegisterAttributeDriver(self.master, "state-visibility", "[group:raid][group:party]show;hide")
	else
		RegisterAttributeDriver(self.master, "state-visibility", "[group:raid]show;hide")
	end
end

function sRaidFrames:HideBlizzard()
	if privateFuncs.IsInCombat() then
		self:ScheduleLeaveCombatAction("HideBlizzard")
		return
	end
	local shouldHide = self.opt.HideBlizzard and self.opt.Show and not self._inEditMode
	self._blizzHidden = self._blizzHidden or {}

	local targets = {
		{ frame = _G.CompactRaidFrameContainer, hide = shouldHide },
		{ frame = _G.PartyFrame, hide = shouldHide and self.opt.ShowInParty },
	}

	for _, entry in ipairs(targets) do
		local f = entry.frame
		if f and not (f.IsForbidden and f:IsForbidden()) then
			if entry.hide then
				if not self._blizzHidden[f] then
					self._blizzHidden[f] = true
					pcall(RegisterStateDriver, f, "visibility", "hide")
					pcall(f.Hide, f)
				end
			elseif self._blizzHidden[f] then
				self._blizzHidden[f] = nil
				pcall(UnregisterStateDriver, f, "visibility")
				if f.UpdateSystemSettingPosition then
					pcall(f.UpdateSystemSettingPosition, f)
				end
			end
		end
	end
end

function sRaidFrames:AddExternalStatusMap(name)
	if strmatch(name, "Buff_%d+") ~= name and strmatch(name, "%d+") ~= name then print(L["Invalid name specified"]); return end
	local id = strmatch(name, "%d+")
	local buff
	if id == name then
		buff = "Buff_"..name
	else
		buff = name
	end
	id = tonumber(id)
	if SpellCache[id] then
		self.statusSpellTable[SpellCache[id]] = id
	end
	self.statusSpellByID[id] = id
	self:AddStatusMap(buff, 0, {"background"}, SpellCache[id] or ("Spell #"..id), {r=0, g=0, b=0, a=0})
	if not sRaidFramesDB.CustomStatuses then
		sRaidFramesDB.CustomStatuses = {}
	end
	sRaidFramesDB.CustomStatuses[id] = true
	for unit in pairs(self:GetAllUnits()) do
		self:UpdateAuras(unit)
	end
end

function sRaidFrames:RemoveExternalStatusMap(id)
	local name = "Buff_"..tonumber(id)
	for unit in pairs(self:GetAllUnits()) do
		self:UnsetStatus(unit, name)
	end

	self.options.args.advanced.args[name] = nil
	self.opt.StatusMaps[name] = nil
	if not sRaidFramesDB.CustomStatuses then
		sRaidFramesDB.CustomStatuses = {}
	end
	sRaidFramesDB.CustomStatuses[id] = nil
end

function sRaidFrames:ScheduleLeaveCombatAction(callback, arg1)
	if not privateFuncs.IsInCombat() then
		self[callback](self, arg1)
		return
	end
	if not self.leaveCombatActions then self.leaveCombatActions = {} end
	for _, entry in ipairs(self.leaveCombatActions) do
		if entry.callback == callback and entry.arg == arg1 then
			return
		end
	end
	tinsert(self.leaveCombatActions, {callback = callback, arg = arg1})
end

function sRaidFrames:PLAYER_REGEN_ENABLED()
	self.InCombat = false
	for unit in pairs(self:GetAllUnits()) do
		self:UpdateAuras(unit)
	end
	local queue = self.leaveCombatActions
	if not queue then return end
	self.leaveCombatActions = nil
	for _, info in ipairs(queue) do
		if info.callback and self[info.callback] then
			self[info.callback](self, info.arg)
		end
	end
end

function sRaidFrames:PLAYER_REGEN_DISABLED()
	self.InCombat = true
	for unit in pairs(self:GetAllUnits()) do
		self:UpdateAuras(unit)
	end
end

StaticPopupDialogs["SRAIDFRAMES_PROFILE"] = {
	text = L["After changing the Profile it is required that you reload the UI to apply the new settings.\n Do you want reload the UI now?"],
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		ReloadUI()
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 0,
}

function sRaidFrames:OnProfileEnable()
	self.opt = self.db.profile
	self:DefaultGroupSetups()
	StaticPopup_Show("SRAIDFRAMES_PROFILE")
end

function sRaidFrames:OnEnable()
	if CUSTOM_CLASS_COLORS then
		RAID_CLASS_COLORS = CUSTOM_CLASS_COLORS
	end

	self.PlayerClass = select(2, UnitClass("player"))
	self.Dispeller = self.dispellers[self.PlayerClass]

	if self.Dispeller then
		self:UpdateCleanseTypes()
		self:RegisterEvent("PLAYER_LEVEL_UP", "UpdateCleanseTypes")
		pcall(self.RegisterEvent, self, "ACTIVE_TALENT_GROUP_CHANGED", "UpdateCleanseTypes")
		pcall(self.RegisterEvent, self, "LEARNED_SPELL_IN_TAB", "UpdateCleanseTypes")
	end

	self:InitRangeChecks()
	pcall(self.RegisterEvent, self, "PLAYER_TALENT_UPDATE", "InitRangeChecks")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "InitRangeChecks")

	self:RegisterBucketEvent("SPELLS_CHANGED", 0.2)
	self:RegisterBucketEvent("GROUP_ROSTER_UPDATE", 0.2, "UpdateRoster")
	pcall(self.RegisterEvent, self, "PARTY_LEADER_CHANGED", "UpdateAllUnits")
	pcall(self.RegisterEvent, self, "PLAYER_ROLES_ASSIGNED", "UpdateAllUnits")
	pcall(self.RegisterEvent, self, "UNIT_PORTRAIT_UPDATE", "UpdateUnitPortraitEvent")
	pcall(self.RegisterEvent, self, "UNIT_MODEL_CHANGED", "UpdateUnitPortraitEvent")
	pcall(self.RegisterEvent, self, "UNIT_LEVEL", "OnUnitLevelUpdate")
	pcall(self.RegisterEvent, self, "VOICE_START", "UpdateUnitVoiceEvent")
	pcall(self.RegisterEvent, self, "VOICE_STOP", "UpdateUnitVoiceEvent")
	pcall(self.RegisterEvent, self, "VOICE_CHAT_CHANNEL_MEMBER_SPEAKING_STATE_CHANGED", "UpdateVoiceChatMemberSpeaking")
	Media.RegisterCallback(self, "LibSharedMedia_SetGlobal")

	self:InitDBMIntegration()

	self:CreateFrames()
	self:UpdateRoster()
	self:ToggleFrequentUpdates()

	self:HideBlizzard()

	if _G.EditModeManagerFrame and not self._editModeHooked then
		self._editModeHooked = true
		_G.EditModeManagerFrame:HookScript("OnShow", function()
			self._inEditMode = true
			self:HideBlizzard()
		end)
		_G.EditModeManagerFrame:HookScript("OnHide", function()
			self._inEditMode = false
			self:HideBlizzard()
		end)
	end
end

function sRaidFrames:SPELLS_CHANGED()
	if self.Dispeller then
		self:UpdateCleanseTypes()
	end
	self:InitRangeChecks()
end

function sRaidFrames:UpdateCleanseTypes()
	local pClass = self.PlayerClass
	local pLevel = UnitLevel("player") or 60
	if IsSecret(pLevel) then pLevel = 60 end

	-- Supports Classic 60 / Turtle WoW / WoW: Forever (1.60.x / 16001)
	if pClass == "PRIEST" then
		-- Dispel Magic (527 / 988) learned at lvl 18; Cure Disease (528) & Abolish Disease (552) at lvl 14
		self.cleanseTypes["Magic"]   = Compat.IsSpellKnown(527) or Compat.IsSpellKnown(988) or pLevel >= 18
		self.cleanseTypes["Disease"] = Compat.IsSpellKnown(528) or Compat.IsSpellKnown(552) or pLevel >= 14
		self.cleanseTypes["Poison"]  = false
		self.cleanseTypes["Curse"]   = false
	elseif pClass == "PALADIN" then
		-- Purify (1152) at lvl 8 (Disease/Poison), Cleanse (4987) at lvl 42 (Disease/Poison/Magic)
		self.cleanseTypes["Disease"] = Compat.IsSpellKnown(1152) or Compat.IsSpellKnown(4987) or pLevel >= 8
		self.cleanseTypes["Poison"]  = Compat.IsSpellKnown(1152) or Compat.IsSpellKnown(4987) or pLevel >= 8
		self.cleanseTypes["Magic"]   = Compat.IsSpellKnown(4987) or pLevel >= 42
		self.cleanseTypes["Curse"]   = false
	elseif pClass == "SHAMAN" then
		-- Cure Poison (526) at 16, Cure Disease (2870) at 22, Cleanse Spirit (51886)
		self.cleanseTypes["Poison"]  = Compat.IsSpellKnown(526) or Compat.IsSpellKnown(8166) or pLevel >= 16
		self.cleanseTypes["Disease"] = Compat.IsSpellKnown(2870) or Compat.IsSpellKnown(8170) or pLevel >= 22
		self.cleanseTypes["Curse"]   = Compat.IsSpellKnown(51886) or false
		self.cleanseTypes["Magic"]   = false
	elseif pClass == "DRUID" then
		-- Cure Poison (8946) / Abolish Poison (2893) at 14, Remove Curse (2782) at 24
		self.cleanseTypes["Poison"]  = Compat.IsSpellKnown(8946) or Compat.IsSpellKnown(2893) or pLevel >= 14
		self.cleanseTypes["Curse"]   = Compat.IsSpellKnown(2782) or pLevel >= 24
		self.cleanseTypes["Magic"]   = false
		self.cleanseTypes["Disease"] = false
	elseif pClass == "MAGE" then
		-- Remove Lesser Curse (475) at 18
		self.cleanseTypes["Curse"]   = Compat.IsSpellKnown(475) or pLevel >= 18
		self.cleanseTypes["Magic"]   = false
		self.cleanseTypes["Poison"]  = false
		self.cleanseTypes["Disease"] = false
	elseif pClass == "MONK" then
		self.cleanseTypes["Magic"]   = pLevel >= 20
		self.cleanseTypes["Disease"] = pLevel >= 20
		self.cleanseTypes["Poison"]  = pLevel >= 20
	end
end

function sRaidFrames:InitRangeChecks()
	self.RangeChecks = {}

	self:AddRangeFunction(10, function(unit)
		if not CheckInteractDistance then return UnitInRange(unit) end
		local ok, res = pcall(CheckInteractDistance, unit, 3)
		if ok and not IsSecret(res) then return (res == true or res == 1) end
		return UnitInRange(unit)
	end)
	self:AddRangeFunction(28, function(unit)
		if not CheckInteractDistance then return UnitInRange(unit) end
		local ok, res = pcall(CheckInteractDistance, unit, 4)
		if ok and not IsSecret(res) then return (res == true or res == 1) end
		return UnitInRange(unit)
	end)
	self:AddRangeFunction(38, function(unit)
		return UnitInRange(unit)
	end)
	self:AddRangeFunction(100, function(unit)
		local ok, vis = pcall(UnitIsVisible, unit)
		if ok and not IsSecret(vis) then return (vis == true or vis == 1) end
		return vis
	end)

	self:ScanSpellbookForRange()
end

local EventsHealth = {"UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_FLAGS", "UNIT_CONNECTION"}
local EventsPower = {"UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER"}

function sRaidFrames:UpdateRaidTargets()
	for unit in pairs(sRaidFrames:GetAllUnits()) do
		sRaidFrames:UpdateAuras(unit)
	end
end

local ShouldUpdateFrameCache = false

function sRaidFrames:EnableFrames()
	self.enabled = true
	self.statusstate = {}
	ShouldUpdateFrameCache = true

	local isEventValid = _G.C_EventUtils and _G.C_EventUtils.IsEventValid
	self.healthBucket = self:RegisterBucketEvent(EventsHealth, 0.05, "UNIT_HEALTH")
	if not isEventValid or isEventValid("UNIT_HEALTH_FREQUENT") then
		pcall(function()
			self.healthFreqBucket = self:RegisterBucketEvent("UNIT_HEALTH_FREQUENT", 0.05, "UNIT_HEALTH")
		end)
	end
	self.powerBucket = self:RegisterBucketEvent(EventsPower, 0.3, "UNIT_POWER")
	if not isEventValid or isEventValid("UNIT_POWER") then
		pcall(function()
			self.legacyPowerBucket = self:RegisterBucketEvent("UNIT_POWER", 0.3, "UNIT_POWER")
		end)
	end
	self.auraBucket = self:RegisterBucketEvent("UNIT_AURA", 0.15)

	self:RegisterEvent("PLAYER_TARGET_CHANGED", "UpdateTarget")

	pcall(self.RegisterEvent, self, "UNIT_ENTERED_VEHICLE", "UpdateVehicle")
	pcall(self.RegisterEvent, self, "UNIT_EXITED_VEHICLE", "UpdateVehicle")
	self:RegisterEvent("RAID_TARGET_UPDATE", "UpdateRaidTargets")

	pcall(self.RegisterEvent, self, "UNIT_HEAL_PREDICTION", "UpdateHealsOnUnit")
	pcall(self.RegisterEvent, self, "UNIT_THREAT_SITUATION_UPDATE", "UpdateUnitThreat")
	pcall(self.RegisterEvent, self, "UNIT_SPELLCAST_START", "OnUnitSpellcastStart")
	pcall(self.RegisterEvent, self, "UNIT_SPELLCAST_CHANNEL_START", "OnUnitSpellcastStart")
	pcall(self.RegisterEvent, self, "UNIT_NAME_UPDATE", "OnUnitNameUpdate")
	pcall(self.RegisterEvent, self, "UNIT_PET", "OnUnitPet")

	if ResInfo then
		ResInfo.RegisterCallback(self, "LibResInfo_ResPending", "ResInfo_CanRes")
		ResInfo.RegisterCallback(self, "LibResInfo_ResCastStarted", "ResInfo_ResStart")
		ResInfo.RegisterCallback(self, "LibResInfo_ResCastFinished", "ResInfo_ResEnd")
		ResInfo.RegisterCallback(self, "LibResInfo_ResExpired", "ResInfo_ResEnd")
		ResInfo.RegisterCallback(self, "LibResInfo_ResCastCancelled", "ResInfo_ResEnd")
		ResInfo.RegisterCallback(self, "LibResInfo_ResUsed", "ResInfo_Ressed")
	end

	if Banzai and not _G.UnitThreatSituation then
		Banzai:RegisterCallback(sRaidFrames.Banzai_Callback)
	end

	if LGIST then
		LGIST.RegisterCallback(self, "GroupInSpecT_Update", "LGIST_Update")
		LGIST.RegisterCallback(self, "GroupInSpecT_Remove", "LGIST_Update")
	end

	self:RegisterEvent("READY_CHECK")
	self:RegisterEvent("READY_CHECK_CONFIRM")
	self:RegisterEvent("READY_CHECK_FINISHED")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")

	self.rangeTimer = self:ScheduleRepeatingTimer("RangeCheck", self.opt.RangeFrequency)

	if self.master and not self._masterOnShowHooked then
		self._masterOnShowHooked = true
		self.master:HookScript("OnShow", function()
			for _, gf in pairs(sRaidFrames.groupframes) do
				if gf.header then
					sRaidFrames:UpdateTitleVisibility(gf.header)
				end
			end
			if sRaidFrames.petGroup and sRaidFrames.petGroup.header then
				sRaidFrames:UpdateTitleVisibility(sRaidFrames.petGroup.header)
			end
		end)
	end

	for _, gf in pairs(self.groupframes) do
		if gf.header then self:UpdateTitleVisibility(gf.header) end
	end
end

function sRaidFrames:DisableFrames()
	if not self.enabled then return end
	self.statusstate = {}
	self.FramesByUnit = {}
	ShouldUpdateFrameCache = true

	if self.healthBucket then self:UnregisterBucket(self.healthBucket); self.healthBucket = nil end
	if self.healthFreqBucket then self:UnregisterBucket(self.healthFreqBucket); self.healthFreqBucket = nil end
	if self.powerBucket then self:UnregisterBucket(self.powerBucket); self.powerBucket = nil end
	if self.legacyPowerBucket then self:UnregisterBucket(self.legacyPowerBucket); self.legacyPowerBucket = nil end
	if self.auraBucket then self:UnregisterBucket(self.auraBucket); self.auraBucket = nil end

	self:UnregisterEvent("PLAYER_TARGET_CHANGED")

	pcall(self.UnregisterEvent, self, "UNIT_ENTERED_VEHICLE")
	pcall(self.UnregisterEvent, self, "UNIT_EXITED_VEHICLE")
	self:UnregisterEvent("RAID_TARGET_UPDATE")

	pcall(self.UnregisterEvent, self, "UNIT_HEAL_PREDICTION")
	pcall(self.UnregisterEvent, self, "UNIT_THREAT_SITUATION_UPDATE")
	pcall(self.UnregisterEvent, self, "UNIT_SPELLCAST_START")
	pcall(self.UnregisterEvent, self, "UNIT_SPELLCAST_CHANNEL_START")
	pcall(self.UnregisterEvent, self, "UNIT_NAME_UPDATE")
	pcall(self.UnregisterEvent, self, "UNIT_PET")

	self:UnregisterEvent("READY_CHECK")
	self:UnregisterEvent("READY_CHECK_CONFIRM")
	self:UnregisterEvent("READY_CHECK_FINISHED")
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	self:UnregisterEvent("PLAYER_REGEN_DISABLED")

	if Banzai and not _G.UnitThreatSituation then
		Banzai:UnregisterCallback(sRaidFrames.Banzai_Callback)
	end

	if self.rangeTimer then
		self:CancelTimer(self.rangeTimer)
		self.rangeTimer = nil
	end

	if ResInfo then
		ResInfo.UnregisterCallback(self, "LibResInfo_ResPending")
		ResInfo.UnregisterCallback(self, "LibResInfo_ResCastStarted")
		ResInfo.UnregisterCallback(self, "LibResInfo_ResCastFinished")
		ResInfo.UnregisterCallback(self, "LibResInfo_ResExpired")
		ResInfo.UnregisterCallback(self, "LibResInfo_ResCastCancelled")
		ResInfo.UnregisterCallback(self, "LibResInfo_ResUsed")
	end

	if LGIST then
		LGIST.UnregisterCallback(self, "GroupInSpecT_Update")
		LGIST.UnregisterCallback(self, "GroupInSpecT_Remove")
	end

	self.enabled = false
end

function sRaidFrames:ToggleFrequentUpdates()
	if self.opt.HealthFrequentUpdates then
		self.master:SetScript("OnUpdate", function(_, elapsed) sRaidFrames:FrequentHealthUpdate(elapsed) end)
	else
		self.master:SetScript("OnUpdate", nil)
	end
end

function sRaidFrames:LibSharedMedia_SetGlobal(mediatype, handle)
	if mediatype == "statusbar" then
		local texture = Media:Fetch("statusbar", handle)
		for _, frame in pairs(self.frames) do
			frame.hpbar:SetStatusBarTexture(texture)
			frame.mpbar:SetStatusBarTexture(texture)
			if frame.healbar then frame.healbar:SetStatusBarTexture(texture) end
			if frame.petframe then
				if frame.petframe.hpbar then frame.petframe.hpbar:SetStatusBarTexture(texture) end
				if frame.petframe.healbar then frame.petframe.healbar:SetStatusBarTexture(texture) end
			end
		end
	end
end

function sRaidFrames:ScanSpellbookForRange()
	local classHealSpells = {
		["PRIEST"]  = {2061, 2050, 139, 17, 527},   -- Flash Heal, Lesser Heal, Renew, PW:S, Dispel Magic
		["PALADIN"] = {19750, 635, 1152, 4987},     -- Flash of Light, Holy Light, Purify, Cleanse
		["DRUID"]   = {774, 5185, 8936, 2782},      -- Rejuvenation, Healing Touch, Regrowth, Remove Curse
		["SHAMAN"]  = {331, 8004, 1064, 526},       -- Healing Wave, Lesser Healing Wave, Chain Heal, Cure Poison
		["MAGE"]    = {475, 1459},                  -- Remove Lesser Curse, Arcane Intellect
	}
	local list = classHealSpells[self.PlayerClass]
	if list then
		for _, spellID in ipairs(list) do
			local name, _, _, _, _, maxRange = GetSpellInfo(spellID)
			if name and maxRange and maxRange > 0 then
				local r = tonumber(maxRange)
				if r and r > 0 and Compat.IsSpellKnown(spellID) then
					self:AddRangeFunction(r, function(unit)
						local inRange = Compat.IsSpellInRange(name, unit)
						if inRange == nil then inRange = Compat.IsSpellInRange(spellID, unit) end
						if inRange ~= nil then return inRange end
						return UnitInRange(unit)
					end)
				end
			end
		end
	end

	if _G.GetSpellTabInfo and _G.BOOKTYPE_SPELL then
		local ok, _, _, tabOffset, tabSlots = pcall(_G.GetSpellTabInfo, 2)
		if ok and tabOffset and tabSlots then
			for spellIdx = tabOffset + 1, tabSlots + tabOffset do
				local spellName = Compat.GetSpellName(spellIdx, _G.BOOKTYPE_SPELL)
				if not spellName then break end
				local _, _, _, _, _, maxRange = GetSpellInfo(spellName)
				if maxRange and maxRange > 0 and Compat.IsSpellInRange(spellName, "player") ~= nil then
					self:AddRangeFunction(tonumber(maxRange), function(unit)
						return Compat.IsSpellInRange(spellName, unit)
					end)
				end
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Roster & Dual-Name Lookup System
-------------------------------------------------------------------------------
do
	local roster, oldroster = { n = 0 }, {}
	local nameToUnit = {}
	local searchNames = {}
	local unitFullNames = {}

	local function AddSearchName(name, unit)
		if name and type(name) == "string" and name ~= "" then
			nameToUnit[name] = unit
			nameToUnit[strlower(name)] = unit
			searchNames[name] = unit
		end
	end

	local function IndexUnitNames(unit)
		local variants = Compat.GetUnitNameVariants(unit)
		for var in pairs(variants) do
			AddSearchName(var, unit)
		end
		local full = Compat.GetUnitDisplayName(unit, "full")
		if full and not IsSecret(full) then
			unitFullNames[unit] = full
			AddSearchName(full, unit)
		end
	end

	function sRaidFrames:ScanRoster()
		for id, name in pairs(roster) do
			if id ~= "n" then
				oldroster[id] = name
			end
		end
		nameToUnit = {}
		searchNames = {}
		unitFullNames = {}

		if not self.enabled then
			roster.n = 0
		elseif IsInRaid() then
			local numRaid = GetNumGroupMembers()
			for i = 1, numRaid do
				local unit = ("raid%d"):format(i)
				local dispName = Compat.GetUnitDisplayName(unit, "full")
				if IsSecret(dispName) then dispName = unit end
				roster[unit] = dispName

				IndexUnitNames(unit)
				local rosterName = GetRaidRosterInfo(i)
				if rosterName and not IsSecret(rosterName) then
					AddSearchName(rosterName, unit)
					local shortRoster = strmatch(rosterName, "^([^%-]+)")
					if shortRoster then
						AddSearchName(shortRoster, unit)
					end
				end

				if roster[unit] ~= oldroster[unit] then
					self:Roster_UnitChanged(unit)
				end
				oldroster[unit] = nil
			end
			roster.n = numRaid
		elseif self.opt.ShowInParty and IsInGroup() then
			local partyUnits = {"player", "party1", "party2", "party3", "party4"}
			local count = 0
			for _, unit in ipairs(partyUnits) do
				local okEx, exists = pcall(UnitExists, unit)
				if okEx and exists and not IsSecret(exists) then
					count = count + 1
					local dispName = Compat.GetUnitDisplayName(unit, "full")
					if IsSecret(dispName) then dispName = unit end
					roster[unit] = dispName
					IndexUnitNames(unit)
					if roster[unit] ~= oldroster[unit] then
						self:Roster_UnitChanged(unit)
					end
					oldroster[unit] = nil
				end
			end
			roster.n = count
		else
			roster.n = 0
		end

		oldroster.n = nil
		for id in pairs(oldroster) do
			oldroster[id] = nil
			roster[id] = nil
			self:Roster_UnitLeft(id)
		end
	end

	function sRaidFrames:GetUnitByName(unitname)
		if not unitname or IsSecret(unitname) then return nil end
		local u = nameToUnit[unitname] or nameToUnit[strlower(unitname)]
		if u then return u end
		local short = strmatch(unitname, "^([^%-]+)")
		if short and short ~= unitname then
			u = nameToUnit[short] or nameToUnit[strlower(short)]
			if u then return u end
		end
		local firstWord = strmatch(unitname, "^([^ ]+)")
		if firstWord and firstWord ~= unitname then
			u = nameToUnit[firstWord] or nameToUnit[strlower(firstWord)]
			if u then return u end
		end
		return nil
	end

	function sRaidFrames:FindUnitsInText(text)
		if not text or IsSecret(text) or type(text) ~= "string" then return nil end
		local found = nil
		local cleanText = gsub(text, "|c%x%x%x%x%x%x%x%x", "")
		cleanText = gsub(cleanText, "|r", "")

		for var, unit in pairs(searchNames) do
			local hasMultiByte = strfind(var, "[\128-\255]") ~= nil
			local valid = false
			if hasMultiByte then
				local _, charCount = gsub(var, "[^\128-\193]", "")
				valid = (charCount >= 2)
			else
				valid = (#var >= 3)
			end
			if valid then
				local sPos, ePos = strfind(cleanText, var, 1, true)
				if sPos then
					local boundaryOk = true
					if not hasMultiByte and strmatch(var, "^[A-Za-z]+$") then
						local prevCh = (sPos > 1) and cleanText:sub(sPos - 1, sPos - 1) or ""
						local nextCh = cleanText:sub(ePos + 1, ePos + 1)
						if strmatch(prevCh, "%a") or strmatch(nextCh, "%a") then
							boundaryOk = false
						end
					end
					if boundaryOk then
						found = found or {}
						found[unit] = true
					end
				end
			end
		end
		return found
	end
end

function sRaidFrames:OnUnitNameUpdate(event, unit)
	if not unit then return end
	local u = self:GetNonVehicleUnit(unit)
	if self:IsTracking(u) then
		self:ScanRoster()
		self:UpdateUnitDetails(u)
	end
	if self.PetToOwnerUnit then
		local owner = self:PetToOwnerUnit(unit)
		if owner and self:GetCurrentPetMode() == "attached" then
			self:UpdateAttachedPetHealth(owner, unit)
		end
	end
end

-------------------------------------------------------------------------------
-- DBM / BigWigs / Boss Cast Warning Integration
-------------------------------------------------------------------------------
function sRaidFrames:InitDBMIntegration()
	if self.dbmHooked then return end

	local function TryHookDBM()
		if _G.DBM and _G.DBM.RegisterCallback and not self.dbmCallbacksRegistered then
			self.dbmCallbacksRegistered = true
			_G.DBM:RegisterCallback("DBM_Announce", function(event, msg, icon, announceType, spellId, modId, isSpecialWarning)
				if not self.enabled or not self.opt.ShowBossDebuffs then return end
				self:OnDBMAnnounce(msg, icon, announceType, spellId, isSpecialWarning)
			end)
			-- DBM-Core 12.1.24 uses DBM_TimerBegin (older DBM used DBM_TimerStart)
			_G.DBM:RegisterCallback("DBM_TimerBegin", function(event, timerId, msg, timer, icon, timerType, spellId)
				if not self.enabled or not self.opt.ShowBossDebuffs then return end
				self:OnDBMTimerStart(timerId, msg, timer, icon, spellId)
			end)
			_G.DBM:RegisterCallback("DBM_TimerStart", function(event, timerId, msg, timer, icon, timerType, spellId)
				if not self.enabled or not self.opt.ShowBossDebuffs then return end
				self:OnDBMTimerStart(timerId, msg, timer, icon, spellId)
			end)
			_G.DBM:RegisterCallback("DBM_TimerStop", function(event, timerId)
				if not self.enabled then return end
				self:OnDBMTimerStop(timerId)
			end)
			_G.DBM:RegisterCallback("DBM_Wipe", function()
				self:ClearAllBossWarnings()
			end)
			_G.DBM:RegisterCallback("DBM_Kill", function()
				self:ClearAllBossWarnings()
			end)
		end
		if _G.BigWigsLoader and _G.BigWigsLoader.RegisterMessage and not self.bwCallbacksRegistered then
			self.bwCallbacksRegistered = true
			_G.BigWigsLoader.RegisterMessage(self, "BigWigs_Message", function(event, module, key, text, color, icon)
				if not self.enabled or not self.opt.ShowBossDebuffs then return end
				self:OnDBMAnnounce(text, icon, "target", type(key) == "number" and key or nil)
			end)
			_G.BigWigsLoader.RegisterMessage(self, "BigWigs_StartBar", function(event, module, key, text, time, icon)
				if not self.enabled or not self.opt.ShowBossDebuffs then return end
				self:OnDBMTimerStart(text, text, time, icon, type(key) == "number" and key or nil)
			end)
		end
	end

	TryHookDBM()
	self:RegisterEvent("ADDON_LOADED", function(_, loadedName)
		if loadedName == "DBM-Core" or loadedName == "BigWigs" or loadedName == "BigWigs_Core" then
			TryHookDBM()
		end
	end)
	self.dbmHooked = true
end

function sRaidFrames:TriggerUnitBossWarning(unit, spellName, icon, duration, spellId, timerId)
	if not unit or not self:IsTracking(unit) then return end
	local dur = duration or self.opt.DBMWarningDuration or 6
	if dur <= 0 then dur = 6 end
	if dur > 25 then dur = 25 end

	local spellDisplay = spellName
	if (not spellDisplay or spellDisplay == "") and spellId then
		spellDisplay = GetSpellInfo(spellId)
	end
	if not spellDisplay or spellDisplay == "" then
		spellDisplay = L["Boss Debuff"]
	end

	if not icon and spellId then
		local _, _, spIcon = GetSpellInfo(spellId)
		icon = spIcon
	end
	icon = icon or "Interface\\Icons\\Spell_Shadow_ShadowWordPain"

	local now = GetTime()
	self.dbmWarnings[unit] = {
		spellName = spellDisplay,
		icon = icon,
		spellId = spellId,
		duration = dur,
		expires = now + dur,
		timerId = timerId,
	}
	if timerId then
		self.dbmTimerMap[timerId] = unit
	end

	self:SetStatus(unit, "BossWarning", "! " .. spellDisplay .. " !", nil, true)
	self:UpdateAuras(unit)

	self:ScheduleTimer(function()
		local w = self.dbmWarnings[unit]
		if w and GetTime() >= (w.expires - 0.1) then
			self.dbmWarnings[unit] = nil
			self:UnsetStatus(unit, "BossWarning")
			self:UpdateAuras(unit)
		end
	end, dur + 0.15)
end

function sRaidFrames:ClearAllBossWarnings()
	for unit in pairs(self.dbmWarnings) do
		self.dbmWarnings[unit] = nil
		self:UnsetStatus(unit, "BossWarning")
		self:UpdateAuras(unit)
	end
	self.dbmTimerMap = {}
end

function sRaidFrames:OnDBMAnnounce(msg, icon, announceType, spellId, isSpecialWarning)
	if not msg or IsSecret(msg) then return end
	if IsSecret(announceType) then announceType = nil end
	if IsSecret(spellId) then spellId = nil end
	if IsSecret(icon) then icon = nil end
	local units = self:FindUnitsInText(msg)

	-- For personal "you" / "youcount" / "youpos" DBM warnings (which say "You" instead of player name),
	-- highlight the player's own unit frame directly.
	if (not units or not next(units)) and (announceType == "you" or announceType == "youcount" or announceType == "youpos") then
		for unit in pairs(self:GetAllUnits()) do
			local okSelf, isSelf = pcall(UnitIsUnit, unit, "player")
			if okSelf and not IsSecret(isSelf) and isSelf then
				units = { [unit] = true }
				break
			end
		end
	end
	if not units then return end

	local spellName = spellId and GetSpellInfo(spellId) or nil
	if not spellName then
		local clean = gsub(msg, "|c%x%x%x%x%x%x%x%x", "")
		clean = gsub(clean, "|r", "")
		spellName = strmatch(clean, "^([^:：>%-%(]+)") or clean
	end

	for unit in pairs(units) do
		self:TriggerUnitBossWarning(unit, spellName, icon, self.opt.DBMWarningDuration or 6, spellId)
	end
end

function sRaidFrames:OnDBMTimerStart(timerId, msg, timer, icon, spellId)
	if not msg or IsSecret(msg) then return end
	if IsSecret(spellId) then spellId = nil end
	if IsSecret(icon) then icon = nil end
	local units = self:FindUnitsInText(msg)
	if not units then return end

	local spellName = spellId and GetSpellInfo(spellId) or nil
	if not spellName then
		local clean = gsub(msg, "|c%x%x%x%x%x%x%x%x", "")
		clean = gsub(clean, "|r", "")
		spellName = strmatch(clean, "^([^:：%(]+)") or clean
	end

	local dur = (not IsSecret(timer) and tonumber(timer)) or (self.opt.DBMWarningDuration or 6)
	for unit in pairs(units) do
		self:TriggerUnitBossWarning(unit, spellName, icon, min(dur, 15), spellId, timerId)
	end
end

function sRaidFrames:OnDBMTimerStop(timerId)
	if not timerId then return end
	local unit = self.dbmTimerMap[timerId]
	if unit then
		self.dbmTimerMap[timerId] = nil
		local w = self.dbmWarnings[unit]
		if w and w.timerId == timerId then
			self.dbmWarnings[unit] = nil
			self:UnsetStatus(unit, "BossWarning")
			self:UpdateAuras(unit)
		end
	end
end

function sRaidFrames:OnUnitSpellcastStart(event, casterUnit)
	if not self.opt.ShowBossDebuffs or not casterUnit or IsSecret(casterUnit) then return end
	if strfind(casterUnit, "^raid") or strfind(casterUnit, "^party") or casterUnit == "player" or casterUnit == "pet" then
		return
	end
	local isBossUnit = strmatch(casterUnit, "^boss%d+$") ~= nil
	if not isBossUnit then
		local okCls, cls = pcall(UnitClassification, casterUnit)
		if not okCls or IsSecret(cls) or cls ~= "worldboss" then
			return
		end
	end
	local okEn, isEnemy = pcall(UnitIsEnemy, "player", casterUnit)
	if not okEn or IsSecret(isEnemy) or not isEnemy then
		return
	end
	local targetUnit = casterUnit .. "target"
	local okEx, exists = pcall(UnitExists, targetUnit)
	if not okEx or IsSecret(exists) or not exists then return end

	for raidUnit in pairs(self:GetAllUnits()) do
		local okSame, isSame = pcall(UnitIsUnit, targetUnit, raidUnit)
		if okSame and not IsSecret(isSame) and isSame then
			local spellName, icon, startTime, endTime, spellId
			if _G.UnitCastingInfo then
				local okC, n, _, tex, sTime, eTime, _, _, _, sId = pcall(_G.UnitCastingInfo, casterUnit)
				if okC and not IsSecret(n) then
					spellName, icon, startTime, endTime, spellId = n, tex, sTime, eTime, sId
				end
			end
			if not spellName and _G.UnitChannelInfo then
				local okC, n, _, tex, sTime, eTime, _, _, sId = pcall(_G.UnitChannelInfo, casterUnit)
				if okC and not IsSecret(n) then
					spellName, icon, startTime, endTime, spellId = n, tex, sTime, eTime, sId
				end
			end
			if spellName then
				local dur = (endTime and startTime and not IsSecret(endTime) and not IsSecret(startTime) and ((endTime - startTime) / 1000)) or 4
				self:TriggerUnitBossWarning(raidUnit, spellName, icon, max(dur, 3), spellId)
			end
			break
		end
	end
end

function sRaidFrames:Roster_UnitChanged(unitid)
	ShouldUpdateFrameCache = true

	self.statusstate[unitid] = {}
	self:UpdateAll(unitid)
end

function sRaidFrames:Roster_UnitLeft(unitid)
	ShouldUpdateFrameCache = true

	self.statusstate[unitid] = nil
	self.dbmWarnings[unitid] = nil
end

function sRaidFrames:UpdateRoster()
	local inRaid = IsInRaid()
	local inGroup = IsInGroup()
	local shouldBeActive = inRaid or (self.opt.ShowInParty and inGroup)
	local inArena = select(2, IsInInstance()) == "arena"

	if not sRaidFrames.enabled then
		if shouldBeActive and not (sRaidFrames.opt.HideInArena and inArena) and sRaidFrames.opt.Show then
			sRaidFrames:EnableFrames()
		end
	end
	if sRaidFrames.enabled then
		if not shouldBeActive then
			sRaidFrames:DisableFrames()
		end
		if sRaidFrames.opt.HideInArena and inArena then
			sRaidFrames:DisableFrames()
		end
		if not sRaidFrames.opt.Show then
			sRaidFrames:DisableFrames()
		end
	end
	sRaidFrames:HideBlizzard()
	local portraitMode = self:ShouldShowPortrait()
	local petMode = self:GetCurrentPetMode()
	if self._lastPortraitMode ~= portraitMode or self._lastInRaid ~= inRaid or self._lastPetMode ~= petMode then
		self._lastPortraitMode = portraitMode
		self._lastInRaid = inRaid
		self._lastPetMode = petMode
		if not InCombatLockdown() then
			self:SetGroupFilters()
			self:SetGrowth()
			self:ApplyLayout()
			self:RefreshAllNativeAuraContainers()
		else
			self:ScheduleLeaveCombatAction("SetGroupFilters")
			self:ScheduleLeaveCombatAction("SetGrowth")
			self:ScheduleLeaveCombatAction("ApplyLayout")
		end
	end
	sRaidFrames:ScanRoster()
end

function sRaidFrames:IsPetUnit(unit)
	if not unit or IsSecret(unit) then return false end
	return unit == "pet" or unit:match("^partypet%d+$") ~= nil or unit:match("^raidpet%d+$") ~= nil
end

function sRaidFrames:OwnerToPetUnit(unit)
	if not unit or IsSecret(unit) then return nil end
	if unit == "player" then return "pet" end
	local pIdx = unit:match("^party(%d+)$")
	if pIdx then return "partypet" .. pIdx end
	local rIdx = unit:match("^raid(%d+)$")
	if rIdx then return "raidpet" .. rIdx end
	return nil
end

function sRaidFrames:PetToOwnerUnit(unit)
	if not unit or IsSecret(unit) then return nil end
	if unit == "pet" then return "player" end
	local pIdx = unit:match("^partypet(%d+)$")
	if pIdx then return "party" .. pIdx end
	local rIdx = unit:match("^raidpet(%d+)$")
	if rIdx then return "raid" .. rIdx end
	return nil
end

function sRaidFrames:GetCurrentPetMode()
	if not self.opt then return "attached" end
	if IsInRaid() then
		return self.opt.RaidPetMode or "attached"
	end
	return self.opt.PartyPetMode or "attached"
end

function sRaidFrames:GetPartyPetSpacingReserve()
	if (not IsInRaid()) and self:GetCurrentPetMode() == "attached" then
		return 24
	end
	return 0
end

function sRaidFrames:OnUnitPet(event, ownerUnit)
	if not ownerUnit or IsSecret(ownerUnit) then return end
	if self:GetCurrentPetMode() == "attached" then
		for _, f in pairs(self:FindUnitFrames(ownerUnit)) do
			self:UpdateAttachedPetFrame(f)
		end
	elseif self:GetCurrentPetMode() == "group" then
		ShouldUpdateFrameCache = true
		local petUnit = self:OwnerToPetUnit(ownerUnit)
		if petUnit and self.enabled and self:IsTracking(petUnit) then
			self:UpdateAll(petUnit)
		end
		if self.petGroup and self.petGroup.header then
			self:ScheduleLeaveCombatAction("UpdateTitleVisibility", self.petGroup.header)
		end
	end
end

function sRaidFrames:ShouldShowPortrait()
	return self.opt and self.opt.ShowPartyPortrait and not IsInRaid()
end

function sRaidFrames:UpdateAllUnits()
	for unit in pairs(self:GetAllUnits()) do
		self:UpdateAll(unit)
	end
end

function sRaidFrames:UpdateAll(unit)
	if self.vehicleUpdate[unit] then
		self:CancelTimer(self.vehicleUpdate[unit], true)
		self.vehicleUpdate[unit] = nil
	end
	self:UpdateUnitDetails(unit)
	self:UpdateUnitHealth(unit)
	self:UpdateUnitPower(unit)
	self:UpdateStatuses(unit)
	self:UpdateAuras(unit)
	if self:GetCurrentPetMode() == "attached" and not self:IsPetUnit(unit) then
		for _, f in pairs(self:FindUnitFrames(unit)) do
			self:UpdateAttachedPetFrame(f)
		end
	end
end

function sRaidFrames:UpdateVehicle(event, unit)
	if not unit or not self:IsTracking(unit) then return end
	self:UpdateAll(unit)
end

function sRaidFrames:UpdateHealsOnUnit(event, unit)
	if not unit or IsSecret(unit) then return end
	local petOwner = self:PetToOwnerUnit(unit)
	if petOwner and self:GetCurrentPetMode() == "attached" then
		local okM, hpmax = pcall(UnitHealthMax, unit)
		for _, f in pairs(self:FindUnitFrames(petOwner)) do
			if f.petframe and f.petframe:IsShown() then
				self:UpdateUnitHealPredictionBar(f.petframe, unit, okM and hpmax or nil)
			end
		end
	end
	if not self:IsTracking(unit) then return end
	local actualUnit = self:GetVehicleUnit(unit)
	local hpmax = UnitHealthMax(actualUnit)
	for _, f in pairs(self:FindUnitFrames(unit)) do
		self:UpdateUnitHealPredictionBar(f, actualUnit, hpmax)
	end

	local ok, incomingHeals = pcall(UnitGetIncomingHeals, unit)
	if not ok or IsSecret(incomingHeals) or not incomingHeals then
		incomingHeals = 0
	end

	if self.opt.HighlightHeals and incomingHeals > 0 then
		self:SetStatus(unit, "Heal", ("+%d"):format(incomingHeals), nil, true)
	else
		self:UnsetStatus(unit, "Heal")
	end
end

function sRaidFrames:UpdateUnitThreat(event, unit)
	if not self.opt.AggroCheck or not unit or not self:IsTracking(unit) then return end
	if _G.UnitThreatSituation then
		local ok, status = pcall(_G.UnitThreatSituation, unit)
		if ok and not IsSecret(status) and status and status >= 2 then
			self:SetStatus(unit, "Aggro")
		else
			self:UnsetStatus(unit, "Aggro")
		end
	end
end

function sRaidFrames:UNIT_POWER(units)
	for unit in pairs(units) do
		local u = self:GetNonVehicleUnit(unit)
		self:UpdateUnitPower(u)
	end
end

function sRaidFrames:UNIT_HEALTH(units)
	for unit in pairs(units) do
		local u = self:GetNonVehicleUnit(unit)
		self:UpdateUnitHealth(u)
		local owner = self:PetToOwnerUnit(unit)
		if owner and self:GetCurrentPetMode() == "attached" then
			self:UpdateAttachedPetHealth(owner, unit)
		end
	end
end

function sRaidFrames:UNIT_AURA(units)
	for unit in pairs(units) do
		local u = self:GetNonVehicleUnit(unit)
		self:UpdateAuras(u)
		local owner = self:PetToOwnerUnit(unit)
		if owner and self:GetCurrentPetMode() == "attached" then
			self:UpdateAttachedPetAuras(owner, unit)
		end
	end
end

function sRaidFrames:READY_CHECK(event, author)
	if not self.opt.ReadyCheck then return end

	local authorid = self:GetUnitByName(author)

	for unitid in pairs(self:GetAllUnits()) do
		if unitid ~= authorid then
			self:SetStatus(unitid, "ReadyCheck_Pending")
		else
			self:SetStatus(unitid, "ReadyCheck_Ready")
		end
	end
end

function sRaidFrames:READY_CHECK_CONFIRM(event, unitid, confirm)
	if not self.opt.ReadyCheck or not unitid then return end
	if not self:IsTracking(unitid) then return end

	self:UnsetStatus(unitid, "ReadyCheck_Pending")
	if confirm then
		self:SetStatus(unitid, "ReadyCheck_Ready")
	else
		self:SetStatus(unitid, "ReadyCheck_NotReady")
	end
end

function sRaidFrames:READY_CHECK_FINISHED()
	if not self.opt.ReadyCheck then return end

	self:ScheduleTimer(function()
		for unitid in pairs(self:GetAllUnits()) do
			self:UnsetStatus(unitid, "ReadyCheck_Pending")
			self:UnsetStatus(unitid, "ReadyCheck_Ready")
			self:UnsetStatus(unitid, "ReadyCheck_NotReady")
		end
	end, 3)
end

local LastTarget
function sRaidFrames:UpdateTarget()
	if not self.opt.HighlightTarget then return end

	if LastTarget then
		self:UnsetStatus(LastTarget, "Target")
		LastTarget = nil
	end

	for unit in pairs(self:GetAllUnits()) do
		local ok, same = pcall(UnitIsUnit, unit, "target")
		if ok and not IsSecret(same) and same then
			self:SetStatus(unit, "Target")
			LastTarget = unit
			break
		end
	end

	-- Update target highlight border on visible attached pet bars
	if self:GetCurrentPetMode() == "attached" then
		for _, f in pairs(self.frames) do
			local pf = f.petframe
			if pf and pf.targetHighlight then
				if pf:IsShown() then
					local owner = f:GetAttribute("unit")
					local petUnit = self:OwnerToPetUnit(owner)
					local isTarget = false
					if petUnit then
						local okT, same = pcall(UnitIsUnit, petUnit, "target")
						if okT and not IsSecret(same) and same then
							isTarget = true
						end
					end
					pf.targetHighlight:SetShown(isTarget)
				else
					pf.targetHighlight:Hide()
				end
			end
		end
	end
end

function sRaidFrames.Banzai_Callback(aggro, name, ...)
	local self = sRaidFrames
	if not self.opt.AggroCheck then return end

	local unit = self:GetUnitByName(name)
	if not unit or not self:IsTracking(unit) then return end

	local hasAggro = Banzai:GetUnitAggroByUnitName(name)
	if hasAggro then
		self:SetStatus(unit, "Aggro")
	else
		self:UnsetStatus(unit, "Aggro")
	end
end

function sRaidFrames:LGIST_Update(event, guid, unit, info)
	self:ScheduleLeaveCombatAction("SetGroupFilters")
end

function sRaidFrames:ResInfo_ResStart(event, target)
	if not target or not self:IsTracking(target) then return end
	self.res[target] = 3
	self:UpdateUnitHealth(target)
end

function sRaidFrames:ResInfo_ResEnd(event, target)
	if not target or not self:IsTracking(target) then return end
	local ok, status = pcall(ResInfo.UnitHasIncomingRes, ResInfo, target)
	if not ok or IsSecret(status) then status = nil end
	if status == "CASTING" then
		self.res[target] = 3
	elseif status == "PENDING" then
		self.res[target] = 1
	else
		self.res[target] = nil
	end
	self:UpdateUnitHealth(target)
end

function sRaidFrames:ResInfo_CanRes(event, target)
	if not target or not self:IsTracking(target) then return end
	self.res[target] = 1
	self:UpdateUnitHealth(target)
end

function sRaidFrames:ResInfo_Ressed(event, target)
	if not target or not self:IsTracking(target) then return end
	self.res[target] = 2
	self:UpdateUnitHealth(target)
end

function sRaidFrames:IsUnitInRange(unit, range)
	if not self.RangeChecks[range] then
		return UnitInRange(unit)
	end
	return self.RangeChecks[range](unit)
end

function sRaidFrames:CanDispell(dispelType)
	if not dispelType or IsSecret(dispelType) then return false end
	if not self.dispellers[self.PlayerClass] then
		return false
	else
		return self.cleanseTypes[dispelType] and true or false
	end
end

function sRaidFrames:RangeCheck()
	if not self.opt.RangeCheck then return end
	local RangeLimit = self.opt.RangeLimit
	local RangeAlpha = self.opt.RangeAlpha

	for unit in pairs(self:GetAllUnits()) do
		local vunit = self:GetVehicleUnit(unit)
		local okSelf, isSelf = pcall(UnitIsUnit, vunit, "player")
		if okSelf and not IsSecret(isSelf) and isSelf then
			for _, f in pairs(self:FindUnitFrames(unit)) do
				if f.SetVisualAlpha then f:SetVisualAlpha(1) else f:SetAlpha(1) end
			end
		else
			local inRange, checked = self:IsUnitInRange(vunit, RangeLimit)
			if IsSecret(inRange) or IsSecret(checked) then
				for _, f in pairs(self:FindUnitFrames(unit)) do
					if f.SetVisualAlphaFromBoolean then
						f:SetVisualAlphaFromBoolean(inRange, 1, RangeAlpha)
					end
				end
			else
				local near = (inRange == true or inRange == 1) or (checked == false)
				local alpha = near and 1 or RangeAlpha
				for _, f in pairs(self:FindUnitFrames(unit)) do
					if f.SetVisualAlpha then f:SetVisualAlpha(alpha) else f:SetAlpha(alpha) end
				end
			end
		end
	end
	-- Range alpha check for visible attached pet bars
	if self:GetCurrentPetMode() == "attached" then
		for _, f in pairs(self.frames) do
			local pf = f.petframe
			if pf and pf:IsShown() then
				local owner = f:GetAttribute("unit")
				local petUnit = self:OwnerToPetUnit(owner)
				if petUnit then
					local inRange, checked = self:IsUnitInRange(petUnit, RangeLimit)
					if IsSecret(inRange) or IsSecret(checked) then
						if pf.SetVisualAlphaFromBoolean then
							pf:SetVisualAlphaFromBoolean(inRange, 1, RangeAlpha)
						end
					else
						local near = (inRange == true or inRange == 1) or (checked == false)
						local alpha = near and 1 or RangeAlpha
						if pf.SetVisualAlpha then pf:SetVisualAlpha(alpha) else pf:SetAlpha(alpha) end
					end
				end
			end
		end
	end
end

function sRaidFrames:AddRangeFunction(range, check)
	if not range or self.RangeChecks[range] then return end
	self.RangeChecks[range] = check
	self:UpdateRangeLimitOptions()
end

function sRaidFrames:UpdateRangeFrequency()
	if self.rangeTimer then
		self:CancelTimer(self.rangeTimer)
	end
	self.rangeTimer = self:ScheduleRepeatingTimer("RangeCheck", self.opt.RangeFrequency)
end

function sRaidFrames:UpdateStatuses(unit)
	for element in pairs(self.statusElements) do
		self:UpdateUnitStatusElement(unit, element)
	end
end

local CLASS_ICON_COORDS = _G.CLASS_ICON_TCOORDS or {
	WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.49609375, 0, 0.25 }, ROGUE = { 0.49609375, 0.7421875, 0, 0.25 },
	DRUID = { 0.7421875, 0.98828125, 0, 0.25 }, HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
	PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 }, WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 }, PALADIN = { 0, 0.25, 0.5, 0.75 },
	DEATHKNIGHT = { 0.25, 0.5, 0.5, 0.75 }, MONK = { 0.5, 0.73828125, 0.5, 0.75 },
}

local function SetClassIconTexture(tex, class)
	if not tex or not class or IsSecret(class) then return false end
	local info = _G.C_Texture and _G.C_Texture.GetAtlasInfo and _G.C_Texture.GetAtlasInfo("classicon-" .. strlower(class))
	if info and (info.file or info.filename) then
		local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
		local w, h = (r - l) * 0.04, (b - t) * 0.04
		tex:SetTexture(info.file or info.filename)
		tex:SetTexCoord(l + w, r - w, t + h, b - h)
		return true
	end
	local c = CLASS_ICON_COORDS[class]
	if c then
		tex:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
		tex:SetTexCoord(c[1], c[2], c[3], c[4])
		return true
	end
	return false
end

local PARTY_ROLE_ATLAS = {
	TANK    = "icons_16x16_tank",
	HEALER  = "icons_16x16_heal",
	DAMAGER = "icons_16x16_damage",
}
local PARTY_ROLE_COORDS = {
	TANK    = { 0 / 64, 19 / 64, 22 / 64, 41 / 64 },
	HEALER  = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
	DAMAGER = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 },
}

local function SetTankIconTexture(tex, unit)
	if not tex or not unit or IsSecret(unit) then return false end
	local kind = nil
	local inRaid = _G.IsInRaid and _G.IsInRaid()
	if inRaid and _G.GetPartyAssignment then
		local okT, isMT = pcall(_G.GetPartyAssignment, "MAINTANK", unit)
		local okM, isMA = pcall(_G.GetPartyAssignment, "MAINASSIST", unit)
		if okT and not IsSecret(isMT) and isMT then
			kind = "MAINTANK"
		elseif okM and not IsSecret(isMA) and isMA then
			kind = "MAINASSIST"
		end
	end
	if not kind and _G.UnitGroupRolesAssigned then
		local okR, role = pcall(_G.UnitGroupRolesAssigned, unit)
		if okR and not IsSecret(role) then
			if role == "TANK" or (not inRaid and (role == "HEALER" or role == "DAMAGER")) then
				kind = role
			end
		end
	end
	if not kind then return false end

	if kind == "MAINTANK" then
		local atlas = "RaidFrame-Icon-MainTank"
		if _G.C_Texture and _G.C_Texture.GetAtlasInfo and _G.C_Texture.GetAtlasInfo(atlas) then
			tex:SetAtlas(atlas)
		else
			tex:SetTexture("Interface\\GroupFrame\\UI-Group-MainTankIcon")
			tex:SetTexCoord(0, 1, 0, 1)
		end
		return true
	elseif kind == "MAINASSIST" then
		local atlas = "RaidFrame-Icon-MainAssist"
		if _G.C_Texture and _G.C_Texture.GetAtlasInfo and _G.C_Texture.GetAtlasInfo(atlas) then
			tex:SetAtlas(atlas)
		else
			tex:SetTexture("Interface\\GroupFrame\\UI-Group-MainAssistIcon")
			tex:SetTexCoord(0, 1, 0, 1)
		end
		return true
	elseif PARTY_ROLE_ATLAS[kind] then
		local atlas = PARTY_ROLE_ATLAS[kind]
		if _G.C_Texture and _G.C_Texture.GetAtlasInfo and _G.C_Texture.GetAtlasInfo(atlas) then
			tex:SetAtlas(atlas)
		else
			local c = PARTY_ROLE_COORDS[kind]
			tex:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
			tex:SetTexCoord(c[1], c[2], c[3], c[4])
		end
		return true
	end
	return false
end

local function SetLeaderIconTexture(tex, unit)
	if not tex or not unit or IsSecret(unit) then return false end
	local okL, isLead = pcall(UnitIsGroupLeader, unit)
	if not okL or IsSecret(isLead) or not isLead then return false end
	local atlas = "UI-HUD-UnitFrame-Player-Group-LeaderIcon"
	if _G.C_Texture and _G.C_Texture.GetAtlasInfo and _G.C_Texture.GetAtlasInfo(atlas) then
		tex:SetAtlas(atlas)
	else
		tex:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
		tex:SetTexCoord(0, 1, 0, 1)
	end
	return true
end

local function UpdateUnitPortrait(f, unit)
	if not f or not f.portraitFrame or not f.portrait then return end
	if not sRaidFrames:ShouldShowPortrait() or not unit or IsSecret(unit) then
		f.portraitFrame:Hide()
		return
	end
	f.portraitFrame:Show()
	local okV, visible = pcall(UnitIsVisible, unit)
	if okV and not IsSecret(visible) and visible then
		local okP = pcall(SetPortraitTexture, f.portrait, unit)
		if okP then
			f.portrait:SetTexCoord(0, 1, 0, 1)
			return
		end
	end
	-- Unit not yet in view range ("未见面"): show default race/gender portrait
	local okR, _, raceFile = pcall(UnitRace, unit)
	local okS, sex = pcall(UnitSex, unit)
	local sexStr = (okS and not IsSecret(sex) and sex == 3) and "Female" or "Male"
	if okR and type(raceFile) == "string" and not IsSecret(raceFile) and raceFile ~= "" then
		f.portrait:SetTexture("Interface\\CharacterFrame\\TemporaryPortrait-" .. sexStr .. "-" .. raceFile)
		f.portrait:SetTexCoord(0, 1, 0, 1)
	else
		pcall(SetPortraitTexture, f.portrait, unit)
	end
end

function sRaidFrames:UpdateUnitPortraitEvent(event, unit)
	if not unit or IsSecret(unit) then return end
	if self:IsTracking(unit) then
		for _, f in pairs(self:FindUnitFrames(unit)) do
			UpdateUnitPortrait(f, unit)
		end
	end
	local owner = self:PetToOwnerUnit(unit)
	if owner and self:GetCurrentPetMode() == "attached" then
		self:UpdateAttachedPetPortrait(owner, unit)
	end
end

function sRaidFrames:OnUnitLevelUpdate(event, unit)
	if not unit or IsSecret(unit) or not self:IsTracking(unit) then return end
	self:UpdateUnitDetails(unit)
end

local function SetVoiceIconTexture(tex)
	if not tex then return end
	local atlases = { "voicechat-icon-speaker", "VoiceChat-Speaker" }
	if _G.C_Texture and _G.C_Texture.GetAtlasInfo then
		for _, a in ipairs(atlases) do
			if _G.C_Texture.GetAtlasInfo(a) then
				tex:SetAtlas(a)
				return
			end
		end
	end
	tex:SetTexture("Interface\\Common\\VoiceChat-Speaker")
	tex:SetTexCoord(0, 1, 0, 1)
end

function sRaidFrames:UpdateUnitVoiceDisplay(unit)
	if not unit or IsSecret(unit) or not self:IsTracking(unit) then return end
	local speaking = self._unitSpeaking and self._unitSpeaking[unit] or false
	for _, f in pairs(self:FindUnitFrames(unit)) do
		if f.voiceIcon then
			if speaking then
				SetVoiceIconTexture(f.voiceIcon)
				f.voiceIcon:Show()
			else
				f.voiceIcon:Hide()
			end
		end
	end
end

function sRaidFrames:UpdateUnitVoiceEvent(event, unit)
	if not unit or IsSecret(unit) then return end
	self._unitSpeaking = self._unitSpeaking or {}
	self._unitSpeaking[unit] = (event == "VOICE_START") or nil
	self:UpdateUnitVoiceDisplay(unit)
end

function sRaidFrames:UpdateVoiceChatMemberSpeaking(event, memberID, channelID, isSpeaking)
	if not (_G.C_VoiceChat and _G.C_VoiceChat.GetMemberGUID) then return end
	local okG, memberGUID = pcall(_G.C_VoiceChat.GetMemberGUID, memberID, channelID)
	if not okG or not memberGUID or IsSecret(memberGUID) then return end
	self._unitSpeaking = self._unitSpeaking or {}
	for unit in pairs(self:GetAllUnits()) do
		local okU, uGUID = pcall(UnitGUID, unit)
		if okU and uGUID and not IsSecret(uGUID) and uGUID == memberGUID then
			self._unitSpeaking[unit] = isSpeaking and true or nil
			self:UpdateUnitVoiceDisplay(unit)
		end
	end
end

-------------------------------------------------------------------------------
-- Dual-Name Display & Class-Colored Player Name
-------------------------------------------------------------------------------
function sRaidFrames:UpdateUnitDetails(unit)
	if not self:IsTracking(unit) then return end
	local rawClass = select(2, UnitClass(unit))
	if rawClass and not IsSecret(rawClass) then
		self.unitClassCache[unit] = rawClass
	end
	local class = (rawClass and not IsSecret(rawClass) and rawClass) or self.unitClassCache[unit]
	local dispName = Compat.GetUnitDisplayName(unit, self.opt.NameFormat)

	for _, f in pairs(self:FindUnitFrames(unit)) do
		if IsSecret(dispName) then
			pcall(f.title.SetText, f.title, dispName)
		elseif dispName and dispName ~= "" then
			f.title:SetText(dispName)
		else
			local cur = f.title:GetText()
			if not cur or cur == "" then
				f.title:SetText(L["Unknown"])
			end
		end

		-- Always color player name by class color; for standalone pet group frames use owner's class color (or soft pet green)
		local isPetFrame = f.isPetGroupFrame or self:IsPetUnit(unit)
		local color = nil
		if isPetFrame then
			local owner = self:PetToOwnerUnit(unit)
			local ownerClass = owner and (select(2, UnitClass(owner)) or self.unitClassCache[owner])
			if ownerClass and not IsSecret(ownerClass) and RAID_CLASS_COLORS[ownerClass] then
				color = RAID_CLASS_COLORS[ownerClass]
			else
				color = { r = 0.72, g = 0.94, b = 0.72 }
			end
		else
			color = (class and RAID_CLASS_COLORS[class]) or NORMAL_FONT_COLOR
		end
		if color then
			f.title:SetTextColor(color.r, color.g, color.b, 1)
			if self.opt.HealthBarColorByClass and not isPetFrame then
				f.hpbar:SetStatusBarColor(color.r, color.g, color.b)
			end
		end

		if f.classIcon then
			if (not isPetFrame) and self.opt.ShowClassIcon and class and SetClassIconTexture(f.classIcon, class) then
				f.classIcon:Show()
			else
				f.classIcon:Hide()
			end
		end

		if f.levelText then
			if not IsInRaid() then
				local okL, lvl = pcall(UnitLevel, unit)
				if okL and lvl and not IsSecret(lvl) then
					if lvl > 0 then
						f.levelText:SetText("Lv." .. lvl)
					else
						f.levelText:SetText("Lv.??")
					end
					f.levelText:Show()
				else
					f.levelText:Hide()
				end
			else
				f.levelText:Hide()
			end
		end

		local showPortrait = self:ShouldShowPortrait()
		if f.tankIcon then
			if (not isPetFrame) and self.opt.ShowTankIcons and SetTankIconTexture(f.tankIcon, unit) then
				f.tankIcon:ClearAllPoints()
				if showPortrait and f.portraitFrame then
					f.tankIcon:SetPoint("BOTTOMRIGHT", f.portraitFrame, "BOTTOMRIGHT", 2, -2)
				else
					f.tankIcon:SetPoint("TOPLEFT", f.hpbar, "TOPLEFT", 1, 0)
				end
				f.tankIcon:Show()
			else
				f.tankIcon:Hide()
			end
		end

		if f.leaderIcon then
			if (not isPetFrame) and self.opt.ShowLeaderIcon and SetLeaderIconTexture(f.leaderIcon, unit) then
				f.leaderIcon:ClearAllPoints()
				if showPortrait and f.portraitFrame then
					f.leaderIcon:SetPoint("TOPLEFT", f.portraitFrame, "TOPLEFT", -2, 2)
				elseif f.tankIcon and f.tankIcon:IsShown() then
					f.leaderIcon:SetPoint("TOPLEFT", f.tankIcon, "TOPRIGHT", 1, 0)
				else
					f.leaderIcon:SetPoint("TOPLEFT", f.hpbar, "TOPLEFT", 1, 0)
				end
				f.leaderIcon:Show()
			else
				f.leaderIcon:Hide()
			end
		end

		if f.raidMarker and f.hpbar then
			f.raidMarker:ClearAllPoints()
			if not showPortrait and not isPetFrame then
				local leftShift = 1 + ((f.tankIcon and f.tankIcon:IsShown()) and 12 or 0) + ((f.leaderIcon and f.leaderIcon:IsShown()) and 12 or 0)
				f.raidMarker:SetPoint("LEFT", f.hpbar, "LEFT", leftShift, 0)
			else
				f.raidMarker:SetPoint("LEFT", f.hpbar, "LEFT", 1, 0)
			end
		end

		UpdateUnitPortrait(f, unit)
		self:UpdateUnitVoiceDisplay(unit)

		if self.opt.VehicleStatus and UnitHasVehicleUI(unit) then
			local vName = Compat.GetUnitDisplayName(self:GetVehicleUnit(unit), "full")
			self:SetStatus(unit, "Vehicle", not IsSecret(vName) and vName or L["On Vehicle"])
		else
			self:UnsetStatus(unit, "Vehicle")
		end

		if f.hasNativeAuraContainers and not privateFuncs.IsInCombat() then
			self:SyncNativeAuraContainers(f, self:GetVehicleUnit(unit))
		end
	end
end

-------------------------------------------------------------------------------
-- Secret-Safe Health & Power Bars (WoW: Forever 16001)
-------------------------------------------------------------------------------
function sRaidFrames:GetHealthColorCurve()
	if self._healthColorCurve == nil then
		self._healthColorCurve = false
		if _G.C_CurveUtil and _G.C_CurveUtil.CreateColorCurve and _G.CreateColor then
			local ok, curve = pcall(_G.C_CurveUtil.CreateColorCurve)
			if ok and curve then
				curve:AddPoint(0.0, _G.CreateColor(1.0, 0.0, 0.0, 1.0))
				curve:AddPoint(0.5, _G.CreateColor(1.0, 1.0, 0.0, 1.0))
				curve:AddPoint(1.0, _G.CreateColor(0.0, 1.0, 0.0, 1.0))
				self._healthColorCurve = curve
			end
		end
	end
	return self._healthColorCurve or nil
end

local missingHealthCalc
function sRaidFrames:GetUnitMissingHealth(unit)
	if missingHealthCalc == nil then
		missingHealthCalc = _G.CreateUnitHealPredictionCalculator and _G.CreateUnitHealPredictionCalculator() or false
	end
	if missingHealthCalc and missingHealthCalc.GetMissingHealth and _G.UnitGetDetailedHealPrediction then
		local ok = pcall(missingHealthCalc.ResetPredictedValues, missingHealthCalc)
		ok = ok and pcall(_G.UnitGetDetailedHealPrediction, unit, "player", missingHealthCalc)
		local okM, lost = pcall(missingHealthCalc.GetMissingHealth, missingHealthCalc)
		if ok and okM and lost ~= nil then return lost end
	end
	if _G.UnitHealthMissing then
		local ok, lost = pcall(_G.UnitHealthMissing, unit, false)
		if ok then return lost end
	end
	return nil
end

local incomingHealCalc
function sRaidFrames:UpdateUnitHealPredictionBar(f, unit, hpmax)
	if not f or not f.healbar then return end
	if not self.opt.ShowHealPrediction or not unit or IsSecret(unit) then
		f.healbar:Hide()
		return
	end
	local dead, ghost = self:IsUnitReallyDead(unit)
	if dead or ghost then
		f.healbar:Hide()
		return
	end
	if incomingHealCalc == nil then
		incomingHealCalc = _G.CreateUnitHealPredictionCalculator and _G.CreateUnitHealPredictionCalculator() or false
		if incomingHealCalc and _G.Enum and _G.Enum.UnitIncomingHealClampMode and incomingHealCalc.SetIncomingHealClampMode then
			pcall(incomingHealCalc.SetIncomingHealClampMode, incomingHealCalc, _G.Enum.UnitIncomingHealClampMode.MissingHealth)
		end
	end

	local inc = nil
	if incomingHealCalc and incomingHealCalc.GetIncomingHeals and _G.UnitGetDetailedHealPrediction then
		local ok = pcall(incomingHealCalc.ResetPredictedValues, incomingHealCalc)
		ok = ok and pcall(_G.UnitGetDetailedHealPrediction, unit, "player", incomingHealCalc)
		if ok then
			local okI, val = pcall(incomingHealCalc.GetIncomingHeals, incomingHealCalc)
			if okI then inc = val end
		end
	elseif _G.UnitGetIncomingHeals then
		local okI, val = pcall(_G.UnitGetIncomingHeals, unit)
		if okI then inc = val end
	end

	if inc == nil then
		f.healbar:Hide()
		return
	end
	hpmax = hpmax or UnitHealthMax(unit)
	if not IsSecret(inc) and (inc <= 0) then
		f.healbar:Hide()
		return
	end
	if not IsSecret(hpmax) and (not hpmax or hpmax <= 0) then
		f.healbar:Hide()
		return
	end

	if not IsSecret(inc) and not IsSecret(hpmax) then
		local hp = UnitHealth(unit)
		if hp and not IsSecret(hp) then
			local missing = max(0, hpmax - hp)
			if inc > missing then inc = missing end
			if inc <= 0 then
				f.healbar:Hide()
				return
			end
		end
	end

	self:SyncHealPredictionOrientation(f)
	pcall(f.healbar.SetMinMaxValues, f.healbar, 0, hpmax)
	pcall(f.healbar.SetValue, f.healbar, inc)
	f.healbar:Show()
end

local hpcache = {}
local freqElapsed = 0
function sRaidFrames:FrequentHealthUpdate(elapsed)
	if elapsed then
		freqElapsed = freqElapsed + elapsed
		if freqElapsed < 0.08 then return end
		freqElapsed = 0
	end
	for munit in pairs(self:GetAllUnits()) do
		if not self:GetStatus(munit, "Death") then
			local unit = self:GetVehicleUnit(munit)
			local okH, hp = pcall(UnitHealth, unit)
			local okM, hpmax = pcall(UnitHealthMax, unit)
			if not okH or not okM then hp, hpmax = 0, 0 end

			if IsSecret(hp) or IsSecret(hpmax) then
				hpcache[munit] = nil
				for _, f in pairs(self:FindUnitFrames(munit)) do
					self:UpdateSingleUnitHealth(f, hp, hpmax, nil, unit)
				end
			else
				hp = hp or 0
				hpmax = hpmax or 0
				local hpp = (hpmax ~= 0) and ceil((hp / hpmax) * 100) or 0
				if hpcache[munit] ~= hp then
					hpcache[munit] = hp
					for _, f in pairs(self:FindUnitFrames(munit)) do
						self:UpdateSingleUnitHealth(f, hp, hpmax, hpp, unit)
					end
				end
			end
		end
	end
	-- Smooth frequent updates for visible attached pet bars
	if self:GetCurrentPetMode() == "attached" then
		for _, f in pairs(self.frames) do
			local pf = f.petframe
			if pf and pf:IsShown() then
				local owner = f:GetAttribute("unit")
				local petUnit = self:OwnerToPetUnit(owner)
				if petUnit then
					self:UpdateSingleAttachedPetHealth(pf, petUnit)
				end
			end
		end
	end
end

function sRaidFrames:SyncHealPredictionOrientation(f)
	if not f or not f.hpbar or not f.healbar then return end
	local invert = (not f.ownerFrame) and self.opt and self.opt.Invert and true or false
	if f.healbar.SetReverseFill then
		f.healbar:SetReverseFill(invert)
	end
	if f.healbar._lastInvert ~= invert then
		f.healbar._lastInvert = invert
		local tex = f.hpbar:GetStatusBarTexture()
		f.healbar:ClearAllPoints()
		if invert then
			f.healbar:SetPoint("TOPRIGHT", tex, "TOPLEFT", 0, 0)
			f.healbar:SetPoint("BOTTOMRIGHT", tex, "BOTTOMLEFT", 0, 0)
		else
			f.healbar:SetPoint("TOPLEFT", tex, "TOPRIGHT", 0, 0)
			f.healbar:SetPoint("BOTTOMLEFT", tex, "BOTTOMRIGHT", 0, 0)
		end
	end
end

function sRaidFrames:UpdateSingleUnitHealth(f, hp, hpmax, hpp, unit)
	local format = self.opt.HealthFormat
	local invert = self.opt.Invert and true or false

	if IsSecret(hp) or IsSecret(hpmax) then
		if f.hpbar.SetReverseFill then
			f.hpbar:SetReverseFill(invert)
		end
		self:SyncHealPredictionOrientation(f)
		pcall(f.hpbar.SetMinMaxValues, f.hpbar, 0, hpmax)
		pcall(f.hpbar.SetValue, f.hpbar, hp)
		self:UpdateUnitHealPredictionBar(f, unit, hpmax)

		if not self.opt.HealthBarColorByClass then
			local curve = self:GetHealthColorCurve()
			local painted = false
			if curve and _G.UnitHealthPercent then
				local okC, col = pcall(_G.UnitHealthPercent, unit, false, curve)
				if okC and col ~= nil and not IsSecret(col) and not IsSecretTable(col) then
					painted = pcall(function()
						if col.GetRGB then
							f.hpbar:SetStatusBarColor(col:GetRGB())
						else
							error("no GetRGB")
						end
					end)
				end
			end
			if not painted then
				f.hpbar:SetStatusBarColor(0.1, 0.85, 0.2)
			end
		end

		if format == "none" then
			f.hpbar.text:SetText(nil)
		elseif format == "deficit" then
			local lost = unit and self:GetUnitMissingHealth(unit)
			local SU = _G.C_StringUtil
			local ok = false
			if lost ~= nil and SU and SU.TruncateWhenZero and SU.WrapString then
				local okT, txt = pcall(SU.TruncateWhenZero, lost)
				local okW, out
				if okT then okW, out = pcall(SU.WrapString, txt, "-") end
				if okW then ok = pcall(f.hpbar.text.SetText, f.hpbar.text, out) end
			end
			if not ok and lost ~= nil then
				pcall(f.hpbar.text.SetFormattedText, f.hpbar.text, "-%.0f", lost)
			end
		elseif format == "current" then
			if not pcall(f.hpbar.text.SetFormattedText, f.hpbar.text, "%.0f", hp) then
				pcall(f.hpbar.text.SetFormattedText, f.hpbar.text, "%s", hp)
			end
		elseif format == "curmax" then
			if not pcall(f.hpbar.text.SetFormattedText, f.hpbar.text, "%.0f/%.0f", hp, hpmax) then
				pcall(f.hpbar.text.SetFormattedText, f.hpbar.text, "%s/%s", hp, hpmax)
			end
		elseif format == "curdeficit" then
			if unit and _G.UnitHealthPercent and _G.CurveConstants and _G.CurveConstants.ScaleTo100 then
				local okP, pct = pcall(_G.UnitHealthPercent, unit, true, _G.CurveConstants.ScaleTo100)
				if okP then
					if not pcall(f.hpbar.text.SetFormattedText, f.hpbar.text, "%.0f (%.0f%%)", hp, pct) then
						pcall(f.hpbar.text.SetFormattedText, f.hpbar.text, "%s (%s%%)", hp, pct)
					end
				end
			else
				pcall(f.hpbar.text.SetFormattedText, f.hpbar.text, "%.0f", hp)
			end
		else
			-- "percent"
			if unit and _G.UnitHealthPercent and _G.CurveConstants and _G.CurveConstants.ScaleTo100 then
				local okP, pct = pcall(_G.UnitHealthPercent, unit, true, _G.CurveConstants.ScaleTo100)
				if okP then
					if not pcall(f.hpbar.text.SetFormattedText, f.hpbar.text, "%.0f%%", pct) then
						pcall(f.hpbar.text.SetFormattedText, f.hpbar.text, "%s%%", pct)
					end
				end
			end
		end
		return
	end

	if f.hpbar.SetReverseFill then
		f.hpbar:SetReverseFill(invert)
	end
	self:SyncHealPredictionOrientation(f)
	local safeMax = (hpmax and hpmax > 0) and hpmax or 1
	local safeHp = hp or 0
	f.hpbar:SetMinMaxValues(0, safeMax)

	local hptext
	if self.opt.HideMaxHealth and (safeHp == safeMax) then
		hptext = nil
	else
		if format == "percent" then
			hptext = hpp .. "%"
		elseif format == "deficit" then
			hptext = (safeHp - safeMax) ~= 0 and (safeHp - safeMax) or nil
		elseif format == "current" then
			hptext = safeHp
		elseif format == "curmax" then
			hptext = safeHp .. "/" .. safeMax
		elseif format == "curdeficit" then
			hptext = (safeHp ~= safeMax) and (safeHp .. " |cffff0000" .. (safeHp - safeMax) .. "|r") or safeMax
		elseif format == "none" then
			hptext = nil
		end
	end

	local hpvalue = (not f.hpbar.SetReverseFill and invert) and max(0, safeMax - safeHp) or safeHp

	f.hpbar.text:SetText(hptext)
	f.hpbar:SetValue(hpvalue)
	if not self.opt.HealthBarColorByClass then
		f.hpbar:SetStatusBarColor(self:GetHPSeverity(hpp / 100))
	end
	self:UpdateUnitHealPredictionBar(f, unit, hpmax)
end

function sRaidFrames:IsUnitReallyDead(unit)
	local okD, dead = pcall(UnitIsDead, unit)
	if not okD or IsSecret(dead) then dead = false end
	local okG, ghost = pcall(UnitIsGhost, unit)
	if not okG or IsSecret(ghost) then ghost = false end
	if dead and _G.UnitIsFeignDeath then
		local okF, feign = pcall(_G.UnitIsFeignDeath, unit)
		if okF and not IsSecret(feign) and feign then
			dead = false
		end
	end
	return dead, ghost
end

function sRaidFrames:UpdateUnitHealth(munit)
	if not self:IsTracking(munit) then return end
	local unit = self:GetVehicleUnit(munit)
	local dead, ghost = self:IsUnitReallyDead(unit)
	local okConn, connected = pcall(UnitIsConnected, munit)
	local isOffline = (okConn and not IsSecret(connected) and connected == false)

	for _, f in pairs(self:FindUnitFrames(munit)) do
		local status = nil

		if isOffline then status = "|cffff0000"..L["Offline"].."|r"
		elseif dead and self.res[munit] == 1 then status = "|cff00ff00"..L["Can Recover"].."|r"
		elseif (dead or ghost) and self.res[munit] == 2 then status = "|cff00ff00"..L["Resurrected"].."|r"
		elseif (dead or ghost) and self.res[munit] == 3 then status = "|cffff8c00"..L["Resurrecting"].."|r"
		elseif ghost then status = "|cffff0000"..L["Released"].."|r"
		elseif dead then status = "|cffff0000"..L["Dead"].."|r"
		end

		if status then
			f.hpbar.text:SetText(status)
			f.hpbar:SetMinMaxValues(0, 100)
			f.hpbar:SetValue(0)
			if f.healbar then f.healbar:Hide() end
			f.mpbar:SetMinMaxValues(0, 100)
			f.mpbar:SetValue(0)
			self:SetStatus(munit, "Death")
		else
			self:UnsetStatus(munit, "Death")
			self.res[munit] = nil
			local hp = UnitHealth(unit)
			local hpmax = UnitHealthMax(unit)

			if IsSecret(hp) or IsSecret(hpmax) then
				self:UpdateSingleUnitHealth(f, hp, hpmax, nil, unit)
			else
				hp = hp or 0
				hpmax = hpmax or 0
				local hpp = (hpmax ~= 0) and ceil((hp / hpmax) * 100) or 0

				if unit ~= munit and (isOffline or hpmax == 0) then
					hp, hpmax, hpp = 1, 1, 100
					if not self.vehicleUpdate[munit] then
						self.vehicleUpdate[munit] = self:ScheduleTimer("UpdateAll", 0.2, munit)
					end
				end

				self:UpdateSingleUnitHealth(f, hp, hpmax, hpp, unit)
			end
		end
	end
end

function sRaidFrames:UpdateUnitPower(munit)
	if not self:IsTracking(munit) then return end
	local unit = self:GetVehicleUnit(munit)
	local dead, ghost = self:IsUnitReallyDead(unit)

	for _, f in pairs(self:FindUnitFrames(munit)) do
		if dead or ghost then
			f.mpbar:SetMinMaxValues(0, 100)
			f.mpbar:SetValue(0)
		else
			local okPT, powerType, powerToken = pcall(UnitPowerType, unit)
			if not okPT or IsSecret(powerType) then powerType, powerToken = Compat.POWER_MANA, "MANA" end
			if not self.opt.PowerFilter[powerType] and not (self.opt.VehicleSwitch and self.opt.VehiclePower and munit ~= unit) then
				f.mpbar:SetMinMaxValues(0, 100)
				f.mpbar:SetValue(0)
			else
				local color = (not IsSecret(powerToken) and powerToken and PowerBarColor[powerToken])
					or PowerBarColor[powerType]
					or PowerBarColor["MANA"]
					or {r = 0, g = 0.5, b = 1}
				f.mpbar:SetStatusBarColor(color.r, color.g, color.b)

				local mp = UnitPower(unit)
				local mpmax = UnitPowerMax(unit)
				if IsSecret(mp) or IsSecret(mpmax) then
					pcall(f.mpbar.SetMinMaxValues, f.mpbar, 0, mpmax)
					pcall(f.mpbar.SetValue, f.mpbar, mp)
				else
					mp = mp or 0
					mpmax = mpmax or 0
					local mpp = (mpmax ~= 0) and ceil((mp / mpmax) * 100) or 0
					f.mpbar:SetMinMaxValues(0, 100)
					f.mpbar:SetValue(mpp)
				end
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Native Forever AuraContainers + Lua Aura Scanner
-------------------------------------------------------------------------------
local FlowDir = _G.AnchorUtil and _G.AnchorUtil.FlowDirection
local AuraChangedType = _G.AuraUtil and _G.AuraUtil.AuraUpdateChangedType
local AuraPolicies = _G.CustomAuraContainerAuraProcessingPolicy
local AuraSortMethod = _G.AuraContainerSortMethod

local function EnsureNativeAuraFonts()
	if not _G.sRaidFramesAuraTimerFont then
		local tf = CreateFont("sRaidFramesAuraTimerFont")
		local path = (GameFontNormal and GameFontNormal:GetFont()) or STANDARD_TEXT_FONT
		tf:SetFont(path, 8, "OUTLINE")
		tf:SetTextColor(1, 0.9, 0.2, 1)
	end
	if not _G.sRaidFramesAuraCountFont then
		local cf = CreateFont("sRaidFramesAuraCountFont")
		local path = (GameFontNormal and GameFontNormal:GetFont()) or STANDARD_TEXT_FONT
		cf:SetFont(path, 8, "OUTLINE")
		cf:SetTextColor(0.45, 1, 0.5, 1)
	end
end

local nativeDispelColorMap
local function AddNativeDispelTypeTexture(btn, tex, useBorderStyle)
	local styleEnum = _G.Enum and _G.Enum.CustomAuraButtonDispelTypeTextureStyle
	if useBorderStyle then
		pcall(btn.AddDispelTypeTexture, btn, tex, { style = styleEnum and styleEnum.Border })
		return
	end
	if not nativeDispelColorMap and _G.CreateColor then
		nativeDispelColorMap = {
			Magic   = _G.CreateColor(0.20, 0.55, 1.00),
			Curse   = _G.CreateColor(0.75, 0.10, 1.00),
			Disease = _G.CreateColor(0.75, 0.50, 0.05),
			Poison  = _G.CreateColor(0.10, 0.75, 0.15),
		}
	end
	if not pcall(btn.AddDispelTypeTexture, btn, tex, { style = styleEnum and styleEnum.PreserveAsset, customDispelColorMap = nativeDispelColorMap }) then
		pcall(btn.AddDispelTypeTexture, btn, tex, { style = styleEnum and styleEnum.PreserveAsset })
	end
end

local function InitNativeAuraButton(btn, size, borderColor, isDebuff, forceHideNumbers)
	EnsureNativeAuraFonts()
	btn._isDebuff = isDebuff and true or false
	btn._forceHideNumbers = forceHideNumbers and true or false
	local timerOpt = isDebuff and sRaidFrames.opt.debufftimer or sRaidFrames.opt.bufftimer
	local showTimers = timerOpt and timerOpt.show
	local hideNums = forceHideNumbers or not showTimers
	pcall(btn.SetIcon, btn, btn.Icon)
	pcall(btn.SetDurationCooldown, btn, btn.Cooldown)
	if btn.Border and borderColor then
		pcall(btn.Border.SetColorTexture, btn.Border, borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
	end
	if btn.Cooldown then
		pcall(btn.Cooldown.SetHideCountdownNumbers, btn.Cooldown, hideNums and true or false)
		if btn.Cooldown.SetCountdownFont then
			pcall(btn.Cooldown.SetCountdownFont, btn.Cooldown, "sRaidFramesAuraTimerFont")
		end
		if btn.Cooldown.SetCountdownAbbrevThreshold then
			pcall(btn.Cooldown.SetCountdownAbbrevThreshold, btn.Cooldown, 1)
		end
	end
	local holder = btn.CountHolder
	local fs = holder and holder.Count
	if fs and btn.SetApplicationCount then
		pcall(fs.SetFontObject, fs, "sRaidFramesAuraCountFont")
		pcall(holder.SetFrameLevel, holder, btn:GetFrameLevel() + 10)
		local util = _G.C_AuraContainerUtil
		local opts
		if util and util.ProcessCustomAuraButtonApplicationCountOptions then
			local ok, o = pcall(util.ProcessCustomAuraButtonApplicationCountOptions, {})
			if ok then opts = o end
		end
		if not (opts and pcall(btn.SetApplicationCount, btn, fs, opts)) then
			pcall(btn.SetApplicationCount, btn, fs)
		end
	end
	pcall(btn.SetSize, btn, size, size)
	pcall(btn.SetMouseClickEnabled, btn, false)
	pcall(btn.SetMouseMotionEnabled, btn, true)
	pcall(btn.SetPropagateMouseMotion, btn, true)
	pcall(btn.SetTooltipAnchorPoint, btn, "ANCHOR_RIGHT")
end

local function InitNativeDispelButton(btn, unitFrame, size)
	InitNativeAuraButton(btn, size, nil, true, false)
	if btn.DispelBorder then
		AddNativeDispelTypeTexture(btn, btn.DispelBorder, true)
		pcall(btn.DispelBorder.SetShown, btn.DispelBorder, sRaidFrames.opt.DispelIconBorder ~= false)
	end
	if btn.DispelGlow then
		pcall(btn.DispelGlow.SetAlpha, btn.DispelGlow, 0)
	end
	-- Attach a dispel-colored background overlay to the unit frame's safe backdrop
	-- so the frame background highlights in combat even when aura data is secret!
	if unitFrame and unitFrame._safeBackdropFrame and not btn._srfBgTint then
		local bgHolder = CreateFrame("Frame", nil, btn)
		bgHolder:SetAllPoints(unitFrame._safeBackdropFrame)
		bgHolder:SetFrameLevel(unitFrame._safeBackdropFrame:GetFrameLevel() + 1)
		bgHolder:SetAlpha(sRaidFrames.opt.HighlightDebuffs == "never" and 0 or 0.55)
		local bgTex = bgHolder:CreateTexture(nil, "ARTWORK")
		bgTex:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
		bgTex:SetPoint("TOPLEFT", unitFrame._safeBackdropFrame, "TOPLEFT", 3, -3)
		bgTex:SetPoint("BOTTOMRIGHT", unitFrame._safeBackdropFrame, "BOTTOMRIGHT", -3, 3)
		bgTex:Show()
		AddNativeDispelTypeTexture(btn, bgTex, false)
		btn._srfBgHolder = bgHolder
		btn._srfBgTint = bgTex
		unitFrame._srfBgHolders = unitFrame._srfBgHolders or {}
		tinsert(unitFrame._srfBgHolders, bgHolder)
	end
end

local excludeFromHoTsCache
local function GetExcludeFromHoTs()
	if not excludeFromHoTsCache then
		excludeFromHoTsCache = {}
		for id in pairs(Compat.FoodDrinkSpellIDs) do excludeFromHoTsCache[id] = true end
		for id in pairs(Compat.ImportantCombatBuffIDs) do excludeFromHoTsCache[id] = true end
	end
	return excludeFromHoTsCache
end

function sRaidFrames:EnsureNativeAuraContainers()
	if privateFuncs.IsInCombat() then
		self:ScheduleLeaveCombatAction("EnsureNativeAuraContainers")
		return
	end
	for _, f in pairs(self.frames) do
		if not f.hasNativeAuraContainers then
			self:CreateNativeAuraContainers(f)
			local layout = self:GetLayout()
			if layout and layout.StyleUnitFrame then
				layout.StyleUnitFrame(f)
			end
			local unit = f:GetAttribute("unit")
			if unit then
				self:SyncNativeAuraContainers(f, self:GetVehicleUnit(unit))
			end
		end
	end
end

function sRaidFrames:CreateNativeAuraContainers(f)
	if not FlowDir or f.hasNativeAuraContainers or f.nativeAurasTried then return end
	if privateFuncs.IsInCombat() then
		self:ScheduleLeaveCombatAction("EnsureNativeAuraContainers")
		return
	end
	local vf = f._visualFrame or f
	local baseLevel = vf:GetFrameLevel() + 6

	-- 1. Dispellable Debuffs Container (TOPRIGHT, growing Left)
	local ok1, dispelBox = pcall(CreateFrame, "AuraContainer", nil, vf, "CustomAuraContainerTemplate")
	if not ok1 or not dispelBox then return end
	pcall(dispelBox.SetFrameStrata, dispelBox, vf:GetFrameStrata())
	pcall(dispelBox.SetFrameLevel, dispelBox, baseLevel + 1)

	local conf1 = pcall(function()
		dispelBox:SetPoint("TOPRIGHT", vf, "TOPRIGHT", -4, -4)
		dispelBox:SetFlowLayoutAnchorPoint("TOPRIGHT")
		dispelBox:SetFlowLayoutGrowthDirection(FlowDir.Left, FlowDir.Down)
		dispelBox:EnableMouse(false)
		if dispelBox.SetEditModePreviewEnabled then dispelBox:SetEditModePreviewEnabled(false) end
		if AuraPolicies and AuraSortMethod then
			dispelBox:SetAuraProcessingPolicy(AuraPolicies.ProcessAura, { displayOnlyDispellableDebuffs = sRaidFrames.opt.ShowOnlyDispellable and true or false })
		end
		dispelBox:AddAuraGroup("dispel", "HARMFUL|RAID", {
			maxFrameCount = 2,
			sortMethod = AuraSortMethod and AuraSortMethod.UnitFrameDebuff,
			templateNames = { "sRaidFramesDispelIconTemplate" },
			initializeFrame = function(btn) InitNativeDispelButton(btn, f, sRaidFrames.opt.AuraIconSize or 13) end,
			layout = { elementSpacing = 1, elementWidth = (sRaidFrames.opt.AuraIconSize or 13) + 1, elementHeight = sRaidFrames.opt.AuraIconSize or 13 },
		})
		if dispelBox.SetAuraGroupMaxFrameCount then dispelBox:SetAuraGroupMaxFrameCount("dispel", 2) end
	end)
	if not conf1 then
		dispelBox:Hide()
		return
	end
	f.nativeAurasTried = true

	-- 2. Boss Debuffs, Crowd Control & Weakened Soul Container (chained left of dispelBox)
	local ok2, bossBox = pcall(CreateFrame, "AuraContainer", nil, vf, "CustomAuraContainerTemplate")
	if ok2 and bossBox then
		pcall(bossBox.SetFrameStrata, bossBox, vf:GetFrameStrata())
		pcall(bossBox.SetFrameLevel, bossBox, baseLevel + 1)
		local conf2 = pcall(function()
			bossBox:SetPoint("TOPRIGHT", vf, "TOPRIGHT", -4, -4)
			bossBox:SetFlowLayoutAnchorPoint("TOPRIGHT")
			bossBox:SetFlowLayoutGrowthDirection(FlowDir.Left, FlowDir.Down)
			bossBox:EnableMouse(false)
			if bossBox.SetEditModePreviewEnabled then bossBox:SetEditModePreviewEnabled(false) end
			if AuraPolicies and AuraPolicies.ProcessAura then
				bossBox:SetAuraProcessingPolicy(AuraPolicies.ProcessAura, { displayOnlyDispellableDebuffs = false })
			end
			local bossCandidates = { isBossAura = true }
			if AuraChangedType and AuraChangedType.Debuff then
				bossCandidates.processedAuraType = AuraChangedType.Debuff
			end
			local iconSize = sRaidFrames.opt.AuraIconSize or 13
			bossBox:AddAuraGroup("boss", "HARMFUL|!RAID|!PLAYER", {
				maxFrameCount = 1,
				sortMethod = AuraSortMethod and AuraSortMethod.UnitFrameDebuff,
				templateNames = { "sRaidFramesAuraIconTemplate" },
				initializeFrame = function(btn) InitNativeAuraButton(btn, iconSize, {1.0, 0.75, 0.05, 1}, true, false) end,
				candidateFilters = bossCandidates,
				layout = { elementSpacing = 0, groupSpacing = 0, elementWidth = iconSize + 1, elementHeight = iconSize, layoutIndex = 1 },
			})
			if bossBox.SetAuraGroupMaxFrameCount then bossBox:SetAuraGroupMaxFrameCount("boss", 1) end

			bossBox:AddAuraGroup("cc", "HARMFUL|!RAID|!PLAYER|CROWD_CONTROL", {
				maxFrameCount = 1,
				sortMethod = AuraSortMethod and AuraSortMethod.UnitFrameDebuff,
				templateNames = { "sRaidFramesAuraIconTemplate" },
				initializeFrame = function(btn) InitNativeAuraButton(btn, iconSize, {1.0, 0.15, 0.15, 1}, true, false) end,
				candidateFilters = { isBossAura = false },
				layout = { elementSpacing = 0, groupSpacing = 0, elementWidth = iconSize + 1, elementHeight = iconSize, layoutIndex = 2 },
			})
			if bossBox.SetAuraGroupMaxFrameCount then bossBox:SetAuraGroupMaxFrameCount("cc", 1) end

			-- Player-caused debuffs such as Priest's Weakened Soul (虚弱灵魂 6788)
			bossBox:AddAuraGroup("own_debuff", "HARMFUL|PLAYER", {
				maxFrameCount = 1,
				templateNames = { "sRaidFramesAuraIconTemplate" },
				initializeFrame = function(btn) InitNativeAuraButton(btn, max(10, iconSize - 1), {0.85, 0.15, 0.25, 1}, true, false) end,
				candidateFilters = { maxDuration = 300 },
				layout = { elementSpacing = 0, groupSpacing = 0, elementWidth = iconSize, elementHeight = max(10, iconSize - 1), layoutIndex = 3 },
			})
			if bossBox.SetAuraGroupMaxFrameCount then bossBox:SetAuraGroupMaxFrameCount("own_debuff", 1) end
		end)
		if conf2 then
			if not pcall(bossBox.SetPoint, bossBox, "TOPRIGHT", dispelBox, "TOPLEFT", 0, 0) then
				bossBox:ClearAllPoints()
				bossBox:SetPoint("TOPRIGHT", vf, "TOPRIGHT", -4, -4)
			end
		else
			bossBox:Hide()
			bossBox = nil
		end
	end

	-- 3. Priest Buffs, HoTs & Defensive Cooldowns Container (chained left of bossBox / dispelBox)
	local ok3, buffBox = pcall(CreateFrame, "AuraContainer", nil, vf, "CustomAuraContainerTemplate")
	if ok3 and buffBox then
		pcall(buffBox.SetFrameStrata, buffBox, vf:GetFrameStrata())
		pcall(buffBox.SetFrameLevel, buffBox, baseLevel)
		local conf3 = pcall(function()
			buffBox:SetPoint("TOPRIGHT", vf, "TOPRIGHT", -4, -4)
			buffBox:SetFlowLayoutAnchorPoint("TOPRIGHT")
			buffBox:SetFlowLayoutGrowthDirection(FlowDir.Left, FlowDir.Down)
			buffBox:EnableMouse(false)
			if buffBox.SetEditModePreviewEnabled then buffBox:SetEditModePreviewEnabled(false) end

			-- Group 1: Priest combat buffs (PW:S, Renew, PoM, Penance, Fear Ward, PI, Pain Supp, Divine Aegis, etc.) + External/Big Defensives
			local buffSize = max(9, (sRaidFrames.opt.AuraIconSize or 13) - 2)
			buffBox:AddAuraGroup("priest_combat", "HELPFUL", {
				maxFrameCount = 3,
				templateNames = { "sRaidFramesAuraIconTemplate" },
				initializeFrame = function(btn) InitNativeAuraButton(btn, buffSize, {0.15, 0.75, 0.95, 1}, false, false) end,
				candidateFilters = { includeSpellIDs = Compat.ImportantCombatBuffIDs },
				layout = { elementSpacing = 1, groupSpacing = 1, elementWidth = buffSize, elementHeight = buffSize, layoutIndex = 1 },
			})
			if buffBox.SetAuraGroupMaxFrameCount then buffBox:SetAuraGroupMaxFrameCount("priest_combat", 3) end

			-- Group 2: Any other short buff/HoT cast by the player (excluding food/drink & already-included combat buffs)
			buffBox:AddAuraGroup("player_hots", "HELPFUL|PLAYER", {
				maxFrameCount = 2,
				templateNames = { "sRaidFramesAuraIconTemplate" },
				initializeFrame = function(btn) InitNativeAuraButton(btn, buffSize, {0.1, 0.1, 0.1, 0.9}, false, false) end,
				candidateFilters = { maxDuration = 60, excludeSpellIDs = GetExcludeFromHoTs() },
				layout = { elementSpacing = 1, groupSpacing = 1, elementWidth = buffSize, elementHeight = buffSize, layoutIndex = 2 },
			})
			if buffBox.SetAuraGroupMaxFrameCount then buffBox:SetAuraGroupMaxFrameCount("player_hots", 2) end

			-- Group 3: Class-specific raid buffs by default (or all-class raid buffs when set to "all")
			local raidBuffSize = max(8, buffSize - 1)
			local playerClass = sRaidFrames.PlayerClass or select(2, UnitClass("player"))
			buffBox:AddAuraGroup("priest_raid", "HELPFUL", {
				maxFrameCount = 4,
				templateNames = { "sRaidFramesAuraIconTemplate" },
				initializeFrame = function(btn) InitNativeAuraButton(btn, raidBuffSize, {0.1, 0.1, 0.1, 0.9}, false, true) end,
				candidateFilters = { includeSpellIDs = Compat.GetPlayerClassRaidBuffIDs(playerClass) },
				layout = { elementSpacing = 1, groupSpacing = 1, elementWidth = raidBuffSize, elementHeight = raidBuffSize, layoutIndex = 3 },
			})
			if buffBox.SetAuraGroupMaxFrameCount then buffBox:SetAuraGroupMaxFrameCount("priest_raid", 4) end
		end)
		if conf3 then
			-- Buffs stay on the RIGHT (TOPRIGHT); Debuffs chain to the LEFT of Buffs
			buffBox:ClearAllPoints()
			buffBox:SetPoint("TOPRIGHT", vf, "TOPRIGHT", -4, -4)
			if dispelBox then
				pcall(dispelBox.ClearAllPoints, dispelBox)
				if not pcall(dispelBox.SetPoint, dispelBox, "TOPRIGHT", buffBox, "TOPLEFT", 0, 0) then
					dispelBox:ClearAllPoints()
					dispelBox:SetPoint("TOPRIGHT", vf, "TOPRIGHT", -4, -4)
				end
				if bossBox then
					pcall(bossBox.ClearAllPoints, bossBox)
					if not pcall(bossBox.SetPoint, bossBox, "TOPRIGHT", dispelBox, "TOPLEFT", 0, 0) then
						bossBox:ClearAllPoints()
						bossBox:SetPoint("TOPRIGHT", vf, "TOPRIGHT", -4, -4)
					end
				end
			end
		else
			buffBox:Hide()
			buffBox = nil
		end
	end

	f.dispelBox = dispelBox
	f.bossDebuffBox = bossBox
	f.buffBox = buffBox
	f.hasNativeAuraContainers = (dispelBox ~= nil)

	dispelBox:SetUnit("none")
	if bossBox then bossBox:SetUnit("none") end
	if buffBox then buffBox:SetUnit("none") end
end

function sRaidFrames:StyleNativeAuraContainers(f, offsetX, offsetY)
	if privateFuncs.IsInCombat() then
		self:ScheduleLeaveCombatAction("ApplyLayout")
		return
	end
	offsetX = offsetX or -4
	offsetY = offsetY or -4
	local vf = f._visualFrame or f
	local inParty = not IsInRaid()
	local iconSize = (self.opt.AuraIconSize or 13) + (inParty and 2 or 0)
	local buffSize = max(9, iconSize - 2)
	local raidBuffSize = max(8, buffSize - 1)

	local function resizeGroup(box, group, s, spacing)
		if not box then return end
		local ok, count = pcall(box.GetAuraGroupFrameCount, box, group)
		for i = 1, (ok and count or 0) do
			local got, btn = pcall(box.GetAuraGroupFrame, box, group, i)
			if got and btn and (not btn.CanBeAccessedInContext or btn:CanBeAccessedInContext()) then
				pcall(btn.SetSize, btn, s, s)
			end
		end
		pcall(box.SetAuraGroupLayout, box, group, { elementSpacing = spacing, elementWidth = s + spacing, elementHeight = s })
	end

	if f.isPetGroupFrame and f.hpbar then
		local petSz = 9
		if f.buffBox then
			resizeGroup(f.buffBox, "priest_combat", petSz, 1)
			resizeGroup(f.buffBox, "player_hots", petSz, 1)
			resizeGroup(f.buffBox, "priest_raid", petSz, 1)
			pcall(f.buffBox.SetFrameLevel, f.buffBox, f.hpbar:GetFrameLevel() + 5)
			pcall(f.buffBox.ClearAllPoints, f.buffBox)
			pcall(f.buffBox.SetPoint, f.buffBox, "TOPRIGHT", f.hpbar, "TOPRIGHT", -1, -1)
		end
		if f.dispelBox then
			resizeGroup(f.dispelBox, "dispel", petSz, 1)
			pcall(f.dispelBox.SetFrameLevel, f.dispelBox, f.hpbar:GetFrameLevel() + 5)
			pcall(f.dispelBox.ClearAllPoints, f.dispelBox)
			if f.buffBox then
				if not pcall(f.dispelBox.SetPoint, f.dispelBox, "TOPRIGHT", f.buffBox, "TOPLEFT", -1, 0) then
					pcall(f.dispelBox.ClearAllPoints, f.dispelBox)
					pcall(f.dispelBox.SetPoint, f.dispelBox, "TOPRIGHT", f.hpbar, "TOPRIGHT", -1, -1)
				end
			else
				pcall(f.dispelBox.SetPoint, f.dispelBox, "TOPRIGHT", f.hpbar, "TOPRIGHT", -1, -1)
			end
		end
		if f.bossDebuffBox then
			pcall(f.bossDebuffBox.Hide, f.bossDebuffBox)
		end
		return
	end

	if f.buffBox then
		resizeGroup(f.buffBox, "priest_combat", buffSize, 1)
		resizeGroup(f.buffBox, "player_hots", buffSize, 1)
		resizeGroup(f.buffBox, "priest_raid", raidBuffSize, 1)
		pcall(f.buffBox.ClearAllPoints, f.buffBox)
		pcall(f.buffBox.SetPoint, f.buffBox, "TOPRIGHT", vf, "TOPRIGHT", offsetX, offsetY)
	end
	if f.dispelBox then
		resizeGroup(f.dispelBox, "dispel", iconSize, 1)
		pcall(f.dispelBox.ClearAllPoints, f.dispelBox)
		if f.buffBox then
			if not pcall(f.dispelBox.SetPoint, f.dispelBox, "TOPRIGHT", f.buffBox, "TOPLEFT", 0, 0) then
				pcall(f.dispelBox.ClearAllPoints, f.dispelBox)
				pcall(f.dispelBox.SetPoint, f.dispelBox, "TOPRIGHT", vf, "TOPRIGHT", offsetX, offsetY)
			end
		else
			pcall(f.dispelBox.SetPoint, f.dispelBox, "TOPRIGHT", vf, "TOPRIGHT", offsetX, offsetY)
		end
	end
	if f.bossDebuffBox and f.dispelBox then
		resizeGroup(f.bossDebuffBox, "boss", iconSize, 0)
		resizeGroup(f.bossDebuffBox, "cc", iconSize, 0)
		resizeGroup(f.bossDebuffBox, "own_debuff", max(10, iconSize - 1), 0)
		pcall(f.bossDebuffBox.ClearAllPoints, f.bossDebuffBox)
		if not pcall(f.bossDebuffBox.SetPoint, f.bossDebuffBox, "TOPRIGHT", f.dispelBox, "TOPLEFT", 0, 0) then
			pcall(f.bossDebuffBox.ClearAllPoints, f.bossDebuffBox)
			pcall(f.bossDebuffBox.SetPoint, f.bossDebuffBox, "TOPRIGHT", vf, "TOPRIGHT", offsetX, offsetY)
		end
	end
end

function sRaidFrames:SyncNativeAuraContainers(f, unit)
	if not f.hasNativeAuraContainers or privateFuncs.IsInCombat() then return end
	local buffType = self.opt.BuffType or "both"
	local showDebuffs = (buffType == "debuffs" or buffType == "buffsifnotdebuffed" or buffType == "both")
	local showBuffs = (buffType == "buffs" or buffType == "buffsifnotdebuffed" or buffType == "both")
	local showDebuffTimer = self.opt.debufftimer and self.opt.debufftimer.show
	local showBuffTimer = self.opt.bufftimer and self.opt.bufftimer.show
	local showDispelBorder = self.opt.DispelIconBorder ~= false

	local function syncGroupButtons(box, group, isDebuff, isDispelGroup)
		if not box or not box.GetAuraGroupFrameCount or not box.GetAuraGroupFrame then return end
		local ok, count = pcall(box.GetAuraGroupFrameCount, box, group)
		local showTimer = isDebuff and showDebuffTimer or showBuffTimer
		for i = 1, (ok and count or 0) do
			local got, btn = pcall(box.GetAuraGroupFrame, box, group, i)
			if got and btn and (not btn.CanBeAccessedInContext or btn:CanBeAccessedInContext()) then
				if btn.Cooldown then
					local hideNums = btn._forceHideNumbers or not showTimer
					pcall(btn.Cooldown.SetHideCountdownNumbers, btn.Cooldown, hideNums and true or false)
				end
				if isDispelGroup and btn.DispelBorder then
					pcall(btn.DispelBorder.SetShown, btn.DispelBorder, showDispelBorder)
				end
			end
		end
	end

	if f.isPetGroupFrame then
		local allowPetAuras = self.opt.ShowPetBuffs and unit
		if f.dispelBox then
			if f.dispelBox.SetAuraProcessingPolicy and AuraPolicies and AuraPolicies.ProcessAura then
				pcall(f.dispelBox.SetAuraProcessingPolicy, f.dispelBox, AuraPolicies.ProcessAura, {
					displayOnlyDispellableDebuffs = self.opt.ShowOnlyDispellable and true or false,
				})
			end
			if f.dispelBox.SetAuraGroupMaxFrameCount then
				pcall(f.dispelBox.SetAuraGroupMaxFrameCount, f.dispelBox, "dispel", 1)
			end
			syncGroupButtons(f.dispelBox, "dispel", true, true)
			local u = (allowPetAuras and showDebuffs) and unit or "none"
			if f.dispelBox:GetUnit() ~= u then pcall(f.dispelBox.SetUnit, f.dispelBox, u) end
			pcall(f.dispelBox.SetShown, f.dispelBox, u ~= "none")
		end
		if f.bossDebuffBox then
			if f.bossDebuffBox:GetUnit() ~= "none" then pcall(f.bossDebuffBox.SetUnit, f.bossDebuffBox, "none") end
			pcall(f.bossDebuffBox.Hide, f.bossDebuffBox)
		end
		if f.buffBox then
			if f.buffBox.SetAuraGroupMaxFrameCount then
				pcall(f.buffBox.SetAuraGroupMaxFrameCount, f.buffBox, "priest_combat", 2)
				pcall(f.buffBox.SetAuraGroupMaxFrameCount, f.buffBox, "player_hots", 2)
				pcall(f.buffBox.SetAuraGroupMaxFrameCount, f.buffBox, "priest_raid", 0)
			end
			if f.buffBox.SetAuraGroupCandidateFilters and Compat.PetBuffSpellIDs then
				pcall(f.buffBox.SetAuraGroupCandidateFilters, f.buffBox, "priest_combat", { includeSpellIDs = Compat.PetBuffSpellIDs })
				pcall(f.buffBox.SetAuraGroupCandidateFilters, f.buffBox, "priest_raid", { includeSpellIDs = { [0] = true } })
			end
			syncGroupButtons(f.buffBox, "priest_combat", false, false)
			syncGroupButtons(f.buffBox, "player_hots", false, false)
			local u = (allowPetAuras and showBuffs) and unit or "none"
			if f.buffBox:GetUnit() ~= u then pcall(f.buffBox.SetUnit, f.buffBox, u) end
			pcall(f.buffBox.SetShown, f.buffBox, u ~= "none")
		end
		return
	end

	if f.dispelBox then
		if f.dispelBox.SetAuraProcessingPolicy and AuraPolicies and AuraPolicies.ProcessAura then
			pcall(f.dispelBox.SetAuraProcessingPolicy, f.dispelBox, AuraPolicies.ProcessAura, {
				displayOnlyDispellableDebuffs = self.opt.ShowOnlyDispellable and true or false,
			})
		end
		if f.dispelBox.SetAuraGroupMaxFrameCount then
			pcall(f.dispelBox.SetAuraGroupMaxFrameCount, f.dispelBox, "dispel", (not IsInRaid()) and 4 or 2)
		end
		if f._srfBgHolders then
			local bgAlpha = (self.opt.HighlightDebuffs == "never") and 0 or 0.55
			for _, holder in ipairs(f._srfBgHolders) do
				pcall(holder.SetAlpha, holder, bgAlpha)
			end
		end
		syncGroupButtons(f.dispelBox, "dispel", true, true)
		local u = (unit and showDebuffs) and unit or "none"
		if f.dispelBox:GetUnit() ~= u then pcall(f.dispelBox.SetUnit, f.dispelBox, u) end
		pcall(f.dispelBox.SetShown, f.dispelBox, u ~= "none")
	end
	if f.bossDebuffBox then
		local inParty = not IsInRaid()
		local showBoss = self.opt.ShowBossDebuffs
		local showPriest = self.opt.ShowPriestBuffs
		if f.bossDebuffBox.SetAuraGroupMaxFrameCount then
			pcall(f.bossDebuffBox.SetAuraGroupMaxFrameCount, f.bossDebuffBox, "boss", showBoss and (inParty and 3 or 2) or 0)
			pcall(f.bossDebuffBox.SetAuraGroupMaxFrameCount, f.bossDebuffBox, "cc", showBoss and (inParty and 2 or 1) or 0)
			pcall(f.bossDebuffBox.SetAuraGroupMaxFrameCount, f.bossDebuffBox, "own_debuff", showPriest and (inParty and 2 or 1) or 0)
		end
		syncGroupButtons(f.bossDebuffBox, "boss", true, false)
		syncGroupButtons(f.bossDebuffBox, "cc", true, false)
		syncGroupButtons(f.bossDebuffBox, "own_debuff", true, false)
		local u = (unit and showDebuffs) and unit or "none"
		if f.bossDebuffBox:GetUnit() ~= u then pcall(f.bossDebuffBox.SetUnit, f.bossDebuffBox, u) end
		pcall(f.bossDebuffBox.SetShown, f.bossDebuffBox, u ~= "none")
	end
	if f.buffBox then
		local inParty = not IsInRaid()
		local mode = self.opt.PriestBuffFilter or "class"
		local isMineOnly = (mode == "mine")
		local showPriest = self.opt.ShowPriestBuffs
		if f.buffBox.SetAuraGroupMaxFrameCount then
			pcall(f.buffBox.SetAuraGroupMaxFrameCount, f.buffBox, "priest_combat", (not showPriest or isMineOnly) and 0 or (inParty and 4 or 3))
			pcall(f.buffBox.SetAuraGroupMaxFrameCount, f.buffBox, "player_hots", isMineOnly and 6 or (inParty and 3 or 2))
			pcall(f.buffBox.SetAuraGroupMaxFrameCount, f.buffBox, "priest_raid", (not showPriest or mode == "combat" or isMineOnly) and 0 or (inParty and 6 or 4))
		end
		-- Configure whether raid-wide buffs are filtered by player class ("class"), all classes ("all"), or hidden ("combat"/"mine")
		if f.buffBox.SetAuraGroupCandidateFilters then
			if isMineOnly then
				pcall(f.buffBox.SetAuraGroupCandidateFilters, f.buffBox, "player_hots", { excludeSpellIDs = Compat.FoodDrinkSpellIDs })
			else
				pcall(f.buffBox.SetAuraGroupCandidateFilters, f.buffBox, "player_hots", { maxDuration = 60, excludeSpellIDs = GetExcludeFromHoTs() })
			end
			if not self.opt.ShowPriestBuffs or mode == "combat" or isMineOnly then
				pcall(f.buffBox.SetAuraGroupCandidateFilters, f.buffBox, "priest_raid", { includeSpellIDs = { [0] = true } })
			elseif mode == "all" then
				pcall(f.buffBox.SetAuraGroupCandidateFilters, f.buffBox, "priest_raid", { includeSpellIDs = Compat.AllClassRaidBuffIDs })
			else
				local playerClass = self.PlayerClass or select(2, UnitClass("player"))
				pcall(f.buffBox.SetAuraGroupCandidateFilters, f.buffBox, "priest_raid", { includeSpellIDs = Compat.GetPlayerClassRaidBuffIDs(playerClass) })
			end
		end
		syncGroupButtons(f.buffBox, "priest_combat", false, false)
		syncGroupButtons(f.buffBox, "player_hots", false, false)
		syncGroupButtons(f.buffBox, "priest_raid", false, false)
		local u = (unit and showBuffs) and unit or "none"
		if f.buffBox:GetUnit() ~= u then pcall(f.buffBox.SetUnit, f.buffBox, u) end
		pcall(f.buffBox.SetShown, f.buffBox, u ~= "none")
	end
end

local function SetAuraButtonBorder(btn, r, g, b, a)
	if not btn or not btn.border then return end
	if r and g and b then
		btn.border:SetVertexColor(r, g, b, a or 1)
		btn.border:Show()
	else
		btn.border:Hide()
	end
end

local function SetAuraButtonCooldown(btn, unit, duration, expirationTime, auraInstanceID)
	if not btn or not btn.cooldown then return end
	local shown = false
	if auraInstanceID and _G.C_UnitAuras and _G.C_UnitAuras.GetAuraDuration and btn.cooldown.SetCooldownFromDurationObject then
		local ok, durObj = pcall(_G.C_UnitAuras.GetAuraDuration, unit, auraInstanceID)
		if ok and durObj then
			shown = pcall(btn.cooldown.SetCooldownFromDurationObject, btn.cooldown, durObj)
		end
	end
	if not shown then
		if duration and expirationTime and not IsSecret(duration) and not IsSecret(expirationTime) and duration > 0 and expirationTime > 0 then
			btn.cooldown:SetCooldown(expirationTime - duration, duration)
		else
			btn.cooldown:Clear()
		end
	end
end

function sRaidFrames:UpdateAuras(munit)
	if not self:IsTracking(munit) then return end
	local layout = self:GetLayout()
	local unit = self:GetVehicleUnit(munit)

	local BuffType = self.opt.BuffType
	local HighLightRule = self.opt.HighlightDebuffs
	local DebuffFilter = self.opt.DebuffFilter
	local DebuffWhitelist = self.opt.DebuffWhitelist
	local ShowOnlyDispellable = self.opt.ShowOnlyDispellable
	local ShowPriestBuffs = self.opt.ShowPriestBuffs
	local PriestBuffFilter = self.opt.PriestBuffFilter
	local ShowBossDebuffs = self.opt.ShowBossDebuffs
	local BossWhitelist = self.opt.BossWhitelist

	-- Active DBM / BigWigs / Boss Cast Warning on this unit
	local activeDBM = self.dbmWarnings[munit]
	if activeDBM and GetTime() >= activeDBM.expires then
		self.dbmWarnings[munit] = nil
		self:UnsetStatus(munit, "BossWarning")
		activeDBM = nil
	end

	-- 1. Scan Debuffs (when aura data is not secret)
	local chosenDebuffs = {}
	local firstDispelType, firstDispelName = nil, nil
	local firstBossDebuffName = nil
	local foundStatusBuffs = {}
	local aurasAreSecret = (_G.C_Secrets and _G.C_Secrets.ShouldAurasBeSecret and _G.C_Secrets.ShouldAurasBeSecret()) and true or false

	local idx = 1
	while not aurasAreSecret and idx <= 40 do
		local name, icon, count, dispelType, duration, expirationTime, source, isStealable, spellId, isBossAura, auraInstanceID, isSecret = GetUnitDebuff(unit, idx)
		if isSecret then
			aurasAreSecret = true
			break
		end
		if not name then break end

		local canDispel = dispelType and self:CanDispell(dispelType)
		local isBoss = ShowBossDebuffs and Compat.IsImportantBossSkill(name, spellId, isBossAura, BossWhitelist)
		local isPriestDebuff = ShowPriestBuffs and Compat.IsPriestImportantDebuff(name, spellId)

		if isBoss and not firstBossDebuffName then
			firstBossDebuffName = name
		end

		if dispelType and not firstDispelType and (HighLightRule ~= "onlyself" or canDispel) then
			firstDispelType = dispelType
			firstDispelName = name
		end

		local statusId = (spellId and self.statusSpellByID[spellId]) or self.statusSpellTable[name]
		if statusId then
			foundStatusBuffs[statusId] = (source == "player")
		end

		if not DebuffFilter[name] then
			local shouldShow = false
			local priority = 1
			if isBoss then
				shouldShow = true
				priority = 4
			elseif canDispel then
				shouldShow = true
				priority = 3
			elseif isPriestDebuff or DebuffWhitelist[name] then
				shouldShow = true
				priority = 2
			elseif not ShowOnlyDispellable then
				shouldShow = true
				priority = 1
			end

			if shouldShow then
				tinsert(chosenDebuffs, {
					index = idx,
					name = name,
					icon = icon,
					count = count or 0,
					dispelType = dispelType,
					duration = duration or 0,
					expirationTime = expirationTime or 0,
					spellId = spellId,
					isBoss = isBoss,
					isPriestDebuff = isPriestDebuff,
					auraInstanceID = auraInstanceID,
					priority = priority,
				})
			end
		end

		idx = idx + 1
	end

	-- Update non-secret Debuff & Boss status maps
	if not aurasAreSecret then
		self:UnsetStatus(munit, "Debuff_Curse")
		self:UnsetStatus(munit, "Debuff_Magic")
		self:UnsetStatus(munit, "Debuff_Poison")
		self:UnsetStatus(munit, "Debuff_Disease")
		if HighLightRule ~= "never" and firstDispelType and self.opt.StatusMaps["Debuff_" .. firstDispelType] then
			self:SetStatus(munit, "Debuff_" .. firstDispelType, firstDispelName, nil, true)
		end

		if firstBossDebuffName then
			self:SetStatus(munit, "BossDebuff", "! " .. firstBossDebuffName, nil, true)
		else
			self:UnsetStatus(munit, "BossDebuff")
		end
	end

	if #chosenDebuffs > 1 then
		tsort(chosenDebuffs, function(a, b)
			if a.priority ~= b.priority then return a.priority > b.priority end
			return a.index < b.index
		end)
	end

	-- 2. Scan Buffs (when aura data is not secret)
	local chosenBuffs = {}
	local BuffFilter = self.opt.BuffFilter
	local HasBuffFilter = next(BuffFilter) and true or false
	local BuffDisplayOptions = self.opt.BuffDisplayOptions
	local BuffDisplay = self.opt.BuffDisplay.default

	if not aurasAreSecret then
		idx = 1
		while idx <= 40 do
			local name, icon, count, dispelType, duration, expirationTime, caster, isStealable, spellId, isBossAura, auraInstanceID, isSecret = GetUnitBuff(unit, idx)
			if isSecret then
				aurasAreSecret = true
				break
			end
			if not name then break end

			local isMine = (caster == "player")
			local lowerName = strlower(name)

			local statusId = (spellId and self.statusSpellByID[spellId]) or self.statusSpellTable[name]
			if statusId then
				foundStatusBuffs[statusId] = isMine
			end

			local playerClass = self.PlayerClass or select(2, UnitClass("player"))
			local priestPrio = ShowPriestBuffs and Compat.GetPriestBuffPriority(name, spellId) or nil
			local isMyClassRaidBuff = Compat.IsClassRaidBuff and Compat.IsClassRaidBuff(name, spellId, playerClass)
			local isAnyClassRaidBuff = Compat.IsAllClassRaidBuff and Compat.IsAllClassRaidBuff(name, spellId)
			local passPriestFilter = false
			local isOtherRaidBuff = false

			if ShowPriestBuffs then
				if PriestBuffFilter == "class" then
					passPriestFilter = isMyClassRaidBuff or (priestPrio == 2 and playerClass == "PRIEST") or false
				elseif PriestBuffFilter == "all" then
					passPriestFilter = (priestPrio ~= nil) or isAnyClassRaidBuff or false
					isOtherRaidBuff = isAnyClassRaidBuff
				elseif PriestBuffFilter == "combat" then
					passPriestFilter = (priestPrio and priestPrio >= 2) or false
				elseif PriestBuffFilter == "mine" then
					passPriestFilter = (priestPrio ~= nil and isMine) or false
				else
					passPriestFilter = isMyClassRaidBuff or (priestPrio ~= nil) or false
				end
			end

			local displaytype = BuffDisplayOptions[lowerName]
			local allowedByCombatOpt = (displaytype == 3 or not displaytype)
				or (displaytype == 1 and self.InCombat)
				or (displaytype == 2 and not self.InCombat)

			if allowedByCombatOpt and not (spellId and Compat.FoodDrinkSpellIDs[spellId]) then
				local mode = self.opt.BuffDisplay[lowerName] or BuffDisplay
				local standardMatch = ((isMine and mode == "own" and duration > 0) or mode == "all" or isOtherRaidBuff)
					and (not HasBuffFilter or BuffFilter[lowerName])

				if passPriestFilter or standardMatch then
					local sortPrio = 1
					if priestPrio == 2 then
						sortPrio = isMine and 5 or 4
					elseif isMine and duration > 0 and duration <= 60 then
						sortPrio = 3
					elseif priestPrio == 1 then
						sortPrio = 2
					end
					tinsert(chosenBuffs, {
						index = idx,
						name = name,
						icon = icon,
						count = count or 0,
						duration = duration or 0,
						expirationTime = expirationTime or 0,
						spellId = spellId,
						auraInstanceID = auraInstanceID,
						priority = sortPrio,
					})
				end
			end

			idx = idx + 1
		end

		for _, id in pairs(self.statusSpellByID) do
			if foundStatusBuffs[id] == nil then
				self:UnsetStatus(munit, "Buff_" .. id)
			end
		end
		for statusId, isMine in pairs(foundStatusBuffs) do
			local status = "Buff_" .. statusId
			local map = self.opt.StatusMaps[status]
			if map then
				local playerAllowed = not (map.options and map.options.playerOnly and not isMine)
				local classAllowed = not self.opt.classspelltable[statusId]["IsFiltered"] or self.opt.classspelltable[statusId][self.PlayerClass]
				if playerAllowed and classAllowed then
					self:SetStatus(munit, status)
				else
					self:UnsetStatus(munit, status)
				end
			else
				self:UnsetStatus(munit, status)
			end
		end
	end

	if #chosenBuffs > 1 then
		tsort(chosenBuffs, function(a, b)
			if a.priority ~= b.priority then return a.priority > b.priority end
			return a.index < b.index
		end)
	end

	-- 3. Raid Target Icon Status & SpriteSheet Marker (Secret-Safe)
	local okRT, raidtarget = false, nil
	if GetRaidTargetIndex then
		okRT, raidtarget = pcall(GetRaidTargetIndex, unit)
		if not okRT then raidtarget = nil end
	end
	local raidtargets = {"Raid Icon: Star", "Raid Icon: Circle", "Raid Icon: Diamond", "Raid Icon: Triangle", "Raid Icon: Moon", "Raid Icon: Square", "Raid Icon: Cross", "Raid Icon: Skull"}
	if raidtarget ~= nil and not IsSecret(raidtarget) then
		for i = 1, #raidtargets do
			if i ~= raidtarget then
				self:UnsetStatus(munit, raidtargets[i])
			else
				self:SetStatus(munit, raidtargets[i])
			end
		end
	elseif raidtarget == nil then
		for i = 1, #raidtargets do
			self:UnsetStatus(munit, raidtargets[i])
		end
	end

	-- 4. Update Each Frame for Unit
	for _, f in pairs(self:FindUnitFrames(munit)) do
		-- Update DBM / Boss Alert Overlay Icon (always works in and out of combat!)
		if f.dbmAlertIcon then
			if activeDBM then
				f.dbmAlertIcon.texture:SetTexture(activeDBM.icon)
				f.dbmAlertIcon.timer.expires = activeDBM.expires
				SetAuraButtonCooldown(f.dbmAlertIcon, unit, activeDBM.duration, activeDBM.expires, nil)
				f.dbmAlertIcon:Show()
			else
				f.dbmAlertIcon:Hide()
			end
		end

		-- Update Raid Target Marker Texture if present
		if f.raidMarker then
			if raidtarget then
				if f.raidMarker.SetSpriteSheetCell then
					pcall(f.raidMarker.SetSpriteSheetCell, f.raidMarker, raidtarget, 4, 4)
					f.raidMarker:Show()
				elseif not IsSecret(raidtarget) then
					local col, row = (raidtarget - 1) % 4, floor((raidtarget - 1) / 4)
					f.raidMarker:SetTexCoord(col * 0.25, (col + 1) * 0.25, row * 0.25, (row + 1) * 0.25)
					f.raidMarker:Show()
				else
					f.raidMarker:Hide()
				end
			else
				f.raidMarker:Hide()
			end
		end

		if f.hasNativeAuraContainers then
			-- Native Forever AuraContainers handle top-right buff/debuff icons both in and out of combat
			if not privateFuncs.IsInCombat() then
				self:SyncNativeAuraContainers(f, unit)
			end
			for i = 1, layout.debuffCount do
				if f["aura"..i] then f["aura"..i]:Hide() end
			end
			for i = 1, layout.buffCount do
				if f["buff"..i] then f["buff"..i]:Hide() end
			end
		else
			-- Fallback Lua Aura Buttons (for clients without CustomAuraContainerTemplate)
			for i = 1, layout.debuffCount do
				f["aura"..i]:Hide()
				f["aura"..i].timer:SetText(nil)
				f["aura"..i].timer.expires = nil
			end
			for i = 1, layout.buffCount do
				f["buff"..i]:Hide()
				f["buff"..i].timer:SetText(nil)
				f["buff"..i].timer.expires = nil
			end

			local BuffSlots = 0
			local lastBuffFrame = nil
			local allowBuffIcons = (BuffType == "buffs" or (BuffType == "buffsifnotdebuffed" and #chosenDebuffs == 0) or BuffType == "both")
			if f.isPetGroupFrame and not self.opt.ShowPetBuffs then
				allowBuffIcons = false
			end
			if allowBuffIcons then
				for _, b in ipairs(chosenBuffs) do
					if BuffSlots >= layout.buffCount then break end
					BuffSlots = BuffSlots + 1
					local buffFrame = f["buff"..BuffSlots]
					if not buffFrame then break end
					buffFrame.buffid = b.index
					buffFrame.unitid = unit
					buffFrame.showCastable = nil
					buffFrame.count:SetText(b.count and b.count > 1 and b.count or nil)
					buffFrame.texture:SetTexture(b.icon)
					SetAuraButtonCooldown(buffFrame, unit, b.duration, b.expirationTime, b.auraInstanceID)
					SetAuraButtonBorder(buffFrame, 0.1, 0.1, 0.1, 0.85)
					buffFrame.timer.expires = (b.expirationTime and b.expirationTime > 0) and b.expirationTime or nil
					buffFrame:Show()
					lastBuffFrame = buffFrame
				end
			end

			local DebuffSlots = 0
			local allowDebuffIcons = (BuffType == "debuffs" or BuffType == "buffsifnotdebuffed" or BuffType == "both")
			if f.isPetGroupFrame and not self.opt.ShowPetBuffs then
				allowDebuffIcons = false
			end
			if allowDebuffIcons then
				for _, d in ipairs(chosenDebuffs) do
					if DebuffSlots >= layout.debuffCount then break end
					DebuffSlots = DebuffSlots + 1
					local debuffFrame = f["aura"..DebuffSlots]
					if not debuffFrame then break end
					debuffFrame.unitid = unit
					debuffFrame.debuffid = d.index
					debuffFrame.count:SetText(d.count and d.count > 1 and d.count or nil)
					debuffFrame.texture:SetTexture(d.icon)
					SetAuraButtonCooldown(debuffFrame, unit, d.duration, d.expirationTime, d.auraInstanceID)

					if d.isBoss then
						SetAuraButtonBorder(debuffFrame, 1.0, 0.75, 0.05, 1)
					elseif self.opt.DispelIconBorder and d.dispelType and DISPEL_BORDER_COLORS[d.dispelType] then
						local dc = DISPEL_BORDER_COLORS[d.dispelType]
						SetAuraButtonBorder(debuffFrame, dc.r, dc.g, dc.b, 1)
					elseif d.isPriestDebuff then
						SetAuraButtonBorder(debuffFrame, 0.85, 0.15, 0.25, 1)
					else
						SetAuraButtonBorder(debuffFrame, 0.1, 0.1, 0.1, 0.9)
					end

					if DebuffSlots == 1 then
						local offset = (self:GetLayout()["Name"] == L["CT_RaidAssist (Without Borders)"]) and 0 or -4
						if lastBuffFrame then
							self:SetWHP(debuffFrame, debuffFrame:GetWidth(), debuffFrame:GetHeight(), "TOPRIGHT", lastBuffFrame, "TOPLEFT", -1, 0)
						elseif f.isPetGroupFrame and f.hpbar then
							self:SetWHP(debuffFrame, debuffFrame:GetWidth(), debuffFrame:GetHeight(), "TOPRIGHT", f.hpbar, "TOPRIGHT", -1, -1)
						else
							self:SetWHP(debuffFrame, debuffFrame:GetWidth(), debuffFrame:GetHeight(), "TOPRIGHT", f, "TOPRIGHT", offset, offset)
						end
					end

					debuffFrame.timer.expires = (d.expirationTime and d.expirationTime > 0) and d.expirationTime or nil
					debuffFrame:Show()
				end
			end
		end
	end
end

function sRaidFrames:RefreshAllNativeAuraContainers()
	if privateFuncs.IsInCombat() then
		self:ScheduleLeaveCombatAction("RefreshAllNativeAuraContainers")
		return
	end
	for unit in pairs(self:GetAllUnits()) do
		local vunit = self:GetVehicleUnit(unit)
		for _, f in pairs(self:FindUnitFrames(unit)) do
			if f.hasNativeAuraContainers then
				self:SyncNativeAuraContainers(f, vunit)
			end
			if f.petframe then
				local petUnit = self:OwnerToPetUnit(unit)
				self:SyncAttachedPetNativeAuras(f.petframe, petUnit)
				if petUnit and self:GetCurrentPetMode() == "attached" then
					self:UpdateAttachedPetAuras(unit, petUnit)
				end
			end
		end
		self:UpdateAuras(unit)
	end
end

-------------------------------------------------------------------------------
-- Status Map System (with per-unit override isolation)
-------------------------------------------------------------------------------
function sRaidFrames:AddStatusMap(statuskey, priority, elements, text, color, disabled, options)
	if self.opt.StatusMaps[statuskey] then return end
	self.opt.StatusMaps[statuskey] = {
		["priority"] = priority,
		["elements"] = {},
		["text"] = text,
		["color"] = color,
		["enabled"] = disabled ~= true,
		["options"] = options or {},
	}
	for _, element in pairs(elements) do
		self.opt.StatusMaps[statuskey].elements[element] = true
	end
	self:chatUpdateStatusElements()
end

function sRaidFrames:GetStatus(unit, statuskey)
	return self.statusstate[unit] and self.statusstate[unit][statuskey] or nil
end

function sRaidFrames:SetStatus(unit, statuskey, text, color, update)
	if not self:IsTracking(unit) then return end

	local map = self.opt.StatusMaps[statuskey]
	if not map or map.enabled == false then return end

	if not self.statusstate[unit] then
		self.statusstate[unit] = {}
	end

	local hasStatus = self:GetStatus(unit, statuskey)
	if hasStatus and not update then return end

	if text or color then
		self.statusstate[unit][statuskey] = {
			priority = map.priority,
			elements = map.elements,
			text = text or map.text,
			color = color or map.color,
			enabled = map.enabled,
			options = map.options,
		}
	else
		self.statusstate[unit][statuskey] = map
	end

	self:UpdateStatusElements(unit, statuskey)
end

function sRaidFrames:UnsetStatus(unit, statuskey)
	if not self:IsTracking(unit) then return end
	if self.opt.StatusMaps[statuskey] and self:GetStatus(unit, statuskey) then
		self.statusstate[unit][statuskey] = nil
		self:UpdateStatusElements(unit, statuskey)
	end
end

function sRaidFrames:UpdateStatusElements(unit, statuskey)
	for element in pairs(self.opt.StatusMaps[statuskey].elements) do
		self:UpdateUnitStatusElement(unit, element)
	end
end

function sRaidFrames:RegisterStatusElement(element, name, func)
	self.statusElements[element] = { ["func"] = func, ["name"] = name }
	self.validateStatusElements[element] = name
end

function sRaidFrames:UpdateUnitStatusElement(unit, element)
	local status = self:GetTopStatus(element, unit)

	for _, frame in pairs(self:FindUnitFrames(unit)) do
		if self.statusElements[element] then
			self.statusElements[element].func(self, frame, status)
		end
	end
end

function sRaidFrames:GetTopStatus(element, unit)
	if not self.statusstate[unit] then
		return nil
	end

	local TopStatus, TopPriority = nil, 0
	for name in pairs(self.statusstate[unit]) do
		local map = self.opt.StatusMaps[name]
		if map and map.elements[element] and map.priority > TopPriority then
			TopPriority = map.priority
			TopStatus = name
		end
	end

	return TopStatus and self.statusstate[unit][TopStatus] or nil
end

function sRaidFrames:GetHPSeverity(percent)
	if percent >= 0.5 then
		return (1.0 - percent) * 2, 1.0, 0.0
	else
		return 1.0, percent * 2, 0.0
	end
end

function sRaidFrames:QueryTooltipDisplay(value)
	if value == "never" then
		return false
	elseif value == "notincombat" and privateFuncs.IsInCombat() then
		return false
	else
		return true
	end
end

function sRaidFrames:UnitTooltip(frame)
	local unit = frame:GetAttribute("unit")
	if not unit then return end

	GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")

	if self.opt.UnitTooltipType == "blizz" or not frame.id or not IsInRaid() then
		pcall(GameTooltip.SetUnit, GameTooltip, unit)
		GameTooltip:Show()
		return
	end

	local name, rank, subgroup, level, class, eclass, zone = GetRaidRosterInfo(tonumber(frame.id) or 0)
	local dispName = Compat.GetUnitDisplayName(unit, "full")
	if dispName and not IsSecret(dispName) then
		name = dispName
	end
	if not name or IsSecret(name) then
		pcall(GameTooltip.SetUnit, GameTooltip, unit)
		GameTooltip:Show()
		return
	end

	local cColor = (eclass and not IsSecret(eclass) and RAID_CLASS_COLORS[eclass]) or NORMAL_FONT_COLOR
	GameTooltip:AddDoubleLine(name, (level and not IsSecret(level) and level > 0) and level or nil, cColor.r, cColor.g, cColor.b, 1, 1, 1)

	if UnitHasVehicleUI(unit) then
		local vName = Compat.GetUnitDisplayName(self:GetVehicleUnit(unit), "full")
		if vName and not IsSecret(vName) then
			GameTooltip:AddLine(vName)
		end
	end

	local okAfk, isAfk = pcall(UnitIsAFK, unit)
	if okAfk and not IsSecret(isAfk) and isAfk then
		GameTooltip:AddLine(L["AFK: Away From Keyboard"], 1, 1, 0)
	end

	local role, spec
	if LGIST then
		role, spec = privateFuncs.LGIST_to_RoleSpec(unit, eclass)
	end

	local race = UnitRace(unit) or ""
	if IsSecret(race) then race = "" end
	class = (class and not IsSecret(class)) and class or ""

	if spec and role then
		GameTooltip:AddDoubleLine(race .. " " .. class, spec .. " (" .. role .. ")", 1, 1, 1, cColor.r, cColor.g, cColor.b)
	else
		GameTooltip:AddLine(race .. " " .. class, 1, 1, 1)
	end

	if subgroup and not IsSecret(subgroup) then
		GameTooltip:AddDoubleLine((zone and not IsSecret(zone) and zone) or UNKNOWN, L["Group %d"]:format(subgroup), 1, 1, 1, 1, 1, 1)
	end

	local cooldownSpell = eclass and not IsSecret(eclass) and self.cooldownSpells[eclass]
	if oRA and oRA:HasModule("OptionalCooldown") and cooldownSpell then
		if oRA:GetModule("OptionalCooldown").db.realm.cooldowns and oRA:GetModule("OptionalCooldown").db.realm.cooldowns[name] then
			local expire = oRA:GetModule("OptionalCooldown").db.realm.cooldowns[name] - time()
			if expire > 0 then
				GameTooltip:AddDoubleLine(cooldownSpell, SecondsToTime(expire), nil, nil, nil, 1, 0, 0)
			else
				GameTooltip:AddDoubleLine(cooldownSpell, L["Ready!"], nil, nil, nil, 0, 1, 0)
			end
		else
			GameTooltip:AddDoubleLine(cooldownSpell, UNKNOWN, nil, nil, nil, 1, 1, 0)
		end
	end

	GameTooltip:Show()
end

privateFuncs.IsInCombat = function()
	local okP, pCombat = pcall(UnitAffectingCombat, "player")
	if not okP or IsSecret(pCombat) then pCombat = false end
	return (sRaidFrames.InCombat or InCombatLockdown() or pCombat)
end

privateFuncs.LGIST_to_RoleSpec = function(unit, eclass)
	if not unit or not LGIST then return nil, nil end

	local okG, guid = pcall(UnitGUID, unit)
	if not okG or IsSecret(guid) then guid = nil end
	local info = nil
	if guid and LGIST.GetCachedInfo then
		local okI, res = pcall(LGIST.GetCachedInfo, LGIST, guid)
		if okI and type(res) == "table" and not IsSecretTable(res) then
			info = res
		end
	end
	if info and info.class and not eclass then eclass = info.class end
	if not eclass or IsSecret(eclass) then return nil, nil end

	local spec, role
	if info and info.spec_name_localized then
		spec = info.spec_name_localized
	end
	if eclass == "MAGE" or eclass == "HUNTER" or eclass == "WARLOCK" then
		role = "caster"
	elseif eclass == "ROGUE" then
		role = "melee"
	end
	if not role and info and info.global_spec_id and sRaidFrames.specMap[info.global_spec_id] then
		role = sRaidFrames.specMap[info.global_spec_id]
	end

	return role, spec
end

local function sRaidFrames_OnAttributeChanged(frame, name, value)
	if name == "unit" then
		ShouldUpdateFrameCache = true

		if value then
			frame.id = select(3, value:find("(%d+)"))
			if sRaidFrames.enabled then
				sRaidFrames:UpdateAll(value)
			end
		elseif frame.hasNativeAuraContainers and not privateFuncs.IsInCombat() then
			sRaidFrames:SyncNativeAuraContainers(frame, nil)
		end
	end
end

function sRaidFrames:UpdateFrameCache()
	self.FramesByUnit = {}
	for k, frame in pairs(self.frames) do
		local unit = frame:GetAttribute("unit")
		if unit then
			if not self.FramesByUnit[unit] then
				self.FramesByUnit[unit] = {}
			end
			tinsert(self.FramesByUnit[unit], frame)
		end
	end
	ShouldUpdateFrameCache = false
end

local function BuffFrame_OnEnter(this)
	if sRaidFrames:QueryTooltipDisplay(sRaidFrames.opt.BuffTooltipMethod) and this.unitid and this.buffid then
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		pcall(GameTooltip.SetUnitBuff, GameTooltip, this.unitid, this.buffid, this.showCastable)
	end
end

local function BuffFrame_OnLeave(this)
	GameTooltip:Hide()
end

local function DebuffFrame_OnEnter(this)
	if sRaidFrames:QueryTooltipDisplay(sRaidFrames.opt.DebuffTooltipMethod) and this.unitid and this.debuffid then
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		pcall(GameTooltip.SetUnitDebuff, GameTooltip, this.unitid, this.debuffid)
	end
end

local DebuffFrame_OnLeave = BuffFrame_OnLeave

local function UnitFrame_OnEnter(this)
	if sRaidFrames:QueryTooltipDisplay(sRaidFrames.opt.UnitTooltipMethod) then
		sRaidFrames:UnitTooltip(this)
	end
end

local UnitFrame_OnLeave = BuffFrame_OnLeave

-- Pure Target Selection on Click (No one-click healing!)
local sRaidFrames_InitUnitFrame = [[
	local header = self:GetParent()

	self:SetAttribute("type1", "target")
	self:SetAttribute("*type1", "target")
	self:SetAttribute("type2", "togglemenu")
	self:SetAttribute("*type2", "togglemenu")
	self:SetAttribute("useOnKeyDown", true)
	self:SetAttribute("toggleForVehicle", true)

	self:SetWidth(header:GetAttribute("style-width"))
	self:SetHeight(header:GetAttribute("style-height"))

	header:CallMethod("CreateChildFrame", self:GetName())
]]

local function CreateStyledAuraIconButton(parent, onEnter, onLeave, defaultFontSize)
	local btn = CreateFrame("Button", nil, parent)
	if onEnter then btn:SetScript("OnEnter", onEnter) end
	if onLeave then btn:SetScript("OnLeave", onLeave) end
	pcall(btn.SetMouseClickEnabled, btn, false)
	pcall(btn.SetMouseMotionEnabled, btn, true)
	pcall(btn.SetPropagateMouseMotion, btn, true)

	btn.border = btn:CreateTexture(nil, "BACKGROUND")
	btn.border:SetAllPoints(btn)
	btn.border:SetColorTexture(1, 1, 1, 1)
	btn.border:Hide()

	btn.texture = btn:CreateTexture(nil, "ARTWORK")
	btn.texture:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
	btn.texture:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
	btn.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
	btn.cooldown:SetAllPoints(btn.texture)
	btn.cooldown:SetReverse(true)
	if btn.cooldown.SetDrawEdge then btn.cooldown:SetDrawEdge(false) end
	if btn.cooldown.SetDrawBling then btn.cooldown:SetDrawBling(false) end
	if btn.cooldown.SetHideCountdownNumbers then btn.cooldown:SetHideCountdownNumbers(true) end

	btn.count = btn:CreateFontString(nil, "OVERLAY")
	btn.count:SetFontObject(GameFontHighlightSmallOutline)
	btn.count:SetJustifyH("RIGHT")
	btn.count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, 0)

	local timer = btn:CreateFontString(nil, "OVERLAY")
	local fontPath = (GameFontNormal and GameFontNormal:GetFont()) or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
	timer:SetFont(fontPath, defaultFontSize, "OUTLINE")
	timer.fontsize = defaultFontSize
	timer:SetTextColor(1, 0.9, 0.1)
	timer:SetAllPoints(btn)

	btn.timer = timer
	btn:Hide()
	return btn
end

function sRaidFrames.CreateChildFrame(header, name)
	local self = sRaidFrames
	local f = _G[name]

	Compat.AttachSafeUnitBackdrop(f)
	local vf = f._visualFrame or f

	local layout = self:GetLayout()

	pcall(f.RegisterForClicks, f, "AnyUp", "AnyDown")
	pcall(f.RegisterForDrag, f, "LeftButton")

	local gf = header and header:GetParent()
	f:HookScript("OnDragStart", function(this)
		if sRaidFrames.opt.Locked or privateFuncs.IsInCombat() or not gf then return end
		this._isDragging = true
		if IsAltKeyDown() then sRaidFrames:StartMovingAll(gf, this) end
		gf:StartMoving()
	end)
	f:HookScript("OnDragStop", function(this)
		if not this._isDragging or not gf then return end
		this._isDragging = nil
		if this.multidrag == 1 then
			if not privateFuncs.IsInCombat() then
				sRaidFrames:StopMovingOrSizingAll(gf, this)
			else
				this.multidrag = nil
			end
		end
		pcall(gf.StopMovingOrSizing, gf)
		if not privateFuncs.IsInCombat() then
			sRaidFrames:SavePosition()
		end
	end)

	f:HookScript("OnEnter", UnitFrame_OnEnter)
	f:HookScript("OnLeave", UnitFrame_OnLeave)
	f:HookScript("OnAttributeChanged", sRaidFrames_OnAttributeChanged)

	f.title = vf:CreateFontString(nil, "ARTWORK")
	f.title:SetFontObject(GameFontNormalSmall)
	f.title:SetJustifyH("LEFT")
	if f.title.SetWordWrap then f.title:SetWordWrap(false) end

	local fontPath = (GameFontNormal and GameFontNormal:GetFont()) or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

	for i = 1, layout.debuffCount do
		local debuffFrame = CreateStyledAuraIconButton(vf, DebuffFrame_OnEnter, DebuffFrame_OnLeave, 11)
		local debuffTimer = debuffFrame.timer
		debuffFrame:SetScript("OnUpdate", function(btn, elapsed)
			btn._elapsed = (btn._elapsed or 0) + (elapsed or 0)
			if btn._elapsed < 0.1 then return end
			btn._elapsed = 0
			local expires = debuffTimer.expires
			if not expires then
				if debuffTimer.cache then
					debuffTimer:SetText(nil)
					debuffTimer.cache = nil
				end
				return
			end
			local seconds = floor(expires - GetTime())
			if seconds >= 0 and sRaidFrames.opt.debufftimer.show and (seconds <= sRaidFrames.opt.debufftimer.max) then
				local sStr = tostring(seconds)
				if debuffTimer.cache ~= sStr then
					debuffTimer:SetText(sStr)
					debuffTimer.cache = sStr
				end
				local supposedsize = seconds >= 10 and 9 or 11
				if supposedsize ~= debuffTimer.fontsize then
					debuffTimer:SetFont(fontPath, supposedsize, "OUTLINE")
					debuffTimer.fontsize = supposedsize
				end
			elseif debuffTimer.cache then
				debuffTimer:SetText(nil)
				debuffTimer.cache = nil
			end
		end)
		f["aura"..i] = debuffFrame
	end

	for i = 1, layout.buffCount do
		local buffFrame = CreateStyledAuraIconButton(vf, BuffFrame_OnEnter, BuffFrame_OnLeave, 9)
		local buffTimer = buffFrame.timer
		buffFrame:SetScript("OnUpdate", function(btn, elapsed)
			btn._elapsed = (btn._elapsed or 0) + (elapsed or 0)
			if btn._elapsed < 0.1 then return end
			btn._elapsed = 0
			local expires = buffTimer.expires
			if not expires then
				if buffTimer.cache then
					buffTimer:SetText(nil)
					buffTimer.cache = nil
				end
				return
			end
			local seconds = floor(expires - GetTime())
			if seconds >= 0 and sRaidFrames.opt.bufftimer.show and (seconds <= sRaidFrames.opt.bufftimer.max) then
				local sStr = tostring(seconds)
				if buffTimer.cache ~= sStr then
					buffTimer:SetText(sStr)
					buffTimer.cache = sStr
				end
				local supposedsize = seconds >= 10 and 7 or 9
				if supposedsize ~= buffTimer.fontsize then
					buffTimer:SetFont(fontPath, supposedsize, "OUTLINE")
					buffTimer.fontsize = supposedsize
				end
			elseif buffTimer.cache then
				buffTimer:SetText(nil)
				buffTimer.cache = nil
			end
		end)
		f["buff"..i] = buffFrame
	end

	local texture = Media:Fetch("statusbar", self.opt.Texture)

	f.hpbar = CreateFrame("StatusBar", nil, vf)
	f.hpbar:SetStatusBarTexture(texture)
	f.hpbar:SetMinMaxValues(0, 100)
	f.hpbar:SetValue(0)
	pcall(f.hpbar.SetClipsChildren, f.hpbar, true)
	f.hpbar.bg = f.hpbar:CreateTexture(nil, "BACKGROUND")
	f.hpbar.bg:SetAllPoints(f.hpbar)
	f.hpbar.bg:SetColorTexture(0.08, 0.10, 0.14, 0.85)

	-- Incoming heal prediction bar (parented & clipped to hpbar so it never overflows onto aura icons)
	f.healbar = CreateFrame("StatusBar", nil, f.hpbar)
	f.healbar:SetStatusBarTexture(texture)
	f.healbar:SetStatusBarColor(0.32, 0.72, 0.42, 0.78)
	f.healbar:SetMinMaxValues(0, 100)
	f.healbar:SetValue(0)
	f.healbar:SetPoint("TOPLEFT", f.hpbar:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
	f.healbar:SetPoint("BOTTOMLEFT", f.hpbar:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
	f.healbar:SetFrameLevel(f.hpbar:GetFrameLevel())
	f.healbar:Hide()

	f.hpbar.text = f.hpbar:CreateFontString(nil, "ARTWORK")
	f.hpbar.text:SetFontObject(GameFontHighlightSmall)
	f.hpbar.text:SetJustifyH("CENTER")

	local color = self.opt.HealthTextColor
	f.hpbar.text:SetTextColor(color.r, color.g, color.b, color.a)

	f.mpbar = CreateFrame("StatusBar", nil, vf)
	f.mpbar:SetStatusBarTexture(texture)
	f.mpbar:SetMinMaxValues(0, 100)
	f.mpbar:SetValue(0)
	f.mpbar.bg = f.mpbar:CreateTexture(nil, "BACKGROUND")
	f.mpbar.bg:SetAllPoints(f.mpbar)
	f.mpbar.bg:SetColorTexture(0.06, 0.08, 0.12, 0.85)

	f.statustext = f.mpbar:CreateFontString(nil, "ARTWORK")
	f.statustext:SetFontObject(GameFontHighlightSmall)
	f.statustext:SetJustifyH("CENTER")

	-- DBM / Boss Alert Overlay Icon (anchored on the right of the health bar so it's always visible)
	local dbmIcon = CreateStyledAuraIconButton(vf, nil, nil, 10)
	dbmIcon:SetFrameLevel(f.hpbar:GetFrameLevel() + 8)
	dbmIcon:SetSize(14, 14)
	dbmIcon:SetPoint("RIGHT", f.hpbar, "RIGHT", -1, 0)
	SetAuraButtonBorder(dbmIcon, 1.0, 0.2, 0.0, 1.0)
	f.dbmAlertIcon = dbmIcon

	-- Raid Target Marker Texture (anchored on the left of the health bar)
	local markerHolder = CreateFrame("Frame", nil, vf)
	markerHolder:SetAllPoints(f.hpbar)
	markerHolder:SetFrameLevel(f.hpbar:GetFrameLevel() + 7)
	local raidMarker = markerHolder:CreateTexture(nil, "OVERLAY")
	raidMarker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	raidMarker:SetSize(11, 11)
	raidMarker:SetPoint("LEFT", f.hpbar, "LEFT", 1, 0)
	raidMarker:Hide()
	f.raidMarker = raidMarker

	-- Small Class Icon beside the right side of the health bar
	local classIcon = markerHolder:CreateTexture(nil, "OVERLAY")
	classIcon:SetSize(11, 11)
	classIcon:SetPoint("LEFT", f.hpbar, "RIGHT", 2, 0)
	classIcon:Hide()
	f.classIcon = classIcon

	-- Player Level Text to the right of Class Icon (5-player Party mode only)
	local levelText = markerHolder:CreateFontString(nil, "OVERLAY")
	levelText:SetFontObject(GameFontNormalSmall)
	levelText:SetJustifyH("LEFT")
	levelText:SetTextColor(1, 0.85, 0.25, 1)
	levelText:SetPoint("LEFT", classIcon, "RIGHT", 2, 0)
	levelText:Hide()
	f.levelText = levelText

	-- Main Tank / Main Assist (Off-Tank) Icon at the top-left corner of the health bar
	local tankIcon = markerHolder:CreateTexture(nil, "OVERLAY")
	tankIcon:SetSize(11, 11)
	tankIcon:SetPoint("TOPLEFT", f.hpbar, "TOPLEFT", 1, 0)
	tankIcon:Hide()
	f.tankIcon = tankIcon

	-- Raid / Party Leader Crown Icon at the top-left of the health bar (shifts right if tankIcon is shown)
	local leaderIcon = markerHolder:CreateTexture(nil, "OVERLAY")
	leaderIcon:SetSize(11, 11)
	leaderIcon:SetPoint("TOPLEFT", f.hpbar, "TOPLEFT", 1, 0)
	leaderIcon:Hide()
	f.leaderIcon = leaderIcon

	-- Circular 2D Portrait on the left side in 5-player Party mode
	local portraitFrame = CreateFrame("Frame", nil, vf)
	portraitFrame:SetSize(30, 30)
	portraitFrame:SetPoint("LEFT", f, "LEFT", 4, 0)
	portraitFrame:Hide()
	local portraitBg = portraitFrame:CreateTexture(nil, "BACKGROUND")
	portraitBg:SetAllPoints(portraitFrame)
	portraitBg:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
	portraitBg:SetVertexColor(0.06, 0.08, 0.12, 0.92)
	local portrait = portraitFrame:CreateTexture(nil, "ARTWORK")
	portrait:SetAllPoints(portraitFrame)
	if portraitFrame.CreateMaskTexture then
		local mask = portraitFrame:CreateMaskTexture()
		mask:SetAllPoints(portrait)
		mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		portrait:AddMaskTexture(mask)
	end
	local portraitBorder = portraitFrame:CreateTexture(nil, "OVERLAY")
	portraitBorder:SetPoint("CENTER", portraitFrame, "CENTER", 0, 0)
	portraitBorder:SetSize(42, 42)
	portraitBorder:SetTexture("Interface\\CharacterFrame\\TotemBorder")
	portraitBorder:SetVertexColor(0.85, 0.78, 0.62, 0.95)
	f.portraitFrame = portraitFrame
	f.portrait = portrait
	f.portraitBorder = portraitBorder

	-- Voice chat speaker indicator (hidden unless teammate is actively speaking)
	local voiceIcon = markerHolder:CreateTexture(nil, "OVERLAY")
	voiceIcon:SetSize(13, 13)
	voiceIcon:SetPoint("BOTTOMLEFT", portraitFrame, "BOTTOMLEFT", -2, -2)
	voiceIcon:Hide()
	f.voiceIcon = voiceIcon

	f.isPetGroupFrame = (header and header.isPetHeader) and true or false

	-- Native Forever AuraContainers (for combat-locked auras in WoW: Forever 16001)
	self:CreateNativeAuraContainers(f)

	-- Attached Pet Bar (only on regular teammate frames, never on standalone pet group frames)
	if not f.isPetGroupFrame then
		if not privateFuncs.IsInCombat() then
			self:CreateAttachedPetFrame(f, name)
		else
			self:ScheduleLeaveCombatAction("EnsureAttachedPetFrames")
		end
	end

	layout.StyleUnitFrame(f)

	tinsert(self.frames, f)
	ShouldUpdateFrameCache = true
end

-------------------------------------------------------------------------------
-- Pet Health Bar System (Party Attached / Raid Attached / Standalone Pet Group)
-------------------------------------------------------------------------------
function sRaidFrames:CreateAttachedPetNativeAuras(pf)
	if not FlowDir or pf.nativeAurasTried or not pf.hpbar then return end
	pf.nativeAurasTried = true
	local ok, box = pcall(CreateFrame, "AuraContainer", nil, pf.hpbar, "CustomAuraContainerTemplate")
	if not ok or not box then return end
	pcall(box.SetFrameStrata, box, pf.hpbar:GetFrameStrata())
	pcall(box.SetFrameLevel, box, pf.hpbar:GetFrameLevel() + 5)

	local iconSz = 9
	local conf = pcall(function()
		box:SetPoint("TOPRIGHT", pf.hpbar, "TOPRIGHT", -1, -1)
		box:SetFlowLayoutAnchorPoint("TOPRIGHT")
		box:SetFlowLayoutGrowthDirection(FlowDir.Left, FlowDir.Down)
		box:EnableMouse(false)
		if box.SetEditModePreviewEnabled then box:SetEditModePreviewEnabled(false) end
		if AuraPolicies and AuraPolicies.ProcessAura then
			box:SetAuraProcessingPolicy(AuraPolicies.ProcessAura, { displayOnlyDispellableDebuffs = false })
		end
		box:AddAuraGroup("pet_combat", "HELPFUL", {
			maxFrameCount = 2,
			templateNames = { "sRaidFramesAuraIconTemplate" },
			initializeFrame = function(btn) InitNativeAuraButton(btn, iconSz, {0.15, 0.75, 0.95, 1}, false, true) end,
			candidateFilters = { includeSpellIDs = Compat.PetBuffSpellIDs or Compat.ImportantCombatBuffIDs },
			layout = { elementSpacing = 1, groupSpacing = 1, elementWidth = iconSz, elementHeight = iconSz, layoutIndex = 1 },
		})
		if box.SetAuraGroupMaxFrameCount then box:SetAuraGroupMaxFrameCount("pet_combat", 2) end

		local excludeIds = {}
		for id in pairs(Compat.FoodDrinkSpellIDs) do excludeIds[id] = true end
		for id in pairs(Compat.PetBuffSpellIDs or Compat.ImportantCombatBuffIDs) do excludeIds[id] = true end
		box:AddAuraGroup("pet_hots", "HELPFUL|PLAYER", {
			maxFrameCount = 2,
			templateNames = { "sRaidFramesAuraIconTemplate" },
			initializeFrame = function(btn) InitNativeAuraButton(btn, iconSz, {0.1, 0.1, 0.1, 0.9}, false, true) end,
			candidateFilters = { maxDuration = 60, excludeSpellIDs = excludeIds },
			layout = { elementSpacing = 1, groupSpacing = 1, elementWidth = iconSz, elementHeight = iconSz, layoutIndex = 2 },
		})
		if box.SetAuraGroupMaxFrameCount then box:SetAuraGroupMaxFrameCount("pet_hots", 2) end

		box:AddAuraGroup("pet_dispel", "HARMFUL|RAID", {
			maxFrameCount = 1,
			sortMethod = AuraSortMethod and AuraSortMethod.UnitFrameDebuff,
			templateNames = { "sRaidFramesDispelIconTemplate" },
			initializeFrame = function(btn)
				InitNativeAuraButton(btn, iconSz, nil, true, true)
				if btn.DispelBorder then AddNativeDispelTypeTexture(btn, btn.DispelBorder, true) end
				if btn.DispelGlow then pcall(btn.DispelGlow.SetAlpha, btn.DispelGlow, 0) end
			end,
			layout = { elementSpacing = 1, groupSpacing = 1, elementWidth = iconSz, elementHeight = iconSz, layoutIndex = 3 },
		})
		if box.SetAuraGroupMaxFrameCount then box:SetAuraGroupMaxFrameCount("pet_dispel", 1) end
	end)
	if not conf then
		box:Hide()
		return
	end
	pf.nativeBuffBox = box
	pf.hasNativeAuraContainers = true
	pcall(box.SetUnit, box, "none")
	pcall(box.Hide, box)
end

function sRaidFrames:SyncAttachedPetNativeAuras(pf, petUnit)
	if not pf or not pf.nativeBuffBox or privateFuncs.IsInCombat() then return end
	local inParty = not IsInRaid()
	local allow = inParty and self:GetCurrentPetMode() == "attached" and self.opt.ShowPetBuffs and (self.opt.BuffType ~= "none") and petUnit
	local u = allow and petUnit or "none"
	if pf.nativeBuffBox:GetUnit() ~= u then
		pcall(pf.nativeBuffBox.SetUnit, pf.nativeBuffBox, u)
	end
	pcall(pf.nativeBuffBox.SetShown, pf.nativeBuffBox, u ~= "none")
end

function sRaidFrames:CreateAttachedPetFrame(f, name)
	if not f or f.petframe or f.isPetGroupFrame or privateFuncs.IsInCombat() then return end
	local petName = (name or f:GetName() or "sRaidFramesUnit") .. "Pet"
	local pf = CreateFrame("Button", petName, f, "SecureUnitButtonTemplate")
	pf.ownerFrame = f
	Compat.AttachSafeUnitBackdrop(pf)
	local pvf = pf._visualFrame or pf

	pcall(pf.RegisterForClicks, pf, "AnyUp", "AnyDown")
	pf:SetAttribute("type1", "target")
	pf:SetAttribute("*type1", "target")
	pf:SetAttribute("type2", "togglemenu")
	pf:SetAttribute("*type2", "togglemenu")
	pf:SetAttribute("useOnKeyDown", true)
	pf:SetAttribute("useparent-unit", true)
	pf:SetAttribute("unitsuffix", "pet")

	pf:SetScript("OnEnter", function(this)
		if sRaidFrames:QueryTooltipDisplay(sRaidFrames.opt.UnitTooltipMethod) then
			local owner = this.ownerFrame and this.ownerFrame:GetAttribute("unit")
			local petUnit = sRaidFrames:OwnerToPetUnit(owner)
			if petUnit then
				GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
				pcall(GameTooltip.SetUnit, GameTooltip, petUnit)
				GameTooltip:Show()
			end
		end
	end)
	pf:SetScript("OnLeave", function()
		if GameTooltip then GameTooltip:Hide() end
	end)
	pf:HookScript("OnShow", function(this)
		if this.ownerFrame then
			sRaidFrames:UpdateAttachedPetFrame(this.ownerFrame)
		end
	end)

	local texture = Media:Fetch("statusbar", self.opt.Texture)

	-- Circular 2D pet portrait (shown in 5-player Party attached mode)
	local portraitFrame = CreateFrame("Frame", nil, pvf)
	portraitFrame:SetSize(16, 16)
	portraitFrame:SetPoint("LEFT", pf, "LEFT", 3, 0)
	portraitFrame:Hide()
	local portraitBg = portraitFrame:CreateTexture(nil, "BACKGROUND")
	portraitBg:SetAllPoints(portraitFrame)
	portraitBg:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
	portraitBg:SetVertexColor(0.06, 0.08, 0.12, 0.92)
	local portrait = portraitFrame:CreateTexture(nil, "ARTWORK")
	portrait:SetAllPoints(portraitFrame)
	if portraitFrame.CreateMaskTexture then
		local mask = portraitFrame:CreateMaskTexture()
		mask:SetAllPoints(portrait)
		mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		portrait:AddMaskTexture(mask)
	end
	local portraitBorder = portraitFrame:CreateTexture(nil, "OVERLAY")
	portraitBorder:SetPoint("CENTER", portraitFrame, "CENTER", 0, 0)
	portraitBorder:SetSize(22, 22)
	portraitBorder:SetTexture("Interface\\CharacterFrame\\TotemBorder")
	portraitBorder:SetVertexColor(0.85, 0.78, 0.62, 0.95)
	pf.portraitFrame = portraitFrame
	pf.portrait = portrait
	pf.portraitBorder = portraitBorder

	-- Pet Health StatusBar
	pf.hpbar = CreateFrame("StatusBar", nil, pvf)
	pf.hpbar:SetStatusBarTexture(texture)
	pf.hpbar:SetMinMaxValues(0, 100)
	pf.hpbar:SetValue(100)
	pcall(pf.hpbar.SetClipsChildren, pf.hpbar, true)
	pf.hpbar.bg = pf.hpbar:CreateTexture(nil, "BACKGROUND")
	pf.hpbar.bg:SetAllPoints(pf.hpbar)
	pf.hpbar.bg:SetColorTexture(0.08, 0.10, 0.14, 0.88)

	-- Pet Incoming Heal Prediction bar (parented & clipped to pf.hpbar)
	pf.healbar = CreateFrame("StatusBar", nil, pf.hpbar)
	pf.healbar:SetStatusBarTexture(texture)
	pf.healbar:SetStatusBarColor(0.32, 0.72, 0.42, 0.78)
	pf.healbar:SetMinMaxValues(0, 100)
	pf.healbar:SetValue(0)
	pf.healbar:SetPoint("TOPLEFT", pf.hpbar:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
	pf.healbar:SetPoint("BOTTOMLEFT", pf.hpbar:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
	pf.healbar:SetFrameLevel(pf.hpbar:GetFrameLevel())
	pf.healbar:Hide()

	-- Compact Pet Name + HP% Text (Party attached mode)
	pf.hpbar.text = pf.hpbar:CreateFontString(nil, "OVERLAY")
	local fontPath = (GameFontNormalSmall and GameFontNormalSmall:GetFont()) or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
	pf.hpbar.text:SetFont(fontPath, 8, "OUTLINE")
	pf.hpbar.text:SetJustifyH("LEFT")
	if pf.hpbar.text.SetWordWrap then pf.hpbar.text:SetWordWrap(false) end
	pf.hpbar.text:SetTextColor(0.95, 0.98, 0.95, 1)

	-- Target highlight border overlay
	local hl = CreateFrame("Frame", nil, pvf, BackdropTemplateMixin and "BackdropTemplate" or nil)
	hl:SetAllPoints(pf)
	hl:SetFrameLevel(pf.hpbar:GetFrameLevel() + 8)
	if hl.SetBackdrop then
		hl:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
		hl:SetBackdropBorderColor(1, 0.92, 0.25, 1)
	end
	hl:Hide()
	pf.targetHighlight = hl

	-- Low-pixel fallback Lua aura icons inside TOPRIGHT of pet health bar (9x9)
	pf.buffs = {}
	for i = 1, 3 do
		local icon = CreateFrame("Frame", nil, pf.hpbar)
		icon:SetSize(9, 9)
		icon:SetFrameLevel(pf.hpbar:GetFrameLevel() + 5)
		if i == 1 then
			icon:SetPoint("TOPRIGHT", pf.hpbar, "TOPRIGHT", -1, -1)
		else
			icon:SetPoint("RIGHT", pf.buffs[i - 1], "LEFT", -1, 0)
		end
		icon.border = icon:CreateTexture(nil, "BACKGROUND")
		icon.border:SetAllPoints(icon)
		icon.border:SetColorTexture(0.1, 0.1, 0.1, 0.9)
		icon.texture = icon:CreateTexture(nil, "ARTWORK")
		icon.texture:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1)
		icon.texture:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
		icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
		icon.cooldown:SetAllPoints(icon.texture)
		icon.cooldown:SetReverse(true)
		if icon.cooldown.SetDrawEdge then icon.cooldown:SetDrawEdge(false) end
		if icon.cooldown.SetDrawBling then icon.cooldown:SetDrawBling(false) end
		if icon.cooldown.SetHideCountdownNumbers then icon.cooldown:SetHideCountdownNumbers(true) end
		icon:Hide()
		pf.buffs[i] = icon
	end

	self:CreateAttachedPetNativeAuras(pf)

	pf:Hide()
	f.petframe = pf

	if self:GetCurrentPetMode() == "attached" then
		RegisterUnitWatch(pf)
		pf._unitWatched = true
	end
end

function sRaidFrames:EnsureAttachedPetFrames()
	if privateFuncs.IsInCombat() then
		self:ScheduleLeaveCombatAction("EnsureAttachedPetFrames")
		return
	end
	for _, f in pairs(self.frames) do
		if not f.isPetGroupFrame and not f.petframe then
			self:CreateAttachedPetFrame(f, f:GetName())
			local layout = self:GetLayout()
			if layout and layout.StyleUnitFrame then
				layout.StyleUnitFrame(f)
			end
		end
	end
	self:SyncAttachedPetWatches()
end

function sRaidFrames:SyncAttachedPetWatches()
	if privateFuncs.IsInCombat() then
		self:ScheduleLeaveCombatAction("SyncAttachedPetWatches")
		return
	end
	local mode = self:GetCurrentPetMode()
	for _, f in pairs(self.frames) do
		local pf = f.petframe
		if pf then
			local owner = f:GetAttribute("unit")
			local petUnit = self:OwnerToPetUnit(owner)
			if mode == "attached" then
				if not pf._unitWatched then
					RegisterUnitWatch(pf)
					pf._unitWatched = true
				end
				self:SyncAttachedPetNativeAuras(pf, petUnit)
				if pf:IsShown() then
					self:UpdateAttachedPetFrame(f)
				end
			else
				if pf._unitWatched then
					UnregisterUnitWatch(pf)
					pf._unitWatched = false
				end
				self:SyncAttachedPetNativeAuras(pf, nil)
				pf:Hide()
			end
		end
	end
end

function sRaidFrames:UpdateSingleAttachedPetHealth(pf, petUnit)
	if not pf or not pf.hpbar or not petUnit or IsSecret(petUnit) then return end
	local okE, exists = pcall(UnitExists, petUnit)
	if not okE or (not IsSecret(exists) and not exists) then return end

	local dead, ghost = self:IsUnitReallyDead(petUnit)
	local okH, hp = pcall(UnitHealth, petUnit)
	local okM, hpmax = pcall(UnitHealthMax, petUnit)
	if not okH or not okM then hp, hpmax = 0, 1 end

	local inParty = not IsInRaid()
	local petName = ""
	if inParty then
		local okN, rawName = pcall(UnitName, petUnit)
		if okN and rawName and not IsSecret(rawName) then
			petName = rawName
		end
	end

	if dead or ghost then
		pf.hpbar:SetMinMaxValues(0, 1)
		pf.hpbar:SetValue(0)
		pf.hpbar:SetStatusBarColor(0.45, 0.45, 0.45)
		if pf.healbar then pf.healbar:Hide() end
		if inParty and pf.hpbar.text then
			pf.hpbar.text:SetText((petName ~= "" and (petName .. " ") or "") .. L["Dead"])
		end
		return
	end

	if IsSecret(hp) or IsSecret(hpmax) then
		pcall(pf.hpbar.SetMinMaxValues, pf.hpbar, 0, hpmax)
		pcall(pf.hpbar.SetValue, pf.hpbar, hp)
		self:UpdateUnitHealPredictionBar(pf, petUnit, hpmax)

		local curve = self:GetHealthColorCurve()
		local painted = false
		if curve and _G.UnitHealthPercent then
			local okC, col = pcall(_G.UnitHealthPercent, petUnit, false, curve)
			if okC and col ~= nil and not IsSecret(col) and not IsSecretTable(col) then
				painted = pcall(function()
					if col.GetRGB then
						pf.hpbar:SetStatusBarColor(col:GetRGB())
					else
						error("no GetRGB")
					end
				end)
			end
		end
		if not painted then
			pf.hpbar:SetStatusBarColor(0.15, 0.82, 0.25)
		end

		if inParty and pf.hpbar.text then
			if _G.UnitHealthPercent and _G.CurveConstants and _G.CurveConstants.ScaleTo100 then
				local okP, pct = pcall(_G.UnitHealthPercent, petUnit, true, _G.CurveConstants.ScaleTo100)
				if okP then
					if petName ~= "" then
						if not pcall(pf.hpbar.text.SetFormattedText, pf.hpbar.text, "%s %.0f%%", petName, pct) then
							pcall(pf.hpbar.text.SetText, pf.hpbar.text, petName)
						end
					else
						pcall(pf.hpbar.text.SetFormattedText, pf.hpbar.text, "%.0f%%", pct)
					end
				end
			elseif petName ~= "" then
				pf.hpbar.text:SetText(petName)
			end
		end
		return
	end

	local safeMax = (hpmax and hpmax > 0) and hpmax or 1
	local safeHp = hp or 0
	local hpp = ceil((safeHp / safeMax) * 100)
	pf.hpbar:SetMinMaxValues(0, safeMax)
	pf.hpbar:SetValue(safeHp)
	pf.hpbar:SetStatusBarColor(self:GetHPSeverity(hpp / 100))
	self:UpdateUnitHealPredictionBar(pf, petUnit, safeMax)

	if inParty and pf.hpbar.text then
		if petName ~= "" then
			pf.hpbar.text:SetText(petName .. " " .. hpp .. "%")
		else
			pf.hpbar.text:SetText(hpp .. "%")
		end
	end
end

function sRaidFrames:UpdateAttachedPetHealth(ownerUnit, petUnit)
	if not ownerUnit or not petUnit then return end
	for _, f in pairs(self:FindUnitFrames(ownerUnit)) do
		if f.petframe and f.petframe:IsShown() then
			self:UpdateSingleAttachedPetHealth(f.petframe, petUnit)
		end
	end
end

function sRaidFrames:UpdateAttachedPetPortrait(ownerUnit, petUnit)
	if not ownerUnit or not petUnit then return end
	local inParty = not IsInRaid()
	for _, f in pairs(self:FindUnitFrames(ownerUnit)) do
		local pf = f.petframe
		if pf and pf.portraitFrame and pf.portrait then
			if inParty and self:GetCurrentPetMode() == "attached" and pf:IsShown() then
				pf.portraitFrame:Show()
				local okP = pcall(SetPortraitTexture, pf.portrait, petUnit)
				if okP then
					pf.portrait:SetTexCoord(0, 1, 0, 1)
				end
			else
				pf.portraitFrame:Hide()
			end
		end
	end
end

function sRaidFrames:UpdateAttachedPetAuras(ownerUnit, petUnit)
	if not ownerUnit or not petUnit then return end
	local inParty = not IsInRaid()
	local allow = inParty and self:GetCurrentPetMode() == "attached" and self.opt.ShowPetBuffs and (self.opt.BuffType ~= "none")

	for _, f in pairs(self:FindUnitFrames(ownerUnit)) do
		local pf = f.petframe
		if pf then
			if pf.hasNativeAuraContainers then
				if not privateFuncs.IsInCombat() then
					self:SyncAttachedPetNativeAuras(pf, allow and petUnit or nil)
				end
				if pf.buffs then
					for i = 1, #pf.buffs do pf.buffs[i]:Hide() end
				end
			elseif pf.buffs then
				for i = 1, #pf.buffs do pf.buffs[i]:Hide() end
				if allow and pf:IsShown() then
					local aurasSecret = (_G.C_Secrets and _G.C_Secrets.ShouldAurasBeSecret and _G.C_Secrets.ShouldAurasBeSecret()) and true or false
					if not aurasSecret then
						local slot = 0
						-- 1. Helpful HoTs / Shields / Mend Pet
						local idx = 1
						while idx <= 32 and slot < #pf.buffs do
							local name, icon, _, _, duration, expirationTime, caster, _, spellId, _, auraInstanceID, isSecret = GetUnitBuff(petUnit, idx)
							if isSecret then break end
							if not name then break end
							local isMine = (caster == "player")
							local wanted = (spellId and Compat.PetBuffSpellIDs and Compat.PetBuffSpellIDs[spellId])
								or (isMine and duration and duration > 0 and duration <= 60 and not (spellId and Compat.FoodDrinkSpellIDs and Compat.FoodDrinkSpellIDs[spellId]))
							if wanted and icon then
								slot = slot + 1
								local btn = pf.buffs[slot]
								btn.texture:SetTexture(icon)
								btn.border:SetColorTexture(0.15, 0.75, 0.95, 0.95)
								SetAuraButtonCooldown(btn, petUnit, duration, expirationTime, auraInstanceID)
								btn:Show()
							end
							idx = idx + 1
						end
						-- 2. Dispellable debuffs on pet
						idx = 1
						while idx <= 32 and slot < #pf.buffs do
							local name, icon, _, dispelType, duration, expirationTime, _, _, _, _, auraInstanceID, isSecret = GetUnitDebuff(petUnit, idx)
							if isSecret then break end
							if not name then break end
							if dispelType and self:CanDispell(dispelType) and icon then
								slot = slot + 1
								local btn = pf.buffs[slot]
								btn.texture:SetTexture(icon)
								local dc = DISPEL_BORDER_COLORS[dispelType]
								if dc then
									btn.border:SetColorTexture(dc.r, dc.g, dc.b, 1)
								else
									btn.border:SetColorTexture(0.9, 0.2, 0.2, 1)
								end
								SetAuraButtonCooldown(btn, petUnit, duration, expirationTime, auraInstanceID)
								btn:Show()
							end
							idx = idx + 1
						end
					end
				end
			end
		end
	end
end

function sRaidFrames:UpdateAttachedPetFrame(f)
	if not f or not f.petframe then return end
	local pf = f.petframe
	local owner = f:GetAttribute("unit")
	local petUnit = self:OwnerToPetUnit(owner)
	if not owner or not petUnit then return end

	if not privateFuncs.IsInCombat() then
		self:SyncAttachedPetNativeAuras(pf, petUnit)
	end
	if not pf:IsShown() then return end

	self:UpdateSingleAttachedPetHealth(pf, petUnit)
	self:UpdateAttachedPetPortrait(owner, petUnit)
	self:UpdateAttachedPetAuras(owner, petUnit)

	if pf.targetHighlight then
		local isTarget = false
		if self.opt.HighlightTarget then
			local okT, same = pcall(UnitIsUnit, petUnit, "target")
			if okT and not IsSecret(same) and same then isTarget = true end
		end
		pf.targetHighlight:SetShown(isTarget)
	end
end

function sRaidFrames:ApplyPetMode()
	if privateFuncs.IsInCombat() then
		self:ScheduleLeaveCombatAction("ApplyPetMode")
		return
	end
	self._lastPetMode = self:GetCurrentPetMode()
	self:EnsureAttachedPetFrames()
	self:SetGroupFilters()
	self:ApplyLayout()
	self:SyncAttachedPetWatches()
	self:RefreshAllNativeAuraContainers()
end

function sRaidFrames:CreateFrames()
	local setup = self:GetCurrentGroupSetup() or {}
	local neededGroups = #setup
	local createdGroups = #self.groupframes
	for i = createdGroups + 1, neededGroups do
		self:CreateGroupFrame(i)
	end
	if not self.petGroup then
		self:CreatePetGroupFrame()
	end
	self:SetPosition()
	self:SetGrowth()
	self:SetGroupFilters()
end

function sRaidFrames:SetGroupFilters()
	if privateFuncs.IsInCombat() then return end

	local inRaid = IsInRaid()
	for _, f in pairs(self.groupframes) do
		local id = f:GetID()
		local frame = self:GetCurrentGroupSetup()[id]
		if not inRaid and self.opt.ShowInParty then
			if id == 1 then
				local pSort = self.opt.PartySortOrder or "tank_dps_healer"
				f.header:SetAttribute("showRaid", true)
				f.header:SetAttribute("showParty", true)
				f.header:SetAttribute("showPlayer", self.opt.ShowSelfInParty and true or false)
				f.header:SetAttribute("groupFilter", nil)
				f.header:SetAttribute("nameList", nil)
				if pSort == "tank_dps_healer" then
					f.header:SetAttribute("groupBy", "ASSIGNEDROLE")
					f.header:SetAttribute("groupingOrder", "TANK,DAMAGER,HEALER,NONE")
					f.header:SetAttribute("sortMethod", "INDEX")
					f.header:SetAttribute("sortDir", "ASC")
				elseif pSort == "tank_healer_dps" then
					f.header:SetAttribute("groupBy", "ASSIGNEDROLE")
					f.header:SetAttribute("groupingOrder", "TANK,HEALER,DAMAGER,NONE")
					f.header:SetAttribute("sortMethod", "INDEX")
					f.header:SetAttribute("sortDir", "ASC")
				elseif pSort == "name" then
					f.header:SetAttribute("groupBy", nil)
					f.header:SetAttribute("groupingOrder", nil)
					f.header:SetAttribute("sortMethod", "NAME")
					f.header:SetAttribute("sortDir", "ASC")
				else
					-- "blizzard": default Blizzard party order (player, party1..party4)
					f.header:SetAttribute("groupBy", nil)
					f.header:SetAttribute("groupingOrder", nil)
					f.header:SetAttribute("sortMethod", "INDEX")
					f.header:SetAttribute("sortDir", "ASC")
				end
				f.title:SetText(L["Party"] or "Party")
				f.header:Show()
			else
				f.header:Hide()
				f.header:SetAttribute("groupFilter", false)
				f.header:SetAttribute("nameList", false)
			end
		elseif frame and not frame.hidden then
			local pSort = self.opt.PartySortOrder or "tank_dps_healer"
			f.header:SetAttribute("showRaid", true)
			f.header:SetAttribute("showParty", self.opt.ShowInParty and true or false)
			f.header:SetAttribute("showPlayer", self.opt.ShowInParty and true or false)
			f.header:SetAttribute("groupFilter", nil)
			f.header:SetAttribute("nameList", nil)
			f.header:SetAttribute("groupBy", nil)
			f.header:SetAttribute("groupingOrder", nil)
			for attribute, value in pairs(frame.attributes) do
				f.header:SetAttribute(attribute, value or nil)
			end
			if self.opt.GroupSetup == L["By group"] and not frame.customSort and not frame.attributes["groupBy"] then
				if pSort == "tank_dps_healer" then
					f.header:SetAttribute("groupBy", "ASSIGNEDROLE")
					f.header:SetAttribute("groupingOrder", "TANK,DAMAGER,HEALER,NONE")
					f.header:SetAttribute("sortMethod", "INDEX")
					f.header:SetAttribute("sortDir", "ASC")
				elseif pSort == "tank_healer_dps" then
					f.header:SetAttribute("groupBy", "ASSIGNEDROLE")
					f.header:SetAttribute("groupingOrder", "TANK,HEALER,DAMAGER,NONE")
					f.header:SetAttribute("sortMethod", "INDEX")
					f.header:SetAttribute("sortDir", "ASC")
				elseif pSort == "name" then
					f.header:SetAttribute("groupBy", nil)
					f.header:SetAttribute("groupingOrder", nil)
					f.header:SetAttribute("sortMethod", "NAME")
					f.header:SetAttribute("sortDir", "ASC")
				else
					f.header:SetAttribute("groupBy", nil)
					f.header:SetAttribute("groupingOrder", nil)
					f.header:SetAttribute("sortMethod", "INDEX")
					f.header:SetAttribute("sortDir", "ASC")
				end
			end
			if LGIST and frame.magicRoles then
				local nameList = {}
				for _, roles in pairs({strsplit(",", frame.magicRoles)}) do
					if IsInRaid() then
						local numRaid = GetNumGroupMembers()
						for i = 1, numRaid do
							local unit = ("raid%d"):format(i)
							local _, eclass = UnitClass(unit)
							local role = privateFuncs.LGIST_to_RoleSpec(unit, eclass)

							if role == roles or (roles == "unknown" and not role) then
								local name = GetRaidRosterInfo(i)
								if name and not IsSecret(name) then
									tinsert(nameList, name)
								end
							end
						end
					end
				end
				f.header:SetAttribute("nameList", tconcat(nameList, ","))
				f.header:SetAttribute("groupFilter", false)
			end
			f.title:SetText(frame.caption)
			f.header:Show()
		else
			f.header:Hide()
			f.header:SetAttribute("groupFilter", false)
			f.header:SetAttribute("nameList", false)
		end
		self:UpdateTitleVisibility(f.header)
	end

	-- Standalone Pet Group Header ("group" mode for Party / Raid)
	if self.petGroup and self.petGroup.header then
		local pf = self.petGroup
		local hdr = pf.header
		local petMode = self:GetCurrentPetMode()
		if petMode == "group" then
			if not inRaid and self.opt.ShowInParty then
				hdr:SetAttribute("showRaid", false)
				hdr:SetAttribute("showParty", true)
				hdr:SetAttribute("showPlayer", self.opt.ShowSelfInParty and true or false)
				hdr:SetAttribute("showSolo", false)
				hdr:SetAttribute("groupFilter", nil)
				hdr:SetAttribute("maxColumns", 1)
				hdr:SetAttribute("unitsPerColumn", 5)
			else
				hdr:SetAttribute("showRaid", true)
				hdr:SetAttribute("showParty", false)
				hdr:SetAttribute("showPlayer", false)
				hdr:SetAttribute("showSolo", false)
				hdr:SetAttribute("groupFilter", nil)
				hdr:SetAttribute("maxColumns", 4)
				hdr:SetAttribute("unitsPerColumn", 5)
				hdr:SetAttribute("columnSpacing", 4)
				hdr:SetAttribute("columnAnchorPoint", "LEFT")
			end
			pf.title:SetText(L["Pets"])
			hdr:Show()
		else
			hdr:Hide()
			hdr:SetAttribute("showRaid", false)
			hdr:SetAttribute("showParty", false)
			hdr:SetAttribute("showPlayer", false)
			hdr:SetAttribute("showSolo", false)
		end
		self:UpdateTitleVisibility(hdr)
	end
	self:UpdateAllUnits()
end

function sRaidFrames:GroupFrameGetNumChildren(frame)
	local i = 1
	local child = frame:GetAttribute("child"..i)
	while child do
		local unit = child:GetAttribute("unit")
		local okEx, exists = pcall(UnitExists, unit)
		if not child:IsVisible() or not unit or not okEx or IsSecret(exists) or not exists then
			break
		end
		i = i + 1
		child = frame:GetAttribute("child"..i)
	end
	return (i - 1)
end

function sRaidFrames:UpdateTitleVisibility(frame)
	if not frame then return end
	if self.petGroup and frame == self.petGroup.header then
		if self:GetCurrentPetMode() == "group" and self.opt.ShowGroupTitles and (self:GroupFrameGetNumChildren(frame) > 0 or not self.opt.Locked) then
			frame:GetParent().anchor:Show()
		else
			frame:GetParent().anchor:Hide()
		end
		return
	end
	if self.opt.ShowGroupTitles and self:GroupFrameGetNumChildren(frame) > 0 then
		frame:GetParent().anchor:Show()
	else
		frame:GetParent().anchor:Hide()
	end
end

function sRaidFrames:SetGrowth()
	if privateFuncs.IsInCombat() then
		self:ScheduleLeaveCombatAction("SetGrowth")
		return
	end
	local inParty = (not IsInRaid()) and self.opt.ShowInParty
	for i, f in pairs(self.groupframes) do
		f.header:ClearAllPoints()
		local growth = (inParty and i == 1) and (self.opt.PartyGrowth or "down") or self.opt.Growth["default"]
		if not (inParty and i == 1) then
			if not self.opt.Growth[self.opt.GroupSetup] then self.opt.Growth[self.opt.GroupSetup] = {} end
			if self.opt.Growth[self.opt.GroupSetup][i] and self.opt.Growth[self.opt.GroupSetup][i] ~= "default" then
				growth = self.opt.Growth[self.opt.GroupSetup][i]
			end
		end
		if growth == "up" then
			f.header:SetAttribute("point", "BOTTOM")
			f.header:SetPoint("BOTTOM", f.anchor, "TOP")
		elseif growth == "right" then
			f.header:SetAttribute("point", "LEFT")
			f.header:SetPoint("LEFT", f.anchor, "RIGHT")
		elseif growth == "left" then
			f.header:SetAttribute("point", "RIGHT")
			f.header:SetPoint("RIGHT", f.anchor, "LEFT")
		elseif growth == "down" then
			f.header:SetAttribute("point", "TOP")
			f.header:SetPoint("TOP", f.anchor, "BOTTOM")
		end
	end
	if self.petGroup and self.petGroup.header and not privateFuncs.IsInCombat() then
		local pf = self.petGroup
		local growth = inParty and (self.opt.PartyGrowth or "down") or (self.opt.Growth["default"] or "down")
		pf.header:ClearAllPoints()
		if growth == "up" then
			pf.header:SetAttribute("point", "BOTTOM")
			pf.header:SetPoint("BOTTOM", pf.anchor, "TOP")
		elseif growth == "right" then
			pf.header:SetAttribute("point", "LEFT")
			pf.header:SetPoint("LEFT", pf.anchor, "RIGHT")
		elseif growth == "left" then
			pf.header:SetAttribute("point", "RIGHT")
			pf.header:SetPoint("RIGHT", pf.anchor, "LEFT")
		else
			pf.header:SetAttribute("point", "TOP")
			pf.header:SetPoint("TOP", pf.anchor, "BOTTOM")
		end
	end
	self:SetSpacing()
end

function sRaidFrames:SetSpacing()
	if privateFuncs.IsInCombat() then
		self:ScheduleLeaveCombatAction("SetSpacing")
		return
	end
	local inParty = (not IsInRaid()) and self.opt.ShowInParty
	local baseSpacing = inParty and (self.opt.PartySpacing or 8) or (self.opt.Spacing or 0)
	local petReserve = self:GetPartyPetSpacingReserve()
	for i, f in pairs(self.groupframes) do
		local growth = (inParty and i == 1) and (self.opt.PartyGrowth or "down") or self.opt.Growth["default"]
		if not (inParty and i == 1) then
			if self.opt.Growth[self.opt.GroupSetup] and self.opt.Growth[self.opt.GroupSetup][i] and self.opt.Growth[self.opt.GroupSetup][i] ~= "default" then
				growth = self.opt.Growth[self.opt.GroupSetup][i]
			end
		end
		local vs = baseSpacing + petReserve
		if growth == "down" then
			f.header:SetAttribute("xOffset", 0)
			f.header:SetAttribute("yOffset", -vs)
		elseif growth == "up" then
			f.header:SetAttribute("xOffset", 0)
			f.header:SetAttribute("yOffset", vs)
		elseif growth == "left" then
			f.header:SetAttribute("xOffset", -baseSpacing)
			f.header:SetAttribute("yOffset", 0)
		elseif growth == "right" then
			f.header:SetAttribute("xOffset", baseSpacing)
			f.header:SetAttribute("yOffset", 0)
		end
	end
	if self.petGroup and self.petGroup.header then
		local growth = inParty and (self.opt.PartyGrowth or "down") or (self.opt.Growth["default"] or "down")
		if growth == "down" then
			self.petGroup.header:SetAttribute("xOffset", 0)
			self.petGroup.header:SetAttribute("yOffset", -baseSpacing)
		elseif growth == "up" then
			self.petGroup.header:SetAttribute("xOffset", 0)
			self.petGroup.header:SetAttribute("yOffset", baseSpacing)
		elseif growth == "left" then
			self.petGroup.header:SetAttribute("xOffset", -baseSpacing)
			self.petGroup.header:SetAttribute("yOffset", 0)
		elseif growth == "right" then
			self.petGroup.header:SetAttribute("xOffset", baseSpacing)
			self.petGroup.header:SetAttribute("yOffset", 0)
		end
	end
end

function sRaidFrames:StartMovingAll(f, this)
	this.multidrag = 1
	local fg = f
	if not fg then return end
	local x, y = fg:GetLeft(), fg:GetTop()
	if not x or not y then
		return
	end
	for _, gf in pairs(self.groupframes) do
		if gf ~= fg then
			local oX, oY = gf:GetLeft(), gf:GetTop()
			if oX and oY then
				gf:ClearAllPoints()
				gf:SetPoint("TOPLEFT", fg, "TOPLEFT", oX - x, oY - y)
			end
		end
	end
	if self.petGroup and self.petGroup ~= fg then
		local oX, oY = self.petGroup:GetLeft(), self.petGroup:GetTop()
		if oX and oY then
			self.petGroup:ClearAllPoints()
			self.petGroup:SetPoint("TOPLEFT", fg, "TOPLEFT", oX - x, oY - y)
		end
	end
end

function sRaidFrames:StopMovingOrSizingAll(f, this)
	this.multidrag = nil
	local fg = f
	for _, gf in pairs(self.groupframes) do
		if gf ~= fg then
			local oX, oY = gf:GetLeft(), gf:GetTop()
			if oX and oY then
				gf:ClearAllPoints()
				gf:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", oX, oY)
			end
		end
	end
	if self.petGroup and self.petGroup ~= fg then
		local oX, oY = self.petGroup:GetLeft(), self.petGroup:GetTop()
		if oX and oY then
			self.petGroup:ClearAllPoints()
			self.petGroup:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", oX, oY)
		end
	end
end

local function sRaidFrames_OnGroupFrameEvent(frame, event)
	if (event == "GROUP_ROSTER_UPDATE" or event == "GROUP_JOINED" or event == "UNIT_PET") and frame:IsVisible() then
		sRaidFrames:ScheduleLeaveCombatAction("UpdateTitleVisibility", frame)
	end
end

function sRaidFrames:CreatePetGroupFrame()
	if self.petGroup then return end
	local layout = self:GetLayout()
	local f = CreateFrame("Frame", "sRaidFramesPetGroupBase", self.master)
	f:SetHeight(layout.headerHeight)
	f:SetWidth(layout.headerWidth)
	f:SetMovable(true)
	f.isPetGroup = true

	local ok, hdr = pcall(CreateFrame, "Frame", "sRaidFramesPetGroupHeader", f, "SecureGroupPetHeaderTemplate")
	if not ok or not hdr then
		ok, hdr = pcall(CreateFrame, "Frame", "sRaidFramesPetGroupHeader", f, "SecureRaidPetHeaderTemplate")
	end
	if not ok or not hdr then
		return
	end
	hdr.isPetHeader = true
	hdr:SetAttribute("template", "SecureUnitButtonTemplate")
	hdr:SetAttribute("initialConfigFunction", sRaidFrames_InitUnitFrame)
	hdr:SetAttribute("useOwnerUnit", false)
	hdr:SetAttribute("filterOnPet", true)
	hdr:HookScript("OnEvent", sRaidFrames_OnGroupFrameEvent)
	hdr.CreateChildFrame = sRaidFrames.CreateChildFrame
	hdr:SetAttribute("style-width", layout.unitframeWidth)
	hdr:SetAttribute("style-height", layout.unitframeHeight)

	if not hdr:IsEventRegistered("GROUP_ROSTER_UPDATE") then hdr:RegisterEvent("GROUP_ROSTER_UPDATE") end
	pcall(function()
		if not hdr:IsEventRegistered("GROUP_JOINED") then hdr:RegisterEvent("GROUP_JOINED") end
		if not hdr:IsEventRegistered("UNIT_PET") then hdr:RegisterEvent("UNIT_PET") end
	end)
	f.header = hdr

	f.anchor = CreateFrame("Button", "sRaidFramesPetAnchor", self.master)
	f.anchor:SetHeight(layout.headerHeight)
	f.anchor:SetWidth(layout.headerWidth)
	f.anchor:SetScript("OnDragStart", function(this)
		if self.opt.Locked or privateFuncs.IsInCombat() then return end
		this._isDragging = true
		if IsAltKeyDown() then self:StartMovingAll(f, this) end
		f:StartMoving()
	end)
	f.anchor:SetScript("OnDragStop", function(this)
		if not this._isDragging then return end
		this._isDragging = nil
		if this.multidrag == 1 then
			if not privateFuncs.IsInCombat() then
				self:StopMovingOrSizingAll(f, this)
			else
				this.multidrag = nil
			end
		end
		pcall(f.StopMovingOrSizing, f)
		if not privateFuncs.IsInCombat() then
			self:SavePosition()
		end
	end)
	f.anchor:SetScript("OnEnter", function(this)
		if self.opt.Locked or not GameTooltip then return end
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		GameTooltip:SetText(f.title:GetText() or L["Pets"])
		GameTooltip:AddLine(L["Drag: Move this group"] or "Drag: Move this group", 1, 1, 1)
		GameTooltip:AddLine(L["Alt + Drag: Move all 8 groups together"] or "Alt + Drag: Move all 8 groups together", 0.2, 1, 0.2)
		GameTooltip:Show()
	end)
	f.anchor:SetScript("OnLeave", function()
		if GameTooltip then GameTooltip:Hide() end
	end)
	f.anchor:EnableMouse(true)
	f.anchor:RegisterForDrag("LeftButton")
	pcall(f.anchor.RegisterForClicks, f.anchor, "AnyUp")
	f.anchor:SetPoint("CENTER", f)

	f.title = f.anchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.title:SetJustifyH("CENTER")
	f.title:ClearAllPoints()
	f.title:SetPoint("CENTER", f.anchor)
	f.title:SetText(L["Pets"])
	f.anchor:Hide()
	hdr:Hide()

	self.petGroup = f
end

function sRaidFrames:CreateGroupFrame(id)
	local layout = self:GetLayout()
	local f = CreateFrame("Frame", "sRaidFramesGroupBase".. id, self.master)
	f:SetHeight(layout.headerHeight)
	f:SetWidth(layout.headerWidth)
	f:SetMovable(true)
	f:SetID(id)

	f.header = CreateFrame("Frame", "sRaidFramesGroupHeader" .. id, f, "SecureRaidGroupHeaderTemplate")
	f.header:SetAttribute("template", "SecureUnitButtonTemplate")
	f.header:SetAttribute("initialConfigFunction", sRaidFrames_InitUnitFrame)
	f.header:HookScript("OnEvent", sRaidFrames_OnGroupFrameEvent)
	f.header.CreateChildFrame = sRaidFrames.CreateChildFrame
	f.header:SetAttribute("style-width", layout.unitframeWidth)
	f.header:SetAttribute("style-height", layout.unitframeHeight)

	if not f.header:IsEventRegistered("GROUP_ROSTER_UPDATE") then f.header:RegisterEvent("GROUP_ROSTER_UPDATE") end
	pcall(function()
		if not f.header:IsEventRegistered("GROUP_JOINED") then f.header:RegisterEvent("GROUP_JOINED") end
	end)

	f.anchor = CreateFrame("Button", "sRaidFramesAnchor"..id, self.master)
	f.anchor:SetHeight(layout.headerHeight)
	f.anchor:SetWidth(layout.headerWidth)
	f.anchor:SetScript("OnDragStart", function(this)
		if self.opt.Locked or privateFuncs.IsInCombat() then return end
		this._isDragging = true
		if IsAltKeyDown() then self:StartMovingAll(f, this) end
		f:StartMoving()
	end)
	f.anchor:SetScript("OnDragStop", function(this)
		if not this._isDragging then return end
		this._isDragging = nil
		if this.multidrag == 1 then
			if not privateFuncs.IsInCombat() then
				self:StopMovingOrSizingAll(f, this)
			else
				this.multidrag = nil
			end
		end
		pcall(f.StopMovingOrSizing, f)
		if not privateFuncs.IsInCombat() then
			self:SavePosition()
		end
	end)
	f.anchor:SetScript("OnEnter", function(this)
		if self.opt.Locked or not GameTooltip then return end
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		GameTooltip:SetText(f.title:GetText() or "sRaidFrames")
		GameTooltip:AddLine(L["Drag: Move this group"] or "Drag: Move this group", 1, 1, 1)
		GameTooltip:AddLine(L["Alt + Drag: Move all 8 groups together"] or "Alt + Drag: Move all 8 groups together", 0.2, 1, 0.2)
		GameTooltip:Show()
	end)
	f.anchor:SetScript("OnLeave", function()
		if GameTooltip then GameTooltip:Hide() end
	end)
	f.anchor:EnableMouse(true)
	f.anchor:RegisterForDrag("LeftButton")
	pcall(f.anchor.RegisterForClicks, f.anchor, "AnyUp")
	f.anchor:SetPoint("CENTER", f)

	f.title = f.anchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.title:SetJustifyH("CENTER")
	f.title:ClearAllPoints()
	f.title:SetPoint("CENTER", f.anchor)

	self.groupframes[id] = f
end

function sRaidFrames:SetWHP(frame, width, height, p1, relative, p2, x, y)
	if not frame then return end
	if not frame:IsProtected() or not privateFuncs.IsInCombat() then
		frame:SetWidth(width)
		frame:SetHeight(height)

		if p1 then
			frame:ClearAllPoints()
			frame:SetPoint(p1, relative, p2, x, y)
		end
	end
end

function sRaidFrames:GetAllUnits()
	if ShouldUpdateFrameCache then self:UpdateFrameCache() end
	return self.FramesByUnit
end

function sRaidFrames:FindUnitFrames(unit)
	if ShouldUpdateFrameCache then self:UpdateFrameCache() end
	return self.FramesByUnit[unit] or {}
end

function sRaidFrames:GetNonVehicleUnit(unit)
	if not unit or IsSecret(unit) then return unit end
	local noPet = unit:gsub("[pP][eE][tT](%d)", "%1")
	if self.opt.VehicleSwitch and UnitHasVehicleUI(noPet) then
		unit = noPet
	end
	return unit
end

function sRaidFrames:GetVehicleUnit(unit)
	if not unit or IsSecret(unit) then return unit end
	if self.opt.VehicleSwitch and UnitHasVehicleUI(unit) then
		unit = unit .. "pet"
		unit = gsub(unit, "^([^%d]+)([%d]+)[pP][eE][tT]", "%1pet%2")
	end
	return unit
end

function sRaidFrames:IsTracking(unit)
	if not unit or IsSecret(unit) then return false end
	if ShouldUpdateFrameCache then self:UpdateFrameCache() end
	return (self.FramesByUnit[unit] ~= nil)
end

function sRaidFrames:SetPosition()
	if #self.opt.Positions[self.opt.GroupSetup] <= 0 then
		self:ResetPosition()
	else
		self:RestorePosition()
	end
end

function sRaidFrames:SavePosition()
	if not self.opt.Positions[self.opt.GroupSetup] then
		self.opt.Positions[self.opt.GroupSetup] = {}
	end

	for k, frame in pairs(self.groupframes) do
		local dbentry = {}
		local x, y, s = frame:GetLeft(), frame:GetTop(), frame:GetEffectiveScale()
		if x and y and s then
			x, y = x * s, y * s
			dbentry.x = x
			dbentry.y = y
			dbentry.s = s
			self.opt.Positions[self.opt.GroupSetup][k] = dbentry
		end
	end
	if self.petGroup then
		local x, y, s = self.petGroup:GetLeft(), self.petGroup:GetTop(), self.petGroup:GetEffectiveScale()
		if x and y and s then
			self.opt.Positions[self.opt.GroupSetup]["pets"] = { x = x * s, y = y * s, s = s }
		end
	end
end

function sRaidFrames:RestorePosition()
	local aryPos = self.opt.Positions[self.opt.GroupSetup] or {}

	for k, data in pairs(aryPos) do
		local groupframe = (k == "pets") and self.petGroup or self.groupframes[k]
		if groupframe then
			local x, y, s = data.x, data.y, groupframe:GetEffectiveScale()
			x, y = x and x / s, y and y / s
			groupframe:ClearAllPoints()
			groupframe:SetPoint(x and "TOPLEFT" or "CENTER", UIParent, y and "BOTTOMLEFT" or "CENTER", x or 0, y or 0)
		end
	end

	-- Self-heal profiles where only Group 1 was saved in Positions (so Groups 2..N still get valid 4x2 grid anchors)
	local curLayout = self:GetLayout()
	local frameHeight = (curLayout and curLayout.unitframeHeight or 36) + 3 + (self.opt.Spacing or 0)
	local headerH = (curLayout and curLayout.headerHeight) or 22
	local framePadding = MEMBERS_PER_RAID_GROUP or 5
	local g1 = self.groupframes[1]
	local g1Pos = aryPos[1]
	for k = 1, #self.groupframes do
		local frame = self.groupframes[k]
		if frame and not aryPos[k] then
			local col = fmod(k - 1, 4)
			local row = floor((k - 1) / 4)
			local xOff = col * ((frame:GetWidth() > 0 and frame:GetWidth() or 90) + 6)
			local yOff = -1 * row * (framePadding * frameHeight + headerH + 10)
			frame:ClearAllPoints()
			if k > 1 and g1 and g1Pos and g1Pos.x and g1Pos.y then
				local s = frame:GetEffectiveScale()
				frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (g1Pos.x / s) + xOff, (g1Pos.y / s) + yOff)
			else
				frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 160 + xOff, -140 + yOff)
			end
		end
	end

	if self.petGroup and not aryPos["pets"] and self.groupframes[1] then
		self.petGroup:ClearAllPoints()
		self.petGroup:SetPoint("TOPLEFT", self.groupframes[1], "TOPRIGHT", 10, 0)
	end
end

function sRaidFrames:ResetPosition()
	if privateFuncs.IsInCombat() then
		self:ScheduleLeaveCombatAction("ResetPosition")
		return
	end
	self.opt.Scale = 1
	self.opt.FrameWidth = 90
	self.opt.HealthBarHeight = 12
	self.opt.PowerBarHeight = 4
	self.opt.FontSize = 10
	self.opt.AuraIconSize = 13
	self.opt.Spacing = 0
	self.opt.PartySpacing = 8
	self.opt.PartyGrowth = "down"
	if self.opt.Growth then
		self.opt.Growth["default"] = "down"
	end
	if self.master then
		self.master:SetScale(1)
	end
	self:ApplyLayout()
	self:SetGrowth()
	self:PositionLayout("ctra", 160, -140)
	self:RefreshAllNativeAuraContainers()
end

function sRaidFrames:PositionLayout(layout, xBuffer, yBuffer)
	local xMod, yMod, i = 0, 0, -1
	local curLayout = self:GetLayout()
	local frameHeight = curLayout.unitframeHeight + 3 + (self.opt.Spacing or 0)
	local headerH = curLayout.headerHeight or 22
	local framePadding = MEMBERS_PER_RAID_GROUP or 5

	for k = 1, #self.groupframes do
		local frame = self.groupframes[k]
		if frame then
			i = i + 1
			if layout == "horizontal" then
				yMod = i * (frame:GetWidth() + 4)
				xMod = 0
			elseif layout == "vertical" then
				if i ~= 0 and fmod(i, 2) == 0 then
					xMod = xMod + (-1 * (framePadding * frameHeight + headerH + 8))
					yMod = 0
					i = 0
				else
					yMod = i * (frame:GetWidth() + 4)
				end
			elseif layout == "ctra" then
				-- Default 4x2 grid: Groups 1-4 on top row, Groups 5-8 on bottom row
				local col = fmod(k - 1, 4)
				local row = floor((k - 1) / 4)
				yMod = col * (frame:GetWidth() + 6)
				xMod = -1 * row * (framePadding * frameHeight + headerH + 10)
			end

			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", xBuffer + yMod, yBuffer + xMod)
		end
	end

	if self.petGroup then
		local refW = (self.groupframes[1] and self.groupframes[1]:GetWidth()) or curLayout.headerWidth or 90
		local petX = xBuffer + (IsInRaid() and (4 * (refW + 6)) or (refW + 10))
		self.petGroup:ClearAllPoints()
		self.petGroup:SetPoint("TOPLEFT", UIParent, "TOPLEFT", petX, yBuffer)
	end

	self:SavePosition()
end

createLDBLauncher = function()
	local version = GetAddOnMetadata("sRaidFrames", "Version") or ""
	if LDB then
		local launcher = LibStub("LibDataBroker-1.1"):NewDataObject("sRaidFrames", {
			type = "launcher",
			label = "sRaidFrames",
			icon = "Interface\\Icons\\INV_Helmet_06",
			OnClick = function(self, button)
				if button == "LeftButton" then
					if LibStub("AceConfigDialog-3.0").OpenFrames["sRaidFrames"] then
						LibStub("AceConfigDialog-3.0"):Close("sRaidFrames")
					else
						LibStub("AceConfigDialog-3.0"):Open("sRaidFrames")
					end
				else
					sRaidFrames:ToggleVisibility()
				end
			end,
			OnTooltipShow = function(tooltip)
				if not tooltip or not tooltip.AddLine then return end
				tooltip:AddLine("sRaidFrames " .. version)
				tooltip:AddLine("|cffaaaaaaForever Edition - Elunia-Moonshadow|r")
				tooltip:AddLine("|cffffff00" .. L["Left-click for options."] .. "|r")
				tooltip:AddLine("|cffffff00" .. L["Right-click to toggle visibility."] .. "|r")
			end
		})

		if LDBIcon then
			LDBIcon:Register("sRaidFrames", launcher, sRaidFrames.db.profile.minimapIcon)
		end
	end
end
