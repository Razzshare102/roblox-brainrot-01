-- Brainrot Bay: the server boot. Wires every module together, creates the
-- remotes the client talks on, claims a base per player, ticks income
-- once a second and runs the belt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BrainrotData = require(script.Parent.Parent.Shared.BrainrotData)
local GameState = require(script.Parent.GameState)
local Spawner = require(script.Parent.Spawner)
local StealSystem = require(script.Parent.StealSystem)
local Tsunami = require(script.Parent.Tsunami)
local Shop = require(script.Parent.Shop)

-- Folders the world keeps its moving pieces in.
local beltFolder = Instance.new("Folder")
beltFolder.Name = "BeltBrainrots"
beltFolder.Parent = workspace

local baseFolder = Instance.new("Folder")
baseFolder.Name = "BaseBrainrots"
baseFolder.Parent = workspace

local droppedFolder = Instance.new("Folder")
droppedFolder.Name = "DroppedBrainrots"
droppedFolder.Parent = workspace

Spawner.setFolder(beltFolder)
StealSystem.setFolders(baseFolder, droppedFolder)
Tsunami.buildWave(workspace)

-- Every remote the client uses, in one folder.
local remotes = Instance.new("Folder")
remotes.Name = "BrainrotRemotes"
remotes.Parent = ReplicatedStorage

local function makeRemote(name)
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local BuyBelt = makeRemote("BuyBelt")
local GrabBase = makeRemote("GrabBase")
local PlaceCarried = makeRemote("PlaceCarried")
local DropCarried = makeRemote("DropCarried")
local PickupDropped = makeRemote("PickupDropped")
local Slap = makeRemote("Slap")
local LockBase = makeRemote("LockBase")
local BuyShop = makeRemote("BuyShop")
local DoRebirth = makeRemote("DoRebirth")
local StateSync = makeRemote("StateSync")
local TsunamiSync = makeRemote("TsunamiSync")
local Toast = makeRemote("Toast")

local function syncPlayer(player)
	local state = GameState.getState(player)
	if state then
		StateSync:FireClient(player, GameState.syncSnapshot(state))
	end
end

local function toast(player, message)
	Toast:FireClient(player, message)
end

-- A name sign over each base's totem, and a red lock frame that appears
-- while the base is locked.
local baseSigns = {}
local baseLockFrames = {}

local function buildBaseFurniture()
	for index, base in ipairs(GameState.BASES) do
		local totemTop = workspace:FindFirstChild("Base" .. index .. "TotemTop")
		if totemTop then
			local sign = Instance.new("BillboardGui")
			sign.Name = "BaseSign"
			sign.Size = UDim2.new(0, 160, 0, 40)
			sign.StudsOffset = Vector3.new(0, 4, 0)
			sign.AlwaysOnTop = true
			sign.Parent = totemTop
			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, 1, 0)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamBold
			label.TextSize = 18
			label.TextColor3 = Color3.fromRGB(255, 255, 255)
			label.TextStrokeTransparency = 0
			label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			label.Text = "EMPTY BASE"
			label.Parent = sign
			baseSigns[index] = label
		end
		local frame = Instance.new("Part")
		frame.Name = "LockFrame" .. index
		frame.Size = Vector3.new(28, 0.5, 28)
		frame.Position = Vector3.new(base.center.X, 4.5, base.center.Z)
		frame.Color = Color3.fromRGB(255, 60, 60)
		frame.Material = Enum.Material.Neon
		frame.Transparency = 1
		frame.Anchored = true
		frame.CanCollide = false
		frame.Parent = workspace
		baseLockFrames[index] = frame
	end
end

local function refreshLockFrames()
	for index = 1, #GameState.BASES do
		local ownerId = GameState.baseOwner(index)
		local frame = baseLockFrames[index]
		if not frame then
			continue
		end
		local locked = false
		if ownerId then
			local ownerState = GameState.getStateByUserId(ownerId)
			if ownerState then
				locked = GameState.isLocked(ownerState)
			end
		end
		frame.Transparency = locked and 0.4 or 1
	end
end

local function onPlayerAdded(player)
	local state = GameState.newState(player)
	local baseIndex = GameState.claimBase(player)
	if baseIndex > 0 and baseSigns[baseIndex] then
		baseSigns[baseIndex].Text = player.Name .. "'s BASE"
	end
	local function onCharacterAdded(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.WalkSpeed = 16 + 2 * state.speedLevel
		humanoid.Died:Connect(function()
			if state.carrying then
				StealSystem.dropCarried(player)
				syncPlayer(player)
			end
		end)
	end
	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
	task.delay(1, function()
		syncPlayer(player)
	end)
end

local function onPlayerRemoving(player)
	local state = GameState.getState(player)
	if state then
		if state.baseIndex > 0 and baseSigns[state.baseIndex] then
			baseSigns[state.baseIndex].Text = "EMPTY BASE"
		end
		for slotIndex, _ in pairs(state.brainrots) do
			StealSystem.removeBaseModel(player.UserId, slotIndex)
		end
	end
	GameState.removeState(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- Buy a brainrot off the belt.
BuyBelt.OnServerEvent:Connect(function(player, instanceId)
	local state = GameState.getState(player)
	if not state then
		return
	end
	local entry = Spawner.findBeltBrainrot(instanceId)
	if not entry then
		toast(player, "That brainrot is gone.")
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or (entry.model.PrimaryPart.Position - root.Position).Magnitude > Spawner.BUY_RANGE then
		toast(player, "Get closer to buy it.")
		return
	end
	local brainrot = BrainrotData.getBrainrot(entry.record.brainrotId)
	local cost = BrainrotData.buyCost(brainrot)
	if state.cash < cost then
		toast(player, string.format("You need $%d for %s.", cost, brainrot.name))
		return
	end
	if GameState.freeSlot(state) == nil then
		toast(player, "Your base is full.")
		return
	end
	if not GameState.spendCash(player, cost) then
		toast(player, "You need more cash.")
		return
	end
	local record = entry.record
	Spawner.removeBeltBrainrot(entry)
	local ok, result = StealSystem.placeBrainrotOnBase(player, record)
	if not ok then
		GameState.addCash(player, cost)
		toast(player, result)
		return
	end
	syncPlayer(player)
	toast(player, string.format("Bought %s for $%d!", brainrot.name, cost))
end)

GrabBase.OnServerEvent:Connect(function(player, ownerUserId, slotIndex)
	local ok, result = StealSystem.grabFromBase(player, ownerUserId, slotIndex)
	if ok then
		syncPlayer(player)
		toast(player, "RUN HOME! Place it on your base with E.")
	else
		toast(player, result)
	end
end)

PlaceCarried.OnServerEvent:Connect(function(player)
	local ok, result = StealSystem.placeCarried(player)
	if ok then
		syncPlayer(player)
		toast(player, "Placed! It earns money for you now.")
	else
		toast(player, result)
	end
end)

DropCarried.OnServerEvent:Connect(function(player)
	local ok, result = StealSystem.dropCarried(player)
	if ok then
		syncPlayer(player)
	else
		toast(player, result)
	end
end)

PickupDropped.OnServerEvent:Connect(function(player, instanceId)
	local ok, result = StealSystem.pickupDropped(player, instanceId)
	if ok then
		syncPlayer(player)
		toast(player, "Picked it up! Place it on your base with E.")
	else
		toast(player, result)
	end
end)

Slap.OnServerEvent:Connect(function(player)
	local ok, result = StealSystem.slap(player)
	if not ok then
		toast(player, result)
	end
end)

LockBase.OnServerEvent:Connect(function(player)
	local state = GameState.getState(player)
	if not state or state.baseIndex == 0 then
		return
	end
	if GameState.isLocked(state) then
		toast(player, "Your base is already locked.")
		return
	end
	local cooldown = GameState.lockCooldownLeft(state)
	if cooldown > 0 then
		toast(player, string.format("Lock recharges in %ds.", cooldown))
		return
	end
	state.lockUntil = os.time() + GameState.lockDuration(state)
	state.lockCooldownUntil = state.lockUntil + BrainrotData.LOCK_COOLDOWN_SECONDS
	refreshLockFrames()
	syncPlayer(player)
	toast(player, string.format("Base locked for %ds!", GameState.lockDuration(state)))
end)

BuyShop.OnServerEvent:Connect(function(player, itemId)
	local ok, message = Shop.buyItem(player, itemId)
	toast(player, message)
	if ok then
		syncPlayer(player)
	end
end)

DoRebirth.OnServerEvent:Connect(function(player)
	local ok, message = Shop.doRebirth(player)
	toast(player, message)
	if ok then
		syncPlayer(player)
	end
end)

Tsunami.onPhaseChanged(function(phase, secondsLeft)
	TsunamiSync:FireAllClients(phase, secondsLeft)
end)

buildBaseFurniture()
Tsunami.start()

-- The belt loop: spawn on a timer, walk the belt every frame.
task.spawn(function()
	while true do
		task.wait(Spawner.SPAWN_EVERY_SECONDS)
		Spawner.spawnBrainrot()
	end
end)

RunService.Heartbeat:Connect(function(dt)
	Spawner.stepBelt(dt)
end)

-- Income ticks once a second; dropped brainrots and lock frames refresh
-- on the same beat.
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local state = GameState.getState(player)
			if state then
				local income = GameState.totalIncome(state)
				if income > 0 then
					state.cash += income
				end
				syncPlayer(player)
			end
		end
		StealSystem.sweepDropped()
		refreshLockFrames()
	end
end)
