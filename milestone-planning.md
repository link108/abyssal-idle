# Project 6 — Recipe Discovery & Experimentation System

## Vision

Transform the cannery from a static recipe executor into an experimental system where:

- Players combine fish + ingredients + processes
- The system evaluates outcomes using tag-based scoring
- Hidden recipes (Silhouettes) unlock based on proximity
- Failed attempts still generate meaningful progress

This system should feel:
- Mysterious
- Experimental
- Discoverable
- Replayable

Heat and Preserve remain optional. Strange or incomplete tins may unlock rare outcomes.

---

# System Overview

The system consists of three major pillars:

1. Tag-Based Scoring Engine
2. Silhouette Unlock System
3. Experimental Log

All three operate on the same data foundation:
- Fish tags
- Ingredient tags
- Process tags (v2 core verbs)
- Result tags (derived)

---

# Architecture Overview

Craft Attempt → Build Tag Set → Score Against Silhouettes → 
Return:
- Result quality
- Matching silhouette progress
- Unlock events (if threshold met)
- Log entry

---

# PHASE 1 — Tag-Based Scoring Engine

## Goal

Create a flexible scoring system that evaluates how close a crafted tin is to a hidden recipe archetype.

## Core Concepts

Each craft attempt generates:

- fish tags
- ingredient tags
- process tags
- derived tags (e.g. raw, preserved, unstable, cursed)

Each silhouette defines:
- required_tags
- preferred_tags
- forbidden_tags
- minimum_score_to_unlock

## Scoring Model

Example scoring weights:

- Required tag match: +5
- Preferred tag match: +2
- Missing required tag: -3
- Forbidden tag present: -5

Return:
- final_score
- normalized_score (0–100)
- matched_tags
- missing_required_tags

## Deliverables

- scoring_engine.gd
- silhouette data structure
- attempt → score pipeline
- unit test style debug print in dev builds

---

# PHASE 2 — Silhouette Unlock System

## Goal

Introduce hidden recipes that reveal themselves through experimentation.

## Silhouette Structure

Each silhouette contains:

- silhouette_id
- display_name (hidden until unlocked)
- hint_text
- required_tags
- preferred_tags
- forbidden_tags
- unlock_threshold
- reward (money multiplier, cosmetic, achievement, etc.)

## Behavior

Before unlock:
- UI shows shadowed name
- Shows vague hint (e.g. “Preserved Deep Flesh”)
- Displays progress bar if player has scored > 0

After unlock:
- Full name revealed
- Exact tag breakdown optionally shown
- May appear in Collections screen

Unlock condition:
- normalized_score >= unlock_threshold

## Deliverables

- silhouettes.json
- unlock logic integrated into scoring
- UI support for:
  - shadowed entries
  - progress indicators
  - unlock animation trigger

---

# PHASE 3 — Experimental Log

## Goal

Record all craft attempts and make experimentation feel cumulative.

## Log Entry Structure

- attempt_id
- fish_id
- ingredient_ids
- process_ids
- derived_tags
- score
- matched_silhouette_id (if any)
- timestamp

## Features

- Show last 10 attempts
- Highlight best attempt per silhouette
- Display “Closest So Far” marker
- Allow sorting by:
  - highest score
  - newest
  - silhouette progress

This encourages:
- Iteration
- Refinement
- Discovery loops

## Deliverables

- experimental_log.gd
- user://save integration
- basic UI panel under Cannery or new screen

---

# SYSTEM RULES (Important)

- Heat and Preserve are optional.
- Missing both may create tags like:
  - raw
  - unstable
  - putrid
  - living
- These should not block crafting.
- They should affect scoring.

Do NOT hard-fail crafting unless equipment missing.

---

# DATA REQUIREMENTS

We will need:

- silhouettes.json
- Add tags to:
  - fish.json
  - ingredients.json
  - processes.json (already present)
- scoring configuration (constants or JSON)

---

# DESIGN CONSTRAINTS

- Keep core verbs minimal (v2 list only)
- No process variants explosion
- Tags drive complexity, not process count
- System must scale without adding more verbs

---

# Future Extensions (Not In Scope Now)

- Rare cursed silhouettes
- Ocean-state-dependent recipes
- Time-based aging system
- Mold growth mechanic
- Prestige-only silhouettes

---

# Success Criteria

- Player can craft without knowing recipes
- UI provides meaningful “hot/cold” feedback
- Unlocking feels earned
- Failed attempts still give information
- System is data-driven and easy to extend

