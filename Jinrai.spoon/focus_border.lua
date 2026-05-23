local M = {}

local function resourcePath(fileName)
	if not hs or not hs.spoons or not hs.spoons.resourcePath then
		error("[jinrai.focus_border] hs.spoons.resourcePath is not available")
	end

	local path = hs.spoons.resourcePath(fileName)
	if not path then
		error("[jinrai.focus_border] failed to resolve Spoon resource: " .. tostring(fileName))
	end
	return path
end

local focusBorderConfig = nil
local function loadFocusBorderConfig()
	if focusBorderConfig == nil then
		focusBorderConfig = dofile(resourcePath("focus_border_config.lua"))
	end
	return focusBorderConfig
end

function M.new(options)
	local config = loadFocusBorderConfig().build(options)

	local currentCanvases = {}
	local delayTimer = nil
	local fadeTimer = nil
	local wf = nil
	local focusCallback = nil
	local lastFocusedSpaceId = nil

	local function stopDelayTimer()
		if delayTimer then
			delayTimer:stop()
			delayTimer = nil
		end
	end

	local function stopFadeTimer()
		if fadeTimer then
			fadeTimer:stop()
			fadeTimer = nil
		end
	end

	local function cleanup()
		stopDelayTimer()
		stopFadeTimer()
		for _, canvas in ipairs(currentCanvases) do
			canvas:delete()
		end
		currentCanvases = {}
	end

	local function newBorderCanvas(frame, fillColor)
		local canvas = hs.canvas.new(frame)
		canvas:level(hs.canvas.windowLevels.overlay)
		canvas:behavior({ "canJoinAllSpaces", "stationary", "ignoresCycle" })
		canvas:appendElements({
			type = "rectangle",
			action = "fill",
			fillColor = fillColor,
			frame = { x = 0, y = 0, w = frame.w, h = frame.h },
		})
		canvas:show()
		table.insert(currentCanvases, canvas)
		return canvas
	end

	local function showBorderLayer(frame, inset, width, color)
		if width <= 0 then
			return
		end
		local left = frame.x + inset
		local top = frame.y + inset
		local right = frame.x + frame.w - inset
		local bottom = frame.y + frame.h - inset
		local horizontalWidth = right - left
		local verticalHeight = bottom - top - (width * 2)
		if horizontalWidth <= 0 or bottom - top <= 0 then
			return
		end

		newBorderCanvas({ x = left, y = top, w = horizontalWidth, h = width }, color)
		newBorderCanvas({ x = left, y = bottom - width, w = horizontalWidth, h = width }, color)
		if verticalHeight > 0 then
			newBorderCanvas({ x = left, y = top + width, w = width, h = verticalHeight }, color)
			newBorderCanvas({ x = right - width, y = top + width, w = width, h = verticalHeight }, color)
		end
	end

	local function currentSpaceIdForWindow(win)
		if not hs or not hs.spaces or not hs.spaces.windowSpaces or not win or not win.id then
			return nil
		end

		local ok, spaces = pcall(function()
			return hs.spaces.windowSpaces(win:id())
		end)
		if not ok or type(spaces) ~= "table" then
			return nil
		end
		return spaces[1]
	end

	local function showBorder(win)
		if not win or not win.frame then
			return
		end

		local ok, frame = pcall(function()
			return win:frame()
		end)
		if not ok or not frame or frame.w == 0 or frame.h == 0 then
			return
		end

		if frame.w < config.minWindowSize or frame.h < config.minWindowSize then
			return
		end

		cleanup()

		local bw = config.borderWidth
		local ow = config.outlineWidth
		showBorderLayer(frame, 0, bw + ow * 2, config.outlineColor)
		showBorderLayer(frame, ow, bw, config.borderColor)

		local stepInterval = config.duration / config.fadeSteps
		local step = 0
		local initialAlpha = config.borderColor.alpha

		fadeTimer = hs.timer.doEvery(stepInterval, function()
			step = step + 1
			if step >= config.fadeSteps then
				cleanup()
				return
			end
			local alpha = initialAlpha * (1 - step / config.fadeSteps)
			for _, canvas in ipairs(currentCanvases) do
				canvas:alpha(alpha)
			end
		end)
	end

	local function handleWindowFocused(win)
		local currentSpaceId = currentSpaceIdForWindow(win)
		local shouldDelay = currentSpaceId ~= nil
			and lastFocusedSpaceId ~= nil
			and currentSpaceId ~= lastFocusedSpaceId
			and config.spaceSwitchDelay > 0

		stopDelayTimer()
		stopFadeTimer()
		for _, canvas in ipairs(currentCanvases) do
			canvas:delete()
		end
		currentCanvases = {}

		if shouldDelay then
			delayTimer = hs.timer.doAfter(config.spaceSwitchDelay, function()
				delayTimer = nil
				showBorder(win)
			end)
		else
			showBorder(win)
		end

		lastFocusedSpaceId = currentSpaceId
	end

	wf = hs.window.filter.default
	focusCallback = handleWindowFocused
	wf:subscribe(hs.window.filter.windowFocused, focusCallback)

	local function teardown()
		cleanup()
		if wf then
			wf:unsubscribe(hs.window.filter.windowFocused, focusCallback)
			wf = nil
		end
		focusCallback = nil
	end

	return {
		teardown = teardown,
	}
end

return M
