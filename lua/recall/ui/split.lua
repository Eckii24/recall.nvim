local review = require("recall.review")
local config = require("recall.config")

local M = {}

local current_buf = nil
local current_win = nil
local current_session = nil

--- @param session RecallSession
--- @return string
local function build_winbar(session)
  local deck_name = vim.fn.fnamemodify(session.deck.filepath, ":t")
  local rating_keys = config.opts.rating_keys
  local quit_key = config.opts.quit_key

  if review.is_complete(session) then
    return " recall.nvim \u{00b7} " .. deck_name .. " \u{00b7} Complete  %=  Any key to close "
  end

  local prog = review.progress(session)
  local left = " recall.nvim \u{00b7} " .. deck_name .. " \u{00b7} " .. prog.current .. "/" .. prog.total

  local right
  if session.answer_shown then
    right = "[" .. rating_keys.again .. "] Again  "
      .. "[" .. rating_keys.hard .. "] Hard  "
      .. "[" .. rating_keys.good .. "] Good  "
      .. "[" .. rating_keys.easy .. "] Easy  "
      .. "[" .. quit_key .. "] Quit "
  else
    local show_label = config.opts.show_answer_key == "<Space>" and "\u{2423}" or config.opts.show_answer_key
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

  if review.is_complete(session) then
    local total = review.progress(session).total
    table.insert(lines, "# Review Complete")
    table.insert(lines, "")
    table.insert(lines, "**" .. total .. "** cards reviewed.")
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

local function handle_quit()
  if current_buf and vim.api.nvim_buf_is_valid(current_buf) then
    vim.api.nvim_buf_delete(current_buf, { force = true })
    current_buf = nil
    current_win = nil
    current_session = nil
  end
end

local function setup_dynamic_keymaps()
  local buf = current_buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local rating_keys = config.opts.rating_keys
  local show_key = config.opts.show_answer_key
  local quit_key = config.opts.quit_key

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

  if review.is_complete(current_session) then
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

  vim.cmd("split")
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)

  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
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
