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
				moveToSelectedArea = {
					hotkey = {
						modifiers = { "cmd", "alt" },
						key = "f18",
					},
				},
			},
			behavior = {
				cursor = {
					afterMove = false,
				},
				selectedArea = {
					default = "uuid-a",
					screens = {
						["uuid-a"] = {
							full = "a",
							halfLeft = "s",
							halfHorizontalCenter = "d",
							halfRight = "f",
							halfTop = "q",
							halfVerticalCenter = "w",
							halfBottom = "e",
							thirdLeft = "r",
							thirdHorizontalCenter = "j",
							thirdRight = "k",
							thirdTop = "l",
							thirdVerticalCenter = "m",
							thirdBottom = "z",
							twoThirdsHorizontalCenter = "x",
							twoThirdsVerticalCenter = "c",
							["1920x1080Center"] = "v",
						},
					},
				},
			},
			appearance = {
				selectedArea = {
					borderWidth = 4,
					cornerRadius = 10,
					state = {
						normal = {
							bgColor = { red = 0.1, green = 0.2, blue = 0.3, alpha = 0.4 },
							textColor = { red = 0.9, green = 0.8, blue = 0.7, alpha = 0.6 },
						},
					},
					styles = {
						half = {
							color = { red = 0.2, green = 0.4, blue = 0.6, alpha = 0.8 },
						},
					},
				},
			},
		})

		assert.are.same({ "cmd", "shift" }, built.moveToNextDisplayHotkeyModifiers)
		assert.are.equal("f18", built.moveToNextDisplayHotkeyKey)
		assert.are.same({ "ctrl", "alt" }, built.moveToActiveDisplayFreeAreaHotkeyModifiers)
		assert.are.equal("f19", built.moveToActiveDisplayFreeAreaHotkeyKey)
		assert.are.same({ "cmd", "alt" }, built.moveToSelectedAreaHotkeyModifiers)
		assert.are.equal("f18", built.moveToSelectedAreaHotkeyKey)
		assert.is_false(built.centerCursor)
		assert.are.equal("uuid-a", built.selectedAreaDefault)
		assert.are.same({
			["uuid-a"] = {
				full = "A",
				halfLeft = "S",
				halfHorizontalCenter = "D",
				halfRight = "F",
				halfTop = "Q",
				halfVerticalCenter = "W",
				halfBottom = "E",
				thirdLeft = "R",
				thirdHorizontalCenter = "J",
				thirdRight = "K",
				thirdTop = "L",
				thirdVerticalCenter = "M",
				thirdBottom = "Z",
				twoThirdsHorizontalCenter = "X",
				twoThirdsVerticalCenter = "C",
				["1920x1080Center"] = "V",
			},
		}, built.selectedAreaScreens)
		assert.are.equal(4, built.selectedAreaAppearance.borderWidth)
		assert.are.equal(10, built.selectedAreaAppearance.cornerRadius)
		assert.are.same({ red = 0.1, green = 0.2, blue = 0.3, alpha = 0.4 }, built.selectedAreaAppearance.state.normal.bgColor)
		assert.are.same({ red = 0.9, green = 0.8, blue = 0.7, alpha = 0.6 }, built.selectedAreaAppearance.state.normal.textColor)
		assert.are.same({ red = 0.2, green = 0.4, blue = 0.6, alpha = 0.8 }, built.selectedAreaAppearance.styles.half.color)
		assert.are.same({ red = 0.92, green = 0.42, blue = 0.74, alpha = 0.22 }, built.selectedAreaAppearance.styles.half.dimmedColor)
	end)

	it("未指定時はホットキーなし、カーソル移動あり、選択エリア候補なし", function()
		local built = mod.build()

		assert.are.equal(nil, built.moveToNextDisplayHotkeyModifiers)
		assert.are.equal(nil, built.moveToNextDisplayHotkeyKey)
		assert.are.equal(nil, built.moveToActiveDisplayFreeAreaHotkeyModifiers)
		assert.are.equal(nil, built.moveToActiveDisplayFreeAreaHotkeyKey)
		assert.are.equal(nil, built.moveToSelectedAreaHotkeyModifiers)
		assert.are.equal(nil, built.moveToSelectedAreaHotkeyKey)
		assert.is_true(built.centerCursor)
		assert.is_nil(built.selectedAreaDefault)
		assert.are.same({}, built.selectedAreaScreens)
		assert.are.equal(2, built.selectedAreaAppearance.borderWidth)
		assert.are.equal(6, built.selectedAreaAppearance.cornerRadius)
		assert.are.same({ red = 0.36, green = 0.62, blue = 1.00, alpha = 0.92 }, built.selectedAreaAppearance.styles.full.color)
	end)

	it("selectedArea.default の参照先がなければエラー", function()
		local ok, err = pcall(function()
			mod.build({
				behavior = {
					selectedArea = {
						default = "missing",
						screens = {
							["uuid-a"] = {
								full = "A",
							},
						},
					},
				},
			})
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("default must refer"))
	end)

	it("selectedArea のキーが不正ならエラー", function()
		local ok, err = pcall(function()
			mod.build({
				behavior = {
					selectedArea = {
						screens = {
							["uuid-a"] = {
								full = "ABC",
							},
						},
					},
				},
			})
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("must be a 1%-2 character string"))
	end)

	it("selectedArea の重複キーはエラー", function()
		local ok, err = pcall(function()
			mod.build({
				behavior = {
					selectedArea = {
						screens = {
							["uuid-a"] = {
								full = "A",
								halfLeft = "a",
							},
						},
					},
				},
			})
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("duplicate key"))
	end)

	it("selectedArea の prefix 衝突キーはエラー", function()
		local ok, err = pcall(function()
			mod.build({
				behavior = {
					selectedArea = {
						screens = {
							["uuid-a"] = {
								full = "A",
								halfLeft = "AS",
							},
						},
					},
				},
			})
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("prefix%-conflicting key"))
	end)

	it("旧 Start/End 系 area はエラー", function()
		local ok, err = pcall(function()
			mod.build({
				behavior = {
					selectedArea = {
						screens = {
							["uuid-a"] = {
								halfStart = "A",
							},
						},
					},
				},
			})
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("unsupported selectedArea area 'halfStart'"))
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
