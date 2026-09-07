#!/bin/bash
# Fake Herdr RPCs only: fail closed, rollback ownership, roots and concurrency.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
export HOME="$TMP/home" XDG_STATE_HOME="$TMP/state" HDW_FIXTURE_STATE="$TMP/herdr.json"
export HERDR_PANE_ID=w99:p1 EDITOR=true
mkdir -p "$HOME" "$TMP/bin" "$TMP/project" "$TMP/other/project"
printf '#!/bin/bash\nexit 99\n' >"$TMP/bin/claude"
chmod +x "$TMP/bin/claude"
ln -s claude "$TMP/bin/codex"
ln -s claude "$TMP/bin/opencode"
export PATH="$TMP/bin:$PATH"
herdr() { python3 "$ROOT/tests/fixtures/herdr" "$@"; }
setsid() { [[ $* == '-f herdr server' ]] || return 99; herdr server; }
mv() {
  [[ ${HDW_STATE_FAIL:-0} != 1 || $* != *'/roots.new '* ]] || return 1
  command mv "$@"
}
source "$ROOT/bash/.config/bash/functions/hdw"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
reset_fake() {
  printf '{"next":1,"workspaces":{},"calls":[],"counts":{},"runs":[]}\n' >"$HDW_FIXTURE_STATE"
  rm -rf -- "$XDG_STATE_HOME"
}
reset_fake
(cd "$TMP/project" && hdw cc) || fail 'creation failed'
jq -e '.workspaces.w1 | .label == "project" and .tabs[0].label == "claude" and (.panes | length) == 3 and .panes[0].focused' "$HDW_FIXTURE_STATE" >/dev/null || fail 'layout/labels/focus'
cp "$XDG_STATE_HOME/hdw/roots" "$TMP/roots.before"
(cd "$TMP/project" && hdw oc -c) || fail 'reattach failed'
(cd "$TMP/project" && hdw) || fail 'bare reattach failed'
[[ $(jq '.runs | length' "$HDW_FIXTURE_STATE") == 2 ]] || fail 'reattach launched input'
cmp "$TMP/roots.before" "$XDG_STATE_HOME/hdw/roots" || fail 'reattach changed roots'
if (cd "$TMP/other/project" && hdw cc) >/dev/null 2>&1; then fail 'collision accepted'; fi
cmp "$TMP/roots.before" "$XDG_STATE_HOME/hdw/roots" || fail 'collision changed roots'
mkdir -p "$TMP/second"
if (cd "$TMP/second" && HDW_STATE_FAIL=1 hdw oc) >"$TMP/error" 2>&1; then fail 'state-write failure accepted'; fi
[[ $(jq '.workspaces | length' "$HDW_FIXTURE_STATE") == 1 ]] || fail 'state failure harmed existing workspace or left a partial one'
[[ $(jq '.runs | length' "$HDW_FIXTURE_STATE") == 2 ]] || fail 'state failure sent input'
cmp "$TMP/roots.before" "$XDG_STATE_HOME/hdw/roots" || fail 'state failure changed previous roots'

for injection in 'workspace list:1:exit' 'workspace list:1:error' 'workspace list:1:invalid' \
  'workspace list:1:null' 'workspace create:1:exit' 'workspace create:1:lost' 'workspace create:1:id' \
  'workspace create:1:invalid' 'workspace report-metadata:1:exit' 'tab rename:1:exit' 'tab rename:1:invalid' \
  'pane split:1:exit' 'pane split:2:exit' 'pane split:1:invalid' 'pane split:2:id' 'pane get:2:exit' \
  'workspace rename:1:lost' 'workspace focus:1:error' 'pane run:1:exit'; do
  reset_fake
  if (cd "$TMP/project" && HDW_INJECT=$injection hdw cc) >"$TMP/error" 2>&1; then fail "$injection accepted"; fi
  [[ $(jq '.workspaces | length' "$HDW_FIXTURE_STATE") == 0 ]] || fail "$injection left a partial workspace"
  [[ $(jq '.runs | length' "$HDW_FIXTURE_STATE") == 0 ]] || fail "$injection sent input"
  [[ ! -s $XDG_STATE_HOME/hdw/roots ]] || fail "$injection left roots state"
done

reset_fake
if (cd "$TMP/project" && HDW_CLOSE_FAIL=1 HDW_INJECT='workspace focus:1:error' hdw cc) >"$TMP/error" 2>&1; then fail 'failed rollback claimed success'; fi
[[ -s $XDG_STATE_HOME/hdw/roots ]] || fail 'unverified rollback dropped collision guard'
snapshots=("$XDG_STATE_HOME"/hdw/pending.*/roots.before)
[[ ${#snapshots[@]} == 1 && -f ${snapshots[0]} ]] || fail 'unverified rollback discarded previous root record'
grep -q 'roots recovery retained' "$TMP/error" || fail 'manual recovery not explained'

reset_fake
if (cd "$TMP/project" && HDW_INJECT='pane split:1:foreign' hdw cc) >"$TMP/error" 2>&1; then fail 'foreign replacement accepted'; fi
[[ $(jq '.workspaces | length' "$HDW_FIXTURE_STATE") == 1 ]] || fail 'rollback killed foreign workspace'
[[ $(jq -r '.workspaces.w1.label' "$HDW_FIXTURE_STATE") == foreign ]] || fail 'rollback rewrote foreign workspace'

for phase in 'pane get:3' 'workspace get:5' 'workspace rename:1' 'workspace focus:1' 'workspace get:8' 'pane run:1' 'workspace get:9'; do
  for replacement in replace replace-empty; do
    reset_fake
    if (cd "$TMP/project" && HDW_INJECT="$phase:$replacement" hdw cc) >"$TMP/error" 2>&1; then fail "$phase $replacement accepted reused IDs"; fi
    jq -e '.replacement != null and .workspaces.w1 == .replacement and (.runs | length) == .runs_at_replacement' "$HDW_FIXTURE_STATE" >/dev/null ||
      fail "$phase $replacement mutated or sent input to the replacement"
    grep -q 'rollback unverified; inspect workspace w1 (hdw-pending\.' "$TMP/error" || fail 'missing replacement recovery identity'
  done
done

reset_fake
(cd "$TMP/project" && hdw cc) >"$TMP/a.log" 2>&1 & a=$!
(cd "$TMP/project" && hdw oc) >"$TMP/b.log" 2>&1 & b=$!
wait "$a" || fail 'concurrent first launch'
wait "$b" || fail 'concurrent second launch'
[[ $(jq '.runs | length' "$HDW_FIXTURE_STATE") == 2 ]] || fail 'concurrent launch duplicated input'
[[ $(wc -l <"$XDG_STATE_HOME/hdw/roots") == 1 ]] || fail 'concurrent launch duplicated roots'

reset_fake
mkdir -p "$TMP/alpha" "$TMP/beta"
(cd "$TMP/alpha" && hdw cx -c) >"$TMP/a.log" 2>&1 & a=$!
(cd "$TMP/beta" && hdw oc -c) >"$TMP/b.log" 2>&1 & b=$!
wait "$a" || fail 'concurrent alpha'
wait "$b" || fail 'concurrent beta'
[[ $(wc -l <"$XDG_STATE_HOME/hdw/roots") == 2 ]] || fail 'concurrent roots update lost a project'
jq -e '[.runs[][3]] | index("codex resume --last") != null and index("opencode -c") != null' "$HDW_FIXTURE_STATE" >/dev/null || fail 'continue forms'

reset_fake
jq '.next = 10' "$HDW_FIXTURE_STATE" >"$TMP/next.json"
mv "$TMP/next.json" "$HDW_FIXTURE_STATE"
(cd "$TMP/project" && hdw cc) || fail 'Herdr base-32 workspace ID rejected'
(cd "$TMP/project" && hdw) || fail 'base-32 roots record rejected'
jq -e '.workspaces.wA != null' "$HDW_FIXTURE_STATE" >/dev/null || fail 'fixture did not test base-32 ID'

reset_fake
if (cd "$TMP/project" && HDW_COLD=1 HDW_INJECT='server:1:exit' hdw cc) >"$TMP/error" 2>&1; then fail 'failed cold start claimed success'; fi
jq -e '.calls | all(length > 0)' "$HDW_FIXTURE_STATE" >/dev/null || fail 'failed cold start launched plain Herdr'
reset_fake
(unset HERDR_PANE_ID; cd "$TMP/project" && HDW_COLD=1 hdw cc -c) || fail 'fake cold-start/attach failed'
jq -e '.calls | any(length == 0)' "$HDW_FIXTURE_STATE" >/dev/null || fail 'outside Herdr did not attach'
reset_fake
(cd "$TMP/project" && hdw cc) || fail 'unterminated-record setup failed'
printf 'project\tw1\t%s' "$TMP/project" >"$XDG_STATE_HOME/hdw/roots"
cp "$XDG_STATE_HOME/hdw/roots" "$TMP/unterminated.before"
if (cd "$TMP/other/project" && hdw) >"$TMP/error" 2>&1; then fail 'unterminated roots record bypassed collision guard'; fi
cmp "$TMP/unterminated.before" "$XDG_STATE_HOME/hdw/roots" || fail 'collision refusal changed unterminated record'
(cd "$TMP/second" && hdw cc) || fail 'unrelated update with unterminated record failed'
[[ $(wc -l <"$XDG_STATE_HOME/hdw/roots") == 2 ]] || fail 'unrelated update lost unterminated record'
grep -qxF "$(<"$TMP/unterminated.before")" "$XDG_STATE_HOME/hdw/roots" || fail 'unterminated ownership row was not preserved'
printf 'ok:   hdw validates RPCs, builds layout before input, rolls back only owned workspaces, preserves collisions and serializes roots\n'
