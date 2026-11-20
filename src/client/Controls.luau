-- Brainrot Bay: the keys. E buys, grabs, places and picks up; Q slaps;
-- F locks your base; G drops what you carry. Bound with
-- ContextActionService so the keys work even when Roblox's camera
-- scripts would otherwise swallow them.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotData = require(script.Parent.Parent.Shared.BrainrotData)

local Controls = {}

local player = Players.LocalPlayer
local remotes = nil
local hud = nil
local effects = nil
local state = nil

local INTERACT_RANGE = 12

local function getRemotes()
	if not remotes then
		remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")
	end
	return remotes
end

local function getRoot()
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function nearestModel(folderName, position, maxDistance)
	local folder = workspace:FindFirstChild(folderName)
	if not folder then
		return nil, maxDistance
	end
	local nearest = nil
	local nearestDistance = maxDistance
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") and model.PrimaryPart then
			local distance = (model.PrimaryPart.Position - position).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearest = model
			end
		end
	end
	return nearest, nearestDistance
end

-- What E would do right now, for the prompt line and the press.
local function findInteractTarget()
	local root = getRoot()
	if not root then
		return nil
	end
	local position = root.Position
	if state and state.carrying then
		if state.baseIndex and state.baseIndex > 0 then
			return { kind = "place" }
		end
		return { kind = "carrying" }
	end
	local beltModel = nearestModel("BeltBrainrots", position, INTERACT_RANGE)
	if beltModel then
		local brainrot = BrainrotData.getBrainrot(beltModel:GetAttribute("BrainrotId"))
		if brainrot then
			return { kind = "buy", model = beltModel, brainrot = brainrot }
		end
	end
	local droppedModel = nearestModel("DroppedBrainrots", position, INTERACT_RANGE)
	if droppedModel then
		return { kind = "pickup", model = droppedModel }
	end
	local baseFolder = workspace:FindFirstChild("BaseBrainrots")
	if baseFolder then
		local nearest = nil
		local nearestDistance = INTERACT_RANGE
		for _, model in ipairs(baseFolder:GetChildren()) do
			local ownerId = model:GetAttribute("OwnerUserId")
			if ownerId and ownerId ~= player.UserId and model.PrimaryPart then
				local distance = (model.PrimaryPart.Position - position).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearest = model
				end
			end
		end
		if nearest then
			return { kind = "grab", model = nearest, ownerId = nearest:GetAttribute("OwnerUserId"), slot = nearest:GetAttribute("SlotIndex") }
		end
	end
	return nil
end

local function promptFor(target)
	if not target then
		return "Walk to the belt and press E to buy a brainrot!"
	end
	if target.kind == "buy" then
		return string.format("Press E to buy %s — $%d", target.brainrot.name, BrainrotData.buyCost(target.brainrot))
	elseif target.kind == "grab" then
		return "Press E to STEAL this brainrot — then RUN HOME!"
	elseif target.kind == "pickup" then
		return "Press E to pick up the dropped brainrot!"
	elseif target.kind == "place" then
		return "Press E to place it on your base!"
	elseif target.kind == "carrying" then
		return "RUN HOME! You are carrying a stolen brainrot!"
	end
	return ""
end

local function onInteract(_action, inputState, _input)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local target = findInteractTarget()
	local r = getRemotes()
	if not target then
		return Enum.ContextActionResult.Pass
	end
	if target.kind == "buy" then
		r.BuyBelt:FireServer(target.model:GetAttribute("InstanceId"))
	elseif target.kind == "grab" then
		r.GrabBase:FireServer(target.ownerId, target.slot)
	elseif target.kind == "pickup" then
		r.PickupDropped:FireServer(target.model:GetAttribute("InstanceId"))
	elseif target.kind == "place" then
		r.PlaceCarried:FireServer()
	end
	return Enum.ContextActionResult.Sink
end

local function onSlap(_action, inputState, _input)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	getRemotes().Slap:FireServer()
	return Enum.ContextActionResult.Sink
end

local function onLock(_action, inputState, _input)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	getRemotes().LockBase:FireServer()
	return Enum.ContextActionResult.Sink
end

local function onDrop(_action, inputState, _input)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	getRemotes().DropCarried:FireServer()
	return Enum.ContextActionResult.Sink
end

function Controls.start(hudModule, effectsModule)
	hud = hudModule
	effects = effectsModule
	ContextActionService:BindAction("BrainrotInteract", onInteract, false, Enum.KeyCode.E)
	ContextActionService:BindAction("BrainrotSlap", onSlap, false, Enum.KeyCode.Q)
	ContextActionService:BindAction("BrainrotLock", onLock, false, Enum.KeyCode.F)
	ContextActionService:BindAction("BrainrotDrop", onDrop, false, Enum.KeyCode.G)
	task.spawn(function()
		while true do
			task.wait(0.2)
			if hud then
				local target = findInteractTarget()
				hud.setPrompt(promptFor(target))
			end
		end
	end)
end

function Controls.setState(newState)
	state = newState
end

return Controls
