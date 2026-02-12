local parser = require("recall.parser")

local function test_tagged_mode_parses_flashcard_headings()
  local lines = {
    "# My Notes",
    "",
    "## What is Neovim? #flashcard",
    "",
    "A hyperextensible Vim-based text editor.",
    "",
    "## What is Lua? #flashcard",
    "",
    "A lightweight scripting language.",
  }

  local cards = parser.parse(lines, { auto_mode = false })

  assert(#cards == 2, "Expected 2 cards, got " .. #cards)
  assert(cards[1].question == "What is Neovim?", "Question mismatch: " .. cards[1].question)
  assert(cards[1].answer == "A hyperextensible Vim-based text editor.", "Answer mismatch: " .. cards[1].answer)
  assert(cards[2].question == "What is Lua?", "Question mismatch: " .. cards[2].question)
  assert(cards[1].id ~= nil and cards[1].id ~= "", "Card ID should be non-empty")
  assert(cards[1].id ~= cards[2].id, "Card IDs should be unique")
end

local function test_tagged_mode_ignores_untagged_headings()
  local lines = {
    "## Regular heading",
    "",
    "Some text.",
    "",
    "## Tagged heading #flashcard",
    "",
    "Answer here.",
  }

  local cards = parser.parse(lines, { auto_mode = false })
  assert(#cards == 1, "Expected 1 card, got " .. #cards)
  assert(cards[1].question == "Tagged heading", "Question mismatch: " .. cards[1].question)
end

local function test_auto_mode_captures_all_headings()
  local lines = {
    "# Title",
    "",
    "## Question One",
    "",
    "Answer one.",
    "",
    "## Question Two",
    "",
    "Answer two.",
  }

  local cards = parser.parse(lines, { auto_mode = true, min_heading_level = 2 })
  assert(#cards == 2, "Expected 2 cards in auto mode, got " .. #cards)
  assert(cards[1].question == "Question One", "Question mismatch: " .. cards[1].question)
end

local function test_auto_mode_skips_headings_above_min_level()
  local lines = {
    "# Title",
    "",
    "## Should be card",
    "",
    "Answer.",
  }

  local cards = parser.parse(lines, { auto_mode = true, min_heading_level = 2 })
  assert(#cards == 1, "Expected 1 card (H1 skipped), got " .. #cards)
end

local function test_code_blocks_not_parsed_as_headings()
  local lines = {
    "## Real card #flashcard",
    "",
    "```markdown",
    "## This is inside a code block #flashcard",
    "```",
    "",
    "The answer.",
  }

  local cards = parser.parse(lines, { auto_mode = false })
  assert(#cards == 1, "Expected 1 card (code block heading ignored), got " .. #cards)
end

local function test_deterministic_card_ids()
  local lines = {
    "## Same question #flashcard",
    "",
    "Answer.",
  }

  local cards1 = parser.parse(lines, { auto_mode = false })
  local cards2 = parser.parse(lines, { auto_mode = false })
  assert(cards1[1].id == cards2[1].id, "Card IDs should be deterministic")
end

local function test_multiline_answer()
  local lines = {
    "## Question #flashcard",
    "",
    "Line 1.",
    "Line 2.",
    "Line 3.",
  }

  local cards = parser.parse(lines, { auto_mode = false })
  assert(#cards == 1, "Expected 1 card, got " .. #cards)
  assert(cards[1].answer:find("Line 1") ~= nil, "Answer should contain Line 1")
  assert(cards[1].answer:find("Line 3") ~= nil, "Answer should contain Line 3")
end

local tests = {
  { "tagged mode parses flashcard headings", test_tagged_mode_parses_flashcard_headings },
  { "tagged mode ignores untagged headings", test_tagged_mode_ignores_untagged_headings },
  { "auto mode captures all headings", test_auto_mode_captures_all_headings },
  { "auto mode skips headings above min level", test_auto_mode_skips_headings_above_min_level },
  { "code blocks not parsed as headings", test_code_blocks_not_parsed_as_headings },
  { "deterministic card IDs", test_deterministic_card_ids },
  { "multiline answer", test_multiline_answer },
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

print(string.format("\nParser: %d passed, %d failed", passed, failed))
if failed > 0 then
  vim.cmd("cquit! 1")
end
