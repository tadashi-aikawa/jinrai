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

local function sameWindow(a, b)
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

local function screenOf(win)
	if not win or not win.screen then
		return nil
	end
	local ok, screen = pcall(function()
		return win:screen()
	end)
	if not ok then
		return nil
	end
	return screen
end

local function frameOf(win)
	if not win or not win.frame then
		return nil
	end
	local ok, frame = pcall(function()
		return win:frame()
	end)
	if not ok then
		return nil
	end
	return frame
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

local function validFrame(frame)
	return frame and frame.x ~= nil and frame.y ~= nil and frame.w ~= nil and frame.h ~= nil and frame.w > 0 and frame.h > 0
end

local function cloneFrame(frame)
	if not validFrame(frame) then
		return nil
	end
	return { x = frame.x, y = frame.y, w = frame.w, h = frame.h }
end

local function intersectFrame(a, b)
	if not validFrame(a) or not validFrame(b) then
		return nil
	end
	local x1 = math.max(a.x, b.x)
	local y1 = math.max(a.y, b.y)
	local x2 = math.min(a.x + a.w, b.x + b.w)
	local y2 = math.min(a.y + a.h, b.y + b.h)
	if x2 <= x1 or y2 <= y1 then
		return nil
	end
	return { x = x1, y = y1, w = x2 - x1, h = y2 - y1 }
end

local function subtractFrame(base, occupied)
	local cut = intersectFrame(base, occupied)
	if not cut then
		return { base }
	end

	local rects = {
		{ x = base.x, y = base.y, w = base.w, h = cut.y - base.y },
		{ x = base.x, y = cut.y + cut.h, w = base.w, h = (base.y + base.h) - (cut.y + cut.h) },
		{ x = base.x, y = cut.y, w = cut.x - base.x, h = cut.h },
		{ x = cut.x + cut.w, y = cut.y, w = (base.x + base.w) - (cut.x + cut.w), h = cut.h },
	}
	local result = {}
	for _, rect in ipairs(rects) do
		if validFrame(rect) then
			table.insert(result, rect)
		end
	end
	return result
end

local function frameArea(frame)
	return frame.w * frame.h
end

local function centerDistanceSquared(a, b)
	local ax = a.x + a.w / 2
	local ay = a.y + a.h / 2
	local bx = b.x + b.w / 2
	local by = b.y + b.h / 2
	local dx = ax - bx
	local dy = ay - by
	return dx * dx + dy * dy
end

local function isBetterFreeFrame(candidate, best, currentFrame)
	if not best then
		return true
	end
	local candidateArea = frameArea(candidate)
	local bestArea = frameArea(best)
	if candidateArea ~= bestArea then
		return candidateArea > bestArea
	end
	if currentFrame then
		local candidateDistance = centerDistanceSquared(candidate, currentFrame)
		local bestDistance = centerDistanceSquared(best, currentFrame)
		if candidateDistance ~= bestDistance then
			return candidateDistance < bestDistance
		end
	end
	if candidate.y ~= best.y then
		return candidate.y < best.y
	end
	return candidate.x < best.x
end

local function bestFreeFrame(screenFrame, occupiedFrames, currentFrame)
	local freeFrames = { cloneFrame(screenFrame) }
	for _, occupied in ipairs(occupiedFrames) do
		local nextFreeFrames = {}
		for _, freeFrame in ipairs(freeFrames) do
			local splitFrames = subtractFrame(freeFrame, occupied)
			for _, splitFrame in ipairs(splitFrames) do
				table.insert(nextFreeFrames, splitFrame)
			end
		end
		freeFrames = nextFreeFrames
	end

	local best = nil
	for _, freeFrame in ipairs(freeFrames) do
		if isBetterFreeFrame(freeFrame, best, currentFrame) then
			best = freeFrame
		end
	end
	return best
end

function M.new(options)
	local config = loadWindowMoverConfig().build(options)

	local hotkeys = {}

	local function centerCursorOnWindow(win)
		if not config.centerCursor then
			return
		end
		local ok, frame = pcall(function()
			return win:frame()
		end)
		if ok and frame and (frame.w or 0) > 0 and (frame.h or 0) > 0 then
			hs.mouse.absolutePosition({ x = frame.x + frame.w / 2, y = frame.y + frame.h / 2 })
		end
	end

	local function activateWindow(win)
		if win.raise then
			win:raise()
		end
		if win.focus then
			win:focus()
		end
		centerCursorOnWindow(win)
	end

	local function moveToNextDisplay()
		if not hs or not hs.window or not hs.window.focusedWindow then
			return
		end
		local win = hs.window.focusedWindow()
		if not win or not win.screen then
			return
		end
		local currentScreen = screenOf(win)
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
		activateWindow(win)
	end

	local function moveToActiveDisplayFreeArea()
		if not hs or not hs.window or not hs.window.focusedWindow or not hs.window.visibleWindows then
			return
		end
		local win = hs.window.focusedWindow()
		if not win or not win.screen or not win.frame then
			return
		end
		local screen = screenOf(win)
		if not screen or not screen.frame then
			return
		end
		local screenFrame = cloneFrame(screen:frame())
		if not screenFrame then
			return
		end
		local currentFrame = cloneFrame(frameOf(win))
		local occupiedFrames = {}
		for _, otherWin in ipairs(hs.window.visibleWindows()) do
			if otherWin and not sameWindow(win, otherWin) and isStandardWindow(otherWin) then
				local otherScreen = screenOf(otherWin)
				if sameScreen(screen, otherScreen) then
					local occupiedFrame = intersectFrame(screenFrame, frameOf(otherWin))
					if occupiedFrame then
						table.insert(occupiedFrames, occupiedFrame)
					end
				end
			end
		end

		local targetFrame = bestFreeFrame(screenFrame, occupiedFrames, currentFrame)
		if not targetFrame then
			return
		end
		win:setFrame(targetFrame, 0)
		activateWindow(win)
	end

	local function bindHotkey(modifiers, key, callback)
		if key then
			table.insert(hotkeys, hs.hotkey.bind(modifiers, key, callback))
		end
	end

	bindHotkey(config.moveToNextDisplayHotkeyModifiers, config.moveToNextDisplayHotkeyKey, moveToNextDisplay)
	bindHotkey(
		config.moveToActiveDisplayFreeAreaHotkeyModifiers,
		config.moveToActiveDisplayFreeAreaHotkeyKey,
		moveToActiveDisplayFreeArea
	)

	local function teardown()
		for _, hotkey in ipairs(hotkeys) do
			hotkey:delete()
		end
		hotkeys = {}
	end

	return {
		moveToNextDisplay = moveToNextDisplay,
		moveToActiveDisplayFreeArea = moveToActiveDisplayFreeArea,
		teardown = teardown,
	}
end

return M
