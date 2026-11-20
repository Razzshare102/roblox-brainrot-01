-- Brainrot Bay: one source of truth for every player's state and the bases.
-- The server owns this table; the client only ever sees a compact copy
-- sent over the StateSync remote. Nothing else keeps player numbers.

local BrainrotData = require(script.Parent.Parent.Shared.BrainrotData)

local GameState = {}

-- The eight bases, in a ring around the plaza. Centers and colours match
-- the platforms default.project.json builds. Slot pads sit on each
-- platform in a 3 by 2 grid: x offsets -6, 0, 6 and z offsets -4, 4.
GameState.BASES = {
	{ center = Vector3.new(95, 1, 0), color = Color3.fromRGB(255, 69, 69) },
	{ center = Vector3.new(67.2, 1, 67.2), color = Color3.fromRGB(255, 140, 41) },
	{ center = Vector3.new(0, 1, 95), color = Color3.fromRGB(255, 209, 41) },
	{ center = Vector3.new(-67.2, 1, 67.2), color = Color3.fromRGB(79, 199, 89) },
	{ center = Vector3.new(-95, 1, 0), color = Color3.fromRGB(79, 140, 255) },
	{ center = Vector3.new(-67.2, 1, -67.2), color = Color3.fromRGB(171, 89, 255) },
	{ center = Vector3.new(0, 1, -95), color = Color3.fromRGB(255, 120, 181) },
	{ center = Vector3.new(67.2, 1, -67.2), color = Color3.fromRGB(79, 219, 219) },
}

GameState.BASE_HALF_SIZE = 13
GameState.SLOT_Y = 2.5

-- World position of a slot pad on a base (slotIndex 1..6).
function GameState.slotPosition(baseIndex, slotIndex)
	local base = GameState.BASES[baseIndex]
	local row = (slotIndex - 1) % 3
	local col = math.floor((slotIndex - 1) / 3)
	local dx = (row - 1) * 6
	local dz = (col == 0) and -4 or 4
	return Vector3.new(base.center.X + dx, GameState.SLOT_Y, base.center.Z + dz)
end

-- Is a world position standing on a base's platform?
function GameState.onBasePlatform(baseIndex, position)
	local base = GameState.BASES[baseIndex]
	return math.abs(position.X - base.center.X) <= GameState.BASE_HALF_SIZE
		and math.abs(position.Z - base.center.Z) <= GameState.BASE_HALF_SIZE
		and position.Y > 1.5
end

local states = {}
local baseOwners = {}
local nextBrainrotId = 0

-- Wall-clock seconds. Locks and cooldowns are whole seconds, so os.time
-- is the right clock for them (os.clock measures CPU time, not wall time).
local function now()
	return os.time()
end

function GameState.newBrainrotId()
	nextBrainrotId += 1
	return "br_" .. tostring(nextBrainrotId)
end

function GameState.newState(player)
	local state = {
		player = player,
		cash = 0,
		rebirths = 0,
		slots = BrainrotData.START_SLOTS,
		speedLevel = 0,
		slapLevel = 0,
		lockLevel = 0,
		income2x = false,
		lockUntil = 0,
		lockCooldownUntil = 0,
		baseIndex = 0,
		brainrots = {},
		carrying = nil,
		slapCooldownUntil = 0,
	}
	states[player.UserId] = state
	return state
end

function GameState.getState(player)
	return states[player.UserId]
end

function GameState.getStateByUserId(userId)
	return states[userId]
end

function GameState.removeState(player)
	local state = states[player.UserId]
	if state and state.baseIndex > 0 then
		baseOwners[state.baseIndex] = nil
	end
	states[player.UserId] = nil
end

function GameState.claimBase(player)
	for index = 1, #GameState.BASES do
		if baseOwners[index] == nil then
			baseOwners[index] = player.UserId
			local state = GameState.getState(player)
			if state then
				state.baseIndex = index
			end
			return index
		end
	end
	return 0
end

function GameState.baseOwner(baseIndex)
	return baseOwners[baseIndex]
end

function GameState.allStates()
	return states
end

function GameState.addCash(player, amount)
	local state = GameState.getState(player)
	if state then
		state.cash += amount
	end
end

function GameState.spendCash(player, amount)
	local state = GameState.getState(player)
	if not state or state.cash < amount then
		return false
	end
	state.cash -= amount
	return true
end

function GameState.rebirthMultiplier(state)
	return BrainrotData.rebirthMultiplier(state.rebirths)
end

-- Dollars per second across every brainrot on the player's base.
function GameState.totalIncome(state)
	local sum = 0
	for _, record in pairs(state.brainrots) do
		local brainrot = BrainrotData.getBrainrot(record.brainrotId)
		if brainrot then
			sum += BrainrotData.baseIncome(brainrot, record.mutation)
		end
	end
	sum *= GameState.rebirthMultiplier(state)
	if state.income2x then
		sum *= 2
	end
	return math.floor(sum)
end

function GameState.freeSlot(state)
	for index = 1, state.slots do
		if state.brainrots[index] == nil then
			return index
		end
	end
	return nil
end

function GameState.brainrotCount(state)
	local count = 0
	for _ in pairs(state.brainrots) do
		count += 1
	end
	return count
end

function GameState.addBrainrot(state, record)
	local slot = GameState.freeSlot(state)
	if not slot then
		return nil
	end
	record.slotIndex = slot
	state.brainrots[slot] = record
	return slot
end

function GameState.removeBrainrot(state, slotIndex)
	local record = state.brainrots[slotIndex]
	state.brainrots[slotIndex] = nil
	return record
end

function GameState.lockDuration(state)
	return BrainrotData.LOCK_SECONDS + 30 * state.lockLevel
end

function GameState.isLocked(state)
	return now() < state.lockUntil
end

function GameState.lockSecondsLeft(state)
	local left = state.lockUntil - now()
	if left < 0 then
		return 0
	end
	return math.ceil(left)
end

function GameState.lockCooldownLeft(state)
	local left = state.lockCooldownUntil - now()
	if left < 0 then
		return 0
	end
	return math.ceil(left)
end

-- Rebirth: cash and brainrots go, the +25% multiplier stays forever.
function GameState.applyRebirth(state)
	local cost = BrainrotData.rebirthCost(state.rebirths)
	if state.cash < cost then
		return false, cost
	end
	state.cash = 0
	state.brainrots = {}
	state.rebirths += 1
	return true, cost
end

-- The compact copy the client gets over StateSync.
function GameState.syncSnapshot(state)
	return {
		cash = math.floor(state.cash),
		income = GameState.totalIncome(state),
		rebirths = state.rebirths,
		multiplier = GameState.rebirthMultiplier(state),
		slots = state.slots,
		brainrotCount = GameState.brainrotCount(state),
		speedLevel = state.speedLevel,
		slapLevel = state.slapLevel,
		lockLevel = state.lockLevel,
		income2x = state.income2x,
		lockSecondsLeft = GameState.lockSecondsLeft(state),
		lockCooldownLeft = GameState.lockCooldownLeft(state),
		carrying = state.carrying ~= nil,
		baseIndex = state.baseIndex,
		rebirthCost = BrainrotData.rebirthCost(state.rebirths),
	}
end

return GameState
