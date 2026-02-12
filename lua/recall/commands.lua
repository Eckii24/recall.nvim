local M = {}

local picker = require("recall.picker")
local scanner = require("recall.scanner")
local stats = require("recall.stats")
local config = require("recall.config")
local review = require("recall.review")

--- Main command dispatcher
--- @param fargs string[] Command arguments from :Recall
function M.dispatch(fargs)
  local subcommand = fargs[1] or ""

  if subcommand == "review" then
    local arg = fargs[2]
    if not arg then
      picker.pick_and_review()
    elseif arg == "." then
      local decks = scanner.scan_cwd()

      local due_decks = {}
      for _, deck in ipairs(decks) do
        if deck.due > 0 then
          table.insert(due_decks, deck)
        end
      end

      if #due_decks == 0 then
        vim.notify("No decks with due cards in current directory.", vim.log.levels.INFO)
        return
      end

      picker.pick_deck(due_decks, function(selected_deck)
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
    else
      local dirs = config.get_dirs()
      if not dirs or #dirs == 0 then
        vim.notify("No directories configured for scanning. Set dirs in setup().", vim.log.levels.WARN)
        return
      end

      local decks = scanner.scan(dirs)

      local target_deck = nil
      for _, deck in ipairs(decks) do
        if deck.name == arg then
          target_deck = deck
          break
        end
      end

      if not target_deck then
        vim.notify(string.format("Deck '%s' not found.", arg), vim.log.levels.WARN)
        return
      end

      local session = review.new_session(target_deck)
      if review.is_complete(session) then
        vim.notify(string.format("No cards due in '%s'.", target_deck.name), vim.log.levels.INFO)
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
    end
  elseif subcommand == "stats" then
    local dirs = config.get_dirs()
    if not dirs or #dirs == 0 then
      vim.notify("No directories configured for scanning. Set dirs in setup().", vim.log.levels.WARN)
      return
    end

    local decks = scanner.scan(dirs)

    local computed_stats = stats.compute(decks)
    stats.display(computed_stats)
  elseif subcommand == "scan" then
    local arg = fargs[2]
    local dirs_to_scan

    if arg then
      dirs_to_scan = { arg }
    else
      dirs_to_scan = config.get_dirs()
      if not dirs_to_scan or #dirs_to_scan == 0 then
        vim.notify("No directories configured for scanning. Set dirs in setup().", vim.log.levels.WARN)
        return
      end
    end

    local decks = scanner.scan(dirs_to_scan)

    local total_cards = 0
    for _, deck in ipairs(decks) do
      total_cards = total_cards + deck.total
    end

    vim.notify(
      string.format("Scanned %d decks, %d cards", #decks, total_cards),
      vim.log.levels.INFO
    )
  else
    local usage = [[
recall.nvim - Spaced repetition for Neovim

Usage:
  :Recall review [deck_name|.]
    - No arg: Open deck picker for all configured directories
    - deck_name: Start review for specific deck by name
    - '.': Scan current working directory only

  :Recall stats
    - Show statistics across all configured decks

  :Recall scan [dir]
    - Manually scan directories (or specific dir)
    - Shows "Scanned N decks, M cards" notification
]]
    vim.notify(usage, vim.log.levels.INFO)
  end
end

--- Tab-completion for :Recall command
--- @param ArgLead string Current argument being completed
--- @param CmdLine string Full command line
--- @return string[] Completion candidates
function M.complete(ArgLead, CmdLine)
  local args = vim.split(CmdLine, "%s+")
  local num_args = #args

  if args[1] == "Recall" then
    num_args = num_args - 1
  end

  if num_args == 1 or (num_args == 2 and ArgLead ~= "") then
    local subcommands = { "review", "stats", "scan" }
    if ArgLead == "" then
      return subcommands
    end
    local matches = {}
    for _, cmd in ipairs(subcommands) do
      if cmd:match("^" .. vim.pesc(ArgLead)) then
        table.insert(matches, cmd)
      end
    end
    return matches
  end

  if num_args >= 2 and (args[2] == "review" or args[3] == "review") then
    local dirs = config.get_dirs()
    if not dirs or #dirs == 0 then
      return {}
    end

    local decks = scanner.scan(dirs)

    local deck_names = { "." }
    for _, deck in ipairs(decks) do
      table.insert(deck_names, deck.name)
    end

    if ArgLead == "" then
      return deck_names
    end

    local matches = {}
    for _, name in ipairs(deck_names) do
      if name:match("^" .. vim.pesc(ArgLead)) then
        table.insert(matches, name)
      end
    end
    return matches
  end

  return {}
end

return M
