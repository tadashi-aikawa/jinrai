local M = {}

local DEFAULT_HINT_CHARS = {
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

local DEFAULT_CONFIG = {
	-- ヒント表示のホットキー修飾キー
	hotkeyModifiers = { "alt" },
	-- ヒント表示のホットキー
	hotkeyKey = "f20",
	-- アプリアイコンのサイズ (px)
	iconSize = 72,
	-- キー表示ボックスの高さ (px)
	keyBoxSize = 72,
	-- キー表示ボックスの最小幅 (px)
	keyBoxMinWidth = 72,
	-- キー表示ボックスの左右パディング (px)
	keyBoxHorizontalPadding = 10,
	-- アイコンとキー表示ボックスの間隔 (px)
	keyGap = 0,
	-- ヒントバッジ全体の内側余白 (px)
	padding = 12,
	-- キー・タイトルのフォント名 (nilでシステムデフォルト)
	fontName = nil,
	-- キー文字のフォントサイズ
	fontSize = 48,
	-- タイトル文字のフォントサイズ
	titleFontSize = 16,
	-- アイコン行とタイトル行の間隔 (px)
	rowGap = 8,
	-- タイトルの最大表示文字数 (超過は省略)
	titleMaxSize = 72,
	-- タイトル行を表示するか
	showTitles = true,
	-- ヒントバッジの背景色
	bgColor = { red = 0, green = 0, blue = 0, alpha = 0.72 },
	-- 非アクティブ(入力不一致)時の背景アルファ値
	dimmedBgAlpha = 0.22,
	-- キー文字の色
	textColor = { red = 1, green = 1, blue = 1, alpha = 1 },
	-- 非アクティブ時のキー文字の色
	dimmedTextColor = { red = 1, green = 1, blue = 1, alpha = 0.35 },
	-- タイトル文字の色
	titleTextColor = { red = 0.84, green = 0.84, blue = 0.86, alpha = 1 },
	-- 非アクティブ時のタイトル文字の色
	dimmedTitleTextColor = { red = 0.84, green = 0.84, blue = 0.86, alpha = 0.35 },
	-- 入力済みキープレフィックスのハイライト色
	keyHighlightColor = { red = 0.84, green = 0.84, blue = 0.86, alpha = 0.35 },
	-- アプリアイコンの不透明度
	iconAlpha = 0.95,
	-- 非アクティブ時のアプリアイコンの不透明度
	dimmedIconAlpha = 0.48,
	-- ヒント同士の重なり検出しきい値 (px)
	bumpThreshold = 120,
	-- ヒント重なり時のずらし量 (px)
	bumpMove = 90,
	-- 遮蔽ウィンドウのプレビュー画像を表示するか
	showPreviewForOccluded = true,
	-- 遮蔽ウィンドウのプレビュー画像の幅 (px)
	previewWidth = 140,
	-- プレビュー画像の上余白 (px)
	previewPadding = 6,
	-- 遮蔽ヒントの縮小率 (1.0で等倍)
	occludedScale = 0.65,
	-- 遮蔽ヒントの背景アルファ値
	occludedBgAlpha = 0.50,
	-- 遮蔽ヒントのアイコン不透明度
	occludedIconAlpha = 0.65,
	-- 遮蔽ヒントのプレビュー画像の不透明度
	occludedPreviewAlpha = 0.65,
	-- 前面ヒントバッジのボーダー色 (未使用: hintOverlay系に置換済み)
	visibleBorderColor = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.80 },
	-- 前面ヒントバッジのボーダー幅 (未使用: hintOverlay系に置換済み)
	visibleBorderWidth = 10,
	-- アクティブウィンドウのオーバーレイ塗り色
	activeOverlayColor = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.08 },
	-- アクティブウィンドウのオーバーレイボーダー色
	activeOverlayBorderColor = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.95 },
	-- アクティブウィンドウのオーバーレイボーダー幅 (px)
	activeOverlayBorderWidth = 10,
	-- アクティブウィンドウのオーバーレイ角丸半径 (px)
	activeOverlayCornerRadius = 10,
	-- 前面ヒントバッジのオーバーレイ塗り色
	hintOverlayColor = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.38 },
	-- 前面ヒントバッジのオーバーレイボーダー色
	hintOverlayBorderColor = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.85 },
	-- 前面ヒントバッジのオーバーレイボーダー幅 (px)
	hintOverlayBorderWidth = 4,
	-- 前面ヒントバッジのオーバーレイ角丸半径 (px)
	hintOverlayCornerRadius = 12,
	-- 遮蔽ヒントドックの画面下端からのマージン (px)
	dockBottomMargin = 24,
	-- 遮蔽ヒントドック内のアイテム間隔 (px)
	dockItemGap = 10,
	-- ウィンドウ選択時のコールバック関数
	onSelect = nil,
}

local function mergeTable(defaults, overrides)
	local merged = {}
	for k, v in pairs(defaults) do
		merged[k] = v
	end
	if overrides then
		for k, v in pairs(overrides) do
			merged[k] = v
		end
	end
	return merged
end

local function cloneColor(color)
	return {
		red = color.red,
		green = color.green,
		blue = color.blue,
		alpha = color.alpha,
	}
end

local function startsWith(s, prefix)
	return string.sub(s, 1, #prefix) == prefix
end

local function utf8Truncate(text, maxSize)
	if maxSize == nil or maxSize < 6 then
		return text
	end
	local len = utf8.len(text)
	if not len or len <= maxSize then
		return text
	end
	local endIdx = utf8.offset(text, math.max(1, maxSize - 3))
	if not endIdx then
		return text
	end
	return string.sub(text, 1, endIdx - 1) .. "..."
end

local function keySuffixFor(index, hintChars)
	local base = #hintChars
	local n = index
	local code = ""
	repeat
		local rem = n % base
		code = hintChars[rem + 1] .. code
		n = math.floor(n / base) - 1
	until n < 0
	return code
end

local function appPrefixChar(appTitle, fallback, allowedPrefixes)
	local c = string.upper(string.sub(appTitle or "", 1, 1))
	if c == "" or not allowedPrefixes[c] then
		return fallback
	end
	return c
end

local function clamp(value, min, max)
	if value < min then
		return min
	end
	if value > max then
		return max
	end
	return value
end

local function estimatedTextWidth(text, fontSize, minimum)
	local len = utf8.len(text) or string.len(text)
	return math.max(minimum or 40, math.floor((len + 1) * fontSize * 0.55))
end

local function estimatedKeyTextWidth(text, fontSize)
	local width = 0
	for i = 1, #text do
		local ch = string.sub(text, i, i)
		if ch == " " then
			width = width + (fontSize * 0.30)
		else
			width = width + (fontSize * 0.62)
		end
	end
	return math.floor(width)
end

local function isPointInRect(px, py, rect)
	return px >= rect.x and px <= rect.x + rect.w and py >= rect.y and py <= rect.y + rect.h
end

local function isWindowOccluded(targetFrame, coveringFrames)
	local cols, rows = 4, 4
	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			local px = targetFrame.x + targetFrame.w * (col + 0.5) / cols
			local py = targetFrame.y + targetFrame.h * (row + 0.5) / rows
			local covered = false
			for _, f in ipairs(coveringFrames) do
				if isPointInRect(px, py, f) then
					covered = true
					break
				end
			end
			if not covered then
				return false
			end
		end
	end
	return true
end

local function findUncoveredCenter(windowFrame, coveringFrames)
	local cx = windowFrame.x + windowFrame.w / 2
	local cy = windowFrame.y + windowFrame.h / 2
	if not coveringFrames or #coveringFrames == 0 then
		return cx, cy
	end

	local cols, rows = 5, 5
	local bestX, bestY = cx, cy
	local bestDist = math.huge
	local found = false

	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			local px = windowFrame.x + windowFrame.w * (col + 0.5) / cols
			local py = windowFrame.y + windowFrame.h * (row + 0.5) / rows
			local covered = false
			for _, f in ipairs(coveringFrames) do
				if isPointInRect(px, py, f) then
					covered = true
					break
				end
			end
			if not covered then
				local dx = px - cx
				local dy = py - cy
				local dist = dx * dx + dy * dy
				if dist < bestDist then
					bestDist = dist
					bestX = px
					bestY = py
					found = true
				end
			end
		end
	end

	return bestX, bestY
end

local function rawPrefixLenToDisplayLen(prefixLen)
	if prefixLen <= 0 then
		return 0
	end
	return prefixLen * 2 - 1
end

local function keyToDisplayText(key)
	if #key <= 1 then
		return key
	end
	local parts = {}
	for i = 1, #key do
		table.insert(parts, string.sub(key, i, i))
	end
	return table.concat(parts, " ")
end

function M.new(options)
	options = options or {}
	local config = mergeTable(DEFAULT_CONFIG, options)
	local hintChars = options.hintChars or DEFAULT_HINT_CHARS

	local hotkey = nil
	local modal = nil
	local openHints = {}
	local hintByKey = {}
	local currentInput = ""
	local isShowing = false
	local activeOverlayCanvas = nil
	local allowedPrefixes = {}
	for _, char in ipairs(hintChars) do
		allowedPrefixes[char] = true
	end

	local function clearHints()
		for _, hint in ipairs(openHints) do
			if hint.canvas then
				hint.canvas:delete()
			end
		end
		if activeOverlayCanvas then
			activeOverlayCanvas:delete()
			activeOverlayCanvas = nil
		end
		openHints = {}
		hintByKey = {}
		currentInput = ""
	end

	local function setHintActive(hint, active)
		local bg = cloneColor(config.bgColor)
		if hint.isOccluded then
			bg.alpha = active and config.occludedBgAlpha or config.dimmedBgAlpha
		elseif not active then
			bg.alpha = config.dimmedBgAlpha
		end
		local prefixLen = 0
		if active and currentInput ~= "" and startsWith(hint.key, currentInput) then
			prefixLen = math.min(#currentInput, #hint.keyText)
		end
		local fSize = hint.effectiveFontSize or config.fontSize
		local displayPrefixLen = rawPrefixLenToDisplayLen(prefixLen)
		local prefixText = displayPrefixLen > 0 and string.sub(hint.displayKeyText, 1, displayPrefixLen) or ""
		local restText = string.sub(hint.displayKeyText, displayPrefixLen + 1)
		local totalTextWidth = estimatedKeyTextWidth(hint.displayKeyText, fSize) + 8
		local prefixTextWidth = estimatedKeyTextWidth(prefixText, fSize) + 2
		prefixTextWidth = math.max(0, math.min(totalTextWidth, prefixTextWidth))
		local textLeft = hint.keyBoxFrame.x + (hint.keyBoxFrame.w - totalTextWidth) / 2
		local textTop = hint.keyBoxFrame.y + (hint.keyBoxFrame.h - hint.keyTextHeight) / 2

		hint.canvas[1].fillColor = bg
		local activeIconAlpha = hint.isOccluded and config.occludedIconAlpha or config.iconAlpha
		hint.canvas[hint.iconIdx].imageAlpha = active and activeIconAlpha or config.dimmedIconAlpha
		hint.canvas[hint.keyPrefixIdx].text = prefixText
		hint.canvas[hint.keyPrefixIdx].frame = {
			x = textLeft,
			y = textTop,
			w = prefixTextWidth,
			h = hint.keyTextHeight,
		}
		hint.canvas[hint.keyRestIdx].text = restText
		hint.canvas[hint.keyRestIdx].frame = {
			x = textLeft + prefixTextWidth,
			y = textTop,
			w = math.max(0, totalTextWidth - prefixTextWidth),
			h = hint.keyTextHeight,
		}
		hint.canvas[hint.keyPrefixIdx].textColor = active and config.keyHighlightColor or config.dimmedTextColor
		hint.canvas[hint.keyRestIdx].textColor = active and config.textColor or config.dimmedTextColor
		hint.canvas[hint.titleIdx].textColor = active and config.titleTextColor or config.dimmedTitleTextColor
	end

	local function keyBoxWidthForText(displayKeyText)
		local textWidth = estimatedKeyTextWidth(displayKeyText, config.fontSize)
		local minWidth = config.keyBoxMinWidth or config.keyBoxSize
		return math.max(minWidth, textWidth + (config.keyBoxHorizontalPadding * 2))
	end

	local function hasPrefixMatch(prefix)
		for key, _ in pairs(hintByKey) do
			if startsWith(key, prefix) then
				return true
			end
		end
		return false
	end

	local function refreshHighlights()
		for _, hint in ipairs(openHints) do
			local active = currentInput == "" or startsWith(hint.key, currentInput)
			setHintActive(hint, active)
		end
	end

	local function closeHints(exitModal)
		if isShowing and exitModal and modal then
			modal:exit()
		end
		isShowing = false
		clearHints()
	end

	local function selectWindow(win)
		if not win then
			return
		end
		win:focus()
		if config.onSelect then
			config.onSelect(win)
		end
		closeHints(true)
	end

	local function handleChar(char)
		if not isShowing then
			return
		end

		currentInput = currentInput .. char
		local exact = hintByKey[currentInput]
		if exact then
			selectWindow(exact.win)
			return
		end

		if hasPrefixMatch(currentInput) then
			refreshHighlights()
			return
		end

		currentInput = char
		if hasPrefixMatch(currentInput) then
			refreshHighlights()
			return
		end

		currentInput = ""
		refreshHighlights()
	end

	local function handleBackspace()
		if not isShowing then
			return
		end
		if #currentInput == 0 then
			return
		end
		currentInput = string.sub(currentInput, 1, #currentInput - 1)
		refreshHighlights()
	end

	local function ensureModal()
		if modal then
			return
		end
		modal = hs.hotkey.modal.new(nil, nil)
		modal:bind({}, "escape", function()
			closeHints(true)
		end)
		modal:bind({}, "delete", function()
			handleBackspace()
		end)
		modal:bind({}, "forwarddelete", function()
			handleBackspace()
		end)
		for _, char in ipairs(hintChars) do
			local lower = string.lower(char)
			modal:bind({}, lower, function()
				handleChar(char)
			end)
			modal:bind({ "shift" }, lower, function()
				handleChar(char)
			end)
		end
	end

	local function collectEntries()
		local entries = {}
		local focusedWin = hs.window.focusedWindow()
		local focusedId = focusedWin and focusedWin:id() or nil
		local orderedWins = hs.window.orderedWindows()
		local orderedFrames = {}
		for _, w in ipairs(orderedWins) do
			local f = w:frame()
			if f then
				table.insert(orderedFrames, { id = w:id(), frame = f })
			end
		end

		for _, win in ipairs(hs.window.visibleWindows()) do
			local app = win:application()
			local screen = win:screen()
			if app and app:bundleID() and screen and win:isStandard() and win:id() ~= focusedId then
				local appTitle = app:title() or ""
				local occluded = false
				local coveringFrames = {}
				local wf = win:frame()
				local wid = win:id()
				for _, of in ipairs(orderedFrames) do
					if of.id == wid then
						break
					end
					table.insert(coveringFrames, of.frame)
				end
				if config.showPreviewForOccluded and #coveringFrames > 0 and wf.w > 0 and wf.h > 0 then
					occluded = isWindowOccluded(wf, coveringFrames)
				end
				table.insert(entries, {
					win = win,
					app = app,
					appTitle = appTitle,
					title = win:title() or "",
					prefix = appPrefixChar(appTitle, hintChars[1], allowedPrefixes),
					isOccluded = occluded,
					coveringFrames = coveringFrames,
				})
			end
		end

		table.sort(entries, function(a, b)
			if a.prefix ~= b.prefix then
				return a.prefix < b.prefix
			end
			if a.appTitle ~= b.appTitle then
				return a.appTitle < b.appTitle
			end
			if a.title ~= b.title then
				return a.title < b.title
			end
			local af = a.win:frame()
			local bf = b.win:frame()
			if af.x ~= bf.x then
				return af.x < bf.x
			end
			return af.y < bf.y
		end)

		return entries
	end

	local function buildHintEntries(entries)
		local grouped = {}
		for _, entry in ipairs(entries) do
			grouped[entry.prefix] = grouped[entry.prefix] or {}
			table.insert(grouped[entry.prefix], entry)
		end

		local hints = {}
		for _, char in ipairs(hintChars) do
			local group = grouped[char]
			if group then
				for i, entry in ipairs(group) do
					local key = #group == 1 and char or (char .. keySuffixFor(i - 1, hintChars))
					local title = entry.title ~= "" and entry.title or entry.appTitle
					title = config.showTitles and utf8Truncate(title, config.titleMaxSize) or ""
					table.insert(hints, {
						key = key,
						keyText = key,
						displayKeyText = keyToDisplayText(key),
						titleText = title,
						win = entry.win,
						app = entry.app,
						isOccluded = entry.isOccluded,
						coveringFrames = entry.coveringFrames,
					})
				end
			end
		end

		return hints
	end

	local function nextCenter(baseCenter, screenFrame, width, height, takenRects)
		local x = baseCenter.x
		local y = baseCenter.y

		for _ = 1, 80 do
			local conflicted = false
			for _, r in ipairs(takenRects) do
				local overlapX = math.abs(r.x - x) < (r.w + width) / 2
				local overlapY = math.abs(r.y - y) < (r.h + height) / 2
				if overlapX and overlapY then
					conflicted = true
					break
				end
			end

			if not conflicted then
				break
			end

			y = y + config.bumpMove
			local maxY = screenFrame.y + screenFrame.h - (height / 2)
			if y > maxY then
				y = baseCenter.y
				x = x + config.bumpMove
			end
		end

		local minX = screenFrame.x + (width / 2)
		local maxX = screenFrame.x + screenFrame.w - (width / 2)
		local minY = screenFrame.y + (height / 2)
		local maxY = screenFrame.y + screenFrame.h - (height / 2)

		return {
			x = clamp(x, minX, maxX),
			y = clamp(y, minY, maxY),
		}
	end

	local function newHintCanvas(
		frame,
		icon,
		keyText,
		titleText,
		keyBoxWidth,
		previewImage,
		previewHeight,
		isOccluded,
		scale
	)
		scale = scale or 1
		local canvas = hs.canvas
			.new(frame)
			:level(hs.canvas.windowLevels.overlay)
			:behavior({ "canJoinAllSpaces", "stationary", "ignoresCycle" })

		local iconSz = math.floor(config.iconSize * scale)
		local keyBoxSz = math.floor(config.keyBoxSize * scale)
		local fSize = math.floor(config.fontSize * scale)
		local tFontSize = math.floor(config.titleFontSize * scale)
		local pad = math.floor(config.padding * scale)
		local gap = math.floor(config.keyGap * scale)
		local rGap = math.floor(config.rowGap * scale)

		local topRowHeight = math.max(iconSz, keyBoxSz)
		local topRowWidth = iconSz + gap + keyBoxWidth
		local topRowLeft = (frame.w - topRowWidth) / 2
		local keyTextHeight = fSize + 8
		local titleTextHeight = tFontSize + 8
		local iconFrame = {
			x = topRowLeft,
			y = pad + (topRowHeight - iconSz) / 2,
			w = iconSz,
			h = iconSz,
		}
		local keyBoxFrame = {
			x = topRowLeft + iconSz + gap,
			y = pad + (topRowHeight - keyBoxSz) / 2,
			w = keyBoxWidth,
			h = keyBoxSz,
		}
		local keyPrefixFrame = {
			x = keyBoxFrame.x,
			y = keyBoxFrame.y + (keyBoxFrame.h - keyTextHeight) / 2,
			w = 0,
			h = keyTextHeight,
		}
		local keyRestFrame = {
			x = keyBoxFrame.x,
			y = keyBoxFrame.y + (keyBoxFrame.h - keyTextHeight) / 2,
			w = keyBoxFrame.w,
			h = keyTextHeight,
		}
		local titleTextFrame = {
			x = pad,
			y = pad + topRowHeight + rGap,
			w = frame.w - (pad * 2),
			h = titleTextHeight,
		}

		local bgColor = cloneColor(config.bgColor)
		if isOccluded then
			bgColor.alpha = config.occludedBgAlpha
		end
		local curIconAlpha = isOccluded and config.occludedIconAlpha or config.iconAlpha

		local nextIdx = 1
		canvas[nextIdx] = {
			type = "rectangle",
			action = "fill",
			fillColor = bgColor,
			roundedRectRadii = { xRadius = 12, yRadius = 12 },
			frame = { x = 0, y = 0, w = frame.w, h = frame.h },
		}
		nextIdx = nextIdx + 1

		if not isOccluded then
			canvas[nextIdx] = {
				type = "rectangle",
				action = "fill",
				fillColor = cloneColor(config.hintOverlayColor),
				roundedRectRadii = {
					xRadius = config.hintOverlayCornerRadius,
					yRadius = config.hintOverlayCornerRadius,
				},
				frame = { x = 0, y = 0, w = frame.w, h = frame.h },
			}
			nextIdx = nextIdx + 1
			local obw = config.hintOverlayBorderWidth
			canvas[nextIdx] = {
				type = "rectangle",
				action = "stroke",
				strokeColor = cloneColor(config.hintOverlayBorderColor),
				strokeWidth = obw,
				roundedRectRadii = {
					xRadius = config.hintOverlayCornerRadius,
					yRadius = config.hintOverlayCornerRadius,
				},
				frame = { x = obw / 2, y = obw / 2, w = frame.w - obw, h = frame.h - obw },
			}
			nextIdx = nextIdx + 1
		end

		local iconIdx = nextIdx
		canvas[nextIdx] = {
			type = "image",
			image = icon,
			imageScaling = "scaleToFit",
			imageAlpha = curIconAlpha,
			frame = iconFrame,
		}
		nextIdx = nextIdx + 1

		local keyPrefixIdx = nextIdx
		canvas[nextIdx] = {
			type = "text",
			text = "",
			textFont = config.fontName,
			textSize = fSize,
			textColor = config.keyHighlightColor,
			textAlignment = "left",
			textLineBreak = "clip",
			frame = keyPrefixFrame,
		}
		nextIdx = nextIdx + 1

		local keyRestIdx = nextIdx
		canvas[nextIdx] = {
			type = "text",
			text = keyToDisplayText(keyText),
			textFont = config.fontName,
			textSize = fSize,
			textColor = config.textColor,
			textAlignment = "left",
			textLineBreak = "clip",
			frame = keyRestFrame,
		}
		nextIdx = nextIdx + 1

		local titleIdx = nextIdx
		canvas[nextIdx] = {
			type = "text",
			text = titleText or "",
			textFont = config.fontName,
			textSize = tFontSize,
			textColor = config.titleTextColor,
			textAlignment = "left",
			textLineBreak = "truncateTail",
			frame = titleTextFrame,
		}
		nextIdx = nextIdx + 1

		if previewImage and previewHeight and previewHeight > 0 then
			local pPad = math.floor(config.previewPadding * scale)
			local previewY = pad + topRowHeight + rGap + titleTextHeight + pPad
			local previewW = frame.w - (pad * 2)
			canvas[nextIdx] = {
				type = "image",
				image = previewImage,
				imageScaling = "scaleProportionally",
				imageAlignment = "center",
				imageAlpha = isOccluded and config.occludedPreviewAlpha or 0.85,
				frame = {
					x = pad,
					y = previewY,
					w = previewW,
					h = previewHeight,
				},
			}
		end

		canvas:show()
		return canvas, keyBoxFrame, keyTextHeight, iconIdx, keyPrefixIdx, keyRestIdx, titleIdx, fSize
	end

	local function computeHintSize(hint, scale)
		scale = scale or 1
		local iconSz = math.floor(config.iconSize * scale)
		local keyBoxSz = math.floor(config.keyBoxSize * scale)
		local fSize = math.floor(config.fontSize * scale)
		local tFontSize = math.floor(config.titleFontSize * scale)
		local pad = math.floor(config.padding * scale)
		local titleWidth = estimatedTextWidth(hint.titleText, tFontSize, math.floor(120 * scale))
		local keyBoxWidth = keyBoxWidthForText(hint.displayKeyText)
		if scale ~= 1 then
			local textWidth = estimatedKeyTextWidth(hint.displayKeyText, fSize)
			local minWidth = math.floor((config.keyBoxMinWidth or config.keyBoxSize) * scale)
			keyBoxWidth = math.max(minWidth, textWidth + (math.floor(config.keyBoxHorizontalPadding * scale) * 2))
		end
		local topRowWidth = iconSz + math.floor(config.keyGap * scale) + keyBoxWidth
		local contentWidth = math.max(topRowWidth, titleWidth)
		local width = pad * 2 + contentWidth
		local topRowHeight = math.max(iconSz, keyBoxSz)
		local titleRowHeight = tFontSize + 8
		local height = pad * 2 + topRowHeight + math.floor(config.rowGap * scale) + titleRowHeight
		return width, height, keyBoxWidth, scale
	end

	local function placeHint(hint, canvasFrame, previewImage, previewHeight, keyBoxWidth, scale)
		local bundleID = hint.app and hint.app:bundleID() or nil
		local icon = bundleID and hs.image.imageFromAppBundle(bundleID) or nil
		local canvas, keyBoxFrame, keyTextHeight, iconIdx, keyPrefixIdx, keyRestIdx, titleIdx, fSize = newHintCanvas(
			canvasFrame,
			icon,
			hint.keyText,
			hint.titleText,
			keyBoxWidth,
			previewImage,
			previewHeight,
			hint.isOccluded,
			scale
		)
		hint.canvas = canvas
		hint.keyBoxFrame = keyBoxFrame
		hint.keyTextHeight = keyTextHeight
		hint.iconIdx = iconIdx
		hint.keyPrefixIdx = keyPrefixIdx
		hint.keyRestIdx = keyRestIdx
		hint.titleIdx = titleIdx
		hint.effectiveFontSize = fSize
		table.insert(openHints, hint)
		hintByKey[hint.key] = hint
	end

	local function showActiveOverlay()
		local focusedWin = hs.window.focusedWindow()
		if not focusedWin then
			return
		end
		local ok, frame = pcall(function()
			return focusedWin:frame()
		end)
		if not ok or not frame or frame.w == 0 or frame.h == 0 then
			return
		end
		local bw = config.activeOverlayBorderWidth
		local canvas = hs.canvas.new({
			x = frame.x,
			y = frame.y,
			w = frame.w,
			h = frame.h,
		})
		canvas:level(hs.canvas.windowLevels.overlay)
		canvas:behavior({ "canJoinAllSpaces", "stationary", "ignoresCycle" })
		canvas:appendElements({
			type = "rectangle",
			action = "fill",
			fillColor = config.activeOverlayColor,
		})
		canvas:appendElements({
			type = "rectangle",
			action = "stroke",
			frame = { x = bw / 2, y = bw / 2, w = frame.w - bw, h = frame.h - bw },
			strokeColor = config.activeOverlayBorderColor,
			strokeWidth = bw,
			roundedRectRadii = {
				xRadius = config.activeOverlayCornerRadius,
				yRadius = config.activeOverlayCornerRadius,
			},
		})
		canvas:show()
		activeOverlayCanvas = canvas
	end

	local function showHints()
		local entries = collectEntries()
		local hintEntries = buildHintEntries(entries)

		closeHints(false)
		showActiveOverlay()

		if #hintEntries == 0 then
			-- No hints to show; auto-dismiss overlay after a short delay
			hs.timer.doAfter(0.5, function()
				if activeOverlayCanvas then
					activeOverlayCanvas:delete()
					activeOverlayCanvas = nil
				end
			end)
			return
		end

		ensureModal()

		local visibleHints = {}
		local occludedHints = {}
		for _, hint in ipairs(hintEntries) do
			if hint.isOccluded then
				table.insert(occludedHints, hint)
			else
				table.insert(visibleHints, hint)
			end
		end

		-- Place visible (front) hints at uncovered area of window
		local takenRects = {}
		for _, hint in ipairs(visibleHints) do
			local screen = hint.win:screen()
			local windowFrame = hint.win:frame()
			if screen then
				local width, height, keyBoxWidth = computeHintSize(hint)
				local baseCx, baseCy = findUncoveredCenter(windowFrame, hint.coveringFrames)
				local center = nextCenter(
					{ x = baseCx, y = baseCy },
					screen:frame(),
					width,
					height,
					takenRects
				)
				local canvasFrame = {
					x = center.x - (width / 2),
					y = center.y - (height / 2),
					w = width,
					h = height,
				}
				placeHint(hint, canvasFrame, nil, 0, keyBoxWidth)
				table.insert(takenRects, { x = center.x, y = center.y, w = width, h = height })
			end
		end

		-- Place occluded (background) hints in a dock at each screen's bottom
		if #occludedHints > 0 then
			local scale = config.occludedScale or 1
			-- Group by screen and prepare sizes/snapshots
			local screenGroups = {}
			for _, hint in ipairs(occludedHints) do
				local screen = hint.win:screen()
				if screen then
					local screenKey = tostring(screen:id())
					if not screenGroups[screenKey] then
						screenGroups[screenKey] = { screen = screen, items = {} }
					end
					local width, height, keyBoxWidth = computeHintSize(hint, scale)
					local previewImage = nil
					local previewHeight = 0
					if config.showPreviewForOccluded then
						local ok, snapshot = pcall(function()
							return hint.win:snapshot()
						end)
						if ok and snapshot then
							local imgSize = snapshot:size()
							if imgSize and imgSize.w > 0 and imgSize.h > 0 then
								previewImage = snapshot
								local previewW = config.previewWidth
								previewHeight = math.floor(previewW * imgSize.h / imgSize.w)
								local pad = math.floor(config.padding * scale)
								width = math.max(width, pad * 2 + previewW)
								height = height + math.floor(config.previewPadding * scale) + previewHeight
							end
						end
					end
					table.insert(screenGroups[screenKey].items, {
						hint = hint,
						width = width,
						height = height,
						keyBoxWidth = keyBoxWidth,
						previewImage = previewImage,
						previewHeight = previewHeight,
					})
				end
			end

			-- Layout dock per screen
			for _, group in pairs(screenGroups) do
				local screenFrame = group.screen:frame()
				local maxHeight = 0
				local totalWidth = 0
				for i, item in ipairs(group.items) do
					totalWidth = totalWidth + item.width
					if i > 1 then
						totalWidth = totalWidth + config.dockItemGap
					end
					if item.height > maxHeight then
						maxHeight = item.height
					end
				end

				local startX = screenFrame.x + (screenFrame.w - totalWidth) / 2
				local dockY = screenFrame.y + screenFrame.h - maxHeight - config.dockBottomMargin
				local curX = startX

				for _, item in ipairs(group.items) do
					local canvasFrame = {
						x = curX,
						y = dockY + (maxHeight - item.height),
						w = item.width,
						h = item.height,
					}
					placeHint(item.hint, canvasFrame, item.previewImage, item.previewHeight, item.keyBoxWidth, scale)
					curX = curX + item.width + config.dockItemGap
				end
			end
		end

		if #openHints == 0 then
			clearHints()
			return
		end

		isShowing = true
		currentInput = ""
		refreshHighlights()
		modal:enter()
	end

	local function invokeShowHints()
		local ok, err = pcall(showHints)
		if ok then
			return true
		end
		if config.onError then
			config.onError(err)
		end
		return false
	end

	local function teardown()
		if hotkey then
			hotkey:delete()
			hotkey = nil
		end
		closeHints(true)
		if modal then
			modal:delete()
			modal = nil
		end
	end

	hotkey = hs.hotkey.bind(config.hotkeyModifiers, config.hotkeyKey, function()
		invokeShowHints()
	end)

	return {
		show = invokeShowHints,
		teardown = teardown,
	}
end

return M
