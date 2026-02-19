POLICY SYSTEM NOTES

Exclusivity
- Policy upgrades use exclusive groups keyed by exclusive_group_id.
- When a policy with exclusive_choice is purchased, chosen_exclusive_groups[group_id] is set to that upgrade_id.
- The requires condition exclusive_group_unchosen is true only if no choice has been recorded for that group.
- The UI still shows the other option but disables purchase, with lock reason "Policy already chosen: <name>".

Stage gating
- Each policy upgrade now includes policy_stage (1..N).
- policy_stage_chosen[group_id] tracks the highest stage purchased for that group.
- The requires condition policy_stage_at_least(group_id, stage) gates later stages (stage N requires stage N-1).

State storage
- chosen_exclusive_groups: Dictionary<String, String>
- policy_stage_chosen: Dictionary<String, int>
- Both are saved in save data and rebuilt for old saves during migration.
