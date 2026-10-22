# Power System Model Audit

面向电力系统优化模型的数学规范—代码双向审计工具与 Agent Skill。

当前方法版本 **v0.13**，语义验收契约 **v0.12**。

工具同时核查数学说明、活动代码与数值结果，区分数学模型错误、实现错误、双方错误、文档遗漏及参考争议，并生成带来源、数值证据和数学补全内容的 Markdown 审计报告。求解成功或当前解残差为零，不等于模型语义正确。

## 发布内容

| 路径 | 内容 |
| --- | --- |
| [Skill 入口](skills/power-system-model-audit/SKILL.md) | 审计流程、定级、使用路由和能力边界 |
| [通用工具](skills/power-system-model-audit/scripts/) | MATLAB 数值关系、网络重建、储能递推、系数比较、见证与验收工具 |
| [案例适配器](skills/power-system-model-audit/examples/) | HW4、HW5、其他课程案例及独立两机 LP 示例 |
| [参考文档](skills/power-system-model-audit/references/) | 工作流、数学审查、执行模式、验收契约与工具目录 |
| [报告模板](skills/power-system-model-audit/assets/audit-report.md) | 审计输出模板 |
| [运行工具](tools/) | 自包含测试、独立 LP 示例与包完整性检查 |

此仓库发布可分发的方法、工具与适配器。原课程作业、讲义、历史求解结果、全量 benchmark、第三方求解器及本机配置未随包提供。课程适配器仍需对应输入和证据，不能仅凭此仓库重放完整课程实验。

## 快速开始

```bash
git clone https://github.com/dengk21/Power-System-Model-Audit.git
cd Power-System-Model-Audit
python3 tools/verify_package.py
```

在 MATLAB 中切换到仓库根目录，运行无需课程输入、无需外部求解器的九组自包含检查：

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
