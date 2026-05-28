describe("window_mover_config", function()
	local mod

	before_each(function()
		mod = dofile("./Jinrai.spoon/window_mover_config.lua")
	end)

	it("ネスト設定を実行時設定へ変換できる", function()
		local built = mod.build({
			hotkey = {
				modifiers = { "cmd", "shift" },
				key = "f18",
			},
			behavior = {
				cursor = {
					afterMove = false,
				},
			},
		})

		assert.are.same({ "cmd", "shift" }, built.hotkeyModifiers)
		assert.are.equal("f18", built.hotkeyKey)
		assert.is_false(built.centerCursor)
	end)

	it("未指定時はホットキーなし、カーソル移動あり", function()
		local built = mod.build()

		assert.are.equal(nil, built.hotkeyModifiers)
		assert.are.equal(nil, built.hotkeyKey)
		assert.is_true(built.centerCursor)
	end)

	it("options が table でなければエラー", function()
		local ok, err = pcall(function()
			mod.build("invalid")
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("options must be a table"))
	end)
end)
