local M = {}

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
	},
	behavior = {
		cursor = {
			afterMove = true,
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

function M.build(options)
	options = options or {}
	if type(options) ~= "table" then
		error("[jinrai.window_mover] options must be a table")
	end
	checkRemovedKeys(options)
	local merged = deepMerge(DEFAULT_CONFIG, options)

	return {
		moveToNextDisplayHotkeyModifiers = merged.commands.moveToNextDisplay.hotkey.modifiers,
		moveToNextDisplayHotkeyKey = merged.commands.moveToNextDisplay.hotkey.key,
		moveToActiveDisplayFreeAreaHotkeyModifiers = merged.commands.moveToActiveDisplayFreeArea.hotkey.modifiers,
		moveToActiveDisplayFreeAreaHotkeyKey = merged.commands.moveToActiveDisplayFreeArea.hotkey.key,
		centerCursor = merged.behavior.cursor.afterMove,
	}
end

return M
