# Subproject 1 — Data Contract Coverage + Attempt Pipeline Foundation

## Goal
Confirm data-contract and validation coverage, then establish a single attempt pipeline that all discovery systems can use.

## Checklist
- [ ] Confirm canonical IDs and cross-file references are validated for fish, recipes, items/ingredients, processes, and equipment
- [ ] Document and close any remaining validation gaps using existing scaffolding so bad data fails with actionable errors
- [ ] Add `data/raw/silhouettes.json` scaffold and load path so silhouettes are first-class data
- [ ] Define a single in-memory craft-attempt structure (fish, ingredients, processes, derived tags, score summary, match metadata, timestamp)
- [ ] Ensure craft attempts always return an output tin result, even when no valid/strong recipe match is found
- [ ] Wire attempt pipeline so scoring, unlock progression, and logging all consume the same attempt result object

## Update Instructions
- Check off each task as soon as it is completed.
- If scope changes, add a new checklist item before implementing it.
- When all items are complete, mark Subproject 1 complete in `planning/6/project.md`.
