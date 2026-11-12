# Subproject 4 — Experimental Log + Refine Loop + Integration Polish

## Goal
Make experimentation cumulative by storing attempts, surfacing best tries, and enabling fast iteration from prior results.

## Checklist
- [x] Persist experiment log entries with attempt composition, derived tags, score, best-match metadata, and timestamp
- [x] Add log UI with usable sorting/filtering for newest attempts, highest score, and silhouette-related progress
- [x] Implement attempt detail view that explains what was tried and how close it was
- [x] Add “Refine” flow to prefill the cannery from a prior attempt so players can iterate quickly
- [x] Highlight “closest so far” and other progression cues that reward repeated experimentation
- [x] Run integration pass for cannery crafting, silhouette progression, and save/load migration safety

Notes (2026-11-11, ABYSS-15): the cannery's "Experiment Log" button opens `src/ui/components/experiment_log/experiment_log_panel.gd`: sort by newest or highest score, filter by recipe (hidden recipes show only the fish), an attempt detail (score vs threshold, key/flavor note counts, process steps, hint) and "Refine this". ★ marks the closest attempt per recipe, and the cannery's recent list shows the closest attempt for the selected fish. Integration and save/load migration are covered by `tests/headless/test_experiment_log.gd`, `test_recipes.gd`, `test_use_recipe.gd` and `test_clues.gd`.

## Update Instructions
- Check off each task as soon as it is completed.
- Note blockers directly under the relevant checklist item until resolved.
- When all items are complete, mark Subproject 4 complete in `planning/6/project.md`.
