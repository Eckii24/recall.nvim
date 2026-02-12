# Decisions — recall.nvim

This notepad tracks architectural choices and design decisions.

---

## [2026-02-12T19:21:48.539Z] Session Started

- **Sidecar storage**: `.flashcards.json` keeps markdown files clean (user preference)
- **Algorithm**: SM-2 with 4 ratings (Again/Hard/Good/Easy)
- **UI**: snacks.nvim for picker + floating windows (no plenary.nvim)
- **Neovim**: 0.11+ minimum (use built-ins: vim.uv, vim.fs, vim.json)
- **Testing**: No automated framework, agent-executed QA only
- **Card identity**: Content hash of question text (rename = new card)
- **Performance**: mtime-based caching for parser

---
