local M = {}

function M.new()
	local state = {
		focusedWindow = nil,
		subscriptions = {},
		unsubscriptions = {},
		timers = {},
		hotkeys = {},
		urlBindings = {},
		mousePositions = {},
	}

	local filterDefault = {}
	function filterDefault:subscribe(event, fn)
		state.subscriptions[event] = fn
	end
	function filterDefault:unsubscribe(event, fn)
		table.insert(state.unsubscriptions, { event = event, fn = fn })
	end

	local hs = {
		window = {
			focusedWindow = function()
				return state.focusedWindow
			end,
			filter = {
				default = filterDefault,
				windowFocused = "windowFocused",
			},
		},
		timer = {
			doEvery = function(interval, fn)
				local timer = {
					interval = interval,
					callback = fn,
					stopped = false,
				}
				function timer:stop()
					self.stopped = true
				end
				table.insert(state.timers, timer)
				return timer
			end,
		},
		hotkey = {
			bind = function(modifiers, key, fn)
				local hotkey = {
					modifiers = modifiers,
					key = key,
					callback = fn,
					deleted = false,
				}
				function hotkey:delete()
					self.deleted = true
				end
				table.insert(state.hotkeys, hotkey)
				return hotkey
			end,
		},
		mouse = {
			absolutePosition = function(pos)
				table.insert(state.mousePositions, { x = pos.x, y = pos.y })
			end,
		},
		urlevent = {
			bind = function(name, fn)
				state.urlBindings[name] = fn
			end,
		},
		spoons = {
			resourcePath = function(path)
				return "./Jinrai.spoon/" .. path
			end,
		},
	}

	local function setFocusedWindow(win)
		state.focusedWindow = win
	end

	local function emitWindowFocused(win)
		local cb = state.subscriptions[hs.window.filter.windowFocused]
		if cb then
			cb(win)
		end
	end

	return {
		hs = hs,
		state = state,
		setFocusedWindow = setFocusedWindow,
		emitWindowFocused = emitWindowFocused,
	}
end

function M.newWindow(id, options)
	options = options or {}
	local app = {
		name = function()
			return options.appName or options.bundleID or "app-" .. tostring(id)
		end,
		bundleID = function()
			return options.bundleID
		end,
	}

	local win = {
		_focusCalls = 0,
		_visible = options.visible ~= false,
	}

	function win:id()
		return id
	end

	function win:application()
		return app
	end

	function win:isVisible()
		return self._visible
	end

	function win:setVisible(visible)
		self._visible = visible
	end

	function win:focus()
		self._focusCalls = self._focusCalls + 1
		if options.onFocus then
			options.onFocus(self)
		end
	end

	function win:frame()
		return self._frame or options.frame or { x = 0, y = 0, w = 100, h = 100 }
	end

	return win
end

return M
