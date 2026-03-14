describe("focus_border_config", function()
	local mod

	before_each(function()
		mod = dofile("./Jinrai.spoon/focus_border_config.lua")
	end)

	it("ネスト設定を実行時設定へ変換できる", function()
		local built = mod.build({
			visual = {
				border = {
					width = 20,
				},
				outline = {
					width = 3,
				},
				cornerRadius = 24,
			},
			animation = {
				duration = 1.2,
				fadeSteps = 30,
			},
			window = {
				minSize = 640,
			},
		})

		assert.are.equal(20, built.borderWidth)
		assert.are.equal(3, built.outlineWidth)
		assert.are.equal(24, built.cornerRadius)
		assert.are.equal(1.2, built.duration)
		assert.are.equal(30, built.fadeSteps)
		assert.are.equal(0.30, built.spaceSwitchDelay)
		assert.are.equal(640, built.minWindowSize)
	end)

	it("spaceSwitchDelay を上書きできる", function()
		local built = mod.build({
			animation = {
				spaceSwitchDelay = 0.42,
			},
		})

		assert.are.equal(0.42, built.spaceSwitchDelay)
	end)

	it("旧フラットキーはエラー", function()
		local ok, err = pcall(function()
			mod.build({
				borderWidth = 99,
			})
		end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):match("legacy flat key"))
	end)
end)
