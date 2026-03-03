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

	local currentCanvas = nil
	local fadeTimer = nil
	local wf = nil

	local function cleanup()
		if fadeTimer then
			fadeTimer:stop()
			fadeTimer = nil
		end
		if currentCanvas then
			currentCanvas:delete()
			currentCanvas = nil
		end
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
		local canvas = hs.canvas.new({
			x = frame.x,
			y = frame.y,
			w = frame.w,
			h = frame.h,
		})
		canvas:level(hs.canvas.windowLevels.overlay)
		canvas:behavior({ "canJoinAllSpaces", "stationary", "ignoresCycle" })
		local ow = config.outlineWidth
		local totalWidth = bw + ow * 2
		-- 外側アウトライン
		canvas:appendElements({
			type = "rectangle",
			action = "stroke",
			frame = { x = totalWidth / 2, y = totalWidth / 2, w = frame.w - totalWidth, h = frame.h - totalWidth },
			strokeColor = {
				red = config.outlineColor.red,
				green = config.outlineColor.green,
				blue = config.outlineColor.blue,
				alpha = config.outlineColor.alpha,
			},
			strokeWidth = totalWidth,
			roundedRectRadii = { xRadius = config.cornerRadius + ow, yRadius = config.cornerRadius + ow },
		})
		-- 内側メインボーダー（上に重ねて描画）
		canvas:appendElements({
			type = "rectangle",
			action = "stroke",
			frame = { x = ow + bw / 2, y = ow + bw / 2, w = frame.w - ow * 2 - bw, h = frame.h - ow * 2 - bw },
			strokeColor = {
				red = config.borderColor.red,
				green = config.borderColor.green,
				blue = config.borderColor.blue,
				alpha = config.borderColor.alpha,
			},
			strokeWidth = bw,
			roundedRectRadii = { xRadius = config.cornerRadius, yRadius = config.cornerRadius },
		})
		canvas:show()
		currentCanvas = canvas

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
			if currentCanvas then
				currentCanvas:alpha(alpha)
			end
		end)
	end

	wf = hs.window.filter.default
	wf:subscribe(hs.window.filter.windowFocused, function(win)
		showBorder(win)
	end)

	local function teardown()
		cleanup()
		if wf then
			wf:unsubscribe(hs.window.filter.windowFocused, showBorder)
			wf = nil
		end
	end

	return {
		teardown = teardown,
	}
end

return M
