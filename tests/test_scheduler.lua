local scheduler = require("recall.scheduler")

local function test_new_card_defaults()
  local state = scheduler.new_card()
  assert(state.ease == 2.5, "Default ease should be 2.5, got " .. state.ease)
  assert(state.interval == 0, "Default interval should be 0, got " .. state.interval)
  assert(state.reps == 0, "Default reps should be 0, got " .. state.reps)
  assert(state.due ~= nil, "Due date should be set")
  assert(state.due:match("^%d%d%d%d%-%d%d%-%d%d$"), "Due should be ISO 8601: " .. state.due)
end

local function test_new_card_is_due()
  local state = scheduler.new_card()
  assert(scheduler.is_due(state) == true, "New card should be due immediately")
end

local function test_future_card_is_not_due()
  local state = { ease = 2.5, interval = 10, reps = 3, due = "2099-12-31" }
  assert(scheduler.is_due(state) == false, "Future card should not be due")
end

local function test_past_card_is_due()
  local state = { ease = 2.5, interval = 1, reps = 1, due = "2020-01-01" }
  assert(scheduler.is_due(state) == true, "Past due card should be due")
end

local function test_again_resets_to_interval_1()
  local state = { ease = 2.5, interval = 10, reps = 5, due = os.date("%Y-%m-%d") }
  local new = scheduler.schedule(state, "again")
  assert(new.interval == 1, "Again should reset interval to 1, got " .. new.interval)
  assert(new.reps == 0, "Again should reset reps to 0, got " .. new.reps)
end

local function test_hard_resets_reps()
  local state = { ease = 2.5, interval = 10, reps = 5, due = os.date("%Y-%m-%d") }
  local new = scheduler.schedule(state, "hard")
  -- quality=2, which is < 3, so reps resets
  assert(new.reps == 0, "Hard (quality=2) should reset reps to 0, got " .. new.reps)
  assert(new.interval == 1, "Hard should reset interval to 1, got " .. new.interval)
end

local function test_good_first_review()
  local state = scheduler.new_card()
  local new = scheduler.schedule(state, "good")
  assert(new.interval == 1, "First good review: interval should be 1, got " .. new.interval)
  assert(new.reps == 1, "First good review: reps should be 1, got " .. new.reps)
end

local function test_good_second_review()
  local state = { ease = 2.5, interval = 1, reps = 1, due = os.date("%Y-%m-%d") }
  local new = scheduler.schedule(state, "good")
  assert(new.interval == 6, "Second good review: interval should be 6, got " .. new.interval)
  assert(new.reps == 2, "Second good review: reps should be 2, got " .. new.reps)
end

local function test_good_third_review_uses_ease()
  local state = { ease = 2.5, interval = 6, reps = 2, due = os.date("%Y-%m-%d") }
  local new = scheduler.schedule(state, "good")
  -- SM-2: interval = ceil(old_interval * old_ease) = ceil(6 * 2.5) = 15
  assert(new.interval == 15, "Third good review: interval should be 15, got " .. new.interval)
  assert(new.reps == 3, "Third good review: reps should be 3, got " .. new.reps)
end

local function test_ease_never_below_1_3()
  local state = { ease = 1.3, interval = 1, reps = 0, due = os.date("%Y-%m-%d") }
  local new = scheduler.schedule(state, "again")
  assert(new.ease >= 1.3, "Ease should never go below 1.3, got " .. new.ease)
end

local function test_easy_increases_ease()
  local state = scheduler.new_card()
  local new = scheduler.schedule(state, "easy")
  assert(new.ease > 2.5, "Easy should increase ease above 2.5, got " .. new.ease)
end

local function test_hard_decreases_ease()
  local state = scheduler.new_card()
  local new = scheduler.schedule(state, "hard")
  assert(new.ease < 2.5, "Hard should decrease ease below 2.5, got " .. new.ease)
end

local function test_due_date_is_in_future_after_review()
  local state = scheduler.new_card()
  local new = scheduler.schedule(state, "good")
  local today = os.date("%Y-%m-%d")
  assert(new.due > today, "Due date should be in the future after review, got " .. new.due)
end

local function test_schedule_returns_all_fields()
  local state = scheduler.new_card()
  local new = scheduler.schedule(state, "good")
  assert(new.ease ~= nil, "ease must be present")
  assert(new.interval ~= nil, "interval must be present")
  assert(new.reps ~= nil, "reps must be present")
  assert(new.due ~= nil, "due must be present")
end

local function test_schedule_does_not_mutate_input()
  local state = { ease = 2.5, interval = 6, reps = 2, due = os.date("%Y-%m-%d") }
  local original_ease = state.ease
  local original_interval = state.interval
  scheduler.schedule(state, "good")
  assert(state.ease == original_ease, "Input ease should not be mutated")
  assert(state.interval == original_interval, "Input interval should not be mutated")
end

local function test_repeated_again_keeps_interval_at_1()
  local state = scheduler.new_card()
  for _ = 1, 5 do
    state = scheduler.schedule(state, "again")
    assert(state.interval == 1, "Repeated again should keep interval=1, got " .. state.interval)
    assert(state.reps == 0, "Repeated again should keep reps=0, got " .. state.reps)
  end
end

local function test_easy_first_review_interval_is_1()
  local state = scheduler.new_card()
  local new = scheduler.schedule(state, "easy")
  -- quality=5, reps=0 → interval=1, reps=1
  assert(new.interval == 1, "First easy review: interval should be 1, got " .. new.interval)
  assert(new.reps == 1, "First easy review: reps should be 1, got " .. new.reps)
end

local function test_ease_exact_value_after_good()
  local state = { ease = 2.5, interval = 1, reps = 0, due = os.date("%Y-%m-%d") }
  local new = scheduler.schedule(state, "good")
  -- quality=3: ease = 2.5 + (0.1 - (5-3) * (0.08 + (5-3)*0.02)) = 2.5 + (0.1 - 2*0.12) = 2.5 - 0.14 = 2.36
  local expected = 2.36
  assert(math.abs(new.ease - expected) < 0.001,
    string.format("Ease after good should be %.2f, got %.4f", expected, new.ease))
end

local function test_ease_exact_value_after_easy()
  local state = { ease = 2.5, interval = 1, reps = 0, due = os.date("%Y-%m-%d") }
  local new = scheduler.schedule(state, "easy")
  -- quality=5: ease = 2.5 + (0.1 - 0*(0.08 + 0*0.02)) = 2.5 + 0.1 = 2.6
  local expected = 2.6
  assert(math.abs(new.ease - expected) < 0.001,
    string.format("Ease after easy should be %.1f, got %.4f", expected, new.ease))
end

local function test_due_date_format()
  local state = scheduler.new_card()
  local new = scheduler.schedule(state, "good")
  assert(new.due:match("^%d%d%d%d%-%d%d%-%d%d$") ~= nil,
    "Due date should be YYYY-MM-DD format, got: " .. new.due)
end

local tests = {
  { "new card defaults", test_new_card_defaults },
  { "new card is due", test_new_card_is_due },
  { "future card is not due", test_future_card_is_not_due },
  { "past card is due", test_past_card_is_due },
  { "again resets to interval 1", test_again_resets_to_interval_1 },
  { "hard resets reps", test_hard_resets_reps },
  { "good first review", test_good_first_review },
  { "good second review", test_good_second_review },
  { "good third review uses ease", test_good_third_review_uses_ease },
  { "ease never below 1.3", test_ease_never_below_1_3 },
  { "easy increases ease", test_easy_increases_ease },
  { "hard decreases ease", test_hard_decreases_ease },
  { "due date is in future after review", test_due_date_is_in_future_after_review },
  { "schedule returns all fields", test_schedule_returns_all_fields },
  { "schedule does not mutate input", test_schedule_does_not_mutate_input },
  { "repeated again keeps interval at 1", test_repeated_again_keeps_interval_at_1 },
  { "easy first review interval is 1", test_easy_first_review_interval_is_1 },
  { "ease exact value after good", test_ease_exact_value_after_good },
  { "ease exact value after easy", test_ease_exact_value_after_easy },
  { "due date format", test_due_date_format },
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

print(string.format("\nScheduler: %d passed, %d failed", passed, failed))
if failed > 0 then
  vim.cmd("cquit! 1")
end
