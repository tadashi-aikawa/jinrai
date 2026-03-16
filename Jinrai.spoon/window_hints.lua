local M = {}

local function resourcePath(fileName)
	if not hs or not hs.spoons or not hs.spoons.resourcePath then
		error("[jinrai.window_hints] hs.spoons.resourcePath is not available")
	end

	local path = hs.spoons.resourcePath(fileName)
	if not path then
		error("[jinrai.window_hints] failed to resolve Spoon resource: " .. tostring(fileName))
	end
	return path
end

local windowHintsConfig = nil
local function loadWindowHintsConfig()
	if windowHintsConfig == nil then
		windowHintsConfig = dofile(resourcePath("window_hints_config.lua"))
	end
	return windowHintsConfig
end

local function cloneColor(color)
	return {
		red = color.red,
		green = color.green,
		blue = color.blue,
		alpha = color.alpha,
	}
end

local function resolveHintOverlayBorderColor(active, config)
	if not active and config.dimmedHintOverlayBorderColor then
		return config.dimmedHintOverlayBorderColor
	end
	return config.hintOverlayBorderColor
end

local function resolveOffSpaceBadgeColors(active, config)
	local fill = cloneColor(config.offSpaceBadgeFillColor)
	local stroke = cloneColor(config.offSpaceBadgeStrokeColor)
	if not active then
		fill.alpha = config.offSpaceBadgeInactiveFillAlpha
		stroke.alpha = config.offSpaceBadgeInactiveStrokeAlpha
	end
	return fill, stroke
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

local function normalizePrefixChar(value, allowedPrefixes)
	local c = string.upper(string.sub(tostring(value or ""), 1, 1))
	if c == "" or not allowedPrefixes[c] then
		return nil
	end
	return c
end

local function normalizeActionKey(value, optionName)
	if value == nil then
		return nil
	end
	if type(value) ~= "string" then
		error(string.format("[jinrai.window_hints] %s must be a string", optionName))
	end
	if value == "" then
		error(string.format("[jinrai.window_hints] %s must not be empty", optionName))
	end
	return string.lower(value)
end

local function normalizeDirectionKeys(directionKeys)
	if directionKeys == nil then
		return nil
	end
	if type(directionKeys) ~= "table" then
		error("[jinrai.window_hints] directionKeys must be a table")
	end
	return {
		left = normalizeActionKey(directionKeys.left, "directionKeys.left"),
		down = normalizeActionKey(directionKeys.down, "directionKeys.down"),
		up = normalizeActionKey(directionKeys.up, "directionKeys.up"),
		right = normalizeActionKey(directionKeys.right, "directionKeys.right"),
		upLeft = normalizeActionKey(directionKeys.upLeft, "directionKeys.upLeft"),
		upRight = normalizeActionKey(directionKeys.upRight, "directionKeys.upRight"),
		downLeft = normalizeActionKey(directionKeys.downLeft, "directionKeys.downLeft"),
		downRight = normalizeActionKey(directionKeys.downRight, "directionKeys.downRight"),
	}
end

local function normalizeNonNegativeNumber(value, optionName)
	if type(value) ~= "number" or value ~= value then
		error(string.format("[jinrai.window_hints] %s must be a number", optionName))
	end
	if value < 0 then
		error(string.format("[jinrai.window_hints] %s must be >= 0", optionName))
	end
	return value
end

local function normalizeUnitIntervalNumber(value, optionName)
	if type(value) ~= "number" or value ~= value then
		error(string.format("[jinrai.window_hints] %s must be a number", optionName))
	end
	if value < 0 or value > 1 then
		error(string.format("[jinrai.window_hints] %s must be between 0 and 1", optionName))
	end
	return value
end

local ALL_DIRECTIONS = {
	"left",
	"down",
	"up",
	"right",
	"upLeft",
	"upRight",
	"downLeft",
	"downRight",
}

local CARDINAL_DIRECTIONS = {
	left = true,
	down = true,
	up = true,
	right = true,
}

local SELECT_MODIFIER_ORDER = {
	"cmd",
	"alt",
	"ctrl",
	"shift",
	"fn",
}

local SELECT_MODIFIER_LOOKUP = {
	cmd = true,
	alt = true,
	ctrl = true,
	shift = true,
	fn = true,
}

local MODIFIER_ALIAS_LOOKUP = {
	option = "alt",
}

local function normalizeModifierName(modifier)
	local normalized = string.lower(modifier)
	return MODIFIER_ALIAS_LOOKUP[normalized] or normalized
end

local function buildDirectionKeyLookup(directionKeys)
	if not directionKeys then
		return {}
	end
	local lookup = {}
	for _, direction in ipairs(ALL_DIRECTIONS) do
		local key = directionKeys[direction]
		if key then
			local existing = lookup[key]
			if existing and existing ~= direction then
				error("[jinrai.window_hints] directionKeys must not contain duplicate keys")
			end
			lookup[key] = direction
		end
	end
	return lookup
end

local function normalizeDirectDirectionHotkeys(directDirectionHotkeys)
	if directDirectionHotkeys == nil then
		return nil
	end
	if type(directDirectionHotkeys) ~= "table" then
		error("[jinrai.window_hints] directDirectionHotkeys must be a table")
	end

	local keys = directDirectionHotkeys.keys
	if keys ~= nil and type(keys) ~= "table" then
		error("[jinrai.window_hints] directDirectionHotkeys.keys must be a table")
	end
	local directionKeys = normalizeDirectionKeys(keys)
	local directionKeyLookup = buildDirectionKeyLookup(directionKeys)
	if next(directionKeyLookup) == nil then
		return nil
	end

	local modifiers = directDirectionHotkeys.modifiers
	if type(modifiers) ~= "table" then
		error("[jinrai.window_hints] directDirectionHotkeys.modifiers must be an array")
	end
	local maxIndex = 0
	for k, _ in pairs(modifiers) do
		if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
			error("[jinrai.window_hints] directDirectionHotkeys.modifiers must be an array")
		end
		if k > maxIndex then
			maxIndex = k
		end
	end
	for i = 1, maxIndex do
		if modifiers[i] == nil then
			error("[jinrai.window_hints] directDirectionHotkeys.modifiers must be an array")
		end
	end
	if #modifiers == 0 then
		error("[jinrai.window_hints] directDirectionHotkeys.modifiers must not be empty")
	end

	local modifierLookup = {}
	for i, modifier in ipairs(modifiers) do
		if type(modifier) ~= "string" then
			error(string.format("[jinrai.window_hints] directDirectionHotkeys.modifiers[%d] must be a string", i))
		end
		local normalized = normalizeModifierName(modifier)
		if normalized == "" then
			error(string.format("[jinrai.window_hints] directDirectionHotkeys.modifiers[%d] must not be empty", i))
		end
		if not SELECT_MODIFIER_LOOKUP[normalized] then
			error(
				string.format(
					"[jinrai.window_hints] directDirectionHotkeys.modifiers[%d] must be one of cmd/alt/ctrl/shift/fn",
					i
				)
			)
		end
		if modifierLookup[normalized] then
			error("[jinrai.window_hints] directDirectionHotkeys.modifiers must not contain duplicate modifiers")
		end
		modifierLookup[normalized] = true
	end

	local normalizedModifiers = {}
	for _, modifier in ipairs(SELECT_MODIFIER_ORDER) do
		if modifierLookup[modifier] then
			table.insert(normalizedModifiers, modifier)
		end
	end

	return {
		modifiers = normalizedModifiers,
		keys = directionKeys,
		keyLookup = directionKeyLookup,
	}
end

local function buildReservedHintCharLookup(directionKeyLookup, focusBackKey)
	local reserved = {}
	local function addKey(key)
		if key and #key == 1 then
			reserved[string.upper(key)] = true
		end
	end
	for key, _ in pairs(directionKeyLookup or {}) do
		addKey(key)
	end
	addKey(focusBackKey)
	return reserved
end

local function normalizeHintChars(rawHintChars)
	local normalized = {}
	for _, char in ipairs(rawHintChars) do
		table.insert(normalized, string.upper(tostring(char)))
	end
	return normalized
end

local function filterHintChars(hintChars, reservedHintCharLookup)
	local filtered = {}
	for _, char in ipairs(hintChars) do
		if not reservedHintCharLookup[char] then
			table.insert(filtered, char)
		end
	end
	return filtered
end

local function isArrayTable(tbl)
	if type(tbl) ~= "table" then
		return false
	end
	local maxIndex = 0
	for k, _ in pairs(tbl) do
		if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
			return false
		end
		if k > maxIndex then
			maxIndex = k
		end
	end
	for i = 1, maxIndex do
		if tbl[i] == nil then
			return false
		end
	end
	return true
end

local function normalizeSelectModifiers(modifiers)
	if modifiers == nil then
		return nil
	end
	if type(modifiers) ~= "table" or not isArrayTable(modifiers) then
		error("[jinrai.window_hints] swapWindowFrameSelectModifiers must be an array")
	end
	if #modifiers == 0 then
		error("[jinrai.window_hints] swapWindowFrameSelectModifiers must not be empty")
	end

	local lookup = {}
	for i, modifier in ipairs(modifiers) do
		if type(modifier) ~= "string" then
			error(string.format("[jinrai.window_hints] swapWindowFrameSelectModifiers[%d] must be a string", i))
		end
		local normalized = normalizeModifierName(modifier)
		if normalized == "" then
			error(string.format("[jinrai.window_hints] swapWindowFrameSelectModifiers[%d] must not be empty", i))
		end
		if not SELECT_MODIFIER_LOOKUP[normalized] then
			error(
				string.format(
					"[jinrai.window_hints] swapWindowFrameSelectModifiers[%d] must be one of cmd/alt/ctrl/shift/fn",
					i
				)
			)
		end
		if lookup[normalized] then
			error("[jinrai.window_hints] swapWindowFrameSelectModifiers must not contain duplicate modifiers")
		end
		lookup[normalized] = true
	end

	local normalized = {}
	for _, modifier in ipairs(SELECT_MODIFIER_ORDER) do
		if lookup[modifier] then
			table.insert(normalized, modifier)
		end
	end
	return normalized
end

local function modifierListKey(modifiers)
	if not modifiers then
		return ""
	end
	return table.concat(modifiers, "+")
end

local function shouldSwapWindowFrameOnSelect(swapModifiers, inputModifiers)
	if not swapModifiers or not inputModifiers then
		return false
	end
	return modifierListKey(swapModifiers) == modifierListKey(inputModifiers)
end

local function collectModalInputModifiers(key, swapModifiers)
	local modifierBindings = {}
	local function addModifierBinding(modifiers)
		modifierBindings[modifierListKey(modifiers)] = modifiers
	end
	addModifierBinding({})
	if #key == 1 then
		addModifierBinding({ "shift" })
	end
	if swapModifiers then
		addModifierBinding(swapModifiers)
	end
	local bindings = {}
	for _, modifiers in pairs(modifierBindings) do
		table.insert(bindings, modifiers)
	end
	table.sort(bindings, function(a, b)
		return modifierListKey(a) < modifierListKey(b)
	end)
	return bindings
end

local function cloneFrameRect(frame)
	if not frame then
		return nil
	end
	if frame.x == nil or frame.y == nil or frame.w == nil or frame.h == nil then
		return nil
	end
	return {
		x = frame.x,
		y = frame.y,
		w = frame.w,
		h = frame.h,
	}
end

local function hasFrameSetter(win)
	return win and (win.setFrameWithWorkarounds or win.setFrame)
end

local function applyWindowFrame(win, nextFrame)
	if win.setFrameWithWorkarounds then
		local ok = pcall(function()
			win:setFrameWithWorkarounds(nextFrame, 0)
		end)
		if ok then
			return true
		end
	end
	if win.setFrame then
		local ok = pcall(function()
			win:setFrame(nextFrame, 0)
		end)
		if ok then
			return true
		end
	end
	return false
end

local function swapWindowFrames(currentWin, targetWin)
	if not currentWin or not targetWin then
		return false
	end
	if currentWin == targetWin then
		return false
	end
	if
		not currentWin.frame
		or not targetWin.frame
		or not hasFrameSetter(currentWin)
		or not hasFrameSetter(targetWin)
	then
		return false
	end

	local currentID = currentWin.id and currentWin:id() or nil
	local targetID = targetWin.id and targetWin:id() or nil
	if currentID ~= nil and targetID ~= nil and currentID == targetID then
		return false
	end

	local currentFrame = currentWin:frame()
	local targetFrame = targetWin:frame()
	local nextCurrentFrame = cloneFrameRect(targetFrame)
	local nextTargetFrame = cloneFrameRect(currentFrame)
	if not nextCurrentFrame or not nextTargetFrame then
		return false
	end

	if not applyWindowFrame(currentWin, nextCurrentFrame) then
		return false
	end
	if not applyWindowFrame(targetWin, nextTargetFrame) then
		-- best effort rollback
		applyWindowFrame(currentWin, nextTargetFrame)
		return false
	end
	return true
end

local function resolveFocusBackTargetWindow(focusHistory, swapWithFocused)
	if not focusHistory then
		return nil, false
	end
	if swapWithFocused and focusHistory.getPreviousWindow then
		local previousWin = focusHistory:getPreviousWindow()
		if previousWin then
			return previousWin, true
		end
	end
	if focusHistory.focusBack then
		local win = focusHistory:focusBack()
		if win then
			return win, false
		end
	end
	return nil, false
end

local LUA_PATTERN_MAGIC_CHARS = {
	["^"] = true,
	["$"] = true,
	["("] = true,
	[")"] = true,
	["%"] = true,
	["."] = true,
	["["] = true,
	["]"] = true,
	["*"] = true,
	["+"] = true,
	["-"] = true,
	["?"] = true,
}

local function globToLuaPattern(glob)
	local parts = { "^" }
	for i = 1, #glob do
		local ch = string.sub(glob, i, i)
		if ch == "*" then
			table.insert(parts, ".*")
		elseif ch == "?" then
			table.insert(parts, ".")
		elseif LUA_PATTERN_MAGIC_CHARS[ch] then
			table.insert(parts, "%" .. ch)
		else
			table.insert(parts, ch)
		end
	end
	table.insert(parts, "$")
	return table.concat(parts)
end

local function normalizeOverridePrefix(prefix, allowedPrefixes)
	if type(prefix) ~= "string" then
		return nil
	end
	local upper = string.upper(prefix)
	if #upper < 1 or #upper > 2 then
		return nil
	end
	for i = 1, #upper do
		local ch = string.sub(upper, i, i)
		if not allowedPrefixes[ch] then
			return nil
		end
	end
	return upper
end

local function compileAppPrefixOverrides(appPrefixOverrides, allowedPrefixes)
	if appPrefixOverrides == nil then
		return nil
	end
	if type(appPrefixOverrides) ~= "table" then
		error("[jinrai.window_hints] appPrefixOverrides must be an array of rule objects")
	end
	if not isArrayTable(appPrefixOverrides) then
		error("[jinrai.window_hints] appPrefixOverrides map format is no longer supported; use array rules")
	end

	local compiled = {}
	for i, rule in ipairs(appPrefixOverrides) do
		if type(rule) ~= "table" then
			error(string.format("[jinrai.window_hints] appPrefixOverrides[%d] must be a table", i))
		end
		if type(rule.match) ~= "table" then
			error(string.format("[jinrai.window_hints] appPrefixOverrides[%d].match must be a table", i))
		end
		local match = rule.match
		local bundleID = match.bundleID
		local titleGlob = match.titleGlob
		if bundleID == nil and titleGlob == nil then
			error(string.format("[jinrai.window_hints] appPrefixOverrides[%d].match requires bundleID or titleGlob", i))
		end
		if bundleID ~= nil and type(bundleID) ~= "string" then
			error(string.format("[jinrai.window_hints] appPrefixOverrides[%d].match.bundleID must be a string", i))
		end
		if titleGlob ~= nil and type(titleGlob) ~= "string" then
			error(string.format("[jinrai.window_hints] appPrefixOverrides[%d].match.titleGlob must be a string", i))
		end

		local prefix = normalizeOverridePrefix(rule.prefix, allowedPrefixes)
		if not prefix then
			error(
				string.format(
					"[jinrai.window_hints] appPrefixOverrides[%d].prefix must be 1 or 2 chars from hintChars",
					i
				)
			)
		end

		table.insert(compiled, {
			bundleID = bundleID,
			titlePattern = titleGlob and globToLuaPattern(titleGlob) or nil,
			prefix = prefix,
		})
	end

	return compiled
end

local function resolveAppPrefixFromOverride(bundleID, windowTitle, compiledOverrides)
	if type(compiledOverrides) == "table" then
		for _, rule in ipairs(compiledOverrides) do
			local bundleMatched = (rule.bundleID == nil) or (rule.bundleID == bundleID)
			if bundleMatched then
				local titleMatched = (rule.titlePattern == nil)
					or (string.match(windowTitle or "", rule.titlePattern) ~= nil)
				if titleMatched then
					return rule.prefix, true
				end
			end
		end
	end
	return nil, false
end

local function resolveAppPrefix(appTitle, bundleID, windowTitle, fallback, allowedPrefixes, compiledOverrides)
	local overridePrefix, overridden = resolveAppPrefixFromOverride(bundleID, windowTitle, compiledOverrides)
	if overridePrefix then
		return overridePrefix, overridden
	end
	local titlePrefix = normalizePrefixChar(appTitle, allowedPrefixes)
	if titlePrefix then
		return titlePrefix, false
	end
	return fallback, false
end

local function collectAppPrefixCandidates(appTitle, basePrefix, allowedPrefixes)
	local candidates = {}
	local seen = {}
	local function add(prefix)
		if prefix and not seen[prefix] then
			seen[prefix] = true
			table.insert(candidates, prefix)
		end
	end

	add(basePrefix)
	for i = 1, #appTitle do
		add(normalizePrefixChar(string.sub(appTitle, i, i), allowedPrefixes))
	end
	return candidates
end

local function assignUniquePrefixes(entries, fallbackPrefix, allowedPrefixes)
	local used = {}
	local appPrefixMap = {}
	for _, entry in ipairs(entries) do
		local appKey = entry.appKey
		if entry.isOverridePrefix then
			local chosen = entry.basePrefix or fallbackPrefix
			used[chosen] = true
			entry.prefix = chosen
		else
			local existing = appPrefixMap[appKey]
			if existing then
				entry.prefix = existing
			else
				local chosen = entry.basePrefix or fallbackPrefix
				local candidates = collectAppPrefixCandidates(entry.appTitle or "", chosen, allowedPrefixes)
				for _, candidate in ipairs(candidates) do
					if not used[candidate] then
						chosen = candidate
						break
					end
				end
				appPrefixMap[appKey] = chosen
				used[chosen] = true
				entry.prefix = chosen
			end
		end
	end
end

local function comparePrefixes(a, b, hintCharOrder)
	if a == b then
		return false
	end
	local maxLen = math.max(#a, #b)
	for i = 1, maxLen do
		local ac = string.sub(a, i, i)
		local bc = string.sub(b, i, i)
		if ac ~= bc then
			if ac == "" then
				return true
			end
			if bc == "" then
				return false
			end
			local ai = hintCharOrder[ac]
			local bi = hintCharOrder[bc]
			if ai and bi and ai ~= bi then
				return ai < bi
			end
			return ac < bc
		end
	end
	return #a < #b
end

local function hintKeyForGroup(prefix, groupSize, index, hintChars)
	if groupSize == 1 then
		return prefix
	end
	return prefix .. keySuffixFor(index - 1, hintChars)
end

local keyToDisplayText

local function isStrictPrefix(a, b)
	return #a < #b and startsWith(b, a)
end

local function keysConflict(a, b)
	return a == b or isStrictPrefix(a, b) or isStrictPrefix(b, a)
end

local function findExpandedKey(baseKey, otherKeys, hintChars)
	local index = 0
	while true do
		local candidate = baseKey .. keySuffixFor(index, hintChars)
		local conflicted = false
		for _, key in ipairs(otherKeys) do
			if keysConflict(candidate, key) then
				conflicted = true
				break
			end
		end
		if not conflicted then
			return candidate
		end
		index = index + 1
	end
end

local function makeKeysPrefixFree(hints, hintChars, hintCharOrder)
	local maxIterations = math.max(1, #hints * 32)
	for _ = 1, maxIterations do
		local changed = false
		for i = 1, #hints do
			local key = hints[i].key
			local hasConflict = false
			for j = 1, #hints do
				if i ~= j and isStrictPrefix(key, hints[j].key) then
					hasConflict = true
					break
				end
			end
			if hasConflict then
				local otherKeys = {}
				for j = 1, #hints do
					if i ~= j then
						table.insert(otherKeys, hints[j].key)
					end
				end
				local expanded = findExpandedKey(key, otherKeys, hintChars)
				hints[i].key = expanded
				hints[i].keyText = expanded
				hints[i].displayKeyText = keyToDisplayText(expanded)
				changed = true
			end
		end
		if not changed then
			table.sort(hints, function(a, b)
				if a.key ~= b.key then
					return comparePrefixes(a.key, b.key, hintCharOrder)
				end
				return false
			end)
			return
		end
	end
	error("[jinrai.window_hints] failed to resolve key prefix conflicts")
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

local function resolveOccludedDockItemX(screenFrame, itemWidth, centeredX, windowCenterX, minimumX, windowXBlend)
	windowXBlend = windowXBlend or 0
	local desiredX = centeredX
	if windowXBlend > 0 and type(windowCenterX) == "number" and windowCenterX == windowCenterX then
		local targetX = windowCenterX - (itemWidth / 2)
		desiredX = centeredX + (targetX - centeredX) * windowXBlend
	end
	local maxX = screenFrame.x + screenFrame.w - itemWidth
	return clamp(math.max(minimumX, desiredX), screenFrame.x, maxX)
end

local function resolveOccludedDockItemXs(screenFrame, items, itemGap, windowXBlend)
	if not items or #items == 0 then
		return {}
	end

	itemGap = itemGap or 0
	windowXBlend = windowXBlend or 0

	local screenRight = screenFrame.x + screenFrame.w
	local desiredXs = {}
	local offsets = {}
	local blocks = {}

	for i, item in ipairs(items) do
		local desiredX = item.centeredX
		if windowXBlend > 0 and type(item.windowCenterX) == "number" and item.windowCenterX == item.windowCenterX then
			local targetX = item.windowCenterX - (item.width / 2)
			desiredX = item.centeredX + (targetX - item.centeredX) * windowXBlend
		end
		local maxX = screenRight - item.width
		desiredX = clamp(desiredX, screenFrame.x, maxX)
		desiredXs[i] = desiredX
	end

	local runningOffset = 0
	for i, item in ipairs(items) do
		offsets[i] = runningOffset
		local z = desiredXs[i] - runningOffset
		table.insert(blocks, {
			startIndex = i,
			endIndex = i,
			sum = z,
			count = 1,
			mean = z,
		})
		while #blocks >= 2 and blocks[#blocks - 1].mean > blocks[#blocks].mean do
			local b2 = table.remove(blocks)
			local b1 = blocks[#blocks]
			b1.endIndex = b2.endIndex
			b1.sum = b1.sum + b2.sum
			b1.count = b1.count + b2.count
			b1.mean = b1.sum / b1.count
		end
		runningOffset = runningOffset + item.width + itemGap
	end

	local xs = {}
	for _, block in ipairs(blocks) do
		for i = block.startIndex, block.endIndex do
			xs[i] = block.mean + offsets[i]
		end
	end

	local lowerShift = -math.huge
	local upperShift = math.huge
	for i, item in ipairs(items) do
		lowerShift = math.max(lowerShift, screenFrame.x - xs[i])
		upperShift = math.min(upperShift, (screenRight - item.width) - xs[i])
	end

	if lowerShift <= upperShift then
		local shift = clamp(0, lowerShift, upperShift)
		for i = 1, #xs do
			xs[i] = xs[i] + shift
		end
		return xs
	end

	local fallbackXs = {}
	local curX = windowXBlend > 0 and screenFrame.x or items[1].centeredX
	for i, item in ipairs(items) do
		local x = resolveOccludedDockItemX(
			screenFrame,
			item.width,
			item.centeredX,
			item.windowCenterX,
			curX,
			windowXBlend
		)
		fallbackXs[i] = x
		curX = x + item.width + itemGap
	end
	return fallbackXs
end

local function resolveOccludedDockItemY(screenFrame, itemHeight, centeredY, windowCenterY, windowYBlend, dockMargin)
	windowYBlend = windowYBlend or 0
	dockMargin = dockMargin or 0
	local desiredY = centeredY
	if windowYBlend > 0 and type(windowCenterY) == "number" and windowCenterY == windowCenterY then
		local screenCenterY = screenFrame.y + (screenFrame.h / 2)
		local targetY = centeredY
		if windowCenterY < screenCenterY then
			targetY = screenFrame.y + dockMargin
		end
		desiredY = centeredY + (targetY - centeredY) * windowYBlend
	end
	local maxY = screenFrame.y + screenFrame.h - itemHeight
	return clamp(desiredY, screenFrame.y, maxY)
end

local function resolveOccludedDockStartX(screenFrame, totalWidth)
	return screenFrame.x + (screenFrame.w - totalWidth) / 2
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
			width = width + (fontSize * 0.68)
		end
	end
	return math.floor(width)
end

local function isPointInRect(px, py, rect)
	return px >= rect.x and px <= rect.x + rect.w and py >= rect.y and py <= rect.y + rect.h
end

local function computeOcclusionSamplingGrid(windowFrame, config)
	if not config.occlusionSamplingEnabled then
		return 4, 4
	end

	local baseWidth = math.max(1, config.occlusionSamplingBaseWidth or 1920)
	local baseHeight = math.max(1, config.occlusionSamplingBaseHeight or 1080)
	local minCols = math.max(1, config.occlusionSamplingMinCols or 4)
	local minRows = math.max(1, config.occlusionSamplingMinRows or 4)
	local maxCols = math.max(minCols, config.occlusionSamplingMaxCols or 8)
	local maxRows = math.max(minRows, config.occlusionSamplingMaxRows or 8)

	local cols = clamp(math.floor((minCols * windowFrame.w / baseWidth) + 0.5), minCols, maxCols)
	local rows = clamp(math.floor((minRows * windowFrame.h / baseHeight) + 0.5), minRows, maxRows)
	return cols, rows
end

local function isWindowOccluded(targetFrame, coveringFrames, cols, rows)
	local sampleCols = math.max(1, cols or 4)
	local sampleRows = math.max(1, rows or 4)
	for row = 0, sampleRows - 1 do
		for col = 0, sampleCols - 1 do
			local px = targetFrame.x + targetFrame.w * (col + 0.5) / sampleCols
			local py = targetFrame.y + targetFrame.h * (row + 0.5) / sampleRows
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

local function windowFrameOf(win)
	if not win or not win.frame then
		return nil
	end
	local ok, frame = pcall(function()
		return win:frame()
	end)
	if not ok or not frame or frame.w <= 0 or frame.h <= 0 then
		return nil
	end
	return frame
end

local function windowIdOf(win)
	if not win or not win.id then
		return nil
	end
	local ok, id = pcall(function()
		return win:id()
	end)
	if not ok then
		return nil
	end
	return id
end

local function isStandardWindow(win)
	if not win or not win.isStandard then
		return false
	end
	local ok, standard = pcall(function()
		return win:isStandard()
	end)
	return ok and standard
end

local function buildWindowIdLookup(wins)
	local lookup = {}
	if type(wins) ~= "table" then
		return lookup
	end
	for _, win in ipairs(wins) do
		local id = windowIdOf(win)
		if id ~= nil then
			lookup[id] = true
		end
	end
	return lookup
end

local function mergeUniqueWindows(primaryWins, secondaryWins)
	local merged = {}
	local seen = {}
	local function appendWins(wins)
		if type(wins) ~= "table" then
			return
		end
		for _, win in ipairs(wins) do
			local id = windowIdOf(win)
			if id ~= nil then
				if not seen[id] then
					seen[id] = true
					table.insert(merged, win)
				end
			else
				table.insert(merged, win)
			end
		end
	end
	appendWins(primaryWins)
	appendWins(secondaryWins)
	return merged
end

local function currentSpaceVisibleWindows()
	if not hs or not hs.window or not hs.window.visibleWindows then
		return {}
	end
	local ok, wins = pcall(function()
		return hs.window.visibleWindows()
	end)
	if not ok or type(wins) ~= "table" then
		return {}
	end
	return wins
end

local function allSpaceVisibleWindows()
	if not hs or not hs.window or not hs.window.filter or not hs.window.filter.new then
		return currentSpaceVisibleWindows()
	end
	local ok, filter = pcall(function()
		return hs.window.filter.new()
	end)
	if not ok or not filter or not filter.getWindows then
		return currentSpaceVisibleWindows()
	end
	local getOk, wins = pcall(function()
		return filter:getWindows()
	end)
	if not getOk or type(wins) ~= "table" then
		return currentSpaceVisibleWindows()
	end
	return mergeUniqueWindows(currentSpaceVisibleWindows(), wins)
end

local function collectCandidateWindows(includeOtherSpaces)
	local currentWins = currentSpaceVisibleWindows()
	local currentLookup = buildWindowIdLookup(currentWins)
	if includeOtherSpaces then
		return allSpaceVisibleWindows(), currentLookup
	end
	return currentWins, currentLookup
end

local function splitCandidatesByCurrentSpace(candidateWins, currentSpaceLookup)
	local currentSpaceWins = {}
	local otherSpaceWins = {}
	for _, win in ipairs(candidateWins or {}) do
		local id = windowIdOf(win)
		if id ~= nil and currentSpaceLookup[id] then
			table.insert(currentSpaceWins, win)
		else
			table.insert(otherSpaceWins, win)
		end
	end
	return currentSpaceWins, otherSpaceWins
end

local function debugLogDirectional(config, message)
	if not config or not config.debugDirectionalNavigation then
		return
	end
	local line = "[jinrai.window_hints][direction] " .. message
	if hs and hs.printf then
		hs.printf("%s", line)
		return
	end
	print(line)
end

local function frameToDebugString(frame)
	if not frame then
		return "nil"
	end
	return string.format("{x=%.1f,y=%.1f,w=%.1f,h=%.1f}", frame.x, frame.y, frame.w, frame.h)
end

local function windowIdsToDebugString(wins)
	if type(wins) ~= "table" then
		return "[]"
	end
	local ids = {}
	for _, win in ipairs(wins) do
		local id = windowIdOf(win)
		table.insert(ids, tostring(id))
	end
	return "[" .. table.concat(ids, ",") .. "]"
end

local function centerOfFrame(frame)
	return {
		x = frame.x + frame.w / 2,
		y = frame.y + frame.h / 2,
	}
end

local function isDirectionalCandidate(direction, fromCenter, toCenter)
	if direction == "left" then
		return toCenter.x < fromCenter.x
	end
	if direction == "right" then
		return toCenter.x > fromCenter.x
	end
	if direction == "up" then
		return toCenter.y < fromCenter.y
	end
	if direction == "down" then
		return toCenter.y > fromCenter.y
	end
	if direction == "upLeft" then
		return toCenter.x < fromCenter.x and toCenter.y < fromCenter.y
	end
	if direction == "upRight" then
		return toCenter.x > fromCenter.x and toCenter.y < fromCenter.y
	end
	if direction == "downLeft" then
		return toCenter.x < fromCenter.x and toCenter.y > fromCenter.y
	end
	if direction == "downRight" then
		return toCenter.x > fromCenter.x and toCenter.y > fromCenter.y
	end
	return false
end

local function directionalPrimaryGap(direction, fromFrame, toFrame)
	if direction == "left" then
		return math.max(0, fromFrame.x - (toFrame.x + toFrame.w))
	end
	if direction == "right" then
		return math.max(0, toFrame.x - (fromFrame.x + fromFrame.w))
	end
	if direction == "up" then
		return math.max(0, fromFrame.y - (toFrame.y + toFrame.h))
	end
	if direction == "down" then
		return math.max(0, toFrame.y - (fromFrame.y + fromFrame.h))
	end
	return math.huge
end

local function diagonalAxisGaps(direction, fromFrame, toFrame)
	if direction == "upLeft" then
		local xGap = math.max(0, fromFrame.x - (toFrame.x + toFrame.w))
		local yGap = math.max(0, fromFrame.y - (toFrame.y + toFrame.h))
		return xGap, yGap
	end
	if direction == "upRight" then
		local xGap = math.max(0, toFrame.x - (fromFrame.x + fromFrame.w))
		local yGap = math.max(0, fromFrame.y - (toFrame.y + toFrame.h))
		return xGap, yGap
	end
	if direction == "downLeft" then
		local xGap = math.max(0, fromFrame.x - (toFrame.x + toFrame.w))
		local yGap = math.max(0, toFrame.y - (fromFrame.y + fromFrame.h))
		return xGap, yGap
	end
	if direction == "downRight" then
		local xGap = math.max(0, toFrame.x - (fromFrame.x + fromFrame.w))
		local yGap = math.max(0, toFrame.y - (fromFrame.y + fromFrame.h))
		return xGap, yGap
	end
	return math.huge, math.huge
end

local function rangeOverlap(aStart, aEnd, bStart, bEnd)
	return math.max(0, math.min(aEnd, bEnd) - math.max(aStart, bStart))
end

local function orthogonalOverlap(direction, fromFrame, toFrame)
	if direction == "left" or direction == "right" then
		return rangeOverlap(fromFrame.y, fromFrame.y + fromFrame.h, toFrame.y, toFrame.y + toFrame.h)
	end
	return rangeOverlap(fromFrame.x, fromFrame.x + fromFrame.w, toFrame.x, toFrame.x + toFrame.w)
end

local function secondaryAxisDelta(direction, fromCenter, toCenter)
	if direction == "left" or direction == "right" then
		return math.abs(toCenter.y - fromCenter.y)
	end
	return math.abs(toCenter.x - fromCenter.x)
end

local function compareWindowIds(a, b)
	if a == b then
		return false
	end
	if type(a) == "number" and type(b) == "number" then
		return a < b
	end
	return tostring(a) < tostring(b)
end

local function buildWindowZOrderIndex(orderedWins)
	local lookup = {}
	if type(orderedWins) ~= "table" then
		return lookup
	end
	for i, win in ipairs(orderedWins) do
		local id = windowIdOf(win)
		if id ~= nil and lookup[id] == nil then
			lookup[id] = i
		end
	end
	return lookup
end

local function collectCoveringFramesBeforeWindow(orderedWins, targetWindowId)
	local frames = {}
	if type(orderedWins) ~= "table" then
		return frames
	end
	for _, win in ipairs(orderedWins) do
		local winId = windowIdOf(win)
		if winId == targetWindowId then
			break
		end
		local frame = windowFrameOf(win)
		if frame then
			table.insert(frames, frame)
		end
	end
	return frames
end

local function isFullyOccludedWindow(win, orderedWins, config)
	local winId = windowIdOf(win)
	if winId == nil then
		return false
	end
	local frame = windowFrameOf(win)
	if not frame then
		return false
	end
	local coveringFrames = collectCoveringFramesBeforeWindow(orderedWins, winId)
	if #coveringFrames == 0 then
		return false
	end
	local sampleCols, sampleRows = computeOcclusionSamplingGrid(frame, config or {})
	return isWindowOccluded(frame, coveringFrames, sampleCols, sampleRows)
end

local function filterDirectionalCandidatesByOcclusion(candidateWins, orderedWins, config)
	local filtered = {}
	for _, win in ipairs(candidateWins) do
		if not isFullyOccludedWindow(win, orderedWins, config) then
			table.insert(filtered, win)
		end
	end
	return filtered
end

local function findDirectionalWindowTarget(currentWin, candidateWins, direction, previousWin, orderedWins, config)
	local currentFrame = windowFrameOf(currentWin)
	if not currentFrame then
		debugLogDirectional(config, "focused window has no valid frame")
		return nil
	end
	local currentId = windowIdOf(currentWin)
	local previousId = windowIdOf(previousWin)
	local currentCenter = centerOfFrame(currentFrame)
	local zOrderLookup = buildWindowZOrderIndex(orderedWins)
	local best = nil
	local SCORE_EPSILON = 0.0001
	local overlapTieThresholdPx = 0
	if config and type(config.cardinalOverlapTieThresholdPx) == "number" then
		overlapTieThresholdPx = config.cardinalOverlapTieThresholdPx
	end
	debugLogDirectional(
		config,
		string.format(
			"start direction=%s current=%s currentFrame=%s previous=%s candidates=%s ordered=%s overlapTieThresholdPx=%.3f",
			tostring(direction),
			tostring(currentId),
			frameToDebugString(currentFrame),
			tostring(previousId),
			windowIdsToDebugString(candidateWins),
			windowIdsToDebugString(orderedWins),
			overlapTieThresholdPx
		)
	)

	for _, win in ipairs(candidateWins) do
		local winId = windowIdOf(win)
		if winId ~= nil and winId ~= currentId then
			local frame = windowFrameOf(win)
			if frame then
				local center = centerOfFrame(frame)
				if isDirectionalCandidate(direction, currentCenter, center) then
					local primaryGap = directionalPrimaryGap(direction, currentFrame, frame)
					local secondary = secondaryAxisDelta(direction, currentCenter, center)
					local isPrevious = previousId ~= nil and winId == previousId
					local candidate = {
						win = win,
						id = winId,
						zOrder = zOrderLookup[winId] or math.huge,
						isPrevious = isPrevious,
					}
					if CARDINAL_DIRECTIONS[direction] then
						candidate.primaryGap = primaryGap
						candidate.orthogonalOverlap = orthogonalOverlap(direction, currentFrame, frame)
						candidate.secondary = secondary
						debugLogDirectional(
							config,
							string.format(
								"candidate id=%s frame=%s overlap=%.3f primaryGap=%.3f secondary=%.3f zOrder=%s isPrevious=%s",
								tostring(winId),
								frameToDebugString(frame),
								candidate.orthogonalOverlap,
								candidate.primaryGap,
								candidate.secondary,
								tostring(candidate.zOrder),
								tostring(candidate.isPrevious)
							)
						)
					else
						local xGap, yGap = diagonalAxisGaps(direction, currentFrame, frame)
						local dx = center.x - currentCenter.x
						local dy = center.y - currentCenter.y
						candidate.diagonalGap = xGap + yGap
						candidate.distance2 = dx * dx + dy * dy
						debugLogDirectional(
							config,
							string.format(
								"candidate id=%s frame=%s diagonalGap=%.3f distance2=%.3f zOrder=%s isPrevious=%s",
								tostring(winId),
								frameToDebugString(frame),
								candidate.diagonalGap,
								candidate.distance2,
								tostring(candidate.zOrder),
								tostring(candidate.isPrevious)
							)
						)
					end

					if not best then
						best = candidate
						debugLogDirectional(config, string.format("best <- %s (first)", tostring(candidate.id)))
					else
						local better = false
						if CARDINAL_DIRECTIONS[direction] then
							local overlapDiff = candidate.orthogonalOverlap - best.orthogonalOverlap
							local overlapTie = math.abs(overlapDiff) <= (overlapTieThresholdPx + SCORE_EPSILON)
							if not overlapTie and math.abs(overlapDiff) > SCORE_EPSILON then
								better = overlapDiff > 0
							elseif candidate.primaryGap < (best.primaryGap - SCORE_EPSILON) then
								better = true
							elseif math.abs(candidate.primaryGap - best.primaryGap) <= SCORE_EPSILON then
								if candidate.zOrder ~= best.zOrder then
									better = candidate.zOrder < best.zOrder
								elseif candidate.secondary ~= best.secondary then
									better = candidate.secondary < best.secondary
								elseif candidate.isPrevious ~= best.isPrevious then
									better = candidate.isPrevious
								else
									better = compareWindowIds(candidate.id, best.id)
								end
							end
						else
							if candidate.diagonalGap < (best.diagonalGap - SCORE_EPSILON) then
								better = true
							elseif math.abs(candidate.diagonalGap - best.diagonalGap) <= SCORE_EPSILON then
								if candidate.zOrder ~= best.zOrder then
									better = candidate.zOrder < best.zOrder
								elseif candidate.distance2 < (best.distance2 - SCORE_EPSILON) then
									better = true
								elseif math.abs(candidate.distance2 - best.distance2) <= SCORE_EPSILON then
									if candidate.isPrevious ~= best.isPrevious then
										better = candidate.isPrevious
									else
										better = compareWindowIds(candidate.id, best.id)
									end
								end
							end
						end

						if better then
							best = candidate
							debugLogDirectional(config, string.format("best <- %s (better)", tostring(candidate.id)))
						end
					end
				else
					debugLogDirectional(
						config,
						string.format(
							"candidate id=%s frame=%s skipped (outside %s)",
							tostring(winId),
							frameToDebugString(frame),
							tostring(direction)
						)
					)
				end
			else
				debugLogDirectional(config, string.format("candidate id=%s skipped (no valid frame)", tostring(winId)))
			end
		end
	end

	debugLogDirectional(config, string.format("result target=%s", tostring(best and best.id or nil)))
	return best and best.win or nil
end

local function rawPrefixLenToDisplayLen(prefixLen)
	if prefixLen <= 0 then
		return 0
	end
	return prefixLen * 2 - 1
end

keyToDisplayText = function(key)
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
	local config = loadWindowHintsConfig().build(options)
	local focusHistory = config.focusHistory
	local directionKeys = config.directionKeys
	local directionKeyLookup = config.directionKeyLookup or buildDirectionKeyLookup(directionKeys)
	local directDirectionHotkeys = config.directDirectionHotkeys
	local focusBackKey = config.focusBackKey
	local swapWindowFrameSelectModifiers = config.swapWindowFrameSelectModifiers
	local hintChars = config.hintChars

	local hotkey = nil
	local directDirectionBindings = {}
	local keyBlocker = nil
	local openHints = {}
	local hintByKey = {}
	local hintCharByInputKey = {}
	local currentInput = ""
	local isShowing = false
	local activeOverlayCanvas = nil
	local allowedPrefixes = {}
	local hintCharOrder = {}
	for i, char in ipairs(hintChars) do
		allowedPrefixes[char] = true
		hintCharOrder[char] = i
		hintCharByInputKey[string.lower(char)] = char
	end
	local appPrefixOverrides = compileAppPrefixOverrides(config.appPrefixOverrides, allowedPrefixes)

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
		if hint.isOffSpace then
			local badgeFillColor, badgeStrokeColor = resolveOffSpaceBadgeColors(active, config)
			if hint.offSpaceBadgeFillIdx then
				hint.canvas[hint.offSpaceBadgeFillIdx].fillColor = badgeFillColor
			end
			if hint.offSpaceBadgeStrokeIdx then
				hint.canvas[hint.offSpaceBadgeStrokeIdx].strokeColor = badgeStrokeColor
			end
		end
		if hint.overlayBorderIdx then
			hint.canvas[hint.overlayBorderIdx].strokeColor = cloneColor(resolveHintOverlayBorderColor(active, config))
		end
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

	local function closeHints(stopKeyBlocker)
		if isShowing and stopKeyBlocker and keyBlocker then
			keyBlocker:stop()
		end
		isShowing = false
		clearHints()
	end

	local function selectWindow(win, opts)
		if not win then
			return
		end
		opts = opts or {}
		if opts.swapWithFocused then
			swapWindowFrames(hs.window.focusedWindow(), win)
		end
		win:focus()
		if config.centerCursor then
			local frame = win:frame()
			hs.mouse.absolutePosition({ x = frame.x + frame.w / 2, y = frame.y + frame.h / 2 })
		end
		if config.onSelect then
			config.onSelect(win)
		end
		closeHints(true)
	end

	local function runFocusBackAction(swapWithFocused)
		local win, shouldSwapWithFocused = resolveFocusBackTargetWindow(focusHistory, swapWithFocused)
		if not win then
			return false
		end
		if shouldSwapWithFocused then
			selectWindow(win, { swapWithFocused = true })
			return true
		end
		if not focusHistory or not focusHistory.focusBack then
			return false
		end
		if config.centerCursor then
			local frame = win:frame()
			hs.mouse.absolutePosition({ x = frame.x + frame.w / 2, y = frame.y + frame.h / 2 })
		end
		if config.onSelect then
			config.onSelect(win)
		end
		closeHints(true)
		return true
	end

	local function resolvePreviousWindowForDirection()
		if focusHistory and focusHistory.getPreviousWindow then
			return focusHistory:getPreviousWindow()
		end
		local ordered = hs.window.orderedWindows()
		if type(ordered) == "table" and #ordered >= 2 then
			return ordered[2]
		end
		return nil
	end

	local function runDirectionalAction(direction, swapWithFocused)
		local focusedWin = hs.window.focusedWindow()
		if not focusedWin then
			debugLogDirectional(config, string.format("direction=%s skipped (no focused window)", tostring(direction)))
			return false
		end
		local orderedWins = hs.window.orderedWindows()
		local candidates = {}
		for _, win in ipairs(hs.window.visibleWindows()) do
			if isStandardWindow(win) then
				table.insert(candidates, win)
			end
		end
		debugLogDirectional(
			config,
			string.format(
				"direction=%s focused=%s visibleCandidates=%s",
				tostring(direction),
				tostring(windowIdOf(focusedWin)),
				windowIdsToDebugString(candidates)
			)
		)
		candidates = filterDirectionalCandidatesByOcclusion(candidates, orderedWins, config)
		debugLogDirectional(
			config,
			string.format("direction=%s afterOcclusion=%s", tostring(direction), windowIdsToDebugString(candidates))
		)
		local previousWin = resolvePreviousWindowForDirection()
		debugLogDirectional(
			config,
			string.format("direction=%s previous=%s", tostring(direction), tostring(windowIdOf(previousWin)))
		)
		local target = findDirectionalWindowTarget(focusedWin, candidates, direction, previousWin, orderedWins, config)
		if not target then
			debugLogDirectional(config, string.format("direction=%s no target", tostring(direction)))
			return false
		end
		debugLogDirectional(
			config,
			string.format("direction=%s select target=%s", tostring(direction), tostring(windowIdOf(target)))
		)
		selectWindow(target, { swapWithFocused = swapWithFocused })
		return true
	end

	local function handleChar(char, swapWithFocused)
		if not isShowing then
			return
		end

		currentInput = currentInput .. char
		local exact = hintByKey[currentInput]
		if exact then
			selectWindow(exact.win, { swapWithFocused = swapWithFocused })
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

	local function handleInputKey(key, inputModifiers)
		if not isShowing then
			return
		end
		local swapWithFocused = shouldSwapWindowFrameOnSelect(swapWindowFrameSelectModifiers, inputModifiers)
		if focusBackKey and key == focusBackKey then
			if runFocusBackAction(swapWithFocused) then
				return
			end
		end
		local direction = directionKeyLookup[key]
		if direction then
			runDirectionalAction(direction, swapWithFocused)
			return
		end
		local hintChar = hintCharByInputKey[key]
		if hintChar then
			handleChar(hintChar, swapWithFocused)
		end
	end

	local function ensureKeyBlocker()
		if keyBlocker then
			return
		end
		keyBlocker = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
			local keyCode = event:getKeyCode()
			local key = hs.keycodes.map[keyCode]
			local flags = event:getFlags()
			local modifiers = {}
			if flags.alt then
				table.insert(modifiers, "alt")
			end
			if flags.cmd then
				table.insert(modifiers, "cmd")
			end
			if flags.ctrl then
				table.insert(modifiers, "ctrl")
			end
			if flags.shift then
				table.insert(modifiers, "shift")
			end

			if key == "escape" then
				closeHints(true)
			elseif key == "delete" or key == "forwarddelete" then
				handleBackspace()
			elseif key then
				handleInputKey(key, modifiers)
			end

			return true
		end)
	end

	local function collectEntries()
		local entries = {}
		local focusedWin = hs.window.focusedWindow()
		local focusedId = focusedWin and focusedWin:id() or nil
		local orderedWins = hs.window.orderedWindows()
		local candidateWins, currentSpaceLookup = collectCandidateWindows(config.includeOtherSpaces)
		local orderedFrames = {}
		for _, w in ipairs(orderedWins) do
			local f = w:frame()
			if f then
				table.insert(orderedFrames, { id = w:id(), frame = f })
			end
		end

		for _, win in ipairs(candidateWins) do
			local app = win:application()
			local bundleID = app and app:bundleID() or nil
			local screen = win:screen()
			local winId = win:id()
			local isOffSpace = config.includeOtherSpaces and not currentSpaceLookup[winId]
			if app and bundleID and screen and isStandardWindow(win) and winId ~= focusedId then
				local appTitle = app:title() or ""
				local windowTitle = win:title() or ""
				local occluded = isOffSpace
				local coveringFrames = {}
				local wf = win:frame()
				if not isOffSpace then
					for _, of in ipairs(orderedFrames) do
						if of.id == winId then
							break
						end
						table.insert(coveringFrames, of.frame)
					end
					if #coveringFrames > 0 and wf.w > 0 and wf.h > 0 then
						local sampleCols, sampleRows = computeOcclusionSamplingGrid(wf, config)
						occluded = isWindowOccluded(wf, coveringFrames, sampleCols, sampleRows)
					end
				end
				local basePrefix, isOverridePrefix =
					resolveAppPrefix(appTitle, bundleID, windowTitle, hintChars[1], allowedPrefixes, appPrefixOverrides)
				table.insert(entries, {
					win = win,
					app = app,
					appKey = bundleID or appTitle,
					appTitle = appTitle,
					title = windowTitle,
					basePrefix = basePrefix,
					isOverridePrefix = isOverridePrefix,
					isOccluded = occluded,
					isOffSpace = isOffSpace,
					coveringFrames = coveringFrames,
				})
			end
		end

		table.sort(entries, function(a, b)
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
		assignUniquePrefixes(entries, hintChars[1], allowedPrefixes)
		table.sort(entries, function(a, b)
			if a.prefix ~= b.prefix then
				return comparePrefixes(a.prefix, b.prefix, hintCharOrder)
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
		local prefixes = {}
		for prefix, _ in pairs(grouped) do
			table.insert(prefixes, prefix)
		end
		table.sort(prefixes, function(a, b)
			return comparePrefixes(a, b, hintCharOrder)
		end)

		for _, prefix in ipairs(prefixes) do
			local group = grouped[prefix]
			if group then
				for i, entry in ipairs(group) do
					local key = hintKeyForGroup(prefix, #group, i, hintChars)
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
						isOffSpace = entry.isOffSpace,
						coveringFrames = entry.coveringFrames,
					})
				end
			end
		end

		makeKeysPrefixFree(hints, hintChars, hintCharOrder)
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
		isOffSpace,
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
		local offSpaceBadgeFillColor, offSpaceBadgeStrokeColor = resolveOffSpaceBadgeColors(true, config)

		local overlayBorderIdx = nil
		local offSpaceBadgeFillIdx = nil
		local offSpaceBadgeStrokeIdx = nil
		local nextIdx = 1
		canvas[nextIdx] = {
			type = "rectangle",
			action = "fill",
			fillColor = bgColor,
			roundedRectRadii = { xRadius = 12, yRadius = 12 },
			frame = { x = 0, y = 0, w = frame.w, h = frame.h },
		}
		nextIdx = nextIdx + 1

		if isOffSpace then
			local badgeDiameter = math.max(1, math.floor(config.offSpaceBadgeSize * scale))
			local badgeInset = math.max(6, math.floor(8 * scale))
			local badgeX = frame.w - badgeInset - badgeDiameter
			local badgeY = badgeInset
			canvas[nextIdx] = {
				type = "rectangle",
				action = "fill",
				fillColor = offSpaceBadgeFillColor,
				roundedRectRadii = { xRadius = badgeDiameter / 2, yRadius = badgeDiameter / 2 },
				frame = { x = badgeX, y = badgeY, w = badgeDiameter, h = badgeDiameter },
			}
			offSpaceBadgeFillIdx = nextIdx
			nextIdx = nextIdx + 1
			canvas[nextIdx] = {
				type = "rectangle",
				action = "stroke",
				strokeColor = offSpaceBadgeStrokeColor,
				strokeWidth = math.max(1, math.floor(1.0 * scale)),
				roundedRectRadii = { xRadius = badgeDiameter / 2, yRadius = badgeDiameter / 2 },
				frame = { x = badgeX, y = badgeY, w = badgeDiameter, h = badgeDiameter },
			}
			offSpaceBadgeStrokeIdx = nextIdx
			nextIdx = nextIdx + 1
		end

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
			overlayBorderIdx = nextIdx
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
		return
			canvas,
			keyBoxFrame,
			keyTextHeight,
			iconIdx,
			keyPrefixIdx,
			keyRestIdx,
			titleIdx,
			fSize,
			overlayBorderIdx,
			offSpaceBadgeFillIdx,
			offSpaceBadgeStrokeIdx
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
		local
			canvas,
			keyBoxFrame,
			keyTextHeight,
			iconIdx,
			keyPrefixIdx,
			keyRestIdx,
			titleIdx,
			fSize,
			overlayBorderIdx,
			offSpaceBadgeFillIdx,
			offSpaceBadgeStrokeIdx =
			newHintCanvas(
				canvasFrame,
				icon,
				hint.keyText,
				hint.titleText,
				keyBoxWidth,
				previewImage,
				previewHeight,
				hint.isOccluded,
				hint.isOffSpace,
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
		hint.overlayBorderIdx = overlayBorderIdx
		hint.offSpaceBadgeFillIdx = offSpaceBadgeFillIdx
		hint.offSpaceBadgeStrokeIdx = offSpaceBadgeStrokeIdx
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
			strokeColor = cloneColor(config.activeOverlayBorderColor),
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

		if config.centerCursorOnStart then
			local focusedWin = hs.window.focusedWindow()
			if focusedWin then
				local frame = focusedWin:frame()
				hs.mouse.absolutePosition({ x = frame.x + frame.w / 2, y = frame.y + frame.h / 2 })
			end
		end

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

		ensureKeyBlocker()

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
				local center = nextCenter({ x = baseCx, y = baseCy }, screen:frame(), width, height, takenRects)
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
					local winFrame = hint.win:frame()
					local windowCenterX = winFrame.x + (winFrame.w / 2)
					local windowCenterY = winFrame.y + (winFrame.h / 2)
					table.insert(screenGroups[screenKey].items, {
						hint = hint,
						width = width,
						height = height,
						keyBoxWidth = keyBoxWidth,
						previewImage = previewImage,
						previewHeight = previewHeight,
						windowCenterX = windowCenterX,
						windowCenterY = windowCenterY,
					})
				end
			end

			-- Layout dock per screen
			for _, group in pairs(screenGroups) do
				if config.dockWindowXBlend > 0 then
					table.sort(group.items, function(a, b)
						if a.windowCenterX ~= b.windowCenterX then
							return a.windowCenterX < b.windowCenterX
						end
						if a.hint.key ~= b.hint.key then
							return a.hint.key < b.hint.key
						end
						return false
					end)
				end
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

				local startX = resolveOccludedDockStartX(screenFrame, totalWidth)
				local dockY = screenFrame.y + screenFrame.h - maxHeight - config.dockBottomMargin
				local centeredX = startX
				for _, item in ipairs(group.items) do
					item.centeredX = centeredX
					centeredX = centeredX + item.width + config.dockItemGap
				end
				local itemXs = resolveOccludedDockItemXs(
					screenFrame,
					group.items,
					config.dockItemGap,
					config.dockWindowXBlend
				)

				for i, item in ipairs(group.items) do
					local itemX = itemXs[i]
					local centeredY = dockY + (maxHeight - item.height)
					local itemY = resolveOccludedDockItemY(
						screenFrame,
						item.height,
						centeredY,
						item.windowCenterY,
						config.dockWindowYBlend,
						config.dockBottomMargin
					)
					local canvasFrame = {
						x = itemX,
						y = itemY,
						w = item.width,
						h = item.height,
					}
					placeHint(item.hint, canvasFrame, item.previewImage, item.previewHeight, item.keyBoxWidth, scale)
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
		keyBlocker:start()
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
		for _, binding in ipairs(directDirectionBindings) do
			binding:delete()
		end
		directDirectionBindings = {}
		closeHints(true)
		if keyBlocker then
			keyBlocker:stop()
			keyBlocker = nil
		end
	end

	hotkey = hs.hotkey.bind(config.hotkeyModifiers, config.hotkeyKey, function()
		invokeShowHints()
	end)
	if directDirectionHotkeys then
		for _, direction in ipairs(ALL_DIRECTIONS) do
			local key = directDirectionHotkeys.keys and directDirectionHotkeys.keys[direction]
			if key then
				local binding = hs.hotkey.bind(directDirectionHotkeys.modifiers, key, function()
					runDirectionalAction(direction, false)
				end)
				table.insert(directDirectionBindings, binding)
			end
		end
	end

	return {
		show = invokeShowHints,
		teardown = teardown,
	}
end

M._test = {
	globToLuaPattern = globToLuaPattern,
	compileAppPrefixOverrides = compileAppPrefixOverrides,
	resolveAppPrefix = resolveAppPrefix,
	normalizeHintChars = normalizeHintChars,
	filterHintChars = filterHintChars,
	buildReservedHintCharLookup = buildReservedHintCharLookup,
	normalizeDirectDirectionHotkeys = normalizeDirectDirectionHotkeys,
	collectAppPrefixCandidates = collectAppPrefixCandidates,
	assignUniquePrefixes = assignUniquePrefixes,
	findDirectionalWindowTarget = findDirectionalWindowTarget,
	filterDirectionalCandidatesByOcclusion = filterDirectionalCandidatesByOcclusion,
	normalizeSelectModifiers = normalizeSelectModifiers,
	shouldSwapWindowFrameOnSelect = shouldSwapWindowFrameOnSelect,
	collectModalInputModifiers = collectModalInputModifiers,
	swapWindowFrames = swapWindowFrames,
	resolveFocusBackTargetWindow = resolveFocusBackTargetWindow,
	resolveHintOverlayBorderColor = resolveHintOverlayBorderColor,
	resolveOccludedDockItemX = resolveOccludedDockItemX,
	resolveOccludedDockItemXs = resolveOccludedDockItemXs,
	resolveOccludedDockItemY = resolveOccludedDockItemY,
	resolveOccludedDockStartX = resolveOccludedDockStartX,
	comparePrefixes = comparePrefixes,
	buildWindowIdLookup = buildWindowIdLookup,
	mergeUniqueWindows = mergeUniqueWindows,
	collectCandidateWindows = collectCandidateWindows,
	splitCandidatesByCurrentSpace = splitCandidatesByCurrentSpace,
	resolveOffSpaceBadgeColors = resolveOffSpaceBadgeColors,
	hintKeyForGroup = hintKeyForGroup,
	findExpandedKey = findExpandedKey,
	makeKeysPrefixFree = makeKeysPrefixFree,
}

return M
