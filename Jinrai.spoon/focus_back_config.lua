local M = {}

local DEFAULT_CONFIG = {
	hotkey = {
		modifiers = { "option" },
		key = "w",
	},
	urlEvent = {
		name = nil,
	},
	behavior = {
		centerCursor = false,
	},
	stateSync = nil,
	internal = {
		focusHistory = nil,
	},
}

local LEGACY_FLAT_KEYS = {
	hotkeyModifiers = true,
	hotkeyKey = true,
	centerCursor = true,
	focusHistory = true,
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

local function checkLegacyFlatKeys(options)
	for key, _ in pairs(options) do
		if LEGACY_FLAT_KEYS[key] then
			error(string.format("[jinrai.focus_back] legacy flat key '%s' is no longer supported; use nested config", key))
		end
	end
end

function M.build(options)
	options = options or {}
	if type(options) ~= "table" then
		error("[jinrai.focus_back] options must be a table")
	end
	checkLegacyFlatKeys(options)
	local merged = deepMerge(DEFAULT_CONFIG, options)
	if options.internal and type(options.internal) == "table" and options.internal.focusHistory ~= nil then
		merged.internal.focusHistory = options.internal.focusHistory
	end

	return {
		hotkeyModifiers = merged.hotkey.modifiers,
		hotkeyKey = merged.hotkey.key,
		urlEvent = merged.urlEvent and merged.urlEvent.name or nil,
		centerCursor = merged.behavior.centerCursor,
		stateSync = merged.stateSync,
		focusHistory = merged.internal.focusHistory,
	}
end

return M
