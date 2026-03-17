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
	hotkey = {
		modifiers = { "alt" },
		key = "f20",
	},
	hint = {
		chars = DEFAULT_HINT_CHARS,
		prefixOverrides = nil,
	},
	ui = {
		icon = {
			size = 72,
			alpha = 0.95,
			dimmedAlpha = 0.30,
		},
		keyBox = {
			size = 72,
			minWidth = 72,
			horizontalPadding = 10,
			gap = 0,
		},
		text = {
			fontName = nil,
			keyFontSize = 48,
			titleFontSize = 16,
			rowGap = 8,
			titleMaxSize = 72,
			showTitles = true,
			keyColor = { red = 1, green = 1, blue = 1, alpha = 1 },
			keyDimmedColor = { red = 0.85, green = 0.85, blue = 0.88, alpha = 0.28 },
			titleColor = { red = 0.90, green = 0.92, blue = 0.96, alpha = 1.00 },
			titleDimmedColor = { red = 0.90, green = 0.92, blue = 0.96, alpha = 0.30 },
			keyHighlightColor = { red = 0.84, green = 0.84, blue = 0.86, alpha = 0.35 },
		},
		badge = {
			padding = 12,
			bgColor = { red = 0.03, green = 0.03, blue = 0.04, alpha = 0.80 },
			dimmedBgAlpha = 0.14,
			bumpMove = 90,
		},
		offSpaceBadge = {
			enabled = true,
			size = 32,
			fillColor = { red = 0.34, green = 0.64, blue = 0.96, alpha = 0.56 },
			strokeColor = { red = 0.98, green = 0.99, blue = 1.00, alpha = 0.72 },
			textColor = { red = 1.0, green = 1.0, blue = 1.0, alpha = 0.92 },
			inactiveFillAlpha = 0.28,
			inactiveStrokeAlpha = 0.40,
			inactiveTextAlpha = 0.35,
			spaceColors = {
				-- 1: 青（デフォルトと同系色）
				{
					fillColor = { red = 0.34, green = 0.64, blue = 0.96, alpha = 0.56 },
					strokeColor = { red = 0.98, green = 0.99, blue = 1.00, alpha = 0.72 },
					textColor = { red = 1.0, green = 1.0, blue = 1.0, alpha = 0.92 },
				},
				-- 2: 緑
				{
					fillColor = { red = 0.30, green = 0.78, blue = 0.47, alpha = 0.56 },
					strokeColor = { red = 0.85, green = 1.00, blue = 0.90, alpha = 0.72 },
					textColor = { red = 1.0, green = 1.0, blue = 1.0, alpha = 0.92 },
				},
				-- 3: オレンジ
				{
					fillColor = { red = 0.95, green = 0.60, blue = 0.25, alpha = 0.56 },
					strokeColor = { red = 1.00, green = 0.92, blue = 0.80, alpha = 0.72 },
					textColor = { red = 1.0, green = 1.0, blue = 1.0, alpha = 0.92 },
				},
				-- 4: 紫
				{
					fillColor = { red = 0.68, green = 0.42, blue = 0.90, alpha = 0.56 },
					strokeColor = { red = 0.92, green = 0.85, blue = 1.00, alpha = 0.72 },
					textColor = { red = 1.0, green = 1.0, blue = 1.0, alpha = 0.92 },
				},
				-- 5: ピンク
				{
					fillColor = { red = 0.92, green = 0.38, blue = 0.58, alpha = 0.56 },
					strokeColor = { red = 1.00, green = 0.85, blue = 0.90, alpha = 0.72 },
					textColor = { red = 1.0, green = 1.0, blue = 1.0, alpha = 0.92 },
				},
			},
		},
	},
	overlay = {
		active = {
			fillColor = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.08 },
			borderColor = { red = 0.95, green = 0.68, blue = 0.40, alpha = 0.95 },
			borderWidth = 13,
			cornerRadius = 10,
		},
		hint = {
			fillColor = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.56 },
			borderColor = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.85 },
			dimmedBorderColor = { red = 0.45, green = 0.45, blue = 0.48, alpha = 0.30 },
			borderWidth = 6,
			cornerRadius = 12,
		},
	},
	occlusion = {
		sampling = {
			enabled = true,
			baseWidth = 1920,
			baseHeight = 1080,
			minCols = 4,
			minRows = 4,
			maxCols = 8,
			maxRows = 8,
		},
		preview = {
			enabled = true,
			width = 140,
			padding = 6,
			alpha = 0.46,
		},
		hint = {
			scale = 0.65,
			bgAlpha = 0.32,
			iconAlpha = 0.46,
		},
	},
	dock = {
		bottomMargin = 24,
		itemGap = 12,
		windowBlend = {
			x = 0.0,
			y = 0.0,
		},
	},
	navigation = {
		focusBackKey = nil,
		directionKeys = nil,
		directHotkeys = nil,
		cardinalOverlapTieThresholdPx = 720,
		debugDirectionalNavigation = false,
		swapSelectModifiers = nil,
	},
	behavior = {
		onSelect = nil,
		onError = nil,
		centerCursor = false,
		centerCursorOnStart = false,
		includeOtherSpaces = false,
	},
	internal = {
		focusHistory = nil,
	},
}

local LEGACY_FLAT_KEYS = {
	hotkeyModifiers = true,
	hotkeyKey = true,
	hintChars = true,
	iconSize = true,
	keyBoxSize = true,
	keyBoxMinWidth = true,
	keyBoxHorizontalPadding = true,
	keyGap = true,
	padding = true,
	fontName = true,
	fontSize = true,
	titleFontSize = true,
	rowGap = true,
	titleMaxSize = true,
	showTitles = true,
	bgColor = true,
	dimmedBgAlpha = true,
	textColor = true,
	dimmedTextColor = true,
	titleTextColor = true,
	dimmedTitleTextColor = true,
	keyHighlightColor = true,
	iconAlpha = true,
	dimmedIconAlpha = true,
	bumpMove = true,
	showPreviewForOccluded = true,
	appPrefixOverrides = true,
	occlusionSamplingEnabled = true,
	occlusionSamplingBaseWidth = true,
	occlusionSamplingBaseHeight = true,
	occlusionSamplingMinCols = true,
	occlusionSamplingMinRows = true,
	occlusionSamplingMaxCols = true,
	occlusionSamplingMaxRows = true,
	previewWidth = true,
	previewPadding = true,
	occludedScale = true,
	occludedBgAlpha = true,
	occludedIconAlpha = true,
	occludedPreviewAlpha = true,
	activeOverlayColor = true,
	activeOverlayBorderColor = true,
	activeOverlayBorderWidth = true,
	activeOverlayCornerRadius = true,
	hintOverlayColor = true,
	hintOverlayBorderColor = true,
	dimmedHintOverlayBorderColor = true,
	hintOverlayBorderWidth = true,
	hintOverlayCornerRadius = true,
	dockBottomMargin = true,
	dockItemGap = true,
	dockWindowXBlend = true,
	dockWindowYBlend = true,
	focusBackKey = true,
	directionKeys = true,
	directDirectionHotkeys = true,
	cardinalOverlapTieThresholdPx = true,
	debugDirectionalNavigation = true,
	swapWindowFrameSelectModifiers = true,
	onSelect = true,
	onError = true,
	centerCursor = true,
	centerCursorOnStart = true,
	focusHistory = true,
}

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
	return maxIndex > 0
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copied = {}
	for k, v in pairs(value) do
		copied[k] = deepCopy(v)
	end
	return copied
end

local function deepMerge(defaults, overrides)
	if type(defaults) ~= "table" then
		if overrides ~= nil then
			return deepCopy(overrides)
		end
		return deepCopy(defaults)
	end
	if type(overrides) ~= "table" then
		if overrides ~= nil then
			return deepCopy(overrides)
		end
		return deepCopy(defaults)
	end
	local defaultsIsArray = isArrayTable(defaults)
	local overridesIsArray = isArrayTable(overrides)
	if defaultsIsArray or overridesIsArray then
		return deepCopy(overrides)
	end

	local merged = {}
	for k, v in pairs(defaults) do
		merged[k] = deepCopy(v)
	end
	for k, v in pairs(overrides) do
		merged[k] = deepMerge(defaults[k], v)
	end
	return merged
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
		error("[jinrai.window_hints] navigation.directionKeys must be a table")
	end
	return {
		left = normalizeActionKey(directionKeys.left, "navigation.directionKeys.left"),
		down = normalizeActionKey(directionKeys.down, "navigation.directionKeys.down"),
		up = normalizeActionKey(directionKeys.up, "navigation.directionKeys.up"),
		right = normalizeActionKey(directionKeys.right, "navigation.directionKeys.right"),
		upLeft = normalizeActionKey(directionKeys.upLeft, "navigation.directionKeys.upLeft"),
		upRight = normalizeActionKey(directionKeys.upRight, "navigation.directionKeys.upRight"),
		downLeft = normalizeActionKey(directionKeys.downLeft, "navigation.directionKeys.downLeft"),
		downRight = normalizeActionKey(directionKeys.downRight, "navigation.directionKeys.downRight"),
	}
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
				error("[jinrai.window_hints] navigation.directionKeys must not contain duplicate keys")
			end
			lookup[key] = direction
		end
	end
	return lookup
end

local function normalizeModifierName(modifier)
	local normalized = string.lower(modifier)
	return MODIFIER_ALIAS_LOOKUP[normalized] or normalized
end

local function normalizeDirectDirectionHotkeys(directDirectionHotkeys)
	if directDirectionHotkeys == nil then
		return nil
	end
	if type(directDirectionHotkeys) ~= "table" then
		error("[jinrai.window_hints] navigation.directHotkeys must be a table")
	end

	local keys = directDirectionHotkeys.keys
	if keys ~= nil and type(keys) ~= "table" then
		error("[jinrai.window_hints] navigation.directHotkeys.keys must be a table")
	end
	local directionKeys = normalizeDirectionKeys(keys)
	local directionKeyLookup = buildDirectionKeyLookup(directionKeys)
	if next(directionKeyLookup) == nil then
		return nil
	end

	local modifiers = directDirectionHotkeys.modifiers
	if type(modifiers) ~= "table" then
		error("[jinrai.window_hints] navigation.directHotkeys.modifiers must be an array")
	end
	local maxIndex = 0
	for k, _ in pairs(modifiers) do
		if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
			error("[jinrai.window_hints] navigation.directHotkeys.modifiers must be an array")
		end
		if k > maxIndex then
			maxIndex = k
		end
	end
	for i = 1, maxIndex do
		if modifiers[i] == nil then
			error("[jinrai.window_hints] navigation.directHotkeys.modifiers must be an array")
		end
	end
	if #modifiers == 0 then
		error("[jinrai.window_hints] navigation.directHotkeys.modifiers must not be empty")
	end

	local modifierLookup = {}
	for i, modifier in ipairs(modifiers) do
		if type(modifier) ~= "string" then
			error(string.format("[jinrai.window_hints] navigation.directHotkeys.modifiers[%d] must be a string", i))
		end
		local normalized = normalizeModifierName(modifier)
		if normalized == "" then
			error(string.format("[jinrai.window_hints] navigation.directHotkeys.modifiers[%d] must not be empty", i))
		end
		if not SELECT_MODIFIER_LOOKUP[normalized] then
			error(
				string.format(
					"[jinrai.window_hints] navigation.directHotkeys.modifiers[%d] must be one of cmd/alt/ctrl/shift/fn",
					i
				)
			)
		end
		if modifierLookup[normalized] then
			error("[jinrai.window_hints] navigation.directHotkeys.modifiers must not contain duplicate modifiers")
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

local function normalizeHintChars(rawHintChars)
	if type(rawHintChars) ~= "table" or not isArrayTable(rawHintChars) then
		error("[jinrai.window_hints] hint.chars must be an array")
	end
	local normalized = {}
	for i, char in ipairs(rawHintChars) do
		if type(char) ~= "string" then
			error(string.format("[jinrai.window_hints] hint.chars[%d] must be a string", i))
		end
		if char == "" then
			error(string.format("[jinrai.window_hints] hint.chars[%d] must not be empty", i))
		end
		table.insert(normalized, string.upper(char))
	end
	if #normalized == 0 then
		error("[jinrai.window_hints] hint.chars must not be empty")
	end
	return normalized
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

local function filterHintChars(hintChars, reservedHintCharLookup)
	local filtered = {}
	for _, char in ipairs(hintChars) do
		if not reservedHintCharLookup[char] then
			table.insert(filtered, char)
		end
	end
	return filtered
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

local function normalizePositiveNumber(value, optionName)
	if type(value) ~= "number" or value ~= value then
		error(string.format("[jinrai.window_hints] %s must be a number", optionName))
	end
	if value <= 0 then
		error(string.format("[jinrai.window_hints] %s must be > 0", optionName))
	end
	return value
end

local function normalizeSelectModifiers(modifiers)
	if modifiers == nil then
		return nil
	end
	if type(modifiers) ~= "table" or not isArrayTable(modifiers) then
		error("[jinrai.window_hints] navigation.swapSelectModifiers must be an array")
	end
	if #modifiers == 0 then
		error("[jinrai.window_hints] navigation.swapSelectModifiers must not be empty")
	end

	local lookup = {}
	for i, modifier in ipairs(modifiers) do
		if type(modifier) ~= "string" then
			error(string.format("[jinrai.window_hints] navigation.swapSelectModifiers[%d] must be a string", i))
		end
		local normalized = normalizeModifierName(modifier)
		if normalized == "" then
			error(string.format("[jinrai.window_hints] navigation.swapSelectModifiers[%d] must not be empty", i))
		end
		if not SELECT_MODIFIER_LOOKUP[normalized] then
			error(
				string.format(
					"[jinrai.window_hints] navigation.swapSelectModifiers[%d] must be one of cmd/alt/ctrl/shift/fn",
					i
				)
			)
		end
		if lookup[normalized] then
			error("[jinrai.window_hints] navigation.swapSelectModifiers must not contain duplicate modifiers")
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

local function checkLegacyFlatKeys(options)
	for key, _ in pairs(options) do
		if LEGACY_FLAT_KEYS[key] then
			error(string.format("[jinrai.window_hints] legacy flat key '%s' is no longer supported; use nested config", key))
		end
	end
end

function M.build(options)
	options = options or {}
	if type(options) ~= "table" then
		error("[jinrai.window_hints] options must be a table")
	end
	checkLegacyFlatKeys(options)

	local merged = deepMerge(DEFAULT_CONFIG, options)
	if options.internal and type(options.internal) == "table" and options.internal.focusHistory ~= nil then
		merged.internal.focusHistory = options.internal.focusHistory
	end

	local directionKeys = normalizeDirectionKeys(merged.navigation.directionKeys)
	local directionKeyLookup = buildDirectionKeyLookup(directionKeys)
	local directDirectionHotkeys = normalizeDirectDirectionHotkeys(merged.navigation.directHotkeys)
	local focusBackKey = normalizeActionKey(merged.navigation.focusBackKey, "navigation.focusBackKey")
	local swapSelectModifiers = normalizeSelectModifiers(merged.navigation.swapSelectModifiers)
	local focusHistory = merged.internal.focusHistory
	if not focusHistory then
		focusBackKey = nil
	end

	local hintChars = normalizeHintChars(merged.hint.chars or DEFAULT_HINT_CHARS)
	local reservedHintCharLookup = buildReservedHintCharLookup(directionKeyLookup, focusBackKey)
	hintChars = filterHintChars(hintChars, reservedHintCharLookup)
	if #hintChars == 0 then
		error("[jinrai.window_hints] no available hintChars after excluding reserved navigation keys")
	end

	local dockWindowXBlend = normalizeUnitIntervalNumber(merged.dock.windowBlend.x, "dock.windowBlend.x")
	local dockWindowYBlend = normalizeUnitIntervalNumber(merged.dock.windowBlend.y, "dock.windowBlend.y")
	local offSpaceBadgeSize = normalizePositiveNumber(merged.ui.offSpaceBadge.size, "ui.offSpaceBadge.size")
	local offSpaceBadgeInactiveFillAlpha = normalizeUnitIntervalNumber(
		merged.ui.offSpaceBadge.inactiveFillAlpha,
		"ui.offSpaceBadge.inactiveFillAlpha"
	)
	local offSpaceBadgeInactiveStrokeAlpha = normalizeUnitIntervalNumber(
		merged.ui.offSpaceBadge.inactiveStrokeAlpha,
		"ui.offSpaceBadge.inactiveStrokeAlpha"
	)
	local offSpaceBadgeInactiveTextAlpha = normalizeUnitIntervalNumber(
		merged.ui.offSpaceBadge.inactiveTextAlpha,
		"ui.offSpaceBadge.inactiveTextAlpha"
	)
	local cardinalOverlapTieThresholdPx = normalizeNonNegativeNumber(
		merged.navigation.cardinalOverlapTieThresholdPx,
		"navigation.cardinalOverlapTieThresholdPx"
	)

	return {
		hotkeyModifiers = merged.hotkey.modifiers,
		hotkeyKey = merged.hotkey.key,
		hintChars = hintChars,
		iconSize = merged.ui.icon.size,
		keyBoxSize = merged.ui.keyBox.size,
		keyBoxMinWidth = merged.ui.keyBox.minWidth,
		keyBoxHorizontalPadding = merged.ui.keyBox.horizontalPadding,
		keyGap = merged.ui.keyBox.gap,
		padding = merged.ui.badge.padding,
		fontName = merged.ui.text.fontName,
		fontSize = merged.ui.text.keyFontSize,
		titleFontSize = merged.ui.text.titleFontSize,
		rowGap = merged.ui.text.rowGap,
		titleMaxSize = merged.ui.text.titleMaxSize,
		showTitles = merged.ui.text.showTitles,
		bgColor = merged.ui.badge.bgColor,
		dimmedBgAlpha = merged.ui.badge.dimmedBgAlpha,
		offSpaceBadgeEnabled = merged.ui.offSpaceBadge.enabled,
		offSpaceBadgeSize = offSpaceBadgeSize,
		offSpaceBadgeFillColor = merged.ui.offSpaceBadge.fillColor,
		offSpaceBadgeStrokeColor = merged.ui.offSpaceBadge.strokeColor,
		offSpaceBadgeInactiveFillAlpha = offSpaceBadgeInactiveFillAlpha,
		offSpaceBadgeInactiveStrokeAlpha = offSpaceBadgeInactiveStrokeAlpha,
		offSpaceBadgeTextColor = merged.ui.offSpaceBadge.textColor,
		offSpaceBadgeInactiveTextAlpha = offSpaceBadgeInactiveTextAlpha,
		offSpaceBadgeSpaceColors = merged.ui.offSpaceBadge.spaceColors,
		textColor = merged.ui.text.keyColor,
		dimmedTextColor = merged.ui.text.keyDimmedColor,
		titleTextColor = merged.ui.text.titleColor,
		dimmedTitleTextColor = merged.ui.text.titleDimmedColor,
		keyHighlightColor = merged.ui.text.keyHighlightColor,
		iconAlpha = merged.ui.icon.alpha,
		dimmedIconAlpha = merged.ui.icon.dimmedAlpha,
		bumpMove = merged.ui.badge.bumpMove,
		showPreviewForOccluded = merged.occlusion.preview.enabled,
		occlusionSamplingEnabled = merged.occlusion.sampling.enabled,
		occlusionSamplingBaseWidth = merged.occlusion.sampling.baseWidth,
		occlusionSamplingBaseHeight = merged.occlusion.sampling.baseHeight,
		occlusionSamplingMinCols = merged.occlusion.sampling.minCols,
		occlusionSamplingMinRows = merged.occlusion.sampling.minRows,
		occlusionSamplingMaxCols = merged.occlusion.sampling.maxCols,
		occlusionSamplingMaxRows = merged.occlusion.sampling.maxRows,
		previewWidth = merged.occlusion.preview.width,
		previewPadding = merged.occlusion.preview.padding,
		occludedScale = merged.occlusion.hint.scale,
		occludedBgAlpha = merged.occlusion.hint.bgAlpha,
		occludedIconAlpha = merged.occlusion.hint.iconAlpha,
		occludedPreviewAlpha = merged.occlusion.preview.alpha,
		activeOverlayColor = merged.overlay.active.fillColor,
		activeOverlayBorderColor = merged.overlay.active.borderColor,
		activeOverlayBorderWidth = merged.overlay.active.borderWidth,
		activeOverlayCornerRadius = merged.overlay.active.cornerRadius,
		hintOverlayColor = merged.overlay.hint.fillColor,
		hintOverlayBorderColor = merged.overlay.hint.borderColor,
		dimmedHintOverlayBorderColor = merged.overlay.hint.dimmedBorderColor,
		hintOverlayBorderWidth = merged.overlay.hint.borderWidth,
		hintOverlayCornerRadius = merged.overlay.hint.cornerRadius,
		dockBottomMargin = merged.dock.bottomMargin,
		dockItemGap = merged.dock.itemGap,
		dockWindowXBlend = dockWindowXBlend,
		dockWindowYBlend = dockWindowYBlend,
		appPrefixOverrides = merged.hint.prefixOverrides,
		onSelect = merged.behavior.onSelect,
		onError = merged.behavior.onError,
		centerCursor = merged.behavior.centerCursor,
		centerCursorOnStart = merged.behavior.centerCursorOnStart,
		includeOtherSpaces = merged.behavior.includeOtherSpaces,
		focusBackKey = focusBackKey,
		directionKeys = directionKeys,
		directionKeyLookup = directionKeyLookup,
		directDirectionHotkeys = directDirectionHotkeys,
		cardinalOverlapTieThresholdPx = cardinalOverlapTieThresholdPx,
		debugDirectionalNavigation = merged.navigation.debugDirectionalNavigation,
		swapWindowFrameSelectModifiers = swapSelectModifiers,
		focusHistory = focusHistory,
	}
end

M._test = {
	deepMerge = deepMerge,
	normalizeHintChars = normalizeHintChars,
	filterHintChars = filterHintChars,
	buildReservedHintCharLookup = buildReservedHintCharLookup,
	normalizeDirectDirectionHotkeys = normalizeDirectDirectionHotkeys,
	normalizeSelectModifiers = normalizeSelectModifiers,
}

return M
