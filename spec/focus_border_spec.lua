local hsMock = dofile("./spec/helpers/hs_focus_border_mock.lua")

describe("focus_border", function()
	local originalHs
	local CANVASES_PER_BORDER = 8

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
		assert.are.equal(CANVASES_PER_BORDER, #mock.state.canvases)
		assert.are.equal(0, #mock.state.delayTimers)

		mock.emitWindowFocused(win2)
		assert.are.equal(CANVASES_PER_BORDER * 2, #mock.state.canvases)
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
		assert.are.equal(CANVASES_PER_BORDER, #mock.state.canvases)

		mock.emitWindowFocused(win2)
		assert.are.equal(CANVASES_PER_BORDER, #mock.state.canvases)
		assert.are.equal(1, #mock.state.delayTimers)
		assert.are.equal(0.42, mock.state.delayTimers[1].interval)

		mock.state.delayTimers[1].callback()
		assert.are.equal(CANVASES_PER_BORDER * 2, #mock.state.canvases)

		instance.teardown()
	end)

	it("Space 判定できない場合は即時表示する", function()
		local win1 = hsMock.newWindow(1)
		local win2 = hsMock.newWindow(2)
		local mock, instance = newFocusBorderWithMock({})
		mock.setWindowSpaces(win1, { 1 })

		mock.emitWindowFocused(win1)
		mock.emitWindowFocused(win2)

		assert.are.equal(CANVASES_PER_BORDER * 2, #mock.state.canvases)
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
		assert.are.equal(CANVASES_PER_BORDER, #mock.state.canvases)
		assert.are.equal(2, #mock.state.delayTimers)
		assert.is_false(mock.state.delayTimers[2].stopped)

		instance.teardown()
	end)

	it("logo 指定時はデフォルト画像をウィンドウ中央に表示してフェードする", function()
		local win = hsMock.newWindow(1, { x = 100, y = 200, w = 900, h = 700 })
		local mock, instance = newFocusBorderWithMock({
			visual = {
				logo = {
					size = 200,
					alpha = 0.8,
				},
			},
			animation = {
				fadeSteps = 10,
			},
		})
		mock.setWindowSpaces(win, { 1 })

		mock.emitWindowFocused(win)

		assert.are.equal(CANVASES_PER_BORDER + 1, #mock.state.canvases)
		local logoCanvas = mock.state.canvases[CANVASES_PER_BORDER + 1]
		assert.are.same({ x = 450, y = 450, w = 200, h = 200 }, logoCanvas.frame)
		assert.are.equal("image", logoCanvas.elements[1].type)
		assert.are.equal("./Jinrai.spoon/jinrai.svg", logoCanvas.elements[1].image.path)
		assert.are.equal(0.8, logoCanvas.alphaValue)

		mock.state.fadeTimers[1].callback()
		assert.is_true(math.abs(0.72 - logoCanvas.alphaValue) < 0.0001)

		instance.teardown()
		assert.is_true(logoCanvas.deleted)
	end)

	it("logo.source がローカルパスの場合はその画像を表示する", function()
		local win = hsMock.newWindow(1)
		local mock, instance = newFocusBorderWithMock({
			visual = {
				logo = {
					source = "/tmp/logo.png",
				},
			},
		})
		mock.setWindowSpaces(win, { 1 })

		mock.emitWindowFocused(win)

		local logoCanvas = mock.state.canvases[CANVASES_PER_BORDER + 1]
		assert.are.equal("/tmp/logo.png", logoCanvas.elements[1].image.path)
		assert.are.same({ "/tmp/logo.png" }, mock.state.loadedImagePaths)
		assert.are.same({}, mock.state.loadedImageUrls)

		instance.teardown()
	end)

	it("logo.source がURLの場合はURL画像を表示する", function()
		local win = hsMock.newWindow(1)
		local mock, instance = newFocusBorderWithMock({
			visual = {
				logo = {
					source = "https://example.com/logo.png",
				},
			},
		})
		mock.setWindowSpaces(win, { 1 })

		mock.emitWindowFocused(win)

		local logoCanvas = mock.state.canvases[CANVASES_PER_BORDER + 1]
		assert.are.equal("https://example.com/logo.png", logoCanvas.elements[1].image.url)
		assert.are.same({}, mock.state.loadedImagePaths)
		assert.are.same({ "https://example.com/logo.png" }, mock.state.loadedImageUrls)

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
		for i = 1, CANVASES_PER_BORDER do
			assert.is_true(mock.state.canvases[i].deleted)
		end
		assert.are.equal(1, #mock.state.unsubscriptions)
		assert.are.equal(mock.hs.window.filter.windowFocused, mock.state.unsubscriptions[1].event)
	end)
end)
