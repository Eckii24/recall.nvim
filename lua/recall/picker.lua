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
    confirm = function(picker, item)
      picker:close()
      if item and item.deck then
        vim.schedule(function()
          on_select(item.deck)
        end)
      end
    end,
  })
end

--- Convenience function: scan directories, filter due decks, open picker, start review
--- @param opts table|nil Options: { dirs = string[], show_all = bool }
function M.pick_and_review(opts)
  opts = opts or {}

  local dirs = opts.dirs or config.get_dirs()
  if not dirs or #dirs == 0 then
    vim.notify("No directories configured for scanning. Set dirs in setup().", vim.log.levels.WARN)
    return
  end

  local decks = scanner.scan(dirs)

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

  M.pick_deck(filtered_decks, function(selected_deck)
    local session = review.new_session(selected_deck)

    if review.is_complete(session) then
      vim.notify(string.format("No cards due in '%s'.", selected_deck.name), vim.log.levels.INFO)
      return
    end

    local review_mode = config.opts.review_mode
    if review_mode == "split" then
      local ui_split = require("recall.ui.split")
      ui_split.start(session)
    elseif review_mode == "buffer" then
      local ui_buffer = require("recall.ui.buffer")
      ui_buffer.start(session)
    else
      local ui_float = require("recall.ui.float")
      ui_float.start(session)
    end
  end)
end

return M
