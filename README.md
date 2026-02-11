# recall.nvim

Markdown-based spaced repetition for Neovim. Define flashcards as markdown headings, review them with SM-2 scheduling, all within your editor.

## Features

- **Markdown-native flashcards**: Headings become questions, body text becomes answers
- **Two card modes**: Tag-based (`#flashcard`) or auto-mode (all headings)
- **SM-2 spaced repetition**: Proven algorithm with 4 ratings (Again/Hard/Good/Easy)
- **Clean markdown**: Scheduling data stored in sidecar `.flashcards.json` — your markdown files are never modified
- **Floating window review**: Beautiful review experience via [snacks.nvim](https://github.com/folke/snacks.nvim)
- **Split buffer review**: Alternative review mode using native Neovim splits
- **Deck picker**: Browse and select decks via snacks.nvim picker
- **Statistics**: Track your learning progress
- **Health check**: `:checkhealth recall` to verify setup

## Requirements

- Neovim >= 0.11
- [snacks.nvim](https://github.com/folke/snacks.nvim) (for floating window UI and deck picker)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "Eckii24/recall.nvim",
  dependencies = { "folke/snacks.nvim" },
  config = function()
    require("recall").setup({
      -- your configuration here
    })
  end,
}
```

## Configuration

All options with their defaults:

```lua
require("recall").setup({
  dirs = {},                    -- directories to scan for flashcard files
  auto_mode = false,            -- if true, all headings become cards (no #flashcard tag needed)
  min_heading_level = 2,        -- minimum heading level for auto mode (skips H1, often document title)
  review_mode = "float",        -- "float" (floating window) or "split" (buffer split)
  rating_keys = {               -- keymaps during review
    again = "1",
    hard  = "2",
    good  = "3",
    easy  = "4",
  },
  show_answer_key = "<Space>",  -- key to reveal answer during review
  quit_key = "q",               -- key to quit review
  initial_ease = 2.5,           -- SM-2 initial ease factor
  sidecar_filename = ".flashcards.json",  -- name of sidecar JSON file
})
```

## Card Format

### Tagged Mode (default)

Add `#flashcard` to any heading to make it a flashcard. The heading text is the question, everything below until the next heading of equal or higher level is the answer.

```markdown
# My Study Notes

## What is Neovim? #flashcard

A hyperextensible Vim-based text editor that supports Lua plugins.

## What is Lua? #flashcard

A lightweight, high-level scripting language designed for embedded use.
It's the primary plugin language for Neovim.

## Not a flashcard

This section won't be treated as a flashcard since it lacks the #flashcard tag.
```

### Auto Mode

When `auto_mode = true`, every heading at or below `min_heading_level` becomes a flashcard automatically. No `#flashcard` tag needed.

```lua
require("recall").setup({
  auto_mode = true,
  min_heading_level = 2,  -- H2 and below become cards, H1 is skipped
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:Recall review` | Open deck picker, select a deck to review |
| `:Recall review .` | Scan current working directory and start review |
| `:Recall review <deck>` | Start review for a specific deck by name |
| `:Recall review --dir=<path>` | Scan a specific directory and start review |
| `:Recall stats` | Show learning statistics |
| `:Recall stats .` | Show stats for current directory |
| `:Recall scan` | Scan configured directories and report card counts |
| `:Recall scan .` | Scan current directory and report card counts |

## Review Keymaps

During a review session:

| Key | Action |
|-----|--------|
| `<Space>` | Show answer |
| `1` | Rate: Again (complete lapse) |
| `2` | Rate: Hard (incorrect but close) |
| `3` | Rate: Good (correct with difficulty) |
| `4` | Rate: Easy (perfect recall) |
| `q` | Quit review |

All keys are configurable via the `rating_keys`, `show_answer_key`, and `quit_key` options.

## How It Works

1. **One file = one deck**: Each markdown file is treated as a deck. The filename (without extension) is the deck name.
2. **Heading = question**: Markdown headings become flashcard questions.
3. **Body = answer**: Text between headings becomes the answer.
4. **Sidecar storage**: Scheduling data (ease factor, interval, due date) is stored in `.flashcards.json` alongside each markdown file. Your markdown files are **never modified**.
5. **SM-2 algorithm**: The classic spaced repetition algorithm determines when cards are due for review.

## SM-2 Algorithm

The plugin uses the SM-2 algorithm with Anki-style rating mapping:

- **Again** (quality 0): Complete lapse — reset to interval 1
- **Hard** (quality 2): Incorrect but close — reset to interval 1
- **Good** (quality 3): Correct with difficulty — progress normally
- **Easy** (quality 5): Perfect recall — progress with ease bonus

Intervals progress: 1 day → 6 days → `interval × ease_factor` → ...

The ease factor adjusts based on performance (minimum 1.3).

## Health Check

Run `:checkhealth recall` to verify:

- Neovim version >= 0.11
- snacks.nvim is available
- Configured directories exist
- JSON encoding/decoding works
