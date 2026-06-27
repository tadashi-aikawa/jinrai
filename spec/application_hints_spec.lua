describe("application_hints", function()
	local originalHs

	before_each(function()
		originalHs = _G.hs
	end)

	after_each(function()
		_G.hs = originalHs
	end)

	local function newWindow(id, focusCount)
		return {
			id = function()
				return id
			end,
			isStandard = function()
				return true
			end,
			focus = function()
				focusCount.count = focusCount.count + 1
			end,
		}
	end

	local function installHsMock(app, options)
		options = options or {}
		local keyWatcher
		local keyStrokes = {}
		local launched = {}
		local alerts = {}
		local timers = {}
		local canvasFrames = {}
		local canvasLevels = {}
		local function canvas(frame)
			table.insert(canvasFrames, frame)
			local value = {}
			function value:level(level)
				table.insert(canvasLevels, level)
				return self
			end
			function value:behavior()
				return self
			end
			function value:appendElements(...)
				for _, element in ipairs({ ... }) do
					table.insert(self, element)
				end
				return self
			end
			function value:show()
				if options.onCanvasShow then
					options.onCanvasShow()
				end
				return self
			end
			function value:delete()
				self.deleted = true
			end
			return value
		end

		_G.hs = {
			spoons = {
				resourcePath = function(path)
					return "./Jinrai.spoon/" .. path
				end,
			},
			application = {
				get = function()
					return app
				end,
				nameForBundleID = function()
					return "Example"
				end,
				launchOrFocusByBundleID = function(bundleID)
					table.insert(launched, bundleID)
					return true
				end,
			},
			hotkey = {
				bind = function()
					return { delete = function() end }
				end,
			},
			eventtap = {
				event = { types = { keyDown = 1 } },
				new = function(_, callback)
					keyWatcher = {
						callback = callback,
						start = function() end,
						stop = function() end,
					}
					return keyWatcher
				end,
				keyStroke = function(modifiers, key, delay, targetApp)
					table.insert(keyStrokes, {
						modifiers = modifiers,
						key = key,
						delay = delay,
						targetApp = targetApp,
					})
					if options.onKeyStroke then
						options.onKeyStroke(modifiers, key, targetApp)
					end
				end,
			},
			keycodes = {
				map = options.keyMap or { [8] = "c" },
			},
			window = {
				focusedWindow = function()
					return options.focusedWindow and options.focusedWindow() or nil
				end,
			},
			screen = {
				mainScreen = function()
					return {
						frame = function()
							return options.mainScreenFrame or { x = 0, y = 0, w = 1440, h = 900 }
						end,
					}
				end,
			},
			canvas = setmetatable({
				windowLevels = { overlay = 3 },
			}, {
				__index = {
					new = canvas,
				},
			}),
			image = {
				imageFromAppBundle = function()
					return {}
				end,
			},
			alert = {
				show = function(message)
					table.insert(alerts, message)
				end,
			},
			timer = {
				doEvery = function(_, callback)
					local timer = { callback = callback, stop = function(self) self.stopped = true end }
					table.insert(timers, timer)
					return timer
				end,
				doAfter = function(_, callback)
					local timer = { callback = callback, stop = function(self) self.stopped = true end }
					table.insert(timers, timer)
					return timer
				end,
			},
		}

		return {
			keyWatcher = function()
				return keyWatcher
			end,
			keyStrokes = keyStrokes,
			launched = launched,
			alerts = alerts,
			timers = timers,
			canvasFrames = canvasFrames,
			canvasLevels = canvasLevels,
		}
	end

	it("callback指定時はキー送信せず生成ウィンドウだけをフォーカスする", function()
		local focusCount = { count = 0 }
		local windows = { newWindow(1, focusCount) }
		local activateCount = 0
		local app = {
			allWindows = function()
				return windows
			end,
			activate = function()
				activateCount = activateCount + 1
			end,
			name = function()
				return "Example"
			end,
		}
		local mocks = installHsMock(app)
		local mod = dofile("./Jinrai.spoon/application_hints.lua")
		local instance = mod.new({
			apps = {
				{
					bundleID = "com.example.app",
					key = "C",
					newWindow = {
						callback = function()
							table.insert(windows, newWindow(2, focusCount))
						end,
					},
				},
			},
		})

		assert.is_true(instance.show())
		mocks.keyWatcher().callback({ getKeyCode = function() return 8 end })

		assert.are.equal(0, activateCount)
		assert.are.equal(0, #mocks.keyStrokes)
		assert.are.equal(1, focusCount.count)
	end)

	it("callback指定時にアプリ未起動ならapp=nilでcallbackを呼びlaunchしない", function()
		local receivedApp = "not_called"
		local mocks = installHsMock(nil)
		local mod = dofile("./Jinrai.spoon/application_hints.lua")
		local callbackInvoked = false
		local instance = mod.new({
			apps = {
				{
					bundleID = "com.example.app",
					key = "C",
					newWindow = {
						callback = function(app)
							callbackInvoked = true
							receivedApp = app
						end,
					},
				},
			},
		})

		assert.is_true(instance.show())
		mocks.keyWatcher().callback({ getKeyCode = function() return 8 end })

		assert.is_true(callbackInvoked)
		assert.is_nil(receivedApp)
		assert.are.equal(0, #mocks.launched)
	end)

	it("newWindow未指定時はアプリをアクティブ化せず直接Cmd+Nを送る", function()
		local focusCount = { count = 0 }
		local windows = { newWindow(1, focusCount) }
		local activateCount = 0
		local app = {
			allWindows = function()
				return windows
			end,
			activate = function()
				activateCount = activateCount + 1
			end,
			name = function()
				return "Example"
			end,
		}
		local mocks = installHsMock(app, {
			onKeyStroke = function()
				table.insert(windows, newWindow(2, focusCount))
			end,
		})
		local mod = dofile("./Jinrai.spoon/application_hints.lua")
		local instance = mod.new({
			apps = {
				{ bundleID = "com.example.app", key = "C" },
			},
		})

		assert.is_true(instance.show())
		mocks.keyWatcher().callback({ getKeyCode = function() return 8 end })

		assert.are.equal(0, activateCount)
		assert.are.equal("n", mocks.keyStrokes[1].key)
		assert.are.same({ "cmd" }, mocks.keyStrokes[1].modifiers)
		assert.is_nil(mocks.keyStrokes[1].delay)
		assert.are.equal(app, mocks.keyStrokes[1].targetApp)
		assert.are.equal(1, focusCount.count)
	end)

	it("Ghosttyは設定したCtrl+Nを対象アプリへ直接送る", function()
		local focusCount = { count = 0 }
		local windows = { newWindow(1, focusCount) }
		local app = {
			allWindows = function()
				return windows
			end,
			name = function()
				return "Ghostty"
			end,
		}
		local mocks = installHsMock(app, {
			onKeyStroke = function()
				table.insert(windows, newWindow(2, focusCount))
			end,
		})
		local mod = dofile("./Jinrai.spoon/application_hints.lua")
		local instance = mod.new({
			apps = {
				{
					bundleID = "com.mitchellh.ghostty",
					key = "C",
					newWindow = {
						hotkey = { modifiers = { "ctrl" }, key = "n" },
					},
				},
			},
		})

		assert.is_true(instance.show())
		mocks.keyWatcher().callback({ getKeyCode = function() return 8 end })

		assert.are.same({ "ctrl" }, mocks.keyStrokes[1].modifiers)
		assert.are.equal("n", mocks.keyStrokes[1].key)
		assert.are.equal(app, mocks.keyStrokes[1].targetApp)
		assert.are.equal(1, focusCount.count)
	end)

	it("新規ウィンドウIDを既存IDとの差分から選べる", function()
		local mod = dofile("./Jinrai.spoon/application_hints.lua")
		local focusCount = { count = 0 }
		local old = newWindow(1, focusCount)
		local created = newWindow(2, focusCount)

		local found = mod._test.findNewWindow({ old, created }, { [1] = true })

		assert.are.equal(created, found)
	end)

	it("app:allWindowsの更新が遅くてもフォーカス済み新規ウィンドウを検出する", function()
		local focusCount = { count = 0 }
		local old = newWindow(1, focusCount)
		local app = {
			allWindows = function()
				return { old }
			end,
			bundleID = function()
				return "com.mitchellh.ghostty"
			end,
		}
		local focused = newWindow(2, focusCount)
		focused.application = function()
			return app
		end
		installHsMock(app, {
			focusedWindow = function()
				return focused
			end,
		})
		local mod = dofile("./Jinrai.spoon/application_hints.lua")

		local detected = mod._test.collectDetectedWindows(app, "com.mitchellh.ghostty")

		assert.are.equal(2, #detected)
		assert.are.equal(focused, detected[2])
	end)

	it("新規ウィンドウのフォーカス反映が遅い場合はWAITを維持して再試行する", function()
		local focusCount = { count = 0 }
		local currentFocused
		local old = newWindow(1, focusCount)
		local created = newWindow(2, focusCount)
		local originalFocus = created.focus
		created.focus = function()
			originalFocus()
			if focusCount.count >= 2 then
				currentFocused = created
			else
				currentFocused = old
			end
		end
		local windows = { old }
		local app = {
			allWindows = function()
				return windows
			end,
			name = function()
				return "Chrome"
			end,
		}
		local mocks = installHsMock(app, {
			focusedWindow = function()
				return currentFocused
			end,
			onKeyStroke = function()
				table.insert(windows, created)
			end,
		})
		local mod = dofile("./Jinrai.spoon/application_hints.lua")
		local instance = mod.new({
			apps = {
				{ bundleID = "com.google.Chrome", key = "C" },
			},
		})

		assert.is_true(instance.show())
		mocks.keyWatcher().callback({ getKeyCode = function() return 8 end })

		assert.are.equal(1, focusCount.count)
		assert.is_false(mocks.timers[1].stopped == true)

		mocks.timers[1].callback()

		assert.are.equal(2, focusCount.count)
		assert.is_true(mocks.timers[1].stopped)
	end)

	it("新規ウィンドウが生成されない場合はタイムアウトをアラート表示する", function()
		local focusCount = { count = 0 }
		local app = {
			allWindows = function()
				return { newWindow(1, focusCount) }
			end,
			name = function()
				return "Example"
			end,
		}
		local mocks = installHsMock(app)
		local mod = dofile("./Jinrai.spoon/application_hints.lua")
		local instance = mod.new({
			windowWaitTimeout = 1,
			apps = {
				{ bundleID = "com.example.app", key = "C" },
			},
		})

		assert.is_true(instance.show())
		mocks.keyWatcher().callback({ getKeyCode = function() return 8 end })
		mocks.timers[2].callback()

		assert.are.equal(1, #mocks.alerts)
		assert.is_truthy(mocks.alerts[1]:match("timed out waiting for a new window"))
	end)

	it("表示中の開始キーでJinraiModeへ入りアプリ選択後も継続する", function()
		local focusCount = { count = 0 }
		local windows = { newWindow(1, focusCount) }
		local started = 0
		local selected
		local app = {
			allWindows = function()
				return windows
			end,
			name = function()
				return "Example"
			end,
		}
		local mocks = installHsMock(app, {
			keyMap = {
				[8] = "c",
				[49] = "space",
			},
		})
		local mod = dofile("./Jinrai.spoon/application_hints.lua")
		local instance = mod.new({
			apps = {
				{
					bundleID = "com.example.app",
					key = "C",
					newWindow = {
						callback = function()
							table.insert(windows, newWindow(2, focusCount))
						end,
					},
				},
			},
			internal = {
				jinraiModeKey = "space",
				onStartJinraiMode = function()
					started = started + 1
				end,
				onSelectInJinraiMode = function(win)
					selected = win
				end,
			},
		})

		assert.is_true(instance.show())
		mocks.keyWatcher().callback({ getKeyCode = function() return 49 end })
		mocks.keyWatcher().callback({ getKeyCode = function() return 8 end })

		assert.are.equal(1, started)
		assert.are.equal(windows[2], selected)
	end)

	it("Application Hintsで開始したJinraiModeはEscapeで終了する", function()
		local canceled = 0
		local app = {
			allWindows = function()
				return {}
			end,
			name = function()
				return "Example"
			end,
		}
		local mocks = installHsMock(app, {
			keyMap = {
				[49] = "space",
				[53] = "escape",
			},
		})
		local mod = dofile("./Jinrai.spoon/application_hints.lua")
		local instance = mod.new({
			apps = {
				{ bundleID = "com.example.app", key = "C" },
			},
			internal = {
				jinraiModeKey = "space",
				onStartJinraiMode = function() end,
				onCancelJinraiMode = function()
					canceled = canceled + 1
				end,
			},
		})

		assert.is_true(instance.show())
		mocks.keyWatcher().callback({ getKeyCode = function() return 49 end })
		mocks.keyWatcher().callback({ getKeyCode = function() return 53 end })

		assert.are.equal(1, canceled)
	end)

	it("アクティブウィンドウ中央にヒントを表示する", function()
		local screen = {
			frame = function()
				return { x = 0, y = 0, w = 1440, h = 900 }
			end,
		}
		local focusedWindow = {
			screen = function()
				return screen
			end,
			frame = function()
				return { x = 100, y = 100, w = 600, h = 400 }
			end,
		}
		local mocks = installHsMock(nil, {
			focusedWindow = function()
				return focusedWindow
			end,
		})
		local mod = dofile("./Jinrai.spoon/application_hints.lua")
		local instance = mod.new({
			apps = {
				{ bundleID = "com.example.app", key = "C" },
			},
		})

		assert.is_true(instance.show())

		assert.are.same({ x = 290, y = 244, w = 220, h = 112 }, mocks.canvasFrames[1])
	end)

	it("アクティブウィンドウ中央基準の表示を画面内へ補正する", function()
		local screen = {
			frame = function()
				return { x = 0, y = 0, w = 1440, h = 900 }
			end,
		}
		local focusedWindow = {
			screen = function()
				return screen
			end,
			frame = function()
				return { x = 1300, y = 800, w = 200, h = 100 }
			end,
		}
		local mocks = installHsMock(nil, {
			focusedWindow = function()
				return focusedWindow
			end,
		})
		local mod = dofile("./Jinrai.spoon/application_hints.lua")
		local instance = mod.new({
			apps = {
				{ bundleID = "com.example.app", key = "C" },
			},
		})

		assert.is_true(instance.show())

		assert.are.same({ x = 1220, y = 788, w = 220, h = 112 }, mocks.canvasFrames[1])
	end)

	it("アクティブウィンドウがなければメイン画面中央に表示する", function()
		local mocks = installHsMock(nil)
		local mod = dofile("./Jinrai.spoon/application_hints.lua")
		local instance = mod.new({
			apps = {
				{ bundleID = "com.example.app", key = "C" },
			},
		})

		assert.is_true(instance.show())

		assert.are.same({ x = 610, y = 394, w = 220, h = 112 }, mocks.canvasFrames[1])
	end)

	it("appearance.columnsで指定した件数ごとに折り返す", function()
		local mocks = installHsMock(nil)
		local mod = dofile("./Jinrai.spoon/application_hints.lua")
		local instance = mod.new({
			appearance = {
				columns = 2,
			},
			apps = {
				{ bundleID = "com.example.a", key = "A" },
				{ bundleID = "com.example.b", key = "B" },
				{ bundleID = "com.example.c", key = "C" },
			},
		})

		assert.is_true(instance.show())

		assert.are.same({ x = 494, y = 332, w = 220, h = 112 }, mocks.canvasFrames[1])
		assert.are.same({ x = 726, y = 332, w = 220, h = 112 }, mocks.canvasFrames[2])
		assert.are.same({ x = 494, y = 456, w = 220, h = 112 }, mocks.canvasFrames[3])
	end)

	it("JinraiModeの表示完了通知後にカードを前面表示する", function()
		local events = {}
		installHsMock(nil, {
			onCanvasShow = function()
				table.insert(events, "canvas")
			end,
		})
		local mod = dofile("./Jinrai.spoon/application_hints.lua")
		local instance = mod.new({
			apps = {
				{ bundleID = "com.example.app", key = "C" },
			},
			internal = {
				onShowInJinraiMode = function()
					table.insert(events, "combo")
				end,
			},
		})

		assert.is_true(instance.show({ jinraiMode = true }))

		assert.are.same({ "combo", "canvas" }, events)
	end)

	it("JinraiMode開始直後はCOMBO表示を進めずカードを表示する", function()
		local events = {}
		installHsMock(nil, {
			onCanvasShow = function()
				table.insert(events, "canvas")
			end,
		})
		local mod = dofile("./Jinrai.spoon/application_hints.lua")
		local instance = mod.new({
			apps = {
				{ bundleID = "com.example.app", key = "C" },
			},
			internal = {
				onShowInJinraiMode = function()
					table.insert(events, "combo")
				end,
			},
		})

		assert.is_true(instance.show({
			jinraiMode = true,
			advanceJinraiModeCombo = false,
		}))

		assert.are.same({ "canvas" }, events)
	end)

	it("JinraiModeの表示より前面のlevelを使用する", function()
		local mocks = installHsMock(nil)
		local mod = dofile("./Jinrai.spoon/application_hints.lua")
		local instance = mod.new({
			apps = {
				{ bundleID = "com.example.app", key = "C" },
			},
		})

		assert.is_true(instance.show())

		assert.are.equal(5, mocks.canvasLevels[1])
	end)
end)
