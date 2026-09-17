# Brotato Core Rules For Phase 1

This document translates the approved Phase 0-1 spec into project-level rules.

## Wave Durations

`WaveManager.get_wave_duration(wave, endless_mode)` returns:

| Wave | Duration |
|---|---:|
| 1 | 20 |
| 2 | 25 |
| 3 | 30 |
| 4 | 35 |
| 5 | 40 |
| 6 | 45 |
| 7 | 50 |
| 8 | 55 |
| 9-19 | 60 |
| 20 | 90 |
| 21+ endless | 60 |

## Materials

Materials are the run currency and XP source.

When a material pickup with value `n` is collected:

1. Add `n` to current materials.
2. Add `n * xp_boost` to XP.
3. Update material and XP UI.

The transitional `gold` field stays during Phase 1 as an alias for current materials.

## Material Bag

At wave end, visible material pickup values are added to `material_bag`.

When future material pickups are spawned, bagged material value is paid out before normal drop value. Phase 1 may pay the entire bag into the next material pickup if exact per-drop behavior is not yet modeled.

## Level-Up Queue

XP thresholds can create multiple pending level-ups.

Level-up effects are not auto-applied during combat. Each level queues one post-wave upgrade choice.

Wave-end sequence:

1. Resolve uncollected materials.
2. Show wave summary.
3. Resolve each pending level-up.
4. Open shop.

## Upgrade Choices

Each queued level-up generates four choices from `UpgradeChoiceRules`.

Phase 1 stat choice pool:

| ID | Name | Apply Effect |
|---|---|---|
| max_hp | Max HP | `max_hp += value`, `hp += value` |
| damage | Damage | `damage_bonus += value` |
| attack_speed | Attack Speed | `fire_rate_multiplier += value` |
| speed | Speed | `speed += value`, `base_speed += value` |
| armor | Armor | `armor += value` |
| crit_chance | Crit Chance | `crit_chance += value` capped at 0.8 |
| luck | Luck | `luck += value` |
| harvesting | Harvesting Approximation | `gold_per_wave += value` as a Phase 1 approximation |

## Shop

Shop UI keeps four slots, lock, reroll, purchase, sell, and weapon upgrade panels.

`ShopRules` owns:

- `get_reroll_cost(reroll_index)`.
- `get_price(base_price, rarity, wave)`.
- `roll_rarity(wave, luck)`.
- `roll_slot_type(wave, slot_index)`.
- `roll_offers(pool, wave, luck, locked_items)`.

All visible shop text should say `Materials` or `材料`, not `金币`.
