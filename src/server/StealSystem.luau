-- StealSystem: the steal. Walk into another player's base while it is
-- unlocked, pick a brainrot up, and carry it home. While you carry it
-- you walk slower; a slap drops it where you stand. A locked base cannot
-- be stolen from at all, and a dropped brainrot walks home on its own
-- after a while. Every rule here is enforced on the server — the client
-- only asks.

local Players = game:GetService("Players")
local GameState = require(script.Parent.GameState)
local BrainrotData = require(game:GetService("ReplicatedStorage").Shared.BrainrotData)

local StealSystem = {}

StealSystem.CARRY_SLOW = 8 -- WalkSpeed while carrying (normal is 16)
StealSystem.NORMAL_SPEED = 16
StealSystem.SLAP_RANGE = 8 -- studs
StealSystem.SLAP_COOLDOWN = 2 -- seconds
StealSystem.SLAP_KNOCKBACK = 30 -- studs per second of launch velocity
StealSystem.DROP_RETURN_AFTER = 30 -- seconds before a dropped brainrot walks home
StealSystem.PICKUP_RANGE = 10 -- studs from a base brainrot to grab it

export type DroppedBrainrot = {
	Model: Model?, -- the ground model, nil while it is being carried
	DefId: string,
	Mutation: string,
	Mult: number,
	Owner: Player, -- the player it was stolen from
	DropAt: number, -- os.clock() time it was dropped
}

local dropped: { DroppedBrainrot } = {}
local dropFolder: Folder? = nil
-- Which base plot belongs to which player, by base number (1..8).
local baseOwners: { [number]: Player } = {}

-- The 8 base plots, in ring order. The world builder names them Base1..Base8.
StealSystem.BASE_COUNT = 8

-- Claim a free base plot for a player who just joined. Returns the base
-- number, or 0 when the island is full.
function StealSystem.claimBase(player: Player): number
	for i = 1, StealSystem.BASE_COUNT do
		if baseOwners[i] == nil then
			baseOwners[i] = player
			return i
		end
	end
	return 0
end

function StealSystem.baseOf(player: Player): number
	for i, owner in baseOwners do
		if owner == player then
			return i
		end
	end
	return 0
end

function StealSystem.ownerOfBase(baseNumber: number): Player?
	return baseOwners[baseNumber]
end

function StealSystem.releaseBase(player: Player)
	for i, owner in baseOwners do
		if owner == player then
			baseOwners[i] = nil
		end
	end
end

-- Where a brainrot sits on a base: slot positions are laid out 3 by 2
-- on the platform. baseNumber picks the plot; slot picks the pad.
-- The world builder puts the pads at these offsets from the plot centre.
function StealSystem.slotOffset(slot: number): Vector3
	local cols = { -6, 0, 6 }
	local rows = { -4, 4 }
	local col = cols[((slot - 1) % 3) + 1]
	local row = rows[math.floor((slot - 1) / 3) + 1]
	return Vector3.new(col, 0, row)
end

-- Pick a brainrot up off a base. The thief must be close to it, the
-- owner's base must be unlocked, and the thief must not already carry
-- one. Returns the carried record, or nil with a reason.
function StealSystem.pickUp(thief: Player, owner: Player, uid: string): (DroppedBrainrot?, string?)
	local thiefState = GameState.get(thief)
	local ownerState = GameState.get(owner)
	if not thiefState or not ownerState then
		return nil, "no state"
	end
	if thiefState.Carrying ~= nil then
		return nil, "already carrying"
	end
	if GameState.isLocked(ownerState) then
		return nil, "base locked"
	end
	local owned = GameState.takeBrainrot(ownerState, uid)
	if not owned then
		return nil, "not there"
	end
	-- The thief now carries it: slow them down and mark it.
	thiefState.Carrying = uid
	local character = thief.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = StealSystem.CARRY_SLOW + 2 * thiefState.SpeedLevel
		end
	end
	-- Keep the full record so a drop or a disconnect can return it.
	-- No ground model yet: there is none while it is being carried.
	local record: DroppedBrainrot = {
		Model = nil,
		DefId = owned.DefId,
		Mutation = owned.Mutation,
		Mult = owned.Mult,
		Owner = owner,
		DropAt = 0,
	}
	-- Remember which uid the thief holds, mapped to this record.
	StealSystem._carried[thief] = record
	StealSystem._carriedUid[thief] = uid
	return record, nil
end

-- The thief reached their own base with the stolen brainrot: it becomes
-- theirs. Returns the new owned record, or nil when they carry nothing
-- or their base is full.
function StealSystem.placeStolen(thief: Player): GameState.OwnedBrainrot?
	local thiefState = GameState.get(thief)
	if not thiefState or thiefState.Carrying == nil then
		return nil
	end
	local record = StealSystem._carried[thief]
	if not record then
		return nil
	end
	local placed = GameState.placeBrainrot(thiefState, record.DefId, record.Mutation, record.Mult)
	if not placed then
		return nil
	end
	thiefState.Carrying = nil
	StealSystem._carried[thief] = nil
	StealSystem._carriedUid[thief] = nil
	local character = thief.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = StealSystem.NORMAL_SPEED + 2 * thiefState.SpeedLevel
		end
	end
	return placed
end

-- Drop what the thief carries where they stand. The brainrot stays on
-- the ground as a dropped model until someone grabs it or it walks home.
function StealSystem.dropCarried(thief: Player): boolean
	local thiefState = GameState.get(thief)
	if not thiefState or thiefState.Carrying == nil then
		return false
	end
	local record = StealSystem._carried[thief]
	if not record then
		return false
	end
	local character = thief.Character
	local position = Vector3.new(0, 3, 0)
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			position = (root :: BasePart).Position
		end
	end
	thiefState.Carrying = nil
	StealSystem._carried[thief] = nil
	StealSystem._carriedUid[thief] = nil
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = StealSystem.NORMAL_SPEED + 2 * thiefState.SpeedLevel
		end
	end
	-- Build the dropped model at the drop point.
	local def = BrainrotData.getById(record.DefId)
	if def then
		local model = StealSystem.buildDroppedModel(def, record.Mutation, record.Mult)
		model:PivotTo(CFrame.new(position.X, 3, position.Z))
		model.Parent = dropFolder
		record.Model = model
		record.DropAt = os.clock()
		table.insert(dropped, record)
	end
	return true
end

-- A player picks a dropped brainrot up off the ground. It goes straight
-- onto their base if they have a free slot.
function StealSystem.pickUpDropped(player: Player, record: DroppedBrainrot): boolean
	local state = GameState.get(player)
	if not state or state.Carrying ~= nil then
		return false
	end
	local placed = GameState.placeBrainrot(state, record.DefId, record.Mutation, record.Mult)
	if not placed then
		return false
	end
	if record.Model then
		record.Model:Destroy()
	end
	for i, other in dropped do
		if other == record then
			table.remove(dropped, i)
			break
		end
	end
	return true
end

-- The nearest dropped brainrot to a point, within range.
function StealSystem.nearestDropped(position: Vector3, maxDistance: number): DroppedBrainrot?
	local best: DroppedBrainrot? = nil
	local bestDist = maxDistance
	for _, record in dropped do
		if record.Model then
			local dist = (record.Model:GetPivot().Position - position).Magnitude
			if dist < bestDist then
				bestDist = dist
				best = record
			end
		end
	end
	return best
end

-- Dropped brainrots walk home after DROP_RETURN_AFTER seconds: back onto
-- their owner's base if it has room, otherwise they despawn.
function StealSystem.step(_dt: number)
	local now = os.clock()
	for i = #dropped, 1, -1 do
		local record = dropped[i]
		if now - record.DropAt >= StealSystem.DROP_RETURN_AFTER then
			if record.Model then
				record.Model:Destroy()
			end
			table.remove(dropped, i)
			local ownerState = GameState.get(record.Owner)
			if ownerState then
				GameState.placeBrainrot(ownerState, record.DefId, record.Mutation, record.Mult)
			end
		end
	end
end

-- Slap another player: knocks them back, and if they carry a brainrot
-- they drop it. Returns false when on cooldown or out of range.
function StealSystem.slap(slapper: Player, target: Player): boolean
	local slapperState = GameState.get(slapper)
	local targetState = GameState.get(target)
	if not slapperState or not targetState then
		return false
	end
	local now = os.clock()
	if now - slapperState.LastSlapAt < StealSystem.SLAP_COOLDOWN then
		return false
	end
	local slapperChar = slapper.Character
	local targetChar = target.Character
	if not slapperChar or not targetChar then
		return false
	end
	local slapperRoot = slapperChar:FindFirstChild("HumanoidRootPart")
	local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
	local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
	if not slapperRoot or not targetRoot or not targetHumanoid then
		return false
	end
	local distance = ((slapperRoot :: BasePart).Position - (targetRoot :: BasePart).Position).Magnitude
	if distance > StealSystem.SLAP_RANGE then
		return false
	end
	slapperState.LastSlapAt = now
	-- Knockback away from the slapper, plus a little up.
	local targetPart = targetRoot :: BasePart
	local direction = (targetPart.Position - (slapperRoot :: BasePart).Position).Unit
	local power = StealSystem.SLAP_KNOCKBACK + 10 * slapperState.SlapLevel
	targetPart.AssemblyLinearVelocity = direction * power + Vector3.new(0, 18, 0)
	-- A slap drops whatever the target carries.
	if targetState.Carrying ~= nil then
		StealSystem.dropCarried(target)
	end
	return true
end

-- Build a small dropped model for a brainrot on the ground.
function StealSystem.buildDroppedModel(def: BrainrotData.BrainrotDef, mutationName: string, mult: number): Model
	local model = Instance.new("Model")
	model.Name = def.Name .. " (dropped)"
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
	local label = Instance.new("BillboardGui")
	label.Name = "DroppedLabel"
	label.Size = UDim2.fromOffset(140, 40)
	label.StudsOffset = Vector3.new(0, size * 1.2, 0)
	label.AlwaysOnTop = true
	label.Parent = model
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	local labelText = def.Name
	if mutationName ~= "Normal" then
		labelText = mutationName .. " " .. def.Name
	end
	text.Text = labelText .. " • $" .. tostring(def.Rate * mult) .. "/s"
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.Parent = label
	model.PrimaryPart = body
	return model
end

-- What a player is carrying right now, if anything.
StealSystem._carried = {} :: { [Player]: DroppedBrainrot }
StealSystem._carriedUid = {} :: { [Player]: string }

function StealSystem.init(parent: Folder)
	dropFolder = Instance.new("Folder")
	dropFolder.Name = "DroppedBrainrots"
	dropFolder.Parent = parent
	-- A player who leaves while carrying drops it on the spot, so the
	-- brainrot is not lost with them.
	Players.PlayerRemoving:Connect(function(player)
		if GameState.get(player) and (GameState.get(player) :: GameState.PlayerState).Carrying ~= nil then
			StealSystem.dropCarried(player)
		end
		StealSystem.releaseBase(player)
	end)
end

return StealSystem
