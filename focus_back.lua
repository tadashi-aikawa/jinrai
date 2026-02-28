local M = {}

local DEFAULT_CONFIG = {
	hotkeyModifiers = { "option" },
	hotkeyKey = "w",
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

	local hotkey = nil
	local wf = nil
	local previousWindow = nil
	local currentWindow = hs.window.focusedWindow()
	local switching = false

	wf = hs.window.filter.default
	wf:subscribe(hs.window.filter.windowFocused, function(win)
		if switching then
			return
		end
		if currentWindow and currentWindow:id() ~= (win and win:id()) then
			previousWindow = currentWindow
		end
		currentWindow = win
	end)

	local function focusBack()
		if not previousWindow then
			return
		end
		local ok, _ = pcall(function()
			if not previousWindow:isVisible() then
				previousWindow = nil
				return
			end
			switching = true
			previousWindow:focus()
			switching = false
			previousWindow, currentWindow = currentWindow, previousWindow
		end)
		if not ok then
			switching = false
		end
	end

	if config.hotkeyKey then
		hotkey = hs.hotkey.bind(config.hotkeyModifiers, config.hotkeyKey, focusBack)
	end

	if config.urlEvent then
		hs.urlevent.bind(config.urlEvent, function()
			focusBack()
		end)
	end

	local function teardown()
		if hotkey then
			hotkey:delete()
			hotkey = nil
		end
		if config.urlEvent then
			hs.urlevent.bind(config.urlEvent, nil)
		end
		if wf then
			wf:unsubscribe(hs.window.filter.windowFocused)
			wf = nil
		end
		previousWindow = nil
		currentWindow = nil
	end

	return {
		teardown = teardown,
	}
end

return M
