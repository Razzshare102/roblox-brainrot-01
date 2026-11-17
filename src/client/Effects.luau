-- Effects: the little moments of feedback — a chime when you buy, a
-- thud when you slap, a fanfare on rebirth, and a burst of sparkles
-- where it happened. All of it is client-side and cosmetic; the server
-- never depends on it. Sounds use Roblox's built-in asset ids, so they
-- need no upload.

local Effects = {}

-- Play a short built-in sound at a position.
local function playSound(soundId: string, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.Parent = game:GetService("Workspace")
	sound:Play()
	-- Clean it up once it finishes.
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

-- A burst of sparkles at a point.
local function sparkle(position: Vector3, color: Color3)
	local part = Instance.new("Part")
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.Position = position
	part.Parent = game:GetService("Workspace")
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new(0.5)
	emitter.Lifetime = NumberRange.new(0.6)
	emitter.Rate = 60
	emitter.Speed = NumberRange.new(6)
	emitter.Parent = part
	task.delay(1, function()
		part:Destroy()
	end)
end

function Effects.bought(position: Vector3)
	playSound("rbxassetid://13107261", 0.5)
	sparkle(position, Color3.fromRGB(120, 255, 120))
end

function Effects.stolen(position: Vector3)
	playSound("rbxassetid://13107261", 0.5)
	sparkle(position, Color3.fromRGB(255, 210, 60))
end

function Effects.slap()
	playSound("rbxassetid://13107272", 0.6)
end

function Effects.rebirth(position: Vector3)
	playSound("rbxassetid://13107265", 0.6)
	sparkle(position, Color3.fromRGB(255, 190, 40))
end

function Effects.tsunamiWarning()
	playSound("rbxassetid://13107269", 0.6)
end

return Effects
