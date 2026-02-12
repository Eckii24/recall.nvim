local config = require("recall.config")

local function test_setup_returns_opts()
  local opts = config.setup({})
  assert(type(opts) == "table", "setup should return a table")
end

local function test_default_dirs_empty()
  local opts = config.setup({})
  assert(type(opts.dirs) == "table", "dirs should be a table")
  assert(#opts.dirs == 0, "Default dirs should be empty")
end

local function test_default_auto_mode_false()
  local opts = config.setup({})
  assert(opts.auto_mode == false, "Default auto_mode should be false")
end

local function test_default_min_heading_level()
  local opts = config.setup({})
  assert(opts.min_heading_level == 2, "Default min_heading_level should be 2, got " .. opts.min_heading_level)
end

local function test_default_review_mode()
  local opts = config.setup({})
  assert(opts.review_mode == "float", "Default review_mode should be 'float', got " .. opts.review_mode)
end

local function test_default_rating_keys()
  local opts = config.setup({})
  assert(opts.rating_keys.again == "1", "again key should be '1'")
  assert(opts.rating_keys.hard == "2", "hard key should be '2'")
  assert(opts.rating_keys.good == "3", "good key should be '3'")
  assert(opts.rating_keys.easy == "4", "easy key should be '4'")
end

local function test_default_show_answer_key()
  local opts = config.setup({})
  assert(opts.show_answer_key == "<Space>", "Default show_answer_key should be '<Space>', got " .. opts.show_answer_key)
end

local function test_default_quit_key()
  local opts = config.setup({})
  assert(opts.quit_key == "q", "Default quit_key should be 'q', got " .. opts.quit_key)
end

local function test_default_initial_ease()
  local opts = config.setup({})
  assert(opts.initial_ease == 2.5, "Default initial_ease should be 2.5, got " .. opts.initial_ease)
end

local function test_default_sidecar_filename()
  local opts = config.setup({})
  assert(opts.sidecar_filename == ".flashcards.json",
    "Default sidecar_filename should be '.flashcards.json', got " .. opts.sidecar_filename)
end

local function test_setup_overrides_dirs()
  local opts = config.setup({ dirs = { "/tmp/notes" } })
  assert(#opts.dirs == 1, "dirs should have 1 entry")
  assert(opts.dirs[1] == "/tmp/notes", "dirs[1] should be '/tmp/notes'")
  -- Reset
  config.setup({})
end

local function test_setup_overrides_auto_mode()
  local opts = config.setup({ auto_mode = true })
  assert(opts.auto_mode == true, "auto_mode should be overridden to true")
  -- Reset
  config.setup({})
end

local function test_setup_deep_extends_rating_keys()
  local opts = config.setup({ rating_keys = { again = "a" } })
  assert(opts.rating_keys.again == "a", "again should be overridden to 'a'")
  -- Other keys should retain defaults
  assert(opts.rating_keys.hard == "2", "hard should retain default '2'")
  assert(opts.rating_keys.good == "3", "good should retain default '3'")
  assert(opts.rating_keys.easy == "4", "easy should retain default '4'")
  -- Reset
  config.setup({})
end

local function test_setup_stores_in_opts()
  config.setup({ review_mode = "split" })
  assert(config.opts.review_mode == "split", "config.opts should be updated")
  -- Reset
  config.setup({})
end

local function test_setup_with_nil_uses_defaults()
  local opts = config.setup(nil)
  assert(opts.review_mode == "float", "nil opts should use defaults")
  assert(opts.auto_mode == false, "nil opts should use defaults for auto_mode")
end

-- =================================================================
-- Runner
-- =================================================================

local tests = {
  { "setup returns opts", test_setup_returns_opts },
  { "default dirs empty", test_default_dirs_empty },
  { "default auto_mode false", test_default_auto_mode_false },
  { "default min_heading_level", test_default_min_heading_level },
  { "default review_mode", test_default_review_mode },
  { "default rating_keys", test_default_rating_keys },
  { "default show_answer_key", test_default_show_answer_key },
  { "default quit_key", test_default_quit_key },
  { "default initial_ease", test_default_initial_ease },
  { "default sidecar_filename", test_default_sidecar_filename },
  { "setup overrides dirs", test_setup_overrides_dirs },
  { "setup overrides auto_mode", test_setup_overrides_auto_mode },
  { "setup deep extends rating_keys", test_setup_deep_extends_rating_keys },
  { "setup stores in opts", test_setup_stores_in_opts },
  { "setup with nil uses defaults", test_setup_with_nil_uses_defaults },
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

print(string.format("\nConfig: %d passed, %d failed", passed, failed))
if failed > 0 then
  vim.cmd("cquit! 1")
end
