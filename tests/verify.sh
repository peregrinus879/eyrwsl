#!/usr/bin/env bash
# Verifier fixtures: fixture mode over a fake repo and home fails closed on
# every host, deployment, identity, and format error, and never targets the
# live home; repo mode needs only the verifier tools.
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
[[ -n ${EYRWSL_PACKAGES:-} ]] || { printf 'FAIL: EYRWSL_PACKAGES is required\n' >&2; exit 1; }
read -r -a PACKAGES <<<"$EYRWSL_PACKAGES"
(( ${#PACKAGES[@]} )) || { printf 'FAIL: package list is empty\n' >&2; exit 1; }

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

make_baseline() {
  local base=$1 repo="$1/repo" home="$1/home" source
  mkdir -p "$repo" "$home/.config/git"
  while IFS= read -r source; do
    [[ -e $ROOT/$source || -L $ROOT/$source ]] || continue
    mkdir -p "$repo/$(dirname -- "$source")"
    cp -a -- "$ROOT/$source" "$repo/$source"
  done < <(git -C "$ROOT" ls-files --cached --others --exclude-standard)
  git -C "$repo" init -q
  git -C "$repo" add .
  printf '[user]\n  name = Fixture User\n  email = fixture@users.noreply.github.com\n' >"$home/.config/git/config.local"
  stow --no-folding -t "$home" -d "$repo" "${PACKAGES[@]}"
}

clone_baseline() {
  cp -a -- "$TMP/baseline" "$TMP/$1"
}

run_verify() {
  local base=$1 mode=$2 extra_tool=${3:-}
  HOME="$base/home" \
    VERIFY_MODE="$mode" \
    VERIFY_REPO="$base/repo" \
    VERIFY_HOME="$base/home" \
    VERIFY_KERNEL_RELEASE="6.6.0-microsoft-standard-WSL2" \
    VERIFY_PACKAGES="${PACKAGES[*]}" \
    VERIFY_EXTRA_REQUIRED_TOOL="$extra_tool" \
    bash "$ROOT/scripts/verify.sh"
}

expect_failure() {
  local label=$1
  shift
  if "$@" >/dev/null 2>&1; then
    fail "$label did not fail closed"
  fi
}

make_baseline "$TMP/baseline"
run_verify "$TMP/baseline" fixture >/dev/null

expect_failure "full-mode path override" run_verify "$TMP/baseline" full
expect_failure "missing verifier" run_verify "$TMP/baseline" repo eyrwsl-missing-verifier

clone_baseline bad-identity
: >"$TMP/bad-identity/home/.config/git/config.local"
expect_failure "empty Git identity" run_verify "$TMP/bad-identity" fixture

clone_baseline personal-identity
printf '[user]\n  name = Fixture User\n  email = fixture@example.invalid\n' >"$TMP/personal-identity/home/.config/git/config.local"
expect_failure "Git identity outside the GitHub no-reply domain" run_verify "$TMP/personal-identity" fixture

clone_baseline folded
rm -rf -- "$TMP/folded/home/.config/yazi"
ln -s ../repo/yazi/.config/yazi "$TMP/folded/home/.config/yazi"
expect_failure "folded managed directory" run_verify "$TMP/folded" fixture

expect_failure "fixture mode against the live HOME" env HOME="$HOME" VERIFY_MODE=fixture VERIFY_REPO="$TMP/baseline/repo" \
  VERIFY_HOME="$HOME" VERIFY_KERNEL_RELEASE="6.6.0-microsoft-standard-WSL2" VERIFY_PACKAGES="${PACKAGES[*]}" \
  bash "$ROOT/scripts/verify.sh"

clone_baseline bad-starship
printf '[broken\n' >"$TMP/bad-starship/repo/starship/.config/starship.toml"
expect_failure "malformed Starship TOML" run_verify "$TMP/bad-starship" repo

clone_baseline bad-yazi
printf '[mgr\n' >"$TMP/bad-yazi/repo/yazi/.config/yazi/yazi.toml"
expect_failure "malformed Yazi TOML" run_verify "$TMP/bad-yazi" repo

clone_baseline bad-lua
printf 'local =\n' >"$TMP/bad-lua/repo/nvim/.config/nvim/lua/config/options.lua"
expect_failure "malformed Lua" run_verify "$TMP/bad-lua" repo

clone_baseline bad-json
printf '{\n' >"$TMP/bad-json/repo/windows-terminal/settings.json"
expect_failure "malformed Windows Terminal JSON" run_verify "$TMP/bad-json" repo

clone_baseline wrong-terminal-font
terminal="$TMP/wrong-terminal-font/repo/windows-terminal/settings.json"
jq '.profiles.defaults.font.size = 10' "$terminal" >"$terminal.tmp"
mv -- "$terminal.tmp" "$terminal"
expect_failure "wrong Windows Terminal font size" run_verify "$TMP/wrong-terminal-font" repo

clone_baseline bad-fastfetch
printf '{ invalid\n' >"$TMP/bad-fastfetch/repo/fastfetch/.config/fastfetch/config.jsonc"
expect_failure "malformed Fastfetch JSONC" run_verify "$TMP/bad-fastfetch" repo

clone_baseline bad-git
printf '[broken\n' >"$TMP/bad-git/repo/git/.config/git/config"
expect_failure "malformed Git config" run_verify "$TMP/bad-git" repo

clone_baseline bad-tmux
printf '%s\n' 'not-a-tmux-command' >>"$TMP/bad-tmux/repo/tmux/.config/tmux/tmux.conf"
expect_failure "malformed tmux config" run_verify "$TMP/bad-tmux" repo

clone_baseline bad-lock
printf '{}\n' >"$TMP/bad-lock/repo/nvim/.config/nvim/lazy-lock.json"
expect_failure "incomplete LazyVim lock" run_verify "$TMP/bad-lock" repo

clone_baseline wrapper-not-executable
chmod a-x "$TMP/wrapper-not-executable/repo/mise/.local/bin/claude"
expect_failure "non-executable mise wrapper" run_verify "$TMP/wrapper-not-executable" repo

clone_baseline wrapper-wrong-tool
sed -i 's/"codex"/"claude"/g' "$TMP/wrapper-wrong-tool/repo/mise/.local/bin/codex"
expect_failure "mise wrapper naming another tool" run_verify "$TMP/wrapper-wrong-tool" repo

clone_baseline wrapper-no-cooldown
sed -i '1a export MISE_MINIMUM_RELEASE_AGE=0' "$TMP/wrapper-no-cooldown/repo/mise/.local/bin/opencode"
expect_failure "mise wrapper overriding the release cooldown" run_verify "$TMP/wrapper-no-cooldown" repo

clone_baseline not-paranoid
printf '[settings]\nparanoid = false\n' >"$TMP/not-paranoid/repo/mise/.config/mise/conf.d/eyrwsl.toml"
expect_failure "mise fragment without paranoid mode" run_verify "$TMP/not-paranoid" repo

clone_baseline non-wsl
if HOME="$TMP/non-wsl/home" \
  VERIFY_MODE=fixture \
  VERIFY_REPO="$TMP/non-wsl/repo" \
  VERIFY_HOME="$TMP/non-wsl/home" \
  VERIFY_KERNEL_RELEASE=linux-fixture \
  VERIFY_PACKAGES="${PACKAGES[*]}" \
  bash "$ROOT/scripts/verify.sh" >/dev/null 2>&1; then
  fail "non-WSL fixture did not fail closed"
fi

clone_baseline missing-deployment
rm -- "$TMP/missing-deployment/home/.bashrc"
expect_failure "missing deployment" run_verify "$TMP/missing-deployment" fixture

printf 'ok: verifier fixtures fail closed across host, deployment, and format errors\n'
