# Codex 委派模板（复制填空后作为 prompt；项目细节取自 .codex-orchestrate.env）

## 环境
- 仓库/worktree（绝对路径）：
- 分支规则：（worktree 新建分支 / 直接主线；并行会话的文件归属）
- 必须导出的环境变量：（来自 REQUIRED_ENV；非交互 shell 用解释器绝对路径）
- 资源预算：（队列/分区、节点×GPU 上限、排除节点、最多作业数）；提交前先查在跑作业
- 时间盒：≤2 小时；到点先 commit + 写笔记 + 提交作业再收尾

## 任务
- 目标（一句话）：
- 非目标：
- 必读文件：
- 实现要求（编号）：
- 测试/验收命令：
- 失败预案：

## 交付
- 笔记：<项目笔记路径>（里程碑即写）
- 报告契约：commits / files / jobs{id,name,queue,resources,log,output_dir} / tests（命令+原样摘要）/ gates / open_risks / next_command
- 禁止：编造未产出的结果；超出资源预算；改动归属外文件
