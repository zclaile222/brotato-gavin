# Weapon Special Rules Runtime Coverage Audit

> ## ⚠️ 现状已更新，本文件下方的审计结论已过时（保留作规则清单使用）
>
> 审计日期为 **2026-05-29**，当时 `PlayerCombat.gd` 确实尚未分发任何规则。
> **2026-09-15 实测覆盖率**：`weapons.json` 共 65 条唯一 `special_rules`，
> **已接线 55 条（85%）**，未接线 10 条（均因目录缺取值或需新建子系统而暂缓，
> 逐条理由见 `BROTATO_REMAKE_STATUS_AND_PLAN.md` §7.7 / §7.9）。
>
> 统计口径（可随时复算）：规则 id 是否出现在 `scripts/*.gd` 的字符串字面量中。
> 最新进展与分批计划见 `BROTATO_REMAKE_STATUS_AND_PLAN.md` 的 §七 P1 与 §7.2。
>
> 下方「Unimplemented Rules」清单仍可用作规则全量索引，但**不要**再据此判定某条规则未实现。
>
> 另注：剩余 31 条**每条都只涉及 1 把武器**，因此下文按「命中武器数」排的优先级已失效。

## Summary

**PlayerCombat.gd** contains **zero** references to `special_rule` or `special_rules`. None of the 65 unique special rules defined in `weapons.json` are dispatched or processed at runtime.

The `fire_weapon` function handles generic weapon stats only:
- Melee vs ranged branching
- Pierce (via `weapon.data.get("pierce", false)`)
- Splash/explosion (via `weapon.data.get("splash", false)`)
- Crit
- Lifesteal
- Returns, gravity, bullet_scale (passed to bullet)

None of these are driven by `special_rules` data — they are plain weapon stat fields.

---

## Unimplemented Rules (65 unique)

### A. `_damage_for_weapon` — Damage modifier rules:
1. `bonus_damage_per_free_weapon_slot` (Trident)
2. `bonus_damage_above_health_threshold` (Minigun)
3. `bonus_damage_against_low_health` (Sickle)
4. `bonus_damage_for_duplicate_sticks` (Stick)
5. `current_health_bonus_damage` (Chainsaw)
6. `damage_growth_per_kills_this_wave` (Ghost Axe)
7. `damage_growth_when_damaged_this_wave` (Scythe)
8. `burning_damage_by_tier` (Flamethrower)
9. `attack_speed_penalty` (War Hammer)

### B. `_cooldown_for_weapon` — Cooldown modifier rules:
10. `sixth_shot_longer_cooldown` (Revolver)
11. `cooldown_every_100_shots` (Gatling Laser)
12. `material_pickup_resets_cooldown` (Blunderbuss)
13. `reload_every_n_attacks_by_tier` (Chainsaw)
14. `reload_every_n_shots_by_tier` (Grenade Launcher)

### C. Melee on-hit rules (38 total):
15. `alternate_thrust_and_sweep` (Captain's Sword, Quarterstaff, Chopper, Vorpal Sword, Excalibur, Jousting Lance)
16. `melee_hit_explosion_chance` (Plank, Power Fist)
17. `harvesting_by_tier` (Hand)
18. `range_gain_per_steps_during_wave` (Hiking Pole)
19. `charm_low_health_enemy_on_hit` (Flute)
20. `damage_taken_debuff_on_hit` (Lute)
21. `spawn_fruit_garden` (Pruner)
22. `break_and_drop_materials_on_hit` (Brick)
23. `armor_and_hp_bonus_by_tier` (Rock)
24. `lifesteal_per_missing_health` (Sharp Tooth)
25. `flat_knockback_bonus` (Hammer)
26. `reset_offensive_turret_cooldowns_on_attack` (Screwdriver)
27. `spawn_landmine_by_tier` (Wrench)
28. `spawn_structure_by_tier` (War Hammer)
29. `crit_pierce_by_tier` (Crossbow)
30. `consumable_heal_bonus_by_tier` (Chopper)
31. `instant_kill_chance_by_tier` (Vorpal Sword)
32. `armor_penalty_per_weapon` (Excalibur)
33. `speed_bonus_by_tier` (Jousting Lance)
34. `damage_penalty_while_standing_still` (Jousting Lance)
35. `always_crit_burning_targets` (Spoon)
36. `burn` (Torch, Wand, Fireball, Flaming Brass Knuckles, Flamethrower, Rocket Launcher, Plasma Sledge)
37. `slow` (Taser)
38. `burn_spread_by_tier` (Torch)

### D. Ranged projectile/on-hit rules (24 total):
39. `pierce_falloff` (Double Barrel Shotgun, Laser Gun, Pistol, Blunderbuss, Harpoon Gun, Sniper Gun, Drill, Shuriken, Javelin)
40. `damage_charges_until_hit` (Railgun)
41. `projectile_explosion_chance` (Shredder)
42. `projectile_explosion_on_hit` (Obliterator, Rocket Launcher, Plasma Sledge, DEX-troyer, Grenade Launcher)
43. `full_pierce` (Particle Accelerator, Sniper Gun)
44. `engineering_based_slow` (Sniper Gun)
45. `cannot_bounce` (Sniper Gun)
46. `spawn_projectiles_on_hit` (Chain Gun)
47. `material_on_critical_kill` (Drill, Thief Dagger)
48. `attack_speed_growth_over_wave` (Drill)
49. `critical_hit_bounce` (Thief Dagger)
50. `spawn_lightning_projectile_on_hit` (Lightning Shiv)
51. `spawn_lightning_projectiles_on_hit` (Thunder Sword)
52. `negative_knockback_pull` (Harpoon Gun)
53. `projectile_slow_aura` (Harpoon Gun)
54. `pull_distance_damage_reduction` (Harpoon Gun)
55. `every_nth_projectile_guaranteed_crit` (Javelin)
56. `xp_gain_by_tier` (Quarterstaff)
57. `bounce_by_tier` (Slingshot)
58. `shoot_thorns` (Cacti Club)
59. `pierce_99_for_one_damage` (Flamethrower)
60. `hit_explosion_chance_by_tier` (Plasma Sledge)
61. `explosion_damage_growth_per_explosion_this_wave` (DEX-troyer)
62. `bounce_once` (Grenade Launcher)

### E. Wave-tick / context rules:
63. `self_damage_over_time` (Scythe)
64. `attack_speed_growth_over_wave` (Drill) — also needs wave context
65. `damage_penalty_while_standing_still` (Jousting Lance) — also needs movement context

---

## Implementation Priority

### High Priority (common weapons, high impact):
- `burn` — 7 weapons, core elemental mechanic
- `pierce_falloff` — 9 weapons, core ranged mechanic
- `sixth_shot_longer_cooldown` (Revolver)
- `damage_charges_until_hit` (Railgun)
- `alternate_thrust_and_sweep` — 6 melee weapons
- `material_on_critical_kill` (Drill, Thief Dagger)

### Medium Priority (mid-tier weapons):
- `projectile_explosion_on_hit` — 5 weapons
- `full_pierce` — 2 weapons
- `critical_hit_bounce` (Thief Dagger)
- `spawn_lightning_projectile_on_hit` (Lightning Shiv)
- `harvesting_by_tier` (Hand)
- `melee_hit_explosion_chance` (Plank, Power Fist)

### Low Priority (niche/legendary weapons):
- All remaining legendary/unique weapon rules
- `charm_low_health_enemy_on_hit` (Flute)
- `instant_kill_chance_by_tier` (Vorpal Sword)
- `spawn_structure_by_tier` (War Hammer)

---

*Audit date: 2026-05-29*
*Auditor: game-coder (program department)*
