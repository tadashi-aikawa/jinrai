local M = {}

local DEFAULT_CONFIG = {
	hotkey = {
		modifiers = nil,
		key = nil,
	},
	windowWaitTimeout = 10,
	apps = {},
	appearance = {
		itemWidth = 220,
		itemHeight = 112,
		gap = 12,
		columns = 3,
		iconSize = 64,
		cornerRadius = 12,
		bgColor = { red = 0.03, green = 0.03, blue = 0.04, alpha = 0.80 },
		dimmedBgColor = { red = 0.03, green = 0.03, blue = 0.04, alpha = 0.30 },
		textColor = { red = 0.96, green = 0.97, blue = 1.00, alpha = 1.00 },
		dimmedTextColor = { red = 0.82, green = 0.84, blue = 0.88, alpha = 0.30 },
		stateColor = { red = 0.40, green = 0.68, blue = 0.98, alpha = 1.00 },
	},
	behavior = {
		callbacks = {
			onError = nil,
		},
	},
	internal = {
		windowHintsKey = nil,
		jinraiModeKey = nil,
		onOpenWindowHints = nil,
		onShowInJinraiMode = nil,
		onStartJinraiMode = nil,
		onSelectInJinraiMode = nil,
		onCancelJinraiMode = nil,
	},
}

local MODIFIER_ORDER = {
	"cmd",
	"alt",
	"ctrl",
	"shift",
	"fn",
}

local MODIFIER_LOOKUP = {
	cmd = true,
	alt = true,
	ctrl = true,
	shift = true,
	fn = true,
}

local MODIFIER_ALIAS_LOOKUP = {
	option = "alt",
}

local DEFAULT_NEW_WINDOW = {
	hotkey = {
		modifiers = { "cmd" },
		key = "n",
	},
	callback = nil,
}

local function isArrayTable(value)
	if type(value) ~= "table" then
		return false
	end
	local maxIndex = 0
	for key, _ in pairs(value) do
		if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then
			return false
		end
		maxIndex = math.max(maxIndex, key)
	end
	for i = 1, maxIndex do
		if value[i] == nil then
			return false
		end
	end
	return true
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copied = {}
	for key, item in pairs(value) do
		copied[key] = deepCopy(item)
	end
	return copied
end

local function deepMerge(defaults, overrides)
	if type(defaults) ~= "table" then
		return overrides ~= nil and deepCopy(overrides) or deepCopy(defaults)
	end
	if type(overrides) ~= "table" then
		return overrides ~= nil and deepCopy(overrides) or deepCopy(defaults)
	end
	if isArrayTable(defaults) or isArrayTable(overrides) then
		return deepCopy(overrides)
	end
	local merged = deepCopy(defaults)
	for key, value in pairs(overrides) do
		merged[key] = deepMerge(defaults[key], value)
	end
	return merged
end

local function normalizeKey(value, optionName, allowNil)
	if value == nil and allowNil then
		return nil
	end
	if type(value) ~= "string" or value == "" then
		error(string.format("[jinrai.application_hints] %s must be a non-empty string", optionName))
	end
	return string.upper(value)
end

local function keysConflict(a, b)
	return a == b or string.sub(a, 1, #b) == b or string.sub(b, 1, #a) == a
end

local function normalizeModifiers(modifiers, optionName)
	if type(modifiers) ~= "table" or not isArrayTable(modifiers) then
		error(string.format("[jinrai.application_hints] %s must be an array", optionName))
	end
	if #modifiers == 0 then
		error(string.format("[jinrai.application_hints] %s must not be empty", optionName))
	end
	local lookup = {}
	for index, modifier in ipairs(modifiers) do
		if type(modifier) ~= "string" then
			error(string.format("[jinrai.application_hints] %s[%d] must be a string", optionName, index))
		end
		local normalized = string.lower(modifier)
		normalized = MODIFIER_ALIAS_LOOKUP[normalized] or normalized
		if not MODIFIER_LOOKUP[normalized] then
			error(
				string.format(
					"[jinrai.application_hints] %s[%d] must be one of cmd/alt/ctrl/shift/fn",
					optionName,
					index
				)
			)
		end
		if lookup[normalized] then
			error(string.format("[jinrai.application_hints] %s must not contain duplicate modifiers", optionName))
		end
		lookup[normalized] = true
	end
	local normalized = {}
	for _, modifier in ipairs(MODIFIER_ORDER) do
		if lookup[modifier] then
			table.insert(normalized, modifier)
		end
	end
	return normalized
end

local function normalizeNewWindow(newWindow, optionName)
	if newWindow ~= nil and type(newWindow) ~= "table" then
		error(string.format("[jinrai.application_hints] %s must be a table", optionName))
	end
	local hotkey = deepCopy(DEFAULT_NEW_WINDOW.hotkey)
	local callback = nil
	if newWindow and newWindow.hotkey ~= nil then
		if type(newWindow.hotkey) ~= "table" then
			error(string.format("[jinrai.application_hints] %s.hotkey must be a table", optionName))
		end
		if newWindow.hotkey.modifiers ~= nil then
			hotkey.modifiers = newWindow.hotkey.modifiers
		end
		if newWindow.hotkey.key ~= nil then
			hotkey.key = newWindow.hotkey.key
		end
	end
	if type(hotkey) ~= "table" then
		error(string.format("[jinrai.application_hints] %s.hotkey must be a table", optionName))
	end
	if newWindow then
		callback = newWindow.callback
	end
	if callback ~= nil and type(callback) ~= "function" then
		error(string.format("[jinrai.application_hints] %s.callback must be a function", optionName))
	end
	return {
		hotkey = {
			modifiers = normalizeModifiers(hotkey.modifiers, optionName .. ".hotkey.modifiers"),
			key = string.lower(normalizeKey(hotkey.key, optionName .. ".hotkey.key", false)),
		},
		callback = callback,
	}
end

local function normalizeApps(apps)
	if type(apps) ~= "table" or not isArrayTable(apps) then
		error("[jinrai.application_hints] apps must be an array")
	end
	if #apps == 0 then
		error("[jinrai.application_hints] apps must not be empty")
	end
	local normalized = {}
	for index, app in ipairs(apps) do
		if type(app) ~= "table" then
			error(string.format("[jinrai.application_hints] apps[%d] must be a table", index))
		end
		if type(app.bundleID) ~= "string" or app.bundleID == "" then
			error(string.format("[jinrai.application_hints] apps[%d].bundleID must be a non-empty string", index))
		end
		local key = normalizeKey(app.key, string.format("apps[%d].key", index), false)
		if #key < 1 or #key > 2 then
			error(string.format("[jinrai.application_hints] apps[%d].key must be 1 or 2 characters", index))
		end
		local newWindow = normalizeNewWindow(app.newWindow, string.format("apps[%d].newWindow", index))
		for _, existing in ipairs(normalized) do
			if keysConflict(existing.key, key) then
				error(
					string.format(
						"[jinrai.application_hints] app keys must not duplicate or share a prefix: %s / %s",
						existing.key,
						key
					)
				)
			end
		end
		table.insert(normalized, {
			bundleID = app.bundleID,
			key = key,
			name = app.name,
			newWindow = newWindow,
		})
	end
	return normalized
end

local function positiveNumber(value, optionName)
	if type(value) ~= "number" or value <= 0 or value ~= value then
		error(string.format("[jinrai.application_hints] %s must be > 0", optionName))
	end
	return value
end

function M.build(options)
	options = options or {}
	if type(options) ~= "table" then
		error("[jinrai.application_hints] options must be a table")
	end
	local merged = deepMerge(DEFAULT_CONFIG, options)
	local appearance = merged.appearance
	local apps = normalizeApps(merged.apps)
	local windowHintsKey = normalizeKey(merged.internal.windowHintsKey, "internal.windowHintsKey", true)
	local jinraiModeKey = normalizeKey(merged.internal.jinraiModeKey, "jinrai_mode.triggers.applicationHints.key", true)
	if windowHintsKey and jinraiModeKey and keysConflict(windowHintsKey, jinraiModeKey) then
		error(
			"[jinrai.application_hints] jinrai_mode.triggers.applicationHints.key conflicts with the Window Hints toggle key"
		)
	end
	if windowHintsKey then
		for index, app in ipairs(apps) do
			if keysConflict(app.key, windowHintsKey) then
				error(
					string.format(
						"[jinrai.application_hints] apps[%d].key conflicts with the Window Hints toggle key",
						index
					)
				)
			end
		end
	end
	if jinraiModeKey then
		for index, app in ipairs(apps) do
			if keysConflict(app.key, jinraiModeKey) then
				error(
					string.format(
						"[jinrai.application_hints] apps[%d].key conflicts with jinrai_mode.triggers.applicationHints.key",
						index
					)
				)
			end
		end
	end
	return {
		hotkeyModifiers = merged.hotkey.modifiers,
		hotkeyKey = merged.hotkey.key and string.lower(merged.hotkey.key) or nil,
		windowWaitTimeout = positiveNumber(merged.windowWaitTimeout, "windowWaitTimeout"),
		apps = apps,
		itemWidth = positiveNumber(appearance.itemWidth, "appearance.itemWidth"),
		itemHeight = positiveNumber(appearance.itemHeight, "appearance.itemHeight"),
		gap = positiveNumber(appearance.gap, "appearance.gap"),
		columns = math.floor(positiveNumber(appearance.columns, "appearance.columns")),
		iconSize = positiveNumber(appearance.iconSize, "appearance.iconSize"),
		cornerRadius = positiveNumber(appearance.cornerRadius, "appearance.cornerRadius"),
		bgColor = appearance.bgColor,
		dimmedBgColor = appearance.dimmedBgColor,
		textColor = appearance.textColor,
		dimmedTextColor = appearance.dimmedTextColor,
		stateColor = appearance.stateColor,
		onError = merged.behavior.callbacks.onError,
		windowHintsKey = windowHintsKey,
		jinraiModeKey = jinraiModeKey,
		onOpenWindowHints = merged.internal.onOpenWindowHints,
		onShowInJinraiMode = merged.internal.onShowInJinraiMode,
		onStartJinraiMode = merged.internal.onStartJinraiMode,
		onSelectInJinraiMode = merged.internal.onSelectInJinraiMode,
		onCancelJinraiMode = merged.internal.onCancelJinraiMode,
	}
end

M._test = {
	keysConflict = keysConflict,
	normalizeApps = normalizeApps,
}

return M
