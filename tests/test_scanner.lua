local scanner = require("recall.scanner")
local storage = require("recall.storage")
local scheduler = require("recall.scheduler")
local config = require("recall.config")

--- Helper: create a temp directory
local function tmpdir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  return dir
end

--- Helper: write a file with given content
local function write_file(path, content)
  local f = io.open(path, "w")
  assert(f, "Could not create file: " .. path)
  f:write(content)
  f:close()
end

-- =================================================================
-- Tests
-- =================================================================

local function test_scan_file_returns_deck()
  local dir = tmpdir()
  local filepath = dir .. "/notes.md"
  write_file(filepath, "## What is Lua? #flashcard\n\nA scripting language.\n")

  local deck = scanner.scan_file(filepath)

  assert(deck ~= nil, "Deck should not be nil")
  assert(deck.name == "notes", "Deck name should be 'notes', got " .. deck.name)
  assert(deck.filepath == filepath, "Deck filepath should match")
  assert(deck.total == 1, "Total should be 1, got " .. deck.total)
  assert(#deck.cards == 1, "Should have 1 card")

  -- Cleanup
  os.remove(filepath)
end

local function test_scan_file_card_structure()
  local dir = tmpdir()
  local filepath = dir .. "/cards.md"
  write_file(filepath, "## Question here #flashcard\n\nAnswer content.\n")

  local deck = scanner.scan_file(filepath)
  local card = deck.cards[1]

  assert(card.id ~= nil, "Card should have an id")
  assert(card.question == "Question here", "Question mismatch: " .. card.question)
  assert(card.answer:find("Answer content") ~= nil, "Answer should contain 'Answer content'")
  assert(card.line_number ~= nil, "Card should have line_number")
  assert(card.heading_level == 2, "Heading level should be 2")
  assert(card.state ~= nil, "Card should have state")
  assert(card.state.ease == 2.5, "Default ease should be 2.5")
  assert(card.state.reps == 0, "Default reps should be 0")

  os.remove(filepath)
end

local function test_scan_file_new_cards_are_due()
  local dir = tmpdir()
  local filepath = dir .. "/due.md"
  write_file(filepath, "## Q1 #flashcard\n\nA1.\n\n## Q2 #flashcard\n\nA2.\n")

  local deck = scanner.scan_file(filepath)

  assert(deck.due == 2, "All new cards should be due, got " .. deck.due)

  os.remove(filepath)
end

local function test_scan_file_with_existing_sidecar()
  local dir = tmpdir()
  local filepath = dir .. "/existing.md"
  write_file(filepath, "## Known card #flashcard\n\nAnswer.\n")

  -- Parse once to get the card ID
  local deck = scanner.scan_file(filepath)
  local card_id = deck.cards[1].id

  -- Create sidecar with existing state
  local sidecar = storage.sidecar_path(filepath)
  local data = { version = 1, cards = {} }
  data.cards[card_id] = { ease = 3.0, interval = 15, reps = 4, due = "2099-12-31" }
  storage.save(sidecar, data)

  -- Re-scan: should merge with sidecar state
  local deck2 = scanner.scan_file(filepath)
  local card = deck2.cards[1]

  assert(card.state.ease == 3.0, "Ease should come from sidecar, got " .. card.state.ease)
  assert(card.state.interval == 15, "Interval should come from sidecar, got " .. card.state.interval)
  assert(card.state.reps == 4, "Reps should come from sidecar, got " .. card.state.reps)
  assert(card.state.due == "2099-12-31", "Due should come from sidecar")
  assert(deck2.due == 0, "Card not due, due count should be 0, got " .. deck2.due)

  os.remove(filepath)
  os.remove(sidecar)
end

local function test_scan_file_auto_mode()
  local dir = tmpdir()
  local filepath = dir .. "/auto.md"
  write_file(filepath, "# Title\n\n## Card A\n\nAns A.\n\n## Card B\n\nAns B.\n")

  local deck = scanner.scan_file(filepath, { auto_mode = true, min_heading_level = 2 })

  assert(deck.total == 2, "Auto mode should find 2 cards, got " .. deck.total)

  os.remove(filepath)
end

local function test_scan_file_no_cards()
  local dir = tmpdir()
  local filepath = dir .. "/empty.md"
  write_file(filepath, "# Just a title\n\nNo flashcards here.\n")

  local deck = scanner.scan_file(filepath)

  assert(deck.total == 0, "Should have 0 cards, got " .. deck.total)
  assert(#deck.cards == 0, "Cards array should be empty")
  assert(deck.due == 0, "Due should be 0")

  os.remove(filepath)
end

local function test_scan_directory()
  local dir = tmpdir()
  write_file(dir .. "/a.md", "## Q1 #flashcard\n\nA1.\n")
  write_file(dir .. "/b.md", "## Q2 #flashcard\n\nA2.\n")

  config.setup({ dirs = { dir } })
  local decks = scanner.scan({ dir })

  assert(#decks == 2, "Should find 2 decks, got " .. #decks)

  local names = {}
  for _, d in ipairs(decks) do names[d.name] = true end
  assert(names["a"], "Should find deck 'a'")
  assert(names["b"], "Should find deck 'b'")

  os.remove(dir .. "/a.md")
  os.remove(dir .. "/b.md")
end

local function test_scan_ignores_non_md_files()
  local dir = tmpdir()
  write_file(dir .. "/notes.md", "## Card #flashcard\n\nAnswer.\n")
  write_file(dir .. "/readme.txt", "Not a markdown file.\n")

  config.setup({ dirs = { dir } })
  local decks = scanner.scan({ dir })

  assert(#decks == 1, "Should only find .md files, got " .. #decks)
  assert(decks[1].name == "notes", "Deck name should be 'notes'")

  os.remove(dir .. "/notes.md")
  os.remove(dir .. "/readme.txt")
end

local function test_scan_multiple_dirs()
  local dir1 = tmpdir()
  local dir2 = tmpdir()
  write_file(dir1 .. "/d1.md", "## Q1 #flashcard\n\nA.\n")
  write_file(dir2 .. "/d2.md", "## Q2 #flashcard\n\nA.\n")

  config.setup({ dirs = { dir1, dir2 } })
  local decks = scanner.scan({ dir1, dir2 })

  assert(#decks == 2, "Should find 2 decks from 2 dirs, got " .. #decks)

  os.remove(dir1 .. "/d1.md")
  os.remove(dir2 .. "/d2.md")
end

local function test_scan_empty_directory()
  local dir = tmpdir()
  config.setup({ dirs = { dir } })
  local decks = scanner.scan({ dir })
  assert(#decks == 0, "Empty dir should yield 0 decks, got " .. #decks)
end

local function test_deck_filepath_is_absolute()
  local dir = tmpdir()
  write_file(dir .. "/abs.md", "## Q #flashcard\n\nA.\n")

  local deck = scanner.scan_file(dir .. "/abs.md")
  assert(deck.filepath:sub(1, 1) == "/", "Filepath should be absolute, got: " .. deck.filepath)

  os.remove(dir .. "/abs.md")
end

local function test_deck_name_is_filename_without_extension()
  local dir = tmpdir()
  write_file(dir .. "/my-notes.md", "## Q #flashcard\n\nA.\n")

  local deck = scanner.scan_file(dir .. "/my-notes.md")
  assert(deck.name == "my-notes", "Name should be 'my-notes', got " .. deck.name)

  os.remove(dir .. "/my-notes.md")
end

-- =================================================================
-- Runner
-- =================================================================

local tests = {
  { "scan_file returns deck", test_scan_file_returns_deck },
  { "scan_file card structure", test_scan_file_card_structure },
  { "scan_file new cards are due", test_scan_file_new_cards_are_due },
  { "scan_file with existing sidecar", test_scan_file_with_existing_sidecar },
  { "scan_file auto mode", test_scan_file_auto_mode },
  { "scan_file no cards", test_scan_file_no_cards },
  { "scan directory", test_scan_directory },
  { "scan ignores non-md files", test_scan_ignores_non_md_files },
  { "scan multiple dirs", test_scan_multiple_dirs },
  { "scan empty directory", test_scan_empty_directory },
  { "deck filepath is absolute", test_deck_filepath_is_absolute },
  { "deck name is filename without extension", test_deck_name_is_filename_without_extension },
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

print(string.format("\nScanner: %d passed, %d failed", passed, failed))
if failed > 0 then
  vim.cmd("cquit! 1")
end
