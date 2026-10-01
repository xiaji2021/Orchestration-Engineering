#!/usr/bin/env bash
# Install the orchestrate-delegation skill.
#   bash install.sh                      # -> ~/.claude/skills/orchestrate-delegation
#   bash install.sh --skills-dir <dir>   # e.g. <repo>/.claude/skills for a project-scoped install
#   bash install.sh --link               # symlink instead of copy (track this repo's updates)
# No placeholders, no MCP name, no host config: the skill discovers all of that at runtime.
set -euo pipefail
SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"; LINK=0
while [ $# -gt 0 ]; do case "$1" in
  --skills-dir) SKILLS_DIR="$2"; shift 2;;
  --link) LINK=1; shift;;
  -h|--help) sed -n '2,6p' "$0"; exit 0;;
  *) echo "unknown arg: $1" >&2; exit 1;;
esac; done

HERE="$(cd "$(dirname "$0")" && pwd)"
D="$SKILLS_DIR/orchestrate-delegation"
mkdir -p "$SKILLS_DIR"

if [ "$LINK" = 1 ]; then
  rm -rf "$D"; ln -s "$HERE" "$D"; echo "linked $D -> $HERE"
else
  mkdir -p "$D/scripts"
  cp "$HERE/SKILL.md" "$HERE/DELEGATION_TEMPLATE.md" "$HERE/BACKENDS.md" "$D/"
  cp "$HERE/scripts/preflight.sh" "$HERE/scripts/run_worker.sh" "$D/scripts/"; chmod +x "$D/scripts/"*.sh
  echo "installed to $D"
fi

cat <<'NEXT'

Next (all optional):
  1. Per project: cp orchestrate.env.example <repo>/.orchestrate.env and fill in what applies.
     Nothing set is a valid state — the skill auto-detects submodules and schedulers.
  2. Sanity check:  bash scripts/preflight.sh <repo>
  3. Workers need no registration: `codex exec`, `claude -p`, Gemini CLI, aider, or a Claude Code
     subagent are used directly. (`codex mcp-server` was removed upstream in v0.154.0 — if you
     registered one, drop it:  claude mcp remove <mcp-name>)
NEXT
