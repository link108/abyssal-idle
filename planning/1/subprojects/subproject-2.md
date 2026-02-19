# Subproject 2 — Reputation + MetaState Persistence

## Goal
Introduce a minimal MetaState with reputation and prestige count, and make it persist.

## Notes
- Keep the initial reputation formula simple and measurable.
- MetaState persists across runs; run state resets on prestige.

## Checklist
- [x] Define a MetaState data structure (reputation, prestige_count, permanent bonuses)
- [x] Add persistence for MetaState in save/load (versioned)
- [x] Add a simple reputation calculation function that uses measurable inputs
- [x] Ensure reputation is added on prestige and not on normal save
- [x] Document the formula in code comments for tuning later

## Update Instructions
- Check off items as you complete them.
- When all items are complete, mark this subproject as complete in `planning/1/project.md`.
