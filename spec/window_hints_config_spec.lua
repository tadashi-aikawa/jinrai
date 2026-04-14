describe("window_hints_config", function()
	local mod

	before_each(function()
		mod = dofile("./Jinrai.spoon/window_hints_config.lua")
	end)

	it("新しいネスト設定を実行時設定へ変換できる", function()
		local focusHistory = { tag = "focusHistory" }
		local built = mod.build({
			hotkey = {
				modifiers = { "ctrl", "alt" },
				key = "f18",
			},
			hint = {
				chars = { "A", "B", "C" },
				padding = 10,
				collisionOffset = 42,
				cornerRadius = 14,
				state = {
					normal = {
						bgColor = { red = 0.1, green = 0.2, blue = 0.3, alpha = 0.4 },
						highlight = {
							fillColor = { red = 0.4, green = 0.5, blue = 0.6, alpha = 0.7 },
							borderColor = { red = 0.5, green = 0.6, blue = 0.7, alpha = 0.8 },
						},
					},
					dimmed = {
						bgColor = { red = 0.11, green = 0.12, blue = 0.13, alpha = 0.14 },
						highlight = {
							borderColor = { red = 0.15, green = 0.16, blue = 0.17, alpha = 0.18 },
						},
					},
					occluded = {
						bgColor = { red = 0.21, green = 0.22, blue = 0.23, alpha = 0.24 },
					},
					active = {
						bgColor = { red = 0.31, green = 0.32, blue = 0.33, alpha = 0.34 },
						highlight = {
							fillColor = { red = 0.35, green = 0.36, blue = 0.37, alpha = 0.38 },
							borderColor = { red = 0.39, green = 0.40, blue = 0.41, alpha = 0.42 },
						},
					},
				},
				icon = {
					size = 80,
					state = {
						normal = { alpha = 0.91 },
						dimmed = { alpha = 0.29 },
						occluded = { alpha = 0.49 },
						active = { alpha = 0.79 },
					},
				},
				key = {
					size = 74,
					minWidth = 88,
					horizontalPadding = 11,
					gap = 3,
					fontName = "KeyFont",
					fontSize = 44,
					keyHighlightColor = { red = 0.41, green = 0.42, blue = 0.43, alpha = 0.44 },
					state = {
						normal = {
							color = { red = 0.51, green = 0.52, blue = 0.53, alpha = 0.54 },
						},
						dimmed = {
							color = { red = 0.61, green = 0.62, blue = 0.63, alpha = 0.64 },
						},
						active = {
							color = { red = 0.65, green = 0.66, blue = 0.67, alpha = 0.68 },
						},
					},
				},
				title = {
					fontName = "TitleFont",
					fontSize = 18,
					rowGap = 9,
					maxSize = 50,
					show = false,
					state = {
						normal = {
							color = { red = 0.71, green = 0.72, blue = 0.73, alpha = 0.74 },
						},
						dimmed = {
							color = { red = 0.81, green = 0.82, blue = 0.83, alpha = 0.84 },
						},
						active = {
							color = { red = 0.85, green = 0.86, blue = 0.87, alpha = 0.88 },
						},
					},
				},
				highlight = {
					borderWidth = 7,
				},
				spaceBadge = {
					enabled = false,
					size = 20,
					state = {
						normal = {
							fillColor = { red = 0.1, green = 0.2, blue = 0.3, alpha = 0.4 },
							strokeColor = { red = 0.8, green = 0.9, blue = 1.0, alpha = 0.7 },
							textColor = { red = 0.9, green = 0.9, blue = 0.9, alpha = 0.85 },
						},
						dimmed = {
							fillColor = { red = 0.1, green = 0.2, blue = 0.3, alpha = 0.12 },
							strokeColor = { red = 0.8, green = 0.9, blue = 1.0, alpha = 0.34 },
							textColor = { red = 0.9, green = 0.9, blue = 0.9, alpha = 0.20 },
						},
						active = {
							fillColor = { red = 0.21, green = 0.22, blue = 0.23, alpha = 0.24 },
							strokeColor = { red = 0.25, green = 0.26, blue = 0.27, alpha = 0.28 },
							textColor = { red = 0.29, green = 0.30, blue = 0.31, alpha = 0.32 },
						},
					},
					spaceColors = {
						{
							fillColor = { red = 0.99, green = 0.99, blue = 0.99, alpha = 0.99 },
						},
					},
				},
			},
			focusedWindowHighlight = {
				fillColor = { red = 0.91, green = 0.92, blue = 0.93, alpha = 0.94 },
				borderColor = { red = 0.81, green = 0.82, blue = 0.83, alpha = 0.84 },
				borderWidth = 15,
				cornerRadius = 16,
			},
			navigation = {
				focusBack = {
					key = "i",
				},
				direction = {
					hints = {
						keys = {
							left = "h",
							right = "l",
						},
					},
					direct = {
						modifiers = { "cmd" },
						keys = {
							left = "h",
						},
					},
					scoring = {
						cardinalOverlapTieThresholdPx = 300,
					},
				},
				spaces = {
					numbers = true,
					prev = {
						key = nil,
					},
					next = {
						key = nil,
					},
				},
			},
			dock = {
				windowBlend = {
					x = 0.5,
					y = 0.25,
				},
			},
			behavior = {
				selection = {
					swapWindowFrame = {
						modifiers = { "shift" },
					},
				},
				candidates = {
					includeOtherSpaces = true,
					includeActiveWindow = true,
				},
				callbacks = {
					onSelect = nil,
					onError = nil,
				},
				cursor = {
					onSelect = false,
					onStart = false,
				},
			},
			internal = {
				focusHistory = focusHistory,
			},
		})

		assert.are.same({ "ctrl", "alt" }, built.hotkeyModifiers)
		assert.are.equal("f18", built.hotkeyKey)
		assert.are.same({ "A", "B", "C" }, built.hintChars)
		assert.are.equal(80, built.iconSize)
		assert.are.equal(74, built.keyBoxSize)
		assert.are.equal(88, built.keyBoxMinWidth)
		assert.are.equal(11, built.keyBoxHorizontalPadding)
		assert.are.equal(3, built.keyGap)
		assert.are.equal(10, built.padding)
		assert.are.equal(14, built.hintCornerRadius)
		assert.are.equal("KeyFont", built.keyFontName)
		assert.are.equal("TitleFont", built.titleFontName)
		assert.are.equal(44, built.fontSize)
		assert.are.equal(18, built.titleFontSize)
		assert.are.equal(9, built.rowGap)
		assert.are.equal(50, built.titleMaxSize)
		assert.is_false(built.showTitles)
		assert.are.same({ red = 0.1, green = 0.2, blue = 0.3, alpha = 0.4 }, built.bgColor)
		assert.are.same({ red = 0.11, green = 0.12, blue = 0.13, alpha = 0.14 }, built.dimmedBgColor)
		assert.are.same({ red = 0.21, green = 0.22, blue = 0.23, alpha = 0.24 }, built.occludedBgColor)
		assert.are.same({ red = 0.31, green = 0.32, blue = 0.33, alpha = 0.34 }, built.activeBgColor)
		assert.are.same({ red = 0.51, green = 0.52, blue = 0.53, alpha = 0.54 }, built.textColor)
		assert.are.same({ red = 0.61, green = 0.62, blue = 0.63, alpha = 0.64 }, built.dimmedTextColor)
		assert.are.same({ red = 0.65, green = 0.66, blue = 0.67, alpha = 0.68 }, built.activeTextColor)
		assert.are.same({ red = 0.71, green = 0.72, blue = 0.73, alpha = 0.74 }, built.titleTextColor)
		assert.are.same({ red = 0.81, green = 0.82, blue = 0.83, alpha = 0.84 }, built.dimmedTitleTextColor)
		assert.are.same({ red = 0.85, green = 0.86, blue = 0.87, alpha = 0.88 }, built.activeTitleTextColor)
		assert.are.same({ red = 0.41, green = 0.42, blue = 0.43, alpha = 0.44 }, built.keyHighlightColor)
		assert.are.equal(0.91, built.iconAlpha)
		assert.are.equal(0.29, built.dimmedIconAlpha)
		assert.are.equal(0.49, built.occludedIconAlpha)
		assert.are.equal(0.79, built.activeIconAlpha)
		assert.is_false(built.offSpaceBadgeEnabled)
		assert.are.equal(20, built.offSpaceBadgeSize)
		assert.are.same({ red = 0.1, green = 0.2, blue = 0.3, alpha = 0.4 }, built.offSpaceBadgeFillColor)
		assert.are.same({ red = 0.8, green = 0.9, blue = 1.0, alpha = 0.7 }, built.offSpaceBadgeStrokeColor)
		assert.are.same({ red = 0.9, green = 0.9, blue = 0.9, alpha = 0.85 }, built.offSpaceBadgeTextColor)
		assert.are.same({ red = 0.1, green = 0.2, blue = 0.3, alpha = 0.12 }, built.offSpaceBadgeDimmedFillColor)
		assert.are.same({ red = 0.8, green = 0.9, blue = 1.0, alpha = 0.34 }, built.offSpaceBadgeDimmedStrokeColor)
		assert.are.same({ red = 0.9, green = 0.9, blue = 0.9, alpha = 0.20 }, built.offSpaceBadgeDimmedTextColor)
		assert.are.same({ red = 0.21, green = 0.22, blue = 0.23, alpha = 0.24 }, built.activeOffSpaceBadgeFillColor)
		assert.are.same({ red = 0.25, green = 0.26, blue = 0.27, alpha = 0.28 }, built.activeOffSpaceBadgeStrokeColor)
		assert.are.same({ red = 0.29, green = 0.30, blue = 0.31, alpha = 0.32 }, built.activeOffSpaceBadgeTextColor)
		assert.are.equal(1, #built.offSpaceBadgeSpaceColors)
		assert.are.equal(0.99, built.offSpaceBadgeSpaceColors[1].fillColor.red)
		assert.are.same({ red = 0.4, green = 0.5, blue = 0.6, alpha = 0.7 }, built.hintOverlayColor)
		assert.are.same({ red = 0.5, green = 0.6, blue = 0.7, alpha = 0.8 }, built.hintOverlayBorderColor)
		assert.are.same({ red = 0.15, green = 0.16, blue = 0.17, alpha = 0.18 }, built.dimmedHintOverlayBorderColor)
		assert.are.same({ red = 0.35, green = 0.36, blue = 0.37, alpha = 0.38 }, built.activeHintOverlayColor)
		assert.are.same({ red = 0.39, green = 0.40, blue = 0.41, alpha = 0.42 }, built.activeHintOverlayBorderColor)
		assert.are.equal(7, built.hintOverlayBorderWidth)
		assert.are.equal(14, built.hintOverlayCornerRadius)
		assert.are.same({ red = 0.91, green = 0.92, blue = 0.93, alpha = 0.94 }, built.activeOverlayColor)
		assert.are.same({ red = 0.81, green = 0.82, blue = 0.83, alpha = 0.84 }, built.activeOverlayBorderColor)
		assert.are.equal(15, built.activeOverlayBorderWidth)
		assert.are.equal(16, built.activeOverlayCornerRadius)
		assert.are.equal("h", built.directionKeys.left)
		assert.are.equal("left", built.directionKeyLookup.h)
		assert.are.same({ "cmd" }, built.directDirectionHotkeys.modifiers)
		assert.are.equal("i", built.focusBackKey)
		assert.are.same({ "shift" }, built.swapWindowFrameSelectModifiers)
		assert.are.equal(300, built.cardinalOverlapTieThresholdPx)
		assert.are.equal(0.5, built.dockWindowXBlend)
		assert.are.equal(0.25, built.dockWindowYBlend)
		assert.is_true(built.includeOtherSpaces)
		assert.is_true(built.includeActiveWindow)
		assert.are.equal(focusHistory, built.focusHistory)
	end)

	it("active state の未指定値はデフォルト active 設定を使う", function()
		local built = mod.build({
			hint = {
				state = {
					normal = {
						bgColor = { red = 0.1, green = 0.2, blue = 0.3, alpha = 0.4 },
						highlight = {
							fillColor = { red = 0.4, green = 0.5, blue = 0.6, alpha = 0.7 },
							borderColor = { red = 0.5, green = 0.6, blue = 0.7, alpha = 0.8 },
						},
					},
				},
				icon = {
					state = {
						normal = { alpha = 0.91 },
					},
				},
				key = {
					fontName = "KeyFont",
					state = {
						normal = {
							color = { red = 0.51, green = 0.52, blue = 0.53, alpha = 0.54 },
						},
					},
				},
				title = {
					fontName = nil,
				},
			},
		})

		assert.are.same({ red = 0.95, green = 0.68, blue = 0.40, alpha = 0.56 }, built.activeHintOverlayColor)
		assert.are.same({ red = 0.95, green = 0.68, blue = 0.40, alpha = 0.95 }, built.activeHintOverlayBorderColor)
		assert.are.equal("KeyFont", built.titleFontName)
	end)

	it("focusHistory が無いと focusBackKey は無効化される", function()
		local built = mod.build({
			hint = {
				chars = { "A", "S" },
			},
			navigation = {
				focusBack = {
					key = "i",
				},
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

	it("旧 nested key はエラー", function()
		local legacyOptions = {
			{
				hint = {
					badge = {
						bgColor = { red = 0, green = 0, blue = 0, alpha = 1 },
					},
				},
			},
			{
				hint = {
					keyBox = {
						size = 80,
					},
				},
			},
			{
				hint = {
					text = {
						keyFontSize = 44,
					},
				},
			},
			{
				hint = {
					overlay = {
						fillColor = { red = 0, green = 0, blue = 0, alpha = 1 },
					},
				},
			},
			{
				hint = {
					onActiveWindow = {
						fillColor = { red = 0, green = 0, blue = 0, alpha = 1 },
					},
				},
			},
			{
				hint = {
					offSpaceBadge = {
						enabled = false,
					},
				},
			},
			{
				activeWindow = {
					borderWidth = 5,
				},
			},
		}

		for _, options in ipairs(legacyOptions) do
			local ok = pcall(function()
			mod.build(options)
			end)
			assert.is_false(ok)
		end
	end)

	it("予約キー除外後に hintChars が空ならエラー", function()
		local ok, err = pcall(function()
			mod.build({
				hint = {
					chars = { "H" },
				},
				navigation = {
					direction = {
						hints = {
							keys = {
								left = "h",
							},
						},
					},
				},
			})
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("no available hintChars"))
	end)

	it("spaceKeys = true で hintChars から数字が除外される", function()
		local built = mod.build({
			hint = {
				chars = { "A", "1", "2", "B", "9" },
			},
			navigation = {
				spaces = {
					numbers = true,
				},
			},
		})
		assert.are.same({ "A", "B" }, built.hintChars)
		assert.is_true(built.spaceKeys)
	end)

	it("prevSpaceKey/nextSpaceKey は hintChars から除外される", function()
		local built = mod.build({
			hint = {
				chars = { "A", "P", "N", "B" },
			},
			navigation = {
				spaces = {
					prev = {
						key = "P",
					},
					next = {
						key = "N",
					},
				},
			},
		})
		assert.are.same({ "A", "B" }, built.hintChars)
		assert.are.equal("p", built.prevSpaceKey)
		assert.are.equal("n", built.nextSpaceKey)
	end)

	it("hint.spaceBadge.size が 0 以下ならエラー", function()
		local ok, err = pcall(function()
			mod.build({
				hint = {
					spaceBadge = {
						size = 0,
					},
				},
			})
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("hint%.spaceBadge%.size must be > 0"))
	end)
end)
