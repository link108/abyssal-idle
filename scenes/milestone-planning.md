# Abyssal Idle — Milestone Planning (Revised Loop + Prestige Model)

This document reflects the clarified core loop:

Core Loop (per run):
1. Start new game
2. Send crew on fishing trips
3. Sell fish for money
4. Purchase cash upgrades
5. Purchase a cannery
6. Sell tins for money
7. Prestige becomes AVAILABLE after selling 100 tins (not required)
8. Prestige grants Reputation
9. Spend Reputation in a permanent tech tree
10. Repeat loop with improved ceilings and options

Reputation gained depends on:
- Total money earned
- Upgrades purchased
- Ocean health performance
- Production scale
NOT fish vs tins ratio (tins are always encouraged)

Player is never forced into a path. Path emerges from behavior and permanent upgrades.

---

# Milestone 1 — Foundational Run + Optional Prestige Unlock

## Goal
Implement the complete base loop with:
- Crew fishing
- Selling fish
- Cannery unlock
- Selling tins
- Optional prestige unlock at 100 tins
- Save/load

No sustainability branch yet.
Ocean health may exist internally but does not need to be visible.

---

## Systems to Build

### 1. Core Economic Loop
- Crew trip system (send → return → yield fish)
- Fish inventory
- Sell fish for money
- Purchase upgrades with money
- Unlock and use cannery
- Convert fish → tins
- Sell tins for higher value

### 2. Prestige Availability Gate
Prestige becomes available when:
- Player has sold at least 100 tins in the current run

Tracking note:
- “Tins sold” is per-run and resets on new game and on prestige.

Prestige is OPTIONAL.
Player can continue scaling instead of prestiging.

### 3. Reputation System (Initial Implementation)
On prestige:
- Calculate reputation earned this run
- Reset run state
- Preserve meta state

Reputation calculation inputs:
- Total money earned
- Total tins produced
- Automation scale achieved (initially proxy by money earned and/or count of automation upgrades)
- Average ocean health (even if hidden)
- Upgrade distribution

Clarifications:
- “Automation scale” can start as a simple proxy (money earned + upgrade count). Keep it measurable.
- Some upgrades are “choose-one-per-prestige” pairs: industrial vs sustainability versions of the same upgrade.
  - Only one of each pair can be chosen per prestige.
  - The other becomes available on a later prestige.
  - These choices influence reputation bonuses/weights.
- Example choose-one pair:
  - Pair ID: route_boost_1
  - Industrial option: Turbo Trawlers (+15% production, -5% ocean regen)
  - Sustainability option: Net Mending Guild (+15% ocean regen, -5% production)
  - Rule: pick one per prestige; the other can be picked on a later prestige.

Do not overcomplicate the formula.
Start simple and tune later.

### 4. MetaState System
Persistent data:
- Total reputation
- Prestige count
- Permanent tech unlocks
- Endings achieved (later)

### 5. Permanent Tech Tree (Basic Version)
Reputation can unlock:
- View ocean health bar
- Increase fish quantity
- Increase fish quality ceiling
- Increase base automation efficiency
- Increase regen cap

Upgrades should:
- Raise ceilings
- Slightly reduce friction
- Never invalidate Act 1

Rep bonuses:
- Reputation bonuses are permanent stat modifiers applied to future runs.

### 6. Save/Load (Required)
Because runs can last hours:
- Autosave periodically
- Save on quit
- Versioned save schema

---

# Milestone 2 — Ocean Health + Behavior-Based Path Emergence

## Goal
Make ocean health meaningful and visible.
Allow industrial vs sustainability behaviors to naturally affect reputation gain.

---

## Systems to Build

### 1. Visible Ocean Health
- Health meter
- Regen rate
- Extraction pressure

Health decreases with:
- Fish extraction
- Automation scale

Health regenerates slowly over time.

### 2. Industrial vs Sustainable Behaviors (No Forced Choice)
Industrial behavior:
- High automation
- High production
- Faster depletion

Sustainable behavior:
- Higher regen upgrades
- Lower pressure per extraction
- Slower but stable scaling

No menu choice.
Behavior drives outcome.

### 3. Reputation Weighting Update
Industrial Reputation weighted by:
- High production scale
- Low average ocean health
- Industrial upgrades

Sustainability Reputation weighted by:
- High average ocean health
- Regen upgrades
- Quality focus

Both types can be earned in same run.

---

# Milestone 3 — Endings (All Require Prestige)

## Goal
Implement 3 endings.
Prestige is not a hard requirement, but without it endings should be impractically slow.

---

## Ending Structure

### 1. Industrial Collapse (~2–3 hour run target)
Trigger:
- Ocean health reaches 0
- Production threshold met

Fastest path.

### 2. Sustainable Equilibrium (~1.5x time)
Trigger:
- Maintain ocean health above threshold
- Sustain production for long duration

Requires regen upgrades and reputation boosts.

### 3. Dual Mastery (~2–2.5x time)
Trigger:
- High production threshold
- High ocean health threshold
- High quality ceiling reached

Mathematically unreachable on first run due to ceiling caps.
Prestige required to raise caps.

---

# Milestone 4 — Reputation Skill Tree Expansion

## Goal
Deepen permanent progression while preserving early-game feel.

---

## Skill Tree Categories

### Industrial Branch
- Throughput multipliers
- Automation cap increases
- Pressure efficiency tradeoffs

### Sustainability Branch
- Regen multipliers
- Quality cap increases
- Pressure reduction efficiency

### Structural / Meta Branch
- Faster early upgrade ramp
- Minor starting boosts
- Slightly increased base regen
- Slightly increased base catch

Rule:
All bonuses > penalties.
Combined mastery must be possible over multiple prestiges.

---

# Milestone 5 — Fish Variety + Collection

## Goal
Add depth and replay incentive.

---

## Systems
- Multiple fish types
- Rare fish (high health)
- Mutated fish (low health)
- Quality tiers
- Collection page
- Achievements
- Persistent collection across runs

Collection contributes to reputation weighting (optional later).

---

# Milestone 6 — Balance + Pacing Pass

## Targets

Industrial run:
- ~2–3 hours to collapse

Sustainable run:
- Longer than industrial

Dual mastery:
- Requires multiple prestiges

Early game:
- Manual matters

Mid game:
- Automation dominates

Late game:
- Passive scaling + strategic tuning

Avoid:
- Exponential runaway within 30 minutes
- Stagnation after 1 hour

---

# Global Design Rules

- Prestige becomes available early (100 tins), not mandatory.
- Player is never forced into a path.
- Selling tins is always encouraged.
- Reputation is based on scale and health, not fish vs tin ratio.
- Permanent upgrades raise ceilings, not skip gameplay.
- Automation replaces actions, not thinking.
- Dual mastery requires multiple prestiges.
- System complexity increases only after the base loop feels strong.

---

# Development Order (Strict)

1. Ship complete loop + optional prestige unlock.
2. Implement reputation calculation + permanent tech tree.
3. Make ocean health visible and meaningful.
4. Implement endings.
5. Add fish variety + collection.
6. Final tuning for Steam release.

Do not build sustainability systems before prestige works.
Do not build full collection before endings exist.
Do not add complexity before a 2–3 hour arc feels satisfying.
