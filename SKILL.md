---
name: orchestrate-delegation
description: Delegate implementation, debugging, refactoring, or experiment work to a worker agent (Codex MCP, a Claude Code subagent, another CLI or MCP coding agent) while you stay the orchestrator — planning, resource budgets, a fixed report contract, independent verification, and a gated merge. Use when the user asks to hand coding or experiment work to another agent, to run long or expensive work in the background, or to coordinate parallel agent sessions on one repo or cluster.
---

# Orchestrate Delegation

You are the **orchestrator**: plan, budget, verify, gate the merge. The **worker** implements.
**Never accept a worker's report you have not checked against the diff, the acceptance criteria, and a rerun test.**
> 中文要点：口头汇报一律不算数 —— 必须自己看 diff、自己跑测试、自己核实作业是否真的存在。

This file is **mechanism only**. Project specifics (submodules, required env vars, scheduler, resource caps, test command) are discovered at runtime (§1). Never hardcode a project, host, or site name here — that is what makes this reusable.

## 0. Pick a worker, then learn its three limits

Before delegating, establish for the backend you will use: **(a) hard wall-clock limit, (b) whether you can resume the same thread, (c) whether you can interrupt or add instructions mid-run.**

| Backend | start | resume | typical limits |
|---|---|---|---|
| Codex MCP | `codex(cwd, prompt, sandbox/approval)` → save `threadId` | `codex-reply(threadId, evidence)` | ~3h hard timeout; **on timeout the result and threadId are both lost**; no mid-run interrupt |
| Claude Code subagent | `Agent`/`Task` tool | new agent, or `SendMessage` where supported | context-bound rather than clock-bound; no mid-run steering |
| CLI agent (aider, gemini-cli, codex exec, …) | shell command in a worktree | re-invoke with prior state in the prompt | shell/session timeout; state lives in the repo, not the tool |
| Another MCP coding server | its start tool | its continuation tool, if any | read the tool description before trusting either |

If (b) or (c) is unavailable or unknown, assume the worst: no resume, no interrupt.

**Rules that follow from the limits — these are the heart of the skill:**
- **One delegation = one milestone completable in ≲⅔ of the hard limit** (≤2h against a 3h cap). Anything larger gets split.
- **Progress must survive the process dying.** The worker commits in small steps and writes each milestone into the project notes file *as it happens*, so a timeout costs the report, never the work.
- **Never let a worker sit and watch.** Long runs (queued jobs, training, CI, long test suites) are *launched and handed back as a handle* — implementation → targeted test → submit/start → record handle → return. Analysis of results happens in a later delegation, or by you.

## 1. Preflight (you run this, before writing the brief)

1. **Backend reachable.** Confirm the worker exists — for an MCP backend, that its server is connected (e.g. `claude mcp list`); for a subagent, that the agent type exists. If not, stop and give the user the exact one-line fix rather than silently falling back to doing the work yourself.
2. **Load project config**, in this order — the skill works with none of it, and gets sharper with each layer present:
   - `.orchestrate.env` in the repo root (also accept `.codex-orchestrate.env`);
   - else `CLAUDE.md` / `AGENTS.md` / `README`;
   - else infer from the repo (see 3);
   - else ask the user **once**, and write the answers into `.orchestrate.env` so nobody re-answers them.
   ```bash
   TEST_CMD=""            # targeted test/acceptance command (the one thing worth setting first)
   REQUIRED_ENV=""        # env var names the work and any submitted job must export
   SUBMODULES=""          # submodule paths needing a gitlink gate; empty = auto-detect
   NOTES_FILE=""          # project notes/log the worker appends milestones to
   SCHED_LIST_CMD=""      # lists your jobs, one per line "<nodes> <name> <state>"; empty = no scheduler
   MAX_BIG_JOBS=1         # concurrent multi-node/expensive jobs allowed
   EXTRA_SUBMIT_ARGS=""   # always-added submit args (e.g. excluding known-bad nodes)
   QUOTA_CMD=""           # e.g. "df -h $HOME", "lfs quota -hu $USER $HOME"
   ```
3. **Auto-detect the optional layers** instead of assuming them: `.gitmodules` → submodules layer (§7); `which sbatch/qsub/bsub` or a `SCHED_LIST_CMD` → scheduler layer (§S); `uv.lock`/`poetry.lock`/`package-lock.json` → lockfile invariant; a notes/log file in the repo → milestone journaling. **Skip cleanly any layer whose signal is absent** — a laptop-repo delegation should read nothing about clusters.
4. **Record the baseline.** `git status --porcelain` (pre-existing uncommitted work **must survive**), current branch, and for each submodule `git ls-tree HEAD <sub>` → `160000 <sha>`. With parallel sessions, give each worker its **own worktree**, or assign disjoint file ownership in writing.
5. **Check the budget.** If a scheduler or shared resource is in play, count what is already running against `MAX_BIG_JOBS`, check quota, and **put the remaining budget into the brief as a number**. A worker with no stated cap will happily exceed it.

## 2. Write the brief (send only when every field is filled)

```
ENVIRONMENT   repo/worktree absolute path · branch rule · env vars to export
              (non-interactive shells: use absolute interpreter paths) · resource budget · timebox
TASK          goal (one sentence) · non-goals · files to read first · numbered requirements
ACCEPTANCE    exact test/verification command(s) and what counts as passing
TIMEBOX       ≤⅔ of the hard limit; at the deadline: commit + write notes + submit/record handles, then stop
REPORT        the contract in §4, verbatim
FALLBACK      what to do if blocked (record the blocker and stop — do not improvise scope)
FORBIDDEN     inventing results not actually produced · exceeding the resource budget ·
              touching files owned by another session · committing secrets
```
Non-negotiable brief rules: small commits; milestone → notes file immediately; long work is launched, not watched; absolute interpreter paths in submitted/background scripts (`conda activate` routinely fails in non-interactive shells); export required env vars *before* any `--export=ALL`-style propagation; in a fresh or temporary worktree submodules may be absent, so their root paths must be exported explicitly.

## 3. Launch, then stay useful

Start with an absolute `cwd`. **Save the handle** (`threadId`, agent id, PID, job id) the moment you get it — it is unrecoverable later. While the worker runs, do not idle: monitor the jobs it submitted, prepare the verification commands, or review adjacent code. Do not start a second worker on the same files.

## 4. Report contract (require exactly this back)

```
commits:   [<sha> <subject> ...]
files:     [paths touched]
handles:   [{id, name, kind: job|process|run, where, resources, log, output_dir}]
tests:     <exact command> → <verbatim summary line>
gates:     {invariants checked and their results}
risks:     [open risks]
next:      <one command the orchestrator can run next>
```

## 5. Independent verification (always; a report is a claim, not evidence)

1. `git status` + read the **full** relevant `git diff` against each acceptance item. Look for: unrelated edits, half-finished branches, missing tests, stale docs, secrets.
2. **Rerun** `TEST_CMD` yourself. If the full suite has pre-existing collection errors, targeted tests + static checks are acceptable — but record exactly what was skipped.
3. If handles were returned: verify each **actually exists**, that log/output paths match the brief, that there are **no duplicate submissions** (same name or same output dir), and that resources are within budget.
4. If numbers were delivered: spot-check one **raw** output, not just the summary table.
5. Anything unverifiable, report as unverified. Never launder a worker's claim into your own summary.

## 6. Rework in the same thread

Resume (`codex-reply(threadId, …)` or the backend's equivalent) with **evidence**: the failing command and its output, the file/line or diff hunk, which acceptance item was violated, the exact change required, and the constraints that still hold. Never "please try again".
If the thread is gone (timeout, lost handle): start a fresh one whose brief says *"a previous session was interrupted; inspect `git status` for work in progress and reuse the uncommitted changes."*

## 7. Merge gate: assert structural invariants, and never chain them

Some structure survives review but not a merge: **submodule gitlinks**, symlinks, file modes, lockfiles, generated artifacts, large-file pointers. Assert each one as a **hard check that exits non-zero** — never as a link in an `&&` chain, where one earlier failure silently skips the rest.

```bash
for sub in ${SUBMODULES:-$(git config -f .gitmodules --get-regexp path | awk '{print $2}')}; do
  T=$(git ls-tree <branch> "$sub" | awk '{print $1}')
  [ "$T" = "160000" ] || { echo "ABORT: $sub gitlink=${T:-missing}"; exit 1; }
done
git merge --no-ff <branch>
for sub in $SUBMODULES; do git ls-tree HEAD "$sub"; done   # verify after, too
```
Both empty output (gitlink deleted on the branch) and `040000` (submodule expanded into a plain directory) must abort. Repair: `git update-index --add --cacheinfo 160000,<sha>,<sub>`.

## 8. Close out

Only when acceptance is fully met, the diff is reviewed, tests pass or the blocker is documented, and the user's pre-existing changes are intact. Report: outcome · paths changed · how you verified · residual risks · **the handle list and how to resume monitoring** after a session restart. **Do not push unless asked.**

## Collaboration & safety

- One coherent task per thread. Never have two agents editing the same file; parallel sessions need worktrees or written file ownership.
- Destructive commands, dependency installs, releases, and anything with external side effects are **separate authorizations** — ask, per action.
- Secrets never enter a prompt, a diff, or a report.

## §S Scheduler / long-running layer (only when a scheduler or long job exists)

Count running jobs before submitting; enforce `MAX_BIG_JOBS`; append `EXTRA_SUBMIT_ARGS` (bad-node exclusions) on every submit; submit scripts call interpreters by absolute path; export required env before propagating the environment. Treat an **empty response from a scheduler or status API as flakiness — retry, never as "finished"**. Record for every job: id, name, queue, resources, log path, output dir.

## Why these rules exist (each earned)

- A hard timeout swallowed several sessions' final reports → §0 timebox + journal milestones as they happen.
- A branch merge deleted submodule gitlinks three times; an `&&` chain made the guard a no-op → §7 hard assertions.
- A temporary worktree lacked submodules and a path variable was unexported → a whole batch of jobs failed at import → §1.3–1.4, §2.
- `conda activate` failed in a non-interactive shell; an analysis step lacked `PYTHONPATH` → §2 absolute paths, explicit exports.
- Two sessions submitted the same job, and parallel sessions mixed untracked files into one repo → §5.3, collaboration rules.
- A shared concurrency cap was breached because no one told the worker the number → §1.5.
- A scheduler's accounting endpoint returned empty output and a monitor called the job "done" → §S.
