# Weapon Special Rules Audit Report

## Summary

- **Total weapons in weapons.json**: 55
- **Weapons with special_rules**: 35
- **Unique rule types**: 52
- **Runtime coverage**: 0 rules fully implemented

## Root Cause

The data pipeline gap is in `BrotatoData.weapon_tier_to_combat_entry()` which only reads structural fields and ignores `special_rules` and tier-level special fields (burn_damage, explosion_chance, crit_bounces, etc.). PlayerCombat.fire_weapon() has no dispatch logic for weapon-specific rules.

## Partially Covered (7 rules)

Generic systems exist but weapon-specific behavior is missing:

| Rule | Weapons | Gap |
|------|---------|-----|
| `pierce_falloff` | DB Shotgun, Laser Gun, Pistol, Blunderbuss, Harpoon Gun, Gatling Laser, Icicle, Javelin (8) | Bullet.gd supports pierce structurally, but per-weapon damage falloff multiplier never applied |
| `burn` | Torch, Wand, Fireball, Flaming Brass Knuckles, Particle Accelerator (5) | Enemy.gd has `apply_burn()` but weapon-specific burn_damage/burn_instances never passed through |
| `projectile_explosion_on_hit` | Nuclear Launcher, Fireball, Rocket Launcher, DEX-troyer, Grenade Launcher (5) | splash/splash_radius exists generically but not triggered by special_rule |
| `slow` | Taser (1) | Enemy.gd has `apply_slow()` but Taser never triggers it |
| `bounce_by_tier` | Slingshot (1) | bounce_remaining exists in Bullet.gd but only from item stats |
| `melee_hit_explosion_chance` | Plank, Power Fist (2) | explosion chance from tiers data never evaluated |
| `hit_explosion_chance_by_tier` | Plasma Sledge (1) | same gap |

## Not Covered (45+ rules)

No runtime logic at all, including:
- `damage_charges_until_hit` (Railgun)
- `sixth_shot_longer_cooldown` (Revolver)
- `material_pickup_resets_cooldown` (Blunderbuss)
- `negative_knockback_pull` (Harpoon Gun)
- `alternate_thrust_and_sweep` (Captain's Sword, Quarterstaff, Chopper, Vorpal Sword, Excalibur, Jousting Lance)
- `bonus_damage_per_free_weapon_slot` (Trident)
- `full_pierce` (Particle Accelerator, Sniper Gun)
- `spawn_projectiles_on_hit` (Chain Gun)
- `material_on_critical_kill` (Drill, Thief Dagger)
- `charm_low_health_enemy_on_hit` (Flute)
- `spawn_landmine_by_tier` (Wrench)
- `spawn_structure_by_tier` (War Hammer)
- `self_damage_over_time` (Scythe)
- `instant_kill_chance_by_tier` (Vorpal Sword)
- And 31 others

## Recommended Fix Path

1. **Phase 1**: Modify `weapon_tier_to_combat_entry()` to pass `special_rules` and tier-level fields into the combat entry
2. **Phase 2**: Add `_apply_weapon_special_rules()` dispatch in PlayerCombat.gd
3. **Phase 3**: Implement rule handlers prioritizing burn, pierce_falloff, explosion_on_hit first

---

*Audit date: 2026-05-29*
*Auditor: game-designer (策划部)*
