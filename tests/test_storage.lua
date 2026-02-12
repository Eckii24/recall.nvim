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
  assert(sidecar == "/home/user/notes/.flashcards.json", "Sidecar path mismatch: " .. sidecar)
end

local tests = {
  { "load returns empty for missing file", test_load_returns_empty_for_missing_file },
  { "save and load roundtrip", test_save_and_load_roundtrip },
  { "load handles corrupted JSON", test_load_handles_corrupted_json },
  { "get and set card state", test_get_and_set_card_state },
  { "get card state returns nil for missing", test_get_card_state_returns_nil_for_missing },
  { "sidecar path", test_sidecar_path },
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
