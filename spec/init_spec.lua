describe("init", function()
	local originalDofile
	local originalJinraiState
	local originalHs

	before_each(function()
		originalDofile = _G.dofile
		originalJinraiState = _G.__jinrai
		originalHs = _G.hs

		_G.hs = {
			spoons = {
				resourcePath = function(path)
					return "./Jinrai.spoon/" .. path
				end,
			},
		}
	end)

	after_each(function()
		_G.dofile = originalDofile
		_G.__jinrai = originalJinraiState
		_G.hs = originalHs
	end)

	it("読み込み時に既存 __jinrai.teardown を実行する", function()
		local called = 0
		_G.__jinrai = {
			teardown = function()
				called = called + 1
			end,
		}

		dofile("./Jinrai.spoon/init.lua")
		assert.are.equal(1, called)
	end)

	it("setup で指定したモジュールだけ new される", function()
		_G.__jinrai = nil
		local init = dofile("./Jinrai.spoon/init.lua")
		local calls = {
			new = {},
			teardown = {},
			loadPaths = {},
		}

		_G.dofile = function(path)
			table.insert(calls.loadPaths, path)
			if path:match("focus_border.lua$") then
				return {
					new = function(options)
						calls.new.focus_border = options
						return {
							teardown = function()
								calls.teardown.focus_border = true
							end,
						}
					end,
				}
			end
			if path:match("window_hints.lua$") then
				return {
					new = function(options)
						calls.new.window_hints = options
						return {
							teardown = function()
								calls.teardown.window_hints = true
							end,
						}
					end,
				}
			end
			if path:match("focus_back.lua$") then
				return {
					new = function(options)
						calls.new.focus_back = options
						return {
							teardown = function()
								calls.teardown.focus_back = true
							end,
						}
					end,
				}
			end
			if path:match("focus_history.lua$") then
				return {
					new = function(options)
						calls.new.focus_history = options
						return {
							teardown = function()
								calls.teardown.focus_history = true
							end,
						}
					end,
				}
			end
			if path:match("window_mover.lua$") then
				return {
					new = function(options)
						calls.new.window_mover = options
						return {
							teardown = function()
								calls.teardown.window_mover = true
							end,
						}
					end,
				}
			end
			return originalDofile(path)
		end

		init:setup({
			focus_border = {
				visual = {
					border = {
						width = 99,
					},
				},
			},
			focus_back = {
				hotkey = {
					key = "q",
				},
				behavior = {
					cursor = {
						onSelect = true,
					},
				},
			},
			window_mover = {
				commands = {
					moveToNextDisplay = {
						hotkey = {
							key = "m",
						},
					},
				},
			},
			macosNativeTabs = {
				apps = { "com.mitchellh.ghostty" },
				stateSyncInterval = 0.15,
			},
		})

		assert.are.equal(99, calls.new.focus_border.visual.border.width)
		assert.are.same({
			macosNativeTabs = {
				apps = { "com.mitchellh.ghostty", "com.apple.finder" },
				stateSyncInterval = 0.15,
			},
		}, calls.new.focus_history)
		assert.are.equal("q", calls.new.focus_back.hotkey.key)
		assert.is_true(calls.new.focus_back.behavior.cursor.onSelect)
		assert.is_truthy(calls.new.focus_back.internal.focusHistory)
		assert.are.equal("m", calls.new.window_mover.commands.moveToNextDisplay.hotkey.key)
		assert.are.equal(nil, calls.new.window_hints)

		local joined = table.concat(calls.loadPaths, "\n")
		assert.is_truthy(joined:match("focus_border.lua"))
		assert.is_truthy(joined:match("window_hints.lua"))
		assert.is_truthy(joined:match("focus_back.lua"))
		assert.is_truthy(joined:match("focus_history.lua"))
		assert.is_truthy(joined:match("window_mover.lua"))

		init:teardown()
		assert.is_true(calls.teardown.focus_border)
		assert.is_true(calls.teardown.focus_back)
		assert.is_true(calls.teardown.focus_history)
		assert.is_true(calls.teardown.window_mover)
		assert.are.equal(nil, calls.teardown.window_hints)
	end)

	it("focus_history は window_hints.internal.focusHistory に注入される", function()
		_G.__jinrai = nil
		local init = dofile("./Jinrai.spoon/init.lua")
		local calls = {
			new = {},
		}

		_G.dofile = function(path)
			if path:match("window_hints.lua$") then
				return {
					new = function(options)
						calls.new.window_hints = options
						return { teardown = function() end }
					end,
				}
			end
			if path:match("focus_back.lua$") then
				return {
					new = function(options)
						calls.new.focus_back = options
						return { teardown = function() end }
					end,
				}
			end
			if path:match("focus_history.lua$") then
				return {
					new = function(options)
						calls.new.focus_history = options
						return { teardown = function() end }
					end,
				}
			end
			if path:match("focus_border.lua$") then
				return {
					new = function()
						return { teardown = function() end }
					end,
				}
			end
			if path:match("window_mover.lua$") then
				return {
					new = function()
						return { teardown = function() end }
					end,
				}
			end
			return originalDofile(path)
		end

		init:setup({
			macosNativeTabs = {
				apps = { "com.mitchellh.ghostty" },
			},
			window_hints = {},
			focus_back = {},
		})

		assert.is_truthy(calls.new.focus_history)
		assert.is_truthy(calls.new.window_hints.internal)
		assert.is_truthy(calls.new.window_hints.internal.focusHistory)
		assert.are.same({
			apps = { "com.mitchellh.ghostty", "com.apple.finder" },
			stateSyncInterval = 0.5,
		}, calls.new.window_hints.internal.macosNativeTabs)
		assert.are.equal(nil, calls.new.window_hints.macosNativeTabs)
		assert.are.equal(nil, calls.new.window_hints.focusHistory)
	end)

	it("JinraiMode は Window Hints と Window Mover を接続する", function()
		_G.__jinrai = nil
		local init = dofile("./Jinrai.spoon/init.lua")
		local calls = {
			new = {},
			openWindowActionChooserOptions = nil,
			openWindowActionChooserCount = 0,
			startJinraiMode = 0,
			show = 0,
			showJinraiMode = 0,
			showJinraiModeAsync = 0,
			advanceJinraiModeCombo = 0,
			stopJinraiMode = 0,
		}

		_G.dofile = function(path)
			if path:match("window_hints.lua$") then
				return {
					new = function(options)
						calls.new.window_hints = options
						return {
							startJinraiMode = function()
								calls.startJinraiMode = calls.startJinraiMode + 1
							end,
							show = function()
								calls.show = calls.show + 1
							end,
							showJinraiMode = function()
								calls.showJinraiMode = calls.showJinraiMode + 1
							end,
							showJinraiModeAsync = function()
								calls.showJinraiModeAsync = calls.showJinraiModeAsync + 1
							end,
							advanceJinraiModeCombo = function()
								calls.advanceJinraiModeCombo = calls.advanceJinraiModeCombo + 1
							end,
							stopJinraiMode = function()
								calls.stopJinraiMode = calls.stopJinraiMode + 1
							end,
							teardown = function() end,
						}
					end,
				}
			end
			if path:match("window_mover.lua$") then
				return {
					new = function(options)
						calls.new.window_mover = options
						return {
							openWindowActionChooser = function(options)
								calls.openWindowActionChooserCount = calls.openWindowActionChooserCount + 1
								calls.openWindowActionChooserOptions = options
							end,
							teardown = function() end,
						}
					end,
				}
			end
			if path:match("focus_border.lua$") then
				return {
					new = function()
						return { teardown = function() end }
					end,
				}
			end
			if path:match("focus_back.lua$") then
				return {
					new = function()
						return { teardown = function() end }
					end,
				}
			end
			if path:match("focus_history.lua$") then
				return {
					new = function()
						return { teardown = function() end }
					end,
				}
			end
			return originalDofile(path)
		end

		init:setup({
			jinrai_mode = {
				position = "activeWindow",
				triggers = {
					windowHints = {
						key = "space",
					},
					windowMover = {
						key = "j",
					},
				},
			},
			window_hints = {},
			window_mover = {},
		})

		assert.are.equal("activeWindow", calls.new.window_hints.internal.jinraiMode.position)
		assert.are.equal("space", calls.new.window_hints.internal.jinraiMode.windowHints.key)
		assert.are.equal("j", calls.new.window_mover.internal.jinraiMode.windowMover.key)
		assert.are.equal(0.25, calls.new.window_hints.internal.jinraiMode.logo.alpha)
		assert.is_false(calls.new.window_hints.internal.jinraiMode.combo.character.enabled)
		assert.are.equal(0.7, calls.new.window_hints.internal.jinraiMode.combo.character.alpha)
		assert.are.same(
			{ fade = true, scale = 1.18, duration = 0.16, easing = "linear" },
			calls.new.window_hints.internal.jinraiMode.combo.character.animation
		)
		assert.is_false(calls.new.window_hints.internal.jinraiMode.combo.text.enabled)
		assert.are.equal(0.7, calls.new.window_hints.internal.jinraiMode.combo.text.alpha)
		assert.are.same(
			{ fade = true, scale = 1.0, duration = 0.16, easing = "linear" },
			calls.new.window_hints.internal.jinraiMode.combo.text.animation
		)
		assert.is_truthy(calls.new.window_hints.internal.onOpenWindowActionChooser)
		calls.new.window_hints.internal.onOpenWindowActionChooser()
		assert.are.equal(1, calls.openWindowActionChooserCount)
		assert.is_nil(calls.openWindowActionChooserOptions)
		assert.are.equal(0, calls.advanceJinraiModeCombo)
		calls.new.window_hints.internal.onOpenWindowActionChooser({ jinraiMode = true })
		assert.is_true(calls.openWindowActionChooserOptions.jinraiMode)
		assert.is_truthy(calls.openWindowActionChooserOptions.onApply)
		assert.is_truthy(calls.openWindowActionChooserOptions.onCancel)
		assert.are.equal(1, calls.advanceJinraiModeCombo)
		assert.is_truthy(calls.new.window_hints.internal.onJinraiModeSelect)
		calls.new.window_hints.internal.onJinraiModeSelect({})
		assert.is_true(calls.openWindowActionChooserOptions.jinraiMode)
		assert.is_truthy(calls.openWindowActionChooserOptions.onApply)
		assert.is_truthy(calls.openWindowActionChooserOptions.onCancel)
		assert.are.equal(2, calls.advanceJinraiModeCombo)
		calls.openWindowActionChooserOptions.onApply()
		calls.openWindowActionChooserOptions.onCancel()
		calls.new.window_mover.internal.jinraiMode.onStart()
		calls.new.window_mover.internal.jinraiMode.onApply()
		calls.new.window_mover.internal.jinraiMode.onCancel()
		calls.new.window_mover.internal.jinraiMode.onOpenWindowHints({ jinraiMode = false })
		calls.new.window_mover.internal.jinraiMode.onOpenWindowHints({ jinraiMode = true })

		assert.are.equal(1, calls.startJinraiMode)
		assert.are.equal(1, calls.show)
		assert.are.equal(1, calls.showJinraiMode)
		assert.are.equal(2, calls.showJinraiModeAsync)
		assert.are.equal(5, calls.advanceJinraiModeCombo)
		assert.are.equal(2, calls.stopJinraiMode)
		assert.are.equal(3, calls.openWindowActionChooserCount)
	end)

	it("macosNativeTabs 未指定時は組み込みのデフォルト設定を注入する", function()
		_G.__jinrai = nil
		local init = dofile("./Jinrai.spoon/init.lua")
		local calls = {
			new = {},
		}

		_G.dofile = function(path)
			if path:match("window_hints.lua$") then
				return {
					new = function(options)
						calls.new.window_hints = options
						return { teardown = function() end }
					end,
				}
			end
			if path:match("focus_back.lua$") then
				return {
					new = function(options)
						calls.new.focus_back = options
						return { teardown = function() end }
					end,
				}
			end
			if path:match("focus_history.lua$") then
				return {
					new = function(options)
						calls.new.focus_history = options
						return { teardown = function() end }
					end,
				}
			end
			if path:match("focus_border.lua$") then
				return {
					new = function()
						return { teardown = function() end }
					end,
				}
			end
			if path:match("window_mover.lua$") then
				return {
					new = function()
						return { teardown = function() end }
					end,
				}
			end
			return originalDofile(path)
		end

		init:setup({
			window_hints = {},
			focus_back = {},
		})

		assert.are.same({
			macosNativeTabs = {
				apps = { "com.mitchellh.ghostty", "com.apple.finder" },
				stateSyncInterval = 0.5,
			},
		}, calls.new.focus_history)
		assert.are.same({
			apps = { "com.mitchellh.ghostty", "com.apple.finder" },
			stateSyncInterval = 0.5,
		}, calls.new.window_hints.internal.macosNativeTabs)
	end)

	it("macosNativeTabs.apps はデフォルトアプリに追加される", function()
		_G.__jinrai = nil
		local init = dofile("./Jinrai.spoon/init.lua")
		local calls = {
			new = {},
		}

		_G.dofile = function(path)
			if path:match("window_hints.lua$") then
				return {
					new = function(options)
						calls.new.window_hints = options
						return { teardown = function() end }
					end,
				}
			end
			if path:match("focus_back.lua$") then
				return {
					new = function(options)
						calls.new.focus_back = options
						return { teardown = function() end }
					end,
				}
			end
			if path:match("focus_history.lua$") then
				return {
					new = function(options)
						calls.new.focus_history = options
						return { teardown = function() end }
					end,
				}
			end
			if path:match("focus_border.lua$") then
				return {
					new = function()
						return { teardown = function() end }
					end,
				}
			end
			if path:match("window_mover.lua$") then
				return {
					new = function()
						return { teardown = function() end }
					end,
				}
			end
			return originalDofile(path)
		end

		init:setup({
			macosNativeTabs = {
				apps = { "com.example.terminal", "com.mitchellh.ghostty" },
				stateSyncInterval = 0.75,
			},
			window_hints = {},
			focus_back = {},
		})

		assert.are.same({
			apps = { "com.mitchellh.ghostty", "com.apple.finder", "com.example.terminal" },
			stateSyncInterval = 0.75,
		}, calls.new.window_hints.internal.macosNativeTabs)
		assert.are.same({
			macosNativeTabs = {
				apps = { "com.mitchellh.ghostty", "com.apple.finder", "com.example.terminal" },
				stateSyncInterval = 0.75,
			},
		}, calls.new.focus_history)
	end)

	it("macosNativeTabs = false なら補正設定を注入しない", function()
		_G.__jinrai = nil
		local init = dofile("./Jinrai.spoon/init.lua")
		local calls = {
			new = {},
		}

		_G.dofile = function(path)
			if path:match("window_hints.lua$") then
				return {
					new = function(options)
						calls.new.window_hints = options
						return { teardown = function() end }
					end,
				}
			end
			if path:match("focus_back.lua$") then
				return {
					new = function(options)
						calls.new.focus_back = options
						return { teardown = function() end }
					end,
				}
			end
			if path:match("focus_history.lua$") then
				return {
					new = function(options)
						calls.new.focus_history = options
						return { teardown = function() end }
					end,
				}
			end
			if path:match("focus_border.lua$") then
				return {
					new = function()
						return { teardown = function() end }
					end,
				}
			end
			if path:match("window_mover.lua$") then
				return {
					new = function()
						return { teardown = function() end }
					end,
				}
			end
			return originalDofile(path)
		end

		init:setup({
			macosNativeTabs = false,
			window_hints = {},
			focus_back = {},
		})

		assert.are.same({ macosNativeTabs = nil }, calls.new.focus_history)
		assert.are.equal(nil, calls.new.window_hints.internal.macosNativeTabs)
	end)

	it("teardown は focus_back -> window_hints -> focus_border の順に実行される", function()
		_G.__jinrai = nil
		local init = dofile("./Jinrai.spoon/init.lua")
		local order = {}

		_G.dofile = function(path)
			if path:match("focus_border.lua$") then
				return {
					new = function()
						return {
							teardown = function()
								table.insert(order, "focus_border")
							end,
						}
					end,
				}
			end
			if path:match("window_hints.lua$") then
				return {
					new = function()
						return {
							teardown = function()
								table.insert(order, "window_hints")
							end,
						}
					end,
				}
			end
			if path:match("focus_back.lua$") then
				return {
					new = function()
						return {
							teardown = function()
								table.insert(order, "focus_back")
							end,
						}
					end,
				}
			end
			if path:match("focus_history.lua$") then
				return {
					new = function()
						return {
							teardown = function()
								table.insert(order, "focus_history")
							end,
						}
					end,
				}
			end
			if path:match("window_mover.lua$") then
				return {
					new = function()
						return {
							teardown = function()
								table.insert(order, "window_mover")
							end,
						}
					end,
				}
			end
			return originalDofile(path)
		end

		init:setup({
			focus_border = {},
			window_hints = {},
			focus_back = {},
			window_mover = {},
		})
		init:teardown()

		assert.are.same({ "window_mover", "focus_back", "window_hints", "focus_history", "focus_border" }, order)
	end)

	it("Application Hints は Window Hints と JinraiMode に接続される", function()
		_G.__jinrai = nil
		local init = dofile("./Jinrai.spoon/init.lua")
		local calls = {
			windowHintsOptions = nil,
			applicationHintsOptions = nil,
			applicationShow = nil,
			windowHintsShow = 0,
			windowHintsShowJinraiMode = 0,
			windowHintsStartJinraiMode = 0,
			windowHintsAdvanceJinraiModeCombo = 0,
			windowMoverOptions = nil,
			applicationShowResult = true,
		}

		_G.dofile = function(path)
			if path:match("application_hints.lua$") then
				return {
					new = function(options)
						calls.applicationHintsOptions = options
						return {
							show = function(opts)
								calls.applicationShow = opts
								if
									calls.applicationShowResult
									and opts.jinraiMode
									and opts.advanceJinraiModeCombo ~= false
									and calls.applicationHintsOptions.internal.onShowInJinraiMode
								then
									calls.applicationHintsOptions.internal.onShowInJinraiMode()
								end
								return calls.applicationShowResult
							end,
							teardown = function() end,
						}
					end,
				}
			end
			if path:match("window_hints.lua$") then
				return {
					new = function(options)
						calls.windowHintsOptions = options
						return {
							show = function()
								calls.windowHintsShow = calls.windowHintsShow + 1
							end,
							showJinraiMode = function()
								calls.windowHintsShowJinraiMode = calls.windowHintsShowJinraiMode + 1
							end,
							startJinraiMode = function()
								calls.windowHintsStartJinraiMode = calls.windowHintsStartJinraiMode + 1
							end,
							advanceJinraiModeCombo = function()
								calls.windowHintsAdvanceJinraiModeCombo =
									calls.windowHintsAdvanceJinraiModeCombo + 1
							end,
							stopJinraiMode = function() end,
							teardown = function() end,
						}
					end,
				}
			end
			if path:match("window_mover.lua$") then
				return {
					new = function()
						return {
							openWindowActionChooser = function(opts)
								calls.windowMoverOptions = opts
							end,
							teardown = function() end,
						}
					end,
				}
			end
			if path:match("focus_border.lua$") or path:match("focus_back.lua$") then
				return { new = function() return { teardown = function() end } end }
			end
			if path:match("focus_history.lua$") then
				return { new = function() return { teardown = function() end } end }
			end
			return originalDofile(path)
		end

		init:setup({
			application_hints = {
				apps = {
					{ bundleID = "com.example.app", key = "A" },
				},
			},
			window_hints = {
				navigation = {
					applicationHints = {
						key = ";",
					},
				},
			},
			window_mover = {},
			jinrai_mode = {
				triggers = {
					applicationHints = {
						key = "space",
					},
				},
			},
		})

		assert.are.equal(";", calls.applicationHintsOptions.internal.windowHintsKey)
		assert.are.equal("space", calls.applicationHintsOptions.internal.jinraiModeKey)
		assert.is_truthy(calls.applicationHintsOptions.internal.onShowInJinraiMode)
		assert.is_truthy(calls.windowHintsOptions.internal.onOpenApplicationHints)
		calls.windowHintsOptions.internal.onOpenApplicationHints({ jinraiMode = true })
		assert.is_true(calls.applicationShow.jinraiMode)
		assert.is_true(calls.applicationShow.advanceJinraiModeCombo)
		assert.is_true(calls.applicationShow.returnToWindowHints)
		assert.are.equal(1, calls.windowHintsAdvanceJinraiModeCombo)

		calls.windowHintsOptions.internal.onOpenApplicationHints({
			jinraiMode = true,
			advanceJinraiModeCombo = false,
		})
		assert.is_false(calls.applicationShow.advanceJinraiModeCombo)
		assert.are.equal(1, calls.windowHintsAdvanceJinraiModeCombo)

		calls.applicationHintsOptions.internal.onOpenWindowHints({ jinraiMode = false })
		assert.are.equal(1, calls.windowHintsShow)
		assert.are.equal(1, calls.windowHintsAdvanceJinraiModeCombo)
		calls.applicationHintsOptions.internal.onOpenWindowHints({ jinraiMode = true })
		assert.are.equal(1, calls.windowHintsShowJinraiMode)
		assert.are.equal(2, calls.windowHintsAdvanceJinraiModeCombo)

		calls.applicationShowResult = false
		calls.windowHintsOptions.internal.onOpenApplicationHints({ jinraiMode = true })
		assert.are.equal(2, calls.windowHintsAdvanceJinraiModeCombo)

		calls.applicationHintsOptions.internal.onStartJinraiMode()
		assert.are.equal(1, calls.windowHintsStartJinraiMode)

		calls.applicationHintsOptions.internal.onSelectInJinraiMode()
		assert.is_true(calls.windowMoverOptions.jinraiMode)
	end)

	it("setup で updater を開始し teardown で破棄する", function()
		_G.__jinrai = nil
		local init = dofile("./Jinrai.spoon/init.lua")
		local calls = {
			options = nil,
			start = 0,
			teardown = 0,
		}

		_G.dofile = function(path)
			if path:match("updater.lua$") then
				return {
					new = function(options)
						calls.options = options
						return {
							start = function()
								calls.start = calls.start + 1
							end,
							teardown = function()
								calls.teardown = calls.teardown + 1
							end,
						}
					end,
				}
			end
			return originalDofile(path)
		end

		init:setup({})
		assert.are.equal("0.0.0-development", calls.options.currentVersion)
		assert.is_truthy(calls.options.iconPath:match("menubar.svg$"))
		assert.are.equal(1, calls.start)

		init:teardown()
		assert.are.equal(1, calls.teardown)
	end)
end)
