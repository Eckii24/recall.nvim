local review = require("recall.review")
local config = require("recall.config")

local M = {}

local current_win = nil
local current_session = nil

--- @param session RecallSession
--- @return string
local function build_title(session)
  local deck_name = vim.fn.fnamemodify(session.deck.filepath, ":t")
  if review.is_complete(session) then
    return " recall.nvim \u{00b7} " .. deck_name .. " "
  end
  local prog = review.progress(session)
  return " recall.nvim \u{00b7} " .. deck_name .. " \u{00b7} " .. prog.current .. "/" .. prog.total .. " "
end

--- @param session RecallSession
--- @return table[]
local function build_footer(session)
  local rating_keys = config.opts.rating_keys
  local quit_key = config.opts.quit_key

  if review.is_complete(session) then
    return {
      { " Any key to close ", "RecallFooter" },
    }
  end

  if session.answer_shown then
    return {
      { " " .. rating_keys.again .. " ", "RecallButtonLabel" },
      { " Again ", "RecallFooter" },
      { " " .. rating_keys.hard .. " ", "RecallButtonLabel" },
      { " Hard ", "RecallFooter" },
      { " " .. rating_keys.good .. " ", "RecallButtonLabel" },
      { " Good ", "RecallFooter" },
      { " " .. rating_keys.easy .. " ", "RecallButtonLabel" },
      { " Easy ", "RecallFooter" },
      { "  " },
      { " " .. quit_key .. " ", "RecallButtonLabel" },
      { " Quit ", "RecallFooter" },
    }
  end

  local show_label = config.opts.show_answer_key == "<Space>" and "\u{2423}" or config.opts.show_answer_key
  return {
    { " " .. show_label .. " ", "RecallButtonLabel" },
    { " Show Answer ", "RecallFooter" },
    { "  " },
    { " " .. quit_key .. " ", "RecallButtonLabel" },
    { " Quit ", "RecallFooter" },
  }
end

--- @param win table
--- @param session RecallSession
local function update_chrome(win, session)
  if not win or not win.win or not vim.api.nvim_win_is_valid(win.win) then
    return
  end
  vim.api.nvim_win_set_config(win.win, {
    title = build_title(session),
    title_pos = "center",
    footer = build_footer(session),
    footer_pos = "center",
  })
end

--- @param win table
--- @param session RecallSession
local function render_buffer(win, session)
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

  vim.bo[win.buf].modifiable = true
  vim.api.nvim_buf_set_lines(win.buf, 0, -1, false, lines)
  vim.bo[win.buf].modifiable = false

  update_chrome(win, session)
end

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

--- @param rating string
local function handle_rate(rating)
  if not current_session or not current_win then
    return
  end
  if review.is_complete(current_session) then
    return
  end
  review.rate(current_session, rating)
  render_buffer(current_win, current_session)
end

local function handle_quit()
  if current_win then
    current_win:close()
    current_win = nil
    current_session = nil
  end
end

local function setup_dynamic_keymaps()
  local buf = current_win.buf
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

  local Snacks = require("snacks")
  local win = Snacks.win({
    position = "float",
    width = 0.6,
    height = 0.6,
    border = "rounded",
    title = build_title(session),
    title_pos = "center",
    footer = build_footer(session),
    footer_pos = "center",
    backdrop = 60,
    fixbuf = true,
    bo = {
      filetype = "markdown",
      modifiable = false,
      buftype = "nofile",
    },
    wo = {
      conceallevel = 2,
      wrap = true,
      cursorline = false,
      signcolumn = "no",
      winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,FloatTitle:RecallTitle,FloatFooter:RecallFooter",
    },
  })

  if win.add_padding then
    win:add_padding()
  end

  current_win = win
  render_buffer(win, session)
  setup_dynamic_keymaps()
end

return M
