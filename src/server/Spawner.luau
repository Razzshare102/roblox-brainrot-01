-- Brainrot Bay: the conveyor belt through the middle of the island.
-- Rolls a brainrot, walks it from the west gate to the east gate, and
-- sells it to the first player who presses E beside it with enough cash.

local BrainrotData = require(script.Parent.Parent.Shared.BrainrotData)
local GameState = require(script.Parent.GameState)

local Spawner = {}

Spawner.BELT_START_X = -38
Spawner.BELT_END_X = 38
Spawner.BELT_Y = 2.5
Spawner.BELT_SPEED = 4
Spawner.SPAWN_EVERY_SECONDS = 4
Spawner.MAX_ON_BELT = 6
Spawner.BUY_RANGE = 12

local beltBrainrots = {}
local beltFolder = nil

function Spawner.setFolder(folder)
	beltFolder = folder
end

function Spawner.getBeltBrainrots()
	return beltBrainrots
end

-- Build the little character model: a coloured body, a head, and a
-- floating label with its name, rarity colour and dollars per second.
function Spawner.buildBrainrotModel(record)
	local brainrot = BrainrotData.getBrainrot(record.brainrotId)
	local rarity = BrainrotData.RARITIES[brainrot.rarity]
	local mutation = BrainrotData.MUTATIONS[record.mutation]

	local model = Instance.new("Model")
	model.Name = brainrot.short

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(3, 3, 3)
	body.Color = rarity.color
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.8, 1.8, 1.8)
	head.Color = Color3.fromRGB(255, 220, 170)
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.CanCollide = false
	head.Parent = model

	local eyes = Instance.new("Decal")
	eyes.Name = "Face"
	eyes.Texture = "rbxasset://textures/face.png"
	eyes.Face = Enum.NormalId.Front
	eyes.Parent = head

	-- A golden, diamond or better brainrot glows: its body is neon and
	-- it carries a sparkle so players can spot it from across the plaza.
	if record.mutation ~= "Normal" then
		body.Material = Enum.Material.Neon
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "MutationSparkles"
		sparkles.Color = ColorSequence.new(mutation.color)
		sparkles.Rate = 6
		sparkles.Lifetime = NumberRange.new(0.6)
		sparkles.Speed = NumberRange.new(1)
		sparkles.Size = NumberSequence.new(0.5)
		sparkles.Parent = body
	end

	local label = Instance.new("BillboardGui")
	label.Name = "BrainrotLabel"
	label.Size = UDim2.new(0, 140, 0, 44)
	label.StudsOffset = Vector3.new(0, 3.5, 0)
	label.AlwaysOnTop = true
	label.Parent = model

	local nameTag = Instance.new("TextLabel")
	nameTag.Name = "NameTag"
	nameTag.Size = UDim2.new(1, 0, 0.55, 0)
	nameTag.BackgroundTransparency = 1
	nameTag.Font = Enum.Font.GothamBold
	nameTag.TextSize = 15
	nameTag.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameTag.TextStrokeTransparency = 0
	nameTag.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameTag.Text = BrainrotData.labelText(brainrot, record.mutation)
	nameTag.Parent = label

	local rateTag = Instance.new("TextLabel")
	rateTag.Name = "RateTag"
	rateTag.Size = UDim2.new(1, 0, 0.45, 0)
	rateTag.Position = UDim2.new(0, 0, 0.55, 0)
	rateTag.BackgroundTransparency = 1
	rateTag.Font = Enum.Font.GothamBold
	rateTag.TextSize = 14
	rateTag.TextColor3 = rarity.color
	rateTag.TextStrokeTransparency = 0
	rateTag.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	rateTag.Text = string.format("$%d/s", BrainrotData.baseIncome(brainrot, record.mutation))
	rateTag.Parent = label

	model:SetAttribute("InstanceId", record.instanceId)
	model:SetAttribute("BrainrotId", record.brainrotId)
	model:SetAttribute("Mutation", record.mutation)
	model.PrimaryPart = body
	return model
end

function Spawner.spawnBrainrot()
	if #beltBrainrots >= Spawner.MAX_ON_BELT then
		return nil
	end
	local brainrot, mutation = BrainrotData.rollBrainrot()
	local record = {
		instanceId = GameState.newBrainrotId(),
		brainrotId = brainrot.id,
		mutation = mutation,
	}
	local model = Spawner.buildBrainrotModel(record)
	model:PivotTo(CFrame.new(Spawner.BELT_START_X, Spawner.BELT_Y + 1.5, 0))
	model.Parent = beltFolder
	table.insert(beltBrainrots, { record = record, model = model })
	return record
end

-- Walk every brainrot along the belt; the ones that reach the east gate
-- wander off and despawn.
function Spawner.stepBelt(dt)
	for index = #beltBrainrots, 1, -1 do
		local entry = beltBrainrots[index]
		local model = entry.model
		if not model or not model.Parent then
			table.remove(beltBrainrots, index)
		else
			local pivot = model:GetPivot()
			local nextX = pivot.Position.X + Spawner.BELT_SPEED * dt
			if nextX >= Spawner.BELT_END_X then
				model:Destroy()
				table.remove(beltBrainrots, index)
			else
				model:PivotTo(CFrame.new(nextX, pivot.Position.Y, pivot.Position.Z))
			end
		end
	end
end

function Spawner.findBeltBrainrot(instanceId)
	for _, entry in ipairs(beltBrainrots) do
		if entry.record.instanceId == instanceId then
			return entry
		end
	end
	return nil
end

function Spawner.removeBeltBrainrot(entry)
	for index, other in ipairs(beltBrainrots) do
		if other == entry then
			table.remove(beltBrainrots, index)
			break
		end
	end
	if entry.model then
		entry.model:Destroy()
	end
end

function Spawner.nearestBeltBrainrot(position, maxDistance)
	local nearest = nil
	local nearestDistance = maxDistance
	for _, entry in ipairs(beltBrainrots) do
		local model = entry.model
		if model and model.PrimaryPart then
			local distance = (model.PrimaryPart.Position - position).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearest = entry
			end
		end
	end
	return nearest, nearestDistance
end

return Spawner
