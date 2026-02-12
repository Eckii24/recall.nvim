local M = {}

local scheduler = require("recall.scheduler")

---@class RecallCardWithState
---@field state table { ease: number, interval: integer, reps: integer, due: string }

---@class RecallStats
---@field total_cards integer
---@field due_today integer
---@field new_cards integer       -- cards never reviewed (reps=0)
---@field reviewed_today integer  -- cards reviewed today
---@field mature_cards integer    -- cards with interval > 21 days
---@field young_cards integer     -- cards with interval 1-21 days
---@field decks_summary { name: string, total: integer, due: integer }[]

---@class RecallDeckStats
---@field total integer
---@field due integer
---@field new_cards integer
---@field mature_cards integer
---@field young_cards integer

--- Get today's date as ISO 8601 string
local function get_today()
  return os.date("%Y-%m-%d")
end

--- Compute statistics for a single deck
--- @param deck RecallDeck Deck with cards array
--- @return RecallDeckStats Deck statistics
function M.deck_stats(deck)
  local stats = {
    total = 0,
    due = 0,
    new_cards = 0,
    mature_cards = 0,
    young_cards = 0,
  }

  for _, card in ipairs(deck.cards) do
    stats.total = stats.total + 1

    -- Count due cards
    if scheduler.is_due(card.state) then
      stats.due = stats.due + 1
    end

    -- Count new cards (never reviewed)
    if card.state.reps == 0 then
      stats.new_cards = stats.new_cards + 1
    end

    -- Count mature cards (interval > 21 days)
    if card.state.interval > 21 then
      stats.mature_cards = stats.mature_cards + 1
    end

    -- Count young cards (interval 1-21 days)
    if card.state.interval >= 1 and card.state.interval <= 21 then
      stats.young_cards = stats.young_cards + 1
    end
  end

  return stats
end

--- Compute statistics across all decks
--- @param decks RecallDeck[] Array of decks
--- @return RecallStats Aggregate statistics
function M.compute(decks)
  local stats = {
    total_cards = 0,
    due_today = 0,
    new_cards = 0,
    reviewed_today = 0,
    mature_cards = 0,
    young_cards = 0,
    decks_summary = {},
  }

  local today = get_today()

  for _, deck in ipairs(decks) do
    local deck_stat = M.deck_stats(deck)

    -- Aggregate totals
    stats.total_cards = stats.total_cards + deck_stat.total
    stats.due_today = stats.due_today + deck_stat.due
    stats.new_cards = stats.new_cards + deck_stat.new_cards
    stats.mature_cards = stats.mature_cards + deck_stat.mature_cards
    stats.young_cards = stats.young_cards + deck_stat.young_cards

    -- Count reviewed today (cards with due != today and reps > 0)
    for _, card in ipairs(deck.cards) do
      if card.state.reps > 0 and card.state.due > today then
        stats.reviewed_today = stats.reviewed_today + 1
      end
    end

    -- Add deck summary
    table.insert(stats.decks_summary, {
      name = deck.name,
      total = deck_stat.total,
      due = deck_stat.due,
    })
  end

  return stats
end

--- Display statistics in a floating window or notification
--- @param stats RecallStats Statistics to display
function M.display(stats)
  local lines = {}

  -- Header
  table.insert(lines, "📊 recall.nvim Statistics")
  table.insert(lines, "─────────────────────────")

  -- Main stats
  table.insert(lines, string.format("Total cards:     %d", stats.total_cards))
  table.insert(lines, string.format("Due today:       %d", stats.due_today))
  table.insert(lines, string.format("New cards:       %d", stats.new_cards))
  table.insert(lines, string.format("Reviewed today:  %d", stats.reviewed_today))
  table.insert(lines, "─────────────────────────")
  table.insert(lines, string.format("Mature (>21d):   %d", stats.mature_cards))
  table.insert(lines, string.format("Young (1-21d):   %d", stats.young_cards))

  -- Decks summary
  if #stats.decks_summary > 0 then
    table.insert(lines, "")
    table.insert(lines, "Decks:")
    for _, deck_summary in ipairs(stats.decks_summary) do
      table.insert(
        lines,
        string.format(
          "  %s    [%d due / %d total]",
          deck_summary.name,
          deck_summary.due,
          deck_summary.total
        )
      )
    end
  end

  -- Try to use Snacks.win if available, fallback to vim.notify
  local ok, Snacks = pcall(require, "snacks")
  if ok and Snacks.win then
    local win = Snacks.win({
      position = "float",
      width = 0.5,
      height = 0.6,
      border = "rounded",
      title = " Statistics ",
      title_pos = "center",
    })

    vim.bo[win.buf].modifiable = true
    vim.api.nvim_buf_set_lines(win.buf, 0, -1, false, lines)
    vim.bo[win.buf].modifiable = false
    vim.bo[win.buf].filetype = "markdown"
  else
    -- Fallback to vim.notify
    local message = table.concat(lines, "\n")
    vim.notify(message, vim.log.levels.INFO)
  end
end

return M
