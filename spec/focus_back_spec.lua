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

	it("centerCursor=true なら戻り先ウィンドウ中央にカーソル移動する", function()
		local win1 = hsMock.newWindow(1, {
			bundleID = "com.example.a",
			appName = "A",
			frame = { x = 100, y = 40, w = 300, h = 200 },
		})
		local win2 = hsMock.newWindow(2, { bundleID = "com.example.b", appName = "B" })
		local mock, instance = newFocusBackWithMock({
			behavior = {
				centerCursor = true,
			},
		}, win1)

		mock.emitWindowFocused(win2)
		mock.state.hotkeys[1].callback()

		assert.are.equal(1, #mock.state.mousePositions)
		assert.are.same({ x = 250, y = 140 }, mock.state.mousePositions[1])

		instance.teardown()
	end)

	it("historyScope=application では同一アプリ内移動を履歴更新しない", function()
		local win1 = hsMock.newWindow(1, { bundleID = "com.example.a", appName = "A" })
		local win2 = hsMock.newWindow(2, { bundleID = "com.example.a", appName = "A" })
		local mock, instance = newFocusBackWithMock({
			stateSync = {
				historyScope = "application",
			},
		}, win1)

		mock.emitWindowFocused(win2)
		mock.state.hotkeys[1].callback()

		assert.are.equal(0, win1._focusCalls)

		instance.teardown()
	end)

	it("stateSync.targetApps の対象アプリだけ同期する", function()
		local win1 = hsMock.newWindow(1, { bundleID = "com.example.main", appName = "Main" })
		local nonTargetWin = hsMock.newWindow(2, { bundleID = "com.example.other", appName = "Other" })
		local targetWin = hsMock.newWindow(3, { bundleID = "com.example.target", appName = "Target" })
		local mock, instance = newFocusBackWithMock({
			stateSync = {
				interval = 0.1,
				targetApps = { "com.example.target" },
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
	end)

	it("teardown で hotkey/timer/subscription/urlEvent を解放する", function()
		local win1 = hsMock.newWindow(1, { bundleID = "com.example.a", appName = "A" })
		local mock, instance = newFocusBackWithMock({
			urlEvent = { name = "focus_back" },
			stateSync = {},
		}, win1)

		assert.are.equal("function", type(mock.state.urlBindings.focus_back))
		assert.are.equal(1, #mock.state.hotkeys)
		assert.are.equal(1, #mock.state.timers)

		instance.teardown()

		assert.is_true(mock.state.hotkeys[1].deleted)
		assert.is_true(mock.state.timers[1].stopped)
		assert.are.equal(nil, mock.state.urlBindings.focus_back)
		assert.are.equal(1, #mock.state.unsubscriptions)
		assert.are.equal(mock.hs.window.filter.windowFocused, mock.state.unsubscriptions[1].event)
	end)
end)
