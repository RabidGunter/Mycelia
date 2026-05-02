--!strict
-- Potion catalog. The brewing system produces potions whose id is looked
-- up in this table for display, and (when present in Constants.POTIONS)
-- for effect application.
--
-- Effects are wired up in two places:
--   * `Constants.POTIONS[id]` — effect kind + params + duration. Potions
--     present here are *active* and consumable. Potions missing from there
--     are *inert* and sit in inventory with "No effect yet" in the UI.
--   * `PotionEffects.lua` — handler implementations per effect kind.
--
-- Phase 1 catalog: 20 potions total (6 from Pre-Alpha + 14 new). Several
-- new ones reference effect kinds (luck, harvestYield, reveal, spiritAttract,
-- cosmeticGlow, weatherSummon, timeShift) that ship in the next Phase 1
-- task; until then those potions are inert. See docs/specs/potions-and-recipes.md.

local Potions = {}

Potions.LIST = {
	-- Pre-Alpha (6) -------------------------------------------------------
	{
		id = "CommonSpeedPotion",
		displayName = "Common Speed Potion",
		description = "Quickens your stride for a short while.",
		rarity = "Common",
	},
	{
		id = "DewdropTonic",
		displayName = "Dewdrop Tonic",
		description = "A glistening tonic. Smells faintly of rainfall.",
		rarity = "Common",
	},
	{
		id = "HearthBrew",
		displayName = "Hearth Brew",
		description = "A warming amber brew that smells of woodsmoke.",
		rarity = "Common",
	},
	{
		id = "InkblotElixir",
		displayName = "Inkblot Elixir",
		description = "Black as a moonless pond. The bottle stains everything it touches.",
		rarity = "Uncommon",
	},
	{
		id = "SpottedTincture",
		displayName = "Spotted Tincture",
		description = "Fizzy and unpredictable. Garden gnomes report mild visions.",
		rarity = "Uncommon",
	},
	{
		id = "GlowmossPowder",
		displayName = "Glowmoss Powder",
		description = "Bioluminescent dust. Said to reveal hidden mushrooms when sprinkled.",
		rarity = "Rare",
	},
	-- Phase 1 additions (14) ---------------------------------------------
	{
		id = "StonecastInfusion",
		displayName = "Stonecast Infusion",
		description = "Earthy, mineral-tasting. Steeped from rings of mossring.",
		rarity = "Common",
	},
	{
		id = "WoodlandWarmth",
		displayName = "Woodland Warmth",
		description = "A gentle, sun-warm boil. Settles into the bones.",
		rarity = "Common",
	},
	{
		id = "LatticeBalm",
		displayName = "Lattice Balm",
		description = "Translucent salve laced with woven veil-cap. Time bends a little.",
		rarity = "Uncommon",
	},
	{
		id = "HollowwindBrew",
		displayName = "Hollowwind Brew",
		description = "Smells of high places. Fermented hollowstem keeps it bracing.",
		rarity = "Uncommon",
	},
	{
		id = "CoralCordial",
		displayName = "Coral Cordial",
		description = "Sweet and saline at once. Forest creatures gather where it spills.",
		rarity = "Uncommon",
	},
	{
		id = "DaybreakPowder",
		displayName = "Daybreak Powder",
		description = "Glittering gold dust. Ground from sundrop caps; lets you call the dawn.",
		rarity = "Uncommon",
	},
	{
		id = "LuckPowder",
		displayName = "Luck Powder",
		description = "Whisperbloom dust that hums faintly. Rare finds favor those who carry it.",
		rarity = "Rare",
	},
	{
		id = "EverdewPowder",
		displayName = "Everdew Powder",
		description = "Damp-cool grit. A pinch summons rain to the local glade.",
		rarity = "Rare",
	},
	{
		id = "CrystalEssence",
		displayName = "Crystal Essence",
		description = "Refined twice over. Distilled crystalcaps wreathe the drinker in pale light.",
		rarity = "Rare",
	},
	{
		id = "NightlanternOil",
		displayName = "Nightlantern Oil",
		description = "Deep-emerald glow. Reveals the hidden things under leaves and stones.",
		rarity = "Rare",
	},
	{
		id = "TideweaverElixir",
		displayName = "Tideweaver Elixir",
		description = "Rolling currents in a bottle. The forest yields more to those it favors.",
		rarity = "Rare",
	},
	{
		id = "SpiritcallTonic",
		displayName = "Spiritcall Tonic",
		description = "A whisper made liquid. Forest spirits drift closer to those who drink it.",
		rarity = "Rare",
	},
}

Potions.byId = {}
for _, p in ipairs(Potions.LIST) do
	Potions.byId[p.id] = p
end

return Potions
