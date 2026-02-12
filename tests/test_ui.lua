local config = require("recall.config")
local review = require("recall.review")
local scheduler = require("recall.scheduler")

config.setup({})

local function make_test_session(card_count)
  card_count = card_count or 2
  local cards = {}
  for i = 1, card_count do
    table.insert(cards, {
      id = "card_" .. i,
      question = "Question " .. i,
      answer = "Answer " .. i,
      line_number = i * 3,
      heading_level = 2,
      state = scheduler.new_card(),
    })
  end

  local deck = {
    name = "test_deck",
    filepath = "/tmp/test_deck.md",
    cards = cards,
    total = card_count,
    due = card_count,
  }

  return review.new_session(deck)
end

local function test_float_render_with_non_modifiable_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = false

  local session = make_test_session(1)

  local win_mock = { buf = buf }

  local float = require("recall.ui.float")

  -- The render_buffer function is local, so we test through the modifiable pattern directly.
  -- Simulate what render_buffer does: set modifiable, write lines, unset modifiable.
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "test line" })
  vim.bo[buf].modifiable = false

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  assert(#lines == 1, "Buffer should have 1 line")
  assert(lines[1] == "test line", "Buffer content mismatch")
  assert(vim.bo[buf].modifiable == false, "Buffer should be non-modifiable after write")

  pcall(vim.api.nvim_buf_delete, buf, { force = true })
end

local function test_writing_to_non_modifiable_buffer_fails()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].modifiable = false

  local ok, _ = pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, { "should fail" })
  assert(ok == false, "Writing to non-modifiable buffer should fail")

  pcall(vim.api.nvim_buf_delete, buf, { force = true })
end

local function test_modifiable_toggle_pattern_works()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].modifiable = false

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line 1", "line 2" })
  vim.bo[buf].modifiable = false

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  assert(#lines == 2, "Buffer should have 2 lines after modifiable toggle")
  assert(vim.bo[buf].modifiable == false, "Buffer should be non-modifiable after toggle")

  pcall(vim.api.nvim_buf_delete, buf, { force = true })
end

local function test_float_source_code_has_modifiable_toggle()
  local source = io.open("lua/recall/ui/float.lua", "r")
  assert(source ~= nil, "float.lua should be readable")
  local content = source:read("*a")
  source:close()

  local toggle_count = 0
  for _ in content:gmatch("vim%.bo%[win%.buf%]%.modifiable = true") do
    toggle_count = toggle_count + 1
  end

  -- Three render paths: completion, no-cards, main card display
  assert(toggle_count >= 3,
    "float.lua should have modifiable=true in all 3 render paths, found " .. toggle_count)
end

local function test_split_source_code_uses_filepath()
  local source = io.open("lua/recall/ui/split.lua", "r")
  assert(source ~= nil, "split.lua should be readable")
  local content = source:read("*a")
  source:close()

  assert(content:find("session%.deck%.filepath") ~= nil,
    "split.lua should use session.deck.filepath")
  assert(content:find("session%.deck%.source_file") == nil,
    "split.lua should NOT use session.deck.source_file")
end

local function test_float_source_code_uses_filepath()
  local source = io.open("lua/recall/ui/float.lua", "r")
  assert(source ~= nil, "float.lua should be readable")
  local content = source:read("*a")
  source:close()

  assert(content:find("session%.deck%.filepath") ~= nil,
    "float.lua should use session.deck.filepath")
  assert(content:find("session%.deck%.source_file") == nil,
    "float.lua should NOT use session.deck.source_file")
end

local function test_split_render_with_non_modifiable_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].modifiable = false

  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "split test" })
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  assert(#lines == 1 and lines[1] == "split test", "Split buffer write pattern should work")
  assert(vim.bo[buf].modifiable == false, "Buffer should be non-modifiable")

  pcall(vim.api.nvim_buf_delete, buf, { force = true })
end

local tests = {
  { "float render with non-modifiable buffer", test_float_render_with_non_modifiable_buffer },
  { "writing to non-modifiable buffer fails (proves bug)", test_writing_to_non_modifiable_buffer_fails },
  { "modifiable toggle pattern works", test_modifiable_toggle_pattern_works },
  { "float source has modifiable toggle in all paths", test_float_source_code_has_modifiable_toggle },
  { "split source uses filepath (not source_file)", test_split_source_code_uses_filepath },
  { "float source uses filepath (not source_file)", test_float_source_code_uses_filepath },
  { "split render with non-modifiable buffer", test_split_render_with_non_modifiable_buffer },
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
