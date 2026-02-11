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

  table.insert(lines, "  " .. string.rep("#", card.heading_level) .. " " .. card.question)
  table.insert(lines, "")

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

--- Start a split buffer review session
---@param session RecallSession
function M.start(session)
  if #session.queue == 0 then
    vim.notify("[recall.nvim] No cards due for review in this deck.", vim.log.levels.INFO)
    return
  end

  -- Create a new buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = false

  -- Open in a split
  vim.cmd("botright split")
  vim.api.nvim_set_current_buf(buf)

  local split_win = vim.api.nvim_get_current_win()

  local function close()
    if vim.api.nvim_win_is_valid(split_win) then
      vim.api.nvim_win_close(split_win, true)
    end
  end

  local function setup_keymaps()
    local keys = config.opts.rating_keys or { again = "1", hard = "2", good = "3", easy = "4" }
    local show_key = config.opts.show_answer_key or "<Space>"
    local quit_key = config.opts.quit_key or "q"

    vim.keymap.set("n", show_key, function()
      if not session.answer_shown then
        review.show_answer(session)
        render_answer(buf, session)
      end
    end, { buffer = buf, nowait = true })

    local function rate_and_advance(rating)
      return function()
        if not session.answer_shown then
          return
        end

        review.rate(session, rating)

        if review.is_complete(session) then
          render_complete(buf, session)
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

    vim.keymap.set("n", quit_key, close, { buffer = buf, nowait = true })
  end

  setup_keymaps()
  render_question(buf, session)
end

return M
