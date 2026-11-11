# Subproject 4 — Experimental Log + Refine Loop + Integration Polish

## Goal
Make experimentation cumulative by storing attempts, surfacing best tries, and enabling fast iteration from prior results.

## Checklist
- [x] Persist experiment log entries with attempt composition, derived tags, score, best-match metadata, and timestamp
- [ ] Add log UI with usable sorting/filtering for newest attempts, highest score, and silhouette-related progress
- [ ] Implement attempt detail view that explains what was tried and how close it was
- [x] Add “Refine” flow to prefill the cannery from a prior attempt so players can iterate quickly
- [ ] Highlight “closest so far” and other progression cues that reward repeated experimentation
- [ ] Run integration pass for cannery crafting, silhouette progression, and save/load migration safety

Notes (2026-11-10): the log persists in `meta_state.experiment_log` (max 120) and "Refine Last" prefills the cannery; the cannery shows only the 3 most recent attempts, so sorting/filtering, an attempt detail view and "closest so far" cues are still open. Integration is covered by `tests/headless/test_recipes.gd`, `test_use_recipe.gd` and `test_clues.gd`; save/load migration safety has not been re-verified.

## Update Instructions
- Check off each task as soon as it is completed.
- Note blockers directly under the relevant checklist item until resolved.
- When all items are complete, mark Subproject 4 complete in `planning/6/project.md`.
