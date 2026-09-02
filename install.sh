#!/usr/bin/env bash
# 安装 orchestrate-codex skill 到当前用户的 Claude Code。
# 用法: bash install.sh --mcp-name codex-<you> --codex-home ~/.codex_<you> --shared-user <you> [--codex-bin ~/.local/bin/codex] [--iam-cmd "iam <you>"] [--skills-dir ~/.claude/skills]
set -euo pipefail
MCP_NAME=""; CODEX_HOME=""; SHARED_USER=""; CODEX_BIN="$HOME/.local/bin/codex"; IAM_CMD=""; SKILLS_DIR="$HOME/.claude/skills"
while [ $# -gt 0 ]; do case "$1" in
  --mcp-name) MCP_NAME="$2"; shift 2;; --codex-home) CODEX_HOME="$2"; shift 2;; --shared-user) SHARED_USER="$2"; shift 2;;
  --codex-bin) CODEX_BIN="$2"; shift 2;; --iam-cmd) IAM_CMD="$2"; shift 2;; --skills-dir) SKILLS_DIR="$2"; shift 2;;
  *) echo "unknown arg $1"; exit 1;; esac; done
[ -n "$MCP_NAME" ] && [ -n "$CODEX_HOME" ] && [ -n "$SHARED_USER" ] || { echo "need --mcp-name --codex-home --shared-user"; exit 1; }
[ -n "$IAM_CMD" ] || IAM_CMD="# (no identity switch needed)"
D="$SKILLS_DIR/orchestrate-codex"; mkdir -p "$D/scripts"
HERE="$(cd "$(dirname "$0")" && pwd)"
sed -e "s#{{MCP_NAME}}#$MCP_NAME#g" -e "s#{{CODEX_HOME}}#$CODEX_HOME#g" -e "s#{{SHARED_USER}}#$SHARED_USER#g" -e "s#{{CODEX_BIN}}#$CODEX_BIN#g" -e "s#{{IAM_CMD}}#$IAM_CMD#g" "$HERE/SKILL.md.tmpl" > "$D/SKILL.md"
cp "$HERE/DELEGATION_TEMPLATE.md" "$D/"; cp "$HERE/scripts/preflight.sh" "$D/scripts/"; chmod +x "$D/scripts/preflight.sh"
echo "installed to $D"; echo "next: claude mcp add --scope user $MCP_NAME -e CODEX_HOME=$CODEX_HOME -e SHARED_USER=$SHARED_USER -- $CODEX_BIN mcp-server"
echo "then copy codex-orchestrate.env.example to your repo as .codex-orchestrate.env"
