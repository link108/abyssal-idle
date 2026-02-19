# Subproject 3 — Prestige Flow and Reset Logic

## Goal
Implement the prestige action, including confirmation, calculation, and run reset while preserving MetaState.

## Notes
- Prestige becomes available at 100 tins sold per run.
- Prestige is optional; player can continue the run.

## Checklist
- [x] Add prestige availability check (uses per-run tins sold)
- [x] Add prestige action entry point (UI button or command stub)
- [x] On prestige: compute reputation, update MetaState, reset run state
- [x] Ensure MetaState persists after prestige
- [x] Add minimal UI feedback or debug logging for prestige result

## Update Instructions
- Check off items as you complete them.
- When all items are complete, mark this subproject as complete in `projects/1/project.md`.
