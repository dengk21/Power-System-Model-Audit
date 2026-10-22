# v0.13 仓库发布核验

日期：2026-10-22（Asia/Shanghai）。

本次发布以 2026-10-20 已验证的公开包为基础，新增仓库首页和本记录，并重新生成包文件清单。90 个 Skill 资源及 MATLAB 工具保持发布包原字节；原项目维护源码、课程材料和实验记录未改动。macOS 自动生成的 `.DS_Store` 未进入发布副本。

发布前运行标准库完整性检查，核对文件大小、SHA-256、Skill 来源、内部 Markdown 链接及私有绝对路径。历史九组 MATLAB 测试记录见 VALIDATION.md；本次运行情况在下文记录。

## 本次实测

在 macOS 的 MATLAB R2025b 中重新运行 `run_smoke_tests`，core、model_review、affine、repair_gate、execution_and_witnesses、report_data、hw4_adapter、hw5_adapter、course_helpers 九组全部通过；汇总 `groupsPassed=9`、`groupsTotal=9`、`solverCalls=0`。本地日志未上传。未在本次发布中运行需要 Gurobi 的真实 LP 演示或完整课程案例。

标准库包检查通过：99 个清单内文件、90 个 Skill 资源、86 个资源与原维护源逐字节一致、4 份既有公开包文档适配、45 个内部链接。清单文件本身另计，共发布 100 个文件。
