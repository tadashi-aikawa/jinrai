local M = {}

local function resourcePath(fileName)
	if not hs or not hs.spoons or not hs.spoons.resourcePath then
		error("[jinrai.window_mover] hs.spoons.resourcePath is not available")
	end

	local path = hs.spoons.resourcePath(fileName)
	if not path then
		error("[jinrai.window_mover] failed to resolve Spoon resource: " .. tostring(fileName))
	end
	return path
end

local windowMoverConfig = nil
local function loadWindowMoverConfig()
	if windowMoverConfig == nil then
		windowMoverConfig = dofile(resourcePath("window_mover_config.lua"))
	end
	return windowMoverConfig
end

local function sameScreen(a, b)
	if not a or not b then
		return false
	end
	if a == b then
		return true
	end
	if a.id and b.id then
		local okA, idA = pcall(function()
			return a:id()
		end)
		local okB, idB = pcall(function()
			return b:id()
		end)
		if okA and okB and idA ~= nil and idB ~= nil then
			return idA == idB
		end
	end
	return false
end

function M.new(options)
	local config = loadWindowMoverConfig().build(options)

	local hotkey = nil

	local function moveToNextScreen()
		if not hs or not hs.window or not hs.window.focusedWindow then
			return
		end
		local win = hs.window.focusedWindow()
		if not win or not win.screen then
			return
		end
		local currentScreen = win:screen()
		if not currentScreen or not currentScreen.next then
			return
		end
		local targetScreen = currentScreen:next()
		if not targetScreen or sameScreen(currentScreen, targetScreen) or not targetScreen.frame then
			return
		end

		local targetFrame = targetScreen:frame()
		if not targetFrame then
			return
		end
		win:setFrame(targetFrame, 0)
		if win.raise then
			win:raise()
		end
		if win.focus then
			win:focus()
		end
		if config.centerCursor then
			local ok, frame = pcall(function()
				return win:frame()
			end)
			if ok and frame and (frame.w or 0) > 0 and (frame.h or 0) > 0 then
				hs.mouse.absolutePosition({ x = frame.x + frame.w / 2, y = frame.y + frame.h / 2 })
			end
		end
	end

	if config.hotkeyKey then
		hotkey = hs.hotkey.bind(config.hotkeyModifiers, config.hotkeyKey, moveToNextScreen)
	end

	local function teardown()
		if hotkey then
			hotkey:delete()
			hotkey = nil
		end
	end

	return {
		moveToNextScreen = moveToNextScreen,
		teardown = teardown,
	}
end

return M
