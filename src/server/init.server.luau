-- init.server: the server boots here. It wires the modules together,
-- builds the per-base visuals, answers the client's RemoteEvents, ticks
-- income every second, and runs the belt, the wave and the steal system.
-- All rules are enforced on this side; the client only asks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BrainrotData = require(ReplicatedStorage.Shared.BrainrotData)
local GameState = require(script.Parent.GameState)
local Spawner = require(script.Parent.Spawner)
local StealSystem = require(script.Parent.StealSystem)
local Tsunami = require(script.Parent.Tsunami)
local Shop = require(script.Parent.Shop)

-- The 8 base plots, in ring order. The world puts a folder Base1..Base8
-- in Workspace, each with a Platform part and Slot1..Slot6 pad parts.
local BASE_COUNT = 8
local BASE_RADIUS = 95

-- Base plot centre, by base number (1..8). Angle 0 is east (+X); the
-- plots run counter-clockwise so Base1 sits east, Base3 north.
local function baseCenter(baseNumber: number): Vector3
	local angle = (baseNumber - 1) * (math.pi * 2 / BASE_COUNT)
	return Vector3.new(math.cos(angle) * BASE_RADIUS, 0, math.sin(angle) * BASE_RADIUS)
end

-- RemoteEvents, one folder in ReplicatedStorage. The client fires these
-- and the server answers; the server also fires SyncState and SyncWorld.
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local function makeRemote(name: string): RemoteEvent
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remotes
	return event
end

local BuyBrainrot = makeRemote("BuyBrainrot")
local PickupBrainrot = makeRemote("PickupBrainrot")
local PlaceStolen = makeRemote("PlaceStolen")
local DropCarried = makeRemote("DropCarried")
local Slap = makeRemote("Slap")
local LockBase = makeRemote("LockBase")
local BuyShop = makeRemote("BuyShop")
local Rebirth = makeRemote("Rebirth")
local PickupDropped = makeRemote("PickupDropped")
local SyncState = makeRemote("SyncState")
local SyncWorld = makeRemote("SyncWorld")

-- Folders for the things the server builds at runtime.
local worldFolder = Instance.new("Folder")
worldFolder.Name = "ServerWorld"
worldFolder.Parent = Workspace

local baseModelsFolder = Instance.new("Folder")
baseModelsFolder.Name = "BaseBrainrots"
baseModelsFolder.Parent = worldFolder

-- Base brainrot models, by owned uid, so taking one off removes its model.
local baseModels: { [string]: Model } = {}
-- Which player each base model belongs to, by owned uid.
local baseModelOwners: { [string]: Player } = {}

-- The forcefield wall shown around a locked base, by base number.
local lockWalls: { [number]: Part } = {}

-- Build a brainrot model standing on a base slot.
local function buildBaseModel(def: BrainrotData.BrainrotDef, mutationName: string, mult: number): Model
	local model = Instance.new("Model")
	model.Name = def.Name
	local size = def.Size
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(size, size, size)
	body.Color = def.Color
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(size * 0.62, size * 0.62, size * 0.62)
	head.Color = def.Color
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.CanCollide = false
	head.Position = Vector3.new(0, size * 0.72, 0)
	head.Parent = model
	local label = Instance.new("BillboardGui")
	label.Name = "BaseLabel"
	label.Size = UDim2.fromOffset(140, 52)
	label.StudsOffset = Vector3.new(0, size * 1.45, 0)
	label.AlwaysOnTop = true
	label.Parent = model
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(1, 0.4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = def.Name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = label
	local rateLabel = Instance.new("TextLabel")
	rateLabel.Position = UDim2.fromScale(0, 0.4)
	rateLabel.Size = UDim2.fromScale(1, 0.3)
	rateLabel.BackgroundTransparency = 1
	local rarityText = def.Rarity
	if mutationName ~= "Normal" then
		rarityText = mutationName .. " " .. def.Rarity
	end
	rateLabel.Text = rarityText
	rateLabel.TextColor3 = BrainrotData.RARITY_COLORS[def.Rarity]
	rateLabel.TextScaled = true
	rateLabel.Font = Enum.Font.GothamBold
	rateLabel.Parent = label
	local moneyLabel = Instance.new("TextLabel")
	moneyLabel.Position = UDim2.fromScale(0, 0.7)
	moneyLabel.Size = UDim2.fromScale(1, 0.3)
	moneyLabel.BackgroundTransparency = 1
	moneyLabel.Text = "$" .. tostring(def.Rate * mult) .. "/s"
	moneyLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
	moneyLabel.TextScaled = true
	moneyLabel.Font = Enum.Font.GothamBold
	moneyLabel.Parent = label
	model.PrimaryPart = body
	return model
end

-- Place a brainrot model on a base slot, and remember it by uid.
local function showOnBase(player: Player, owned: GameState.OwnedBrainrot)
	local baseNumber = StealSystem.baseOf(player)
	if baseNumber == 0 then
		return
	end
	local def = BrainrotData.getById(owned.DefId)
	if not def then
		return
	end
	local center = baseCenter(baseNumber)
	local offset = StealSystem.slotOffset(owned.Slot)
	-- The platform top is at y = 2; the model sits on it.
	local pos = Vector3.new(center.X + offset.X, 2 + def.Size * 0.5, center.Z + offset.Z)
	local model = buildBaseModel(def, owned.Mutation, owned.Mult)
	model:PivotTo(CFrame.new(pos))
	model.Parent = baseModelsFolder
	baseModels[owned.Uid] = model
	baseModelOwners[owned.Uid] = player
end

local function hideFromBase(uid: string)
	local model = baseModels[uid]
	if model then
		model:Destroy()
		baseModels[uid] = nil
		baseModelOwners[uid] = nil
	end
end

-- Rebuild one player's whole base display from their state.
local function refreshBase(player: Player)
	local state = GameState.get(player)
	if not state then
		return
	end
	-- Destroy only this player's models, then show the current ones.
	for uid, model in baseModels do
		if baseModelOwners[uid] == player then
			model:Destroy()
			baseModels[uid] = nil
			baseModelOwners[uid] = nil
		end
	end
	for _, owned in state.Brainrots do
		showOnBase(player, owned)
	end
end

-- The sign over a base: owner name, lock state and income. Rebuilt when
-- a base is claimed; the lock text is updated by the sync loop.
local function buildBaseSign(baseNumber: number, owner: Player)
	local center = baseCenter(baseNumber)
	-- A floating sign above the back of the plot.
	local sign = Instance.new("Part")
	sign.Name = "BaseSign" .. tostring(baseNumber)
	sign.Size = Vector3.new(14, 4, 1)
	sign.Color = Color3.fromRGB(40, 40, 50)
	sign.Material = Enum.Material.SmoothPlastic
	sign.Anchored = true
	sign.CanCollide = false
	-- Stand it at the outer edge of the plot, facing the centre.
	local angle = (baseNumber - 1) * (math.pi * 2 / BASE_COUNT)
	local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local pos = center + outward * 12
	sign.Position = Vector3.new(pos.X, 10, pos.Z)
	sign.CFrame = CFrame.lookAt(sign.Position, Vector3.new(0, 6, 0))
	sign.Parent = worldFolder
	local gui = Instance.new("BillboardGui")
	gui.Name = "SignGui"
	gui.Size = UDim2.fromOffset(220, 70)
	gui.StudsOffset = Vector3.new(0, 0, 0)
	gui.AlwaysOnTop = true
	gui.Parent = sign
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "OwnerName"
	nameLabel.Size = UDim2.fromScale(1, 0.5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = owner.Name .. "'s Base"
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = gui
	local lockLabel = Instance.new("TextLabel")
	lockLabel.Name = "LockStatus"
	lockLabel.Position = UDim2.fromScale(0, 0.5)
	lockLabel.Size = UDim2.fromScale(1, 0.5)
	lockLabel.BackgroundTransparency = 1
	lockLabel.Text = "OPEN — steal me!"
	lockLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
	lockLabel.TextScaled = true
	lockLabel.Font = Enum.Font.GothamBold
	lockLabel.Parent = gui
end

-- A translucent wall around a base while it is locked.
local function buildLockWall(baseNumber: number): Part
	local center = baseCenter(baseNumber)
	local wall = Instance.new("Part")
	wall.Name = "LockWall" .. tostring(baseNumber)
	wall.Size = Vector3.new(28, 14, 28)
	wall.Color = Color3.fromRGB(80, 170, 255)
	wall.Material = Enum.Material.ForceField
	wall.Transparency = 0.6
	wall.Anchored = true
	wall.CanCollide = false
	wall.Position = Vector3.new(center.X, 9, center.Z)
	wall.Parent = worldFolder
	return wall
end

-- Distance from a player to a point, in studs. Nil when no character.
local function distanceTo(player: Player, position: Vector3): number?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	return ((root :: BasePart).Position - position).Magnitude
end

-- Is the player standing on their own base platform?
local function isOnOwnBase(player: Player): boolean
	local baseNumber = StealSystem.baseOf(player)
	if baseNumber == 0 then
		return false
	end
	local center = baseCenter(baseNumber)
	local dist = distanceTo(player, Vector3.new(center.X, 2, center.Z))
	if not dist then
		return false
	end
	return dist < 16
end

-- Remote: buy the belt brainrot with this uid.
BuyBrainrot.OnServerEvent:Connect(function(player: Player, uid: string)
	local state = GameState.get(player)
	if not state then
		return
	end
	local record: Spawner.BeltBrainrot? = nil
	for _, item in Spawner.getBelt() do
		if item.Uid == uid then
			record = item
			break
		end
	end
	if not record or record.Bought then
		return
	end
	-- The player must stand close to the brainrot on the belt.
	local position = record.Model:GetPivot().Position
	local dist = distanceTo(player, position)
	if not dist or dist > 14 then
		return
	end
	if state.Cash < record.Price then
		return
	end
	if GameState.freeSlot(state) == 0 then
		return
	end
	state.Cash -= record.Price
	Spawner.takeBought(record)
	local owned = GameState.placeBrainrot(state, record.Def.Id, record.Mutation, record.Mult)
	if owned then
		showOnBase(player, owned)
	end
end)

-- Remote: pick a brainrot up off another player's base.
PickupBrainrot.OnServerEvent:Connect(function(player: Player, ownerName: string, uid: string)
	local owner: Player? = nil
	for _, other in Players:GetPlayers() do
		if other.Name == ownerName then
			owner = other
			break
		end
	end
	if not owner then
		return
	end
	local ownerState = GameState.get(owner)
	if not ownerState then
		return
	end
	-- The player must stand close to the brainrot on that base.
	local ownerBase = StealSystem.baseOf(owner)
	if ownerBase == 0 then
		return
	end
	local owned = GameState.findBrainrot(ownerState, uid)
	if not owned then
		return
	end
	local center = baseCenter(ownerBase)
	local offset = StealSystem.slotOffset(owned.Slot)
	local position = Vector3.new(center.X + offset.X, 2, center.Z + offset.Z)
	local dist = distanceTo(player, position)
	if not dist or dist > StealSystem.PICKUP_RANGE then
		return
	end
	local record, _reason = StealSystem.pickUp(player, owner, uid)
	if record then
		hideFromBase(uid)
	end
end)

-- Remote: put a stolen brainrot down on the thief's own base.
PlaceStolen.OnServerEvent:Connect(function(player: Player)
	if not isOnOwnBase(player) then
		return
	end
	local placed = StealSystem.placeStolen(player)
	if placed then
		showOnBase(player, placed)
	end
end)

-- Remote: drop what the player carries.
DropCarried.OnServerEvent:Connect(function(player: Player)
	StealSystem.dropCarried(player)
end)

-- Remote: pick a dropped brainrot up off the ground.
PickupDropped.OnServerEvent:Connect(function(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local record = StealSystem.nearestDropped((root :: BasePart).Position, 10)
	if not record then
		return
	end
	local state = GameState.get(player)
	if not state then
		return
	end
	if StealSystem.pickUpDropped(player, record) then
		-- Show it on the player's base.
		for _, owned in state.Brainrots do
			if owned.DefId == record.DefId and owned.Mutation == record.Mutation then
				showOnBase(player, owned)
				break
			end
		end
	end
end)

-- Remote: slap the nearest player in front of you.
Slap.OnServerEvent:Connect(function(player: Player, targetName: string)
	local target: Player? = nil
	for _, other in Players:GetPlayers() do
		if other.Name == targetName then
			target = other
			break
		end
	end
	if target then
		StealSystem.slap(player, target)
	end
end)

-- Remote: lock your own base.
LockBase.OnServerEvent:Connect(function(player: Player)
	local state = GameState.get(player)
	if not state then
		return
	end
	local seconds = Shop.lockSeconds(state)
	if GameState.lockBase(state, seconds) then
		local baseNumber = StealSystem.baseOf(player)
		if baseNumber ~= 0 then
			local wall = lockWalls[baseNumber]
			if not wall then
				wall = buildLockWall(baseNumber)
				lockWalls[baseNumber] = wall
			end
			wall.Transparency = 0.6
		end
	end
end)

-- Remote: buy a shop item.
BuyShop.OnServerEvent:Connect(function(player: Player, itemId: string)
	Shop.buy(player, itemId)
end)

-- Remote: rebirth.
Rebirth.OnServerEvent:Connect(function(player: Player)
	local state = GameState.get(player)
	if not state then
		return
	end
	if GameState.rebirth(state) then
		-- Clear the base display: the brainrots are gone.
		refreshBase(player)
	end
end)

-- A player joins: state, a base, a sign, and their walk speed.
local function onPlayerAdded(player: Player)
	GameState.add(player)
	local baseNumber = StealSystem.claimBase(player)
	if baseNumber ~= 0 then
		buildBaseSign(baseNumber, player)
	end
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		local state = GameState.get(player)
		local speed = 16
		if state then
			speed = 16 + 2 * state.SpeedLevel
			if state.Carrying ~= nil then
				speed = 8 + 2 * state.SpeedLevel
			end
		end
		(humanoid :: Humanoid).WalkSpeed = speed
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

-- Init the systems.
Spawner.init(worldFolder)
StealSystem.init(worldFolder)
Tsunami.init(worldFolder)

-- The income tick and the sync, once a second.
local lastSync = 0
local lastIncome = 0
RunService.Heartbeat:Connect(function(dt)
	-- The belt, the wave and dropped brainrots move every frame.
	Spawner.step(dt)
	local tsunamiState = Tsunami.step(dt)
	StealSystem.step(dt)

	-- Hide lock walls whose lock has expired.
	for baseNumber, wall in lockWalls do
		local owner = StealSystem.ownerOfBase(baseNumber)
		if owner then
			local state = GameState.get(owner)
			if state and not GameState.isLocked(state) then
				wall.Transparency = 1
			end
		end
	end

	-- Once a second: pay income and sync every player.
	local now = os.clock()
	if now - lastIncome >= 1 then
		lastIncome = now
		GameState.forEach(function(_player, state)
			state.Cash += GameState.incomePerSecond(state)
		end)
	end
	if now - lastSync >= 1 then
		lastSync = now
		-- Each player's own state.
		for _, player in Players:GetPlayers() do
			local state = GameState.get(player)
			if state then
				local brainrots = {}
				for _, owned in state.Brainrots do
					table.insert(brainrots, {
						Uid = owned.Uid,
						DefId = owned.DefId,
						Mutation = owned.Mutation,
						Mult = owned.Mult,
						Slot = owned.Slot,
					})
				end
				SyncState:FireClient(player, {
					Cash = math.floor(state.Cash),
					Income = GameState.incomePerSecond(state),
					Rebirths = state.Rebirths,
					Multiplier = state.Multiplier,
					Slots = state.Slots,
					Brainrots = brainrots,
					LockLeft = GameState.lockSecondsLeft(state),
					RebirthCost = GameState.rebirthCost(state),
					Carrying = state.Carrying ~= nil,
					BoostLeft = math.max(0, state.BoostUntil - now),
				})
			end
		end
		-- The world: the belt, the bases and the wave.
		local belt = {}
		for _, record in Spawner.getBelt() do
			table.insert(belt, {
				Uid = record.Uid,
				DefId = record.Def.Id,
				Name = record.Def.Name,
				Rarity = record.Def.Rarity,
				Mutation = record.Mutation,
				Rate = record.Def.Rate * record.Mult,
				Price = record.Price,
				X = record.X,
			})
		end
		local bases = {}
		for i = 1, BASE_COUNT do
			local owner = StealSystem.ownerOfBase(i)
			local locked = false
			local ownerName = ""
			if owner then
				ownerName = owner.Name
				local ownerState = GameState.get(owner)
				if ownerState then
					locked = GameState.isLocked(ownerState)
				end
			end
			table.insert(bases, { Number = i, Owner = ownerName, Locked = locked })
		end
		SyncWorld:FireAllClients({
			Belt = belt,
			Bases = bases,
			Tsunami = tsunamiState,
			TsunamiIn = Tsunami.secondsUntilWave(),
		})
	end
end)

print("Brainrot Bay server ready.")
