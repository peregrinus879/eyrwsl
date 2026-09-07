local function review(picker, opts)
  local path = vim.api.nvim_buf_get_name(0)
  if vim.bo.filetype == "neo-tree" then
    local state = require("neo-tree.sources.manager").get_state_for_window()
    local node = state and state.tree and state.tree:get_node()
    path = (node and node.path) or (state and state.path)
  elseif vim.bo.buftype ~= "" or path == "" then
    path = vim.fn.getcwd()
  end

  -- New/deleted paths need a physical ancestor, never a lexical repo across a symlink.
  local root
  local probe = path
  while probe and probe ~= "" do
    local resolved, _, code = vim.uv.fs_realpath(probe)
    if resolved then
      root = vim.fs.root(resolved, ".git")
      break
    end
    if code ~= "ENOENT" then
      break
    end
    local stat, _, stat_code = vim.uv.fs_lstat(probe)
    if stat or stat_code ~= "ENOENT" then
      break
    end
    local parent = vim.fs.dirname(probe)
    if parent == probe then
      break
    end
    probe = parent
  end
  if not root then
    vim.notify(
      "No Git repository found for " .. (path and path ~= "" and path or "the current Neo-tree view"),
      vim.log.levels.WARN
    )
    return
  end

  opts = opts or {}
  opts.cwd = root
  Snacks.picker[picker](opts)
end

return {
  {
    "folke/snacks.nvim",
    keys = {
      {
        "<leader>gd",
        function()
          review("git_diff")
        end,
        desc = "Git Diff (hunks)",
      },
      {
        "<leader>gD",
        function()
          review("git_diff", { base = "origin", group = true })
        end,
        desc = "Git Diff (origin)",
      },
      {
        "<leader>gs",
        function()
          review("git_status")
        end,
        desc = "Git Status",
      },
    },
  },
}
