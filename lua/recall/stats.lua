local M = {}

local scheduler = require("recall.scheduler")

---@class RecallStats
---@field total_cards integer
---@field due_today integer
---@field new_cards integer cards never reviewed
---@field reviewed_today integer cards reviewed today (interval > 0 and due > today)
---@field mature_cards integer cards with interval > 21 days
---@field young_cards integer cards with interval 1-21 days
---@field decks_summary { name: string, total: integer, due: integer }[]

--- Compute statistics for a single deck
---@param deck RecallDeck
---@return { total: integer, due: integer, new: integer, mature: integer, young: integer }
function M.deck_stats(deck)
  local stats = { total = 0, due = 0, new = 0, mature = 0, young = 0 }

  for _, card in ipairs(deck.cards) do
    stats.total = stats.total + 1

    if scheduler.is_due(card.state) then
      stats.due = stats.due + 1
    end

    if card.state.reps == 0 and card.state.interval == 0 then
      stats.new = stats.new + 1
    elseif card.state.interval > 21 then
      stats.mature = stats.mature + 1
    else
      stats.young = stats.young + 1
    end
  end

  return stats
end

--- Compute aggregate statistics across all decks
---@param decks RecallDeck[]
---@return RecallStats
function M.compute(decks)
  local result = {
    total_cards = 0,
    due_today = 0,
    new_cards = 0,
    reviewed_today = 0,
    mature_cards = 0,
    young_cards = 0,
    decks_summary = {},
  }

  for _, deck in ipairs(decks) do
    local ds = M.deck_stats(deck)
    result.total_cards = result.total_cards + ds.total
    result.due_today = result.due_today + ds.due
    result.new_cards = result.new_cards + ds.new
    result.mature_cards = result.mature_cards + ds.mature
    result.young_cards = result.young_cards + ds.young

    table.insert(result.decks_summary, {
      name = deck.name,
      total = ds.total,
      due = ds.due,
    })
  end

  return result
end

--- Display statistics
---@param stats RecallStats
function M.display(stats)
  local lines = {
    "📊 recall.nvim Statistics",
    "─────────────────────────",
    "Total cards:     " .. stats.total_cards,
    "Due today:       " .. stats.due_today,
    "New cards:       " .. stats.new_cards,
    "─────────────────────────",
    "Mature (>21d):   " .. stats.mature_cards,
    "Young (1-21d):   " .. stats.young_cards,
    "",
  }

  if #stats.decks_summary > 0 then
    table.insert(lines, "Decks:")
    for _, ds in ipairs(stats.decks_summary) do
      table.insert(lines, "  " .. ds.name .. "  [" .. ds.due .. " due / " .. ds.total .. " total]")
    end
  end

  -- Try to use Snacks.win for display, fall back to echo
  local ok_snacks, Snacks = pcall(require, "snacks")
  if ok_snacks then
    local win = Snacks.win({
      position = "float",
      width = 0.5,
      height = 0.5,
      border = "rounded",
      title = " recall.nvim Stats ",
      bo = {
        filetype = "markdown",
        modifiable = false,
        buftype = "nofile",
      },
    })

    vim.bo[win.buf].modifiable = true
    vim.api.nvim_buf_set_lines(win.buf, 0, -1, false, lines)
    vim.bo[win.buf].modifiable = false

    -- Close on q or Escape
    vim.keymap.set("n", "q", function()
      win:close()
    end, { buffer = win.buf, nowait = true })
    vim.keymap.set("n", "<Esc>", function()
      win:close()
    end, { buffer = win.buf, nowait = true })
  else
    -- Fallback: print to messages
    for _, line in ipairs(lines) do
      print(line)
    end
  end
end

return M
