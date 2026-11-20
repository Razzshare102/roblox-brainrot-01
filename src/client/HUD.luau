-- Brainrot Bay: the ScreenGui over the 3D world. Top bar with cash and
-- income, the tsunami banner, the context prompt at the bottom, and the
-- shop panel with the rebirth button. Kept clear of the top-left corner,
-- where Roblox's own menu buttons sit.

local Players = game:GetService("Players")

local BrainrotData = require(script.Parent.Parent.Shared.BrainrotData)

local HUD = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = nil
local cashLabel = nil
local incomeLabel = nil
local statusLabel = nil
local banner = nil
local bannerLabel = nil
local promptLabel = nil
local shopPanel = nil
local shopList = nil
local rebirthButton = nil
local shopButton = nil
local toastLabel = nil

local state = nil
local onBuyShop = nil
local onRebirth = nil

local function money(n)
	local text = tostring(math.floor(n))
	local out = ""
	while #text > 3 do
		out = "," .. string.sub(text, -3) .. out
		text = string.sub(text, 1, -4)
	end
	return "$" .. text .. out
end

local function makeLabel(parent, name, size, position, textSize, color, anchor)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextXAlignment = anchor or Enum.TextXAlignment.Left
	label.Text = ""
	label.Parent = parent
	return label
end

function HUD.build(buyShopCallback, rebirthCallback)
	onBuyShop = buyShopCallback
	onRebirth = rebirthCallback

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BrainrotBayHUD"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- Top bar: title, cash, income, rebirth or lock status.
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, 52)
	topBar.Position = UDim2.new(0, 0, 0, 0)
	topBar.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	topBar.BorderSizePixel = 0
	topBar.Parent = screenGui

	makeLabel(topBar, "Title", UDim2.new(0, 260, 1, 0), UDim2.new(0, 16, 0, 0), 24, Color3.fromRGB(255, 200, 40)).Text = "BRAINROT BAY"
	cashLabel = makeLabel(topBar, "Cash", UDim2.new(0, 200, 1, 0), UDim2.new(0, 300, 0, 0), 24, Color3.fromRGB(110, 230, 110))
	incomeLabel = makeLabel(topBar, "Income", UDim2.new(0, 200, 1, 0), UDim2.new(0, 520, 0, 0), 24, Color3.fromRGB(110, 200, 255))
	statusLabel = makeLabel(topBar, "Status", UDim2.new(0, 260, 1, 0), UDim2.new(1, -276, 0, 0), 22, Color3.fromRGB(255, 200, 40), Enum.TextXAlignment.Right)

	-- Tsunami banner, hidden until the wave is coming.
	banner = Instance.new("Frame")
	banner.Name = "TsunamiBanner"
	banner.Size = UDim2.new(0, 560, 0, 44)
	banner.Position = UDim2.new(0.5, -280, 0, 60)
	banner.BackgroundColor3 = Color3.fromRGB(40, 10, 10)
	banner.BorderSizePixel = 0
	banner.Visible = false
	banner.Parent = screenGui
	local bannerCorner = Instance.new("UICorner")
	bannerCorner.CornerRadius = UDim.new(0, 10)
	bannerCorner.Parent = banner
	bannerLabel = makeLabel(banner, "BannerText", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), 20, Color3.fromRGB(255, 90, 90), Enum.TextXAlignment.Center)

	-- Context prompt along the bottom.
	local promptBar = Instance.new("Frame")
	promptBar.Name = "PromptBar"
	promptBar.Size = UDim2.new(0, 620, 0, 44)
	promptBar.Position = UDim2.new(0.5, -310, 1, -64)
	promptBar.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	promptBar.BackgroundTransparency = 0.15
	promptBar.BorderSizePixel = 0
	promptBar.Parent = screenGui
	local promptCorner = Instance.new("UICorner")
	promptCorner.CornerRadius = UDim.new(0, 10)
	promptCorner.Parent = promptBar
	promptLabel = makeLabel(promptBar, "PromptText", UDim2.new(1, -20, 1, 0), UDim2.new(0, 10, 0, 0), 18, Color3.fromRGB(255, 255, 255), Enum.TextXAlignment.Center)
	promptLabel.Text = "Walk to the belt and press E to buy a brainrot!"

	-- Toast line above the prompt, for server messages.
	toastLabel = makeLabel(screenGui, "Toast", UDim2.new(0, 620, 0, 30), UDim2.new(0.5, -310, 1, -104), 17, Color3.fromRGB(255, 220, 120), Enum.TextXAlignment.Center)

	-- Shop toggle, bottom right.
	shopButton = Instance.new("TextButton")
	shopButton.Name = "ShopButton"
	shopButton.Size = UDim2.new(0, 130, 0, 44)
	shopButton.Position = UDim2.new(1, -146, 1, -64)
	shopButton.BackgroundColor3 = Color3.fromRGB(255, 180, 40)
	shopButton.Font = Enum.Font.GothamBold
	shopButton.TextSize = 20
	shopButton.TextColor3 = Color3.fromRGB(30, 30, 30)
	shopButton.Text = "SHOP"
	shopButton.Parent = screenGui
	local shopCorner = Instance.new("UICorner")
	shopCorner.CornerRadius = UDim.new(0, 10)
	shopCorner.Parent = shopButton
	shopButton.MouseButton1Click:Connect(function()
		shopPanel.Visible = not shopPanel.Visible
		if shopPanel.Visible then
			HUD.refreshShop()
		end
	end)

	-- Shop panel: five upgrades and the rebirth button.
	shopPanel = Instance.new("Frame")
	shopPanel.Name = "ShopPanel"
	shopPanel.Size = UDim2.new(0, 360, 0, 380)
	shopPanel.Position = UDim2.new(1, -380, 1, -460)
	shopPanel.BackgroundColor3 = Color3.fromRGB(24, 24, 34)
	shopPanel.BorderSizePixel = 0
	shopPanel.Visible = false
	shopPanel.Parent = screenGui
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 12)
	panelCorner.Parent = shopPanel
	makeLabel(shopPanel, "ShopTitle", UDim2.new(1, -20, 0, 36), UDim2.new(0, 10, 0, 8), 22, Color3.fromRGB(255, 200, 40)).Text = "SHOP"

	shopList = Instance.new("Frame")
	shopList.Name = "ShopList"
	shopList.Size = UDim2.new(1, -20, 0, 250)
	shopList.Position = UDim2.new(0, 10, 0, 52)
	shopList.BackgroundTransparency = 1
	shopList.Parent = shopPanel

	for index, item in ipairs(BrainrotData.SHOP) do
		local row = Instance.new("Frame")
		row.Name = "ShopRow" .. item.id
		row.Size = UDim2.new(1, 0, 0, 46)
		row.Position = UDim2.new(0, 0, 0, (index - 1) * 50)
		row.BackgroundColor3 = Color3.fromRGB(40, 40, 54)
		row.BorderSizePixel = 0
		row.Parent = shopList
		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 8)
		rowCorner.Parent = row

		makeLabel(row, "ItemName", UDim2.new(0, 200, 0, 22), UDim2.new(0, 10, 0, 3), 16, Color3.fromRGB(255, 255, 255)).Text = item.name
		makeLabel(row, "ItemDesc", UDim2.new(0, 200, 0, 18), UDim2.new(0, 10, 0, 24), 13, Color3.fromRGB(180, 180, 200)).Text = item.desc

		local buyButton = Instance.new("TextButton")
		buyButton.Name = "Buy" .. item.id
		buyButton.Size = UDim2.new(0, 110, 0, 34)
		buyButton.Position = UDim2.new(1, -120, 0, 6)
		buyButton.BackgroundColor3 = Color3.fromRGB(110, 220, 110)
		buyButton.Font = Enum.Font.GothamBold
		buyButton.TextSize = 15
		buyButton.TextColor3 = Color3.fromRGB(20, 40, 20)
		buyButton.Text = "$" .. tostring(item.baseCost)
		buyButton.Parent = row
		local buyCorner = Instance.new("UICorner")
		buyCorner.CornerRadius = UDim.new(0, 8)
		buyCorner.Parent = buyButton
		buyButton.MouseButton1Click:Connect(function()
			if onBuyShop then
				onBuyShop(item.id)
			end
		end)
	end

	rebirthButton = Instance.new("TextButton")
	rebirthButton.Name = "RebirthButton"
	rebirthButton.Size = UDim2.new(1, -20, 0, 48)
	rebirthButton.Position = UDim2.new(0, 10, 0, 312)
	rebirthButton.BackgroundColor3 = Color3.fromRGB(170, 90, 255)
	rebirthButton.Font = Enum.Font.GothamBold
	rebirthButton.TextSize = 17
	rebirthButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	rebirthButton.Text = "REBIRTH"
	rebirthButton.Parent = shopPanel
	local rebirthCorner = Instance.new("UICorner")
	rebirthCorner.CornerRadius = UDim.new(0, 10)
	rebirthCorner.Parent = rebirthButton
	rebirthButton.MouseButton1Click:Connect(function()
		if onRebirth then
			onRebirth()
		end
	end)
end

function HUD.setState(newState)
	state = newState
	if not cashLabel then
		return
	end
	cashLabel.Text = money(state.cash)
	incomeLabel.Text = string.format("+$%d/s", state.income)
	if state.lockSecondsLeft > 0 then
		statusLabel.Text = string.format("LOCKED %ds", state.lockSecondsLeft)
		statusLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
	else
		statusLabel.Text = string.format("Rebirth x%.2f (%d)", state.multiplier, state.rebirths)
		statusLabel.TextColor3 = Color3.fromRGB(255, 200, 40)
	end
	if shopPanel and shopPanel.Visible then
		HUD.refreshShop()
	end
end

function HUD.refreshShop()
	if not state then
		return
	end
	for _, item in ipairs(BrainrotData.SHOP) do
		local row = shopList:FindFirstChild("ShopRow" .. item.id)
		if row then
			local button = row:FindFirstChild("Buy" .. item.id)
			if button then
				local level = 0
				if item.id == "Slot" then
					level = state.slots - BrainrotData.START_SLOTS
				elseif item.id == "Speed" then
					level = state.speedLevel
				elseif item.id == "Slap" then
					level = state.slapLevel
				elseif item.id == "Lock" then
					level = state.lockLevel
				elseif item.id == "Income2x" then
					level = state.income2x and 1 or 0
				end
				if level >= item.maxLevel then
					button.Text = "MAX"
					button.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
				else
					button.Text = "$" .. tostring(BrainrotData.shopCost(item, level + 1))
					button.BackgroundColor3 = Color3.fromRGB(110, 220, 110)
				end
			end
		end
	end
	if rebirthButton and state then
		rebirthButton.Text = string.format("REBIRTH — $%d  (+25%% income)", state.rebirthCost)
	end
end

function HUD.setPrompt(text)
	if promptLabel then
		promptLabel.Text = text
	end
end

function HUD.showToast(message)
	if toastLabel then
		toastLabel.Text = message
		task.delay(4, function()
			if toastLabel and toastLabel.Text == message then
				toastLabel.Text = ""
			end
		end)
	end
end

function HUD.showTsunami(phase, secondsLeft)
	if not banner then
		return
	end
	if phase == "warning" then
		banner.Visible = true
		bannerLabel.Text = string.format("TSUNAMI IN %ds — GET TO YOUR BASE!", secondsLeft)
	elseif phase == "sweep" then
		banner.Visible = true
		bannerLabel.Text = "TSUNAMI! GET TO YOUR BASE!"
	else
		banner.Visible = false
	end
end

return HUD
