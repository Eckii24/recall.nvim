local M = {}

local review = require("recall.review")
local config = require("recall.config")

--- Render the question view in the buffer
---@param buf integer
---@param session RecallSession
local function render_question(buf, session)
  local card = review.current_card(session)
  if not card then
    return
  end

  local progress = review.progress(session)
  local lines = {
    "  Deck: " .. session.deck.name,
    "  Card " .. progress.current .. " / " .. progress.total,
    "",
    "  ─────────────────────────────",
    "",
  }

  -- Add question with heading markup
  table.insert(lines, "  " .. string.rep("#", card.heading_level) .. " " .. card.question)
  table.insert(lines, "")
  table.insert(lines, "")

  local show_key = config.opts.show_answer_key or "<Space>"
  table.insert(lines, "         [" .. show_key .. "] Show Answer")
  table.insert(lines, "")

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

--- Render the answer view in the buffer
---@param buf integer
---@param session RecallSession
local function render_answer(buf, session)
  local card = review.current_card(session)
  if not card then
    return
  end

  local progress = review.progress(session)
  local lines = {
    "  Deck: " .. session.deck.name,
    "  Card " .. progress.current .. " / " .. progress.total,
    "",
    "  ─────────────────────────────",
    "",
  }

  -- Add question
  table.insert(lines, "  " .. string.rep("#", card.heading_level) .. " " .. card.question)
  table.insert(lines, "")

  -- Add answer
  for answer_line in card.answer:gmatch("[^\n]*") do
    table.insert(lines, "  " .. answer_line)
  end

  table.insert(lines, "")
  table.insert(lines, "  ─────────────────────────────")
  table.insert(lines, "")

  local keys = config.opts.rating_keys or { again = "1", hard = "2", good = "3", easy = "4" }
  table.insert(lines, "  [" .. keys.again .. "] Again  [" .. keys.hard .. "] Hard  [" .. keys.good .. "] Good  [" .. keys.easy .. "] Easy")
  table.insert(lines, "")

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

--- Render the completion summary
---@param buf integer
---@param session RecallSession
local function render_complete(buf, session)
  local total = #session.queue
  local lines = {
    "",
    "  ✅ Review Complete!",
    "",
    "  " .. total .. " card" .. (total == 1 and "" or "s") .. " reviewed.",
    "",
  }

  -- Count ratings
  local counts = { again = 0, hard = 0, good = 0, easy = 0 }
  for _, result in ipairs(session.results) do
    counts[result.rating] = (counts[result.rating] or 0) + 1
  end

  table.insert(lines, "  Results:")
  table.insert(lines, "    Again: " .. counts.again)
  table.insert(lines, "    Hard:  " .. counts.hard)
  table.insert(lines, "    Good:  " .. counts.good)
  table.insert(lines, "    Easy:  " .. counts.easy)
  table.insert(lines, "")
  table.insert(lines, "  Press any key to close.")
  table.insert(lines, "")

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

--- Start a floating window review session
---@param session RecallSession
function M.start(session)
  if #session.queue == 0 then
    vim.notify("[recall.nvim] No cards due for review in this deck.", vim.log.levels.INFO)
    return
  end

  local ok_snacks, Snacks = pcall(require, "snacks")
  if not ok_snacks then
    vim.notify("[recall.nvim] snacks.nvim is required for floating window mode", vim.log.levels.ERROR)
    return
  end

  local win = Snacks.win({
    position = "float",
    width = 0.7,
    height = 0.7,
    border = "rounded",
    title = " recall.nvim ",
    bo = {
      filetype = "markdown",
      modifiable = false,
      buftype = "nofile",
    },
  })

  local buf = win.buf

  local function close()
    if win and vim.api.nvim_win_is_valid(win.win) then
      win:close()
    end
  end

  local function setup_keymaps()
    local keys = config.opts.rating_keys or { again = "1", hard = "2", good = "3", easy = "4" }
    local show_key = config.opts.show_answer_key or "<Space>"
    local quit_key = config.opts.quit_key or "q"

    -- Show answer keymap
    vim.keymap.set("n", show_key, function()
      if not session.answer_shown then
        review.show_answer(session)
        render_answer(buf, session)
      end
    end, { buffer = buf, nowait = true })

    -- Rating keymaps
    local function rate_and_advance(rating)
      return function()
        if not session.answer_shown then
          return
        end

        review.rate(session, rating)

        if review.is_complete(session) then
          render_complete(buf, session)
          -- Set up close on any key
          vim.keymap.set("n", "<CR>", close, { buffer = buf, nowait = true })
          vim.keymap.set("n", show_key, close, { buffer = buf, nowait = true })
          vim.keymap.set("n", quit_key, close, { buffer = buf, nowait = true })
        else
          render_question(buf, session)
        end
      end
    end

    vim.keymap.set("n", keys.again, rate_and_advance("again"), { buffer = buf, nowait = true })
    vim.keymap.set("n", keys.hard, rate_and_advance("hard"), { buffer = buf, nowait = true })
    vim.keymap.set("n", keys.good, rate_and_advance("good"), { buffer = buf, nowait = true })
    vim.keymap.set("n", keys.easy, rate_and_advance("easy"), { buffer = buf, nowait = true })

    -- Quit keymap
    vim.keymap.set("n", quit_key, close, { buffer = buf, nowait = true })
  end

  setup_keymaps()
  render_question(buf, session)
end

return M
