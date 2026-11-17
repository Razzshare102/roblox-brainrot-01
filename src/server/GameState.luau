-- GameState: the single source of truth for every player's state on the
-- server. Nothing else on the server keeps its own copy of a player's
-- cash, brainrots, lock or rebirths; every system reads and writes here.
-- The client never writes state directly — it asks through RemoteEvents
-- and the server validates each request here before changing anything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BrainrotData = require(ReplicatedStorage.Shared.BrainrotData)

local GameState = {}

export type OwnedBrainrot = {
	Uid: string,
	DefId: string,
	Mutation: string,
	Mult: number,
	Slot: number,
}

export type PlayerState = {
	Cash: number,
	Rebirths: number,
	Multiplier: number, -- income multiplier from rebirths (1 + 0.25 per rebirth)
	Slots: number, -- base slots owned (start 3, max 6)
	Brainrots: { OwnedBrainrot },
	LockUntil: number, -- os.clock() time the base lock ends, 0 when unlocked
	LockCooldownUntil: number,
	SpeedLevel: number, -- 0..3, +2 WalkSpeed each
	SlapLevel: number, -- 0..3, +slap knockback each
	LockExtraLevel: number, -- 0..2, +30s lock each
	BoostUntil: number, -- os.clock() time a 2x income boost ends, 0 when none
	Carrying: string?, -- uid of the brainrot this player is carrying, if any
	LastSlapAt: number,
}

local START_CASH = 100
local START_SLOTS = 3
local MAX_SLOTS = 6
local LOCK_SECONDS = 60
local LOCK_COOLDOWN = 90
local REBIRTH_BASE_COST = 50000
local REBIRTH_COST_MULT = 3

local states: { [Player]: PlayerState } = {}
local uidCounter = 0

function GameState.newUid(): string
	uidCounter += 1
	return "br" .. tostring(uidCounter) .. "_" .. tostring(math.floor(os.clock() * 1000))
end

-- A fresh state for a player who just joined.
function GameState.newState(): PlayerState
	return {
		Cash = START_CASH,
		Rebirths = 0,
		Multiplier = 1,
		Slots = START_SLOTS,
		Brainrots = {},
		LockUntil = 0,
		LockCooldownUntil = 0,
		SpeedLevel = 0,
		SlapLevel = 0,
		LockExtraLevel = 0,
		BoostUntil = 0,
		Carrying = nil,
		LastSlapAt = 0,
	}
end

function GameState.get(player: Player): PlayerState?
	return states[player]
end

function GameState.add(player: Player)
	states[player] = GameState.newState()
end

function GameState.remove(player: Player)
	states[player] = nil
end

function GameState.forEach(callback: (Player, PlayerState) -> ())
	for player, state in states do
		callback(player, state)
	end
end

-- Money per second from all owned brainrots, before the rebirth
-- multiplier and before any temporary boost.
function GameState.baseIncome(state: PlayerState): number
	local total = 0
	for _, owned in state.Brainrots do
		local def = BrainrotData.getById(owned.DefId)
		if def then
			total += def.Rate * owned.Mult
		end
	end
	return total
end

-- Money per second actually ticking right now.
function GameState.incomePerSecond(state: PlayerState): number
	local income = GameState.baseIncome(state) * state.Multiplier
	if state.BoostUntil > os.clock() then
		income *= 2
	end
	return income
end

-- First free slot index, or 0 when the base is full.
function GameState.freeSlot(state: PlayerState): number
	local used: { [number]: boolean } = {}
	for _, owned in state.Brainrots do
		used[owned.Slot] = true
	end
	for i = 1, state.Slots do
		if not used[i] then
			return i
		end
	end
	return 0
end

-- Put a brainrot on the player's base. Returns the owned record, or nil
-- when the base is full.
function GameState.placeBrainrot(state: PlayerState, defId: string, mutation: string, mult: number): OwnedBrainrot?
	local slot = GameState.freeSlot(state)
	if slot == 0 then
		return nil
	end
	local owned: OwnedBrainrot = {
		Uid = GameState.newUid(),
		DefId = defId,
		Mutation = mutation,
		Mult = mult,
		Slot = slot,
	}
	table.insert(state.Brainrots, owned)
	return owned
end

-- Take a brainrot off the player's base by uid. Returns it, or nil.
function GameState.takeBrainrot(state: PlayerState, uid: string): OwnedBrainrot?
	for i, owned in state.Brainrots do
		if owned.Uid == uid then
			table.remove(state.Brainrots, i)
			return owned
		end
	end
	return nil
end

function GameState.findBrainrot(state: PlayerState, uid: string): OwnedBrainrot?
	for _, owned in state.Brainrots do
		if owned.Uid == uid then
			return owned
		end
	end
	return nil
end

-- Is this player's base locked right now?
function GameState.isLocked(state: PlayerState): boolean
	return state.LockUntil > os.clock()
end

function GameState.lockSecondsLeft(state: PlayerState): number
	return math.max(0, state.LockUntil - os.clock())
end

-- Lock the base for `seconds`. Returns false when on cooldown.
function GameState.lockBase(state: PlayerState, seconds: number): boolean
	local now = os.clock()
	if now < state.LockCooldownUntil then
		return false
	end
	if GameState.isLocked(state) then
		return false
	end
	state.LockUntil = now + seconds
	state.LockCooldownUntil = now + seconds + LOCK_COOLDOWN
	return true
end

-- Cash needed for the next rebirth.
function GameState.rebirthCost(state: PlayerState): number
	return REBIRTH_BASE_COST * (REBIRTH_COST_MULT ^ state.Rebirths)
end

-- Rebirth: reset cash and brainrots, keep slots and upgrades, gain +25%
-- income forever. Returns false when the player cannot afford it.
function GameState.rebirth(state: PlayerState): boolean
	local cost = GameState.rebirthCost(state)
	if state.Cash < cost then
		return false
	end
	state.Cash = START_CASH
	state.Brainrots = {}
	state.Rebirths += 1
	state.Multiplier = 1 + 0.25 * state.Rebirths
	return true
end

GameState.START_CASH = START_CASH
GameState.START_SLOTS = START_SLOTS
GameState.MAX_SLOTS = MAX_SLOTS
GameState.LOCK_SECONDS = LOCK_SECONDS
GameState.LOCK_COOLDOWN = LOCK_COOLDOWN

-- Hand the state out to a player who left, so a dropped carried brainrot
-- can be returned to its owner's base.
Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)

return GameState
