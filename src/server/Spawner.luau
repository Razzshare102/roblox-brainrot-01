-- Spawner: brainrots ride the central conveyor belt. A new one rolls a
-- rarity and a mutation, spawns at the west end of the belt and walks
-- east; if nobody buys it before the east end, it despawns. The belt is
-- the game's shop window: what walks past is what you can buy.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BrainrotData = require(ReplicatedStorage.Shared.BrainrotData)

local Spawner = {}

-- The belt runs along X at this height (top of the belt part) and width.
Spawner.BELT_Y = 2
Spawner.BELT_START_X = -38
Spawner.BELT_END_X = 38
Spawner.BELT_Z = 0
Spawner.WALK_SPEED = 3 -- studs per second along the belt
Spawner.SPAWN_EVERY = 6 -- seconds between spawns (shorter when few are out)
Spawner.MAX_ON_BELT = 8

export type BeltBrainrot = {
	Uid: string,
	Model: Model,
	Def: BrainrotData.BrainrotDef,
	Mutation: string,
	Mult: number,
	Price: number,
	X: number,
	Bought: boolean,
}

local belt: { BeltBrainrot } = {}
local folder: Folder? = nil
local lastSpawnAt = 0
local beltUidCounter = 0

-- Weighted roll over a {Name, Weight} list. Returns the picked entry.
local function rollWeighted(list): any
	local total = 0
	for _, entry in list do
		total += entry.Weight
	end
	local roll = math.random() * total
	for _, entry in list do
		roll -= entry.Weight
		if roll <= 0 then
			return entry
		end
	end
	return list[1]
end

-- Roll a rarity, then a brainrot of that rarity, then its mutation.
function Spawner.rollBrainrot(): (BrainrotData.BrainrotDef, string, number)
	-- RARITY_WEIGHTS is a map, so build the weighted list first.
	local rarityList = {}
	for name, weight in BrainrotData.RARITY_WEIGHTS do
		table.insert(rarityList, { Name = name, Weight = weight })
	end
	-- Keep the ladder order so the roll is deterministic in shape.
	table.sort(rarityList, function(a, b)
		return BrainrotData.rarityIndex(a.Name) < BrainrotData.rarityIndex(b.Name)
	end)
	local rarityEntry = rollWeighted(rarityList)
	local rarityName: string = rarityEntry.Name
	local defs = BrainrotData.getByRarity(rarityName)
	local def = defs[math.random(1, #defs)]
	local mutation = rollWeighted(BrainrotData.MUTATIONS)
	return def, mutation.Name, mutation.Mult
end

-- Build the visible brainrot: a chunky body, a head, a classic smile and
-- a name label. Built from parts only, so it needs no uploaded assets.
local function buildModel(def: BrainrotData.BrainrotDef, mutationName: string, mult: number): Model
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

	-- A little head on top, so it reads as a character, not a ball.
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

	-- Eyes and a smile, drawn as small parts on the head.
	local eyeColor = Color3.fromRGB(30, 30, 30)
	for _, x in { -0.16, 0.16 } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(size * 0.1, size * 0.14, size * 0.05)
		eye.Color = eyeColor
		eye.Material = Enum.Material.SmoothPlastic
		eye.Anchored = true
		eye.CanCollide = false
		eye.Position = Vector3.new(x * size, size * 0.78, size * 0.3)
		eye.Parent = model
	end
	local mouth = Instance.new("Part")
	mouth.Name = "Mouth"
	mouth.Size = Vector3.new(size * 0.24, size * 0.05, size * 0.05)
	mouth.Color = eyeColor
	mouth.Material = Enum.Material.SmoothPlastic
	mouth.Anchored = true
	mouth.CanCollide = false
	mouth.Position = Vector3.new(0, size * 0.58, size * 0.3)
	mouth.Parent = model

	-- Mutation crown: a small gold/diamond star above mutated brainrots.
	if mult > 1 then
		local star = Instance.new("Part")
		star.Name = "MutationStar"
		star.Size = Vector3.new(size * 0.3, size * 0.3, size * 0.1)
		star.Color = Color3.fromRGB(255, 210, 60)
		star.Material = Enum.Material.Neon
		star.Anchored = true
		star.CanCollide = false
		star.Position = Vector3.new(0, size * 1.15, 0)
		star.Parent = model
	end

	-- The label the player reads: name, rarity, mutation and $/sec.
	local label = Instance.new("BillboardGui")
	label.Name = "BrainrotLabel"
	label.Size = UDim2.fromOffset(140, 52)
	label.StudsOffset = Vector3.new(0, size * 1.45, 0)
	label.AlwaysOnTop = true
	label.Parent = model

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.fromScale(1, 0.4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = def.Name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = label

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "Rarity"
	rarityLabel.Position = UDim2.fromScale(0, 0.4)
	rarityLabel.Size = UDim2.fromScale(1, 0.3)
	rarityLabel.BackgroundTransparency = 1
	local rarityText = def.Rarity
	if mutationName ~= "Normal" then
		rarityText = mutationName .. " " .. def.Rarity
	end
	rarityLabel.Text = rarityText
	rarityLabel.TextColor3 = BrainrotData.RARITY_COLORS[def.Rarity]
	rarityLabel.TextScaled = true
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.Parent = label

	local rateLabel = Instance.new("TextLabel")
	rateLabel.Name = "Rate"
	rateLabel.Position = UDim2.fromScale(0, 0.7)
	rateLabel.Size = UDim2.fromScale(1, 0.3)
	rateLabel.BackgroundTransparency = 1
	rateLabel.Text = "$" .. tostring(def.Rate * mult) .. "/s  •  $" .. tostring(def.Price)
	rateLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
	rateLabel.TextScaled = true
	rateLabel.Font = Enum.Font.GothamBold
	rateLabel.Parent = label

	model.PrimaryPart = body
	return model
end

-- Spawn one brainrot on the belt and return its record.
function Spawner.spawnOne(): BeltBrainrot?
	if #belt >= Spawner.MAX_ON_BELT then
		return nil
	end
	local def, mutationName, mult = Spawner.rollBrainrot()
	local model = buildModel(def, mutationName, mult)
	model:PivotTo(CFrame.new(Spawner.BELT_START_X, Spawner.BELT_Y + def.Size * 0.5, Spawner.BELT_Z))
	model.Parent = folder
	beltUidCounter += 1
	local record: BeltBrainrot = {
		Uid = "belt" .. tostring(beltUidCounter),
		Model = model,
		Def = def,
		Mutation = mutationName,
		Mult = mult,
		Price = def.Price,
		X = Spawner.BELT_START_X,
		Bought = false,
	}
	table.insert(belt, record)
	return record
end

-- Move every brainrot along the belt; despawn ones that reach the end.
function Spawner.step(dt: number)
	for i = #belt, 1, -1 do
		local record = belt[i]
		if record.Bought then
			table.remove(belt, i)
		else
			record.X += Spawner.WALK_SPEED * dt
			local pivot = record.Model:GetPivot()
			record.Model:PivotTo(CFrame.new(record.X, pivot.Position.Y, Spawner.BELT_Z))
			if record.X >= Spawner.BELT_END_X then
				record.Model:Destroy()
				table.remove(belt, i)
			end
		end
	end
	-- Keep the belt stocked: spawn faster when it is empty.
	local now = os.clock()
	local interval = Spawner.SPAWN_EVERY
	if #belt <= 2 then
		interval = 3
	end
	if now - lastSpawnAt >= interval then
		lastSpawnAt = now
		Spawner.spawnOne()
	end
end

-- The belt brainrot nearest to a point, within maxDistance studs.
function Spawner.nearestTo(position: Vector3, maxDistance: number): BeltBrainrot?
	local best: BeltBrainrot? = nil
	local bestDist = maxDistance
	for _, record in belt do
		if not record.Bought then
			local dist = (record.Model:GetPivot().Position - position).Magnitude
			if dist < bestDist then
				bestDist = dist
				best = record
			end
		end
	end
	return best
end

-- Mark a belt brainrot bought and remove its model from the belt.
function Spawner.takeBought(record: BeltBrainrot)
	record.Bought = true
	record.Model:Destroy()
	for i, other in belt do
		if other == record then
			table.remove(belt, i)
			break
		end
	end
end

function Spawner.getBelt(): { BeltBrainrot }
	return belt
end

function Spawner.init(parent: Folder)
	folder = Instance.new("Folder")
	folder.Name = "BeltBrainrots"
	folder.Parent = parent
	-- Seed the belt so the first player sees brainrots right away.
	for _ = 1, 4 do
		Spawner.spawnOne()
	end
	-- Spread the seeded ones along the belt.
	for i, record in belt do
		record.X = Spawner.BELT_START_X + (i - 1) * 14
		record.Model:PivotTo(CFrame.new(record.X, Spawner.BELT_Y + record.Def.Size * 0.5, Spawner.BELT_Z))
	end
	lastSpawnAt = os.clock()
end

return Spawner
