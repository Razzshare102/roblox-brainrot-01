-- Brainrot Bay: the shop. Five upgrades, bought with the cash your
-- brainrots earn. Prices rise one step per level you already own.

local BrainrotData = require(script.Parent.Parent.Shared.BrainrotData)
local GameState = require(script.Parent.GameState)

local Shop = {}

function Shop.levelOf(state, itemId)
	if itemId == "Slot" then
		return state.slots - BrainrotData.START_SLOTS
	elseif itemId == "Speed" then
		return state.speedLevel
	elseif itemId == "Slap" then
		return state.slapLevel
	elseif itemId == "Lock" then
		return state.lockLevel
	elseif itemId == "Income2x" then
		return state.income2x and 1 or 0
	end
	return 0
end

function Shop.nextCost(state, item)
	local level = Shop.levelOf(state, item.id)
	return BrainrotData.shopCost(item, level + 1)
end

-- Buy one level of a shop item. Returns ok and a message for the player.
function Shop.buyItem(player, itemId)
	local state = GameState.getState(player)
	if not state then
		return false, "No state."
	end
	local item = BrainrotData.shopItem(itemId)
	if not item then
		return false, "No such item."
	end
	local level = Shop.levelOf(state, itemId)
	if level >= item.maxLevel then
		return false, item.name .. " is maxed out."
	end
	local cost = BrainrotData.shopCost(item, level + 1)
	if state.cash < cost then
		return false, string.format("You need $%d for %s.", cost, item.name)
	end
	state.cash -= cost
	if itemId == "Slot" then
		state.slots += 1
	elseif itemId == "Speed" then
		state.speedLevel += 1
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 16 + 2 * state.speedLevel
		end
	elseif itemId == "Slap" then
		state.slapLevel += 1
	elseif itemId == "Lock" then
		state.lockLevel += 1
	elseif itemId == "Income2x" then
		state.income2x = true
	end
	return true, string.format("Bought %s for $%d.", item.name, cost)
end

-- Rebirth: pay the cost, lose your cash and brainrots, keep a permanent
-- +25% income multiplier for every rebirth you have done.
function Shop.doRebirth(player)
	local state = GameState.getState(player)
	if not state then
		return false, "No state."
	end
	local cost = BrainrotData.rebirthCost(state.rebirths)
	if state.cash < cost then
		return false, string.format("Rebirth costs $%d. Keep earning.", cost)
	end
	-- Clear the brainrot models off the base first.
	local StealSystem = require(script.Parent.StealSystem)
	for slotIndex, _ in pairs(state.brainrots) do
		StealSystem.removeBaseModel(player.UserId, slotIndex)
	end
	local ok, spent = GameState.applyRebirth(state)
	if not ok then
		return false, "Rebirth failed."
	end
	return true, string.format("Reborn! Income is now x%.2f forever.", GameState.rebirthMultiplier(state))
end

return Shop
