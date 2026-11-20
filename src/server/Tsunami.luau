-- Brainrot Bay: the tsunami that sweeps the island every three minutes.
-- Thirty seconds of warning, then a wall of water crosses the island.
-- Your own base platform is the only safe ground.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local GameState = require(script.Parent.GameState)
local StealSystem = require(script.Parent.StealSystem)

local Tsunami = {}

Tsunami.CYCLE_SECONDS = 180
Tsunami.WARNING_SECONDS = 30
Tsunami.SWEEP_SECONDS = 15

local wave = nil
local phase = "calm"
local phaseEndsAt = 0
local onPhaseChange = nil

function Tsunami.getPhase()
	return phase, phaseEndsAt
end

function Tsunami.onPhaseChanged(callback)
	onPhaseChange = callback
end

local function setPhase(newPhase, duration)
	phase = newPhase
	phaseEndsAt = os.time() + duration
	if onPhaseChange then
		onPhaseChange(newPhase, duration)
	end
end

function Tsunami.buildWave(parent)
	wave = Instance.new("Part")
	wave.Name = "TsunamiWave"
	wave.Size = Vector3.new(420, 34, 14)
	wave.Color = Color3.fromRGB(60, 140, 255)
	wave.Material = Enum.Material.Neon
	wave.Transparency = 0.25
	wave.Anchored = true
	wave.CanCollide = false
	wave.CFrame = CFrame.new(0, 12, -240)
	wave.Parent = parent
	return wave
end

-- The sweep: the wall crosses the island, and anyone caught off their
-- base is washed away (respawned) and drops what they carry.
local function sweepPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		local state = GameState.getState(player)
		local character = player.Character
		if state and character then
			local root = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 then
				local safe = false
				if state.baseIndex > 0 then
					safe = GameState.onBasePlatform(state.baseIndex, root.Position)
				end
				if not safe then
					if state.carrying then
						StealSystem.dropCarried(player)
					end
					humanoid.Health = 0
				end
			end
		end
	end
end

function Tsunami.start()
	setPhase("calm", Tsunami.CYCLE_SECONDS - Tsunami.WARNING_SECONDS)
	task.spawn(function()
		while true do
			local waitFor = phaseEndsAt - os.time()
			if waitFor > 0 then
				task.wait(waitFor)
			end
			if phase == "calm" then
				setPhase("warning", Tsunami.WARNING_SECONDS)
			elseif phase == "warning" then
				setPhase("sweep", Tsunami.SWEEP_SECONDS)
				if wave then
					wave.CFrame = CFrame.new(0, 12, -240)
					local tween = TweenService:Create(wave, TweenInfo.new(Tsunami.SWEEP_SECONDS, Enum.EasingStyle.Linear), {
						CFrame = CFrame.new(0, 12, 240),
					})
					tween:Play()
					local start = os.time()
					while os.time() - start < Tsunami.SWEEP_SECONDS do
						sweepPlayers()
						task.wait(0.5)
					end
					wave.CFrame = CFrame.new(0, 12, -240)
				end
				setPhase("calm", Tsunami.CYCLE_SECONDS - Tsunami.WARNING_SECONDS)
			end
		end
	end)
end

return Tsunami
