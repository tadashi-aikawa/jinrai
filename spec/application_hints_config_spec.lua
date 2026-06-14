describe("application_hints_config", function()
	local mod

	before_each(function()
		mod = dofile("./Jinrai.spoon/application_hints_config.lua")
	end)

	it("公開設定を実行時設定へ変換できる", function()
		local callback = function() end
		local built = mod.build({
			hotkey = {
				modifiers = { "ctrl", "alt" },
				key = "A",
			},
			windowWaitTimeout = 5,
			appearance = {
				columns = 2,
				bgColor = { red = 0.1, green = 0.2, blue = 0.3, alpha = 0.4 },
				dimmedBgColor = { red = 0.5, green = 0.6, blue = 0.7, alpha = 0.2 },
			},
			apps = {
				{
					bundleID = "com.google.Chrome",
					key = "c",
					name = "Chrome",
					newWindow = {
						hotkey = {
							modifiers = { "ctrl", "option" },
							key = "N",
						},
						callback = callback,
					},
				},
			},
			internal = {
				windowHintsKey = ";",
				jinraiModeKey = "space",
			},
		})

		assert.are.same({ "ctrl", "alt" }, built.hotkeyModifiers)
		assert.are.equal("a", built.hotkeyKey)
		assert.are.equal(5, built.windowWaitTimeout)
		assert.are.equal("C", built.apps[1].key)
		assert.are.equal("com.google.Chrome", built.apps[1].bundleID)
		assert.are.same({ "alt", "ctrl" }, built.apps[1].newWindow.hotkey.modifiers)
		assert.are.equal("n", built.apps[1].newWindow.hotkey.key)
		assert.are.equal(callback, built.apps[1].newWindow.callback)
		assert.are.equal(";", built.windowHintsKey)
		assert.are.equal("SPACE", built.jinraiModeKey)
		assert.are.equal(2, built.columns)
		assert.are.same({ red = 0.1, green = 0.2, blue = 0.3, alpha = 0.4 }, built.bgColor)
		assert.are.same({ red = 0.5, green = 0.6, blue = 0.7, alpha = 0.2 }, built.dimmedBgColor)
	end)

	it("表示設定のデフォルトを使用する", function()
		local built = mod.build({
			apps = {
				{ bundleID = "com.example.app", key = "A" },
			},
		})

		assert.are.equal(3, built.columns)
		assert.are.equal(0.80, built.bgColor.alpha)
		assert.are.equal(0.30, built.dimmedBgColor.alpha)
	end)

	it("newWindow未指定時はCmd+Nを使用する", function()
		local built = mod.build({
			apps = {
				{ bundleID = "com.example.app", key = "A" },
			},
		})

		assert.are.same({ "cmd" }, built.apps[1].newWindow.hotkey.modifiers)
		assert.are.equal("n", built.apps[1].newWindow.hotkey.key)
		assert.is_nil(built.apps[1].newWindow.callback)
	end)

	it("アプリキーは1文字または2文字に制限する", function()
		local ok, err = pcall(function()
			mod.build({
				apps = {
					{ bundleID = "com.example.app", key = "ABC" },
				},
			})
		end)

		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("1 or 2 characters"))
	end)

	it("appsは1件以上必要", function()
		local ok, err = pcall(function()
			mod.build({ apps = {} })
		end)

		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("must not be empty"))
	end)

	it("重複またはprefix衝突するアプリキーはエラー", function()
		local ok, err = pcall(function()
			mod.build({
				apps = {
					{ bundleID = "com.example.a", key = "A" },
					{ bundleID = "com.example.ab", key = "AB" },
				},
			})
		end)

		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("share a prefix"))
	end)

	it("newWindowはテーブルだけを許可する", function()
		local ok, err = pcall(function()
			mod.build({
				apps = {
					{ bundleID = "com.example.app", key = "A", newWindow = "cmd+n" },
				},
			})
		end)

		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("must be a table"))
	end)

	it("newWindow.callbackは関数だけを許可する", function()
		local ok, err = pcall(function()
			mod.build({
				apps = {
					{
						bundleID = "com.example.app",
						key = "A",
						newWindow = { callback = "create" },
					},
				},
			})
		end)

		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("callback must be a function"))
	end)

	it("Window Hintsへ戻るキーを先頭に持つアプリキーはエラー", function()
		local ok, err = pcall(function()
			mod.build({
				apps = {
					{ bundleID = "com.example.app", key = "AB" },
				},
				internal = {
					windowHintsKey = "A",
				},
			})
		end)

		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("toggle key"))
	end)

	it("JinraiMode開始キーとprefix衝突するアプリキーはエラー", function()
		local ok, err = pcall(function()
			mod.build({
				apps = {
					{ bundleID = "com.example.app", key = "AB" },
				},
				internal = {
					jinraiModeKey = "A",
				},
			})
		end)

		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("triggers.applicationHints.key"))
	end)

	it("JinraiMode開始キーとWindow Hints切り替えキーのprefix衝突はエラー", function()
		local ok, err = pcall(function()
			mod.build({
				apps = {
					{ bundleID = "com.example.app", key = "C" },
				},
				internal = {
					windowHintsKey = "A",
					jinraiModeKey = "AB",
				},
			})
		end)

		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("Window Hints toggle key"))
	end)
end)
