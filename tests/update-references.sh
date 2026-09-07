#!/bin/bash
# Fixtures for scripts/update-references.sh against local bare upstreams: the
# family union of references.txt files defines the quarry, missing own
# references are cloned, listed clones fast-forward while preserving tags, unlisted
# clones are always reported and kept, ahead-only listed branches fail, manifest
# conflicts stop the run before any change, and dry runs change nothing.
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

commit() { # work-dir message
  git -C "$1" -c user.name=fixture -c user.email=fixture@example.invalid commit -q --allow-empty -m "$2"
}

make_upstream() { # name -> bare repo at $TMP/upstream/<name>.git with one commit on main
  local bare="$TMP/upstream/$1.git" work="$TMP/work/$1"
  mkdir -p "$work" "$TMP/upstream"
  git init -q --bare -b main "$bare"
  git init -q -b main "$work"
  printf 'one\n' >"$work/file"
  git -C "$work" add file
  commit "$work" "one"
  git -C "$work" push -q "$bare" main
}

advance_upstream() { # name message
  local work="$TMP/work/$1"
  printf '%s\n' "$2" >>"$work/file"
  git -C "$work" add file
  commit "$work" "$2"
  git -C "$work" push -q "$TMP/upstream/$1.git" main
}

upstream_head() { git -C "$TMP/upstream/$1.git" rev-parse main; }

make_family() { # writes $TMP/eyrie/{eyrarchy,eyrwsl} manifests and the script copy
  mkdir -p "$TMP/eyrie/eyrarchy/scripts" "$TMP/eyrie/eyrwsl"
  cp -- "$ROOT/scripts/update-references.sh" "$TMP/eyrie/eyrarchy/scripts/update-references.sh"
  cat >"$TMP/eyrie/eyrarchy/references.txt" <<MANIFEST
# own references
alpha $TMP/upstream/alpha.git
beta  $TMP/upstream/beta.git   # trailing comment
MANIFEST
  cat >"$TMP/eyrie/eyrwsl/references.txt" <<MANIFEST
beta $TMP/upstream/beta.git
gamma $TMP/upstream/gamma.git
MANIFEST
}

run() { QUARRY="$TMP/quarry" bash "$TMP/eyrie/eyrarchy/scripts/update-references.sh" "$@"; }

for name in alpha beta gamma stale unpushed; do make_upstream "$name"; done
make_family
mkdir -p "$TMP/quarry"
git clone -q -- "$TMP/upstream/beta.git" "$TMP/quarry/beta"
git -C "$TMP/work/beta" tag nightly >/dev/null
git -C "$TMP/work/beta" push -q "$TMP/upstream/beta.git" refs/tags/nightly
git -C "$TMP/quarry/beta" fetch -q --tags origin
nightly=$(git -C "$TMP/quarry/beta" rev-parse refs/tags/nightly)
advance_upstream beta two
git -C "$TMP/work/beta" tag latest
git -C "$TMP/work/beta" push -q "$TMP/upstream/beta.git" refs/tags/latest
git clone -q -- "$TMP/upstream/stale.git" "$TMP/quarry/stale"
git clone -q -- "$TMP/upstream/unpushed.git" "$TMP/quarry/unpushed"
commit "$TMP/quarry/unpushed" "local only"
mkdir -p "$TMP/quarry/plain-dir"

# A clean current HEAD is not proof that an unlisted clone is disposable.
for name in branch-only tag-only stash-only ignored dirty; do
  git clone -q -- "$TMP/upstream/stale.git" "$TMP/quarry/$name"
done
git -C "$TMP/quarry/branch-only" checkout -q -b unpublished
commit "$TMP/quarry/branch-only" 'unpublished non-current branch'
git -C "$TMP/quarry/branch-only" checkout -q main
git -C "$TMP/quarry/tag-only" checkout -q --detach
commit "$TMP/quarry/tag-only" 'unpublished tag'
git -C "$TMP/quarry/tag-only" tag unpublished
git -C "$TMP/quarry/tag-only" checkout -q main
printf 'stashed edit\n' >>"$TMP/quarry/stash-only/file"
git -C "$TMP/quarry/stash-only" -c user.name=fixture -c user.email=fixture@example.invalid stash push -q -m 'fixture stash'
printf 'ignored-data\n' >>"$TMP/quarry/ignored/.git/info/exclude"
printf 'keep ignored data\n' >"$TMP/quarry/ignored/ignored-data"
printf 'local edit\n' >>"$TMP/quarry/dirty/file"
stale_names=(stale unpushed branch-only tag-only stash-only ignored dirty)
snapshot_stale() {
  local name
  for name in "${stale_names[@]}"; do
    find "$TMP/quarry/$name" -type f -print0 | sort -z | xargs -0 sha256sum
  done
}
stale_before=$(snapshot_stale)

# Dry run reports stale clones without inferring deletion safety or failing
# merely because unlisted data exists.
out=$(run --dry-run 2>&1) || fail "dry run failed: $out"
[[ $out == *"plan: alpha: clone"* && $out == *"note: stale: stale reference"* && $out == *"note: gamma: listed by eyrwsl only"* ]] ||
  fail "dry run did not plan clone, report stale clone, and note sibling: $out"
[[ ! -e $TMP/quarry/alpha && -d $TMP/quarry/stale ]] || fail "dry run changed the quarry"
[[ $(snapshot_stale) == "$stale_before" ]] || fail "dry run changed unlisted data"

# Real run: alpha cloned, beta fast-forwarded with a new tag, every stale
# clone preserved byte-for-byte, plain directory kept, gamma not cloned.
out=$(run 2>&1) || fail "run with unlisted clones failed: $out"
[[ -d $TMP/quarry/alpha && $(git -C "$TMP/quarry/alpha" rev-parse HEAD) == $(upstream_head alpha) ]] || fail "own reference was not cloned"
[[ $(git -C "$TMP/quarry/beta" rev-parse HEAD) == $(upstream_head beta) ]] || fail "listed clone did not fast-forward"
[[ $(git -C "$TMP/quarry/beta" rev-parse refs/tags/nightly) == "$nightly" ]] || fail "existing tag was changed"
[[ $(git -C "$TMP/quarry/beta" rev-parse 'latest^{commit}') == $(upstream_head beta) ]] || fail "new tag was not imported"
[[ -d $TMP/quarry/stale ]] || fail "clean unlisted clone was removed"
[[ -d $TMP/quarry/unpushed && -d $TMP/quarry/plain-dir && ! -e $TMP/quarry/gamma ]] || fail "unpushed clone, plain directory, or sibling-only reference was mishandled"
for name in "${stale_names[@]}"; do
  [[ $out == *"note: $name: stale reference"* ]] || fail "unlisted clone was not reported: $name"
done
[[ $(snapshot_stale) == "$stale_before" ]] || fail "unlisted refs, stash, ignored files, or dirty data changed"
run >/dev/null 2>&1 || fail "settled quarry did not succeed"
[[ $(snapshot_stale) == "$stale_before" ]] || fail "repeat update changed stale clones"

# A listed clone with local changes is left alone and fails the run.
printf 'edit\n' >>"$TMP/quarry/beta/file"
if run >/dev/null 2>&1; then fail "dirty listed clone did not fail closed"; fi
[[ $(<"$TMP/quarry/beta/file") == *edit ]] || fail "dirty listed clone was changed"
git -C "$TMP/quarry/beta" checkout -q -- file

# --ff-only alone accepts an ahead-only branch. Refuse before switching away
# from a non-default checkout too, and preserve both local branch tips.
commit "$TMP/quarry/beta" 'ahead only'
ahead=$(git -C "$TMP/quarry/beta" rev-parse HEAD)
if out=$(run 2>&1); then fail "ahead-only listed branch was accepted: $out"; fi
[[ $out == *'ahead of or diverged'* && $(git -C "$TMP/quarry/beta" rev-parse HEAD) == "$ahead" ]] || fail "ahead-only branch was changed or misreported"
git -C "$TMP/quarry/beta" checkout -q -b inspection origin/main
inspection=$(git -C "$TMP/quarry/beta" rev-parse HEAD)
if run >/dev/null 2>&1; then fail "ahead-only non-current default branch was accepted"; fi
[[ $(git -C "$TMP/quarry/beta" branch --show-current) == inspection &&
  $(git -C "$TMP/quarry/beta" rev-parse HEAD) == "$inspection" &&
  $(git -C "$TMP/quarry/beta" rev-parse main) == "$ahead" ]] || fail "ahead-only refusal switched or rewrote a branch"
git -C "$TMP/quarry/beta" push -q "$TMP/upstream/beta.git" main
run >/dev/null 2>&1 || fail "exact upstream parity did not succeed after fixture publication"
[[ $(git -C "$TMP/quarry/beta" rev-parse HEAD) == $(upstream_head beta) ]] || fail "successful run did not reach exact fetched parity"

# Manifests that disagree stop the run before any change.
advance_upstream alpha three
printf 'alpha %s/upstream/other.git\n' "$TMP" >>"$TMP/eyrie/eyrwsl/references.txt"
if run >/dev/null 2>&1; then fail "conflicting manifests did not fail closed"; fi
[[ $(git -C "$TMP/quarry/alpha" rev-parse HEAD) != $(upstream_head alpha) ]] || fail "conflicting manifests still updated a clone"
sed -i '$d' "$TMP/eyrie/eyrwsl/references.txt"
run >/dev/null 2>&1 || fail "repaired manifests did not succeed"
[[ $(git -C "$TMP/quarry/alpha" rev-parse HEAD) == $(upstream_head alpha) ]] || fail "clone did not fast-forward after the repair"

# Fetch before resolving origin/HEAD so a newly introduced default branch works.
git -C "$TMP/work/alpha" checkout -q -b next
commit "$TMP/work/alpha" 'new default'
git -C "$TMP/work/alpha" push -q "$TMP/upstream/alpha.git" next
git -C "$TMP/upstream/alpha.git" symbolic-ref HEAD refs/heads/next
run >/dev/null 2>&1 || fail "new upstream default branch did not settle"
[[ $(git -C "$TMP/quarry/alpha" branch --show-current) == next &&
  $(git -C "$TMP/quarry/alpha" rev-parse HEAD) == $(git -C "$TMP/upstream/alpha.git" rev-parse next) ]] || fail "new default did not reach exact parity"

# A missing quarry is created; a missing manifest and a bad flag fail.
rm -rf -- "$TMP/quarry"
run >/dev/null 2>&1 || fail "missing quarry was not created"
[[ -d $TMP/quarry/alpha && -d $TMP/quarry/beta ]] || fail "own references were not cloned into the new quarry"
if run --bogus >/dev/null 2>&1; then fail "unknown flag was accepted"; fi
if run --dry-run extra >/dev/null 2>&1; then fail "extra operand was accepted"; fi
mv -- "$TMP/eyrie/eyrarchy/references.txt" "$TMP/eyrie/eyrarchy/references.off"
if run >/dev/null 2>&1; then fail "missing manifest was accepted"; fi

case_ignored_collisions() {
  local mode name work upstream base repo quarry clone branch before out expected
  for mode in merge existing-default new-default; do
    name="ignored-$mode"; base="$TMP/$name"
    work="$TMP/work/$name"; upstream="$TMP/upstream/$name.git"
    repo="$base/family/eyrarchy"; quarry="$base/quarry"; clone="$quarry/listed"
    make_upstream "$name"
    mkdir -p "$repo/scripts" "$quarry"
    cp -- "$ROOT/scripts/update-references.sh" "$repo/scripts/update-references.sh"
    printf 'listed %s\n' "$upstream" >"$repo/references.txt"
    git clone -q "$upstream" "$clone"
    if [[ $mode == new-default ]]; then git -C "$work" checkout -q -b next; fi
    printf 'incoming tracked content\n' >"$work/collision.txt"
    git -C "$work" add collision.txt
    commit "$work" 'add colliding path'
    branch=$(git -C "$work" branch --show-current)
    git -C "$work" push -q "$upstream" "$branch"
    expected=$(git -C "$work" rev-parse HEAD)
    if [[ $mode == existing-default ]]; then
      git -C "$clone" checkout -q -b inspection
      git -C "$clone" fetch -q --no-tags origin
      git -C "$clone" update-ref refs/heads/main "$expected" "$(git -C "$clone" rev-parse main)"
    elif [[ $mode == new-default ]]; then
      git -C "$upstream" symbolic-ref HEAD refs/heads/next
    fi
    printf 'collision.txt\n' >>"$clone/.git/info/exclude"
    printf 'irreplaceable ignored bytes\n' >"$clone/collision.txt"
    cp -- "$clone/collision.txt" "$base/original"
    before=$(git -C "$clone" rev-parse HEAD)
    branch=$(git -C "$clone" branch --show-current)
    [[ -z $(git -C "$clone" status --porcelain) ]] || fail "collision fixture is not ignored"
    if out=$(QUARRY="$quarry" bash "$repo/scripts/update-references.sh" 2>&1); then fail "listed ignored collision was accepted: $mode"; fi
    [[ $out == *collision.txt* ]] || fail "ignored collision was not identified: $out"
    cmp -s "$base/original" "$clone/collision.txt" || fail "ignored bytes were overwritten: $mode"
    [[ $(git -C "$clone" rev-parse HEAD) == "$before" && $(git -C "$clone" branch --show-current) == "$branch" ]] || fail "ignored collision changed checkout: $mode"
    [[ -z $(git -C "$clone" ls-files collision.txt) ]] || fail "ignored collision changed index: $mode"
    if [[ $mode == new-default ]] && git -C "$clone" show-ref --verify -q refs/heads/next; then fail "refused checkout created the new default branch"; fi
    mv -- "$clone/collision.txt" "$base/preserved"
    QUARRY="$quarry" bash "$repo/scripts/update-references.sh" >/dev/null 2>&1 || fail "safe update did not recover after fixture preservation: $mode"
    [[ $(git -C "$clone" rev-parse HEAD) == "$expected" ]] || fail "recovered fixture did not reach exact parity"
    cmp -s "$base/original" "$base/preserved" || fail "recovery lost the preserved ignored file"
  done
}

case_tag_preservation() {
  local base="$TMP/tag-safety" repo="$TMP/tag-safety/family/eyrarchy" quarry="$TMP/tag-safety/quarry"
  local work="$TMP/work/tags" upstream="$TMP/upstream/tags.git" clone="$TMP/tag-safety/quarry/listed"
  local name initial annotation refs_before head_before config_before out refspec replacement
  local -A original=()
  make_upstream tags
  initial=$(upstream_head tags)
  git -C "$work" tag nightly
  git -C "$work" -c user.name=fixture -c user.email=fixture@example.invalid tag -a rolling -m 'original annotation'
  git -C "$work" branch retired
  git -C "$work" push -q --tags "$upstream" retired
  mkdir -p "$repo/scripts" "$quarry"
  cp -- "$ROOT/scripts/update-references.sh" "$repo/scripts/update-references.sh"
  printf 'listed %s\n' "$upstream" >"$repo/references.txt"
  git clone -q "$upstream" "$clone"
  git -C "$clone" checkout -q --detach
  commit "$clone" 'unpublished tag-only commit'
  git -C "$clone" tag private-lightweight
  git -C "$clone" -c user.name=fixture -c user.email=fixture@example.invalid tag -a private-annotated -m 'private annotation to preserve'
  git -C "$clone" checkout -q main
  for name in nightly rolling private-lightweight private-annotated; do
    original[$name]=$(git -C "$clone" rev-parse "refs/tags/$name")
  done
  annotation=$(git -C "$clone" cat-file tag refs/tags/private-annotated)
  # Inherited pruning and tag preferences must not override this command's
  # preservation policy. None of these configuration values is rewritten.
  printf '[fetch]\nprune = true\npruneTags = true\n' >"$base/global.config"
  git -C "$clone" config remote.origin.prune true
  git -C "$clone" config remote.origin.pruneTags true
  git -C "$clone" config remote.origin.tagOpt --no-tags
  config_before=$(git -C "$clone" config --local --list)
  tag_run() { GIT_CONFIG_GLOBAL="$base/global.config" QUARRY="$quarry" bash "$repo/scripts/update-references.sh" "$@"; }

  advance_upstream tags two
  git -C "$work" tag added-lightweight
  git -C "$work" -c user.name=fixture -c user.email=fixture@example.invalid tag -a added-annotated -m 'new upstream annotation'
  git -C "$work" push -q --tags "$upstream" :refs/heads/retired
  out=$(tag_run 2>&1) || fail "safe tag update failed under inherited pruning: $out"
  [[ $(git -C "$clone" rev-parse HEAD) == $(upstream_head tags) ]] || fail "tag-safe fetch did not reach head parity"
  if git -C "$clone" show-ref --verify -q refs/remotes/origin/retired; then fail "stale origin tracking branch was not pruned"; fi
  for name in added-lightweight added-annotated; do
    [[ $(git -C "$clone" rev-parse "refs/tags/$name") == $(git -C "$upstream" rev-parse "refs/tags/$name") ]] || fail "new tag was not imported: $name"
  done
  for name in "${!original[@]}"; do
    [[ $(git -C "$clone" rev-parse "refs/tags/$name") == "${original[$name]}" ]] || fail "existing local tag was pruned or replaced: $name"
  done
  [[ $(git -C "$clone" cat-file tag refs/tags/private-annotated) == "$annotation" ]] || fail "private annotation changed"
  [[ $(git -C "$clone" config --local --list) == "$config_before" ]] || fail "fetch rewrote local configuration"

  advance_upstream tags three
  git -C "$work" -c user.name=fixture -c user.email=fixture@example.invalid tag -a replacement -m 'different annotation, same commit' "$initial"
  git -C "$work" push -q "$upstream" refs/tags/replacement
  refs_before=$(git -C "$clone" for-each-ref --format='%(refname) %(objectname)')
  head_before=$(git -C "$clone" rev-parse HEAD)
  # Simulate upstream movement only inside this private fixture, using exact
  # old/new OIDs. Neither a moved commit nor annotation-only drift is safe to overwrite.
  for name in nightly rolling; do
    if [[ $name == nightly ]]; then replacement=$(upstream_head tags)
    else replacement=$(git -C "$upstream" rev-parse refs/tags/replacement); fi
    git -C "$upstream" update-ref "refs/tags/$name" "$replacement" "${original[$name]}"
    if out=$(tag_run 2>&1); then fail "moved upstream tag was accepted: $name"; fi
    [[ $out == *'would clobber existing tag'* && $out == *'tag conflicts require separate review'* ]] || fail "tag refusal was not reported: $out"
    [[ $(git -C "$clone" for-each-ref --format='%(refname) %(objectname)') == "$refs_before" &&
      $(git -C "$clone" rev-parse HEAD) == "$head_before" ]] || fail "tag conflict partially updated refs or checkout"
    [[ $(git -C "$clone" cat-file tag refs/tags/rolling) == "$(git -C "$clone" cat-file tag "${original[rolling]}")" ]] || fail "original rolling annotation was lost"
    git -C "$upstream" update-ref "refs/tags/$name" "${original[$name]}" "$replacement"
  done

  # --no-force does not cancel '+' on configured refspecs. Refuse tag, mirror,
  # local-branch, remapped, and exclusion configurations before any fetch.
  for refspec in '+refs/tags/*:refs/tags/*' 'refs/tags/*:refs/tags/*' '+refs/*:refs/*' \
    '+refs/heads/*:refs/heads/*' '+refs/heads/*:refs/tags/*' '^refs/heads/private'; do
    git -C "$clone" config --add remote.origin.fetch "$refspec"
    if out=$(tag_run 2>&1); then fail "unsafe fetch refspec was accepted: $refspec"; fi
    [[ $out == *'incompatible origin fetch refspec'* ]] || fail "refspec refusal was not reported: $out"
    [[ $(git -C "$clone" for-each-ref --format='%(refname) %(objectname)') == "$refs_before" ]] || fail "refspec refusal modified refs"
    git -C "$clone" config --fixed-value --unset-all remote.origin.fetch "$refspec"
  done
  printf '[remote "origin"]\nfetch = +refs/tags/*:refs/tags/*\n' >>"$base/global.config"
  if out=$(tag_run --dry-run 2>&1); then fail "inherited forced tag mapping was accepted"; fi
  [[ $out == *'incompatible origin fetch refspec'* ]] || fail "inherited mapping was not classified"
  printf '[fetch]\nprune = true\npruneTags = true\n' >"$base/global.config"
  git -C "$clone" config remote.origin.tagOpt --force
  if out=$(tag_run 2>&1); then fail "unsupported force tagOpt was accepted"; fi
  [[ $out == *'incompatible origin tagOpt'* ]] || fail "tagOpt refusal was not reported"
  [[ $(git -C "$clone" for-each-ref --format='%(refname) %(objectname)') == "$refs_before" ]] || fail "configuration refusal modified refs"
  git -C "$clone" config remote.origin.tagOpt --no-tags
  tag_run >/dev/null 2>&1 || fail "tag-safe update failed after fixture conflicts were repaired"
  [[ $(git -C "$clone" rev-parse HEAD) == $(upstream_head tags) ]] || fail "repaired clone did not reach parity"
  for name in "${!original[@]}"; do
    [[ $(git -C "$clone" rev-parse "refs/tags/$name") == "${original[$name]}" ]] || fail "original tag changed after recovery: $name"
  done
}

case_twin_pair() {
  local left="$TMP/pair/self" right="$TMP/pair/peer" self peer original_peer ci_run bin runner out
  mkdir -p "$left" "$right"
  cp -- "$ROOT/Makefile" "$left/Makefile"
  printf '\nTWIN_SPECS := twin\n' >>"$left/Makefile"
  # Peer source code is deliberately unusable. Only its committed blobs count.
  # shellcheck disable=SC2016
  printf '$(error peer Makefile must never execute)\n' >"$right/Makefile"
  for repo in "$left" "$right"; do
    git -C "$repo" init -q
    printf 'identical twin\n' >"$repo/twin"
    git -C "$repo" add twin Makefile
    commit "$repo" 'twin pair'
  done
  self=$(git -C "$left" rev-parse HEAD)
  peer=$(git -C "$right" rev-parse HEAD)
  original_peer=$peer
  make --no-print-directory -C "$left" twins-pair TWIN_SPECS=twin SELF_COMMIT="$self" PEER_COMMIT="$peer" SIBLING="$right" >/dev/null || fail "exact twin pair was rejected"
  local input_bin="$TMP/pair/input-bin" marker="$TMP/pair/INPUT_MARKER" calls="$TMP/pair/git-calls" key payload transport out s p sibling real_git
  local -a payloads=() assignments=()
  mkdir -p "$input_bin" "$TMP/pair/input-home" "$TMP/pair/cross"
  cat >"$input_bin/git" <<'SH'
#!/bin/bash
printf 'git\n' >>"$EYR_INPUT_GIT_CALLS"
exec "$EYR_INPUT_GIT" "$@"
SH
  chmod +x "$input_bin/git"
  real_git=$(command -v git)
  payloads=("'; touch '$marker'; #" "\"; touch '$marker'; #" "\$(shell touch $marker)" "\$(touch $marker)"
    "\$\$(touch $marker)" "\`touch $marker\`" "literal \$dollars" 'value with spaces' $'value\nwith newline'
    "'; git -C '$right' rev-parse HEAD; #")
  for key in SELF_COMMIT PEER_COMMIT SIBLING; do
    for payload in "${payloads[@]}"; do
      s=$self; p=$peer; sibling=$right
      case $key in SELF_COMMIT) s=$payload ;; PEER_COMMIT) p=$payload ;; SIBLING) s=invalid; sibling=$payload ;; esac
      assignments=("SELF_COMMIT=$s" "PEER_COMMIT=$p" "SIBLING=$sibling")
      for transport in argv environment; do
        if [[ $transport == argv ]]; then
          if out=$(HOME="$TMP/pair/input-home" PATH="$input_bin:$PATH" EYR_INPUT_GIT_CALLS="$calls" EYR_INPUT_GIT="$real_git" make --no-print-directory -C "$left" twins-pair TWIN_SPECS=twin "${assignments[@]}" 2>&1); then fail "pair accepted invalid $key"; fi
        else
          if out=$(HOME="$TMP/pair/input-home" PATH="$input_bin:$PATH" EYR_INPUT_GIT_CALLS="$calls" EYR_INPUT_GIT="$real_git" env "${assignments[@]}" make --no-print-directory -C "$left" twins-pair TWIN_SPECS=twin 2>&1); then fail "pair accepted invalid environment $key"; fi
        fi
        [[ $out == *'must be full 40-character commit IDs'* ]] || fail "pair input reached shell parsing before validation: $out"
        [[ ! -e $marker && ! -e $calls ]] || fail "invalid pair input executed code or accessed Git ($key/$transport)"
      done
    done
  done
  sibling="$TMP/pair/peer's \$(shell touch INPUT_MARKER) \$dollars and spaces"
  git clone -q --shared "$right" "$sibling"
  make --no-print-directory -C "$left" twins-pair TWIN_SPECS=twin SELF_COMMIT="$self" PEER_COMMIT="$peer" "SIBLING=$TMP/pair/cross/../${sibling##*/}" >/dev/null || fail "literal cross-directory peer path was not preserved"
  [[ ! -e $marker && ! -e $left/INPUT_MARKER ]] || fail "literal SIBLING path executed Make or shell code"
  printf 'dirty local worktree\n' >"$left/twin"
  printf 'different dirty peer worktree\n' >"$right/twin"
  make --no-print-directory -C "$left" twins-pair TWIN_SPECS=twin SELF_COMMIT="$self" PEER_COMMIT="$peer" SIBLING="$right" >/dev/null || fail "pair check used worktrees instead of exact commits"
  git -C "$right" add twin
  commit "$right" 'peer drift'
  peer=$(git -C "$right" rev-parse HEAD)
  if make --no-print-directory -C "$left" twins-pair TWIN_SPECS=twin SELF_COMMIT="$self" PEER_COMMIT="$peer" SIBLING="$right" >/dev/null 2>&1; then fail "committed peer drift was accepted"; fi
  git -C "$right" replace "$peer" "$original_peer"
  if out=$(make --no-print-directory -C "$left" twins-pair TWIN_SPECS=twin SELF_COMMIT="$self" PEER_COMMIT="$peer" SIBLING="$right" 2>&1); then fail "peer replacement concealed committed drift"; fi
  [[ $out == *'drifted in the exact commit pair'* ]] || fail "peer replacement failed for the wrong reason: $out"
  git -C "$right" replace -d "$peer" >/dev/null
  git -C "$left" fetch -q "$right" "$peer"
  git -C "$left" replace "$self" "$peer"
  if out=$(make --no-print-directory -C "$left" twins-pair TWIN_SPECS=twin SELF_COMMIT="$self" PEER_COMMIT="$peer" SIBLING="$right" 2>&1); then fail "self replacement concealed committed drift"; fi
  [[ $out == *'drifted in the exact commit pair'* ]] || fail "self replacement failed for the wrong reason: $out"
  git -C "$left" replace -d "$self" >/dev/null
  make --no-print-directory -C "$left" twins-pair TWIN_SPECS=twin SELF_COMMIT="$self" PEER_COMMIT="$original_peer" SIBLING="$right" >/dev/null || fail "explicit earlier reviewed peer was not used"
  for peer in '' main "${original_peer:0:12}" 0000000000000000000000000000000000000000; do
    if make --no-print-directory -C "$left" twins-pair TWIN_SPECS=twin SELF_COMMIT="$self" PEER_COMMIT="$peer" SIBLING="$right" >/dev/null 2>&1; then fail "missing, symbolic, short, or unavailable peer was accepted: $peer"; fi
  done
  if make --no-print-directory -C "$left" twins-pair TWIN_SPECS=twin SELF_COMMIT="$self" PEER_COMMIT="$original_peer" SIBLING="$TMP/missing-peer" >/dev/null 2>&1; then fail "missing peer was skipped instead of refused"; fi
  if make --no-print-directory -C "$left" twins-pair TWIN_SPECS=absent SELF_COMMIT="$self" PEER_COMMIT="$original_peer" SIBLING="$right" >/dev/null 2>&1; then fail "twins missing in both commits were accepted"; fi

  # Execute the actual CI shell block, mapping its fixed peer URL to the local
  # fixture. No checkout, peer Makefile execution, or network is involved.
  ci_run=$(python3 - "$ROOT/.github/workflows/test.yml" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
block = text.split("\n  twins:\n", 1)[1].split("        run: |\n", 1)[1]
lines = []
for line in block.splitlines():
    if line and not line.startswith("          "):
        break
    lines.append(line[10:])
assert lines, "missing CI twin shell block"
print("\n".join(lines))
PY
  )
  bin="$TMP/pair/bin"
  mkdir -p "$bin" "$TMP/pair/home"
  cat >"$bin/git" <<'SH'
#!/bin/bash
set -euo pipefail
printf 'git\n' >>"$EYR_TEST_GIT_CALLS"
args=()
for arg in "$@"; do
  case $arg in
    https://github.com/peregrinus879/eyrarchy.git|https://github.com/peregrinus879/eyrwsl.git) args+=("$EYR_TEST_PEER") ;;
    http*://*|ssh://*|git@*) exit 99 ;;
    *) args+=("$arg") ;;
  esac
done
exec "$EYR_TEST_GIT" "${args[@]}"
SH
  chmod +x "$bin/git"
  local scenario reviewed expected code real_git
  real_git=$(command -v git)
  for scenario in default reviewed unreviewed malformed unavailable; do
    runner="$TMP/pair/ci-$scenario"; mkdir -p "$runner"
    peer=$original_peer; reviewed=true; expected=1
    case $scenario in
      default) peer=''; reviewed='' ;;
      reviewed) expected=0 ;;
      unreviewed) reviewed=false ;;
      malformed) peer='main; exit 0' ;;
      unavailable) peer=0000000000000000000000000000000000000000 ;;
    esac
    code=0
    out=$(cd -- "$left" && HOME="$TMP/pair/home" PATH="$bin:$PATH" EYR_TEST_GIT="$real_git" EYR_TEST_PEER="$right" EYR_TEST_GIT_CALLS="$runner/git-calls" RUNNER_TEMP="$runner" GITHUB_STEP_SUMMARY="$runner/summary" PEER_COMMIT="$peer" PEER_REVIEWED="$reviewed" bash -c "$ci_run" 2>&1) || code=$?
    if [[ $expected == 0 ]]; then
      [[ $code == 0 && $out == *"pair: self=$self peer=$original_peer"* ]] || fail "reviewed CI pair did not succeed: $out"
      [[ $(<"$runner/summary") == *"$self"* && $(<"$runner/summary") == *"$original_peer"* ]] || fail "CI summary omitted the exact pair"
    else
      [[ $code != 0 ]] || fail "CI accepted $scenario peer input or default-branch drift"
    fi
    if [[ $scenario == unreviewed || $scenario == malformed ]]; then
      [[ ! -e $runner/git-calls ]] || fail "CI fetched an unreviewed or malformed peer"
    fi
  done
}

case_ignored_collisions
case_tag_preservation
case_twin_pair
printf 'ok:   update-references preserves local tags, refuses moved tags/unsafe mappings, reaches exact fetched parity, and keeps stale clones; twins-pair checks exact commits without executing peer code\n'
