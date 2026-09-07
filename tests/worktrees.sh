#!/bin/bash
# Real Git metadata/history created only in disposable fixtures, including a
# shallow source run. No dependency on the source repository's commit graph.
# shellcheck disable=SC2119 # gd deliberately accepts no arguments.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
unset GIT_CONFIG GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT
export HOME="$TMP/home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=Fixture GIT_AUTHOR_EMAIL=fixture@example.invalid
export GIT_COMMITTER_NAME=Fixture GIT_COMMITTER_EMAIL=fixture@example.invalid
export GIT_TEMPLATE_DIR="$TMP/git-template"
mkdir -p "$HOME" "$GIT_TEMPLATE_DIR"
MAIN="$TMP/main repo"
command git init -q -b main "$MAIN"
mkdir -p "$MAIN/bash"
printf 'fixture base\n' >"$MAIN/bash/tracked"
command git -C "$MAIN" add bash/tracked
command git -C "$MAIN" commit -qm 'fixture base'
source "$ROOT/bash/.config/bash/functions/worktrees"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
gum() {
  printf '%s\n' "$*" >"$TMP/prompt"
  if [[ -n ${PRIMARY_REWIND:-} ]]; then command git -C "$MAIN" update-ref refs/heads/main "$PRIMARY_REWIND"; fi
  [[ ${GUM_REFUSE:-0} == 0 ]]
}
git() {
  if [[ -n ${GIT_FAIL:-} && " $* " == *" $GIT_FAIL "* ]]; then return 1; fi
  command git "$@"
}
builtin() {
  [[ $1 != cd || -z ${CD_REFUSE:-} || ${!#} != "$CD_REFUSE" ]] || return 1
  command builtin "$@"
}

mkdir -p "$TMP/alias-bin"
printf '#!/bin/bash\nexit 99\n' >"$TMP/alias-bin/zoxide"
chmod +x "$TMP/alias-bin/zoxide"
if ! (
  export PATH="$TMP/alias-bin:$PATH"
  shopt -s expand_aliases
  source "$ROOT/bash/.config/bash/aliases"
  # shellcheck disable=SC2329 # Called indirectly by the sourced zd wrapper.
  z() { : >"$TMP/z-called"; return 1; }
  source "$ROOT/bash/.config/bash/functions/worktrees"
  builtin cd "$MAIN/bash"
  ga alias-fixture || exit 1
  [[ $PWD == "$TMP/main repo--alias-fixture" ]] || exit 1
  if GIT_FAIL='worktree remove' gd >/dev/null 2>&1; then exit 1; fi
  [[ $PWD == "$TMP/main repo--alias-fixture" && -d $PWD ]] || exit 1
  gd || exit 1
  [[ $PWD == "$MAIN" && ! -e $TMP/z-called ]] || exit 1
); then fail 'production alias-before-helper navigation failed'; fi

cd "$MAIN/bash"
ga feature || fail 'ga from subdirectory'
[[ $PWD == "$TMP/main repo--feature" ]] || fail 'ga used subdirectory basename'
git branch -m actual-branch
git -C "$MAIN" worktree move "$PWD" "$TMP/unrelated name"
cd "$TMP/unrelated name/bash"
gd || fail 'gd failed for renamed worktree/branch'
[[ $PWD == "$MAIN" && ! -e $TMP/unrelated\ name ]] || fail 'gd removed wrong path or did not return to main'
grep -qF "worktree '$TMP/unrelated name' and branch 'actual-branch'" "$TMP/prompt" || fail 'prompt lacks exact target/branch'
if git show-ref --verify --quiet refs/heads/actual-branch; then fail 'actual branch retained'; fi
if gd >/dev/null 2>&1; then fail 'gd removed main worktree'; fi

ga dirty
printf 'keep\n' >untracked
if gd >"$TMP/error" 2>&1; then fail 'dirty worktree accepted'; fi
[[ -f untracked && $PWD == "$TMP/main repo--dirty" ]] || fail 'dirty data/cwd changed'
rm -- untracked
if GUM_REFUSE=1 gd >/dev/null 2>&1; then fail 'cancel accepted'; fi
[[ -d $PWD ]] || fail 'cancel removed checkout'
if CD_REFUSE=$MAIN gd >/dev/null 2>&1; then fail 'failed cd accepted'; fi
[[ $PWD == "$TMP/main repo--dirty" && -d $PWD ]] || fail 'failed cd removed checkout or changed cwd'
if GIT_FAIL='worktree remove' gd >/dev/null 2>&1; then fail 'remove failure accepted'; fi
[[ $PWD == "$TMP/main repo--dirty" ]] || fail 'remove failure did not restore cwd'
git show-ref --verify --quiet refs/heads/dirty || fail 'remove failure deleted branch'
gd >/dev/null || fail 'clean removal'

before=$PWD
if GIT_FAIL='worktree add' ga failure >/dev/null 2>&1; then fail 'failed add accepted'; fi
[[ $PWD == "$before" && ! -e $TMP/main\ repo--failure ]] || fail 'failed add changed cwd'
if ga ../escape >/dev/null 2>&1; then fail 'invalid branch accepted'; fi
if CD_REFUSE="$TMP/main repo--cd-failure" ga cd-failure >/dev/null 2>&1; then fail 'ga ignored failed cd'; fi
[[ $PWD == "$before" && -d $TMP/main\ repo--cd-failure ]] || fail 'ga cd failure lost checkout/cwd'
git worktree remove -- "$TMP/main repo--cd-failure"
git branch -d -- cd-failure >/dev/null

ga retained >/dev/null
if GIT_FAIL='branch -d' gd >"$TMP/error" 2>&1; then fail 'branch-deletion failure accepted'; fi
git show-ref --verify --quiet refs/heads/retained || fail 'branch-deletion failure lost branch'
grep -q 'branch.*retained' "$TMP/error" || fail 'partial removal not explained'

git worktree add -q -b unmerged "$TMP/unmerged"
printf 'fixture unmerged\n' >>"$TMP/unmerged/bash/tracked"
git -C "$TMP/unmerged" add bash/tracked
git -C "$TMP/unmerged" commit -qm 'fixture unmerged'
cd "$TMP/unmerged/bash"
if gd >"$TMP/error" 2>&1; then fail 'unmerged worktree accepted'; fi
[[ -d $TMP/unmerged ]] || fail 'unmerged worktree removed'
git show-ref --verify --quiet refs/heads/unmerged || fail 'unmerged branch deleted'
grep -q 'not merged' "$TMP/error" || fail 'unmerged refusal not explained'
plain="$TMP/newline-project"; newline="$plain"$'\n'
for path in "$plain" "$newline"; do
  command git init -q -b main "$path"
  command git -C "$path" commit -qm 'newline fixture' --allow-empty
done
cd "$newline"
ga literal || fail 'newline root creation failed'
[[ $PWD == "$newline--literal" ]] || fail 'newline root selected a different repository'
if command git -C "$plain" show-ref --verify --quiet refs/heads/literal; then fail 'newline collision changed the other repository'; fi
mkdir -p "$PWD/plain" "$PWD/plain"$'\n'
cd "$PWD/plain"$'\n'
before=$PWD
if GIT_FAIL='worktree remove' gd >"$TMP/error" 2>&1; then fail 'newline remove failure accepted'; fi
[[ $PWD == "$before" ]] || fail 'failed removal trimmed the restored directory'
gd || fail 'newline worktree removal failed'
[[ $PWD == "$newline" ]] || fail 'newline primary path was not preserved'

cd "$MAIN"
primary_before=$(command git rev-parse HEAD)
command git commit -qm 'primary advanced' --allow-empty
primary_advanced=$(command git rev-parse HEAD)
command git worktree add -q --detach "$TMP/detached" HEAD
cd "$TMP/detached"
if PRIMARY_REWIND=$primary_before gd >"$TMP/error" 2>&1; then fail 'confirmation-time primary rewind removed detached work'; fi
grep -q 'primary worktree no longer contains the reviewed HEAD' "$TMP/error" || fail 'primary rewind refused for the wrong reason'
[[ $PWD == "$TMP/detached" && -d $PWD ]] || fail 'primary rewind changed the target or cwd'
command git -C "$MAIN" update-ref refs/heads/main "$primary_advanced" "$primary_before"
gd || fail 'contained detached worktree was refused'

if [[ ${WORKTREES_SHALLOW_CHILD:-0} == 0 ]]; then
  git clone -q --no-local --depth 1 --branch unmerged "$MAIN" "$TMP/shallow-source"
  [[ $(git -C "$TMP/shallow-source" rev-parse --is-shallow-repository) == true ]] || fail 'shallow fixture is not shallow'
  if git -C "$TMP/shallow-source" rev-parse --verify HEAD^ >/dev/null 2>&1; then fail 'shallow fixture unexpectedly has HEAD^'; fi
  mkdir -p "$TMP/shallow-source/tests" "$TMP/shallow-source/bash/.config/bash/functions"
  cp "$ROOT/tests/worktrees.sh" "$TMP/shallow-source/tests/worktrees.sh"
  cp "$ROOT/bash/.config/bash/functions/worktrees" "$TMP/shallow-source/bash/.config/bash/functions/worktrees"
  cp "$ROOT/bash/.config/bash/aliases" "$TMP/shallow-source/bash/.config/bash/aliases"
  WORKTREES_SHALLOW_CHILD=1 bash "$TMP/shallow-source/tests/worktrees.sh"
  printf 'ok:   worktrees suite also passes from a depth-one source without HEAD^\n'
fi
printf 'ok:   ga/gd use real worktree metadata, exact reviewed targets and non-forced Git safeguards\n'
