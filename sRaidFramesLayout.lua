--[[
	sRaidFrames Layout Engine (WoW: Forever Edition)
	Original Authors: Saroz, Nevcairiel, Stolenlegacy
	WoW: Forever Port & Modernization: Elunia-Moonshadow
	License: GNU General Public License v2.0 (GPLv2) — see LICENSE.txt
]]
local L = LibStub("AceLocale-3.0"):GetLocale("sRaidFrames")
local Media = LibStub("LibSharedMedia-3.0")
local sRaidFrames = sRaidFrames

sRaidFrames.Layouts = {}

function sRaidFrames:RegisterLayout(name, data)
	self.Layouts[name] = data
	
	local layoutOpt = self.options.args.layoutgroup and self.options.args.layoutgroup.args.layout
	if layoutOpt then
		layoutOpt.values = {}
		for _name, _data in pairs(self.Layouts) do
			layoutOpt.values[_name] = _data.Name
		end
	end
end

function sRaidFrames:SetLayout(name)
	if not self.Layouts[name] then
		name = "CTRA_WithBorders"
	end
	self.opt.Layout = name
	self.CurrentLayout = self.Layouts[name]
end

function sRaidFrames:ApplyLayout()
	local layout = self:GetLayout()
	local inParty = not (sRaidFrames.IsEffectiveInRaid and sRaidFrames:IsEffectiveInRaid() or IsInRaid())
	local w = self.opt.FrameWidth or layout.unitframeWidth
	local hpH = self.opt.HealthBarHeight or 12
	local mpH = self.opt.PowerBarHeight or 4
	local fontH = max(14, (self.opt.FontSize or 10) + 6)
	if inParty then
		w = math.max(135, math.floor(w * 1.45 + 0.5))
		hpH = hpH + 4
		mpH = mpH + 2
		fontH = math.max(fontH + 2, (self.opt.FontSize or 10) + 8)
	end
	local pad = (layout.padY ~= nil) and (layout.padY * 2) or (layout.HasBorders and 8 or 0)
	local h = fontH + hpH + mpH + pad
	local showPortrait = self.ShouldShowPortrait and self:ShouldShowPortrait()
	local portraitSize = showPortrait and math.max(24, math.min(48, h - pad)) or 0
	local frameW = w + (showPortrait and (portraitSize + 6) or 0)
	layout.unitframeWidth = frameW
	layout.unitframeHeight = h
	layout.headerWidth = frameW

	if not InCombatLockdown() then
		for _, f in pairs(self.groupframes) do
			f.header:SetAttribute("style-width", frameW)
			f.header:SetAttribute("style-height", h)
			f:SetWidth(frameW)
			if f.anchor then f.anchor:SetWidth(frameW) end
		end
		if self.petGroup and self.petGroup.header then
			self.petGroup.header:SetAttribute("style-width", frameW)
			self.petGroup.header:SetAttribute("style-height", h)
			self.petGroup:SetWidth(frameW)
			if self.petGroup.anchor then self.petGroup.anchor:SetWidth(frameW) end
		end
	else
		self:ScheduleLeaveCombatAction("ApplyLayout")
	end
	for _, f in pairs(self.frames) do
		layout.StyleUnitFrame(f)
	end
	if self.testFrames then
		for _, f in pairs(self.testFrames) do
			layout.StyleUnitFrame(f)
		end
	end
	if self.testPetFrames then
		for _, f in pairs(self.testPetFrames) do
			layout.StyleUnitFrame(f)
		end
	end
	if self.SyncAttachedPetWatches then
		self:SyncAttachedPetWatches()
	end
	for unit in pairs(self:GetAllUnits()) do
		self:UpdateStatuses(unit)
	end
	self:SetSpacing()
end

function sRaidFrames:GetLayout()
	if not self.CurrentLayout then
		self:SetLayout(self.opt.Layout)
	end
	return self.CurrentLayout
end

local function ApplyCommonUnitStyle(f, padX, padY)
	if sRaidFramesCompat and sRaidFramesCompat.AttachSafeUnitBackdrop then
		sRaidFramesCompat.AttachSafeUnitBackdrop(f)
	end
	local opt = sRaidFrames.opt
	local inParty = not (sRaidFrames.IsEffectiveInRaid and sRaidFrames:IsEffectiveInRaid() or IsInRaid())
	local w = opt.FrameWidth or 90
	local hpH = opt.HealthBarHeight or 12
	local mpH = opt.PowerBarHeight or 4
	local fontSize = opt.FontSize or 10
	local titleH = math.max(14, fontSize + 6)
	if inParty then
		w = math.max(135, math.floor(w * 1.45 + 0.5))
		hpH = hpH + 4
		mpH = mpH + 2
		titleH = math.max(titleH + 2, fontSize + 8)
	end
	local iconSize = (opt.AuraIconSize or 13) + (inParty and 2 or 0)
	local debuffSize = iconSize + 2
	local buffSize = math.max(9, iconSize - 2)
	local barW = w - (padX * 2)
	local totalH = titleH + hpH + mpH + (padY * 2)
	local showPortrait = sRaidFrames.ShouldShowPortrait and sRaidFrames:ShouldShowPortrait()
	local portraitSize = showPortrait and math.max(24, math.min(48, totalH - (padY * 2))) or 0
	local leftOffset = padX + (showPortrait and (portraitSize + 6) or 0)
	local frameW = w + (showPortrait and (portraitSize + 6) or 0)

	local fontPath = (GameFontNormalSmall and GameFontNormalSmall:GetFont()) or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
	local partyFontPath = (GameFontNormal and GameFontNormal:GetFont()) or STANDARD_TEXT_FONT or fontPath
	if inParty then
		f.title:SetFont(partyFontPath, fontSize + 2, "")
		f.title:SetShadowColor(0, 0, 0, 0.9)
		f.title:SetShadowOffset(1, -1)
	else
		f.title:SetFont(fontPath, fontSize, "")
		f.title:SetShadowColor(0, 0, 0, 0.7)
		f.title:SetShadowOffset(1, -1)
	end
	f.hpbar.text:SetFont(fontPath, math.max(8, fontSize - 1), "OUTLINE")
	f.statustext:SetFont(fontPath, math.max(8, fontSize - 2), "OUTLINE")

	sRaidFrames:SetWHP(f, frameW, totalH)
	sRaidFrames:SetWHP(f.title, barW, titleH, "TOPLEFT", f, "TOPLEFT", leftOffset, -padY)
	if f.portraitFrame then
		if showPortrait then
			f.portraitFrame:SetSize(portraitSize, portraitSize)
			f.portraitFrame:ClearAllPoints()
			f.portraitFrame:SetPoint("LEFT", f, "LEFT", padX, 0)
			if f.portraitBorder then
				local ringSize = math.floor(portraitSize * 1.38 + 0.5)
				f.portraitBorder:SetSize(ringSize, ringSize)
			end
			f.portraitFrame:Show()
		else
			f.portraitFrame:Hide()
		end
	end
	-- Buffs on the RIGHT (TOPRIGHT), Debuffs to the LEFT of Buffs
	if f.isPetGroupFrame then
		local petIconSz = 9
		sRaidFrames:SetWHP(f.buff1, petIconSz, petIconSz, "TOPRIGHT", f.hpbar, "TOPRIGHT", -1, -1)
		sRaidFrames:SetWHP(f.buff2, petIconSz, petIconSz, "RIGHT", f.buff1, "LEFT", -1, 0)
		sRaidFrames:SetWHP(f.buff3, petIconSz, petIconSz, "RIGHT", f.buff2, "LEFT", -1, 0)
		sRaidFrames:SetWHP(f.buff4, petIconSz, petIconSz, "RIGHT", f.buff3, "LEFT", -1, 0)
		if f.buff5 then
			sRaidFrames:SetWHP(f.buff5, petIconSz, petIconSz, "RIGHT", f.buff4, "LEFT", -1, 0)
		end
		sRaidFrames:SetWHP(f.aura1, petIconSz, petIconSz, "TOPRIGHT", f.buff1, "TOPLEFT", -1, 0)
		sRaidFrames:SetWHP(f.aura2, petIconSz, petIconSz, "RIGHT", f.aura1, "LEFT", -1, 0)
		for i = 1, 5 do
			local b = f["buff"..i]
			if b and f.hpbar then b:SetFrameLevel(f.hpbar:GetFrameLevel() + 5) end
		end
		for i = 1, 2 do
			local a = f["aura"..i]
			if a and f.hpbar then a:SetFrameLevel(f.hpbar:GetFrameLevel() + 5) end
		end
	else
		sRaidFrames:SetWHP(f.buff1, buffSize, buffSize, "TOPRIGHT", f, "TOPRIGHT", -padX, -padY)
		sRaidFrames:SetWHP(f.buff2, buffSize, buffSize, "RIGHT", f.buff1, "LEFT", -1, 0)
		sRaidFrames:SetWHP(f.buff3, buffSize, buffSize, "RIGHT", f.buff2, "LEFT", -1, 0)
		sRaidFrames:SetWHP(f.buff4, buffSize, buffSize, "RIGHT", f.buff3, "LEFT", -1, 0)
		if f.buff5 then
			sRaidFrames:SetWHP(f.buff5, buffSize, buffSize, "RIGHT", f.buff4, "LEFT", -1, 0)
		end
		sRaidFrames:SetWHP(f.aura1, debuffSize, debuffSize, "TOPRIGHT", f.buff1, "TOPLEFT", -1, 0)
		sRaidFrames:SetWHP(f.aura2, debuffSize, debuffSize, "RIGHT", f.aura1, "LEFT", -1, 0)
	end
	local showClassIcon = opt.ShowClassIcon and true or false
	local clsSize = showClassIcon and math.max(10, math.min(20, hpH)) or 0
	local levelW = inParty and math.max(26, math.floor(math.max(8, mpH + 2) * 2.8)) or 0
	local rightColW = math.max(clsSize, levelW)
	local rightReserve = (rightColW > 0) and (rightColW + 3) or 0
	local hpBarW = math.max(24, barW - rightReserve)

	sRaidFrames:SetWHP(f.hpbar, hpBarW, hpH, "TOPLEFT", f.title, "BOTTOMLEFT", 0, 0)
	if f.healbar then
		f.healbar:SetWidth(hpBarW)
		f.healbar:SetHeight(hpH)
		if sRaidFrames.SyncHealPredictionOrientation then
			sRaidFrames:SyncHealPredictionOrientation(f)
		end
	end
	if f.absorbbar then
		f.absorbbar:SetWidth(hpBarW)
		f.absorbbar:SetHeight(math.min(3, hpH))
	end
	sRaidFrames:SetWHP(f.mpbar, hpBarW, mpH, "TOPLEFT", f.hpbar, "BOTTOMLEFT", 0, 0)

	sRaidFrames:SetWHP(f.hpbar.text, hpBarW, hpH, "CENTER", f.hpbar, "CENTER", 0, 0)
	sRaidFrames:SetWHP(f.statustext, hpBarW, math.max(mpH, math.max(8, fontSize - 2) + 2), "CENTER", f.mpbar, "CENTER", 0, 0)
	if f.classIcon then
		local cSize = math.max(10, math.min(20, hpH))
		f.classIcon:SetSize(cSize, cSize)
		f.classIcon:ClearAllPoints()
		local iconOffsetX = 3 + math.floor((rightColW - cSize) / 2)
		f.classIcon:SetPoint("LEFT", f.hpbar, "RIGHT", iconOffsetX, 0)
	end
	if f.levelText then
		local lvlFontSize = math.max(7, math.min(11, mpH + 2))
		f.levelText:SetFont(fontPath, lvlFontSize, "OUTLINE")
		f.levelText:SetWidth(rightColW)
		f.levelText:SetHeight(math.max(mpH, lvlFontSize + 2))
		f.levelText:SetJustifyH("CENTER")
		f.levelText:ClearAllPoints()
		f.levelText:SetPoint("LEFT", f.mpbar, "RIGHT", 3, 0)
		if not inParty then
			f.levelText:Hide()
		end
	end
	if f.tankIcon then
		local tankSize = showPortrait and math.max(12, math.min(18, math.floor(portraitSize * 0.36))) or math.max(9, math.min(18, hpH - 1))
		f.tankIcon:SetSize(tankSize, tankSize)
		f.tankIcon:ClearAllPoints()
		if showPortrait and f.portraitFrame then
			f.tankIcon:SetPoint("BOTTOMRIGHT", f.portraitFrame, "BOTTOMRIGHT", 2, -2)
		else
			f.tankIcon:SetPoint("TOPLEFT", f.hpbar, "TOPLEFT", 1, 0)
		end
	end
	if f.leaderIcon then
		local leadSize = showPortrait and math.max(12, math.min(18, math.floor(portraitSize * 0.36))) or math.max(9, math.min(18, hpH - 1))
		f.leaderIcon:SetSize(leadSize, leadSize)
		f.leaderIcon:ClearAllPoints()
		if showPortrait and f.portraitFrame then
			f.leaderIcon:SetPoint("TOPLEFT", f.portraitFrame, "TOPLEFT", -2, 2)
		elseif f.tankIcon and f.tankIcon:IsShown() then
			f.leaderIcon:SetPoint("TOPLEFT", f.tankIcon, "TOPRIGHT", 1, 0)
		else
			f.leaderIcon:SetPoint("TOPLEFT", f.hpbar, "TOPLEFT", 1, 0)
		end
	end
	if f.voiceIcon then
		local voiceSize = showPortrait and math.max(12, math.min(16, math.floor(portraitSize * 0.34))) or math.max(10, math.min(14, hpH - 1))
		f.voiceIcon:SetSize(voiceSize, voiceSize)
		f.voiceIcon:ClearAllPoints()
		if showPortrait and f.portraitFrame then
			f.voiceIcon:SetPoint("BOTTOMLEFT", f.portraitFrame, "BOTTOMLEFT", -2, -2)
		else
			f.voiceIcon:SetPoint("BOTTOMLEFT", f.hpbar, "BOTTOMLEFT", 1, 0)
		end
	end
	if f.dbmAlertIcon then
		local dbmSize = math.max(12, math.min(hpH + 2, debuffSize))
		f.dbmAlertIcon:SetSize(dbmSize, dbmSize)
	end
	if f.raidMarker then
		f.raidMarker:ClearAllPoints()
		if not showPortrait then
			local leftShift = 1 + ((f.tankIcon and f.tankIcon:IsShown()) and 12 or 0) + ((f.leaderIcon and f.leaderIcon:IsShown()) and 12 or 0)
			f.raidMarker:SetPoint("LEFT", f.hpbar, "LEFT", leftShift, 0)
		else
			f.raidMarker:SetPoint("LEFT", f.hpbar, "LEFT", 1, 0)
		end
	end

	-- Style Attached Pet Bar (Party: right-aligned <=50% sub-bar below owner; Raid: short thin bar inside bottom-right power row)
	if f.petframe then
		local pf = f.petframe
		local inCombat = InCombatLockdown and InCombatLockdown()
		if not inParty then
			-- Raid attached mode: short thin pet bar tucked inside bottom-right of power bar row
			local raidPetW = math.max(24, math.floor(barW * 0.36 + 0.5))
			local raidPetH = math.max(6, mpH + 2)
			if not inCombat then
				pf:SetSize(raidPetW, raidPetH)
				pf:ClearAllPoints()
				pf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -padX, padY)
			end
			local targetLvl = f.mpbar:GetFrameLevel() + 6
			if pf.SetSafeFrameLevel then
				pf:SetSafeFrameLevel(targetLvl)
			elseif not inCombat then
				pf:SetFrameLevel(targetLvl)
			end
			if pf.hpbar then pf.hpbar:SetFrameLevel(targetLvl + 2) end
			if pf.healbar then pf.healbar:SetFrameLevel(targetLvl + 2) end
			if pf.targetHighlight then pf.targetHighlight:SetFrameLevel(targetLvl + 6) end
			if pf.SetBackdrop then
				pf:SetBackdrop({
					bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
					tile = true,
					tileSize = 16,
					edgeFile = "Interface\\Buttons\\WHITE8X8",
					edgeSize = 1,
					insets = { left = 1, right = 1, top = 1, bottom = 1 },
				})
				pf:SetBackdropColor(0.06, 0.08, 0.12, 0.95)
				pf:SetBackdropBorderColor(0.90, 0.82, 0.54, 0.95)
			end
			if pf.portraitFrame then pf.portraitFrame:Hide() end
			if pf.hpbar then
				local innerW = math.max(10, raidPetW - 2)
				local innerH = math.max(4, raidPetH - 2)
				pf.hpbar:ClearAllPoints()
				pf.hpbar:SetPoint("TOPLEFT", pf, "TOPLEFT", 1, -1)
				pf.hpbar:SetSize(innerW, innerH)
				if pf.healbar then
					pf.healbar:SetSize(innerW, innerH)
				end
				if pf.hpbar.text then
					pf.hpbar.text:Hide()
				end
			end
			if pf.buffs then
				for i = 1, #pf.buffs do pf.buffs[i]:Hide() end
			end
		else
			-- 5-player Party attached mode: compact right-aligned pet sub-bar directly underneath owner (<= 50% width)
			local petW = math.max(84, math.floor(frameW * 0.48 + 0.5))
			local petH = 22
			if not inCombat then
				pf:SetSize(petW, petH)
				pf:ClearAllPoints()
				pf:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, -2)
			end
			local targetLvl = f:GetFrameLevel() + 2
			if pf.SetSafeFrameLevel then
				pf:SetSafeFrameLevel(targetLvl)
			elseif not inCombat then
				pf:SetFrameLevel(targetLvl)
			end
			if pf.hpbar then pf.hpbar:SetFrameLevel(targetLvl + 2) end
			if pf.healbar then pf.healbar:SetFrameLevel(targetLvl + 2) end
			if pf.portraitFrame then pf.portraitFrame:SetFrameLevel(targetLvl + 3) end
			if pf.nativeBuffBox then pcall(pf.nativeBuffBox.SetFrameLevel, pf.nativeBuffBox, targetLvl + 6) end
			if pf.targetHighlight then pf.targetHighlight:SetFrameLevel(targetLvl + 8) end
			if pf.SetBackdrop then
				pf:SetBackdrop({
					bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
					tile = true,
					tileSize = 16,
					edgeFile = "Interface\\Buttons\\WHITE8X8",
					edgeSize = 1,
					insets = { left = 1, right = 1, top = 1, bottom = 1 },
				})
				pf:SetBackdropColor(opt.BackgroundColor.r * 0.72, opt.BackgroundColor.g * 0.72, opt.BackgroundColor.b * 0.72, math.min(0.95, opt.BackgroundColor.a))
				pf:SetBackdropBorderColor(opt.BorderColor.r * 0.78, opt.BorderColor.g * 0.78, opt.BorderColor.b * 0.78, 0.95)
			end
			local pPortSz = 16
			if pf.portraitFrame then
				pf.portraitFrame:SetSize(pPortSz, pPortSz)
				pf.portraitFrame:ClearAllPoints()
				pf.portraitFrame:SetPoint("LEFT", pf, "LEFT", 3, 0)
				if pf.portraitBorder then
					pf.portraitBorder:SetSize(22, 22)
				end
				pf.portraitFrame:Show()
			end
			if pf.hpbar then
				local barInnerW = math.max(36, petW - pPortSz - 9)
				local barInnerH = petH - 6
				pf.hpbar:ClearAllPoints()
				pf.hpbar:SetPoint("LEFT", pf, "LEFT", 3 + pPortSz + 3, 0)
				pf.hpbar:SetSize(barInnerW, barInnerH)
				if pf.healbar then
					pf.healbar:SetSize(barInnerW, barInnerH)
				end
				if pf.hpbar.text then
					pf.hpbar.text:SetFont(fontPath, math.max(8, fontSize - 2), "OUTLINE")
					pf.hpbar.text:ClearAllPoints()
					pf.hpbar.text:SetPoint("LEFT", pf.hpbar, "LEFT", 3, 0)
					pf.hpbar.text:SetSize(math.max(20, barInnerW - 6), barInnerH)
					pf.hpbar.text:Show()
				end
			end
			if pf.buffs and pf.hpbar then
				for i = 1, #pf.buffs do
					pf.buffs[i]:SetSize(9, 9)
					pf.buffs[i]:ClearAllPoints()
					if i == 1 then
						pf.buffs[i]:SetPoint("TOPRIGHT", pf.hpbar, "TOPRIGHT", -1, -1)
					else
						pf.buffs[i]:SetPoint("RIGHT", pf.buffs[i - 1], "LEFT", -1, 0)
					end
				end
			end
		end
	end
end

sRaidFrames:RegisterLayout("CTRA_WithBorders", {
	Name = L["CT_RaidAssist"],
	HasBorders = true,
	padX = 5,
	padY = 4,
	StyleUnitFrame = function(f)
		ApplyCommonUnitStyle(f, 5, 4)
		f:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
									tile = true,
									tileSize = 16,
									edgeFile = Media:Fetch("border", sRaidFrames.opt.BorderTexture),
									edgeSize = 16,
									insets = { left = 5, right = 5, top = 5, bottom = 5 }
								})
								
		f:SetBackdropColor(sRaidFrames.opt.BackgroundColor.r, sRaidFrames.opt.BackgroundColor.g, sRaidFrames.opt.BackgroundColor.b, sRaidFrames.opt.BackgroundColor.a)
		f:SetBackdropBorderColor(sRaidFrames.opt.BorderColor.r, sRaidFrames.opt.BorderColor.g, sRaidFrames.opt.BorderColor.b, sRaidFrames.opt.BorderColor.a)
		f.hpbar.text:SetTextColor(sRaidFrames.opt.HealthTextColor.r, sRaidFrames.opt.HealthTextColor.g, sRaidFrames.opt.HealthTextColor.b, sRaidFrames.opt.HealthTextColor.a)
		if sRaidFrames.StyleNativeAuraContainers then
			sRaidFrames:StyleNativeAuraContainers(f, -4, -4)
		end
	end,
	unitframeWidth = 90,
	unitframeHeight = 40,
	headerWidth = 90,
	headerHeight = 15,
	debuffCount = 2,
	buffCount = 5,
})

sRaidFrames:RegisterLayout("CTRA_NoBorders", {
	Name = L["CT_RaidAssist (Without Borders)"],
	HasBorders = false,
	padX = 0,
	padY = 0,
	StyleUnitFrame = function(f)
		ApplyCommonUnitStyle(f, 0, 0)
		f:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
										tile = true, tileSize = 16,
										insets = { left = 0, right = 0, top = 0, bottom = 0 }
									})
		
		f:SetBackdropColor(sRaidFrames.opt.BackgroundColor.r, sRaidFrames.opt.BackgroundColor.g, sRaidFrames.opt.BackgroundColor.b, sRaidFrames.opt.BackgroundColor.a)
		f.hpbar.text:SetTextColor(sRaidFrames.opt.HealthTextColor.r, sRaidFrames.opt.HealthTextColor.g, sRaidFrames.opt.HealthTextColor.b, sRaidFrames.opt.HealthTextColor.a)
		if sRaidFrames.StyleNativeAuraContainers then
			sRaidFrames:StyleNativeAuraContainers(f, 0, 0)
		end
	end,
	unitframeWidth = 80,
	unitframeHeight = 32,
	headerWidth = 80,
	headerHeight = 15,
	debuffCount = 2,
	buffCount = 5,
})

sRaidFrames:RegisterLayout("CTRA_NoBordersWide", {
	Name = L["CT_RaidAssist (Without borders, Wide)"],
	HasBorders = false,
	padX = 5,
	padY = 4,
	StyleUnitFrame = function(f)
		ApplyCommonUnitStyle(f, 5, 4)
		f:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
										tile = true, tileSize = 16,
										insets = { left = 0, right = 0, top = 0, bottom = 0 }
									})
								
		f:SetBackdropColor(sRaidFrames.opt.BackgroundColor.r, sRaidFrames.opt.BackgroundColor.g, sRaidFrames.opt.BackgroundColor.b, sRaidFrames.opt.BackgroundColor.a)
		f.hpbar.text:SetTextColor(sRaidFrames.opt.HealthTextColor.r, sRaidFrames.opt.HealthTextColor.g, sRaidFrames.opt.HealthTextColor.b, sRaidFrames.opt.HealthTextColor.a)
		if sRaidFrames.StyleNativeAuraContainers then
			sRaidFrames:StyleNativeAuraContainers(f, -4, -4)
		end
	end,
	unitframeWidth = 90,
	unitframeHeight = 40,
	headerWidth = 90,
	headerHeight = 15,
	debuffCount = 2,
	buffCount = 5,
})

--[[
sRaidFrames:RegisterLayout("sRaidFrames", {
	Name = "sRaidFrames",
	HasBorders = true,
	StyleUnitFrame = function(f)
		sRaidFrames:SetWHP(f, 80, 30)
		sRaidFrames:SetWHP(f.title, 78, 13, "TOPLEFT", f, "TOPLEFT",  1, 0)
		sRaidFrames:SetWHP(f.aura1, 13, 13, "TOPRIGHT", f, "TOPRIGHT", -1, -1)
		sRaidFrames:SetWHP(f.aura2, 13, 13, "RIGHT", f.aura1, "LEFT", 0, 0)
		sRaidFrames:SetWHP(f.buff1, 13, 13, "TOPRIGHT", f, "TOPRIGHT", -1, -1)
		sRaidFrames:SetWHP(f.buff2, 13, 13, "RIGHT", f.buff1, "LEFT", 0, 0)
		sRaidFrames:SetWHP(f.buff3, 13, 13, "RIGHT", f.buff2, "LEFT", 0, 0)
		sRaidFrames:SetWHP(f.hpbar, 78, 12, "TOPLEFT", f.title, "BOTTOMLEFT", 0, 0)
		sRaidFrames:SetWHP(f.mpbar, 78, 4, "TOPLEFT", f.hpbar, "BOTTOMLEFT", 0, 0)
	
		sRaidFrames:SetWHP(f.hpbar.text, f.hpbar:GetWidth(), f.hpbar:GetHeight(), "CENTER", f.hpbar, "CENTER", 0, 0)
		sRaidFrames:SetWHP(f.statustext, f.mpbar:GetWidth(), f.mpbar:GetHeight(), "CENTER", f.mpbar, "CENTER", 0, 0)
		
		
		f:SetBackdrop({ bgFile = "Interface\\Addons\\sRaidFrames\\textures\\solidborder",
									tile = true,
									tileSize = 16,
									edgeFile = "Interface\\Addons\\sRaidFrames\\textures\\solidborder",
									edgeSize = 1,
									insets = { left = 1, right = 1, top = 1, bottom = 1 }
								})
								
		f:SetBackdropColor(sRaidFrames.opt.BackgroundColor.r, sRaidFrames.opt.BackgroundColor.g, sRaidFrames.opt.BackgroundColor.b, sRaidFrames.opt.BackgroundColor.a)
		f:SetBackdropBorderColor(sRaidFrames.opt.BorderColor.r, sRaidFrames.opt.BorderColor.g, sRaidFrames.opt.BorderColor.b, sRaidFrames.opt.BorderColor.a)
		f.hpbar.text:SetTextColor(sRaidFrames.opt.HealthTextColor.r, sRaidFrames.opt.HealthTextColor.g, sRaidFrames.opt.HealthTextColor.b, sRaidFrames.opt.HealthTextColor.a)
		if sRaidFrames.StyleNativeAuraContainers then
			sRaidFrames:StyleNativeAuraContainers(f, -4, -4)
		end
	end,
	unitframeWidth = 80,
	unitframeHeight = 30,
	headerWidth = 85,
	headerHeight = 15,
	debuffCount = 2,
	buffCount = 3,
})



sRaidFrames:RegisterLayout("Grid", {
	Name = "Dispell Grid",
	HasBorders = false,
	StyleUnitFrame = function(f)
		sRaidFrames:SetWHP(f, 26, 26)
		sRaidFrames:SetWHP(f.title, 80, 16, "TOPLEFT", f, "TOPLEFT",  5, -4)
		
		sRaidFrames:SetWHP(f.aura1, 16, 16, "CENTER", f, "CENTER", 0, 0)
		
		sRaidFrames:SetWHP(f.buff1, 12, 12, "TOPRIGHT", f, "TOPRIGHT", -4, -4)
		sRaidFrames:SetWHP(f.buff2, 12, 12, "RIGHT", f.buff1, "LEFT", 0, 0)
		sRaidFrames:SetWHP(f.buff3, 12, 12, "RIGHT", f.buff2, "LEFT", 0, 0)
		sRaidFrames:SetWHP(f.buff4, 12, 12, "RIGHT", f.buff3, "LEFT", 0, 0)
		
		sRaidFrames:SetWHP(f.hpbar, 80, 12, "TOPLEFT", f, "TOPLEFT", 0, 0)
		sRaidFrames:SetWHP(f.mpbar, 80, 4, "TOPRIGHT", f, "TOPRIGHT", 0, 0)
		
		f.hpbar:Hide()
		f.mpbar:Hide()
	
		sRaidFrames:SetWHP(f.title, f:GetWidth()-4, f.hpbar:GetHeight(), "CENTER", f, "CENTER", 0, 0)
		
		f.title:SetJustifyH("CENTER")
		f.title:SetNonSpaceWrap(true)
		
		f:SetBackdropColor(sRaidFrames.opt.BackgroundColor.r, sRaidFrames.opt.BackgroundColor.g, sRaidFrames.opt.BackgroundColor.b, sRaidFrames.opt.BackgroundColor.a)
		f:SetBackdropBorderColor(sRaidFrames.opt.BorderColor.r, sRaidFrames.opt.BorderColor.g, sRaidFrames.opt.BorderColor.b, sRaidFrames.opt.BorderColor.a)
		f.hpbar.text:SetTextColor(sRaidFrames.opt.HealthTextColor.r, sRaidFrames.opt.HealthTextColor.g, sRaidFrames.opt.HealthTextColor.b, sRaidFrames.opt.HealthTextColor.a)
		
		f:SetBackdrop( {
				      bgFile = "Interface\\Addons\\sRaidFrames\\textures\\solidborder", tile = true, tileSize = 16,
				      edgeFile = "Interface\\Addons\\sRaidFrames\\textures\\solidborder", edgeSize = 1,
				      insets = {left = 1, right = 1, top = 1, bottom = 1},
			      })
	end,
	unitframeWidth = 26,
	unitframeHeight = 26,
	headerWidth = 26,
	headerHeight = 15,
	debuffCount = 1,
	buffCount = 4,
})
]]--