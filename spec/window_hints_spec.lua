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

	it("swapWindowFrameSelectModifiers を正規化できる", function()
		local normalized = helper.normalizeSelectModifiers({ "Shift", "CMD" })
		assert.are.same({ "cmd", "shift" }, normalized)
	end)

	it("swapWindowFrameSelectModifiers で option は alt として扱う", function()
		local normalized = helper.normalizeSelectModifiers({ "option", "cmd" })
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
		assert.is_truthy(tostring(err):match("directionKeys must not contain duplicate keys"))
	end)

	it("swapWindowFrameSelectModifiers が空配列ならエラー", function()
		local ok, err = pcall(function()
			helper.normalizeSelectModifiers({})
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("must not be empty"))
	end)

	it("swapWindowFrameSelectModifiers に重複があればエラー", function()
		local ok, err = pcall(function()
			helper.normalizeSelectModifiers({ "shift", "SHIFT" })
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("duplicate"))
	end)

	it("swapWindowFrameSelectModifiers に不正な修飾キーがあればエラー", function()
		local ok, err = pcall(function()
			helper.normalizeSelectModifiers({ "hyper" })
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("cmd/alt/ctrl/shift/fn"))
	end)

	it("swap判定は修飾キー完全一致のときだけ true", function()
		local swapModifiers = helper.normalizeSelectModifiers({ "shift", "cmd" })
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

	it("dockWindowXBlend=0 では中央寄せレイアウトXを使う", function()
		local x = helper.resolveOccludedDockItemX(
			{ x = 0, y = 0, w = 1200, h = 800 },
			180,
			320,
			700,
			320,
			0
		)
		assert.are.equal(320, x)
	end)

	it("開始Xは中央寄せ", function()
		local startX = helper.resolveOccludedDockStartX({ x = 100, y = 0, w = 1200, h = 800 }, 400)
		assert.are.equal(500, startX)
	end)

	it("dockWindowXBlend=1 では対象ウィンドウ中心にヒント中心を合わせる", function()
		local x = helper.resolveOccludedDockItemX(
			{ x = 0, y = 0, w = 1200, h = 800 },
			180,
			320,
			700,
			320,
			1
		)
		assert.are.equal(610, x)
	end)

	it("dockWindowXBlend=0.5 では中央と対象中心基準xの中間へ寄る", function()
		local x = helper.resolveOccludedDockItemX(
			{ x = 0, y = 0, w = 1200, h = 800 },
			180,
			320,
			700,
			320,
			0.5
		)
		assert.are.equal(465, x)
	end)

	it("dockWindowXBlend=1 でも重なり回避の最小Xを下回らない", function()
		local x = helper.resolveOccludedDockItemX(
			{ x = 0, y = 0, w = 1200, h = 800 },
			180,
			320,
			200,
			320,
			1
		)
		assert.are.equal(320, x)
	end)

	it("dockWindowXBlend=1 では画面右端に収まるようにクランプされる", function()
		local x = helper.resolveOccludedDockItemX(
			{ x = 0, y = 0, w = 800, h = 600 },
			180,
			320,
			900,
			320,
			1
		)
		assert.are.equal(620, x)
	end)

	it("dockWindowXBlend=1 で同一中心の複数ウィンドウは中央寄せを維持する", function()
		local xs = helper.resolveOccludedDockItemXs(
			{ x = 0, y = 0, w = 1200, h = 800 },
			{
				{ width = 180, centeredX = 222, windowCenterX = 600 },
				{ width = 180, centeredX = 414, windowCenterX = 600 },
				{ width = 180, centeredX = 606, windowCenterX = 600 },
				{ width = 180, centeredX = 798, windowCenterX = 600 },
			},
			12,
			1
		)
		assert.are.same({ 222, 414, 606, 798 }, xs)
	end)

	it("dockWindowYBlend=0 では下ドック配置Yを使う", function()
		local y = helper.resolveOccludedDockItemY(
			{ x = 0, y = 0, w = 1200, h = 800 },
			120,
			500,
			220,
			0,
			180
		)
		assert.are.equal(500, y)
	end)

	it("dockWindowYBlend=1 では上半分ウィンドウを上端マージンへ寄せる", function()
		local y = helper.resolveOccludedDockItemY(
			{ x = 0, y = 0, w = 1200, h = 800 },
			120,
			500,
			220,
			1,
			180
		)
		assert.are.equal(180, y)
	end)

	it("dockWindowYBlend=0.5 では下ドックと上端マージンの中間へ寄る", function()
		local y = helper.resolveOccludedDockItemY(
			{ x = 0, y = 0, w = 1200, h = 800 },
			120,
			500,
			220,
			0.5,
			180
		)
		assert.are.equal(340, y)
	end)

	it("dockWindowYBlend=1 でも下半分ウィンドウは下ドック配置を維持する", function()
		local y = helper.resolveOccludedDockItemY(
			{ x = 0, y = 0, w = 1200, h = 800 },
			120,
			500,
			700,
			1,
			180
		)
		assert.are.equal(500, y)
	end)

	it("dockWindowYBlend=1 では上端マージンが大きすぎても画面下端に収まる", function()
		local y = helper.resolveOccludedDockItemY(
			{ x = 0, y = 0, w = 1200, h = 800 },
			120,
			500,
			220,
			1,
			760
		)
		assert.are.equal(680, y)
	end)

	it("dockWindowYBlend=1 では画面下端に収まるようにクランプされる", function()
		local y = helper.resolveOccludedDockItemY(
			{ x = 0, y = 0, w = 1200, h = 800 },
			120,
			900,
			900,
			1,
			180
		)
		assert.are.equal(680, y)
	end)

	it("文字キーの入力修飾キー集合を生成できる", function()
		local bindings = helper.collectModalInputModifiers("w", helper.normalizeSelectModifiers({ "cmd" }))
		assert.are.same({ {}, { "cmd" }, { "shift" } }, bindings)
	end)

	it("非文字キーでも swap 修飾キーを追加できる", function()
		local bindings = helper.collectModalInputModifiers("f18", helper.normalizeSelectModifiers({ "shift" }))
		assert.are.same({ {}, { "shift" } }, bindings)
	end)

	it("swap修飾キーが shift のとき文字キーで重複を除去できる", function()
		local bindings = helper.collectModalInputModifiers("w", helper.normalizeSelectModifiers({ "shift" }))
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

		local target1 = helper.findDirectionalWindowTarget(win4, { win1, win2, win3 }, "up", nil, { win1, win2, win3, win4 })
		assert.are.equal(1, target1:id())

		local target2 = helper.findDirectionalWindowTarget(win4, { win1, win2, win3 }, "up", nil, { win2, win1, win3, win4 })
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
		local target = helper.findDirectionalWindowTarget(current, { win2, win3 }, "upRight", nil, { win3, win2, current })
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
