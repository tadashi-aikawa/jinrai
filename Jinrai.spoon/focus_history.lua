local M = {}

local DEFAULT_CONFIG = {
	macosNativeTabs = nil,
}

local MAX_HISTORY_SIZE = 20

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
		if not win:isVisible() then
			return false
		end
		local f = win:frame()
		return f and (f.w or 0) > 0 and (f.h or 0) > 0
	end)
	return ok and visible
end

function M.new(options)
	options = options or {}
	local config = mergeTable(DEFAULT_CONFIG, options)

	local wf = nil
	local nativeTabsTimer = nil
	local history = {}
	local currentWindow = hs.window.focusedWindow()
	local switching = false

	local macosNativeTabsConfig = type(config.macosNativeTabs) == "table" and config.macosNativeTabs or nil
	local syncTargetLookup = nil
	if macosNativeTabsConfig and type(macosNativeTabsConfig.apps) == "table" then
		syncTargetLookup = {}
		for _, target in ipairs(macosNativeTabsConfig.apps) do
			if type(target) == "string" and target ~= "" then
				syncTargetLookup[target] = true
			end
		end
		if next(syncTargetLookup) == nil then
			syncTargetLookup = nil
		end
	end

	local function shouldPromotePrevious(fromWin, toWin)
		if not syncTargetLookup then
			return true
		end
		local fromKey = appKeyOfWindow(fromWin)
		local toKey = appKeyOfWindow(toWin)
		if not fromKey or not toKey then
			return true
		end
		if fromKey ~= toKey then
			return true
		end
		local app = toWin:application()
		if not app then
			return true
		end
		local appName = app:name()
		local bundleID = app:bundleID()
		return not ((appName and syncTargetLookup[appName]) or (bundleID and syncTargetLookup[bundleID]))
	end

	local function updateWindowState(win)
		if switching then
			return
		end
		if currentWindow and currentWindow:id() ~= (win and win:id()) and shouldPromotePrevious(currentWindow, win) then
			table.insert(history, currentWindow)
			if #history > MAX_HISTORY_SIZE then
				table.remove(history, 1)
			end
		end
		currentWindow = win
	end

	local function isStateSyncTargetWindow(win)
		if not win then
			return false
		end
		if not syncTargetLookup then
			return false
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

	if syncTargetLookup then
		local interval = macosNativeTabsConfig.stateSyncInterval
		if type(interval) ~= "number" or interval <= 0 then
			interval = 0.2
		end
		nativeTabsTimer = hs.timer.doEvery(interval, function()
			local focusedWindow = hs.window.focusedWindow()
			if not isStateSyncTargetWindow(focusedWindow) then
				return
			end
			updateWindowState(focusedWindow)
		end)
	end

	local function focusBack()
		if syncTargetLookup and hs and hs.window and hs.window.focusedWindow then
			local ok, focusedWindow = pcall(function()
				return hs.window.focusedWindow()
			end)
			if ok and isStateSyncTargetWindow(focusedWindow) then
				updateWindowState(focusedWindow)
			end
		end

		local targetWindow = nil
		while #history > 0 do
			local candidate = table.remove(history)
			if isWindowVisible(candidate) and candidate:id() ~= (currentWindow and currentWindow:id()) then
				targetWindow = candidate
				break
			end
		end
		if not targetWindow then
			return nil
		end
		local ok, focusedWindow = pcall(function()
			switching = true
			targetWindow:focus()
			switching = false
			table.insert(history, currentWindow)
			if #history > MAX_HISTORY_SIZE then
				table.remove(history, 1)
			end
			currentWindow = targetWindow
			return currentWindow
		end)
		if not ok then
			switching = false
			return nil
		end
		return focusedWindow
	end

	local function getPreviousWindow()
		for i = #history, 1, -1 do
			local win = history[i]
			if isWindowVisible(win) and win:id() ~= (currentWindow and currentWindow:id()) then
				return win
			end
		end
		return nil
	end

	local function teardown()
		if nativeTabsTimer then
			nativeTabsTimer:stop()
			nativeTabsTimer = nil
		end
		if wf then
			wf:unsubscribe(hs.window.filter.windowFocused)
			wf = nil
		end
		history = {}
		currentWindow = nil
	end

	return {
		focusBack = focusBack,
		getPreviousWindow = getPreviousWindow,
		teardown = teardown,
	}
end

return M
