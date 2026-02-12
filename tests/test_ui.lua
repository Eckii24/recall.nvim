local review = require("recall.review")
local config = require("recall.config")

local function make_session(n_cards)
  local cards = {}
  for i = 1, n_cards do
    table.insert(cards, {
      id = "card_" .. i,
      question = "Question " .. i,
      answer = "Answer " .. i,
      line_number = i * 3,
      heading_level = 2,
      state = { ease = 2.5, interval = 0, reps = 0, due = os.date("%Y-%m-%d") },
    })
  end

  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local filepath = dir .. "/test.md"
  local f = io.open(filepath, "w")
  if f then f:write("# test\n") f:close() end

  local deck = {
    name = "test",
    filepath = filepath,
    cards = cards,
    total = #cards,
    due = #cards,
    sidecar_suffix = ".flashcards.json",
  }

  return review.new_session(deck)
end

local function test_float_render_modifiable_toggle()
  config.setup({})
  local session = make_session(1)

  local Snacks = require("snacks")
  local win = Snacks.win({
    position = "float",
    width = 0.7,
    height = 0.7,
    bo = {
      filetype = "markdown",
      modifiable = false,
    },
  })

  assert(vim.bo[win.buf].modifiable == false, "Buffer should start non-modifiable")

  vim.bo[win.buf].modifiable = true
  vim.api.nvim_buf_set_lines(win.buf, 0, -1, false, { "test line" })
  vim.bo[win.buf].modifiable = false

  assert(vim.bo[win.buf].modifiable == false, "Buffer should be non-modifiable after set_lines")

  local lines = vim.api.nvim_buf_get_lines(win.buf, 0, -1, false)
  assert(#lines >= 1, "Buffer should have content")
  assert(lines[1] == "test line", "Buffer content should match")

  local ok, _ = pcall(vim.api.nvim_buf_set_lines, win.buf, 0, -1, false, { "should fail" })
  assert(not ok, "Writing to non-modifiable buffer should error")

  win:close()
end

local function test_split_render_modifiable_toggle()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = false

  assert(vim.bo[buf].modifiable == false, "Buffer should start non-modifiable")

  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "split content" })
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  assert(vim.bo[buf].modifiable == false, "Buffer should be non-modifiable after write")

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  assert(lines[1] == "split content", "Content should match")

  pcall(vim.api.nvim_buf_delete, buf, { force = true })
end

local function test_float_render_complete_session()
  config.setup({})
  local session = make_session(1)
  review.rate(session, "good")
  assert(review.is_complete(session), "Session should be complete")

  local Snacks = require("snacks")
  local win = Snacks.win({
    position = "float",
    bo = { modifiable = false },
  })

  vim.bo[win.buf].modifiable = true
  vim.api.nvim_buf_set_lines(win.buf, 0, -1, false, {
    "", "  Review complete!", "", "  1 cards reviewed.", "",
  })
  vim.bo[win.buf].modifiable = false

  local lines = vim.api.nvim_buf_get_lines(win.buf, 0, -1, false)
  local found_complete = false
  for _, line in ipairs(lines) do
    if line:find("Review complete") then found_complete = true end
  end
  assert(found_complete, "Completion message should be rendered")

  win:close()
end

local function test_float_render_question_only()
  config.setup({})
  local session = make_session(1)
  assert(session.answer_shown == false, "Answer should not be shown")

  local Snacks = require("snacks")
  local win = Snacks.win({
    position = "float",
    bo = { modifiable = false },
  })

  local card = review.current_card(session)
  vim.bo[win.buf].modifiable = true
  vim.api.nvim_buf_set_lines(win.buf, 0, -1, false, {
    "", "  " .. card.question, "", "  [<Space>] Show Answer", "",
  })
  vim.bo[win.buf].modifiable = false

  local lines = vim.api.nvim_buf_get_lines(win.buf, 0, -1, false)
  local found_question = false
  local found_answer = false
  for _, line in ipairs(lines) do
    if line:find(card.question) then found_question = true end
    if line:find(card.answer) then found_answer = true end
  end
  assert(found_question, "Question should be visible")
  assert(not found_answer, "Answer should NOT be visible before show_answer")

  win:close()
end

local function test_float_render_with_answer()
  config.setup({})
  local session = make_session(1)
  review.show_answer(session)
  assert(session.answer_shown == true, "Answer should be shown")

  local Snacks = require("snacks")
  local win = Snacks.win({
    position = "float",
    bo = { modifiable = false },
  })

  local card = review.current_card(session)
  vim.bo[win.buf].modifiable = true
  vim.api.nvim_buf_set_lines(win.buf, 0, -1, false, {
    "", "  " .. card.question, "", "  " .. card.answer, "",
    "  [1] Again  [2] Hard  [3] Good  [4] Easy", "",
  })
  vim.bo[win.buf].modifiable = false

  local lines = vim.api.nvim_buf_get_lines(win.buf, 0, -1, false)
  local found_answer = false
  local found_rating = false
  for _, line in ipairs(lines) do
    if line:find(card.answer) then found_answer = true end
    if line:find("Again") and line:find("Easy") then found_rating = true end
  end
  assert(found_answer, "Answer should be visible after show_answer")
  assert(found_rating, "Rating buttons should be visible")

  win:close()
end

local function test_session_uses_filepath_not_source_file()
  local session = make_session(1)
  assert(session.deck.filepath ~= nil, "Session deck should have 'filepath' field")
  assert(session.deck.source_file == nil, "Session deck should NOT have 'source_file' field")
end

local function test_multiple_modifiable_cycles()
  local Snacks = require("snacks")
  local win = Snacks.win({
    position = "float",
    bo = { modifiable = false },
  })

  for i = 1, 5 do
    vim.bo[win.buf].modifiable = true
    vim.api.nvim_buf_set_lines(win.buf, 0, -1, false, { "cycle " .. i })
    vim.bo[win.buf].modifiable = false
    assert(vim.bo[win.buf].modifiable == false, "Should be non-modifiable after cycle " .. i)
  end

  local lines = vim.api.nvim_buf_get_lines(win.buf, 0, -1, false)
  assert(lines[1] == "cycle 5", "Last cycle content should persist")

  win:close()
end

local tests = {
  { "float render modifiable toggle", test_float_render_modifiable_toggle },
  { "split render modifiable toggle", test_split_render_modifiable_toggle },
  { "float render complete session", test_float_render_complete_session },
  { "float render question only", test_float_render_question_only },
  { "float render with answer", test_float_render_with_answer },
  { "session uses filepath not source_file", test_session_uses_filepath_not_source_file },
  { "multiple modifiable cycles", test_multiple_modifiable_cycles },
}

local passed, failed = 0, 0
for _, test in ipairs(tests) do
  local name, fn = test[1], test[2]
  local ok, err = pcall(fn)
  if ok then
    print("  PASS: " .. name)
    passed = passed + 1
  else
    print("  FAIL: " .. name .. " - " .. tostring(err))
    failed = failed + 1
  end
end

print(string.format("\nUI: %d passed, %d failed", passed, failed))
if failed > 0 then
  vim.cmd("cquit! 1")
end
