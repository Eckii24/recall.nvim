local storage = require("recall.storage")

local test_dir = vim.fn.tempname()
vim.fn.mkdir(test_dir, "p")

local function test_load_returns_empty_for_missing_file()
  local data = storage.load(test_dir .. "/nonexistent.json")
  assert(data.version == 1, "Version should be 1")
  assert(data.cards ~= nil, "Cards table should exist")
  assert(next(data.cards) == nil, "Cards should be empty")
end

local function test_save_and_load_roundtrip()
  local path = test_dir .. "/test_roundtrip.json"
  local data = {
    version = 1,
    cards = {
      ["abc123"] = { ease = 2.5, interval = 1, reps = 1, due = "2025-01-01" },
    },
  }

  storage.save(path, data)
  local loaded = storage.load(path)

  assert(loaded.version == 1, "Version mismatch")
  assert(loaded.cards["abc123"] ~= nil, "Card should exist")
  assert(loaded.cards["abc123"].ease == 2.5, "Ease mismatch")
  assert(loaded.cards["abc123"].interval == 1, "Interval mismatch")
  assert(loaded.cards["abc123"].due == "2025-01-01", "Due mismatch")
end

local function test_load_handles_corrupted_json()
  local path = test_dir .. "/corrupted.json"
  local f = io.open(path, "w")
  f:write("{invalid json content")
  f:close()

  local data = storage.load(path)
  assert(data.version == 1, "Should return fresh state for corrupted JSON")
  assert(next(data.cards) == nil, "Should have empty cards for corrupted JSON")
end

local function test_get_and_set_card_state()
  local data = { version = 1, cards = {} }
  local state = { ease = 2.5, interval = 6, reps = 2, due = "2025-06-01" }

  storage.set_card_state(data, "card_1", state)
  local retrieved = storage.get_card_state(data, "card_1")

  assert(retrieved ~= nil, "Card state should be retrievable")
  assert(retrieved.ease == 2.5, "Ease mismatch")
  assert(retrieved.interval == 6, "Interval mismatch")
end

local function test_get_card_state_returns_nil_for_missing()
  local data = { version = 1, cards = {} }
  local result = storage.get_card_state(data, "nonexistent")
  assert(result == nil, "Should return nil for missing card")
end

local function test_sidecar_path()
  local md_path = "/home/user/notes/deck.md"
  local sidecar = storage.sidecar_path(md_path)
  assert(sidecar == "/home/user/notes/deck.flashcards.json", "Sidecar path mismatch: " .. sidecar)
end

local function test_save_returns_true_on_success()
  local path = test_dir .. "/success_test.json"
  local result = storage.save(path, { version = 1, cards = {} })
  assert(result == true, "Save should return true on success")
end

local function test_multiple_cards_roundtrip()
  local path = test_dir .. "/multi_cards.json"
  local data = {
    version = 1,
    cards = {
      ["card_a"] = { ease = 2.5, interval = 1, reps = 0, due = "2025-01-01" },
      ["card_b"] = { ease = 2.36, interval = 6, reps = 2, due = "2025-02-01" },
      ["card_c"] = { ease = 1.3, interval = 30, reps = 10, due = "2025-03-01" },
    },
  }

  storage.save(path, data)
  local loaded = storage.load(path)

  assert(loaded.cards["card_a"] ~= nil, "card_a should exist")
  assert(loaded.cards["card_b"] ~= nil, "card_b should exist")
  assert(loaded.cards["card_c"] ~= nil, "card_c should exist")
  assert(loaded.cards["card_c"].reps == 10, "card_c reps should be 10")
end

local function test_set_card_state_overwrites_existing()
  local data = { version = 1, cards = {} }
  storage.set_card_state(data, "card_1", { ease = 2.5, interval = 1, reps = 0, due = "2025-01-01" })
  storage.set_card_state(data, "card_1", { ease = 2.36, interval = 6, reps = 2, due = "2025-02-01" })

  local retrieved = storage.get_card_state(data, "card_1")
  assert(retrieved.interval == 6, "Overwritten interval should be 6, got " .. retrieved.interval)
  assert(retrieved.reps == 2, "Overwritten reps should be 2, got " .. retrieved.reps)
end

local function test_load_handles_invalid_structure()
  local path = test_dir .. "/invalid_structure.json"
  local f = io.open(path, "w")
  f:write('{"foo": "bar"}')
  f:close()

  local data = storage.load(path)
  assert(data.version == 1, "Should return fresh state for invalid structure")
  assert(next(data.cards) == nil, "Cards should be empty for invalid structure")
end

local function test_load_handles_empty_file()
  local path = test_dir .. "/empty.json"
  local f = io.open(path, "w")
  f:write("")
  f:close()

  local data = storage.load(path)
  assert(data.version == 1, "Should return fresh state for empty file")
end

local function test_get_card_state_nil_data()
  local result = storage.get_card_state(nil, "card_1")
  assert(result == nil, "Should return nil for nil data")
end

local function test_sidecar_path_nested_dir()
  local md_path = "/a/b/c/d/notes.md"
  local sidecar = storage.sidecar_path(md_path)
  assert(sidecar == "/a/b/c/d/notes.flashcards.json", "Sidecar path for nested dir: " .. sidecar)
end

local tests = {
  { "load returns empty for missing file", test_load_returns_empty_for_missing_file },
  { "save and load roundtrip", test_save_and_load_roundtrip },
  { "load handles corrupted JSON", test_load_handles_corrupted_json },
  { "get and set card state", test_get_and_set_card_state },
  { "get card state returns nil for missing", test_get_card_state_returns_nil_for_missing },
  { "sidecar path", test_sidecar_path },
  { "save returns true on success", test_save_returns_true_on_success },
  { "multiple cards roundtrip", test_multiple_cards_roundtrip },
  { "set card state overwrites existing", test_set_card_state_overwrites_existing },
  { "load handles invalid structure", test_load_handles_invalid_structure },
  { "load handles empty file", test_load_handles_empty_file },
  { "get card state with nil data", test_get_card_state_nil_data },
  { "sidecar path nested dir", test_sidecar_path_nested_dir },
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

print(string.format("\nStorage: %d passed, %d failed", passed, failed))

vim.fn.delete(test_dir, "rf")

if failed > 0 then
  vim.cmd("cquit! 1")
end
