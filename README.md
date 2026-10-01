# orchestrate-delegation

A skill for Claude Code (and any agent host that reads `SKILL.md`) that turns *handing work to
another agent* into a disciplined loop: **plan → time-boxed brief → fixed report contract →
independent verification → gated merge**. The orchestrator never accepts a worker's word for
anything it has not checked itself.

> 中文一句话：让 Claude 当编排者、把实现工作委派出去，同时守住时间盒、资源预算、验证与合并门禁 ——
> 口头汇报一律不算数。

It grew out of running multi-agent work on an HPC cluster, then had every site-specific name
removed. What is left is the mechanism, and it degrades gracefully: on a laptop repo with no
config file at all it still enforces the parts that matter.

## Why bother

Delegation fails in a small number of repeatable ways, and each rule here exists because one of
them cost real work:

| Failure | Rule |
|---|---|
| A hard timeout swallows the session and its final report | one delegation = one milestone inside ⅔ of the limit; journal each milestone as it lands |
| The worker sits and babysits a queued job until the clock runs out | long work is *launched and handed back as a handle*, never watched |
| A merge silently deletes submodule gitlinks; an `&&` chain makes the guard a no-op | structural invariants asserted as hard, non-chained checks |
| A temporary worktree lacks submodules, a path var is unexported, a whole batch fails at import | preflight records the baseline; the brief exports paths explicitly |
| Two sessions submit the same job, or edit the same file | one thread per task; worktrees or written file ownership |
| A shared concurrency cap is breached because nobody told the worker the number | the remaining budget goes into the brief as a number |
| A status endpoint returns empty and a monitor calls the job "done" | empty output is flakiness, never completion |
| The report says the tests pass | rerun them yourself; spot-check one raw output, not the summary table |

## Works with any worker

The skill defines what a worker backend must expose — how to start it, whether a thread can be
resumed, its hard wall-clock limit — and adapts. `codex exec` / `codex exec resume` (or the Codex app server when you need `turn/interrupt`) is the
recommended Codex path; a Claude Code subagent or `claude -p`, Gemini CLI, aider, any CLI agent in a
worktree, or an MCP coding server are equally valid. Nothing in `SKILL.md` names a host, a cluster, a project, or an MCP server.

## Install

```bash
git clone https://github.com/xiaji2021/orchestration-engineering.git
cd orchestration-engineering
bash install.sh                          # -> ~/.claude/skills/orchestrate-delegation
# bash install.sh --skills-dir <repo>/.claude/skills   # project-scoped
# bash install.sh --link                               # symlink, to track updates
```

Optional, per project:

```bash
cp orchestrate.env.example <repo>/.orchestrate.env    # then fill in what applies — all fields optional
bash scripts/preflight.sh <repo>                      # sanity check before delegating
```

No MCP registration is needed any more. **Update note (2026-10):** OpenAI removed `codex mcp-server`
in Codex v0.154.0, so the old `codex` / `codex-reply` MCP setup no longer works — if you have one
registered, run `claude mcp remove <mcp-name>`. The skill now drives Codex through `codex exec` /
`codex exec resume` (session ids persist on disk, so a killed run is resumable) or `codex app-server`.

## Contents

| File | Purpose |
|---|---|
| `SKILL.md` | the skill itself — mechanism only, zero site-specific names |
| `DELEGATION_TEMPLATE.md` | the brief template; send only when every field is filled |
| `BACKENDS.md` | per-backend start / handle / resume / interrupt, marked verified vs docs-only |
| `scripts/run_worker.sh` | uniform launcher (codex, claude, gemini, aider): captures the handle, report and exit code |
| `scripts/preflight.sh` | pre-delegation check: baseline, submodule gitlinks, env, scheduler load, quota |
| `orchestrate.env.example` | optional per-project config; every field may be left empty |

## Configuration is optional, and layered

`.orchestrate.env` sharpens the skill but is never required. Layers activate only on their own
signal: `.gitmodules` turns on the gitlink gate, `sbatch`/`qstat`/`bjobs` (or `SCHED_LIST_CMD`)
turns on the scheduler layer, a lockfile turns on the lockfile invariant. A laptop repo sees
nothing about clusters.

## Branches

`main` is the general version and the one to use. `cluster-cscc` is the historical
MBZUAI-CSCC-specific variant, kept for reference — its Slurm, Lustre-quota and bad-node
specifics are now expressible as a few lines of `.orchestrate.env`.
