# Brotato_Gavin 项目进度

## Brotato Fidelity Track

Approved spec: `docs/superpowers/specs/2026-05-27-brotato-fidelity-core-design.md`.

Implementation plan: `docs/superpowers/plans/2026-05-27-brotato-fidelity-core.md`.

Phase 0 creates the standing fidelity audit and core rule reference under `docs/brotato-fidelity/`.

Phase 1 replaces the split XP/gold loop with a material-first loop, table-driven wave durations, post-wave upgrade choices, material bag handling, rule-driven shop generation, and explicit wave-end sequencing.

### Brotato Fidelity Phase 1 Core Loop
- [x] Material-first economy foundation
- [x] Brotato-like wave duration table
- [x] Material pickup grants XP and currency
- [x] Uncollected material bag approximation
- [x] Post-wave level-up choice queue
- [x] Rule-driven shop generation
- [x] Godot headless project-load verification
- [x] Godot headless Phase 1 rules smoke test
- [x] Godot headless Main scene smoke test
- [ ] Manual gameplay verification

Verification note: Godot headless project-load verification passed on 2026-05-27 with `G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64_console.exe --headless --path . --quit`. Phase 1 rules smoke test passed with `G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64_console.exe --headless --path . --script res://tests/phase1_rules_smoke.gd`, output `PHASE1_RULE_SMOKE_PASS`. Main scene smoke test passed with `G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64_console.exe --headless --path . --script res://tests/phase1_main_scene_smoke.gd`, output `PHASE1_MAIN_SCENE_SMOKE_PASS`; Godot dummy renderer still reports Canvas/TextServer RID cleanup warnings at exit.

Follow-up note on 2026-05-27: `G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64_console.exe` crashes with signal 11 under the current sandbox, but works when run outside the sandbox. Use escalated shell execution for required Godot headless checks in this worktree. Manual runtime validation in the Godot 4.6 editor is still required.

### Brotato Fidelity Phase 2A Loot And Weapon Combine
- [x] Loot rule layer for fruit/crate/legendary crate
- [x] Wave-end crate reward queue before upgrades and shop
- [x] Crate take/recycle flow
- [x] Tier 1-4 same-type same-tier weapon combining
- [x] Full-slot auto-combine weapon purchase rule
- [x] Godot headless Phase 2A smoke test outside sandbox
- [ ] Manual gameplay verification

Verification note: Phase 2A smoke test passed on 2026-05-27 with `G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64_console.exe --headless --path . --script res://tests/phase2_loot_weapon_smoke.gd`, output `PHASE2_LOOT_WEAPON_SMOKE_PASS`.

### Brotato Fidelity Phase D Content Data
- [x] Content-data design spec for Brotato-like non-art catalogs
- [x] Implementation plan for JSON catalog shell and validator
- [x] Data-backed seed character catalog: Well Rounded, Brawler, Crazy, Ranger, Mage
- [x] Phase D2 base character expansion: Chunky, Old, Mutant, Generalist, Loud, Multitasker
- [x] Data-backed seed weapon catalog with Gun-class tier rows
- [x] Data-backed seed item, upgrade, tag, and weapon-class catalogs
- [x] `BrotatoData` loader, validator, and runtime conversion helpers
- [x] Character select, weapon combat data, and shop weapon entries can consume `BrotatoData`
- [x] Godot headless catalog smoke test
- [x] Phase D1 shop weapon pool filters legacy `Unknown` placeholder rows
- [x] Phase D1 shop weapon pool uses catalog entries as canonical source, with legacy resource fallback only when catalog entries are unavailable
- [x] Phase D1 reference weapon expansion: Spear, Crossbow, Sword, Flamethrower, Rocket Launcher, Plasma Sledge, Grenade Launcher
- [x] Phase D1 Gun/Naval expansion: Blunderbuss, Harpoon Gun, and Naval class bonuses
- [x] Phase D1 Naval weapon set completion: Anchor, Captain's Sword, Trident
- [x] Phase D1 Heavy/Blunt expansion: Heavy and Blunt class bonuses, Cacti Club correction, Hammer, Mace
- [x] Phase D1 high-tier Heavy expansion: Nuclear Launcher, Particle Accelerator, War Hammer, Gatling Laser, plus Explosive/Elemental/Legendary class bonuses
- [x] Phase D1 Precise expansion: Precise class bonuses, Knife correction, Thief Dagger, Shuriken, Drill
- [x] Phase D1 Elemental expansion: Wand/Taser corrections, Icicle, Lightning Shiv, Plank, Torch, Fireball, Flaming Brass Knuckles, Thunder Sword
- [x] Phase D1 Medical expansion: Medical class bonuses, Scissors, Circular Saw
- [x] Phase D1 Support/Musical expansion: Support and Musical class bonuses, Hand correction, Hiking Pole, Lute, Pruner, Sickle, Potato Thrower
- [x] Phase D1 Primitive expansion: Primitive class bonuses, Stick correction, Hatchet, Javelin, Quarterstaff, Rock, Sharp Tooth, Slingshot
- [x] Phase D1 Unarmed expansion: Unarmed class bonuses, Fist correction, Claw, Power Fist
- [x] Phase D1 Tool/Engineering expansion: Tool class bonuses, Wrench correction, Screwdriver, Chainsaw
- [x] Phase D1 Ethereal expansion: Ethereal class bonuses, Ghost Axe, Ghost Flint, Ghost Scepter, Scythe
- [x] Phase D1 Blade expansion: Chopper, Vorpal Sword, Excalibur
- [x] Phase D1 Medieval expansion: Jousting Lance, Spiky Shield
- [x] Phase D1 Blunt expansion: Brick, Spoon
- [x] Phase D1 Legendary/Explosive expansion: DEX-troyer
- [x] Phase D1 high-tier Gun correction: Minigun, Obliterator, Sniper Gun, Chain Gun minimum tiers and special fields
- [x] Phase D1 weapon class map normalized: weapon groups match official Brotato weapon classes, and melee/ranged is carried by `attack_kind`
- [x] Phase D1 high-tier weapon runtime path: catalog shop entries preserve `minimum_tier`, and PlayerCombat equips exact catalog tier data
- [x] Phase D2 second base character expansion: Wildling, Gladiator, Sick, Farmer, Ghost, Speedy
- [x] Phase D2 third base character expansion: Lucky, Pacifist, Saver, Entrepreneur, Engineer, Explorer
- [x] Phase D2 fourth base character expansion: Doctor, Hunter, Artificer, Arms Dealer, Streamer, Cyborg
- [x] Phase D2 fifth base character expansion: Glutton, Jack, Lich, Apprentice, Cryptid, Fisherman
- [x] Phase D2 sixth base character expansion: Golem, King, Renegade, One Armed, Bull, Soldier
- [x] Phase D2 seventh base character expansion: Masochist, Knight, Demon, Baby, Vagabond, Technomage
- [x] Phase D2 final character expansion: Vampire, Sailor, Curious, Builder, Captain, Creature, Chef, Druid, Dwarf, Gangster, Diver, Hiker, Buccaneer, Ogre, Romantic
- [x] Phase D2 character starting item runtime path: catalog `starting_item` rules and fixed starting items convert into runtime catalog item upgrades, including Mage's Snake/Scared Sausage and Creature's cursed Fish Hook.
- [x] Phase D2 Creature character rule runtime path: catalog `weapon_special` rules apply on spawn, covering Curse weapon-damage scaling, +1 Curse on level up, and end-wave Range/XP Gain decay.
- [x] Phase D2 catalog character stat runtime path: catalog `stat_delta` rules now initialize runtime player stats directly, avoiding duplicate legacy bonuses and covering Ranger Range, Sailor Curse/Damage/Dodge cap, and other compatible base stat rows.
- [x] Phase D2 catalog character stat multiplier path: `stat_modifications_multiplier` now stores runtime stat-gain multipliers and applies them to later catalog `stat_delta` gains, covering Mage's Ranged Damage block, Elemental Damage bonus, and Engineering penalty.
- [x] Phase D2 catalog character level-up stat path: `gain_stats_on_level_up` now stores per-level stat deltas and applies them through `Player.on_level_up`, covering Apprentice's per-level damage gains and Max HP loss.
- [x] Phase D2 catalog character weapon-slot cap path: `max_1_weapon` now updates runtime max weapon slots and blocks second non-combine equips, covering One Armed.
- [x] Phase D2 character select UI catalog alignment: character select now exposes all 62 catalog characters through canonical catalog IDs, resolves legacy aliases such as `normal` to catalog rows, preserves catalog unlock conditions, and routes unlock notifications through visible catalog character IDs.
- [x] Full 62-character catalog
- [x] Full 78-weapon catalog and official weapon-class map
- [x] Phase D3 first foundational item batch: Acid, Alien Baby, Alien Magic, Alien Worm, Bag, Bat, Beanie, Big Arms, Broken Mouth, Cake, Coffee, Coupon, Fertilizer, Fin
- [x] Phase D3 second foundational item batch: Butterfly, Charcoal, Clover, Compass, Cyclops Worm, Defective Steroids, Diploma, Duct Tape, Dynamite, Energy Bracelet, Exoskeleton, Explosive Shells, Glasses, Goat Skull, Hedgehog, Helmet
- [x] Phase D3 third foundational item batch: Injection, Leather Vest, Lens, Little Muscley Dude, Lost Duck, Medal, Mushroom, Plant, Pencil, Propeller Hat, Scar, Scope, Shady Potion, Snail, Sunglasses, Toxic Sludge, Weird Food
- [x] Phase D3 fourth foundational item batch: Wheelbarrow, White Flag, Wings, Whetstone, Ritual, Sharp Bullet, Small Magazine, Tentacle, Toolbox, Triangle of Power, Ugly Tooth, plus Scared Sausage reference correction
- [x] Phase D3 fifth foundational item batch: Alloy, Bean Teacher, Black Belt, Blindfold, Blood Leech, Book, Bowler Hat, Boxing Glove, Cape, Claw Tree, Cog, Gentle Alien, Gnome, Lemonade, Lucky Charm, Mastery, Missile, Night Goggles, Octopus, Peaceful Bee, Plastic Explosive, Warrior Helmet
- [x] Phase D3 sixth foundational item batch: Banner, Boiling Water, Campfire, Candle, Clockwork Wasp, Fresh Meat, Fuel Tank, Gambling Token, Glass Cannon, Gummy Berserker, Head Injury, Heavy Bullets, Insanity, Jet Pack, Little Frog, Mammoth, Metal Plate, Mouse, Mutation, Panda, Poisonous Tonic, Reinforced Steel
- [x] Phase D3 seventh foundational item batch: Adrenaline, Alien Eyes, Baby Elephant, Baby Gecko, Baby with a Beard, Bandana, Barricade, Blood Donation, Crown, Cute Monkey, Hunting Trophy, Landmines, Metal Detector, Pumpkin, Recycling Machine, Sad Tomato, Shmoop, Statue, Tardigrade, Terrified Onion, Tractor, Wheat
- [x] Phase D3 eighth foundational item batch: Chameleon, Coil, Cyberball, Fruit Basket, Garden, Ghost Outfit, Medikit, Peacock, Padding, Power Generator, Regeneration Potion, Rip and Tear, Riposte, Silver Bullet, Snowball, Spider, Tree, Vigilante Ring, Wandering Bot, Weird Ghost, Wisdom, Wolf Helmet
- [x] Phase D3 ninth foundational item batch: Anvil, Ball and Chain, Bloody Hand, Broken Hourglass, Broken Mirror, Candy Bag, Community Support, Esty's Couch, Explosive Turret, Extra Stomach, Eyes Surgery, Fairy, Focus, Fried Rice, Frozen Heart, Giant Belt, Gobbler's Hat, Greek Fire, Grind's Magical Leaf, Handcuffs, Honey, Hourglass, Ice Cube, Improved Tools, Incendiary Turret, Laser Turret, Lucky Coin, Lure, Medical Turret, Nail, Pile of Books, Pocket Factory, Potato, Resting Goldfish, Retromation's Hoodie, Ricochet, Robot Arm, Shackles, Sifd's Relic, Stone Skin, Strange Book, Torture, Tyler, Will-o'-Wisp
- [x] Phase D3 DLC table completion batch: Ashes, Axolotl, Baby Squid, Black Flag, Bone Dice, Coral, Corrupted Shard, Crystal, Feather, Goblet, Goldfish, Jerky, Knot, Kraken's Eye, Lantern, Mirror, Penguin, Saltwater, Seashell, Small Fish, Sunken Bell, Whistle
- [x] Phase D4 catalog item runtime path: Shop item offers now come from `BrotatoData.get_shop_pool(false)` instead of the legacy custom passive pool, with 235 currently runtime-supported Brotato catalog items, generic `stat_delta` apply/remove support, economy modifiers for item price/reroll/recycling, Dangerous Bunny free shop rerolls, Treasure Map extra crate rewards, Corrupted Shard Curse stat, Whistle/Lure loot alien spawning and crate drops, Campfire/Candle nightmare fog visibility, Lantern periodic nearby knockback, Ice Cube elemental vulnerability, Greek Fire current-HP burn damage, Barnacle level-up stat scaling, Lighthouse structure Engineering penalty, Bait next-wave special enemy spawn, Hourglass wave-count rewind, Alien Eyes timed projectiles, Baby with a Beard corpse projectiles, Black Flag cursed-kill material rewards, Will-o'-Wisp burning-kill Elemental Damage growth, Kraken's Eye Curse-scaling hit explosions, Sunken Bell low-health wave explosions, Fairy item-tier HP Regeneration scaling, Candy Bag wave-start random primary stat and additional elite chance, Fish Hook locked-shop cursed offer state, Mirror next-shop-item duplication, Broken Mirror/Resting Goldfish post-use state tracking, enemy/material modifiers for enemy health, damage, speed, count, material drops, explosive damage/size modifiers for splash projectiles, Small Fish high-health target damage, Ball and Chain weapon cooldown floor, Eyepatch critical-hit projectile pierce, Coil knockback-scaling damage, Power Generator speed-scaling damage, Retromation's Hoodie dodge-scaling attack speed, Stone Skin armor-scaling Max HP, Strange Book elemental-scaling Engineering, Clockwork Wasp/Improved Tools structure attack speed scaling, Barricade/Statue/Chameleon/Coral stand-still stat bonuses, Eyes Surgery/Frozen Heart burn activation speed, Frozen Heart elemental weapon damage scaling, Nail engineering weapon damage scaling, Crystal timed Attack Speed growth, Community Support living-enemy Attack Speed scaling, Fried Rice burning-enemy HP Regeneration scaling, Pearl Luck-scaling Damage and extra Pearl crate rewards, Torture fixed healing and healing lockout, Jerky delayed consumable healing, Knot weapon upgrade/recycle lock, Goldfish next-reroll tier bonus, Bone Dice shop-reroll Damage/Max HP mutation, Axolotl one-shot primary-stat swap, Anvil shop-entry weapon upgrade/Armor fallback, Fruit Basket enemy fruit-drop bonus, Garden fruit-spawning structures, Turret wave-start structures, Explosive/Incendiary/Laser/Medical Turret wave-start structure variants, Pile of Books structure critical hits, Pocket Factory tree-kill turret spawning, Tyler summoned damage structures, Wandering Bot nearby enemy slow structures, Builder's Turret unique weapon-derived structures, Landmines periodic explosive structures, Spicy Sauce consumable pickup explosions, Tree neutral-unit spawning, Lumberjack Shirt one-hit trees, Vigilante Ring/Grind's Magical Leaf/Robot Arm/Ashes end-wave stat changes, Crown end-wave Harvesting growth, Celery Tea end-wave XP Gain growth, Baby Squid/Decomposing Flesh level-up stat changes, Silver Bullet boss/elite damage, Giant Belt current-HP critical damage, Lucky Coin crit-scaling Luck, Snowball elemental-item pickup bonus, Wisdom in-wave timed damage growth, Medikit in-wave timed HP regeneration growth, Regeneration Potion low-health HP regeneration doubling, Cauldron timed post-consumable Damage boost, Saltwater timed damage-taken Speed boost, Blood Donation/Bloody Hand self-damage over time, Bloody Hand lifesteal-scaling Damage, Extra Stomach full-health fruit Max HP gains, Penguin full-health fruit temporary HP regeneration, Weird Ghost/Broken Hourglass next-wave 1 HP starts, Peacock/Celery Tea next-wave XP/enemy modifiers, Scarf next-wave enemy speed, Handcuffs Max HP cap, Shackles Speed cap, Piggy Bank start-wave material growth through wave 20, Jelly distinct-weapon Max HP, Spider/Focus distinct-weapon Attack Speed scaling, Esty's Couch negative-Speed HP Regeneration scaling, Padding current-material Max HP scaling, Triangle of Power per-hit wave damage loss, Bag's crate material bonus, projectile pierce modifiers for Sharp Bullet/Bandana, Pumpkin's piercing damage cap, Ricochet projectile bounce, Seashell fifth-ranged-shot projectile bursts, critical-kill specials for Tentacle/Hunting Trophy, material-pickup specials for Baby Elephant/Cute Monkey/Metal Detector, Cyberball enemy-death Luck damage, Goblet enemy-kill healing, Rip and Tear enemy-death explosion, Riposte dodge damage, Ghost Outfit dodge cap, Scared Sausage burn-on-hit, Snake burn spread, Baby Gecko/Sifd's Relic instant material-drop attraction, Ugly Tooth hit-slow stacking, Adrenaline dodge-heal, Tardigrade per-wave hit nullification, and Sad Tomato wave-start HP modification
- [ ] Unsupported weapon special-rule runtime coverage audit
- [ ] Full 237-item catalog and item effect migration

Spec: `docs/superpowers/specs/2026-05-27-brotato-content-data-design.md`.

D0/D1/D2/D3/D4 seed implementation note: `BROTATO_DATA_CATALOG_SMOKE_PASS` verifies the catalog shape, the full 62-character catalog, Gun-class weapon rows, weapon tier conversion, the first 235 item rows, and Main scene boot compatibility. `PHASE_D1_WEAPON_CATALOG_SMOKE_PASS` verifies current catalog starting weapons resolve through `BrotatoData`, the merged shop weapon pool no longer exposes the legacy `Unknown` placeholder, catalog-backed shops do not mix in legacy-only weapons, the full 78-weapon manifest count is present, weapon groups match the official Brotato weapon-class map, high-tier shop entries preserve `minimum_tier`, and runtime aliases resolve to canonical rows. `PHASE2_LOOT_WEAPON_SMOKE_PASS` now also verifies a Tier 4 Chain Gun can be equipped from exact catalog tier data instead of legacy multipliers. `PHASE_D2_CHARACTER_RUNTIME_SMOKE_PASS` verifies character select exposes all 62 catalog characters with canonical IDs and catalog unlock conditions, verifies catalog-aware display-name lookup for UI notifications, verifies legacy aliases resolve to canonical catalog rows, verifies catalog character fixed starting items are converted into runtime item upgrades, including Mage's Snake/Scared Sausage and Creature's cursed Fish Hook's Curse surcharge, verifies Creature's catalog special rules for Curse weapon-damage scaling, level-up Curse growth, and end-wave Range/XP Gain decay, and verifies catalog character stat deltas initialize runtime stats without legacy duplicate bonuses for Ranger and Sailor, plus Mage stat modification multipliers on later catalog stat gains, Apprentice level-up stat deltas, and One Armed weapon-slot caps. `PHASE_D4_CATALOG_ITEM_RUNTIME_SMOKE_PASS` verifies the shop item pool uses Brotato catalog items instead of the removed custom passive pool, that catalog `stat_delta` effects apply/remove on the player, that Coupon/Spyglass/Recycling Machine affect economy values, that Dangerous Bunny consumes one free reroll through the real shop reroll path without spending materials, that Treasure Map can enqueue an extra crate reward through the real crate reward queue, that Whistle/Lure drive loot alien chance, speed, next-wave spawns, and crate drops, that Campfire/Candle stack nightmare fog visibility while applying their base stat deltas, that Lantern periodically knocks nearby enemies away while applying its stat and fog effects, that Ice Cube applies timed elemental-hit vulnerability and Greek Fire adds current-HP bonus damage to burn ticks, that Barnacle amplifies level-up stat choices and grants Curse on level up, that Lighthouse dynamically subtracts Engineering per owned structure, that Bait queues a next-wave elite special enemy, that Hourglass decreases the current wave count while preserving its next-wave 1 HP start, that Alien Eyes fires six Max-HP-scaling projectiles every 3 seconds, that Baby with a Beard fires a Ranged Damage-scaling corpse projectile, that Black Flag grants material on cursed enemy kills, that Will-o'-Wisp grants up to +4 Elemental Damage per wave from burning enemy kills, that Kraken's Eye triggers Curse-scaling hit explosions, that Sunken Bell explodes once per wave below 40% HP with combat-stat scaling, that Fairy dynamically recalculates HP Regeneration from distinct owned tier 1 and tier 4 items, that Candy Bag rolls a temporary +8 primary stat each wave and adds a 10% additional elite chance, that Fish Hook marks locked shop entries as cursed on successful lock-to-curse rolls, that Mirror duplicates the next eligible shop item without exceeding catalog limits, that Broken Mirror and Resting Goldfish expose post-use state counters, that Alien Baby/Snail/Gentle Alien/Gobbler's Hat/Starfish affect enemy and material-drop runtime scaling, that Dynamite/Explosive Shells/Plastic Explosive/Honey apply explosion damage/size modifiers through the fired splash projectile path, that Small Fish applies high-health target damage through the shared hit damage modifier path, that Ball and Chain applies a 0.75s weapon cooldown floor through `PlayerCombat.process_weapons`, that Eyepatch adds +1 piercing to critical projectiles, that Coil dynamically recalculates Damage from current Knockback as knockback stats are added or removed, that Power Generator recalculates Damage from current positive Speed percent, that Retromation's Hoodie recalculates Attack Speed from current Dodge percent, that Stone Skin recalculates Max HP from current Armor, that Strange Book recalculates Engineering from current Elemental Damage, that Clockwork Wasp and Improved Tools shorten structure attack intervals through `TurretManager`, that Barricade/Statue/Chameleon/Coral toggle stand-still stat bonuses from the player movement state, that Eyes Surgery/Frozen Heart alter burn tick intervals, that Frozen Heart adds weapon damage from current Elemental Damage, that Nail adds weapon damage from current Engineering, that Crystal gains Attack Speed every second during a wave and loses the timed bonus on damage, wave start, or removal, that Community Support recalculates Attack Speed from current living enemy count, that Fried Rice recalculates HP Regeneration from current burning enemy count, that Pearl recalculates Damage from current Luck and can append Pearl as an extra crate reward, that Torture restores 5 HP per second while blocking non-Torture healing, that Jerky queues consumable healing over 4 seconds instead of applying it instantly, that Knot blocks weapon auto-combine and explicit combine/upgrade actions while active, that Goldfish consumes a pending bonus on the next shop reroll to raise newly rolled item and weapon tiers while preserving locked offers, that Bone Dice can mutate Damage and Max HP through the real shop reroll path, that Axolotl swaps the highest and lowest positive primary stats once on pickup without reverting on removal, that Anvil upgrades an eligible weapon or grants +2 Armor through the real shop-entry path, that Fruit Basket raises enemy fruit drop chance through `LootRules`, that Garden spawns fruit-producing structures through `TurretManager`, that Turret and Landmines spawn engineering-scaling structures through `WaveManager` and `TurretManager`, that Corrupted Shard applies Curse through the player stat path, that Builder's Turret copies the current best ranged weapon profile into a unique Engineering-scaling structure, that Explosive/Incendiary/Laser/Medical Turret variants spawn and scale through the same structure runtime, that Pile of Books lets structures crit through `TurretManager`, that Pocket Factory spawns a turret when trees die, that Tyler spawns an Engineering/Elemental-scaling structure, that Wandering Bot slows nearby enemies through `TurretManager`, that Spicy Sauce triggers Max-HP scaling consumable pickup explosions, that Tree and Lumberjack Shirt add a neutral tree spawn/drops path with one-hit tree support, that Vigilante Ring, Grind's Magical Leaf, Robot Arm, and Ashes apply permanent stat changes through `Player.on_wave_end` and the real `Main._on_wave_ended` path, that Crown grows Harvesting by +8% at wave end, that Celery Tea adds +5% XP Gain at wave end, that Baby Squid and Decomposing Flesh apply permanent stat changes through the real `PlayerCore.gain_xp` level-up path, that Snowball grants persistent Elemental Damage when later Elemental Damage items are picked, that Cauldron applies a timed post-consumable Damage boost, that Saltwater applies a timed temporary Speed boost on damage taken without changing permanent base Speed, that Blood Donation and Bloody Hand deal self-damage over time without consuming invulnerability, that Bloody Hand recalculates Damage from current Lifesteal, that Peacock and Celery Tea apply next-wave XP/enemy modifiers through `Player.on_wave_start` and clear them through `Player.on_wave_end`, that Scarf applies and clears its next-wave enemy Speed modifier through the same path, that Silver Bullet applies extra hit damage only against boss/elite targets, that Giant Belt adds current-HP bonus damage only on critical hits with the boss/elite reduced coefficient, that Lucky Coin dynamically recalculates Luck from current Crit Chance and catalog crit changes, that Wisdom gains +5% damage every 5 seconds during a wave and resets the timed bonus on wave start or removal, that Medikit gains +2 HP Regeneration every 5 seconds during a wave and resets the timed bonus on wave start or removal, that Regeneration Potion doubles HP regeneration below 50% HP through the wave regeneration path, that Extra Stomach grants +1 Max HP on full-health fruit pickups, does not count crates, caps at +8 per wave, and resets its counter on wave start, that Penguin grants temporary HP Regeneration on full-health fruit pickups, ignores crates, resets the temporary bonus at wave start, and removes it with the item, that Weird Ghost and Broken Hourglass apply one-shot next-wave 1 HP starts through `Player.on_wave_start`, that Handcuffs caps future Max HP gains at its pickup value while preserving non-Max HP stat changes, that Shackles caps future Speed gains at its pickup value while preserving non-Speed stat changes, that Piggy Bank adds +20% held materials on wave start through wave 20, that Jelly recalculates Max HP from current distinct weapon types, that Spider and Focus recalculate Attack Speed from current distinct weapon types with positive and negative coefficients, that Esty's Couch recalculates HP Regeneration from current negative permanent Speed percent, that Padding dynamically adds +1 Max HP per 80 held materials through `RunEconomy.materials_changed` and removes the dynamic bonus when materials are spent or the item is removed, that Triangle of Power loses 2% Damage per taken hit until wave start and restores the temporary loss on item removal, that Bag grants +15 materials on crate pickup while preserving crate reward enqueue, that Sharp Bullet/Bandana stack projectile pierce bonuses into fired bullets with Sharp Bullet's piercing damage penalty, that Pumpkin caps pierced-target damage at base damage, that Ricochet adds projectile bounce redirects, that Seashell adds +3 projectiles on every fifth ranged shot, that Tentacle/Hunting Trophy apply critical-kill specials through bullet kill context, that Baby Elephant/Cute Monkey/Metal Detector alter real material pickup resolution through `XPOrb`, that Cyberball deals Luck-scaling damage through `Main._on_enemy_died` / `Player.on_enemy_died`, that Goblet heals through the same enemy-death event path, that Rip and Tear deals melee-scaling explosion damage through the enemy-death event path, that Riposte deals melee-scaling damage through the player dodge path, that Ghost Outfit lowers the dodge cap and clamps later dodge gains, that Scared Sausage applies burn through the attack hit path, that Snake spreads burn to a nearby enemy, that Baby Gecko/Sifd's Relic instantly attract dropped material through the same `XPOrb.collect` path, that Ugly Tooth stacks hit-based enemy slow through combat hit context, that Adrenaline heals on successful dodge through the player damage path, that Tardigrade nullifies one incoming hit per wave through the player damage path, and that Sad Tomato applies its wave-start HP modifier through `Player.on_wave_start`. Main scene boot now binds the local `Player` child before falling back to a global player lookup, avoiding stale player-group contamination in embedded/test scenes. The latest D1 batches now cover all current reference weapons from the Brotato Wiki weapon template, with melee/ranged represented by `attack_kind` instead of a pseudo class group. D2 now covers all 62 Brotato reference characters with starting weapon options, unlock metadata, wanted tags, fixed/core item placeholders, and pending unique-rule records. D3 now covers all currently rendered rows from the Brotato Wiki Items table plus internal character-linked/state rows; D4 starts runtime migration with the 235 currently supported catalog items. Remaining item work is reconciling the 237 count contract and tightening official edge-case semantics for cursed and post-use item states.

## 当前状态

本地 Git 仓库，4 次提交，无远程仓库。

```
1d81726 Performance: object pools, AI frame splitting, DetectArea cache...
2d13716 Deep refactor: split Player/Main/HUD into 12 modules
b8a66e8 Add project documentation — CLAUDE.md + architecture.md
ec3a58b Initial commit — Brotato_Gavin v0.1
```

## 已完成功能（v0.1）

### 核心玩法
- 20 波战斗 + Boss 波（5/10/15/20）+ 无尽模式
- 波次修饰词系统（9 种随机修饰词）
- 特殊事件系统（治愈之泉、宝箱、伏击、祝福、诅咒）
- 动态难度调整（根据玩家表现自动缩放）

### 角色系统
- 14 个可玩角色，各有独特被动
- 3 个难度（简单/普通/困难）
- 角色解锁条件系统

### 战斗系统
- 16 种武器（5 级升级）
- 14 种敌人类型 + Boss/Miniboss/精英
- Boss 3 阶段系统（正常→强化→狂暴）
- 元素弹药（火焰/冰霜/雷电）
- 战利品拾取物（速度/伤害/急速射击/护盾/吸血）

### 成长系统
- 40+ 被动升级道具（4 级稀有度）
- 7 个协同效果
- 10 个成就 + 角色解锁
- 商店（刷新/锁定/出售/武器升级）
- 材料利息系统

### 技术系统
- 对象池（子弹/敌人子弹/XP球/敌人/拾取物/伤害数字/特效）
- 程序化音效（BGM + SFX，无外部音频）
- 程序化视觉（几何图形，无美术资源）
- 存档系统（JSON）
- 小地图 + 连击系统 + Boss 血条

## 技术优化（2026-04-24）

### 阶段 1：基础设施
- [x] Git 仓库初始化 + 首次提交
- [x] 项目文档（CLAUDE.md + architecture.md）

### 阶段 2：代码重构
- [x] Player.gd（935→188行）拆分为 5 个模块
  - PlayerCore：移动、HP、无敌帧
  - PlayerCombat：武器、射击、暴击
  - PlayerUpgrades：升级、协同效果
  - PlayerBuffs：临时增益、击杀回调
  - PlayerStats：统计数据、难度采样
- [x] Main.gd（1153→493行）拆分为 4 个模块
  - WaveManager：波次状态机、敌人生成
  - PickupManager：战利品拾取物
  - TurretManager：炮塔 + 亡灵
  - EventManager：特殊事件
- [x] HUD.gd（1210→683行）拆分为 3 个模块
  - HUDCore：基础显示
  - HUDCombat：连击、Boss血条、小地图
  - HUDPanels：暂停菜单、结算、通知

### 阶段 3：性能优化
- [x] 敌人对象池（初始30，自动扩容）
- [x] 拾取物对象池（初始20）
- [x] 伤害数字/特效对象池
- [x] DetectArea 缓存（每0.1秒刷新）
- [x] 敌人 AI 分帧（每帧更新1/3，Boss除外）
- [x] 协同效果增量检查
- [x] 敌人 modulate 缓存
- [x] damage_events 定期清理

## 待办事项

### 高优先级
- [ ] 在 Godot 编辑器中测试重构后功能完整性
- [ ] 创建远程仓库并推送（需用户手动操作）
- [ ] 美术升级：精灵图/动画替换几何图形

### 中优先级
- [ ] HUD 信号驱动更新优化
- [ ] 新角色/新敌人/新武器
- [ ] 难度曲线调优

### 低优先级
- [ ] 音效升级（外部音频资源）
- [ ] 手柄支持
- [ ] 成就系统扩展

## 文件结构

```
Godot/brotato-gavin/
├── project.godot
├── CLAUDE.md
├── .gitignore
├── data/
│   └── weapons.tres
├── scenes/
│   ├── MainMenu.tscn
│   ├── CharacterSelect.tscn
│   ├── Main.tscn
│   ├── Player.tscn
│   ├── Enemy.tscn
│   ├── Bullet.tscn
│   ├── EnemyBullet.tscn
│   ├── XPOrb.tscn
│   ├── HUD.tscn
│   └── Shop.tscn
├── scripts/
│   ├── [autoload] GameState.gd
│   ├── [autoload] Effects.gd
│   ├── [autoload] SaveSystem.gd
│   ├── [autoload] AudioManager.gd
│   ├── Main.gd (协调者)
│   ├── WaveManager.gd
│   ├── PickupManager.gd
│   ├── TurretManager.gd
│   ├── EventManager.gd
│   ├── Player.gd (协调者)
│   ├── PlayerCore.gd
│   ├── PlayerCombat.gd
│   ├── PlayerUpgrades.gd
│   ├── PlayerBuffs.gd
│   ├── PlayerStats.gd
│   ├── Enemy.gd
│   ├── HUD.gd (协调者)
│   ├── HUDCore.gd
│   ├── HUDCombat.gd
│   ├── HUDPanels.gd
│   ├── Shop.gd
│   ├── Bullet.gd
│   ├── EnemyBullet.gd
│   ├── XPOrb.gd
│   ├── WeaponData.gd
│   ├── WeaponDatabase.gd
│   ├── CharacterSelect.gd
│   ├── MainMenu.gd
│   └── GenerateWeaponDB.gd
└── docs/
    ├── architecture.md
    ├── PROGRESS.md
    └── superpowers/specs/
        └── 2026-04-24-technical-optimization-design.md
```
