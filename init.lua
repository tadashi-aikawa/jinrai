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
local focusBorder = nil
local windowHints = nil
local focusBack = nil

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

	if config.focus_border then
		focusBorder = focusBorderModule.new(config.focus_border)
	end

	if config.window_hints then
		windowHints = windowHintsModule.new(config.window_hints)
	end

	if config.focus_back then
		focusBack = focusBackModule.new(config.focus_back)
	end
end

local function teardown()
	if focusBack and focusBack.teardown then
		focusBack.teardown()
	end
	if windowHints and windowHints.teardown then
		windowHints.teardown()
	end
	if focusBorder and focusBorder.teardown then
		focusBorder.teardown()
	end
	focusBack = nil
	windowHints = nil
	focusBorder = nil
end

_G.__jinrai = {
	teardown = teardown,
}

M.teardown = teardown

return M
