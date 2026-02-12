local stats = require("recall.stats")

--- Helper: build a deck with given card states
local function make_deck(name, card_states)
  local cards = {}
  for i, state in ipairs(card_states) do
    table.insert(cards, {
      id = name .. "_card_" .. i,
      question = "Q" .. i,
      answer = "A" .. i,
      line_number = i * 3,
      heading_level = 2,
      state = state,
    })
  end
  return {
    name = name,
    filepath = "/tmp/" .. name .. ".md",
    cards = cards,
    total = #cards,
    due = 0, -- not used by stats module
  }
end

local today = os.date("%Y-%m-%d")

-- =================================================================
-- deck_stats tests
-- =================================================================

local function test_deck_stats_empty_deck()
  local deck = make_deck("empty", {})
  local s = stats.deck_stats(deck)
  assert(s.total == 0, "Total should be 0")
  assert(s.due == 0, "Due should be 0")
  assert(s.new_cards == 0, "New should be 0")
  assert(s.mature_cards == 0, "Mature should be 0")
  assert(s.young_cards == 0, "Young should be 0")
end

local function test_deck_stats_new_cards()
  local deck = make_deck("new", {
    { ease = 2.5, interval = 0, reps = 0, due = today },
    { ease = 2.5, interval = 0, reps = 0, due = today },
  })
  local s = stats.deck_stats(deck)
  assert(s.total == 2, "Total should be 2, got " .. s.total)
  assert(s.new_cards == 2, "New should be 2, got " .. s.new_cards)
  assert(s.due == 2, "Due should be 2 (new cards are due), got " .. s.due)
end

local function test_deck_stats_mature_cards()
  local deck = make_deck("mature", {
    { ease = 2.5, interval = 30, reps = 5, due = "2099-12-31" },
    { ease = 2.5, interval = 60, reps = 8, due = "2099-12-31" },
  })
  local s = stats.deck_stats(deck)
  assert(s.mature_cards == 2, "Mature should be 2, got " .. s.mature_cards)
  assert(s.young_cards == 0, "Young should be 0, got " .. s.young_cards)
  assert(s.new_cards == 0, "New should be 0, got " .. s.new_cards)
end

local function test_deck_stats_young_cards()
  local deck = make_deck("young", {
    { ease = 2.5, interval = 1, reps = 1, due = "2099-12-31" },
    { ease = 2.5, interval = 6, reps = 2, due = "2099-12-31" },
    { ease = 2.5, interval = 21, reps = 4, due = "2099-12-31" },
  })
  local s = stats.deck_stats(deck)
  assert(s.young_cards == 3, "Young should be 3 (intervals 1, 6, 21), got " .. s.young_cards)
  assert(s.mature_cards == 0, "Mature should be 0, got " .. s.mature_cards)
end

local function test_deck_stats_mixed()
  local deck = make_deck("mixed", {
    { ease = 2.5, interval = 0, reps = 0, due = today },         -- new, due
    { ease = 2.5, interval = 5, reps = 2, due = "2099-12-31" },  -- young, not due
    { ease = 2.5, interval = 30, reps = 5, due = "2020-01-01" }, -- mature, due
  })
  local s = stats.deck_stats(deck)
  assert(s.total == 3, "Total should be 3")
  assert(s.new_cards == 1, "New should be 1")
  assert(s.young_cards == 1, "Young should be 1")
  assert(s.mature_cards == 1, "Mature should be 1")
  assert(s.due == 2, "Due should be 2 (new + past-due mature)")
end

local function test_deck_stats_due_today_counted()
  local deck = make_deck("due", {
    { ease = 2.5, interval = 1, reps = 1, due = today },
  })
  local s = stats.deck_stats(deck)
  assert(s.due == 1, "Card due today should be counted, got " .. s.due)
end

local function test_deck_stats_interval_boundary_21()
  -- interval=21 is young, interval=22 is mature
  local deck = make_deck("boundary", {
    { ease = 2.5, interval = 21, reps = 4, due = "2099-12-31" },
    { ease = 2.5, interval = 22, reps = 4, due = "2099-12-31" },
  })
  local s = stats.deck_stats(deck)
  assert(s.young_cards == 1, "interval=21 should be young, got young=" .. s.young_cards)
  assert(s.mature_cards == 1, "interval=22 should be mature, got mature=" .. s.mature_cards)
end

-- =================================================================
-- compute (aggregate) tests
-- =================================================================

local function test_compute_empty_decks()
  local s = stats.compute({})
  assert(s.total_cards == 0, "Total should be 0")
  assert(s.due_today == 0, "Due should be 0")
  assert(s.new_cards == 0, "New should be 0")
  assert(#s.decks_summary == 0, "Summary should be empty")
end

local function test_compute_aggregates_multiple_decks()
  local deck1 = make_deck("d1", {
    { ease = 2.5, interval = 0, reps = 0, due = today },
    { ease = 2.5, interval = 30, reps = 5, due = "2099-12-31" },
  })
  local deck2 = make_deck("d2", {
    { ease = 2.5, interval = 6, reps = 2, due = "2099-12-31" },
  })

  local s = stats.compute({ deck1, deck2 })
  assert(s.total_cards == 3, "Total should be 3, got " .. s.total_cards)
  assert(s.due_today == 1, "Due should be 1, got " .. s.due_today)
  assert(s.new_cards == 1, "New should be 1, got " .. s.new_cards)
  assert(s.mature_cards == 1, "Mature should be 1, got " .. s.mature_cards)
  assert(s.young_cards == 1, "Young should be 1, got " .. s.young_cards)
end

local function test_compute_decks_summary()
  local deck1 = make_deck("alpha", {
    { ease = 2.5, interval = 0, reps = 0, due = today },
  })
  local deck2 = make_deck("beta", {
    { ease = 2.5, interval = 30, reps = 5, due = "2099-12-31" },
  })

  local s = stats.compute({ deck1, deck2 })
  assert(#s.decks_summary == 2, "Should have 2 deck summaries")
  assert(s.decks_summary[1].name == "alpha", "First summary name should be 'alpha'")
  assert(s.decks_summary[2].name == "beta", "Second summary name should be 'beta'")
end

local function test_compute_reviewed_today()
  -- "Reviewed today" = reps > 0 and due > today
  -- This means a card was reviewed and pushed to a future date
  local deck = make_deck("reviewed", {
    { ease = 2.5, interval = 1, reps = 1, due = "2099-01-01" }, -- reviewed, due in future
    { ease = 2.5, interval = 0, reps = 0, due = today },        -- new, not reviewed
  })
  local s = stats.compute({ deck })
  assert(s.reviewed_today == 1, "Reviewed today should be 1, got " .. s.reviewed_today)
end

-- =================================================================
-- display tests (smoke test — just verify it doesn't error)
-- =================================================================

local function test_display_does_not_error()
  local s = {
    total_cards = 10,
    due_today = 3,
    new_cards = 2,
    reviewed_today = 5,
    mature_cards = 4,
    young_cards = 4,
    decks_summary = {
      { name = "deck1", total = 5, due = 2 },
      { name = "deck2", total = 5, due = 1 },
    },
  }
  local ok, err = pcall(stats.display, s)
  assert(ok, "display should not error: " .. tostring(err))
end

-- =================================================================
-- Runner
-- =================================================================

local tests = {
  { "deck_stats empty deck", test_deck_stats_empty_deck },
  { "deck_stats new cards", test_deck_stats_new_cards },
  { "deck_stats mature cards", test_deck_stats_mature_cards },
  { "deck_stats young cards", test_deck_stats_young_cards },
  { "deck_stats mixed", test_deck_stats_mixed },
  { "deck_stats due today counted", test_deck_stats_due_today_counted },
  { "deck_stats interval boundary 21", test_deck_stats_interval_boundary_21 },
  { "compute empty decks", test_compute_empty_decks },
  { "compute aggregates multiple decks", test_compute_aggregates_multiple_decks },
  { "compute decks summary", test_compute_decks_summary },
  { "compute reviewed today", test_compute_reviewed_today },
  { "display does not error", test_display_does_not_error },
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

print(string.format("\nStats: %d passed, %d failed", passed, failed))
if failed > 0 then
  vim.cmd("cquit! 1")
end
