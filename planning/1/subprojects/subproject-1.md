# Subproject 1 — Run State + Counters

## Goal
Add per-run tracking for tins sold and any other counters needed to gate prestige.

## Notes
- “Tins sold” is per run and must reset on new game and on prestige.
- Track in run state (not MetaState).

## Checklist
- [x] Add per-run `tins_sold` counter to GameState
- [x] Increment `tins_sold` when selling tins in `sell_tick()`
- [x] Reset `tins_sold` on new game and on prestige
- [x] Expose `tins_sold` for UI visibility or gating logic
- [x] Add unit-style sanity checks in code comments or debug prints as needed

## Update Instructions
- Check off items as you complete them.
- When all items are complete, mark this subproject as complete in `planning/1/project.md`.
