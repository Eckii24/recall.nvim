if vim.g.loaded_recall then
  return
end
vim.g.loaded_recall = true

vim.api.nvim_create_user_command("Recall", function(opts)
  require("recall.commands").dispatch(opts.fargs)
end, {
  nargs = "*",
  complete = function(ArgLead, CmdLine, CursorPos)
    return require("recall.commands").complete(ArgLead, CmdLine, CursorPos)
  end,
})
