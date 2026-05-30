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
	"twoThirdsHorizontalCenter",
	"twoThirdsVerticalCenter",
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
		moveToSelectedArea = {
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
		selectedArea = {
			default = nil,
			screens = {},
		},
	},
	appearance = {
		selectedArea = {
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
				half = {
					color = { red = 0.92, green = 0.42, blue = 0.74, alpha = 0.92 },
					dimmedColor = { red = 0.92, green = 0.42, blue = 0.74, alpha = 0.22 },
				},
				third = {
					color = { red = 0.96, green = 0.66, blue = 0.28, alpha = 0.92 },
					dimmedColor = { red = 0.96, green = 0.66, blue = 0.28, alpha = 0.22 },
				},
				twoThirds = {
					color = { red = 0.62, green = 0.52, blue = 1.00, alpha = 0.92 },
					dimmedColor = { red = 0.62, green = 0.52, blue = 1.00, alpha = 0.22 },
				},
				free = {
					color = { red = 0.58, green = 0.64, blue = 0.70, alpha = 0.95 },
					dimmedColor = { red = 0.58, green = 0.64, blue = 0.70, alpha = 0.22 },
				},
			},
		},
	},
}

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
		error("[jinrai.window_mover] behavior.selectedArea.screens must be a table keyed by screen UUID")
	end

	local allowedAreaKeys = {}
	for _, areaKey in ipairs(AREA_KEYS) do
		allowedAreaKeys[areaKey] = true
	end

	local normalized = {}
	for uuid, areaMap in pairs(screens) do
		if type(uuid) ~= "string" or uuid == "" then
			error("[jinrai.window_mover] behavior.selectedArea.screens keys must be non-empty UUID strings")
		end
		if type(areaMap) ~= "table" or isArrayTable(areaMap) then
			error("[jinrai.window_mover] behavior.selectedArea.screens['" .. uuid .. "'] must be an area map")
		end
		normalized[uuid] = {}
		for areaName, key in pairs(areaMap) do
			if not allowedAreaKeys[areaName] and not isFixedSizeCenterArea(areaName) then
				error("[jinrai.window_mover] unsupported selectedArea area '" .. tostring(areaName) .. "'")
			end
			normalized[uuid][areaName] =
				normalizeSelectedAreaKey(key, "behavior.selectedArea.screens['" .. uuid .. "']." .. areaName)
		end
		validateSelectedAreaKeys(normalized[uuid], "behavior.selectedArea.screens['" .. uuid .. "']")
	end
	return normalized
end

local function normalizeSelectedAreaDefault(defaultUuid, screens)
	if defaultUuid == nil then
		return nil
	end
	if type(defaultUuid) ~= "string" or defaultUuid == "" then
		error("[jinrai.window_mover] behavior.selectedArea.default must be a screen UUID string")
	end
	if screens[defaultUuid] == nil then
		error("[jinrai.window_mover] behavior.selectedArea.default must refer to behavior.selectedArea.screens")
	end
	return defaultUuid
end

function M.build(options)
	options = options or {}
	if type(options) ~= "table" then
		error("[jinrai.window_mover] options must be a table")
	end
	checkRemovedKeys(options)
	local merged = deepMerge(DEFAULT_CONFIG, options)
	local selectedAreaScreens = normalizeSelectedAreaScreens(merged.behavior.selectedArea.screens)
	local selectedAreaDefault = normalizeSelectedAreaDefault(merged.behavior.selectedArea.default, selectedAreaScreens)

	return {
		moveToNextDisplayHotkeyModifiers = merged.commands.moveToNextDisplay.hotkey.modifiers,
		moveToNextDisplayHotkeyKey = merged.commands.moveToNextDisplay.hotkey.key,
		moveToActiveDisplayFreeAreaHotkeyModifiers = merged.commands.moveToActiveDisplayFreeArea.hotkey.modifiers,
		moveToActiveDisplayFreeAreaHotkeyKey = merged.commands.moveToActiveDisplayFreeArea.hotkey.key,
		moveToSelectedAreaHotkeyModifiers = merged.commands.moveToSelectedArea.hotkey.modifiers,
		moveToSelectedAreaHotkeyKey = merged.commands.moveToSelectedArea.hotkey.key,
		centerCursor = merged.behavior.cursor.afterMove,
		selectedAreaDefault = selectedAreaDefault,
		selectedAreaScreens = selectedAreaScreens,
		selectedAreaAppearance = merged.appearance.selectedArea,
	}
end

return M
