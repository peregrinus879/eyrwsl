#!/bin/bash
# Fixtures for the tdw workspace launcher on an isolated tmux server: one
# agent-named window with the agent at full height on the left
# half, the editor and shell split equally on the right, and focus on the agent; the
# three agents and their continue forms; re-attach; the root-collision guard;
# and the usage and missing-agent refusals. Stub agents record their arguments;
# ordinary attaches are recorded; a control client tests creation inside tmux.
# The fixture detaches itself from any controlling terminal, so the launcher
# sizes the window from LINES and COLUMNS and the geometry is deterministic.
set -euo pipefail

if [[ -z ${TDW_FIXTURE_DETACHED:-} ]]; then
  command -v setsid >/dev/null || { printf 'FAIL: setsid is required\n' >&2; exit 1; }
  exec setsid -w env TDW_FIXTURE_DETACHED=1 LINES=50 COLUMNS=200 bash "$0" "$@"
fi

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
SOCKET="tdw-test-$$"
BASE_SOCKET=$SOCKET suffix=""
trap 'for suffix in "" -reuse-{1..10}; do command tmux -L "$BASE_SOCKET$suffix" kill-server >/dev/null 2>&1 || true; rm -f -- "${TMUX_TMPDIR:-/tmp}/tmux-$UID/$BASE_SOCKET$suffix"; done; rm -rf -- "$TMP"' EXIT
unset TMUX TMUX_PANE
export XDG_STATE_HOME="$TMP/state" HOME="$TMP/home" HISTFILE=/dev/null
mkdir -p "$HOME"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# Panes run bash without profiles so the stub PATH is what they see. The
# default size must lose to the launcher's explicit size.
printf 'set -g default-command "bash --noprofile --norc"\nset -g default-size 80x24\n' >"$TMP/tmux.conf"
tmux() {
  local count=0 mode="" target="" previous="" arg action=$1 owner_value="" expected=""
  if [[ $1 == if-shell ]]; then
    action=${6%% *}; action=${action//\'/}
  fi
  if [[ $action == kill-session && ${TDW_CLEANUP_NOOP:-0} == 1 ]]; then
    command tmux -L "$SOCKET" display-message -p -t "$4" '#{TDW_OWNER}'
    return 0
  fi
  if [[ -n ${TDW_INJECT:-} ]]; then
    [[ ! -f $TMP/count-$action ]] || read -r count <"$TMP/count-$action"
    count=$((count + 1))
    printf '%s\n' "$count" >"$TMP/count-$action"
    [[ $TDW_INJECT != "$action:$count:"* ]] || mode=${TDW_INJECT##*:}
    [[ $mode != exit ]] || return 1
    if [[ $mode == lost || $mode == invalid ]]; then
      command tmux -L "$SOCKET" -f "$TMP/tmux.conf" "$@" >/dev/null || return 1
      [[ $mode != lost ]] || return 1
      printf 'invalid\n'
      return 0
    fi
    if [[ $mode == foreign ]]; then
      target=$(command tmux -L "$SOCKET" list-sessions -F '#{session_name}' | grep '^tdw-pending-')
      command tmux -L "$SOCKET" set-environment -t "=$target" TDW_OWNER foreign
      printf '%s\n' "$target" >"$TMP/foreign"
      return 1
    fi
    if [[ $mode == replace ]]; then
      [[ $(command tmux -L "$SOCKET" list-sessions -F '#{session_id}') == "\$0" ]] || fail 'replacement requires a private one-session server'
      command tmux -L "$SOCKET" display-message -p -t '%0' '#{TDW_OWNER}' >"$TMP/replaced-token"
      command tmux -L "$SOCKET" kill-server
      sleep 0.1
      command tmux -L "$SOCKET" -f "$TMP/tmux.conf" new-session -d -s foreign -x 200 -y 50
      command tmux -L "$SOCKET" split-window -h -t '%0'
      command tmux -L "$SOCKET" split-window -v -t '%1'
      command tmux -L "$SOCKET" set-environment -t foreign TDW_OWNER foreign
      command tmux -L "$SOCKET" set-option -t foreign @dw_root /foreign
      command tmux -L "$SOCKET" list-panes -t =foreign -F '#{session_id}|#{window_id}|#{pane_id}|#{session_name}|#{pane_active}|#{@dw_root}|#{TDW_OWNER}|#{automatic-rename}|#{allow-rename}|#{set-titles-string}' >"$TMP/replacement-before"
    fi
  fi
  if [[ $action == send-keys ]]; then
    if [[ $1 == if-shell ]]; then
      [[ $6 =~ (%[0-9]+) ]] || fail 'conditional send has no pane ID'
      target=${BASH_REMATCH[1]}
      owner_value=$(command tmux -L "$SOCKET" display-message -p -t "$4" '#{TDW_OWNER}')
      expected=${5#'#{==:#{TDW_OWNER},'}; expected=${expected%\}}
    else
      for arg in "$@"; do
        [[ $previous != -t ]] || target=$arg
        previous=$arg
      done
    fi
    [[ $target =~ ^%[0-9]+$ ]] || fail 'send-keys received an unchecked target'
    [[ $(command tmux -L "$SOCKET" display-message -p -t "$target" '#{window_panes}') == 3 ]] || fail 'keys sent before full layout'
    [[ $owner_value != "$expected" ]] || printf '%s\n' "$*" >>"$TMP/send.log"
  fi
  case ${1:-} in
    attach-session | switch-client)
      printf '%s\n' "$*" >>"$TMP/attach.log"
      return 0
      ;;
  esac
  command tmux -L "$SOCKET" -f "$TMP/tmux.conf" "$@"
}

mkdir -p "$TMP/bin" "$TMP/bin-min"
for stub in claude codex opencode; do
  cat >"$TMP/bin/$stub" <<STUB
#!/bin/bash
printf '%s\\n' "\$(basename "\$0")\${*:+ \$*}" >>'$TMP/calls.log'
sleep 60
STUB
  chmod +x "$TMP/bin/$stub"
done
for tool in git tmux mkdir flock mktemp stty rmdir; do ln -s "$(type -P "$tool")" "$TMP/bin-min/$tool"; done
export PATH="$TMP/bin:$PATH" EDITOR=true
# shellcheck source=/dev/null
source "$ROOT/bash/.config/bash/functions/tdw"

project() {
  mkdir -p "$1"
  git -C "$1" init -q
}

wait_for_call() {
  local i
  for ((i = 0; i < 40; i++)); do
    [[ -f $TMP/calls.log ]] && grep -qxF "$1" "$TMP/calls.log" && return 0
    sleep 0.25
  done
  return 1
}

assert_layout() {
  local session=$1 width=$2 height=$3 line
  local -a editor=() agent=() shell=() fields=()
  # active left top width height window_width window_height
  while IFS= read -r line; do
    read -r -a fields <<<"$line"
    if ((fields[1] == 0)); then agent=("${fields[@]}"); elif ((fields[2] > 0)); then shell=("${fields[@]}"); else editor=("${fields[@]}"); fi
  done < <(tmux list-panes -t "=$session" -F '#{pane_active} #{pane_left} #{pane_top} #{pane_width} #{pane_height} #{window_width} #{window_height}')
  ((${#editor[@]} && ${#agent[@]} && ${#shell[@]})) || fail "could not classify the three panes"
  ((shell[5] == width && shell[6] == height)) || fail "unexpected window size (${shell[5]}x${shell[6]}, expected ${width}x${height})"
  ((agent[0] == 1)) || fail "focus did not land on the agent pane"
  ((editor[1] == agent[3] + 1)) || fail "editor pane does not sit right of the agent"
  (( editor[3] - agent[3] <= 1 && agent[3] - editor[3] <= 1 )) || fail "agent and editor are not split 50/50 (${agent[3]} vs ${editor[3]})"
  ((shell[1] == editor[1] && shell[3] == editor[3])) || fail "shell does not sit under the editor at its width"
  ((agent[4] == agent[6])) || fail "agent pane does not take the full window height"
  ((editor[4] - shell[4] <= 1 && shell[4] - editor[4] <= 1)) || fail "editor and shell are not split 50/50 (${editor[4]} vs ${shell[4]})"
  ((editor[4] + shell[4] + 1 == shell[6])) || fail "editor row and shell do not fill the window height"
}

case_layout() {
  local dir="$TMP/proj/alpha.one" session="alpha-one"
  project "$dir"
  (cd "$dir" && tdw cc) || fail "tdw cc failed"
  [[ $(tmux list-windows -t "=$session" -F '#{window_name}:#{window_panes}') == "claude:3" ]] ||
    fail "expected one agent-named window with three panes"
  [[ $(tmux show-option -t "=$session:" -qv set-titles-string) == '#h:#S:#W' ]] || fail 'outer title omits project'
  assert_layout "$session" 200 50
  tmux resize-window -t "=$session" -x 201 -y 61
  assert_layout "$session" 201 61
  tmux resize-window -t "=$session" -x 200 -y 50
  assert_layout "$session" 200 50
  wait_for_call "claude" || fail "claude did not start in the agent pane"
  grep -qF -- "attach-session -t =$session" "$TMP/attach.log" || fail "creation did not attach"
  [[ $(tmux show-option -t "$session" -qv @dw_root) == "$dir" ]] || fail "session root was not recorded"
}

case_inside_tmux() {
  local dir="$TMP/proj/inside" caller launch i client_pid width height
  project "$dir"
  tmux new-session -d -s source -x 200 -y 50
  coproc TDW_CLIENT { command tmux -L "$SOCKET" -C attach-session -t =source >"$TMP/client.log"; }
  client_pid=$TDW_CLIENT_PID
  printf 'refresh-client -C 200,50\n' >&"${TDW_CLIENT[1]}"
  for ((i = 0; i < 40; i++)); do
    [[ $(tmux list-clients -F '#{client_width}') == 200 ]] && break
    sleep 0.25
  done
  ((i < 40)) || fail "control client did not attach at the requested size"
  read -r width height < <(tmux display-message -p -t =source: '#{window_width} #{window_height}')
  caller=$(tmux split-window -h -l 50% -t =source: -P -F '#{pane_id}')
  caller=$(tmux split-window -v -l 4 -t "$caller" -P -F '#{pane_id}')
  # This executes in the pane's real tty, not the fixture's detached shell.
  printf -v launch 'source %q; cd %q; tdw cc; tmux set-option -g @tdw_fixture_done "$?"' \
    "$ROOT/bash/.config/bash/functions/tdw" "$dir"
  tmux send-keys -t "$caller" "$launch" C-m
  for ((i = 0; i < 40; i++)); do
    [[ -n $(tmux show-option -gqv @tdw_fixture_done) ]] && break
    sleep 0.25
  done
  [[ $(tmux show-option -gqv @tdw_fixture_done) == 0 ]] || fail "tdw inside tmux did not finish successfully"
  [[ $(tmux show-option -t inside -v default-size) == "${width}x${height}" ]] ||
    fail "nested launch used the calling pane size rather than the full window"
  [[ $(tmux list-clients -F '#{session_name}') == inside ]] || fail "nested launch did not switch the client"
  assert_layout inside "$width" "$height"
  printf 'detach-client\n' >&"${TDW_CLIENT[1]}"
  wait "$client_pid"
}

case_continue_forms() {
  project "$TMP/proj/beta"
  (cd "$TMP/proj/beta" && tdw cx -c) || fail "tdw cx -c failed"
  wait_for_call "codex resume --last" || fail "codex did not receive resume --last"
  project "$TMP/proj/gamma"
  (cd "$TMP/proj/gamma" && tdw oc -c) || fail "tdw oc -c failed"
  wait_for_call "opencode -c" || fail "opencode did not receive -c"
  project "$TMP/proj/delta"
  (cd "$TMP/proj/delta" && tdw -c cc) || fail "tdw -c cc failed"
  wait_for_call "claude -c" || fail "claude did not receive -c"
}

case_reattach_and_collision() {
  local dir="$TMP/proj/alpha.one" other="$TMP/elsewhere/alpha.one" out
  out=$(cd "$dir" && tdw cc 2>&1) || fail "re-attach with arguments failed"
  [[ $out == *"session exists, arguments ignored"* ]] || fail "re-attach did not report ignored arguments"
  (cd "$dir" && tdw) || fail "bare tdw did not re-attach"
  (($(grep -c -- "attach-session -t =alpha-one" "$TMP/attach.log") == 3)) || fail "expected three attaches to the project session"
  (($(grep -cx "claude" "$TMP/calls.log") == 1)) || fail "re-attach relaunched the agent"
  project "$other"
  if (cd "$other" && tdw cc) >/dev/null 2>&1; then fail "root collision did not refuse"; fi
  [[ $(tmux show-option -t "alpha-one" -qv @dw_root) == "$dir" ]] || fail "collision changed the session root"
}

case_refusals() {
  local dir="$TMP/proj/usage"
  project "$dir"
  if (cd "$dir" && tdw) >/dev/null 2>&1; then fail "bare tdw without a session did not fail"; fi
  if (cd "$dir" && tdw cc oc) >/dev/null 2>&1; then fail "two agents were accepted"; fi
  if (cd "$dir" && tdw foo) >/dev/null 2>&1; then fail "unknown argument was accepted"; fi
  if (cd "$dir" && PATH="$TMP/bin-min" tdw cx) >"$TMP/error" 2>&1; then fail "missing agent was accepted"; fi
  grep -q "required agent 'codex' is not installed" "$TMP/error" || fail 'missing-agent fixture failed for an unrelated dependency'
  if tmux has-session -t "=usage" 2>/dev/null; then fail "a refusal created a session"; fi
}

case_transaction_failures() {
  local injection before sessions
  project "$TMP/proj/failure"
  sessions=$(tmux list-sessions -F '#{session_id} #{session_name}')
  for injection in new-session:1:exit new-session:1:lost new-session:1:invalid \
    set-option:1:exit split-window:1:exit split-window:2:exit split-window:1:invalid \
    split-window:2:invalid display-message:2:exit select-pane:1:exit rename-session:1:exit; do
    rm -f -- "$TMP"/count-*
    before=$(wc -l <"$TMP/send.log")
    if (cd "$TMP/proj/failure" && TDW_INJECT=$injection tdw cc) >"$TMP/error" 2>&1; then fail "$injection accepted"; fi
    [[ $(wc -l <"$TMP/send.log") == "$before" ]] || fail "$injection sent keys"
    [[ $(tmux list-sessions -F '#{session_id} #{session_name}') == "$sessions" ]] || fail "$injection left partial session or harmed existing one"
  done
  rm -f -- "$TMP"/count-*
  if (cd "$TMP/proj/failure" && TDW_INJECT=split-window:1:foreign tdw cc) >"$TMP/error" 2>&1; then fail 'foreign replacement accepted'; fi
  read -r sessions <"$TMP/foreign"
  tmux has-session -t "=$sessions" || fail 'rollback killed foreign ownership'
  grep -qF "creation $sessions" "$TMP/error" || fail 'refused rollback omitted the pending identity'
  tmux kill-session -t "=$sessions"
  rm -f -- "$TMP"/count-*
  if (cd "$TMP/proj/failure" && TDW_CLEANUP_NOOP=1 TDW_INJECT=split-window:1:exit tdw cc) >"$TMP/error" 2>&1; then fail 'unverified cleanup accepted'; fi
  sessions=$(command tmux -L "$SOCKET" list-sessions -F '#{session_name}' | grep '^tdw-pending-')
  grep -qF "creation $sessions" "$TMP/error" || fail 'unverified cleanup omitted exact recovery identity'
  tmux kill-session -t "=$sessions"
}

case_reused_ids() {
  local original=$SOCKET SOCKET=$SOCKET injection before index=0
  project "$TMP/proj/replaced"
  for injection in set-option:1:replace set-option:2:replace set-option:3:replace set-option:4:replace \
    split-window:1:replace split-window:2:replace display-message:2:replace select-pane:1:replace rename-session:1:replace send-keys:1:replace; do
    index=$((index + 1)); SOCKET="$original-reuse-$index"
    rm -f -- "$TMP"/count-*
    before=$(wc -l <"$TMP/send.log")
    if (cd "$TMP/proj/replaced" && TDW_INJECT=$injection tdw cc) >"$TMP/error" 2>&1; then fail "$injection accepted reused IDs"; fi
    command tmux -L "$SOCKET" list-panes -t =foreign -F '#{session_id}|#{window_id}|#{pane_id}|#{session_name}|#{pane_active}|#{@dw_root}|#{TDW_OWNER}|#{automatic-rename}|#{allow-rename}|#{set-titles-string}' >"$TMP/replacement-after"
    cmp "$TMP/replacement-before" "$TMP/replacement-after" || fail "$injection mutated the replacement"
    [[ $(wc -l <"$TMP/send.log") == "$before" ]] || fail "$injection sent input to reused panes"
    grep -qF "creation $(<"$TMP/replaced-token")" "$TMP/error" || fail "$injection omitted exact recovery identity"
    command tmux -L "$SOCKET" kill-server
  done
}

case_concurrent() {
  local first second before
  project "$TMP/proj/concurrent"
  before=$(wc -l <"$TMP/send.log")
  (cd "$TMP/proj/concurrent" && tdw cc) >"$TMP/first.log" 2>&1 & first=$!
  (cd "$TMP/proj/concurrent" && tdw oc) >"$TMP/second.log" 2>&1 & second=$!
  wait "$first" || fail 'first concurrent launcher failed'
  wait "$second" || fail 'second concurrent launcher failed'
  [[ $(wc -l <"$TMP/send.log") == $((before + 4)) ]] || fail 'concurrent launch sent more than one command set'
  assert_layout concurrent 200 50
}

case_quoting() {
  local session="quote's \$name;work" dir="$TMP/proj/quote's \$name;work" i
  project "$dir"
  (cd "$dir" && EDITOR=$'printf "%s\\n" "editor\'s \\$value; literal"' tdw cc) || fail 'quoted creation failed'
  tmux has-session -t "=$session" || fail 'quoted session name was not preserved'
  [[ $(tmux show-option -t "=$session:" -qv @dw_root) == "$dir" ]] || fail 'quoted root readback was not preserved'
  for ((i = 0; i < 40; i++)); do
    if tmux capture-pane -p -t "=$session:.1" | grep -qxF "editor's \$value; literal"; then return 0; fi
    sleep 0.1
  done
  fail 'server-side guard changed literal command quoting'
}

case_layout
case_continue_forms
case_reattach_and_collision
case_refusals
case_transaction_failures
case_reused_ids
case_concurrent
case_quoting
case_inside_tmux
printf 'ok:   tdw builds equal splits outside and inside tmux, survives resizing, focuses and continues agents, re-attaches, and refuses bad input\n'
