-- Controls: what the keys do. E is the do-everything key: buy the
-- brainrot in front of you, grab one off a base, put a stolen one down
-- on your own base, or pick a dropped one up. Q slaps, F locks your
-- base, G drops what you carry. Touch players get the same actions as
-- on-screen buttons. The client only asks; the server decides.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Controls = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local BuyBrainrot = remotes:WaitForChild("BuyBrainrot")
local PickupBrainrot = remotes:WaitForChild("PickupBrainrot")
local PlaceStolen = remotes:WaitForChild("PlaceStolen")
local DropCarried = remotes:WaitForChild("DropCarried")
local Slap = remotes:WaitForChild("Slap")
local LockBase = remotes:WaitForChild("LockBase")
local PickupDropped = remotes:WaitForChild("PickupDropped")

-- The HUD module, set by the client boot so Controls can set the prompt.
local HUD: any = nil
-- The latest world sync (belt + bases), set by the client boot.
local getWorld: (() -> any)? = nil
local getState: (() -> any)? = nil

local INTERACT_RANGE = 14

-- The belt brainrot nearest the player, from the world sync.
local function nearestBelt(): any
	local world = getWorld and getWorld() or nil
	if not world or not world.Belt then
		return nil
	end
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local best: any = nil
	local bestDist = INTERACT_RANGE
	for _, item in world.Belt do
		-- The belt runs along X at z = 0, y = 2.
		local pos = Vector3.new(item.X, 2, 0)
		local dist = ((root :: BasePart).Position - pos).Magnitude
		if dist < bestDist then
			bestDist = dist
			best = item
		end
	end
	return best
end

-- The nearest other player, for slapping.
local function nearestPlayer(maxDistance: number): Player?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local best: Player? = nil
	local bestDist = maxDistance
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character then
			local otherRoot = other.Character:FindFirstChild("HumanoidRootPart")
			if otherRoot then
				local dist = ((root :: BasePart).Position - (otherRoot :: BasePart).Position).Magnitude
				if dist < bestDist then
					bestDist = dist
					best = other
				end
			end
		end
	end
	return best
end

-- Is the player standing on their own base? The bases ring the island
-- at radius 95; the client knows the ring, not which plot is theirs.
-- The server is the authority, so the client just asks to place and
-- the server checks. This helper only shapes the prompt.
local function onOwnBaseHeuristic(): boolean
	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local pos = (root :: BasePart).Position
	-- On a base platform the feet are above y = 1.5 and far from centre.
	return pos.Y > 1.5 and Vector3.new(pos.X, 0, pos.Z).Magnitude > 80
end

-- E: buy, steal, place, or pick up — whichever fits right now.
local function doInteract()
	local state = getState and getState() or nil
	-- Carrying a stolen brainrot: put it down on your own base.
	if state and state.Carrying then
		if onOwnBaseHeuristic() then
			PlaceStolen:FireServer()
		else
			-- Not home yet: the prompt says run home.
		end
		return
	end
	-- Near a belt brainrot: buy it.
	local belt = nearestBelt()
	if belt then
		BuyBrainrot:FireServer(belt.Uid)
		return
	end
	-- Near a dropped brainrot: pick it up.
	PickupDropped:FireServer()
end

local function doSlap()
	local target = nearestPlayer(8)
	if target then
		Slap:FireServer(target.Name)
	end
end

local function doLock()
	LockBase:FireServer()
end

local function doDrop()
	DropCarried:FireServer()
end

-- Refresh the prompt line every frame from the world state.
local function refreshPrompt()
	if not HUD then
		return
	end
	local state = getState and getState() or nil
	if state and state.Carrying then
		if onOwnBaseHeuristic() then
			HUD.setPrompt("Press E to place your stolen brainrot!")
		else
			HUD.setPrompt("RUN HOME! You are carrying a stolen brainrot!")
		end
		return
	end
	local belt = nearestBelt()
	if belt then
		local afford = ""
		if state and state.Cash < belt.Price then
			afford = " (need $" .. tostring(belt.Price) .. ")"
		end
		HUD.setPrompt("Press E to buy " .. belt.Name .. " — $" .. tostring(belt.Price) .. afford)
		return
	end
	HUD.setPrompt(nil)
end

function Controls.init(hudModule: any, worldGetter: () -> any, stateGetter: () -> any)
	HUD = hudModule
	getWorld = worldGetter
	getState = stateGetter

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.E then
			doInteract()
		elseif input.KeyCode == Enum.KeyCode.Q then
			doSlap()
		elseif input.KeyCode == Enum.KeyCode.F then
			doLock()
		elseif input.KeyCode == Enum.KeyCode.G then
			doDrop()
		end
	end)

	RunService.RenderStepped:Connect(function()
		refreshPrompt()
	end)
end

return Controls
