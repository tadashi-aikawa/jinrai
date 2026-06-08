local M = {}

local function resourcePath(fileName)
	if not hs or not hs.spoons or not hs.spoons.resourcePath then
		error("[jinrai.window_mover] hs.spoons.resourcePath is not available")
	end

	local path = hs.spoons.resourcePath(fileName)
	if not path then
		error("[jinrai.window_mover] failed to resolve Spoon resource: " .. tostring(fileName))
	end
	return path
end

local windowMoverConfig = nil
local function loadWindowMoverConfig()
	if windowMoverConfig == nil then
		windowMoverConfig = dofile(resourcePath("window_mover_config.lua"))
	end
	return windowMoverConfig
end

local AREA_LABEL_MIN_MARGIN = 8
local AREA_LABEL_GAP = 8
local AREA_LABEL_HEIGHT = 52
local AREA_DETAIL_TEXT_SIZE = 13
local AREA_INFO_WIDTH = 420
local AREA_INFO_HEIGHT = 480
local AREA_ORDER = {
	"freeArea",
	"full",
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
}

local DIRECT_AREA_COMMAND_KEYS = {
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
}

local AREA_ORDER_LOOKUP = {}
for _, areaName in ipairs(AREA_ORDER) do
	AREA_ORDER_LOOKUP[areaName] = true
end

local function sameScreen(a, b)
	if not a or not b then
		return false
	end
	if a == b then
		return true
	end
	if a.id and b.id then
		local okA, idA = pcall(function()
			return a:id()
		end)
		local okB, idB = pcall(function()
			return b:id()
		end)
		if okA and okB and idA ~= nil and idB ~= nil then
			return idA == idB
		end
	end
	return false
end

local function sameWindow(a, b)
	if not a or not b then
		return false
	end
	if a == b then
		return true
	end
	if a.id and b.id then
		local okA, idA = pcall(function()
			return a:id()
		end)
		local okB, idB = pcall(function()
			return b:id()
		end)
		if okA and okB and idA ~= nil and idB ~= nil then
			return idA == idB
		end
	end
	return false
end

local function screenOf(win)
	if not win or not win.screen then
		return nil
	end
	local ok, screen = pcall(function()
		return win:screen()
	end)
	if not ok then
		return nil
	end
	return screen
end

local function frameOf(win)
	if not win or not win.frame then
		return nil
	end
	local ok, frame = pcall(function()
		return win:frame()
	end)
	if not ok then
		return nil
	end
	return frame
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

local function validFrame(frame)
	return frame and frame.x ~= nil and frame.y ~= nil and frame.w ~= nil and frame.h ~= nil and frame.w > 0 and frame.h > 0
end

local function cloneFrame(frame)
	if not validFrame(frame) then
		return nil
	end
	return { x = frame.x, y = frame.y, w = frame.w, h = frame.h }
end

local function intersectFrame(a, b)
	if not validFrame(a) or not validFrame(b) then
		return nil
	end
	local x1 = math.max(a.x, b.x)
	local y1 = math.max(a.y, b.y)
	local x2 = math.min(a.x + a.w, b.x + b.w)
	local y2 = math.min(a.y + a.h, b.y + b.h)
	if x2 <= x1 or y2 <= y1 then
		return nil
	end
	return { x = x1, y = y1, w = x2 - x1, h = y2 - y1 }
end

local function subtractFrame(base, occupied)
	local cut = intersectFrame(base, occupied)
	if not cut then
		return { base }
	end

	local rects = {
		{ x = base.x, y = base.y, w = base.w, h = cut.y - base.y },
		{ x = base.x, y = cut.y + cut.h, w = base.w, h = (base.y + base.h) - (cut.y + cut.h) },
		{ x = base.x, y = cut.y, w = cut.x - base.x, h = cut.h },
		{ x = cut.x + cut.w, y = cut.y, w = (base.x + base.w) - (cut.x + cut.w), h = cut.h },
	}
	local result = {}
	for _, rect in ipairs(rects) do
		if validFrame(rect) then
			table.insert(result, rect)
		end
	end
	return result
end

local function frameArea(frame)
	return frame.w * frame.h
end

local function centerDistanceSquared(a, b)
	local ax = a.x + a.w / 2
	local ay = a.y + a.h / 2
	local bx = b.x + b.w / 2
	local by = b.y + b.h / 2
	local dx = ax - bx
	local dy = ay - by
	return dx * dx + dy * dy
end

local function isBetterFreeFrame(candidate, best, currentFrame)
	if not best then
		return true
	end
	local candidateArea = frameArea(candidate)
	local bestArea = frameArea(best)
	if candidateArea ~= bestArea then
		return candidateArea > bestArea
	end
	if currentFrame then
		local candidateDistance = centerDistanceSquared(candidate, currentFrame)
		local bestDistance = centerDistanceSquared(best, currentFrame)
		if candidateDistance ~= bestDistance then
			return candidateDistance < bestDistance
		end
	end
	if candidate.y ~= best.y then
		return candidate.y < best.y
	end
	return candidate.x < best.x
end

local function freeFramesForScreen(screenFrame, occupiedFrames)
	local freeFrames = { cloneFrame(screenFrame) }
	for _, occupied in ipairs(occupiedFrames) do
		local nextFreeFrames = {}
		for _, freeFrame in ipairs(freeFrames) do
			local splitFrames = subtractFrame(freeFrame, occupied)
			for _, splitFrame in ipairs(splitFrames) do
				table.insert(nextFreeFrames, splitFrame)
			end
		end
		freeFrames = nextFreeFrames
	end
	return freeFrames
end

local function bestFreeFrame(screenFrame, occupiedFrames, currentFrame)
	local freeFrames = freeFramesForScreen(screenFrame, occupiedFrames)
	local best = nil
	for _, freeFrame in ipairs(freeFrames) do
		if isBetterFreeFrame(freeFrame, best, currentFrame) then
			best = freeFrame
		end
	end
	return best
end

local function frameKey(frame)
	return table.concat({ frame.x, frame.y, frame.w, frame.h }, ":")
end

local function nearlyEqual(a, b)
	return math.abs(a - b) <= 1
end

local function frameEquals(a, b)
	return validFrame(a)
		and validFrame(b)
		and nearlyEqual(a.x, b.x)
		and nearlyEqual(a.y, b.y)
		and nearlyEqual(a.w, b.w)
		and nearlyEqual(a.h, b.h)
end

local function frameNear(a, b, tolerance)
	return validFrame(a)
		and validFrame(b)
		and math.abs(a.x - b.x) <= tolerance
		and math.abs(a.y - b.y) <= tolerance
		and math.abs(a.w - b.w) <= tolerance
		and math.abs(a.h - b.h) <= tolerance
end

local function markUniqueFrame(seen, frame)
	local cloned = cloneFrame(frame)
	if not cloned then
		return false
	end
	local key = frameKey(cloned)
	if seen[key] then
		return false
	end
	seen[key] = true
	return true
end

local function collectInputModifiers(flags)
	local modifiers = {}
	for _, mod in ipairs({ "cmd", "alt", "ctrl", "shift", "fn" }) do
		if flags and flags[mod] then
			table.insert(modifiers, mod)
		end
	end
	return modifiers
end

local function modifierListKey(modifiers)
	return table.concat(modifiers or {}, "+")
end

local function startsWith(value, prefix)
	return string.sub(value, 1, #prefix) == prefix
end

local function pointInFrame(point, frame)
	if not point or not frame then
		return false
	end
	return point.x >= frame.x
		and point.x <= frame.x + frame.w
		and point.y >= frame.y
		and point.y <= frame.y + frame.h
end

local function cloneColor(color)
	return {
		red = color.red,
		green = color.green,
		blue = color.blue,
		alpha = color.alpha,
	}
end

local function screenUUID(screen)
	if not screen or not screen.getUUID then
		return nil
	end
	local ok, uuid = pcall(function()
		return screen:getUUID()
	end)
	if ok and uuid ~= nil then
		return tostring(uuid)
	end
	return nil
end

local function screenName(screen)
	if not screen or not screen.name then
		return nil
	end
	local ok, name = pcall(function()
		return screen:name()
	end)
	if ok then
		return name
	end
	return nil
end

local function screenID(screen)
	if not screen or not screen.id then
		return nil
	end
	local ok, id = pcall(function()
		return screen:id()
	end)
	if ok then
		return id
	end
	return nil
end

local function escapeHTML(value)
	local text = tostring(value or "")
	text = string.gsub(text, "&", "&amp;")
	text = string.gsub(text, "<", "&lt;")
	text = string.gsub(text, ">", "&gt;")
	text = string.gsub(text, '"', "&quot;")
	return text
end

local function parseFixedSizeCenterArea(areaName)
	if type(areaName) ~= "string" then
		return nil
	end
	local width, height = string.match(areaName, "^(%d+)x(%d+)Center$")
	width = tonumber(width)
	height = tonumber(height)
	if not width or not height or width <= 0 or height <= 0 then
		return nil
	end
	return width, height
end

function M.new(options)
	local config = loadWindowMoverConfig().build(options)

	local hotkeys = {}
	local areaCanvases = {}
	local areaInfoWebviews = {}
	local areaCandidates = {}
	local areaCandidateByKey = {}
	local areaCurrentInput = ""
	local areaKeyBlocker = nil
	local areaMouseClickWatcher = nil
	local areaChooserShowing = false
	local areaApplyCallback = nil
	local areaCancelCallback = nil
	local areaJinraiModeActive = false
	local areaJinraiModeContext = false
	local lastCycleState = nil

	local function selectedAreaState(active)
		local states = config.selectedAreaAppearance.state
		return active and states.normal or states.dimmed
	end

	local function selectedAreaStyle(kind)
		local styles = config.selectedAreaAppearance.styles
		return styles[kind] or styles.free
	end

	local function centerCursorOnWindow(win)
		if not config.centerCursor then
			return
		end
		local ok, frame = pcall(function()
			return win:frame()
		end)
		if ok and frame and (frame.w or 0) > 0 and (frame.h or 0) > 0 then
			hs.mouse.absolutePosition({ x = frame.x + frame.w / 2, y = frame.y + frame.h / 2 })
		end
	end

	local function activateWindow(win)
		if win.raise then
			win:raise()
		end
		if win.focus then
			win:focus()
		end
		centerCursorOnWindow(win)
	end

	local function freeAreaFrameForWindow(win, screen)
		if not win or not screen or not screen.frame or not hs or not hs.window or not hs.window.orderedWindows then
			return nil
		end
		local screenFrame = cloneFrame(screen:frame())
		if not screenFrame then
			return nil
		end
		local currentFrame = cloneFrame(frameOf(win))
		local occupiedFrames = {}
		local frontFrames = {}
		for _, otherWin in ipairs(hs.window.orderedWindows()) do
			if otherWin and not sameWindow(win, otherWin) and isStandardWindow(otherWin) then
				local otherScreen = screenOf(otherWin)
				if sameScreen(screen, otherScreen) then
					local occupiedFrame = intersectFrame(screenFrame, frameOf(otherWin))
					if occupiedFrame then
						local overlapsFrontWindow = false
						for _, frontFrame in ipairs(frontFrames) do
							if intersectFrame(occupiedFrame, frontFrame) then
								overlapsFrontWindow = true
								break
							end
						end
						if not overlapsFrontWindow then
							table.insert(occupiedFrames, occupiedFrame)
						end
						table.insert(frontFrames, occupiedFrame)
					end
				end
			end
		end
		return bestFreeFrame(screenFrame, occupiedFrames, currentFrame)
	end

	local function clearAreaChooserCanvases()
		for _, canvas in ipairs(areaCanvases) do
			canvas:delete()
		end
		areaCanvases = {}
		for _, item in ipairs(areaInfoWebviews) do
			item.webview:delete()
		end
		areaInfoWebviews = {}
		for _, candidate in ipairs(areaCandidates) do
			candidate.labelCanvas = nil
			candidate.iconElementIndices = nil
		end
	end

	local function closeAreaChooser(stopWatchers, opts)
		opts = opts or {}
		local onCancel = opts.cancel and areaCancelCallback or nil
		local onJinraiModeCancel = opts.cancel and areaJinraiModeActive and config.onJinraiModeCancel or nil
		if stopWatchers and areaKeyBlocker then
			areaKeyBlocker:stop()
		end
		if stopWatchers and areaMouseClickWatcher then
			areaMouseClickWatcher:stop()
		end
		areaChooserShowing = false
		areaCurrentInput = ""
		areaCandidateByKey = {}
		areaApplyCallback = nil
		areaCancelCallback = nil
		areaJinraiModeActive = false
		areaJinraiModeContext = false
		clearAreaChooserCanvases()
		areaCandidates = {}
		if onCancel then
			onCancel()
		end
		if onJinraiModeCancel then
			onJinraiModeCancel()
		end
	end

	local function applyAreaCandidate(candidate)
		if not candidate or not candidate.frame or not hs or not hs.window or not hs.window.focusedWindow then
			return
		end
		local win = hs.window.focusedWindow()
		if not win then
			closeAreaChooser(true, { cancel = true })
			return
		end
		local targetFrame
		if candidate.dynamicArea == "freeArea" then
			targetFrame = freeAreaFrameForWindow(win, candidate.screen)
		else
			targetFrame = cloneFrame(candidate.frame)
		end
		if not targetFrame then
			return
		end
		local onApply = areaApplyCallback
		local onJinraiModeApply = areaJinraiModeActive and config.onJinraiModeApply or nil
		closeAreaChooser(true)
		win:setFrame(targetFrame, 0)
		activateWindow(win)
		if onApply then
			onApply(win, candidate)
		end
		if onJinraiModeApply then
			onJinraiModeApply(win, candidate)
		end
	end

	local function applyActionCandidate(candidate)
		if not candidate or not candidate.action or not hs or not hs.window or not hs.window.focusedWindow then
			return
		end
		local win = hs.window.focusedWindow()
		if not win then
			closeAreaChooser(true, { cancel = true })
			return
		end
		local onApply = areaApplyCallback
		local onJinraiModeApply = areaJinraiModeActive and config.onJinraiModeApply or nil
		closeAreaChooser(true)
		if candidate.action == "closeWindow" and win.close then
			local ok = win:close()
			if not ok then
				return
			end
		else
			return
		end
		if onApply then
			onApply(win, candidate)
		end
		if onJinraiModeApply then
			onJinraiModeApply(win, candidate)
		end
	end

	local function addAreaCandidate(candidates, seenByScreen, screen, frame, kind, icon, key, detailLabel)
		if not screen or not frame then
			return
		end
		local screenId = tostring(screen:id())
		seenByScreen[screenId] = seenByScreen[screenId] or {}
		if markUniqueFrame(seenByScreen[screenId], frame) then
			table.insert(candidates, {
				screen = screen,
				screenId = screenId,
				frame = cloneFrame(frame),
				kind = kind,
				icon = icon,
				key = key,
				detailLabel = detailLabel,
			})
		end
	end

	local function addActionCandidate(candidates, screen, screenFrame, actionName, key)
		if key == nil or not screen or not screenFrame then
			return
		end
		local actionFrameWidth = math.min(240, screenFrame.w)
		local actionFrameHeight = 140
		local actionFrame = {
			x = screenFrame.x + ((screenFrame.w - actionFrameWidth) / 2),
			y = screenFrame.y + AREA_LABEL_MIN_MARGIN,
			w = actionFrameWidth,
			h = math.min(actionFrameHeight, screenFrame.h),
		}
		local detailLabels = {
			closeWindow = "Close",
		}
		table.insert(candidates, {
			screen = screen,
			screenId = tostring(screen:id()),
			frame = actionFrame,
			kind = "action",
			hiddenHint = true,
			key = key,
			detailLabel = detailLabels[actionName] or actionName,
			action = actionName,
		})
	end

	local function areaSpecForName(screenFrame, areaName)
		if areaName == "full" then
			return cloneFrame(screenFrame), "full", {
				slots = 1,
				index = 1,
				axis = "horizontal",
			}
		elseif areaName == "halfLeft" then
			return {
				x = screenFrame.x,
				y = screenFrame.y,
				w = screenFrame.w / 2,
				h = screenFrame.h,
			}, "half", { slots = 2, index = 1, axis = "horizontal" }
		elseif areaName == "halfHorizontalCenter" then
			return {
				x = screenFrame.x + (screenFrame.w / 4),
				y = screenFrame.y,
				w = screenFrame.w / 2,
				h = screenFrame.h,
			}, "half", { slots = 4, index = 2, span = 2, axis = "horizontal" }
		elseif areaName == "halfRight" then
			return {
				x = screenFrame.x + (screenFrame.w / 2),
				y = screenFrame.y,
				w = screenFrame.w / 2,
				h = screenFrame.h,
			}, "half", { slots = 2, index = 2, axis = "horizontal" }
		elseif areaName == "halfTop" then
			return {
				x = screenFrame.x,
				y = screenFrame.y,
				w = screenFrame.w,
				h = screenFrame.h / 2,
			}, "half", { slots = 2, index = 1, axis = "vertical" }
		elseif areaName == "halfVerticalCenter" then
			return {
				x = screenFrame.x,
				y = screenFrame.y + (screenFrame.h / 4),
				w = screenFrame.w,
				h = screenFrame.h / 2,
			}, "half", { slots = 4, index = 2, span = 2, axis = "vertical" }
		elseif areaName == "halfBottom" then
			return {
				x = screenFrame.x,
				y = screenFrame.y + (screenFrame.h / 2),
				w = screenFrame.w,
				h = screenFrame.h / 2,
			}, "half", { slots = 2, index = 2, axis = "vertical" }
		elseif areaName == "thirdLeft" then
			return {
				x = screenFrame.x,
				y = screenFrame.y,
				w = screenFrame.w / 3,
				h = screenFrame.h,
			}, "third", { slots = 3, index = 1, axis = "horizontal" }
		elseif areaName == "thirdHorizontalCenter" then
			return {
				x = screenFrame.x + (screenFrame.w / 3),
				y = screenFrame.y,
				w = screenFrame.w / 3,
				h = screenFrame.h,
			}, "third", { slots = 3, index = 2, axis = "horizontal" }
		elseif areaName == "thirdRight" then
			return {
				x = screenFrame.x + (screenFrame.w * 2 / 3),
				y = screenFrame.y,
				w = screenFrame.w / 3,
				h = screenFrame.h,
			}, "third", { slots = 3, index = 3, axis = "horizontal" }
		elseif areaName == "thirdTop" then
			return {
				x = screenFrame.x,
				y = screenFrame.y,
				w = screenFrame.w,
				h = screenFrame.h / 3,
			}, "third", { slots = 3, index = 1, axis = "vertical" }
		elseif areaName == "thirdVerticalCenter" then
			return {
				x = screenFrame.x,
				y = screenFrame.y + (screenFrame.h / 3),
				w = screenFrame.w,
				h = screenFrame.h / 3,
			}, "third", { slots = 3, index = 2, axis = "vertical" }
		elseif areaName == "thirdBottom" then
			return {
				x = screenFrame.x,
				y = screenFrame.y + (screenFrame.h * 2 / 3),
				w = screenFrame.w,
				h = screenFrame.h / 3,
			}, "third", { slots = 3, index = 3, axis = "vertical" }
		elseif areaName == "quarterLeft" then
			return {
				x = screenFrame.x,
				y = screenFrame.y,
				w = screenFrame.w / 4,
				h = screenFrame.h,
			}, "quarter", { slots = 4, index = 1, axis = "horizontal" }
		elseif areaName == "quarterHorizontalLeftCenter" then
			return {
				x = screenFrame.x + (screenFrame.w / 4),
				y = screenFrame.y,
				w = screenFrame.w / 4,
				h = screenFrame.h,
			}, "quarter", { slots = 4, index = 2, axis = "horizontal" }
		elseif areaName == "quarterHorizontalRightCenter" then
			return {
				x = screenFrame.x + (screenFrame.w / 2),
				y = screenFrame.y,
				w = screenFrame.w / 4,
				h = screenFrame.h,
			}, "quarter", { slots = 4, index = 3, axis = "horizontal" }
		elseif areaName == "quarterRight" then
			return {
				x = screenFrame.x + (screenFrame.w * 3 / 4),
				y = screenFrame.y,
				w = screenFrame.w / 4,
				h = screenFrame.h,
			}, "quarter", { slots = 4, index = 4, axis = "horizontal" }
		elseif areaName == "quarterTop" then
			return {
				x = screenFrame.x,
				y = screenFrame.y,
				w = screenFrame.w,
				h = screenFrame.h / 4,
			}, "quarter", { slots = 4, index = 1, axis = "vertical" }
		elseif areaName == "quarterVerticalTopCenter" then
			return {
				x = screenFrame.x,
				y = screenFrame.y + (screenFrame.h / 4),
				w = screenFrame.w,
				h = screenFrame.h / 4,
			}, "quarter", { slots = 4, index = 2, axis = "vertical" }
		elseif areaName == "quarterVerticalBottomCenter" then
			return {
				x = screenFrame.x,
				y = screenFrame.y + (screenFrame.h / 2),
				w = screenFrame.w,
				h = screenFrame.h / 4,
			}, "quarter", { slots = 4, index = 3, axis = "vertical" }
		elseif areaName == "quarterBottom" then
			return {
				x = screenFrame.x,
				y = screenFrame.y + (screenFrame.h * 3 / 4),
				w = screenFrame.w,
				h = screenFrame.h / 4,
			}, "quarter", { slots = 4, index = 4, axis = "vertical" }
		elseif areaName == "quarterTopLeft" then
			return {
				x = screenFrame.x,
				y = screenFrame.y,
				w = screenFrame.w / 2,
				h = screenFrame.h / 2,
			}, "quarter", { cols = 2, rows = 2, col = 1, row = 1 }
		elseif areaName == "quarterTopRight" then
			return {
				x = screenFrame.x + (screenFrame.w / 2),
				y = screenFrame.y,
				w = screenFrame.w / 2,
				h = screenFrame.h / 2,
			}, "quarter", { cols = 2, rows = 2, col = 2, row = 1 }
		elseif areaName == "quarterBottomLeft" then
			return {
				x = screenFrame.x,
				y = screenFrame.y + (screenFrame.h / 2),
				w = screenFrame.w / 2,
				h = screenFrame.h / 2,
			}, "quarter", { cols = 2, rows = 2, col = 1, row = 2 }
		elseif areaName == "quarterBottomRight" then
			return {
				x = screenFrame.x + (screenFrame.w / 2),
				y = screenFrame.y + (screenFrame.h / 2),
				w = screenFrame.w / 2,
				h = screenFrame.h / 2,
			}, "quarter", { cols = 2, rows = 2, col = 2, row = 2 }
		elseif areaName == "sixthTopLeft" then
			return {
				x = screenFrame.x,
				y = screenFrame.y,
				w = screenFrame.w / 3,
				h = screenFrame.h / 2,
			}, "sixth", { cols = 3, rows = 2, col = 1, row = 1 }
		elseif areaName == "sixthTopCenter" then
			return {
				x = screenFrame.x + (screenFrame.w / 3),
				y = screenFrame.y,
				w = screenFrame.w / 3,
				h = screenFrame.h / 2,
			}, "sixth", { cols = 3, rows = 2, col = 2, row = 1 }
		elseif areaName == "sixthTopRight" then
			return {
				x = screenFrame.x + (screenFrame.w * 2 / 3),
				y = screenFrame.y,
				w = screenFrame.w / 3,
				h = screenFrame.h / 2,
			}, "sixth", { cols = 3, rows = 2, col = 3, row = 1 }
		elseif areaName == "sixthBottomLeft" then
			return {
				x = screenFrame.x,
				y = screenFrame.y + (screenFrame.h / 2),
				w = screenFrame.w / 3,
				h = screenFrame.h / 2,
			}, "sixth", { cols = 3, rows = 2, col = 1, row = 2 }
		elseif areaName == "sixthBottomCenter" then
			return {
				x = screenFrame.x + (screenFrame.w / 3),
				y = screenFrame.y + (screenFrame.h / 2),
				w = screenFrame.w / 3,
				h = screenFrame.h / 2,
			}, "sixth", { cols = 3, rows = 2, col = 2, row = 2 }
		elseif areaName == "sixthBottomRight" then
			return {
				x = screenFrame.x + (screenFrame.w * 2 / 3),
				y = screenFrame.y + (screenFrame.h / 2),
				w = screenFrame.w / 3,
				h = screenFrame.h / 2,
			}, "sixth", { cols = 3, rows = 2, col = 3, row = 2 }
		elseif areaName == "twoThirdsLeft" then
			return {
				x = screenFrame.x,
				y = screenFrame.y,
				w = screenFrame.w * 2 / 3,
				h = screenFrame.h,
			}, "twoThirds", { slots = 3, index = 1, span = 2, axis = "horizontal" }
		elseif areaName == "twoThirdsHorizontalCenter" then
			return {
				x = screenFrame.x + (screenFrame.w / 6),
				y = screenFrame.y,
				w = screenFrame.w * 2 / 3,
				h = screenFrame.h,
			}, "twoThirds", { slots = 6, index = 2, span = 4, axis = "horizontal" }
		elseif areaName == "twoThirdsRight" then
			return {
				x = screenFrame.x + (screenFrame.w / 3),
				y = screenFrame.y,
				w = screenFrame.w * 2 / 3,
				h = screenFrame.h,
			}, "twoThirds", { slots = 3, index = 2, span = 2, axis = "horizontal" }
		elseif areaName == "twoThirdsTop" then
			return {
				x = screenFrame.x,
				y = screenFrame.y,
				w = screenFrame.w,
				h = screenFrame.h * 2 / 3,
			}, "twoThirds", { slots = 3, index = 1, span = 2, axis = "vertical" }
		elseif areaName == "twoThirdsVerticalCenter" then
			return {
				x = screenFrame.x,
				y = screenFrame.y + (screenFrame.h / 6),
				w = screenFrame.w,
				h = screenFrame.h * 2 / 3,
			}, "twoThirds", { slots = 6, index = 2, span = 4, axis = "vertical" }
		elseif areaName == "twoThirdsBottom" then
			return {
				x = screenFrame.x,
				y = screenFrame.y + (screenFrame.h / 3),
				w = screenFrame.w,
				h = screenFrame.h * 2 / 3,
			}, "twoThirds", { slots = 3, index = 2, span = 2, axis = "vertical" }
		else
			local width, height = parseFixedSizeCenterArea(areaName)
			if width and height then
				width = math.min(width, screenFrame.w)
				height = math.min(height, screenFrame.h)
				return {
					x = screenFrame.x + ((screenFrame.w - width) / 2),
					y = screenFrame.y + ((screenFrame.h - height) / 2),
					w = width,
					h = height,
				}, "free", { free = true }, areaName:match("^(%d+x%d+)Center$")
			end
		end
	end

	local function addConfiguredAreaCandidate(candidates, seenByScreen, screen, screenFrame, areaName, key)
		if key == nil then
			return
		end
		if areaName == "freeArea" then
			table.insert(candidates, {
				screen = screen,
				screenId = tostring(screen:id()),
				frame = cloneFrame(screenFrame),
				kind = "free",
				icon = { free = true },
				key = key,
				detailLabel = "Free",
				dynamicArea = "freeArea",
				fixedHintPosition = "topRight",
			})
			return
		end
		local frame, kind, icon, detailLabel = areaSpecForName(screenFrame, areaName)
		addAreaCandidate(candidates, seenByScreen, screen, frame, kind, icon, key, detailLabel)
	end

	local function areaMapConflictsWithKeys(areaMap, usedKeys)
		for _, key in pairs(areaMap) do
			local lookupKey = string.lower(key)
			for usedKey, _ in pairs(usedKeys) do
				if startsWith(usedKey, lookupKey) or startsWith(lookupKey, usedKey) then
					return true
				end
			end
		end
		return false
	end

	local function markAreaMapKeys(areaMap, usedKeys)
		for _, key in pairs(areaMap) do
			usedKeys[string.lower(key)] = true
		end
	end

	local function collectAreaCandidates()
		if not hs or not hs.screen or not hs.screen.allScreens then
			return {}, {}
		end
		local candidates = {}
		local screensWithoutCandidates = {}
		local seenByScreen = {}
		local usedKeys = {}

		for _, screen in ipairs(hs.screen.allScreens()) do
			local screenFrame = screen and screen.frame and cloneFrame(screen:frame())
			if screenFrame then
				local uuid = screenUUID(screen)
				local areaMap = uuid and config.selectedAreaScreens[uuid] or nil
				local usingDefault = false
				if areaMap == nil and config.selectedAreaDefault ~= nil then
					areaMap = config.selectedAreaScreens[config.selectedAreaDefault]
					usingDefault = true
				end
				if areaMap ~= nil and not (usingDefault and areaMapConflictsWithKeys(areaMap, usedKeys)) then
					local beforeCount = #candidates
					for _, areaName in ipairs(AREA_ORDER) do
						local key = areaMap[areaName]
						addConfiguredAreaCandidate(candidates, seenByScreen, screen, screenFrame, areaName, key)
					end
					local extraAreaNames = {}
					for areaName, _ in pairs(areaMap) do
						if not AREA_ORDER_LOOKUP[areaName] then
							table.insert(extraAreaNames, areaName)
						end
					end
					table.sort(extraAreaNames)
					for _, areaName in ipairs(extraAreaNames) do
						addConfiguredAreaCandidate(candidates, seenByScreen, screen, screenFrame, areaName, areaMap[areaName])
					end
					if #candidates > beforeCount then
						markAreaMapKeys(areaMap, usedKeys)
					else
						table.insert(screensWithoutCandidates, { screen = screen, uuid = uuid, frame = screenFrame })
					end
				else
					table.insert(screensWithoutCandidates, { screen = screen, uuid = uuid, frame = screenFrame })
				end
			end
		end

		local activeScreen = nil
		local activeWindow = hs.window and hs.window.focusedWindow and hs.window.focusedWindow() or nil
		if activeWindow then
			activeScreen = screenOf(activeWindow)
		end
		if activeScreen and activeScreen.frame then
			local activeScreenFrame = cloneFrame(activeScreen:frame())
			for actionName, key in pairs(config.selectedAreaActions or {}) do
				addActionCandidate(candidates, activeScreen, activeScreenFrame, actionName, key)
			end
		end

		return candidates, screensWithoutCandidates
	end

	local function updateAreaCandidateActiveState()
		for _, candidate in ipairs(areaCandidates) do
			local active = areaCurrentInput == "" or startsWith(candidate.key, areaCurrentInput)
			local state = selectedAreaState(active)
			local style = selectedAreaStyle(candidate.kind)
			local color = active and style.color or style.dimmedColor
			if candidate.labelCanvas then
				local labelColor = cloneColor(color)
				candidate.labelCanvas[1].fillColor = cloneColor(state.bgColor)
				candidate.labelCanvas[2].strokeColor = labelColor
				local keyLen = #candidate.key
				local prefixLen = 0
				if active and areaCurrentInput ~= "" and startsWith(candidate.key, areaCurrentInput) then
					prefixLen = math.min(#areaCurrentInput, keyLen)
				end
				local prefixStr = string.sub(candidate.key, 1, prefixLen)
				local restStr = string.sub(candidate.key, prefixLen + 1)
				local typedColor = state.typedTextColor or state.textColor
				candidate.labelCanvas[candidate.keyTextIdx].text = hs.styledtext.new(prefixStr, {
					font = { size = 26 },
					color = cloneColor(typedColor),
				}) .. hs.styledtext.new(restStr, {
					font = { size = 26 },
					color = cloneColor(state.textColor),
				})
				if candidate.detailTextIdx then
					candidate.labelCanvas[candidate.detailTextIdx].text = hs.styledtext.new(candidate.detailLabel, {
						font = { size = AREA_DETAIL_TEXT_SIZE },
						color = cloneColor(state.textColor),
					})
				end
				for _, idx in ipairs(candidate.iconElementIndices or {}) do
					if candidate.labelCanvas[idx].fillColor then
						candidate.labelCanvas[idx].fillColor = cloneColor(color)
					end
					if candidate.labelCanvas[idx].strokeColor then
						candidate.labelCanvas[idx].strokeColor = labelColor
					end
				end
			end
		end
	end

	local function hasAreaCandidateAtPoint(point)
		for _, candidate in ipairs(areaCandidates) do
			local hitFrame = candidate.fixedHintPosition and candidate.labelAbsoluteFrame or candidate.frame
			if pointInFrame(point, hitFrame) then
				return true
			end
		end
		return false
	end

	local function areaInfoAtPoint(point)
		for _, item in ipairs(areaInfoWebviews) do
			if pointInFrame(point, item.frame) then
				return item
			end
		end
		return nil
	end

	local function eventLocation(event)
		if event and event.location then
			local ok, point = pcall(function()
				return event:location()
			end)
			if ok and point then
				return point
			end
		end
		return hs.mouse.absolutePosition()
	end

	local function ensureAreaKeyBlocker()
		if areaKeyBlocker then
			return
		end
		areaKeyBlocker = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
			local keyCode = event:getKeyCode()
			local key = hs.keycodes.map[keyCode]
			local modifiers = collectInputModifiers(event:getFlags())

			if config.selectedAreaWindowHintsKey and key == config.selectedAreaWindowHintsKey then
				local onOpenWindowHints = config.onOpenWindowHints
				local jinraiMode = areaJinraiModeContext or areaJinraiModeActive
				closeAreaChooser(true)
				if onOpenWindowHints then
					onOpenWindowHints({ jinraiMode = jinraiMode })
				end
				return true
			end

			if config.jinraiModeKey and key == config.jinraiModeKey then
				areaJinraiModeActive = true
				areaJinraiModeContext = true
				areaCurrentInput = ""
				if config.onJinraiModeStart then
					config.onJinraiModeStart()
				end
				updateAreaCandidateActiveState()
				return true
			end

			if
				key == config.openWindowActionChooserHotkeyKey
				and modifierListKey(modifiers) == modifierListKey(config.openWindowActionChooserHotkeyModifiers)
			then
				closeAreaChooser(true, { cancel = true })
				return true
			end
			if
				key == config.openJinraiModeWindowActionChooserHotkeyKey
				and modifierListKey(modifiers) == modifierListKey(config.openJinraiModeWindowActionChooserHotkeyModifiers)
			then
				closeAreaChooser(true, { cancel = true })
				return true
			end

			if key == "escape" then
				closeAreaChooser(true, { cancel = true })
				return true
			end
			if key == "delete" or key == "forwarddelete" then
				if #areaCurrentInput > 0 then
					areaCurrentInput = string.sub(areaCurrentInput, 1, #areaCurrentInput - 1)
					updateAreaCandidateActiveState()
				end
				return true
			end

			local hintChar = key and string.upper(key)
			if not hintChar or #hintChar ~= 1 then
				return true
			end

			areaCurrentInput = areaCurrentInput .. hintChar
			local exact = areaCandidateByKey[areaCurrentInput]
			if exact then
				if exact.action then
					applyActionCandidate(exact)
				else
					applyAreaCandidate(exact)
				end
				return true
			end

			local hasPrefix = false
			for areaKey, _ in pairs(areaCandidateByKey) do
				if startsWith(areaKey, areaCurrentInput) then
					hasPrefix = true
					break
				end
			end
			if hasPrefix then
				updateAreaCandidateActiveState()
				return true
			end

			areaCurrentInput = hintChar
			if areaCandidateByKey[areaCurrentInput] then
				local candidate = areaCandidateByKey[areaCurrentInput]
				if candidate.action then
					applyActionCandidate(candidate)
				else
					applyAreaCandidate(candidate)
				end
				return true
			end
			updateAreaCandidateActiveState()
			return true
		end)
	end

	local function ensureAreaMouseClickWatcher()
		if areaMouseClickWatcher then
			return
		end
		areaMouseClickWatcher = hs.eventtap.new({ hs.eventtap.event.types.leftMouseDown }, function(event)
			if not areaChooserShowing then
				return false
			end
			local point = eventLocation(event)
			if areaInfoAtPoint(point) then
				return false
			end
			if config.selectedAreaHintsShow and hasAreaCandidateAtPoint(point) then
				return true
			end
			closeAreaChooser(true, { cancel = true })
			return true
		end)
	end

	local function appendAreaIconElements(canvas, candidate, color, startIndex, iconX)
		local nextIdx = startIndex
		local iconElementIndices = {}
		local function appendIconElement(element)
			canvas[nextIdx] = element
			table.insert(iconElementIndices, nextIdx)
			nextIdx = nextIdx + 1
		end

		local outlineFrame = { x = iconX, y = 11, w = 38, h = 30 }
		appendIconElement({
			type = "rectangle",
			action = "stroke",
			strokeColor = cloneColor(color),
			strokeWidth = 2,
			roundedRectRadii = { xRadius = 3, yRadius = 3 },
			frame = outlineFrame,
		})

		local icon = candidate.icon or {}
		if icon.free then
			local dotSize = 5
			local dots = {
				{ x = outlineFrame.x + 6, y = outlineFrame.y + 6 },
				{ x = outlineFrame.x + outlineFrame.w - 11, y = outlineFrame.y + 6 },
				{ x = outlineFrame.x + 6, y = outlineFrame.y + outlineFrame.h - 11 },
				{ x = outlineFrame.x + outlineFrame.w - 11, y = outlineFrame.y + outlineFrame.h - 11 },
			}
			for _, dot in ipairs(dots) do
				appendIconElement({
					type = "rectangle",
					action = "fill",
					fillColor = cloneColor(color),
					roundedRectRadii = { xRadius = dotSize / 2, yRadius = dotSize / 2 },
					frame = { x = dot.x, y = dot.y, w = dotSize, h = dotSize },
				})
			end
			return nextIdx, iconElementIndices
		end

		local slots = icon.slots or 1
		local index = icon.index or 1
		local span = icon.span or 1
		local gap = 2
		local inner = {
			x = outlineFrame.x + 5,
			y = outlineFrame.y + 5,
			w = outlineFrame.w - 10,
			h = outlineFrame.h - 10,
		}
		local fillFrame
		if icon.cols and icon.rows and icon.col and icon.row then
			local slotW = (inner.w - (gap * (icon.cols - 1))) / icon.cols
			local slotH = (inner.h - (gap * (icon.rows - 1))) / icon.rows
			fillFrame = {
				x = inner.x + ((slotW + gap) * (icon.col - 1)),
				y = inner.y + ((slotH + gap) * (icon.row - 1)),
				w = slotW,
				h = slotH,
			}
		elseif icon.axis == "vertical" then
			local slotH = (inner.h - (gap * (slots - 1))) / slots
			local fillH = (slotH * span) + (gap * (span - 1))
			fillFrame = {
				x = inner.x,
				y = inner.y + ((slotH + gap) * (index - 1)),
				w = inner.w,
				h = fillH,
			}
		else
			local slotW = (inner.w - (gap * (slots - 1))) / slots
			local fillW = (slotW * span) + (gap * (span - 1))
			fillFrame = {
				x = inner.x + ((slotW + gap) * (index - 1)),
				y = inner.y,
				w = fillW,
				h = inner.h,
			}
		end
		appendIconElement({
			type = "rectangle",
			action = "fill",
			fillColor = cloneColor(color),
			roundedRectRadii = { xRadius = 2, yRadius = 2 },
			frame = fillFrame,
		})
		return nextIdx, iconElementIndices
	end

	local function areaHintKeyWidth(key)
		return math.max(30, #key * 22)
	end

	local function areaDetailTextWidth(text)
		return math.max(64, #tostring(text or "") * 8)
	end

	local function areaLabelFrameForCandidate(candidate)
		local frame = candidate.frame
		local labelW = 9 + areaHintKeyWidth(candidate.key) + 5 + 38 + 10
		if candidate.detailLabel then
			labelW = math.max(labelW, areaDetailTextWidth(candidate.detailLabel) + 12)
		end
		local labelH = candidate.detailLabel and 66 or AREA_LABEL_HEIGHT
		if candidate.fixedHintPosition == "topRight" then
			return {
				x = frame.w - labelW - AREA_LABEL_MIN_MARGIN,
				y = AREA_LABEL_MIN_MARGIN,
				w = labelW,
				h = labelH,
			}
		end
		local icon = candidate.icon or {}
		local labelY
		if icon.rows and icon.row then
			local areaCenter = (icon.row - 0.5) / icon.rows
			labelY = (frame.h - labelH) * areaCenter
		elseif icon.axis == "vertical" and icon.slots and icon.index then
			local slotCenter = (icon.index - 0.5) / icon.slots
			local areaCenter = slotCenter
			if icon.span and icon.span > 1 then
				areaCenter = (icon.index - 1 + (icon.span / 2)) / icon.slots
			end
			labelY = (frame.h - labelH) * areaCenter
		else
			local labelOffsetYByKind = {
				full = -72,
				half = -28,
				third = 28,
				quarter = 52,
				sixth = 64,
				free = 72,
			}
			labelY = ((frame.h - labelH) / 2) + (labelOffsetYByKind[candidate.kind] or 0)
		end
		labelY = math.max(AREA_LABEL_MIN_MARGIN, math.min(frame.h - labelH - AREA_LABEL_MIN_MARGIN, labelY))
		return {
			x = (frame.w - labelW) / 2,
			y = labelY,
			w = labelW,
			h = labelH,
		}
	end

	local function framesOverlapHorizontally(a, b)
		return a.x < b.x + b.w and b.x < a.x + a.w
	end

	local function buildHorizontalLabelGroups(screenCandidates)
		local groups = {}
		for _, candidate in ipairs(screenCandidates) do
			local matchingGroupIndexes = {}
			for groupIndex, group in ipairs(groups) do
				for _, grouped in ipairs(group) do
					if framesOverlapHorizontally(candidate.labelAbsoluteFrame, grouped.labelAbsoluteFrame) then
						table.insert(matchingGroupIndexes, groupIndex)
						break
					end
				end
			end

			if #matchingGroupIndexes == 0 then
				table.insert(groups, { candidate })
			else
				local targetGroup = groups[matchingGroupIndexes[1]]
				table.insert(targetGroup, candidate)
				for i = #matchingGroupIndexes, 2, -1 do
					local groupIndex = matchingGroupIndexes[i]
					for _, grouped in ipairs(groups[groupIndex]) do
						table.insert(targetGroup, grouped)
					end
					table.remove(groups, groupIndex)
				end
			end
		end
		return groups
	end

	local function sortAreaLabelGroup(group)
		table.sort(group, function(a, b)
			if a.fixedHintPosition ~= b.fixedHintPosition then
				return a.fixedHintPosition ~= nil
			end
			if a.labelAbsoluteFrame.y ~= b.labelAbsoluteFrame.y then
				return a.labelAbsoluteFrame.y < b.labelAbsoluteFrame.y
			end
			if a.labelAbsoluteFrame.x ~= b.labelAbsoluteFrame.x then
				return a.labelAbsoluteFrame.x < b.labelAbsoluteFrame.x
			end
			return a.key < b.key
		end)
	end

	local function resolveAreaLabelGroupY(group, screenFrame)
		sortAreaLabelGroup(group)
		if screenFrame then
			local minY = screenFrame.y + AREA_LABEL_MIN_MARGIN
			local maxBottom = screenFrame.y + screenFrame.h - AREA_LABEL_MIN_MARGIN
			local nextY = minY
			for _, candidate in ipairs(group) do
				if not candidate.fixedHintPosition then
					candidate.labelAbsoluteFrame.y = math.max(candidate.labelAbsoluteFrame.y, nextY)
				end
				nextY = candidate.labelAbsoluteFrame.y + candidate.labelAbsoluteFrame.h + AREA_LABEL_GAP
			end

			local top = group[1].labelAbsoluteFrame.y
			local bottom = group[#group].labelAbsoluteFrame.y + group[#group].labelAbsoluteFrame.h
			local shift = math.max(0, bottom - maxBottom)
			shift = math.min(shift, math.max(0, top - minY))
			if shift > 0 and not group[1].fixedHintPosition then
				for _, candidate in ipairs(group) do
					candidate.labelAbsoluteFrame.y = candidate.labelAbsoluteFrame.y - shift
				end
			end
			return
		end

		local nextY = nil
		for _, candidate in ipairs(group) do
			if nextY then
				candidate.labelAbsoluteFrame.y = math.max(candidate.labelAbsoluteFrame.y, nextY)
			end
			nextY = candidate.labelAbsoluteFrame.y + candidate.labelAbsoluteFrame.h + AREA_LABEL_GAP
		end
	end

	local function resolveAreaLabelFrames(candidates)
		local byScreen = {}
		for _, candidate in ipairs(candidates) do
			local labelFrame = areaLabelFrameForCandidate(candidate)
			candidate.labelFrame = labelFrame
			local absoluteFrame = {
				x = candidate.frame.x + labelFrame.x,
				y = candidate.frame.y + labelFrame.y,
				w = labelFrame.w,
				h = labelFrame.h,
			}
			candidate.labelAbsoluteFrame = absoluteFrame
			byScreen[candidate.screenId] = byScreen[candidate.screenId] or {}
			table.insert(byScreen[candidate.screenId], candidate)
		end

		for _, screenCandidates in pairs(byScreen) do
			local screenFrame = screenCandidates[1]
				and screenCandidates[1].screen
				and screenCandidates[1].screen.frame
				and screenCandidates[1].screen:frame()
			for _, group in ipairs(buildHorizontalLabelGroups(screenCandidates)) do
				resolveAreaLabelGroupY(group, screenFrame)
			end

			for _, candidate in ipairs(screenCandidates) do
				candidate.labelFrame.y = candidate.labelAbsoluteFrame.y - candidate.frame.y
			end
		end
	end

	local function showAreaCandidates(candidates)
		local visibleCandidates = {}
		for _, candidate in ipairs(candidates) do
			if not candidate.hiddenHint then
				table.insert(visibleCandidates, candidate)
			end
		end
		resolveAreaLabelFrames(visibleCandidates)
		for _, candidate in ipairs(visibleCandidates) do
			local frame = candidate.frame
			local labelFrame = candidate.labelFrame
			local appearance = config.selectedAreaAppearance
			local state = selectedAreaState(true)
			local style = selectedAreaStyle(candidate.kind)
				local canvas = hs.canvas
					.new({ x = frame.x + labelFrame.x, y = frame.y + labelFrame.y, w = labelFrame.w, h = labelFrame.h })
					:level(hs.canvas.windowLevels.overlay + 2)
				:behavior({ "canJoinAllSpaces", "stationary", "ignoresCycle" })
			canvas[1] = {
				type = "rectangle",
				action = "fill",
				fillColor = cloneColor(state.bgColor),
				roundedRectRadii = { xRadius = appearance.cornerRadius, yRadius = appearance.cornerRadius },
				frame = { x = 0, y = 0, w = labelFrame.w, h = labelFrame.h },
			}
			canvas[2] = {
				type = "rectangle",
				action = "stroke",
				strokeColor = cloneColor(style.color),
				strokeWidth = appearance.borderWidth,
				roundedRectRadii = { xRadius = appearance.cornerRadius, yRadius = appearance.cornerRadius },
				frame = {
					x = appearance.borderWidth / 2,
					y = appearance.borderWidth / 2,
					w = labelFrame.w - appearance.borderWidth,
					h = labelFrame.h - appearance.borderWidth,
				},
			}
			local keyW = areaHintKeyWidth(candidate.key)
			canvas[3] = {
				type = "text",
				text = hs.styledtext.new(candidate.key, { font = { size = 26 }, color = cloneColor(state.textColor) }),
				textFont = nil,
				textSize = 26,
				textAlignment = "center",
				frame = { x = 9, y = 9, w = keyW, h = AREA_LABEL_HEIGHT - 9 },
			}
			local nextIdx, iconElementIndices =
				appendAreaIconElements(canvas, candidate, style.color, 4, 9 + keyW + 5)
			if candidate.detailLabel then
				canvas[nextIdx] = {
					type = "text",
					text = hs.styledtext.new(candidate.detailLabel, {
						font = { size = AREA_DETAIL_TEXT_SIZE },
						color = cloneColor(state.textColor),
					}),
					textFont = nil,
					textSize = AREA_DETAIL_TEXT_SIZE,
					textAlignment = "center",
					frame = {
						x = (labelFrame.w - areaDetailTextWidth(candidate.detailLabel)) / 2,
						y = 47,
						w = areaDetailTextWidth(candidate.detailLabel),
						h = 16,
					},
				}
				candidate.detailTextIdx = nextIdx
				nextIdx = nextIdx + 1
			end
			candidate.iconElementIndices = iconElementIndices
			candidate.keyTextIdx = 3
			canvas:show()
			candidate.labelCanvas = canvas
			table.insert(areaCanvases, canvas)
		end
	end

	local function screenInfoText(screen, uuid, frame)
		local lines = {
			"-- Add this under selectedArea.screens",
			"-- name: " .. tostring(screenName(screen) or ""),
			"-- id: " .. tostring(screenID(screen) or ""),
			"-- frame: x="
				.. tostring(frame.x)
				.. ", y="
				.. tostring(frame.y)
				.. ", w="
				.. tostring(frame.w)
				.. ", h="
				.. tostring(frame.h),
			'["' .. tostring(uuid or "") .. '"] = {',
			'  freeArea = "V",',
			'  full = "A",',
			'  halfLeft = "S",',
			'  halfHorizontalCenter = "D",',
			'  halfRight = "F",',
			'  halfTop = "Q",',
			'  halfVerticalCenter = "W",',
			'  halfBottom = "E",',
			'  thirdLeft = "J",',
			'  thirdHorizontalCenter = "K",',
			'  thirdRight = "L",',
			'  thirdTop = "U",',
			'  thirdVerticalCenter = "I",',
			'  thirdBottom = "O",',
			'  quarterLeft = "1",',
			'  quarterHorizontalLeftCenter = "2",',
			'  quarterHorizontalRightCenter = "3",',
			'  quarterRight = "4",',
			'  quarterTop = "5",',
			'  quarterVerticalTopCenter = "6",',
			'  quarterVerticalBottomCenter = "7",',
			'  quarterBottom = "8",',
			'  twoThirdsLeft = "R1",',
			'  twoThirdsHorizontalCenter = "R2",',
			'  twoThirdsRight = "R3",',
			'  twoThirdsTop = "T1",',
			'  twoThirdsVerticalCenter = "T2",',
			'  twoThirdsBottom = "T3",',
			'  ["1920x1080Center"] = "M",',
			"},",
		}
		return table.concat(lines, "\n")
	end

	local function showAreaInfoScreens(items)
		if not hs.webview then
			return
		end
		for _, item in ipairs(items) do
			local screenFrame = item.frame
			local width = math.min(AREA_INFO_WIDTH, math.max(260, screenFrame.w - (AREA_LABEL_MIN_MARGIN * 2)))
			local height = math.min(AREA_INFO_HEIGHT, math.max(180, screenFrame.h - (AREA_LABEL_MIN_MARGIN * 2)))
			local frame = {
				x = screenFrame.x + (screenFrame.w - width) / 2,
				y = screenFrame.y + (screenFrame.h - height) / 2,
				w = width,
				h = height,
			}
			local html = [[
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<style>
html, body {
  margin: 0;
  width: 100%;
  height: 100%;
  background: #111318;
  color: #f4f6f8;
  font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
}
.wrap {
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
  gap: 10px;
  width: 100%;
  height: 100%;
  padding: 14px;
}
.title {
  font-size: 14px;
  font-weight: 700;
}
.text {
  color: #b7bec8;
  font-size: 12px;
  line-height: 1.35;
}
textarea {
  box-sizing: border-box;
  flex: 1;
  width: 100%;
  resize: none;
  border: 1px solid #3d4654;
  border-radius: 6px;
  padding: 10px;
  background: #080a0d;
  color: #f4f6f8;
  font: 12px Menlo, Monaco, monospace;
}
.actions {
  display: flex;
  align-items: center;
  gap: 8px;
}
button {
  border: 1px solid #566171;
  border-radius: 6px;
  padding: 7px 12px;
  background: #2e7dd7;
  color: #ffffff;
  font: 600 12px -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
}
button:active {
  background: #2469b8;
}
.status {
  min-width: 48px;
  color: #7dd3a8;
  font-size: 12px;
}
</style>
</head>
<body>
<div class="wrap">
  <div class="title">JINRAI selectedArea is not configured for this display</div>
  <div class="text">Copy the template below and add it to your config.</div>
  <textarea id="template" readonly>]] .. escapeHTML(screenInfoText(item.screen, item.uuid, screenFrame)) .. [[</textarea>
  <div class="actions">
    <button id="copy" type="button">Copy template</button>
    <span id="status" class="status" aria-live="polite"></span>
  </div>
</div>
<script>
(function () {
  var button = document.getElementById("copy");
  var status = document.getElementById("status");
  var template = document.getElementById("template");
  function setStatus(text) {
    status.textContent = text;
    if (text) {
      window.setTimeout(function () { status.textContent = ""; }, 1400);
    }
  }
  button.addEventListener("click", function () {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.jinraiCopyTemplate) {
      window.webkit.messageHandlers.jinraiCopyTemplate.postMessage(template.value);
      setStatus("Copied");
    } else {
      template.focus();
      template.select();
      setStatus("Select text");
    }
  });
})();
</script>
</body>
</html>
]]
			local usercontent
			if hs.webview.usercontent and hs.webview.usercontent.new and hs.pasteboard and hs.pasteboard.writeObjects then
				usercontent = hs.webview.usercontent.new("jinraiCopyTemplate")
				usercontent:setCallback(function(message)
					local text = message
					if type(message) == "table" then
						text = message.body or message.message or message.value
					end
					if type(text) == "string" then
						hs.pasteboard.writeObjects(text)
					end
				end)
			end
			local webview
			if hs.webview.newBrowser then
				webview = usercontent and hs.webview.newBrowser(frame, usercontent):html(html) or hs.webview.newBrowser(frame):html(html)
			else
				webview = (
					usercontent and hs.webview.new(frame, usercontent) or hs.webview.new(frame)
				):allowTextEntry(true):windowStyle(15):html(html)
			end
			if webview.level then
				webview:level(hs.canvas.windowLevels.overlay)
			end
			webview:show()
			table.insert(areaInfoWebviews, { webview = webview, frame = frame, usercontent = usercontent })
		end
	end

	local function openWindowActionChooser(options)
		if areaChooserShowing then
			closeAreaChooser(true, { cancel = true })
			return
		end
		if
			not hs
			or not hs.window
			or not hs.window.focusedWindow
			or not hs.screen
			or not hs.screen.allScreens
			or not hs.canvas
			or not hs.eventtap
			or not hs.keycodes
		then
			return
		end
		local win = hs.window.focusedWindow()
		if not win then
			return
		end
		options = options or {}
		local startJinraiMode = options.startJinraiMode == true
		areaApplyCallback = options.onApply
		areaCancelCallback = options.onCancel
		areaJinraiModeActive = false
		areaJinraiModeContext = options.jinraiMode == true

		ensureAreaKeyBlocker()
		ensureAreaMouseClickWatcher()
		areaKeyBlocker:start()
		areaMouseClickWatcher:start()

		local screensWithoutCandidates
		areaCandidates, screensWithoutCandidates = collectAreaCandidates()
		areaCandidateByKey = {}
		areaCurrentInput = ""
		for _, candidate in ipairs(areaCandidates) do
			areaCandidateByKey[candidate.key] = candidate
		end
		if #areaCandidates == 0 and #screensWithoutCandidates == 0 then
			closeAreaChooser(true, { cancel = true })
			return
		end

		areaChooserShowing = true
		if startJinraiMode then
			areaJinraiModeActive = true
			areaJinraiModeContext = true
		end
		if areaJinraiModeActive and config.onJinraiModeStart then
			config.onJinraiModeStart()
		end
		if config.selectedAreaHintsShow then
			showAreaCandidates(areaCandidates)
		end
		showAreaInfoScreens(screensWithoutCandidates)
	end

	local function openJinraiModeWindowActionChooser()
		openWindowActionChooser({ startJinraiMode = true })
	end

	local function moveToNextDisplay()
		if not hs or not hs.window or not hs.window.focusedWindow then
			return
		end
		local win = hs.window.focusedWindow()
		if not win or not win.screen then
			return
		end
		local currentScreen = screenOf(win)
		if not currentScreen or not currentScreen.next then
			return
		end
		local targetScreen = currentScreen:next()
		if not targetScreen or sameScreen(currentScreen, targetScreen) or not targetScreen.frame then
			return
		end

		local targetFrame = targetScreen:frame()
		if not targetFrame then
			return
		end
		win:setFrame(targetFrame, 0)
		activateWindow(win)
	end

	local function moveToActiveDisplayFreeArea()
		if not hs or not hs.window or not hs.window.focusedWindow or not hs.window.orderedWindows then
			return
		end
		local win = hs.window.focusedWindow()
		if not win or not win.screen or not win.frame then
			return
		end
		local screen = screenOf(win)
		if not screen or not screen.frame then
			return
		end
		local targetFrame = freeAreaFrameForWindow(win, screen)
		if not targetFrame then
			return
		end
		win:setFrame(targetFrame, 0)
		activateWindow(win)
	end

	local function minimizeWindow()
		if not hs or not hs.window or not hs.window.focusedWindow then
			return
		end
		local win = hs.window.focusedWindow()
		if not win or not win.minimize then
			return
		end
		win:minimize()
	end

	local function maximizeWindow()
		if not hs or not hs.window or not hs.window.focusedWindow then
			return
		end
		local win = hs.window.focusedWindow()
		if not win then
			return
		end
		local screen = screenOf(win)
		if not screen or not screen.frame or not win.setFrame then
			return
		end
		local targetFrame = cloneFrame(screen:frame())
		if not targetFrame then
			return
		end
		win:setFrame(targetFrame, 0)
		activateWindow(win)
	end

	local function cycleFrameForPosition(screenFrame, direction, position, ratio)
		if direction == "vertical" then
			local height = screenFrame.h * ratio
			local y = screenFrame.y
			if position == "verticalCenter" then
				y = screenFrame.y + ((screenFrame.h - height) / 2)
			elseif position == "bottom" then
				y = screenFrame.y + screenFrame.h - height
			end
			return {
				x = screenFrame.x,
				y = y,
				w = screenFrame.w,
				h = height,
			}
		end

		local width = screenFrame.w * ratio
		local x = screenFrame.x
		if position == "center" then
			x = screenFrame.x + ((screenFrame.w - width) / 2)
		elseif position == "right" then
			x = screenFrame.x + screenFrame.w - width
		end
		return {
			x = x,
			y = screenFrame.y,
			w = width,
			h = screenFrame.h,
		}
	end

	local function cycleWindow(direction, position)
		if not hs or not hs.window or not hs.window.focusedWindow then
			return
		end
		local win = hs.window.focusedWindow()
		if not win or not win.setFrame then
			return
		end
		local screen = screenOf(win)
		if not screen or not screen.frame then
			return
		end
		local screenFrame = cloneFrame(screen:frame())
		local currentFrame = cloneFrame(frameOf(win))
		if not screenFrame or not currentFrame then
			return
		end

		local ratios = direction == "vertical" and config.cycleVerticalRatios or config.cycleHorizontalRatios
		local nextIndex = 1
		local matched = false
		for index, ratio in ipairs(ratios) do
			local candidateFrame = cycleFrameForPosition(screenFrame, direction, position, ratio)
			if frameEquals(currentFrame, candidateFrame) then
				nextIndex = (index % #ratios) + 1
				matched = true
				break
			end
		end
		if
			not matched
			and lastCycleState
			and sameWindow(win, lastCycleState.window)
			and sameScreen(screen, lastCycleState.screen)
			and direction == lastCycleState.direction
			and position == lastCycleState.position
			and frameNear(currentFrame, lastCycleState.appliedFrame, 16)
			and lastCycleState.ratioIndex <= #ratios
			and ratios[lastCycleState.ratioIndex] == lastCycleState.ratio
		then
			nextIndex = (lastCycleState.ratioIndex % #ratios) + 1
		end

		local targetFrame = cycleFrameForPosition(screenFrame, direction, position, ratios[nextIndex])
		win:setFrame(targetFrame, 0)
		local appliedFrame = cloneFrame(frameOf(win)) or cloneFrame(targetFrame)
		lastCycleState = {
			window = win,
			screen = screen,
			direction = direction,
			position = position,
			ratioIndex = nextIndex,
			ratio = ratios[nextIndex],
			appliedFrame = appliedFrame,
		}
		activateWindow(win)
	end

	local function cycleLeft()
		cycleWindow("horizontal", "left")
	end

	local function cycleHorizontalCenter()
		cycleWindow("horizontal", "center")
	end

	local function cycleRight()
		cycleWindow("horizontal", "right")
	end

	local function cycleTop()
		cycleWindow("vertical", "top")
	end

	local function cycleVerticalCenter()
		cycleWindow("vertical", "verticalCenter")
	end

	local function cycleBottom()
		cycleWindow("vertical", "bottom")
	end

	local function moveToAreaName(areaName)
		if not hs or not hs.window or not hs.window.focusedWindow then
			return
		end
		local win = hs.window.focusedWindow()
		if not win or not win.setFrame then
			return
		end
		local screen = screenOf(win)
		if not screen or not screen.frame then
			return
		end
		local screenFrame = cloneFrame(screen:frame())
		if not screenFrame then
			return
		end
		local targetFrame = areaSpecForName(screenFrame, areaName)
		if not targetFrame then
			return
		end
		win:setFrame(targetFrame, 0)
		activateWindow(win)
	end

	local directAreaCommands = {}
	for _, areaName in ipairs(DIRECT_AREA_COMMAND_KEYS) do
		directAreaCommands[areaName] = function()
			moveToAreaName(areaName)
		end
	end

	local function screenInfos()
		if not hs or not hs.screen or not hs.screen.allScreens then
			return {}
		end
		local infos = {}
		for _, screen in ipairs(hs.screen.allScreens()) do
			local frame = screen and screen.frame and cloneFrame(screen:frame()) or nil
			table.insert(infos, {
				uuid = screenUUID(screen),
				name = screenName(screen),
				id = screenID(screen),
				frame = frame,
			})
		end
		return infos
	end

	local function bindHotkey(modifiers, key, callback)
		if key then
			table.insert(hotkeys, hs.hotkey.bind(modifiers, key, callback))
		end
	end

	bindHotkey(config.moveToNextDisplayHotkeyModifiers, config.moveToNextDisplayHotkeyKey, moveToNextDisplay)
	bindHotkey(
		config.moveToActiveDisplayFreeAreaHotkeyModifiers,
		config.moveToActiveDisplayFreeAreaHotkeyKey,
		moveToActiveDisplayFreeArea
	)
	bindHotkey(
		config.openWindowActionChooserHotkeyModifiers,
		config.openWindowActionChooserHotkeyKey,
		openWindowActionChooser
	)
	bindHotkey(
		config.openJinraiModeWindowActionChooserHotkeyModifiers,
		config.openJinraiModeWindowActionChooserHotkeyKey,
		openJinraiModeWindowActionChooser
	)
	bindHotkey(config.minimizeWindowHotkeyModifiers, config.minimizeWindowHotkeyKey, minimizeWindow)
	bindHotkey(config.maximizeWindowHotkeyModifiers, config.maximizeWindowHotkeyKey, maximizeWindow)
	bindHotkey(config.cycleLeftHotkeyModifiers, config.cycleLeftHotkeyKey, cycleLeft)
	bindHotkey(config.cycleHorizontalCenterHotkeyModifiers, config.cycleHorizontalCenterHotkeyKey, cycleHorizontalCenter)
	bindHotkey(config.cycleRightHotkeyModifiers, config.cycleRightHotkeyKey, cycleRight)
	bindHotkey(config.cycleTopHotkeyModifiers, config.cycleTopHotkeyKey, cycleTop)
	bindHotkey(config.cycleVerticalCenterHotkeyModifiers, config.cycleVerticalCenterHotkeyKey, cycleVerticalCenter)
	bindHotkey(config.cycleBottomHotkeyModifiers, config.cycleBottomHotkeyKey, cycleBottom)
	for _, areaName in ipairs(DIRECT_AREA_COMMAND_KEYS) do
		bindHotkey(config[areaName .. "HotkeyModifiers"], config[areaName .. "HotkeyKey"], directAreaCommands[areaName])
	end

	local function teardown()
		closeAreaChooser(true)
		for _, hotkey in ipairs(hotkeys) do
			hotkey:delete()
		end
		hotkeys = {}
	end

	local instance = {
		moveToNextDisplay = moveToNextDisplay,
		moveToActiveDisplayFreeArea = moveToActiveDisplayFreeArea,
		openWindowActionChooser = openWindowActionChooser,
		minimizeWindow = minimizeWindow,
		maximizeWindow = maximizeWindow,
		cycleLeft = cycleLeft,
		cycleHorizontalCenter = cycleHorizontalCenter,
		cycleRight = cycleRight,
		cycleTop = cycleTop,
		cycleVerticalCenter = cycleVerticalCenter,
		cycleBottom = cycleBottom,
		screenInfos = screenInfos,
		teardown = teardown,
	}
	for _, areaName in ipairs(DIRECT_AREA_COMMAND_KEYS) do
		instance[areaName] = directAreaCommands[areaName]
	end
	return instance
end

return M
