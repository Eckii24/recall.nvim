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

local function test_again_resets_to_interval_1()
  local state = { ease = 2.5, interval = 10, reps = 5, due = os.date("%Y-%m-%d") }
  local new = scheduler.schedule(state, "again")

  assert(new.interval == 1, "Again should reset interval to 1, got " .. new.interval)
  assert(new.reps == 0, "Again should reset reps to 0, got " .. new.reps)
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

  -- interval = ceil(6 * 2.5) = 15; but ease changes first iteration to 2.36,
  -- so for second pass: ceil(6 * 2.5) = 15; actually ease is applied after interval calc
  -- SM-2: interval = ceil(old_interval * old_ease) = ceil(6 * 2.5) = 15
  assert(new.interval == 15, "Third good review: interval should be 15, got " .. new.interval)
  assert(new.reps == 3, "Third good review: reps should be 3, got " .. new.reps)
end

local function test_ease_never_below_1_3()
  local state = { ease = 1.3, interval = 1, reps = 0, due = os.date("%Y-%m-%d") }

  -- "again" (quality=0) decreases ease by 0.8
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

local tests = {
  { "new card defaults", test_new_card_defaults },
  { "new card is due", test_new_card_is_due },
  { "again resets to interval 1", test_again_resets_to_interval_1 },
  { "good first review", test_good_first_review },
  { "good second review", test_good_second_review },
  { "good third review uses ease", test_good_third_review_uses_ease },
  { "ease never below 1.3", test_ease_never_below_1_3 },
  { "easy increases ease", test_easy_increases_ease },
  { "hard decreases ease", test_hard_decreases_ease },
  { "due date is in future after review", test_due_date_is_in_future_after_review },
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
