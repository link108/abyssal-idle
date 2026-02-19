# Subproject 4 — Save/Load Schema Updates

## Goal
Update save/load to include the new run counters and MetaState while preserving compatibility.

## Notes
- Save schema should be versioned and tolerant of missing fields.

## Checklist
- [x] Add new fields to save data (`tins_sold`, MetaState, etc.)
- [x] Update load logic with defaults for missing fields
- [x] Increment save version and handle basic migration (if needed)
- [x] Verify save/load across: new game, mid-run, post-prestige

## Update Instructions
- Check off items as you complete them.
- When all items are complete, mark this subproject as complete in `planning/1/project.md`.
