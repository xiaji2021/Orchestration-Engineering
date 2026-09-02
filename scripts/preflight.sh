#!/usr/bin/env bash
# orchestrate-codex preflight (host-agnostic). Usage: bash preflight.sh <repo_or_worktree>
# Reads <repo>/.codex-orchestrate.env: SUBMODULES REQUIRED_ENV SCHED_LIST_CMD MAX_BIG_JOBS QUOTA_CMD
set -u
R="${1:?repo path}"; CFG="$R/.codex-orchestrate.env"
[ -f "$CFG" ] && source "$CFG" || echo "NOTE: no $CFG (project checks skipped)"
echo "== git"; git -C "$R" status --porcelain | head -5; git -C "$R" branch --show-current
for sub in ${SUBMODULES:-}; do
  echo "== submodule $sub"; git -C "$R" ls-tree HEAD "$sub" 2>/dev/null || echo "WARN: no gitlink for $sub at HEAD"
  [ -n "$(ls -A "$R/$sub" 2>/dev/null)" ] || echo "WARN: $sub checkout missing/empty here — export its root path explicitly"
done
echo "== env"; for v in ${REQUIRED_ENV:-}; do [ -n "${!v:-}" ] && echo "$v=${!v}" || echo "WARN: $v unset"; done
if [ -n "${SCHED_LIST_CMD:-}" ]; then
  big=$(bash -c "$SCHED_LIST_CMD" 2>/dev/null | awk '$1>1' | wc -l)
  echo "== big jobs (nodes>1) running/pending: $big (limit ${MAX_BIG_JOBS:-?})"; bash -c "$SCHED_LIST_CMD" 2>/dev/null | awk '$1>1' | sort -rn | head
fi
[ -n "${QUOTA_CMD:-}" ] && { echo "== quota"; bash -c "$QUOTA_CMD" 2>/dev/null | tail -2; }
