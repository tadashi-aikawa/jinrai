describe("window_mover_config", function()
	local mod
	local directAreaCommandKeys = {
		"halfLeft",
		"halfHorizontalCenter",
		"halfRight",
		"halfTop",
		"halfVerticalCenter",
		"halfBottom",
		"thirdLeft",
		"thirdHorizontalCenter",
		"thirdRight",
		"thirdTop",
		"thirdVerticalCenter",
		"thirdBottom",
		"quarterLeft",
		"quarterHorizontalLeftCenter",
		"quarterHorizontalRightCenter",
		"quarterRight",
		"quarterTop",
		"quarterVerticalTopCenter",
		"quarterVerticalBottomCenter",
		"quarterBottom",
		"quarterTopLeft",
		"quarterTopRight",
		"quarterBottomLeft",
		"quarterBottomRight",
		"sixthTopLeft",
		"sixthTopCenter",
		"sixthTopRight",
		"sixthBottomLeft",
		"sixthBottomCenter",
		"sixthBottomRight",
		"twoThirdsLeft",
		"twoThirdsHorizontalCenter",
		"twoThirdsRight",
		"twoThirdsTop",
		"twoThirdsVerticalCenter",
		"twoThirdsBottom",
		"twoThirdsCenter",
		"threeQuartersLeft",
		"threeQuartersHorizontalCenter",
		"threeQuartersRight",
		"threeQuartersTop",
		"threeQuartersVerticalCenter",
		"threeQuartersBottom",
		"threeQuartersCenter",
	}

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
				moveToSelectedAreaInJinraiMode = {
					hotkey = {
						modifiers = { "cmd", "ctrl" },
						key = "f19",
					},
				},
				minimizeWindow = {
					hotkey = {
						modifiers = { "cmd" },
						key = "m",
					},
				},
				maximizeWindow = {
					hotkey = {
						modifiers = { "cmd" },
						key = "f",
					},
				},
				cycleLeft = {
					hotkey = {
						modifiers = { "ctrl", "alt" },
						key = "h",
					},
				},
				cycleHorizontalCenter = {
					hotkey = {
						modifiers = { "ctrl", "alt" },
						key = "j",
					},
				},
				cycleRight = {
					hotkey = {
						modifiers = { "ctrl", "alt" },
						key = "l",
					},
				},
				cycleTop = {
					hotkey = {
						modifiers = { "ctrl", "alt" },
						key = "k",
					},
				},
				cycleVerticalCenter = {
					hotkey = {
						modifiers = { "ctrl", "alt" },
						key = "i",
					},
				},
				cycleBottom = {
					hotkey = {
						modifiers = { "ctrl", "alt" },
						key = "m",
					},
				},
				halfLeft = {
					hotkey = {
						modifiers = { "cmd", "alt" },
						key = "1",
					},
				},
				thirdHorizontalCenter = {
					hotkey = {
						modifiers = { "cmd", "alt" },
						key = "2",
					},
				},
				quarterBottom = {
					hotkey = {
						modifiers = { "cmd", "alt" },
						key = "3",
					},
				},
				sixthTopCenter = {
					hotkey = {
						modifiers = { "cmd", "alt" },
						key = "4",
					},
				},
				twoThirdsRight = {
					hotkey = {
						modifiers = { "cmd", "alt" },
						key = "5",
					},
				},
				threeQuartersRight = {
					hotkey = {
						modifiers = { "cmd", "alt" },
						key = "6",
					},
				},
			},
			behavior = {
				cursor = {
					afterMove = false,
				},
				cycle = {
					horizontalRatios = { 1 / 3, 1 / 2 },
					verticalRatios = { 2 / 3, 1 / 2 },
				},
			},
			selectedArea = {
				defaultScreen = "uuid-a",
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
						quarterLeft = "1",
						quarterHorizontalLeftCenter = "2",
						quarterHorizontalRightCenter = "3",
						quarterRight = "4",
						quarterTop = "5",
						quarterVerticalTopCenter = "6",
						quarterVerticalBottomCenter = "7",
						quarterBottom = "8",
						quarterTopLeft = "9",
						quarterTopRight = "0",
						quarterBottomLeft = "ba",
						quarterBottomRight = "bb",
						sixthTopLeft = "bc",
						sixthTopCenter = "bd",
						sixthTopRight = "be",
						sixthBottomLeft = "bf",
						sixthBottomCenter = "bg",
						sixthBottomRight = "bh",
						twoThirdsLeft = "ca",
						twoThirdsHorizontalCenter = "cb",
						twoThirdsRight = "cc",
						twoThirdsTop = "cd",
						twoThirdsVerticalCenter = "ce",
						twoThirdsBottom = "cf",
						twoThirdsCenter = "cg",
						threeQuartersLeft = "ga",
						threeQuartersHorizontalCenter = "gb",
						threeQuartersRight = "gc",
						threeQuartersTop = "gd",
						threeQuartersVerticalCenter = "ge",
						threeQuartersBottom = "gf",
						threeQuartersCenter = "gg",
						["1920x1080Center"] = "v",
					},
				},
				actions = {
					closeWindow = "x1",
					minimizeWindow = "x2",
					quitApplication = "x3",
				},
				hints = {
					show = false,
				},
				appearance = {
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
		assert.are.same({ "cmd", "alt" }, built.openWindowActionChooserHotkeyModifiers)
		assert.are.equal("f18", built.openWindowActionChooserHotkeyKey)
		assert.are.same({ "cmd", "ctrl" }, built.openJinraiModeWindowActionChooserHotkeyModifiers)
		assert.are.equal("f19", built.openJinraiModeWindowActionChooserHotkeyKey)
		assert.are.same({ "cmd" }, built.minimizeWindowHotkeyModifiers)
		assert.are.equal("m", built.minimizeWindowHotkeyKey)
		assert.are.same({ "cmd" }, built.maximizeWindowHotkeyModifiers)
		assert.are.equal("f", built.maximizeWindowHotkeyKey)
		assert.are.same({ "ctrl", "alt" }, built.cycleLeftHotkeyModifiers)
		assert.are.equal("h", built.cycleLeftHotkeyKey)
		assert.are.same({ "ctrl", "alt" }, built.cycleHorizontalCenterHotkeyModifiers)
		assert.are.equal("j", built.cycleHorizontalCenterHotkeyKey)
		assert.are.same({ "ctrl", "alt" }, built.cycleRightHotkeyModifiers)
		assert.are.equal("l", built.cycleRightHotkeyKey)
		assert.are.same({ "ctrl", "alt" }, built.cycleTopHotkeyModifiers)
		assert.are.equal("k", built.cycleTopHotkeyKey)
		assert.are.same({ "ctrl", "alt" }, built.cycleVerticalCenterHotkeyModifiers)
		assert.are.equal("i", built.cycleVerticalCenterHotkeyKey)
		assert.are.same({ "ctrl", "alt" }, built.cycleBottomHotkeyModifiers)
		assert.are.equal("m", built.cycleBottomHotkeyKey)
		assert.are.same({ "cmd", "alt" }, built.halfLeftHotkeyModifiers)
		assert.are.equal("1", built.halfLeftHotkeyKey)
		assert.are.same({ "cmd", "alt" }, built.thirdHorizontalCenterHotkeyModifiers)
		assert.are.equal("2", built.thirdHorizontalCenterHotkeyKey)
		assert.are.same({ "cmd", "alt" }, built.quarterBottomHotkeyModifiers)
		assert.are.equal("3", built.quarterBottomHotkeyKey)
		assert.are.same({ "cmd", "alt" }, built.sixthTopCenterHotkeyModifiers)
		assert.are.equal("4", built.sixthTopCenterHotkeyKey)
		assert.are.same({ "cmd", "alt" }, built.twoThirdsRightHotkeyModifiers)
		assert.are.equal("5", built.twoThirdsRightHotkeyKey)
		assert.are.same({ "cmd", "alt" }, built.threeQuartersRightHotkeyModifiers)
		assert.are.equal("6", built.threeQuartersRightHotkeyKey)
		assert.is_false(built.centerCursor)
		assert.are.equal("uuid-a", built.selectedAreaDefault)
		assert.is_false(built.selectedAreaHintsShow)
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
				quarterLeft = "1",
				quarterHorizontalLeftCenter = "2",
				quarterHorizontalRightCenter = "3",
				quarterRight = "4",
				quarterTop = "5",
				quarterVerticalTopCenter = "6",
				quarterVerticalBottomCenter = "7",
				quarterBottom = "8",
				quarterTopLeft = "9",
				quarterTopRight = "0",
				quarterBottomLeft = "BA",
				quarterBottomRight = "BB",
				sixthTopLeft = "BC",
				sixthTopCenter = "BD",
				sixthTopRight = "BE",
				sixthBottomLeft = "BF",
				sixthBottomCenter = "BG",
				sixthBottomRight = "BH",
				twoThirdsLeft = "CA",
				twoThirdsHorizontalCenter = "CB",
				twoThirdsRight = "CC",
				twoThirdsTop = "CD",
				twoThirdsVerticalCenter = "CE",
				twoThirdsBottom = "CF",
				twoThirdsCenter = "CG",
				threeQuartersLeft = "GA",
				threeQuartersHorizontalCenter = "GB",
				threeQuartersRight = "GC",
				threeQuartersTop = "GD",
				threeQuartersVerticalCenter = "GE",
				threeQuartersBottom = "GF",
				threeQuartersCenter = "GG",
				["1920x1080Center"] = "V",
			},
		}, built.selectedAreaScreens)
		assert.are.same({
			closeWindow = "X1",
			minimizeWindow = "X2",
			quitApplication = "X3",
		}, built.selectedAreaActions)
		assert.are.equal(4, built.selectedAreaAppearance.borderWidth)
		assert.are.equal(10, built.selectedAreaAppearance.cornerRadius)
		assert.are.same({ red = 0.1, green = 0.2, blue = 0.3, alpha = 0.4 }, built.selectedAreaAppearance.state.normal.bgColor)
		assert.are.same({ red = 0.9, green = 0.8, blue = 0.7, alpha = 0.6 }, built.selectedAreaAppearance.state.normal.textColor)
		assert.are.same({ red = 0.2, green = 0.4, blue = 0.6, alpha = 0.8 }, built.selectedAreaAppearance.styles.half.color)
		assert.are.same({ red = 0.62, green = 0.52, blue = 1.00, alpha = 0.22 }, built.selectedAreaAppearance.styles.half.dimmedColor)
		assert.are.same({ red = 0.92, green = 0.42, blue = 0.74, alpha = 0.92 }, built.selectedAreaAppearance.styles.quarter.color)
		assert.are.same({ red = 0.75, green = 0.15, blue = 0.25, alpha = 0.92 }, built.selectedAreaAppearance.styles.sixth.color)
		assert.are.same({ red = 0.50, green = 0.82, blue = 0.42, alpha = 0.92 }, built.selectedAreaAppearance.styles.twoThirds.color)
		assert.are.same(
			{ red = 0.30, green = 0.76, blue = 0.86, alpha = 0.92 },
			built.selectedAreaAppearance.styles.threeQuarters.color
		)
		assert.are.same({ 1 / 3, 1 / 2 }, built.cycleHorizontalRatios)
		assert.are.same({ 2 / 3, 1 / 2 }, built.cycleVerticalRatios)
	end)

	it("未指定時はホットキーなし、カーソル移動あり、選択エリア候補なし", function()
		local built = mod.build()

		assert.are.equal(nil, built.moveToNextDisplayHotkeyModifiers)
		assert.are.equal(nil, built.moveToNextDisplayHotkeyKey)
		assert.are.equal(nil, built.moveToActiveDisplayFreeAreaHotkeyModifiers)
		assert.are.equal(nil, built.moveToActiveDisplayFreeAreaHotkeyKey)
		assert.are.equal(nil, built.openWindowActionChooserHotkeyModifiers)
		assert.are.equal(nil, built.openWindowActionChooserHotkeyKey)
		assert.are.equal(nil, built.minimizeWindowHotkeyModifiers)
		assert.are.equal(nil, built.minimizeWindowHotkeyKey)
		assert.are.equal(nil, built.maximizeWindowHotkeyModifiers)
		assert.are.equal(nil, built.maximizeWindowHotkeyKey)
		assert.are.equal(nil, built.cycleLeftHotkeyModifiers)
		assert.are.equal(nil, built.cycleLeftHotkeyKey)
		assert.are.equal(nil, built.cycleHorizontalCenterHotkeyModifiers)
		assert.are.equal(nil, built.cycleHorizontalCenterHotkeyKey)
		assert.are.equal(nil, built.cycleRightHotkeyModifiers)
		assert.are.equal(nil, built.cycleRightHotkeyKey)
		assert.are.equal(nil, built.cycleTopHotkeyModifiers)
		assert.are.equal(nil, built.cycleTopHotkeyKey)
		assert.are.equal(nil, built.cycleVerticalCenterHotkeyModifiers)
		assert.are.equal(nil, built.cycleVerticalCenterHotkeyKey)
		assert.are.equal(nil, built.cycleBottomHotkeyModifiers)
		assert.are.equal(nil, built.cycleBottomHotkeyKey)
		for _, commandName in ipairs(directAreaCommandKeys) do
			assert.are.equal(nil, built[commandName .. "HotkeyModifiers"])
			assert.are.equal(nil, built[commandName .. "HotkeyKey"])
		end
		assert.is_true(built.centerCursor)
		assert.is_nil(built.selectedAreaDefault)
		assert.are.same({}, built.selectedAreaScreens)
		assert.are.same({}, built.selectedAreaActions)
		assert.is_true(built.selectedAreaHintsShow)
		assert.are.equal(2, built.selectedAreaAppearance.borderWidth)
		assert.are.equal(6, built.selectedAreaAppearance.cornerRadius)
		assert.are.same({ red = 0.36, green = 0.62, blue = 1.00, alpha = 0.92 }, built.selectedAreaAppearance.styles.full.color)
		assert.are.same({ red = 0.75, green = 0.15, blue = 0.25, alpha = 0.92 }, built.selectedAreaAppearance.styles.sixth.color)
		assert.are.same({ red = 0.50, green = 0.82, blue = 0.42, alpha = 0.92 }, built.selectedAreaAppearance.styles.twoThirds.color)
		assert.are.same(
			{ red = 0.30, green = 0.76, blue = 0.86, alpha = 0.92 },
			built.selectedAreaAppearance.styles.threeQuarters.color
		)
		assert.are.same({ 1 / 2, 1 / 3, 2 / 3 }, built.cycleHorizontalRatios)
		assert.are.same({ 1 / 2, 1 / 3, 2 / 3 }, built.cycleVerticalRatios)
	end)

	it("cycle ratio が不正ならエラー", function()
		local cases = {
			{
				ratios = {},
				message = "must be a non%-empty array",
			},
			{
				ratios = { "1/2" },
				message = "must be a number greater than 0 and at most 1",
			},
			{
				ratios = { 0 },
				message = "must be a number greater than 0 and at most 1",
			},
			{
				ratios = { -0.5 },
				message = "must be a number greater than 0 and at most 1",
			},
			{
				ratios = { 1.1 },
				message = "must be a number greater than 0 and at most 1",
			},
			{
				ratios = { 1 / 2, 1 / 2 },
				message = "duplicate ratios",
			},
		}

		for _, case in ipairs(cases) do
			local ok, err = pcall(function()
				mod.build({
					behavior = {
						cycle = {
							horizontalRatios = case.ratios,
						},
					},
				})
			end)

			assert.is_false(ok)
			assert.is_truthy(tostring(err):match(case.message))
		end
	end)

	it("selectedArea.defaultScreen の参照先がなければエラー", function()
		local ok, err = pcall(function()
			mod.build({
				selectedArea = {
					defaultScreen = "missing",
					screens = {
						["uuid-a"] = {
							full = "A",
						},
					},
				},
			})
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("defaultScreen must refer"))
	end)

	it("selectedArea のキーが不正ならエラー", function()
		local ok, err = pcall(function()
			mod.build({
				selectedArea = {
					screens = {
						["uuid-a"] = {
							full = "ABCD",
						},
					},
				},
			})
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("must be a 1%-3 character string"))
	end)

	it("selectedArea.screens に freeArea を設定できる", function()
		local built = mod.build({
			selectedArea = {
				screens = {
					["uuid-a"] = {
						freeArea = "v12",
					},
				},
			},
		})

		assert.are.same({ ["uuid-a"] = { freeArea = "V12" } }, built.selectedAreaScreens)
	end)

	it("selectedArea の重複キーはエラー", function()
		local ok, err = pcall(function()
			mod.build({
				selectedArea = {
					screens = {
						["uuid-a"] = {
							full = "A",
							halfLeft = "a",
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
				selectedArea = {
					screens = {
						["uuid-a"] = {
							full = "A",
							halfLeft = "AS",
						},
					},
				},
			})
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("prefix%-conflicting key"))
	end)

	it("selectedArea.actions を設定できる", function()
		local built = mod.build({
			selectedArea = {
				actions = {
					closeWindow = "x12",
					minimizeWindow = "m12",
					maximizeWindow = "f12",
					quitApplication = "q12",
				},
			},
		})

		assert.are.same({
			closeWindow = "X12",
			minimizeWindow = "M12",
			maximizeWindow = "F12",
			quitApplication = "Q12",
		}, built.selectedAreaActions)
	end)

	it("selectedArea.windowHints.key を設定できる", function()
		local built = mod.build({
			selectedArea = {
				windowHints = {
					key = "space",
				},
			},
		})

		assert.are.equal("space", built.selectedAreaWindowHintsKey)
	end)

	it("selectedArea.actions の未対応 action はエラー", function()
		local ok, err = pcall(function()
			mod.build({
				selectedArea = {
					actions = {
						windowHints = "Q",
					},
				},
			})
		end)

		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("unsupported selectedArea action 'windowHints'"))
	end)

	it("selectedArea.actions と selectedArea.screens の重複キーはエラー", function()
		local ok, err = pcall(function()
			mod.build({
				selectedArea = {
					screens = {
						["uuid-a"] = {
							full = "A",
						},
					},
					actions = {
						closeWindow = "a",
					},
				},
			})
		end)

		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("selectedArea%.actions%.closeWindow key 'A' conflicts"))
	end)

	it("selectedArea.actions と selectedArea.screens の prefix 衝突キーはエラー", function()
		local ok, err = pcall(function()
			mod.build({
				selectedArea = {
					screens = {
						["uuid-a"] = {
							full = "AX",
						},
					},
					actions = {
						closeWindow = "A",
					},
				},
			})
		end)

		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("selectedArea%.actions%.closeWindow key 'A' conflicts"))
	end)

	it("selectedArea.actions 同士の prefix 衝突キーはエラー", function()
		local ok, err = pcall(function()
			mod.build({
				selectedArea = {
					actions = {
						closeWindow = "A",
						minimizeWindow = "AX",
					},
				},
			})
		end)

		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("selectedArea%.actions has prefix%-conflicting key"))
	end)

	it("selectedArea.windowHints.key が不正ならエラー", function()
		local ok, err = pcall(function()
			mod.build({
				selectedArea = {
					windowHints = {
						key = "",
					},
				},
			})
		end)

		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("selectedArea%.windowHints%.key must be a non%-empty string"))
	end)

	it("selectedArea.windowHints が table でなければエラー", function()
		local ok, err = pcall(function()
			mod.build({
				selectedArea = {
					windowHints = false,
				},
			})
		end)

		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("selectedArea%.windowHints must be a table"))
	end)

	it("旧 Start/End 系 area はエラー", function()
		local ok, err = pcall(function()
			mod.build({
				selectedArea = {
					screens = {
						["uuid-a"] = {
							halfStart = "A",
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

	it("旧 commands.openWindowActionChooser はエラー", function()
		local ok, err = pcall(function()
			mod.build({
				commands = {
					openWindowActionChooser = {
						hotkey = {
							modifiers = { "cmd" },
							key = "m",
						},
					},
				},
			})
		end)

		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("removed key 'commands%.openWindowActionChooser'"))
	end)

	it("旧 behavior.selectedArea はエラー", function()
		local ok, err = pcall(function()
			mod.build({
				behavior = {
					selectedArea = {
						default = "uuid-a",
						screens = {},
					},
				},
			})
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("removed key 'behavior%.selectedArea'"))
	end)

	it("旧 appearance.selectedArea はエラー", function()
		local ok, err = pcall(function()
			mod.build({
				appearance = {
					selectedArea = {
						borderWidth = 4,
					},
				},
			})
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("removed key 'appearance%.selectedArea'"))
	end)

	it("jinrai_mode windowMover key は selectedArea 候補キーと衝突しなければ設定できる", function()
		local built = mod.build({
			selectedArea = {
				screens = {
					["uuid-a"] = {
						halfLeft = "A",
					},
				},
			},
			internal = {
				jinraiMode = {
					windowMover = {
						key = "space",
					},
				},
			},
		})

		assert.are.equal("space", built.jinraiModeKey)
	end)

	it("jinrai_mode windowMover key は selectedArea 候補キーと衝突するとエラー", function()
		local ok, err = pcall(function()
			mod.build({
				selectedArea = {
					screens = {
						["uuid-a"] = {
							halfLeft = "A",
						},
					},
				},
				internal = {
					jinraiMode = {
						windowMover = {
							key = "a",
						},
					},
				},
			})
		end)

		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("conflicts"))
	end)

	it("jinrai_mode windowMover key は selectedArea action キーと衝突するとエラー", function()
		local ok, err = pcall(function()
			mod.build({
				selectedArea = {
					actions = {
						closeWindow = "A",
					},
				},
				internal = {
					jinraiMode = {
						windowMover = {
							key = "a",
						},
					},
				},
			})
		end)

		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("selectedArea%.actions%.closeWindow"))
	end)

	it("jinrai_mode windowMover key は selectedArea action キーの prefix と衝突するとエラー", function()
		local ok, err = pcall(function()
			mod.build({
				selectedArea = {
					actions = {
						closeWindow = "AX",
					},
				},
				internal = {
					jinraiMode = {
						windowMover = {
							key = "a",
						},
					},
				},
			})
		end)

		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("selectedArea%.actions%.closeWindow"))
	end)

	it("jinrai_mode windowMover key は selectedArea 候補キーの prefix と衝突するとエラー", function()
		local ok, err = pcall(function()
			mod.build({
				selectedArea = {
					screens = {
						["uuid-a"] = {
							halfLeft = "KD",
						},
					},
				},
				internal = {
					jinraiMode = {
						windowMover = {
							key = "k",
						},
					},
				},
			})
		end)

		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("conflicts"))
	end)

	it("options が table でなければエラー", function()
		local ok, err = pcall(function()
			mod.build("invalid")
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("options must be a table"))
	end)
end)
