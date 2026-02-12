local review = require('recall.review')
local config = require('recall.config')

local M = {}

--- Internal state
local current_win = nil
local current_session = nil

--- Render buffer content for the current state
--- @param win table Snacks window object
--- @param session RecallSession Session object
local function render_buffer(win, session)
  local lines = {}

  -- Check if session is complete
  if review.is_complete(session) then
    -- Show completion summary
    local total = review.progress(session).total
    table.insert(lines, "")
    table.insert(lines, "  Review complete!")
    table.insert(lines, "")
    table.insert(lines, string.format("  %d cards reviewed.", total))
    table.insert(lines, "")
    table.insert(lines, "  Press any key to close.")
    table.insert(lines, "")

    vim.bo[win.buf].modifiable = true
    vim.api.nvim_buf_set_lines(win.buf, 0, -1, false, lines)
    vim.bo[win.buf].modifiable = false
    return
  end

  -- Get current card and progress
  local card = review.current_card(session)
  if not card then
    table.insert(lines, "")
    table.insert(lines, "  No cards to review.")
    table.insert(lines, "")
    vim.bo[win.buf].modifiable = true
    vim.api.nvim_buf_set_lines(win.buf, 0, -1, false, lines)
    vim.bo[win.buf].modifiable = false
    return
  end

  local prog = review.progress(session)
  local deck_name = vim.fn.fnamemodify(session.deck.filepath, ":t")

  -- Header
  table.insert(lines, "")
  table.insert(lines, string.format("  Deck: %s", deck_name))
  table.insert(lines, string.format("  Card %d / %d", prog.current, prog.total))
  table.insert(lines, "")
  table.insert(lines, "  ─────────────────────────────")
  table.insert(lines, "")

  -- Question
  local question_lines = vim.split(card.question, "\n")
  for _, line in ipairs(question_lines) do
    table.insert(lines, "  " .. line)
  end
  table.insert(lines, "")

  -- Answer (if shown)
  if session.answer_shown then
    local answer_lines = vim.split(card.answer, "\n")
    for _, line in ipairs(answer_lines) do
      table.insert(lines, "  " .. line)
    end
    table.insert(lines, "")
    table.insert(lines, "  ─────────────────────────────")
    table.insert(lines, "")

    -- Rating buttons
    local rating_keys = config.opts.rating_keys
    table.insert(lines, string.format("  [%s] Again  [%s] Hard  [%s] Good  [%s] Easy",
      rating_keys.again, rating_keys.hard, rating_keys.good, rating_keys.easy))
    table.insert(lines, "")
  else
    -- Show answer prompt
    table.insert(lines, "")
    local show_key = config.opts.show_answer_key
    table.insert(lines, string.format("         [%s] Show Answer", show_key))
    table.insert(lines, "")
  end

  vim.bo[win.buf].modifiable = true
  vim.api.nvim_buf_set_lines(win.buf, 0, -1, false, lines)
  vim.bo[win.buf].modifiable = false
end

--- Handle showing the answer
local function handle_show_answer()
  if not current_session or not current_win then
    return
  end

  if review.is_complete(current_session) then
    return
  end

  review.show_answer(current_session)
  render_buffer(current_win, current_session)
end

--- Handle rating and advance to next card
--- @param rating string Rating: "again", "hard", "good", "easy"
local function handle_rate(rating)
  if not current_session or not current_win then
    return
  end

  if review.is_complete(current_session) then
    return
  end

  -- Rate current card (this advances to next)
  review.rate(current_session, rating)

  -- Re-render (either next card or completion summary)
  render_buffer(current_win, current_session)
end

--- Handle quit
local function handle_quit()
  if current_win then
    current_win:close()
    current_win = nil
    current_session = nil
  end
end

--- Build dynamic keymaps based on session state
--- @param session RecallSession Session object
--- @return table Keymap table for Snacks.win
local function build_keymaps(session)
  local rating_keys = config.opts.rating_keys
  local show_key = config.opts.show_answer_key
  local quit_key = config.opts.quit_key

  local keys = {}

  -- Quit always available
  keys[quit_key] = function() handle_quit() end

  -- If session complete, any key closes
  if review.is_complete(session) then
    -- Override all keys to close on completion
    for _, key in ipairs({"1", "2", "3", "4", " ", "q", "<Space>", "<Esc>", "<CR>"}) do
      keys[key] = function() handle_quit() end
    end
    return keys
  end

  -- Show answer key (only when answer not shown)
  if not session.answer_shown then
    keys[show_key] = function() handle_show_answer() end
  end

  -- Rating keys (only when answer shown)
  if session.answer_shown then
    keys[rating_keys.again] = function() handle_rate("again") end
    keys[rating_keys.hard] = function() handle_rate("hard") end
    keys[rating_keys.good] = function() handle_rate("good") end
    keys[rating_keys.easy] = function() handle_rate("easy") end
  end

  return keys
end

--- Start a floating window review session
--- @param session RecallSession Session created by review.new_session()
function M.start(session)
  -- Store session globally
  current_session = session

  -- Create floating window with initial keymaps
  local Snacks = require('snacks')
  local win = Snacks.win({
    position = "float",
    width = 0.7,
    height = 0.7,
    border = "rounded",
    title = " recall.nvim ",
    bo = {
      filetype = "markdown",
      modifiable = false,
    },
    keys = build_keymaps(session),
  })

  -- Store window reference
  current_win = win

  -- Initial render
  render_buffer(win, session)

  -- Note: Snacks.win keymaps are static at creation time
  -- To support dynamic keymaps (answer shown → rating keys appear),
  -- we need to rebuild the window or manually manage keybindings
  -- For now, we'll use a workaround: manually set buffer keymaps

  -- Clear static keys and use dynamic buffer keymaps
  local function setup_dynamic_keymaps()
    local buf = win.buf

    -- Clear all existing buffer keymaps
    local rating_keys = config.opts.rating_keys
    local show_key = config.opts.show_answer_key
    local quit_key = config.opts.quit_key

    -- Helper to safely unmap keys
    local function safe_unmap(mode, key)
      pcall(vim.api.nvim_buf_del_keymap, buf, mode, key)
    end

    -- Unmap all potential keys
    for _, key in ipairs({show_key, rating_keys.again, rating_keys.hard, rating_keys.good, rating_keys.easy, quit_key}) do
      safe_unmap("n", key)
    end

    -- Quit always available
    vim.api.nvim_buf_set_keymap(buf, "n", quit_key, "", {
      noremap = true,
      silent = true,
      callback = handle_quit,
    })

    -- Session complete: any key closes
    if review.is_complete(current_session) then
      for _, key in ipairs({"1", "2", "3", "4", " ", "<CR>", "<Esc>"}) do
        vim.api.nvim_buf_set_keymap(buf, "n", key, "", {
          noremap = true,
          silent = true,
          callback = handle_quit,
        })
      end
      return
    end

    -- Show answer key
    if not current_session.answer_shown then
      vim.api.nvim_buf_set_keymap(buf, "n", show_key, "", {
        noremap = true,
        silent = true,
        callback = function()
          handle_show_answer()
          setup_dynamic_keymaps() -- Rebuild keymaps after state change
        end,
      })
    end

    -- Rating keys
    if current_session.answer_shown then
      vim.api.nvim_buf_set_keymap(buf, "n", rating_keys.again, "", {
        noremap = true,
        silent = true,
        callback = function()
          handle_rate("again")
          setup_dynamic_keymaps() -- Rebuild keymaps after state change
        end,
      })
      vim.api.nvim_buf_set_keymap(buf, "n", rating_keys.hard, "", {
        noremap = true,
        silent = true,
        callback = function()
          handle_rate("hard")
          setup_dynamic_keymaps()
        end,
      })
      vim.api.nvim_buf_set_keymap(buf, "n", rating_keys.good, "", {
        noremap = true,
        silent = true,
        callback = function()
          handle_rate("good")
          setup_dynamic_keymaps()
        end,
      })
      vim.api.nvim_buf_set_keymap(buf, "n", rating_keys.easy, "", {
        noremap = true,
        silent = true,
        callback = function()
          handle_rate("easy")
          setup_dynamic_keymaps()
        end,
      })
    end
  end

  -- Set up initial dynamic keymaps
  setup_dynamic_keymaps()
end

return M
