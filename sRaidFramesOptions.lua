--[[
	sRaidFrames Options (WoW: Forever Edition)
	Original Authors: Saroz, Nevcairiel, Stolenlegacy
	WoW: Forever Port & Modernization: Elunia-Moonshadow
	License: GNU General Public License v2.0 (GPLv2) — see LICENSE.txt
]]
local L = LibStub("AceLocale-3.0"):GetLocale("sRaidFrames")
local Media = LibStub("LibSharedMedia-3.0")
local LDBIcon = LibStub("LibDBIcon-1.0", true)
local sRaidFrames = sRaidFrames
local Compat = _G.sRaidFramesCompat
local GetSpellInfo = Compat and Compat.GetSpellInfo or _G.GetSpellInfo

local addonName, NS = ...
local privateFuncs = NS.funcs
local IsInCombat = privateFuncs.IsInCombat

BINDING_HEADER_sRaidFrames = "sRaidFrames"
BINDING_NAME_ShowHideRaidWindows = L["Show/Hide Raid Windows"]
BINDING_NAME_ToggleBuffDebuffview = L["Toggle Buff/Debuff view"]
BINDING_NAME_Toggledisplayofonlydispellabledebuffs = L["Toggle display of only dispellable debuffs"]

local function SetVar(info, val)
	local var = info.arg
	sRaidFrames.db.profile[var] = val
	if sRaidFrames.testMode and sRaidFrames.testMode ~= "off" and sRaidFrames.RefreshTestFrames then
		sRaidFrames:RefreshTestFrames()
	end
end

local function GetVar(info)
	local var = info.arg
	return sRaidFrames.db.profile[var]
end

local function UsesNativeAuraContainers()
	if sRaidFrames and sRaidFrames.frames then
		for _, f in pairs(sRaidFrames.frames) do
			if f.hasNativeAuraContainers then
				return true
			end
		end
	end
	return (_G.AnchorUtil and _G.AnchorUtil.FlowDirection) ~= nil
end

sRaidFrames.options = {
	type = 'group',
	handler = sRaidFrames,
	args = {
		lock = {
			name = L["Lock"],
			type = "toggle",
			desc = L["Lock/Unlock the raid frames"],
			get = function()
				return sRaidFrames.opt.Locked
			end,
			set = function(info, value)
				sRaidFrames.opt.Locked = value
				if not value then
					sRaidFrames.opt.ShowGroupTitles = true
					for _, f in pairs(sRaidFrames.groupframes) do
						sRaidFrames:UpdateTitleVisibility(f.header)
					end
				end
				if sRaidFrames.petGroup and sRaidFrames.petGroup.header then
					sRaidFrames:UpdateTitleVisibility(sRaidFrames.petGroup.header)
				end
				if sRaidFrames.testMode and sRaidFrames.testMode ~= "off" then
					sRaidFrames:RefreshTestFrames()
				end
			end,
			disabled = function() return not sRaidFrames.opt.Show or IsInCombat() end,
			order = 2,
			width = "half",
		},

		testmode = {
			name = L["Test Preview Mode"],
			type = "select",
			desc = L["Preview frames solo (Party with portraits & pets, or 10/20/40-man Raid). Drag out of combat; exits automatically on combat."],
			get = function()
				return sRaidFrames.testMode or "off"
			end,
			set = function(info, value)
				sRaidFrames:SetTestMode(value)
			end,
			values = {
				["off"]    = L["Off"],
				["party"]  = L["5-Player Party (Portraits & Pets)"],
				["raid10"] = L["10-Player Raid (2 Groups + Pets)"],
				["raid20"] = L["20-Player Raid (4 Groups + Pets)"],
				["raid40"] = L["40-Player Raid (8 Groups + Pets)"],
			},
			disabled = IsInCombat,
			width = "double",
			order = 3.2,
		},

		show = {
			name = L["Show"],
			type = "toggle",
			desc = L["Show the raid frames"],
			get = function()
				return sRaidFrames.opt.Show
			end,
			set = function(info, value)
				sRaidFrames.opt.Show = value
				sRaidFrames:UpdateVisibilityDriver()
				sRaidFrames:UpdateRoster()
			end,
			disabled = IsInCombat,
			order = 3,
			width = "half",
		},

		showinparty = {
			name = L["Show in party"],
			type = "toggle",
			desc = L["Show the raid frames when in a 5-man party"],
			get = function()
				return sRaidFrames.opt.ShowInParty
			end,
			set = function(info, value)
				sRaidFrames.opt.ShowInParty = value
				sRaidFrames:UpdateVisibilityDriver()
				sRaidFrames:SetGroupFilters()
				sRaidFrames:UpdateRoster()
			end,
			disabled = function() return not sRaidFrames.opt.Show or IsInCombat() end,
			order = 3.5,
		},

		showselfinparty = {
			name = L["Show myself in party"],
			type = "toggle",
			desc = L["Show your own frame (5 frames total) in 5-player Party mode; uncheck to show only your 4 teammates"],
			get = function()
				return sRaidFrames.opt.ShowSelfInParty
			end,
			set = function(info, value)
				sRaidFrames.opt.ShowSelfInParty = value
				sRaidFrames:SetGroupFilters()
				sRaidFrames:UpdateRoster()
				if sRaidFrames.testMode and sRaidFrames.testMode ~= "off" then
					sRaidFrames:RefreshTestFrames()
				end
			end,
			disabled = function() return not sRaidFrames.opt.Show or not sRaidFrames.opt.ShowInParty or IsInCombat() end,
			order = 3.6,
		},

		hidearena = {
			name = L["Hide in arena"],
			type = "toggle",
			desc = L["Hide the raid frames when you are in an arena"],
			get = function()
				return sRaidFrames.opt.HideInArena
			end,
			set = function(info, value)
				sRaidFrames.opt.HideInArena = value
				sRaidFrames:UpdateRoster()
			end,
			disabled = function() return not sRaidFrames.opt.Show or IsInCombat() end,
			order = 4,
		},
		minimapIcon = {
			type = "toggle",
			order = 5,
			name = L["Minimap Icon"],
			desc = L["Show a Icon to open the config at the Minimap"],
			get = function() return not sRaidFrames.db.profile.minimapIcon.hide end,
			set = function(info, value)
				sRaidFrames.db.profile.minimapIcon.hide = not value
				LDBIcon[value and "Show" or "Hide"](LDBIcon, "sRaidFrames")
			end,
			disabled = function() return not LDBIcon end,
		},
		hideBlizzard = {
			type = "toggle",
			order = 6,
			name = L["Hide Blizzard Raid Frames"],
			get = function() return sRaidFrames.opt.HideBlizzard end,
			set = function(info, value)
				sRaidFrames.opt.HideBlizzard = value
				sRaidFrames:HideBlizzard()
			end,
			disabled = function() return IsInCombat() end,
			width = "double",
		},
		layoutgroup = {
			type = "group",
			name = L["Layout & Positioning"],
			order = 100,
			cmdInline = true,
			args = {
				positioning = {
					name = L["Positioning"],
					type = "group",
					desc = L["Set the positioning of the raid frames"],
					dialogInline = true,
					order = 10,
					disabled = IsInCombat,
					args = {
						reset = {
							name = L["Reset position, size & spacing"],
							type = "execute",
							desc = L["Reset all Party and Raid frames to default position, size, and spacing"],
							func = "ResetPosition",
							order = 1,
						},
						predefined = {
							name = L["Predefined position"],
							type = "select",
							desc = L["Set a predefined position for the raid frames"],
							get = function() return nil end,
							set = function(info, layout)
								local gf1 = sRaidFrames.groupframes and sRaidFrames.groupframes[1]
								local x = (gf1 and gf1:GetLeft()) or 24
								local top = gf1 and gf1:GetTop()
								local y = top and (top - UIParent:GetEffectiveScale() / sRaidFrames.master:GetEffectiveScale() * UIParent:GetTop()) or -155
								sRaidFrames:PositionLayout(layout, x, y)
							end,
							values = {["ctra"] = L["CT_RaidAssist"], ["horizontal"] = L["Horizontal"], ["vertical"] = L["Vertical"]},
							order = 2,
						},
						overallscale = {
							name = L["Overall frame scale"],
							type = "range",
							desc = L["Scale the entire Party and Raid frame group proportionally"],
							min = 0.5,
							max = 2.0,
							step = 0.05,
							get = function()
								return sRaidFrames.opt.Scale or 1
							end,
							set = function(info, value)
								sRaidFrames.opt.Scale = value
								if sRaidFrames.master then
									sRaidFrames.master:SetScale(value)
								end
								if sRaidFrames.testMaster then
									sRaidFrames.testMaster:SetScale(value)
								end
								sRaidFrames:RestorePosition()
							end,
							order = 3,
						},
					},
				},
				arrangement = {
					name = L["Arrangement & Spacing"],
					type = "group",
					dialogInline = true,
					order = 20,
					disabled = IsInCombat,
					args = {
						partysort = {
							name = L["Group Sort Order (Party & Raid)"],
							type = "select",
							desc = L["Choose how players are sorted in 5-player Party and By-group Raid layouts"],
							get = function()
								return sRaidFrames.opt.PartySortOrder or "tank_dps_healer"
							end,
							set = function(info, value)
								sRaidFrames.opt.PartySortOrder = value
								sRaidFrames:SetGroupFilters()
							end,
							values = {
								["tank_dps_healer"] = L["Tank -> DPS -> Healer (Default)"],
								["tank_healer_dps"] = L["Tank -> Healer -> DPS"],
								["blizzard"]        = L["Blizzard Default (Group Order)"],
								["name"]            = L["By Name (A-Z)"],
							},
							width = "double",
							order = 1,
						},
						partygrowth = {
							name = L["Party layout direction"],
							type = "select",
							desc = L["Choose vertical stacking or horizontal tiling for 5-player Party frames"],
							get = function()
								return sRaidFrames.opt.PartyGrowth or "down"
							end,
							set = function(info, value)
								sRaidFrames.opt.PartyGrowth = value
								sRaidFrames:SetGrowth()
							end,
							values = {
								["down"]  = L["Vertical (Top to Bottom)"],
								["right"] = L["Horizontal (Left to Right)"],
								["up"]    = L["Vertical (Bottom to Top)"],
								["left"]  = L["Horizontal (Right to Left)"],
							},
							width = "double",
							order = 1.5,
						},
						growth = {
							name = L["Growth"],
							type = "select",
							desc = L["Set the default growth of the raid frames"],
							get = function()
								return sRaidFrames.opt.Growth["default"]
							end,
							set = function(info, value)
								sRaidFrames.opt.Growth["default"] = value
								sRaidFrames:SetGrowth()
							end,
							values = {["up"] = L["Up"], ["down"] = L["Down"], ["left"] = L["Left"], ["right"] = L["Right"]},
							order = 2,
						},
						spacing = {
							name = L["Frame Spacing"],
							type = "range",
							desc = L["Set the spacing between each of the raid frames"],
							min = -20,
							max = 20,
							step = 1,
							get = function()
								return sRaidFrames.opt.Spacing
							end,
							set = function(info, s)
								sRaidFrames.opt.Spacing = s
								sRaidFrames:SetSpacing()
							end,
							order = 3,
						},
						partyspacing = {
							name = L["Party Frame Spacing"],
							type = "range",
							desc = L["Set the spacing between each of the 5-player party frames"],
							min = 0,
							max = 24,
							step = 1,
							get = function()
								return sRaidFrames.opt.PartySpacing or 8
							end,
							set = function(info, s)
								sRaidFrames.opt.PartySpacing = s
								sRaidFrames:SetSpacing()
							end,
							order = 4,
						},
					},
				},
				layout = {
					name = L["Layout"],
					type = "select",
					desc = L["Set the layout of the frames based on presets"],
					hidden = true,
					get = function()
						return sRaidFrames.opt.Layout
					end,
					set = function(info, value)
						sRaidFrames.opt.Layout = value
						sRaidFrames:SetLayout(value)
						sRaidFrames:ApplyLayout()
					end,
					values = {},
					order = 30,
					width = "double",
					disabled = IsInCombat,
				},
			},
		},

		appearance = {
			type = "group",
			name = L["Appearance & Sizing"],
			order = 200,
			cmdInline = true,
			args = {
				sizing = {
					name = L["Sizing"],
					type = "group",
					dialogInline = true,
					order = 10,
					disabled = IsInCombat,
					args = {
						scale = {
							name = L["Scale"],
							type = "range",
							desc = L["Set the scale of the raid frames"],
							min = 0.5,
							max = 2.0,
							step = 0.05,
							get = function()
								return sRaidFrames.opt.Scale
							end,
							set = function(info, value)
								sRaidFrames.opt.Scale = value
								sRaidFrames.master:SetScale(value)
								sRaidFrames:RestorePosition()
							end,
							order = 1,
						},
						framewidth = {
							name = L["Frame width"],
							type = "range",
							desc = L["Set the width of each unit frame (allows longer dual-names)"],
							min = 70,
							max = 200,
							step = 2,
							get = function() return sRaidFrames.opt.FrameWidth or 90 end,
							set = function(info, value)
								sRaidFrames.opt.FrameWidth = value
								sRaidFrames:ApplyLayout()
							end,
							order = 2,
						},
						hpheight = {
							name = L["Health bar height"],
							type = "range",
							desc = L["Set the height of the health bar"],
							min = 8,
							max = 30,
							step = 1,
							get = function() return sRaidFrames.opt.HealthBarHeight or 12 end,
							set = function(info, value)
								sRaidFrames.opt.HealthBarHeight = value
								sRaidFrames:ApplyLayout()
							end,
							order = 3,
						},
						mpheight = {
							name = L["Power bar height"],
							type = "range",
							desc = L["Set the height of the mana/power bar"],
							min = 2,
							max = 16,
							step = 1,
							get = function() return sRaidFrames.opt.PowerBarHeight or 4 end,
							set = function(info, value)
								sRaidFrames.opt.PowerBarHeight = value
								sRaidFrames:ApplyLayout()
							end,
							order = 4,
						},
						fontsize = {
							name = L["Font size"],
							type = "range",
							desc = L["Set the font size for player names and health text"],
							min = 8,
							max = 20,
							step = 1,
							get = function() return sRaidFrames.opt.FontSize or 10 end,
							set = function(info, value)
								sRaidFrames.opt.FontSize = value
								sRaidFrames:ApplyLayout()
							end,
							order = 5,
						},
						auraiconsize = {
							name = L["Buff/Debuff icon size"],
							type = "range",
							desc = L["Set the size of Buff and Debuff icons on the frames"],
							min = 10,
							max = 24,
							step = 1,
							get = function() return sRaidFrames.opt.AuraIconSize or 13 end,
							set = function(info, value)
								sRaidFrames.opt.AuraIconSize = value
								sRaidFrames:ApplyLayout()
							end,
							order = 6,
						},
					},
				},
				style = {
					name = L["Textures & Colors"],
					type = "group",
					dialogInline = true,
					order = 20,
					args = {
						texture = {
							name = L["Bar textures"],
							type = "select",
							desc = L["Set the texture used on health and mana bars"],
							get = function()
								return sRaidFrames.opt.Texture
							end,
							set = function(info, value)
								sRaidFrames.opt.Texture = value
								sRaidFrames:SetAllStatusBarTexture(Media:Fetch("statusbar", sRaidFrames.opt.Texture))
							end,
							values = AceGUIWidgetLSMlists.statusbar,
							order = 1,
							dialogControl = 'LSM30_Statusbar',
						},
						bordertexture = {
							name = L["Border texture"],
							type = "select",
							desc = L["Set the border texture"],
							get = function()
								return sRaidFrames.opt.BorderTexture
							end,
							set = function(info, value)
								sRaidFrames.opt.BorderTexture = value

								local tex = Media:Fetch("border", sRaidFrames.opt.BorderTexture)
								for _, frame in pairs(sRaidFrames.frames) do
									local backdrop = frame:GetBackdrop()
									if backdrop then
										backdrop.edgeFile = tex
										frame:SetBackdrop(backdrop)
									end
								end
								sRaidFrames:UpdateAllUnits()
							end,
							values = AceGUIWidgetLSMlists.border,
							order = 2,
							dialogControl = 'LSM30_Border',
						},
						background = {
							type = "color",
							name = L["Background color"],
							desc = L["Change the background color"],
							get = function()
								local s = sRaidFrames.opt.BackgroundColor
								return s.r, s.g, s.b, s.a
							end,
							set = function(info, r, g, b, a)
								sRaidFrames.opt.BackgroundColor = {r = r, g = g, b = b, a = a}
								sRaidFrames:UpdateAllUnits()
							end,
							hasAlpha = true,
							order = 3,
						},
						border = {
							type = "color",
							name = L["Border color"],
							desc = L["Change the border color"],
							get = function()
								local s = sRaidFrames.opt.BorderColor
								return s.r, s.g, s.b, s.a
							end,
							set = function(info, r, g, b, a)
								sRaidFrames.opt.BorderColor = {r = r, g = g, b = b, a = a}

								for _, frame in pairs(sRaidFrames.frames) do
									frame:SetBackdropBorderColor(r, g, b, a)
								end
								if sRaidFrames.testMode and sRaidFrames.testMode ~= "off" then
									sRaidFrames:RefreshTestFrames()
								end
							end,
							hasAlpha = true,
							disabled = function() return not sRaidFrames.opt.Border end,
							order = 4,
						},
						healthtext = {
							type = "color",
							name = L["Health text color"],
							desc = L["Change the color of the health text"],
							get = function()
								local s = sRaidFrames.opt.HealthTextColor
								return s.r, s.g, s.b, s.a
							end,
							set = function(info, r, g, b, a)
								sRaidFrames.opt.HealthTextColor = {r = r, g = g, b = b, a = a}

								for _, frame in pairs(sRaidFrames.frames) do
									frame.hpbar.text:SetTextColor(r, g, b, a)
								end
								if sRaidFrames.testMode and sRaidFrames.testMode ~= "off" then
									sRaidFrames:RefreshTestFrames()
								end
							end,
							hasAlpha = false,
							order = 5,
						},
						healthbar = {
							type = "toggle",
							name = L["Color health bar by class"],
							desc = L["Color the health bar by class color"],
							get = function()
								return sRaidFrames.opt.HealthBarColorByClass
							end,
							set = function(info, value)
								sRaidFrames.opt.HealthBarColorByClass = value
								sRaidFrames:UpdateAllUnits()
							end,
							order = 6,
						},
						invert = {
							name = L["Invert health bars"],
							type = "toggle",
							desc = L["Invert the growth of the health bars"],
							get = function()
								return sRaidFrames.opt.Invert
							end,
							set = function(info, value)
								sRaidFrames.opt.Invert = value
								sRaidFrames:UpdateAllUnits()
							end,
							order = 7,
						},
					},
				},
			},
		},

		unitinfo = {
			type = "group",
			name = L["Unit Info & Indicators"],
			order = 300,
			cmdInline = true,
			args = {
				bars = {
					name = L["Name, Health & Power"],
					type = "group",
					dialogInline = true,
					order = 10,
					args = {
						nameformat = {
							name = L["Player name format (Dual-Name)"],
							type = "select",
							width = "double",
							desc = L["Set how player names are displayed (supports WoW: Forever dual-name system, always class-colored)"],
							get = function()
								return sRaidFrames.opt.NameFormat or "full"
							end,
							set = function(info, value)
								sRaidFrames.opt.NameFormat = value
								sRaidFrames:UpdateAllUnits()
							end,
							values = {
								["full"]    = L["Full dual name (First Surname)"],
								["first"]   = L["First name only"],
								["surname"] = L["Surname only"],
							},
							order = 1,
						},
						health = {
							name = L["Health text"],
							type = "select",
							width = "double",
							desc = L["Set health display type"],
							get = function()
								return sRaidFrames.opt.HealthFormat
							end,
							set = function(info, value)
								sRaidFrames.opt.HealthFormat = value
								sRaidFrames:UpdateAllUnits()
							end,
							values = {
								["curmax"] = L["Current and max health"],
								["deficit"] = L["Health deficit"],
								["percent"] = L["Health percentage"],
								["current"] = L["Current health"],
								["curdeficit"] = L["Current health with deficit"],
								["none"] = L["Hide health text"],
							},
							order = 2,
						},
						hidemaxhealth = {
							name = L["Hide Health at 100%"],
							type = "toggle",
							desc = L["Hide Health values if at 100%"],
							get = function()
								return sRaidFrames.opt.HideMaxHealth
							end,
							set = function(info, value)
								sRaidFrames.opt.HideMaxHealth = value
								sRaidFrames:UpdateAllUnits()
							end,
							order = 3,
						},
						healprediction = {
							name = L["Show incoming heal prediction bar"],
							type = "toggle",
							desc = L["Display incoming heal prediction in muted green on health bars"],
							get = function() return sRaidFrames.opt.ShowHealPrediction end,
							set = function(info, value)
								sRaidFrames.opt.ShowHealPrediction = value
								sRaidFrames:UpdateAllUnits()
							end,
							order = 4,
						},
						absorbbar = {
							name = L["Show absorb shield bar"],
							type = "toggle",
							desc = L["Display a 3px absorb shield bar along the top edge of health bars"],
							get = function() return sRaidFrames.opt.ShowAbsorbBar ~= false end,
							set = function(info, value)
								sRaidFrames.opt.ShowAbsorbBar = value
								sRaidFrames:UpdateAllUnits()
							end,
							order = 4.5,
						},
						frequentUpdates = {
							name = L["Frequent Health Updates"],
							type = "toggle",
							desc = L["Accelerate updating of health bars using timed updates instead of relying on the events send by the game."],
							get = function()
								return sRaidFrames.opt.HealthFrequentUpdates
							end,
							set = function(info, s)
								sRaidFrames.opt.HealthFrequentUpdates = s
								sRaidFrames:ToggleFrequentUpdates()
							end,
							order = 5,
						},
						powerfilter = {
							name = L["Power type visiblity"],
							type = "multiselect",
							desc = L["Toggle the display of certain power types (Mana, Rage, Energy)"],
							get = function(info, key)
								return sRaidFrames.opt.PowerFilter[tonumber(key)]
							end,
							set = function(info, key, value)
								sRaidFrames.opt.PowerFilter[tonumber(key)] = value
								sRaidFrames:UpdateAllUnits()
							end,
							values = {
								[tostring(Compat.POWER_MANA)] = L["Mana"],
								[tostring(Compat.POWER_RAGE)] = L["Rage"],
								[tostring(Compat.POWER_FOCUS)] = L["Focus"],
								[tostring(Compat.POWER_ENERGY)] = L["Energy"],
								[tostring(Compat.POWER_RUNIC_POWER)] = L["Runic Power"],
							},
							order = 10,
						},
						vehiclepower = {
							name = L["Show Vehicle Power"],
							type = "toggle",
							hidden = true,
							desc = L["Always show the power of vehicles, independant of the power filter setting."],
							get = function(info)
								return sRaidFrames.opt.VehiclePower
							end,
							set = function(info, value)
								sRaidFrames.opt.VehiclePower = value
								sRaidFrames:UpdateAllUnits()
							end,
							order = 98,
						},
						vehiclestatus = {
							name = L["Show Vehicle Name"],
							type = "toggle",
							hidden = true,
							desc = L["Show the name of the units vehicle in the statusbar."],
							get = function(info)
								return sRaidFrames.opt.VehicleStatus
							end,
							set = function(info, value)
								sRaidFrames.opt.VehicleStatus = value
								sRaidFrames:UpdateAllUnits()
							end,
							order = 99,
						},
					},
				},
				icons = {
					name = L["Icons & Portrait"],
					type = "group",
					dialogInline = true,
					order = 20,
					args = {
						partyportrait = {
							name = L["Show circular 2D portrait in Party"],
							type = "toggle",
							width = "double",
							desc = L["Display a circular 2D character portrait on the left side of frames in 5-player Party mode (shows default race/gender portrait until in view range)"],
							get = function() return sRaidFrames.opt.ShowPartyPortrait end,
							set = function(info, value)
								sRaidFrames.opt.ShowPartyPortrait = value
								sRaidFrames:ApplyLayout()
								sRaidFrames:UpdateAllUnits()
							end,
							order = 1,
						},
						titles = {
							name = L["Show group titles"],
							type = "toggle",
							desc = L["Toggle display of titles above each group frame"],
							get = function()
								return sRaidFrames.opt.ShowGroupTitles
							end,
							set = function(info, value)
								sRaidFrames.opt.ShowGroupTitles = value
								for _, f in pairs(sRaidFrames.groupframes) do
									sRaidFrames:UpdateTitleVisibility(f.header)
								end
								if sRaidFrames.petGroup and sRaidFrames.petGroup.header then
									sRaidFrames:UpdateTitleVisibility(sRaidFrames.petGroup.header)
								end
								if sRaidFrames.testMode and sRaidFrames.testMode ~= "off" then
									sRaidFrames:RefreshTestFrames()
								end
							end,
							disabled = function() return not sRaidFrames.opt.Locked or IsInCombat() end,
							order = 2,
						},
						classicon = {
							name = L["Show class icon beside health bar"],
							type = "toggle",
							desc = L["Display a small class icon to the right of the health bar"],
							get = function() return sRaidFrames.opt.ShowClassIcon end,
							set = function(info, value)
								sRaidFrames.opt.ShowClassIcon = value
								sRaidFrames:ApplyLayout()
								sRaidFrames:UpdateAllUnits()
							end,
							order = 3,
						},
						tankicons = {
							name = L["Show Tank / Role icons"],
							type = "toggle",
							desc = L["Display Main Tank / Main Assist icons in Raid, and Tank / Healer / DPS role icons in 5-player Party"],
							get = function() return sRaidFrames.opt.ShowTankIcons end,
							set = function(info, value)
								sRaidFrames.opt.ShowTankIcons = value
								sRaidFrames:UpdateAllUnits()
							end,
							order = 4,
						},
						leadericon = {
							name = L["Show leader crown icon"],
							type = "toggle",
							desc = L["Display a crown icon on the health bar for the raid or party leader"],
							get = function() return sRaidFrames.opt.ShowLeaderIcon end,
							set = function(info, value)
								sRaidFrames.opt.ShowLeaderIcon = value
								sRaidFrames:UpdateAllUnits()
							end,
							order = 5,
						},
					},
				},
				highlights = {
					name = L["Status Highlights"],
					type = "group",
					dialogInline = true,
					order = 30,
					args = {
						highlight = {
							name = L["Highlight targetted unit"],
							type = "toggle",
							desc = L["Turn the border of unit you are targetting orange"],
							arg = "HighlightTarget",
							get = GetVar,
							set = function(info, value)
								sRaidFrames.opt.HighlightTarget = value
								if not value then
									for unit in pairs(sRaidFrames:GetAllUnits()) do
										sRaidFrames:UnsetStatus(unit, "Target")
									end
									for _, f in pairs(sRaidFrames.frames) do
										if f.petframe and f.petframe.targetHighlight then
											f.petframe.targetHighlight:Hide()
										end
									end
								else
									sRaidFrames:UpdateTarget()
								end
							end,
							order = 1,
						},
						aggro = {
							name = L["Highlight units with aggro"],
							type = "toggle",
							desc = L["Turn the border of units who have aggro red"],
							get = GetVar,
							set = function(info, value)
								sRaidFrames.opt.AggroCheck = value
								if not value then
									for unit in pairs(sRaidFrames:GetAllUnits()) do
										sRaidFrames:UnsetStatus(unit, "Aggro")
									end
								else
									for unit in pairs(sRaidFrames:GetAllUnits()) do
										sRaidFrames:UpdateUnitThreat("OPTION", unit)
									end
								end
							end,
							arg = "AggroCheck",
							order = 2,
							disabled = function() return not LibStub("LibBanzai-2.0", true) and not _G.UnitThreatSituation end,
						},
						heals = {
							name = L["Enable heal tracking"],
							type = "toggle",
							desc = L["Show incoming healing amount (+value) in green on the status bar"],
							get = GetVar,
							set = function(info, value)
								sRaidFrames.opt.HighlightHeals = value
								if not value then
									for unit in pairs(sRaidFrames:GetAllUnits()) do
										sRaidFrames:UnsetStatus(unit, "Heal")
									end
								else
									for unit in pairs(sRaidFrames:GetAllUnits()) do
										sRaidFrames:UpdateHealsOnUnit("OPTION", unit)
									end
								end
							end,
							arg = "HighlightHeals",
							order = 3,
						},
						readycheck = {
							name = L["Display ready check"],
							type = "toggle",
							desc = L["Display readiness status for the raid"],
							get = GetVar,
							set = function(info, value)
								sRaidFrames.opt.ReadyCheck = value
								if not value then
									for unit in pairs(sRaidFrames:GetAllUnits()) do
										sRaidFrames:UnsetStatus(unit, "ReadyCheck_Pending")
										sRaidFrames:UnsetStatus(unit, "ReadyCheck_Ready")
										sRaidFrames:UnsetStatus(unit, "ReadyCheck_NotReady")
									end
								end
							end,
							arg = "ReadyCheck",
							order = 4,
						},
					},
				},
			},
		},

		pets = {
			type = "group",
			name = L["Pets"],
			desc = L["Configure how party and raid pets are displayed"],
			order = 350,
			args = {
				partyGroup = {
					type = "group",
					name = L["Party Pets"],
					inline = true,
					order = 10,
					args = {
						partyPetMode = {
							name = L["Party pet display mode"],
							type = "select",
							width = "double",
							desc = L["Choose how pets are displayed in 5-player parties (Follow teammate reserves uniform spacing below each player)"],
							values = {
								["attached"] = L["Follow teammate frame"],
								["group"]    = L["Separate pet group"],
								["none"]     = L["Do not show"],
							},
							get = function() return sRaidFrames.opt.PartyPetMode or "attached" end,
							set = function(info, value)
								sRaidFrames.opt.PartyPetMode = value
								sRaidFrames:ApplyPetMode()
							end,
							disabled = IsInCombat,
							order = 1,
						},
					},
				},
				raidGroup = {
					type = "group",
					name = L["Raid Pets"],
					inline = true,
					order = 20,
					args = {
						raidPetMode = {
							name = L["Raid pet display mode"],
							type = "select",
							width = "double",
							desc = L["Choose how pets are displayed in raids (Follow teammate tucks a compact pet bar inside the bottom-right of the power bar)"],
							values = {
								["attached"] = L["Follow teammate frame"],
								["group"]    = L["Separate pet group"],
								["none"]     = L["Do not show"],
							},
							get = function() return sRaidFrames.opt.RaidPetMode or "attached" end,
							set = function(info, value)
								sRaidFrames.opt.RaidPetMode = value
								sRaidFrames:ApplyPetMode()
							end,
							disabled = IsInCombat,
							order = 1,
						},
					},
				},
				showPetBuffs = {
					name = L["Show pet buffs/debuffs"],
					type = "toggle",
					width = "double",
					desc = L["Display compact low-pixel HoT, shield, and dispellable debuff icons in the top-right corner of pet health bars"],
					get = function() return sRaidFrames.opt.ShowPetBuffs ~= false end,
					set = function(info, value)
						sRaidFrames.opt.ShowPetBuffs = value
						sRaidFrames:RefreshAllNativeAuraContainers()
						sRaidFrames:UpdateAllUnits()
					end,
					order = 30,
				},
			},
		},

		utility = {
			type = "group",
			name = L["Range & Tooltips"],
			order = 500,
			cmdInline = true,
			args = {
				range = {
					name = L["Range"],
					type = "group",
					desc = L["Options for range checks"],
					dialogInline = true,
					order = 10,
					args = {
						enable = {
							name = L["Enable range check"],
							type = "toggle",
							desc = L["Enable range checking"],
							get = function() return sRaidFrames.opt.RangeCheck end,
							set = function(info, value)
								sRaidFrames.opt.RangeCheck = value
								if not value then
									for _, f in pairs(sRaidFrames.frames) do
										if f.SetVisualAlpha then f:SetVisualAlpha(1) else f:SetAlpha(1) end
										if f.petframe then
											if f.petframe.SetVisualAlpha then f.petframe:SetVisualAlpha(1) else f.petframe:SetAlpha(1) end
										end
									end
								end
								if sRaidFrames.testMode and sRaidFrames.testMode ~= "off" then
									sRaidFrames:RefreshTestFrames()
								end
							end,
							order = 1,
						},
						limit = {
							name = L["Range"],
							type = "select",
							desc = L["The range at which a unit is considered out of range"],
							get = function() return tostring(sRaidFrames.opt.RangeLimit) end,
							set = function(info, value)
								sRaidFrames.opt.RangeLimit = tonumber(value)
							end,
							values = {},
							disabled = function() return not sRaidFrames.opt.RangeCheck end,
							order = 2,
						},
						alpha = {
							name = L["Alpha"],
							type = "range",
							desc = L["The alpha level for units who are out of range"],
							get = GetVar,
							set = SetVar,
							arg = "RangeAlpha",
							min  = 0,
							max  = 1,
							step = 0.1,
							disabled = function() return not sRaidFrames.opt.RangeCheck end,
							order = 3,
						},
						frequency = {
							name = L["Frequency"],
							type = "range",
							desc = L["The interval between which range checks are performed"],
							get = function() return sRaidFrames.opt.RangeFrequency end,
							set = function(info, value)
								sRaidFrames.opt.RangeFrequency = value
								sRaidFrames:UpdateRangeFrequency()
							end,
							min  = 0.2,
							max  = 2.0,
							step = 0.1,
							disabled = function() return not sRaidFrames.opt.RangeCheck end,
							order = 4,
						},
					},
				},
				tooltips = {
					name = L["Tooltip display"],
					type = "group",
					desc = L["Determine when a tooltip is displayed"],
					dialogInline = true,
					order = 20,
					args = {
						units = {
							name = L["Unit tooltips"],
							type = "select",
							width = "double",
							desc = L["Determine when a tooltip is displayed"],
							get = GetVar,
							set = SetVar,
							arg = "UnitTooltipMethod",
							values = {["never"] = L["Never"], ["notincombat"] = L["Only when not in combat"], ["always"] = L["Always"]},
							order = 1,
						},
						unittype = {
							name = L["Unit tooltip type"],
							type = "select",
							desc = L["Determine the look of unit tooltips"],
							get = GetVar,
							set = SetVar,
							arg = "UnitTooltipType",
							values = {["blizz"] = "Blizzard", ["ctra"] = "CT_RaidAssist"},
							order = 2,
						},
						buffs = {
							name = L["Buff tooltips"],
							type = "select",
							desc = L["Determine when a tooltip is displayed"],
							get = GetVar,
							set = SetVar,
							arg = "BuffTooltipMethod",
							values = {["never"] = L["Never"], ["notincombat"] = L["Only when not in combat"], ["always"] = L["Always"]},
							order = 3,
						},
						debuffs = {
							name = L["Debuff tooltips"],
							type = "select",
							desc = L["Determine when a tooltip is displayed"],
							get = GetVar,
							set = SetVar,
							arg = "DebuffTooltipMethod",
							values = {["never"] = L["Never"], ["notincombat"] = L["Only when not in combat"], ["always"] = L["Always"]},
							order = 4,
						},
					},
				},
			},
		},

		sets = {
			name = L["Filter/Sort sets"],
			type = "group",
			desc = L["Toggle the display of certain Groups/Classes"],
			args = {},
			disabled = IsInCombat,
			order = 600,
		},

		buffsdebuffs = {
			type = "group",
			name = L["Buffs & Debuffs"],
			order = 400,
			cmdInline = true,
			args = {
				debuffs = {
					name = L["Debuffs"],
					type = "group",
					desc = L["Debuff settings"],
					args = {
						curable = {
							order = 1,
							width = "full",
							name = L["Show only curable debuffs"],
							type = "toggle",
							desc = L["Show only debuffs that are curable by me"],
							get = function()
								return sRaidFrames.opt.ShowOnlyDispellable
							end,
							set = function(info, value)
								sRaidFrames.opt.ShowOnlyDispellable = value
								sRaidFrames:RefreshAllNativeAuraContainers()
							end,
							disabled = function() return (sRaidFrames.opt.BuffType == "buffs" or sRaidFrames.opt.BuffType == "none") end,
						},
						dispelborder = {
							order = 1.5,
							width = "full",
							name = L["Color debuff icon border by dispel type"],
							type = "toggle",
							desc = L["Show a colored border around dispellable debuff icons (Magic/Disease/Poison/Curse)"],
							get = function()
								return sRaidFrames.opt.DispelIconBorder
							end,
							set = function(info, value)
								sRaidFrames.opt.DispelIconBorder = value
								sRaidFrames:RefreshAllNativeAuraContainers()
							end,
						},
						highlight = {
							order = 2,
							width = "double",
							name = L["Highlight debuffed units"],
							type = "select",
							desc = L["Highlight units afflicted by a certain debuff type"],
							get = function()
								return sRaidFrames.opt.HighlightDebuffs
							end,
							set = function(info, value)
								sRaidFrames.opt.HighlightDebuffs = value
								sRaidFrames:RefreshAllNativeAuraContainers()
							end,
							values = {["never"] = L["Never"], ["all"] = L["All dispellable debuffs"], ["onlyself"] = L["Debuffs dispellable by me"]},
						},
						blacklist = {
							name = L["Debuff blacklist"],
							type = "group",
							desc = L["Set a list of debuffs to never be displayed"],
							hidden = UsesNativeAuraContainers,
							dialogInline = true,
							args = {
								add = {
									name = L["Add debuff"],
									type = "input",
									desc = L["Add a debuff"],
									get = false,
									set = function(info, value)
										if tonumber(value) then
											value = GetSpellInfo(tonumber(value))
										end
										if value and value ~= "" and not sRaidFrames.opt.DebuffFilter[value] and not sRaidFrames.opt.DebuffWhitelist[value] then
											sRaidFrames.opt.DebuffFilter[value] = true
											sRaidFrames:chatUpdateDebuffMenu()
											for unit in pairs(sRaidFrames:GetAllUnits()) do
												sRaidFrames:UpdateAuras(unit)
											end
										end
									end,
									usage = L["<name of debuff>"],
								},
								remove = {
									type = "select",
									name = L["Remove debuff"],
									desc = L["Remove debuffs from the filter"],
									order = 200,
									values = {},
									get = false,
									set = function(info, value)
										sRaidFrames.opt.DebuffFilter[value] = nil
										sRaidFrames:chatUpdateDebuffMenu()
										for unit in pairs(sRaidFrames:GetAllUnits()) do
											sRaidFrames:UpdateAuras(unit)
										end
									end,
								},
							},
							disabled = function() return (sRaidFrames.opt.BuffType == "buffs") end,
							order = 3,
						},
						whitelist = {
							name = L["Debuff whitelist"],
							type = "group",
							desc = L["Set a list of debuffs to always be displayed"],
							hidden = UsesNativeAuraContainers,
							dialogInline = true,
							args = {
								add = {
									name = L["Add debuff"],
									type = "input",
									desc = L["Add a debuff"],
									get = false,
									set = function(info, value)
										if tonumber(value) then
											value = GetSpellInfo(tonumber(value))
										end
										if value and value ~= "" and not sRaidFrames.opt.DebuffWhitelist[value] and not sRaidFrames.opt.DebuffFilter[value] then
											sRaidFrames.opt.DebuffWhitelist[value] = true
											sRaidFrames:chatUpdateDebuffMenu()
											for unit in pairs(sRaidFrames:GetAllUnits()) do
												sRaidFrames:UpdateAuras(unit)
											end
										end
									end,
									usage = L["<name of debuff>"],
								},
								remove = {
									type = "select",
									name = L["Remove debuff"],
									desc = L["Remove debuffs from the filter"],
									order = 200,
									values = {},
									get = false,
									set = function(info, value)
										sRaidFrames.opt.DebuffWhitelist[value] = nil
										sRaidFrames:chatUpdateDebuffMenu()
										for unit in pairs(sRaidFrames:GetAllUnits()) do
											sRaidFrames:UpdateAuras(unit)
										end
									end,
								},
							},
							disabled = function() return not (sRaidFrames.opt.BuffType ~= "buffs" and sRaidFrames.opt.ShowOnlyDispellable) end,
							order = 4,
						},
						debufftimer = {
							order = 5,
							type = "group",
							desc = L["Display a countdown on debuffs"],
							dialogInline = true,
							name = L["Debuff timer"],
							args = {
								enable = {
									type = "toggle",
									name = L["Enable debuff countdowns"],
									desc = L["Select whether you want countdowns to be displayed on debuffs"],
									get = function() return sRaidFrames.opt.debufftimer.show end,
									set = function(info, value)
										sRaidFrames.opt.debufftimer.show = value
										sRaidFrames:RefreshAllNativeAuraContainers()
									end,
									order = 1,
								},
								limit = {
									type = "range",
									name = L["Maximum time"],
									desc = L["Debuffs lasting longer than this do not have a countdown"],
									hidden = UsesNativeAuraContainers,
									get = function() return sRaidFrames.opt.debufftimer.max end,
									set = function(info, value) sRaidFrames.opt.debufftimer.max = value end,
									order = 2,
									disabled = function() return not sRaidFrames.opt.debufftimer.show end,
									min = 1,
									max = 99,
									step = 1,
									bigStep = 1,
								},
							},
						},
					},
					order = 501,
				},

				buffs = {
					name = L["Buffs"],
					type = "group",
					desc = L["Buff settings"],
					disabled = function() return (sRaidFrames.opt.BuffType == "debuffs" or sRaidFrames.opt.BuffType == "none") end,
					args = {
						priestbuffs = {
							type = "group",
							name = L["Class & Raid Buffs"],
							desc = L["Prioritize and display key class buffs, HoTs, shields, and Weakened Soul"],
							order = 0,
							dialogInline = true,
							args = {
								enable = {
									type = "toggle",
									width = "full",
									name = L["Show Class Buffs, HoTs & Weakened Soul"],
									desc = L["Prioritize and display key raid buffs, healing HoTs, shields, defensive cooldowns, and Weakened Soul"],
									get = function() return sRaidFrames.opt.ShowPriestBuffs end,
									set = function(info, value)
										sRaidFrames.opt.ShowPriestBuffs = value
										sRaidFrames:RefreshAllNativeAuraContainers()
									end,
									order = 1,
								},
								mode = {
									type = "select",
									width = "double",
									name = L["Class & raid buff filter"],
									desc = L["Select which class and raid buffs to display on raid frames"],
									get = function() return sRaidFrames.opt.PriestBuffFilter end,
									set = function(info, value)
										sRaidFrames.opt.PriestBuffFilter = value
										sRaidFrames:RefreshAllNativeAuraContainers()
									end,
									disabled = function() return not sRaidFrames.opt.ShowPriestBuffs end,
									values = {
										["class"]  = L["My class raid buffs only (Smart: e.g. Paladin sees Blessings, Priest sees Fort/Spirit)"],
										["all"]    = L["All class raid & combat buffs (Fort/Intellect/MotW/Blessings/Shields/HoTs)"],
										["combat"] = L["Combat & healing buffs only (HoTs/Shields/Defensives)"],
										["mine"]   = L["My buffs only"],
									},
									order = 2,
								},
							},
						},
						displaysettings = {
							type = "group",
							name = L["Buff Display"],
							desc = L["Set which buffs are displayed by default"],
							hidden = UsesNativeAuraContainers,
							order = 3,
							dialogInline = true,
							args = {
								display = {
									name = L["Default"],
									type = "select",
									desc = L["Set which buffs are displayed by default"],
									get = function()
										return sRaidFrames.opt.BuffDisplay.default
									end,
									set = function(info, value)
										if tonumber(value) then
											value = GetSpellInfo(tonumber(value))
										end
										sRaidFrames.opt.BuffDisplay.default = value
										for unit in pairs(sRaidFrames:GetAllUnits()) do
											sRaidFrames:UpdateAuras(unit)
										end
									end,
									values = {["own"] = L["Show buffs cast by me"], ["all"] = L["Show all buffs"]},
									order = 1,
								},
								exceptions = {
									type = "group",
									name = L["Exceptions"],
									order = 2,
									desc = L["Add exceptions to the above default value"],
									dialogInline = true,
									args = {
										manage = {
											name = L["Buff"],
											desc = L["Select a buff to configure"],
											type = "input",
											get = function() return sRaidFrames.CurrentExceptionBuff or "" end,
											set = function(info, value)
												if tonumber(value) then
													value = GetSpellInfo(tonumber(value)) or value
												end
												sRaidFrames.CurrentExceptionBuff = (value and value ~= "") and value or nil
											end,
											order = 1,
										},
										suggest = {
											name = L["Already configured exceptions"],
											desc = L["A list of already configured exceptions"],
											type = "select",
											order = 2,
											get = function() return sRaidFrames.CurrentExceptionBuff or false end,
											set = function(info, value) sRaidFrames.CurrentExceptionBuff = value end,
											values = function()
												local t = {}
												for i, k in pairs(sRaidFrames.opt.BuffDisplay) do
													if i ~= "default" then t[i] = string.lower(i) end
												end
												if sRaidFrames.CurrentExceptionBuff then
													t[sRaidFrames.CurrentExceptionBuff] = sRaidFrames.CurrentExceptionBuff
												end
												return t
											end,
										},
										set = {
											name = L["Set display type"],
											type = "group",
											desc = L["Set the display type for the above buff"],
											dialogInline = true,
											hidden = function() return not sRaidFrames.CurrentExceptionBuff end,
											order = 3,
											args = {
												own = {
													name = L["Own"],
													desc = L["Show this if it is cast by me"],
													type = "toggle",
													order = 1,
													get = function() return sRaidFrames.opt.BuffDisplay[string.lower(sRaidFrames.CurrentExceptionBuff)] and (sRaidFrames.opt.BuffDisplay[string.lower(sRaidFrames.CurrentExceptionBuff)] == "own") end,
													set = function() sRaidFrames.opt.BuffDisplay[string.lower(sRaidFrames.CurrentExceptionBuff)] = "own" for unit in pairs(sRaidFrames:GetAllUnits()) do sRaidFrames:UpdateAuras(unit) end end,
												},
												all = {
													name = L["All"],
													desc = L["Show this even if it is not cast by me"],
													type = "toggle",
													order = 2,
													get = function() return sRaidFrames.opt.BuffDisplay[string.lower(sRaidFrames.CurrentExceptionBuff)] and (sRaidFrames.opt.BuffDisplay[string.lower(sRaidFrames.CurrentExceptionBuff)] == "all") end,
													set = function() sRaidFrames.opt.BuffDisplay[string.lower(sRaidFrames.CurrentExceptionBuff)] = "all" for unit in pairs(sRaidFrames:GetAllUnits()) do sRaidFrames:UpdateAuras(unit) end end,
												},
												default = {
													name = L["Default"],
													desc = L["Show this according to the default setting"],
													type = "toggle",
													order = 3,
													get = function() return not sRaidFrames.opt.BuffDisplay[string.lower(sRaidFrames.CurrentExceptionBuff)] end,
													set = function() sRaidFrames.opt.BuffDisplay[string.lower(sRaidFrames.CurrentExceptionBuff)] = nil for unit in pairs(sRaidFrames:GetAllUnits()) do sRaidFrames:UpdateAuras(unit) end end,
												},
											},
										},
									},
								},
							},
						},
						filter = {
							name = L["Buff Filter"],
							type = "group",
							desc = L["Set a list of buffs to be exclusively displayed"],
							hidden = UsesNativeAuraContainers,
							dialogInline = true,
							args = {
								add = {
									name = L["Add buff"],
									type = "input",
									desc = L["Add a buff"],
									get = false,
									set = function(info, value)
										if tonumber(value) then
											value = GetSpellInfo(tonumber(value))
										end
										if value and value ~= "" and not sRaidFrames.opt.BuffFilter[string.lower(value)] then
											sRaidFrames.opt.BuffFilter[string.lower(value)] = true
											sRaidFrames:chatUpdateBuffMenu()
											for unit in pairs(sRaidFrames:GetAllUnits()) do
												sRaidFrames:UpdateAuras(unit)
											end
										end
									end,
									usage = L["<name of buff>"],
								},
								remove = {
									type = "select",
									name = L["Remove buff"],
									desc = L["Remove buffs from the filter"],
									order = 200,
									values = {},
									get = false,
									set = function(info, value)
										sRaidFrames.opt.BuffFilter[value] = nil
										sRaidFrames:chatUpdateBuffMenu()
										for unit in pairs(sRaidFrames:GetAllUnits()) do
											sRaidFrames:UpdateAuras(unit)
										end
									end,
								},
							},
							order = 4,
						},
						oldblacklist = {
							name = L["Buff blacklist"],
							type = "group",
							hidden = true,
							desc = L["Prevent certain buffs from being displayed"],
							order = 1,
							dialogInline = true,
							args = {
								add = {
									type = "input",
									name = L["Add buff"],
									desc = L["Add a buff"],
									usage = L["<name of buff>"],
									get = false,
									set = function(info, value)
										if tonumber(value) then
											value = GetSpellInfo(tonumber(value)) or value
										end
										if value and value ~= "" then
											sRaidFrames.opt.BuffDisplayOptions[string.lower(value)] = 0
											for unit in pairs(sRaidFrames:GetAllUnits()) do sRaidFrames:UpdateAuras(unit) end
										end
									end,
									order = 1,
								},
								remove = {
									type = "select",
									name = L["Remove buff"],
									desc = L["Remove a buff from the blacklist"],
									get = false,
									set = function(info, value) sRaidFrames.opt.BuffDisplayOptions[value] = 3 for unit in pairs(sRaidFrames:GetAllUnits()) do sRaidFrames:UpdateAuras(unit) end end,
									values = function()
										local a = {}
										for i, k in pairs(sRaidFrames.opt.BuffDisplayOptions) do
											if k == 0 then a[i] = i end
										end
										return a
									end,
									order = 2,
								},
							},
						},
						bufftimer = {
							name = L["Buff timer"],
							type = "group",
							desc = L["Display a countdown on buffs"],
							order = 5,
							dialogInline = true,
							args = {
								enable = {
									type = "toggle",
									name = L["Enable buff countdowns"],
									desc = L["Select whether you want countdowns to be displayed on buffs"],
									get = function() return sRaidFrames.opt.bufftimer.show end,
									set = function(info, value)
										sRaidFrames.opt.bufftimer.show = value
										sRaidFrames:RefreshAllNativeAuraContainers()
									end,
									order = 1,
								},
								limit = {
									type = "range",
									name = L["Maximum time"],
									desc = L["Buffs lasting longer than this do not have a countdown"],
									hidden = UsesNativeAuraContainers,
									get = function() return sRaidFrames.opt.bufftimer.max end,
									set = function(info, value) sRaidFrames.opt.bufftimer.max = value end,
									order = 2,
									disabled = function() return not sRaidFrames.opt.bufftimer.show end,
									min = 1,
									max = 99,
									step = 1,
									bigStep = 1,
								},
							},
						},
					},
					order = 502,
				},

				bosswarnings = {
					name = L["Boss & DBM Warnings"],
					type = "group",
					desc = L["Important Boss debuffs and DBM skill warning settings"],
					order = 503,
					args = {
						enable = {
							type = "toggle",
							width = "full",
							name = L["Enable Boss & DBM skill warnings"],
							desc = L["Always display important Boss debuffs and DBM/BigWigs skill target warnings on raid frames"],
							get = function() return sRaidFrames.opt.ShowBossDebuffs end,
							set = function(info, value)
								sRaidFrames.opt.ShowBossDebuffs = value
								sRaidFrames:RefreshAllNativeAuraContainers()
							end,
							order = 1,
						},
						duration = {
							type = "range",
							name = L["DBM warning duration"],
							desc = L["How many seconds a DBM target announcement alert stays highlighted on the unit frame"],
							min = 2,
							max = 15,
							step = 1,
							get = function() return sRaidFrames.opt.DBMWarningDuration or 6 end,
							set = function(info, value) sRaidFrames.opt.DBMWarningDuration = value end,
							disabled = function() return not sRaidFrames.opt.ShowBossDebuffs end,
							order = 2,
						},
						test = {
							type = "execute",
							name = L["Test Boss/DBM warning"],
							desc = L["Trigger a test Boss/DBM skill warning on visible raid frames"],
							func = function()
								local testName = GetSpellInfo(20475) or L["Boss Debuff"] -- Living Bomb
								local _, _, testIcon = GetSpellInfo(20475)
								for unit in pairs(sRaidFrames:GetAllUnits()) do
									sRaidFrames:TriggerUnitBossWarning(unit, testName, testIcon or "Interface\\Icons\\Spell_Fire_SelfDestruct", sRaidFrames.opt.DBMWarningDuration or 6, 20475)
								end
							end,
							disabled = function() return not sRaidFrames.opt.ShowBossDebuffs end,
							order = 2.5,
						},
						custom = {
							type = "group",
							name = L["Custom Boss skills"],
							desc = L["Add custom Boss debuff names or spell IDs to always trigger Boss warnings"],
							dialogInline = true,
							disabled = function() return not sRaidFrames.opt.ShowBossDebuffs end,
							order = 3,
							args = {
								add = {
									name = L["Add Boss skill"],
									type = "input",
									desc = L["Add a Boss debuff name or spell ID"],
									get = false,
									set = function(info, value)
										if not value or value == "" then return end
										local num = tonumber(value)
										if num then
											local spName = GetSpellInfo(num)
											if spName then
												sRaidFrames.opt.BossWhitelist[spName] = true
											else
												sRaidFrames.opt.BossWhitelist[num] = true
											end
										else
											sRaidFrames.opt.BossWhitelist[value] = true
										end
										sRaidFrames:UpdateAllUnits()
									end,
									usage = L["<name or spell ID>"],
									order = 1,
								},
								remove = {
									type = "select",
									name = L["Remove Boss skill"],
									desc = L["Remove a custom Boss skill from the list"],
									order = 2,
									values = function()
										local t = {}
										for k in pairs(sRaidFrames.opt.BossWhitelist) do
											t[k] = tostring(k)
										end
										return t
									end,
									get = false,
									set = function(info, value)
										sRaidFrames.opt.BossWhitelist[value] = nil
										sRaidFrames:UpdateAllUnits()
									end,
								},
							},
						},
					},
				},

				bufftype = {
					name = L["Buff/Debuff visibility"],
					type = "select",
					desc = L["Show buffs or debuffs on the raid frames"],
					get = function()
						return sRaidFrames.opt.BuffType
					end,
					set = function(info, value)
						sRaidFrames.opt.BuffType = value
						sRaidFrames:RefreshAllNativeAuraContainers()
					end,
					values = function()
						local v = {
							["none"] = L["Hide all"],
							["buffs"] = L["Only buffs"],
							["debuffs"] = L["Only debuffs"],
							["both"] = L["Both buffs and debuffs"],
						}
						if not UsesNativeAuraContainers() or (sRaidFrames and sRaidFrames.opt and sRaidFrames.opt.BuffType == "buffsifnotdebuffed") then
							v["buffsifnotdebuffed"] = L["Buffs if not debuffed"]
						end
						return v
					end,
					order = 500,
				},
			},
		},
		advanced = {
			name = L["Statuses"],
			type = "group",
			hidden = true,
			desc = L["Configure statuses"],
			args = {
				reset = {
					name = L["|cffff0000Delete all statuses|r"],
					desc = L["Resets all status maps, requires a RELOAD UI to initate the default maps"],
					type = "execute",
					func = function()
						for key in pairs(sRaidFrames.opt.StatusMaps) do
							sRaidFrames.options.args.advanced.args[key] = nil
							sRaidFrames.opt.StatusMaps[key] = nil
						end
						sRaidFramesDB.CustomStatuses = {}
					end,
					confirm = true,
					order = 500,
				},
				add = {
					name = L["|cff00ff00Add a status|r"],
					desc = L["Adds a custom buff/debuff status"],
					type = "input",
					usage = "<id>",
					set = function(info, value) sRaidFrames:AddExternalStatusMap(value) end,
					get = function() return "" end,
					order = 300,
				},
				delete = {
					name = L["|cff00ff00Remove a custom status|r"],
					desc = L["Removes a custom status"],
					type = "select",
					get = false,
					set = function(info, value) sRaidFrames:RemoveExternalStatusMap(value) end,
					arg = "RemoveCustomStatus",
					values = function()
						local a = {}
						if not sRaidFramesDB.CustomStatuses then sRaidFramesDB.CustomStatuses = {} end
						for id in pairs(sRaidFramesDB.CustomStatuses) do
							a[id] = GetSpellInfo(id) or tostring(id)
						end
						return a
					end,
					order = 400,
				},
				classfilter = {
					name = L["Class filtering"],
					type = "group",
					desc = L["Filter statuses by class"],
					dialogInline = true,
					args = {
						selectbuff = {
							name = L["Select Buff"],
							desc = L["Select a buff you want to change classes for"],
							type = "select",
							get = function() return sRaidFrames.currbuff or false end,
							set = function(info, value) sRaidFrames.currbuff = tonumber(value) end,
							values = function()
								local ret = {}
								for i in pairs(sRaidFrames.opt.StatusMaps) do
									if string.match(i, "Buff_%d+") then
										local id = tonumber((string.match(i, "%d+")))
										local spName = GetSpellInfo(id)
										if spName then ret[id] = spName end
									end
								end
								return ret
							end,
							order = 1,
						},
						selectclass = {
							name = L["Select Classes"],
							desc = L["Select the classes that this status is available for"],
							type = "multiselect",
							get = function(info, key)
								if sRaidFrames.opt.classspelltable[sRaidFrames.currbuff][key] then return true else return false end
							end,
							set = function(info, key, value)
								sRaidFrames.opt.classspelltable[sRaidFrames.currbuff][key] = value
								sRaidFrames:UpdateAllUnits()
							end,
							values = LOCALIZED_CLASS_NAMES_MALE,
							disabled = function() return not sRaidFrames.currbuff and true or sRaidFrames.opt.classspelltable[sRaidFrames.currbuff]["IsFiltered"] and false or true end,
							hidden = function() return sRaidFrames.currbuff and false or true end,
							order = 2,
						},
						selectclassall = {
							name = L["All"],
							desc = L["Enable this buff for all classes"],
							type = "toggle",
							get = function()
								if sRaidFrames.opt.classspelltable[sRaidFrames.currbuff]["IsFiltered"] then return false else return true end
							end,
							set = function(info, value)
								sRaidFrames.opt.classspelltable[sRaidFrames.currbuff]["IsFiltered"] = not value
								sRaidFrames:UpdateAllUnits()
							end,
							hidden = function() if sRaidFrames.currbuff then return false else return true end end,
							order = 3,
						},
					},
					order = 600,
				},
			},
			order = 601,
		},
	},
}

function sRaidFrames:chatUpdateStatusElements()
	for key, data in pairs(self.opt.StatusMaps) do
		local name = L[key] or data.text or key
		if key:find("^Buff_") then
			local id = tonumber(key:match("^Buff_(%d+)"))
			name = (id and GetSpellInfo(id)) or data.text or key
		end
		if not name then
			self.opt.StatusMaps[key] = nil
		elseif not self.options.args.advanced.args[key] then
			self.options.args.advanced.args[key] = {
				type = 'group',
				name = name,
				desc = L["Change settings for the status %s"]:format(name),
				args = {
					priority = {
						name = L["Priority"],
						desc = L["Set the priority"],
						type = "range",
						min = 1,
						max = 200,
						step = 1,
						set = function(info, value) self.opt.StatusMaps[key].priority = value end,
						get = function() return self.opt.StatusMaps[key].priority end,
					},
					enabled = {
						name = L["Enabled"],
						desc = L["Enable the status indicator"],
						type = "toggle",
						set = function(info, value) self.opt.StatusMaps[key].enabled = value end,
						get = function() return self.opt.StatusMaps[key].enabled ~= false end,
					},
					elements = {
						name = L["GUI Elements"],
						desc = L["Set which elements this status will use"],
						type = "multiselect",
						values = sRaidFrames.validateStatusElements,
						set = function(info, element, value) self.opt.StatusMaps[key].elements[element] = value end,
						get = function(info, element) return self.opt.StatusMaps[key].elements[element] end,
					},
					color = {
						name = L["Color"],
						desc = L["Set which color this status will use"],
						type = "color",
						set = function(info, r, g, b, a)
							self.opt.StatusMaps[key].color = {r = r, g = g, b = b, a = a}
						end,
						get = function()
							local color = self.opt.StatusMaps[key].color
							return color.r, color.g, color.b, color.a
						end,
						hasAlpha = sRaidFrames.opt.advanced,
					},
					text = {
						name = L["Text"],
						desc = L["Set which text this status will show"],
						type = "input",
						usage = "<name>",
						set = function(info, value) self.opt.StatusMaps[key].text = value end,
						get = function() return self.opt.StatusMaps[key].text end,
					},
					options = {
						name = L["Options"],
						type = "group",
						order = 200,
						dialogInline = true,
						args = {
							playerOnly = {
								name = L["Player only"],
								desc = L["Only show this status if it was cast by yourself.\nOnly valid for buff statuses."],
								type = "toggle",
								get = function()
									return self.opt.StatusMaps[key].options.playerOnly
								end,
								set = function(info, value)
									self.opt.StatusMaps[key].options.playerOnly = value
								end,
							}
						},
					},
				},
				order = 200 - self.opt.StatusMaps[key].priority,
			}
		end
	end
end

function sRaidFrames:chatUpdateBuffMenu()
	local filter = {}
	for k in pairs(self.opt.BuffFilter) do
		filter[k] = k
	end
	self.options.args.buffsdebuffs.args.buffs.args.filter.args.remove.values = filter
end

function sRaidFrames:chatUpdateDebuffMenu()
	local filter = {}
	for k in pairs(self.opt.DebuffWhitelist) do
		filter[k] = k
	end
	self.options.args.buffsdebuffs.args.debuffs.args.whitelist.args.remove.values = filter

	local bfilter = {}
	for k in pairs(self.opt.DebuffFilter) do
		bfilter[k] = k
	end
	self.options.args.buffsdebuffs.args.debuffs.args.blacklist.args.remove.values = bfilter
end

function sRaidFrames:UpdateRangeLimitOptions()
	local rangeOpt = self.options.args.utility and self.options.args.utility.args.range and self.options.args.utility.args.range.args.limit
	if not rangeOpt then return end
	rangeOpt.values = {}
	for r, _ in pairs(self.RangeChecks) do
		rangeOpt.values[tostring(r)] = L["%d yards"]:format(r)
	end
end
