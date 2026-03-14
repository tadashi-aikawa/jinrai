local hsMock = dofile("./spec/helpers/hs_focus_border_mock.lua")

describe("focus_border", function()
	local originalHs

	before_each(function()
		originalHs = _G.hs
	end)

	after_each(function()
		_G.hs = originalHs
	end)

	local function newFocusBorderWithMock(options)
		local mock = hsMock.new()
		_G.hs = mock.hs
		local module = dofile("./Jinrai.spoon/focus_border.lua")
		return mock, module.new(options or {})
	end

	it("同一 Space では即時に枠を表示する", function()
		local win1 = hsMock.newWindow(1)
		local win2 = hsMock.newWindow(2)
		local mock, instance = newFocusBorderWithMock({})
		mock.setWindowSpaces(win1, { 1 })
		mock.setWindowSpaces(win2, { 1 })

		mock.emitWindowFocused(win1)
		assert.are.equal(1, #mock.state.canvases)
		assert.are.equal(0, #mock.state.delayTimers)

		mock.emitWindowFocused(win2)
		assert.are.equal(2, #mock.state.canvases)
		assert.are.equal(0, #mock.state.delayTimers)

		instance.teardown()
	end)

	it("別 Space では遅延後に枠を表示する", function()
		local win1 = hsMock.newWindow(1)
		local win2 = hsMock.newWindow(2)
		local mock, instance = newFocusBorderWithMock({
			animation = {
				spaceSwitchDelay = 0.42,
			},
		})
		mock.setWindowSpaces(win1, { 1 })
		mock.setWindowSpaces(win2, { 2 })

		mock.emitWindowFocused(win1)
		assert.are.equal(1, #mock.state.canvases)

		mock.emitWindowFocused(win2)
		assert.are.equal(1, #mock.state.canvases)
		assert.are.equal(1, #mock.state.delayTimers)
		assert.are.equal(0.42, mock.state.delayTimers[1].interval)

		mock.state.delayTimers[1].callback()
		assert.are.equal(2, #mock.state.canvases)

		instance.teardown()
	end)

	it("Space 判定できない場合は即時表示する", function()
		local win1 = hsMock.newWindow(1)
		local win2 = hsMock.newWindow(2)
		local mock, instance = newFocusBorderWithMock({})
		mock.setWindowSpaces(win1, { 1 })

		mock.emitWindowFocused(win1)
		mock.emitWindowFocused(win2)

		assert.are.equal(2, #mock.state.canvases)
		assert.are.equal(0, #mock.state.delayTimers)

		instance.teardown()
	end)

	it("遅延待ち中に別フォーカスが来たら古い予約を止める", function()
		local win1 = hsMock.newWindow(1)
		local win2 = hsMock.newWindow(2)
		local win3 = hsMock.newWindow(3)
		local mock, instance = newFocusBorderWithMock({})
		mock.setWindowSpaces(win1, { 1 })
		mock.setWindowSpaces(win2, { 2 })
		mock.setWindowSpaces(win3, { 1 })

		mock.emitWindowFocused(win1)
		mock.emitWindowFocused(win2)
		assert.are.equal(1, #mock.state.delayTimers)
		assert.is_false(mock.state.delayTimers[1].stopped)

		mock.emitWindowFocused(win3)
		assert.is_true(mock.state.delayTimers[1].stopped)
		assert.are.equal(1, #mock.state.canvases)
		assert.are.equal(2, #mock.state.delayTimers)
		assert.is_false(mock.state.delayTimers[2].stopped)

		instance.teardown()
	end)

	it("teardown で購読とタイマーと canvas を解放する", function()
		local win1 = hsMock.newWindow(1)
		local win2 = hsMock.newWindow(2)
		local mock, instance = newFocusBorderWithMock({})
		mock.setWindowSpaces(win1, { 1 })
		mock.setWindowSpaces(win2, { 2 })

		mock.emitWindowFocused(win1)
		mock.emitWindowFocused(win2)
		assert.are.equal(1, #mock.state.fadeTimers)
		assert.are.equal(1, #mock.state.delayTimers)

		instance.teardown()

		assert.is_true(mock.state.fadeTimers[1].stopped)
		assert.is_true(mock.state.delayTimers[1].stopped)
		assert.is_true(mock.state.canvases[1].deleted)
		assert.are.equal(1, #mock.state.unsubscriptions)
		assert.are.equal(mock.hs.window.filter.windowFocused, mock.state.unsubscriptions[1].event)
	end)
end)
