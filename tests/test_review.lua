local review = require("recall.review")
local scheduler = require("recall.scheduler")
local storage = require("recall.storage")

local test_dir = vim.fn.tempname()
vim.fn.mkdir(test_dir, "p")

local function make_test_deck(card_count)
  card_count = card_count or 3
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

  return {
    name = "test_deck",
    filepath = test_dir .. "/test.md",
    cards = cards,
    total = card_count,
    due = card_count,
  }
end

local function test_new_session_creates_queue_of_due_cards()
  local deck = make_test_deck(3)
  local session = review.new_session(deck)

  assert(session.queue ~= nil, "Queue should exist")
  assert(#session.queue == 3, "Queue should have 3 due cards, got " .. #session.queue)
  assert(session.current_index == 1, "Should start at index 1")
  assert(session.answer_shown == false, "Answer should not be shown initially")
end

local function test_new_session_filters_non_due_cards()
  local deck = make_test_deck(3)
  deck.cards[2].state.due = "2099-01-01"

  local session = review.new_session(deck)
  assert(#session.queue == 2, "Queue should have 2 due cards (1 not due), got " .. #session.queue)
end

local function test_current_card_returns_first_card()
  local deck = make_test_deck(1)
  local session = review.new_session(deck)

  local card = review.current_card(session)
  assert(card ~= nil, "Current card should not be nil")
  assert(card.question == "Question 1", "Should return first card")
end

local function test_show_answer_sets_flag()
  local deck = make_test_deck(1)
  local session = review.new_session(deck)

  assert(session.answer_shown == false, "Answer should start hidden")
  review.show_answer(session)
  assert(session.answer_shown == true, "Answer should be shown after show_answer()")
end

local function test_rate_advances_to_next_card()
  local deck = make_test_deck(2)

  local md_path = test_dir .. "/test.md"
  local f = io.open(md_path, "w")
  f:write("# Test\n\n## Q1 #flashcard\n\nA1\n\n## Q2 #flashcard\n\nA2\n")
  f:close()

  local session = review.new_session(deck)
  review.show_answer(session)
  review.rate(session, "good")

  assert(session.current_index == 2, "Should advance to card 2, got " .. session.current_index)
  assert(session.answer_shown == false, "Answer should be reset after rating")
end

local function test_is_complete_after_all_cards_rated()
  local deck = make_test_deck(1)

  local md_path = test_dir .. "/test.md"
  local f = io.open(md_path, "w")
  f:write("# Test\n")
  f:close()

  local session = review.new_session(deck)
  assert(review.is_complete(session) == false, "Should not be complete at start")

  review.show_answer(session)
  review.rate(session, "good")

  assert(review.is_complete(session) == true, "Should be complete after rating all cards")
end

local function test_progress_tracking()
  local deck = make_test_deck(3)
  local session = review.new_session(deck)

  local prog = review.progress(session)
  assert(prog.total == 3, "Total should be 3")
  assert(prog.current == 1, "Current should be 1")
  assert(prog.remaining == 3, "Remaining should be 3")
end

local function test_deck_has_filepath_field()
  local deck = make_test_deck(1)
  assert(deck.filepath ~= nil, "Deck should have 'filepath' field")
  assert(type(deck.filepath) == "string", "filepath should be a string")

  local deck_name = vim.fn.fnamemodify(deck.filepath, ":t")
  assert(deck_name == "test.md", "fnamemodify on filepath should work, got: " .. tostring(deck_name))
end

local function test_current_card_nil_when_complete()
  local deck = make_test_deck(1)

  local md_path = test_dir .. "/test.md"
  local f = io.open(md_path, "w")
  f:write("# Test\n")
  f:close()

  local session = review.new_session(deck)
  review.show_answer(session)
  review.rate(session, "good")

  local card = review.current_card(session)
  assert(card == nil, "Current card should be nil when complete")
end

local tests = {
  { "new session creates queue of due cards", test_new_session_creates_queue_of_due_cards },
  { "new session filters non-due cards", test_new_session_filters_non_due_cards },
  { "current card returns first card", test_current_card_returns_first_card },
  { "show answer sets flag", test_show_answer_sets_flag },
  { "rate advances to next card", test_rate_advances_to_next_card },
  { "is complete after all cards rated", test_is_complete_after_all_cards_rated },
  { "progress tracking", test_progress_tracking },
  { "deck has filepath field (not source_file)", test_deck_has_filepath_field },
  { "current card nil when complete", test_current_card_nil_when_complete },
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

print(string.format("\nReview: %d passed, %d failed", passed, failed))

vim.fn.delete(test_dir, "rf")

if failed > 0 then
  vim.cmd("cquit! 1")
end
