# Issues — recall.nvim

This notepad tracks problems, gotchas, and warnings.

---

## [2026-02-12T19:21:48.539Z] Session Started

No issues yet.

---

## [2026-02-12T23:45:00Z] Bug Fixed in review.lua (Task 10 Integration)

**Issue**: review.lua line 23 called `scheduler.is_due(card.state)` but cards from scanner have state fields directly merged (no `.state` property).

**Root cause**: RecallCardWithState type has `ease`, `interval`, `reps`, `due` as direct fields, not nested in a `state` object.

**Fix**: Changed `scheduler.is_due(card.state)` to `scheduler.is_due(card)` in review.lua line 23.

**Impact**: Direct deck review (`:Recall review deck_name`) now works correctly.

**Prevention**: Type system would catch this (Lua has runtime-only type checking via LuaLS annotations).

### Resolved during Task 12
- Fixed `review.rate` using `source_file` instead of `filepath`.
- Fixed `stats.lua` and `review.lua` passing `card` instead of `card.state` to `scheduler.is_due`.
- Fixed `scanner.lua` flattening card state, which caused mismatches in other modules.
