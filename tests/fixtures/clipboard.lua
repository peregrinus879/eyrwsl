-- Mock Neovim only. Emit provider argv for the fake Windows transport fixture.
local wsl, executable = 0, 1
vim = {
  opt = {},
  g = {},
  fn = {
    has = function(name) assert(name == "wsl"); return wsl end,
    executable = function(name) assert(name == "powershell.exe"); return executable end,
  },
}
dofile(arg[1])
assert(vim.opt.relativenumber == false and vim.g.autoformat == false, "baseline options changed")
assert(vim.g.clipboard == nil, "provider enabled off WSL")
wsl, executable = 1, 0
dofile(arg[1])
assert(vim.g.clipboard == nil, "provider enabled without Windows helper")
executable = 1
dofile(arg[1])
local provider = vim.g.clipboard
assert(provider.name == "WslClipboard" and provider.cache_enabled == 0)
for _, operation in ipairs({ "copy", "paste" }) do
  local argv = provider[operation]["+"]
  assert(type(argv) == "table" and #argv == 6, "provider must use argv, not shell strings")
  assert(argv == provider[operation]["*"])
  assert(argv[1] == "powershell.exe" and argv[2] == "-NoLogo")
  assert(argv[3] == "-NoProfile" and argv[4] == "-NonInteractive" and argv[5] == "-Command")
  io.write(table.concat(argv, "\0"), "\0\0")
end
