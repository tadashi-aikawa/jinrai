local M = {}

local DEFAULT_CONFIG = {
	borderWidth = 10,
	borderColor = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.95 },
	duration = 0.5,
	fadeSteps = 18,
	cornerRadius = 10,
	minWindowSize = 480,
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

function M.new(options)
	options = options or {}
	local config = mergeTable(DEFAULT_CONFIG, options)

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
		canvas:appendElements({
			type = "rectangle",
			action = "stroke",
			frame = { x = bw / 2, y = bw / 2, w = frame.w - bw, h = frame.h - bw },
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
