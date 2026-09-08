#!/usr/bin/env bash
# Verifier fixtures: fixture mode over a fake repo and home fails closed on
# every host, deployment, identity, and format error, and never targets the
# live home; repo mode needs only the verifier tools.
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
# A regression must never reach an installed tmux or a user server.
mkdir "$TMP/bin"
cat >"$TMP/bin/tmux" <<'SH'
#!/bin/bash
printf called >"${0%/*}/tmux-called"
exit 99
SH
chmod +x "$TMP/bin/tmux"
export PATH="$TMP/bin:$PATH"
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
  HOME="${4:-$base/home}" \
    VERIFY_MODE="$mode" \
    VERIFY_REPO="${6:-$base/repo}" \
    VERIFY_HOME="${5:-$base/home}" \
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
HOME="$TMP/baseline/home" bash --noprofile --norc -c '
  source "$1"
  ! alias h >/dev/null 2>&1
' bash "$TMP/baseline/repo/bash/.config/bash/aliases" || fail 'copied Herdr launch alias remains'
[[ ! -e $TMP/baseline/repo/bash/.config/bash/functions/herdr && ! -L $TMP/baseline/repo/bash/.config/bash/functions/herdr ]] ||
  fail 'copied Herdr helper source remains'

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

# Model login-home identity inside scratch; even a guard regression must not
# send fixture host overrides to the real HOME.
mkdir "$TMP/login-bin"
cat >"$TMP/login-bin/getent" <<'SH'
#!/bin/bash
[[ $# == 2 && $1 == passwd ]] || exit 99
printf 'fixture:x:%s:%s::%s:/bin/bash\n' "$UID" "$UID" "$EYR_TEST_LOGIN_HOME"
SH
chmod +x "$TMP/login-bin/getent"
if out=$(PATH="$TMP/login-bin:$PATH" EYR_TEST_LOGIN_HOME="$TMP/baseline/home" run_verify "$TMP/baseline" fixture 2>&1); then
  fail 'fixture mode against the modeled login HOME did not fail closed'
fi
[[ $out == *'fixture mode must not target the live HOME'* ]] || fail "wrong login-home refusal: $out"

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

clone_baseline missing-source
rm -- "$TMP/missing-source/repo/bash/.config/bash/aliases"
expect_failure "unrelated missing source" run_verify "$TMP/missing-source" fixture

for state in pulled pending; do
  clone_baseline "retired-$state"
  base="$TMP/retired-$state"; repo="$base/repo"; home="$base/home"
  mkdir -p "$repo/tmux/.config/tmux"
  for source in bash/.config/bash/functions/herdr bash/.config/bash/functions/tdw bash/.config/bash/functions/tmux tmux/.config/tmux/tmux.conf; do
    printf '# old fixture\n' >"$repo/$source"
  done
  git -C "$repo" add bash tmux
  stow --no-folding -R -t "$home" -d "$repo" "${PACKAGES[@]}" tmux
  [[ -L $home/.config/bash/functions/herdr &&
    $(readlink -f -- "$home/.config/bash/functions/herdr") == "$repo/bash/.config/bash/functions/herdr" ]] ||
    fail 'old Stow did not deploy the copied Herdr helpers'
  if [[ $state != pending ]]; then
    git -C "$repo" rm -q --cached -- bash/.config/bash/functions/herdr bash/.config/bash/functions/tdw bash/.config/bash/functions/tmux tmux/.config/tmux/tmux.conf
  fi
  rm -- "$repo/bash/.config/bash/functions/herdr" "$repo/bash/.config/bash/functions/tdw" "$repo/bash/.config/bash/functions/tmux" "$repo/tmux/.config/tmux/tmux.conf"
  rmdir "$repo/tmux/.config/tmux" "$repo/tmux/.config" "$repo/tmux"
  expect_failure "retired endpoints after $state deletion" run_verify "$base" fixture
  [[ -L $home/.config/bash/functions/herdr && -L $home/.config/bash/functions/tdw && -L $home/.config/tmux/tmux.conf ]] || fail 'verification mutated retired links'
  rm -- "$home/.config/bash/functions/tdw" "$home/.config/bash/functions/tmux" "$home/.config/tmux/tmux.conf"
  expect_failure "only the copied Herdr helper remains after $state deletion" run_verify "$base" fixture
  [[ -L $home/.config/bash/functions/herdr ]] || fail 'verification mutated the retired Herdr link'
  rm -- "$home/.config/bash/functions/herdr"
  run_verify "$base" fixture >/dev/null || fail "verification failed after $state retirement"
  source='bash/.config/bash/functions/herdr-user'
  printf '# unrelated helper\n' >"$repo/$source"
  git -C "$repo" add -- "$source"
  rm -- "$repo/$source"
  if out=$(run_verify "$base" fixture 2>&1); then fail 'verification hid a missing similarly named helper'; fi
  [[ $out == *"Git-visible Stow source is missing: $source"* ]] || fail "wrong missing-helper failure: $out"
  git -C "$repo" rm -q --cached -- "$source"
  for source in bash/.config/bash/functions/herdr bash/.config/bash/functions/tdw bash/.config/bash/functions/tmux tmux/.config/tmux/tmux.conf; do
    mkdir -p "$repo/$(dirname -- "$source")"
    for kind in regular symlink; do
      if [[ $kind == regular ]]; then
        printf '# restored retired source\n' >"$repo/$source"
      else
        ln -s "$TMP/absent"$'\n' "$repo/$source"
      fi
      if out=$(run_verify "$base" fixture 2>&1); then fail "verification hid restored $state retired source $source ($kind)"; fi
      [[ $out == *'retired source still exists:'* ]] || fail "wrong restored-source failure: $out"
      [[ -e $repo/$source || -L $repo/$source ]] || fail 'verification modified restored source'
      rm -- "$repo/$source"
    done
  done
  # An unrelated retained source directory/data is not a retired source file.
  printf 'retained state\n' >"$repo/tmux/.config/tmux/state"
  run_verify "$base" fixture >/dev/null || fail 'verification rejected unrelated retained tmux source data'
  ln -s "$TMP/foreign/bash/.config/bash/functions/tdw" "$home/.config/bash/functions/tdw"
  expect_failure 'foreign retired endpoint' run_verify "$base" fixture
  rm -- "$home/.config/bash/functions/tdw"
  for kind in foreign regular; do
    if [[ $kind == foreign ]]; then
      ln -s "$TMP/foreign/bash/.config/bash/functions/herdr" "$home/.config/bash/functions/herdr"
    else
      printf 'keep Herdr helper\n' >"$home/.config/bash/functions/herdr"
    fi
    expect_failure "$kind retired Herdr endpoint" run_verify "$base" fixture
    if [[ $kind == foreign ]]; then
      [[ $(readlink -- "$home/.config/bash/functions/herdr") == "$TMP/foreign/bash/.config/bash/functions/herdr" ]] || fail 'verification changed a foreign Herdr link'
    else
      [[ $(<"$home/.config/bash/functions/herdr") == 'keep Herdr helper' ]] || fail 'verification changed a regular Herdr helper'
    fi
    rm -- "$home/.config/bash/functions/herdr"
  done
  rmdir "$home/.config/tmux"
  ln -s "$repo/tmux/.config/tmux" "$home/.config/tmux"
  expect_failure 'retired fold after pull' run_verify "$base" fixture
  [[ -L $home/.config/tmux ]] || fail 'verification removed a retired fold'
done

for dir in '' .config .config/bash .config/bash/functions .config/tmux; do
  clone_baseline "unsafe-parent-${dir//\//-}"
  base="$TMP/unsafe-parent-${dir//\//-}"
  mkdir -p "$base/home/.config/tmux"
  chmod 775 "$base/home/$dir"
  if out=$(run_verify "$base" fixture 2>&1); then fail "verification accepted writable retired ancestor $dir"; fi
  [[ $out == *'unsafe retirement directory'* ]] || fail "wrong retired-directory failure: $out"
  [[ $(stat -c %a -- "$base/home/$dir") == 775 ]] || fail 'verification repaired unsafe permissions'
done

# The original spellings must reach preparation even when the other variable
# names the same canonical directory and all deployed endpoints are valid.
clone_baseline home-spelling
base="$TMP/home-spelling"
ln -s "$base/home" "$base/home-alias"
for spelling in "$base/home-alias" "$base/home-alias/" "$base/home-alias/."; do
  for selected in home verify-home both; do
    original_home="$base/home"; original_verify_home="$base/home"
    [[ $selected == verify-home ]] || original_home=$spelling
    [[ $selected == home ]] || original_verify_home=$spelling
    if out=$(run_verify "$base" fixture '' "$original_home" "$original_verify_home" 2>&1); then
      fail "verifier normalized away symlinked $selected"
    fi
    [[ $out == *'HOME must use a real, non-symlinked path'* ]] || fail "wrong HOME-spelling refusal: $out"
    [[ -L $base/home-alias && -L $base/home/.bashrc ]] || fail 'HOME-spelling refusal changed links'
  done
done

clone_baseline root-lookalikes
base="$TMP/root-lookalikes"
cp -a -- "$base/home" "$base/home"$'\n'
cp -a -- "$base/repo" "$base/repo"$'\n'
ln -s "$base/home"$'\n' "$base/home-alias"
ln -s "$base/repo"$'\n' "$base/repo-alias"
for selected in home verify-home repo home-alias verify-home-alias repo-alias both; do
  original_home="$base/home"; original_verify_home="$base/home"; original_repo="$base/repo"
  case $selected in
    home) original_home+=$'\n' ;;
    verify-home) original_verify_home+=$'\n' ;;
    repo) original_repo+=$'\n' ;;
    home-alias) original_home="$base/home-alias" ;;
    verify-home-alias) original_verify_home="$base/home-alias" ;;
    repo-alias) original_repo="$base/repo-alias" ;;
    both) original_home+=$'\n'; original_verify_home+=$'\n'; original_repo+=$'\n' ;;
  esac
  if out=$(run_verify "$base" fixture '' "$original_home" "$original_verify_home" "$original_repo" 2>&1); then
    fail "verifier accepted newline root lookalike: $selected"
  fi
  [[ $out == *'control characters'* ]] || fail "wrong verifier root-identity refusal: $out"
done
if out=$(builtin cd -- "$base/repo"$'\n' && HOME="$base/home" VERIFY_MODE=repo VERIFY_PACKAGES="${PACKAGES[*]}" bash scripts/verify.sh 2>&1); then
  fail 'relative verifier invocation trimmed its canonical clone root'
fi
[[ $out == *'control characters'* ]] || fail "wrong relative verifier root refusal: $out"
mkdir "$base/repo/scripts"$'\n'
cp -- "$ROOT/scripts/verify.sh" "$base/repo/scripts"$'\n/verify.sh'
if out=$(HOME="$base/home" VERIFY_MODE=repo VERIFY_PACKAGES="${PACKAGES[*]}" bash "$base/repo/scripts"$'\n/verify.sh' 2>&1); then
  fail 'verifier accepted a newline script dirname'
fi
[[ $out == *'control characters'* ]] || fail "wrong verifier dirname refusal: $out"

clone_baseline newline-leaf
base="$TMP/newline-leaf"
rm -- "$base/home/.bashrc"
ln -s "$base/repo/bash/.bashrc"$'\n' "$base/home/.bashrc"
if out=$(run_verify "$base" fixture 2>&1); then fail 'verifier trimmed a newline deployment target'; fi
[[ $out == *"$base/home/.bashrc does not resolve to $base/repo/bash/.bashrc"* ]] || fail "wrong newline target failure: $out"

# Every command the verifier needs is present, but tmux does not even resolve.
mkdir "$TMP/no-tmux"
for tool in bash cmp cut diff dirname fastfetch find getent git id jq luac python3 readlink realpath sort stat; do
  ln -s "$(command -v "$tool")" "$TMP/no-tmux/$tool"
done
PATH="$TMP/no-tmux" run_verify "$TMP/baseline" fixture >/dev/null || fail 'verification requires tmux'
PATH="$TMP/no-tmux" run_verify "$TMP/baseline" repo >/dev/null || fail 'repo verification requires tmux'
[[ ! -e $TMP/bin/tmux-called ]] || fail 'verification invoked tmux'

printf 'ok: verifier fixtures fail closed across host, deployment, and format errors\n'
