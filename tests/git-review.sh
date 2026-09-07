#!/bin/bash
# Mocked context/API contracts only: no Neovim, Git process, or filesystem fixtures.
# vim.fs.root results model .git directories/files and nested roots, not Git validity.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
LUA=$(command -v lua5.4 || command -v lua) || {
  printf 'FAIL: Lua is required for git-review tests\n' >&2
  exit 1
}

"$LUA" - "$ROOT/nvim/.config/nvim/lua/plugins/git-review.lua" <<'LUA'
local current, state, probes, calls, notices, cwd_reads, root_reads, realpath_reads, explorer_reads
local lstat_reads, dirname_reads
local bo = {}

-- Reject undeclared APIs and writes, including cwd mutation, subprocesses and globals.
local function readonly(values)
  return setmetatable({}, {
    __index = function(_, key)
      assert(values[key] ~= nil, "unexpected API: " .. tostring(key))
      return values[key]
    end,
    __newindex = function(_, key)
      error("unexpected write: " .. tostring(key))
    end,
  })
end

local function picker(name)
  return function(opts)
    calls[#calls + 1] = { name = name, opts = opts }
  end
end

local env = readonly({
  vim = readonly({
    bo = readonly(bo),
    api = readonly({ nvim_buf_get_name = function(buf)
      assert(buf == 0)
      return current.path or ""
    end }),
    fn = readonly({ getcwd = function(...)
      assert(select("#", ...) == 0, "must use the current window cwd")
      cwd_reads = cwd_reads + 1
      return current.cwd or "/unrelated"
    end }),
    uv = readonly({
      fs_realpath = function(path)
        realpath_reads = realpath_reads + 1
        assert(path == probes[realpath_reads], "wrong realpath probe")
        local code = realpath_reads < #probes and "ENOENT" or current.error
        if code then
          return nil, code .. ": mock realpath failure", code
        end
        return current.realpath or path
      end,
      fs_lstat = function(path)
        assert(path == probes[realpath_reads], "wrong lstat probe")
        lstat_reads = lstat_reads + 1
        if realpath_reads == #probes and current.object then
          return { type = "link" }
        end
        local code = current.lstat_error or "ENOENT"
        return nil, code .. ": mock lstat failure", code
      end,
    }),
    fs = readonly({
      root = function(path, marker)
        assert(not current.error, "must not search for Git after a resolution failure")
        assert(path == (current.realpath or probes[#probes]), "wrong physical root input")
        assert(marker == ".git", "must allow both .git directories and worktree files")
        root_reads = root_reads + 1
        return current.root
      end,
      dirname = function(path)
        assert(path == probes[realpath_reads], "wrong dirname probe")
        dirname_reads = dirname_reads + 1
        return path:match("^(.+)/[^/]+$") or "/"
      end,
    }),
    log = readonly({ levels = readonly({ WARN = 3 }) }),
    notify = function(message, level)
      assert(message:find("No Git repository found", 1, true), "unclear notification")
      assert(level == 3, "expected a warning")
      notices[#notices + 1] = message
    end,
  }),
  Snacks = readonly({ picker = readonly({ git_diff = picker("git_diff"), git_status = picker("git_status") }) }),
  require = function(name)
    assert(name == "neo-tree.sources.manager" and bo.filetype == "neo-tree")
    return readonly({ get_state_for_window = function(...)
      assert(select("#", ...) == 0, "must use the current explorer window")
      explorer_reads = explorer_reads + 1
      return state
    end })
  end,
})

-- Load once so successive invocations must resolve fresh buffer/explorer context.
local specs = assert(loadfile(arg[1], "t", env))()
assert(#specs == 1 and specs[1][1] == "folke/snacks.nvim")
assert(#specs[1].keys == 3)
local keys = {}
local descriptions = { gd = "Git Diff (hunks)", gD = "Git Diff (origin)", gs = "Git Status" }
for _, key in ipairs(specs[1].keys) do
  local suffix = assert(key[1]:match("^<leader>(g[dDs])$"))
  assert(not keys[suffix] and key.desc == descriptions[suffix])
  assert(key.mode == nil or key.mode == "n")
  keys[suffix] = key[2]
end

local cases = {
  { "file A with unrelated cwd", path = "/repos/a/src/main.lua", root = "/repos/a" },
  { "switch to B in the same session", path = "/repos/b/main.lua", root = "/repos/b" },
  { "ordinary directory", path = "/repos/a/src", root = "/repos/a" },
  { "repository root directory", path = "/repos/b", root = "/repos/b" },
  { "root and filename with spaces", path = "/repo space/a file.lua", root = "/repo space", key = "gs" },
  { "symlink file targets B", path = "/repos/a/link.lua", realpath = "/repos/b/main.lua", root = "/repos/b" },
  { "symlink directory targets B", path = "/link dir", realpath = "/repos/b/src", root = "/repos/b" },
  { "deleted file uses physical parent", path = "/repos/a/deleted.lua", probes = { "/repos/a/deleted.lua", "/repos/a" }, root = "/repos/a" },
  { "unsaved path and parent", path = "/repos/b/new/unsaved.lua", probes = { "/repos/b/new/unsaved.lua", "/repos/b/new", "/repos/b" }, root = "/repos/b" },
  { "missing file through symlink targets B", path = "/repos/a/link/new.lua", probes = { "/repos/a/link/new.lua", "/repos/a/link" }, realpath = "/repos/b/src", root = "/repos/b" },
  { "deep new file through symlink targets B", path = "/repos/a/link/new/deep/file.lua", probes = { "/repos/a/link/new/deep/file.lua", "/repos/a/link/new/deep", "/repos/a/link/new", "/repos/a/link" }, realpath = "/repos/b/src", root = "/repos/b", key = "gD" },
  { "missing file through non-Git symlink refuses", path = "/repos/a/link/new.lua", probes = { "/repos/a/link/new.lua", "/repos/a/link" }, realpath = "/outside/src", cwd = "/repos/b" },
  { "deep new file through non-Git symlink refuses", path = "/repos/a/link/new/deep/file.lua", probes = { "/repos/a/link/new/deep/file.lua", "/repos/a/link/new/deep", "/repos/a/link/new", "/repos/a/link" }, realpath = "/outside/src", cwd = "/repos/b", key = "gs" },
  { "missing child of broken symlink refuses", path = "/repos/a/broken/new.lua", probes = { "/repos/a/broken/new.lua", "/repos/a/broken" }, error = "ENOENT", object = true, cwd = "/repos/b" },
  { "cyclic symlink refuses", path = "/repos/a/cycle/new.lua", error = "ELOOP", cwd = "/repos/b" },
  { "inaccessible symlink target refuses", path = "/repos/a/private/new.lua", error = "EACCES", cwd = "/repos/b" },
  { "non-directory path component refuses", path = "/repos/a/file/new.lua", error = "ENOTDIR", cwd = "/repos/b" },
  { "lstat permission failure cannot establish absence", path = "/repos/a/new.lua", error = "ENOENT", lstat_error = "EACCES", cwd = "/repos/b" },
  { "dirname non-progress at root refuses", path = "/", error = "ENOENT", nonprogress = true },
  { ".git file worktree root contract", path = "/worktrees/topic/main.lua", root = "/worktrees/topic" },
  { "nearest nested Git root contract", path = "/repos/a/nested/main.lua", root = "/repos/a/nested" },
  { "empty buffer uses window cwd", path = "", cwd = "/repos/a/src", target = "/repos/a/src", root = "/repos/a", fallback = true },
  { "special named buffer uses window cwd", path = "/repos/a/help", bt = "nofile", cwd = "/repos/b", target = "/repos/b", root = "/repos/b", fallback = true },
  { "terminal uses window cwd", path = "term://shell", bt = "terminal", cwd = "/repos/a", target = "/repos/a", root = "/repos/a", fallback = true },
  { "empty buffer outside Git refuses", path = "", target = "/unrelated", fallback = true },
  { "named non-Git file never uses cwd repo", path = "/outside/file", cwd = "/repos/a", key = "gs" },
  { "non-Git symlink target never uses lexical repo", path = "/repos/a/link", realpath = "/outside/file", cwd = "/repos/b" },
  { "origin diff retains options", path = "/repos/a/main.lua", root = "/repos/a", key = "gD" },
  { "origin diff switches repo", path = "/repos/b/main.lua", root = "/repos/b", key = "gD" },
  { "hunk diff does not inherit origin options", path = "/repos/a/main.lua", root = "/repos/a" },
  { "explorer selected child beats displayed root", ft = "neo-tree", state = { path = "/repos/a", node = { path = "/repos/b/main.lua" } }, target = "/repos/b/main.lua", root = "/repos/b" },
  { "explorer selected directory", ft = "neo-tree", state = { path = "/repos", node = { path = "/repos/a/src" } }, target = "/repos/a/src", root = "/repos/a" },
  { "explorer missing selection uses displayed root", ft = "neo-tree", state = { path = "/repos/b" }, target = "/repos/b", root = "/repos/b" },
  { "explorer pathless node uses displayed root", ft = "neo-tree", state = { path = "/repos/a", node = {} }, target = "/repos/a", root = "/repos/a" },
  { "explorer missing tree uses displayed root", ft = "neo-tree", state = { path = "/repos/a", no_tree = true }, target = "/repos/a", root = "/repos/a" },
  { "explorer non-Git child refuses root and cwd repos", ft = "neo-tree", state = { path = "/repos/a", node = { path = "/outside/file" } }, target = "/outside/file", cwd = "/repos/b" },
  { "explorer non-Git displayed root refuses cwd repo", ft = "neo-tree", state = { path = "/outside" }, target = "/outside", cwd = "/repos/a" },
  { "explorer missing state refuses cwd repo", ft = "neo-tree", cwd = "/repos/a", key = "gD" },
  { "explorer missing path refuses cwd repo", ft = "neo-tree", state = {}, cwd = "/repos/a" },
}

for _, case in ipairs(cases) do
  current = case
  bo.filetype, bo.buftype = case.ft or "", case.bt or (case.ft == "neo-tree" and "nofile" or "")
  state = case.state and {
    path = case.state.path,
    tree = not case.state.no_tree and { get_node = function() return case.state.node end } or nil,
  }
  calls, notices = {}, {}
  cwd_reads, root_reads, realpath_reads, explorer_reads = 0, 0, 0, 0
  lstat_reads, dirname_reads = 0, 0
  local target = case.target or case.path
  probes = case.probes or (target and target ~= "" and { target } or {})
  assert(#probes == 0 or probes[1] == target, case[1] .. ": invalid fixture target")
  local ok, err = pcall(keys[case.key or "gd"])
  assert(ok, case[1] .. ": " .. tostring(err))
  assert(cwd_reads == (case.fallback and 1 or 0), case[1] .. ": unexpected cwd fallback")
  assert(explorer_reads == (case.ft == "neo-tree" and 1 or 0), case[1] .. ": wrong explorer lookup")
  local ascents = math.max(#probes - 1, 0)
  assert(realpath_reads == #probes, case[1] .. ": wrong realpath probe count")
  assert(root_reads == (#probes > 0 and not case.error and 1 or 0), case[1] .. ": wrong Git root lookup count")
  assert(lstat_reads == ascents + (case.error == "ENOENT" and 1 or 0), case[1] .. ": wrong lstat count")
  assert(dirname_reads == ascents + (case.nonprogress and 1 or 0), case[1] .. ": unsafe ancestor traversal")
  if case.root then
    assert(#calls == 1 and #notices == 0, case[1] .. ": expected one picker, no warning")
    assert(calls[1].name == (case.key == "gs" and "git_status" or "git_diff"))
    local expected = { cwd = case.root }
    if case.key == "gD" then
      expected.base, expected.group = "origin", true
    end
    for key, value in pairs(expected) do
      assert(calls[1].opts[key] == value, case[1] .. ": wrong option " .. key)
    end
    for key in pairs(calls[1].opts) do
      assert(expected[key] ~= nil, case[1] .. ": extra option " .. key)
    end
  else
    assert(#calls == 0 and #notices == 1, case[1] .. ": must warn without opening picker")
    assert(notices[1]:find(target or "the current Neo-tree view", 1, true), case[1] .. ": warning lost original target")
  end
  print("ok:   " .. case[1])
end
print(("ok:   git-review (%d cases)"):format(#cases))
LUA
