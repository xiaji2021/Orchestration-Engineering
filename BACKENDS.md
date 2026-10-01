# Worker backend cookbook

Checked 2026-10-02. **Verified** = run end-to-end on this machine; **Docs** = built from the vendor's
current docs, not yet run here. Flags drift — `<tool> --help` wins over this file.
`scripts/run_worker.sh <backend> <worktree> <brief> [--resume <handle>]` wraps all of these.

| Backend | Status | Start | Handle | Resume | Mid-run interrupt |
|---|---|---|---|---|---|
| Codex `exec` | **Verified** (codex-cli 0.159.0) | `codex exec -C <dir> -s workspace-write --json -o report.md - < brief.md` | first JSONL event `{"type":"thread.started","thread_id":…}` | `codex exec resume <thread_id> --json -o r.md - < followup.md` (context retained — tested) | no (use app-server) |
| Codex app-server | Docs (experimental) | JSON-RPC over stdio: `thread/start`, `turn/start` | thread id (persisted JSONL) | `thread/resume` | `turn/interrupt` |
| Claude Code headless | Docs | `claude -p --output-format json --permission-mode acceptEdits --max-turns N < brief.md` | `session_id` in the JSON result | `claude -p --resume <session_id>` | no; `claude --bg` + `claude stop <id>` for background sessions |
| Claude Code subagent | in-session | `Agent` tool | agent id | `SendMessage` | no |
| Gemini CLI | Docs | `gemini -p "<brief>" --output-format json --approval-mode auto_edit` | not captured by the wrapper | `--resume` (see `--help`) | no |
| aider | Docs | `aider --message-file brief.md --yes --no-auto-commits` | none — state is the repo | re-invoke with prior state in the brief | no |
| `codex mcp-server` | **Removed** in v0.154.0 | — | — | — | — |

## Codex gotchas (observed)
- `codex exec resume` accepts `--json`, `-o`, `--skip-git-repo-check` but **not** `-s` / `-C`: it reuses the
  session's original cwd and sandbox. Start the thread with the sandbox you want.
- `codex exec` without a trailing `-` reads the prompt from argv; with `-` it reads stdin. Briefs belong in a file.
- The thread id is emitted immediately, before any work — publish it to the notes file at once.
- A resumed thread remembers prior turns (verified: it named the file it created earlier).
- `--ephemeral` disables persistence → no resume. Never use it for delegated work.
- Add `.orchestrate-runs/` to `.git/info/exclude` so run artifacts never enter a diff.

## Claude Code gotchas (from docs)
- Default `-p` permission behavior is not "allow everything"; pass `--permission-mode` explicitly. Prefer
  `acceptEdits` + `--allowedTools` over `bypassPermissions`. `--permission-prompts none` makes unanswerable prompts deny.
- `--max-turns` and `--max-budget-usd` are the headless equivalents of a timebox — set both.
- `--bare` skips CLAUDE.md/hooks/MCP discovery: faster, but the worker then misses project rules; put them in the brief.
- `-p` sessions are skipped by plain `--continue`; resume by explicit id.

## Adding another backend
Fill the same four cells — start, handle, resume, interrupt — then the hard limit. If you cannot fill
"handle" or "resume", treat the worker as one-shot: smaller milestones, state committed to the repo.
