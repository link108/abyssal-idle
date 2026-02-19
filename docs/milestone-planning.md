# Milestone Planning: Recipe Discovery Systems

Goal: Implement a player-friendly recipe discovery loop that scales to a large search space while staying “idle game” friendly.

Core combo:

* Tag-based scoring system
* Silhouette unlocks
* Experimental log

This plan assumes you already have data files:

* `fish.json`
* `recipes.json`
* `ingredients.json`
* `processes.json`
* `equipment.json`

---

## Milestone 0: Data Contract + Validation (Foundation)

### 0.1 Define canonical IDs and references

* Fish are keyed by `fish_id`
* Recipes are keyed by `recipe_id`
* Ingredients are keyed by `ingredient_id`
* Processes are keyed by `process_id`
* Equipment is keyed by `equipment_id`

### 0.2 Implement data loading

* Load all JSON files at game start
* Build lookup maps:

  * `fish_by_id`
  * `recipe_by_id`
  * `ingredient_by_id`
  * `process_by_id`
  * `equipment_by_id`

### 0.3 Implement validation pass

Validate and hard-fail with actionable errors:

* Unique IDs per file
* Recipe `required_fish_name` or `required_fish_id` aligns with fish list (prefer `required_fish_id` soon)
* Recipe `ingredients[*].item_id` exists in `ingredients.json` OR is a fish pseudo-item like `fish_<fish_id>`
* Recipe `processes[*]` exists in `processes.json`
* Processes’ `required_equipment[*]` exist in `equipment.json`

### 0.4 Define the “attempt” schema (player-created recipes)

A “recipe attempt” is what the player assembles:

* `fish_id`
* `ingredient_ids[]` + quantities
* `process_ids[]` (ordered)
* `timestamp`
* `result`: score, matched recipe (if any), output item, notes

Deliverable:

* Data loads reliably
* Clear validation errors
* A single in-memory representation for fish/recipe/process/ingredient/equipment

---

## Milestone 1: Experimental Log (Quality-of-Life Backbone)

### 1.1 Log persistence

* Create an `experiment_log.json` save file (or embed inside your save)
* Store each attempt with:

  * `attempt_id`
  * `fish_id`
  * `ingredient_ids` (and qty)
  * `process_ids` (ordered)
  * `score` summary fields
  * `matched_recipe_id` (nullable)
  * `created_at`

### 1.2 Log UI

* A simple list view:

  * Shows fish icon/name, top tags, score %, “Discovered!” if exact match
  * Sort options:

    * Recent
    * Highest score
    * Same fish
* Selecting an entry opens details:

  * Full ingredient list
  * Process sequence
  * Score breakdown

### 1.3 “Refine attempt” workflow

* Button: “Refine”

  * Prefills crafting UI with ingredients/processes from selected attempt
  * Player can adjust one element and re-run

Deliverable:

* Attempts are saved
* Attempts are reviewable
* Attempts can be used as iteration starting points

---

## Milestone 2: Tag Model (The Language of Discovery)

### 2.1 Add tags to ingredients/processes/equipment

* Ensure every ingredient has `tags[]`
* Ensure every process has `adds_tags[]`
* Optionally give fish `tags[]` (already present)

### 2.2 Compute attempt tag set

Given an attempt:

* Start with fish tags
* Add ingredient tags
* Add tags from each process’s `adds_tags`
* Optionally add “derived tags”:

  * If any acid ingredient present → `acidic`
  * If any oil ingredient present → `oily`
  * If includes `trim_special_cut` → `special_cut`

### 2.3 Define recipe tag signature

For each recipe in `recipes.json`, compute a “signature”:

* Fish requirement (hard gate)
* Required ingredients (hard or soft gate; start as hard)
* Required processes (hard or soft; start as hard)
* Target tags (soft scoring)

Deliverable:

* Attempt tags are computed consistently
* Every recipe has a comparable tag signature

---

## Milestone 3: Tag-Based Scoring (Hot/Cold Without Spoiling)

### 3.1 Scoring algorithm (v1)

Score attempt vs each recipe candidate for the same fish:

* Ingredient match score

  * exact ingredient IDs match: +X
  * tag overlap: +Y
* Process match score

  * exact process IDs match: +X
  * tag overlap: +Y
* Penalties

  * extra ingredients: -p
  * missing key process: -p

Pick best candidate and produce:

* `best_recipe_id`
* `score_percent`
* `missing_hints[]` (derived)

### 3.2 Hint generation rules

Show only 1–2 hints max, prefer vague:

* “Needs more acidity.”
* “This wants smoke.”
* “A special cut is expected.”

Avoid leaking exact items early.

### 3.3 Feedback UI

On craft completion:

* Show score meter (0–100%)
* If score >= threshold (e.g., 70%): show a silhouette entry appears
* If exact match: show “Recipe Discovered!”

Deliverable:

* Players get a readable “closer/farther” signal
* Players can iterate using experimental log

---

## Milestone 4: Silhouette Unlock System (Recipe Book Progression)

### 4.1 Recipe book entries

Each recipe has a “discovery state”:

* `undiscovered`
* `hinted` (silhouette visible)
* `discovered` (full visible)

Persist per-recipe state in save.

### 4.2 Triggering silhouettes

When an attempt has:

* `best_recipe_id` score >= silhouette_threshold
  Then:
* Mark that recipe as `hinted`

### 4.3 Progressive reveal

For `hinted` recipes, reveal partial fields based on “milestones”:

* If fish matches: show fish name
* If includes an acid ingredient tag: reveal “in Vinegar”
* If includes smoking tag: reveal “Smoked”
* If includes special_cut tag: reveal the cut word (Tongue/Liver/Heart) OR reveal “Special Cut” until discovered

### 4.4 Completion / discovery

When exact match occurs:

* Set `discovered`
* Reveal all details and unlock crafting directly from recipe book

Deliverable:

* Recipe book feels like exploration
* Near-misses become visible goals

---

## Milestone 5: Equipment Gating + UX Polish

### 5.1 Gate processes by equipment

* If player lacks required equipment:

  * process is disabled in UI
  * tooltip shows missing equipment

### 5.2 Suggested next actions (optional but strong)

Based on scoring hints:

* Show 1–3 “suggestions” in the UI:

  * “Try an acid ingredient”
  * “Try a smoking process”
  * “Try brining”

### 5.3 Balance knobs exposed

Create constants in one place:

* silhouette threshold
* discovery threshold
* scoring weights and penalties
* max hints per attempt

Deliverable:

* Progression feels earned
* Complexity unfolds gradually

---

## Milestone 6: Content Scaling + Modding Readiness

### 6.1 Content pack format

* Allow adding fish/recipes/ingredients/processes via additional JSON files
* On boot: load base + mods
* Validate all

### 6.2 Debug tools (dev-only)

* “Reveal all recipes” toggle
* Print best-match recipe and score breakdown
* Export experiment log

Deliverable:

* Easy to add 200+ fish/recipes later
* Debuggable and iteration-friendly

---

## Notes for Implementation

### Strong recommendation: reference IDs everywhere

* Replace `required_fish_name` in `recipes.json` with `required_fish_id`.
* In ingredients, treat fish as items consistently:

  * Option A: `fish_<fish_id>` pseudo-items
  * Option B: ingredient entries for fish meat as ingredients (more verbose)

### Keep early version simple

* Start with fewer ingredient types and processes
* Keep scoring coarse
* Add nuance after the loop feels good

