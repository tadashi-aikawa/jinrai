local M = {}

function M.new()
	local state = {
		subscriptions = {},
		unsubscriptions = {},
		canvases = {},
		delayTimers = {},
		fadeTimers = {},
		windowSpaces = {},
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
			filter = {
				default = filterDefault,
				windowFocused = "windowFocused",
			},
		},
		timer = {
			doAfter = function(interval, fn)
				local timer = {
					interval = interval,
					callback = fn,
					stopped = false,
				}
				function timer:stop()
					self.stopped = true
				end
				table.insert(state.delayTimers, timer)
				return timer
			end,
			doEvery = function(interval, fn)
				local timer = {
					interval = interval,
					callback = fn,
					stopped = false,
				}
				function timer:stop()
					self.stopped = true
				end
				table.insert(state.fadeTimers, timer)
				return timer
			end,
		},
		spaces = {
			windowSpaces = function(id)
				return state.windowSpaces[id]
			end,
		},
		canvas = {
			windowLevels = {
				overlay = "overlay",
			},
			new = function(frame)
				local canvas = {
					frame = frame,
					visible = false,
					deleted = false,
					elements = {},
					behaviorValue = nil,
					levelValue = nil,
					alphaValue = 1,
				}
				function canvas:level(level)
					self.levelValue = level
					return self
				end
				function canvas:behavior(behavior)
					self.behaviorValue = behavior
					return self
				end
				function canvas:appendElements(element)
					table.insert(self.elements, element)
					return self
				end
				function canvas:show()
					self.visible = true
					return self
				end
				function canvas:delete()
					self.deleted = true
				end
				function canvas:alpha(value)
					self.alphaValue = value
					return self
				end
				table.insert(state.canvases, canvas)
				return canvas
			end,
		},
		spoons = {
			resourcePath = function(path)
				return "./Jinrai.spoon/" .. path
			end,
		},
	}

	local function emitWindowFocused(win)
		local cb = state.subscriptions[hs.window.filter.windowFocused]
		if cb then
			cb(win)
		end
	end

	local function setWindowSpaces(win, spaces)
		state.windowSpaces[win:id()] = spaces
	end

	return {
		hs = hs,
		state = state,
		emitWindowFocused = emitWindowFocused,
		setWindowSpaces = setWindowSpaces,
	}
end

function M.newWindow(id, frame)
	frame = frame or { x = 0, y = 0, w = 1000, h = 800 }
	local win = {}

	function win:id()
		return id
	end

	function win:frame()
		return frame
	end

	return win
end

return M
