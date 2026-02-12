# recall.nvim — Markdown-Based Spaced Repetition for Neovim

## TL;DR

> **Quick Summary**: Build `recall.nvim`, a standalone Neovim plugin that parses heading-based flashcards from markdown files and implements SM-2 spaced repetition with a polished review experience via snacks.nvim. No existing Neovim plugin offers native markdown flashcards + spaced repetition + in-editor review.
>
> **Deliverables**:
> - Complete Neovim plugin: `recall.nvim` with full plugin structure
> - Markdown parser for heading-based flashcard extraction
> - SM-2 spaced repetition scheduler
> - Sidecar `.flashcards.json` storage (keeps markdown clean)
> - Floating window review mode (primary) + split buffer mode
> - Deck picker via snacks.nvim
> - Simple learning statistics
> - `:Recall` command with subcommands (review, stats, scan)
> - Health check (`:checkhealth recall`)
> - README.md with usage documentation
>
> **Estimated Effort**: Large
> **Parallel Execution**: YES — 3 waves
> **Critical Path**: Task 1 (config) → Task 2 (parser) → Task 3 (scheduler) → Task 4 (storage) → Task 5 (scanner) → Task 6 (review) → Task 7 (float UI) → Task 8 (picker) → Task 9 (commands)

---

## Context

### Original Request
User wants a Neovim plugin for flashcards with spaced repetition. Cards should be markdown-based (heading = question, body = answer). The plugin should support repetitive learning via the SM-2 algorithm with a clean review UI.

### Interview Summary
**Key Discussions**:
- **Card format**: Heading-based with `#flashcard` tag OR automatic mode where all headings in a configured folder become cards
- **Metadata**: Separate `.flashcards.json` (user strongly prefers clean markdown files)
- **Algorithm**: SM-2 with 4 ratings (Again/Hard/Good/Easy)
- **UI modes**: All three (floating, split, in-file fold) should be available, user picks via config. Floating window is primary.
- **Dependencies**: snacks.nvim for picker and UI windows. No plenary.nvim (use Neovim 0.11 built-ins).
- **Decks**: One file = one deck. Filename = deck name.
- **Review start**: Subcommands — `:Recall review` (picker), `:Recall review <deck>`, `:Recall review .` (cwd)
- **Stats**: Simple — due today, total cards, progress
- **Card creation**: Purely manual, no wizards
- **Tests**: No automated test framework; agent-executed QA only
- **Neovim**: 0.11+ minimum (bleeding edge)
- **Scan dirs**: Configurable defaults + command param override

**Research Findings**:
- **No competing plugin**: All existing Neovim flashcard plugins either require Anki (neoanki, nvimanki, anki.nvim) or lack spaced repetition (flashcards.nvim with 27 stars, JSON-only)
- **SM-2 is ~50 LOC in Lua**: Well-documented, `EF' = EF + (0.1 - (5-q) * (0.08 + (5-q) * 0.02))`, intervals `I(1)=1, I(2)=6, I(n)=I(n-1)*EF`
- **Obsidian SR plugin** (2.2k stars): Validates heading-based format, uses `::` separators and `#flashcard` tag — confirms the approach
- **NeuraCache markdown spec** (50 stars): Shows standardized markdown flashcard conventions
- **snacks.nvim**: Confirmed stable APIs — `Snacks.win()` for floating windows, `Snacks.picker.pick()` for deck selection, `Snacks.notify()` for feedback

### Metis Review
**Identified Gaps** (all addressed):
- **Rating mapping**: Resolved with Anki-style mapping (Again→0, Hard→2, Good→3, Easy→5)
- **Card identity**: Resolved with content-hash of question text. Rename = new card.
- **Auto-mode heading levels**: Resolved with configurable `min_heading_level` (default: 2)
- **Session state on quit**: Resolved — ratings saved immediately, no session resume
- **Concurrency**: Last-write-wins, single instance expected
- **Fold-based review**: Deferred to Phase 4 (stretch goal)
- **Atomic JSON writes**: Write to `.tmp` then `os.rename()` to prevent corruption
- **Code block skipping**: Parser must skip fenced code blocks and YAML frontmatter
- **Performance caching**: Use file mtime to avoid re-parsing unchanged files

---

## Work Objectives

### Core Objective
Build `recall.nvim` — a standalone, markdown-native spaced repetition plugin for Neovim 0.11+ that lets users define flashcards as markdown headings and review them with SM-2 scheduling, all within the editor.

### Concrete Deliverables
- GitHub-ready plugin directory with standard Neovim plugin structure
- Markdown parser extracting heading-based cards (with `#flashcard` tag or auto-mode)
- SM-2 scheduler (pure Lua, no dependencies)
- `.flashcards.json` sidecar storage with atomic writes
- Floating window review UI via `Snacks.win()`
- Split buffer review UI
- Deck picker via `Snacks.picker.pick()`
- Simple statistics display
- `:Recall` command with `review`, `stats`, `scan` subcommands
- Health check module
- README.md

### Definition of Done
- [ ] `:Recall review` opens deck picker, selecting a deck starts floating window review with card display and 4-button rating
- [ ] Cards are scheduled according to SM-2 algorithm (intervals verified)
- [ ] `.flashcards.json` is created/updated next to markdown files with scheduling data
- [ ] Markdown files remain completely untouched (no inline metadata)
- [ ] `:Recall stats` shows due count, total cards, review progress
- [ ] `:checkhealth recall` passes all checks

### Must Have
- Heading-based card parsing with `#flashcard` tag support
- Auto-mode: all headings in configured folders become cards
- SM-2 algorithm with 4 ratings (Again/Hard/Good/Easy)
- Sidecar `.flashcards.json` for scheduling data
- Floating window review mode
- Split buffer review mode
- snacks.nvim deck picker
- Simple stats
- Subcommand dispatch (`:Recall review`, `:Recall stats`, `:Recall scan`)
- Health check
- Atomic JSON writes (`.tmp` + rename)
- Skip code blocks and YAML frontmatter in parser

### Must NOT Have (Guardrails)
- NO inline metadata in markdown files (no HTML comments, no frontmatter additions)
- NO cloze deletions in v1
- NO reversed cards in v1
- NO Anki import/export
- NO FSRS algorithm (v1 is SM-2 only)
- NO card creation wizards/templates
- NO cloud sync or mobile support
- NO plenary.nvim dependency (use Neovim 0.11 built-ins: `vim.uv`, `vim.fs`, `vim.json`)
- NO eager file scanning on plugin load (scan only on command invocation)
- NO custom UI primitives (use `Snacks.win` and `Snacks.picker` exclusively)

---

## Verification Strategy (MANDATORY)

> **UNIVERSAL RULE: ZERO HUMAN INTERVENTION**
>
> ALL tasks in this plan MUST be verifiable WITHOUT any human action.
> Every criterion is verified by the agent using tools (tmux for Neovim headless commands, Bash for file checks).

### Test Decision
- **Infrastructure exists**: NO (new repo, no test framework)
- **Automated tests**: None (user decision)
- **Framework**: N/A

### Agent-Executed QA Scenarios (MANDATORY — ALL tasks)

Every task includes QA scenarios using:
- `nvim --headless -c "lua ..."` for Lua module verification
- `bash` for file system checks (JSON existence, content validation)
- `tmux` + `nvim` for interactive UI verification (floating windows, picker)

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately):
├── Task 1: Project Setup + Config Module
└── (sequential foundation — all else depends on this)

Wave 2 (After Task 1):
├── Task 2: Markdown Parser
├── Task 3: SM-2 Scheduler
└── Task 4: Sidecar Storage

Wave 3 (After Wave 2):
├── Task 5: Scanner (depends: 2, 4)
└── Task 6: Review State Machine (depends: 3)

Wave 4 (After Wave 3):
├── Task 7: Floating Window UI (depends: 6)
├── Task 8: Deck Picker (depends: 5)
└── Task 9: Stats Module (depends: 5)

Wave 5 (After Wave 4):
├── Task 10: Command Dispatch + Health Check (depends: 7, 8, 9)
└── Task 11: Split Buffer UI (depends: 6)

Wave 6 (After Wave 5):
└── Task 12: README + Vimdoc + Final Integration

Critical Path: 1 → 2 → 5 → 8 → 10 → 12
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 2, 3, 4 | None |
| 2 | 1 | 5 | 3, 4 |
| 3 | 1 | 6 | 2, 4 |
| 4 | 1 | 5 | 2, 3 |
| 5 | 2, 4 | 8, 9 | 6 |
| 6 | 3 | 7, 11 | 5 |
| 7 | 6 | 10 | 8, 9 |
| 8 | 5 | 10 | 7, 9 |
| 9 | 5 | 10 | 7, 8 |
| 10 | 7, 8, 9 | 12 | 11 |
| 11 | 6 | 12 | 10 |
| 12 | 10, 11 | None | None (final) |

### Agent Dispatch Summary

| Wave | Tasks | Recommended Agents |
|------|-------|--------------------|
| 1 | 1 | `task(category="quick", load_skills=[], ...)` |
| 2 | 2, 3, 4 | 3 parallel `task(category="quick", ...)` |
| 3 | 5, 6 | 2 parallel `task(category="unspecified-low", ...)` |
| 4 | 7, 8, 9 | 3 parallel `task(category="unspecified-high", ...)` |
| 5 | 10, 11 | 2 parallel `task(category="unspecified-low", ...)` |
| 6 | 12 | `task(category="writing", ...)` |

---

## TODOs

---

- [x] 1. Project Setup + Config Module

  **What to do**:
  - Create the full plugin directory structure:
    ```
    recall.nvim/
    ├── lua/
    │   └── recall/
    │       ├── init.lua
    │       ├── config.lua
    │       ├── parser.lua        (stub)
    │       ├── scheduler.lua     (stub)
    │       ├── storage.lua       (stub)
    │       ├── scanner.lua       (stub)
    │       ├── review.lua        (stub)
    │       ├── picker.lua        (stub)
    │       ├── stats.lua         (stub)
    │       ├── commands.lua      (stub)
    │       ├── health.lua        (stub)
    │       └── ui/
    │           ├── float.lua     (stub)
    │           └── split.lua     (stub)
    └── plugin/
        └── recall.lua
    ```
  - Implement `lua/recall/config.lua` with defaults and validation:
    ```lua
    local defaults = {
      dirs = {},                    -- directories to scan for flashcard files
      auto_mode = false,            -- if true, all headings become cards (no #flashcard needed)
      min_heading_level = 2,        -- skip H1 in auto mode (often document title)
      review_mode = "float",        -- "float" | "split"
      rating_keys = {               -- keymaps during review
        again = "1",
        hard  = "2",
        good  = "3",
        easy  = "4",
      },
      show_answer_key = "<Space>",  -- key to reveal answer
      quit_key = "q",               -- key to quit review
      initial_ease = 2.5,           -- SM-2 initial ease factor
      sidecar_filename = ".flashcards.json",
    }
    ```
  - Use `vim.tbl_deep_extend("force", defaults, opts or {})` for config merging
  - Implement `lua/recall/init.lua` with `M.setup(opts)` that calls `config.setup(opts)` and stores global state
  - Implement `plugin/recall.lua` with lazy-load guard (`if vim.g.loaded_recall then return end`) — just register the `:Recall` command that dispatches to `require('recall.commands').dispatch(fargs)` with tab-completion
  - All stub files should return an empty module `local M = {} return M`

  **Must NOT do**:
  - Do NOT implement any actual logic in stub files (just `local M = {} return M`)
  - Do NOT add plenary.nvim as dependency
  - Do NOT scan files on plugin load

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Straightforward boilerplate creation with well-defined structure
  - **Skills**: `[]`
    - No special skills needed — standard file creation
  - **Skills Evaluated but Omitted**:
    - `frontend-ui-ux`: Not applicable — this is Lua boilerplate, not visual UI

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1 (solo)
  - **Blocks**: Tasks 2, 3, 4, and all subsequent
  - **Blocked By**: None (first task)

  **References**:

  **Pattern References** (existing code to follow):
  - Standard Neovim plugin structure: `lua/<plugin>/init.lua` + `plugin/<plugin>.lua` — follow patterns from folke/snacks.nvim, folke/lazy.nvim
  - Subcommand dispatch pattern: `vim.api.nvim_create_user_command('Recall', function(opts) require('recall.commands').dispatch(opts.fargs) end, { nargs = '*', complete = function(_, line) ... end })`
  - Config merge pattern: `vim.tbl_deep_extend("force", defaults, opts or {})`
  - Lazy-load guard: `if vim.g.loaded_recall then return end; vim.g.loaded_recall = true`

  **External References**:
  - Neovim plugin development guide: https://neovim.io/doc/user/lua-guide.html#lua-guide-plugin
  - snacks.nvim as reference for modern plugin structure: https://github.com/folke/snacks.nvim

  **Acceptance Criteria**:

  **Agent-Executed QA Scenarios:**

  ```
  Scenario: Plugin directory structure is complete
    Tool: Bash
    Preconditions: recall.nvim directory created
    Steps:
      1. ls -la recall.nvim/lua/recall/ → verify all .lua files exist
      2. ls -la recall.nvim/plugin/ → verify recall.lua exists
      3. ls -la recall.nvim/lua/recall/ui/ → verify float.lua and split.lua exist
    Expected Result: All 14 Lua files present in correct directories
    Evidence: Directory listing output

  Scenario: Config module returns valid defaults
    Tool: Bash (nvim --headless)
    Preconditions: Plugin files exist
    Steps:
      1. nvim --headless --noplugin -u NONE \
           --cmd "set rtp+=recall.nvim" \
           -c "lua local c = require('recall.config'); c.setup({}); assert(c.opts.initial_ease == 2.5); assert(c.opts.review_mode == 'float'); assert(c.opts.min_heading_level == 2); print('CONFIG OK')" \
           -c "qa!"
      2. Assert stdout contains "CONFIG OK"
    Expected Result: Default config values are correct
    Evidence: stdout output

  Scenario: Config merges user overrides correctly
    Tool: Bash (nvim --headless)
    Steps:
      1. nvim --headless --noplugin -u NONE \
           --cmd "set rtp+=recall.nvim" \
           -c "lua local c = require('recall.config'); c.setup({review_mode='split', initial_ease=3.0}); assert(c.opts.review_mode == 'split'); assert(c.opts.initial_ease == 3.0); assert(c.opts.min_heading_level == 2); print('MERGE OK')" \
           -c "qa!"
    Expected Result: User overrides applied, defaults preserved for non-overridden keys
    Evidence: stdout output

  Scenario: Plugin lazy-load guard works
    Tool: Bash (nvim --headless)
    Steps:
      1. nvim --headless --noplugin -u NONE \
           --cmd "set rtp+=recall.nvim" \
           -c "runtime plugin/recall.lua" \
           -c "lua assert(vim.g.loaded_recall == true); print('GUARD OK')" \
           -c "qa!"
    Expected Result: vim.g.loaded_recall is set to true
    Evidence: stdout output

  Scenario: Recall command is registered
    Tool: Bash (nvim --headless)
    Steps:
      1. nvim --headless --noplugin -u NONE \
           --cmd "set rtp+=recall.nvim" \
           -c "runtime plugin/recall.lua" \
           -c "lua local cmds = vim.api.nvim_get_commands({}); assert(cmds['Recall'] ~= nil); print('CMD OK')" \
           -c "qa!"
    Expected Result: :Recall command exists
    Evidence: stdout output
  ```

  **Commit**: YES
  - Message: `feat(recall): scaffold plugin structure with config module`
  - Files: `recall.nvim/**`
  - Pre-commit: QA scenarios above

---

- [x] 2. Markdown Parser

  **What to do**:
  - Implement `lua/recall/parser.lua` as a **pure function** module
  - Main function: `M.parse(lines, opts) → cards[]`
    - `lines`: array of strings (file content split by newline)
    - `opts`: `{ auto_mode = bool, min_heading_level = int }`
    - Returns: array of card objects `{ question = string, answer = string, line_number = int, heading_level = int, id = string }`
  - Card detection logic:
    1. **Tagged mode** (default): A heading line containing `#flashcard` anywhere becomes a card. The heading text (minus the `#flashcard` tag) is the question.
    2. **Auto mode**: Every heading at or below `min_heading_level` becomes a card. The heading text is the question.
  - Answer extraction: All text from the line after the heading until the next heading of same or higher level (or end of file). Trim leading/trailing blank lines.
  - **Card ID**: SHA-like hash of the question text (use simple string hash — `vim.fn.sha256()` or a basic djb2 hash in pure Lua). This ID links the card to its scheduling data in the sidecar JSON.
  - **Must skip**:
    - YAML frontmatter (lines between `---` at start of file)
    - Fenced code blocks (lines between ``` markers)
    - Headings inside code blocks
  - Handle edge cases:
    - Empty answer (heading with no body text)
    - Multiple `#flashcard` tags on one line (treat as one card)
    - `#flashcard` as part of a word (e.g., `#flashcards`) — should NOT match (word boundary)
    - Heading with only `#flashcard` tag and no question text → skip
  - The `#flashcard` tag should be stripped from the question text in the returned card object

  **Must NOT do**:
  - Do NOT read files from disk (pure function — takes string array input)
  - Do NOT access vim API for file operations
  - Do NOT parse cloze syntax
  - Do NOT handle reversed cards

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single-file implementation with clear input/output contract, algorithmic but not complex
  - **Skills**: `[]`
  - **Skills Evaluated but Omitted**:
    - `frontend-ui-ux`: Not applicable — pure data transformation

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 3 and 4)
  - **Blocks**: Task 5 (scanner)
  - **Blocked By**: Task 1 (project setup)

  **References**:

  **Pattern References**:
  - Obsidian SR parser approach: heading text = question, body = answer, `#flashcard` tag marks cards
  - Lua pattern matching: `line:match("^(#+)%s+(.+)")` to extract heading level and text
  - YAML frontmatter detection: first line is `---`, scan until next `---`
  - Code block detection: line starts with `` ``` `` (toggle in/out of code block state)

  **API/Type References**:
  - Card type contract:
    ```lua
    ---@class RecallCard
    ---@field question string      -- heading text (without #flashcard tag)
    ---@field answer string        -- body text below heading
    ---@field line_number integer  -- 1-based line of the heading
    ---@field heading_level integer -- 1-6
    ---@field id string            -- hash of question text
    ```

  **External References**:
  - Lua string patterns: https://www.lua.org/pil/20.2.html
  - `vim.fn.sha256(str)` for card ID generation

  **Acceptance Criteria**:

  **Agent-Executed QA Scenarios:**

  ```
  Scenario: Parse tagged flashcards from markdown
    Tool: Bash (nvim --headless)
    Preconditions: Parser module implemented, test markdown content prepared inline
    Steps:
      1. nvim --headless --noplugin -u NONE \
           --cmd "set rtp+=recall.nvim" \
           -c "lua
             local p = require('recall.parser')
             local lines = {
               '# Document Title',
               '',
               '## What is Lua? #flashcard',
               '',
               'A lightweight scripting language.',
               'Used in Neovim plugins.',
               '',
               '## Not a card',
               '',
               'Just some text.',
               '',
               '### How does SM-2 work? #flashcard',
               '',
               'It uses an ease factor formula.',
             }
             local cards = p.parse(lines, { auto_mode = false })
             assert(#cards == 2, 'Expected 2 cards, got ' .. #cards)
             assert(cards[1].question == 'What is Lua?', 'Q1 wrong: ' .. cards[1].question)
             assert(cards[1].answer:find('lightweight scripting'), 'A1 missing content')
             assert(cards[1].heading_level == 2)
             assert(cards[1].line_number == 3)
             assert(cards[2].question == 'How does SM-2 work?')
             assert(cards[2].heading_level == 3)
             print('PARSE TAGGED OK')
           " -c "qa!"
    Expected Result: 2 cards parsed with correct question, answer, level, line number
    Evidence: stdout output

  Scenario: Parse auto-mode flashcards (all headings)
    Tool: Bash (nvim --headless)
    Steps:
      1. nvim --headless --noplugin -u NONE \
           --cmd "set rtp+=recall.nvim" \
           -c "lua
             local p = require('recall.parser')
             local lines = {
               '# Title',
               '',
               '## Topic A',
               'Answer A',
               '',
               '## Topic B',
               'Answer B',
               '',
               '### Subtopic B1',
               'Answer B1',
             }
             local cards = p.parse(lines, { auto_mode = true, min_heading_level = 2 })
             assert(#cards == 3, 'Expected 3 cards, got ' .. #cards)
             assert(cards[1].question == 'Topic A')
             assert(cards[2].question == 'Topic B')
             assert(cards[3].question == 'Subtopic B1')
             print('PARSE AUTO OK')
           " -c "qa!"
    Expected Result: 3 cards (H1 skipped due to min_heading_level=2)
    Evidence: stdout output

  Scenario: Skip YAML frontmatter and code blocks
    Tool: Bash (nvim --headless)
    Steps:
      1. nvim --headless --noplugin -u NONE \
           --cmd "set rtp+=recall.nvim" \
           -c 'lua
             local p = require("recall.parser")
             local lines = {
               "---",
               "title: My Notes",
               "---",
               "",
               "## Real card #flashcard",
               "Real answer",
               "",
               "```markdown",
               "## Fake heading inside code #flashcard",
               "```",
               "",
               "## Another real card #flashcard",
               "Another answer",
             }
             local cards = p.parse(lines, { auto_mode = false })
             assert(#cards == 2, "Expected 2 cards, got " .. #cards)
             assert(cards[1].question == "Real card")
             assert(cards[2].question == "Another real card")
             print("SKIP OK")
           ' -c "qa!"
    Expected Result: 2 cards (frontmatter and code block headings skipped)
    Evidence: stdout output

  Scenario: Card ID is deterministic
    Tool: Bash (nvim --headless)
    Steps:
      1. Parse same content twice, assert card IDs are identical
      2. Parse different content, assert card IDs differ
    Expected Result: Same question → same ID, different question → different ID
    Evidence: stdout output
  ```

  **Commit**: YES
  - Message: `feat(parser): implement heading-based flashcard extraction`
  - Files: `recall.nvim/lua/recall/parser.lua`
  - Pre-commit: QA scenarios above

---

- [x] 3. SM-2 Scheduler

  **What to do**:
  - Implement `lua/recall/scheduler.lua` as a **pure function** module
  - Main function: `M.schedule(card_state, rating) → new_card_state`
    - `card_state`: `{ ease = number, interval = number, reps = number, due = string }`
    - `rating`: one of `"again"`, `"hard"`, `"good"`, `"easy"`
    - Returns: new card_state with updated values
  - Rating-to-quality mapping (Anki-style):
    - `again` → quality 0 (complete lapse)
    - `hard` → quality 2 (incorrect but close)
    - `good` → quality 3 (correct with difficulty)
    - `easy` → quality 5 (perfect recall)
  - SM-2 algorithm implementation:
    ```
    if quality < 3:
        interval = 1
        reps = 0
    else:
        if reps == 0: interval = 1
        elif reps == 1: interval = 6
        else: interval = ceil(interval * ease)
        reps = reps + 1
    
    ease = ease + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))
    ease = max(1.3, ease)
    due = today + interval days
    ```
  - Helper function: `M.new_card() → card_state` — returns initial state `{ ease = 2.5, interval = 0, reps = 0, due = today }`
  - Helper function: `M.is_due(card_state) → boolean` — true if `card_state.due <= today`
  - Date handling: Use `os.date("%Y-%m-%d")` for ISO date strings, `os.time()` for calculations

  **Must NOT do**:
  - Do NOT implement FSRS
  - Do NOT implement Leitner system
  - Do NOT access file system or vim APIs (pure math/logic only)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single-file, algorithmic, well-defined math with clear test cases
  - **Skills**: `[]`
  - **Skills Evaluated but Omitted**:
    - `ultrabrain`: Overkill — SM-2 is a simple formula, not a complex logic puzzle

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 2 and 4)
  - **Blocks**: Task 6 (review state machine)
  - **Blocked By**: Task 1 (project setup)

  **References**:

  **Pattern References**:
  - SM-2 algorithm paper: E-Factor formula, interval progression
  - Python SM-2 implementation: `supermemo2` package on PyPI — same formula in Python for cross-reference

  **External References**:
  - Original SM-2 algorithm: https://super-memory.com/english/ol/sm2.htm
  - Anki's 4-button mapping: Again→0, Hard→2, Good→3, Easy→5

  **Acceptance Criteria**:

  **Agent-Executed QA Scenarios:**

  ```
  Scenario: New card rated "good" gets interval=1, reps=1
    Tool: Bash (nvim --headless)
    Steps:
      1. nvim --headless --noplugin -u NONE \
           --cmd "set rtp+=recall.nvim" \
           -c "lua
             local s = require('recall.scheduler')
             local card = s.new_card()
             local result = s.schedule(card, 'good')
             assert(result.interval == 1, 'interval should be 1, got ' .. result.interval)
             assert(result.reps == 1, 'reps should be 1, got ' .. result.reps)
             assert(result.ease == 2.5, 'ease should stay 2.5')
             print('NEW GOOD OK')
           " -c "qa!"
    Expected Result: First "good" review → interval 1, reps 1, ease unchanged
    Evidence: stdout output

  Scenario: Second "good" review gets interval=6
    Tool: Bash (nvim --headless)
    Steps:
      1. nvim --headless --noplugin -u NONE \
           --cmd "set rtp+=recall.nvim" \
           -c "lua
             local s = require('recall.scheduler')
             local card = { ease = 2.5, interval = 1, reps = 1, due = '2026-01-01' }
             local result = s.schedule(card, 'good')
             assert(result.interval == 6, 'interval should be 6, got ' .. result.interval)
             assert(result.reps == 2)
             print('SECOND GOOD OK')
           " -c "qa!"
    Expected Result: Second "good" → interval 6
    Evidence: stdout output

  Scenario: Third "good" review calculates interval * ease
    Tool: Bash (nvim --headless)
    Steps:
      1. nvim --headless --noplugin -u NONE \
           --cmd "set rtp+=recall.nvim" \
           -c "lua
             local s = require('recall.scheduler')
             local card = { ease = 2.5, interval = 6, reps = 2, due = '2026-01-01' }
             local result = s.schedule(card, 'good')
             assert(result.interval == 15, 'interval should be ceil(6*2.5)=15, got ' .. result.interval)
             assert(result.reps == 3)
             print('THIRD GOOD OK')
           " -c "qa!"
    Expected Result: ceil(6 × 2.5) = 15
    Evidence: stdout output

  Scenario: "again" rating resets interval and reps
    Tool: Bash (nvim --headless)
    Steps:
      1. nvim --headless --noplugin -u NONE \
           --cmd "set rtp+=recall.nvim" \
           -c "lua
             local s = require('recall.scheduler')
             local card = { ease = 2.5, interval = 15, reps = 3, due = '2026-01-01' }
             local result = s.schedule(card, 'again')
             assert(result.interval == 1, 'interval should reset to 1')
             assert(result.reps == 0, 'reps should reset to 0')
             assert(result.ease >= 1.3, 'ease should not go below 1.3')
             print('AGAIN OK')
           " -c "qa!"
    Expected Result: Lapse resets interval=1, reps=0
    Evidence: stdout output

  Scenario: Ease factor has floor of 1.3
    Tool: Bash (nvim --headless)
    Steps:
      1. Rate "again" repeatedly until ease would drop below 1.3
      2. Assert ease never goes below 1.3
    Expected Result: Ease factor bottoms out at 1.3
    Evidence: stdout output

  Scenario: is_due returns true for past/today dates, false for future
    Tool: Bash (nvim --headless)
    Steps:
      1. Test with due = today → true
      2. Test with due = yesterday → true
      3. Test with due = tomorrow → false
    Expected Result: Correct due-date comparison
    Evidence: stdout output
  ```

  **Commit**: YES
  - Message: `feat(scheduler): implement SM-2 spaced repetition algorithm`
  - Files: `recall.nvim/lua/recall/scheduler.lua`
  - Pre-commit: QA scenarios above

---

- [x] 4. Sidecar JSON Storage

  **What to do**:
  - Implement `lua/recall/storage.lua`
  - Main functions:
    - `M.load(json_path) → data_table` — read and parse `.flashcards.json`, return empty `{ cards = {} }` if file doesn't exist
    - `M.save(json_path, data_table)` — serialize to JSON and write atomically (write to `.tmp`, then `os.rename()`)
    - `M.get_card_state(data, card_id) → card_state|nil` — lookup a card's scheduling state by ID
    - `M.set_card_state(data, card_id, card_state)` — update a card's scheduling state
    - `M.sidecar_path(md_file_path) → json_path` — given a markdown file path, return the path to its sidecar JSON (same directory, filename from config default `.flashcards.json`)
  - JSON structure:
    ```json
    {
      "version": 1,
      "cards": {
        "<card_id>": {
          "ease": 2.5,
          "interval": 6,
          "reps": 2,
          "due": "2026-02-15",
          "source_file": "algorithms.md",
          "question_preview": "What is binary search?"
        }
      }
    }
    ```
  - Use `vim.json.encode()` / `vim.json.decode()` (Neovim built-in, no deps)
  - Use `vim.uv.fs_open()`, `vim.uv.fs_write()`, `vim.uv.fs_close()` for file I/O, or simpler `io.open()`/`io.close()` with atomic rename via `vim.uv.fs_rename()` or `os.rename()`
  - Handle errors gracefully: corrupted JSON → warn user, return empty state, do NOT crash

  **Must NOT do**:
  - Do NOT use SQLite
  - Do NOT modify markdown files
  - Do NOT store scheduling data inline

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single-file, straightforward I/O with JSON serialization
  - **Skills**: `[]`
  - **Skills Evaluated but Omitted**:
    - None applicable

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 2 and 3)
  - **Blocks**: Task 5 (scanner)
  - **Blocked By**: Task 1 (project setup)

  **References**:

  **Pattern References**:
  - Atomic file writes: write to `path .. ".tmp"` then `os.rename(tmp_path, path)` — POSIX atomic on same filesystem
  - Neovim JSON: `vim.json.encode(tbl)` returns string, `vim.json.decode(str)` returns table

  **External References**:
  - `vim.json` docs: https://neovim.io/doc/user/lua.html#vim.json
  - `vim.uv` (libuv bindings): https://neovim.io/doc/user/lua.html#vim.uv

  **Acceptance Criteria**:

  **Agent-Executed QA Scenarios:**

  ```
  Scenario: Save and load round-trip preserves data
    Tool: Bash (nvim --headless)
    Steps:
      1. nvim --headless --noplugin -u NONE \
           --cmd "set rtp+=recall.nvim" \
           -c "lua
             local st = require('recall.storage')
             local data = { version = 1, cards = { abc123 = { ease = 2.5, interval = 6, reps = 2, due = '2026-02-15' } } }
             st.save('/tmp/test_recall.json', data)
             local loaded = st.load('/tmp/test_recall.json')
             assert(loaded.version == 1)
             assert(loaded.cards.abc123.ease == 2.5)
             assert(loaded.cards.abc123.interval == 6)
             assert(loaded.cards.abc123.due == '2026-02-15')
             os.remove('/tmp/test_recall.json')
             print('ROUND TRIP OK')
           " -c "qa!"
    Expected Result: Data survives save/load cycle
    Evidence: stdout output

  Scenario: Load returns empty state for missing file
    Tool: Bash (nvim --headless)
    Steps:
      1. nvim --headless --noplugin -u NONE \
           --cmd "set rtp+=recall.nvim" \
           -c "lua
             local st = require('recall.storage')
             local data = st.load('/tmp/nonexistent_recall.json')
             assert(data.cards ~= nil)
             assert(next(data.cards) == nil)
             print('MISSING FILE OK')
           " -c "qa!"
    Expected Result: Returns `{ cards = {} }` without error
    Evidence: stdout output

  Scenario: Atomic write prevents corruption (tmp file used)
    Tool: Bash
    Steps:
      1. Check that during save, a .tmp file is created before the final file
      2. After save, verify no .tmp file remains
      3. Verify final .json file is valid JSON
    Expected Result: Atomic write pattern confirmed
    Evidence: File system check output

  Scenario: Corrupted JSON handled gracefully
    Tool: Bash (nvim --headless)
    Steps:
      1. Write invalid JSON to /tmp/corrupt.json (e.g., "not json at all")
      2. Call st.load('/tmp/corrupt.json')
      3. Assert returns empty state, no crash
    Expected Result: Returns default empty state, logs warning
    Evidence: stdout output
  ```

  **Commit**: YES
  - Message: `feat(storage): implement sidecar JSON storage with atomic writes`
  - Files: `recall.nvim/lua/recall/storage.lua`
  - Pre-commit: QA scenarios above

---

- [x] 5. File Scanner

  **What to do**:
  - Implement `lua/recall/scanner.lua`
  - Main functions:
    - `M.scan(dirs, opts) → decks[]` — scan directories for markdown files, parse each for cards, merge with sidecar scheduling data
    - `M.scan_file(filepath, opts) → deck` — scan a single file
    - `M.scan_cwd(opts) → decks[]` — scan current working directory
  - Deck structure:
    ```lua
    ---@class RecallDeck
    ---@field name string          -- filename without extension
    ---@field filepath string      -- full path to markdown file
    ---@field cards RecallCardWithState[]
    ---@field total integer
    ---@field due integer          -- cards due today
    ```
  - For each markdown file found:
    1. Read file content with `vim.fn.readfile(filepath)` or `io.lines()`
    2. Call `parser.parse(lines, opts)` to extract cards
    3. Call `storage.load(sidecar_path)` to get scheduling data
    4. Merge: for each parsed card, look up its ID in the sidecar data. If found, attach scheduling state. If not found (new card), create initial state.
    5. Return deck with card count and due count
  - **Performance**: Cache parsed results per file using `mtime`. Store cache in memory (Lua table). Only re-parse files whose `mtime` changed.
  - Use `vim.fs.find()` with `{ type = 'file', limit = math.huge }` to find `.md` files
  - Use `vim.uv.fs_stat(path).mtime` for modification time checking

  **Must NOT do**:
  - Do NOT scan recursively into deeply nested directories without limit
  - Do NOT scan on plugin load (only on explicit command)
  - Do NOT modify any files during scan

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
    - Reason: Orchestration logic combining parser + storage, moderate complexity
  - **Skills**: `[]`
  - **Skills Evaluated but Omitted**:
    - None applicable

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Task 6)
  - **Blocks**: Tasks 8 (picker), 9 (stats)
  - **Blocked By**: Tasks 2 (parser), 4 (storage)

  **References**:

  **Pattern References**:
  - `vim.fs.find('*.md', { path = dir, type = 'file', limit = math.huge })` for file discovery
  - `vim.uv.fs_stat(path)` returns `{ mtime = { sec = ..., nsec = ... } }` for caching

  **API/Type References**:
  - Uses `parser.parse()` from Task 2
  - Uses `storage.load()`, `storage.sidecar_path()` from Task 4
  - Uses `scheduler.new_card()`, `scheduler.is_due()` from Task 3

  **Acceptance Criteria**:

  **Agent-Executed QA Scenarios:**

  ```
  Scenario: Scan directory finds markdown files and parses cards
    Tool: Bash (nvim --headless)
    Preconditions: Create test directory with 2 markdown files containing flashcards
    Steps:
      1. mkdir -p /tmp/recall_test && write two .md files with #flashcard headings
      2. nvim --headless --noplugin -u NONE \
           --cmd "set rtp+=recall.nvim" \
           -c "lua
             local scanner = require('recall.scanner')
             local decks = scanner.scan({'/tmp/recall_test'}, { auto_mode = false })
             assert(#decks == 2, 'Expected 2 decks')
             assert(decks[1].total > 0, 'Deck should have cards')
             print('SCAN OK')
           " -c "qa!"
      3. rm -rf /tmp/recall_test
    Expected Result: 2 decks found with correct card counts
    Evidence: stdout output

  Scenario: New cards get initial scheduling state
    Tool: Bash (nvim --headless)
    Steps:
      1. Scan directory with no existing .flashcards.json
      2. Assert all cards have initial ease=2.5, interval=0, reps=0, due=today
    Expected Result: New cards initialized correctly
    Evidence: stdout output

  Scenario: Existing scheduling data is merged
    Tool: Bash (nvim --headless)
    Steps:
      1. Create .flashcards.json with known card state
      2. Scan same directory
      3. Assert card has the stored scheduling state (not initial)
    Expected Result: Existing card state preserved from sidecar
    Evidence: stdout output
  ```

  **Commit**: YES
  - Message: `feat(scanner): implement directory scanning with mtime caching`
  - Files: `recall.nvim/lua/recall/scanner.lua`
  - Pre-commit: QA scenarios above

---

- [x] 6. Review State Machine

  **What to do**:
  - Implement `lua/recall/review.lua`
  - This module manages the **review session logic**, decoupled from any UI rendering
  - Main functions:
    - `M.new_session(deck) → session` — create a review session from a deck. Filter to only due cards. Shuffle order.
    - `M.current_card(session) → card|nil` — return the current card to review, or nil if session complete
    - `M.show_answer(session)` — mark current card as "answer revealed"
    - `M.rate(session, rating) → card_state` — rate current card, compute new scheduling state via `scheduler.schedule()`, advance to next card
    - `M.is_complete(session) → boolean`
    - `M.progress(session) → { current = int, total = int, remaining = int }`
  - Session structure:
    ```lua
    ---@class RecallSession
    ---@field deck RecallDeck
    ---@field queue RecallCardWithState[]  -- due cards in review order
    ---@field current_index integer
    ---@field answer_shown boolean
    ---@field results { card_id: string, rating: string, old_state: CardState, new_state: CardState }[]
    ```
  - When `rate()` is called:
    1. Compute new state via `scheduler.schedule(card.state, rating)`
    2. Store the rating result
    3. Immediately persist via `storage.save()` (ratings are saved immediately, not batched)
    4. Advance `current_index`
  - **On quit mid-session**: Already-rated cards are saved (immediate persist). Unreviewed cards remain due for next session. No session resume concept.

  **Must NOT do**:
  - Do NOT render any UI (no `vim.api.nvim_open_win`, no buffer manipulation)
  - Do NOT handle keymaps
  - This module is purely data/state management

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
    - Reason: State machine logic, moderate complexity, clear contract
  - **Skills**: `[]`
  - **Skills Evaluated but Omitted**:
    - None applicable

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Task 5)
  - **Blocks**: Tasks 7 (float UI), 11 (split UI)
  - **Blocked By**: Task 3 (scheduler)

  **References**:

  **API/Type References**:
  - Uses `scheduler.schedule(card_state, rating)` from Task 3
  - Uses `storage.save()` from Task 4
  - Consumed by `ui/float.lua` (Task 7) and `ui/split.lua` (Task 11)

  **Pattern References**:
  - State machine pattern: `session.current_index` tracks position, `rate()` advances index
  - Anki review flow: show question → user action → show answer → user rates → next card

  **Acceptance Criteria**:

  **Agent-Executed QA Scenarios:**

  ```
  Scenario: Session filters to only due cards
    Tool: Bash (nvim --headless)
    Steps:
      1. Create deck with 5 cards: 3 due, 2 not due
      2. Create session, assert queue has exactly 3 cards
    Expected Result: Only due cards in review queue
    Evidence: stdout output

  Scenario: Rate advances to next card
    Tool: Bash (nvim --headless)
    Steps:
      1. Create session with 3 due cards
      2. Assert current_card() returns card 1
      3. Call show_answer(), then rate("good")
      4. Assert current_card() returns card 2
      5. Rate remaining cards
      6. Assert is_complete() returns true
    Expected Result: Session progresses through all cards
    Evidence: stdout output

  Scenario: Progress tracking is accurate
    Tool: Bash (nvim --headless)
    Steps:
      1. Session with 5 due cards
      2. Rate 2 cards
      3. Assert progress() returns { current = 3, total = 5, remaining = 3 }
    Expected Result: Progress reflects reviewed count
    Evidence: stdout output

  Scenario: Rating persists immediately to storage
    Tool: Bash (nvim --headless)
    Steps:
      1. Create session, rate one card
      2. Load sidecar JSON, verify the card's state was updated
    Expected Result: Sidecar JSON updated after each rating
    Evidence: stdout output + file content check
  ```

  **Commit**: YES
  - Message: `feat(review): implement review session state machine`
  - Files: `recall.nvim/lua/recall/review.lua`
  - Pre-commit: QA scenarios above

---

- [x] 7. Floating Window Review UI

  **What to do**:
  - Implement `lua/recall/ui/float.lua`
  - This module creates the visual review experience using `Snacks.win()`
  - Main function: `M.start(session)` — open floating window and drive the review
  - UI Layout:
    ```
    ╭───────────── recall.nvim ──────────────╮
    │                                         │
    │  Deck: algorithms.md                    │
    │  Card 3 / 12                            │
    │                                         │
    │  ─────────────────────────────          │
    │                                         │
    │  ## What is binary search?              │
    │                                         │
    │                                         │
    │         [Space] Show Answer              │
    │                                         │
    ╰─────────────────────────────────────────╯
    ```
  - After answer reveal:
    ```
    ╭───────────── recall.nvim ──────────────╮
    │                                         │
    │  Deck: algorithms.md                    │
    │  Card 3 / 12                            │
    │                                         │
    │  ─────────────────────────────          │
    │                                         │
    │  ## What is binary search?              │
    │                                         │
    │  A divide-and-conquer algorithm that    │
    │  searches a sorted array by repeatedly  │
    │  halving the search interval.           │
    │                                         │
    │  ─────────────────────────────          │
    │                                         │
    │  [1] Again  [2] Hard  [3] Good  [4] Easy│
    │                                         │
    ╰─────────────────────────────────────────╯
    ```
  - Use `Snacks.win()` with:
    - `position = "float"`, `width = 0.7`, `height = 0.7`
    - `border = "rounded"`
    - `bo = { filetype = "markdown", modifiable = false }`
    - `title = " recall.nvim "`
    - Dynamic keymaps via `keys` table
  - Set buffer content via `vim.api.nvim_buf_set_lines(win.buf, 0, -1, false, lines)`
  - Update content dynamically: question view → answer view → next card
  - Keymaps:
    - `<Space>` or configured key → reveal answer (calls `session:show_answer()`, re-renders)
    - `1`/`2`/`3`/`4` or configured keys → rate (calls `session:rate(rating)`, loads next card or closes if done)
    - `q` → quit review (close window)
  - On session complete: show summary in the same window ("Review complete! 12 cards reviewed. Next review: 3 cards tomorrow.") then close on any key.
  - Set `filetype = "markdown"` on the buffer so that Treesitter/syntax highlighting works for markdown content in the cards.

  **Must NOT do**:
  - Do NOT implement split mode here (that's Task 11)
  - Do NOT implement fold mode
  - Do NOT build custom floating window primitives (use Snacks.win exclusively)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: UI work requiring snacks.nvim API knowledge, dynamic buffer updates, keymap management
  - **Skills**: `[]`
  - **Skills Evaluated but Omitted**:
    - `frontend-ui-ux`: This is terminal UI, not web UI. snacks.nvim handles rendering.

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 8, 9)
  - **Blocks**: Task 10 (command dispatch)
  - **Blocked By**: Task 6 (review state machine)

  **References**:

  **Pattern References**:
  - snacks.nvim `Snacks.win()` API for floating windows with custom content and keymaps
  - Buffer content update: `vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines_table)`
  - Markdown rendering: set `bo.filetype = "markdown"` for Treesitter highlighting

  **External References**:
  - snacks.nvim docs: https://github.com/folke/snacks.nvim/blob/main/docs/win.md
  - Neovim floating window API: `vim.api.nvim_open_win()` (used internally by Snacks.win)

  **Acceptance Criteria**:

  **Agent-Executed QA Scenarios:**

  ```
  Scenario: Floating window opens with question content
    Tool: interactive_bash (tmux)
    Preconditions: recall.nvim installed, test flashcard .md file exists
    Steps:
      1. tmux new-session: nvim --cmd "set rtp+=recall.nvim" test_cards.md
      2. Wait for Neovim to load (timeout: 5s)
      3. Execute: :lua require('recall.ui.float').start(mock_session)
      4. Assert: floating window visible (check vim.api.nvim_list_wins() count > 1)
      5. Assert: buffer content contains question text
      6. Screenshot: .sisyphus/evidence/task-7-float-open.png
    Expected Result: Floating window appears with question
    Evidence: .sisyphus/evidence/task-7-float-open.png

  Scenario: Space reveals answer
    Tool: interactive_bash (tmux)
    Steps:
      1. With floating window open showing question
      2. Send keys: Space
      3. Assert: buffer content now contains answer text
      4. Assert: rating keybinds hint visible ("[1] Again [2] Hard [3] Good [4] Easy")
    Expected Result: Answer appears after Space
    Evidence: Terminal output captured

  Scenario: Rating advances to next card
    Tool: interactive_bash (tmux)
    Steps:
      1. With answer shown
      2. Send keys: 3 (Good)
      3. Assert: window now shows next card's question
      4. Assert: previous card not visible
    Expected Result: Next card displayed after rating
    Evidence: Terminal output

  Scenario: Session completion shows summary
    Tool: interactive_bash (tmux)
    Steps:
      1. Rate all cards in session
      2. Assert: summary message displayed ("Review complete!")
      3. Send any key
      4. Assert: window closes (win count back to 1)
    Expected Result: Summary shown, then window closes
    Evidence: Terminal output

  Scenario: Quit key closes review
    Tool: interactive_bash (tmux)
    Steps:
      1. With review window open
      2. Send keys: q
      3. Assert: window closes, no error
    Expected Result: Clean exit on q
    Evidence: Terminal output
  ```

  **Commit**: YES
  - Message: `feat(ui): implement floating window review mode`
  - Files: `recall.nvim/lua/recall/ui/float.lua`
  - Pre-commit: QA scenarios above

---

- [ ] 8. Deck Picker (snacks.nvim)

  **What to do**:
  - Implement `lua/recall/picker.lua`
  - Main function: `M.pick_deck(decks, on_select)` — show a snacks.nvim picker listing all decks
  - Use `Snacks.picker.pick()` with:
    - Items: list of decks with `text = deck.name`, `data = deck`
    - Format: Show deck name + due count + total count (e.g., `"algorithms.md  [5 due / 20 total]"`)
    - Preview: Show first few cards from the deck as markdown preview
    - Confirm action: Call `on_select(deck)` with the chosen deck
    - Sort: Decks with most due cards first
  - Helper: `M.pick_and_review(opts)` — convenience function that:
    1. Calls `scanner.scan(dirs, opts)` to get decks
    2. Filters to decks with at least 1 due card (optionally show all)
    3. Opens picker
    4. On selection, creates review session and starts the configured UI mode

  **Must NOT do**:
  - Do NOT implement custom picker UI (use snacks.nvim exclusively)
  - Do NOT add telescope.nvim support

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Requires snacks.nvim picker API knowledge, formatting, preview rendering
  - **Skills**: `[]`
  - **Skills Evaluated but Omitted**:
    - `frontend-ui-ux`: Not web UI

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 7, 9)
  - **Blocks**: Task 10 (command dispatch)
  - **Blocked By**: Task 5 (scanner)

  **References**:

  **Pattern References**:
  - snacks.nvim picker: `Snacks.picker.pick({ items = ..., format = "text", confirm = function(picker, item) ... end })`

  **External References**:
  - snacks.nvim picker docs: https://github.com/folke/snacks.nvim/blob/main/docs/picker.md

  **Acceptance Criteria**:

  **Agent-Executed QA Scenarios:**

  ```
  Scenario: Picker shows available decks with due counts
    Tool: interactive_bash (tmux)
    Preconditions: Test directory with 3 markdown files, some with due cards
    Steps:
      1. Open Neovim, trigger picker via Lua
      2. Assert: picker window opens
      3. Assert: deck names visible with due/total counts
      4. Assert: decks sorted by due count (most first)
    Expected Result: Picker displays all decks with stats
    Evidence: Terminal output

  Scenario: Selecting a deck starts review
    Tool: interactive_bash (tmux)
    Steps:
      1. Open picker
      2. Navigate to a deck, press Enter
      3. Assert: picker closes, floating review window opens
    Expected Result: Review starts after deck selection
    Evidence: Terminal output
  ```

  **Commit**: YES
  - Message: `feat(picker): implement deck picker via snacks.nvim`
  - Files: `recall.nvim/lua/recall/picker.lua`
  - Pre-commit: QA scenarios above

---

- [ ] 9. Statistics Module

  **What to do**:
  - Implement `lua/recall/stats.lua`
  - Main functions:
    - `M.compute(decks) → stats` — compute statistics across all decks
    - `M.deck_stats(deck) → deck_stats` — compute statistics for a single deck
    - `M.display(stats)` — show stats in a floating `Snacks.win()` or via `Snacks.notify()`
  - Stats to compute:
    ```lua
    ---@class RecallStats
    ---@field total_cards integer
    ---@field due_today integer
    ---@field new_cards integer       -- cards never reviewed
    ---@field reviewed_today integer  -- cards reviewed today
    ---@field mature_cards integer    -- cards with interval > 21 days
    ---@field young_cards integer     -- cards with interval 1-21 days
    ---@field decks_summary { name: string, total: int, due: int }[]
    ```
  - Display format (simple text in floating window or echo):
    ```
    📊 recall.nvim Statistics
    ─────────────────────────
    Total cards:     142
    Due today:        12
    New cards:         5
    Reviewed today:    8
    ─────────────────────────
    Mature (>21d):   89
    Young (1-21d):   48

    Decks:
      algorithms.md    [3 due / 45 total]
      data-structures  [5 due / 32 total]
      ...
    ```

  **Must NOT do**:
  - Do NOT implement charts, heatmaps, or visual graphs (simple text only)
  - Do NOT track historical review data (only current state)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
    - Reason: Straightforward data aggregation + simple display
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 7, 8)
  - **Blocks**: Task 10 (command dispatch)
  - **Blocked By**: Task 5 (scanner)

  **References**:

  **Pattern References**:
  - Stats computation: iterate decks, count cards by state
  - Display via `Snacks.win()` or `vim.api.nvim_echo()`

  **Acceptance Criteria**:

  **Agent-Executed QA Scenarios:**

  ```
  Scenario: Stats computation returns correct counts
    Tool: Bash (nvim --headless)
    Steps:
      1. Create mock decks with known card states
      2. Call stats.compute(decks)
      3. Assert total_cards, due_today, new_cards match expected
    Expected Result: All counts accurate
    Evidence: stdout output

  Scenario: Stats display renders without error
    Tool: interactive_bash (tmux)
    Steps:
      1. Open Neovim with test data
      2. Call stats.display(computed_stats)
      3. Assert: floating window or echo shows stats text
      4. Assert: contains "Total cards:", "Due today:"
    Expected Result: Stats displayed cleanly
    Evidence: Terminal output
  ```

  **Commit**: YES
  - Message: `feat(stats): implement simple learning statistics`
  - Files: `recall.nvim/lua/recall/stats.lua`
  - Pre-commit: QA scenarios above

---

- [ ] 10. Command Dispatch + Health Check

  **What to do**:
  - Implement `lua/recall/commands.lua`:
    - `M.dispatch(args)` — route subcommands:
      - `review` → open deck picker, then start review
      - `review <deck_name>` → start review for specific deck
      - `review .` → scan cwd, then start review
      - `review --dir=<path>` → scan specific directory
      - `stats` → show statistics
      - `scan` → scan configured dirs and report card counts
    - `M.complete(arg_lead, cmd_line, cursor_pos) → string[]` — tab-completion for subcommands and deck names
  - Update `plugin/recall.lua` to connect the `:Recall` command to `commands.dispatch()`
  - Implement `lua/recall/health.lua`:
    - `M.check()` — health check function using `vim.health` API:
      - Check Neovim version ≥ 0.11 → `vim.health.ok()` or `vim.health.error()`
      - Check snacks.nvim available → `pcall(require, 'snacks')` → ok/error
      - Check configured directories exist → `vim.fn.isdirectory()` → ok/warn
      - Check `.flashcards.json` writability → attempt write test → ok/warn

  **Must NOT do**:
  - Do NOT add commands beyond review/stats/scan in v1
  - Do NOT implement interactive prompts (all via subcommands)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
    - Reason: Wiring/integration task, moderate complexity
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 5 (with Task 11)
  - **Blocks**: Task 12 (final integration)
  - **Blocked By**: Tasks 7, 8, 9

  **References**:

  **Pattern References**:
  - Subcommand dispatch: `vim.api.nvim_create_user_command('Recall', function(opts) require('recall.commands').dispatch(opts.fargs) end, { nargs = '*', complete = function(arg_lead, line, pos) return require('recall.commands').complete(arg_lead, line, pos) end })`
  - Health check: `vim.health.start('recall')`, `vim.health.ok('...')`, `vim.health.error('...')`

  **External References**:
  - Neovim health check docs: https://neovim.io/doc/user/health.html
  - Neovim user commands: https://neovim.io/doc/user/api.html#nvim_create_user_command()

  **Acceptance Criteria**:

  **Agent-Executed QA Scenarios:**

  ```
  Scenario: :Recall review opens picker
    Tool: interactive_bash (tmux)
    Steps:
      1. Open Neovim with recall.nvim loaded and configured dirs
      2. Execute :Recall review
      3. Assert: picker window opens showing decks
    Expected Result: Picker displayed
    Evidence: Terminal output

  Scenario: :Recall stats shows statistics
    Tool: interactive_bash (tmux)
    Steps:
      1. Open Neovim with recall.nvim and flashcard files
      2. Execute :Recall stats
      3. Assert: stats display appears with card counts
    Expected Result: Stats rendered
    Evidence: Terminal output

  Scenario: Tab-completion works for subcommands
    Tool: interactive_bash (tmux)
    Steps:
      1. Type :Recall <Tab>
      2. Assert: completion menu shows "review", "stats", "scan"
    Expected Result: Subcommands complete
    Evidence: Terminal output

  Scenario: :checkhealth recall passes
    Tool: Bash (nvim --headless)
    Steps:
      1. nvim --headless --noplugin -u NONE \
           --cmd "set rtp+=recall.nvim" \
           -c "lua vim.g.loaded_recall = true" \
           -c "checkhealth recall" \
           -c "qa!"
      2. Assert output contains "OK" for Neovim version check
    Expected Result: Health check runs without crash
    Evidence: stdout output
  ```

  **Commit**: YES
  - Message: `feat(commands): implement subcommand dispatch and health check`
  - Files: `recall.nvim/lua/recall/commands.lua`, `recall.nvim/lua/recall/health.lua`, `recall.nvim/plugin/recall.lua`
  - Pre-commit: QA scenarios above

---

- [ ] 11. Split Buffer Review UI

  **What to do**:
  - Implement `lua/recall/ui/split.lua`
  - Main function: `M.start(session)` — open a vertical or horizontal split for review
  - Layout: Create a new buffer in a split. Render question first, then answer on reveal.
  - Reuse the same keymap logic as float UI (Space to reveal, 1-4 to rate, q to quit)
  - Use standard Neovim split commands: `vim.cmd('vsplit')` or `vim.cmd('split')`, then set buffer content
  - Set `filetype = "markdown"` for syntax highlighting
  - Make buffer `nomodifiable`, `nofile`, `bufhidden=wipe`
  - Share review logic with `review.lua` — only the rendering differs

  **Must NOT do**:
  - Do NOT implement fold-based review (that's Phase 4 stretch)
  - Do NOT use snacks.nvim for split (use native Neovim splits)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
    - Reason: Similar to float UI but simpler (native splits), can reference float implementation
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 5 (with Task 10)
  - **Blocks**: Task 12 (final integration)
  - **Blocked By**: Task 6 (review state machine)

  **References**:

  **Pattern References**:
  - Float UI (Task 7): Same review flow, just different window type
  - Neovim split: `vim.cmd('botright split')`, then `vim.api.nvim_set_current_buf(buf)`
  - Buffer options: `vim.bo[buf].buftype = 'nofile'`, `vim.bo[buf].bufhidden = 'wipe'`, `vim.bo[buf].filetype = 'markdown'`

  **Acceptance Criteria**:

  **Agent-Executed QA Scenarios:**

  ```
  Scenario: Split review opens in new window
    Tool: interactive_bash (tmux)
    Steps:
      1. Open Neovim, trigger split review
      2. Assert: window count increases by 1
      3. Assert: new window shows question content
    Expected Result: Split window with card content
    Evidence: Terminal output

  Scenario: Split review follows same flow as float
    Tool: interactive_bash (tmux)
    Steps:
      1. Press Space → answer appears
      2. Press 3 (Good) → next card appears
      3. Complete all cards → summary shown
      4. Press any key → split closes
    Expected Result: Same review flow as floating mode
    Evidence: Terminal output
  ```

  **Commit**: YES
  - Message: `feat(ui): implement split buffer review mode`
  - Files: `recall.nvim/lua/recall/ui/split.lua`
  - Pre-commit: QA scenarios above

---

- [ ] 12. README + Vimdoc + Final Integration

  **What to do**:
  - Create `recall.nvim/README.md` with:
    - Plugin description and motivation
    - Features list
    - Requirements (Neovim 0.11+, snacks.nvim)
    - Installation (lazy.nvim config example)
    - Configuration (all options with defaults)
    - Card format documentation (heading-based, `#flashcard` tag, auto-mode)
    - Commands documentation (`:Recall review`, `:Recall stats`, `:Recall scan`)
    - Keymaps during review
    - Example markdown file with flashcards
    - Screenshots/GIFs placeholder
  - Create `recall.nvim/doc/recall.txt` — vimdoc format help file:
    - `:help recall` entry point
    - All commands, config options, card format documented
  - Create `.gitignore` (ignore `.flashcards.json` in the plugin repo itself)
  - Final integration test: verify full flow end-to-end (create test cards → scan → pick deck → review → rate → verify JSON updated)

  **Must NOT do**:
  - Do NOT add badges, CI/CD, or GitHub Actions in v1
  - Do NOT create a LICENSE file (user can add later)

  **Recommended Agent Profile**:
  - **Category**: `writing`
    - Reason: Documentation-heavy task with technical writing
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 6 (solo, final)
  - **Blocks**: None (last task)
  - **Blocked By**: Tasks 10, 11

  **References**:

  **Pattern References**:
  - README format: follow folke plugin README style (features list, lazy.nvim setup, config defaults, commands)
  - Vimdoc: follow `:help write-plugin` format with tags

  **External References**:
  - Vimdoc guide: https://neovim.io/doc/user/usr_41.html#write-plugin
  - Example README: https://github.com/folke/snacks.nvim/blob/main/README.md

  **Acceptance Criteria**:

  **Agent-Executed QA Scenarios:**

  ```
  Scenario: README contains all required sections
    Tool: Bash
    Steps:
      1. grep for "Installation", "Configuration", "Commands", "Card Format" in README.md
      2. Assert all sections present
    Expected Result: All documentation sections exist
    Evidence: grep output

  Scenario: Vimdoc is loadable
    Tool: Bash (nvim --headless)
    Steps:
      1. nvim --headless --noplugin -u NONE \
           --cmd "set rtp+=recall.nvim" \
           -c "helptags recall.nvim/doc" \
           -c "help recall" \
           -c "qa!"
      2. Assert no error
    Expected Result: :help recall works
    Evidence: stdout output

  Scenario: End-to-end flow works
    Tool: interactive_bash (tmux)
    Preconditions: recall.nvim fully assembled, test flashcard directory created
    Steps:
      1. Create test directory with markdown flashcard files
      2. Open Neovim with recall.nvim configured to scan test dir
      3. Run :Recall scan → verify card count reported
      4. Run :Recall review → picker opens → select deck → review opens
      5. Review 2-3 cards with ratings
      6. Quit review
      7. Verify .flashcards.json was created with scheduling data
      8. Run :Recall stats → verify stats display
    Expected Result: Complete flow works without errors
    Evidence: Terminal output + .flashcards.json content
  ```

  **Commit**: YES
  - Message: `docs(recall): add README, vimdoc, and verify end-to-end flow`
  - Files: `recall.nvim/README.md`, `recall.nvim/doc/recall.txt`, `recall.nvim/.gitignore`
  - Pre-commit: QA scenarios above

---

## Commit Strategy

| After Task | Message | Key Files | Verification |
|------------|---------|-----------|--------------|
| 1 | `feat(recall): scaffold plugin structure with config module` | lua/recall/*.lua, plugin/recall.lua | Config defaults, command registered |
| 2 | `feat(parser): implement heading-based flashcard extraction` | lua/recall/parser.lua | Parse tagged + auto mode |
| 3 | `feat(scheduler): implement SM-2 spaced repetition algorithm` | lua/recall/scheduler.lua | Interval calculations correct |
| 4 | `feat(storage): implement sidecar JSON storage with atomic writes` | lua/recall/storage.lua | Round-trip, atomic write |
| 5 | `feat(scanner): implement directory scanning with mtime caching` | lua/recall/scanner.lua | Scan + merge scheduling data |
| 6 | `feat(review): implement review session state machine` | lua/recall/review.lua | Session flow, immediate persist |
| 7 | `feat(ui): implement floating window review mode` | lua/recall/ui/float.lua | Float opens, rates, closes |
| 8 | `feat(picker): implement deck picker via snacks.nvim` | lua/recall/picker.lua | Picker shows decks, triggers review |
| 9 | `feat(stats): implement simple learning statistics` | lua/recall/stats.lua | Correct counts, display works |
| 10 | `feat(commands): implement subcommand dispatch and health check` | lua/recall/commands.lua, health.lua | :Recall works, :checkhealth passes |
| 11 | `feat(ui): implement split buffer review mode` | lua/recall/ui/split.lua | Split review flow matches float |
| 12 | `docs(recall): add README, vimdoc, and verify end-to-end flow` | README.md, doc/recall.txt | E2E flow, help tags |

---

## Success Criteria

### Verification Commands
```bash
# Full end-to-end test sequence:
# 1. Create test flashcard file
mkdir -p /tmp/recall_test
cat > /tmp/recall_test/test.md << 'EOF'
# Test Deck

## What is Neovim? #flashcard

A hyperextensible Vim-based text editor.

## What is Lua? #flashcard

A lightweight scripting language used in Neovim.
EOF

# 2. Verify parser
nvim --headless --noplugin -u NONE \
  --cmd "set rtp+=recall.nvim" \
  -c "lua local p = require('recall.parser'); local cards = p.parse(vim.fn.readfile('/tmp/recall_test/test.md'), {}); assert(#cards == 2); print('PARSER OK')" \
  -c "qa!"

# 3. Verify scheduler
nvim --headless --noplugin -u NONE \
  --cmd "set rtp+=recall.nvim" \
  -c "lua local s = require('recall.scheduler'); local c = s.new_card(); local r = s.schedule(c, 'good'); assert(r.interval == 1); print('SCHEDULER OK')" \
  -c "qa!"

# 4. Verify storage
nvim --headless --noplugin -u NONE \
  --cmd "set rtp+=recall.nvim" \
  -c "lua local st = require('recall.storage'); st.save('/tmp/recall_test/.flashcards.json', {version=1,cards={}}); local d = st.load('/tmp/recall_test/.flashcards.json'); assert(d.version == 1); print('STORAGE OK')" \
  -c "qa!"

# 5. Verify health check
nvim --headless --noplugin -u NONE \
  --cmd "set rtp+=recall.nvim" \
  -c "checkhealth recall" \
  -c "qa!"

# Cleanup
rm -rf /tmp/recall_test
```

### Final Checklist
- [ ] `:Recall review` opens deck picker → selecting deck starts floating window review
- [ ] `:Recall review .` scans cwd for flashcard files
- [ ] `:Recall stats` shows due count, total cards, deck breakdown
- [ ] `:Recall scan` reports card counts per file
- [ ] `:checkhealth recall` passes all checks
- [ ] `.flashcards.json` created next to markdown files after first review
- [ ] Markdown files are NEVER modified by the plugin
- [ ] SM-2 intervals are correct (1 → 6 → 15 → ...)
- [ ] Both floating and split review modes work
- [ ] All keymaps functional during review (Space, 1-4, q)
- [ ] README.md documents all features, commands, and config
- [ ] `:help recall` works with vimdoc
