describe("window_hints_config", function()
	local mod

	before_each(function()
		mod = dofile("./Jinrai.spoon/window_hints_config.lua")
	end)

	it("ネスト設定を実行時設定へ変換できる", function()
		local focusHistory = { tag = "focusHistory" }
		local built = mod.build({
			hotkey = {
				modifiers = { "ctrl", "alt" },
				key = "f18",
			},
			hint = {
				chars = { "A", "B", "C" },
			},
			navigation = {
				directionKeys = {
					left = "h",
					right = "l",
				},
				directHotkeys = {
					modifiers = { "cmd" },
					keys = {
						left = "h",
					},
				},
				focusBackKey = "i",
				swapSelectModifiers = { "shift" },
				cardinalOverlapTieThresholdPx = 300,
			},
			dock = {
				windowBlend = {
					x = 0.5,
					y = 0.25,
				},
			},
			behavior = {
				includeOtherSpaces = true,
			},
			internal = {
				focusHistory = focusHistory,
			},
		})

		assert.are.same({ "ctrl", "alt" }, built.hotkeyModifiers)
		assert.are.equal("f18", built.hotkeyKey)
		assert.are.same({ "A", "B", "C" }, built.hintChars)
		assert.are.equal("h", built.directionKeys.left)
		assert.are.equal("left", built.directionKeyLookup.h)
		assert.are.same({ "cmd" }, built.directDirectionHotkeys.modifiers)
		assert.are.equal("i", built.focusBackKey)
		assert.are.same({ "shift" }, built.swapWindowFrameSelectModifiers)
		assert.are.equal(300, built.cardinalOverlapTieThresholdPx)
		assert.are.equal(0.5, built.dockWindowXBlend)
		assert.are.equal(0.25, built.dockWindowYBlend)
		assert.is_true(built.includeOtherSpaces)
		assert.are.equal(focusHistory, built.focusHistory)
	end)

	it("focusHistory が無いと focusBackKey は無効化される", function()
		local built = mod.build({
			hint = {
				chars = { "A", "S" },
			},
			navigation = {
				focusBackKey = "i",
			},
		})
		assert.are.equal(nil, built.focusBackKey)
	end)

	it("配列は deep merge でなく置換される", function()
		local built = mod.build({
			hint = {
				chars = { "Z" },
			},
		})
		assert.are.same({ "Z" }, built.hintChars)
	end)

	it("旧フラットキーはエラー", function()
		local ok, err = pcall(function()
			mod.build({
				hotkeyKey = "f20",
			})
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("legacy flat key"))
	end)

	it("予約キー除外後に hintChars が空ならエラー", function()
		local ok, err = pcall(function()
			mod.build({
				hint = {
					chars = { "H" },
				},
				navigation = {
					directionKeys = {
						left = "h",
					},
				},
			})
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("no available hintChars"))
	end)
end)
