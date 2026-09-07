"""Mock argv-based Neovim providers and Windows UTF-8 pipe boundaries."""
from pathlib import Path
import subprocess
import sys

root = Path(sys.argv[1])
raw = subprocess.check_output([
    "lua", str(root / "tests/fixtures/clipboard.lua"),
    str(root / "nvim/.config/nvim/lua/config/options.lua"),
])
copy, paste = [part.decode().split("\0") for part in raw.split(b"\0\0") if part]


def windows_helper(argv, data=b"", clipboard=None):
    assert argv[:5] == ["powershell.exe", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command"]
    script = argv[5]
    assert "$ErrorActionPreference = 'Stop'" in script
    assert "[System.Text.UTF8Encoding]::new($false)" in script
    if "Set-Clipboard" in script:
        assert "[Console]::InputEncoding =" in script
        assert "[Console]::In.ReadToEnd()" in script
        assert "if ($text.Length -eq 0) { Set-Clipboard }" in script
        assert "Set-Clipboard -Value $text" in script
        return data.decode("utf-8")
    assert "[Console]::OutputEncoding =" in script
    assert '[Console]::Out.Write(([string](Get-Clipboard -Raw)).Replace("`r", ""))' in script
    return (clipboard or "").replace("\r", "").encode("utf-8")


for text in ["", "ascii", "a\nb\n", "a\r\nb\r\n", "a\rb", "\u0627\u0644\u0639\u0631\u0628\u064a\u0629", "\u00e9\u6f22\U0001f642", "'\"; $x | nope", "\n\n"]:
    stored = windows_helper(copy, text.encode("utf-8"))
    assert stored == text
    assert windows_helper(paste, clipboard=stored).decode("utf-8") == text.replace("\r", "")
assert windows_helper(paste, clipboard=None) == b""
print("ok:   mocked clipboard provider argv, explicit UTF-8, Unicode/multiline/empty values and WSL guards")
