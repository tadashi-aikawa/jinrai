local M = {}

local DEFAULT_CONFIG = {
	hotkeyModifiers = { "option" },
	hotkeyKey = "w",
	centerCursor = false,
	stateSync = nil,
	focusHistory = nil,
}

local function resourcePath(fileName)
	if not hs or not hs.spoons or not hs.spoons.resourcePath then
		error("[jinrai.focus_back] hs.spoons.resourcePath is not available")
	end

	local path = hs.spoons.resourcePath(fileName)
	if not path then
		error("[jinrai.focus_back] failed to resolve Spoon resource: " .. tostring(fileName))
	end
	return path
end
local focusHistoryModule = dofile(resourcePath("focus_history.lua"))

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
	local ownsFocusHistory = false
	local focusHistory = config.focusHistory
	if not focusHistory then
		focusHistory = focusHistoryModule.new({
			stateSync = config.stateSync,
		})
		ownsFocusHistory = true
	end

	local function focusBack()
		if not focusHistory or not focusHistory.focusBack then
			return
		end
		local win = focusHistory:focusBack()
		if not win then
			return
		end
		if config.centerCursor then
			local frame = win:frame()
			hs.mouse.absolutePosition({ x = frame.x + frame.w / 2, y = frame.y + frame.h / 2 })
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
		if ownsFocusHistory and focusHistory and focusHistory.teardown then
			focusHistory:teardown()
			focusHistory = nil
		end
	end

	return {
		teardown = teardown,
	}
end

return M
