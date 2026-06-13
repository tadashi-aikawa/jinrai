describe("window_hints appPrefixOverrides", function()
	local helper
	local allowedPrefixes
	local originalHs
	local defaultHintChars = {
		"A",
		"S",
		"D",
		"F",
		"G",
		"H",
		"J",
		"K",
		"L",
		"Q",
		"W",
		"E",
		"R",
		"T",
		"Y",
		"U",
		"I",
		"O",
		"P",
		"Z",
		"X",
		"C",
		"V",
		"B",
		"N",
		"M",
	}
	local hintCharOrder

	before_each(function()
		originalHs = _G.hs
		local mod = dofile("./Jinrai.spoon/window_hints.lua")
		helper = mod._test
		allowedPrefixes = {
			A = true,
			S = true,
			D = true,
			F = true,
			G = true,
			H = true,
			J = true,
			K = true,
			L = true,
			Q = true,
			W = true,
			E = true,
			R = true,
			T = true,
			Y = true,
			U = true,
			I = true,
			O = true,
			P = true,
			Z = true,
			X = true,
			C = true,
			V = true,
			B = true,
			N = true,
			M = true,
		}
		hintCharOrder = {}
		for i, c in ipairs(defaultHintChars) do
			hintCharOrder[c] = i
		end
	end)

	after_each(function()
		_G.hs = originalHs
	end)

	it("bundleID + titleGlob を上から先勝ちで評価できる", function()
		local compiled = helper.compileAppPrefixOverrides({
			{
				match = { bundleID = "md.obsidian", titleGlob = "Minerva*" },
				prefix = "M",
			},
			{
				match = { bundleID = "md.obsidian" },
				prefix = "O",
			},
		}, allowedPrefixes)

		local matched =
			helper.resolveAppPrefix("Obsidian", "md.obsidian", "Minerva - Daily", "A", allowedPrefixes, compiled)
		assert.are.equal("M", matched)

		local fallbackRuleMatched =
			helper.resolveAppPrefix("Obsidian", "md.obsidian", "Scratch", "A", allowedPrefixes, compiled)
		assert.are.equal("O", fallbackRuleMatched)
	end)

	it("titleGlob は window:title() に対して大文字小文字を区別する", function()
		local compiled = helper.compileAppPrefixOverrides({
			{
				match = { titleGlob = "Minerva*" },
				prefix = "M",
			},
		}, allowedPrefixes)

		local matched =
			helper.resolveAppPrefix("Obsidian", "md.obsidian", "Minerva - Daily", "A", allowedPrefixes, compiled)
		assert.are.equal("M", matched)

		local notMatched =
			helper.resolveAppPrefix("Obsidian", "md.obsidian", "minerva - Daily", "A", allowedPrefixes, compiled)
		assert.are.equal("O", notMatched)
	end)

	it("旧形式の辞書指定はエラー", function()
		local ok, err = pcall(function()
			helper.compileAppPrefixOverrides({
				["md.obsidian"] = "M",
			}, allowedPrefixes)
		end)

		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("map format is no longer supported"))
	end)

	it("prefix が3文字以上ならエラー", function()
		local ok, err = pcall(function()
			helper.compileAppPrefixOverrides({
				{
					match = { bundleID = "md.obsidian" },
					prefix = "MIN",
				},
			}, allowedPrefixes)
		end)

		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("must be 1 or 2 chars"))
	end)

	it("prefix が hintChars 外の文字ならエラー", function()
		local ok, err = pcall(function()
			helper.compileAppPrefixOverrides({
				{
					match = { bundleID = "md.obsidian" },
					prefix = "1",
				},
			}, allowedPrefixes)
		end)

		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("must be 1 or 2 chars"))
	end)

	it("2文字prefix時のキー生成を行える", function()
		local hintChars = { "A", "S", "D" }
		assert.are.equal("TM", helper.hintKeyForGroup("TM", 1, 1, hintChars))
		assert.are.equal("TMA", helper.hintKeyForGroup("TM", 2, 1, hintChars))
		assert.are.equal("TMS", helper.hintKeyForGroup("TM", 2, 2, hintChars))
	end)

	local function runPrefixFree(keys)
		local hints = {}
		for _, key in ipairs(keys) do
			table.insert(hints, {
				key = key,
				keyText = key,
				displayKeyText = key,
			})
		end
		helper.makeKeysPrefixFree(hints, defaultHintChars, hintCharOrder)
		local actual = {}
		for _, hint in ipairs(hints) do
			table.insert(actual, hint.key)
		end
		return actual
	end

	it("G と GC の衝突では G を GA に延長する", function()
		assert.are.same({ "GA", "GC" }, runPrefixFree({ "G", "GC" }))
	end)

	it("G と GCA/GCS の衝突では G を GA に延長する", function()
		assert.are.same({ "GA", "GCA", "GCS" }, runPrefixFree({ "G", "GCA", "GCS" }))
	end)

	it("GA が使用済みなら次の候補に延長する", function()
		assert.are.same({ "GA", "GS", "GC" }, runPrefixFree({ "G", "GA", "GC" }))
	end)

	it("多段prefix衝突でも最終的にprefix-freeになる", function()
		assert.are.same({ "AA", "ABA", "ABC" }, runPrefixFree({ "A", "AB", "ABC" }))
	end)

	it("予約キーを hintChars から除外できる", function()
		local reserved = helper.buildReservedHintCharLookup({
			h = "left",
			j = "down",
		}, "k")
		local filtered = helper.filterHintChars(helper.normalizeHintChars({ "A", "H", "J", "K", "L" }), reserved)
		assert.are.same({ "A", "L" }, filtered)
	end)

	it("swapWindowFrameSelectModifiers を正規化できる", function()
		local normalized =
			helper.normalizeSelectModifiers({ "Shift", "CMD" }, "behavior.selection.swapWindowFrame.modifiers")
		assert.are.same({ "cmd", "shift" }, normalized)
	end)

	it("swapWindowFrameSelectModifiers で option は alt として扱う", function()
		local normalized =
			helper.normalizeSelectModifiers({ "option", "cmd" }, "behavior.selection.swapWindowFrame.modifiers")
		assert.are.same({ "cmd", "alt" }, normalized)
	end)

	it("directDirectionHotkeys を正規化できる", function()
		local normalized = helper.normalizeDirectDirectionHotkeys({
			modifiers = { "Shift", "CMD" },
			keys = {
				left = "h",
				right = "l",
			},
		})
		assert.are.same({ "cmd", "shift" }, normalized.modifiers)
		assert.are.equal("h", normalized.keys.left)
		assert.are.equal("l", normalized.keys.right)
		assert.are.equal("left", normalized.keyLookup.h)
		assert.are.equal("right", normalized.keyLookup.l)
	end)

	it("directDirectionHotkeys.modifiers で option は alt として扱う", function()
		local normalized = helper.normalizeDirectDirectionHotkeys({
			modifiers = { "option", "cmd" },
			keys = {
				left = "h",
			},
		})
		assert.are.same({ "cmd", "alt" }, normalized.modifiers)
	end)

	it("directDirectionHotkeys は keys 未指定なら無効化される", function()
		local normalized = helper.normalizeDirectDirectionHotkeys({
			modifiers = { "cmd" },
		})
		assert.are.equal(nil, normalized)
	end)

	it("directDirectionHotkeys は空テーブルなら無効化される", function()
		local normalized = helper.normalizeDirectDirectionHotkeys({})
		assert.are.equal(nil, normalized)
	end)

	it("directDirectionHotkeys.modifiers が空配列ならエラー", function()
		local ok, err = pcall(function()
			helper.normalizeDirectDirectionHotkeys({
				modifiers = {},
				keys = { left = "h" },
			})
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("modifiers must not be empty"))
	end)

	it("directDirectionHotkeys.modifiers に重複があればエラー", function()
		local ok, err = pcall(function()
			helper.normalizeDirectDirectionHotkeys({
				modifiers = { "shift", "SHIFT" },
				keys = { left = "h" },
			})
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("duplicate"))
	end)

	it("directDirectionHotkeys.keys で重複キーがあればエラー", function()
		local ok, err = pcall(function()
			helper.normalizeDirectDirectionHotkeys({
				modifiers = { "cmd" },
				keys = {
					left = "h",
					right = "h",
				},
			})
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("must not contain duplicate keys"))
	end)

	it("swapWindowFrameSelectModifiers が空配列ならエラー", function()
		local ok, err = pcall(function()
			helper.normalizeSelectModifiers({}, "behavior.selection.swapWindowFrame.modifiers")
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("must not be empty"))
	end)

	it("swapWindowFrameSelectModifiers に重複があればエラー", function()
		local ok, err = pcall(function()
			helper.normalizeSelectModifiers({ "shift", "SHIFT" }, "behavior.selection.swapWindowFrame.modifiers")
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("duplicate"))
	end)

	it("swapWindowFrameSelectModifiers に不正な修飾キーがあればエラー", function()
		local ok, err = pcall(function()
			helper.normalizeSelectModifiers({ "hyper" }, "behavior.selection.swapWindowFrame.modifiers")
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("cmd/alt/ctrl/shift/fn"))
	end)

	it("swap判定は修飾キー完全一致のときだけ true", function()
		local swapModifiers =
			helper.normalizeSelectModifiers({ "shift", "cmd" }, "behavior.selection.swapWindowFrame.modifiers")
		assert.is_true(helper.shouldSwapWindowFrameOnSelect(swapModifiers, { "cmd", "shift" }))
		assert.is_false(helper.shouldSwapWindowFrameOnSelect(swapModifiers, { "shift" }))
		assert.is_false(helper.shouldSwapWindowFrameOnSelect(swapModifiers, { "cmd", "alt", "shift" }))
		assert.is_false(helper.shouldSwapWindowFrameOnSelect(nil, { "cmd", "shift" }))
	end)

	it("候補内ヒントの overlay border 色は通常色", function()
		local normal = { red = 0.4, green = 0.6, blue = 0.9, alpha = 0.85 }
		local dimmed = { red = 0.5, green = 0.5, blue = 0.5, alpha = 0.55 }
		local color = helper.resolveHintOverlayBorderColor(true, {
			hintOverlayBorderColor = normal,
			dimmedHintOverlayBorderColor = dimmed,
		})
		assert.are.same(normal, color)
	end)

	it("候補外ヒントの overlay border 色は dimmed 色", function()
		local normal = { red = 0.4, green = 0.6, blue = 0.9, alpha = 0.85 }
		local dimmed = { red = 0.5, green = 0.5, blue = 0.5, alpha = 0.55 }
		local color = helper.resolveHintOverlayBorderColor(false, {
			hintOverlayBorderColor = normal,
			dimmedHintOverlayBorderColor = dimmed,
		})
		assert.are.same(dimmed, color)
	end)

	it("dimmed overlay border 色が無ければ通常色へフォールバック", function()
		local normal = { red = 0.4, green = 0.6, blue = 0.9, alpha = 0.85 }
		local color = helper.resolveHintOverlayBorderColor(false, {
			hintOverlayBorderColor = normal,
		})
		assert.are.same(normal, color)
	end)

	it("active window のヒント本体色は active state を使う", function()
		local color = helper.resolveHintBackgroundColor(true, false, true, {
			bgColor = { red = 0.1, green = 0.2, blue = 0.3, alpha = 0.4 },
			dimmedBgColor = { red = 0.01, green = 0.02, blue = 0.03, alpha = 0.04 },
			activeBgColor = { red = 0.7, green = 0.8, blue = 0.9, alpha = 1.0 },
		})
		assert.are.same({ red = 0.7, green = 0.8, blue = 0.9, alpha = 1.0 }, color)
	end)

	it("active window のヒント文字色は active state を使う", function()
		local color = helper.resolveHintTextColor(true, true, {
			textColor = { red = 0.1, green = 0.2, blue = 0.3, alpha = 0.4 },
			dimmedTextColor = { red = 0.01, green = 0.02, blue = 0.03, alpha = 0.04 },
			activeTextColor = { red = 0.7, green = 0.8, blue = 0.9, alpha = 1.0 },
		})
		assert.are.same({ red = 0.7, green = 0.8, blue = 0.9, alpha = 1.0 }, color)
	end)

	it("active window の hint overlay fill 色は active state を使う", function()
		local color = helper.resolveHintOverlayFillColor(true, true, {
			hintOverlayColor = { red = 0.1, green = 0.2, blue = 0.3, alpha = 0.4 },
			activeHintOverlayColor = { red = 0.7, green = 0.8, blue = 0.9, alpha = 1.0 },
		})
		assert.are.same({ red = 0.7, green = 0.8, blue = 0.9, alpha = 1.0 }, color)
	end)

	it("別 Space 丸バッジは dimmed で別色セットに切り替わる", function()
		local badgeConfig = {
			offSpaceBadgeFillColor = { red = 0.2, green = 0.3, blue = 0.4, alpha = 0.8 },
			offSpaceBadgeStrokeColor = { red = 0.9, green = 1.0, blue = 1.0, alpha = 0.7 },
			offSpaceBadgeTextColor = { red = 1.0, green = 1.0, blue = 1.0, alpha = 0.92 },
			offSpaceBadgeDimmedFillColor = { red = 0.2, green = 0.3, blue = 0.4, alpha = 0.11 },
			offSpaceBadgeDimmedStrokeColor = { red = 0.9, green = 1.0, blue = 1.0, alpha = 0.22 },
			offSpaceBadgeDimmedTextColor = { red = 1.0, green = 1.0, blue = 1.0, alpha = 0.35 },
		}
		local activeFill, activeStroke, activeText = helper.resolveOffSpaceBadgeColors(true, badgeConfig)
		local inactiveFill, inactiveStroke, inactiveText = helper.resolveOffSpaceBadgeColors(false, badgeConfig)

		assert.is_true(activeFill.alpha > inactiveFill.alpha)
		assert.is_true(activeStroke.alpha > inactiveStroke.alpha)
		assert.is_true(activeText.alpha > inactiveText.alpha)
		assert.are.equal(0.11, inactiveFill.alpha)
		assert.are.equal(0.22, inactiveStroke.alpha)
		assert.are.equal(0.35, inactiveText.alpha)
	end)

	it("active window の Space バッジは active state を使う", function()
		local fill, stroke, text = helper.resolveOffSpaceBadgeColors(true, {
			offSpaceBadgeFillColor = { red = 0.2, green = 0.3, blue = 0.4, alpha = 0.8 },
			offSpaceBadgeStrokeColor = { red = 0.9, green = 1.0, blue = 1.0, alpha = 0.7 },
			offSpaceBadgeTextColor = { red = 1.0, green = 1.0, blue = 1.0, alpha = 0.92 },
			activeOffSpaceBadgeFillColor = { red = 0.31, green = 0.32, blue = 0.33, alpha = 0.34 },
			activeOffSpaceBadgeStrokeColor = { red = 0.41, green = 0.42, blue = 0.43, alpha = 0.44 },
			activeOffSpaceBadgeTextColor = { red = 0.51, green = 0.52, blue = 0.53, alpha = 0.54 },
		}, nil, true)

		assert.are.same({ red = 0.31, green = 0.32, blue = 0.33, alpha = 0.34 }, fill)
		assert.are.same({ red = 0.41, green = 0.42, blue = 0.43, alpha = 0.44 }, stroke)
		assert.are.same({ red = 0.51, green = 0.52, blue = 0.53, alpha = 0.54 }, text)
	end)

	it("spaceColors[2] の色が使われる", function()
		local badgeConfig = {
			offSpaceBadgeFillColor = { red = 0.2, green = 0.3, blue = 0.4, alpha = 0.8 },
			offSpaceBadgeStrokeColor = { red = 0.9, green = 1.0, blue = 1.0, alpha = 0.7 },
			offSpaceBadgeTextColor = { red = 1.0, green = 1.0, blue = 1.0, alpha = 0.92 },
			offSpaceBadgeSpaceColors = {
				[1] = {
					fillColor = { red = 0.1, green = 0.1, blue = 0.1, alpha = 0.5 },
					strokeColor = { red = 0.2, green = 0.2, blue = 0.2, alpha = 0.6 },
					textColor = { red = 0.3, green = 0.3, blue = 0.3, alpha = 0.7 },
				},
				[2] = {
					fillColor = { red = 0.30, green = 0.78, blue = 0.47, alpha = 0.56 },
					strokeColor = { red = 0.85, green = 1.00, blue = 0.90, alpha = 0.72 },
					textColor = { red = 0.9, green = 0.9, blue = 0.9, alpha = 0.85 },
				},
			},
		}
		local fill, stroke, text = helper.resolveOffSpaceBadgeColors(true, badgeConfig, 2)
		assert.are.same({ red = 0.30, green = 0.78, blue = 0.47, alpha = 0.56 }, fill)
		assert.are.same({ red = 0.85, green = 1.00, blue = 0.90, alpha = 0.72 }, stroke)
		assert.are.same({ red = 0.9, green = 0.9, blue = 0.9, alpha = 0.85 }, text)
	end)

	it("spaceColors の範囲外はデフォルト色にフォールバック", function()
		local badgeConfig = {
			offSpaceBadgeFillColor = { red = 0.2, green = 0.3, blue = 0.4, alpha = 0.8 },
			offSpaceBadgeStrokeColor = { red = 0.9, green = 1.0, blue = 1.0, alpha = 0.7 },
			offSpaceBadgeTextColor = { red = 1.0, green = 1.0, blue = 1.0, alpha = 0.92 },
			offSpaceBadgeSpaceColors = {
				[1] = {
					fillColor = { red = 0.1, green = 0.1, blue = 0.1, alpha = 0.5 },
					strokeColor = { red = 0.2, green = 0.2, blue = 0.2, alpha = 0.6 },
					textColor = { red = 0.3, green = 0.3, blue = 0.3, alpha = 0.7 },
				},
			},
		}
		local fill, stroke, text = helper.resolveOffSpaceBadgeColors(true, badgeConfig, 10)
		assert.are.same({ red = 0.2, green = 0.3, blue = 0.4, alpha = 0.8 }, fill)
		assert.are.same({ red = 0.9, green = 1.0, blue = 1.0, alpha = 0.7 }, stroke)
		assert.are.same({ red = 1.0, green = 1.0, blue = 1.0, alpha = 0.92 }, text)
	end)

	it("spaceColors=nil ならデフォルト色", function()
		local badgeConfig = {
			offSpaceBadgeFillColor = { red = 0.2, green = 0.3, blue = 0.4, alpha = 0.8 },
			offSpaceBadgeStrokeColor = { red = 0.9, green = 1.0, blue = 1.0, alpha = 0.7 },
			offSpaceBadgeTextColor = { red = 1.0, green = 1.0, blue = 1.0, alpha = 0.92 },
		}
		local fill, stroke, text = helper.resolveOffSpaceBadgeColors(true, badgeConfig, 2)
		assert.are.same({ red = 0.2, green = 0.3, blue = 0.4, alpha = 0.8 }, fill)
		assert.are.same({ red = 0.9, green = 1.0, blue = 1.0, alpha = 0.7 }, stroke)
		assert.are.same({ red = 1.0, green = 1.0, blue = 1.0, alpha = 0.92 }, text)
	end)

	it(
		"spaceColors エントリで一部の色のみ指定時は未指定フィールドがデフォルトにフォールバック",
		function()
			local badgeConfig = {
				offSpaceBadgeFillColor = { red = 0.2, green = 0.3, blue = 0.4, alpha = 0.8 },
				offSpaceBadgeStrokeColor = { red = 0.9, green = 1.0, blue = 1.0, alpha = 0.7 },
				offSpaceBadgeTextColor = { red = 1.0, green = 1.0, blue = 1.0, alpha = 0.92 },
				offSpaceBadgeSpaceColors = {
					[1] = {
						fillColor = { red = 0.5, green = 0.5, blue = 0.5, alpha = 0.5 },
						-- strokeColor, textColor は未指定
					},
				},
			}
			local fill, stroke, text = helper.resolveOffSpaceBadgeColors(true, badgeConfig, 1)
			assert.are.same({ red = 0.5, green = 0.5, blue = 0.5, alpha = 0.5 }, fill)
			assert.are.same({ red = 0.9, green = 1.0, blue = 1.0, alpha = 0.7 }, stroke)
			assert.are.same({ red = 1.0, green = 1.0, blue = 1.0, alpha = 0.92 }, text)
		end
	)

	it("dimmed では spaceColors を無視してグローバルの dimmed 色が使われる", function()
		local badgeConfig = {
			offSpaceBadgeFillColor = { red = 0.2, green = 0.3, blue = 0.4, alpha = 0.8 },
			offSpaceBadgeStrokeColor = { red = 0.9, green = 1.0, blue = 1.0, alpha = 0.7 },
			offSpaceBadgeTextColor = { red = 1.0, green = 1.0, blue = 1.0, alpha = 0.92 },
			offSpaceBadgeDimmedFillColor = { red = 0.11, green = 0.12, blue = 0.13, alpha = 0.11 },
			offSpaceBadgeDimmedStrokeColor = { red = 0.21, green = 0.22, blue = 0.23, alpha = 0.22 },
			offSpaceBadgeDimmedTextColor = { red = 0.31, green = 0.32, blue = 0.33, alpha = 0.35 },
			offSpaceBadgeSpaceColors = {
				[2] = {
					fillColor = { red = 0.30, green = 0.78, blue = 0.47, alpha = 0.56 },
					strokeColor = { red = 0.85, green = 1.00, blue = 0.90, alpha = 0.72 },
					textColor = { red = 0.9, green = 0.9, blue = 0.9, alpha = 0.85 },
				},
			},
		}
		local fill, stroke, text = helper.resolveOffSpaceBadgeColors(false, badgeConfig, 2)
		assert.are.same({ red = 0.11, green = 0.12, blue = 0.13, alpha = 0.11 }, fill)
		assert.are.same({ red = 0.21, green = 0.22, blue = 0.23, alpha = 0.22 }, stroke)
		assert.are.same({ red = 0.31, green = 0.32, blue = 0.33, alpha = 0.35 }, text)
	end)

	it("buildSpaceNumberLookup は hs がなければ空テーブルを返す", function()
		_G.hs = nil
		local lookup = helper.buildSpaceNumberLookup()
		assert.are.same({}, lookup)
	end)

	it("buildSpaceNumberLookup はスペースID→番号の辞書を構築する", function()
		_G.hs = {
			screen = {
				allScreens = function()
					return {
						{
							id = function()
								return 1
							end,
						},
					}
				end,
			},
			spaces = {
				spacesForScreen = function()
					return { 101, 102, 103 }
				end,
			},
		}
		local lookup = helper.buildSpaceNumberLookup()
		assert.are.equal(1, lookup[101])
		assert.are.equal(2, lookup[102])
		assert.are.equal(3, lookup[103])
	end)

	it("buildSpaceIdByNumberLookup はスペースIDの逆引きルックアップを返す", function()
		local screen = {
			id = function()
				return 1
			end,
		}
		_G.hs = {
			spaces = {
				spacesForScreen = function()
					return { 101, 102, 103 }
				end,
			},
		}
		local lookup = helper.buildSpaceIdByNumberLookup(screen)
		assert.are.equal(101, lookup["1"])
		assert.are.equal(102, lookup["2"])
		assert.are.equal(103, lookup["3"])
	end)

	it("buildSpaceIdByNumberLookup は hs 未定義時に空テーブルを返す", function()
		_G.hs = nil
		local screen = {
			id = function()
				return 1
			end,
		}
		local lookup = helper.buildSpaceIdByNumberLookup(screen)
		assert.are.same({}, lookup)
	end)

	it("buildSpaceIdByNumberLookup は9を超えるスペースはルックアップに含めない", function()
		local screen = {
			id = function()
				return 1
			end,
		}
		_G.hs = {
			spaces = {
				spacesForScreen = function()
					return { 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111 }
				end,
			},
		}
		local lookup = helper.buildSpaceIdByNumberLookup(screen)
		assert.are.equal(109, lookup["9"])
		assert.is_nil(lookup["10"])
		assert.is_nil(lookup["11"])
	end)

	it("spaceNumberForWindow はウィンドウのスペース番号を返す", function()
		_G.hs = {
			spaces = {
				windowSpaces = function()
					return { 102 }
				end,
			},
		}
		local lookup = { [101] = 1, [102] = 2, [103] = 3 }
		assert.are.equal(2, helper.spaceNumberForWindow(42, lookup))
	end)

	it("spaceNumberForWindow は hs.spaces がなければ nil を返す", function()
		_G.hs = nil
		assert.is_nil(helper.spaceNumberForWindow(42, {}))
	end)

	it("spaceNumberForWindow はルックアップにないスペースなら nil を返す", function()
		_G.hs = {
			spaces = {
				windowSpaces = function()
					return { 999 }
				end,
			},
		}
		local lookup = { [101] = 1 }
		assert.is_nil(helper.spaceNumberForWindow(42, lookup))
	end)

	it("dockWindowXBlend=0 では中央寄せレイアウトXを使う", function()
		local x = helper.resolveOccludedDockItemX({ x = 0, y = 0, w = 1200, h = 800 }, 180, 320, 700, 320, 0)
		assert.are.equal(320, x)
	end)

	it("開始Xは中央寄せ", function()
		local startX = helper.resolveOccludedDockStartX({ x = 100, y = 0, w = 1200, h = 800 }, 400)
		assert.are.equal(500, startX)
	end)

	it("dockWindowXBlend=1 では対象ウィンドウ中心にヒント中心を合わせる", function()
		local x = helper.resolveOccludedDockItemX({ x = 0, y = 0, w = 1200, h = 800 }, 180, 320, 700, 320, 1)
		assert.are.equal(610, x)
	end)

	it("dockWindowXBlend=0.5 では中央と対象中心基準xの中間へ寄る", function()
		local x = helper.resolveOccludedDockItemX({ x = 0, y = 0, w = 1200, h = 800 }, 180, 320, 700, 320, 0.5)
		assert.are.equal(465, x)
	end)

	it("dockWindowXBlend=1 でも重なり回避の最小Xを下回らない", function()
		local x = helper.resolveOccludedDockItemX({ x = 0, y = 0, w = 1200, h = 800 }, 180, 320, 200, 320, 1)
		assert.are.equal(320, x)
	end)

	it("dockWindowXBlend=1 では画面右端に収まるようにクランプされる", function()
		local x = helper.resolveOccludedDockItemX({ x = 0, y = 0, w = 800, h = 600 }, 180, 320, 900, 320, 1)
		assert.are.equal(620, x)
	end)

	it("dockWindowXBlend=1 で同一中心の複数ウィンドウは中央寄せを維持する", function()
		local xs = helper.resolveOccludedDockItemXs({ x = 0, y = 0, w = 1200, h = 800 }, {
			{ width = 180, centeredX = 222, windowCenterX = 600 },
			{ width = 180, centeredX = 414, windowCenterX = 600 },
			{ width = 180, centeredX = 606, windowCenterX = 600 },
			{ width = 180, centeredX = 798, windowCenterX = 600 },
		}, 12, 1)
		assert.are.same({ 222, 414, 606, 798 }, xs)
	end)

	it("dockWindowYBlend=0 では下ドック配置Yを使う", function()
		local y = helper.resolveOccludedDockItemY({ x = 0, y = 0, w = 1200, h = 800 }, 120, 500, 220, 0, 180)
		assert.are.equal(500, y)
	end)

	it("dockWindowYBlend=1 では上半分ウィンドウを上端マージンへ寄せる", function()
		local y = helper.resolveOccludedDockItemY({ x = 0, y = 0, w = 1200, h = 800 }, 120, 500, 220, 1, 180)
		assert.are.equal(180, y)
	end)

	it("dockWindowYBlend=0.5 では下ドックと上端マージンの中間へ寄る", function()
		local y = helper.resolveOccludedDockItemY({ x = 0, y = 0, w = 1200, h = 800 }, 120, 500, 220, 0.5, 180)
		assert.are.equal(340, y)
	end)

	it("dockWindowYBlend=1 でも下半分ウィンドウは下ドック配置を維持する", function()
		local y = helper.resolveOccludedDockItemY({ x = 0, y = 0, w = 1200, h = 800 }, 120, 500, 700, 1, 180)
		assert.are.equal(500, y)
	end)

	it("dockWindowYBlend=1 では上端マージンが大きすぎても画面下端に収まる", function()
		local y = helper.resolveOccludedDockItemY({ x = 0, y = 0, w = 1200, h = 800 }, 120, 500, 220, 1, 760)
		assert.are.equal(680, y)
	end)

	it("dockWindowYBlend=1 では画面下端に収まるようにクランプされる", function()
		local y = helper.resolveOccludedDockItemY({ x = 0, y = 0, w = 1200, h = 800 }, 120, 900, 900, 1, 180)
		assert.are.equal(680, y)
	end)

	it("前面ヒントと重なる背面ドックは上方向へ退避する", function()
		local frame = helper.resolveOccludedDockFrameAvoidingRects(
			{ x = 0, y = 0, w = 1200, h = 800 },
			{ x = 400, y = 500, w = 180, h = 120 },
			{
				{ x = 420, y = 520, w = 200, h = 120 },
			},
			12
		)
		assert.are.same({ x = 400, y = 392, w = 180, h = 120 }, frame)
	end)

	it("上方向だけで解消できない場合は左右へ探索する", function()
		local frame = helper.resolveOccludedDockFrameAvoidingRects(
			{ x = 0, y = 0, w = 1200, h = 800 },
			{ x = 400, y = 500, w = 180, h = 120 },
			{
				{ x = 390, y = 0, w = 220, h = 800 },
			},
			12
		)
		assert.are.same({ x = 208, y = 500, w = 180, h = 120 }, frame)
	end)

	it("逃げ場がない場合は元のドック位置を維持する", function()
		local frame = helper.resolveOccludedDockFrameAvoidingRects(
			{ x = 0, y = 0, w = 180, h = 120 },
			{ x = 0, y = 0, w = 180, h = 120 },
			{
				{ x = 0, y = 0, w = 180, h = 120 },
			},
			12
		)
		assert.are.same({ x = 0, y = 0, w = 180, h = 120 }, frame)
	end)

	it("文字キーの入力修飾キー集合を生成できる", function()
		local bindings = helper.collectModalInputModifiers(
			"w",
			helper.normalizeSelectModifiers({ "cmd" }, "behavior.selection.swapWindowFrame.modifiers")
		)
		assert.are.same({ {}, { "cmd" }, { "shift" } }, bindings)
	end)

	it("非文字キーでも swap 修飾キーを追加できる", function()
		local bindings = helper.collectModalInputModifiers(
			"f18",
			helper.normalizeSelectModifiers({ "shift" }, "behavior.selection.swapWindowFrame.modifiers")
		)
		assert.are.same({ {}, { "shift" } }, bindings)
	end)

	it("swap修飾キーが shift のとき文字キーで重複を除去できる", function()
		local bindings = helper.collectModalInputModifiers(
			"w",
			helper.normalizeSelectModifiers({ "shift" }, "behavior.selection.swapWindowFrame.modifiers")
		)
		assert.are.same({ {}, { "shift" } }, bindings)
	end)

	it("swap付き focusBack では previousWindow を優先する", function()
		local previousWin = { label = "previous" }
		local focusBackCalls = 0
		local focusHistory = {
			getPreviousWindow = function()
				return previousWin
			end,
			focusBack = function()
				focusBackCalls = focusBackCalls + 1
				return nil
			end,
		}

		local win, shouldSwap = helper.resolveFocusBackTargetWindow(focusHistory, true)
		assert.are.equal(previousWin, win)
		assert.is_true(shouldSwap)
		assert.are.equal(0, focusBackCalls)
	end)

	it("swap付き focusBack で previousWindow が無ければ focusBack へフォールバックする", function()
		local focusedWin = { label = "focused" }
		local focusBackCalls = 0
		local focusHistory = {
			getPreviousWindow = function()
				return nil
			end,
			focusBack = function()
				focusBackCalls = focusBackCalls + 1
				return focusedWin
			end,
		}

		local win, shouldSwap = helper.resolveFocusBackTargetWindow(focusHistory, true)
		assert.are.equal(focusedWin, win)
		assert.is_false(shouldSwap)
		assert.are.equal(1, focusBackCalls)
	end)

	it("collectCandidateWindows は includeOtherSpaces=false なら current Space のみ返す", function()
		local function makeWindow(id, frame)
			return {
				id = function()
					return id
				end,
				frame = function()
					return frame
				end,
			}
		end
		local currentA = makeWindow(1, { x = 0, y = 0, w = 100, h = 100 })
		local currentB = makeWindow(2, { x = 120, y = 0, w = 100, h = 100 })
		_G.hs = {
			window = {
				visibleWindows = function()
					return { currentA, currentB }
				end,
				filter = {
					new = function()
						return {
							getWindows = function()
								error("should not be called")
							end,
						}
					end,
				},
			},
		}

		local wins, lookup = helper.collectCandidateWindows(false)
		assert.are.same({ currentA, currentB }, wins)
		assert.is_true(lookup[1])
		assert.is_true(lookup[2])
	end)

	it("collectCandidateWindows は includeOtherSpaces=true なら別 Space 候補を追加する", function()
		local function makeWindow(id, frame)
			return {
				id = function()
					return id
				end,
				frame = function()
					return frame
				end,
			}
		end
		local currentA = makeWindow(1, { x = 0, y = 0, w = 100, h = 100 })
		local currentB = makeWindow(2, { x = 120, y = 0, w = 100, h = 100 })
		local offSpace = makeWindow(3, { x = 240, y = 0, w = 100, h = 100 })
		_G.hs = {
			window = {
				visibleWindows = function()
					return { currentA, currentB }
				end,
				filter = {
					new = function()
						return {
							getWindows = function()
								return { currentB, offSpace }
							end,
						}
					end,
				},
			},
		}

		local wins, lookup = helper.collectCandidateWindows(true)
		assert.are.same({ currentA, currentB, offSpace }, wins)
		assert.is_true(lookup[1])
		assert.is_true(lookup[2])
		assert.is_nil(lookup[3])
	end)

	it("splitCandidatesByCurrentSpace は別 Space 候補を分離できる", function()
		local function makeWindow(id, frame)
			return {
				id = function()
					return id
				end,
				frame = function()
					return frame
				end,
			}
		end
		local currentA = makeWindow(1, { x = 0, y = 0, w = 100, h = 100 })
		local currentB = makeWindow(2, { x = 120, y = 0, w = 100, h = 100 })
		local offSpace = makeWindow(3, { x = 240, y = 0, w = 100, h = 100 })

		local currentWins, offSpaceWins = helper.splitCandidatesByCurrentSpace({ currentA, offSpace, currentB }, {
			[1] = true,
			[2] = true,
		})

		assert.are.same({ currentA, currentB }, currentWins)
		assert.are.same({ offSpace }, offSpaceWins)
	end)

	it("macOS Native Tabs 対象アプリの別 Space かつ Space番号不明な候補は除外する", function()
		assert.is_true(helper.shouldSkipUnknownSpaceMacosNativeTabCandidate(true, true, nil))
		assert.is_false(helper.shouldSkipUnknownSpaceMacosNativeTabCandidate(true, true, 2))
		assert.is_false(helper.shouldSkipUnknownSpaceMacosNativeTabCandidate(true, false, nil))
		assert.is_false(helper.shouldSkipUnknownSpaceMacosNativeTabCandidate(false, true, nil))
	end)

	it("通常 focusBack では focusBack を使う", function()
		local focusedWin = { label = "focused" }
		local focusBackCalls = 0
		local focusHistory = {
			getPreviousWindow = function()
				return { label = "previous" }
			end,
			focusBack = function()
				focusBackCalls = focusBackCalls + 1
				return focusedWin
			end,
		}

		local win, shouldSwap = helper.resolveFocusBackTargetWindow(focusHistory, false)
		assert.are.equal(focusedWin, win)
		assert.is_false(shouldSwap)
		assert.are.equal(1, focusBackCalls)
	end)

	it("同一先頭文字が競合したらアプリ名の次候補文字を使う", function()
		local entries = {
			{
				appKey = "com.example.github",
				appTitle = "GitHub",
				basePrefix = "G",
				isOverridePrefix = false,
			},
			{
				appKey = "com.example.chrome",
				appTitle = "Google Chrome",
				basePrefix = "G",
				isOverridePrefix = false,
			},
		}
		helper.assignUniquePrefixes(entries, "A", allowedPrefixes)
		assert.are.equal("G", entries[1].prefix)
		assert.are.equal("O", entries[2].prefix)
	end)

	it("prefix はアプリ単位で固定される", function()
		local entries = {
			{
				appKey = "com.example.chrome",
				appTitle = "Google Chrome",
				basePrefix = "G",
				isOverridePrefix = false,
			},
			{
				appKey = "com.example.chrome",
				appTitle = "Google Chrome",
				basePrefix = "G",
				isOverridePrefix = false,
			},
		}
		helper.assignUniquePrefixes(entries, "A", allowedPrefixes)
		assert.are.equal("G", entries[1].prefix)
		assert.are.equal("G", entries[2].prefix)
	end)

	it("override prefix は重複していても維持される", function()
		local entries = {
			{
				appKey = "com.example.github",
				appTitle = "GitHub",
				basePrefix = "G",
				isOverridePrefix = false,
			},
			{
				appKey = "com.example.override",
				appTitle = "Another",
				basePrefix = "G",
				isOverridePrefix = true,
			},
		}
		helper.assignUniquePrefixes(entries, "A", allowedPrefixes)
		assert.are.equal("G", entries[1].prefix)
		assert.are.equal("G", entries[2].prefix)
	end)

	it("同一アプリでも異なる override prefix はそれぞれ維持される", function()
		local entries = {
			{
				appKey = "md.obsidian",
				appTitle = "Obsidian",
				basePrefix = "M",
				isOverridePrefix = true,
			},
			{
				appKey = "md.obsidian",
				appTitle = "Obsidian",
				basePrefix = "D",
				isOverridePrefix = true,
			},
		}
		helper.assignUniquePrefixes(entries, "A", allowedPrefixes)
		assert.are.equal("M", entries[1].prefix)
		assert.are.equal("D", entries[2].prefix)
	end)

	local function stubWindow(id, frame)
		return {
			id = function()
				return id
			end,
			frame = function()
				return frame
			end,
		}
	end

	local function stubSwappableWindow(id, frame)
		local currentFrame = frame
		local setFrameCalls = {}
		local setFrameWithWorkaroundsCalls = {}
		local focusCalls = 0
		return {
			id = function()
				return id
			end,
			frame = function()
				return currentFrame
			end,
			setFrame = function(_, nextFrame, duration)
				table.insert(setFrameCalls, { frame = nextFrame, duration = duration })
				currentFrame = nextFrame
			end,
			setFrameWithWorkarounds = function(_, nextFrame, duration)
				table.insert(setFrameWithWorkaroundsCalls, { frame = nextFrame, duration = duration })
				currentFrame = nextFrame
			end,
			focus = function()
				focusCalls = focusCalls + 1
			end,
			_getSetFrameCalls = function()
				return setFrameCalls
			end,
			_getSetFrameWithWorkaroundsCalls = function()
				return setFrameWithWorkaroundsCalls
			end,
			_getFocusCalls = function()
				return focusCalls
			end,
		}
	end

	local function stubSetFrameOnlyWindow(id, frame)
		local currentFrame = frame
		local setFrameCalls = {}
		return {
			id = function()
				return id
			end,
			frame = function()
				return currentFrame
			end,
			setFrame = function(_, nextFrame, duration)
				table.insert(setFrameCalls, { frame = nextFrame, duration = duration })
				currentFrame = nextFrame
			end,
			_getSetFrameCalls = function()
				return setFrameCalls
			end,
		}
	end

	it("swapWindowFrames は2ウィンドウの frame を入れ替える", function()
		local current = stubSwappableWindow(1, { x = 0, y = 0, w = 100, h = 100 })
		local target = stubSwappableWindow(2, { x = 200, y = 100, w = 300, h = 200 })
		local ok = helper.swapWindowFrames(current, target)

		assert.is_true(ok)
		assert.are.same({ x = 200, y = 100, w = 300, h = 200 }, current:frame())
		assert.are.same({ x = 0, y = 0, w = 100, h = 100 }, target:frame())
		assert.are.equal(0, #current:_getSetFrameCalls())
		assert.are.equal(0, #target:_getSetFrameCalls())
		assert.are.equal(1, #current:_getSetFrameWithWorkaroundsCalls())
		assert.are.equal(1, #target:_getSetFrameWithWorkaroundsCalls())
		assert.are.equal(0, current:_getSetFrameWithWorkaroundsCalls()[1].duration)
		assert.are.equal(0, target:_getSetFrameWithWorkaroundsCalls()[1].duration)
	end)

	it("swapWindowFrames は workaround 非対応なら setFrame(..., 0) にフォールバックする", function()
		local current = stubSetFrameOnlyWindow(1, { x = 0, y = 0, w = 100, h = 100 })
		local target = stubSetFrameOnlyWindow(2, { x = 200, y = 100, w = 300, h = 200 })
		local ok = helper.swapWindowFrames(current, target)

		assert.is_true(ok)
		assert.are.same({ x = 200, y = 100, w = 300, h = 200 }, current:frame())
		assert.are.same({ x = 0, y = 0, w = 100, h = 100 }, target:frame())
		assert.are.equal(0, current:_getSetFrameCalls()[1].duration)
		assert.are.equal(0, target:_getSetFrameCalls()[1].duration)
	end)

	it("swapWindowFrames は同一IDなら入れ替えない", function()
		local current = stubSwappableWindow(1, { x = 0, y = 0, w = 100, h = 100 })
		local target = stubSwappableWindow(1, { x = 200, y = 100, w = 300, h = 200 })
		local ok = helper.swapWindowFrames(current, target)

		assert.is_false(ok)
		assert.are.equal(0, #current:_getSetFrameCalls())
		assert.are.equal(0, #target:_getSetFrameCalls())
		assert.are.equal(0, #current:_getSetFrameWithWorkaroundsCalls())
		assert.are.equal(0, #target:_getSetFrameWithWorkaroundsCalls())
	end)

	it("swapWindowFrames は frame setter 非対応ウィンドウがあれば入れ替えない", function()
		local current = stubWindow(1, { x = 0, y = 0, w = 100, h = 100 })
		local target = stubSwappableWindow(2, { x = 200, y = 100, w = 300, h = 200 })
		local ok = helper.swapWindowFrames(current, target)
		assert.is_false(ok)
		assert.are.equal(0, #target:_getSetFrameCalls())
		assert.are.equal(0, #target:_getSetFrameWithWorkaroundsCalls())
	end)

	it("swapWindowFrames は frame が x/y/w/h を持たなければ入れ替えない", function()
		local current = stubSwappableWindow(1, { x = 0, y = 0, w = 100, h = 100 })
		local target = stubSwappableWindow(2, { x = 200, y = 100, h = 200 })
		local ok = helper.swapWindowFrames(current, target)
		assert.is_false(ok)
		assert.are.equal(0, #current:_getSetFrameCalls())
		assert.are.equal(0, #target:_getSetFrameCalls())
		assert.are.equal(0, #current:_getSetFrameWithWorkaroundsCalls())
		assert.are.equal(0, #target:_getSetFrameWithWorkaroundsCalls())
	end)

	it("方向移動は指定方向の最近傍ウィンドウを返す", function()
		local current = stubWindow(1, { x = 0, y = 0, w = 10, h = 10 })
		local nearRight = stubWindow(2, { x = 20, y = 0, w = 10, h = 10 })
		local farRight = stubWindow(3, { x = 80, y = 0, w = 10, h = 10 })
		local target = helper.findDirectionalWindowTarget(current, { nearRight, farRight }, "right", nil)
		assert.are.equal(2, target:id())
	end)

	it(
		"上下左右: preferredVisibleRatio 指定時は大きく隠れた近傍候補より可視候補を優先する",
		function()
			local current = stubWindow(1, { x = 0, y = 0, w = 10, h = 100 })
			local nearRight = stubWindow(2, { x = 20, y = 0, w = 100, h = 100 })
			local farRight = stubWindow(3, { x = 140, y = 0, w = 100, h = 100 })
			local blocker = stubWindow(9, { x = 20, y = 0, w = 100, h = 75 })
			local target = helper.findDirectionalWindowTarget(
				current,
				{ nearRight, farRight },
				"right",
				nil,
				{ blocker, current, nearRight, farRight },
				{
					occlusionSamplingEnabled = false,
					preferredVisibleRatio = 0.5,
				}
			)
			assert.are.equal(3, target:id())
		end
	)

	it("上下左右: preferredVisibleRatio は移動方向側の露出を優先する", function()
		local current = stubWindow(1, { x = 65, y = 20, w = 20, h = 60 })
		local containingRight = stubWindow(2, { x = 0, y = 0, w = 100, h = 100 })
		local exposedRight = stubWindow(3, { x = 130, y = 20, w = 80, h = 60 })
		local target = helper.findDirectionalWindowTarget(
			current,
			{ containingRight, exposedRight },
			"right",
			nil,
			{ current, containingRight, exposedRight },
			{
				occlusionSamplingEnabled = false,
				preferredVisibleRatio = 0.5,
			}
		)
		assert.are.equal(3, target:id())
	end)

	it("上下左右: 移動方向の大きな背面候補より内側の前面候補を優先する", function()
		local current = stubWindow(1, { x = 0, y = 0, w = 100, h = 120 })
		local backgroundRight = stubWindow(2, { x = 110, y = 0, w = 170, h = 120 })
		local foregroundInside = stubWindow(3, { x = 140, y = 25, w = 70, h = 70 })
		local target = helper.findDirectionalWindowTarget(
			current,
			{ backgroundRight, foregroundInside },
			"right",
			nil,
			{ current, foregroundInside, backgroundRight },
			{
				occlusionSamplingEnabled = false,
				preferredVisibleRatio = 0.5,
			}
		)
		assert.are.equal(3, target:id())
	end)

	it(
		"上下左右: 移動方向の大きな候補に内包された候補をウィンドウ順序に依存せず優先する",
		function()
			local current = stubWindow(1, { x = 320, y = 0, w = 100, h = 120 })
			local containingLeft = stubWindow(2, { x = 0, y = 0, w = 280, h = 120 })
			local containedLeft = stubWindow(3, { x = 170, y = 25, w = 70, h = 70 })
			local target = helper.findDirectionalWindowTarget(
				current,
				{ containingLeft, containedLeft },
				"left",
				nil,
				{ current, containingLeft, containedLeft },
				{
					occlusionSamplingEnabled = false,
					preferredVisibleRatio = 0.5,
				}
			)
			assert.are.equal(3, target:id())
		end
	)

	it("上下左右: 数pxはみ出した内包候補も移動先として優先する", function()
		local current = stubWindow(1, { x = 320, y = 0, w = 100, h = 120 })
		local containingLeft = stubWindow(2, { x = 0, y = 0, w = 280, h = 120 })
		local slightlyProtrudingLeft = stubWindow(3, { x = 206, y = 25, w = 80, h = 70 })
		local target = helper.findDirectionalWindowTarget(
			current,
			{ containingLeft, slightlyProtrudingLeft },
			"left",
			nil,
			{ current, containingLeft, slightlyProtrudingLeft },
			{
				occlusionSamplingEnabled = false,
				preferredVisibleRatio = 0.5,
			}
		)
		assert.are.equal(3, target:id())
	end)

	it("上下左右: 左右移動では高さが同じ内包候補も移動先として優先する", function()
		local current = stubWindow(1, { x = 320, y = 0, w = 100, h = 120 })
		local containingLeft = stubWindow(2, { x = 0, y = 0, w = 280, h = 120 })
		local containedSameHeight = stubWindow(3, { x = 170, y = 0, w = 70, h = 120 })
		local target = helper.findDirectionalWindowTarget(
			current,
			{ containingLeft, containedSameHeight },
			"left",
			nil,
			{ current, containingLeft, containedSameHeight },
			{
				occlusionSamplingEnabled = false,
				preferredVisibleRatio = 0.5,
			}
		)
		assert.are.equal(3, target:id())
	end)

	it(
		"上下左右: preferredVisibleRatio=0 なら部分遮蔽していても既存どおり近傍候補を優先する",
		function()
			local current = stubWindow(1, { x = 0, y = 0, w = 10, h = 100 })
			local nearRight = stubWindow(2, { x = 20, y = 0, w = 100, h = 100 })
			local farRight = stubWindow(3, { x = 140, y = 0, w = 100, h = 100 })
			local blocker = stubWindow(9, { x = 20, y = 0, w = 100, h = 75 })
			local target = helper.findDirectionalWindowTarget(
				current,
				{ nearRight, farRight },
				"right",
				nil,
				{ blocker, current, nearRight, farRight },
				{
					occlusionSamplingEnabled = false,
					preferredVisibleRatio = 0,
				}
			)
			assert.are.equal(2, target:id())
		end
	)

	it("上下左右: 可視率がしきい値以上なら既存スコア順を維持する", function()
		local current = stubWindow(1, { x = 0, y = 0, w = 10, h = 100 })
		local nearRight = stubWindow(2, { x = 20, y = 0, w = 100, h = 100 })
		local farRight = stubWindow(3, { x = 140, y = 0, w = 100, h = 100 })
		local blocker = stubWindow(9, { x = 20, y = 0, w = 100, h = 50 })
		local target = helper.findDirectionalWindowTarget(
			current,
			{ nearRight, farRight },
			"right",
			nil,
			{ blocker, current, nearRight, farRight },
			{
				occlusionSamplingEnabled = false,
				preferredVisibleRatio = 0.5,
			}
		)
		assert.are.equal(2, target:id())
	end)

	it("上下左右: すべてしきい値未満なら可視率が高い候補を優先する", function()
		local current = stubWindow(1, { x = 0, y = 0, w = 10, h = 100 })
		local mostlyHidden = stubWindow(2, { x = 20, y = 0, w = 100, h = 100 })
		local lessHidden = stubWindow(3, { x = 140, y = 0, w = 100, h = 100 })
		local bigBlocker = stubWindow(9, { x = 20, y = 0, w = 100, h = 75 })
		local smallBlocker = stubWindow(8, { x = 140, y = 0, w = 100, h = 50 })
		local target = helper.findDirectionalWindowTarget(
			current,
			{ mostlyHidden, lessHidden },
			"right",
			nil,
			{ bigBlocker, smallBlocker, current, mostlyHidden, lessHidden },
			{
				occlusionSamplingEnabled = false,
				preferredVisibleRatio = 0.75,
			}
		)
		assert.are.equal(3, target:id())
	end)

	it(
		"上下左右: しきい値未満の候補しかなくてもフォールバックとして選択する",
		function()
			local current = stubWindow(1, { x = 0, y = 0, w = 10, h = 100 })
			local mostlyHidden = stubWindow(2, { x = 20, y = 0, w = 100, h = 100 })
			local blocker = stubWindow(9, { x = 20, y = 0, w = 100, h = 75 })
			local target = helper.findDirectionalWindowTarget(
				current,
				{ mostlyHidden },
				"right",
				nil,
				{ blocker, current, mostlyHidden },
				{
					occlusionSamplingEnabled = false,
					preferredVisibleRatio = 0.5,
				}
			)
			assert.are.equal(2, target:id())
		end
	)

	it("同距離候補に previousWindow が含まれるとそちらを優先する", function()
		local current = stubWindow(1, { x = 0, y = 0, w = 10, h = 10 })
		local win2 = stubWindow(2, { x = 20, y = 0, w = 10, h = 10 })
		local win3 = stubWindow(3, { x = 20, y = 0, w = 10, h = 10 })
		local target = helper.findDirectionalWindowTarget(current, { win2, win3 }, "right", win3)
		assert.are.equal(3, target:id())
	end)

	it("指定方向に候補がなければ nil を返す", function()
		local current = stubWindow(1, { x = 0, y = 0, w = 10, h = 10 })
		local left = stubWindow(2, { x = -30, y = 0, w = 10, h = 10 })
		local target = helper.findDirectionalWindowTarget(current, { left }, "right", nil)
		assert.are.equal(nil, target)
	end)

	it("右方向: 中心が少し右でも右端が現在ウィンドウ内なら候補にしない", function()
		local current = stubWindow(1, { x = 100, y = 100, w = 300, h = 200 })
		local centeredShort = stubWindow(2, { x = 160, y = 130, w = 260, h = 120 })
		local right = stubWindow(3, { x = 430, y = 120, w = 120, h = 160 })
		local target = helper.findDirectionalWindowTarget(current, { centeredShort, right }, "right", nil)
		assert.are.equal(3, target:id())
	end)

	it("右方向: 右端が現在ウィンドウを越えない候補だけなら nil を返す", function()
		local current = stubWindow(1, { x = 100, y = 100, w = 300, h = 200 })
		local centeredShort = stubWindow(2, { x = 160, y = 130, w = 230, h = 120 })
		local target = helper.findDirectionalWindowTarget(current, { centeredShort }, "right", nil)
		assert.are.equal(nil, target)
	end)

	it(
		"右方向: 主軸重なり率がしきい値以下なら副軸重なりが小さくても候補に残る",
		function()
			local current = stubWindow(1, { x = 100, y = 100, w = 100, h = 100 })
			local detachedRight = stubWindow(2, { x = 180, y = 230, w = 100, h = 100 })
			local target = helper.findDirectionalWindowTarget(current, { detachedRight }, "right", nil)
			assert.are.equal(2, target:id())
		end
	)

	it(
		"右方向: 主軸重なり率がしきい値を超え副軸重なり率が不足する候補は除外する",
		function()
			local current = stubWindow(1, { x = 100, y = 100, w = 100, h = 100 })
			local mostlyStacked = stubWindow(2, { x = 170, y = 230, w = 100, h = 100 })
			local target = helper.findDirectionalWindowTarget(current, { mostlyStacked }, "right", nil)
			assert.are.equal(nil, target)
		end
	)

	it(
		"右方向: 主軸重なり率がしきい値を超えても副軸重なり率が足りれば候補に残る",
		function()
			local current = stubWindow(1, { x = 100, y = 100, w = 100, h = 100 })
			local alignedRight = stubWindow(2, { x = 170, y = 150, w = 100, h = 100 })
			local target = helper.findDirectionalWindowTarget(current, { alignedRight }, "right", nil)
			assert.are.equal(2, target:id())
		end
	)

	it("右方向: 主軸で重なった候補を除外し、離れた候補を選ぶ", function()
		local current = stubWindow(1, { x = 100, y = 200, w = 100, h = 100 })
		local stackedWide = stubWindow(2, { x = 120, y = 80, w = 220, h = 80 })
		local detachedRight = stubWindow(3, { x = 260, y = 330, w = 100, h = 100 })
		local target = helper.findDirectionalWindowTarget(current, { stackedWide, detachedRight }, "right", nil)
		assert.are.equal(3, target:id())
	end)

	it("左図: 1->下 は 3", function()
		local win1 = stubWindow(1, { x = 100, y = 100, w = 200, h = 120 })
		local win2 = stubWindow(2, { x = 300, y = 100, w = 200, h = 120 })
		local win3 = stubWindow(3, { x = 190, y = 230, w = 220, h = 120 })
		local target = helper.findDirectionalWindowTarget(win1, { win2, win3 }, "down", nil)
		assert.are.equal(3, target:id())
	end)

	it("左図: 1->右 は 2", function()
		local win1 = stubWindow(1, { x = 100, y = 100, w = 200, h = 120 })
		local win2 = stubWindow(2, { x = 300, y = 100, w = 200, h = 120 })
		local win3 = stubWindow(3, { x = 190, y = 230, w = 220, h = 120 })
		local target = helper.findDirectionalWindowTarget(win1, { win2, win3 }, "right", nil)
		assert.are.equal(2, target:id())
	end)

	it("左図: 2->左 は 1", function()
		local win1 = stubWindow(1, { x = 100, y = 100, w = 200, h = 120 })
		local win2 = stubWindow(2, { x = 300, y = 100, w = 200, h = 120 })
		local win3 = stubWindow(3, { x = 190, y = 230, w = 220, h = 120 })
		local target = helper.findDirectionalWindowTarget(win2, { win1, win3 }, "left", nil)
		assert.are.equal(1, target:id())
	end)

	it("左図: 2->下 は 3", function()
		local win1 = stubWindow(1, { x = 100, y = 100, w = 200, h = 120 })
		local win2 = stubWindow(2, { x = 300, y = 100, w = 200, h = 120 })
		local win3 = stubWindow(3, { x = 190, y = 230, w = 220, h = 120 })
		local target = helper.findDirectionalWindowTarget(win2, { win1, win3 }, "down", nil)
		assert.are.equal(3, target:id())
	end)

	it("左図: 3->上 は前面順で変わる", function()
		local win1 = stubWindow(1, { x = 100, y = 100, w = 200, h = 120 })
		local win2 = stubWindow(2, { x = 300, y = 100, w = 200, h = 120 })
		local win3 = stubWindow(3, { x = 190, y = 230, w = 220, h = 120 })

		local target1 = helper.findDirectionalWindowTarget(win3, { win1, win2 }, "up", nil, { win1, win2, win3 })
		assert.are.equal(1, target1:id())

		local target2 = helper.findDirectionalWindowTarget(win3, { win1, win2 }, "up", nil, { win2, win1, win3 })
		assert.are.equal(2, target2:id())
	end)

	it("上方向: 重なり差がしきい値以内なら前面候補を優先する", function()
		local current = stubWindow(431, { x = 16, y = 60, w = 1768, h = 1093 })
		local widerBack = stubWindow(328, { x = -237, y = -1424, w = 2276, h = 1408 })
		local front = stubWindow(567, { x = 41, y = -1424, w = 1720, h = 1408 })

		local target = helper.findDirectionalWindowTarget(
			current,
			{ widerBack, front },
			"up",
			nil,
			{ current, front, widerBack },
			{ cardinalOverlapTieThresholdPx = 48 }
		)
		assert.are.equal(567, target:id())
	end)

	it("上方向: 重なり差がしきい値を超えるなら重なり量を優先する", function()
		local current = stubWindow(431, { x = 16, y = 60, w = 1768, h = 1093 })
		local widerBack = stubWindow(328, { x = -237, y = -1424, w = 2276, h = 1408 })
		local front = stubWindow(567, { x = 41, y = -1424, w = 1720, h = 1408 })

		local target = helper.findDirectionalWindowTarget(
			current,
			{ widerBack, front },
			"up",
			nil,
			{ current, front, widerBack },
			{ cardinalOverlapTieThresholdPx = 47 }
		)
		assert.are.equal(328, target:id())
	end)

	it("右図: 1->下 は 4", function()
		local win1 = stubWindow(1, { x = 100, y = 100, w = 140, h = 120 })
		local win2 = stubWindow(2, { x = 250, y = 100, w = 80, h = 120 })
		local win3 = stubWindow(3, { x = 340, y = 100, w = 140, h = 120 })
		local win4 = stubWindow(4, { x = 180, y = 230, w = 130, h = 120 })
		local target = helper.findDirectionalWindowTarget(win1, { win2, win3, win4 }, "down", nil)
		assert.are.equal(4, target:id())
	end)

	it("右図: 1->右 は 2", function()
		local win1 = stubWindow(1, { x = 100, y = 100, w = 140, h = 120 })
		local win2 = stubWindow(2, { x = 250, y = 100, w = 80, h = 120 })
		local win3 = stubWindow(3, { x = 340, y = 100, w = 140, h = 120 })
		local win4 = stubWindow(4, { x = 180, y = 230, w = 130, h = 120 })
		local target = helper.findDirectionalWindowTarget(win1, { win2, win3, win4 }, "right", nil)
		assert.are.equal(2, target:id())
	end)

	it("右図: 2->左 は 1", function()
		local win1 = stubWindow(1, { x = 100, y = 100, w = 140, h = 120 })
		local win2 = stubWindow(2, { x = 250, y = 100, w = 80, h = 120 })
		local win3 = stubWindow(3, { x = 340, y = 100, w = 140, h = 120 })
		local win4 = stubWindow(4, { x = 180, y = 230, w = 130, h = 120 })
		local target = helper.findDirectionalWindowTarget(win2, { win1, win3, win4 }, "left", nil)
		assert.are.equal(1, target:id())
	end)

	it("右図: 2->右 は 3", function()
		local win1 = stubWindow(1, { x = 100, y = 100, w = 140, h = 120 })
		local win2 = stubWindow(2, { x = 250, y = 100, w = 80, h = 120 })
		local win3 = stubWindow(3, { x = 340, y = 100, w = 140, h = 120 })
		local win4 = stubWindow(4, { x = 180, y = 230, w = 130, h = 120 })
		local target = helper.findDirectionalWindowTarget(win2, { win1, win3, win4 }, "right", nil)
		assert.are.equal(3, target:id())
	end)

	it("右図: 2->下 は 4", function()
		local win1 = stubWindow(1, { x = 100, y = 100, w = 140, h = 120 })
		local win2 = stubWindow(2, { x = 250, y = 100, w = 80, h = 120 })
		local win3 = stubWindow(3, { x = 340, y = 100, w = 140, h = 120 })
		local win4 = stubWindow(4, { x = 180, y = 230, w = 130, h = 120 })
		local target = helper.findDirectionalWindowTarget(win2, { win1, win3, win4 }, "down", nil)
		assert.are.equal(4, target:id())
	end)

	it("右図: 3->下 は 4", function()
		local win1 = stubWindow(1, { x = 100, y = 100, w = 140, h = 120 })
		local win2 = stubWindow(2, { x = 250, y = 100, w = 80, h = 120 })
		local win3 = stubWindow(3, { x = 340, y = 100, w = 140, h = 120 })
		local win4 = stubWindow(4, { x = 180, y = 230, w = 130, h = 120 })
		local target = helper.findDirectionalWindowTarget(win3, { win1, win2, win4 }, "down", nil)
		assert.are.equal(4, target:id())
	end)

	it("右図: 3->左 は 2", function()
		local win1 = stubWindow(1, { x = 100, y = 100, w = 140, h = 120 })
		local win2 = stubWindow(2, { x = 250, y = 100, w = 80, h = 120 })
		local win3 = stubWindow(3, { x = 340, y = 100, w = 140, h = 120 })
		local win4 = stubWindow(4, { x = 180, y = 230, w = 130, h = 120 })
		local target = helper.findDirectionalWindowTarget(win3, { win1, win2, win4 }, "left", nil)
		assert.are.equal(2, target:id())
	end)

	it("右図: 4->上 は前面順で変わる", function()
		local win1 = stubWindow(1, { x = 100, y = 100, w = 140, h = 120 })
		local win2 = stubWindow(2, { x = 250, y = 100, w = 80, h = 120 })
		local win3 = stubWindow(3, { x = 340, y = 100, w = 140, h = 120 })
		local win4 = stubWindow(4, { x = 180, y = 230, w = 130, h = 120 })

		local target1 = helper.findDirectionalWindowTarget(
			win4,
			{ win1, win2, win3 },
			"up",
			nil,
			{ win1, win2, win3, win4 }
		)
		assert.are.equal(1, target1:id())

		local target2 = helper.findDirectionalWindowTarget(
			win4,
			{ win1, win2, win3 },
			"up",
			nil,
			{ win2, win1, win3, win4 }
		)
		assert.are.equal(2, target2:id())
	end)

	it("斜め方向: upRight は右上象限の候補だけを対象にする", function()
		local current = stubWindow(1, { x = 100, y = 100, w = 100, h = 100 })
		local rightOnly = stubWindow(2, { x = 220, y = 160, w = 80, h = 80 })
		local upOnly = stubWindow(3, { x = 20, y = 0, w = 80, h = 80 })
		local target = helper.findDirectionalWindowTarget(current, { rightOnly, upOnly }, "upRight", nil)
		assert.are.equal(nil, target)
	end)

	it("斜め方向: 合成ギャップが小さい候補を優先する", function()
		local current = stubWindow(1, { x = 100, y = 100, w = 100, h = 100 })
		local nearDiag = stubWindow(2, { x = 220, y = 20, w = 80, h = 80 })
		local farDiag = stubWindow(3, { x = 210, y = -80, w = 80, h = 80 })
		local target = helper.findDirectionalWindowTarget(current, { nearDiag, farDiag }, "upRight", nil)
		assert.are.equal(2, target:id())
	end)

	it("斜め方向: 同率時は前面ウィンドウを優先する", function()
		local current = stubWindow(1, { x = 100, y = 100, w = 100, h = 100 })
		local win2 = stubWindow(2, { x = 220, y = 20, w = 80, h = 80 })
		local win3 = stubWindow(3, { x = 220, y = 20, w = 80, h = 80 })
		local target = helper.findDirectionalWindowTarget(
			current,
			{ win2, win3 },
			"upRight",
			nil,
			{ win3, win2, current }
		)
		assert.are.equal(3, target:id())
	end)

	it("斜め方向: 前面/距離まで同率なら previousWindow を優先する", function()
		local current = stubWindow(1, { x = 100, y = 100, w = 100, h = 100 })
		local win2 = stubWindow(2, { x = 220, y = 20, w = 80, h = 80 })
		local win3 = stubWindow(3, { x = 220, y = 20, w = 80, h = 80 })
		local target = helper.findDirectionalWindowTarget(current, { win2, win3 }, "upRight", win2)
		assert.are.equal(2, target:id())
	end)

	it("完全遮蔽ウィンドウは方向候補から除外される", function()
		local blocker = stubWindow(9, { x = 120, y = 100, w = 100, h = 100 })
		local occluded = stubWindow(2, { x = 120, y = 100, w = 100, h = 100 })
		local visible = stubWindow(3, { x = 250, y = 100, w = 100, h = 100 })
		local filtered = helper.filterDirectionalCandidatesByOcclusion(
			{ occluded, visible },
			{ blocker, occluded, visible },
			{ occlusionSamplingEnabled = false }
		)

		assert.are.equal(1, #filtered)
		assert.are.equal(3, filtered[1]:id())
	end)

	it("部分遮蔽ウィンドウは方向候補に残る", function()
		local blocker = stubWindow(9, { x = 120, y = 100, w = 50, h = 100 })
		local partial = stubWindow(2, { x = 120, y = 100, w = 100, h = 100 })
		local filtered = helper.filterDirectionalCandidatesByOcclusion(
			{ partial },
			{ blocker, partial },
			{ occlusionSamplingEnabled = false }
		)

		assert.are.equal(1, #filtered)
		assert.are.equal(2, filtered[1]:id())
	end)

	it("候補がすべて完全遮蔽なら空配列になる", function()
		local blockerA = stubWindow(9, { x = 120, y = 100, w = 100, h = 100 })
		local blockerB = stubWindow(8, { x = 260, y = 100, w = 100, h = 100 })
		local occludedA = stubWindow(2, { x = 120, y = 100, w = 100, h = 100 })
		local occludedB = stubWindow(3, { x = 260, y = 100, w = 100, h = 100 })
		local filtered = helper.filterDirectionalCandidatesByOcclusion(
			{ occludedA, occludedB },
			{ blockerA, occludedA, blockerB, occludedB },
			{ occlusionSamplingEnabled = false }
		)

		assert.are.equal(0, #filtered)
	end)
end)

describe("window_hints mouse selection", function()
	local originalHs
	local originalUtf8

	before_each(function()
		originalHs = _G.hs
		originalUtf8 = _G.utf8
	end)

	after_each(function()
		_G.hs = originalHs
		_G.utf8 = originalUtf8
	end)

	local function makeCanvasMock(createdCanvases)
		local canvasMethods = {}
		canvasMethods.__index = canvasMethods

		function canvasMethods:level(value)
			self._level = value
			return self
		end

		function canvasMethods:behavior()
			return self
		end

		function canvasMethods:appendElements(elements)
			table.insert(self, elements)
			return self
		end

		function canvasMethods:alpha(value)
			self._alpha = value
			return self
		end

		function canvasMethods:frame(value)
			if value then
				self._frame = value
				return self
			end
			return self._frame
		end

		function canvasMethods:show()
			self._shown = true
			return self
		end

		function canvasMethods:hide()
			self._shown = false
			return self
		end

		function canvasMethods:delete()
			self._deleted = true
			return self
		end

		function canvasMethods:mouseCallback(callback)
			self._mouseCallback = callback
			return self
		end

		return {
			windowLevels = {
				overlay = 1,
			},
			new = function(frame)
				local canvas = setmetatable({ _frame = frame }, canvasMethods)
				table.insert(createdCanvases, canvas)
				return canvas
			end,
		}
	end

	local function makeWindow(id, title, focusCounter)
		local app = {
			title = function()
				return "App" .. tostring(id)
			end,
			bundleID = function()
				return "com.example.app" .. tostring(id)
			end,
		}
		local screen = {
			id = function()
				return 1
			end,
			frame = function()
				return { x = 0, y = 0, w = 1200, h = 800 }
			end,
		}
		return {
			id = function()
				return id
			end,
			isStandard = function()
				return true
			end,
			application = function()
				return app
			end,
			screen = function()
				return screen
			end,
			title = function()
				return title
			end,
			frame = function()
				return { x = 100, y = 100, w = 400, h = 300 }
			end,
			focus = function()
				focusCounter.count = focusCounter.count + 1
			end,
		}
	end

	local function findCanvasByImagePath(createdCanvases, path)
		for _, canvas in ipairs(createdCanvases) do
			if canvas[1] and canvas[1].image and canvas[1].image.path == path then
				return canvas
			end
		end
		return nil
	end

	local function findCanvasByText(createdCanvases, elementIndex, text)
		for _, canvas in ipairs(createdCanvases) do
			local element = canvas[elementIndex]
			if element and element.text and element.text.string == text then
				return canvas
			end
		end
		return nil
	end

	local function comboCanvases(createdCanvases)
		local canvases = {}
		for _, canvas in ipairs(createdCanvases) do
			if canvas._level == 2 and not canvas._mouseCallback then
				table.insert(canvases, canvas)
			end
		end
		return canvases
	end

	local function hintCanvases(createdCanvases)
		local canvases = {}
		for _, canvas in ipairs(createdCanvases) do
			if canvas._mouseCallback then
				table.insert(canvases, canvas)
			end
		end
		return canvases
	end

	local function runNextDelayedTimer(delayedTimers)
		while #delayedTimers > 0 do
			local timer = table.remove(delayedTimers, 1)
			if not timer.stopped then
				timer.callback()
				return true
			end
		end
		return false
	end

	local function installHsMock(targetWindow, createdCanvases, options)
		options = options or {}
		_G.utf8 = {
			len = function(text)
				return string.len(text)
			end,
		}
		local hotkeys = {}
		local keyBlocker = {
			started = false,
			start = function(self)
				self.started = true
			end,
			stop = function(self)
				self.started = false
			end,
		}
		local mouseClickWatcher = {
			started = false,
			start = function(self)
				self.started = true
			end,
			stop = function(self)
				self.started = false
			end,
		}
		local loadedImagePaths = {}
		local repeatingTimers = {}
		local delayedTimers = {}
		local windows = options.windows or { targetWindow }
		local absoluteTime = 0
		_G.hs = {
			spoons = {
				resourcePath = function(fileName)
					return "./Jinrai.spoon/" .. fileName
				end,
			},
			hotkey = {
				bind = function(modifiers, key, callback)
					local binding = {
						modifiers = modifiers,
						key = key,
						callback = callback,
						delete = function() end,
					}
					table.insert(hotkeys, binding)
					return binding
				end,
			},
			eventtap = {
				event = {
					types = {
						keyDown = 1,
						leftMouseDown = 2,
					},
				},
				new = function(types, callback)
					if types[1] == 2 then
						mouseClickWatcher.callback = callback
						return mouseClickWatcher
					end
					keyBlocker.callback = callback
					return keyBlocker
				end,
			},
			keycodes = {
				map = {
					[42] = "f20",
					[49] = "space",
					[53] = "escape",
				},
			},
			window = {
				focusedWindow = function()
					return targetWindow
				end,
				orderedWindows = function()
					return windows
				end,
				visibleWindows = function()
					return windows
				end,
			},
			canvas = makeCanvasMock(createdCanvases),
			image = {
				imageFromAppBundle = function()
					return {}
				end,
				imageFromPath = function(path)
					table.insert(loadedImagePaths, path)
					return { path = path }
				end,
			},
			styledtext = {
				new = function(text, attributes)
					return {
						string = text,
						attributes = attributes,
					}
				end,
			},
			mouse = {
				absolutePosition = function() end,
			},
			timer = {
				doAfter = function(_, callback)
					if options.deferDoAfter then
						local timer = {
							callback = callback,
							stop = function(self)
								self.stopped = true
							end,
						}
						table.insert(delayedTimers, timer)
						return timer
					end
					callback()
					return {
						stop = function() end,
					}
				end,
				absoluteTime = options.elapsedPerClockCall and function()
					absoluteTime = absoluteTime + options.elapsedPerClockCall
					return absoluteTime
				end or nil,
				doEvery = function(_, callback)
					local timer = {
						callback = callback,
						stop = function(self)
							self.stopped = true
						end,
					}
					table.insert(repeatingTimers, timer)
					return timer
				end,
			},
		}
		return {
			hotkeys = hotkeys,
			keyBlocker = keyBlocker,
			mouseClickWatcher = mouseClickWatcher,
			loadedImagePaths = loadedImagePaths,
			repeatingTimers = repeatingTimers,
			delayedTimers = delayedTimers,
		}
	end

	local function countCanvasImages(canvas)
		local count = 0
		for _, element in pairs(canvas) do
			if type(element) == "table" and element.image ~= nil then
				count = count + 1
			end
		end
		return count
	end

	it("ヒントの mouseUp で該当ウィンドウを選択する", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local targetWindow = makeWindow(1, "Target", focusCounter)
		local mocks = installHsMock(targetWindow, createdCanvases)
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")

		local instance = windowHints.new({
			hint = {
				title = {
					show = false,
				},
			},
			behavior = {
				callbacks = {
					onError = function(err)
						error(err)
					end,
				},
				cursor = {
					onStart = false,
					onSelect = false,
				},
			},
		})
		assert.is_true(instance.show())

		local hintCanvas
		for _, canvas in ipairs(createdCanvases) do
			if canvas._mouseCallback then
				hintCanvas = canvas
				break
			end
		end
		assert.is_truthy(hintCanvas)
		assert.are.equal(3, hintCanvas._level)
		assert.is_true(hintCanvas[1].trackMouseUp)
		assert.is_true(countCanvasImages(hintCanvas) > 0)

		hintCanvas._mouseCallback(hintCanvas, "mouseUp")

		assert.are.equal(1, focusCounter.count)
		assert.are.equal(0, countCanvasImages(hintCanvas))
		assert.is_true(hintCanvas._deleted)
		for _, canvas in ipairs(createdCanvases) do
			assert.is_true(canvas._deleted)
		end
	end)

	it("ヒントの mouseDown では該当ウィンドウを選択しない", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local targetWindow = makeWindow(1, "Target", focusCounter)
		local mocks = installHsMock(targetWindow, createdCanvases)
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")

		local instance = windowHints.new({
			hint = {
				title = {
					show = false,
				},
			},
			behavior = {
				callbacks = {
					onError = function(err)
						error(err)
					end,
				},
				cursor = {
					onStart = false,
					onSelect = false,
				},
			},
		})
		assert.is_true(instance.show())

		local hintCanvas
		for _, canvas in ipairs(createdCanvases) do
			if canvas._mouseCallback then
				hintCanvas = canvas
				break
			end
		end
		assert.is_truthy(hintCanvas)

		hintCanvas._mouseCallback(hintCanvas, "mouseDown")

		assert.are.equal(0, focusCounter.count)
		assert.is_nil(hintCanvas._deleted)
	end)

	it("JinraiModeキー押下後の選択は内部コールバックへ通知する", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local targetWindow = makeWindow(1, "Target", focusCounter)
		local mocks = installHsMock(targetWindow, createdCanvases)
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")
		local normalSelectCount = 0
		local jinraiModeSelectCount = 0

		local instance = windowHints.new({
			hint = {
				title = {
					show = false,
				},
			},
			behavior = {
				callbacks = {
					onSelect = function()
						normalSelectCount = normalSelectCount + 1
					end,
					onError = function(err)
						error(err)
					end,
				},
				cursor = {
					onStart = false,
					onSelect = false,
				},
			},
			internal = {
				jinraiMode = {
					windowHints = {
						key = "space",
					},
					logo = {
						enabled = true,
						size = 480,
						alpha = 0.3,
					},
				},
				onJinraiModeSelect = function(win)
					assert.are.equal(targetWindow, win)
					jinraiModeSelectCount = jinraiModeSelectCount + 1
				end,
			},
		})
		assert.is_true(instance.show())

		assert.is_true(mocks.keyBlocker.callback({
			getKeyCode = function()
				return 49
			end,
			getFlags = function()
				return {}
			end,
		}))

		local hintCanvas
		for _, canvas in ipairs(createdCanvases) do
			if canvas._mouseCallback then
				hintCanvas = canvas
				break
			end
		end
		hintCanvas._mouseCallback(hintCanvas, "mouseUp")

		assert.are.equal(1, focusCounter.count)
		assert.are.equal(0, normalSelectCount)
		assert.are.equal(1, jinraiModeSelectCount)
		assert.is_false(mocks.keyBlocker.started)
	end)

	it("ヒント表示中にmoveToSelectedAreaキーを押すと内部コールバックへ通知する", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local targetWindow = makeWindow(1, "Target", focusCounter)
		local mocks = installHsMock(targetWindow, createdCanvases)
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")
		local openWindowActionChooserCount = 0
		local openWindowActionChooserContext

		local instance = windowHints.new({
			hint = {
				title = {
					show = false,
				},
			},
			navigation = {
				windowMover = {
					moveToSelectedArea = {
						key = "space",
					},
				},
			},
			behavior = {
				callbacks = {
					onError = function(err)
						error(err)
					end,
				},
				cursor = {
					onStart = false,
					onSelect = false,
				},
			},
			internal = {
				onOpenWindowActionChooser = function(ctx)
					openWindowActionChooserCount = openWindowActionChooserCount + 1
					openWindowActionChooserContext = ctx
				end,
			},
		})
		assert.is_true(instance.show())

		local hintCanvas
		for _, canvas in ipairs(createdCanvases) do
			if canvas._mouseCallback then
				hintCanvas = canvas
				break
			end
		end
		assert.is_truthy(hintCanvas)

		assert.is_true(mocks.keyBlocker.callback({
			getKeyCode = function()
				return 49
			end,
			getFlags = function()
				return {}
			end,
		}))

		assert.are.equal(0, focusCounter.count)
		assert.are.equal(1, openWindowActionChooserCount)
		assert.is_false(openWindowActionChooserContext.jinraiMode)
		assert.is_true(hintCanvas._deleted)
		assert.is_false(mocks.keyBlocker.started)
	end)

	it("JinraiMode中にmoveToSelectedAreaキーを押すとJinraiMode継続を通知する", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local targetWindow = makeWindow(1, "Target", focusCounter)
		local mocks = installHsMock(targetWindow, createdCanvases)
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")
		local openWindowActionChooserContext

		local instance = windowHints.new({
			hint = {
				title = {
					show = false,
				},
			},
			navigation = {
				windowMover = {
					moveToSelectedArea = {
						key = "space",
					},
				},
			},
			behavior = {
				callbacks = {
					onError = function(err)
						error(err)
					end,
				},
				cursor = {
					onStart = false,
					onSelect = false,
				},
			},
			internal = {
				jinraiMode = {
					windowHints = {
						key = "f20",
					},
				},
				onOpenWindowActionChooser = function(ctx)
					openWindowActionChooserContext = ctx
				end,
			},
		})
		assert.is_true(instance.show())

		assert.is_true(mocks.keyBlocker.callback({
			getKeyCode = function()
				return 42
			end,
			getFlags = function()
				return {}
			end,
		}))
		assert.is_true(mocks.keyBlocker.callback({
			getKeyCode = function()
				return 49
			end,
			getFlags = function()
				return {}
			end,
		}))

		assert.is_true(openWindowActionChooserContext.jinraiMode)
		assert.is_false(mocks.keyBlocker.started)
	end)

	it("JinraiMode中にApplication Hintsを開いてもロゴ表示を維持する", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local targetWindow = makeWindow(1, "Target", focusCounter)
		local mocks = installHsMock(targetWindow, createdCanvases)
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")
		local openApplicationHintsContext

		local instance = windowHints.new({
			hint = {
				title = {
					show = false,
				},
			},
			navigation = {
				applicationHints = {
					key = "f20",
				},
			},
			behavior = {
				callbacks = {
					onError = function(err)
						error(err)
					end,
				},
				cursor = {
					onStart = false,
					onSelect = false,
				},
			},
			internal = {
				jinraiMode = {
					windowHints = {
						key = "space",
					},
					logo = {
						enabled = true,
						size = 480,
						alpha = 0.3,
					},
				},
				onOpenApplicationHints = function(ctx)
					openApplicationHintsContext = ctx
				end,
			},
		})
		assert.is_true(instance.show())

		assert.is_true(mocks.keyBlocker.callback({
			getKeyCode = function()
				return 49
			end,
			getFlags = function()
				return {}
			end,
		}))
		local logoCanvas = findCanvasByImagePath(createdCanvases, "./Jinrai.spoon/jinrai.svg")
		assert.is_truthy(logoCanvas)

		assert.is_true(mocks.keyBlocker.callback({
			getKeyCode = function()
				return 42
			end,
			getFlags = function()
				return {}
			end,
		}))

		assert.is_true(openApplicationHintsContext.jinraiMode)
		assert.is_nil(logoCanvas._deleted)
		assert.is_false(mocks.keyBlocker.started)
	end)

	it("showJinraiMode は追加キーなしで内部コールバックへ通知する", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local targetWindow = makeWindow(1, "Target", focusCounter)
		installHsMock(targetWindow, createdCanvases)
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")
		local jinraiModeSelectCount = 0

		local instance = windowHints.new({
			hint = {
				title = {
					show = false,
				},
			},
			behavior = {
				callbacks = {
					onError = function(err)
						error(err)
					end,
				},
				cursor = {
					onStart = false,
					onSelect = false,
				},
			},
			internal = {
				onJinraiModeSelect = function()
					jinraiModeSelectCount = jinraiModeSelectCount + 1
				end,
			},
		})
		assert.is_true(instance.showJinraiMode())

		local hintCanvas
		for _, canvas in ipairs(createdCanvases) do
			if canvas._mouseCallback then
				hintCanvas = canvas
				break
			end
		end
		hintCanvas._mouseCallback(hintCanvas, "mouseUp")

		assert.are.equal(1, jinraiModeSelectCount)
	end)

	it("showJinraiModeAsync は Canvas を分割準備して完成後に一斉表示する", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local windows = {
			makeWindow(1, "First", focusCounter),
			makeWindow(2, "Second", focusCounter),
			makeWindow(3, "Third", focusCounter),
		}
		local mocks = installHsMock(windows[1], createdCanvases, {
			windows = windows,
			deferDoAfter = true,
			elapsedPerClockCall = 9000000,
		})
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")
		local instance = windowHints.new({
			hint = {
				title = {
					show = false,
				},
			},
			behavior = {
				callbacks = {
					onError = function(err)
						error(err)
					end,
				},
				cursor = {
					onStart = false,
					onSelect = false,
				},
			},
		})

		assert.is_true(instance.showJinraiModeAsync())
		assert.are.equal(0, #hintCanvases(createdCanvases))
		assert.is_true(mocks.keyBlocker.started)

		assert.is_true(runNextDelayedTimer(mocks.delayedTimers))
		local prepared = hintCanvases(createdCanvases)
		assert.are.equal(1, #prepared)
		assert.is_nil(prepared[1]._shown)

		assert.is_true(runNextDelayedTimer(mocks.delayedTimers))
		prepared = hintCanvases(createdCanvases)
		assert.are.equal(2, #prepared)
		assert.is_nil(prepared[1]._shown)
		assert.is_nil(prepared[2]._shown)

		assert.is_true(runNextDelayedTimer(mocks.delayedTimers))
		prepared = hintCanvases(createdCanvases)
		assert.are.equal(3, #prepared)
		for _, canvas in ipairs(prepared) do
			assert.is_true(canvas._shown)
		end
	end)

	it("showJinraiModeAsync は準備中の Escape で予約処理と Canvas を破棄する", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local windows = {
			makeWindow(1, "First", focusCounter),
			makeWindow(2, "Second", focusCounter),
		}
		local mocks = installHsMock(windows[1], createdCanvases, {
			windows = windows,
			deferDoAfter = true,
			elapsedPerClockCall = 9000000,
		})
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")
		local instance = windowHints.new({
			hint = {
				title = {
					show = false,
				},
			},
			behavior = {
				cursor = {
					onStart = false,
					onSelect = false,
				},
			},
		})

		assert.is_true(instance.showJinraiModeAsync())
		assert.is_true(runNextDelayedTimer(mocks.delayedTimers))
		local prepared = hintCanvases(createdCanvases)
		assert.are.equal(1, #prepared)
		assert.is_nil(prepared[1]._shown)

		assert.is_true(mocks.keyBlocker.callback({
			getKeyCode = function()
				return 53
			end,
			getFlags = function()
				return {}
			end,
		}))
		assert.is_true(prepared[1]._deleted)
		assert.is_false(mocks.keyBlocker.started)
		assert.is_false(runNextDelayedTimer(mocks.delayedTimers))
		assert.are.equal(1, #hintCanvases(createdCanvases))
	end)

	it("JinraiMode 中はロゴをアクティブ画面中央に表示し選択後も維持する", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local targetWindow = makeWindow(1, "Target", focusCounter)
		local mocks = installHsMock(targetWindow, createdCanvases)
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")

		local instance = windowHints.new({
			hint = {
				title = {
					show = false,
				},
			},
			behavior = {
				callbacks = {
					onError = function(err)
						error(err)
					end,
				},
				cursor = {
					onStart = false,
					onSelect = false,
				},
			},
			internal = {
				jinraiMode = {
					position = "activeDisplay",
					windowHints = {
						key = "space",
					},
					logo = {
						enabled = true,
						size = 480,
						alpha = 0.3,
					},
				},
				onJinraiModeSelect = function() end,
			},
		})
		assert.is_true(instance.show())

		mocks.keyBlocker.callback({
			getKeyCode = function()
				return 49
			end,
			getFlags = function()
				return {}
			end,
		})

		local logoCanvas
		for _, canvas in ipairs(createdCanvases) do
			if canvas[1] and canvas[1].image and canvas[1].image.path == "./Jinrai.spoon/jinrai.svg" then
				logoCanvas = canvas
				break
			end
		end
		assert.is_truthy(logoCanvas)
		assert.are.same({ x = 360, y = 160, w = 480, h = 480 }, logoCanvas._frame)
		assert.are.equal(0, logoCanvas._alpha)
		assert.are.equal(0.3, logoCanvas[1].imageAlpha)

		local hintCanvas
		for _, canvas in ipairs(createdCanvases) do
			if canvas._mouseCallback then
				hintCanvas = canvas
				break
			end
		end
		hintCanvas._mouseCallback(hintCanvas, "mouseUp")

		local activeLogoCanvas
		for _, canvas in ipairs(createdCanvases) do
			if
				not canvas._deleted
				and canvas[1]
				and canvas[1].image
				and canvas[1].image.path == "./Jinrai.spoon/jinrai.svg"
			then
				activeLogoCanvas = canvas
				break
			end
		end
		assert.is_truthy(activeLogoCanvas)
		instance.stopJinraiMode()
		assert.is_true(activeLogoCanvas._deleted)
	end)

	it("JinraiMode 再表示時はロゴを再作成せずアクティブ画面中央へ移動する", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local targetWindow = makeWindow(1, "Target", focusCounter)
		local activeScreenFrame = { x = 0, y = 0, w = 1200, h = 800 }
		targetWindow.screen = function()
			return {
				id = function()
					return 1
				end,
				frame = function()
					return activeScreenFrame
				end,
			}
		end
		installHsMock(targetWindow, createdCanvases)
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")

		local instance = windowHints.new({
			hint = {
				title = {
					show = false,
				},
			},
			behavior = {
				callbacks = {
					onError = function(err)
						error(err)
					end,
				},
				cursor = {
					onStart = false,
					onSelect = false,
				},
			},
			internal = {
				jinraiMode = {
					position = "activeDisplay",
					logo = {
						enabled = true,
						size = 480,
						alpha = 0.3,
					},
				},
			},
		})

		assert.is_true(instance.showJinraiMode())
		local logoCanvas = findCanvasByImagePath(createdCanvases, "./Jinrai.spoon/jinrai.svg")
		assert.is_truthy(logoCanvas)
		assert.are.same({ x = 360, y = 160, w = 480, h = 480 }, logoCanvas._frame)

		activeScreenFrame = { x = 1200, y = 100, w = 1600, h = 1000 }
		assert.is_true(instance.showJinraiMode())

		local logoCanvasCount = 0
		for _, canvas in ipairs(createdCanvases) do
			if canvas[1] and canvas[1].image and canvas[1].image.path == "./Jinrai.spoon/jinrai.svg" then
				logoCanvasCount = logoCanvasCount + 1
			end
		end
		assert.are.equal(1, logoCanvasCount)
		assert.is_nil(logoCanvas._deleted)
		assert.are.same({ x = 1760, y = 360, w = 480, h = 480 }, logoCanvas._frame)
		assert.are.equal(0.3, logoCanvas[1].imageAlpha)
	end)

	it("JinraiMode の表示をアクティブウィンドウ中央に配置する", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local targetWindow = makeWindow(1, "Target", focusCounter)
		installHsMock(targetWindow, createdCanvases)
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")

		local instance = windowHints.new({
			hint = { title = { show = false } },
			behavior = {
				callbacks = {
					onError = function(err)
						error(err)
					end,
				},
				cursor = { onStart = false, onSelect = false },
			},
			internal = {
				jinraiMode = {
					position = "activeWindow",
					logo = {
						enabled = true,
						size = 480,
						alpha = 0.3,
					},
					combo = {
						character = {
							enabled = true,
							alpha = 0.25,
						},
						text = {
							enabled = true,
							alpha = 0.75,
						},
					},
				},
			},
		})

		assert.is_true(instance.showJinraiMode())
		local logoCanvas = findCanvasByImagePath(createdCanvases, "./Jinrai.spoon/jinrai.svg")
		assert.are.same({ x = 60, y = 10, w = 480, h = 480 }, logoCanvas._frame)

		assert.is_true(instance.advanceJinraiModeCombo())
		local comboCanvas = findCanvasByImagePath(createdCanvases, "./Jinrai.spoon/resources/jinrai1.webp")
		local characterFrame = comboCanvas[1].frame
		local characterCenterX = comboCanvas._frame.x + characterFrame.x + (characterFrame.w / 2)
		local characterCenterY = comboCanvas._frame.y + characterFrame.y + (characterFrame.h / 2)
		assert.are.equal(300, characterCenterX)
		assert.are.equal(250, characterCenterY)
		assert.are.equal(651.36, characterFrame.w)

		local textCanvas = findCanvasByText(createdCanvases, 1, "1")
		local textLeft = textCanvas._frame.x + textCanvas[1].frame.x
		local textRight = textCanvas._frame.x + textCanvas[2].frame.x + textCanvas[2].frame.w
		assert.are.equal(300, (textLeft + textRight) / 2)
	end)

	it("activeWindow 指定時は再表示で最新のウィンドウ中央へロゴを移動する", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local targetWindow = makeWindow(1, "Target", focusCounter)
		local activeWindowFrame = { x = 100, y = 100, w = 400, h = 300 }
		targetWindow.frame = function()
			return activeWindowFrame
		end
		installHsMock(targetWindow, createdCanvases)
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")
		local instance = windowHints.new({
			internal = {
				jinraiMode = {
					position = "activeWindow",
				},
			},
		})

		assert.is_true(instance.showJinraiMode())
		local logoCanvas = findCanvasByImagePath(createdCanvases, "./Jinrai.spoon/jinrai.svg")
		assert.are.same({ x = 60, y = 10, w = 480, h = 480 }, logoCanvas._frame)

		activeWindowFrame = { x = 800, y = 300, w = 1000, h = 700 }
		assert.is_true(instance.showJinraiMode())
		assert.are.same({ x = 1060, y = 410, w = 480, h = 480 }, logoCanvas._frame)
	end)

	it("activeWindow 指定時はコンボ加算で最新のウィンドウ中央へロゴを移動する", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local targetWindow = makeWindow(1, "Target", focusCounter)
		local activeWindowFrame = { x = 100, y = 100, w = 400, h = 300 }
		targetWindow.frame = function()
			return activeWindowFrame
		end
		installHsMock(targetWindow, createdCanvases)
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")
		local instance = windowHints.new({
			internal = {
				jinraiMode = {
					position = "activeWindow",
				},
			},
		})

		assert.is_true(instance.showJinraiMode())
		local logoCanvas = findCanvasByImagePath(createdCanvases, "./Jinrai.spoon/jinrai.svg")
		assert.are.same({ x = 60, y = 10, w = 480, h = 480 }, logoCanvas._frame)

		activeWindowFrame = { x = 800, y = 300, w = 1000, h = 700 }
		assert.is_true(instance.advanceJinraiModeCombo())
		assert.are.same({ x = 1060, y = 410, w = 480, h = 480 }, logoCanvas._frame)
	end)

	it("activeWindow 指定時にウィンドウフレームを取得できなければ画面中央へ配置する", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local targetWindow = makeWindow(1, "Target", focusCounter)
		targetWindow.frame = nil
		installHsMock(targetWindow, createdCanvases)
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")
		local instance = windowHints.new({
			internal = {
				jinraiMode = {
					position = "activeWindow",
				},
			},
		})

		instance.startJinraiMode()
		local logoCanvas = findCanvasByImagePath(createdCanvases, "./Jinrai.spoon/jinrai.svg")
		assert.are.same({ x = 360, y = 160, w = 480, h = 480 }, logoCanvas._frame)
	end)

	it("JinraiMode ロゴは指定したイージングでフェードと倍率を補間する", function()
		local cases = {
			{ easing = "linear", progress = 0.5 },
			{ easing = "easeOut", progress = 0.875 },
			{ easing = "easeInOut", progress = 0.5 },
		}
		for _, case in ipairs(cases) do
			local createdCanvases = {}
			local focusCounter = { count = 0 }
			local targetWindow = makeWindow(1, "Target", focusCounter)
			local mocks = installHsMock(targetWindow, createdCanvases)
			local windowHints = dofile("./Jinrai.spoon/window_hints.lua")
			local instance = windowHints.new({
				internal = {
					jinraiMode = {
						logo = {
							animation = {
								fade = true,
								scale = 0.5,
								duration = 0.04,
								easing = case.easing,
							},
						},
					},
				},
			})

			instance.startJinraiMode()
			local logoCanvas = findCanvasByImagePath(createdCanvases, "./Jinrai.spoon/jinrai.svg")
			assert.are.equal(240, logoCanvas._frame.w)
			assert.are.equal(0, logoCanvas._alpha)
			local timer = mocks.repeatingTimers[#mocks.repeatingTimers]
			timer.callback()
			assert.are.equal(240 + (240 * case.progress), logoCanvas._frame.w)
			assert.are.equal(case.progress, logoCanvas._alpha)
			timer.callback()
			assert.are.equal(480, logoCanvas._frame.w)
			assert.are.equal(1, logoCanvas._alpha)
			assert.is_true(timer.stopped)
			instance.teardown()
		end
	end)

	it("JinraiMode キャラクターと文字は個別の時間でアニメーションする", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local targetWindow = makeWindow(1, "Target", focusCounter)
		local mocks = installHsMock(targetWindow, createdCanvases)
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")
		local instance = windowHints.new({
			internal = {
				jinraiMode = {
					logo = { enabled = false },
					combo = {
						character = {
							enabled = true,
							animation = { duration = 0.04 },
						},
						text = {
							enabled = true,
							animation = { duration = 0.08 },
						},
					},
				},
			},
		})

		instance.startJinraiMode()
		assert.is_true(instance.advanceJinraiModeCombo())
		local characterTimer = mocks.repeatingTimers[#mocks.repeatingTimers - 1]
		local textTimer = mocks.repeatingTimers[#mocks.repeatingTimers]
		characterTimer.callback()
		characterTimer.callback()
		assert.is_true(characterTimer.stopped)
		assert.is_nil(textTimer.stopped)
		for _ = 1, 4 do
			textTimer.callback()
		end
		assert.is_true(textTimer.stopped)
		instance.teardown()
	end)

	it("JinraiMode の fade=false と duration=0 は即時に最終表示する", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local targetWindow = makeWindow(1, "Target", focusCounter)
		local mocks = installHsMock(targetWindow, createdCanvases)
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")
		local instance = windowHints.new({
			internal = {
				jinraiMode = {
					logo = {
						animation = { fade = false, scale = 0.5, duration = 0 },
					},
					combo = {
						character = {
							enabled = true,
							animation = { fade = false, scale = 1.3, duration = 0 },
						},
						text = {
							enabled = true,
							animation = { fade = false, scale = 0.8, duration = 0 },
						},
					},
				},
			},
		})

		instance.startJinraiMode()
		assert.is_true(instance.advanceJinraiModeCombo())
		assert.are.equal(0, #mocks.repeatingTimers)
		local logoCanvas = findCanvasByImagePath(createdCanvases, "./Jinrai.spoon/jinrai.svg")
		local characterCanvas = findCanvasByImagePath(createdCanvases, "./Jinrai.spoon/resources/jinrai1.webp")
		local textCanvas = findCanvasByText(createdCanvases, 1, "1")
		assert.are.equal(480, logoCanvas._frame.w)
		assert.are.equal(1, logoCanvas._alpha)
		assert.are.equal(552, characterCanvas[1].frame.w)
		assert.are.equal(1, characterCanvas._alpha)
		assert.are.equal(99, textCanvas[1].textSize)
		assert.are.equal(1, textCanvas._alpha)
		instance.teardown()
	end)

	it("JinraiMode 中の遷移だけコンボを加算し画像を循環表示する", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local targetWindow = makeWindow(1, "Target", focusCounter)
		local mocks = installHsMock(targetWindow, createdCanvases)
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")

		local instance = windowHints.new({
			hint = {
				title = {
					show = false,
				},
			},
			behavior = {
				callbacks = {
					onError = function(err)
						error(err)
					end,
				},
				cursor = {
					onStart = false,
					onSelect = false,
				},
			},
			internal = {
				jinraiMode = {
					position = "activeDisplay",
					combo = {
						character = {
							enabled = true,
							alpha = 0.25,
						},
						text = {
							enabled = true,
							alpha = 0.75,
						},
					},
				},
			},
		})

		assert.are.equal(10, #mocks.loadedImagePaths)
		assert.are.equal(4, #comboCanvases(createdCanvases))
		assert.is_false(instance.advanceJinraiModeCombo())
		assert.is_true(instance.showJinraiMode())
		local initialComboCanvas = findCanvasByImagePath(createdCanvases, "./Jinrai.spoon/resources/jinrai0.webp")
		assert.is_truthy(initialComboCanvas)
		assert.is_nil(initialComboCanvas[2])
		local comboImagePaths = {}
		for combo = 1, 10 do
			assert.is_true(instance.advanceJinraiModeCombo())
			local imageIndex = ((combo - 1) % 9) + 1
			local comboCanvas =
				findCanvasByImagePath(createdCanvases, "./Jinrai.spoon/resources/jinrai" .. imageIndex .. ".webp")
			comboImagePaths[combo] = comboCanvas[1].image.path
		end

		assert.are.same({
			"./Jinrai.spoon/resources/jinrai1.webp",
			"./Jinrai.spoon/resources/jinrai2.webp",
			"./Jinrai.spoon/resources/jinrai3.webp",
			"./Jinrai.spoon/resources/jinrai4.webp",
			"./Jinrai.spoon/resources/jinrai5.webp",
			"./Jinrai.spoon/resources/jinrai6.webp",
			"./Jinrai.spoon/resources/jinrai7.webp",
			"./Jinrai.spoon/resources/jinrai8.webp",
			"./Jinrai.spoon/resources/jinrai9.webp",
			"./Jinrai.spoon/resources/jinrai1.webp",
		}, comboImagePaths)
		local activeCharacterCanvas = findCanvasByImagePath(createdCanvases, "./Jinrai.spoon/resources/jinrai1.webp")
		local activeComboCanvas = findCanvasByText(createdCanvases, 1, "10")
		assert.are.equal(0.25, activeCharacterCanvas[1].imageAlpha)
		assert.are.equal("10", activeComboCanvas[1].text.string)
		assert.are.same(
			{ name = "Avenir Next Heavy", size = activeComboCanvas[1].textSize },
			activeComboCanvas[1].text.attributes.font
		)
		assert.are.same({ red = 1, green = 0.46, blue = 0.08, alpha = 0.75 }, activeComboCanvas[1].text.attributes.color)
		assert.are.same(
			{ red = 0, green = 0, blue = 0, alpha = 0.75 },
			activeComboCanvas[1].text.attributes.strokeColor
		)
		assert.are.equal(-5, activeComboCanvas[1].text.attributes.strokeWidth)
		assert.are.equal("center", activeComboCanvas[1].text.attributes.paragraphStyle.alignment)
		assert.are.equal("COMBO!", activeComboCanvas[2].text.string)
		assert.are.same(
			{ name = "Avenir Next Heavy", size = activeComboCanvas[2].textSize },
			activeComboCanvas[2].text.attributes.font
		)
		assert.are.same({ red = 1, green = 0.46, blue = 0.08, alpha = 0.75 }, activeComboCanvas[2].text.attributes.color)
		assert.are.equal(-4, activeComboCanvas[2].text.attributes.strokeWidth)
		assert.are.same(activeComboCanvas[2].text.attributes.color, activeComboCanvas[1].text.attributes.color)
		assert.is_true(activeComboCanvas[1].textSize > activeComboCanvas[2].textSize)
		assert.are.equal(2, activeComboCanvas._level)
		local comboNumberTextBottom = activeComboCanvas._frame.y + activeComboCanvas[1].frame.y + activeComboCanvas[1].frame.h
		local comboLabelTextBottom = activeComboCanvas._frame.y + activeComboCanvas[2].frame.y + activeComboCanvas[2].frame.h
		assert.are.equal(comboNumberTextBottom, comboLabelTextBottom)
		assert.are.equal(196, comboLabelTextBottom)
		assert.is_true(activeComboCanvas[1].frame.h >= activeComboCanvas[1].textSize * 1.1)
		assert.is_true(activeComboCanvas[1].frame.x < activeComboCanvas[2].frame.x)
		assert.are.equal("clip", activeComboCanvas[1].textLineBreak)
		local comboTextTop = activeComboCanvas._frame.y + activeComboCanvas[1].frame.y
		assert.are.equal(82, comboTextTop)
		local comboAnimationTimer = mocks.repeatingTimers[#mocks.repeatingTimers]
		for _ = 1, 8 do
			comboAnimationTimer.callback()
		end
		local animatedComboNumberTextBottom = activeComboCanvas._frame.y
			+ activeComboCanvas[1].frame.y
			+ activeComboCanvas[1].frame.h
		local animatedComboLabelTextBottom = activeComboCanvas._frame.y
			+ activeComboCanvas[2].frame.y
			+ activeComboCanvas[2].frame.h
		assert.are.equal(animatedComboNumberTextBottom, animatedComboLabelTextBottom)
		assert.are.equal(196, animatedComboLabelTextBottom)

		instance.stopJinraiMode()
		assert.is_false(activeComboCanvas._shown)
		assert.is_nil(activeComboCanvas._deleted)
		assert.is_false(instance.advanceJinraiModeCombo())

		instance.startJinraiMode()
		assert.is_true(instance.advanceJinraiModeCombo())
		local restartedComboCanvas = findCanvasByText(createdCanvases, 1, "1")
		assert.are.equal("1", restartedComboCanvas[1].text.string)
		assert.are.equal("COMBO!", restartedComboCanvas[2].text.string)
		assert.is_true(instance.advanceJinraiModeCombo())
		local twoComboCanvas = findCanvasByText(createdCanvases, 1, "2")
		assert.are.equal("2", twoComboCanvas[1].text.string)
		assert.are.equal("COMBO!", twoComboCanvas[2].text.string)
		assert.is_true(twoComboCanvas[1].frame.h >= twoComboCanvas[1].textSize * 1.1)
		assert.are.equal(4, #comboCanvases(createdCanvases))

		instance.teardown()
		for _, canvas in ipairs(comboCanvases(createdCanvases)) do
			assert.is_true(canvas._deleted)
			assert.is_nil(canvas[1].image)
		end
	end)

	it("JinraiMode コンボ文字は小さい画面でも上端から 16px 内側に配置する", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local targetWindow = makeWindow(1, "Target", focusCounter)
		local smallScreen = {
			id = function()
				return 1
			end,
			frame = function()
				return { x = 0, y = 0, w = 800, h = 600 }
			end,
		}
		targetWindow.screen = function()
			return smallScreen
		end
		installHsMock(targetWindow, createdCanvases)
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")
		local instance = windowHints.new({
			hint = {
				title = {
					show = false,
				},
			},
			behavior = {
				callbacks = {
					onError = function(err)
						error(err)
					end,
				},
				cursor = {
					onStart = false,
					onSelect = false,
				},
			},
			internal = {
				jinraiMode = {
					logo = {
						size = 580,
					},
					combo = {
						text = {
							enabled = true,
						},
					},
				},
			},
		})

		assert.is_true(instance.showJinraiMode())
		assert.is_true(instance.advanceJinraiModeCombo())
		local comboCanvas = findCanvasByText(createdCanvases, 1, "1")
		local comboTextTop = comboCanvas._frame.y + comboCanvas[1].frame.y
		assert.are.equal(16, comboTextTop)
	end)

	it("JinraiMode コンボ文字と画像が無効でもコンボ遷移は継続する", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local targetWindow = makeWindow(1, "Target", focusCounter)
		local mocks = installHsMock(targetWindow, createdCanvases)
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")

		local instance = windowHints.new({
			hint = {
				title = {
					show = false,
				},
			},
			behavior = {
				callbacks = {
					onError = function(err)
						error(err)
					end,
				},
				cursor = {
					onStart = false,
					onSelect = false,
				},
			},
		})

		assert.are.equal(0, #mocks.loadedImagePaths)
		assert.are.equal(0, #comboCanvases(createdCanvases))
		assert.is_true(instance.showJinraiMode())
		local canvasCount = #createdCanvases
		local imageLoadCount = #mocks.loadedImagePaths
		assert.is_true(instance.advanceJinraiModeCombo())
		assert.are.equal(canvasCount, #createdCanvases)
		assert.are.equal(imageLoadCount, #mocks.loadedImagePaths)
	end)

	it("JinraiMode コンボ文字だけを表示できる", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local targetWindow = makeWindow(1, "Target", focusCounter)
		local mocks = installHsMock(targetWindow, createdCanvases)
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")
		local instance = windowHints.new({
			hint = { title = { show = false } },
			behavior = {
				callbacks = {
					onError = function(err)
						error(err)
					end,
				},
				cursor = { onStart = false, onSelect = false },
			},
			internal = {
				jinraiMode = {
					combo = {
						text = {
							enabled = true,
							alpha = 0.65,
						},
					},
				},
			},
		})

		assert.is_true(instance.showJinraiMode())
		local imageLoadCount = #mocks.loadedImagePaths
		assert.is_true(instance.advanceJinraiModeCombo())
		local comboCanvas = findCanvasByText(createdCanvases, 1, "1")
		assert.are.equal("text", comboCanvas[1].type)
		assert.are.equal("1", comboCanvas[1].text.string)
		assert.are.equal("COMBO!", comboCanvas[2].text.string)
		assert.are.equal(0.65, comboCanvas[1].text.attributes.color.alpha)
		assert.are.equal(0.65, comboCanvas[2].text.attributes.color.alpha)
		assert.are.equal(imageLoadCount, #mocks.loadedImagePaths)
	end)

	it("JinraiMode キャラクター画像だけを表示できる", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local targetWindow = makeWindow(1, "Target", focusCounter)
		installHsMock(targetWindow, createdCanvases)
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")
		local instance = windowHints.new({
			hint = { title = { show = false } },
			behavior = {
				callbacks = {
					onError = function(err)
						error(err)
					end,
				},
				cursor = { onStart = false, onSelect = false },
			},
			internal = {
				jinraiMode = {
					combo = {
						character = {
							enabled = true,
							alpha = 0.35,
						},
					},
				},
			},
		})

		assert.is_true(instance.showJinraiMode())
		local comboCanvas = findCanvasByImagePath(createdCanvases, "./Jinrai.spoon/resources/jinrai0.webp")
		assert.is_truthy(comboCanvas)
		assert.are.equal("image", comboCanvas[1].type)
		assert.are.equal(0.35, comboCanvas[1].imageAlpha)
		assert.is_nil(comboCanvas[2])
		assert.is_true(instance.advanceJinraiModeCombo())
		local firstComboCanvas = findCanvasByImagePath(createdCanvases, "./Jinrai.spoon/resources/jinrai1.webp")
		assert.are.equal("./Jinrai.spoon/resources/jinrai1.webp", firstComboCanvas[1].image.path)
		assert.is_nil(firstComboCanvas[2])
	end)

	it("JinraiMode コンボ画像は画像番号ごとにキャッシュする", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local targetWindow = makeWindow(1, "Target", focusCounter)
		local mocks = installHsMock(targetWindow, createdCanvases)
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")
		local instance = windowHints.new({
			hint = {
				title = {
					show = false,
				},
			},
			behavior = {
				callbacks = {
					onError = function(err)
						error(err)
					end,
				},
				cursor = {
					onStart = false,
					onSelect = false,
				},
			},
			internal = {
				jinraiMode = {
					combo = {
						character = {
							enabled = true,
						},
					},
				},
			},
		})

		assert.is_true(instance.showJinraiMode())
		assert.is_true(instance.advanceJinraiModeCombo())
		for _ = 1, 4 do
			assert.is_true(instance.advanceJinraiModeCombo())
		end

		local jinrai1LoadCount = 0
		for _, path in ipairs(mocks.loadedImagePaths) do
			if path == "./Jinrai.spoon/resources/jinrai1.webp" then
				jinrai1LoadCount = jinrai1LoadCount + 1
			end
		end
		assert.are.equal(1, jinrai1LoadCount)
	end)

	it("JinraiMode 中にキャンセルするとロゴを削除する", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local targetWindow = makeWindow(1, "Target", focusCounter)
		local mocks = installHsMock(targetWindow, createdCanvases)
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")

		local instance = windowHints.new({
			hint = {
				title = {
					show = false,
				},
			},
			behavior = {
				callbacks = {
					onError = function(err)
						error(err)
					end,
				},
				cursor = {
					onStart = false,
					onSelect = false,
				},
			},
			internal = {
				jinraiMode = {
					windowHints = {
						key = "space",
					},
					logo = {
						enabled = true,
						size = 480,
						alpha = 0.3,
					},
				},
				onJinraiModeSelect = function() end,
			},
		})
		assert.is_true(instance.show())
		mocks.keyBlocker.callback({
			getKeyCode = function()
				return 49
			end,
			getFlags = function()
				return {}
			end,
		})

		local logoCanvas
		for _, canvas in ipairs(createdCanvases) do
			if canvas[1] and canvas[1].image and canvas[1].image.path == "./Jinrai.spoon/jinrai.svg" then
				logoCanvas = canvas
				break
			end
		end
		assert.is_truthy(logoCanvas)

		mocks.keyBlocker.callback({
			getKeyCode = function()
				return 53
			end,
			getFlags = function()
				return {}
			end,
		})

		assert.is_true(logoCanvas._deleted)
	end)

	it("ヒント表示中にヒント外を左クリックすると閉じる", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local targetWindow = makeWindow(1, "Target", focusCounter)
		local mocks = installHsMock(targetWindow, createdCanvases)
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")

		local instance = windowHints.new({
			hint = {
				title = {
					show = false,
				},
			},
			behavior = {
				callbacks = {
					onError = function(err)
						error(err)
					end,
				},
				cursor = {
					onStart = false,
					onSelect = false,
				},
			},
		})
		assert.is_true(instance.show())

		local hintCanvas
		for _, canvas in ipairs(createdCanvases) do
			if canvas._mouseCallback then
				hintCanvas = canvas
				break
			end
		end
		assert.is_truthy(hintCanvas)
		assert.is_true(mocks.mouseClickWatcher.started)

		local consumed = mocks.mouseClickWatcher.callback({
			location = function()
				return { x = 10, y = 10 }
			end,
		})

		assert.is_true(consumed)
		assert.are.equal(0, focusCounter.count)
		assert.is_true(hintCanvas._deleted)
		assert.is_false(mocks.mouseClickWatcher.started)
	end)

	it("ヒント表示中にヒント内を左クリックしても外側クリックとして閉じない", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local targetWindow = makeWindow(1, "Target", focusCounter)
		local mocks = installHsMock(targetWindow, createdCanvases)
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")

		local instance = windowHints.new({
			hint = {
				title = {
					show = false,
				},
			},
			behavior = {
				callbacks = {
					onError = function(err)
						error(err)
					end,
				},
				cursor = {
					onStart = false,
					onSelect = false,
				},
			},
		})
		assert.is_true(instance.show())

		local hintCanvas
		for _, canvas in ipairs(createdCanvases) do
			if canvas._mouseCallback then
				hintCanvas = canvas
				break
			end
		end
		assert.is_truthy(hintCanvas)

		local consumed = mocks.mouseClickWatcher.callback({
			location = function()
				return { x = hintCanvas._frame.x + 1, y = hintCanvas._frame.y + 1 }
			end,
		})

		assert.is_false(consumed)
		assert.are.equal(0, focusCounter.count)
		assert.is_nil(hintCanvas._deleted)
		assert.is_true(mocks.mouseClickWatcher.started)
	end)

	it("ヒント表示中に同じホットキーを押すと keyBlocker 経由で閉じる", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local targetWindow = makeWindow(1, "Target", focusCounter)
		local mocks = installHsMock(targetWindow, createdCanvases)
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")

		local instance = windowHints.new({
			hotkey = {
				modifiers = { "alt" },
				key = "f20",
			},
			hint = {
				title = {
					show = false,
				},
			},
			behavior = {
				callbacks = {
					onError = function(err)
						error(err)
					end,
				},
				cursor = {
					onStart = false,
					onSelect = false,
				},
			},
		})
		assert.is_true(instance.show())
		assert.is_true(mocks.keyBlocker.started)
		assert.is_truthy(mocks.keyBlocker.callback)

		local consumed = mocks.keyBlocker.callback({
			getKeyCode = function()
				return 42
			end,
			getFlags = function()
				return { alt = true }
			end,
		})

		assert.is_true(consumed)
		assert.is_false(mocks.keyBlocker.started)
		for _, canvas in ipairs(createdCanvases) do
			assert.is_true(canvas._deleted)
		end
	end)

	it("ヒント表示中に同じホットキー callback が発火しても閉じる", function()
		local createdCanvases = {}
		local focusCounter = { count = 0 }
		local targetWindow = makeWindow(1, "Target", focusCounter)
		local mocks = installHsMock(targetWindow, createdCanvases)
		local windowHints = dofile("./Jinrai.spoon/window_hints.lua")

		local instance = windowHints.new({
			hotkey = {
				modifiers = { "alt" },
				key = "f20",
			},
			hint = {
				title = {
					show = false,
				},
			},
			behavior = {
				callbacks = {
					onError = function(err)
						error(err)
					end,
				},
				cursor = {
					onStart = false,
					onSelect = false,
				},
			},
		})
		assert.is_true(instance.show())
		assert.is_truthy(mocks.hotkeys[1])

		mocks.hotkeys[1].callback()

		assert.is_false(mocks.keyBlocker.started)
		for _, canvas in ipairs(createdCanvases) do
			assert.is_true(canvas._deleted)
		end
	end)
end)

describe("shrinkDockItemWidths", function()
	local helper
	before_each(function()
		helper = dofile("./Jinrai.spoon/window_hints.lua")._test
	end)

	it("totalWidth が availableWidth 以下なら変更しない", function()
		local items = {
			{ width = 100, minWidth = 60 },
			{ width = 100, minWidth = 60 },
		}
		local needsMultiRow = helper.shrinkDockItemWidths(items, 220, 10)
		assert.is_false(needsMultiRow)
		assert.are.equal(100, items[1].width)
		assert.are.equal(100, items[2].width)
	end)

	it("totalWidth が超えるが minWidth で収まる場合、タイトル幅を比例縮小する", function()
		local items = {
			{ width = 200, minWidth = 80 },
			{ width = 200, minWidth = 80 },
		}
		-- totalWidth = 200+10+200 = 410, availableWidth = 300
		-- totalMinWidth = 80+10+80 = 170, availableForTitles = 300-170 = 130
		-- ratio = 130 / 240 ≈ 0.541, titleContrib each = 120
		-- new width = 80 + floor(120 * 130/240) = 80 + 65 = 145
		local needsMultiRow = helper.shrinkDockItemWidths(items, 300, 10)
		assert.is_false(needsMultiRow)
		assert.are.equal(145, items[1].width)
		assert.are.equal(145, items[2].width)
	end)

	it("minWidth でも収まらない場合、needsMultiRow = true を返す", function()
		local items = {
			{ width = 200, minWidth = 150 },
			{ width = 200, minWidth = 150 },
		}
		-- totalMinWidth = 150+10+150 = 310 > 300
		local needsMultiRow = helper.shrinkDockItemWidths(items, 300, 10)
		assert.is_true(needsMultiRow)
		assert.are.equal(150, items[1].width)
		assert.are.equal(150, items[2].width)
	end)

	it("アイテムが1つだけで収まる場合は変更しない", function()
		local items = {
			{ width = 200, minWidth = 80 },
		}
		local needsMultiRow = helper.shrinkDockItemWidths(items, 300, 10)
		assert.is_false(needsMultiRow)
		assert.are.equal(200, items[1].width)
	end)

	it("空配列では false を返す", function()
		local needsMultiRow = helper.shrinkDockItemWidths({}, 300, 10)
		assert.is_false(needsMultiRow)
	end)

	it("gap = 0 でも正しく動作する", function()
		local items = {
			{ width = 200, minWidth = 80 },
			{ width = 200, minWidth = 80 },
		}
		-- totalWidth = 400, availableWidth = 300
		-- totalMinWidth = 160, availableForTitles = 140
		-- ratio = 140 / 240 ≈ 0.583, each = 80 + floor(120 * 140/240) = 80 + 70 = 150
		local needsMultiRow = helper.shrinkDockItemWidths(items, 300, 0)
		assert.is_false(needsMultiRow)
		assert.are.equal(150, items[1].width)
		assert.are.equal(150, items[2].width)
	end)

	it("異なるタイトル幅のアイテムは比例縮小される", function()
		local items = {
			{ width = 300, minWidth = 100 }, -- titleContrib = 200
			{ width = 150, minWidth = 100 }, -- titleContrib = 50
		}
		-- totalWidth = 300+10+150 = 460, availableWidth = 350
		-- totalMinWidth = 100+10+100 = 210, availableForTitles = 140
		-- totalTitleWidth = 250, ratio = 140/250 = 0.56
		-- item1: 100 + floor(200 * 0.56) = 100 + 112 = 212
		-- item2: 100 + floor(50 * 0.56) = 100 + 28 = 128
		local needsMultiRow = helper.shrinkDockItemWidths(items, 350, 10)
		assert.is_false(needsMultiRow)
		assert.are.equal(212, items[1].width)
		assert.are.equal(128, items[2].width)
	end)
end)

describe("splitDockItemsIntoRows", function()
	local helper
	before_each(function()
		helper = dofile("./Jinrai.spoon/window_hints.lua")._test
	end)

	it("1行に収まる場合は1行を返す", function()
		local items = {
			{ width = 100 },
			{ width = 100 },
		}
		local rows = helper.splitDockItemsIntoRows(items, 220, 10)
		assert.are.equal(1, #rows)
		assert.are.equal(2, #rows[1])
	end)

	it("2行に分割されるケース", function()
		local items = {
			{ width = 100 },
			{ width = 100 },
			{ width = 100 },
		}
		-- availableWidth = 220, gap = 10
		-- row1: 100 + 10 + 100 = 210 <= 220, then +10+100 = 320 > 220
		-- row2: 100
		local rows = helper.splitDockItemsIntoRows(items, 220, 10)
		assert.are.equal(2, #rows)
		assert.are.equal(2, #rows[1])
		assert.are.equal(1, #rows[2])
	end)

	it("1アイテムが availableWidth を超える場合でも行に入る", function()
		local items = {
			{ width = 300 },
			{ width = 100 },
		}
		local rows = helper.splitDockItemsIntoRows(items, 200, 10)
		assert.are.equal(2, #rows)
		assert.are.equal(1, #rows[1])
		assert.are.equal(300, rows[1][1].width)
		assert.are.equal(1, #rows[2])
		assert.are.equal(100, rows[2][1].width)
	end)

	it("空配列の場合は空を返す", function()
		local rows = helper.splitDockItemsIntoRows({}, 200, 10)
		assert.are.equal(0, #rows)
	end)

	it("元の順序を保持する", function()
		local items = {
			{ width = 100, id = "a" },
			{ width = 100, id = "b" },
			{ width = 100, id = "c" },
			{ width = 100, id = "d" },
		}
		local rows = helper.splitDockItemsIntoRows(items, 220, 10)
		assert.are.equal(2, #rows)
		assert.are.equal("a", rows[1][1].id)
		assert.are.equal("b", rows[1][2].id)
		assert.are.equal("c", rows[2][1].id)
		assert.are.equal("d", rows[2][2].id)
	end)
end)
