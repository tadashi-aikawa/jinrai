local obj = {
	name = "Jinrai",
	version = "0.0.0-development",
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
local windowMoverModule = nil
local updaterModule = nil
local focusBorder = nil
local windowHints = nil
local focusBack = nil
local focusHistory = nil
local windowMover = nil
local updater = nil

local DEFAULT_MACOS_NATIVE_TABS = {
	apps = { "com.mitchellh.ghostty", "com.apple.finder" },
	stateSyncInterval = 0.5,
}

local DEFAULT_JINRAI_MODE = {
	position = "activeWindow",
	selectionOrder = "windowFirst",
	triggers = {
		windowHints = {
			key = nil,
		},
		windowMover = {
			key = nil,
		},
	},
	logo = {
		enabled = true,
		size = 480,
		alpha = 0.4,
	},
	combo = {
		character = {
			enabled = false,
			alpha = 0.5,
		},
		text = {
			enabled = false,
			alpha = 0.7,
		},
	},
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

local function deepMerge(defaults, overrides)
	if type(defaults) ~= "table" then
		if overrides ~= nil then
			return overrides
		end
		return defaults
	end
	local merged = {}
	for k, v in pairs(defaults) do
		if type(v) == "table" then
			merged[k] = deepMerge(v, nil)
		else
			merged[k] = v
		end
	end
	if type(overrides) == "table" then
		for k, v in pairs(overrides) do
			merged[k] = deepMerge(defaults[k], v)
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

local function normalizeJinraiMode(config)
	local normalized = deepMerge(DEFAULT_JINRAI_MODE, config)
	if normalized.selectionOrder ~= "windowFirst" and normalized.selectionOrder ~= "actionFirst" then
		error("[jinrai] jinrai_mode.selectionOrder must be one of windowFirst/actionFirst")
	end
	return normalized
end

local function defer(callback)
	if hs and hs.timer and hs.timer.doAfter then
		hs.timer.doAfter(0, callback)
		return
	end
	callback()
end

function obj:setup(config)
	config = normalizeConfig(self, config)
	local macosNativeTabs = normalizeMacosNativeTabs(config.macosNativeTabs)
	local jinraiMode = normalizeJinraiMode(config.jinrai_mode)
	local pendingJinraiModeCandidate = nil
	local function showJinraiModeAfterTransition()
		defer(function()
			if windowHints and windowHints.showJinraiMode then
				if windowHints.advanceJinraiModeCombo then
					windowHints.advanceJinraiModeCombo()
				end
				windowHints.showJinraiMode()
			end
		end)
	end

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
	if windowMoverModule == nil then
		windowMoverModule = dofile(resourcePath("window_mover.lua"))
	end
	if updaterModule == nil then
		updaterModule = dofile(resourcePath("updater.lua"))
	end

	updater = updaterModule.new({
		currentVersion = obj.version,
		iconPath = resourcePath("menubar.svg"),
	})
	updater:start()

	if config.focus_border then
		focusBorder = focusBorderModule.new(config.focus_border)
	end

	if config.window_mover then
		local windowMoverConfig = config.window_mover
		local internalConfig = mergeTable(windowMoverConfig.internal or {}, {
			jinraiMode = {
				selectionOrder = jinraiMode.selectionOrder,
				windowMover = {
					key = jinraiMode.triggers.windowMover.key,
				},
				onStart = function()
					pendingJinraiModeCandidate = nil
					if windowHints and windowHints.startJinraiMode then
						windowHints.startJinraiMode()
					end
				end,
				onSelect = function(candidate)
					pendingJinraiModeCandidate = candidate
					showJinraiModeAfterTransition()
				end,
				onApply = function()
					showJinraiModeAfterTransition()
				end,
				onCancel = function()
					pendingJinraiModeCandidate = nil
					if windowHints and windowHints.stopJinraiMode then
						windowHints.stopJinraiMode()
					end
				end,
				onOpenWindowHints = function(ctx)
					defer(function()
						if not windowHints then
							return
						end
						if ctx and ctx.jinraiMode and windowHints.showJinraiMode then
							if windowHints.advanceJinraiModeCombo then
								windowHints.advanceJinraiModeCombo()
							end
							windowHints.showJinraiMode()
						elseif windowHints.show then
							windowHints.show()
						end
					end)
				end,
			},
		})
		windowMoverConfig = mergeTable(windowMoverConfig, { internal = internalConfig })
		windowMover = windowMoverModule.new(windowMoverConfig)
	end

	if config.focus_back then
		focusHistory = focusHistoryModule.new({
			macosNativeTabs = macosNativeTabs,
		})
	end

	if config.window_hints then
		local windowHintsConfig = config.window_hints
		local jinraiModeInternalConfig = mergeTable(windowHintsConfig.internal or {}, {
			jinraiMode = {
				position = jinraiMode.position,
				windowHints = {
					key = jinraiMode.triggers.windowHints.key,
				},
				logo = jinraiMode.logo,
				combo = jinraiMode.combo,
			},
		})
		windowHintsConfig = mergeTable(windowHintsConfig, { internal = jinraiModeInternalConfig })
		if windowMover then
			local function openJinraiModeWindowActionChooser(options)
				options = options or {}
				if windowHints and windowHints.advanceJinraiModeCombo then
					windowHints.advanceJinraiModeCombo()
				end
				windowMover.openWindowActionChooser({
					jinraiMode = true,
					onSelect = options.onSelect,
					onApply = function()
						showJinraiModeAfterTransition()
					end,
					onCancel = function()
						pendingJinraiModeCandidate = nil
						if windowHints and windowHints.stopJinraiMode then
							windowHints.stopJinraiMode()
						end
					end,
				})
			end
			local function openActionFirstChooser()
				openJinraiModeWindowActionChooser({
					onSelect = function(candidate)
						pendingJinraiModeCandidate = candidate
						showJinraiModeAfterTransition()
					end,
				})
			end
			local onJinraiModeStart = nil
			if jinraiMode.selectionOrder == "actionFirst" then
				onJinraiModeStart = function()
					pendingJinraiModeCandidate = nil
					openActionFirstChooser()
				end
			end
			local internalConfig = mergeTable(windowHintsConfig.internal or {}, {
				onOpenWindowActionChooser = function(ctx)
					if not windowMover or not windowMover.openWindowActionChooser then
						return
					end
					if ctx and ctx.jinraiMode then
						if jinraiMode.selectionOrder == "actionFirst" then
							openActionFirstChooser()
						else
							openJinraiModeWindowActionChooser()
						end
						return
					end
					windowMover.openWindowActionChooser()
				end,
				onJinraiModeStart = onJinraiModeStart,
				onJinraiModeSelect = function(win)
					if not windowMover or not windowMover.openWindowActionChooser then
						return
					end
					if jinraiMode.selectionOrder == "actionFirst" then
						local candidate = pendingJinraiModeCandidate
						pendingJinraiModeCandidate = nil
						local applied = false
						if candidate and windowMover.applyCandidateToWindow then
							applied = windowMover.applyCandidateToWindow(candidate, win)
						end
						defer(function()
							if applied and windowHints and windowHints.refreshJinraiModeLogo then
								windowHints.refreshJinraiModeLogo()
							end
							openActionFirstChooser()
						end)
					else
						openJinraiModeWindowActionChooser()
					end
				end,
			})
			windowHintsConfig = mergeTable(windowHintsConfig, { internal = internalConfig })
		end
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
	if updater and updater.teardown then
		updater:teardown()
	end
	if windowMover and windowMover.teardown then
		windowMover.teardown()
	end
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
	windowMover = nil
	updater = nil

	return obj
end

_G.__jinrai = {
	teardown = function()
		obj:teardown()
	end,
}

return obj
