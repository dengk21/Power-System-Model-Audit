# Power System Model Audit

中文名称：**电力系统优化问题校核与修正Skill**。

电力系统优化模型能够求出结果，为什么还需要检查？因为求解器处理的是程序中已经写出的数学问题。如果储能效率用反、设备编号对应错误，或者最小开停机时间多算一期，程序仍可能正常运行，但它求解的已经不是原来的物理问题。

本项目针对这类错误，将检查步骤、领域知识和数值工具整理为Agent Skill，让AI编程助手能够从公式、代码和已有结果三个方面检查模型，并给出修改建议。当前版本为**1.1.2**；本次统一项目名称，计算方法沿用1.1版。

## 怎样检查模型

首先，对照数学说明与实际运行的代码，查看每条约束是否正确实现，程序是否额外加入了条件。然后，按照独立的物理定义重新计算关键关系，比较单位、系数、设备编号和各时段结果。最后，在相同输入下检查修改后的程序，并判断它是否允许已经确认合法的参考运行方案。这样既能发现约束不足，也能发现限制过多的问题。

例如，便宜机组漏掉容量上限时，调度费用可能很低；补回容量限制后，费用反而上涨。但由于修改后的方案满足了真实约束，这次修复仍然正确。因此，费用涨跌只能帮助分析结果，不能单独决定是否接受修改。

每次检查输出两份文件：`audit_brief.md`用表格说明哪里有问题、应该改代码还是补充说明；`audit_report.md`给出公式、数值和判断依据。

## 知识卡和项目程序各负责什么

知识卡保存可以重复使用的公式、适用条件、常见错误和小型测试。目前有9张卡片、45个局部公式测试，涉及功率平衡、储能、机组启停和移动资源。Agent先查看卡片是否适用于当前模型，再读取详细内容；新关系经过检查后保存，供后续任务使用。

通用工具负责计算误差和比较公式，但具体模型的变量含义、设备连接和初末状态不同。因此，每个项目还需要自己的适配程序，把这些信息传给通用工具。新项目的公式、数据和运行记录留在项目中，Skill保存通用方法和知识卡。具体写法见[项目接入说明](skills/power-system-model-audit/references/project-adapters.md)。

## 安装和使用

在[最新Release](https://github.com/dengk21/Power-System-Model-Audit/releases/latest)下载`power-system-model-audit-v1.1.2.zip`，将其中的`power-system-model-audit/`完整放入客户端的技能目录。Codex个人目录通常为`~/.codex/skills/`。已有同名版本时，先保留自己新增的知识，再更新并重新加载。

准备数学说明、实际求解代码、参数和可用结果后，可以直接提出要求：

```text
使用 power-system-model-audit 检查这个模型的公式、实际运行代码和数值结果。
请说明错误位置和判断依据，区分应该修改代码还是补充数学说明，
并生成简报和详细报告。
```

只检查公式和代码时，可以先准备说明材料；需要验算结果时，再接入项目程序。默认`replay`模式使用已有结果，不重新求解。需要进一步定位错误或生成新结果时，分别使用`diagnose`和`capture`，并设置求解次数和时间限制。`collect`用于自动记录命令、耗时、退出状态和本次使用的文件版本，便于核对报告对应的是哪一次运行。

普通检查也会判断是否整理新的知识卡。已经明确的经典结构按规则保存；含义不清或采用新假设的结构，则先确认条件，再决定如何记录。相关方法见[知识检索与学习](skills/power-system-model-audit/references/learning-workflow.md)。

## 代码和示例在哪里

| 目录 | 内容 |
| --- | --- |
| [Skill入口](skills/power-system-model-audit/SKILL.md) | Agent应遵循的检查步骤与工具调用方法 |
| [数值工具](skills/power-system-model-audit/scripts/) | 误差计算、公式比较、运行记录和修复检查程序 |
| [知识卡与参考说明](skills/power-system-model-audit/references/) | 常见约束、适用条件、检查方法和使用命令 |
| [报告模板](skills/power-system-model-audit/assets/audit-report.md) | 详细报告需要说明的问题和依据 |
| [课程项目程序](projects/course-audit/README.md) | HW4/HW5等课程模型的检查程序及双机LP示例 |
| [报告与海报](docs/project/README.md) | 项目报告PDF/TeX、A1海报PDF/PPTX |
| [运行与完整性检查](tools/) | 程序测试、LP演示和文件校验工具 |

完整源码可下载`PowerSystemModelAudit-v1.1.2-source.zip`，也可以直接克隆：

```bash
git clone https://github.com/dengk21/Power-System-Model-Audit.git
cd Power-System-Model-Audit
python tools/verify_package.py
```

Release中的`SHA256SUMS.txt`列出每个附件的校验值，用于检查下载文件是否发生变化。[v1.1.2发布说明](docs/releases/v1.1.2.md)介绍了此次名称统一。

## 运行环境

Python管理工具只使用标准库，建议Python 3.10及以上版本。数值工具使用MATLAB，已在R2025b中检查。不同优化模型使用的Gurobi、COPT、YALMIP或MATPOWER等环境由项目自行配置。

在MATLAB中进入仓库根目录，运行六组通用工具检查：

```matlab
addpath(fullfile(pwd, 'tools'));
summary = run_smoke_tests;
```

这六组检查使用预设数值例子，不调用优化求解器。结果写入新建的`outputs/smoke-<UUID>/`目录。如果已经配置具有有效许可的Gurobi MATLAB接口，还可以运行真实双机LP示例：

```matlab
summary = run_semantic_demo;
```

该示例会新建结果目录，执行28次LP求解，比较正确修复、容量放宽、费用系数错误等六种情况。原课程模型的完整检查还需要对应输入和运行记录；本仓库提供程序和独立小例子。

## 怎样理解已有结果

v0.15对照实验中，A/B/C完整审计分别通过42/48、45/48、45/48项，三组都已指出全部36个确定错误。因此，这轮实验主要反映了问题分类和文档补全的差异。最终修复分别通过44/48、44/48、48/48项，但C组包含三项追加运行，不能将其100%解释为相同尝试次数下的优势。

1.1版工具通过131项Python功能与兼容性测试、45项知识卡公式测试，以及MATLAB六组通用工具和三组课程项目程序检查。工具测试回答的是程序是否按预期工作；模型效果对照回答的是Agent能否发现并修复错误，二者分别统计。原始数据、具体条件和引用来源见[项目报告](docs/project/report.pdf)及[发布记录](docs/PUBLICATION.md)。
