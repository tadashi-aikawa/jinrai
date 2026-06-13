local M = {}

local function resourcePath(fileName)
	if not hs or not hs.spoons or not hs.spoons.resourcePath then
		error("[jinrai.application_hints] hs.spoons.resourcePath is not available")
	end
	local path = hs.spoons.resourcePath(fileName)
	if not path then
		error("[jinrai.application_hints] failed to resolve Spoon resource: " .. tostring(fileName))
	end
	return path
end

local configModule = nil
local function loadConfig()
	if configModule == nil then
		configModule = dofile(resourcePath("application_hints_config.lua"))
	end
	return configModule
end

local function windowId(win)
	if not win or not win.id then
		return nil
	end
	local ok, id = pcall(function()
		return win:id()
	end)
	return ok and id or nil
end

local function isStandardWindow(win)
	if not win or not win.isStandard then
		return false
	end
	local ok, standard = pcall(function()
		return win:isStandard()
	end)
	return ok and standard
end

local function collectStandardWindows(app)
	if not app or not app.allWindows then
		return {}
	end
	local ok, windows = pcall(function()
		return app:allWindows()
	end)
	if not ok or type(windows) ~= "table" then
		return {}
	end
	local result = {}
	for _, win in ipairs(windows) do
		if isStandardWindow(win) and windowId(win) ~= nil then
			table.insert(result, win)
		end
	end
	return result
end

local function buildWindowIdLookup(windows)
	local lookup = {}
	for _, win in ipairs(windows or {}) do
		local id = windowId(win)
		if id ~= nil then
			lookup[id] = true
		end
	end
	return lookup
end

local function findNewWindow(windows, previousIds)
	for _, win in ipairs(windows or {}) do
		local id = windowId(win)
		if id ~= nil and not previousIds[id] then
			return win
		end
	end
	return nil
end

local function focusWindowAndConfirm(win)
	if not win or not win.focus then
		return false
	end
	local ok = pcall(function()
		win:focus()
	end)
	if not ok then
		return false
	end
	if not hs or not hs.window or not hs.window.focusedWindow then
		return true
	end
	local focusedOk, focused = pcall(hs.window.focusedWindow)
	if not focusedOk or focused == nil then
		return true
	end
	local targetId = windowId(win)
	local focusedId = windowId(focused)
	return targetId ~= nil and focusedId ~= nil and targetId == focusedId
end

local function windowBelongsToBundleID(win, bundleID)
	if not win or not win.application then
		return false
	end
	local ok, app = pcall(function()
		return win:application()
	end)
	if not ok or not app or not app.bundleID then
		return false
	end
	local bundleOk, actualBundleID = pcall(function()
		return app:bundleID()
	end)
	return bundleOk and actualBundleID == bundleID
end

local function collectDetectedWindows(app, bundleID)
	local windows = collectStandardWindows(app)
	local seen = buildWindowIdLookup(windows)
	if hs and hs.window and hs.window.focusedWindow then
		local ok, focused = pcall(hs.window.focusedWindow)
		local focusedId = ok and windowId(focused) or nil
		if
			focusedId ~= nil
			and not seen[focusedId]
			and isStandardWindow(focused)
			and windowBelongsToBundleID(focused, bundleID)
		then
			table.insert(windows, focused)
		end
	end
	return windows
end

local function appForBundleID(bundleID)
	if not hs or not hs.application or not hs.application.get then
		return nil
	end
	local ok, app = pcall(hs.application.get, bundleID)
	return ok and app or nil
end

local function appName(entry, app)
	if entry.name and entry.name ~= "" then
		return entry.name
	end
	if app and app.name then
		local ok, name = pcall(function()
			return app:name()
		end)
		if ok and name and name ~= "" then
			return name
		end
	end
	if hs and hs.application and hs.application.nameForBundleID then
		local ok, name = pcall(hs.application.nameForBundleID, entry.bundleID)
		if ok and name and name ~= "" then
			return name
		end
	end
	return entry.bundleID
end

local function currentDisplayContext()
	local win = hs.window and hs.window.focusedWindow and hs.window.focusedWindow() or nil
	local screen = win and win.screen and win:screen() or nil
	if not screen and hs.screen and hs.screen.mainScreen then
		screen = hs.screen.mainScreen()
	end
	local screenFrame = screen and screen.frame and screen:frame() or nil
	if not screenFrame then
		return nil
	end
	local centerFrame = screenFrame
	if win and win.frame then
		local ok, frame = pcall(function()
			return win:frame()
		end)
		if ok and frame and frame.w and frame.h and frame.w > 0 and frame.h > 0 then
			centerFrame = frame
		end
	end
	return {
		screenFrame = screenFrame,
		centerX = centerFrame.x + (centerFrame.w / 2),
		centerY = centerFrame.y + (centerFrame.h / 2),
	}
end

local function clampGroupStart(center, totalSize, screenStart, screenSize)
	local maxStart = screenStart + math.max(0, screenSize - totalSize)
	return math.min(math.max(center - (totalSize / 2), screenStart), maxStart)
end

function M.new(options)
	local config = loadConfig().build(options)
	local hotkey = nil
	local keyWatcher = nil
	local canvases = {}
	local hintByKey = {}
	local currentInput = ""
	local showing = false
	local waiting = false
	local waitTimer = nil
	local timeoutTimer = nil
	local showContext = nil

	local function reportError(err)
		if config.onError then
			config.onError(err)
		elseif hs and hs.alert and hs.alert.show then
			hs.alert.show(tostring(err))
		elseif hs and hs.printf then
			hs.printf("%s", tostring(err))
		end
	end

	local function stopWait()
		if waitTimer then
			waitTimer:stop()
			waitTimer = nil
		end
		if timeoutTimer then
			timeoutTimer:stop()
			timeoutTimer = nil
		end
		waiting = false
	end

	local function clearCanvases()
		for _, canvas in ipairs(canvases) do
			for _, element in pairs(canvas) do
				if type(element) == "table" and element.image ~= nil then
					element.image = nil
				end
			end
			canvas:delete()
		end
		canvases = {}
		hintByKey = {}
		currentInput = ""
	end

	local function close(opts)
		opts = opts or {}
		local context = showContext
		stopWait()
		showing = false
		if keyWatcher then
			keyWatcher:stop()
		end
		clearCanvases()
		showContext = nil
		if
			not opts.keepJinraiMode
			and context
			and context.jinraiMode
			and config.onCancelJinraiMode
		then
			config.onCancelJinraiMode()
		end
	end

	local function refreshHighlights()
		for _, hint in pairs(hintByKey) do
			local active = currentInput == "" or string.sub(hint.entry.key, 1, #currentInput) == currentInput
			hint.canvas[1].fillColor = active and config.bgColor or config.dimmedBgColor
			hint.canvas[2].imageAlpha = active and 1 or 0.3
			hint.canvas[3].textColor = active and config.textColor or config.dimmedTextColor
			hint.canvas[4].textColor = active and config.textColor or config.dimmedTextColor
			hint.canvas[5].textColor = active and config.stateColor or config.dimmedTextColor
		end
	end

	local function completeWithWindow(win)
		local context = showContext or {}
		stopWait()
		showing = false
		if keyWatcher then
			keyWatcher:stop()
		end
		clearCanvases()
		showContext = nil
		if context.jinraiMode and config.onSelectInJinraiMode then
			config.onSelectInJinraiMode(win)
		end
	end

	local function startWindowWait(entry, previousIds)
		waiting = true
		local createdWindow = nil
		local function check()
			if not createdWindow then
				local app = appForBundleID(entry.bundleID)
				createdWindow = findNewWindow(collectDetectedWindows(app, entry.bundleID), previousIds)
			end
			if createdWindow and focusWindowAndConfirm(createdWindow) then
				completeWithWindow(createdWindow)
			end
		end
		waitTimer = hs.timer.doEvery(0.1, check)
		timeoutTimer = hs.timer.doAfter(config.windowWaitTimeout, function()
			stopWait()
			reportError("[jinrai.application_hints] timed out waiting for a new window: " .. entry.bundleID)
			close()
		end)
		check()
	end

	local function createWindow(entry)
		if waiting then
			return
		end
		local app = appForBundleID(entry.bundleID)
		local previousIds = buildWindowIdLookup(collectStandardWindows(app))
		local ok, err
		if app then
			if entry.newWindow.callback then
				ok, err = pcall(entry.newWindow.callback, app)
			else
				ok, err = pcall(function()
					hs.eventtap.keyStroke(
						entry.newWindow.hotkey.modifiers,
						entry.newWindow.hotkey.key,
						nil,
						app
					)
				end)
			end
		else
			ok, err = pcall(function()
				if not hs.application.launchOrFocusByBundleID(entry.bundleID) then
					error("failed to launch application")
				end
			end)
		end
		if not ok then
			reportError(err)
			close()
			return
		end
		for _, hint in pairs(hintByKey) do
			if hint.entry == entry then
				hint.canvas[5].text = "WAIT"
			end
		end
		startWindowWait(entry, previousIds)
	end

	local function openWindowHints()
		if not showContext or not showContext.returnToWindowHints or not config.onOpenWindowHints then
			return false
		end
		local context = showContext
		showing = false
		if keyWatcher then
			keyWatcher:stop()
		end
		clearCanvases()
		showContext = nil
		config.onOpenWindowHints({ jinraiMode = context.jinraiMode == true })
		return true
	end

	local function handleKey(key)
		if waiting then
			if key == "escape" then
				close()
			end
			return
		end
		if key == "escape" then
			close()
			return
		end
		local upper = string.upper(key)
		if config.jinraiModeKey and upper == config.jinraiModeKey then
			if showContext then
				showContext.jinraiMode = true
			end
			currentInput = ""
			if config.onStartJinraiMode then
				config.onStartJinraiMode()
			end
			refreshHighlights()
			return
		end
		if
			config.windowHintsKey
			and upper == config.windowHintsKey
			and showContext
			and showContext.returnToWindowHints
		then
			openWindowHints()
			return
		end
		if key == "delete" or key == "forwarddelete" then
			currentInput = string.sub(currentInput, 1, math.max(0, #currentInput - 1))
			refreshHighlights()
			return
		end
		currentInput = currentInput .. upper
		local exact = hintByKey[currentInput]
		if exact then
			createWindow(exact.entry)
			return
		end
		local prefixMatched = false
		for hintKey, _ in pairs(hintByKey) do
			if string.sub(hintKey, 1, #currentInput) == currentInput then
				prefixMatched = true
				break
			end
		end
		if not prefixMatched then
			currentInput = ""
		end
		refreshHighlights()
	end

	local function ensureKeyWatcher()
		if keyWatcher then
			return
		end
		keyWatcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
			local key = hs.keycodes.map[event:getKeyCode()]
			if key then
				handleKey(key)
			end
			return true
		end)
	end

	local function show(opts)
		if showing then
			close()
			return true
		end
		opts = opts or {}
		local displayContext = currentDisplayContext()
		if not displayContext or #config.apps == 0 then
			return false
		end
		showContext = {
			jinraiMode = opts.jinraiMode == true,
			advanceJinraiModeCombo = opts.advanceJinraiModeCombo ~= false,
			returnToWindowHints = opts.returnToWindowHints == true,
		}
		local columns = math.min(config.columns, #config.apps)
		local rows = math.ceil(#config.apps / columns)
		local totalWidth = columns * config.itemWidth + (columns - 1) * config.gap
		local totalHeight = rows * config.itemHeight + (rows - 1) * config.gap
		local screenFrame = displayContext.screenFrame
		local startX = clampGroupStart(displayContext.centerX, totalWidth, screenFrame.x, screenFrame.w)
		local startY = clampGroupStart(displayContext.centerY, totalHeight, screenFrame.y, screenFrame.h)

		for index, entry in ipairs(config.apps) do
			local app = appForBundleID(entry.bundleID)
			local col = (index - 1) % columns
			local row = math.floor((index - 1) / columns)
			local frame = {
				x = startX + col * (config.itemWidth + config.gap),
				y = startY + row * (config.itemHeight + config.gap),
				w = config.itemWidth,
				h = config.itemHeight,
			}
			local canvas = hs.canvas.new(frame)
			canvas:level(hs.canvas.windowLevels.overlay + 2)
			canvas:behavior({ "canJoinAllSpaces", "stationary", "ignoresCycle" })
			canvas:appendElements(
				{
					type = "rectangle",
					action = "fill",
					fillColor = config.bgColor,
					roundedRectRadii = { xRadius = config.cornerRadius, yRadius = config.cornerRadius },
					frame = { x = 0, y = 0, w = frame.w, h = frame.h },
				},
				{
					type = "image",
					image = hs.image.imageFromAppBundle(entry.bundleID),
					imageAlpha = 1,
					frame = { x = 16, y = 24, w = config.iconSize, h = config.iconSize },
				},
				{
					type = "text",
					text = entry.key,
					textColor = config.textColor,
					textFont = "Menlo-Bold",
					textSize = 30,
					textAlignment = "center",
					frame = { x = 88, y = 14, w = frame.w - 100, h = 40 },
				},
				{
					type = "text",
					text = appName(entry, app),
					textColor = config.textColor,
					textSize = 14,
					textAlignment = "center",
					textLineBreak = "truncateTail",
					frame = { x = 88, y = 56, w = frame.w - 100, h = 24 },
				},
				{
					type = "text",
					text = app and "NEW" or "OPEN",
					textColor = config.stateColor,
					textSize = 12,
					textAlignment = "center",
					frame = { x = 88, y = 82, w = frame.w - 100, h = 18 },
				}
			)
			table.insert(canvases, canvas)
			hintByKey[entry.key] = { entry = entry, canvas = canvas }
		end
		if showContext.jinraiMode and showContext.advanceJinraiModeCombo and config.onShowInJinraiMode then
			config.onShowInJinraiMode()
		end
		for _, canvas in ipairs(canvases) do
			canvas:show()
		end
		currentInput = ""
		showing = true
		ensureKeyWatcher()
		keyWatcher:start()
		return true
	end

	local function teardown()
		close()
		if hotkey then
			hotkey:delete()
			hotkey = nil
		end
		keyWatcher = nil
	end

	if config.hotkeyKey then
		hotkey = hs.hotkey.bind(config.hotkeyModifiers or {}, config.hotkeyKey, function()
			show()
		end)
	end

	return {
		show = show,
		close = close,
		teardown = teardown,
	}
end

M._test = {
	collectStandardWindows = collectStandardWindows,
	buildWindowIdLookup = buildWindowIdLookup,
	findNewWindow = findNewWindow,
	focusWindowAndConfirm = focusWindowAndConfirm,
	collectDetectedWindows = collectDetectedWindows,
	clampGroupStart = clampGroupStart,
}

return M
