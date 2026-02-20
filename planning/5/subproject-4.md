# Subproject 4 — Persistence, Stats Tracking, and Integration Polish

## Goal
Persist collection state across runs/prestiges, track lifetime collection stats, and finalize usability/polish.

## Checklist
- [x] Add collection discovery + lifetime stat structures to persistent MetaState/save schema
- [x] Ensure save migration defaults are safe for newly added fish/recipes
- [x] Confirm discovery tracking updates on first catch/craft and survives reloads and prestiges
- [x] Add integration pass for sidebar/detail interaction behavior and non-blocking navigation
- [x] Run milestone success-criteria validation and document any follow-up tasks (2026-02-19)

## Update Instructions
- Check off each task as soon as it is completed.
- Note blockers directly under the relevant checklist item until resolved.
- When all items are complete, mark Subproject 4 complete in `planning/5/project.md`.

## Validation Notes (2026-02-19)
- Ran headless project validation: `godot-4 --headless --path . --quit --verbose`.
- Result: project loads successfully, Collections screen/resources/scripts load without parse/runtime startup errors, process exits `0`.
- Follow-up task: investigate existing Godot shutdown leak warning (`res://src/data/data_registry.gd` resource still in use at exit) to determine whether cleanup should be tightened.
