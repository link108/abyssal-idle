# Milestone 6 — Recipe Discovery & Experimentation System

## Goal
Implement a data-driven experimentation loop in the cannery where players craft tins without known recipes, receive meaningful proximity feedback, unlock silhouette discoveries, and retain all attempts in an experimental log.

## How To Use This Project File
- This file is the master checklist for Milestone 6.
- Each subproject has its own checklist. As items are completed, update the related subproject file.
- When a subproject is fully complete, mark it done here and note the completion date.
- When the final subproject is done, ensure every item in this checklist is checked.

## Subprojects
- `planning/6/subproject-1.md` — Data contract coverage + attempt pipeline foundation
- `planning/6/subproject-2.md` — Tag-based scoring engine + feedback behavior
- `planning/6/subproject-3.md` — Silhouette unlock system + progression states
- `planning/6/subproject-4.md` — Experimental log + refine loop + integration polish

## Checklist
- [ ] Subproject 1 complete
- [ ] Subproject 2 complete
- [ ] Subproject 3 complete
- [ ] Subproject 4 complete
- [ ] Integration pass across Cannery, Recipes/Collections views, and save/load flows
- [ ] Smoke test: failed experiments produce lower-quality tins, near-matches progress silhouettes, exact matches register discoveries, and log entries persist across reload

## Constraints
- Keep implementation behavior-driven and data-driven.
- Do not require Heat/Preserve to produce a craft output; non-matching attempts should still produce lower-quality/random tins.
- Keep scope open for future extensions (cursed silhouettes, ocean-state dependencies, aging, mold, prestige-only silhouettes) without pre-implementing them.

## Completion Instructions
- Check off each task in this file immediately after it is finished.
- Add completion dates next to checked items when applicable.
- When all items are complete, add a short `Completed: YYYY-MM-DD` note at the end of this file.
