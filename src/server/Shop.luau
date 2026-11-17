-- Shop: spend cash on upgrades. Everything here is bought with the
-- money brainrots earn, so the shop is the game's progression sink:
-- more slots, faster feet, a harder slap, a longer lock, and a burst
-- of double income. Prices rise per level so the choice stays real.

local GameState = require(script.Parent.GameState)
local BrainrotData = require(game:GetService("ReplicatedStorage").Shared.BrainrotData)

local Shop = {}

export type ShopItem = {
	Id: string,
	Name: string,
	Desc: string,
	Price: number,
	MaxLevel: number,
}

-- The shop list lives in BrainrotData (shared) so the client draws the
-- same items the server prices. Price is the cost of the first level;
-- it doubles per level.
Shop.ITEMS = BrainrotData.SHOP_ITEMS

-- The level a player has of an item, from their state.
function Shop.levelOf(state: GameState.PlayerState, itemId: string): number
	if itemId == "slot" then
		return state.Slots - GameState.START_SLOTS
	elseif itemId == "speed" then
		return state.SpeedLevel
	elseif itemId == "slap" then
		return state.SlapLevel
	elseif itemId == "lock" then
		-- Lock level is stored as extra lock seconds / 30.
		return state.LockExtraLevel or 0
	end
	return 0
end

-- Price of the next level of an item for this player.
function Shop.priceOf(state: GameState.PlayerState, item: ShopItem): number
	local level = Shop.levelOf(state, item.Id)
	return item.Price * (2 ^ level)
end

-- Buy an item. Returns true when it worked, false when the player
-- cannot afford it or is already maxed out.
function Shop.buy(player: Player, itemId: string): boolean
	local state = GameState.get(player)
	if not state then
		return false
	end
	local item: ShopItem? = nil
	for _, entry in Shop.ITEMS do
		if entry.Id == itemId then
			item = entry
			break
		end
	end
	if not item then
		return false
	end
	local level = Shop.levelOf(state, itemId)
	if level >= item.MaxLevel then
		return false
	end
	local price = Shop.priceOf(state, item)
	if state.Cash < price then
		return false
	end
	state.Cash -= price
	if itemId == "slot" then
		state.Slots += 1
	elseif itemId == "speed" then
		state.SpeedLevel += 1
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local carrying = state.Carrying ~= nil
				local base = 16
				if carrying then
					base = 8
				end
				humanoid.WalkSpeed = base + 2 * state.SpeedLevel
			end
		end
	elseif itemId == "slap" then
		state.SlapLevel += 1
	elseif itemId == "lock" then
		state.LockExtraLevel = (state.LockExtraLevel or 0) + 1
	elseif itemId == "boost" then
		state.BoostUntil = os.clock() + 60
	end
	return true
end

-- Lock seconds for this player (base 60 plus 30 per lock level).
function Shop.lockSeconds(state: GameState.PlayerState): number
	return GameState.LOCK_SECONDS + 30 * (state.LockExtraLevel or 0)
end

return Shop
