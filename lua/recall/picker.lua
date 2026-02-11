local M = {}

local scanner = require("recall.scanner")
local review = require("recall.review")
local config = require("recall.config")

--- Pick a deck and start review
---@param decks RecallDeck[]
---@param on_select function callback receiving the selected deck
function M.pick_deck(decks, on_select)
  local ok_snacks, Snacks = pcall(require, "snacks")
  if not ok_snacks then
    vim.notify("[recall.nvim] snacks.nvim is required for deck picker", vim.log.levels.ERROR)
    return
  end

  -- Sort decks by due count (most due first)
  table.sort(decks, function(a, b)
    return a.due > b.due
  end)

  -- Build picker items
  local items = {}
  for i, deck in ipairs(decks) do
    table.insert(items, {
      idx = i,
      text = deck.name .. "  [" .. deck.due .. " due / " .. deck.total .. " total]",
      deck = deck,
    })
  end

  Snacks.picker.pick({
    title = "recall.nvim - Select Deck",
    items = items,
    format = "text",
    confirm = function(picker, item)
      picker:close()
      if item and item.deck then
        on_select(item.deck)
      end
    end,
    preview = function(ctx)
      local deck = ctx.item.deck
      local lines = {
        "# " .. deck.name,
        "",
        "Total cards: " .. deck.total,
        "Due today: " .. deck.due,
        "",
        "---",
        "",
      }
      -- Show first few cards as preview
      local preview_count = math.min(5, #deck.cards)
      for i = 1, preview_count do
        local card = deck.cards[i]
        table.insert(lines, string.rep("#", card.heading_level) .. " " .. card.question)
        table.insert(lines, "")
      end
      if #deck.cards > preview_count then
        table.insert(lines, "... and " .. (#deck.cards - preview_count) .. " more cards")
      end
      return ctx.preview:set_lines(lines)
    end,
  })
end

--- Convenience function: scan, pick, and start review
---@param opts? { dirs?: string[], auto_mode?: boolean }
function M.pick_and_review(opts)
  opts = opts or {}
  local dirs = opts.dirs or config.opts.dirs or {}

  if #dirs == 0 then
    dirs = { vim.fn.getcwd() }
  end

  local decks = scanner.scan(dirs, {
    auto_mode = opts.auto_mode or config.opts.auto_mode,
    min_heading_level = config.opts.min_heading_level,
  })

  if #decks == 0 then
    vim.notify("[recall.nvim] No flashcard decks found.", vim.log.levels.INFO)
    return
  end

  M.pick_deck(decks, function(deck)
    local session = review.new_session(deck)
    local review_mode = config.opts.review_mode or "float"

    if review_mode == "split" then
      require("recall.ui.split").start(session)
    else
      require("recall.ui.float").start(session)
    end
  end)
end

return M
