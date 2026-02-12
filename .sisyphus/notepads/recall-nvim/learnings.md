# Learnings — recall.nvim

This notepad tracks conventions, patterns, and insights discovered during implementation.

---

## [2026-02-12T19:21:48.539Z] Session Started

- Plan: recall-nvim (12 tasks, 6 parallel waves)
- Goal: Build markdown-based spaced repetition plugin for Neovim
- Critical Path: 1 → 2 → 5 → 8 → 10 → 12

---

## [2026-02-12T20:26:00Z] Plugin Structure Implementation Complete

### Directory Structure Created
- ✅ `/lua/recall/init.lua` - Main module entry point
- ✅ `/lua/recall/config.lua` - Configuration with defaults
- ✅ `/plugin/recall.lua` - Plugin initialization with lazy-load guard
- ✅ 9 stub files in `/lua/recall/` (parser, scheduler, storage, scanner, review, picker, stats, commands, health)
- ✅ 2 UI stub files in `/lua/recall/ui/` (float, split)

### Config Module Pattern
- Uses `vim.tbl_deep_extend("force", defaults, opts)` for proper merging
- All defaults hardcoded: `initial_ease=2.5`, `review_mode="float"`, `min_heading_level=2`, `sidecar_filename=".flashcards.json"`
- `M.opts` global state stores merged configuration
- Returns opts from `setup()` for chaining

### Plugin Bootstrap Pattern
- Lazy-load guard: `vim.g.loaded_recall` prevents double-loading
- Command registration: `:Recall` dispatches to `require('recall.commands').dispatch(fargs)`
- Tab-completion returns subcommands: `["review", "add", "remove"]`
- Uses standard `nvim_create_user_command` API

### QA Results
- ✅ Config defaults test: All 4 defaults verified
- ✅ Config merge test: User overrides work correctly
- ✅ Plugin guard test: vim.g.loaded_recall set correctly
- ✅ Command registration test: `:Recall` command exists in nvim_get_commands()

### LSP Diagnostics
- Lua files compile without errors
- Warnings about undefined `vim` global are expected (available at runtime)
- All 14 files have valid Lua syntax

### Key Patterns Learned
1. **RTP Setup**: When testing plugins with `nvim --headless`, use absolute path with `--cmd "set rtp+=/full/path/to/plugin"`
2. **Config Merging**: `vim.tbl_deep_extend()` with "force" strategy properly merges nested tables
3. **Plugin Loading**: Always use lazy-load guard to prevent side effects on double-load
4. **Stub Pattern**: Simple `local M = {} return M` works for module stubs

