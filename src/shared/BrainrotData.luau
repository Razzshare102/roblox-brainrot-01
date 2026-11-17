-- BrainrotData: the cast of Brainrot Bay. One table per brainrot: its name,
-- rarity, base money per second, body color, size and a one-line joke.
-- The server spawns these on the conveyor; the client shows them in the
-- shop, the labels and the index. All characters are original creations
-- for this game, not copies of any other game's cast.

local BrainrotData = {}

export type RarityName = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Brainrot God"

export type BrainrotDef = {
	Id: string,
	Name: string,
	Rarity: RarityName,
	Rate: number, -- money per second at mutation x1
	Color: Color3,
	Size: number, -- body stud height
	Price: number, -- cash to buy one
	Blurb: string,
}

-- Rarity ladder, cheapest first. Price is roughly Rate x 100 so a brainrot
-- pays for itself in about 100 seconds of ticking.
BrainrotData.RARITIES = {
	"Common",
	"Rare",
	"Epic",
	"Legendary",
	"Mythic",
	"Brainrot God",
}

BrainrotData.RARITY_COLORS = {
	Common = Color3.fromRGB(180, 180, 180),
	Rare = Color3.fromRGB(80, 170, 255),
	Epic = Color3.fromRGB(170, 90, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
	Mythic = Color3.fromRGB(255, 80, 140),
	["Brainrot God"] = Color3.fromRGB(255, 240, 120),
}

-- Spawn weights: how likely each rarity is to roll on the belt.
BrainrotData.RARITY_WEIGHTS = {
	Common = 52,
	Rare = 26,
	Epic = 13,
	Legendary = 6,
	Mythic = 2.4,
	["Brainrot God"] = 0.6,
}

BrainrotData.DEFS = {
	-- Common: the everyday weirdos.
	{
		Id = "noodle-cat",
		Name = "Noodle Cat",
		Rarity = "Common",
		Rate = 5,
		Color = Color3.fromRGB(255, 200, 120),
		Size = 2.2,
		Price = 500,
		Blurb = "A cat made of noodles. Slurps itself when nervous.",
	},
	{
		Id = "pickle-pal",
		Name = "Pickle Pal",
		Rarity = "Common",
		Rate = 6,
		Color = Color3.fromRGB(120, 200, 80),
		Size = 2.2,
		Price = 600,
		Blurb = "A pickle with big dreams and zero chill.",
	},
	{
		Id = "sock-puppet",
		Name = "Sock Puppet",
		Rarity = "Common",
		Rate = 7,
		Color = Color3.fromRGB(200, 120, 200),
		Size = 2.4,
		Price = 700,
		Blurb = "Talks back. Mostly about feet.",
	},
	-- Rare: getting strange.
	{
		Id = "disco-pigeon",
		Name = "Disco Pigeon",
		Rarity = "Rare",
		Rate = 15,
		Color = Color3.fromRGB(120, 140, 255),
		Size = 2.6,
		Price = 1500,
		Blurb = "Never stops dancing. Neither does your wallet.",
	},
	{
		Id = "toaster-shark",
		Name = "Toaster Shark",
		Rarity = "Rare",
		Rate = 18,
		Color = Color3.fromRGB(220, 220, 230),
		Size = 2.8,
		Price = 1800,
		Blurb = "Toasty on the outside, shark on the inside.",
	},
	{
		Id = "traffic-cone-dog",
		Name = "Traffic Cone Dog",
		Rarity = "Rare",
		Rate = 20,
		Color = Color3.fromRGB(255, 130, 40),
		Size = 2.6,
		Price = 2000,
		Blurb = "Directs traffic. Charges for it.",
	},
	-- Epic: the bay's celebrities.
	{
		Id = "dj-banana",
		Name = "DJ Banana",
		Rarity = "Epic",
		Rate = 40,
		Color = Color3.fromRGB(255, 220, 40),
		Size = 3.0,
		Price = 4000,
		Blurb = "Drops beats and drops the bass. Never peels out.",
	},
	{
		Id = "couch-potato-king",
		Name = "Couch Potato King",
		Rarity = "Epic",
		Rate = 45,
		Color = Color3.fromRGB(150, 100, 60),
		Size = 3.2,
		Price = 4500,
		Blurb = "Rules the living room from a recliner of gold.",
	},
	{
		Id = "lawn-flamingo",
		Name = "Lawn Flamingo",
		Rarity = "Epic",
		Rate = 50,
		Color = Color3.fromRGB(255, 120, 180),
		Size = 3.0,
		Price = 5000,
		Blurb = "Stands on one leg. Owns the whole lawn.",
	},
	-- Legendary: rare sightings.
	{
		Id = "astronaut-llama",
		Name = "Astronaut Llama",
		Rarity = "Legendary",
		Rate = 100,
		Color = Color3.fromRGB(200, 220, 255),
		Size = 3.4,
		Price = 10000,
		Blurb = "Spits in zero gravity. It still lands.",
	},
	{
		Id = "wizard-frog",
		Name = "Wizard Frog",
		Rarity = "Legendary",
		Rate = 120,
		Color = Color3.fromRGB(80, 200, 120),
		Size = 3.2,
		Price = 12000,
		Blurb = "Ribbitus Maximus. Turns coins into more coins.",
	},
	{
		Id = "turbo-turtle",
		Name = "Turbo Turtle",
		Rarity = "Legendary",
		Rate = 140,
		Color = Color3.fromRGB(90, 180, 90),
		Size = 3.4,
		Price = 14000,
		Blurb = "The fastest slow animal in the bay.",
	},
	-- Mythic: almost a rumor.
	{
		Id = "golden-goose-prime",
		Name = "Golden Goose Prime",
		Rarity = "Mythic",
		Rate = 300,
		Color = Color3.fromRGB(255, 210, 60),
		Size = 3.8,
		Price = 30000,
		Blurb = "Lays golden eggs. Charges rent for the nest.",
	},
	{
		Id = "cyber-unicorn",
		Name = "Cyber Unicorn",
		Rarity = "Mythic",
		Rate = 350,
		Color = Color3.fromRGB(140, 220, 255),
		Size = 3.8,
		Price = 35000,
		Blurb = "Half horse, half Wi-Fi. Fully fabulous.",
	},
	-- Brainrot God: the top of the ladder.
	{
		Id = "sir-reginald",
		Name = "Sir Reginald III",
		Rarity = "Brainrot God",
		Rate = 1000,
		Color = Color3.fromRGB(255, 240, 150),
		Size = 4.4,
		Price = 100000,
		Blurb = "A top hat with a monocle and a trust fund.",
	},
	{
		Id = "infinite-sandwich",
		Name = "The Infinite Sandwich",
		Rarity = "Brainrot God",
		Rate = 1200,
		Color = Color3.fromRGB(230, 180, 120),
		Size = 4.4,
		Price = 120000,
		Blurb = "Every bite regrows. Every crumb is cash.",
	},
}

-- Mutations multiply a brainrot's money per second. Rolled when it spawns.
BrainrotData.MUTATIONS = {
	{ Name = "Normal", Mult = 1, Weight = 70, Color = Color3.fromRGB(255, 255, 255) },
	{ Name = "Golden", Mult = 2, Weight = 18, Color = Color3.fromRGB(255, 210, 60) },
	{ Name = "Diamond", Mult = 4, Weight = 8, Color = Color3.fromRGB(140, 220, 255) },
	{ Name = "Rainbow", Mult = 8, Weight = 3.2, Color = Color3.fromRGB(255, 120, 200) },
	{ Name = "Galactic", Mult = 15, Weight = 0.8, Color = Color3.fromRGB(170, 90, 255) },
}

-- The shop list, shared so the client can draw it and the server can
-- price it. Price is the cost of the first level; it doubles per level.
BrainrotData.SHOP_ITEMS = {
	{
		Id = "slot",
		Name = "Base Slot",
		Desc = "One more brainrot fits on your base.",
		Price = 500,
		MaxLevel = 3,
	},
	{
		Id = "speed",
		Name = "Speed Boots",
		Desc = "+2 WalkSpeed. Outrun the wave.",
		Price = 300,
		MaxLevel = 3,
	},
	{
		Id = "slap",
		Name = "Slap Power",
		Desc = "+10 slap knockback.",
		Price = 200,
		MaxLevel = 3,
	},
	{
		Id = "lock",
		Name = "Longer Lock",
		Desc = "+30s of base lock.",
		Price = 400,
		MaxLevel = 2,
	},
	{
		Id = "boost",
		Name = "2x Income (60s)",
		Desc = "Double money per second for one minute.",
		Price = 1000,
		MaxLevel = 99,
	},
}

-- Look a brainrot up by its id. Returns nil for an unknown id.
function BrainrotData.getById(id: string): BrainrotDef?
	for _, def in BrainrotData.DEFS do
		if def.Id == id then
			return def
		end
	end
	return nil
end

-- All definitions of one rarity, in ladder order.
function BrainrotData.getByRarity(rarity: RarityName): { BrainrotDef }
	local out = {}
	for _, def in BrainrotData.DEFS do
		if def.Rarity == rarity then
			table.insert(out, def)
		end
	end
	return out
end

-- The 1-based index of a rarity on the ladder (Common = 1).
function BrainrotData.rarityIndex(rarity: RarityName): number
	for i, name in BrainrotData.RARITIES do
		if name == rarity then
			return i
		end
	end
	return 1
end

return BrainrotData
