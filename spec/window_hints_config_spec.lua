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
			ui = {
				offSpaceBadge = {
					size = 20,
					fillColor = { red = 0.1, green = 0.2, blue = 0.3, alpha = 0.4 },
					strokeColor = { red = 0.8, green = 0.9, blue = 1.0, alpha = 0.7 },
					textColor = { red = 0.9, green = 0.9, blue = 0.9, alpha = 0.85 },
					inactiveFillAlpha = 0.12,
					inactiveStrokeAlpha = 0.34,
					inactiveTextAlpha = 0.20,
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
		assert.are.equal(20, built.offSpaceBadgeSize)
		assert.are.same({ red = 0.1, green = 0.2, blue = 0.3, alpha = 0.4 }, built.offSpaceBadgeFillColor)
		assert.are.same({ red = 0.8, green = 0.9, blue = 1.0, alpha = 0.7 }, built.offSpaceBadgeStrokeColor)
		assert.are.equal(0.12, built.offSpaceBadgeInactiveFillAlpha)
		assert.are.equal(0.34, built.offSpaceBadgeInactiveStrokeAlpha)
		assert.are.same({ red = 0.9, green = 0.9, blue = 0.9, alpha = 0.85 }, built.offSpaceBadgeTextColor)
		assert.are.equal(0.20, built.offSpaceBadgeInactiveTextAlpha)
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

	it("offSpaceBadge.enabled はデフォルトで true", function()
		local built = mod.build({})
		assert.is_true(built.offSpaceBadgeEnabled)
	end)

	it("offSpaceBadge.enabled を false に設定できる", function()
		local built = mod.build({
			ui = {
				offSpaceBadge = {
					enabled = false,
				},
			},
		})
		assert.is_false(built.offSpaceBadgeEnabled)
	end)

	it("spaceColors が flatten で渡される", function()
		local built = mod.build({})
		assert.is_not_nil(built.offSpaceBadgeSpaceColors)
		assert.are.equal(5, #built.offSpaceBadgeSpaceColors)
		-- 2番目（緑）の fillColor を確認
		assert.are.equal(0.30, built.offSpaceBadgeSpaceColors[2].fillColor.red)
		assert.are.equal(0.78, built.offSpaceBadgeSpaceColors[2].fillColor.green)
	end)

	it("spaceColors をユーザーが上書きできる", function()
		local built = mod.build({
			ui = {
				offSpaceBadge = {
					spaceColors = {
						{
							fillColor = { red = 0.99, green = 0.99, blue = 0.99, alpha = 0.99 },
						},
					},
				},
			},
		})
		assert.are.equal(1, #built.offSpaceBadgeSpaceColors)
		assert.are.equal(0.99, built.offSpaceBadgeSpaceColors[1].fillColor.red)
	end)

	it("デフォルトで spaceKeys は true", function()
		local built = mod.build({})
		assert.is_true(built.spaceKeys)
	end)

	it("spaceKeys = true で hintChars から数字が除外される", function()
		local built = mod.build({
			hint = {
				chars = { "A", "1", "2", "B", "9" },
			},
			navigation = {
				spaceKeys = true,
			},
		})
		assert.are.same({ "A", "B" }, built.hintChars)
		assert.is_true(built.spaceKeys)
	end)

	it("デフォルトで prevSpaceKey/nextSpaceKey は nil", function()
		local built = mod.build({})
		assert.is_nil(built.prevSpaceKey)
		assert.is_nil(built.nextSpaceKey)
	end)

	it("prevSpaceKey/nextSpaceKey を設定できる", function()
		local built = mod.build({
			navigation = {
				prevSpaceKey = "P",
				nextSpaceKey = "N",
			},
		})
		assert.are.equal("p", built.prevSpaceKey)
		assert.are.equal("n", built.nextSpaceKey)
	end)

	it("prevSpaceKey/nextSpaceKey は hintChars から除外される", function()
		local built = mod.build({
			hint = {
				chars = { "A", "P", "N", "B" },
			},
			navigation = {
				prevSpaceKey = "P",
				nextSpaceKey = "N",
			},
		})
		assert.are.same({ "A", "B" }, built.hintChars)
	end)

	it("offSpaceBadge.size が 0 以下ならエラー", function()
		local ok, err = pcall(function()
			mod.build({
				ui = {
					offSpaceBadge = {
						size = 0,
					},
				},
			})
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("ui.offSpaceBadge.size must be > 0"))
	end)
end)
