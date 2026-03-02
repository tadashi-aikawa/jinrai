local M = {}

local scriptSource = debug.getinfo(1, "S").source
local scriptDir = scriptSource:sub(1, 1) == "@" and scriptSource:match("^@(.+)/[^/]+$") or nil
if not scriptDir then
	error("[jinrai] failed to resolve script directory")
end

local previousState = _G.__jinrai
if previousState and previousState.teardown then
	previousState.teardown()
end

local focusBorderModule = nil
local windowHintsModule = nil
local focusBackModule = nil
local focusHistoryModule = nil
local focusBorder = nil
local windowHints = nil
local focusBack = nil
local focusHistory = nil

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

function M.setup(config)
	config = config or {}

	if focusBorderModule == nil then
		focusBorderModule = dofile(scriptDir .. "/focus_border.lua")
	end
	if windowHintsModule == nil then
		windowHintsModule = dofile(scriptDir .. "/window_hints.lua")
	end
	if focusBackModule == nil then
		focusBackModule = dofile(scriptDir .. "/focus_back.lua")
	end
	if focusHistoryModule == nil then
		focusHistoryModule = dofile(scriptDir .. "/focus_history.lua")
	end

	if config.focus_border then
		focusBorder = focusBorderModule.new(config.focus_border)
	end

	if config.focus_back then
		focusHistory = focusHistoryModule.new({
			stateSync = config.focus_back.stateSync,
		})
	end

	if config.window_hints then
		local windowHintsConfig = config.window_hints
		if focusHistory then
			windowHintsConfig = mergeTable(windowHintsConfig, { focusHistory = focusHistory })
		end
		windowHints = windowHintsModule.new(windowHintsConfig)
	end

	if config.focus_back then
		local focusBackConfig = mergeTable(config.focus_back, { focusHistory = focusHistory })
		focusBack = focusBackModule.new(focusBackConfig)
	end
end

local function teardown()
	if focusBack and focusBack.teardown then
		focusBack.teardown()
	end
	if windowHints and windowHints.teardown then
		windowHints.teardown()
	end
	if focusHistory and focusHistory.teardown then
		focusHistory:teardown()
	end
	if focusBorder and focusBorder.teardown then
		focusBorder.teardown()
	end
	focusBack = nil
	windowHints = nil
	focusHistory = nil
	focusBorder = nil
end

_G.__jinrai = {
	teardown = teardown,
}

M.teardown = teardown

return M
