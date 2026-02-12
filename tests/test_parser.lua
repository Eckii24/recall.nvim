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

local function test_empty_file_returns_no_cards()
  local cards = parser.parse({}, { auto_mode = false })
  assert(#cards == 0, "Empty file should produce 0 cards, got " .. #cards)
end

local function test_no_headings_returns_no_cards()
  local lines = { "Just some text.", "No headings here." }
  local cards = parser.parse(lines, { auto_mode = false })
  assert(#cards == 0, "No headings should produce 0 cards, got " .. #cards)
end

local function test_card_has_line_number()
  local lines = { "# Title", "", "## Card question #flashcard", "", "Answer text." }
  local cards = parser.parse(lines, { auto_mode = false })
  assert(cards[1].line_number == 3, "Line number should be 3, got " .. cards[1].line_number)
end

local function test_card_has_heading_level()
  local lines = { "### Deep heading #flashcard", "", "Answer." }
  local cards = parser.parse(lines, { auto_mode = false })
  assert(cards[1].heading_level == 3, "Heading level should be 3, got " .. cards[1].heading_level)
end

local function test_flashcard_tag_stripped_from_question()
  local lines = { "## My Question #flashcard", "", "Answer." }
  local cards = parser.parse(lines, { auto_mode = false })
  assert(cards[1].question == "My Question", "Tag should be stripped: " .. cards[1].question)
  assert(not cards[1].question:find("#flashcard"), "Question should not contain #flashcard tag")
end

local function test_frontmatter_skipped()
  local lines = { "---", "title: My Notes", "date: 2025-01-01", "---", "", "## Card #flashcard", "", "Answer." }
  local cards = parser.parse(lines, { auto_mode = false })
  assert(#cards == 1, "Should parse card after frontmatter, got " .. #cards)
  assert(cards[1].question == "Card", "Question mismatch: " .. cards[1].question)
end

local function test_answer_bounded_by_same_level_heading()
  local lines = {
    "## First #flashcard", "", "Answer to first.", "",
    "## Second #flashcard", "", "Answer to second.",
  }
  local cards = parser.parse(lines, { auto_mode = false })
  assert(#cards == 2, "Expected 2 cards, got " .. #cards)
  assert(not cards[1].answer:find("Answer to second"), "First card should not include second card's answer")
end

local function test_auto_mode_with_min_heading_level_3()
  local lines = { "# H1", "", "## H2", "", "Text.", "", "### H3", "", "Text under H3." }
  local cards = parser.parse(lines, { auto_mode = true, min_heading_level = 3 })
  assert(#cards == 1, "Only H3+ should be cards with min_heading_level=3, got " .. #cards)
  assert(cards[1].question == "H3", "Question should be H3, got " .. cards[1].question)
end

local function test_different_questions_produce_different_ids()
  local cards1 = parser.parse({ "## Question A #flashcard", "", "A." }, { auto_mode = false })
  local cards2 = parser.parse({ "## Question B #flashcard", "", "B." }, { auto_mode = false })
  assert(cards1[1].id ~= cards2[1].id, "Different questions should have different IDs")
end

local function test_empty_answer_between_headings()
  local lines = { "## Q1 #flashcard", "", "## Q2 #flashcard", "", "Has answer." }
  local cards = parser.parse(lines, { auto_mode = false })
  assert(#cards == 2, "Expected 2 cards, got " .. #cards)
  assert(cards[1].answer == "", "First card should have empty answer, got: '" .. cards[1].answer .. "'")
end

local function test_subheadings_included_in_answer()
  local lines = {
    "## Main question #flashcard", "",
    "Intro text.", "",
    "### Sub-section", "",
    "Detail under sub.",
  }
  local cards = parser.parse(lines, { auto_mode = false })
  assert(#cards == 1, "Expected 1 card, got " .. #cards)
  assert(cards[1].answer:find("Detail under sub") ~= nil, "Answer should include sub-heading content")
end

local function test_default_opts_uses_tagged_mode()
  local lines = { "## Should not match", "", "Text.", "", "## Should match #flashcard", "", "Answer." }
  local cards = parser.parse(lines)
  assert(#cards == 1, "Default should use tagged mode, got " .. #cards)
end

local tests = {
  { "tagged mode parses flashcard headings", test_tagged_mode_parses_flashcard_headings },
  { "tagged mode ignores untagged headings", test_tagged_mode_ignores_untagged_headings },
  { "auto mode captures all headings", test_auto_mode_captures_all_headings },
  { "auto mode skips headings above min level", test_auto_mode_skips_headings_above_min_level },
  { "code blocks not parsed as headings", test_code_blocks_not_parsed_as_headings },
  { "deterministic card IDs", test_deterministic_card_ids },
  { "multiline answer", test_multiline_answer },
  { "empty file returns no cards", test_empty_file_returns_no_cards },
  { "no headings returns no cards", test_no_headings_returns_no_cards },
  { "card has line number", test_card_has_line_number },
  { "card has heading level", test_card_has_heading_level },
  { "flashcard tag stripped from question", test_flashcard_tag_stripped_from_question },
  { "frontmatter skipped", test_frontmatter_skipped },
  { "answer bounded by same level heading", test_answer_bounded_by_same_level_heading },
  { "auto mode with min_heading_level 3", test_auto_mode_with_min_heading_level_3 },
  { "different questions produce different IDs", test_different_questions_produce_different_ids },
  { "empty answer between headings", test_empty_answer_between_headings },
  { "subheadings included in answer", test_subheadings_included_in_answer },
  { "default opts uses tagged mode", test_default_opts_uses_tagged_mode },
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
