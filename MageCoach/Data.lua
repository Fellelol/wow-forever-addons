-- MageCoach data. Talent paths and spell lists follow the Mobalytics "WoW Forever Mage Leveling Guide"
-- (by Asuna_qt). Map coordinates are approximate; add your own with /mc pin <note>.
local _, MC = ...
MC.Data = {}
local D = MC.Data

------------------------------------------------------------------------
-- Talent paths: entry i is the point spent at level (i + 9), i.e. [1] = level 10.
------------------------------------------------------------------------
D.PathOrder = { "arcane", "frost", "fire", "frostaoe" }

D.Paths = {
    arcane = {
        name = "Arcane",
        color = "ff69ccf0",
        split = "32 / 16 / 3",
        blurb = "Recommended starter: best mana conservation, fewest drink breaks. Swap to Frost later if you like.",
        talents = {
            "Improved Channeling", "Improved Channeling", "Improved Channeling", "Improved Channeling", "Improved Channeling", -- 10-14
            "Missile Barrage", "Missile Barrage",                                                                              -- 15-16
            "Arcane Concentration", "Arcane Concentration", "Arcane Concentration",                                           -- 17-19
            "Arcane Blast",                                                                                                    -- 20
            "Arcane Concentration", "Arcane Concentration",                                                                   -- 21-22
            "Arcane Subtlety", "Arcane Subtlety",                                                                             -- 23-24
            "Arcane Wrath",                                                                                                    -- 25
            "Arcane Impact", "Arcane Impact", "Arcane Impact",                                                                 -- 26-28
            "Arcane Meditation",                                                                                               -- 29
            "Presence of Mind",                                                                                                -- 30
            "Arcane Mind", "Arcane Mind", "Arcane Mind", "Arcane Mind",                                                       -- 31-34
            "Arcane Instability", "Arcane Instability", "Arcane Instability",                                                 -- 35-37
            "Arcane Mind",                                                                                                     -- 38
            "Arcane Meditation",                                                                                               -- 39
            "Arcane Power",                                                                                                    -- 40
            "Precision", "Precision", "Precision",                                                                             -- 41-43
            "Arcane Meditation",                                                                                               -- 44
            "Accelerant", "Accelerant", "Accelerant", "Accelerant", "Accelerant",                                             -- 45-49
            "Ignite", "Ignite", "Ignite", "Ignite", "Ignite",                                                                  -- 50-54
            "Pyroblast",                                                                                                       -- 55
            "Improved Fire Blast", "Improved Fire Blast",                                                                     -- 56-57
            "Incineration", "Incineration",                                                                                   -- 58-59
            "Heating Up",                                                                                                      -- 60
        },
        notes = {
            { 10, "Improved Channeling (less pushback on Missiles), then Missile Barrage + Arcane Concentration." },
            { 20, "Arcane Blast unlocked: your main spammable spell." },
            { 25, "Arcane Wrath unlocked: big hitter, use as your precast." },
            { 30, "Presence of Mind: instant Arcane Wrath, or save it for an emergency Polymorph." },
            { 40, "Arcane Power: main offensive cooldown, pop it right after your precast." },
            { 41, "Flexible from here. Improved Counterspell is fine on PvP servers (drop Impact/Meditation)." },
            { 45, "Accelerant speeds up Arcane Wrath. Incineration (Arcane Blast crit) is an equal alternative." },
            { 50, "Ignite into Pyroblast at 55 and Heating Up at 60." },
        },
        rotation = {
            "Precast Arcane Wrath (or anything) before the pull.",
            "Missile Barrage proc  ->  Arcane Missiles.",
            "Arcane Wrath when it is safe to hard-cast.",
            "Fill with Arcane Blast while mana allows.",
            "Presence of Mind on Arcane Wrath, or keep it for an instant when moving.",
            "OOM: mana gem / potion / Evocation, then wand.",
            "AoE: precast Flamestrike (careful, big threat), then spam Arcane Explosion. Frost Nova to get space.",
        },
        skip = { ["Blizzard"] = true, ["Scorch"] = true, ["Pyroblast"] = true, ["Ice Lance"] = true, ["Ice Barrier"] = true, ["Blast Wave"] = true },
        skipNote = "Arcane rarely uses Blizzard or Scorch; Frostbolt/Fireball ranks matter only until level 20.",
    },

    frost = {
        name = "Frost",
        color = "ff3fc7eb",
        split = "12 / 0 / 39",
        blurb = "Slow start, strong late (Shatter + Fingers of Frost). Highest burst and best defensives; great vs elites.",
        talents = {
            "Improved Frostbolt", "Improved Frostbolt", "Improved Frostbolt", "Improved Frostbolt", "Improved Frostbolt", -- 10-14
            "Precision", "Precision", "Precision",                                                                         -- 15-17
            "Frostbite", "Frostbite",                                                                                      -- 18-19
            "Ice Lance",                                                                                                   -- 20
            "Ice Shards", "Ice Shards", "Ice Shards", "Ice Shards",                                                       -- 21-24
            "Ice Block",                                                                                                   -- 25
            "Shatter", "Shatter", "Shatter",                                                                              -- 26-28
            "Ice Shards",                                                                                                  -- 29
            "Fingers of Frost", "Fingers of Frost",                                                                       -- 30-31
            "Cold Snap",                                                                                                   -- 32
            "Improved Cone of Cold", "Improved Cone of Cold",                                                             -- 33-34
            "Winter's Chill", "Winter's Chill", "Winter's Chill", "Winter's Chill", "Winter's Chill",                     -- 35-39
            "Ice Barrier",                                                                                                 -- 40
            "Improved Cone of Cold",                                                                                       -- 41
            "Frostbite",                                                                                                   -- 42
            "Frost Channeling", "Frost Channeling", "Frost Channeling",                                                   -- 43-45
            "Improved Blizzard", "Improved Blizzard", "Improved Blizzard",                                                -- 46-48
            "Improved Channeling", "Improved Channeling", "Improved Channeling", "Improved Channeling", "Improved Channeling", -- 49-53
            "Missile Barrage",                                                                                             -- 54
            "Arcane Subtlety", "Arcane Subtlety",                                                                         -- 55-56
            "Arcane Concentration", "Arcane Concentration", "Arcane Concentration", "Arcane Concentration",              -- 57-60
        },
        notes = {
            { 10, "Improved Frostbolt first for faster casts." },
            { 20, "Ice Lance: burst on frozen targets (Frost Nova / Frostbite). Shares cooldown with Fire Blast." },
            { 26, "Shatter: crits on frozen targets. The spec comes online here." },
            { 30, "Fingers of Frost. Priority for procs: Ice Lance > Cone of Cold > Frostbolt." },
            { 35, "Winter's Chill stacks make Cone of Cold hit hard." },
            { 40, "Ice Barrier: keep it up, it also raises your damage." },
            { 46, "Improved Blizzard is a must if you run dungeons; you can take it earlier instead of Ice Shards/Frostbite." },
        },
        rotation = {
            "Keep Ice Barrier up (40+).",
            "Precast Frostbolt.",
            "Winter's Chill fully stacked or target nearly dead  ->  Cone of Cold.",
            "Fingers of Frost: at 2 stacks Frostbolt; at 1 stack Frostbolt into Ice Lance.",
            "Frostbite proc  ->  Frostbolt then Ice Lance so both Shatter.",
            "Missile Barrage proc (if talented)  ->  Arcane Missiles.",
            "Spam Frostbolt. Fire Blast while moving. Frost Nova to dodge pushback.",
            "AoE: Blizzard when safe, otherwise Cone of Cold + Arcane Explosion.",
        },
        skip = { ["Arcane Blast"] = true, ["Arcane Wrath"] = true, ["Pyroblast"] = true, ["Scorch"] = true, ["Blast Wave"] = true },
        skipNote = "Deep Frost doesn't need Arcane Blast or Scorch. Keep Fireball rank 1 for long-range pulls.",
    },

    fire = {
        name = "Fire",
        color = "ffff7c0a",
        split = "17 / 31 / 3",
        blurb = "Long range and good single target. Mana-hungry until talents kick in.",
        talents = {
            "Accelerant", "Accelerant", "Accelerant", "Accelerant", "Accelerant",                 -- 10-14 (guide text: Improved Fireball)
            "Ignite", "Ignite", "Ignite", "Ignite", "Ignite",                                      -- 15-19
            "Pyroblast",                                                                           -- 20
            "Burning Soul", "Burning Soul", "Burning Soul",                                       -- 21-23
            "Improved Fire Blast",                                                                 -- 24
            "Heating Up",                                                                          -- 25
            "Improved Fire Blast",                                                                 -- 26
            "Incineration", "Incineration", "Incineration",                                       -- 27-29
            "Blast Wave",                                                                          -- 30
            "Critical Mass", "Critical Mass", "Critical Mass",                                    -- 31-33
            "Incineration",                                                                        -- 34
            "Fire Power", "Fire Power", "Fire Power",                                             -- 35-37
            "Incineration",                                                                        -- 38
            "Master of Elements",                                                                  -- 39 (any Fire talent; Flame Throwing also fine)
            "Combustion",                                                                          -- 40
            "Precision", "Precision", "Precision",                                                 -- 41-43
            "Improved Channeling", "Improved Channeling", "Improved Channeling", "Improved Channeling", "Improved Channeling", -- 44-48
            "Missile Barrage", "Missile Barrage",                                                 -- 49-50
            "Arcane Subtlety", "Arcane Subtlety",                                                 -- 51-52
            "Arcane Concentration",                                                                -- 53
            "Arcane Blast",                                                                        -- 54
            "Arcane Concentration", "Arcane Concentration", "Arcane Concentration", "Arcane Concentration", -- 55-58
            "Arcane Meditation", "Arcane Meditation",                                             -- 59-60
        },
        notes = {
            { 10, "Faster Fireball casts first (the guide's list shows Accelerant here; its text says Improved Fireball)." },
            { 20, "Pyroblast: precast it on every pull." },
            { 21, "Burning Soul cuts spell pushback while leveling." },
            { 25, "Heating Up: Fire Blast on cooldown, Pyroblast at 3 stacks." },
            { 30, "Blast Wave: instant AoE, also great for kiting." },
            { 40, "Combustion: use on cooldown." },
            { 41, "Precision / Missile Barrage can be picked up earlier if you prefer." },
        },
        rotation = {
            "Precast Pyroblast out of combat.",
            "Scorch if the target lives long enough to stack Improved Scorch.",
            "Heating Up at 3 stacks  ->  Pyroblast.",
            "Fire Blast on cooldown to build Heating Up.",
            "Missile Barrage proc  ->  Arcane Missiles.",
            "Fireball as filler. OOM: gem / potion / Evocation, then wand.",
            "AoE: precast Flamestrike, Blast Wave, then spam Arcane Explosion.",
        },
        skip = { ["Blizzard"] = true, ["Ice Lance"] = true, ["Ice Barrier"] = true, ["Arcane Wrath"] = true },
        skipNote = "Fire doesn't need higher Frostbolt/Blizzard ranks; keep Frostbolt rank 1 for the slow.",
    },

    frostaoe = {
        name = "Frost AoE",
        color = "ff9ad6ff",
        split = "18 / 0 / 33",
        blurb = "AoE grinding: gather packs, Frost Nova, Blizzard, kite. Weak single target and very mana hungry.",
        talents = {
            "Precision", "Precision", "Precision",                                                -- 10-12
            "Frost Warding", "Frost Warding",                                                     -- 13-14
            "Improved Frost Nova", "Improved Frost Nova",                                         -- 15-16
            "Permafrost", "Permafrost", "Permafrost",                                             -- 17-19
            "Ice Lance",                                                                          -- 20
            "Improved Blizzard", "Improved Blizzard", "Improved Blizzard",                        -- 21-23
            "Frost Channeling",                                                                   -- 24
            "Ice Block",                                                                          -- 25
            "Arctic Reach", "Arctic Reach",                                                       -- 26-27
            "Shatter", "Shatter", "Shatter",                                                      -- 28-30
            "Fingers of Frost",                                                                   -- 31
            "Cold Snap",                                                                          -- 32
            "Improved Cone of Cold", "Improved Cone of Cold", "Improved Cone of Cold",            -- 33-35
            "Frost Channeling", "Frost Channeling",                                               -- 36-37
            "Ice Shards", "Ice Shards",                                                           -- 38-39
            "Ice Barrier",                                                                        -- 40
            "Arcane Resilience", "Arcane Resilience", "Arcane Resilience",                        -- 41-43 (any Arcane row 1)
            "Wand Specialization", "Wand Specialization",                                         -- 44-45
            "Arcane Concentration", "Arcane Concentration", "Arcane Concentration", "Arcane Concentration", "Arcane Concentration", -- 46-50
            "Arcane Subtlety", "Arcane Subtlety",                                                 -- 51-52
            "Arcane Impact", "Arcane Impact", "Arcane Impact",                                    -- 53-55
            "Arcane Meditation", "Arcane Meditation", "Arcane Meditation",                        -- 56-58
            "Ice Shards", "Ice Shards",                                                           -- 59-60 (or Magic Absorption)
        },
        notes = {
            { 10, "Precision + Frost Warding for hit and survivability." },
            { 15, "Improved Frost Nova (shorter CD) and Permafrost (stronger slows)." },
            { 21, "Improved Blizzard: the slow that makes AoE kiting work." },
            { 26, "Arctic Reach: longer Blizzard range for kiting." },
            { 41, "Arcane row 1 is your choice: Arcane Resilience, Wand Specialization or Improved Channeling." },
        },
        rotation = {
            "Keep Ice Barrier up (40+). Start with full mana and gems ready.",
            "Gather a pack (wand, rank 1 spells, Frost Blast, running through), then Frost Nova.",
            "Blink/run out to max Blizzard range and Blizzard.",
            "When they reach you: Cone of Cold, step back, Arcane Explosion until Nova is back.",
            "Packs at ~30-40%: Frost Nova -> Flamestrike -> Cone of Cold for Shatter crits, then Arcane Explosion.",
            "Clean up stragglers with Fingers of Frost + Ice Lance.",
        },
        skip = { ["Arcane Blast"] = true, ["Arcane Wrath"] = true, ["Pyroblast"] = true, ["Scorch"] = true, ["Fireball"] = true, ["Blast Wave"] = true },
        skipNote = "AoE Frost lives on Blizzard / Cone of Cold / Arcane Explosion / Frost Nova. Keep Fireball rank 1 to pull.",
    },
}

------------------------------------------------------------------------
-- Spells to learn. { level, spell, rank, onlyPath }
------------------------------------------------------------------------
D.Spells = {
    { 1, "Frost Armor" }, { 1, "Arcane Intellect" },
    { 4, "Frostbolt" }, { 4, "Conjure Water" },
    { 6, "Conjure Food" }, { 6, "Fireball", 2 }, { 6, "Fire Blast" },
    { 8, "Frostbolt", 2 }, { 8, "Arcane Missiles" }, { 8, "Polymorph" },
    { 10, "Frost Armor", 2 }, { 10, "Frost Nova" }, { 10, "Conjure Water", 2 },
    { 12, "Fireball", 3 }, { 12, "Slow Fall" }, { 12, "Dampen Magic" }, { 12, "Conjure Food", 2 },
    { 14, "Arcane Intellect", 2 }, { 14, "Arcane Explosion" }, { 14, "Fire Blast", 2 }, { 14, "Frostbolt", 3 },
    { 16, "Arcane Missiles", 2 }, { 16, "Flamestrike" },
    { 18, "Fireball", 4 }, { 18, "Amplify Magic" }, { 18, "Remove Lesser Curse" },
    { 20, "Conjure Water", 3 }, { 20, "Evocation" }, { 20, "Blink" }, { 20, "Polymorph", 2 }, { 20, "Fire Ward" },
    { 20, "Frostbolt", 4 }, { 20, "Frost Armor", 3 }, { 20, "Blizzard" }, { 20, "Mana Shield" },
    { 20, "Teleport (city)", nil, nil, "Stormwind/Ironforge or Orgrimmar/Undercity" },
    { 22, "Frost Ward" }, { 22, "Fire Blast", 3 }, { 22, "Scorch" }, { 22, "Arcane Explosion", 2 }, { 22, "Conjure Food", 3 },
    { 24, "Fireball", 5 }, { 24, "Flamestrike", 2 }, { 24, "Pyroblast", 2, "fire" }, { 24, "Dampen Magic", 2 },
    { 24, "Arcane Missiles", 3 }, { 24, "Counterspell" },
    { 26, "Frostbolt", 5 }, { 26, "Frost Nova", 2 }, { 26, "Cone of Cold" },
    { 28, "Blizzard", 2 }, { 28, "Ice Lance", 2, "frost" }, { 28, "Scorch", 2 }, { 28, "Arcane Intellect", 3 },
    { 28, "Conjure Mana Agate" }, { 28, "Mana Shield", 2 },
    { 30, "Ice Armor" }, { 30, "Fireball", 6 }, { 30, "Fire Ward", 2 }, { 30, "Fire Blast", 4 }, { 30, "Pyroblast", 3, "fire" },
    { 30, "Conjure Water", 4 }, { 30, "Arcane Explosion", 3 }, { 30, "Amplify Magic", 2 }, { 30, "Arcane Blast", 2, "arcane" },
    { 30, "Teleport (city)", nil, nil, "Darnassus or Thunder Bluff" },
    { 32, "Conjure Food", 4 }, { 32, "Arcane Missiles", 4 }, { 32, "Flamestrike", 3 }, { 32, "Frostbolt", 6 }, { 32, "Frost Ward", 2 },
    { 34, "Ice Lance", 3, "frost" }, { 34, "Cone of Cold", 2 }, { 34, "Scorch", 3 }, { 34, "Mage Armor" }, { 34, "Arcane Wrath", 2, "arcane" },
    { 36, "Blizzard", 3 }, { 36, "Fireball", 7 }, { 36, "Blast Wave", 2, "fire" }, { 36, "Pyroblast", 4, "fire" },
    { 36, "Dampen Magic", 3 }, { 36, "Mana Shield", 3 },
    { 38, "Frostbolt", 7 }, { 38, "Fire Blast", 5 }, { 38, "Arcane Explosion", 4 }, { 38, "Conjure Mana Jade" },
    { 40, "Ice Armor", 2 }, { 40, "Frost Nova", 3 }, { 40, "Fire Ward", 3 }, { 40, "Scorch", 4 }, { 40, "Frostfire Bolt" },
    { 40, "Flamestrike", 4 }, { 40, "Arcane Missiles", 5 }, { 40, "Conjure Water", 5 }, { 40, "Polymorph", 3 },
    { 40, "Arcane Blast", 3, "arcane" }, { 40, "Portals (city)", nil, nil, "Stormwind/Ironforge or Orgrimmar/Undercity" },
    { 42, "Ice Lance", 4, "frost" }, { 42, "Frost Ward", 3 }, { 42, "Cone of Cold", 3 }, { 42, "Fireball", 8 },
    { 42, "Pyroblast", 5, "fire" }, { 42, "Arcane Intellect", 4 }, { 42, "Conjure Food", 5 }, { 42, "Amplify Magic", 3 },
    { 44, "Blizzard", 4 }, { 44, "Frostbolt", 8 }, { 44, "Blast Wave", 3, "fire" }, { 44, "Mana Shield", 4 },
    { 46, "Ice Barrier", 2, "frost" }, { 46, "Fire Blast", 6 }, { 46, "Scorch", 5 }, { 46, "Arcane Explosion", 5 }, { 46, "Mage Armor", 2 },
    { 48, "Ice Lance", 5, "frost" }, { 48, "Fireball", 9 }, { 48, "Flamestrike", 5 }, { 48, "Pyroblast", 6, "fire" },
    { 48, "Arcane Missiles", 6 }, { 48, "Dampen Magic", 4 }, { 48, "Arcane Wrath", 3, "arcane" }, { 48, "Conjure Mana Citrine" },
    { 50, "Frostbolt", 9 }, { 50, "Ice Armor", 3 }, { 50, "Cone of Cold", 4 }, { 50, "Fire Ward", 4 }, { 50, "Frostfire Bolt", 2 },
    { 50, "Conjure Water", 6 }, { 50, "Arcane Blast", 4, "arcane" },
    { 50, "Portals (city)", nil, nil, "Darnassus or Thunder Bluff (+ Teleport: Dalaran for Alliance)" },
    { 52, "Blizzard", 5 }, { 52, "Frost Ward", 4 }, { 52, "Ice Barrier", 3, "frost" }, { 52, "Scorch", 6 },
    { 52, "Blast Wave", 4, "fire" }, { 52, "Conjure Food", 6 }, { 52, "Mana Shield", 5 },
    { 54, "Arcane Explosion", 6 }, { 54, "Amplify Magic", 4 }, { 54, "Fireball", 10 }, { 54, "Fire Blast", 7 },
    { 54, "Pyroblast", 7, "fire" }, { 54, "Frost Nova", 4 },
    { 56, "Ice Lance", 6, "frost" }, { 56, "Frostbolt", 10 }, { 56, "Flamestrike", 6 }, { 56, "Arcane Intellect", 5 },
    { 56, "Arcane Missiles", 8 }, { 56, "Arcane Brilliance" },
    { 58, "Cone of Cold", 5 }, { 58, "Ice Barrier", 4, "frost" }, { 58, "Scorch", 7 }, { 58, "Mage Armor", 3 }, { 58, "Conjure Mana Ruby" },
    { 60, "Blizzard", 6 }, { 60, "Frostbolt", 11 }, { 60, "Frost Ward", 5 }, { 60, "Ice Armor", 4 }, { 60, "Fireball", 11 },
    { 60, "Fire Ward", 5 }, { 60, "Blast Wave", 5, "fire" }, { 60, "Frostfire Bolt", 3 }, { 60, "Pyroblast", 8, "fire" },
    { 60, "Conjure Water", 7 }, { 60, "Conjure Food", 7 }, { 60, "Mana Shield", 6 }, { 60, "Arcane Blast", 5, "arcane" },
    { 60, "Arcane Wrath", 4, "arcane" },
}

------------------------------------------------------------------------
-- Level bracket tips: water, wand, quest rewards
------------------------------------------------------------------------
D.Brackets = {
    { min = 1, max = 9,
      water = "Ice Cold Milk (lvl 5-15) beats your conjured water.",
      wand = "Rush Lesser Magic Wand (lvl 5) - huge for its level.",
      extra = "Pick up First Aid right away and level it with you." },
    { min = 10, max = 19,
      water = "Melon Juice (lvl 15-25).",
      wand = "Greater Magic Wand (lvl 13) - check the Auction House.",
      extra = "Quest rewards: Staff of Westfall (Deadmines, A), Deepblaze (Halls of Thanes, A), Staff of Orgrimmar (RFC, H), Gnarled Necromancer's Staff (Ruins of Lordaeron, H). Class quest: Manaweave Robe (A) / Lesser Spellfire Robes (H)." },
    { min = 20, max = 29,
      water = "Sweet Nectar (lvl 25-35).",
      wand = "Gravestone Scepter (Blackfathom Deeps quest, both factions).",
      extra = "Set your Hearthstone in your questing zone - you have city teleports now. Class quest: Astral Knot (A) / Nether-lace (H). Counterspell at 24." },
    { min = 30, max = 39,
      water = "Moonberry Juice (lvl 35-45).",
      wand = "Twisted Nether Wand (Auction House). Class quest: Icefury / Nether Force / Ragefire Wand.",
      extra = "Frost Armor becomes Ice Armor. Gnomeregan / Razorfen Kraul / SM Library quests have good caster gear." },
    { min = 40, max = 49,
      water = "Morning Glory Dew (lvl 45-55).",
      wand = "Dreambough Wand or Lesser Eternal Wand (Auction House).",
      extra = "Portals at 40: sell portals in trade chat to fund training. Maraudon quests: Acumen Robes, Woodseed Hoop. Spellshifter Rod from Zul'Farrak." },
    { min = 50, max = 60,
      water = "Your conjured water is best from here.",
      wand = "Greater Eternal Wand (Auction House).",
      extra = "Sunken Temple / Blackrock Depths quests for caster gear. Class quest: Glacial Spike / Arcane Crystal Pendant / Fire Ruby." },
}

D.GeneralTips = {
    "Always be casting - an imperfect spell beats an empty global cooldown (mind your mana).",
    "Rank 1 Frost Nova roots just as long as max rank for a fraction of the mana. Rank 1 Frostbolt is a cheap slow.",
    "Rank 1 Fireball has extra range for pulling; rank 1 Fire Blast / Ice Lance tag mobs instantly.",
    "Solo: Frost/Ice Armor + Dampen Magic on yourself. Dungeons: Mage Armor for regen.",
    "Re-conjure water, food and mana gems and rebuff while you travel.",
    "Fire Ward / Frost Ward when you take that school of damage. Mana Shield only for melee/arrows, it is pricey.",
    "Don't buy ranks of spells your spec never casts - the Trainer tab marks them.",
    "Comprehend Scroll: search \"Scroll:\" on the AH. Skill breakpoints 1 / 15 / 50 / 175. Familiars give Intellect.",
    "XP food (+5%): Longjaw Mud Snapper, Smoked Sagefish, Twice-Spiced Raptor Slice.",
}

D.Professions = {
    "|cffffd100Tailoring|r - strong cloth gear while leveling, some of it best-in-slot at 60.",
    "|cffffd100Enchanting|r - pairs with Tailoring (disenchant what you make). Makes Lesser/Greater Magic Wand.",
    "|cffffd100Engineering|r - gadgets and bombs (SAF-T Nitro Boosts). Expensive without Mining. Gnomes get a bonus.",
    "|cffffd100First Aid|r (secondary) - mages have no self-heal. Level it from the start.",
    "Classic pick: Tailoring + Enchanting, plus First Aid / Cooking / Fishing.",
}

D.Stats = "Hit (to 17%) > Spell Power > Crit > Haste > Intellect > Spirit > Stamina. While leveling: Spell Power + Intellect, with Stamina on PvP/Hardcore."

D.Consumables = {
    "|cffffd100Spell power|r: Minor -> Lesser -> Arcane -> Greater Arcane Elixir (Elixir of Fire Power for Fire).",
    "|cffffd100Mana regen|r: Minor / Lesser / Greater Mageblood Elixir.",
    "|cffffd100Intellect|r: Elixir of Wisdom -> Lesser Intellect -> Greater Intellect -> Elixir of the Sages.",
    "|cffffd100Potions|r share a cooldown: Mana / Healing / Spellblasting potion of your level.",
    "|cffffd100Weapon oil|r: Minor -> Lesser -> Wizard Oil (stacks with Comprehend Scroll imbues).",
}

------------------------------------------------------------------------
-- Leveling zones. uiMapIDs are the Classic-era ones; Forever may add zones not listed here.
------------------------------------------------------------------------
D.Zones = {
    { 1429, "Elwynn Forest", 1, 10, "A" }, { 1426, "Dun Morogh", 1, 10, "A" }, { 1438, "Teldrassil", 1, 10, "A" },
    { 1411, "Durotar", 1, 10, "H" }, { 1412, "Mulgore", 1, 10, "H" }, { 1420, "Tirisfal Glades", 1, 10, "H" },
    { 1436, "Westfall", 10, 20, "A" }, { 1432, "Loch Modan", 10, 20, "A" }, { 1439, "Darkshore", 10, 20, "A" },
    { 1413, "The Barrens", 10, 25, "H" }, { 1421, "Silverpine Forest", 10, 20, "H" },
    { 1433, "Redridge Mountains", 15, 25, "A" }, { 1442, "Stonetalon Mountains", 15, 27, "B" },
    { 1440, "Ashenvale", 18, 30, "B" }, { 1431, "Duskwood", 18, 30, "A" }, { 1437, "Wetlands", 20, 30, "A" },
    { 1424, "Hillsbrad Foothills", 20, 30, "B" }, { 1441, "Thousand Needles", 25, 35, "B" },
    { 1416, "Alterac Mountains", 30, 40, "B" }, { 1417, "Arathi Highlands", 30, 40, "B" }, { 1443, "Desolace", 30, 40, "B" },
    { 1434, "Stranglethorn Vale", 30, 45, "B" }, { 1445, "Dustwallow Marsh", 35, 45, "B" }, { 1418, "Badlands", 35, 45, "B" },
    { 1435, "Swamp of Sorrows", 35, 45, "B" }, { 1444, "Feralas", 40, 50, "B" }, { 1425, "The Hinterlands", 40, 50, "B" },
    { 1446, "Tanaris", 40, 50, "B" }, { 1427, "Searing Gorge", 43, 50, "B" }, { 1447, "Azshara", 45, 55, "B" },
    { 1419, "Blasted Lands", 45, 55, "B" }, { 1449, "Un'Goro Crater", 48, 55, "B" }, { 1448, "Felwood", 48, 55, "B" },
    { 1428, "Burning Steppes", 50, 58, "B" }, { 1422, "Western Plaguelands", 51, 58, "B" },
    { 1423, "Eastern Plaguelands", 53, 60, "B" }, { 1452, "Winterspring", 53, 60, "B" }, { 1451, "Silithus", 55, 60, "B" },
}

------------------------------------------------------------------------
-- Map pins: { uiMapID, x, y, faction, kind, label }. Coordinates are approximate (0-100).
------------------------------------------------------------------------
D.Pins = {
    -- Stormwind
    { 1453, 38.6, 79.4, "A", "mage", "Mage trainers (Wizard's Sanctum)" },
    { 1453, 39.6, 79.6, "A", "portal", "Portal trainer" },
    { 1453, 53.0, 74.2, "A", "prof", "Enchanting trainer" },
    { 1453, 43.2, 73.6, "A", "prof", "Tailoring trainer" },
    { 1453, 42.8, 26.6, "A", "prof", "First Aid trainer" },
    -- Ironforge
    { 1455, 27.2, 8.4, "A", "mage", "Mage trainers (Mystic Ward)" },
    { 1455, 25.4, 7.2, "A", "portal", "Portal trainer" },
    { 1455, 60.6, 45.0, "A", "prof", "Enchanting trainer" },
    { 1455, 43.2, 29.0, "A", "prof", "Tailoring trainer" },
    { 1455, 55.2, 58.6, "A", "prof", "First Aid trainer" },
    -- Orgrimmar
    { 1454, 38.8, 85.6, "H", "mage", "Mage trainers (Darkbriar Lodge)" },
    { 1454, 38.6, 85.6, "H", "portal", "Portal trainer" },
    { 1454, 53.6, 38.2, "H", "prof", "Enchanting trainer" },
    { 1454, 63.0, 51.2, "H", "prof", "Tailoring trainer" },
    { 1454, 34.2, 84.6, "H", "prof", "First Aid trainer" },
    -- Undercity
    { 1458, 85.2, 10.0, "H", "mage", "Mage trainers (Magic Quarter)" },
    { 1458, 84.6, 11.2, "H", "portal", "Portal trainer" },
    { 1458, 62.0, 61.0, "H", "prof", "Enchanting trainer" },
    { 1458, 70.6, 58.6, "H", "prof", "Tailoring trainer" },
    { 1458, 73.4, 55.6, "H", "prof", "First Aid trainer" },
    -- Starting areas / early towns
    { 1429, 49.6, 39.6, "A", "mage", "Mage trainer (Northshire Abbey)" },
    { 1429, 43.2, 66.2, "A", "mage", "Mage trainer (Goldshire, top of the tower)" },
    { 1426, 28.8, 66.4, "A", "mage", "Mage trainer (Coldridge Valley)" },
    { 1426, 47.4, 52.4, "A", "mage", "Mage trainer (Kharanos inn)" },
    { 1420, 32.6, 65.6, "H", "mage", "Mage trainer (Deathknell)" },
    { 1420, 61.8, 52.0, "H", "mage", "Mage trainer (Brill)" },
    { 1411, 42.4, 68.8, "H", "mage", "Mage trainer (Valley of Trials)" },
    { 1411, 56.2, 75.0, "H", "mage", "Mage trainer (Sen'jin Village)" },
}

D.PinColors = {
    mage = { 0.41, 0.80, 0.94 },
    portal = { 0.70, 0.45, 1.00 },
    prof = { 1.00, 0.82, 0.00 },
    custom = { 0.40, 1.00, 0.40 },
}
