-- 🖱️ MythicClick: Teleports highlighted. Left click teleport. Right click LFG.

local addonName, ns = ...

ns.MythicClick = CreateFrame("Frame")
local MythicClick = ns.MythicClick
MythicClick.name = addonName

-- TODO: update this data when new dungeons are added or spellIDs change
-- [mapID] = { spellID, activityGroupID }
local DUNGEON_DATA = {
	[560] = { 1254559, 400 }, -- Maisara Caverns
	[559] = { 1254563, 401 }, -- Nexus-Point Xenas
	[558] = { 1254572, 399 }, -- Magisters' Terrace
	[557] = { 1254400, 370 }, -- Windrunner Spire
	[402] = { 393273, 302 }, -- Algeth'ar Academy
	[239] = { 1254551, 133 }, -- Seat of the Triumvirate
	[161] = { 1254557, 9 }, -- Skyreach
	[556] = { 1254555, 52 }, -- Pit of Saron
}

local BORDER_IDLE_ALPHA = 0.75
local BORDER_HOVER_ALPHA = 1.0
local CASTBAR_COLOR = { 0.2, 0.8, 1.0 }
local CASTBAR_TEXTURE_DEFAULT = "Interface\\TargetingFrame\\UI-StatusBar"
local CASTBAR_SPARK_TEXTURE = "Interface\\CastingBar\\UI-CastingBar-Spark"

function MythicClick:OpenLFG(mapID)
	local data = DUNGEON_DATA[mapID]
	if not data then return end
	local groupID = data[2]

	local filter = C_LFGList.GetAdvancedFilter()
	filter.activities = { groupID }
	filter.difficultyNormal = false
	filter.difficultyHeroic = false
	filter.difficultyMythic = false
	filter.difficultyMythicPlus = true
	C_LFGList.SaveAdvancedFilter(filter)

	if not PVEFrame then UIParentLoadAddOn("Blizzard_LFGUI") end
	PVEFrame_ShowFrame("GroupFinderFrame", "LFGListPVEStub")
	LFGListCategorySelection_SelectCategory(LFGListFrame.CategorySelection, 2, 0)

	local findBtn = LFGListFrame.CategorySelection and LFGListFrame.CategorySelection.FindGroupButton
	if findBtn and findBtn:IsEnabled() then
		findBtn:Click()
	end
end

-- Keep compatibility for secure macro execution.
function MythicClick_OpenLFG(mapID)
	MythicClick:OpenLFG(mapID)
end

function MythicClick:IsSpellKnown(spellID)
	if not spellID or spellID == 0 then return false end
	return C_SpellBook.IsSpellInSpellBook(spellID, Enum.SpellBookSpellBank.Player)
end

function MythicClick:InitButton(button)
	button:SetAllPoints()

	local parent = button:GetParent()
	if parent then
		button:SetFrameLevel(parent:GetFrameLevel() + 1)
	end

	button:RegisterForClicks("AnyDown", "AnyUp")

	local castBar = CreateFrame("StatusBar", nil, button)
	castBar:SetStatusBarTexture(CASTBAR_TEXTURE_DEFAULT)
	castBar:SetMinMaxValues(0, 1)
	castBar:SetValue(0)
	castBar:SetStatusBarColor(CASTBAR_COLOR[1], CASTBAR_COLOR[2], CASTBAR_COLOR[3])
	castBar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
	castBar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
	castBar:SetHeight(10)
	castBar:Hide()

	local castBarBg = castBar:CreateTexture(nil, "BACKGROUND")
	castBarBg:SetAllPoints()
	castBarBg:SetColorTexture(0, 0, 0, 0.65)

	local castBarSpellTex = castBar:CreateTexture(nil, "ARTWORK")
	castBarSpellTex:SetAllPoints()
	castBarSpellTex:SetAlpha(0.3)
	castBarSpellTex:Hide()

	local castBarSpark = castBar:CreateTexture(nil, "OVERLAY")
	castBarSpark:SetTexture(CASTBAR_SPARK_TEXTURE)
	castBarSpark:SetBlendMode("ADD")
	castBarSpark:SetSize(30, 30)
	castBarSpark:Hide()

	button.castBarSpellTex = castBarSpellTex
	button.castBarSpark = castBarSpark
	button.castBar = castBar

	local highlight = button:CreateTexture(nil, "OVERLAY")
	highlight:SetTexture("Interface\\EncounterJournal\\UI-EncounterJournalTextures")
	highlight:SetTexCoord(0.34570313, 0.68554688, 0.33300781, 0.42675781)
	highlight:SetAllPoints()
	highlight:SetAlpha(BORDER_IDLE_ALPHA)
	highlight:Hide()
	button.highlight = highlight

	button:SetScript("OnEnter", function(self)
		local p = self:GetParent()
		if p and p:GetScript("OnEnter") then
			p:GetScript("OnEnter")(p)
		end

		if self.spellID then
			self.highlight:SetAlpha(BORDER_HOVER_ALPHA)

			if GameTooltip:GetOwner() == p then
				GameTooltip:AddLine(" ")
				if self.hasSpell then
					GameTooltip:AddLine("Left Click: |cff80ff80Teleport|r")
				end
				GameTooltip:AddLine("Right Click: |cff80ff80LFG|r")
				GameTooltip:Show()
			end
		end
	end)

	button:SetScript("OnLeave", function(self)
		local p = self:GetParent()
		if p and p:GetScript("OnLeave") then
			p:GetScript("OnLeave")(p)
		end
		GameTooltip:Hide()
		if self.spellID then self.highlight:SetAlpha(BORDER_IDLE_ALPHA) end
	end)
end

function MythicClick:GetPlayerCastState()
	local _, _, _, startTimeMS, endTimeMS, _, _, _, spellID = UnitCastingInfo("player")
	local isChannel = false

	if not spellID then
		_, _, _, startTimeMS, endTimeMS, _, _, spellID = UnitChannelInfo("player")
		isChannel = spellID ~= nil
	end

	if not spellID or not startTimeMS or not endTimeMS then return nil end

	local nowMS = GetTime() * 1000
	local duration = math.max(endTimeMS - startTimeMS, 1)
	local progress

	if isChannel then
		progress = (endTimeMS - nowMS) / duration
	else
		progress = (nowMS - startTimeMS) / duration
	end

	progress = math.max(0, math.min(1, progress))

	return spellID, progress
end

function MythicClick:UpdateButtonCastBar(button)
	if not button or not button.castBar then return end

	if self.activeCastSpellID and self.castProgress and button.spellID == self.activeCastSpellID then
		button.castBar:SetValue(self.castProgress)

		if button.castBarSpark then
			button.castBarSpark:ClearAllPoints()
			button.castBarSpark:SetPoint("CENTER", button.castBar, "LEFT", button.castBar:GetWidth() * self.castProgress, 0)
			button.castBarSpark:Show()
		end

		button.castBar:Show()
	else
		if button.castBarSpark then
			button.castBarSpark:Hide()
		end
		button.castBar:Hide()
	end
end

function MythicClick:UpdateAllCastBars()
	if not ChallengesFrame or not ChallengesFrame.DungeonIcons then return end
	for _, icon in ipairs(ChallengesFrame.DungeonIcons) do
		local button = icon.__mythicClickButton
		if button then
			self:UpdateButtonCastBar(button)
		end
	end
end

function MythicClick:OnCastUpdate(elapsed)
	self.castUpdateElapsed = (self.castUpdateElapsed or 0) + elapsed
	if self.castUpdateElapsed < 0.05 then return end
	self.castUpdateElapsed = 0

	self:RefreshCastState()
end

function MythicClick:RefreshCastState()
	local spellID, progress = self:GetPlayerCastState()
	self.activeCastSpellID = spellID
	self.castProgress = progress

	if spellID then
		if not self.castingUpdateActive then
			self.castingUpdateActive = true
			self:SetScript("OnUpdate", function(frame, elapsed)
				frame:OnCastUpdate(elapsed)
			end)
		end
	elseif self.castingUpdateActive then
		self.castingUpdateActive = false
		self:SetScript("OnUpdate", nil)
	end

	self:UpdateAllCastBars()
end

function MythicClick:GetOrCreateButton(icon)
	if icon.__mythicClickButton then return icon.__mythicClickButton end
	local button = CreateFrame("Button", nil, icon, "InsecureActionButtonTemplate")
	self:InitButton(button)
	icon.__mythicClickButton = button
	return button
end

function MythicClick:ProcessIcon(icon)
	if InCombatLockdown() then return end

	local mapID = icon.mapID
	local data = mapID and DUNGEON_DATA[mapID] or nil
	local spellID = data and data[1] or nil
	local button = self:GetOrCreateButton(icon)
	button.mapID = mapID
	button.spellID = spellID
	if button.castBarSpellTex then
		if spellID then
			local spellTexture = C_Spell.GetSpellTexture(spellID)
			if spellTexture then
				button.castBarSpellTex:SetTexture(spellTexture)
				button.castBarSpellTex:Show()
			else
				button.castBarSpellTex:Hide()
			end
		else
			button.castBarSpellTex:Hide()
		end
	end
	local hasSpell = spellID and self:IsSpellKnown(spellID)
	button.hasSpell = hasSpell

	if hasSpell then
		local spellName = C_Spell.GetSpellName(spellID)
		button:SetAttribute("type1", "spell")
		button:SetAttribute("spell1", spellName)
		button.highlight:SetAlpha(BORDER_IDLE_ALPHA)
		button.highlight:Show()
	else
		button:SetAttribute("type1", nil)
		button.highlight:Hide()
	end

	if mapID then
		button:SetAttribute("type2", "macro")
		button:SetAttribute("macrotext2", string.format("/run MythicClick_OpenLFG(%d)", mapID))
	else
		button:SetAttribute("type2", nil)
		button:SetAttribute("macrotext2", nil)
	end

	self:UpdateButtonCastBar(button)
end

function MythicClick:OnChallengesFrameUpdate()
	if not ChallengesFrame or not ChallengesFrame.DungeonIcons then return end
	self:RefreshCastState()
	for _, icon in ipairs(ChallengesFrame.DungeonIcons) do
		self:ProcessIcon(icon)
	end
end

MythicClick:RegisterEvent("ADDON_LOADED")
MythicClick:RegisterEvent("SPELLS_CHANGED")
MythicClick:RegisterEvent("PLAYER_REGEN_ENABLED")
MythicClick:RegisterEvent("UNIT_SPELLCAST_START")
MythicClick:RegisterEvent("UNIT_SPELLCAST_STOP")
MythicClick:RegisterEvent("UNIT_SPELLCAST_FAILED")
MythicClick:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
MythicClick:RegisterEvent("UNIT_SPELLCAST_DELAYED")
MythicClick:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
MythicClick:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
MythicClick:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
MythicClick:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and (arg1 == "Blizzard_ChallengesUI" or arg1 == addonName) then
		if ChallengesFrame and not self.hooked then
			self.hooked = true
			hooksecurefunc(ChallengesFrame, "Update", function()
				self:OnChallengesFrameUpdate()
			end)
			self:OnChallengesFrameUpdate()
		end
	elseif event == "SPELLS_CHANGED" or event == "PLAYER_REGEN_ENABLED" then
		if not InCombatLockdown() then self:OnChallengesFrameUpdate() end
	elseif string.match(event, "^UNIT_SPELLCAST") and arg1 == "player" then
		self:RefreshCastState()
	end
end)
