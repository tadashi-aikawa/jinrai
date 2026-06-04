local M = {}

local AREA_KEYS = {
	"full",
	"halfLeft",
	"halfHorizontalCenter",
	"halfRight",
	"halfTop",
	"halfVerticalCenter",
	"halfBottom",
	"thirdLeft",
	"thirdHorizontalCenter",
	"thirdRight",
	"thirdTop",
	"thirdVerticalCenter",
	"thirdBottom",
	"quarterLeft",
	"quarterHorizontalLeftCenter",
	"quarterHorizontalRightCenter",
	"quarterRight",
	"quarterTop",
	"quarterVerticalTopCenter",
	"quarterVerticalBottomCenter",
	"quarterBottom",
	"quarterTopLeft",
	"quarterTopRight",
	"quarterBottomLeft",
	"quarterBottomRight",
	"sixthTopLeft",
	"sixthTopCenter",
	"sixthTopRight",
	"sixthBottomLeft",
	"sixthBottomCenter",
	"sixthBottomRight",
	"twoThirdsLeft",
	"twoThirdsHorizontalCenter",
	"twoThirdsRight",
	"twoThirdsTop",
	"twoThirdsVerticalCenter",
	"twoThirdsBottom",
}

local DIRECT_AREA_COMMAND_KEYS = {
	"halfLeft",
	"halfHorizontalCenter",
	"halfRight",
	"halfTop",
	"halfVerticalCenter",
	"halfBottom",
	"thirdLeft",
	"thirdHorizontalCenter",
	"thirdRight",
	"thirdTop",
	"thirdVerticalCenter",
	"thirdBottom",
	"quarterLeft",
	"quarterHorizontalLeftCenter",
	"quarterHorizontalRightCenter",
	"quarterRight",
	"quarterTop",
	"quarterVerticalTopCenter",
	"quarterVerticalBottomCenter",
	"quarterBottom",
	"quarterTopLeft",
	"quarterTopRight",
	"quarterBottomLeft",
	"quarterBottomRight",
	"sixthTopLeft",
	"sixthTopCenter",
	"sixthTopRight",
	"sixthBottomLeft",
	"sixthBottomCenter",
	"sixthBottomRight",
	"twoThirdsLeft",
	"twoThirdsHorizontalCenter",
	"twoThirdsRight",
	"twoThirdsTop",
	"twoThirdsVerticalCenter",
	"twoThirdsBottom",
}

local DEFAULT_CONFIG = {
	commands = {
		moveToNextDisplay = {
			hotkey = {
				modifiers = nil,
				key = nil,
			},
		},
		moveToActiveDisplayFreeArea = {
			hotkey = {
				modifiers = nil,
				key = nil,
			},
		},
		openWindowActionChooser = {
			hotkey = {
				modifiers = nil,
				key = nil,
			},
		},
		minimizeWindow = {
			hotkey = {
				modifiers = nil,
				key = nil,
			},
		},
		maximizeWindow = {
			hotkey = {
				modifiers = nil,
				key = nil,
			},
		},
		cycleLeft = {
			hotkey = {
				modifiers = nil,
				key = nil,
			},
		},
		cycleHorizontalCenter = {
			hotkey = {
				modifiers = nil,
				key = nil,
			},
		},
		cycleRight = {
			hotkey = {
				modifiers = nil,
				key = nil,
			},
		},
		cycleTop = {
			hotkey = {
				modifiers = nil,
				key = nil,
			},
		},
		cycleVerticalCenter = {
			hotkey = {
				modifiers = nil,
				key = nil,
			},
		},
		cycleBottom = {
			hotkey = {
				modifiers = nil,
				key = nil,
			},
		},
	},
	behavior = {
		cursor = {
			afterMove = true,
		},
		cycle = {
			horizontalRatios = { 1 / 2, 1 / 3, 2 / 3 },
			verticalRatios = { 1 / 2, 1 / 3, 2 / 3 },
		},
	},
	selectedArea = {
		defaultScreen = nil,
		screens = {},
		actions = {
			closeWindow = nil,
		},
		hints = {
			show = true,
		},
		appearance = {
			borderWidth = 2,
			cornerRadius = 6,
			state = {
				normal = {
					bgColor = { red = 0.03, green = 0.03, blue = 0.04, alpha = 0.88 },
					textColor = { red = 0.96, green = 1.0, blue = 0.98, alpha = 1.0 },
					typedTextColor = { red = 0.96, green = 1.0, blue = 0.98, alpha = 0.38 },
				},
				dimmed = {
					bgColor = { red = 0.03, green = 0.03, blue = 0.04, alpha = 0.30 },
					textColor = { red = 0.96, green = 1.0, blue = 0.98, alpha = 0.32 },
				},
			},
			styles = {
				full = {
					color = { red = 0.36, green = 0.62, blue = 1.00, alpha = 0.92 },
					dimmedColor = { red = 0.36, green = 0.62, blue = 1.00, alpha = 0.22 },
				},
				twoThirds = {
					color = { red = 0.50, green = 0.82, blue = 0.42, alpha = 0.92 },
					dimmedColor = { red = 0.50, green = 0.82, blue = 0.42, alpha = 0.22 },
				},
				half = {
					color = { red = 0.62, green = 0.52, blue = 1.00, alpha = 0.92 },
					dimmedColor = { red = 0.62, green = 0.52, blue = 1.00, alpha = 0.22 },
				},
				third = {
					color = { red = 0.96, green = 0.66, blue = 0.28, alpha = 0.92 },
					dimmedColor = { red = 0.96, green = 0.66, blue = 0.28, alpha = 0.22 },
				},
				quarter = {
					color = { red = 0.92, green = 0.42, blue = 0.74, alpha = 0.92 },
					dimmedColor = { red = 0.92, green = 0.42, blue = 0.74, alpha = 0.22 },
				},
				sixth = {
					color = { red = 0.75, green = 0.15, blue = 0.25, alpha = 0.92 },
					dimmedColor = { red = 0.75, green = 0.15, blue = 0.25, alpha = 0.22 },
				},
				free = {
					color = { red = 0.58, green = 0.64, blue = 0.70, alpha = 0.95 },
					dimmedColor = { red = 0.58, green = 0.64, blue = 0.70, alpha = 0.22 },
				},
			},
		},
	},
	internal = {
		jinraiMode = {
			windowMover = {
				key = nil,
			},
			onStart = nil,
			onApply = nil,
			onCancel = nil,
		},
	},
}

for _, commandName in ipairs(DIRECT_AREA_COMMAND_KEYS) do
	DEFAULT_CONFIG.commands[commandName] = {
		hotkey = {
			modifiers = nil,
			key = nil,
		},
	}
end

local function isArrayTable(tbl)
	if type(tbl) ~= "table" then
		return false
	end
	local maxIndex = 0
	for k, _ in pairs(tbl) do
		if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
			return false
		end
		if k > maxIndex then
			maxIndex = k
		end
	end
	for i = 1, maxIndex do
		if tbl[i] == nil then
			return false
		end
	end
	return maxIndex > 0
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copied = {}
	for k, v in pairs(value) do
		copied[k] = deepCopy(v)
	end
	return copied
end

local function deepMerge(defaults, overrides)
	if type(defaults) ~= "table" then
		if overrides ~= nil then
			return deepCopy(overrides)
		end
		return deepCopy(defaults)
	end
	if type(overrides) ~= "table" then
		if overrides ~= nil then
			return deepCopy(overrides)
		end
		return deepCopy(defaults)
	end
	local defaultsIsArray = isArrayTable(defaults)
	local overridesIsArray = isArrayTable(overrides)
	if defaultsIsArray or overridesIsArray then
		return deepCopy(overrides)
	end

	local merged = {}
	for k, v in pairs(defaults) do
		merged[k] = deepCopy(v)
	end
	for k, v in pairs(overrides) do
		merged[k] = deepMerge(defaults[k], v)
	end
	return merged
end

local function checkRemovedKeys(options)
	if options.hotkey ~= nil then
		error("[jinrai.window_mover] removed key 'hotkey' is no longer supported; use 'commands.moveToNextDisplay.hotkey'")
	end
	if type(options.commands) == "table" and options.commands.moveToSelectedArea ~= nil then
		error(
			"[jinrai.window_mover] removed key 'commands.moveToSelectedArea' is no longer supported; use 'commands.openWindowActionChooser'"
		)
	end
	if type(options.behavior) == "table" and options.behavior.selectedArea ~= nil then
		error("[jinrai.window_mover] removed key 'behavior.selectedArea' is no longer supported; use 'selectedArea'")
	end
	if type(options.appearance) == "table" and options.appearance.selectedArea ~= nil then
		error(
			"[jinrai.window_mover] removed key 'appearance.selectedArea' is no longer supported; use 'selectedArea.appearance'"
		)
	end
end

local function startsWith(value, prefix)
	return string.sub(value, 1, #prefix) == prefix
end

local function normalizeSelectedAreaKey(key, path)
	if type(key) ~= "string" or #key < 1 or #key > 2 then
		error("[jinrai.window_mover] " .. path .. " must be a 1-2 character string")
	end

	return string.upper(key)
end

local function isFixedSizeCenterArea(areaName)
	if type(areaName) ~= "string" then
		return false
	end
	local width, height = string.match(areaName, "^(%d+)x(%d+)Center$")
	return tonumber(width) ~= nil and tonumber(width) > 0 and tonumber(height) ~= nil and tonumber(height) > 0
end

local function validateSelectedAreaKeys(areaMap, path)
	local seen = {}
	for areaName, key in pairs(areaMap) do
		local lookupKey = string.lower(key)
		if seen[lookupKey] then
			error("[jinrai.window_mover] " .. path .. " has duplicate key '" .. key .. "'")
		end
		seen[lookupKey] = areaName
	end

	for areaName, key in pairs(areaMap) do
		local lookupKey = string.lower(key)
		for otherAreaName, otherKey in pairs(areaMap) do
			local otherLookupKey = string.lower(otherKey)
			if areaName ~= otherAreaName and startsWith(otherLookupKey, lookupKey) then
				error("[jinrai.window_mover] " .. path .. " has prefix-conflicting key '" .. key .. "'")
			end
		end
	end
end

local function normalizeSelectedAreaScreens(screens)
	if type(screens) ~= "table" or isArrayTable(screens) then
		error("[jinrai.window_mover] selectedArea.screens must be a table keyed by screen UUID")
	end

	local allowedAreaKeys = {}
	for _, areaKey in ipairs(AREA_KEYS) do
		allowedAreaKeys[areaKey] = true
	end

	local normalized = {}
	for uuid, areaMap in pairs(screens) do
		if type(uuid) ~= "string" or uuid == "" then
			error("[jinrai.window_mover] selectedArea.screens keys must be non-empty UUID strings")
		end
		if type(areaMap) ~= "table" or isArrayTable(areaMap) then
			error("[jinrai.window_mover] selectedArea.screens['" .. uuid .. "'] must be an area map")
		end
		normalized[uuid] = {}
		for areaName, key in pairs(areaMap) do
			if not allowedAreaKeys[areaName] and not isFixedSizeCenterArea(areaName) then
				error("[jinrai.window_mover] unsupported selectedArea area '" .. tostring(areaName) .. "'")
			end
			normalized[uuid][areaName] =
				normalizeSelectedAreaKey(key, "selectedArea.screens['" .. uuid .. "']." .. areaName)
		end
		validateSelectedAreaKeys(normalized[uuid], "selectedArea.screens['" .. uuid .. "']")
	end
	return normalized
end

local function normalizeSelectedAreaActions(actions)
	if type(actions) ~= "table" or isArrayTable(actions) then
		error("[jinrai.window_mover] selectedArea.actions must be a table keyed by action name")
	end

	local normalized = {}
	for actionName, key in pairs(actions) do
		if actionName ~= "closeWindow" then
			error("[jinrai.window_mover] unsupported selectedArea action '" .. tostring(actionName) .. "'")
		end
		if key ~= nil then
			normalized[actionName] = normalizeSelectedAreaKey(key, "selectedArea.actions." .. actionName)
		end
	end
	validateSelectedAreaKeys(normalized, "selectedArea.actions")
	return normalized
end

local function normalizeSelectedAreaDefault(defaultUuid, screens)
	if defaultUuid == nil then
		return nil
	end
	if type(defaultUuid) ~= "string" or defaultUuid == "" then
		error("[jinrai.window_mover] selectedArea.defaultScreen must be a screen UUID string")
	end
	if screens[defaultUuid] == nil then
		error("[jinrai.window_mover] selectedArea.defaultScreen must refer to selectedArea.screens")
	end
	return defaultUuid
end

local function normalizeJinraiModeKey(key)
	if key == nil then
		return nil
	end
	if type(key) ~= "string" or key == "" then
		error("[jinrai.window_mover] jinrai_mode.triggers.windowMover.key must be a non-empty string")
	end
	return string.lower(key)
end

local function normalizeCycleRatios(ratios, path)
	if type(ratios) ~= "table" or not isArrayTable(ratios) then
		error("[jinrai.window_mover] " .. path .. " must be a non-empty array")
	end

	local normalized = {}
	local seen = {}
	for index, ratio in ipairs(ratios) do
		if type(ratio) ~= "number" or ratio <= 0 or ratio > 1 then
			error("[jinrai.window_mover] " .. path .. "[" .. index .. "] must be a number greater than 0 and at most 1")
		end
		if seen[ratio] then
			error("[jinrai.window_mover] " .. path .. " must not contain duplicate ratios")
		end
		seen[ratio] = true
		table.insert(normalized, ratio)
	end
	return normalized
end

local function validateSelectedAreaActionKeysDoNotConflict(selectedAreaActions, selectedAreaScreens)
	for actionName, actionKey in pairs(selectedAreaActions) do
		local normalizedActionKey = string.lower(actionKey)
		for uuid, areaMap in pairs(selectedAreaScreens) do
			for _, areaKey in pairs(areaMap) do
				local normalizedAreaKey = string.lower(areaKey)
				if startsWith(normalizedAreaKey, normalizedActionKey) or startsWith(normalizedActionKey, normalizedAreaKey) then
					error(
						string.format(
							"[jinrai.window_mover] selectedArea.actions.%s key '%s' conflicts with selectedArea.screens['%s'] key '%s'",
							actionName,
							actionKey,
							uuid,
							areaKey
						)
					)
				end
			end
		end
	end
end

local function actionKeyConflictsWithJinraiMode(jinraiModeKey, selectedAreaActions)
	for actionName, actionKey in pairs(selectedAreaActions) do
		local normalizedActionKey = string.lower(actionKey)
		if normalizedActionKey == jinraiModeKey or startsWith(normalizedActionKey, jinraiModeKey) then
			return actionName, actionKey
		end
	end
	return nil, nil
end

local function validateJinraiModeKeyDoesNotConflict(jinraiModeKey, selectedAreaScreens, selectedAreaActions)
	if not jinraiModeKey then
		return
	end
	local actionName, actionKey = actionKeyConflictsWithJinraiMode(jinraiModeKey, selectedAreaActions)
	if actionName then
		error(
			string.format(
				"[jinrai.window_mover] jinrai_mode.triggers.windowMover.key '%s' conflicts with selectedArea.actions.%s key '%s'",
				jinraiModeKey,
				actionName,
				actionKey
			)
		)
	end
	for uuid, areaMap in pairs(selectedAreaScreens) do
		for _, areaKey in pairs(areaMap) do
			local normalizedAreaKey = string.lower(areaKey)
			if normalizedAreaKey == jinraiModeKey or startsWith(normalizedAreaKey, jinraiModeKey) then
				error(
					string.format(
						"[jinrai.window_mover] jinrai_mode.triggers.windowMover.key '%s' conflicts with selectedArea.screens['%s'] key '%s'",
						jinraiModeKey,
						uuid,
						areaKey
					)
				)
			end
		end
	end
end

function M.build(options)
	options = options or {}
	if type(options) ~= "table" then
		error("[jinrai.window_mover] options must be a table")
	end
	checkRemovedKeys(options)
	local merged = deepMerge(DEFAULT_CONFIG, options)
	local selectedAreaScreens = normalizeSelectedAreaScreens(merged.selectedArea.screens)
	local selectedAreaActions = normalizeSelectedAreaActions(merged.selectedArea.actions)
	local selectedAreaDefault = normalizeSelectedAreaDefault(merged.selectedArea.defaultScreen, selectedAreaScreens)
	local jinraiModeKey = normalizeJinraiModeKey(merged.internal.jinraiMode.windowMover.key)
	local cycleHorizontalRatios = normalizeCycleRatios(merged.behavior.cycle.horizontalRatios, "behavior.cycle.horizontalRatios")
	local cycleVerticalRatios = normalizeCycleRatios(merged.behavior.cycle.verticalRatios, "behavior.cycle.verticalRatios")
	validateSelectedAreaActionKeysDoNotConflict(selectedAreaActions, selectedAreaScreens)
	validateJinraiModeKeyDoesNotConflict(jinraiModeKey, selectedAreaScreens, selectedAreaActions)

	local built = {
		moveToNextDisplayHotkeyModifiers = merged.commands.moveToNextDisplay.hotkey.modifiers,
		moveToNextDisplayHotkeyKey = merged.commands.moveToNextDisplay.hotkey.key,
		moveToActiveDisplayFreeAreaHotkeyModifiers = merged.commands.moveToActiveDisplayFreeArea.hotkey.modifiers,
		moveToActiveDisplayFreeAreaHotkeyKey = merged.commands.moveToActiveDisplayFreeArea.hotkey.key,
		openWindowActionChooserHotkeyModifiers = merged.commands.openWindowActionChooser.hotkey.modifiers,
		openWindowActionChooserHotkeyKey = merged.commands.openWindowActionChooser.hotkey.key,
		minimizeWindowHotkeyModifiers = merged.commands.minimizeWindow.hotkey.modifiers,
		minimizeWindowHotkeyKey = merged.commands.minimizeWindow.hotkey.key,
		maximizeWindowHotkeyModifiers = merged.commands.maximizeWindow.hotkey.modifiers,
		maximizeWindowHotkeyKey = merged.commands.maximizeWindow.hotkey.key,
		cycleLeftHotkeyModifiers = merged.commands.cycleLeft.hotkey.modifiers,
		cycleLeftHotkeyKey = merged.commands.cycleLeft.hotkey.key,
		cycleHorizontalCenterHotkeyModifiers = merged.commands.cycleHorizontalCenter.hotkey.modifiers,
		cycleHorizontalCenterHotkeyKey = merged.commands.cycleHorizontalCenter.hotkey.key,
		cycleRightHotkeyModifiers = merged.commands.cycleRight.hotkey.modifiers,
		cycleRightHotkeyKey = merged.commands.cycleRight.hotkey.key,
		cycleTopHotkeyModifiers = merged.commands.cycleTop.hotkey.modifiers,
		cycleTopHotkeyKey = merged.commands.cycleTop.hotkey.key,
		cycleVerticalCenterHotkeyModifiers = merged.commands.cycleVerticalCenter.hotkey.modifiers,
		cycleVerticalCenterHotkeyKey = merged.commands.cycleVerticalCenter.hotkey.key,
		cycleBottomHotkeyModifiers = merged.commands.cycleBottom.hotkey.modifiers,
		cycleBottomHotkeyKey = merged.commands.cycleBottom.hotkey.key,
		centerCursor = merged.behavior.cursor.afterMove,
		cycleHorizontalRatios = cycleHorizontalRatios,
		cycleVerticalRatios = cycleVerticalRatios,
		selectedAreaDefault = selectedAreaDefault,
		selectedAreaScreens = selectedAreaScreens,
		selectedAreaActions = selectedAreaActions,
		selectedAreaHintsShow = merged.selectedArea.hints.show,
		selectedAreaAppearance = merged.selectedArea.appearance,
		jinraiModeKey = jinraiModeKey,
		onJinraiModeStart = merged.internal.jinraiMode.onStart,
		onJinraiModeApply = merged.internal.jinraiMode.onApply,
		onJinraiModeCancel = merged.internal.jinraiMode.onCancel,
	}
	for _, commandName in ipairs(DIRECT_AREA_COMMAND_KEYS) do
		built[commandName .. "HotkeyModifiers"] = merged.commands[commandName].hotkey.modifiers
		built[commandName .. "HotkeyKey"] = merged.commands[commandName].hotkey.key
	end
	return built
end

return M
