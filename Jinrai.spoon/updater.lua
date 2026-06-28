local M = {}

local RELEASE_API_URL = "https://api.github.com/repos/tadashi-aikawa/jinrai/releases/latest"
local RELEASES_URL = "https://github.com/tadashi-aikawa/jinrai/releases"
local RELEASE_ASSET_NAME = "Jinrai.spoon.zip"

local function trimVersion(version)
	return tostring(version or ""):gsub("^v", "")
end

local function displayVersion(version)
	local normalized = trimVersion(version)
	if normalized:match("^%d+%.%d+%.%d+") then
		return "v" .. normalized
	end
	return normalized
end

local function parseVersion(version)
	local major, minor, patch = trimVersion(version):match("^(%d+)%.(%d+)%.(%d+)")
	if not major then
		return nil
	end
	return { tonumber(major), tonumber(minor), tonumber(patch) }
end

local function isNewerVersion(candidate, current)
	local candidateParts = parseVersion(candidate)
	local currentParts = parseVersion(current)
	if not candidateParts or not currentParts then
		return false
	end
	for index = 1, 3 do
		if candidateParts[index] ~= currentParts[index] then
			return candidateParts[index] > currentParts[index]
		end
	end
	return false
end

local function findAsset(release)
	for _, asset in ipairs(release.assets or {}) do
		if asset.name == RELEASE_ASSET_NAME and type(asset.browser_download_url) == "string" then
			return asset.browser_download_url
		end
	end
	return nil
end

function M.new(options)
	options = options or {}
	local currentVersion = options.currentVersion or "0.0.0-development"
	local checking = false
	local updating = false
	local availableRelease = nil
	local menubar = nil
	local notifications = {}
	local reloadTimer = nil
	local active = false
	local logger = hs and hs.logger and hs.logger.new and hs.logger.new("JinraiUpdater") or nil
	local updater = {}

	local function logError(message)
		if logger and logger.e then
			logger.e(message)
		end
	end

	local function notify(title, subtitle, information, callback)
		if not hs or not hs.notify then
			return nil
		end
		local notification
		if hs.notify.new then
			notification = hs.notify.new(callback, {
				title = title,
				subTitle = subtitle or "",
				informativeText = information or "",
				hasActionButton = callback ~= nil,
				actionButtonTitle = callback and "Update" or nil,
			})
			if notification and notification.send then
				notification:send()
			end
		elseif hs.notify.show then
			notification = hs.notify.show(title, subtitle or "", information or "")
		end
		if notification then
			table.insert(notifications, notification)
		end
		return notification
	end

	local function menuItems()
		local items = {
			{
				title = "Jinrai " .. displayVersion(currentVersion),
				disabled = true,
			},
			{ title = "-" },
		}
		if checking then
			table.insert(items, {
				title = "Checking for Updates...",
				disabled = true,
			})
		elseif updating then
			table.insert(items, {
				title = "Updating to " .. displayVersion(availableRelease and availableRelease.version) .. "...",
				disabled = true,
			})
		elseif availableRelease then
			table.insert(items, {
				title = "Update to " .. displayVersion(availableRelease.version) .. "...",
				fn = function()
					updater:update()
				end,
			})
		else
			table.insert(items, {
				title = "Check for Updates...",
				fn = function()
					updater:checkForUpdate()
				end,
			})
		end
		table.insert(items, { title = "-" })
		table.insert(items, {
			title = "Release Notes...",
			fn = function()
				hs.urlevent.openURL(RELEASES_URL)
			end,
		})
		return items
	end

	local function refreshMenu()
		if menubar and menubar.setMenu then
			menubar:setMenu(menuItems)
		end
	end

	local function fail(title, detail)
		checking = false
		updating = false
		refreshMenu()
		logError(detail)
		notify(title, "", detail)
	end

	function updater:checkForUpdate()
		if not active or checking or updating then
			return false
		end
		if currentVersion == "0.0.0-development" then
			notify(
				"Jinrai development version",
				"",
				"Development version cannot be updated automatically. Use git pull."
			)
			return false
		end
		if not hs or not hs.http or not hs.http.asyncGet or not hs.json or not hs.json.decode then
			fail("Failed to check for updates", "Required Hammerspoon HTTP or JSON API is unavailable.")
			return false
		end

		checking = true
		refreshMenu()
		hs.http.asyncGet(RELEASE_API_URL, {
			["Accept"] = "application/vnd.github+json",
			["User-Agent"] = "Jinrai/" .. trimVersion(currentVersion),
			["X-GitHub-Api-Version"] = "2022-11-28",
		}, function(status, body)
			if not active then
				return
			end
			if status < 200 or status >= 300 then
				fail("Failed to check for updates", "GitHub Releases returned HTTP " .. tostring(status) .. ".")
				return
			end

			local ok, release = pcall(hs.json.decode, body)
			if not ok or type(release) ~= "table" or type(release.tag_name) ~= "string" then
				fail("Failed to check for updates", "GitHub Releases returned invalid JSON.")
				return
			end

			local assetUrl = findAsset(release)
			if not assetUrl then
				fail("Failed to check for updates", RELEASE_ASSET_NAME .. " was not found in the latest release.")
				return
			end

			checking = false
			if isNewerVersion(release.tag_name, currentVersion) then
				availableRelease = {
					version = trimVersion(release.tag_name),
					assetUrl = assetUrl,
				}
				refreshMenu()
				notify(
					"Jinrai update available",
					displayVersion(currentVersion) .. " -> " .. displayVersion(availableRelease.version),
					"Click to update.",
					function()
						updater:update()
					end
				)
				return
			end

			availableRelease = nil
			refreshMenu()
			notify("Jinrai is up to date", "", "Current version: " .. displayVersion(currentVersion))
		end)
		return true
	end

	function updater:update()
		if not active or checking or updating then
			return false
		end
		if currentVersion == "0.0.0-development" then
			notify(
				"Jinrai development version",
				"",
				"Development version cannot be updated automatically. Use git pull."
			)
			return false
		end
		if not availableRelease then
			return self:checkForUpdate()
		end

		if not spoon or not spoon.SpoonInstall then
			if hs and hs.loadSpoon then
				pcall(hs.loadSpoon, "SpoonInstall")
			end
		end
		if not spoon or not spoon.SpoonInstall or not spoon.SpoonInstall.asyncInstallSpoonFromZipURL then
			fail("Failed to update Jinrai", "SpoonInstall is required to update Jinrai.")
			return false
		end

		updating = true
		refreshMenu()
		local targetVersion = availableRelease.version
		local started = spoon.SpoonInstall:asyncInstallSpoonFromZipURL(availableRelease.assetUrl, function(_, success)
			if not active then
				return
			end
			if not success then
				fail(
					"Failed to update Jinrai",
					"SpoonInstall could not install " .. displayVersion(targetVersion) .. "."
				)
				return
			end

			updating = false
			notify(
				"Jinrai updated",
				displayVersion(currentVersion) .. " -> " .. displayVersion(targetVersion),
				"Hammerspoon will reload."
			)
			if hs and hs.timer and hs.timer.doAfter then
				reloadTimer = hs.timer.doAfter(2, function()
					if hs.reload then
						hs.reload()
					end
				end)
			elseif hs and hs.reload then
				hs.reload()
			end
		end)
		if not started then
			fail("Failed to update Jinrai", "SpoonInstall could not start the download.")
			return false
		end
		return true
	end

	function updater:start()
		if menubar then
			return updater
		end
		active = true
		if not hs or not hs.menubar or not hs.menubar.new then
			return updater
		end
		menubar = hs.menubar.new(true, "JinraiUpdater")
		if not menubar then
			return updater
		end
		local iconWasSet = false
		if menubar.setIcon and hs.image and hs.image.imageFromPath and options.iconPath then
			local icon = hs.image.imageFromPath(options.iconPath)
			if icon then
				iconWasSet = menubar:setIcon(icon, true) ~= nil
			end
		end
		if not iconWasSet and menubar.setTitle then
			menubar:setTitle("J")
		end
		if menubar.setTooltip then
			menubar:setTooltip("Jinrai")
		end
		if menubar.isInMenuBar and menubar.returnToMenuBar and not menubar:isInMenuBar() then
			menubar:returnToMenuBar()
		end
		refreshMenu()
		return updater
	end

	function updater:teardown()
		active = false
		if reloadTimer and reloadTimer.stop then
			reloadTimer:stop()
		end
		reloadTimer = nil
		for _, notification in ipairs(notifications) do
			if notification.withdraw then
				notification:withdraw()
			end
		end
		notifications = {}
		if menubar and menubar.delete then
			menubar:delete()
		end
		menubar = nil
		return updater
	end

	return updater
end

M.isNewerVersion = isNewerVersion

return M
