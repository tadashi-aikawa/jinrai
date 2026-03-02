local M = {}

local DEFAULT_CONFIG = {
	stateSync = nil,
}

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

local function appKeyOfWindow(win)
	if not win then
		return nil
	end
	local app = win:application()
	if not app then
		return nil
	end
	return app:bundleID() or app:name()
end

local function isWindowVisible(win)
	if not win then
		return false
	end
	local ok, visible = pcall(function()
		return win:isVisible()
	end)
	return ok and visible
end

function M.new(options)
	options = options or {}
	local config = mergeTable(DEFAULT_CONFIG, options)

	local wf = nil
	local stateSyncTimer = nil
	local previousWindow = nil
	local currentWindow = hs.window.focusedWindow()
	local switching = false

	local stateSyncConfig = type(config.stateSync) == "table" and config.stateSync or nil
	local historyScope = "window"
	if stateSyncConfig and stateSyncConfig.historyScope == "application" then
		historyScope = "application"
	end

	local syncTargetLookup = nil
	if stateSyncConfig and type(stateSyncConfig.targetApps) == "table" then
		syncTargetLookup = {}
		for _, target in ipairs(stateSyncConfig.targetApps) do
			if type(target) == "string" and target ~= "" then
				syncTargetLookup[target] = true
			end
		end
	end

	local function shouldPromotePrevious(fromWin, toWin)
		if historyScope ~= "application" then
			return true
		end
		local fromKey = appKeyOfWindow(fromWin)
		local toKey = appKeyOfWindow(toWin)
		if not fromKey or not toKey then
			return true
		end
		return fromKey ~= toKey
	end

	local function updateWindowState(win)
		if switching then
			return
		end
		if currentWindow and currentWindow:id() ~= (win and win:id()) and shouldPromotePrevious(currentWindow, win) then
			previousWindow = currentWindow
		end
		currentWindow = win
	end

	local function isStateSyncTargetWindow(win)
		if not win then
			return false
		end
		if not syncTargetLookup then
			return true
		end
		local app = win:application()
		if not app then
			return false
		end
		local appName = app:name()
		local bundleID = app:bundleID()
		return (appName and syncTargetLookup[appName]) or (bundleID and syncTargetLookup[bundleID]) or false
	end

	wf = hs.window.filter.default
	wf:subscribe(hs.window.filter.windowFocused, function(win)
		updateWindowState(win)
	end)

	if stateSyncConfig then
		local interval = stateSyncConfig.interval
		if type(interval) ~= "number" or interval <= 0 then
			interval = 0.2
		end
		stateSyncTimer = hs.timer.doEvery(interval, function()
			local focusedWindow = hs.window.focusedWindow()
			if not isStateSyncTargetWindow(focusedWindow) then
				return
			end
			updateWindowState(focusedWindow)
		end)
	end

	local function focusBack()
		if not previousWindow then
			return nil
		end
		local ok, focusedWindow = pcall(function()
			if not isWindowVisible(previousWindow) then
				previousWindow = nil
				return nil
			end
			switching = true
			previousWindow:focus()
			switching = false
			previousWindow, currentWindow = currentWindow, previousWindow
			return currentWindow
		end)
		if not ok then
			switching = false
			return nil
		end
		return focusedWindow
	end

	local function getPreviousWindow()
		if isWindowVisible(previousWindow) then
			return previousWindow
		end
		return nil
	end

	local function teardown()
		if stateSyncTimer then
			stateSyncTimer:stop()
			stateSyncTimer = nil
		end
		if wf then
			wf:unsubscribe(hs.window.filter.windowFocused)
			wf = nil
		end
		previousWindow = nil
		currentWindow = nil
	end

	return {
		focusBack = focusBack,
		getPreviousWindow = getPreviousWindow,
		teardown = teardown,
	}
end

return M
