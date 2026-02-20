# Subproject 3 — Silhouette Unlock System + Progression States

## Goal
Add hidden silhouette targets that reveal through experimentation and convert near-misses into tangible progression.

## Checklist
- [ ] Finalize silhouette data fields and load behavior from `data/raw/silhouettes.json`
- [ ] Implement per-silhouette discovery states (`undiscovered`, `hinted`, `discovered`) with save persistence
- [ ] Trigger silhouette progress/unlock from scoring thresholds and preserve best progress per silhouette
- [ ] Expose silhouette UI behaviors for hidden entries, vague hint text, and visible progress indicators
- [ ] Reveal full silhouette details when discovery criteria are met
- [ ] Ensure unlock/discovery flow is compatible with future silhouette expansion without schema rewrites

## Update Instructions
- Check off each task as soon as it is completed.
- Add new checklist items if additional silhouette behavior is introduced.
- When all items are complete, mark Subproject 3 complete in `planning/6/project.md`.
