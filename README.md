# Power System Model Audit

面向电力系统优化模型的数学规范—代码双向审计工具与 Agent Skill。

当前方法版本 **v0.16**，语义验收契约 **v0.12**。

工具同时核查数学说明、活动代码与数值结果，区分数学模型错误、实现错误、双方错误、文档遗漏及参考争议，并生成带来源、数值证据和数学补全内容的 Markdown 审计报告。求解成功或当前解残差为零，不等于模型语义正确。

最终交付两份报告：`audit_brief.md` 只列检查文件、可能有问题的位置和是否需要改正；`audit_report.md` 保留完整专业分析、公式与证据。逐模型报告使用同名 `_brief.md` 简报。两份报告共用本次审阅结论。

v0.14增加持续学习工作流：按模式保存公式/条件、来源及反例，支持检索、来源变更检查、候选登记和版本归档。首批8张卡片有40个局部fixture；这些不是完整模型效果评测。Git仓库中的Skill是唯一维护源，课程目录副本由同步工具生成。

v0.15把学习接入普通审计：无需额外声明“学习这个项目”。Agent根据活动代码识别经典结构并自动积累；含非经典机制或尚未确认的结构时，询问“本次学习 / 以后默认都自动学习 / 本次不学习”。永久偏好保存在本机，不随仓库发布。识别为经典模型不代表其约束正确，自动学习仍须提取、去重和审阅，未验证知识保持候选状态。

## 项目与Skill分离（v0.16）

Skill只积累可复用的约束知识、审计规范和通用工具。新模型的适配器、数学规范、变量映射、测试和结果保存在模型项目自己的审计目录。首次接入由Agent生成并验证；后续先检查源码、参数、工具和卡片依赖，未变复用，有变局部更新并保留历史。现有课程适配器移到`projects/course-audit/`，不继续扩充Skill内固定caseId。

详见[项目适配器契约](skills/power-system-model-audit/references/project-adapters.md)。`psaudit_project.py init`只生成未实现骨架，不等于自动审计；完整语义提取、独立依据和测试仍由Agent完成。

## 学习与更新

先读[学习流程](skills/power-system-model-audit/references/learning-workflow.md)和[模式索引](skills/power-system-model-audit/references/pattern-index.md)。普通请求“审计这个项目”已包含自动学习判断；也可显式要求：

```text
使用 $power-system-model-audit 学习这个新模型，提取活动约束，
与已有模式比较，验证新模式并登记；不要修改原模型。
```

```bash
python3 skills/power-system-model-audit/scripts/psaudit_knowledge.py search "储能"
python3 skills/power-system-model-audit/scripts/psaudit_knowledge.py validate
python3 skills/power-system-model-audit/scripts/test_psaudit_knowledge.py
python3 skills/power-system-model-audit/scripts/test_psaudit_learning_policy.py
```

检索来源不可用时返回SOURCE_UNAVAILABLE；条件未提供时返回NEEDS_CONTEXT。自动识别来源变化不等于自动完成数学重学，Agent按重学清单重新审阅、测试并递增版本。命令、候选格式和源目录映射见学习流程。

## 发布内容

| 路径 | 内容 |
| --- | --- |
| [Skill 入口](skills/power-system-model-audit/SKILL.md) | 审计流程、定级、使用路由和能力边界 |
| [通用工具](skills/power-system-model-audit/scripts/) | MATLAB 数值关系、网络重建、储能递推、系数比较、见证与验收工具 |
| [独立课程项目](projects/course-audit/) | 已迁出Skill的课程适配器与两机LP；不随Skill安装 |
| [参考文档](skills/power-system-model-audit/references/) | 工作流、数学审查、执行模式、验收契约与工具目录 |
| [移动资源参考](skills/power-system-model-audit/references/mobile-resource-constraints.md) / [电力—通信恢复参考](skills/power-system-model-audit/references/restoration-coupling-constraints.md) | 从更新后活动代码整理的公式、开关、边界与来源哈希；尚无完整数值适配器 |
| [报告模板](skills/power-system-model-audit/assets/audit-report.md) | 审计输出模板 |
| [运行工具](tools/) | 自包含测试、独立 LP 示例与包完整性检查 |

此仓库发布可分发的方法、工具与适配器。原课程作业、讲义、历史求解结果、全量 benchmark、第三方求解器及本机配置未随包提供。课程适配器仍需对应输入和证据，不能仅凭此仓库重放完整课程实验。

## 从Release安装Skill

在[Releases](https://github.com/dengk21/Power-System-Model-Audit/releases/latest)下载`power-system-model-audit-v0.16.zip`。解压后将整个`power-system-model-audit/`目录放入客户端技能目录（Codex个人目录通常为`~/.codex/skills/`），重新加载技能即可。已有同名Skill时先保留本地新增知识。纯Skill安装无需课程适配器或完整仓库。

需要开发和运行示例时下载`PowerSystemModelAudit-v0.16-source.zip`，或克隆仓库。各资产的SHA-256见Release附件`SHA256SUMS.txt`。依赖、迁移及验证范围见[v0.16发布说明](docs/releases/v0.16.md)。

## 快速开始

```bash
git clone https://github.com/dengk21/Power-System-Model-Audit.git
cd Power-System-Model-Audit
python3 tools/verify_package.py
```

在 MATLAB 中切换到仓库根目录，运行无需课程输入、无需外部求解器的六组通用内核检查：

```matlab
addpath(fullfile(pwd, 'tools'));
summary = run_smoke_tests;
```

输出写入新建的 `outputs/smoke-<UUID>/`。测试通过求解器抛错替身防止隐式求解；这些测试验证工具行为，不表示任意电力模型均已验证。

### 独立两机 LP 示例

需要 MATLAB 和已配置、具有有效许可的 Gurobi MATLAB 接口：

```matlab
addpath(fullfile(pwd, 'tools'));
summary = run_semantic_demo;
```

该入口会执行真实求解，演示候选模型的语义验收；它与零求解的自包含测试分开。

### 作为 Agent Skill 使用

将 `skills/power-system-model-audit/` 完整复制到所用客户端的技能目录，并在支持 Skill 的 Agent 中调用：

```text
使用 $power-system-model-audit 审计这个项目的数学说明、活动代码和数值结果，
核查独立物理或数学依据，区分错误来源，并生成 audit_report.md。
```

输入应包含待审说明或 TeX、实际求解入口、参数和可用结果。新模型需要按自身假设建立独立参考与适配，现有工具不是任意 TeX/源码的自动解析器或形式化证明器。

## 环境与验证

现有数值实现使用 MATLAB；历史封装验证环境为 MATLAB R2025b（启用 JVM）。零求解测试无需安装 Gurobi、YALMIP 或 MATPOWER；具体案例与真实求解需按各自运行说明配置依赖。Python 完整性检查仅使用标准库。

- [封装与依赖说明](docs/PACKAGING.md)
- [历史封装验证](docs/VALIDATION.md)
- [本次发布核验](docs/PUBLICATION.md)
- [当前能力与边界](skills/power-system-model-audit/references/capabilities.md)
- [统一运行说明](skills/power-system-model-audit/references/running.md)
- [语义验收契约](skills/power-system-model-audit/references/semantic-verification.md)

历史审计数量仅描述原项目记录；完整原始证据未随本仓库公开。模型族支持、固定案例适配、工具测试与 Agent 效果评测应分别理解。
