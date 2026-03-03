local M = {}

local DEFAULT_CONFIG = {
	visual = {
		border = {
			width = 10,
			color = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.95 },
		},
		outline = {
			width = 2,
			color = { red = 0, green = 0, blue = 0, alpha = 0.70 },
		},
		cornerRadius = 10,
	},
	animation = {
		duration = 0.5,
		fadeSteps = 18,
	},
	window = {
		minSize = 480,
	},
}

local LEGACY_FLAT_KEYS = {
	borderWidth = true,
	borderColor = true,
	outlineWidth = true,
	outlineColor = true,
	duration = true,
	fadeSteps = true,
	cornerRadius = true,
	minWindowSize = true,
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
			error(string.format("[jinrai.focus_border] legacy flat key '%s' is no longer supported; use nested config", key))
		end
	end
end

function M.build(options)
	options = options or {}
	if type(options) ~= "table" then
		error("[jinrai.focus_border] options must be a table")
	end
	checkLegacyFlatKeys(options)
	local merged = deepMerge(DEFAULT_CONFIG, options)
	return {
		borderWidth = merged.visual.border.width,
		borderColor = merged.visual.border.color,
		outlineWidth = merged.visual.outline.width,
		outlineColor = merged.visual.outline.color,
		duration = merged.animation.duration,
		fadeSteps = merged.animation.fadeSteps,
		cornerRadius = merged.visual.cornerRadius,
		minWindowSize = merged.window.minSize,
	}
end

return M
