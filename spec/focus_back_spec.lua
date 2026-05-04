local hsMock = dofile("./spec/helpers/hs_focus_back_mock.lua")

describe("focus_back", function()
	local originalHs

	before_each(function()
		originalHs = _G.hs
	end)

	after_each(function()
		_G.hs = originalHs
	end)

	local function newFocusBackWithMock(options, currentWindow)
		local mock = hsMock.new()
		mock.setFocusedWindow(currentWindow)
		_G.hs = mock.hs
		local module = dofile("./Jinrai.spoon/focus_back.lua")
		return mock, module.new(options or {})
	end

	local function newFocusBackWithFocusHistoryOptions(focusHistoryOptions, currentWindow)
		local mock = hsMock.new()
		mock.setFocusedWindow(currentWindow)
		_G.hs = mock.hs
		local focusHistory = dofile("./Jinrai.spoon/focus_history.lua").new(focusHistoryOptions or {})
		local module = dofile("./Jinrai.spoon/focus_back.lua")
		return mock,
			module.new({
				internal = {
					focusHistory = focusHistory,
				},
			}),
			focusHistory
	end

	it("ホットキーで直前ウィンドウへトグルできる", function()
		local win1 = hsMock.newWindow(1, { bundleID = "com.example.a", appName = "A" })
		local win2 = hsMock.newWindow(2, { bundleID = "com.example.b", appName = "B" })
		local mock, instance = newFocusBackWithMock({}, win1)

		mock.emitWindowFocused(win2)

		assert.are.equal(1, #mock.state.hotkeys)
		mock.state.hotkeys[1].callback()
		assert.are.equal(1, win1._focusCalls)

		mock.state.hotkeys[1].callback()
		assert.are.equal(1, win2._focusCalls)

		instance.teardown()
	end)

	it("閉じたウィンドウをスキップして履歴を辿れる", function()
		local win1 = hsMock.newWindow(1, { bundleID = "com.example.a", appName = "A" })
		local win2 = hsMock.newWindow(2, { bundleID = "com.example.b", appName = "B" })
		local win3 = hsMock.newWindow(3, { bundleID = "com.example.c", appName = "C" })
		local mock, instance = newFocusBackWithMock({}, win1)

		mock.emitWindowFocused(win2)
		mock.emitWindowFocused(win3)

		-- ウィンドウCを閉じ、macOSがBを自動フォーカスする状況を再現
		win3._visible = false
		mock.emitWindowFocused(win2)

		-- Focus Backを実行すると、閉じたCとcurrentのBをスキップしてAにフォーカス
		mock.state.hotkeys[1].callback()
		assert.are.equal(1, win1._focusCalls)

		instance.teardown()
	end)

	it("staleなウィンドウ(visible=trueだがframe無効)をスキップする", function()
		local win1 = hsMock.newWindow(1, { bundleID = "com.example.chrome", appName = "Chrome" })
		local win2 = hsMock.newWindow(2, { bundleID = "com.example.chrome", appName = "Chrome" })
		local win3 = hsMock.newWindow(3, { bundleID = "com.example.chrome", appName = "Chrome" })
		local mock, instance = newFocusBackWithMock({}, win1)

		mock.emitWindowFocused(win2)
		mock.emitWindowFocused(win3)

		-- ウィンドウCを閉じるが、isVisible()はtrueを返し続ける(stale)
		-- frameが{0,0,0,0}になることでstaleを検出
		win3._frame = { x = 0, y = 0, w = 0, h = 0 }
		mock.emitWindowFocused(win2)

		-- staleなCをスキップし、currentのBもスキップし、Aにフォーカス
		mock.state.hotkeys[1].callback()
		assert.are.equal(1, win1._focusCalls)
		assert.are.equal(0, win3._focusCalls)

		instance.teardown()
	end)

	it("centerCursor=true なら戻り先ウィンドウ中央にカーソル移動する", function()
		local win1 = hsMock.newWindow(1, {
			bundleID = "com.example.a",
			appName = "A",
			frame = { x = 100, y = 40, w = 300, h = 200 },
		})
		local win2 = hsMock.newWindow(2, { bundleID = "com.example.b", appName = "B" })
		local mock, instance = newFocusBackWithMock({
			behavior = {
				cursor = {
					onSelect = true,
				},
			},
		}, win1)

		mock.emitWindowFocused(win2)
		mock.state.hotkeys[1].callback()

		assert.are.equal(1, #mock.state.mousePositions)
		assert.are.same({ x = 250, y = 140 }, mock.state.mousePositions[1])

		instance.teardown()
	end)

	it("macosNativeTabs.apps 対象アプリ内移動では履歴更新しない", function()
		local win1 = hsMock.newWindow(1, { bundleID = "com.example.a", appName = "A" })
		local win2 = hsMock.newWindow(2, { bundleID = "com.example.a", appName = "A" })
		local mock, instance, focusHistory = newFocusBackWithFocusHistoryOptions({
			macosNativeTabs = {
				apps = { "com.example.a" },
			},
		}, win1)

		mock.emitWindowFocused(win2)
		mock.state.hotkeys[1].callback()

		assert.are.equal(0, win1._focusCalls)

		instance.teardown()
		focusHistory:teardown()
	end)

	it("macosNativeTabs.apps の対象アプリだけ同期する", function()
		local win1 = hsMock.newWindow(1, { bundleID = "com.example.main", appName = "Main" })
		local nonTargetWin = hsMock.newWindow(2, { bundleID = "com.example.other", appName = "Other" })
		local targetWin = hsMock.newWindow(3, { bundleID = "com.example.target", appName = "Target" })
		local mock, instance, focusHistory = newFocusBackWithFocusHistoryOptions({
			macosNativeTabs = {
				stateSyncInterval = 0.1,
				apps = { "com.example.target" },
			},
		}, win1)

		assert.are.equal(1, #mock.state.timers)

		mock.setFocusedWindow(nonTargetWin)
		mock.state.timers[1].callback()
		mock.state.hotkeys[1].callback()
		assert.are.equal(0, win1._focusCalls)

		mock.setFocusedWindow(targetWin)
		mock.state.timers[1].callback()
		mock.state.hotkeys[1].callback()
		assert.are.equal(1, win1._focusCalls)

		instance.teardown()
		focusHistory:teardown()
	end)

	it("macosNativeTabs.stateSyncInterval 未指定時は 0.5 秒で同期する", function()
		local win1 = hsMock.newWindow(1, { bundleID = "com.example.main", appName = "Main" })
		local mock, instance, focusHistory = newFocusBackWithFocusHistoryOptions({
			macosNativeTabs = {
				apps = { "com.mitchellh.ghostty" },
			},
		}, win1)

		assert.are.equal(1, #mock.state.timers)
		assert.are.equal(0.5, mock.state.timers[1].interval)

		instance.teardown()
		focusHistory:teardown()
	end)

	it("macosNativeTabs.apps 対象アプリは focusBack 直前にも現在タブを同期する", function()
		local ghosttyTab1 = hsMock.newWindow(1, { bundleID = "com.mitchellh.ghostty", appName = "Ghostty" })
		local ghosttyTab2 = hsMock.newWindow(2, { bundleID = "com.mitchellh.ghostty", appName = "Ghostty" })
		local otherWin = hsMock.newWindow(3, { bundleID = "com.example.other", appName = "Other" })
		local mock, instance, focusHistory = newFocusBackWithFocusHistoryOptions({
			macosNativeTabs = {
				apps = { "com.mitchellh.ghostty" },
			},
		}, ghosttyTab1)

		mock.setFocusedWindow(otherWin)
		mock.emitWindowFocused(otherWin)
		mock.setFocusedWindow(ghosttyTab1)
		mock.emitWindowFocused(ghosttyTab1)

		mock.setFocusedWindow(ghosttyTab2)
		mock.state.hotkeys[1].callback()
		assert.are.equal(1, otherWin._focusCalls)

		mock.setFocusedWindow(otherWin)
		mock.state.hotkeys[1].callback()
		assert.are.equal(0, ghosttyTab1._focusCalls)
		assert.are.equal(1, ghosttyTab2._focusCalls)

		instance.teardown()
		focusHistory:teardown()
	end)

	it("teardown で hotkey/timer/subscription/urlEvent を解放する", function()
		local win1 = hsMock.newWindow(1, { bundleID = "com.example.a", appName = "A" })
		local mock, instance = newFocusBackWithMock({
			urlEvent = { name = "focus_back" },
		}, win1)

		assert.are.equal("function", type(mock.state.urlBindings.focus_back))
		assert.are.equal(1, #mock.state.hotkeys)
		assert.are.equal(0, #mock.state.timers)

		instance.teardown()

		assert.is_true(mock.state.hotkeys[1].deleted)
		assert.are.equal(nil, mock.state.urlBindings.focus_back)
		assert.are.equal(1, #mock.state.unsubscriptions)
		assert.are.equal(mock.hs.window.filter.windowFocused, mock.state.unsubscriptions[1].event)
	end)
end)
