local scheduler = require("recall.scheduler")
local storage = require("recall.storage")
local review = require("recall.review")

--- Helper: create a temporary directory and return its path
local function tmpdir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  return dir
end

--- Helper: create a deck with N cards, all due today
local function make_deck(n, dir)
  dir = dir or tmpdir()
  local filepath = dir .. "/test.md"
  -- Touch the file so sidecar_path resolves
  local f = io.open(filepath, "w")
  if f then f:write("# test\n") f:close() end

  local cards = {}
  for i = 1, n do
    table.insert(cards, {
      id = "card_" .. i,
      question = "Question " .. i,
      answer = "Answer " .. i,
      line_number = i * 3,
      heading_level = 2,
      state = scheduler.new_card(), -- due today
    })
  end

  return {
    name = "test",
    filepath = filepath,
    cards = cards,
    total = #cards,
    due = #cards,
  }
end

--- Helper: create a deck with a mix of due and future cards
local function make_mixed_deck()
  local dir = tmpdir()
  local filepath = dir .. "/mixed.md"
  local f = io.open(filepath, "w")
  if f then f:write("# mixed\n") f:close() end

  return {
    name = "mixed",
    filepath = filepath,
    cards = {
      {
        id = "due_1",
        question = "Due Q1",
        answer = "Due A1",
        line_number = 1,
        heading_level = 2,
        state = { ease = 2.5, interval = 0, reps = 0, due = os.date("%Y-%m-%d") },
      },
      {
        id = "future_1",
        question = "Future Q1",
        answer = "Future A1",
        line_number = 4,
        heading_level = 2,
        state = { ease = 2.5, interval = 10, reps = 3, due = "2099-12-31" },
      },
      {
        id = "due_2",
        question = "Due Q2",
        answer = "Due A2",
        line_number = 7,
        heading_level = 2,
        state = { ease = 2.5, interval = 0, reps = 0, due = "2020-01-01" },
      },
    },
    total = 3,
    due = 2,
  }
end

-- =================================================================
-- Tests
-- =================================================================

local function test_new_session_creates_session()
  local deck = make_deck(3)
  local session = review.new_session(deck)
  assert(session ~= nil, "Session should not be nil")
  assert(session.deck == deck, "Session deck should match input")
  assert(session.current_index == 1, "Current index should start at 1")
  assert(session.answer_shown == false, "Answer should not be shown initially")
  assert(type(session.results) == "table", "Results should be a table")
  assert(#session.results == 0, "Results should be empty initially")
end

local function test_new_session_only_queues_due_cards()
  local deck = make_mixed_deck()
  local session = review.new_session(deck)
  -- Only 2 cards are due (due_1 and due_2), future_1 is not
  assert(#session.queue == 2, "Queue should have 2 due cards, got " .. #session.queue)

  local ids = {}
  for _, card in ipairs(session.queue) do
    ids[card.id] = true
  end
  assert(ids["due_1"], "due_1 should be in queue")
  assert(ids["due_2"], "due_2 should be in queue")
  assert(not ids["future_1"], "future_1 should NOT be in queue")
end

local function test_new_session_empty_queue_when_no_due()
  local dir = tmpdir()
  local filepath = dir .. "/none.md"
  local f = io.open(filepath, "w")
  if f then f:write("# none\n") f:close() end

  local deck = {
    name = "none",
    filepath = filepath,
    cards = {
      {
        id = "far_future",
        question = "Q",
        answer = "A",
        line_number = 1,
        heading_level = 2,
        state = { ease = 2.5, interval = 10, reps = 3, due = "2099-12-31" },
      },
    },
    total = 1,
    due = 0,
  }

  local session = review.new_session(deck)
  assert(#session.queue == 0, "Queue should be empty when no cards are due")
  assert(review.is_complete(session), "Session should be complete with empty queue")
end

local function test_current_card_returns_first_card()
  local deck = make_deck(2)
  local session = review.new_session(deck)
  local card = review.current_card(session)
  assert(card ~= nil, "Current card should not be nil")
  -- It's one of the cards (order is shuffled)
  assert(card.question ~= nil, "Card should have a question")
end

local function test_current_card_nil_when_complete()
  local deck = make_deck(0)
  deck.cards = {}
  local session = review.new_session(deck)
  local card = review.current_card(session)
  assert(card == nil, "Current card should be nil when session is complete")
end

local function test_show_answer_sets_flag()
  local deck = make_deck(1)
  local session = review.new_session(deck)
  assert(session.answer_shown == false, "Answer should start hidden")
  review.show_answer(session)
  assert(session.answer_shown == true, "Answer should be shown after show_answer()")
end

local function test_rate_advances_to_next_card()
  local deck = make_deck(3)
  local session = review.new_session(deck)
  assert(session.current_index == 1, "Should start at index 1")

  review.rate(session, "good")

  assert(session.current_index == 2, "Should advance to index 2 after rating")
  assert(session.answer_shown == false, "Answer should reset to hidden after rating")
end

local function test_rate_stores_result()
  local deck = make_deck(1)
  local session = review.new_session(deck)
  local card = review.current_card(session)

  review.rate(session, "good")

  assert(#session.results == 1, "Should have 1 result after rating")
  assert(session.results[1].card_id == card.id, "Result card_id should match")
  assert(session.results[1].rating == "good", "Result rating should be 'good'")
  assert(session.results[1].old_state ~= nil, "Result should have old_state")
  assert(session.results[1].new_state ~= nil, "Result should have new_state")
end

local function test_rate_updates_card_state()
  local deck = make_deck(1)
  local session = review.new_session(deck)
  local card = review.current_card(session)
  local old_reps = card.state.reps

  review.rate(session, "good")

  -- Card state should be updated
  assert(card.state.reps == old_reps + 1, "Card reps should increment after 'good'")
  assert(card.state.interval == 1, "First good review: interval should be 1")
end

local function test_rate_persists_to_storage()
  local dir = tmpdir()
  local deck = make_deck(1, dir)
  local session = review.new_session(deck)
  local card = review.current_card(session)

  review.rate(session, "easy")

  -- Verify data was written to sidecar
  local json_path = storage.sidecar_path(deck.filepath)
  local data = storage.load(json_path)
  local persisted = storage.get_card_state(data, card.id)

  assert(persisted ~= nil, "Card state should be persisted to storage")
  assert(persisted.reps == 1, "Persisted reps should be 1")
  assert(persisted.interval == 1, "Persisted interval should be 1")

  -- Cleanup
  os.remove(json_path)
  os.remove(deck.filepath)
end

local function test_rate_errors_when_complete()
  local deck = make_deck(0)
  deck.cards = {}
  local session = review.new_session(deck)

  local ok, err = pcall(review.rate, session, "good")
  assert(not ok, "Rating a complete session should error")
  assert(err:find("No card to rate"), "Error should mention no card to rate")
end

local function test_is_complete_false_when_cards_remain()
  local deck = make_deck(2)
  local session = review.new_session(deck)
  assert(review.is_complete(session) == false, "Should not be complete with 2 cards")
end

local function test_is_complete_true_after_all_rated()
  local deck = make_deck(2)
  local session = review.new_session(deck)

  review.rate(session, "good")
  assert(review.is_complete(session) == false, "Should not be complete after 1 of 2")

  review.rate(session, "good")
  assert(review.is_complete(session) == true, "Should be complete after 2 of 2")
end

local function test_progress_initial()
  local deck = make_deck(3)
  local session = review.new_session(deck)
  local prog = review.progress(session)
  assert(prog.current == 1, "Current should be 1, got " .. prog.current)
  assert(prog.total == 3, "Total should be 3, got " .. prog.total)
  assert(prog.remaining == 3, "Remaining should be 3, got " .. prog.remaining)
end

local function test_progress_after_one_rating()
  local deck = make_deck(3)
  local session = review.new_session(deck)
  review.rate(session, "good")
  local prog = review.progress(session)
  assert(prog.current == 2, "Current should be 2, got " .. prog.current)
  assert(prog.total == 3, "Total should be 3, got " .. prog.total)
  assert(prog.remaining == 2, "Remaining should be 2, got " .. prog.remaining)
end

local function test_progress_when_complete()
  local deck = make_deck(1)
  local session = review.new_session(deck)
  review.rate(session, "good")
  local prog = review.progress(session)
  assert(prog.remaining == 0, "Remaining should be 0 when complete, got " .. prog.remaining)
end

local function test_session_uses_deck_filepath()
  local dir = tmpdir()
  local deck = make_deck(1, dir)
  local session = review.new_session(deck)
  assert(session.deck.filepath ~= nil, "Deck should have filepath")
  assert(session.deck.filepath:find("/test.md$") ~= nil, "Filepath should end with /test.md")

  -- Cleanup
  os.remove(deck.filepath)
end

local function test_rate_all_ratings()
  local ratings = { "again", "hard", "good", "easy" }
  for _, rating in ipairs(ratings) do
    local deck = make_deck(1)
    local session = review.new_session(deck)
    local ok, err = pcall(review.rate, session, rating)
    assert(ok, "Rating '" .. rating .. "' should not error: " .. tostring(err))
    assert(review.is_complete(session), "Session should be complete after rating 1 card")
  end
end

local function test_session_stats_counts_ratings()
  local deck = make_deck(4)
  local session = review.new_session(deck)

  review.rate(session, "again")
  review.rate(session, "hard")
  review.rate(session, "good")
  review.rate(session, "easy")

  local stats = review.session_stats(session)
  assert(stats.total == 4, "Total should be 4, got " .. stats.total)
  assert(stats.again == 1, "Again should be 1, got " .. stats.again)
  assert(stats.hard == 1, "Hard should be 1, got " .. stats.hard)
  assert(stats.good == 1, "Good should be 1, got " .. stats.good)
  assert(stats.easy == 1, "Easy should be 1, got " .. stats.easy)
end

local function test_session_stats_empty_session()
  local deck = make_deck(2)
  local session = review.new_session(deck)

  local stats = review.session_stats(session)
  assert(stats.total == 0, "Total should be 0, got " .. stats.total)
  assert(stats.again == 0, "Again should be 0, got " .. stats.again)
end

-- =================================================================
-- Runner
-- =================================================================

local tests = {
  { "new session creates session", test_new_session_creates_session },
  { "new session only queues due cards", test_new_session_only_queues_due_cards },
  { "new session empty queue when no due", test_new_session_empty_queue_when_no_due },
  { "current card returns first card", test_current_card_returns_first_card },
  { "current card nil when complete", test_current_card_nil_when_complete },
  { "show answer sets flag", test_show_answer_sets_flag },
  { "rate advances to next card", test_rate_advances_to_next_card },
  { "rate stores result", test_rate_stores_result },
  { "rate updates card state", test_rate_updates_card_state },
  { "rate persists to storage", test_rate_persists_to_storage },
  { "rate errors when complete", test_rate_errors_when_complete },
  { "is_complete false when cards remain", test_is_complete_false_when_cards_remain },
  { "is_complete true after all rated", test_is_complete_true_after_all_rated },
  { "progress initial", test_progress_initial },
  { "progress after one rating", test_progress_after_one_rating },
  { "progress when complete", test_progress_when_complete },
  { "session uses deck filepath", test_session_uses_deck_filepath },
  { "rate all ratings", test_rate_all_ratings },
  { "session stats counts ratings", test_session_stats_counts_ratings },
  { "session stats empty session", test_session_stats_empty_session },
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
if failed > 0 then
  vim.cmd("cquit! 1")
end
