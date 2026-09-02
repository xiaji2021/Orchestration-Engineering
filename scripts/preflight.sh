#!/usr/bin/env bash
# orchestrate-delegation preflight — backend-, host- and scheduler-agnostic.
# Usage: bash preflight.sh [repo_or_worktree]   (defaults to the current directory)
#
# Reads <repo>/.orchestrate.env (or the legacy .codex-orchestrate.env) if present.
# Every layer is skipped cleanly when its signal is absent: no config, no submodules,
# no scheduler and no quota command still produce a useful report.
set -u

R="${1:-$PWD}"
[ -d "$R" ] || { echo "ABORT: not a directory: $R"; exit 1; }
R="$(cd "$R" && pwd)"

CFG=""
for c in "$R/.orchestrate.env" "$R/.codex-orchestrate.env"; do
  [ -f "$c" ] && { CFG="$c"; break; }
done
if [ -n "$CFG" ]; then
  # shellcheck disable=SC1090
  . "$CFG"; echo "== config: $CFG"
else
  echo "== config: none (using auto-detection only; see orchestrate.env.example)"
fi

echo "== git"
if git -C "$R" rev-parse --git-dir >/dev/null 2>&1; then
  echo "branch: $(git -C "$R" branch --show-current 2>/dev/null || echo '(detached)')"
  DIRTY="$(git -C "$R" status --porcelain)"
  if [ -n "$DIRTY" ]; then
    echo "PRE-EXISTING uncommitted changes ($(printf '%s\n' "$DIRTY" | wc -l | tr -d ' ') paths) — these MUST survive the delegation:"
    printf '%s\n' "$DIRTY" | head -10
  else
    echo "clean tree"
  fi
  git -C "$R" worktree list 2>/dev/null | sed -n '2,$p' | sed 's/^/other worktree: /'
else
  echo "WARN: not a git repo — no diff-based verification or merge gate available"
fi

# --- submodule layer: only when .gitmodules exists or SUBMODULES is set ---
SUBS="${SUBMODULES:-}"
if [ -z "$SUBS" ] && [ -f "$R/.gitmodules" ]; then
  SUBS="$(git -C "$R" config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null | awk '{print $2}')"
fi
if [ -n "$SUBS" ]; then
  echo "== submodules (gitlink baseline — record these before delegating)"
  for sub in $SUBS; do
    LINE="$(git -C "$R" ls-tree HEAD "$sub" 2>/dev/null)"
    if [ -z "$LINE" ]; then
      echo "WARN: $sub has no gitlink at HEAD"
    else
      MODE="$(printf '%s' "$LINE" | awk '{print $1}')"
      [ "$MODE" = "160000" ] && echo "$LINE" || echo "WARN: $sub mode=$MODE (expected 160000 — expanded into a plain directory?)"
    fi
    [ -n "$(ls -A "$R/$sub" 2>/dev/null)" ] || echo "WARN: $sub is not checked out here — export its root path explicitly in the brief"
  done
fi

# --- required env ---
if [ -n "${REQUIRED_ENV:-}" ]; then
  echo "== required env"
  for v in $REQUIRED_ENV; do
    if [ -n "${!v:-}" ]; then echo "$v=${!v}"; else echo "WARN: $v unset — the worker and any submitted job will inherit this gap"; fi
  done
fi

# --- test command ---
if [ -n "${TEST_CMD:-}" ]; then
  echo "== acceptance command: $TEST_CMD"
else
  echo "NOTE: TEST_CMD unset — decide the acceptance command before writing the brief, not after the report"
fi

# --- scheduler layer: only when configured or a scheduler binary exists ---
SCHED="${SCHED_LIST_CMD:-}"
if [ -z "$SCHED" ]; then
  if   command -v squeue >/dev/null 2>&1; then SCHED='squeue -u $USER -h -o "%D %j %T"'
  elif command -v qstat  >/dev/null 2>&1; then SCHED='qstat -u $USER'
  elif command -v bjobs  >/dev/null 2>&1; then SCHED='bjobs -u $USER -noheader -o "min_req_proc job_name stat"'
  fi
  [ -n "$SCHED" ] && echo "NOTE: scheduler detected, using default listing (set SCHED_LIST_CMD to override)"
fi
if [ -n "$SCHED" ]; then
  echo "== scheduler"
  OUT="$(bash -c "$SCHED" 2>/dev/null)"
  if [ -z "$OUT" ]; then
    echo "WARN: empty listing — treat as flakiness and retry; NEVER read it as 'nothing running'"
  else
    BIG="$(printf '%s\n' "$OUT" | awk '$1>1' | wc -l | tr -d ' ')"
    echo "big jobs (nodes>1): $BIG / limit ${MAX_BIG_JOBS:-?}   |   total lines: $(printf '%s\n' "$OUT" | wc -l | tr -d ' ')"
    printf '%s\n' "$OUT" | awk '$1>1' | sort -rn | head -5
    [ "$BIG" -ge "${MAX_BIG_JOBS:-1}" ] 2>/dev/null && echo "WARN: budget already spent — the brief must say 'submit no new big jobs'"
    printf '%s\n' "$OUT" | awk '{print $2}' | sort | uniq -d | sed 's/^/WARN: duplicate job name: /'
  fi
  [ -n "${EXTRA_SUBMIT_ARGS:-}" ] && echo "always append to submits: $EXTRA_SUBMIT_ARGS"
fi

# --- quota ---
if [ -n "${QUOTA_CMD:-}" ]; then
  echo "== quota"; bash -c "$QUOTA_CMD" 2>/dev/null | tail -3
fi

echo "== preflight done — carry the WARN lines into the brief as explicit constraints"
