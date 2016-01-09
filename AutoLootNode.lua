local GameTooltipTextLeft2 = GameTooltipTextLeft2
local GetSpellInfo = GetSpellInfo
local GetItemInfo = GetItemInfo
local GetCVarBool = GetCVarBool
local UnitIsDead = UnitIsDead
local NewTimer = C_Timer.NewTimer
local SetCVar = SetCVar
local _G = _G

local CVAR_AUTOLOOT = "autoLootDefault"
local AUTOLOOT_OFF = "0"
local AUTOLOOT_ON = "1"

local SPELL_ID_HERBALISM = 170691
local SPELL_ID_MINING = 32606

local autoLootToggled = false
local autoLootDisableTimer = nil

local validAutoLootNode = {
	[GetSpellInfo(SPELL_ID_MINING)] = true,
	[GetSpellInfo(SPELL_ID_HERBALISM)] = true,
}

local validAutoLootUnit = {
	[UNIT_SKINNABLE_BOLTS] = true,
	[UNIT_SKINNABLE_HERB] = true,
	[UNIT_SKINNABLE_LEATHER] = true,
	[UNIT_SKINNABLE_ROCK] = true,
}

-- Checks for profession type on 2nd line.
local function isProfessionNode(tooltip)
	if tooltip:NumLines() == 2 then
		local text = GameTooltipTextLeft2:GetText()
		if text then
			return validAutoLootNode[text]
		end
	end
end

-- Check for enemies that can be mined, herbed, etc.
local function isUnitLootableNode(tooltip)
	-- Is it a unit and is it dead?
	local name, unit = tooltip:GetUnit()
	if unit and not UnitIsDead(unit) then
		return false
	end

	for n=1, tooltip:NumLines() do
		local tooltipLineLeft = _G["GameTooltipTextLeft"..n]
		if tooltipLineLeft then
			local text = tooltipLineLeft:GetText()
			if text and validAutoLootUnit[text] then
				return true
			end
		end
	end
	return false
end

-- Run various checks to see if the node is something we should autoloot.
local function isLootableNode(tooltip)
	-- Regular profession nodes. Mines, herbs.
	if isProfessionNode(tooltip) then
		return true
	end

	-- Dead enemies that can be mined, etc.
	if isUnitLootableNode(tooltip) then
		return true
	end

	return false
end

local function DisableAutoLoot()
	-- Only disable it if we turned it on in the first place.
	if autoLootToggled then
		autoLootToggled = false
		SetCVar(CVAR_AUTOLOOT, AUTOLOOT_OFF)
	end
end

local function DisableAutoLootTimer()
	if autoLootToggled then
		autoLootDisableTimer = NewTimer(1, DisableAutoLoot)
	end
end

local function EnableAutoLoot(tooltip, ...)
	if autoLootDisableTimer and not autoLootDisableTimer._cancelled then
		-- Gone into a new tooltip before our previous timer fired.
		-- Cancel it and disable autoloot.
		autoLootDisableTimer:Cancel()
		DisableAutoLoot()
	end

	if isLootableNode(tooltip) then
		-- We don't want to trample over chars with AutoLoot enabled.
		if not GetCVarBool(CVAR_AUTOLOOT) then
			autoLootToggled = true
			SetCVar(CVAR_AUTOLOOT, AUTOLOOT_ON)
		end
	end
end

GameTooltip:HookScript("OnShow", EnableAutoLoot)
GameTooltip:HookScript("OnHide", DisableAutoLootTimer)
