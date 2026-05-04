local obj = {
	name = "Jinrai",
	version = "0.12.0",
	author = "tadashi-aikawa",
	license = "MIT - https://github.com/tadashi-aikawa/jinrai/blob/main/LICENSE",
	homepage = "https://github.com/tadashi-aikawa/jinrai",
}

local previousState = _G.__jinrai
if previousState and previousState.teardown then
	previousState.teardown()
end

local focusBorderModule = nil
local windowHintsModule = nil
local focusBackModule = nil
local focusHistoryModule = nil
local focusBorder = nil
local windowHints = nil
local focusBack = nil
local focusHistory = nil

local DEFAULT_MACOS_NATIVE_TABS = {
	apps = { "com.mitchellh.ghostty" },
	stateSyncInterval = 0.5,
}

local function resourcePath(fileName)
	if not hs or not hs.spoons or not hs.spoons.resourcePath then
		error("[jinrai] hs.spoons.resourcePath is not available")
	end

	local path = hs.spoons.resourcePath(fileName)
	if not path then
		error("[jinrai] failed to resolve Spoon resource: " .. tostring(fileName))
	end
	return path
end

local function mergeTable(defaults, overrides)
	local merged = {}
	for k, v in pairs(defaults) do
		merged[k] = v
	end
	if overrides then
		for k, v in pairs(overrides) do
			merged[k] = v
		end
	end
	return merged
end

local function mergeAppList(defaultApps, overrideApps)
	local apps = {}
	local seen = {}
	local function add(app)
		if type(app) == "string" and app ~= "" and not seen[app] then
			table.insert(apps, app)
			seen[app] = true
		end
	end
	for _, app in ipairs(defaultApps or {}) do
		add(app)
	end
	for _, app in ipairs(overrideApps or {}) do
		add(app)
	end
	return apps
end

local function normalizeMacosNativeTabs(config)
	if config == false then
		return nil
	end
	local normalized = {
		apps = mergeAppList(DEFAULT_MACOS_NATIVE_TABS.apps, type(config) == "table" and config.apps or nil),
		stateSyncInterval = DEFAULT_MACOS_NATIVE_TABS.stateSyncInterval,
	}
	if type(config) == "table" and config.stateSyncInterval ~= nil then
		normalized.stateSyncInterval = config.stateSyncInterval
	end
	return normalized
end

local function normalizeConfig(selfOrConfig, maybeConfig)
	if maybeConfig ~= nil then
		return maybeConfig
	end
	if selfOrConfig == nil or selfOrConfig == obj then
		return {}
	end
	return selfOrConfig
end

function obj:setup(config)
	config = normalizeConfig(self, config)
	local macosNativeTabs = normalizeMacosNativeTabs(config.macosNativeTabs)

	obj:teardown()

	if focusBorderModule == nil then
		focusBorderModule = dofile(resourcePath("focus_border.lua"))
	end
	if windowHintsModule == nil then
		windowHintsModule = dofile(resourcePath("window_hints.lua"))
	end
	if focusBackModule == nil then
		focusBackModule = dofile(resourcePath("focus_back.lua"))
	end
	if focusHistoryModule == nil then
		focusHistoryModule = dofile(resourcePath("focus_history.lua"))
	end

	if config.focus_border then
		focusBorder = focusBorderModule.new(config.focus_border)
	end

	if config.focus_back then
		focusHistory = focusHistoryModule.new({
			macosNativeTabs = macosNativeTabs,
		})
	end

	if config.window_hints then
		local windowHintsConfig = config.window_hints
		if focusHistory then
			local internalConfig = mergeTable(windowHintsConfig.internal or {}, { focusHistory = focusHistory })
			windowHintsConfig = mergeTable(windowHintsConfig, { internal = internalConfig })
		end
		if macosNativeTabs ~= nil then
			local internalConfig = mergeTable(windowHintsConfig.internal or {}, { macosNativeTabs = macosNativeTabs })
			windowHintsConfig = mergeTable(windowHintsConfig, { internal = internalConfig })
		end
		windowHints = windowHintsModule.new(windowHintsConfig)
	end

	if config.focus_back then
		local focusBackConfig = config.focus_back
		local internalConfig = mergeTable(focusBackConfig.internal or {}, { focusHistory = focusHistory })
		focusBackConfig = mergeTable(focusBackConfig, { internal = internalConfig })
		focusBack = focusBackModule.new(focusBackConfig)
	end

	return obj
end

function obj:teardown()
	if focusBack and focusBack.teardown then
		focusBack.teardown()
	end
	if windowHints and windowHints.teardown then
		windowHints.teardown()
	end
	if focusHistory and focusHistory.teardown then
		focusHistory:teardown()
	end
	if focusBorder and focusBorder.teardown then
		focusBorder.teardown()
	end
	focusBack = nil
	windowHints = nil
	focusHistory = nil
	focusBorder = nil

	return obj
end

_G.__jinrai = {
	teardown = function()
		obj:teardown()
	end,
}

return obj
