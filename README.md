# recall.nvim

> A lightweight, markdown-based spaced repetition (Anki-style) plugin for Neovim.

`recall.nvim` allows you to turn your existing markdown notes into a powerful learning system. It uses the **SM-2 algorithm** (the same one used by Anki) to schedule reviews and keeps your notes clean by storing scheduling data in sidecar JSON files.

## ✨ Features

- **Markdown-native**: No special file formats. Use your existing notes.
- **Two Parsing Modes**:
  - **Tagged Mode**: Explicitly mark cards with `#flashcard` in headings.
  - **Auto Mode**: Automatically treat all headings (from a configurable level) as cards.
- **SM-2 Algorithm**: Proven spaced repetition scheduling.
- **Clean Notes**: Scheduling state is stored in a hidden `.flashcards.json` sidecar file next to your markdown.
- **Flexible UI**: Choose between a floating window or a split buffer for reviews.
- **Integrated Stats**: Track your progress across all your decks.
- **Fast**: Scans directories efficiently and uses `mtime` caching.
- **Modern**: Built with Neovim 0.11+ features and [snacks.nvim](https://github.com/folke/snacks.nvim).

## 📋 Requirements

- **Neovim >= 0.11**
- [snacks.nvim](https://github.com/folke/snacks.nvim)

## 📦 Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "matthiaseck/recall.nvim",
  dependencies = { "folke/snacks.nvim" },
  opts = {
    dirs = { "~/notes/decks" }, -- Directories to scan for markdown files
  }
}
```

## ⚙️ Configuration

`recall.nvim` comes with the following defaults:

```lua
{
  dirs = {},                    -- List of directories to scan for markdown files
  auto_mode = false,            -- If true, all headings are treated as cards
  min_heading_level = 2,        -- In auto_mode, skip headings above this level (e.g. skip H1)
  review_mode = "float",        -- UI mode: "float" or "split"
  rating_keys = {
    again = "1",                -- Quality 0: Forgot
    hard  = "2",                -- Quality 2: Hard to remember
    good  = "3",                -- Quality 3: Good recall
    easy  = "4",                -- Quality 5: Perfect recall
  },
  show_answer_key = "<Space>",  -- Key to reveal the answer
  quit_key = "q",               -- Key to quit the review session
  initial_ease = 2.5,           -- Starting ease factor for new cards
  sidecar_filename = ".flashcards.json", -- Name of the sidecar state file
}
```

## 🎯 Usage

### Card Format

Cards are defined by markdown headings. The heading text is the **Question**, and the content until the next heading of equal or higher level is the **Answer**.

#### Tagged Mode (Default)
Add `#flashcard` to any heading to mark it as a card.

```markdown
# My Notes

## What is Neovim? #flashcard

A hyperextensible Vim-based text editor.

## What is SM-2? #flashcard

An algorithm for spaced repetition.
```

#### Auto Mode
Set `auto_mode = true` in your config. Every heading (at or below `min_heading_level`) will be treated as a card.

### Commands

| Command | Description |
| --- | --- |
| `:Recall review` | Open a picker to select a deck and start a review. |
| `:Recall review .` | Scan current directory and start review for a due deck. |
| `:Recall review <name>` | Start review for a specific deck by name (filename). |
| `:Recall stats` | Show statistics across all configured directories. |
| `:Recall scan` | Manually scan configured directories. |
| `:Recall scan <path>` | Scan a specific directory. |

### Review Keymaps

During a review session, use the following keys:

- `<Space>`: Show Answer
- `1`: Rate **Again** (Forgot)
- `2`: Rate **Hard** (Barely remembered)
- `3`: Rate **Good** (Remembered with effort)
- `4`: Rate **Easy** (Perfect recall)
- `q`: Quit session

## 🎓 Example Markdown

```markdown
# Git Mastery

## How to undo last commit? #flashcard

Use `git reset --soft HEAD~1`.

## What is a merge conflict? #flashcard

A conflict that occurs when Git is unable to automatically resolve differences in code between two commits.

### Steps to resolve:
1. Identify files
2. Edit to resolve
3. `git add`
4. `git commit`
```

## 📸 Screenshots

[Add screenshots here]

## 🛠️ Implementation Details

- **Card Identity**: Cards are identified by a hash of their question text. Moving a card within a file preserves its state. Changing the question text creates a "new" card.
- **Sidecar Storage**: State is stored in `.flashcards.json`. You can commit this to git to sync progress across machines, or ignore it if you prefer local-only progress.
- **Performance**: Scanning is only done when needed, and results are cached based on file modification times.
