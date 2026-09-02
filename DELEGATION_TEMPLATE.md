# Delegation brief template

Copy, fill every field, then send as the worker's prompt. Project values come from
`.orchestrate.env` / preflight — never leave a field as a placeholder.
中文：字段没填满就不要发。缺的每一条，最后都会变成一次返工。

## ENVIRONMENT
- Repo / worktree (absolute path):
- Branch rule: (new branch in own worktree | direct to mainline) — and, if sessions run in
  parallel, which files this worker owns
- Env vars to export: (from `REQUIRED_ENV`; in non-interactive shells call interpreters by
  absolute path — `conda activate` routinely fails there)
- Resource budget: (queue/partition, nodes x accelerators, max concurrent jobs, excluded nodes)
  — check what is already running *before* submitting anything
- Timebox: <= 2/3 of the backend's hard limit. At the deadline: commit, write notes,
  submit/record handles, then stop.

## TASK
- Goal (one sentence):
- Non-goals:
- Files to read first:
- Requirements (numbered):
- Acceptance command(s) and what counts as passing:
- If blocked: record the blocker and stop — do not improvise scope.

## DELIVERY
- Notes file: <path> — append each milestone the moment it lands, not at the end.
- Report back exactly:
  ```
  commits:   [<sha> <subject> ...]
  files:     [paths touched]
  handles:   [{id, name, kind: job|process|run, where, resources, log, output_dir}]
  tests:     <exact command> -> <verbatim summary line>
  gates:     {invariants checked and their results}
  risks:     [open risks]
  next:      <one command the orchestrator can run next>
  ```
- Forbidden: reporting results that were not actually produced; exceeding the resource budget;
  editing files owned by another session; committing secrets; pushing without being asked.
- Long-running work is **launched and handed back as a handle** — never watched to completion.
