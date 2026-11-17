-- HUD: the screen interface over the 3D world. Top bar with cash,
-- income and rebirths; a context prompt telling the player what E does
-- right now; buttons for Shop, Rebirth and Lock; a tsunami banner; and
-- a small leaderboard. The client only displays state the server sends
-- (SyncState / SyncWorld) and fires RemoteEvents for actions.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BrainrotData = require(ReplicatedStorage.Shared.BrainrotData)

local HUD = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local SyncState = remotes:WaitForChild("SyncState")
local SyncWorld = remotes:WaitForChild("SyncWorld")
local BuyShop = remotes:WaitForChild("BuyShop")
local Rebirth = remotes:WaitForChild("Rebirth")
local LockBase = remotes:WaitForChild("LockBase")

local gui: ScreenGui? = nil
local cashLabel: TextLabel? = nil
local incomeLabel: TextLabel? = nil
local rebirthLabel: TextLabel? = nil
local lockLabel: TextLabel? = nil
local tsunamiLabel: TextLabel? = nil
local promptLabel: TextLabel? = nil
local shopFrame: Frame? = nil
local state: any = nil
local world: any = nil

-- Shorten a big number: 1,234,567 becomes 1.23M.
local function shortNumber(n: number): string
	if n >= 1000000 then
		return string.format("%.2fM", n / 1000000)
	elseif n >= 1000 then
		return string.format("%.1fK", n / 1000)
	else
		return tostring(math.floor(n))
	end
end

local function makeLabel(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, textSize: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function makeButton(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 20
	button.Font = Enum.Font.GothamBold
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	return button
end

-- The shop panel: one row per item with its price and level.
local function buildShop(parent: Instance)
	local frame = Instance.new("Frame")
	frame.Name = "ShopFrame"
	frame.Size = UDim2.fromOffset(340, 300)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Text = "SHOP — spend your brainrot cash"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 20
	title.Font = Enum.Font.GothamBold
	title.Parent = frame
	local close = makeButton(frame, "CloseShop", "X", UDim2.fromOffset(36, 36), UDim2.new(1, -44, 0, 4), Color3.fromRGB(200, 60, 60))
	close.MouseButton1Click:Connect(function()
		frame.Visible = false
	end)
	local y = 48
	for _, item in BrainrotData.SHOP_ITEMS do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -16, 0, 44)
		row.Position = UDim2.fromOffset(8, y)
		row.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
		row.BorderSizePixel = 0
		row.Parent = frame
		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 8)
		rowCorner.Parent = row
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.55, 0, 1, 0)
		nameLabel.Position = UDim2.fromOffset(8, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = item.Name .. " — " .. item.Desc
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 14
		nameLabel.Font = Enum.Font.Gotham
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextWrapped = true
		nameLabel.Parent = row
		local buy = makeButton(row, "Buy" .. item.Id, "$" .. tostring(item.Price), UDim2.fromOffset(90, 32), UDim2.new(1, -98, 0.5, -16), Color3.fromRGB(60, 180, 80))
		buy.MouseButton1Click:Connect(function()
			BuyShop:FireServer(item.Id)
		end)
		y += 52
	end
	return frame
end

-- Build the whole HUD once.
function HUD.build()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BrainrotBayGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = player:WaitForChild("PlayerGui")
	gui = screenGui

	-- Top bar: cash, income, rebirths, lock.
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, 52)
	topBar.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	topBar.BackgroundTransparency = 0.25
	topBar.BorderSizePixel = 0
	topBar.Parent = screenGui

	local title = makeLabel(topBar, "Title", "BRAINROT BAY", UDim2.fromOffset(220, 52), UDim2.fromOffset(16, 0), 26, Color3.fromRGB(255, 210, 60))
	title.Font = Enum.Font.GothamBlack
	cashLabel = makeLabel(topBar, "Cash", "$100", UDim2.fromOffset(180, 52), UDim2.fromOffset(250, 0), 24, Color3.fromRGB(120, 255, 120))
	incomeLabel = makeLabel(topBar, "Income", "+$0/s", UDim2.fromOffset(150, 52), UDim2.fromOffset(440, 0), 20, Color3.fromRGB(140, 220, 255))
	rebirthLabel = makeLabel(topBar, "Rebirths", "Rebirth x1.0", UDim2.fromOffset(160, 52), UDim2.fromOffset(600, 0), 20, Color3.fromRGB(255, 190, 40))
	lockLabel = makeLabel(topBar, "Lock", "", UDim2.fromOffset(160, 52), UDim2.fromOffset(770, 0), 20, Color3.fromRGB(80, 170, 255))

	-- Tsunami banner under the top bar (hidden until a warning).
	tsunamiLabel = makeLabel(screenGui, "Tsunami", "", UDim2.fromOffset(500, 44), UDim2.new(0.5, -250, 0, 60), 24, Color3.fromRGB(255, 80, 80))
	tsunamiLabel.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
	tsunamiLabel.BackgroundTransparency = 0.3
	tsunamiLabel.TextXAlignment = Enum.TextXAlignment.Center
	tsunamiLabel.Visible = false

	-- Context prompt at the bottom centre: what E does right now.
	promptLabel = makeLabel(screenGui, "Prompt", "", UDim2.fromOffset(600, 40), UDim2.new(0.5, -300, 1, -120), 20, Color3.fromRGB(255, 255, 255))
	promptLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	promptLabel.BackgroundTransparency = 0.3
	promptLabel.TextXAlignment = Enum.TextXAlignment.Center
	promptLabel.Visible = false

	-- Buttons at the bottom right.
	local shopButton = makeButton(screenGui, "ShopButton", "SHOP", UDim2.fromOffset(120, 48), UDim2.new(1, -140, 1, -120), Color3.fromRGB(60, 120, 220))
	local rebirthButton = makeButton(screenGui, "RebirthButton", "REBIRTH", UDim2.fromOffset(120, 48), UDim2.new(1, -140, 1, -64), Color3.fromRGB(180, 80, 200))
	local lockButton = makeButton(screenGui, "LockButton", "LOCK (F)", UDim2.fromOffset(120, 48), UDim2.new(1, -270, 1, -64), Color3.fromRGB(80, 170, 255))
	shopFrame = buildShop(screenGui)
	shopButton.MouseButton1Click:Connect(function()
		if shopFrame then
			shopFrame.Visible = not shopFrame.Visible
		end
	end)
	rebirthButton.MouseButton1Click:Connect(function()
		Rebirth:FireServer()
	end)
	lockButton.MouseButton1Click:Connect(function()
		LockBase:FireServer()
	end)
end

-- Refresh the HUD from the latest state and world sync.
function HUD.update(newState: any, newWorld: any)
	state = newState or state
	world = newWorld or world
	if not gui then
		return
	end
	if state then
		if cashLabel then
			cashLabel.Text = "$" .. shortNumber(state.Cash)
		end
		if incomeLabel then
			incomeLabel.Text = "+$" .. shortNumber(state.Income) .. "/s"
		end
		if rebirthLabel then
			rebirthLabel.Text = "Rebirth x" .. string.format("%.2f", state.Multiplier) .. " (" .. tostring(state.Rebirths) .. ")"
			-- Show the rebirth cost on the button via the prompt area is
			-- noisy; the shop shows it instead. Keep the label short.
		end
		if lockLabel then
			if state.LockLeft > 0 then
				lockLabel.Text = "LOCKED " .. tostring(math.ceil(state.LockLeft)) .. "s"
			else
				lockLabel.Text = "Base open"
			end
		end
	end
	if world and tsunamiLabel then
		if world.Tsunami == "warning" then
			tsunamiLabel.Visible = true
			tsunamiLabel.Text = "TSUNAMI IN " .. tostring(math.ceil(world.TsunamiIn)) .. "s — GET TO YOUR BASE!"
		elseif world.Tsunami == "sweeping" then
			tsunamiLabel.Visible = true
			tsunamiLabel.Text = "TSUNAMI! HOLD ON!"
		else
			tsunamiLabel.Visible = false
		end
	end
end

-- Set the context prompt (what E does), or hide it.
function HUD.setPrompt(text: string?)
	if promptLabel then
		if text and text ~= "" then
			promptLabel.Visible = true
			promptLabel.Text = text
		else
			promptLabel.Visible = false
		end
	end
end

function HUD.getState(): any
	return state
end

function HUD.getWorld(): any
	return world
end

-- Wire the sync events to the HUD.
function HUD.listen()
	SyncState.OnClientEvent:Connect(function(newState)
		HUD.update(newState, nil)
	end)
	SyncWorld.OnClientEvent:Connect(function(newWorld)
		HUD.update(nil, newWorld)
	end)
end

return HUD
