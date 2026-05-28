describe("window_mover", function()
	local originalHs

	before_each(function()
		originalHs = _G.hs
	end)

	after_each(function()
		_G.hs = originalHs
	end)

	local function newScreen(id, frame)
		local screen = {
			_id = id,
			_frame = frame,
			_next = nil,
		}
		function screen:id()
			return self._id
		end
		function screen:frame()
			return self._frame
		end
		function screen:next()
			return self._next
		end
		return screen
	end

	local function newWindow(screen, frame)
		local win = {
			_screen = screen,
			_frame = frame or { x = 0, y = 0, w = 100, h = 100 },
			setFrameCalls = {},
			moveToScreenCalls = {},
			maximizeCalls = {},
			raiseCalls = 0,
			focusCalls = 0,
		}
		function win:screen()
			return self._screen
		end
		function win:frame()
			return self._frame
		end
		function win:setFrame(nextFrame, duration)
			table.insert(self.setFrameCalls, { frame = nextFrame, duration = duration })
			self._frame = nextFrame
		end
		function win:moveToScreen(screen)
			table.insert(self.moveToScreenCalls, screen)
		end
		function win:maximize(duration)
			table.insert(self.maximizeCalls, duration)
		end
		function win:raise()
			self.raiseCalls = self.raiseCalls + 1
		end
		function win:focus()
			self.focusCalls = self.focusCalls + 1
		end
		return win
	end

	local function installHsMock(focusedWindow)
		local state = {
			hotkeys = {},
			mousePositions = {},
		}
		_G.hs = {
			spoons = {
				resourcePath = function(path)
					return "./Jinrai.spoon/" .. path
				end,
			},
			window = {
				focusedWindow = function()
					return focusedWindow
				end,
			},
			hotkey = {
				bind = function(modifiers, key, callback)
					local hotkey = {
						modifiers = modifiers,
						key = key,
						callback = callback,
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
				absolutePosition = function(position)
					table.insert(state.mousePositions, position)
				end,
			},
		}
		return state
	end

	local function newWindowMoverWithMock(options, focusedWindow)
		local state = installHsMock(focusedWindow)
		local module = dofile("./Jinrai.spoon/window_mover.lua")
		return state, module.new(options or {})
	end

	it("フォーカスウィンドウを次ディスプレイの frame へアニメーションなしで移動する", function()
		local currentScreen = newScreen(1, { x = 0, y = 0, w = 1440, h = 900 })
		local nextScreen = newScreen(2, { x = 1440, y = 0, w = 1920, h = 1080 })
		currentScreen._next = nextScreen
		local win = newWindow(currentScreen, { x = 100, y = 100, w = 800, h = 600 })
		local _, instance = newWindowMoverWithMock({ behavior = { cursor = { afterMove = false } } }, win)

		instance.moveToNextScreen()

		assert.are.equal(1, #win.setFrameCalls)
		assert.are.same({ x = 1440, y = 0, w = 1920, h = 1080 }, win.setFrameCalls[1].frame)
		assert.are.equal(0, win.setFrameCalls[1].duration)
		assert.are.equal(0, #win.moveToScreenCalls)
		assert.are.equal(0, #win.maximizeCalls)
		assert.are.equal(1, win.raiseCalls)
		assert.are.equal(1, win.focusCalls)
	end)

	it("afterMove=true なら移動後ウィンドウ中央へカーソルを移動する", function()
		local currentScreen = newScreen(1, { x = 0, y = 0, w = 1440, h = 900 })
		local nextScreen = newScreen(2, { x = 1440, y = 0, w = 1920, h = 1080 })
		currentScreen._next = nextScreen
		local win = newWindow(currentScreen)
		local state, instance = newWindowMoverWithMock({}, win)

		instance.moveToNextScreen()

		assert.are.same({ x = 2400, y = 540 }, state.mousePositions[1])
	end)

	it("フォーカスウィンドウがなければ何もしない", function()
		local _, instance = newWindowMoverWithMock({}, nil)

		instance.moveToNextScreen()

		assert.is_truthy(instance)
	end)

	it("screen がなければ何もしない", function()
		local win = newWindow(nil)
		local _, instance = newWindowMoverWithMock({}, win)

		instance.moveToNextScreen()

		assert.are.equal(0, #win.setFrameCalls)
	end)

	it("次ディスプレイが同一なら何もしない", function()
		local currentScreen = newScreen(1, { x = 0, y = 0, w = 1440, h = 900 })
		currentScreen._next = currentScreen
		local win = newWindow(currentScreen)
		local _, instance = newWindowMoverWithMock({}, win)

		instance.moveToNextScreen()

		assert.are.equal(0, #win.setFrameCalls)
	end)

	it("次ディスプレイがなければ何もしない", function()
		local currentScreen = newScreen(1, { x = 0, y = 0, w = 1440, h = 900 })
		local win = newWindow(currentScreen)
		local _, instance = newWindowMoverWithMock({}, win)

		instance.moveToNextScreen()

		assert.are.equal(0, #win.setFrameCalls)
	end)

	it("ホットキー指定時だけ bind され teardown で削除される", function()
		local currentScreen = newScreen(1, { x = 0, y = 0, w = 1440, h = 900 })
		local nextScreen = newScreen(2, { x = 1440, y = 0, w = 1920, h = 1080 })
		currentScreen._next = nextScreen
		local win = newWindow(currentScreen)
		local state, instance = newWindowMoverWithMock({
			hotkey = {
				modifiers = { "ctrl", "alt" },
				key = "m",
			},
		}, win)

		assert.are.equal(1, #state.hotkeys)
		state.hotkeys[1].callback()
		assert.are.equal(1, #win.setFrameCalls)

		instance.teardown()
		assert.is_true(state.hotkeys[1].deleted)
	end)

	it("ホットキー未指定時は bind しない", function()
		local state, instance = newWindowMoverWithMock({}, nil)

		assert.are.equal(0, #state.hotkeys)

		instance.teardown()
	end)
end)
