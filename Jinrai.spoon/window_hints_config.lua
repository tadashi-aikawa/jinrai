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
		padding = 12,
		collisionOffset = 90,
		cornerRadius = 12,
		occludedScale = 0.85,
		highlight = {
			borderWidth = 6,
		},
		state = {
			normal = {
				bgColor = { red = 0.03, green = 0.03, blue = 0.04, alpha = 0.80 },
				highlight = {
					fillColor = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.56 },
					borderColor = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.85 },
				},
			},
			dimmed = {
				bgColor = { red = 0.03, green = 0.03, blue = 0.04, alpha = 0.14 },
				highlight = {
					borderColor = { red = 0.45, green = 0.45, blue = 0.48, alpha = 0.30 },
				},
			},
			occluded = {
				bgColor = { red = 0.03, green = 0.03, blue = 0.04, alpha = 0.70 },
			},
			active = {
				bgColor = { red = 0.08, green = 0.05, blue = 0.03, alpha = 0.88 },
				highlight = {
					fillColor = { red = 0.95, green = 0.68, blue = 0.40, alpha = 0.56 },
					borderColor = { red = 0.95, green = 0.68, blue = 0.40, alpha = 0.95 },
				},
			},
		},
		icon = {
			size = 72,
			state = {
				normal = { alpha = 0.95 },
				dimmed = { alpha = 0.30 },
				occluded = { alpha = 0.46 },
				active = { alpha = 1.0 },
			},
		},
		key = {
			size = 72,
			minWidth = 72,
			horizontalPadding = 10,
			gap = 0,
			fontName = nil,
			fontSize = 48,
			keyHighlightColor = { red = 0.84, green = 0.84, blue = 0.86, alpha = 0.35 },
			state = {
				normal = {
					color = { red = 1, green = 1, blue = 1, alpha = 1 },
				},
				dimmed = {
					color = { red = 0.85, green = 0.85, blue = 0.88, alpha = 0.28 },
				},
				occluded = {},
				active = {
					color = { red = 1.00, green = 0.93, blue = 0.86, alpha = 1.00 },
				},
			},
		},
		title = {
			fontName = nil,
			fontSize = 16,
			rowGap = 8,
			maxSize = 72,
			show = true,
			state = {
				normal = {
					color = { red = 0.90, green = 0.92, blue = 0.96, alpha = 1.00 },
				},
				dimmed = {
					color = { red = 0.90, green = 0.92, blue = 0.96, alpha = 0.30 },
				},
				occluded = {},
				active = {
					color = { red = 0.99, green = 0.90, blue = 0.78, alpha = 1.00 },
				},
			},
		},
		spaceBadge = {
			enabled = true,
			size = 32,
			state = {
				normal = {
					fillColor = { red = 0.34, green = 0.64, blue = 0.96, alpha = 0.56 },
					strokeColor = { red = 0.98, green = 0.99, blue = 1.00, alpha = 0.72 },
					textColor = { red = 1.0, green = 1.0, blue = 1.0, alpha = 0.92 },
				},
				dimmed = {
					fillColor = { red = 0.34, green = 0.64, blue = 0.96, alpha = 0.28 },
					strokeColor = { red = 0.98, green = 0.99, blue = 1.00, alpha = 0.40 },
					textColor = { red = 1.0, green = 1.0, blue = 1.0, alpha = 0.35 },
				},
				occluded = {},
				active = {
					fillColor = { red = 0.95, green = 0.68, blue = 0.40, alpha = 0.56 },
					strokeColor = { red = 1.00, green = 0.90, blue = 0.78, alpha = 0.72 },
					textColor = { red = 1.0, green = 0.98, blue = 0.94, alpha = 0.92 },
				},
			},
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
	focusedWindowHighlight = {
		fillColor = { red = 0.40, green = 0.68, blue = 0.98, alpha = 0.08 },
		borderColor = { red = 0.95, green = 0.68, blue = 0.40, alpha = 0.95 },
		borderWidth = 13,
		cornerRadius = 10,
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
			mode = "background", -- "below": タイトル下に小さく表示, "background": ヒント全体の背景として表示
			width = 140,
			padding = 6,
			alpha = 0.64,
		},
	},
	dock = {
		bottomMargin = 96,
		itemGap = 12,
		windowBlend = {
			x = 0.65,
			y = 1,
		},
	},
	navigation = {
		focusBack = {
			key = nil,
		},
		direction = {
			hints = {
				keys = nil,
			},
			direct = {
				modifiers = nil,
				keys = nil,
			},
			scoring = {
				cardinalOverlapTieThresholdPx = 720,
				debug = false,
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
	behavior = {
		selection = {
			swapWindowFrame = {
				modifiers = nil,
			},
		},
		cursor = {
			onSelect = true,
			onStart = true,
		},
		candidates = {
			includeOtherSpaces = true,
			includeActiveWindow = true,
		},
		callbacks = {
			onSelect = nil,
			onError = nil,
		},
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
	keyFontName = true,
	titleFontName = true,
	bumpMove = true,
	showPreviewForOccluded = true,
	previewMode = true,
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

local function normalizeDirectionKeys(directionKeys, optionName)
	if directionKeys == nil then
		return nil
	end
	if type(directionKeys) ~= "table" then
		error(string.format("[jinrai.window_hints] %s must be a table", optionName))
	end
	return {
		left = normalizeActionKey(directionKeys.left, optionName .. ".left"),
		down = normalizeActionKey(directionKeys.down, optionName .. ".down"),
		up = normalizeActionKey(directionKeys.up, optionName .. ".up"),
		right = normalizeActionKey(directionKeys.right, optionName .. ".right"),
		upLeft = normalizeActionKey(directionKeys.upLeft, optionName .. ".upLeft"),
		upRight = normalizeActionKey(directionKeys.upRight, optionName .. ".upRight"),
		downLeft = normalizeActionKey(directionKeys.downLeft, optionName .. ".downLeft"),
		downRight = normalizeActionKey(directionKeys.downRight, optionName .. ".downRight"),
	}
end

local function buildDirectionKeyLookup(directionKeys, optionName)
	if not directionKeys then
		return {}
	end
	local lookup = {}
	for _, direction in ipairs(ALL_DIRECTIONS) do
		local key = directionKeys[direction]
		if key then
			local existing = lookup[key]
			if existing and existing ~= direction then
				error(string.format("[jinrai.window_hints] %s must not contain duplicate keys", optionName))
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
		error("[jinrai.window_hints] navigation.direction.direct must be a table")
	end

	local keys = directDirectionHotkeys.keys
	if keys ~= nil and type(keys) ~= "table" then
		error("[jinrai.window_hints] navigation.direction.direct.keys must be a table")
	end
	local directionKeys = normalizeDirectionKeys(keys, "navigation.direction.direct.keys")
	local directionKeyLookup = buildDirectionKeyLookup(directionKeys, "navigation.direction.direct.keys")
	if next(directionKeyLookup) == nil then
		return nil
	end

	local modifiers = directDirectionHotkeys.modifiers
	if type(modifiers) ~= "table" then
		error("[jinrai.window_hints] navigation.direction.direct.modifiers must be an array")
	end
	local maxIndex = 0
	for k, _ in pairs(modifiers) do
		if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
			error("[jinrai.window_hints] navigation.direction.direct.modifiers must be an array")
		end
		if k > maxIndex then
			maxIndex = k
		end
	end
	for i = 1, maxIndex do
		if modifiers[i] == nil then
			error("[jinrai.window_hints] navigation.direction.direct.modifiers must be an array")
		end
	end
	if #modifiers == 0 then
		error("[jinrai.window_hints] navigation.direction.direct.modifiers must not be empty")
	end

	local modifierLookup = {}
	for i, modifier in ipairs(modifiers) do
		if type(modifier) ~= "string" then
			error(string.format("[jinrai.window_hints] navigation.direction.direct.modifiers[%d] must be a string", i))
		end
		local normalized = normalizeModifierName(modifier)
		if normalized == "" then
			error(string.format("[jinrai.window_hints] navigation.direction.direct.modifiers[%d] must not be empty", i))
		end
		if not SELECT_MODIFIER_LOOKUP[normalized] then
			error(
				string.format(
					"[jinrai.window_hints] navigation.direction.direct.modifiers[%d] must be one of cmd/alt/ctrl/shift/fn",
					i
				)
			)
		end
		if modifierLookup[normalized] then
			error("[jinrai.window_hints] navigation.direction.direct.modifiers must not contain duplicate modifiers")
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

local function buildReservedHintCharLookup(directionKeyLookup, focusBackKey, spaceKeys, prevSpaceKey, nextSpaceKey)
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
	addKey(prevSpaceKey)
	addKey(nextSpaceKey)
	if spaceKeys then
		for i = 1, 9 do
			reserved[tostring(i)] = true
		end
	end
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

local function normalizeSelectModifiers(modifiers, optionName)
	if modifiers == nil then
		return nil
	end
	if type(modifiers) ~= "table" or not isArrayTable(modifiers) then
		error(string.format("[jinrai.window_hints] %s must be an array", optionName))
	end
	if #modifiers == 0 then
		error(string.format("[jinrai.window_hints] %s must not be empty", optionName))
	end

	local lookup = {}
	for i, modifier in ipairs(modifiers) do
		if type(modifier) ~= "string" then
			error(string.format("[jinrai.window_hints] %s[%d] must be a string", optionName, i))
		end
		local normalized = normalizeModifierName(modifier)
		if normalized == "" then
			error(string.format("[jinrai.window_hints] %s[%d] must not be empty", optionName, i))
		end
		if not SELECT_MODIFIER_LOOKUP[normalized] then
			error(
				string.format(
					"[jinrai.window_hints] %s[%d] must be one of cmd/alt/ctrl/shift/fn",
					optionName,
					i
				)
			)
		end
		if lookup[normalized] then
			error(string.format("[jinrai.window_hints] %s must not contain duplicate modifiers", optionName))
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

local function resolveStateConfig(stateConfig, stateName)
	if type(stateConfig) ~= "table" then
		return {}
	end
	local resolved = stateConfig[stateName]
	if type(resolved) ~= "table" then
		return {}
	end
	return resolved
end

local function resolveStateValue(stateConfig, stateName, key, fallbackStateNames)
	local stateValue = resolveStateConfig(stateConfig, stateName)[key]
	if stateValue ~= nil then
		return stateValue
	end
	for _, fallbackStateName in ipairs(fallbackStateNames or {}) do
		local fallbackValue = resolveStateConfig(stateConfig, fallbackStateName)[key]
		if fallbackValue ~= nil then
			return fallbackValue
		end
	end
	return nil
end

local function resolveHighlightStateValue(stateConfig, stateName, key, fallbackStateNames)
	local highlightConfig = resolveStateConfig(stateConfig, stateName).highlight
	if type(highlightConfig) == "table" and highlightConfig[key] ~= nil then
		return highlightConfig[key]
	end
	for _, fallbackStateName in ipairs(fallbackStateNames or {}) do
		local fallbackHighlightConfig = resolveStateConfig(stateConfig, fallbackStateName).highlight
		if type(fallbackHighlightConfig) == "table" and fallbackHighlightConfig[key] ~= nil then
			return fallbackHighlightConfig[key]
		end
	end
	return nil
end

local function checkLegacyFlatKeys(options)
	for key, _ in pairs(options) do
		if LEGACY_FLAT_KEYS[key] then
			error(string.format("[jinrai.window_hints] legacy flat key '%s' is no longer supported; use nested config", key))
		end
	end
end

local function checkLegacyNestedKeys(options)
	if options.ui ~= nil then
		error(
			"[jinrai.window_hints] legacy nested key 'ui.*' is no longer supported; use 'hint.*' (hint.icon / hint.key / hint.title / hint.state / hint.spaceBadge)"
		)
	end
	if options.activeWindow ~= nil then
		error(
			"[jinrai.window_hints] legacy nested key 'activeWindow.*' is no longer supported; use 'focusedWindowHighlight.*'"
		)
	end
	if options.overlay ~= nil then
		error(
			"[jinrai.window_hints] legacy nested key 'overlay.*' is no longer supported; use 'focusedWindowHighlight' / 'hint.state.*.highlight'"
		)
	end
	if type(options.hint) == "table" and options.hint.badge ~= nil then
		error("[jinrai.window_hints] legacy nested key 'hint.badge.*' is no longer supported; use 'hint.state.*.bgColor'")
	end
	if type(options.hint) == "table" and options.hint.keyBox ~= nil then
		error("[jinrai.window_hints] legacy nested key 'hint.keyBox.*' is no longer supported; use 'hint.key.*'")
	end
	if type(options.hint) == "table" and options.hint.text ~= nil then
		error("[jinrai.window_hints] legacy nested key 'hint.text.*' is no longer supported; use 'hint.key.*' / 'hint.title.*'")
	end
	if type(options.hint) == "table" and options.hint.overlay ~= nil then
		error("[jinrai.window_hints] legacy nested key 'hint.overlay.*' is no longer supported; use 'hint.state.*.highlight'")
	end
	if type(options.hint) == "table" and options.hint.onActiveWindow ~= nil then
		error("[jinrai.window_hints] legacy nested key 'hint.onActiveWindow.*' is no longer supported; use 'hint.state.active.highlight'")
	end
	if type(options.hint) == "table" and options.hint.offSpaceBadge ~= nil then
		error("[jinrai.window_hints] legacy nested key 'hint.offSpaceBadge.*' is no longer supported; use 'hint.spaceBadge.*'")
	end
	if type(options.navigation) == "table" then
		if options.navigation.focusBackKey ~= nil then
			error("[jinrai.window_hints] legacy nested key 'navigation.focusBackKey' is no longer supported; use 'navigation.focusBack.key'")
		end
		if options.navigation.directionKeys ~= nil then
			error("[jinrai.window_hints] legacy nested key 'navigation.directionKeys.*' is no longer supported; use 'navigation.direction.hints.keys.*'")
		end
		if options.navigation.directHotkeys ~= nil then
			error("[jinrai.window_hints] legacy nested key 'navigation.directHotkeys.*' is no longer supported; use 'navigation.direction.direct.{modifiers,keys}'")
		end
		if options.navigation.spaceKeys ~= nil then
			error("[jinrai.window_hints] legacy nested key 'navigation.spaceKeys' is no longer supported; use 'navigation.spaces.numbers'")
		end
		if options.navigation.prevSpaceKey ~= nil then
			error("[jinrai.window_hints] legacy nested key 'navigation.prevSpaceKey' is no longer supported; use 'navigation.spaces.prev.key'")
		end
		if options.navigation.nextSpaceKey ~= nil then
			error("[jinrai.window_hints] legacy nested key 'navigation.nextSpaceKey' is no longer supported; use 'navigation.spaces.next.key'")
		end
		if options.navigation.cardinalOverlapTieThresholdPx ~= nil then
			error("[jinrai.window_hints] legacy nested key 'navigation.cardinalOverlapTieThresholdPx' is no longer supported; use 'navigation.direction.scoring.cardinalOverlapTieThresholdPx'")
		end
		if options.navigation.debugDirectionalNavigation ~= nil then
			error("[jinrai.window_hints] legacy nested key 'navigation.debugDirectionalNavigation' is no longer supported; use 'navigation.direction.scoring.debug'")
		end
		if options.navigation.swapSelectModifiers ~= nil then
			error("[jinrai.window_hints] legacy nested key 'navigation.swapSelectModifiers' is no longer supported; use 'behavior.selection.swapWindowFrame.modifiers'")
		end
	end
	if type(options.behavior) == "table" then
		if options.behavior.onSelect ~= nil then
			error("[jinrai.window_hints] legacy nested key 'behavior.onSelect' is no longer supported; use 'behavior.callbacks.onSelect'")
		end
		if options.behavior.onError ~= nil then
			error("[jinrai.window_hints] legacy nested key 'behavior.onError' is no longer supported; use 'behavior.callbacks.onError'")
		end
		if options.behavior.centerCursor ~= nil then
			error("[jinrai.window_hints] legacy nested key 'behavior.centerCursor' is no longer supported; use 'behavior.cursor.onSelect'")
		end
		if options.behavior.centerCursorOnStart ~= nil then
			error("[jinrai.window_hints] legacy nested key 'behavior.centerCursorOnStart' is no longer supported; use 'behavior.cursor.onStart'")
		end
		if options.behavior.includeOtherSpaces ~= nil then
			error("[jinrai.window_hints] legacy nested key 'behavior.includeOtherSpaces' is no longer supported; use 'behavior.candidates.includeOtherSpaces'")
		end
		if options.behavior.includeActiveWindow ~= nil then
			error("[jinrai.window_hints] legacy nested key 'behavior.includeActiveWindow' is no longer supported; use 'behavior.candidates.includeActiveWindow'")
		end
	end
	if type(options.occlusion) == "table" and options.occlusion.hint ~= nil then
		error(
			"[jinrai.window_hints] legacy nested key 'occlusion.hint.*' is no longer supported; use 'hint.occludedScale' / 'hint.state.occluded.bgColor' / 'hint.icon.state.occluded.alpha'"
		)
	end
end

function M.build(options)
	options = options or {}
	if type(options) ~= "table" then
		error("[jinrai.window_hints] options must be a table")
	end
	checkLegacyFlatKeys(options)
	checkLegacyNestedKeys(options)

	local merged = deepMerge(DEFAULT_CONFIG, options)
	if options.internal and type(options.internal) == "table" and options.internal.focusHistory ~= nil then
		merged.internal.focusHistory = options.internal.focusHistory
	end

	local directionKeys = normalizeDirectionKeys(merged.navigation.direction.hints.keys, "navigation.direction.hints.keys")
	local directionKeyLookup = buildDirectionKeyLookup(directionKeys, "navigation.direction.hints.keys")
	local directDirectionHotkeys = normalizeDirectDirectionHotkeys(merged.navigation.direction.direct)
	local focusBackKey = normalizeActionKey(merged.navigation.focusBack.key, "navigation.focusBack.key")
	local prevSpaceKey = normalizeActionKey(merged.navigation.spaces.prev.key, "navigation.spaces.prev.key")
	local nextSpaceKey = normalizeActionKey(merged.navigation.spaces.next.key, "navigation.spaces.next.key")
	local swapSelectModifiers = normalizeSelectModifiers(
		merged.behavior.selection.swapWindowFrame.modifiers,
		"behavior.selection.swapWindowFrame.modifiers"
	)
	local focusHistory = merged.internal.focusHistory
	if not focusHistory then
		focusBackKey = nil
	end

	local spaceKeys = merged.navigation.spaces.numbers and true or false

	local hintChars = normalizeHintChars(merged.hint.chars or DEFAULT_HINT_CHARS)
	local reservedHintCharLookup = buildReservedHintCharLookup(directionKeyLookup, focusBackKey, spaceKeys, prevSpaceKey, nextSpaceKey)
	hintChars = filterHintChars(hintChars, reservedHintCharLookup)
	if #hintChars == 0 then
		error("[jinrai.window_hints] no available hintChars after excluding reserved navigation keys")
	end

	local dockWindowXBlend = normalizeUnitIntervalNumber(merged.dock.windowBlend.x, "dock.windowBlend.x")
	local dockWindowYBlend = normalizeUnitIntervalNumber(merged.dock.windowBlend.y, "dock.windowBlend.y")
	local offSpaceBadgeSize = normalizePositiveNumber(merged.hint.spaceBadge.size, "hint.spaceBadge.size")
	local cardinalOverlapTieThresholdPx = normalizeNonNegativeNumber(
		merged.navigation.direction.scoring.cardinalOverlapTieThresholdPx,
		"navigation.direction.scoring.cardinalOverlapTieThresholdPx"
	)
	local hintState = merged.hint.state
	local iconState = merged.hint.icon.state
	local keyState = merged.hint.key.state
	local titleState = merged.hint.title.state
	local spaceBadgeState = merged.hint.spaceBadge.state

	return {
		hotkeyModifiers = merged.hotkey.modifiers,
		hotkeyKey = merged.hotkey.key,
		hintChars = hintChars,
		iconSize = merged.hint.icon.size,
		hintCornerRadius = merged.hint.cornerRadius,
		keyBoxSize = merged.hint.key.size,
		keyBoxMinWidth = merged.hint.key.minWidth,
		keyBoxHorizontalPadding = merged.hint.key.horizontalPadding,
		keyGap = merged.hint.key.gap,
		padding = merged.hint.padding,
		keyFontName = merged.hint.key.fontName,
		titleFontName = merged.hint.title.fontName or merged.hint.key.fontName,
		fontSize = merged.hint.key.fontSize,
		titleFontSize = merged.hint.title.fontSize,
		rowGap = merged.hint.title.rowGap,
		titleMaxSize = merged.hint.title.maxSize,
		showTitles = merged.hint.title.show,
		bgColor = resolveStateValue(hintState, "normal", "bgColor"),
		dimmedBgColor = resolveStateValue(hintState, "dimmed", "bgColor", { "normal" }),
		activeBgColor = resolveStateValue(hintState, "active", "bgColor", { "normal" }),
		offSpaceBadgeEnabled = merged.hint.spaceBadge.enabled,
		offSpaceBadgeSize = offSpaceBadgeSize,
		offSpaceBadgeFillColor = resolveStateValue(spaceBadgeState, "normal", "fillColor"),
		offSpaceBadgeStrokeColor = resolveStateValue(spaceBadgeState, "normal", "strokeColor"),
		offSpaceBadgeTextColor = resolveStateValue(spaceBadgeState, "normal", "textColor"),
		offSpaceBadgeDimmedFillColor = resolveStateValue(spaceBadgeState, "dimmed", "fillColor", { "normal" }),
		offSpaceBadgeDimmedStrokeColor = resolveStateValue(spaceBadgeState, "dimmed", "strokeColor", { "normal" }),
		offSpaceBadgeDimmedTextColor = resolveStateValue(spaceBadgeState, "dimmed", "textColor", { "normal" }),
		activeOffSpaceBadgeFillColor = resolveStateValue(spaceBadgeState, "active", "fillColor", { "normal" }),
		activeOffSpaceBadgeStrokeColor = resolveStateValue(spaceBadgeState, "active", "strokeColor", { "normal" }),
		activeOffSpaceBadgeTextColor = resolveStateValue(spaceBadgeState, "active", "textColor", { "normal" }),
		offSpaceBadgeSpaceColors = merged.hint.spaceBadge.spaceColors,
		textColor = resolveStateValue(keyState, "normal", "color"),
		dimmedTextColor = resolveStateValue(keyState, "dimmed", "color", { "normal" }),
		activeTextColor = resolveStateValue(keyState, "active", "color", { "normal" }),
		titleTextColor = resolveStateValue(titleState, "normal", "color"),
		dimmedTitleTextColor = resolveStateValue(titleState, "dimmed", "color", { "normal" }),
		activeTitleTextColor = resolveStateValue(titleState, "active", "color", { "normal" }),
		keyHighlightColor = merged.hint.key.keyHighlightColor,
		iconAlpha = resolveStateValue(iconState, "normal", "alpha"),
		dimmedIconAlpha = resolveStateValue(iconState, "dimmed", "alpha", { "normal" }),
		occludedIconAlpha = resolveStateValue(iconState, "occluded", "alpha", { "normal" }),
		activeIconAlpha = resolveStateValue(iconState, "active", "alpha", { "normal" }),
		collisionOffset = merged.hint.collisionOffset,
		showPreviewForOccluded = merged.occlusion.preview.enabled,
		previewMode = merged.occlusion.preview.mode,
		occlusionSamplingEnabled = merged.occlusion.sampling.enabled,
		occlusionSamplingBaseWidth = merged.occlusion.sampling.baseWidth,
		occlusionSamplingBaseHeight = merged.occlusion.sampling.baseHeight,
		occlusionSamplingMinCols = merged.occlusion.sampling.minCols,
		occlusionSamplingMinRows = merged.occlusion.sampling.minRows,
		occlusionSamplingMaxCols = merged.occlusion.sampling.maxCols,
		occlusionSamplingMaxRows = merged.occlusion.sampling.maxRows,
		previewWidth = merged.occlusion.preview.width,
		previewPadding = merged.occlusion.preview.padding,
		occludedScale = merged.hint.occludedScale,
		occludedBgColor = resolveStateValue(hintState, "occluded", "bgColor", { "normal" }),
		occludedPreviewAlpha = merged.occlusion.preview.alpha,
		activeOverlayColor = merged.focusedWindowHighlight.fillColor,
		activeOverlayBorderColor = merged.focusedWindowHighlight.borderColor,
		activeOverlayBorderWidth = merged.focusedWindowHighlight.borderWidth,
		activeOverlayCornerRadius = merged.focusedWindowHighlight.cornerRadius,
		hintOverlayColor = resolveHighlightStateValue(hintState, "normal", "fillColor"),
		hintOverlayBorderColor = resolveHighlightStateValue(hintState, "normal", "borderColor"),
		dimmedHintOverlayBorderColor = resolveHighlightStateValue(hintState, "dimmed", "borderColor", { "normal" }),
		hintOverlayBorderWidth = merged.hint.highlight.borderWidth,
		hintOverlayCornerRadius = merged.hint.cornerRadius,
		activeHintOverlayColor = resolveHighlightStateValue(hintState, "active", "fillColor", { "normal" }),
		activeHintOverlayBorderColor = resolveHighlightStateValue(hintState, "active", "borderColor", { "normal" }),
		dockBottomMargin = merged.dock.bottomMargin,
		dockItemGap = merged.dock.itemGap,
		dockWindowXBlend = dockWindowXBlend,
		dockWindowYBlend = dockWindowYBlend,
		appPrefixOverrides = merged.hint.prefixOverrides,
		onSelect = merged.behavior.callbacks.onSelect,
		onError = merged.behavior.callbacks.onError,
		centerCursor = merged.behavior.cursor.onSelect,
		centerCursorOnStart = merged.behavior.cursor.onStart,
		includeOtherSpaces = merged.behavior.candidates.includeOtherSpaces,
		includeActiveWindow = merged.behavior.candidates.includeActiveWindow,
		focusBackKey = focusBackKey,
		directionKeys = directionKeys,
		directionKeyLookup = directionKeyLookup,
		directDirectionHotkeys = directDirectionHotkeys,
		cardinalOverlapTieThresholdPx = cardinalOverlapTieThresholdPx,
		debugDirectionalNavigation = merged.navigation.direction.scoring.debug,
		spaceKeys = spaceKeys,
		prevSpaceKey = prevSpaceKey,
		nextSpaceKey = nextSpaceKey,
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
