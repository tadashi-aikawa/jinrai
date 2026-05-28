describe("window_mover_config", function()
	local mod

	before_each(function()
		mod = dofile("./Jinrai.spoon/window_mover_config.lua")
	end)

	it("ネスト設定を実行時設定へ変換できる", function()
		local built = mod.build({
			commands = {
				moveToNextDisplay = {
					hotkey = {
						modifiers = { "cmd", "shift" },
						key = "f18",
					},
				},
				moveToActiveDisplayFreeArea = {
					hotkey = {
						modifiers = { "ctrl", "alt" },
						key = "f19",
					},
				},
			},
			behavior = {
				cursor = {
					afterMove = false,
				},
			},
		})

		assert.are.same({ "cmd", "shift" }, built.moveToNextDisplayHotkeyModifiers)
		assert.are.equal("f18", built.moveToNextDisplayHotkeyKey)
		assert.are.same({ "ctrl", "alt" }, built.moveToActiveDisplayFreeAreaHotkeyModifiers)
		assert.are.equal("f19", built.moveToActiveDisplayFreeAreaHotkeyKey)
		assert.is_false(built.centerCursor)
	end)

	it("未指定時はホットキーなし、カーソル移動あり", function()
		local built = mod.build()

		assert.are.equal(nil, built.moveToNextDisplayHotkeyModifiers)
		assert.are.equal(nil, built.moveToNextDisplayHotkeyKey)
		assert.are.equal(nil, built.moveToActiveDisplayFreeAreaHotkeyModifiers)
		assert.are.equal(nil, built.moveToActiveDisplayFreeAreaHotkeyKey)
		assert.is_true(built.centerCursor)
	end)

	it("旧 hotkey はエラー", function()
		local ok, err = pcall(function()
			mod.build({
				hotkey = {
					modifiers = { "cmd" },
					key = "m",
				},
			})
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("removed key 'hotkey'"))
	end)

	it("options が table でなければエラー", function()
		local ok, err = pcall(function()
			mod.build("invalid")
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("options must be a table"))
	end)
end)
