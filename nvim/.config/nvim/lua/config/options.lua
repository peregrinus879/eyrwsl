-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.relativenumber = false
vim.g.autoformat = false

-- Explicit UTF-8 on both pipes; no Windows profile or locale-dependent clip.exe.
if vim.fn.has("wsl") == 1 and vim.fn.executable("powershell.exe") == 1 then
  local copy = {
    "powershell.exe", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command",
    "$ErrorActionPreference = 'Stop'; [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false); "
      .. "$text = [Console]::In.ReadToEnd(); if ($text.Length -eq 0) { Set-Clipboard } else { Set-Clipboard -Value $text }",
  }
  local paste = {
    "powershell.exe", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command",
    "$ErrorActionPreference = 'Stop'; [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false); "
      .. '[Console]::Out.Write(([string](Get-Clipboard -Raw)).Replace("`r", ""))',
  }
  vim.g.clipboard = {
    name = "WslClipboard",
    copy = {
      ["+"] = copy,
      ["*"] = copy,
    },
    paste = {
      ["+"] = paste,
      ["*"] = paste,
    },
    cache_enabled = 0,
  }
end
