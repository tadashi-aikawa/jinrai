describe("window_mover", function()
	local originalHs

	before_each(function()
		originalHs = _G.hs
	end)

	after_each(function()
		_G.hs = originalHs
	end)

	local function newScreen(id, frame, uuid, name)
		local screen = {
			_id = id,
			_frame = frame,
			_uuid = uuid or ("uuid-" .. tostring(id)),
			_name = name or ("Display " .. tostring(id)),
			_next = nil,
		}
		function screen:id()
			return self._id
		end
		function screen:frame()
			return self._frame
		end
		function screen:getUUID()
			return self._uuid
		end
		function screen:name()
			return self._name
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
			minimizeCalls = 0,
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
		function win:minimize()
			self.minimizeCalls = self.minimizeCalls + 1
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
			screens = {},
			canvases = {},
			eventtaps = {},
			webviews = {},
			pasteboardWrites = {},
		}
		local canvasMethods = {}
		canvasMethods.__index = canvasMethods
		function canvasMethods:level(level)
			self._level = level
			return self
		end
		function canvasMethods:behavior(behavior)
			self._behavior = behavior
			return self
		end
		function canvasMethods:show()
			self._shown = true
			return self
		end
		function canvasMethods:delete()
			self._deleted = true
		end

		local webviewMethods = {}
		webviewMethods.__index = webviewMethods
		function webviewMethods:allowTextEntry(value)
			self._allowTextEntry = value
			return self
		end
		function webviewMethods:html(html)
			self._html = html
			return self
		end
		function webviewMethods:level(level)
			self._level = level
			return self
		end
		function webviewMethods:windowStyle(style)
			self._windowStyle = style
			return self
		end
		function webviewMethods:show()
			self._shown = true
			return self
		end
		function webviewMethods:delete()
			self._deleted = true
		end

		local keycodesByName = {
			escape = 53,
			delete = 51,
			forwarddelete = 117,
			a = 0,
			s = 1,
			d = 2,
			f = 3,
			q = 12,
			w = 13,
			e = 14,
			r = 15,
			j = 38,
			k = 40,
			l = 37,
			m = 46,
			z = 6,
			x = 7,
			c = 8,
			v = 9,
			f18 = 79,
			f19 = 80,
		}
		local keycodesMap = {}
		for name, code in pairs(keycodesByName) do
			keycodesMap[code] = name
		end
		_G.hs = {
			styledtext = {
				new = function(text, _style)
					local obj = { _text = text }
					return setmetatable(obj, {
						__concat = function(a, b)
							local at = type(a) == "table" and a._text or tostring(a)
							local bt = type(b) == "table" and b._text or tostring(b)
							return hs.styledtext.new(at .. bt, {})
						end,
					})
				end,
			},
			spoons = {
				resourcePath = function(path)
					return "./Jinrai.spoon/" .. path
				end,
			},
			screen = {
				allScreens = function()
					return state.screens
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
			canvas = {
				windowLevels = {
					overlay = 10,
				},
				new = function(frame)
					local canvas = setmetatable({ _frame = frame }, canvasMethods)
					table.insert(state.canvases, canvas)
					return canvas
				end,
			},
			webview = {
				new = function(frame, usercontent)
					local webview = setmetatable({ _frame = frame, _usercontent = usercontent }, webviewMethods)
					table.insert(state.webviews, webview)
					return webview
				end,
				newBrowser = function(frame, usercontent)
					local webview = setmetatable({ _frame = frame, _newBrowser = true, _usercontent = usercontent }, webviewMethods)
					table.insert(state.webviews, webview)
					return webview
				end,
			},
			eventtap = {
				event = {
					types = {
						keyDown = 1,
						leftMouseDown = 2,
					},
				},
				new = function(types, callback)
					local tap = {
						types = types,
						callback = callback,
						started = false,
						stopped = false,
					}
					function tap:start()
						self.started = true
						self.stopped = false
					end
					function tap:stop()
						self.stopped = true
						self.started = false
					end
					table.insert(state.eventtaps, tap)
					return tap
				end,
			},
			keycodes = {
				map = keycodesMap,
			},
			pasteboard = {
				writeObjects = function(value)
					table.insert(state.pasteboardWrites, value)
					return true
				end,
			},
		}
		_G.hs.webview.usercontent = {
			new = function(name)
				local usercontent = {
					_name = name,
				}
				function usercontent:setCallback(callback)
					self._callback = callback
					return self
				end
				return usercontent
			end,
		}
		state.keycodes = keycodesByName
		return state
	end

	local function sendKey(state, key, flags)
		local keyCode = state.keycodes[key]
		local event = {
			getKeyCode = function()
				return keyCode
			end,
			getFlags = function()
				return flags or {}
			end,
		}
		return state.eventtaps[1].callback(event)
	end

	local function sendMouseDown(state, point)
		local event = {
			location = function()
				return point
			end,
		}
		return state.eventtaps[2].callback(event)
	end

	local function newWindowMoverWithMock(options, focusedWindow, visibleWindows)
		local state = installHsMock(focusedWindow)
		state.visibleWindows = visibleWindows or (focusedWindow and { focusedWindow } or {})
		local module = dofile("./Jinrai.spoon/window_mover.lua")
		return state, module.new(options or {})
	end

	local function canvasKeys(state)
		local keys = {}
		for _, canvas in ipairs(state.canvases) do
			local text = canvas[3].text
			table.insert(keys, type(text) == "table" and text._text or text)
		end
		return keys
	end

	local function canvasHasText(state, text)
		for _, canvas in ipairs(state.canvases) do
			for _, element in pairs(canvas) do
				if type(element) == "table" then
					local value = element.text
					value = type(value) == "table" and value._text or value
					if value == text then
						return true
					end
				end
			end
		end
		return false
	end

	local function canvasFramesByKey(state)
		local frames = {}
		for _, canvas in ipairs(state.canvases) do
			local text = canvas[3].text
			frames[type(text) == "table" and text._text or text] = canvas._frame
		end
		return frames
	end

	local function framesOverlapHorizontally(a, b)
		return a.x < b.x + b.w and b.x < a.x + a.w
	end

	local function framesHaveVerticalGap(a, b, gap)
		if a.y <= b.y then
			return a.y + a.h + gap <= b.y
		end
		return b.y + b.h + gap <= a.y
	end

	local function selectedAreaOptions(screens, defaultUuid, selectedAreaOverrides)
		selectedAreaOverrides = selectedAreaOverrides or {}
		return {
			behavior = {
				cursor = { afterMove = false },
			},
			selectedArea = {
				defaultScreen = defaultUuid,
				screens = screens,
				hints = selectedAreaOverrides.hints,
			},
		}
	end

	it("フォーカスウィンドウを次ディスプレイの frame へアニメーションなしで移動する", function()
		local currentScreen = newScreen(1, { x = 0, y = 0, w = 1440, h = 900 })
		local nextScreen = newScreen(2, { x = 1440, y = 0, w = 1920, h = 1080 })
		currentScreen._next = nextScreen
		local win = newWindow(currentScreen, { x = 100, y = 100, w = 800, h = 600 })
		local _, instance = newWindowMoverWithMock({ behavior = { cursor = { afterMove = false } } }, win)

		instance.moveToNextDisplay()

		assert.are.same({ x = 1440, y = 0, w = 1920, h = 1080 }, win.setFrameCalls[1].frame)
		assert.are.equal(0, win.setFrameCalls[1].duration)
		assert.are.equal(1, win.raiseCalls)
		assert.are.equal(1, win.focusCalls)
	end)

	it("アクティブディスプレイの最大空き領域へ移動する", function()
		local screen = newScreen(1, { x = 0, y = 0, w = 1000, h = 800 })
		local win = newWindow(screen, { x = 100, y = 100, w = 200, h = 100 })
		local occupied = newWindow(screen, { x = 0, y = 0, w = 300, h = 800 })
		local _, instance = newWindowMoverWithMock({ behavior = { cursor = { afterMove = false } } }, win, {
			win,
			occupied,
		})

		instance.moveToActiveDisplayFreeArea()

		assert.are.same({ x = 300, y = 0, w = 700, h = 800 }, win.setFrameCalls[1].frame)
	end)

	it("新しい直接実行コマンドのホットキーを登録して解放する", function()
		local screen = newScreen(1, { x = 0, y = 0, w = 1200, h = 800 })
		local win = newWindow(screen)
		local state, instance = newWindowMoverWithMock({
			commands = {
				minimizeWindow = { hotkey = { modifiers = { "cmd" }, key = "m" } },
				maximizeWindow = { hotkey = { modifiers = { "cmd" }, key = "f" } },
				cycleLeft = { hotkey = { modifiers = { "ctrl", "alt" }, key = "h" } },
				cycleCenter = { hotkey = { modifiers = { "ctrl", "alt" }, key = "j" } },
				cycleRight = { hotkey = { modifiers = { "ctrl", "alt" }, key = "l" } },
			},
		}, win, { win })

		assert.are.equal(5, #state.hotkeys)
		assert.are.same({ "m", "f", "h", "j", "l" }, {
			state.hotkeys[1].key,
			state.hotkeys[2].key,
			state.hotkeys[3].key,
			state.hotkeys[4].key,
			state.hotkeys[5].key,
		})

		instance.teardown()

		for _, hotkey in ipairs(state.hotkeys) do
			assert.is_true(hotkey.deleted)
		end
	end)

	it("フォーカスウィンドウを最小化する", function()
		local screen = newScreen(1, { x = 0, y = 0, w = 1200, h = 800 })
		local win = newWindow(screen)
		local _, instance = newWindowMoverWithMock({}, win, { win })

		instance.minimizeWindow()

		assert.are.equal(1, win.minimizeCalls)
		assert.are.equal(0, win.raiseCalls)
		assert.are.equal(0, win.focusCalls)
	end)

	it("フォーカスウィンドウを現在ディスプレイの full frame へ移動する", function()
		local screen = newScreen(1, { x = 10, y = 20, w = 1200, h = 800 })
		local win = newWindow(screen, { x = 100, y = 100, w = 500, h = 300 })
		local _, instance = newWindowMoverWithMock({ behavior = { cursor = { afterMove = false } } }, win, { win })

		instance.maximizeWindow()

		assert.are.same({ x = 10, y = 20, w = 1200, h = 800 }, win.setFrameCalls[1].frame)
		assert.are.equal(0, win.setFrameCalls[1].duration)
		assert.are.equal(0, #win.maximizeCalls)
		assert.are.equal(1, win.raiseCalls)
		assert.are.equal(1, win.focusCalls)
	end)

	it("左中央右の cycle は 1/2、2/3、1/3 の順でサイズを切り替える", function()
		local screen = newScreen(1, { x = 0, y = 0, w = 1200, h = 900 })
		local win = newWindow(screen, { x = 50, y = 50, w = 500, h = 300 })
		local _, instance = newWindowMoverWithMock({ behavior = { cursor = { afterMove = false } } }, win, { win })

		instance.cycleLeft()
		instance.cycleLeft()
		instance.cycleLeft()
		instance.cycleLeft()
		instance.cycleCenter()
		instance.cycleCenter()
		instance.cycleRight()
		instance.cycleRight()

		assert.are.same({ x = 0, y = 0, w = 600, h = 900 }, win.setFrameCalls[1].frame)
		assert.are.same({ x = 0, y = 0, w = 800, h = 900 }, win.setFrameCalls[2].frame)
		assert.are.same({ x = 0, y = 0, w = 400, h = 900 }, win.setFrameCalls[3].frame)
		assert.are.same({ x = 0, y = 0, w = 600, h = 900 }, win.setFrameCalls[4].frame)
		assert.are.same({ x = 300, y = 0, w = 600, h = 900 }, win.setFrameCalls[5].frame)
		assert.are.same({ x = 200, y = 0, w = 800, h = 900 }, win.setFrameCalls[6].frame)
		assert.are.same({ x = 600, y = 0, w = 600, h = 900 }, win.setFrameCalls[7].frame)
		assert.are.same({ x = 400, y = 0, w = 800, h = 900 }, win.setFrameCalls[8].frame)
	end)

	it("cycle は手動リサイズ後に 1/2 から再開する", function()
		local screen = newScreen(1, { x = 0, y = 0, w = 1200, h = 900 })
		local win = newWindow(screen, { x = 50, y = 50, w = 500, h = 300 })
		local _, instance = newWindowMoverWithMock({ behavior = { cursor = { afterMove = false } } }, win, { win })

		instance.cycleLeft()
		instance.cycleLeft()
		win._frame = { x = 20, y = 30, w = 700, h = 500 }
		instance.cycleLeft()

		assert.are.same({ x = 0, y = 0, w = 600, h = 900 }, win.setFrameCalls[3].frame)
	end)

	it("UUID一致ディスプレイは設定キーマップで候補表示される", function()
		local screen = newScreen(1, { x = 0, y = 0, w = 1200, h = 800 }, "uuid-a")
		local win = newWindow(screen, { x = 100, y = 100, w = 200, h = 100 })
		local state, instance = newWindowMoverWithMock(selectedAreaOptions({
			["uuid-a"] = {
				full = "A",
				halfLeft = "S",
				halfHorizontalCenter = "D",
				halfRight = "F",
				thirdLeft = "Q",
				thirdHorizontalCenter = "W",
				thirdRight = "E",
				twoThirdsHorizontalCenter = "R",
			},
		}), win, { win })
		state.screens = { screen }

		instance.moveToSelectedArea()

		assert.are.same({ "A", "S", "D", "F", "Q", "W", "E", "R" }, canvasKeys(state))
		assert.are.equal(0, #state.webviews)

		sendKey(state, "s")

		assert.are.same({ x = 0, y = 0, w = 600, h = 800 }, win.setFrameCalls[1].frame)
	end)

	it("明示された上下方向の half エリアへ移動する", function()
		local screen = newScreen(1, { x = 0, y = 0, w = 600, h = 900 }, "uuid-a")
		local win = newWindow(screen, { x = 100, y = 100, w = 200, h = 100 })
		local state, instance = newWindowMoverWithMock(selectedAreaOptions({
			["uuid-a"] = {
				halfTop = "A",
				halfVerticalCenter = "S",
				halfBottom = "D",
			},
		}), win, { win })
		state.screens = { screen }

		instance.moveToSelectedArea()
		sendKey(state, "d")

		assert.are.same({ x = 0, y = 450, w = 600, h = 450 }, win.setFrameCalls[1].frame)
	end)

	it("画面の縦横比に関係なく明示方向を使う", function()
		local screen = newScreen(1, { x = 0, y = 0, w = 600, h = 900 }, "uuid-a")
		local win = newWindow(screen, { x = 100, y = 100, w = 200, h = 100 })
		local state, instance = newWindowMoverWithMock(selectedAreaOptions({
			["uuid-a"] = {
				halfRight = "F",
				thirdBottom = "B",
			},
		}), win, { win })
		state.screens = { screen }

		instance.moveToSelectedArea()
		sendKey(state, "f")

		assert.are.same({ x = 300, y = 0, w = 300, h = 900 }, win.setFrameCalls[1].frame)
	end)

	it("twoThirdsVerticalCenter と固定サイズ Center へ移動する", function()
		local screen = newScreen(1, { x = 0, y = 0, w = 1200, h = 900 }, "uuid-a")
		local win = newWindow(screen, { x = 100, y = 100, w = 200, h = 100 })
		local state, instance = newWindowMoverWithMock(selectedAreaOptions({
			["uuid-a"] = {
				twoThirdsVerticalCenter = "V",
				["800x600Center"] = "M",
			},
		}), win, { win })
		state.screens = { screen }

		instance.moveToSelectedArea()
		assert.is_true(canvasHasText(state, "800x600"))
		sendKey(state, "v")
		assert.are.same({ x = 0, y = 150, w = 1200, h = 600 }, win.setFrameCalls[1].frame)

		instance.moveToSelectedArea()
		sendKey(state, "m")
		assert.are.same({ x = 200, y = 150, w = 800, h = 600 }, win.setFrameCalls[2].frame)
	end)

	it("固定サイズ Center はディスプレイサイズを上限にする", function()
		local screen = newScreen(1, { x = 10, y = 20, w = 1200, h = 900 }, "uuid-a")
		local win = newWindow(screen, { x = 100, y = 100, w = 200, h = 100 })
		local state, instance = newWindowMoverWithMock(selectedAreaOptions({
			["uuid-a"] = {
				["1920x1080Center"] = "M",
			},
		}), win, { win })
		state.screens = { screen }

		instance.moveToSelectedArea()
		sendKey(state, "m")

		assert.are.same({ x = 10, y = 20, w = 1200, h = 900 }, win.setFrameCalls[1].frame)
	end)

	it("selectedArea ヒントは横方向に重なる列だけ縦方向にずらす", function()
		local screen = newScreen(1, { x = 0, y = 0, w = 2560, h = 1440 }, "uuid-a")
		local win = newWindow(screen, { x = 100, y = 100, w = 200, h = 100 })
		local state, instance = newWindowMoverWithMock(selectedAreaOptions({
			["uuid-a"] = {
				full = "KD",
				halfLeft = "KH",
				halfRight = "KL",
				twoThirdsHorizontalCenter = "KS",
				halfHorizontalCenter = "KA",
				["1920x1080Center"] = "K1",
				["1280x720Center"] = "K2",
			},
		}), win, { win })
		state.screens = { screen }

		instance.moveToSelectedArea()

		local framesByKey = canvasFramesByKey(state)
		assert.are.equal(framesByKey.KH.y, framesByKey.KL.y)
		for keyA, frameA in pairs(framesByKey) do
			for keyB, frameB in pairs(framesByKey) do
				if keyA < keyB and framesOverlapHorizontally(frameA, frameB) then
					assert.is_true(framesHaveVerticalGap(frameA, frameB, 8))
				end
			end
		end
	end)

	it("UUID未登録ディスプレイは default 参照先のキーマップを使う", function()
		local screen = newScreen(1, { x = 0, y = 0, w = 1200, h = 800 }, "unknown")
		local win = newWindow(screen, { x = 100, y = 100, w = 200, h = 100 })
		local state, instance = newWindowMoverWithMock(selectedAreaOptions({
			["uuid-a"] = {
				full = "A",
				halfRight = "F",
			},
		}, "uuid-a"), win, { win })
		state.screens = { screen }

		instance.moveToSelectedArea()

		assert.are.same({ "A", "F" }, canvasKeys(state))
		assert.are.equal(0, #state.webviews)
	end)

	it("default未指定のUUID未登録ディスプレイにはUUID案内を表示する", function()
		local screen = newScreen(1, { x = 0, y = 0, w = 1200, h = 800 }, "unknown-uuid", "Guest Display")
		local win = newWindow(screen, { x = 100, y = 100, w = 200, h = 100 })
		local state, instance = newWindowMoverWithMock(selectedAreaOptions({}), win, { win })
		state.screens = { screen }

		instance.moveToSelectedArea()

		assert.are.equal(0, #state.canvases)
		assert.are.equal(1, #state.webviews)
		assert.is_truthy(state.webviews[1]._html:match("unknown%-uuid"))
		assert.is_truthy(state.webviews[1]._html:match("Guest Display"))
		assert.is_truthy(state.webviews[1]._html:match("Copy template"))
		assert.is_truthy(state.webviews[1]._html:match("thirdLeft"))
		assert.is_truthy(state.webviews[1]._html:match("thirdHorizontalCenter"))
		assert.is_truthy(state.webviews[1]._html:match("thirdRight"))
		assert.is_truthy(state.webviews[1]._html:match("thirdTop"))
		assert.is_truthy(state.webviews[1]._html:match("thirdVerticalCenter"))
		assert.is_truthy(state.webviews[1]._html:match("thirdBottom"))
		assert.is_truthy(state.webviews[1]._html:match("twoThirdsHorizontalCenter"))
		assert.is_truthy(state.webviews[1]._html:match("twoThirdsVerticalCenter"))
		assert.is_true(state.eventtaps[1].started)
	end)

	it("UUID案内のCopy templateは設定テンプレートをクリップボードに書き込む", function()
		local screen = newScreen(1, { x = 0, y = 0, w = 1200, h = 800 }, "unknown-uuid", "Guest Display")
		local win = newWindow(screen, { x = 100, y = 100, w = 200, h = 100 })
		local state, instance = newWindowMoverWithMock(selectedAreaOptions({}), win, { win })
		state.screens = { screen }

		instance.moveToSelectedArea()

		assert.are.equal("jinraiCopyTemplate", state.webviews[1]._usercontent._name)
		state.webviews[1]._usercontent._callback([[
-- Add this under selectedArea.screens
["unknown-uuid"] = {
  full = "A",
},
]])

		assert.are.equal(1, #state.pasteboardWrites)
		assert.is_truthy(state.pasteboardWrites[1]:match("unknown%-uuid"))
		assert.is_truthy(state.pasteboardWrites[1]:match('full = "A"'))
	end)

	it("UUID案内はテンプレートが見やすい高さで表示する", function()
		local screen = newScreen(1, { x = 0, y = 0, w = 1200, h = 800 }, "unknown")
		local win = newWindow(screen, { x = 100, y = 100, w = 200, h = 100 })
		local state, instance = newWindowMoverWithMock(selectedAreaOptions({}), win, { win })
		state.screens = { screen }

		instance.moveToSelectedArea()

		assert.are.equal(480, state.webviews[1]._frame.h)
	end)

	it("default候補が既存候補と衝突する未登録ディスプレイにはUUID案内を表示する", function()
		local configured = newScreen(1, { x = 0, y = 0, w = 1200, h = 800 }, "uuid-a")
		local unknown = newScreen(2, { x = 1200, y = 0, w = 1200, h = 800 }, "unknown")
		local win = newWindow(configured, { x = 100, y = 100, w = 200, h = 100 })
		local state, instance = newWindowMoverWithMock(selectedAreaOptions({
			["uuid-a"] = {
				full = "A",
				halfLeft = "S",
			},
		}, "uuid-a"), win, { win })
		state.screens = { configured, unknown }

		instance.moveToSelectedArea()

		assert.are.same({ "A", "S" }, canvasKeys(state))
		assert.are.equal(1, #state.webviews)
		assert.is_truthy(state.webviews[1]._html:match("unknown"))
	end)

	it("selectedArea は visibleWindows を参照しない", function()
		local screen = newScreen(1, { x = 0, y = 0, w = 1200, h = 800 }, "uuid-a")
		local win = newWindow(screen, { x = 100, y = 100, w = 200, h = 100 })
		local state, instance = newWindowMoverWithMock(selectedAreaOptions({
			["uuid-a"] = {
				full = "A",
			},
		}), win, { win })
		state.screens = { screen }
		_G.hs.window.visibleWindows = function()
			error("visibleWindows should not be called")
		end

		instance.moveToSelectedArea()

		assert.are.same({ "A" }, canvasKeys(state))
	end)

	it("selectedArea.hints.show=false なら候補canvasを描画せずキー入力で移動する", function()
		local screen = newScreen(1, { x = 0, y = 0, w = 1200, h = 800 }, "uuid-a")
		local win = newWindow(screen, { x = 100, y = 100, w = 200, h = 100 })
		local state, instance = newWindowMoverWithMock(selectedAreaOptions({
			["uuid-a"] = {
				halfLeft = "A",
			},
		}, nil, { hints = { show = false } }), win, { win })
		state.screens = { screen }

		instance.moveToSelectedArea()

		assert.are.equal(0, #state.canvases)
		assert.are.equal(0, #state.webviews)
		assert.is_true(state.eventtaps[1].started)

		assert.is_true(sendMouseDown(state, { x = 10, y = 10 }))
		assert.is_true(state.eventtaps[1].stopped)

		instance.moveToSelectedArea()
		sendKey(state, "a")

		assert.are.same({ x = 0, y = 0, w = 600, h = 800 }, win.setFrameCalls[1].frame)
	end)

	it("UUID案内内のクリックは消費せず候補外クリックは閉じる", function()
		local screen = newScreen(1, { x = 0, y = 0, w = 1200, h = 800 }, "unknown")
		local win = newWindow(screen, { x = 100, y = 100, w = 200, h = 100 })
		local state, instance = newWindowMoverWithMock(selectedAreaOptions({}), win, { win })
		state.screens = { screen }

		instance.moveToSelectedArea()
		local infoFrame = state.webviews[1]._frame

		assert.is_false(sendMouseDown(state, { x = infoFrame.x + 10, y = infoFrame.y + 10 }))
		assert.is_nil(state.webviews[1]._deleted)

		assert.is_true(sendMouseDown(state, { x = 10, y = 10 }))
		assert.is_true(state.webviews[1]._deleted)
	end)

	it("selectedArea の候補クリックは移動せずイベントだけ消費する", function()
		local screen = newScreen(1, { x = 0, y = 0, w = 1200, h = 800 }, "uuid-a")
		local win = newWindow(screen, { x = 100, y = 100, w = 200, h = 100 })
		local state, instance = newWindowMoverWithMock(selectedAreaOptions({
			["uuid-a"] = {
				halfLeft = "A",
			},
		}), win, { win })
		state.screens = { screen }

		instance.moveToSelectedArea()

		assert.is_true(sendMouseDown(state, { x = 10, y = 10 }))
		assert.are.equal(0, #win.setFrameCalls)
		assert.is_nil(state.canvases[1]._deleted)
	end)

	it("Escape と teardown は canvas と webview を解放する", function()
		local configured = newScreen(1, { x = 0, y = 0, w = 1200, h = 800 }, "uuid-a")
		local unknown = newScreen(2, { x = 1200, y = 0, w = 1200, h = 800 }, "unknown")
		local win = newWindow(configured, { x = 100, y = 100, w = 200, h = 100 })
		local state, instance = newWindowMoverWithMock(selectedAreaOptions({
			["uuid-a"] = {
				full = "A",
			},
		}), win, { win })
		state.screens = { configured, unknown }

		instance.moveToSelectedArea()
		sendKey(state, "escape")

		assert.is_true(state.canvases[1]._deleted)
		assert.is_true(state.webviews[1]._deleted)
		assert.is_true(state.eventtaps[1].stopped)

		instance.moveToSelectedArea()
		local canvas = state.canvases[2]
		local webview = state.webviews[2]
		instance.teardown()

		assert.is_true(canvas._deleted)
		assert.is_true(webview._deleted)
	end)

	it("screenInfos は UUID/name/id/frame を返す", function()
		local screen = newScreen(1, { x = 0, y = 0, w = 1200, h = 800 }, "uuid-a", "Main")
		local win = newWindow(screen)
		local state, instance = newWindowMoverWithMock({}, win, { win })
		state.screens = { screen }

		assert.are.same({
			{
				uuid = "uuid-a",
				name = "Main",
				id = 1,
				frame = { x = 0, y = 0, w = 1200, h = 800 },
			},
		}, instance.screenInfos())
	end)
end)
