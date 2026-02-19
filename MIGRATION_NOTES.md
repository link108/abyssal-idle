MIGRATION NOTES

Requires condition types used
- always
- flag_true
- upgrade_purchased
- upgrade_level_at_least
- exclusive_group_unchosen

Assumptions and mappings
- chain_prev was converted to upgrade_purchased of the previous upgrade in the same category, based on file order. This was applied only to non-exclusive upgrades to preserve the old behavior (chain_prev was ignored for policy pairs).
- Policy pair exclusivity is enforced via exclusive_group_unchosen + exclusive_group_id. The exclusive_group_unchosen condition is new and must be implemented in code.
- pair_stage is removed; its values are only carried into ui.sort_order for UI ordering. Stage-gated unlocking for policies is not represented in requires under the new schema.
