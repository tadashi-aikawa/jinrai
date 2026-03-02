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

	it("予約キーを hintChars から除外できる", function()
		local reserved = helper.buildReservedHintCharLookup({
			h = "left",
			j = "down",
		}, "k")
		local filtered = helper.filterHintChars(helper.normalizeHintChars({ "A", "H", "J", "K", "L" }), reserved)
		assert.are.same({ "A", "L" }, filtered)
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

	it("方向移動は指定方向の最近傍ウィンドウを返す", function()
		local current = stubWindow(1, { x = 0, y = 0, w = 10, h = 10 })
		local nearRight = stubWindow(2, { x = 20, y = 0, w = 10, h = 10 })
		local farRight = stubWindow(3, { x = 80, y = 0, w = 10, h = 10 })
		local target = helper.findDirectionalWindowTarget(current, { nearRight, farRight }, "right", nil)
		assert.are.equal(2, target:id())
	end)

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

		local target1 = helper.findDirectionalWindowTarget(win4, { win1, win2, win3 }, "up", nil, { win1, win2, win3, win4 })
		assert.are.equal(1, target1:id())

		local target2 = helper.findDirectionalWindowTarget(win4, { win1, win2, win3 }, "up", nil, { win2, win1, win3, win4 })
		assert.are.equal(2, target2:id())
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
