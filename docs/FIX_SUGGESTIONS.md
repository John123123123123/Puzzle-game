# Fix & Polish Suggestions

This document lists gameplay, level-design, and technical fix suggestions for **Raiders of the Lost Temple**.

---

## Gameplay & Level Design

### 1. Interacting While Holding a Torch (or Other Carryable)
- **Files:** [player.gd](file:///c:/Users/danni/Documents/GitHub/Puzzle-game/scenes/characters/player.gd#L378-L395), [brazier.gd](file:///c:/Users/danni/Documents/GitHub/Puzzle-game/scenes/puzzles/brazier.gd)
- **Issue:** `Player.interact()` immediately drops `carried_item` whenever you are holding something, before checking `current_interactable`. You can't pull levers, rotate mirrors, or light braziers while holding a torch without dropping it first.
- **Suggestions (pick one):**
  1. **Context-sensitive `[E]`:** Prioritize `current_interactable` when one is in range (e.g., lighting a brazier, pulling a lever), and only drop the carried item when there is nothing to interact with.
  2. **Separate Drop / Carry key:** Keep `[E]` strictly for interacting with world objects, and bind a dedicated button for picking up / dropping items (or a dedicated Drop button).

### 2. Braziers Should Require a Torch (No Bare-Handed `[E]` Lighting)
- **File:** [brazier.gd](file:///c:/Users/danni/Documents/GitHub/Puzzle-game/scenes/puzzles/brazier.gd)
- **Issue:** Currently, players can light a brazier just by pressing `[E]` without carrying a `Torch`.
- **Suggestion:** Require the interacting player to be carrying a `Torch` (or have a `Torch` brought into range) in order to light the brazier, and update the prompt accordingly (e.g., `"Requires Torch"` when empty-handed, `"Light Brazier"` when holding a torch).

### 3. Dart Traps Feel Like Invisible Spikes
- **Files:** [dart_trap.gd](file:///c:/Users/danni/Documents/GitHub/Puzzle-game/scenes/puzzles/dart_trap.gd), [dart_trap.tscn](file:///c:/Users/danni/Documents/GitHub/Puzzle-game/scenes/puzzles/dart_trap.tscn), [dart_projectile.gd](file:///c:/Users/danni/Documents/GitHub/Puzzle-game/scenes/puzzles/dart_projectile.gd)
- **Issue:** Currently, `DartTrap` stays dormant until a player steps into its narrow `TriggerArea`, then waits only `0.10s` (`trigger_delay`) before firing a `14.0 m/s` dart—so players get hit almost immediately without seeing it coming.
- **Suggestions:**
  1. **Steady rhythmic firing:** Fire periodically (e.g., every `1.8s–2.2s`) whenever `is_active` is true (or while players are in the room) instead of waiting for someone to step into the firing line, so players can see darts flying across the hallway and time their crossing.
  2. **Slower darts & clear telegraphing:** Lower `dart_speed` (e.g., `8.0–9.5`) so projectiles are readable in flight, and play `dart_click` plus a small dust puff / flash at `SpawnPoint` `0.35s–0.45s` before each shot.
  3. **Co-op puzzle synergy:** Place rhythmic dart traps in corridors where players can block the firing line with a `PushableBlock` crate or disable the trap via a `WallLever` / `PressurePlate` (`register_trigger_activated()` already sets `is_active = false`).

### 4. Spike Traps Should Span the Full Corridor Width
- **Files:** [spike_trap.gd](file:///c:/Users/danni/Documents/GitHub/Puzzle-game/scenes/puzzles/spike_trap.gd), level scenes (`temple_level_1.tscn`–`3.tscn`)
- **Issue:** Spike traps are easy to simply walk around instead of forcing players to time their movement.
- **Suggestion:** Widen or tile spike traps across the full width of hallways/chokepoints so players actually have to read the cycle and time their crossing.

### 5. Unused Pushable Boxes Alongside Mirrors (Level 2)
- **File:** [temple_level_2.tscn](file:///c:/Users/danni/Documents/GitHub/Puzzle-game/scenes/levels/temple_level_2.tscn)
- **Issue:** Pushable boxes/crates are introduced alongside mirrors in Level 2, which is confusing because you don't actually need to use the boxes to solve the room.
- **Suggestion:** Either remove the unnecessary boxes from that room or integrate them into the puzzle (e.g., blocking a dart trap, weighing down a pressure plate to open a shutter for the light beam, or acting as a mirror/beam obstacle).

### 6. Unused Mirror in the Final Level (Level 3)
- **File:** [temple_level_3.tscn](file:///c:/Users/danni/Documents/GitHub/Puzzle-game/scenes/levels/temple_level_3.tscn)
- **Issue:** There is a mirror placed in the final level that isn't used for anything.
- **Suggestion:** Either remove the unused mirror or connect it to a `SunReceiver` / secret scarab door / hazard-disabling puzzle.

---

## Technical & UI Fixes

### 7. Main Menu `ui_accept` Accidental Game Start
- **File:** [main_menu.gd](file:///c:/Users/danni/Documents/GitHub/Puzzle-game/scenes/ui/main_menu.gd#L134-L143)
- **Issue:** `_unhandled_input()` calls `_on_start_pressed()` whenever `ui_accept` is pressed and `start_button` does not have focus, which can start the game when pressing `Enter`/`Space` on another button or inside `SettingsMenu`.
- **Suggestion:** Guard against open modal overlays and avoid overriding `ui_accept` when another UI control has focus.

### 8. Settings Menu Focus After Reset & Window Mode Labels
- **Files:** [settings_menu.gd](file:///c:/Users/danni/Documents/GitHub/Puzzle-game/scenes/ui/settings_menu.gd#L250-L254), [settings_menu.gd](file:///c:/Users/danni/Documents/GitHub/Puzzle-game/scenes/ui/settings_menu.gd#L404-L412), [settings_manager.gd](file:///c:/Users/danni/Documents/GitHub/Puzzle-game/scripts/settings_manager.gd#L46-L48)
- **Issue:** `_on_reset_defaults()` frees and rebuilds UI nodes without restoring button focus, and `window_mode` labels (`"Fullscreen"` vs `"Exclusive Fullscreen"`) don't match the `SettingsManager` comment (`1=Borderless, 2=Fullscreen`).
- **Suggestion:** Re-grab focus on `_close_button` after resetting defaults, and align the window mode labels.

### 9. Dropped Item Floor Check Over Gaps
- **File:** [player.gd](file:///c:/Users/danni/Documents/GitHub/Puzzle-game/scenes/characters/player.gd#L415-L443)
- **Issue:** `_find_safe_drop_position()` prevents dropping items inside walls/pillars/blocks, but doesn't check if there is floor beneath the drop point (e.g., at the edge of a `CrumblingFloor` pit).
- **Suggestion:** Add a short downward raycast at the candidate drop point and fall back to `global_position` if there is no floor underneath.
