#!/bin/bash
# Mocked Herdr only: new-workspace layout, identity, preservation and failures.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
umask 077
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hdw.XXXXXXXXXX")
trap 'wait; rm -rf -- "$TMP"' EXIT
export HOME="$TMP/home" XDG_STATE_HOME="$TMP/state" XDG_CONFIG_HOME="$TMP/config"
export XDG_DATA_HOME="$TMP/data" XDG_CACHE_HOME="$TMP/cache" XDG_RUNTIME_DIR="$TMP/runtime" HISTFILE=/dev/null
export HDW_FIXTURE_STATE="$TMP/herdr.json" HDW_CWD="$TMP/project/sub dir"
export HERDR_WORKSPACE_ID=w1 HERDR_TAB_ID=w1:t7 HERDR_PANE_ID=w1:p1 EDITOR=true
unset HDW_INJECT HDW_WORKSPACE HDW_LABEL HERDR_SOCKET_PATH HERDR_SESSION BASH_ENV ENV
unset HDW_AREA HDW_GAPS HDW_BORDERS HDW_LAYOUT_PATCH HDW_POPULATED
mkdir -p "$HOME" "$TMP/bin" "$TMP/empty-bin" "$HDW_CWD" "$TMP/runtime" "$TMP/project/.git"
printf '#!/bin/bash\nexit 99\n' >"$TMP/bin/claude"
chmod +x "$TMP/bin/claude"
ln -s claude "$TMP/bin/codex"
ln -s claude "$TMP/bin/opencode"
ln -s claude "$TMP/bin/hermes"
ln -s "$HDW_CWD" "$TMP/logical"
export PATH="$TMP/bin:$PATH"
herdr() { python3 "$ROOT/tests/fixtures/herdr" "$@"; }
git() { printf 'Git-root routing attempted\n' >>"$TMP/forbidden"; return 99; }
setsid() { printf 'server start attempted\n' >>"$TMP/forbidden"; return 99; }
source "$ROOT/bash/.config/bash/functions/hdw"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert() { jq -e "$1" "$HDW_FIXTURE_STATE" >/dev/null || fail "$2"; }
reset_fake() {
  python3 "$ROOT/tests/fixtures/herdr" --reset
  rm -rf -- "$XDG_STATE_HOME"
  mkdir -p "$XDG_STATE_HOME/hdw/pending.old"
  printf 'deliberately invalid legacy record\n' >"$XDG_STATE_HOME/hdw/roots"
  printf 'old recovery must survive\n' >"$XDG_STATE_HOME/hdw/pending.old/roots.before"
  cp "$XDG_STATE_HOME/hdw/roots" "$TMP/roots.before"
  cp "$XDG_STATE_HOME/hdw/pending.old/roots.before" "$TMP/recovery.before"
  jq '{workspaces, tabs, panes, trees, focused_panes, runs}' "$HDW_FIXTURE_STATE" >"$TMP/native.before"
}
preserved() {
  [[ ! -e $TMP/forbidden ]] || fail 'routing/server startup attempted'
  cmp "$TMP/roots.before" "$XDG_STATE_HOME/hdw/roots" || fail 'legacy roots changed'
  cmp "$TMP/recovery.before" "$XDG_STATE_HOME/hdw/pending.old/roots.before" || fail 'legacy recovery changed'
  jq -e --slurpfile before "$TMP/native.before" '
    . as $s | $before[0] as $b | ((.workspaces | keys) - ($b.workspaces | keys)) as $new |
    def prior: if ($new | length) > 0 then .focused = false else . end;
    all($b.workspaces | to_entries[]; $s.workspaces[.key] == (.value | prior)) and
    all($b.tabs | to_entries[]; $s.tabs[.key] == (.value | prior)) and
    all($b.panes | to_entries[]; $s.panes[.key] == (.value | prior)) and
    all($b.trees | to_entries[]; $s.trees[.key] == .value) and
    all($b.focused_panes | to_entries[]; $s.focused_panes[.key] == .value) and
    .runs[0:($b.runs | length)] == $b.runs and
    all(.runs[($b.runs | length):][]; $b.panes[.[2]] == null) and
    ([.workspaces[] | select(.focused) | .workspace_id] ==
      (if ($new | length) > 0 then [$s.workspace_id] else [$b.workspaces[] | select(.focused) | .workspace_id] end)) and
    all(.tabs[]; . as $t | .focused == ($s.workspaces[$t.workspace_id].focused and
      $s.workspaces[$t.workspace_id].active_tab_id == $t.tab_id)) and
    all(.panes[]; . as $p | .focused == ($s.tabs[$p.tab_id].focused and $s.focused_panes[$p.tab_id] == $p.pane_id)) and
    all(.calls[]; . as $call | .[0:2] != ["pane","close"] or $before[0].panes[$call[2]] == null) and
    ([.calls[] | .[0:2]] | all(. == ["pane","get"] or . == ["tab","get"] or
      . == ["pane","list"] or . == ["pane","split"] or . == ["pane","layout"] or
      . == ["pane","close"] or . == ["pane","run"] or . == ["workspace","list"] or
      . == ["workspace","get"] or . == ["workspace","create"]))' "$HDW_FIXTURE_STATE" >/dev/null || fail 'existing resources/names or RPC boundary changed'
}
no_writes() {
  assert '(.writes | length) == 0 and (.runs | length) == 0' 'precondition sent writes/input'
  preserved
}
refuse() {
  if (builtin cd -- "$TMP/logical" && hdw "$@") >"$TMP/error" 2>&1; then fail 'unexpected success'; fi
}
launch() { (builtin cd -- "$TMP/logical" && hdw "$@"); }
bad_geometry() {
  reset_fake
  HDW_LAYOUT_PATCH=$1 refuse cc
  preserved
  assert '.layout_reply != null and
    [.layout_reply.panes[].pane_id] == ["w2:p1","w2:p2","w2:p3"] and
    [.layout_reply.splits[] | {direction,ratio}] == [{direction:"right",ratio:0.5},{direction:"down",ratio:0.5}] and
    .runs == [] and .tabs[.tab].pane_count == 1 and .workspaces[.workspace_id].pane_count == 1 and
    .created == ["w2"] and .closed == ["w2:p3","w2:p2"]' "corrupt rectangles accepted or unsafe cleanup: $1"
  grep -q 'stopped at validate layout' "$TMP/error" || fail 'rectangle test did not reach geometry validation'
  geometry_negative=$((geometry_negative + 1))
}
geometry_negative=0 geometry_positive=0

# Numeric defaults, prior agent labels and arbitrary manual labels all survive.
for label in 1 claude codex opencode 'review: keep me'; do
  HDW_LABEL=$label reset_fake
  launch cc || fail "label $label refused"
  preserved
  # shellcheck disable=SC2016 # $ENV is evaluated by jq, not Bash.
  assert '.tabs[.tab].pane_count == 3 and .panes[.caller].focused and
    .workspaces[.workspace_id].focused and .workspaces[.workspace_id].tab_count == 1 and
    .trees[.tab] == {direction:"right",ratio:0.5,first:"w2:p1",second:{direction:"down",ratio:0.5,first:"w2:p2",second:"w2:p3"}} and
    ([.panes[] | select(.workspace_id == "w2") | .cwd] | all(. == $ENV.HDW_CWD)) and
    .runs == [["pane","run","w2:p2","true ."],["pane","run","w2:p1","claude"]]' 'geometry/cwd/focus/input'
  assert '(.workspaces.w1.focused | not) and (.tabs["w1:t7"].focused | not) and
    (.panes["w1:p1"].focused | not) and .workspaces.w1.active_tab_id == "w1:t7" and
    .focused_panes["w1:t7"] == "w1:p1"' 'inactive original focus projection/local selection incorrect'
  jq '{workspaces, tabs, panes, trees, focused_panes, runs}' "$HDW_FIXTURE_STATE" >"$TMP/native.before"
  launch oc -c || fail 'repeated original-context invocation refused'
  preserved
  assert '.created == ["w2","w3"] and (.runs | length) == 4 and
    .workspaces.w3.focused and (.workspaces.w2.focused | not) and
    (.panes["w1:p1"].focused | not) and (.panes["w2:p1"].focused | not) and .panes["w3:p1"].focused and
    .runs[2:] == [["pane","run","w3:p2","true ."],["pane","run","w3:p1","opencode -c"]]' 'repeat reused workspace or conflated focus scopes'
done

# Continue the ordinary workflow from the generated bottom-right shell.
reset_fake
launch cc || fail 'initial workspace for shell continuation'
python3 "$ROOT/tests/fixtures/herdr" --focus w2:p3
assert '.panes["w2:p3"].focused and .focused_panes["w2:t1"] == "w2:p3"' 'shell UI selection failed'
jq '{workspaces, tabs, panes, trees, focused_panes, runs}' "$HDW_FIXTURE_STATE" >"$TMP/native.before"
HERDR_WORKSPACE_ID=w2 HERDR_TAB_ID=w2:t1 HERDR_PANE_ID=w2:p3 launch cx -c || fail 'generated shell caller refused'
preserved
assert '.created == ["w2","w3"] and .focused_panes["w2:t1"] == "w2:p3" and
  (.panes["w2:p3"].focused | not) and .panes["w3:p1"].focused and
  .runs[2:] == [["pane","run","w3:p2","true ."],["pane","run","w3:p1","codex resume --last"]]' 'generated shell context/layout/input changed'

# Inactive does not mean exempt from identity or focus-projection validation.
for rpc in 'tab get' 'pane list' 'pane get'; do
  reset_fake
  launch cc || fail 'initial workspace for inactive refusal'
  jq '{workspaces, tabs, panes, trees, focused_panes, runs}' "$HDW_FIXTURE_STATE" >"$TMP/native.before"
  next=$(jq -r --arg rpc "$rpc" '.counts[$rpc] + 1' "$HDW_FIXTURE_STATE")
  mode=focus-projection; [[ $rpc != 'pane get' ]] || mode=terminal
  HDW_INJECT="$rpc:$next:$mode" refuse oc
  preserved
  assert '.created == ["w2"] and (.writes | length) == 5 and (.runs | length) == 2' 'inactive malformed caller mutated'
done

# A later failed launch must not clean up or send input to an earlier workspace.
for failure in create cleanup cleanup-lost input; do
  reset_fake
  launch cc || fail 'initial workspace for failure preservation'
  jq '{workspaces, tabs, panes, trees, focused_panes, runs}' "$HDW_FIXTURE_STATE" >"$TMP/native.before"
  case "$failure" in
    create) injection='workspace create:2:lost'; panes=1; runs=2; closed='[]' ;;
    cleanup) injection='pane layout:2:error'; panes=1; runs=2; closed='["w3:p3","w3:p2"]' ;;
    cleanup-lost) injection='pane layout:2:error;pane close:1:lost'; panes=2; runs=2; closed='["w3:p3"]' ;;
    input) injection='pane run:3:lost'; panes=3; runs=3; closed='[]' ;;
  esac
  HDW_INJECT=$injection refuse oc
  preserved
  assert ".created == [\"w2\",\"w3\"] and .workspaces.w2.pane_count == 3 and
    .workspaces.w3.pane_count == $panes and .panes[\"w3:p1\"] != null and
    (.runs | length) == $runs and .closed == $closed" "earlier workspace harmed by later $failure"
  if [[ $failure == input ]]; then
    assert '.runs[2:] == [["pane","run","w3:p2","true ."]]' 'later input targeted the wrong pane'
  fi
  if [[ $failure == cleanup-lost ]]; then
    assert '.counts["pane close"] == 1 and .panes["w3:p2"] != null' 'ambiguous close retried/continued cleanup'
    grep -q 'cleanup unverified' "$TMP/error" || fail 'lost close recovery missing'
  fi
done

HDW_POPULATED=1 reset_fake
launch cx || fail 'populated caller refused'
preserved
assert '.tabs["w1:t7"].pane_count == 3 and .created == ["w2"]' 'populated caller changed'
reset_fake
mkdir -p "$TMP/other project"
(export HDW_CWD="$TMP/other project"; builtin cd -- "$HDW_CWD" && hdw oc) || fail 'cd-selected cwd refused'
preserved
assert '.panes["w1:p1"].cwd != .panes["w2:p1"].cwd and
  ([.panes[] | select(.workspace_id == "w2") | .cwd] | unique | length) == 1' 'caller cwd overrode physical cwd'
for agent in cc cx oc ha; do
  for continuation in plain continue; do
    reset_fake
    args=("$agent")
    [[ $continuation == plain ]] || args+=(-c)
    case "$agent:$continuation" in
      cc:plain) expected=claude ;; cc:continue) expected='claude -c' ;;
      cx:plain) expected=codex ;; cx:continue) expected='codex resume --last' ;;
      oc:plain) expected=opencode ;; oc:continue) expected='opencode -c' ;;
      ha:plain) expected=hermes ;; ha:continue) expected='hermes -c' ;;
    esac
    launch "${args[@]}" || fail "$agent $continuation"
    jq -e --arg command "$expected" '.runs[1][3] == $command' "$HDW_FIXTURE_STATE" >/dev/null || fail 'agent command changed'
    preserved
  done
done
reset_fake
(unset EDITOR; launch -c cc) || fail 'default editor/flag order'
assert '.runs[0][3] == "nvim ." and .runs[1][3] == "claude -c"' 'default editor/flag order'
reset_fake
launch -c ha || fail 'Hermes continue flag order'
assert '.runs[1][3] == "hermes -c"' 'Hermes continue command'

# Outer rectangles include borders, but borderless gaps remove one trailing
# cell only when the first-child dimension exceeds one. Odd halves round up.
for area in '{"x":0,"y":0,"width":120,"height":80}' \
  '{"x":26,"y":1,"width":134,"height":47}' '{"x":17,"y":9,"width":135,"height":81}' \
  '{"x":5,"y":3,"width":2,"height":2}' '{"x":65531,"y":65532,"width":4,"height":3}'; do
  for chrome in 00 01 10 11; do
    HDW_AREA=$area HDW_GAPS=${chrome:0:1} HDW_BORDERS=${chrome:1:1} reset_fake
    launch cc || fail "valid offset/rounding/gaps refused: $area $chrome"
    preserved
    assert '(.runs | length) == 2 and .closed == [] and .layout_reply.area == .area' 'geometry positive case not exercised'
    geometry_positive=$((geometry_positive + 1))
  done
done

# Keep IDs and 0.5 ratios correct while corrupting types, dimensions or coverage.
for path in '"area"' '"panes",0,"rect"' '"panes",1,"rect"' '"panes",2,"rect"' \
  '"splits",0,"rect"' '"splits",1,"rect"'; do
  bad_geometry "[{\"path\":[$path],\"value\":null}]"
  for field in x y width height; do
    for value in '"0"' null true 0.5 -1 65536; do
      bad_geometry "[{\"path\":[$path,\"$field\"],\"value\":$value}]"
    done
  done
done
for patch in \
  '[{"path":["panes",0,"rect","width"],"value":1},{"path":["panes",0,"rect","height"],"value":41}]' \
  '[{"path":["panes",0,"rect","height"],"value":79}]' \
  '[{"path":["panes",0,"rect","x"],"value":1}]' \
  '[{"path":["panes",0,"rect","width"],"value":59}]' \
  '[{"path":["panes",1,"rect","width"],"value":59},{"path":["panes",2,"rect","width"],"value":59}]' \
  '[{"path":["panes",1,"rect","y"],"value":1}]' \
  '[{"path":["panes",2,"rect","y"],"value":39}]' \
  '[{"path":["panes",2,"rect","y"],"value":41}]' \
  '[{"path":["panes",2,"rect","height"],"value":39}]' \
  '[{"path":["panes",2,"rect","height"],"value":41}]' \
  '[{"path":["panes",0,"rect","width"],"value":0}]' \
  '[{"path":["panes",1,"rect","height"],"value":0}]' \
  '[{"path":["area","width"],"value":121}]' \
  '[{"path":["area","x"],"value":65535}]' \
  '[{"path":["splits",0,"rect","x"],"value":1}]' \
  '[{"path":["splits",1,"rect","width"],"value":59}]'; do
  bad_geometry "$patch"
done
[[ $geometry_negative == 166 && $geometry_positive == 20 ]] || fail 'geometry coverage changed'

for args in '' '-c' 'cc oc' 'ha cc' 'nope' 'cc --help'; do
  reset_fake
  # shellcheck disable=SC2086 # Deliberate invalid argument vectors.
  refuse $args
  assert '(.calls | length) == 0' 'usage touched Herdr'
  no_writes
done
for variable in HERDR_WORKSPACE_ID HERDR_TAB_ID HERDR_PANE_ID; do
  for value in '' nonsense w1:pI; do
    reset_fake
    (export "$variable=$value"; refuse cc)
    assert '(.calls | length) == 0' 'malformed environment reached Herdr'
    no_writes
  done
done
for ids in 'w2 w2:t7 w2:p1' 'w1 w1:t9 w1:p1' 'w1 w1:t7 w1:p9'; do
  reset_fake
  read -r w t p <<<"$ids"
  HERDR_WORKSPACE_ID=$w HERDR_TAB_ID=$t HERDR_PANE_ID=$p refuse cc
  no_writes
done
for agent in cc cx oc ha; do
  reset_fake
  PATH="$TMP/empty-bin" refuse "$agent"
  grep -q 'required agent' "$TMP/error" || fail 'missing binary not explained'
  assert '(.calls | length) == 0' 'missing binary reached Herdr'
  no_writes
done

reset_fake
mkdir -p "$TMP/unsupported"$'\n'
if (builtin cd -- "$TMP/unsupported"$'\n' && hdw cc) >"$TMP/error" 2>&1; then fail 'trailing-newline cwd accepted'; fi
grep -q 'unsupported current directory' "$TMP/error" || fail 'cwd refusal not explained'
assert '(.calls | length) == 0' 'unsupported cwd reached Herdr'
no_writes

# Every read preflight refuses malformed, error, duplicate and wrong-ID responses.
for injection in 'pane get:1:exit' 'pane get:1:error' 'pane get:1:invalid' 'pane get:1:null' \
  'pane get:1:id' 'pane get:1:terminal' 'pane get:1:wrong-tab' 'pane get:1:wrong-workspace' \
  'pane get:1:type' 'pane get:1:multiple' 'pane get:1:terminal-space' 'tab get:1:error' 'tab get:1:wrong-tab' \
  'tab get:1:wrong-workspace' 'pane list:1:error' 'pane list:1:duplicate' 'pane list:1:list-null' \
  'tab get:1:focus-projection' 'pane list:1:focus-projection' 'workspace get:1:unfocused'; do
  reset_fake
  HDW_INJECT=$injection refuse cc
  no_writes
done
for injection in 'workspace list:1:exit' 'workspace list:1:error' 'workspace list:1:invalid' \
  'workspace list:1:null' 'workspace list:1:type' 'workspace list:1:multiple' 'workspace list:1:duplicate' \
  'workspace list:1:list-null' 'workspace list:1:missing-caller' 'workspace list:1:workspace-id' \
  'workspace list:1:active-tab' 'workspace get:1:exit' 'workspace get:1:error' 'workspace get:1:type' \
  'workspace get:1:workspace-id' 'workspace get:1:active-tab' 'workspace get:1:pane-count' \
  'pane get:2:replace-caller' 'pane list:1:focus-away'; do
  reset_fake
  HDW_INJECT=$injection refuse cc
  assert '.created == [] and .writes == [] and .runs == []' "preflight mutated: $injection"
done

# A create may have succeeded even when its response was lost or malformed.
# Never close the new workspace/root, including plausible reused IDs or labels.
for mode in exit lost invalid null error type multiple id terminal terminal-space wrong-tab wrong-workspace \
  alias terminal-alias sibling-terminal wrong-cwd workspace-id active-tab pane-count tab-count unfocused \
  existing-workspace missing-root tab-identity; do
  reset_fake
  HDW_INJECT="workspace create:1:$mode" refuse cc
  preserved
  count=1; [[ $mode != exit ]] || count=0
  assert "(.created | length) == $count and (.closed | length) == 0 and .runs == [] and
    (.counts[\"pane split\"] // 0) == 0" "unverified workspace used/destroyed: $mode"
  grep -q 'original workspace=w1 tab=w1:t7 caller=w1:p1' "$TMP/error" || fail 'original creation context missing'
  grep -q 'reply uncertain=1' "$TMP/error" || fail 'ambiguous creation not reported'
done
for injection in 'pane get:3:replace-caller' 'pane list:2:replace' 'workspace get:2:workspace-focus-away' \
  'pane list:2:extra-tab' 'pane list:2:extra-pane'; do
  reset_fake
  HDW_INJECT=$injection refuse cc
  assert '.created == ["w2"] and .closed == [] and .runs == [] and
    (.counts["pane split"] // 0) == 0 and .replacement == {workspaces,tabs,panes,trees,focused_panes}' 'unverified new root used/destroyed'
  grep -q 'new workspace=w2 tab=w2:t1 root=w2:p1 retained' "$TMP/error" || fail 'new context missing'
done

# Lost/invalid split replies cannot prove what was created. Keep unproven panes.
for split in 1 2; do
  for mode in exit lost invalid null error id terminal wrong-tab wrong-workspace alias terminal-alias sibling-terminal type multiple; do
    reset_fake
    HDW_INJECT="pane split:$split:$mode" refuse cc
    preserved
    count=$((split + 1)); [[ $mode != exit ]] || count=$split
    assert ".tabs[.tab].pane_count == $count and (.closed | length) == 0 and (.runs | length) == 0" 'uncertain creation was destroyed or received input'
    grep -q 'reply uncertain=1' "$TMP/error" || fail 'ambiguous split recovery missing'
  done
done
for injection in 'pane split:1:wrong-cwd' 'pane split:2:wrong-cwd' \
  'pane get:5:wrong-pane' 'pane get:7:wrong-pane' 'pane get:8:error' \
  'pane layout:1:exit' 'pane layout:1:error' 'pane layout:1:geometry'; do
  reset_fake
  HDW_INJECT=$injection refuse cc
  preserved
  assert '.tabs[.tab].pane_count == 1 and (.runs | length) == 0 and (.closed | length) > 0' 'verified pre-input cleanup failed'
done
reset_fake
HDW_INJECT='pane layout:1:error;pane close:1:exit' refuse cc
preserved
assert '.tabs[.tab].pane_count == 3 and (.runs | length) == 0' 'cleanup failure harmed layout'
grep -q 'cleanup unverified' "$TMP/error" || fail 'cleanup recovery missing'

# Replacement after a valid reply must not be treated as ownership, even when
# public pane/tab/workspace IDs, labels and the pane count are all unchanged.
for phase in 'pane get:4' 'pane get:6' 'pane list:3' 'pane list:4' 'pane list:5' 'pane list:6' 'pane list:7'; do
  for mode in replace replace-empty replace-caller replace-editor foreign-pane focus-away workspace-focus-away extra-tab extra-pane; do
    reset_fake
    HDW_INJECT="$phase:$mode" refuse cc
    assert '.replacement != null and .replacement == {workspaces,tabs,panes,trees,focused_panes} and
      (.runs | length) == .runs_at_replacement and (.writes | length) == .writes_at_replacement' "replacement mutated/received input: $phase:$mode"
    grep -q 'new workspace=w2 tab=w2:t1 root=w2:p1 retained' "$TMP/error" || fail 'replacement context missing'
  done
done
for run in 1 2; do
  for mode in exit lost error invalid unexpected; do
    reset_fake
    HDW_INJECT="pane run:$run:$mode" refuse cc
    preserved
    count=$run; [[ $mode != exit ]] || count=$((run - 1))
    assert ".tabs[.tab].pane_count == 3 and (.closed | length) == 0 and (.runs | length) == $count" 'post-input failure destroyed layout'
    grep -q 'tool input may have started; layout preserved' "$TMP/error" || fail 'input recovery missing'
  done
done

reset_fake
launch cc >"$TMP/a.log" 2>&1 & a=$!
launch oc >"$TMP/b.log" 2>&1 & b=$!
sa=0; wait "$a" || sa=$?
sb=0; wait "$b" || sb=$?
[[ $sa == 0 && $sb == 0 ]] || fail 'cooperating concurrent calls did not both succeed'
preserved
assert '(.runs | length) == 4 and .counts["pane split"] == 4 and .created == ["w2","w3"] and
  .workspaces.w2.pane_count == 3 and .workspaces.w3.pane_count == 3 and .workspaces.w3.focused and
  (.tabs["w1:t7"].focused | not) and (.panes["w1:p1"].focused | not) and
  (.tabs["w2:t1"].focused | not) and (.panes["w2:p1"].focused | not) and
  .focused_panes["w1:t7"] == "w1:p1" and .focused_panes["w2:t1"] == "w2:p1"' 'concurrent calls did not create independent workspaces'

HDW_WORKSPACE=wA reset_fake
HERDR_WORKSPACE_ID=wA HERDR_TAB_ID=wA:t7 HERDR_PANE_ID=wA:p1 launch cx -c || fail 'base-32 IDs rejected'
assert '.panes["wA:p1"] != null and .runs[1][3] == "codex resume --last"' 'base-32 IDs not exercised'
preserved
printf 'ok:   hdw new workspaces, populated/inactive/repeated/generated-shell callers, global focus projections, cwd, agents, identity, earlier-workspace preservation, lost cleanup, concurrency; geometry %s negative/%s positive\n' "$geometry_negative" "$geometry_positive"
