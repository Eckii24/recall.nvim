# recall.nvim — Missing Functionality Analysis

> **Date:** February 2026
> **Scope:** Feature gap analysis comparing recall.nvim against established spaced repetition tools (Anki, SuperMemo, RemNote, Mochi, Obsidian Spaced Repetition plugin) and community best practices.

---

## Table of Contents

1. [Current Feature Summary](#1-current-feature-summary)
2. [Missing Features — High Priority](#2-missing-features--high-priority)
3. [Missing Features — Medium Priority](#3-missing-features--medium-priority)
4. [Missing Features — Low Priority (Nice-to-Have)](#4-missing-features--low-priority-nice-to-have)
5. [Feature Comparison Matrix](#5-feature-comparison-matrix)
6. [Implementation Proposals](#6-implementation-proposals)
7. [Sources & References](#7-sources--references)

---

## 1. Current Feature Summary

recall.nvim already provides a solid foundation:

| Feature | Status |
|---|---|
| SM-2 spaced repetition algorithm | ✅ Implemented |
| Markdown-based flashcards | ✅ Implemented |
| Tagged (`#flashcard`) and auto mode | ✅ Implemented |
| Clean sidecar JSON storage | ✅ Implemented |
| Three UI modes (float, split, buffer) | ✅ Implemented |
| Basic statistics (total, due, new, mature, young) | ✅ Implemented |
| Session stats (rating breakdown) | ✅ Implemented |
| Deck picker with preview (snacks.nvim) | ✅ Implemented |
| Per-directory configuration | ✅ Implemented |
| Configurable keymaps | ✅ Implemented |
| File mtime caching for performance | ✅ Implemented |

---

## 2. Missing Features — High Priority

These are features considered essential by the broader SRS community, present in nearly all major tools, and would significantly improve recall.nvim's value.

### 2.1 Cloze Deletion Cards

**What it is:** Hide specific parts of a sentence (fill-in-the-blank), forcing recall in context rather than as isolated Q&A pairs. Example:

```markdown
The {{mitochondria}} is the powerhouse of the cell.
```

**Why it matters:** Cloze deletions are one of the most effective card types for learning facts in context. Every major SRS tool (Anki, RemNote, Obsidian SR, Mochi) supports them. They allow users to test granular knowledge within larger statements, which research shows improves contextual recall.

**References:** Anki Manual — Cloze Deletion; Obsidian SR Plugin — Cloze Cards; "Effective Flashcard Techniques for Spaced Repetition" (31memorize.com)

### 2.2 Reverse Cards

**What it is:** Automatically generate a second card with question and answer swapped. Example: if the card is `Capital of France → Paris`, a reverse card would be `Paris → Capital of France`.

**Why it matters:** Bidirectional recall is critical for language learning, vocabulary, and any domain where both directions of association are important. Anki, RemNote, and Obsidian SR all support this via simple syntax markers (`:::` in Obsidian SR).

**Proposal:** Support a syntax marker (e.g., `#flashcard-reverse` or `:::` separator) to auto-generate reverse cards.

### 2.3 Undo Last Rating

**What it is:** Allow the user to undo their most recent card rating during a review session and re-answer it.

**Why it matters:** Misclicks and accidental ratings are common, especially with single-key rating (1-4). Anki provides `Ctrl+Z` undo during review. Without undo, an accidental "Again" on a well-known card can reset its interval, causing frustration.

**Proposal:** Add an undo keymap (e.g., `u`) that reverts the last rating, restores the card's previous scheduling state, and re-shows it.

### 2.4 Bury & Suspend Cards

**What it is:**
- **Bury:** Temporarily hide a card for the rest of the current session (it reappears next time).
- **Suspend:** Remove a card from the review schedule indefinitely until manually unsuspended.

**Why it matters:** Users need to handle cards that are poorly formulated, too easy, temporarily irrelevant, or that they want to skip without affecting scheduling. Both features are core to Anki and widely expected.

**Proposal:**
- Bury: Add a `b` keymap during review. Store buried card hashes in session memory (no persistence needed).
- Suspend: Add an `s` keymap. Store suspended status in the sidecar JSON (`"suspended": true`). Suspended cards are filtered out during deck loading.

### 2.5 Leech Detection

**What it is:** Automatically flag cards that have been rated "Again" repeatedly (e.g., 8+ lapses). These "leeches" often indicate a badly formulated card or genuinely difficult material that needs reformulation.

**Why it matters:** Leeches waste study time. Anki automatically suspends or tags leeches after a configurable threshold. This is a fundamental quality-of-life feature for any serious SRS user.

**Proposal:**
- Track a `lapses` counter in the sidecar JSON (increment on "Again" rating).
- When `lapses` exceeds a configurable threshold (default: 8), show a notification and optionally auto-suspend the card.
- Add a leech tag marker or highlight in the review UI.

### 2.6 Daily Review Limits

**What it is:** Cap the maximum number of new cards and review cards shown per day.

**Why it matters:** Without limits, users with large decks can face overwhelming review queues, leading to burnout and abandonment — the #1 reason people quit SRS tools. Anki defaults to 20 new cards and 200 reviews per day. Configurable limits are considered essential.

**Proposal:**
- Add `max_new_per_day` (default: 20) and `max_reviews_per_day` (default: 200) config options.
- Track daily counts in the sidecar or a separate daily state file.
- Show remaining counts in the review UI.

---

## 3. Missing Features — Medium Priority

These features are present in most mature SRS tools and are frequently requested by the community. They add significant value but are not strictly essential for basic functionality.

### 3.1 FSRS Algorithm (Alternative to SM-2)

**What it is:** The Free Spaced Repetition Scheduler (FSRS) is a modern, machine-learning-based algorithm that models memory with "stability" and "difficulty" per card, predicting forgetting probability more accurately than SM-2.

**Why it matters:** FSRS typically reduces total reviews by 20-30% for equal or better retention. It has become the default in Anki (since v23.10) and is adopted by RemNote and other tools. It's considered the state of the art in SRS scheduling.

**Proposal:**
- Implement FSRS as an alternative scheduler selectable via config (`algorithm = "sm2" | "fsrs"`).
- The FSRS algorithm is open-source ([open-spaced-repetition/fsrs4anki](https://github.com/open-spaced-repetition/fsrs4anki)) and can be ported to Lua.
- Store additional FSRS state fields in the sidecar JSON (`stability`, `difficulty`, `last_review`).

**References:** open-spaced-repetition/fsrs4anki on GitHub; "FSRS vs SM-2" (faqs.ankiweb.net); "FSRS Algorithm: Next-Gen Spaced Repetition" (quizcat.ai)

### 3.2 Learning Steps (Sub-Day Intervals)

**What it is:** New cards and lapsed cards go through short "learning steps" (e.g., 1 min, 10 min, 1 day) before graduating to the regular scheduling algorithm.

**Why it matters:** The current SM-2 implementation starts at a 1-day interval. In reality, new information benefits from being seen multiple times on the first day. Anki's learning steps are configurable (e.g., `1m 10m` for new cards, `10m` for lapses) and are a key component of effective SRS.

**Proposal:**
- Add configurable `learning_steps` (e.g., `{ "1m", "10m" }`) and `lapse_steps` (e.g., `{ "10m" }`).
- Cards in learning phase are tracked with a `step` index and `due_time` (timestamp, not just date).
- Learning cards are re-shown within the same session at the appropriate time.

### 3.3 Tag-Based Filtering and Organization

**What it is:** Allow users to filter reviews by tags, not just by deck/file. For example, review only cards tagged `#anatomy` across all decks.

**Why it matters:** As card collections grow, users need finer-grained control over what they review. Anki's tag system and filtered decks are among its most powerful features. The Obsidian SR plugin supports hierarchical tag-based decks.

**Proposal:**
- Parse existing markdown tags (e.g., `#anatomy`, `#chapter3`) from card content.
- Add a `:Recall review --tag <tag>` command to filter cards by tag across all decks.
- Show tags in the picker UI for quick filtering.

### 3.4 Enhanced Statistics & Visualizations

**What it is:** Richer analytics beyond the current basic counts, including:
- **Review heatmap/calendar** (similar to GitHub contribution graph)
- **Forecast** (upcoming reviews per day)
- **Retention rate** tracking
- **Time spent per card/session**
- **Ease factor distribution**
- **Interval distribution**

**Why it matters:** Detailed stats help users understand their learning patterns, identify problem areas, and stay motivated. Anki's stats page and the popular "Review Heatmap" add-on are among the most valued features. The Obsidian SR community consistently requests better analytics.

**Proposal:**
- Track review history (date, rating, time_taken) in the sidecar JSON or a separate log file.
- Create a `:Recall stats detailed` command showing distributions and charts (rendered as text/ASCII art in the buffer).
- Consider a simple heatmap using Unicode block characters for the last 90 days.

### 3.5 Card Preview / Edit During Review

**What it is:** Jump to the source markdown file of the current card during review to edit it, then return to the review session.

**Why it matters:** When users find a mistake or want to improve a card during review, they should be able to edit it in place. This is especially natural in a Neovim context where file editing is the core workflow. Anki provides an "Edit" button during review.

**Proposal:**
- Add a keymap (e.g., `e`) during review that opens the source file at the card's line number.
- On returning to the review buffer (e.g., via `BufEnter` autocmd), re-parse the card and continue the session.

---

## 4. Missing Features — Low Priority (Nice-to-Have)

These features are found in some SRS tools or are community wishlist items. They add polish but are not critical for core SRS functionality.

### 4.1 Streak Tracking & Gamification

**What it is:** Track consecutive days of review activity, display streaks, and optionally show daily goals.

**Why it matters:** Streaks are powerful motivational tools (used by Duolingo, Anki add-ons, etc.). They leverage loss aversion to build consistent study habits. A simple streak counter is low-effort but high-impact for user engagement.

**Proposal:**
- Track `last_review_date` and `current_streak` in a global state file.
- Show streak count in the stats view and optionally in the review UI footer.

### 4.2 Anki Import/Export

**What it is:** Import cards from Anki `.apkg` files or export recall.nvim cards to Anki-compatible format.

**Why it matters:** Anki has a massive shared deck library. Being able to import from Anki lowers the barrier for users migrating. Several Neovim/Obsidian community threads mention Anki interoperability as a top wish.

**Proposal:**
- Support importing from Anki's CSV/TSV export format (simpler than .apkg).
- Export recall.nvim cards as Anki-compatible CSV with the standard columns (front, back, tags).

### 4.3 Image Support / Rich Media

**What it is:** Display images embedded in markdown cards (e.g., `![diagram](path/to/image.png)`) during review.

**Why it matters:** Image occlusion and visual cards are critical for fields like medicine, geography, and engineering. While Neovim's terminal environment limits image rendering, modern terminals (Kitty, WezTerm, iTerm2) support inline images via protocols like Kitty graphics protocol.

**Proposal:**
- For terminals supporting image protocols, render inline images using Neovim image plugins (e.g., `image.nvim` or `hologram.nvim`).
- For unsupported terminals, show the image path as a clickable link or open in an external viewer.

### 4.4 Multi-Deck Review Session

**What it is:** Review cards from multiple decks in a single session, interleaved randomly.

**Why it matters:** Interleaving study across topics improves learning (a well-established finding in cognitive science). Currently, recall.nvim reviews one deck at a time.

**Proposal:**
- Add `:Recall review --all` or allow multiple deck selection in the picker.
- Merge and shuffle cards from all selected decks into a single review queue.

### 4.5 Card Maturity Indicators in Review

**What it is:** Show visual indicators during review for card state — new, young, mature, leech — using colors or icons.

**Why it matters:** Helps users understand what kind of card they're looking at and set expectations. Anki color-codes cards by type (blue = new, red = learning, green = review).

**Proposal:**
- Add highlight groups or status bar indicators during review showing card maturity.
- Use existing highlight infrastructure in `lua/recall/ui/highlights.lua`.

### 4.6 Keyboard Shortcut to Mark/Flag Cards

**What it is:** Flag or star cards during review for later attention (separate from suspend/bury).

**Why it matters:** Users sometimes want to mark cards for later editing, discussion, or special attention without affecting scheduling.

**Proposal:**
- Add a `f` keymap to toggle a `flagged` boolean in the sidecar JSON.
- Show flagged cards in a separate `:Recall flagged` command.

### 4.7 Custom Review Order Options

**What it is:** Allow users to choose review order: random (current), by due date, by difficulty, new cards first/last, etc.

**Why it matters:** Different study strategies benefit from different orderings. Anki offers several review order options.

**Proposal:**
- Add a `review_order` config option with values like `"random"`, `"due_first"`, `"new_first"`, `"new_last"`, `"difficulty_asc"`.

---

## 5. Feature Comparison Matrix

| Feature | Anki | SuperMemo | RemNote | Obsidian SR | Mochi | **recall.nvim** |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Basic SRS algorithm (SM-2) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| FSRS algorithm | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Cloze deletions | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Reverse cards | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Undo last rating | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Bury (session skip) | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Suspend (indefinite pause) | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Leech detection | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Daily review limits | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ |
| Learning steps (sub-day) | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Tag-based filtering | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Detailed statistics | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ⚠️ |
| Review heatmap | ✅¹ | ❌ | ❌ | ⚠️ | ❌ | ❌ |
| Edit card during review | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ |
| Image support | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Multi-deck sessions | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Streak tracking | ✅¹ | ❌ | ✅ | ⚠️ | ❌ | ❌ |
| Import/export | ✅ | ✅ | ✅ | ⚠️ | ✅ | ❌ |
| Card flags/marks | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Custom review order | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Markdown-native | ❌ | ❌ | ⚠️ | ✅ | ✅ | ✅ |
| Neovim-native | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Clean data separation | ❌ | ❌ | ❌ | ❌ | ⚠️ | ✅ |

> ✅ = Fully supported | ⚠️ = Partially/basic | ❌ = Not supported | ¹ = Via add-on

---

## 6. Implementation Proposals

### Priority Roadmap

The following prioritization considers impact-to-effort ratio, community expectations, and competitive positioning:

#### Phase 1 — Core Review Experience (High Impact, Moderate Effort)
1. **Undo last rating** — Small, self-contained change in `review.lua`; store previous card state before applying rating.
2. **Bury & Suspend** — Bury is session-only (in-memory); Suspend adds a field to sidecar JSON. Both need a keymap in the review UI.
3. **Leech detection** — Add `lapses` counter to sidecar, check threshold after "Again" ratings, notify user.
4. **Daily review limits** — Add config options, track counts, enforce during card queue building.

#### Phase 2 — Card Types (High Impact, Moderate Effort)
5. **Cloze deletion support** — Extend `parser.lua` to recognize `{{...}}` or `==...==` syntax, generate cloze cards with the text replaced by `[...]`.
6. **Reverse cards** — Extend parser to recognize a reverse marker, generate a second card with Q/A swapped.

#### Phase 3 — Scheduling & Analytics (Medium Impact, Higher Effort)
7. **Learning steps** — Requires sub-day scheduling logic, timer integration, and state tracking.
8. **Enhanced statistics** — Track review history, build visualizations (ASCII heatmap, distributions).
9. **FSRS algorithm** — Port the open-source FSRS logic to Lua, add as alternative scheduler.

#### Phase 4 — Workflow & Polish (Lower Impact, Variable Effort)
10. **Tag-based filtering** — Parse tags, add filter command.
11. **Edit card during review** — Open source file, handle buffer lifecycle.
12. **Multi-deck review** — Merge cards from multiple decks.
13. **Streak tracking** — Global state file, streak display.
14. **Card maturity indicators** — UI highlight enhancement.
15. **Custom review order** — Config option for sort strategies.

### Estimated Complexity

| Feature | Files Affected | Estimated Effort |
|---|---|---|
| Undo last rating | `review.lua` | Small (< 50 LOC) |
| Bury | `review.lua` | Small (< 30 LOC) |
| Suspend | `review.lua`, `storage.lua`, `scheduler.lua` | Small–Medium |
| Leech detection | `scheduler.lua`, `storage.lua`, `config.lua` | Small–Medium |
| Daily limits | `config.lua`, `review.lua`, `scheduler.lua` | Medium |
| Cloze deletions | `parser.lua`, `review.lua` | Medium |
| Reverse cards | `parser.lua` | Medium |
| Learning steps | `scheduler.lua`, `review.lua`, `storage.lua` | Medium–Large |
| Enhanced stats | `stats.lua`, new `history.lua` | Medium–Large |
| FSRS algorithm | new `fsrs.lua`, `scheduler.lua`, `config.lua` | Large |
| Tag filtering | `parser.lua`, `picker.lua`, `commands.lua` | Medium |

---

## 7. Sources & References

### SRS Tools Analyzed
- **Anki** — [docs.ankiweb.net](https://docs.ankiweb.net/) / [faqs.ankiweb.net](https://faqs.ankiweb.net/what-spaced-repetition-algorithm.html)
- **SuperMemo** — [supermemo.com](https://www.supermemo.com/)
- **RemNote** — [help.remnote.com](https://help.remnote.com/en/articles/9124137-the-fsrs-spaced-repetition-algorithm)
- **Mochi** — [mochi.cards](https://mochi.cards/)
- **Obsidian Spaced Repetition** — [stephenmwangi.com/obsidian-spaced-repetition](https://stephenmwangi.com/obsidian-spaced-repetition/)

### Research & Community Sources
- "FSRS vs SM-2: The Complete Guide" — [memoforge.app](https://memoforge.app/blog/fsrs-vs-sm2-anki-algorithm-guide-2025/)
- "FSRS Algorithm: Next-Gen Spaced Repetition" — [quizcat.ai](https://www.quizcat.ai/blog/fsrs-algorithm-next-gen-spaced-repetition)
- FSRS Open-Source Implementation — [github.com/open-spaced-repetition/fsrs4anki](https://github.com/open-spaced-repetition/fsrs4anki)
- "Effective Flashcard Techniques for Spaced Repetition" — [31memorize.com](https://www.31memorize.com/post/effective-flashcard-techniques-for-spaced-repetition)
- "Best Spaced Repetition Apps Compared: 2025 Review" — [tegaru.app](https://tegaru.app/en/blog/best-spaced-repetition-apps-compared)
- "Advanced Spaced Repetition Techniques for Power Users" — [tegaru.app](https://tegaru.app/en/blog/advanced-spaced-repetition-techniques)
- "5 Open-Source Spaced Repetition Tools Compared" — [quizcat.ai](https://www.quizcat.ai/blog/5-open-source-spaced-repetition-tools-compared)
- "Top 10 Tools for Spaced Repetition in 2025" — [relearnify.com](https://www.relearnify.com/posts/top-10-tools-to-practice-spaced-repetition)
- "Best Plugins for Spaced Repetition in Obsidian" — [obsidianstats.com](https://www.obsidianstats.com/posts/2025-05-01-spaced-repetition-plugins)
- Reddit r/ObsidianMD — Spaced Repetition plugin discussions
- Reddit r/Anki — Feature discussions and best practices
- "Streaks and Milestones for Gamification" — [plotline.so](https://www.plotline.so/blog/streaks-for-gamification-in-mobile-apps)
- "How to Use Gamification in Spaced Repetition" — [31memorize.com](https://www.31memorize.com/post/how-to-use-gamification-in-spaced-repetition)

---

> **Note:** This analysis is a research document only. No code changes have been implemented. The proposals above are suggestions for future development prioritized by impact and community expectations.
