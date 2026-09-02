#!/usr/bin/env bash
# orchestrate-codex preflight (project-agnostic). Usage: bash preflight.sh <repo_or_worktree>
# Reads <repo>/.codex-orchestrate.env: SUBMODULES, REQUIRED_ENV, SCHEDULER, MAX_MULTINODE_JOBS
set -u
R="${1:?repo path}"
CFG="$R/.codex-orchestrate.env"; [ -f "$CFG" ] && source "$CFG" || echo "NOTE: no $CFG (submodule/env checks skipped)"
echo "== git"; git -C "$R" status --porcelain | head -5; git -C "$R" branch --show-current
for sub in ${SUBMODULES:-}; do
  echo "== submodule $sub"; git -C "$R" ls-tree HEAD "$sub" 2>/dev/null || echo "WARN: no gitlink for $sub at HEAD"
  [ -n "$(ls -A "$R/$sub" 2>/dev/null)" ] || echo "WARN: $sub checkout missing/empty in this tree — export its root path explicitly"
done
echo "== env"; for v in ${REQUIRED_ENV:-}; do [ -n "${!v:-}" ] && echo "$v=${!v}" || echo "WARN: $v unset"; done
if [ "${SCHEDULER:-none}" = "slurm" ]; then
  n=$(squeue -u "$USER" -h -o "%D" 2>/dev/null | awk '$1>1' | wc -l)
  echo "== multi-node jobs running/pending: $n (limit ${MAX_MULTINODE_JOBS:-?})"; squeue -u "$USER" -h -o "%D %j %T" 2>/dev/null | awk '$1>1' | sort -rn | head
  command -v lfs >/dev/null && { echo "== quota"; lfs quota -hu "$USER" "$HOME" 2>/dev/null | sed -n '3p'; }
fi
