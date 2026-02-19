# Abyssal Idle - High-Level Plan

Use this checklist as a living plan. Check items as they ship.

---

## Milestone 1: Core Loop (Playable – Act 1: Village)

Goal: Complete a full playable run with **one fish type**, no morality axis yet.

- [x] Fishing minigame (timing bar) with manual catch.
- [ ] Tin creation flow (process + add ingredients).
- [x] Basic market sell mode toggle (fish vs tins).
- [x] Upgrade list from JSON (buy, cost scaling, levels).
- [ ] Save/load (persist money, inventory, upgrades).
- [ ] Single fish type (no rarity yet).
- [ ] Basic cannery conversion (fish → tins, no branching).
- [ ] First full ending: **Industrial Collapse (1x time)**.
- [ ] End-of-run summary screen.

---

## Milestone 2: Automation Tier 1-2 (Act 2: Expansion)

Goal: Introduce scale + first tension signals. Still no explicit morality tree.

- [x] Add crew trips on main screen (send button, return timer).
- [x] Crew upgrades: faster trips, bigger catches.
- [ ] Optional: multiple crew slots.
- [ ] Optional: crew hiring with stats/specialties.
- [ ] Crew speed upgrades.
- [ ] Crew quality upgrades (better average outcome).
- [ ] Ocean health system (hidden at first, soft warnings only).
- [ ] Fishing pressure scales with automation.
- [ ] Subtle scarcity text feedback.
- [ ] 3 fish types introduced (common/uncommon tiers).
- [ ] Basic quality system (0–3 stars).

---

## Milestone 3: Cannery + Processing Depth (Act 3 Begins)

Goal: Introduce meaningful tradeoffs and visible systems.

- [ ] Processing choices: smoke / ferment / age / skin.
- [ ] Auto-processing stations (single method per station).
- [ ] Ingredient inventory (buy + consume).
- [ ] Ocean health meter becomes visible.
- [ ] Rare fish spawn only if ocean health high.
- [ ] Mutated fish spawn if ocean health low.
- [ ] Collection page (fish discovered, best quality, totals).
- [ ] Achievement tracking (first rare fish, first collapse, etc.).

---

## Milestone 4: Industrial vs Sustainability System

Goal: Introduce playstyle divergence **after** systems are understood.

- [ ] Industrial upgrade branch (speed + output focus).
- [ ] Sustainability upgrade branch (regen + quality focus).
- [ ] Soft tradeoffs (bonus % > penalty % rule).
- [ ] Consequence-driven tech visibility (ocean health gates some upgrades).
- [ ] Market manipulation upgrades (optional 3rd axis).
- [ ] Narrative logs (cozy → unsettling text escalation).

---

## Milestone 5: Endings (3 Total)

Goal: Structured arcs with time scaling.

- [ ] Industrial Ending (1x time) – Ocean collapse via max production.
- [ ] Sustainable Ending (1.5x time) – Maintain equilibrium for duration.
- [ ] Dual Mastery Ending (2–2.5x time) – High production + high health + full biodiversity.
- [ ] Ending summary breakdown (stats, fish discovered, ocean outcome).

---

## Milestone 6: Prestige & New Game+

Goal: Faster subsequent runs + build perfection over time.

- [ ] Prestige trigger (relocate operation).
- [ ] Prestige resource (Knowledge or similar).
- [ ] MetaState system (persistent across runs).
- [ ] Prestige modifiers (increase > decrease rule).
- [ ] New Game+ start bonuses (skip early friction).
- [ ] Faster early pacing on subsequent runs.
- [ ] Oceans visited tracker.
- [ ] Ending unlock tracker.
- [ ] Talent tree (small, wide, friction-reducing).

---

## Milestone 7: Optional Systems (Only After 1 Full Arc Ships)

- [ ] Short expedition choices (risk/reward).
- [ ] Rare resources + story beats.
- [ ] Limited tech slots system (if needed).
- [ ] Biome-weighted tech availability (future expansion).

---

## Milestone 8: Polish

- [ ] UI pass (cards, spacing, visual identity).
- [ ] Audio + sfx.
- [ ] Steam demo build.
- [ ] Achievements (Steam integration).
- [ ] Trailer capture.

---

## Development Guardrails

- Ship **Industrial Ending first** before expanding.
- Add fish rarity only after one full run works.
- Prestige only after 3 endings exist.
- Avoid permanent player lock-in.
- Bonus > penalty in all tradeoff upgrades.
- Keep automation replacing actions, not thinking.
