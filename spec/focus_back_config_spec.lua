describe("focus_back_config", function()
	local mod

	before_each(function()
		mod = dofile("./Jinrai.spoon/focus_back_config.lua")
	end)

	it("ネスト設定を実行時設定へ変換できる", function()
		local focusHistory = { tag = "fh" }
		local built = mod.build({
			hotkey = {
				modifiers = { "cmd", "shift" },
				key = "f18",
			},
			urlEvent = {
				name = "focus_back",
			},
			behavior = {
				cursor = {
					onSelect = true,
				},
			},
			internal = {
				focusHistory = focusHistory,
			},
		})

		assert.are.same({ "cmd", "shift" }, built.hotkeyModifiers)
		assert.are.equal("f18", built.hotkeyKey)
		assert.are.equal("focus_back", built.urlEvent)
		assert.is_true(built.centerCursor)
		assert.are.equal(focusHistory, built.focusHistory)
	end)

	it("未指定時は更新済みデフォルト値を使う", function()
		local built = mod.build()

		assert.is_true(built.centerCursor)
	end)

	it("旧フラットキーはエラー", function()
		local ok, err = pcall(function()
			mod.build({
				hotkeyKey = "q",
			})
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("legacy flat key"))
	end)

	it("旧 nested key はエラー", function()
		local ok, err = pcall(function()
			mod.build({
				behavior = {
					centerCursor = true,
				},
			})
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("legacy nested key"))
	end)
end)
