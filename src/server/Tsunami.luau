-- Tsunami: the wave. Every few minutes a warning sounds, then a great
-- wall of water sweeps across the island from the north. Anyone standing
-- on the open ground is knocked flying and drops what they carry; anyone
-- standing on their own base platform rides it out. The wave is the
-- game's dash-home moment: grab a brainrot, then run for your base
-- before the water arrives.

local GameState = require(script.Parent.GameState)
local StealSystem = require(script.Parent.StealSystem)

local Tsunami = {}

Tsunami.CYCLE_SECONDS = 180 -- a wave every 3 minutes
Tsunami.WARNING_SECONDS = 30 -- warning before the wave arrives
Tsunami.WAVE_SPEED = 40 -- studs per second across the island
Tsunami.WAVE_START_Z = -160 -- the wave starts north and sweeps south
Tsunami.WAVE_END_Z = 160
Tsunami.BASE_SAFE_Y = 2 -- standing on a base platform (top y = 2) is safe
Tsunami.KNOCKBACK = 60

local wave: Part? = nil
local cycleStart = 0
local warned = false
local sweeping = false

-- Build the wave wall: a wide, tall, translucent blue wall.
local function buildWave(parent: Folder): Part
	local part = Instance.new("Part")
	part.Name = "TsunamiWave"
	part.Size = Vector3.new(220, 30, 6)
	part.Color = Color3.fromRGB(40, 140, 255)
	part.Material = Enum.Material.Glass
	part.Transparency = 0.35
	part.Anchored = true
	part.CanCollide = false
	part.Position = Vector3.new(0, 15, Tsunami.WAVE_START_Z)
	part.Parent = parent
	return part
end

-- Is a player standing on a base platform (safe), or on open ground?
local function isOnBase(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	-- A base platform's top is at y = 2; the ground is y = 0.
	-- Standing on a platform means the feet are above y = 1.5.
	return (root :: BasePart).Position.Y > 1.5
end

-- The wave hits a player: knock them flying and make them drop a steal.
local function hitPlayer(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	-- Launch them south and up, away from the wave.
	(root :: BasePart).AssemblyLinearVelocity = Vector3.new(0, 30, Tsunami.KNOCKBACK)
	local state = GameState.get(player)
	if state and state.Carrying ~= nil then
		StealSystem.dropCarried(player)
	end
end

-- Advance the cycle. Returns "warning" while the warning is up,
-- "sweeping" while the wave crosses, and "idle" otherwise.
function Tsunami.step(dt: number): string
	local now = os.clock()
	local elapsed = now - cycleStart
	if sweeping then
		-- Move the wall south; hit players it passes.
		if wave then
			local pos = wave.Position
			local newZ = pos.Z + Tsunami.WAVE_SPEED * dt
			wave.Position = Vector3.new(pos.X, pos.Y, newZ)
			-- Hit every player near the wall's front who is not on a base.
			for _, player in game:GetService("Players"):GetPlayers() do
				local character = player.Character
				if character then
					local root = character:FindFirstChild("HumanoidRootPart")
					if root then
						local p = (root :: BasePart).Position
						if math.abs(p.Z - newZ) < 6 and not isOnBase(player) then
							hitPlayer(player)
						end
					end
				end
			end
			if newZ >= Tsunami.WAVE_END_Z then
				wave:Destroy()
				wave = nil
				sweeping = false
				cycleStart = now
				warned = false
			end
		end
		return "sweeping"
	end
	if elapsed >= Tsunami.CYCLE_SECONDS - Tsunami.WARNING_SECONDS and not warned then
		warned = true
		return "warning"
	end
	if elapsed >= Tsunami.CYCLE_SECONDS then
		-- The wave arrives: build the wall and start sweeping.
		sweeping = true
		if Tsunami._parent then
			wave = buildWave(Tsunami._parent)
		end
		return "sweeping"
	end
	if warned then
		return "warning"
	end
	return "idle"
end

-- Seconds until the next wave starts sweeping.
function Tsunami.secondsUntilWave(): number
	local now = os.clock()
	return math.max(0, Tsunami.CYCLE_SECONDS - (now - cycleStart))
end

function Tsunami.init(parent: Folder)
	cycleStart = os.clock()
	-- The wave part is built when the sweep starts, so it is not in the
	-- way while the game is calm. Keep the parent for it.
	Tsunami._parent = parent
end

Tsunami._parent = nil :: Folder?

return Tsunami
