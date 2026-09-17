# Collision System Migration: distance_to -> Area2D Signals

## Summary

Migrate all manual `distance_to` collision detection to Godot's built-in Area2D signal system. This eliminates O(n*m) per-frame brute-force checks in favor of engine-level spatial partitioning (BVH).

## Collision Layer Assignment

| Layer | Bit | Purpose | Node Type |
|-------|-----|---------|-----------|
| 1 | Player body | Player CharacterBody2D |
| 2 | Enemy body | Enemy CharacterBody2D |
| 4 | Player bullet | Bullet Area2D |
| 8 | XP orb | XPOrb Area2D (already working) |
| 16 | Enemy bullet | EnemyBullet Area2D (already working) |
| 32 | Pickup | Pickup Area2D (new) |

## Module Changes

### 1. Bullet.gd (A+B: bullet-enemy hit, splash, chain lightning)

**Current:** `_process()` iterates all enemies every frame, checks `distance_to`.

**New:**
- Scene already has collision_layer=4, collision_mask=2 and CollisionShape2D (r=6) — but code ignores it
- Connect `body_entered` signal in `_ready()` to `_on_body_entered(body)`
- Move all hit logic (damage, lifesteal, status effects, elemental ammo) into `_on_body_entered`
- Piercing: track `hit_enemies`, ignore already-hit bodies in callback, `_return_to_pool` after 3 hits
- Splash: on hit, iterate `get_tree().get_nodes_in_group("enemies")` with distance check (event-driven, not per-frame — acceptable)
- Chain lightning: same approach, one-time distance check on hit event
- Pool management: `activate()` sets `set_deferred("monitoring", true)`, `_return_to_pool()` sets `set_deferred("monitoring", false)`
- Remove the entire enemy iteration loop from `_process()`
- Increase CollisionShape2D radius to match current hit detection (`15 + 20 * scale.x` ~= 35 for normal enemies). Since enemy scale varies, keep bullet collision shape at ~8 and rely on enemy's own collision shape size.

### 2. Enemy.tscn + Enemy.gd (C+G+H: contact damage, separation, healer)

**Contact damage (C):**
- Add child `ContactArea` (Area2D) to Enemy.tscn, collision_layer=0, collision_mask=1 (detects player body)
- CircleShape2D radius = 35 (matches current `35.0 * scale.x` at scale 1.0; auto-scales with parent)
- Connect `body_entered` / `body_exited` signals to track player overlap
- In `_physics_process`, if player is overlapping and `contact_timer <= 0`, deal contact damage
- Remove all `dist < 35.0 * scale.x` and `dist < 55.0` manual checks
- Boss uses the same ContactArea but with larger shape (auto-scaled via parent scale=2.4)

**Separation force (G):**
- Add child `SeparationArea` (Area2D) to Enemy.tscn, collision_layer=0, collision_mask=2 (detects enemy bodies)
- CircleShape2D radius = 50 (matches current `30 * (scale.x + other.scale.x) * 0.5` max range)
- `_get_separation_force()` uses `$SeparationArea.get_overlapping_bodies()` instead of iterating all enemies
- Still calculates distance for direction/magnitude — but only for nearby enemies, not all

**Healer (H):**
- Healer heal range is 50px — reuse `SeparationArea` (radius 50) to find nearby enemies
- `_heal_nearby_enemies()` uses `$SeparationArea.get_overlapping_bodies()`

### 3. Player.tscn + Player.gd (D: melee, thorns, nearest enemy)

**Current:** Player.tscn has no Area2D child. Code iterates all enemies.

**New:**
- Add child `DetectArea` (Area2D) to Player.tscn, collision_layer=0, collision_mask=2 (detects enemies)
- CircleShape2D radius = 160 (covers magnet_range and max weapon range)
- Melee weapons: `$DetectArea.get_overlapping_bodies()` filtered by melee radius
- `_fire_weapon` nearest enemy: iterate `$DetectArea.get_overlapping_bodies()` for nearest
- Thorns: find closest enemy from `$DetectArea.get_overlapping_bodies()`
- Fallback: if `DetectArea` has no overlapping bodies, skip (no enemies in range anyway)

### 4. Main.gd (E+F: pickups, turrets, undeads)

**Pickups (E):**
- Convert pickup nodes from plain Node2D to Area2D with collision_layer=32, collision_mask=1
- Add CircleShape2D radius = 80 (current pickup range)
- Connect `body_entered` signal for auto-pickup on player contact
- Remove manual distance loop from `_process()`

**Turrets (F):**
- Add Area2D child to turret node, collision_layer=0, collision_mask=2
- CircleShape2D radius = 300 (turret range)
- Use `get_overlapping_bodies()` to find enemies in range

**Undeads (F):**
- Add Area2D child to undead node, collision_layer=0, collision_mask=2
- CircleShape2D radius = 200 (detection range)
- Use `get_overlapping_bodies()` for nearest enemy + attack range check

## Scene File Changes

### Player.tscn
- Add: DetectArea (Area2D) + CollisionShape2D (CircleShape2D r=160)

### Enemy.tscn
- Add: ContactArea (Area2D) + CollisionShape2D (CircleShape2D r=35)
- Add: SeparationArea (Area2D) + CollisionShape2D (CircleShape2D r=50)

### Bullet.tscn
- Verify: collision_layer=4, collision_mask=2 (already set)
- Adjust CollisionShape2D radius if needed

### Main.gd (runtime nodes)
- Pickup, turret, undead nodes constructed in code — add Area2D + shape programmatically

## Pool Management

Bullet and EnemyBullet use object pools. Critical: toggling `monitoring` when activating/deactivating.

- `activate()`: `set_deferred("monitoring", true)`
- `_return_to_pool()`: `set_deferred("monitoring", false)`
- Already done correctly in EnemyBullet.gd (reference implementation)

## Risk Mitigation

1. **Scale-dependent collision shapes**: Enemy scale varies by type (0.5~2.4). CollisionShape2D inherits parent scale — Godot handles this automatically.
2. **Pool reuse**: `set_deferred` prevents physics engine errors when toggling monitoring mid-frame.
3. **Signal disconnection**: No need — signals are connected once in `_ready()`, the callback checks `_active` state.
4. **Boomerang return**: `distance_to(shooter.position)` for return-to-player check is kept (single target, negligible cost).
