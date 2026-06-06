describe("updater", function()
	local originalHs
	local originalSpoon
	local state
	local updaterModule

	local function newMock()
		state = {
			menus = {},
			notifications = {},
			httpCallbacks = {},
			installCallbacks = {},
			reloadCount = 0,
			timers = {},
		}
		_G.hs = {
			logger = {
				new = function()
					return { e = function() end }
				end,
			},
			menubar = {
				new = function(inMenuBar, autosaveName)
					local menu = {
						deleted = false,
						inMenuBar = inMenuBar,
						autosaveName = autosaveName,
						returnedToMenuBar = false,
					}
					function menu:setIcon(icon, template)
						self.icon = icon
						self.template = template
						return self
					end
					function menu:setTitle(title)
						self.title = title
					end
					function menu:setTooltip(tooltip)
						self.tooltip = tooltip
					end
					function menu:isInMenuBar()
						return self.inMenuBar
					end
					function menu:returnToMenuBar()
						self.inMenuBar = true
						self.returnedToMenuBar = true
					end
					function menu:setMenu(items)
						self.items = type(items) == "function" and items() or items
					end
					function menu:delete()
						self.deleted = true
					end
					table.insert(state.menus, menu)
					return menu
				end,
			},
			image = {
				imageFromPath = function(path)
					return { path = path }
				end,
			},
			notify = {
				new = function(callback, attributes)
					local notification = {
						callback = callback,
						attributes = attributes,
						withdrawn = false,
					}
					function notification:send()
						self.sent = true
						table.insert(state.notifications, self)
					end
					function notification:withdraw()
						self.withdrawn = true
					end
					return notification
				end,
			},
			http = {
				asyncGet = function(url, headers, callback)
					table.insert(state.httpCallbacks, {
						url = url,
						headers = headers,
						callback = callback,
					})
				end,
			},
			json = {
				decode = function(body)
					if body == "invalid" then
						error("invalid JSON")
					end
					return body
				end,
			},
			timer = {
				doAfter = function(interval, callback)
					local timer = { interval = interval, callback = callback, stopped = false }
					function timer:stop()
						self.stopped = true
					end
					table.insert(state.timers, timer)
					return timer
				end,
			},
			loadSpoon = function() end,
			reload = function()
				state.reloadCount = state.reloadCount + 1
			end,
		}
		_G.spoon = {
			SpoonInstall = {
				asyncInstallSpoonFromZipURL = function(_, url, callback)
					table.insert(state.installCallbacks, { url = url, callback = callback })
					return true
				end,
			},
		}
	end

	local function newUpdater(version)
		local updater = updaterModule.new({
			currentVersion = version or "0.28.0",
			iconPath = "/tmp/jinrai.svg",
		})
		updater:start()
		return updater
	end

	local function latestRelease(tag)
		return {
			tag_name = tag,
			assets = {
				{
					name = "Jinrai.spoon.zip",
					browser_download_url = "https://example.com/" .. tag .. "/Jinrai.spoon.zip",
				},
			},
		}
	end

	before_each(function()
		originalHs = _G.hs
		originalSpoon = _G.spoon
		newMock()
		updaterModule = dofile("./Jinrai.spoon/updater.lua")
	end)

	after_each(function()
		_G.hs = originalHs
		_G.spoon = originalSpoon
	end)

	it("メニューバーに現在バージョンと更新確認を表示する", function()
		newUpdater()

		assert.are.equal("Jinrai v0.28.0", state.menus[1].items[1].title)
		assert.are.equal("Check for Updates...", state.menus[1].items[3].title)
		assert.is_true(state.menus[1].inMenuBar)
		assert.are.equal("JinraiUpdater", state.menus[1].autosaveName)
		assert.are.equal("/tmp/jinrai.svg", state.menus[1].icon.path)
		assert.is_true(state.menus[1].template)
		assert.is_nil(state.menus[1].title)
		assert.are.equal("Jinrai", state.menus[1].tooltip)
	end)

	it("新しいReleaseがある場合は更新メニューと通知を表示する", function()
		local updater = newUpdater()
		assert.is_true(updater:checkForUpdate())
		assert.are.equal("Checking for Updates...", state.menus[1].items[3].title)

		state.httpCallbacks[1].callback(200, latestRelease("v0.29.0"))

		assert.are.equal("Update to v0.29.0...", state.menus[1].items[3].title)
		assert.are.equal("Jinrai update available", state.notifications[1].attributes.title)
		assert.is_function(state.notifications[1].callback)
	end)

	it("最新版の場合は通知して確認メニューへ戻る", function()
		local updater = newUpdater()
		updater:checkForUpdate()
		state.httpCallbacks[1].callback(200, latestRelease("v0.28.0"))

		assert.are.equal("Check for Updates...", state.menus[1].items[3].title)
		assert.are.equal("Jinrai is up to date", state.notifications[1].attributes.title)
	end)

	it("通知クリックから更新し成功後に再読み込みする", function()
		local updater = newUpdater()
		updater:checkForUpdate()
		state.httpCallbacks[1].callback(200, latestRelease("v0.29.0"))

		state.notifications[1].callback()
		assert.are.equal("Updating to v0.29.0...", state.menus[1].items[3].title)
		assert.are.equal("https://example.com/v0.29.0/Jinrai.spoon.zip", state.installCallbacks[1].url)

		state.installCallbacks[1].callback(nil, true)
		assert.are.equal("Jinrai updated", state.notifications[2].attributes.title)
		assert.are.equal(2, state.timers[1].interval)
		state.timers[1].callback()
		assert.are.equal(1, state.reloadCount)
	end)

	it("開発版では更新確認を拒否する", function()
		local updater = newUpdater("0.0.0-development")

		assert.is_false(updater:checkForUpdate())
		assert.are.equal(0, #state.httpCallbacks)
		assert.are.equal("Jinrai development version", state.notifications[1].attributes.title)
	end)

	it("通信・JSON・assetの失敗を通知する", function()
		local updater = newUpdater()
		updater:checkForUpdate()
		state.httpCallbacks[1].callback(500, {})
		assert.are.equal("Failed to check for updates", state.notifications[1].attributes.title)

		updater:checkForUpdate()
		state.httpCallbacks[2].callback(200, "invalid")
		assert.are.equal("Failed to check for updates", state.notifications[2].attributes.title)

		updater:checkForUpdate()
		state.httpCallbacks[3].callback(200, { tag_name = "v0.29.0", assets = {} })
		assert.are.equal("Failed to check for updates", state.notifications[3].attributes.title)
	end)

	it("SpoonInstall失敗時は再読み込みしない", function()
		local updater = newUpdater()
		updater:checkForUpdate()
		state.httpCallbacks[1].callback(200, latestRelease("v0.29.0"))
		updater:update()
		state.installCallbacks[1].callback(nil, false)

		assert.are.equal("Failed to update Jinrai", state.notifications[2].attributes.title)
		assert.are.equal(0, state.reloadCount)
		assert.are.equal(0, #state.timers)
	end)

	it("SpoonInstall未導入時は更新を開始しない", function()
		local updater = newUpdater()
		updater:checkForUpdate()
		state.httpCallbacks[1].callback(200, latestRelease("v0.29.0"))
		_G.spoon = nil

		assert.is_false(updater:update())
		assert.are.equal("Failed to update Jinrai", state.notifications[2].attributes.title)
		assert.are.equal(0, #state.installCallbacks)
	end)

	it("確認中の重複操作を開始しない", function()
		local updater = newUpdater()

		assert.is_true(updater:checkForUpdate())
		assert.is_false(updater:checkForUpdate())
		assert.is_false(updater:update())
		assert.are.equal(1, #state.httpCallbacks)
	end)

	it("teardownでメニューと通知を破棄する", function()
		local updater = newUpdater()
		updater:checkForUpdate()
		state.httpCallbacks[1].callback(200, latestRelease("v0.29.0"))

		updater:teardown()

		assert.is_true(state.menus[1].deleted)
		assert.is_true(state.notifications[1].withdrawn)
	end)

	it("SemVerを比較する", function()
		assert.is_true(updaterModule.isNewerVersion("v0.29.0", "0.28.9"))
		assert.is_false(updaterModule.isNewerVersion("v0.28.0", "0.28.0"))
		assert.is_false(updaterModule.isNewerVersion("v0.27.9", "0.28.0"))
	end)
end)
