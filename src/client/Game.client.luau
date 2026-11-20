-- Brainrot Bay: the client boot. Builds the HUD, binds the keys, and
-- listens for the server's state, tsunami and toast remotes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HUD = require(script.Parent.HUD)
local Controls = require(script.Parent.Controls)
local Effects = require(script.Parent.Effects)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")

HUD.build(function(itemId)
	remotes.BuyShop:FireServer(itemId)
end, function()
	remotes.DoRebirth:FireServer()
end)
Controls.start(HUD, Effects)

remotes.StateSync.OnClientEvent:Connect(function(snapshot)
	HUD.setState(snapshot)
	Controls.setState(snapshot)
end)

remotes.TsunamiSync.OnClientEvent:Connect(function(phase, secondsLeft)
	HUD.showTsunami(phase, secondsLeft)
end)

remotes.Toast.OnClientEvent:Connect(function(message)
	HUD.showToast(message)
end)
