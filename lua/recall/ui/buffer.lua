local review = require("recall.review")
local config = require("recall.config")

local M = {}

local current_buf = nil
local current_win = nil
local current_session = nil
local showing_stats = false
local original_buf_settings = {}

local function should_show_stats(trigger)
  local setting = config.opts.show_session_stats
  if setting == "always" then
    return true
  end
  return setting == trigger
end

local function build_stats_lines(session, trigger)
  local lines = { "" }
  local stats = review.session_stats(session)
  local prog = review.progress(session)

  if trigger == "on_finish" then
    table.insert(lines, "# Review Complete")
  else
    table.insert(lines, "# Session Quit")
  end
  table.insert(lines, "")

  table.insert(lines, "**" .. stats.total .. "** of **" .. prog.total .. "** cards reviewed.")
  table.insert(lines, "")
  table.insert(lines, "| Rating | Count |")
  table.insert(lines, "| --- | --- |")
  table.insert(lines, "| Again | " .. stats.again .. " |")
  table.insert(lines, "| Hard | " .. stats.hard .. " |")
  table.insert(lines, "| Good | " .. stats.good .. " |")
  table.insert(lines, "| Easy | " .. stats.easy .. " |")

  return lines
end

--- @param session RecallSession
--- @return string
local function build_winbar(session)
  local deck_name = vim.fn.fnamemodify(session.deck.filepath, ":t")
  local rating_keys = config.opts.keys.rating
  local quit_key = config.opts.keys.quit

  if review.is_complete(session) or showing_stats then
    return " recall.nvim · " .. deck_name .. " · Complete  %=  Any key to close "
  end

  local prog = review.progress(session)
  local left = " recall.nvim · " .. deck_name .. " · " .. prog.current .. "/" .. prog.total

  local right
  if session.answer_shown then
    right = "[" .. rating_keys.again .. "] Again  "
      .. "[" .. rating_keys.hard .. "] Hard  "
      .. "[" .. rating_keys.good .. "] Good  "
      .. "[" .. rating_keys.easy .. "] Easy  "
      .. "[" .. quit_key .. "] Quit "
  else
    local show_label = config.opts.keys.show_answer == "<Space>" and "␣" or config.opts.keys.show_answer
    right = "[" .. show_label .. "] Show Answer  [" .. quit_key .. "] Quit "
  end

  return left .. "  %=  " .. right
end

--- @param session RecallSession
local function update_winbar(session)
  if not current_win or not vim.api.nvim_win_is_valid(current_win) then
    return
  end
  vim.wo[current_win].winbar = build_winbar(session)
end

--- @param buf number
--- @param session RecallSession
local function render_buffer(buf, session)
  local lines = { "" }

  if showing_stats then
    lines = build_stats_lines(session, showing_stats)
  elseif review.is_complete(session) then
    if should_show_stats("on_finish") then
      showing_stats = "on_finish"
      lines = build_stats_lines(session, "on_finish")
    else
      local total = review.progress(session).total
      table.insert(lines, "# Review Complete")
      table.insert(lines, "")
      table.insert(lines, "**" .. total .. "** cards reviewed.")
    end
  elseif review.current_card(session) then
    local card = review.current_card(session)
    table.insert(lines, "## " .. card.question)
    table.insert(lines, "")
    if session.answer_shown then
      local answer_lines = vim.split(card.answer, "\n")
      for _, line in ipairs(answer_lines) do
        table.insert(lines, line)
      end
    end
  else
    table.insert(lines, "No cards to review.")
  end

  table.insert(lines, "")

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  update_winbar(current_session)
end

local function handle_show_answer()
  if not current_session or not current_buf then
    return
  end
  if review.is_complete(current_session) then
    return
  end
  review.show_answer(current_session)
  render_buffer(current_buf, current_session)
end

--- @param rating string
local function handle_rate(rating)
  if not current_session or not current_buf then
    return
  end
  if review.is_complete(current_session) then
    return
  end
  review.rate(current_session, rating)
  render_buffer(current_buf, current_session)
end

local function restore_buffer()
  if current_buf and vim.api.nvim_buf_is_valid(current_buf) then
    -- Restore original buffer settings
    vim.bo[current_buf].modifiable = original_buf_settings.modifiable
    vim.bo[current_buf].buftype = original_buf_settings.buftype
    vim.bo[current_buf].filetype = original_buf_settings.filetype
    
    if current_win and vim.api.nvim_win_is_valid(current_win) then
      vim.wo[current_win].winbar = original_buf_settings.winbar
      vim.wo[current_win].conceallevel = original_buf_settings.conceallevel
      vim.wo[current_win].wrap = original_buf_settings.wrap
      vim.wo[current_win].cursorline = original_buf_settings.cursorline
      vim.wo[current_win].signcolumn = original_buf_settings.signcolumn
      vim.wo[current_win].list = original_buf_settings.list
      vim.wo[current_win].listchars = original_buf_settings.listchars
      vim.wo[current_win].statuscolumn = original_buf_settings.statuscolumn
    end
    
    -- Clear buffer keymaps
    local rating_keys = config.opts.keys.rating
    local show_key = config.opts.keys.show_answer
    local quit_key = config.opts.keys.quit
    
    for _, key in ipairs({ "1", "2", "3", "4", " ", "<CR>", "<Esc>", show_key, rating_keys.again, rating_keys.hard, rating_keys.good, rating_keys.easy, quit_key }) do
      pcall(vim.api.nvim_buf_del_keymap, current_buf, "n", key)
    end
    
    -- Reload the original buffer content
    vim.cmd("edit!")
    
    current_buf = nil
    current_win = nil
    current_session = nil
    showing_stats = false
    original_buf_settings = {}
  end
end

local function setup_close_keymaps()
  local buf = current_buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  for _, key in ipairs({ "1", "2", "3", "4", " ", "<CR>", "<Esc>", config.opts.keys.quit }) do
    pcall(vim.api.nvim_buf_del_keymap, buf, "n", key)
    vim.api.nvim_buf_set_keymap(buf, "n", key, "", {
      noremap = true,
      silent = true,
      callback = restore_buffer,
    })
  end
end

local function handle_quit()
  if not current_session or not current_buf then
    return
  end

  if showing_stats then
    restore_buffer()
    return
  end

  if should_show_stats("on_quit") and #current_session.results > 0 then
    showing_stats = "on_quit"
    render_buffer(current_buf, current_session)
    setup_close_keymaps()
    return
  end

  restore_buffer()
end

local function setup_dynamic_keymaps()
  local buf = current_buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local rating_keys = config.opts.keys.rating
  local show_key = config.opts.keys.show_answer
  local quit_key = config.opts.keys.quit

  local function safe_unmap(mode, key)
    pcall(vim.api.nvim_buf_del_keymap, buf, mode, key)
  end

  for _, key in ipairs({ show_key, rating_keys.again, rating_keys.hard, rating_keys.good, rating_keys.easy, quit_key }) do
    safe_unmap("n", key)
  end

  vim.api.nvim_buf_set_keymap(buf, "n", quit_key, "", {
    noremap = true,
    silent = true,
    callback = handle_quit,
  })

  if review.is_complete(current_session) or showing_stats then
    for _, key in ipairs({ "1", "2", "3", "4", " ", "<CR>", "<Esc>" }) do
      vim.api.nvim_buf_set_keymap(buf, "n", key, "", {
        noremap = true,
        silent = true,
        callback = handle_quit,
      })
    end
    return
  end

  if not current_session.answer_shown then
    vim.api.nvim_buf_set_keymap(buf, "n", show_key, "", {
      noremap = true,
      silent = true,
      callback = function()
        handle_show_answer()
        setup_dynamic_keymaps()
      end,
    })
  end

  if current_session.answer_shown then
    local ratings = {
      { key = rating_keys.again, name = "again" },
      { key = rating_keys.hard, name = "hard" },
      { key = rating_keys.good, name = "good" },
      { key = rating_keys.easy, name = "easy" },
    }
    for _, r in ipairs(ratings) do
      vim.api.nvim_buf_set_keymap(buf, "n", r.key, "", {
        noremap = true,
        silent = true,
        callback = function()
          handle_rate(r.name)
          setup_dynamic_keymaps()
        end,
      })
    end
  end
end

--- @param session RecallSession
function M.start(session)
  current_session = session

  -- Use the current buffer and window
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()

  -- Save original buffer settings
  original_buf_settings = {
    modifiable = vim.bo[buf].modifiable,
    buftype = vim.bo[buf].buftype,
    filetype = vim.bo[buf].filetype,
    winbar = vim.wo[win].winbar,
    conceallevel = vim.wo[win].conceallevel,
    wrap = vim.wo[win].wrap,
    cursorline = vim.wo[win].cursorline,
    signcolumn = vim.wo[win].signcolumn,
    list = vim.wo[win].list,
    listchars = vim.wo[win].listchars,
    statuscolumn = vim.wo[win].statuscolumn,
  }

  -- Set buffer options for review
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype = "nofile"
  vim.wo[win].conceallevel = 2
  vim.wo[win].wrap = true
  vim.wo[win].cursorline = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].list = true
  vim.wo[win].listchars = "eol: "
  vim.wo[win].statuscolumn = " "

  current_buf = buf
  current_win = win

  render_buffer(buf, session)
  setup_dynamic_keymaps()
end

return M
