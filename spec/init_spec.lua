describe("init", function()
	local originalDofile
	local originalJinraiState
	local originalHs

	before_each(function()
		originalDofile = _G.dofile
		originalJinraiState = _G.__jinrai
		originalHs = _G.hs

		_G.hs = {
			spoons = {
				resourcePath = function(path)
					return "./Jinrai.spoon/" .. path
				end,
			},
		}
	end)

	after_each(function()
		_G.dofile = originalDofile
		_G.__jinrai = originalJinraiState
		_G.hs = originalHs
	end)

	it("読み込み時に既存 __jinrai.teardown を実行する", function()
		local called = 0
		_G.__jinrai = {
			teardown = function()
				called = called + 1
			end,
		}

		dofile("./Jinrai.spoon/init.lua")
		assert.are.equal(1, called)
	end)

	it("setup で指定したモジュールだけ new される", function()
		_G.__jinrai = nil
		local init = dofile("./Jinrai.spoon/init.lua")
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

		init:setup({
			focus_border = {
				visual = {
					border = {
						width = 99,
					},
				},
			},
			focus_back = {
				hotkey = {
					key = "q",
				},
				behavior = {
					cursor = {
						onSelect = true,
					},
				},
			},
		})

		assert.are.equal(99, calls.new.focus_border.visual.border.width)
		assert.are.same({ stateSync = nil }, calls.new.focus_history)
		assert.are.equal("q", calls.new.focus_back.hotkey.key)
		assert.is_true(calls.new.focus_back.behavior.cursor.onSelect)
		assert.is_truthy(calls.new.focus_back.internal.focusHistory)
		assert.are.equal(nil, calls.new.window_hints)

		local joined = table.concat(calls.loadPaths, "\n")
		assert.is_truthy(joined:match("focus_border.lua"))
		assert.is_truthy(joined:match("window_hints.lua"))
		assert.is_truthy(joined:match("focus_back.lua"))
		assert.is_truthy(joined:match("focus_history.lua"))

		init:teardown()
		assert.is_true(calls.teardown.focus_border)
		assert.is_true(calls.teardown.focus_back)
		assert.is_true(calls.teardown.focus_history)
		assert.are.equal(nil, calls.teardown.window_hints)
	end)

	it("focus_history は window_hints.internal.focusHistory に注入される", function()
		_G.__jinrai = nil
		local init = dofile("./Jinrai.spoon/init.lua")
		local calls = {
			new = {},
		}

		_G.dofile = function(path)
			if path:match("window_hints.lua$") then
				return {
					new = function(options)
						calls.new.window_hints = options
						return { teardown = function() end }
					end,
				}
			end
			if path:match("focus_back.lua$") then
				return {
					new = function(options)
						calls.new.focus_back = options
						return { teardown = function() end }
					end,
				}
			end
			if path:match("focus_history.lua$") then
				return {
					new = function(options)
						calls.new.focus_history = options
						return { teardown = function() end }
					end,
				}
			end
			if path:match("focus_border.lua$") then
				return {
					new = function()
						return { teardown = function() end }
					end,
				}
			end
			return originalDofile(path)
		end

		init:setup({
			window_hints = {},
			focus_back = {},
		})

		assert.is_truthy(calls.new.focus_history)
		assert.is_truthy(calls.new.window_hints.internal)
		assert.is_truthy(calls.new.window_hints.internal.focusHistory)
		assert.are.equal(nil, calls.new.window_hints.focusHistory)
	end)

	it("teardown は focus_back -> window_hints -> focus_border の順に実行される", function()
		_G.__jinrai = nil
		local init = dofile("./Jinrai.spoon/init.lua")
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

		init:setup({
			focus_border = {},
			window_hints = {},
			focus_back = {},
		})
		init:teardown()

		assert.are.same({ "focus_back", "window_hints", "focus_history", "focus_border" }, order)
	end)
end)
