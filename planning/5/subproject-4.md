# Subproject 4 — Persistence, Stats Tracking, and Integration Polish

## Goal
Persist collection state across runs/prestiges, track lifetime collection stats, and finalize usability/polish.

## Checklist
- [x] Add collection discovery + lifetime stat structures to persistent MetaState/save schema
- [x] Ensure save migration defaults are safe for newly added fish/recipes
- [x] Confirm discovery tracking updates on first catch/craft and survives reloads and prestiges
- [x] Add integration pass for sidebar/detail interaction behavior and non-blocking navigation
- [ ] Run milestone success-criteria validation and document any follow-up tasks

## Update Instructions
- Check off each task as soon as it is completed.
- Note blockers directly under the relevant checklist item until resolved.
- When all items are complete, mark Subproject 4 complete in `planning/5/project.md`.

Blocker for final item:
- Runtime validation in Godot editor/runtime is still required in this environment (no `godot` binary available here).
