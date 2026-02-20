# Subproject 2 — Tag-Based Scoring Engine + Feedback Behavior

## Goal
Implement the core tag-scoring model that evaluates experiment proximity and provides useful hot/cold feedback without hard-spoiling full solutions.

## Checklist
- [ ] Build attempt tag set generation from fish, ingredients, processes, and derived/system tags
- [ ] Implement silhouette/recipe scoring with required, preferred, and forbidden tag behavior
- [ ] Normalize final score to a stable player-facing scale and include score breakdown metadata for internal use
- [ ] Select best candidate match per attempt and expose missing/misaligned tag signals
- [ ] Show player-facing craft feedback that communicates closeness (score/progress language) without revealing exact full formulas too early
- [ ] Ensure poor or partial attempts still resolve into lower-quality/random tins rather than hard-failing

## Update Instructions
- Check off each task as soon as it is completed.
- If implementation details change, update checklist wording to reflect final behavior.
- When all items are complete, mark Subproject 2 complete in `planning/6/project.md`.
