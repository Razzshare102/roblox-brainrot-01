-- Game.client: the client boots here. It builds the HUD, wires the
-- controls, and keeps the camera in a friendly third-person view over
-- the island. The server owns every rule; this side only shows state
-- and asks for actions.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local HUD = require(script.Parent.HUD)
local Controls = require(script.Parent.Controls)
local Effects = require(script.Parent.Effects)

local player = Players.LocalPlayer

-- A slightly pulled-back third-person camera, so the player sees the
-- belt, the bases and the brainrots around them.
local camera = Workspace.CurrentCamera
if camera then
	camera.CameraType = Enum.CameraType.Custom
end

HUD.build()
HUD.listen()
Controls.init(HUD, function()
	return HUD.getWorld()
end, function()
	return HUD.getState()
end)

-- A tsunami warning gets a sound, once per warning.
local warned = false
local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
local SyncWorld = remotes:WaitForChild("SyncWorld")
SyncWorld.OnClientEvent:Connect(function(world)
	if world.Tsunami == "warning" and not warned then
		warned = true
		Effects.tsunamiWarning()
	elseif world.Tsunami == "idle" then
		warned = false
	end
end)

print("Brainrot Bay client ready.")
