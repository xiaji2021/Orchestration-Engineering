#!/usr/bin/env bash
# Uniform launcher for a worker backend: start or resume, capture the handle, keep artifacts.
# Usage: run_worker.sh <backend> <worktree> <brief-file> [--resume <handle>] [--out <dir>]
#   backend: codex | claude | gemini | aider
# Artifacts (default <worktree>/.orchestrate-runs/<timestamp>/, add it to .git/info/exclude):
#   handle.txt  session/thread id (empty for aider)    report.md  worker's final message
#   events.log  raw stream/stdout                       exit.txt   exit code
# Run it in the background for long work; read handle.txt the moment it appears.
# Status: codex = verified end-to-end (start + resume, codex-cli 0.159.0); claude/gemini/aider =
# built from vendor docs, NOT yet run here — see BACKENDS.md. Flags drift: check <tool> --help.
set -u
B="${1:?backend}"; W="${2:?worktree}"; F="${3:?brief file}"; shift 3
RES=""; OUT=""
while [ $# -gt 0 ]; do case "$1" in
  --resume) RES="$2"; shift 2;; --out) OUT="$2"; shift 2;;
  *) echo "unknown arg $1" >&2; exit 2;; esac; done
W="$(cd "$W" && pwd)"; F="$(cd "$(dirname "$F")" && pwd)/$(basename "$F")"
OUT="${OUT:-$W/.orchestrate-runs/$(date +%Y%m%d-%H%M%S)}"; mkdir -p "$OUT"; cd "$W" || exit 1
SB="${WORKER_SANDBOX:-workspace-write}"
echo "out: $OUT"

case "$B" in
codex)
  # NB: `exec resume` has no -s/-C flags; it reuses the session's cwd/sandbox unless overridden with -c.
  if [ -n "$RES" ]; then
    codex exec resume "$RES" --json -o "$OUT/report.md" - < "$F" > "$OUT/events.log" 2>"$OUT/stderr.log" &
  else
    codex exec -C "$W" -s "$SB" --json -o "$OUT/report.md" - < "$F" > "$OUT/events.log" 2>"$OUT/stderr.log" &
  fi
  PID=$!
  # thread id is the first event; publish it immediately
  for _ in $(seq 1 60); do
    H="$(grep -m1 '"thread.started"' "$OUT/events.log" 2>/dev/null | sed -E 's/.*"thread_id":"([^"]+)".*/\1/')"
    [ -n "$H" ] && break; sleep 1
  done
  echo "${H:-$RES}" > "$OUT/handle.txt"; echo "handle: $(cat "$OUT/handle.txt")"
  wait $PID; echo $? > "$OUT/exit.txt";;
claude)
  PERM="${CLAUDE_PERMISSION_MODE:-acceptEdits}"   # never default to bypassPermissions
  ARGS=(-p --output-format json --permission-mode "$PERM" --max-turns "${MAX_TURNS:-60}")
  [ -n "$RES" ] && ARGS+=(--resume "$RES")
  claude "${ARGS[@]}" < "$F" > "$OUT/events.log" 2>"$OUT/stderr.log"; echo $? > "$OUT/exit.txt"
  python3 - "$OUT" <<'PY'
import json,sys,pathlib
o=pathlib.Path(sys.argv[1]);
try:
    d=json.loads((o/"events.log").read_text()); (o/"handle.txt").write_text(d.get("session_id","")); (o/"report.md").write_text(d.get("result",""))
except Exception as e: (o/"handle.txt").write_text("")
PY
  echo "handle: $(cat "$OUT/handle.txt")";;
gemini)
  ARGS=(--output-format json --approval-mode "${GEMINI_APPROVAL:-auto_edit}")
  [ -n "$RES" ] && ARGS+=(--resume "$RES")
  gemini "${ARGS[@]}" -p "$(cat "$F")" > "$OUT/events.log" 2>"$OUT/stderr.log"; echo $? > "$OUT/exit.txt"
  cp "$OUT/events.log" "$OUT/report.md"; : > "$OUT/handle.txt"
  echo "handle: (none captured — resume via --resume per gemini --help; state lives in the repo)";;
aider)
  aider --message-file "$F" --yes --no-auto-commits > "$OUT/events.log" 2>"$OUT/stderr.log"; echo $? > "$OUT/exit.txt"
  cp "$OUT/events.log" "$OUT/report.md"; : > "$OUT/handle.txt"
  echo "handle: none — aider has no session ids; state lives in the repo";;
*) echo "unknown backend: $B (codex|claude|gemini|aider)" >&2; exit 2;;
esac
echo "exit: $(cat "$OUT/exit.txt")"
