-- Brainrot Bay: buy, steal, slap and rebirth feedback on the client.
-- Visual only: a sparkle burst and a floating label, so the player sees
-- the moment something happens. No sound assets are needed.

local TweenService = game:GetService("TweenService")

local Effects = {}

-- A burst of coloured sparks at a world position, gone in two seconds.
function Effects.burst(position, color)
	local anchor = Instance.new("Part")
	anchor.Name = "EffectBurst"
	anchor.Size = Vector3.new(0.5, 0.5, 0.5)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.7)
	emitter.Speed = NumberRange.new(12)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.8)
	emitter.Parent = anchor
	emitter:Emit(24)

	task.delay(2, function()
		anchor:Destroy()
	end)
end

-- A label that floats up and fades, for "+$95" and "STOLEN!" moments.
function Effects.floatText(position, text, color)
	local gui = Instance.new("BillboardGui")
	gui.Name = "FloatText"
	gui.Size = UDim2.new(0, 200, 0, 40)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = true

	local anchor = Instance.new("Part")
	anchor.Name = "FloatAnchor"
	anchor.Size = Vector3.new(0.5, 0.5, 0.5)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 20
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.Text = text
	label.Parent = gui

	local tween = TweenService:Create(gui, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(0, 7, 0),
	})
	tween:Play()
	task.delay(1.4, function()
		anchor:Destroy()
	end)
end

function Effects.buyEffect(position)
	Effects.burst(position, Color3.fromRGB(120, 220, 90))
	Effects.floatText(position, "BOUGHT!", Color3.fromRGB(120, 220, 90))
end

function Effects.stealEffect(position)
	Effects.burst(position, Color3.fromRGB(255, 180, 40))
	Effects.floatText(position, "STOLEN!", Color3.fromRGB(255, 180, 40))
end

function Effects.slapEffect(position)
	Effects.burst(position, Color3.fromRGB(255, 80, 80))
end

function Effects.rebirthEffect(position)
	Effects.burst(position, Color3.fromRGB(170, 90, 255))
	Effects.floatText(position, "REBORN!", Color3.fromRGB(200, 140, 255))
end

return Effects
