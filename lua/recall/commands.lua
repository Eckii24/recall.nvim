local M = {}

local config = require("recall.config")

--- Dispatch :Recall subcommands
---@param args string[] command arguments
function M.dispatch(args)
  local subcmd = args[1]

  if not subcmd then
    vim.notify("[recall.nvim] Usage: :Recall <review|stats|scan>", vim.log.levels.INFO)
    return
  end

  if subcmd == "review" then
    M._review(args)
  elseif subcmd == "stats" then
    M._stats(args)
  elseif subcmd == "scan" then
    M._scan(args)
  else
    vim.notify("[recall.nvim] Unknown subcommand: " .. subcmd .. ". Use: review, stats, scan", vim.log.levels.ERROR)
  end
end

--- Handle :Recall review [deck_name|.|--dir=path]
---@param args string[]
function M._review(args)
  local scanner = require("recall.scanner")
  local review_mod = require("recall.review")
  local picker = require("recall.picker")

  local dirs = nil
  local deck_name = nil

  if args[2] then
    if args[2] == "." then
      dirs = { vim.fn.getcwd() }
    elseif args[2]:match("^%-%-dir=") then
      local dir = args[2]:gsub("^%-%-dir=", "")
      dirs = { vim.fn.expand(dir) }
    else
      deck_name = args[2]
    end
  end

  if dirs then
    -- Scan specific dirs
    local decks = scanner.scan(dirs, {
      auto_mode = config.opts.auto_mode,
      min_heading_level = config.opts.min_heading_level,
    })

    if deck_name then
      -- Find specific deck
      for _, deck in ipairs(decks) do
        if deck.name == deck_name then
          local session = review_mod.new_session(deck)
          local review_mode = config.opts.review_mode or "float"
          if review_mode == "split" then
            require("recall.ui.split").start(session)
          else
            require("recall.ui.float").start(session)
          end
          return
        end
      end
      vim.notify("[recall.nvim] Deck not found: " .. deck_name, vim.log.levels.ERROR)
    elseif #decks == 1 then
      -- Single deck, start directly
      local session = review_mod.new_session(decks[1])
      local review_mode = config.opts.review_mode or "float"
      if review_mode == "split" then
        require("recall.ui.split").start(session)
      else
        require("recall.ui.float").start(session)
      end
    else
      picker.pick_deck(decks, function(deck)
        local session = review_mod.new_session(deck)
        local review_mode = config.opts.review_mode or "float"
        if review_mode == "split" then
          require("recall.ui.split").start(session)
        else
          require("recall.ui.float").start(session)
        end
      end)
    end
  elseif deck_name then
    -- Search all configured dirs for the deck
    local scan_dirs = config.opts.dirs or {}
    if #scan_dirs == 0 then
      scan_dirs = { vim.fn.getcwd() }
    end

    local decks = scanner.scan(scan_dirs, {
      auto_mode = config.opts.auto_mode,
      min_heading_level = config.opts.min_heading_level,
    })

    for _, deck in ipairs(decks) do
      if deck.name == deck_name then
        local session = review_mod.new_session(deck)
        local review_mode = config.opts.review_mode or "float"
        if review_mode == "split" then
          require("recall.ui.split").start(session)
        else
          require("recall.ui.float").start(session)
        end
        return
      end
    end
    vim.notify("[recall.nvim] Deck not found: " .. deck_name, vim.log.levels.ERROR)
  else
    -- Open picker
    picker.pick_and_review()
  end
end

--- Handle :Recall stats
---@param args string[]
function M._stats(args)
  local scanner = require("recall.scanner")
  local stats = require("recall.stats")

  local dirs = config.opts.dirs or {}
  if args[2] then
    if args[2] == "." then
      dirs = { vim.fn.getcwd() }
    elseif args[2]:match("^%-%-dir=") then
      local dir = args[2]:gsub("^%-%-dir=", "")
      dirs = { vim.fn.expand(dir) }
    end
  end

  if #dirs == 0 then
    dirs = { vim.fn.getcwd() }
  end

  local decks = scanner.scan(dirs, {
    auto_mode = config.opts.auto_mode,
    min_heading_level = config.opts.min_heading_level,
  })

  local computed = stats.compute(decks)
  stats.display(computed)
end

--- Handle :Recall scan
---@param args string[]
function M._scan(args)
  local scanner = require("recall.scanner")

  local dirs = config.opts.dirs or {}
  if args[2] then
    if args[2] == "." then
      dirs = { vim.fn.getcwd() }
    elseif args[2]:match("^%-%-dir=") then
      local dir = args[2]:gsub("^%-%-dir=", "")
      dirs = { vim.fn.expand(dir) }
    end
  end

  if #dirs == 0 then
    dirs = { vim.fn.getcwd() }
  end

  local decks = scanner.scan(dirs, {
    auto_mode = config.opts.auto_mode,
    min_heading_level = config.opts.min_heading_level,
  })

  if #decks == 0 then
    vim.notify("[recall.nvim] No flashcard files found.", vim.log.levels.INFO)
    return
  end

  local total_cards = 0
  local total_due = 0
  local lines = { "[recall.nvim] Scan results:" }

  for _, deck in ipairs(decks) do
    table.insert(lines, "  " .. deck.name .. ": " .. deck.total .. " cards (" .. deck.due .. " due)")
    total_cards = total_cards + deck.total
    total_due = total_due + deck.due
  end

  table.insert(lines, "  Total: " .. total_cards .. " cards in " .. #decks .. " decks (" .. total_due .. " due)")

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

--- Tab-completion for :Recall
---@param arg_lead string
---@param cmd_line string
---@param cursor_pos integer
---@return string[]
function M.complete(arg_lead, cmd_line, cursor_pos)
  local subcmds = { "review", "stats", "scan" }

  -- If we're completing the first argument
  local args = vim.split(cmd_line, "%s+")
  if #args <= 2 then
    return vim.tbl_filter(function(s)
      return s:find(arg_lead, 1, true) == 1
    end, subcmds)
  end

  -- If completing after "review", suggest deck names and special values
  if args[2] == "review" then
    local suggestions = { "." }

    -- Try to get deck names from configured dirs
    local ok, scanner = pcall(require, "recall.scanner")
    if ok then
      local dirs = config.opts.dirs or {}
      if #dirs == 0 then
        dirs = { vim.fn.getcwd() }
      end
      local ok2, decks = pcall(scanner.scan, dirs, {
        auto_mode = config.opts.auto_mode,
        min_heading_level = config.opts.min_heading_level,
      })
      if ok2 then
        for _, deck in ipairs(decks) do
          table.insert(suggestions, deck.name)
        end
      end
    end

    return vim.tbl_filter(function(s)
      return s:find(arg_lead, 1, true) == 1
    end, suggestions)
  end

  return {}
end

return M
