describe("window_hints appPrefixOverrides", function()
	local helper
	local allowedPrefixes
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
		local mod = dofile("./window_hints.lua")
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

		local matched = helper.resolveAppPrefix(
			"Obsidian",
			"md.obsidian",
			"Minerva - Daily",
			"A",
			allowedPrefixes,
			compiled
		)
		assert.are.equal("M", matched)

		local fallbackRuleMatched = helper.resolveAppPrefix(
			"Obsidian",
			"md.obsidian",
			"Scratch",
			"A",
			allowedPrefixes,
			compiled
		)
		assert.are.equal("O", fallbackRuleMatched)
	end)

	it("titleGlob は window:title() に対して大文字小文字を区別する", function()
		local compiled = helper.compileAppPrefixOverrides({
			{
				match = { titleGlob = "Minerva*" },
				prefix = "M",
			},
		}, allowedPrefixes)

		local matched = helper.resolveAppPrefix(
			"Obsidian",
			"md.obsidian",
			"Minerva - Daily",
			"A",
			allowedPrefixes,
			compiled
		)
		assert.are.equal("M", matched)

		local notMatched = helper.resolveAppPrefix(
			"Obsidian",
			"md.obsidian",
			"minerva - Daily",
			"A",
			allowedPrefixes,
			compiled
		)
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
end)
