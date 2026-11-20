-- Brainrot Bay: stealing, carrying, dropping, slapping and base slots.
-- A brainrot is a record in GameState; its model is just a visual, rebuilt
-- wherever the record goes: belt, base, carried above a head, or dropped.

local Players = game:GetService("Players")

local BrainrotData = require(script.Parent.Parent.Shared.BrainrotData)
local GameState = require(script.Parent.GameState)
local Spawner = require(script.Parent.Spawner)

local StealSystem = {}

StealSystem.INTERACT_RANGE = 12
StealSystem.SLAP_RANGE = 9
StealSystem.SLAP_COOLDOWN_SECONDS = 2
StealSystem.DROPPED_LIFETIME_SECONDS = 60

local baseFolder = nil
local droppedFolder = nil
local droppedBrainrots = {}

function StealSystem.setFolders(base, dropped)
	baseFolder = base
	droppedFolder = dropped
end

function StealSystem.getDroppedBrainrots()
	return droppedBrainrots
end

-- Put a brainrot's model on a free slot of the player's own base.
function StealSystem.placeBrainrotOnBase(player, record)
	local state = GameState.getState(player)
	if not state or state.baseIndex == 0 then
		return false, "You have no base yet."
	end
	local slot = GameState.addBrainrot(state, record)
	if not slot then
		return false, "Your base is full."
	end
	local model = Spawner.buildBrainrotModel(record)
	local slotPos = GameState.slotPosition(state.baseIndex, slot)
	model:PivotTo(CFrame.new(slotPos.X, slotPos.Y + 1.5, slotPos.Z))
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("SlotIndex", slot)
	model.Parent = baseFolder
	return true, slot
end

-- Destroy the model sitting on one slot of a base (used on rebirth).
function StealSystem.removeBaseModel(ownerUserId, slotIndex)
	for _, child in ipairs(baseFolder:GetChildren()) do
		if child:GetAttribute("OwnerUserId") == ownerUserId
			and child:GetAttribute("SlotIndex") == slotIndex then
			child:Destroy()
			return
		end
	end
end

-- Take a brainrot off a base and carry it above your head.
function StealSystem.grabFromBase(player, ownerUserId, slotIndex)
	local state = GameState.getState(player)
	if not state then
		return false, "No state."
	end
	if state.carrying then
		return false, "You are already carrying a brainrot."
	end
	if GameState.freeSlot(state) == nil then
		return false, "Your base is full. Make room first."
	end
	if ownerUserId == player.UserId then
		return false, "That is your own base."
	end
	local owner = Players:GetPlayerByUserId(ownerUserId)
	if not owner then
		return false, "That player is gone."
	end
	local ownerState = GameState.getState(owner)
	if not ownerState then
		return false, "That player is gone."
	end
	if GameState.isLocked(ownerState) then
		return false, "That base is locked."
	end
	local record = ownerState.brainrots[slotIndex]
	if not record then
		return false, "Nothing sits on that slot."
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false, "You have no character."
	end
	-- The brainrot must be close enough to grab.
	local found = nil
	for _, child in ipairs(baseFolder:GetChildren()) do
		if child:GetAttribute("OwnerUserId") == ownerUserId
			and child:GetAttribute("SlotIndex") == slotIndex
			and child.PrimaryPart
			and (child.PrimaryPart.Position - root.Position).Magnitude <= StealSystem.INTERACT_RANGE then
			found = child
			break
		end
	end
	if not found then
		return false, "Get closer to steal it."
	end
	GameState.removeBrainrot(ownerState, slotIndex)
	found:Destroy()
	state.carrying = record
	StealSystem.showCarried(player, record)
	return true, record
end

-- The little model floating above the carrier's head.
function StealSystem.showCarried(player, record)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local model = Spawner.buildBrainrotModel(record)
	model:PivotTo(root.CFrame * CFrame.new(0, 4.5, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
		end
	end
	model.Parent = character
end

function StealSystem.hideCarried(player)
	local character = player.Character
	if not character then
		return
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("InstanceId") ~= nil then
			child:Destroy()
		end
	end
end

-- Put what you carry on your own base.
function StealSystem.placeCarried(player)
	local state = GameState.getState(player)
	if not state or not state.carrying then
		return false, "You are not carrying anything."
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false, "You have no character."
	end
	if state.baseIndex == 0 or not GameState.onBasePlatform(state.baseIndex, root.Position) then
		return false, "Stand on your own base to place it."
	end
	local record = state.carrying
	state.carrying = nil
	StealSystem.hideCarried(player)
	local ok, result = StealSystem.placeBrainrotOnBase(player, record)
	if not ok then
		state.carrying = record
		StealSystem.showCarried(player, record)
		return false, result
	end
	return true, record
end

-- Drop what you carry on the ground. Anyone can pick it up.
function StealSystem.dropCarried(player)
	local state = GameState.getState(player)
	if not state or not state.carrying then
		return false, "You are not carrying anything."
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false, "You have no character."
	end
	local record = state.carrying
	state.carrying = nil
	StealSystem.hideCarried(player)
	local model = Spawner.buildBrainrotModel(record)
	local dropPos = root.Position + root.CFrame.LookVector * 3
	model:PivotTo(CFrame.new(dropPos.X, 3.5, dropPos.Z))
	model:SetAttribute("DroppedAt", os.time())
	model.Parent = droppedFolder
	table.insert(droppedBrainrots, { record = record, model = model, droppedAt = os.time() })
	return true, record
end

-- Pick a dropped brainrot up off the ground.
function StealSystem.pickupDropped(player, instanceId)
	local state = GameState.getState(player)
	if not state then
		return false, "No state."
	end
	if state.carrying then
		return false, "You are already carrying a brainrot."
	end
	if GameState.freeSlot(state) == nil then
		return false, "Your base is full. Make room first."
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false, "You have no character."
	end
	for index, entry in ipairs(droppedBrainrots) do
		if entry.record.instanceId == instanceId then
			local model = entry.model
			if not model or not model.PrimaryPart then
				table.remove(droppedBrainrots, index)
				return false, "It is gone."
			end
			if (model.PrimaryPart.Position - root.Position).Magnitude > StealSystem.INTERACT_RANGE then
				return false, "Get closer to pick it up."
			end
			table.remove(droppedBrainrots, index)
			model:Destroy()
			state.carrying = entry.record
			StealSystem.showCarried(player, entry.record)
			return true, entry.record
		end
	end
	return false, "It is gone."
end

-- Clear out dropped brainrots that sat too long.
function StealSystem.sweepDropped()
	local now = os.time()
	for index = #droppedBrainrots, 1, -1 do
		local entry = droppedBrainrots[index]
		if now - entry.droppedAt >= StealSystem.DROPPED_LIFETIME_SECONDS then
			if entry.model then
				entry.model:Destroy()
			end
			table.remove(droppedBrainrots, index)
		end
	end
end

-- Slap the nearest player in front of you: they fly back, and if they
-- were carrying a brainrot, they drop it.
function StealSystem.slap(player)
	local state = GameState.getState(player)
	if not state then
		return false, "No state."
	end
	local now = os.time()
	if now < state.slapCooldownUntil then
		return false, "Slap is recharging."
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false, "You have no character."
	end
	local target = nil
	local targetDistance = StealSystem.SLAP_RANGE
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and other.Character then
			local otherRoot = other.Character:FindFirstChild("HumanoidRootPart")
			if otherRoot then
				local offset = otherRoot.Position - root.Position
				local distance = offset.Magnitude
				local facing = root.CFrame.LookVector:Dot(offset.Unit)
				if distance < targetDistance and facing > 0.3 then
					targetDistance = distance
					target = other
				end
			end
		end
	end
	if not target then
		return false, "Nobody in reach."
	end
	state.slapCooldownUntil = now + StealSystem.SLAP_COOLDOWN_SECONDS
	local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
	if targetRoot then
		local power = 40 + 15 * state.slapLevel
		local direction = (targetRoot.Position - root.Position).Unit
		targetRoot:ApplyImpulse(direction * power * targetRoot.AssemblyMass + Vector3.new(0, 12 * targetRoot.AssemblyMass, 0))
	end
	local targetState = GameState.getState(target)
	if targetState and targetState.carrying then
		StealSystem.dropCarried(target)
		return true, target
	end
	return true, target
end

-- Nearest brainrot on another player's base, for the client's prompt.
function StealSystem.nearestBaseBrainrot(player, position, maxDistance)
	local state = GameState.getState(player)
	local nearest = nil
	local nearestDistance = maxDistance
	local nearestOwner = nil
	for _, child in ipairs(baseFolder:GetChildren()) do
		local ownerId = child:GetAttribute("OwnerUserId")
		local slot = child:GetAttribute("SlotIndex")
		if ownerId and ownerId ~= player.UserId and slot and child.PrimaryPart then
			local distance = (child.PrimaryPart.Position - position).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearest = child
				nearestOwner = ownerId
			end
		end
	end
	return nearest, nearestOwner, nearestDistance
end

function StealSystem.nearestDroppedBrainrot(position, maxDistance)
	local nearest = nil
	local nearestDistance = maxDistance
	for _, entry in ipairs(droppedBrainrots) do
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

return StealSystem
