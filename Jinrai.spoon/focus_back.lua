local M = {}

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

local focusBackConfig = nil
local function loadFocusBackConfig()
	if focusBackConfig == nil then
		focusBackConfig = dofile(resourcePath("focus_back_config.lua"))
	end
	return focusBackConfig
end

function M.new(options)
	local config = loadFocusBackConfig().build(options)

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
			local ok, frame = pcall(function()
				return win:frame()
			end)
			if ok and frame and (frame.w or 0) > 0 and (frame.h or 0) > 0 then
				hs.mouse.absolutePosition({ x = frame.x + frame.w / 2, y = frame.y + frame.h / 2 })
			end
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
