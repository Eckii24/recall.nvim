local commands = require("recall.commands")
local config = require("recall.config")

local function test_complete_returns_subcommands()
  config.setup({})
  local result = commands.complete("", "Recall ")
  assert(type(result) == "table", "complete should return a table")

  local has_review = false
  local has_stats = false
  local has_scan = false
  for _, cmd in ipairs(result) do
    if cmd == "review" then has_review = true end
    if cmd == "stats" then has_stats = true end
    if cmd == "scan" then has_scan = true end
  end
  assert(has_review, "Should have 'review' subcommand")
  assert(has_stats, "Should have 'stats' subcommand")
  assert(has_scan, "Should have 'scan' subcommand")
end

local function test_complete_filters_by_prefix()
  config.setup({})
  local result = commands.complete("re", "Recall re")

  local found = false
  for _, cmd in ipairs(result) do
    if cmd == "review" then found = true end
    assert(cmd:match("^re"), "All completions should start with 're', got: " .. cmd)
  end
  assert(found, "Should include 'review' when filtering by 're'")
end

local function test_complete_no_match()
  config.setup({})
  local result = commands.complete("xyz", "Recall xyz")
  assert(#result == 0, "No completions should match 'xyz', got " .. #result)
end

local function test_dispatch_unknown_shows_usage()
  config.setup({})
  local notified = false
  local orig_notify = vim.notify
  vim.notify = function(msg)
    if msg:find("Usage") then notified = true end
  end

  commands.dispatch({})

  vim.notify = orig_notify
  assert(notified, "Empty dispatch should show usage")
end

local function test_dispatch_unknown_subcommand_shows_usage()
  config.setup({})
  local notified = false
  local orig_notify = vim.notify
  vim.notify = function(msg)
    if msg:find("Usage") then notified = true end
  end

  commands.dispatch({ "nonexistent" })

  vim.notify = orig_notify
  assert(notified, "Unknown subcommand should show usage")
end

local function test_dispatch_stats_no_dirs_warns()
  config.setup({ dirs = {} })
  local warned = false
  local orig_notify = vim.notify
  vim.notify = function(msg, level)
    if msg:find("No directories configured") and level == vim.log.levels.WARN then
      warned = true
    end
  end

  commands.dispatch({ "stats" })

  vim.notify = orig_notify
  assert(warned, "stats with no dirs should warn")
end

local function test_dispatch_review_no_dirs_warns()
  config.setup({ dirs = {} })
  local warned = false
  local orig_notify = vim.notify
  vim.notify = function(msg, level)
    if msg:find("No directories configured") and level == vim.log.levels.WARN then
      warned = true
    end
  end

  commands.dispatch({ "review", "somefile" })

  vim.notify = orig_notify
  assert(warned, "review with named deck and no dirs should warn")
end

local function test_dispatch_scan_no_dirs_warns()
  config.setup({ dirs = {} })
  local warned = false
  local orig_notify = vim.notify
  vim.notify = function(msg, level)
    if msg:find("No directories configured") and level == vim.log.levels.WARN then
      warned = true
    end
  end

  commands.dispatch({ "scan" })

  vim.notify = orig_notify
  assert(warned, "scan with no dirs should warn")
end

local function test_dispatch_scan_with_dir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local f = io.open(dir .. "/test.md", "w")
  if f then f:write("## Q #flashcard\n\nA.\n") f:close() end

  config.setup({})
  local scan_msg = nil
  local orig_notify = vim.notify
  vim.notify = function(msg)
    if msg:find("Scanned") then scan_msg = msg end
  end

  commands.dispatch({ "scan", dir })

  vim.notify = orig_notify
  assert(scan_msg ~= nil, "scan should report results")
  assert(scan_msg:find("1 decks") ~= nil, "Should find 1 deck")

  os.remove(dir .. "/test.md")
end

local function test_dispatch_review_named_deck_not_found()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  config.setup({ dirs = { dir } })

  local warned = false
  local orig_notify = vim.notify
  vim.notify = function(msg, level)
    if msg:find("not found") and level == vim.log.levels.WARN then
      warned = true
    end
  end

  commands.dispatch({ "review", "nonexistent" })

  vim.notify = orig_notify
  assert(warned, "Should warn when named deck not found")
end

local function test_complete_review_includes_dot()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  config.setup({ dirs = { dir } })

  local result = commands.complete("", "Recall review ")

  local has_dot = false
  for _, item in ipairs(result) do
    if item == "." then has_dot = true end
  end
  assert(has_dot, "Review completion should include '.'")
end

local tests = {
  { "complete returns subcommands", test_complete_returns_subcommands },
  { "complete filters by prefix", test_complete_filters_by_prefix },
  { "complete no match", test_complete_no_match },
  { "dispatch unknown shows usage", test_dispatch_unknown_shows_usage },
  { "dispatch unknown subcommand shows usage", test_dispatch_unknown_subcommand_shows_usage },
  { "dispatch stats no dirs warns", test_dispatch_stats_no_dirs_warns },
  { "dispatch review no dirs warns", test_dispatch_review_no_dirs_warns },
  { "dispatch scan no dirs warns", test_dispatch_scan_no_dirs_warns },
  { "dispatch scan with dir", test_dispatch_scan_with_dir },
  { "dispatch review named deck not found", test_dispatch_review_named_deck_not_found },
  { "complete review includes dot", test_complete_review_includes_dot },
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

print(string.format("\nCommands: %d passed, %d failed", passed, failed))
if failed > 0 then
  vim.cmd("cquit! 1")
end
