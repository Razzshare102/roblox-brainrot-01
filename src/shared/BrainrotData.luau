-- Brainrot Bay: the cast, rarities, mutations and shop.
-- Shared by the server (spawning, income) and the client (labels, shop UI).
-- Every name and rate here is the game's design: keep them in sync with README.md.

local BrainrotData = {}

-- Rarities, rarest last. weight is the spawn weight out of 100.
BrainrotData.RARITIES = {
	Common = { order = 1, color = Color3.fromRGB(120, 200, 90), weight = 50 },
	Rare = { order = 2, color = Color3.fromRGB(70, 140, 255), weight = 25 },
	Epic = { order = 3, color = Color3.fromRGB(170, 90, 255), weight = 13 },
	Legendary = { order = 4, color = Color3.fromRGB(255, 160, 40), weight = 7 },
	Mythic = { order = 5, color = Color3.fromRGB(255, 70, 120), weight = 3.5 },
	BrainrotGod = { order = 6, color = Color3.fromRGB(90, 230, 230), weight = 1.5 },
}

BrainrotData.RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythic", "BrainrotGod" }

BrainrotData.RARITY_LABELS = {
	Common = "Common",
	Rare = "Rare",
	Epic = "Epic",
	Legendary = "Legendary",
	Mythic = "Mythic",
	BrainrotGod = "Brainrot God",
}

-- Mutations multiply a brainrot's income. weight is the roll weight out of 100.
BrainrotData.MUTATIONS = {
	Normal = { mult = 1, color = Color3.fromRGB(255, 255, 255), weight = 70 },
	Golden = { mult = 2, color = Color3.fromRGB(255, 215, 0), weight = 18 },
	Diamond = { mult = 4, color = Color3.fromRGB(120, 220, 255), weight = 7 },
	Rainbow = { mult = 8, color = Color3.fromRGB(255, 120, 220), weight = 3.5 },
	Galactic = { mult = 15, color = Color3.fromRGB(160, 90, 255), weight = 1.5 },
}

BrainrotData.MUTATION_ORDER = { "Normal", "Golden", "Diamond", "Rainbow", "Galactic" }

-- The cast: 15 original brainrots. rate is dollars per second.
-- short is the name the floating label over the character shows.
BrainrotData.BRAINROTS = {
	{ id = "TungTungSahur", name = "Tung Tung Sahur", short = "Tung Tung", rarity = "Common", rate = 12 },
	{ id = "BrrBrrPatapim", name = "Brr Brr Patapim", short = "Brr Brr", rarity = "Common", rate = 9 },
	{ id = "TralaleroTralala", name = "Tralalero Tralala", short = "Tralala", rarity = "Rare", rate = 48 },
	{ id = "ChimpanziniBananini", name = "Chimpanzini Bananini", short = "Bananini", rarity = "Rare", rate = 35 },
	{ id = "CappuccinoAssassino", name = "Cappuccino Assassino", short = "Cappuccino", rarity = "Epic", rate = 95 },
	{ id = "LiriliLarila", name = "Lirili Larila", short = "Lirili", rarity = "Epic", rate = 120 },
	{ id = "BonecaAmbalabu", name = "Boneca Ambalabu", short = "Boneca", rarity = "Epic", rate = 140 },
	{ id = "LaVacaSaturno", name = "La Vaca Saturno", short = "La Vaca", rarity = "Legendary", rate = 260 },
	{ id = "ChimpanziniBananiniPrime", name = "Chimpanzini Bananini", short = "Bananini", rarity = "Legendary", rate = 260 },
	{ id = "FrigoCamelo", name = "Frigo Camelo", short = "Frigo", rarity = "Legendary", rate = 310 },
	{ id = "GiraffaCeleste", name = "Giraffa Celeste", short = "Giraffa", rarity = "Mythic", rate = 520 },
	{ id = "LosTralaleritos", name = "Los Tralaleritos", short = "Tralaleritos", rarity = "Mythic", rate = 640 },
	{ id = "Matteo", name = "Matteo", short = "Matteo", rarity = "Mythic", rate = 780 },
	{ id = "GraipussMedussi", name = "Graipuss Medussi", short = "Graipuss", rarity = "Brainrot God", rate = 1500 },
	{ id = "LosCrocodillitos", name = "Los Crocodillitos", short = "Crocodillitos", rarity = "Brainrot God", rate = 2200 },
}

-- The shop: five upgrades. cost for level n is baseCost * n.
BrainrotData.SHOP = {
	{ id = "Slot", name = "Extra Base Slot", desc = "+1 brainrot slot on your base", baseCost = 300, maxLevel = 3 },
	{ id = "Speed", name = "Speed Boost", desc = "+2 walk speed", baseCost = 400, maxLevel = 5 },
	{ id = "Slap", name = "Slap Power", desc = "Slap hits harder and further", baseCost = 300, maxLevel = 5 },
	{ id = "Lock", name = "Longer Lock", desc = "+30s base lock time", baseCost = 350, maxLevel = 3 },
	{ id = "Income2x", name = "2x Income", desc = "Double all brainrot income, forever", baseCost = 1500, maxLevel = 1 },
}

BrainrotData.START_SLOTS = 3
BrainrotData.MAX_SLOTS = 6
BrainrotData.LOCK_SECONDS = 60
BrainrotData.LOCK_COOLDOWN_SECONDS = 120
BrainrotData.REBIRTH_BASE_COST = 10000
BrainrotData.REBIRTH_MULT_PER = 0.25

function BrainrotData.getBrainrot(id)
	for _, brainrot in ipairs(BrainrotData.BRAINROTS) do
		if brainrot.id == id then
			return brainrot
		end
	end
	return nil
end

function BrainrotData.brainrotsOfRarity(rarity)
	local out = {}
	for _, brainrot in ipairs(BrainrotData.BRAINROTS) do
		if brainrot.rarity == rarity then
			table.insert(out, brainrot)
		end
	end
	return out
end

local function rollWeighted(entries)
	local total = 0
	for _, entry in ipairs(entries) do
		total += entry.weight
	end
	local roll = math.random() * total
	for _, entry in ipairs(entries) do
		roll -= entry.weight
		if roll <= 0 then
			return entry.key
		end
	end
	return entries[1].key
end

function BrainrotData.rollRarity()
	local entries = {}
	for _, key in ipairs(BrainrotData.RARITY_ORDER) do
		table.insert(entries, { key = key, weight = BrainrotData.RARITIES[key].weight })
	end
	return rollWeighted(entries)
end

function BrainrotData.rollMutation()
	local entries = {}
	for _, key in ipairs(BrainrotData.MUTATION_ORDER) do
		table.insert(entries, { key = key, weight = BrainrotData.MUTATIONS[key].weight })
	end
	return rollWeighted(entries)
end

function BrainrotData.rollBrainrot()
	local rarity = BrainrotData.rollRarity()
	local pool = BrainrotData.brainrotsOfRarity(rarity)
	local brainrot = pool[math.random(1, #pool)]
	local mutation = BrainrotData.rollMutation()
	return brainrot, mutation
end

-- Dollars per second a brainrot earns, before rebirth and shop multipliers.
function BrainrotData.baseIncome(brainrot, mutation)
	local mult = BrainrotData.MUTATIONS[mutation].mult
	return brainrot.rate * mult
end

-- What a brainrot costs off the belt: one second of its income.
function BrainrotData.buyCost(brainrot)
	return brainrot.rate
end

function BrainrotData.shopItem(id)
	for _, item in ipairs(BrainrotData.SHOP) do
		if item.id == id then
			return item
		end
	end
	return nil
end

function BrainrotData.shopCost(item, level)
	return item.baseCost * level
end

function BrainrotData.rebirthCost(rebirths)
	return BrainrotData.REBIRTH_BASE_COST * (rebirths + 1)
end

function BrainrotData.rebirthMultiplier(rebirths)
	return 1 + BrainrotData.REBIRTH_MULT_PER * rebirths
end

function BrainrotData.labelText(brainrot, mutation)
	if mutation == "Normal" then
		return brainrot.short
	end
	return mutation .. " " .. brainrot.short
end

return BrainrotData
