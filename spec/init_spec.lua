describe("init", function()
	local originalDofile
	local originalJinraiState

	before_each(function()
		originalDofile = _G.dofile
		originalJinraiState = _G.__jinrai
	end)

	after_each(function()
		_G.dofile = originalDofile
		_G.__jinrai = originalJinraiState
	end)

	it("読み込み時に既存 __jinrai.teardown を実行する", function()
		local called = 0
		_G.__jinrai = {
			teardown = function()
				called = called + 1
			end,
		}

		dofile("./init.lua")
		assert.are.equal(1, called)
	end)

	it("setup で指定したモジュールだけ new される", function()
		_G.__jinrai = nil
		local init = dofile("./init.lua")
		local calls = {
			new = {},
			teardown = {},
			loadPaths = {},
		}

		_G.dofile = function(path)
			table.insert(calls.loadPaths, path)
			if path:match("focus_border.lua$") then
				return {
					new = function(options)
						calls.new.focus_border = options
						return {
							teardown = function()
								calls.teardown.focus_border = true
							end,
						}
					end,
				}
			end
			if path:match("window_hints.lua$") then
				return {
					new = function(options)
						calls.new.window_hints = options
						return {
							teardown = function()
								calls.teardown.window_hints = true
							end,
						}
					end,
				}
			end
			if path:match("focus_back.lua$") then
				return {
					new = function(options)
						calls.new.focus_back = options
						return {
							teardown = function()
								calls.teardown.focus_back = true
							end,
						}
					end,
				}
			end
			if path:match("focus_history.lua$") then
				return {
					new = function(options)
						calls.new.focus_history = options
						return {
							teardown = function()
								calls.teardown.focus_history = true
							end,
						}
					end,
				}
			end
			return originalDofile(path)
		end

		init.setup({
			focus_border = { borderWidth = 99 },
			focus_back = { hotkeyKey = "q" },
		})

		assert.are.same({ borderWidth = 99 }, calls.new.focus_border)
		assert.are.same({ stateSync = nil }, calls.new.focus_history)
		assert.are.equal("q", calls.new.focus_back.hotkeyKey)
		assert.is_truthy(calls.new.focus_back.focusHistory)
		assert.are.equal(nil, calls.new.window_hints)

		local joined = table.concat(calls.loadPaths, "\n")
		assert.is_truthy(joined:match("focus_border.lua"))
		assert.is_truthy(joined:match("window_hints.lua"))
		assert.is_truthy(joined:match("focus_back.lua"))
		assert.is_truthy(joined:match("focus_history.lua"))

		init.teardown()
		assert.is_true(calls.teardown.focus_border)
		assert.is_true(calls.teardown.focus_back)
		assert.is_true(calls.teardown.focus_history)
		assert.are.equal(nil, calls.teardown.window_hints)
	end)

	it("teardown は focus_back -> window_hints -> focus_border の順に実行される", function()
		_G.__jinrai = nil
		local init = dofile("./init.lua")
		local order = {}

		_G.dofile = function(path)
			if path:match("focus_border.lua$") then
				return {
					new = function()
						return {
							teardown = function()
								table.insert(order, "focus_border")
							end,
						}
					end,
				}
			end
			if path:match("window_hints.lua$") then
				return {
					new = function()
						return {
							teardown = function()
								table.insert(order, "window_hints")
							end,
						}
					end,
				}
			end
			if path:match("focus_back.lua$") then
				return {
					new = function()
						return {
							teardown = function()
								table.insert(order, "focus_back")
							end,
						}
					end,
				}
			end
			if path:match("focus_history.lua$") then
				return {
					new = function()
						return {
							teardown = function()
								table.insert(order, "focus_history")
							end,
						}
					end,
				}
			end
			return originalDofile(path)
		end

		init.setup({
			focus_border = {},
			window_hints = {},
			focus_back = {},
		})
		init.teardown()

		assert.are.same({ "focus_back", "window_hints", "focus_history", "focus_border" }, order)
	end)
end)
