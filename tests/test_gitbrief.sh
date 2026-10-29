#!/usr/bin/env bash
# tests/test_gitbrief.sh - Comprehensive automated test suite for gitbrief
# Compatible with macOS Bash 3.2 and modern Linux Bash.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITBRIEF="$(cd "$SCRIPT_DIR/.." && pwd)/gitbrief"
ORIG_PWD="$(pwd)"

if [ ! -x "$GITBRIEF" ]; then
    echo "Error: gitbrief executable not found at $GITBRIEF" >&2
    exit 1
fi

# Isolated temporary workspace for all test fixtures
TEST_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/gitbrief_test.XXXXXX")"
cleanup() {
    cd "$ORIG_PWD"
    rm -rf "$TEST_TMPDIR"
}
trap cleanup EXIT INT TERM

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Formatting
if [ -t 1 ]; then
    C_GREEN="\033[32m"
    C_RED="\033[31m"
    C_CYAN="\033[36m"
    C_RESET="\033[0m"
    C_BOLD="\033[1m"
else
    C_GREEN=""
    C_RED=""
    C_CYAN=""
    C_RESET=""
    C_BOLD=""
fi

pass() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf "${C_GREEN}  ✓ PASS:${C_RESET} %s\n" "$1"
}

fail() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf "${C_RED}  ✗ FAIL:${C_RESET} %s\n" "$1"
    if [ -n "${2:-}" ]; then
        printf "         ${C_RED}Details:${C_RESET} %s\n" "$2"
    fi
}

header() {
    printf "\n${C_BOLD}${C_CYAN}==> %s${C_RESET}\n" "$1"
}

# Helper to create a clean sandboxed Git repository
make_repo() {
    local repo_dir="$TEST_TMPDIR/$1"
    mkdir -p "$repo_dir"
    cd "$repo_dir"
    git init -q
    git config user.name "Test Runner"
    git config user.email "test@example.com"
    git checkout -q -b main 2>/dev/null || git branch -M main 2>/dev/null || true
    echo "$repo_dir"
}

header "Running gitbrief automated test suite"

# -----------------------------------------------------------------------------
# Test 1: Clean working tree
# -----------------------------------------------------------------------------
test_clean_tree() {
    local repo
    repo="$(make_repo "test1_clean")"
    cd "$repo"
    echo "initial content" > file.txt
    git add file.txt
    git commit -qm "initial commit"

    local out status=0
    out="$("$GITBRIEF" --no-color 2>&1)" || status=$?

    if [ "$status" -eq 0 ] && \
       echo "$out" | grep -q "Staged changes:   0" && \
       echo "$out" | grep -q "Unstaged changes: 0" && \
       echo "$out" | grep -q "Untracked files:  0" && \
       echo "$out" | grep -q "Branch:     main"; then
        pass "1. Clean working tree reports 0 changes and exits 0"
    else
        fail "1. Clean working tree" "Status: $status, Output: $out"
    fi
    cd "$ORIG_PWD"
}
test_clean_tree

# -----------------------------------------------------------------------------
# Test 2: Modified tracked files
# -----------------------------------------------------------------------------
test_modified_files() {
    local repo
    repo="$(make_repo "test2_modified")"
    cd "$repo"
    echo "initial content" > file.txt
    git add file.txt
    git commit -qm "initial commit"

    echo "modified content" >> file.txt

    local out status=0
    out="$("$GITBRIEF" --no-color 2>&1)" || status=$?

    if [ "$status" -eq 0 ] && \
       echo "$out" | grep -q "Unstaged changes: 1" && \
       echo "$out" | grep -q "\* \[M\] file.txt" && \
       echo "$out" | grep -q "Staged changes:   0"; then
        pass "2. Modified tracked files detected under Unstaged changes"
    else
        fail "2. Modified tracked files" "Status: $status, Output: $out"
    fi
    cd "$ORIG_PWD"
}
test_modified_files

# -----------------------------------------------------------------------------
# Test 3: Untracked files
# -----------------------------------------------------------------------------
test_untracked_files() {
    local repo
    repo="$(make_repo "test3_untracked")"
    cd "$repo"
    echo "committed" > init.txt
    git add init.txt
    git commit -qm "initial commit"

    echo "untracked 1" > un1.txt
    echo "untracked 2" > un2.txt

    local out status=0
    out="$("$GITBRIEF" --no-color 2>&1)" || status=$?

    if [ "$status" -eq 0 ] && \
       echo "$out" | grep -q "Untracked files:  2" && \
       echo "$out" | grep -q "\? un1.txt" && \
       echo "$out" | grep -q "\? un2.txt"; then
        pass "3. Untracked files reported with '?' and correct count"
    else
        fail "3. Untracked files" "Status: $status, Output: $out"
    fi
    cd "$ORIG_PWD"
}
test_untracked_files

# -----------------------------------------------------------------------------
# Test 4: Staged additions and modifications
# -----------------------------------------------------------------------------
test_staged_changes() {
    local repo
    repo="$(make_repo "test4_staged")"
    cd "$repo"
    echo "file1" > file1.txt
    git add file1.txt
    git commit -qm "first commit"

    echo "file1 modified" >> file1.txt
    echo "file2 added" > file2.txt
    git add file1.txt file2.txt

    local out status=0
    out="$("$GITBRIEF" --no-color 2>&1)" || status=$?

    if [ "$status" -eq 0 ] && \
       echo "$out" | grep -q "Staged changes:   2" && \
       echo "$out" | grep -q "+ \[M\] file1.txt" && \
       echo "$out" | grep -q "+ \[A\] file2.txt"; then
        pass "4. Staged additions and modifications reported with '+'"
    else
        fail "4. Staged additions and modifications" "Status: $status, Output: $out"
    fi
    cd "$ORIG_PWD"
}
test_staged_changes

# -----------------------------------------------------------------------------
# Test 5: A file containing both staged and unstaged changes
# -----------------------------------------------------------------------------
test_staged_and_unstaged() {
    local repo
    repo="$(make_repo "test5_staged_and_unstaged")"
    cd "$repo"
    echo "line 1" > dual.txt
    git add dual.txt
    git commit -qm "initial"

    echo "line 2" >> dual.txt
    git add dual.txt
    echo "line 3" >> dual.txt

    local out status=0
    out="$("$GITBRIEF" --no-color 2>&1)" || status=$?

    if [ "$status" -eq 0 ] && \
       echo "$out" | grep -q "Staged changes:   1" && \
       echo "$out" | grep -q "+ \[M\] dual.txt" && \
       echo "$out" | grep -q "Unstaged changes: 1" && \
       echo "$out" | grep -q "\* \[M\] dual.txt"; then
        pass "5. File containing both staged and unstaged changes"
    else
        fail "5. File containing both staged and unstaged changes" "Status: $status, Output: $out"
    fi
    cd "$ORIG_PWD"
}
test_staged_and_unstaged

# -----------------------------------------------------------------------------
# Test 6: Deleted and renamed files
# -----------------------------------------------------------------------------
test_deleted_and_renamed() {
    local repo
    repo="$(make_repo "test6_deleted_renamed")"
    cd "$repo"
    echo "delete me" > del.txt
    echo "rename me" > ren.txt
    echo "unstaged delete" > un_del.txt
    git add .
    git commit -qm "initial files"

    git rm -q del.txt
    git mv ren.txt renamed.txt
    rm un_del.txt

    local out status=0
    out="$("$GITBRIEF" --no-color 2>&1)" || status=$?

    if [ "$status" -eq 0 ] && \
       echo "$out" | grep -q "+ \[D\] del.txt" && \
       echo "$out" | grep -q "+ \[R\] ren.txt -> renamed.txt" && \
       echo "$out" | grep -q "\* \[D\] un_del.txt"; then
        pass "6. Deleted and renamed files correctly formatted"
    else
        fail "6. Deleted and renamed files" "Status: $status, Output: $out"
    fi
    cd "$ORIG_PWD"
}
test_deleted_and_renamed

# -----------------------------------------------------------------------------
# Test 7: Empty repository with no commits
# -----------------------------------------------------------------------------
test_empty_repo() {
    local repo
    repo="$(make_repo "test7_empty_repo")"
    cd "$repo"

    local out status=0
    out="$("$GITBRIEF" --no-color 2>&1)" || status=$?

    if [ "$status" -eq 0 ] && \
       echo "$out" | grep -q "(No commits yet - fresh repository)" && \
       echo "$out" | grep -q "Working Tree Status:"; then
        pass "7. Empty repository with no commits exits 0 and prints notice"
    else
        fail "7. Empty repository with no commits" "Status: $status, Output: $out"
    fi
    cd "$ORIG_PWD"
}
test_empty_repo

# -----------------------------------------------------------------------------
# Test 8: Detached HEAD state
# -----------------------------------------------------------------------------
test_detached_head() {
    local repo
    repo="$(make_repo "test8_detached")"
    cd "$repo"
    echo "1" > f.txt; git add f.txt; git commit -qm "commit 1"
    echo "2" > f.txt; git add f.txt; git commit -qm "commit 2"
    local first_hash
    first_hash="$(git rev-parse --short HEAD~1)"

    git checkout -q HEAD~1 2>/dev/null

    local out status=0
    out="$("$GITBRIEF" --no-color 2>&1)" || status=$?

    if [ "$status" -eq 0 ] && \
       echo "$out" | grep -q "Branch:     (detached at $first_hash)"; then
        pass "8. Detached HEAD detected and displays commit hash"
    else
        fail "8. Detached HEAD state" "Status: $status, Output: $out"
    fi
    cd "$ORIG_PWD"
}
test_detached_head

# -----------------------------------------------------------------------------
# Test 9: Non-Git directory
# -----------------------------------------------------------------------------
test_non_git() {
    local non_git="$TEST_TMPDIR/not_a_repo"
    mkdir -p "$non_git"
    cd "$non_git"

    local err_out="" status=0
    err_out="$("$GITBRIEF" 2>&1 >/dev/null)" || status=$?

    if [ "$status" -eq 1 ] && \
       echo "$err_out" | grep -q "gitbrief: error: not a git repository (or any parent up to mount point)"; then
        pass "9. Non-Git directory exits 1 and emits specified error"
    else
        fail "9. Non-Git directory" "Status: $status, Stderr: $err_out"
    fi
    cd "$ORIG_PWD"
}
test_non_git

# -----------------------------------------------------------------------------
# Test 10: Invalid flags and invalid --count values
# -----------------------------------------------------------------------------
test_invalid_args() {
    local repo
    repo="$(make_repo "test10_invalid_flags")"
    cd "$repo"

    # 10a: Unrecognized option
    local err_unknown="" status_unknown=0
    err_unknown="$("$GITBRIEF" --nonsense 2>&1 >/dev/null)" || status_unknown=$?

    # 10b: Invalid non-integer count
    local err_count="" status_count=0
    err_count="$("$GITBRIEF" -c abc 2>&1 >/dev/null)" || status_count=$?

    # 10c: Missing count argument
    local err_missing="" status_missing=0
    err_missing="$("$GITBRIEF" -c 2>&1 >/dev/null)" || status_missing=$?

    # 10d: Negative count argument
    local err_neg="" status_neg=0
    err_neg="$("$GITBRIEF" -c -2 2>&1 >/dev/null)" || status_neg=$?

    if [ "$status_unknown" -eq 2 ] && echo "$err_unknown" | grep -q "unrecognized option '--nonsense'" && \
       [ "$status_count" -eq 2 ] && echo "$err_count" | grep -q "requires a valid integer argument" && \
       [ "$status_missing" -eq 2 ] && echo "$err_missing" | grep -q "Usage: gitbrief \[options\]" && \
       [ "$status_neg" -eq 2 ]; then
        pass "10. Invalid flags and invalid --count values exit 2 with synopsis"
    else
        fail "10. Invalid flags and invalid --count values" "Statuses: $status_unknown, $status_count, $status_missing, $status_neg"
    fi
    cd "$ORIG_PWD"
}
test_invalid_args

# -----------------------------------------------------------------------------
# Test 11: Commit history formatting and configurable count
# -----------------------------------------------------------------------------
test_commits_formatting() {
    local repo
    repo="$(make_repo "test11_commits")"
    cd "$repo"
    for i in 1 2 3 4 5; do
        echo "change $i" >> file.txt
        git add file.txt
        git commit -qm "feat: commit $i"
    done

    # Default count is 3
    local out_def
    out_def="$("$GITBRIEF" --no-color)"
    local commits_def
    commits_def="$(echo "$out_def" | grep -c "feat: commit" || true)"

    # Count 1
    local out_1
    out_1="$("$GITBRIEF" -c 1 --no-color)"
    local commits_1
    commits_1="$(echo "$out_1" | grep -c "feat: commit" || true)"

    # Count 5
    local out_5
    out_5="$("$GITBRIEF" --count 5 --no-color)"
    local commits_5
    commits_5="$(echo "$out_5" | grep -c "feat: commit" || true)"

    # Check format: hash (relative time) subject <author>
    local format_match
    format_match="$(echo "$out_1" | grep -E "[0-9a-f]{7} \([^)]+\) feat: commit 5 <Test Runner>" || true)"

    if [ "$commits_def" -eq 3 ] && [ "$commits_1" -eq 1 ] && [ "$commits_5" -eq 5 ] && [ -n "$format_match" ]; then
        pass "11. Commit history formatting and configurable -c/--count"
    else
        fail "11. Commit history formatting and count" "Counts: def=$commits_def, 1=$commits_1, 5=$commits_5"
    fi
    cd "$ORIG_PWD"
}
test_commits_formatting

# -----------------------------------------------------------------------------
# Test 12: Short mode
# -----------------------------------------------------------------------------
test_short_mode() {
    local repo
    repo="$(make_repo "test12_short")"
    cd "$repo"
    echo "tracked" > f1.txt; git add f1.txt; git commit -qm "init"
    echo "mod" >> f1.txt
    echo "staged" > f2.txt; git add f2.txt
    echo "untracked" > f3.txt

    local out_short status=0
    out_short="$("$GITBRIEF" -s --no-color 2>&1)" || status=$?

    local has_counts=0
    if echo "$out_short" | grep -q "Staged changes:   1" && \
       echo "$out_short" | grep -q "Unstaged changes: 1" && \
       echo "$out_short" | grep -q "Untracked files:  1"; then
        has_counts=1
    fi

    local has_individual_files=0
    if echo "$out_short" | grep -E "^\s+(\+|\*|\?)" >/dev/null; then
        has_individual_files=1
    fi

    if [ "$status" -eq 0 ] && [ "$has_counts" -eq 1 ] && [ "$has_individual_files" -eq 0 ]; then
        pass "12. Short mode (-s / --short) suppresses individual file paths"
    else
        fail "12. Short mode" "Status: $status, HasCounts: $has_counts, HasIndividual: $has_individual_files"
    fi
    cd "$ORIG_PWD"
}
test_short_mode

# -----------------------------------------------------------------------------
# Test 13: Color suppression and piped output
# -----------------------------------------------------------------------------
test_color_suppression() {
    local repo
    repo="$(make_repo "test13_colors")"
    cd "$repo"
    echo "data" > data.txt; git add data.txt; git commit -qm "init"

    local out_flag
    out_flag="$("$GITBRIEF" --no-color)"
    local out_pipe
    out_pipe="$("$GITBRIEF" | cat)"
    local out_env
    out_env="$(NO_COLOR=1 "$GITBRIEF" | cat)"

    local esc
    esc="$(printf '\033')"
    local has_esc_flag=0
    if [[ "$out_flag" == *"$esc"* ]]; then has_esc_flag=1; fi

    local has_esc_pipe=0
    if [[ "$out_pipe" == *"$esc"* ]]; then has_esc_pipe=1; fi

    local has_esc_env=0
    if [[ "$out_env" == *"$esc"* ]]; then has_esc_env=1; fi

    if [ "$has_esc_flag" -eq 0 ] && [ "$has_esc_pipe" -eq 0 ] && [ "$has_esc_env" -eq 0 ]; then
        pass "13. Color suppression on --no-color, non-TTY piped output, and NO_COLOR"
    else
        fail "13. Color suppression" "EscFlag: $has_esc_flag, EscPipe: $has_esc_pipe, EscEnv: $has_esc_env"
    fi
    cd "$ORIG_PWD"
}
test_color_suppression

# -----------------------------------------------------------------------------
# Test 14: Upstream status
# -----------------------------------------------------------------------------
test_upstream_status() {
    local remote_dir="$TEST_TMPDIR/test14_remote.git"
    git init --bare -q "$remote_dir"

    local repo
    repo="$(make_repo "test14_upstream")"
    cd "$repo"
    echo "init" > file.txt; git add file.txt; git commit -qm "init"
    git remote add origin "$remote_dir"
    git push -u origin main >/dev/null 2>&1

    # 14a: Up to date
    local out_sync
    out_sync="$("$GITBRIEF" --no-color)"
    local sync_ok=0
    if echo "$out_sync" | grep -q "\[up to date with origin/main\]"; then
        sync_ok=1
    fi

    # 14b: Ahead
    echo "ahead 1" >> file.txt; git commit -qam "local 1"
    echo "ahead 2" >> file.txt; git commit -qam "local 2"
    local out_ahead
    out_ahead="$("$GITBRIEF" --no-color)"
    local ahead_ok=0
    if echo "$out_ahead" | grep -q "\[ahead 2 vs origin/main\]"; then
        ahead_ok=1
    fi

    if [ "$sync_ok" -eq 1 ] && [ "$ahead_ok" -eq 1 ]; then
        pass "14. Upstream tracking status (up to date and ahead detection)"
    else
        fail "14. Upstream status" "SyncOK: $sync_ok, AheadOK: $ahead_ok, OutSync: $out_sync, OutAhead: $out_ahead"
    fi
    cd "$ORIG_PWD"
}
test_upstream_status

# -----------------------------------------------------------------------------
# Test 15: Stash counting
# -----------------------------------------------------------------------------
test_stash_counting() {
    local repo
    repo="$(make_repo "test15_stash")"
    cd "$repo"
    echo "v1" > file.txt; git add file.txt; git commit -qm "base"

    echo "v2" > file.txt
    git stash push -qm "stash 1" >/dev/null 2>&1
    local out_1
    out_1="$("$GITBRIEF" --no-color)"
    local stash_1_ok=0
    if echo "$out_1" | grep -q "Stashes:    1 stashed state(s)"; then
        stash_1_ok=1
    fi

    echo "v3" > file.txt
    git stash push -qm "stash 2" >/dev/null 2>&1
    local out_2
    out_2="$("$GITBRIEF" --no-color)"
    local stash_2_ok=0
    if echo "$out_2" | grep -q "Stashes:    2 stashed state(s)"; then
        stash_2_ok=1
    fi

    if [ "$stash_1_ok" -eq 1 ] && [ "$stash_2_ok" -eq 1 ]; then
        pass "15. Stash counting correctly reflects stashed states"
    else
        fail "15. Stash counting" "1: $stash_1_ok, 2: $stash_2_ok"
    fi
    cd "$ORIG_PWD"
}
test_stash_counting

# -----------------------------------------------------------------------------
# Test 16: Merge, rebase, and cherry-pick operation-state detection
# -----------------------------------------------------------------------------
test_operation_detection() {
    local repo
    repo="$(make_repo "test16_operations")"
    cd "$repo"
    echo "line 1 base" > op.txt; git add op.txt; git commit -qm "base"

    # Branch feat
    git checkout -qb feat 2>/dev/null
    echo "line 1 feat" > op.txt; git commit -qam "feat commit"

    # Branch main
    git checkout -q main
    echo "line 1 main" > op.txt; git commit -qam "main commit"

    # 16a: Merge conflict
    git merge feat >/dev/null 2>&1 || true
    local out_merge
    out_merge="$("$GITBRIEF" --no-color)"
    local merge_ok=0
    if echo "$out_merge" | grep -q "\[Merge in progress\]"; then
        merge_ok=1
    fi
    git merge --abort >/dev/null 2>&1 || true

    # 16b: Cherry-pick conflict
    git checkout -q feat
    git cherry-pick main >/dev/null 2>&1 || true
    local out_cp
    out_cp="$("$GITBRIEF" --no-color)"
    local cp_ok=0
    if echo "$out_cp" | grep -q "\[Cherry-pick in progress\]"; then
        cp_ok=1
    fi
    git cherry-pick --abort >/dev/null 2>&1 || true

    # 16c: Rebase conflict
    git checkout -q feat
    git rebase main >/dev/null 2>&1 || true
    local out_rebase
    out_rebase="$("$GITBRIEF" --no-color)"
    local rebase_ok=0
    if echo "$out_rebase" | grep -q "\[Rebase in progress\]"; then
        rebase_ok=1
    fi
    git rebase --abort >/dev/null 2>&1 || true

    if [ "$merge_ok" -eq 1 ] && [ "$cp_ok" -eq 1 ] && [ "$rebase_ok" -eq 1 ]; then
        pass "16. In-progress operation detection (merge, cherry-pick, rebase)"
    else
        fail "16. Operation-state detection" "Merge: $merge_ok, CherryPick: $cp_ok, Rebase: $rebase_ok"
    fi
    cd "$ORIG_PWD"
}
test_operation_detection

# -----------------------------------------------------------------------------
# Test 17: Read-only guarantee
# -----------------------------------------------------------------------------
test_readonly_guarantee() {
    local repo
    repo="$(make_repo "test17_readonly")"
    cd "$repo"
    echo "v1" > f1.txt; git add f1.txt; git commit -qm "base"
    echo "mod" >> f1.txt
    echo "staged" > f2.txt; git add f2.txt
    echo "untracked" > f3.txt

    # Snapshot state before gitbrief
    local status_before head_before diff_before diff_cached_before
    status_before="$(git status --porcelain)"
    head_before="$(git rev-parse HEAD)"
    diff_before="$(git diff)"
    diff_cached_before="$(git diff --cached)"

    # Execute gitbrief multiple times with diverse flags
    "$GITBRIEF" >/dev/null 2>&1
    "$GITBRIEF" -s >/dev/null 2>&1
    "$GITBRIEF" -c 10 --no-color >/dev/null 2>&1

    # Snapshot state after gitbrief
    local status_after head_after diff_after diff_cached_after
    status_after="$(git status --porcelain)"
    head_after="$(git rev-parse HEAD)"
    diff_after="$(git diff)"
    diff_cached_after="$(git diff --cached)"

    if [ "$status_before" = "$status_after" ] && \
       [ "$head_before" = "$head_after" ] && \
       [ "$diff_before" = "$diff_after" ] && \
       [ "$diff_cached_before" = "$diff_cached_after" ]; then
        pass "17. Read-only guarantee: zero modifications to repository state"
    else
        fail "17. Read-only guarantee" "Repository state altered during execution"
    fi
    cd "$ORIG_PWD"
}
test_readonly_guarantee

# -----------------------------------------------------------------------------
# Test 18: Invocation from nested directory
# -----------------------------------------------------------------------------
test_nested_invocation() {
    local repo
    repo="$(make_repo "test18_nested")"
    cd "$repo"
    mkdir -p deep/nested/dir
    echo "root file" > root.txt
    echo "nested file" > deep/nested/dir/nested.txt
    git add .
    git commit -qm "initial commit"

    echo "mod root" >> root.txt
    echo "mod nested" >> deep/nested/dir/nested.txt
    echo "untracked root" > untracked_root.txt
    echo "untracked nested" > deep/nested/dir/untracked_nested.txt

    cd deep/nested/dir
    local out_nested status=0
    out_nested="$("$GITBRIEF" --no-color 2>&1)" || status=$?

    if [ "$status" -eq 0 ] && \
       echo "$out_nested" | grep -q "root.txt" && \
       echo "$out_nested" | grep -q "deep/nested/dir/nested.txt" && \
       echo "$out_nested" | grep -q "untracked_root.txt" && \
       echo "$out_nested" | grep -q "deep/nested/dir/untracked_nested.txt"; then
        pass "18. Nested directory invocation discovers full repository state"
    else
        fail "18. Nested directory invocation" "Status: $status, Output: $out_nested"
    fi
    cd "$ORIG_PWD"
}
test_nested_invocation

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
printf "\n${C_BOLD}Test Summary:${C_RESET} %d ran, ${C_GREEN}%d passed${C_RESET}, ${C_RED}%d failed${C_RESET}\n" \
    "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"

if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
fi
exit 0
