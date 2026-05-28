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
			_id = nil,
			_standard = true,
			setFrameCalls = {},
			moveToScreenCalls = {},
			maximizeCalls = {},
			raiseCalls = 0,
			focusCalls = 0,
		}
		function win:id()
			return self._id
		end
		function win:screen()
			return self._screen
		end
		function win:frame()
			return self._frame
		end
		function win:isStandard()
			return self._standard
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
			visibleWindows = {},
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
				visibleWindows = function()
					return state.visibleWindows
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

	local function newWindowMoverWithMock(options, focusedWindow, visibleWindows)
		local state = installHsMock(focusedWindow)
		state.visibleWindows = visibleWindows or (focusedWindow and { focusedWindow } or {})
		local module = dofile("./Jinrai.spoon/window_mover.lua")
		return state, module.new(options or {})
	end

	it("フォーカスウィンドウを次ディスプレイの frame へアニメーションなしで移動する", function()
		local currentScreen = newScreen(1, { x = 0, y = 0, w = 1440, h = 900 })
		local nextScreen = newScreen(2, { x = 1440, y = 0, w = 1920, h = 1080 })
		currentScreen._next = nextScreen
		local win = newWindow(currentScreen, { x = 100, y = 100, w = 800, h = 600 })
		local _, instance = newWindowMoverWithMock({ behavior = { cursor = { afterMove = false } } }, win)

		instance.moveToNextDisplay()

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

		instance.moveToNextDisplay()

		assert.are.same({ x = 2400, y = 540 }, state.mousePositions[1])
	end)

	it("フォーカスウィンドウがなければ何もしない", function()
		local _, instance = newWindowMoverWithMock({}, nil)

		instance.moveToNextDisplay()

		assert.is_truthy(instance)
	end)

	it("screen がなければ何もしない", function()
		local win = newWindow(nil)
		local _, instance = newWindowMoverWithMock({}, win)

		instance.moveToNextDisplay()

		assert.are.equal(0, #win.setFrameCalls)
	end)

	it("次ディスプレイが同一なら何もしない", function()
		local currentScreen = newScreen(1, { x = 0, y = 0, w = 1440, h = 900 })
		currentScreen._next = currentScreen
		local win = newWindow(currentScreen)
		local _, instance = newWindowMoverWithMock({}, win)

		instance.moveToNextDisplay()

		assert.are.equal(0, #win.setFrameCalls)
	end)

	it("次ディスプレイがなければ何もしない", function()
		local currentScreen = newScreen(1, { x = 0, y = 0, w = 1440, h = 900 })
		local win = newWindow(currentScreen)
		local _, instance = newWindowMoverWithMock({}, win)

		instance.moveToNextDisplay()

		assert.are.equal(0, #win.setFrameCalls)
	end)

	it("ホットキー指定時だけ bind され teardown で削除される", function()
		local currentScreen = newScreen(1, { x = 0, y = 0, w = 1440, h = 900 })
		local nextScreen = newScreen(2, { x = 1440, y = 0, w = 1920, h = 1080 })
		currentScreen._next = nextScreen
		local win = newWindow(currentScreen)
		local state, instance = newWindowMoverWithMock({
			commands = {
				moveToNextDisplay = {
					hotkey = {
						modifiers = { "ctrl", "alt" },
						key = "m",
					},
				},
				moveToActiveDisplayFreeArea = {
					hotkey = {
						modifiers = { "cmd", "shift" },
						key = "f19",
					},
				},
			},
		}, win)

		assert.are.equal(2, #state.hotkeys)
		state.hotkeys[1].callback()
		assert.are.equal(1, #win.setFrameCalls)

		instance.teardown()
		assert.is_true(state.hotkeys[1].deleted)
		assert.is_true(state.hotkeys[2].deleted)
	end)

	it("ホットキー未指定時は bind しない", function()
		local state, instance = newWindowMoverWithMock({}, nil)

		assert.are.equal(0, #state.hotkeys)

		instance.teardown()
	end)

	it("空き領域移動は他ウィンドウがなければ現在ディスプレイの frame 全体へ移動する", function()
		local screen = newScreen(1, { x = 0, y = 0, w = 1440, h = 900 })
		local win = newWindow(screen, { x = 100, y = 100, w = 800, h = 600 })
		local _, instance = newWindowMoverWithMock({ behavior = { cursor = { afterMove = false } } }, win, { win })

		instance.moveToActiveDisplayFreeArea()

		assert.are.equal(1, #win.setFrameCalls)
		assert.are.same({ x = 0, y = 0, w = 1440, h = 900 }, win.setFrameCalls[1].frame)
		assert.are.equal(0, win.setFrameCalls[1].duration)
	end)

	it("空き領域移動は同一ディスプレイの他ウィンドウを避けた最大領域へ移動する", function()
		local screen = newScreen(1, { x = 0, y = 0, w = 1000, h = 800 })
		local win = newWindow(screen, { x = 300, y = 300, w = 200, h = 100 })
		local occupied = newWindow(screen, { x = 0, y = 0, w = 400, h = 800 })
		local _, instance = newWindowMoverWithMock({ behavior = { cursor = { afterMove = false } } }, win, {
			win,
			occupied,
		})

		instance.moveToActiveDisplayFreeArea()

		assert.are.same({ x = 400, y = 0, w = 600, h = 800 }, win.setFrameCalls[1].frame)
	end)

	it("空き領域移動は同面積なら現在位置に近い領域を選ぶ", function()
		local screen = newScreen(1, { x = 0, y = 0, w = 1000, h = 800 })
		local win = newWindow(screen, { x = 550, y = 300, w = 100, h = 100 })
		local occupied = newWindow(screen, { x = 400, y = 0, w = 200, h = 800 })
		local _, instance = newWindowMoverWithMock({ behavior = { cursor = { afterMove = false } } }, win, {
			win,
			occupied,
		})

		instance.moveToActiveDisplayFreeArea()

		assert.are.same({ x = 600, y = 0, w = 400, h = 800 }, win.setFrameCalls[1].frame)
	end)

	it("空き領域移動は他ディスプレイのウィンドウを占有対象にしない", function()
		local screen = newScreen(1, { x = 0, y = 0, w = 1000, h = 800 })
		local otherScreen = newScreen(2, { x = 1000, y = 0, w = 1000, h = 800 })
		local win = newWindow(screen, { x = 100, y = 100, w = 200, h = 100 })
		local otherDisplayWin = newWindow(otherScreen, { x = 0, y = 0, w = 900, h = 800 })
		local _, instance = newWindowMoverWithMock({ behavior = { cursor = { afterMove = false } } }, win, {
			win,
			otherDisplayWin,
		})

		instance.moveToActiveDisplayFreeArea()

		assert.are.same({ x = 0, y = 0, w = 1000, h = 800 }, win.setFrameCalls[1].frame)
	end)

	it("空き領域移動は非標準ウィンドウを占有対象にしない", function()
		local screen = newScreen(1, { x = 0, y = 0, w = 1000, h = 800 })
		local win = newWindow(screen, { x = 100, y = 100, w = 200, h = 100 })
		local desktopLikeWindow = newWindow(screen, { x = 0, y = 0, w = 1000, h = 800 })
		desktopLikeWindow._standard = false
		local _, instance = newWindowMoverWithMock({ behavior = { cursor = { afterMove = false } } }, win, {
			win,
			desktopLikeWindow,
		})

		instance.moveToActiveDisplayFreeArea()

		assert.are.same({ x = 0, y = 0, w = 1000, h = 800 }, win.setFrameCalls[1].frame)
	end)

	it("空き領域移動はアクティブウィンドウ自身を占有対象にしない", function()
		local screen = newScreen(1, { x = 0, y = 0, w = 1000, h = 800 })
		local win = newWindow(screen, { x = 0, y = 0, w = 900, h = 800 })
		local _, instance = newWindowMoverWithMock({ behavior = { cursor = { afterMove = false } } }, win, { win })

		instance.moveToActiveDisplayFreeArea()

		assert.are.same({ x = 0, y = 0, w = 1000, h = 800 }, win.setFrameCalls[1].frame)
	end)

	it("空き領域移動は空き領域がなければ何もしない", function()
		local screen = newScreen(1, { x = 0, y = 0, w = 1000, h = 800 })
		local win = newWindow(screen, { x = 100, y = 100, w = 200, h = 100 })
		local occupied = newWindow(screen, { x = 0, y = 0, w = 1000, h = 800 })
		local _, instance = newWindowMoverWithMock({}, win, { win, occupied })

		instance.moveToActiveDisplayFreeArea()

		assert.are.equal(0, #win.setFrameCalls)
	end)
end)
