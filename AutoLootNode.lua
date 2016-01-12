local GameTooltipTextLeft2 = GameTooltipTextLeft2
local GetModifiedClick = GetModifiedClick
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

-- Checks to see if the auto loot modifier is held.
local function isAutoLootModifierHeld()
	local autoLootKey = GetModifiedClick("AUTOLOOTTOGGLE")

	if autoLootKey == "ALT" then
		return IsAltKeyDown()
	end

	if autoLootKey == "CTRL" then
		return IsControlKeyDown()
	end

	if autoLootKey == "SHIFT" then
		return IsShiftKeyDown()
	end

	return false
end

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

	-- Search through left hand of the tooltip, checking for profession
	-- lines.
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

local function CancelTimer()
	-- If a timer exists and wasn't yet cancelled, cancel it.
	if autoLootDisableTimer and not autoLootDisableTimer._cancelled then
		autoLootDisableTimer:Cancel()
	end
end

local function DisableAutoLoot()
	-- Only disable it if we turned it on in the first place.
	if autoLootToggled then
		autoLootToggled = false
		SetCVar(CVAR_AUTOLOOT, AUTOLOOT_OFF)
	end
end

--[[
-- When the tooltip is hidden, we cannot disable autoloot right away. Due to
-- latency issues, it's entirely possible to disable autoloot before the loot
-- event starts on the client, meaning that a node/enemy would end up not being
-- autolooted.
-- It is also possible that when right clicking on a node that the tooltip
-- is hidden for a moment due to the cursor disappearing. This too can interfer
-- with autolooting.
--
-- To work around this, we start a timer that disables autoloot after 1 second.
--]]
local function OnHide()
	-- If we toggled auto-loot on, start a timer to disable it.
	if autoLootToggled then
		autoLootDisableTimer = NewTimer(1, DisableAutoLoot)
	end
end

local function OnShow(tooltip, ...)
	if isLootableNode(tooltip) then
		-- We might have entered a new tooltip before the previous
		-- timer expired, so we cancel timer and disable autoloot.
		CancelTimer()
		DisableAutoLoot()

		-- If we have the auto loot modifier held, do nothing.
		-- We do this after the above in case we already had a timer
		-- going when we went into a new tooltip with the modifier
		-- held.
		if isAutoLootModifierHeld() then
			return
		end

		-- We don't want to trample over chars with AutoLoot enabled.
		if not GetCVarBool(CVAR_AUTOLOOT) then
			autoLootToggled = true
			SetCVar(CVAR_AUTOLOOT, AUTOLOOT_ON)
		end
	else
		-- New tooltip that we can't loot. Disable timer and autoloot
		-- right away.
		CancelTimer()
		DisableAutoLoot()
	end
end

GameTooltip:HookScript("OnShow", OnShow)
GameTooltip:HookScript("OnHide", OnHide)
