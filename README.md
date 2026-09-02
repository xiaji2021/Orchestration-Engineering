# orchestrate-codex skill

让 Claude Code 把实现/实验工作委派给 Codex MCP（`codex` / `codex-reply`），同时保留规划、验证、资源与合并门禁。

- **`main`**：通用版，任何主机/服务器/集群。调度器、配额、身份切换全部由项目配置 `.codex-orchestrate.env` 注入，skill 本身不含任何站点专名。
- **`cluster-cscc`**：MBZUAI CSCC 集群特化（Slurm、Lustre `lfs quota`、`iam` 身份切换、坏节点排除、sacct/Lustre 缓存经验）。

## 安装
```bash
bash install.sh --mcp-name codex-<you> --codex-home ~/.codex_<you> --shared-user <you> \
     [--codex-bin ~/.local/bin/codex] [--iam-cmd "<identity switch cmd>"] [--skills-dir ~/.claude/skills]
claude mcp add --scope user codex-<you> -e CODEX_HOME=~/.codex_<you> -e SHARED_USER=<you> -- ~/.local/bin/codex mcp-server
claude mcp list   # 应显示 codex-<you> connected
cp codex-orchestrate.env.example <repo>/.codex-orchestrate.env   # 每个项目填一份
```

## 内容
`SKILL.md.tmpl`（安装时替换 `{{MCP_NAME}}` 等占位符）· `DELEGATION_TEMPLATE.md` · `scripts/preflight.sh <repo>` · `codex-orchestrate.env.example`

## 核心规则
一个会话 = 一个 ≤2h 里程碑（MCP 3h 硬超时会丢结果）；brief 带时间盒与资源预算；Codex 按固定报告契约返回；Claude 独立验证（diff / 定向测试 / 作业核实）；分支合并前子模块 gitlink 硬断言。
