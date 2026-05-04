# Rushshift Trainer Prototype Notes

## What this includes
- One Godot 4 main scene with a KDS-style ticket strip and nacho station panel.
- JSON-driven recipes, ingredients, station stock, and sample ticket queue.
- A thin playable loop: select ticket -> build -> oven -> post-oven (if needed) -> send to service.
- Debrief text panel showing basic accuracy, speed, and mistake categories.

## How to run
1. Open project in Godot 4.x.
2. Run `scenes/main.tscn` (or default project run).
3. Select a ticket card and perform station actions.

## Not validated in this environment
- Runtime execution inside a real Godot editor/export target.
- Visual polish tuning and responsive layout checks across aspect ratios.

## Known limitations
- Validation is intentionally lightweight and focused on core training logic.
- Ingredient button list is static and does not group by pre/post stage.
- Plate stock exists in station JSON but only ingredient stock is consumed in this slice.
- Mods currently focus on wing sauce heat override only.

## Recommended next task
- Add explicit plate stock consumption and on-screen phase hints.
- Add per-error weighted scoring and richer debrief recommendations.
- Add unlockable complexity tiers (rush burst, dual-ticket juggling, recall interrupts).
