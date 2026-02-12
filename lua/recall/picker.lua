local M = {}

local scanner = require("recall.scanner")
local review = require("recall.review")
local config = require("recall.config")

--- Show picker to select a deck for review
--- @param decks RecallDeck[] Array of decks
--- @param on_select fun(deck: RecallDeck) Callback when deck is selected
function M.pick_deck(decks, on_select)
  -- Sort decks by due count (most due first)
  local sorted_decks = vim.list_extend({}, decks)
  table.sort(sorted_decks, function(a, b)
    return a.due > b.due
  end)

  -- Convert decks to picker items
  local items = {}
  for _, deck in ipairs(sorted_decks) do
    local formatted = string.format("%s  [%d due / %d total]", deck.name, deck.due, deck.total)
    table.insert(items, {
      text = formatted,
      deck = deck,
    })
  end

  -- Build preview function to show first few cards
  local function preview_deck(item)
    if not item or not item.deck then
      return {}
    end

    local lines = {}
    local deck = item.deck

    -- Header
    table.insert(lines, string.format("# %s", deck.name))
    table.insert(lines, "")
    table.insert(lines, string.format("**Cards**: %d total, %d due for review", deck.total, deck.due))
    table.insert(lines, "")

    -- Show first 5 cards as preview
    local preview_count = math.min(5, #deck.cards)
    if preview_count > 0 then
      table.insert(lines, "## Preview")
      table.insert(lines, "")

      for i = 1, preview_count do
        local card = deck.cards[i]
        table.insert(lines, string.format("### Card %d", i))
        table.insert(lines, "")
        table.insert(lines, "**Q**: " .. card.question)
        table.insert(lines, "")
        table.insert(lines, "**A**: " .. card.answer)
        table.insert(lines, "")
      end
    end

    return lines
  end

  -- Open snacks picker
  local Snacks = require("snacks")
  Snacks.picker.pick({
    title = "Select Deck",
    items = items,
    format = "text",
    preview = function(item)
      return {
        buf = function(buf)
          local lines = preview_deck(item)
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
          vim.bo[buf].filetype = "markdown"
        end,
      }
    end,
    confirm = function(_, item)
      if item and item.deck then
        on_select(item.deck)
      end
    end,
  })
end

--- Convenience function: scan directories, filter due decks, open picker, start review
--- @param opts table|nil Options: { dirs = string[], auto_mode = bool, min_heading_level = int, show_all = bool }
function M.pick_and_review(opts)
  opts = opts or {}

  -- Get directories from opts or config
  local dirs = opts.dirs or config.opts.dirs
  if not dirs or #dirs == 0 then
    vim.notify("No directories configured for scanning. Set dirs in setup().", vim.log.levels.WARN)
    return
  end

  -- Scan for decks
  local decks = scanner.scan(dirs, {
    auto_mode = opts.auto_mode or config.opts.auto_mode,
    min_heading_level = opts.min_heading_level or config.opts.min_heading_level,
  })

  -- Filter to decks with at least 1 due card (unless show_all=true)
  local show_all = opts.show_all or false
  local filtered_decks = {}
  for _, deck in ipairs(decks) do
    if show_all or deck.due > 0 then
      table.insert(filtered_decks, deck)
    end
  end

  if #filtered_decks == 0 then
    vim.notify("No decks with due cards found.", vim.log.levels.INFO)
    return
  end

  -- Open picker
  M.pick_deck(filtered_decks, function(selected_deck)
    -- Create review session
    local session = review.new_session(selected_deck)

    -- Check if there are any cards to review
    if review.is_complete(session) then
      vim.notify(string.format("No cards due in '%s'.", selected_deck.name), vim.log.levels.INFO)
      return
    end

    -- Start UI based on review_mode
    local review_mode = config.opts.review_mode
    if review_mode == "split" then
      local ui_split = require("recall.ui.split")
      ui_split.start(session)
    else
      local ui_float = require("recall.ui.float")
      ui_float.start(session)
    end
  end)
end

return M
