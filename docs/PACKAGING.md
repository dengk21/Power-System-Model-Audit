# 当前封装 1.1

2026-10-24发布标签为`v1.1`。`docs/project/`加入当前报告PDF/TeX、文档类及海报PDF/PPTX；Release单独提供阅读附件。纯Skill安装包仍只包含Skill清单资源，源码ZIP由发布提交直接归档。更新与验证记录见`releases/v1.1.md`和`PUBLICATION.md`的v1.1发布封装节。

1.1更新精简项目接入、显式测试运行采集、MATLAB事实导出和兼容性回归；当前操作见Skill的project-adapters.md。以下版本段落保留历史封装背景，旧目录与测试数量不作为当前入口。当前Skill版本以SKILL.md和source-manifest.json为准。

# 当前封装与依赖边界 v0.16

2026-10-23：Skill和项目适配器分离。`skills/power-system-model-audit/`只包含知识、规范、通用工具、空白模板及通用工具测试；安装Skill不安装固定课程适配器。

- `projects/course-audit/`是独立课程项目适配器，保留旧实现、规范和入口；原始模型/数据/历史求解结果仍不随包提供。
- `tools/run_smoke_tests.m`运行六组通用内核检查；独立课程项目的`run_adapter_tests.m`运行三组本地适配器fixture。历史九组合计不得误称当前Skill内有九组。
- `tools/run_semantic_demo.m`显式加载独立项目的LP示例，需要有效Gurobi许可；不会因复制Skill自动获得该示例。
- 新项目适配器由Agent在项目审计目录生成验证，生命周期见Skill内`references/project-adapters.md`。初始化骨架不表示数学审阅或测试已完成。
- `tools/refresh_manifests.py`重建完整仓库清单，Skill清单仅统计Skill树。`verify_package.py`同时检查Skill不携带项目examples或固定课程分派器。
- 课程目录Skill是受控同步副本。移出旧资源使用`sync_workspace_skill.py --retire-managed`，拒绝删除已独立修改的文件。旧MAT和冻结规范不改字节，不自动重签路径。

当前测试与迁移记录见`docs/PUBLICATION.md`的v0.16节。以下为历史封装说明，涉及Skill内examples、九组测试和原目录的描述仅适用于对应旧版。

---

# 公开包整理记录

当前维护说明（v0.14，2026-10-22）：Git仓库中的Skill已成为唯一维护源，课程目录副本由 `tools/sync_workspace_skill.py` 同步。`tools/refresh_manifests.py` 根据Git管理的文件生成当前来源和包清单；旧v0.13来源记录保存在 `source-manifest-v0.13.json`。以下2026-10-20段落描述历史封装过程，不是当前双源维护规则。

整理日期：2026-10-20（Asia/Shanghai）。方法版本仍为 v0.13，语义验收契约仍为 v0.12。本文件是封装与依赖记录，README、课程报告和海报由作者后续补充。

## 本包内容

- `skills/power-system-model-audit/`：当前维护源的完整 Skill，包括入口、Agent 元数据、审计参考、报告模板、通用 MATLAB 工具和 HW4/HW5/course/semantic 适配器。
- `tools/run_smoke_tests.m`：串联已有的九组自包含检查，设置求解器抛错替身，结果写入 `outputs/`。
- `tools/run_semantic_demo.m`：直接启动既有两机 LP 示例，不经依赖课程目录的统一分派器。真实求解预算和验收逻辑沿用原实现。
- `tools/verify_package.py`：仅使用 Python 标准库，检查文件清单、SHA-256、内部 Markdown 文件链接、私有绝对路径及来源未改动约束。
- `docs/source-manifest.json`：逐文件记录维护源与公开副本的 SHA-256；仅四份 Markdown 作封装适配，所有 MATLAB 文件、独立数学规范、模板和 Agent 元数据保持原字节。
- `docs/package-manifest.json`：本包受跟踪文件的大小和 SHA-256，不含其自身及运行产物。

未复制：原课程作业/讲义/数据、旧安装备份、历史审计结果和求解 MAT、benchmark 全量材料、对比项目、本机配置、求解器或其他第三方软件。原工作区和已安装 Skill 未修改。

## 环境与最小运行

已有开发环境为 MATLAB R2025b，要求 JVM；其他 MATLAB 版本未在本次封装中验证。Skill 作为 Agent 工作流需要支持 `SKILL.md` 的客户端；确定性检查与示例可直接在 MATLAB 中执行，不调用大模型 API。

在仓库根目录运行：

```matlab
addpath('tools');
summary = run_smoke_tests;
```

九组检查包括 core、model_review、affine、repair_gate、execution_and_witnesses、report_data、hw4_adapter、hw5_adapter、course_helpers。无需课程输入、YALMIP、MATPOWER 或商用求解器。测试中的手算/派生 fixture 是工具校验，不冒充真实优化结果，也不代表 Agent 端到端检出率。

若已安装并配置具有有效许可的 Gurobi MATLAB 接口，可显式运行：

```matlab
addpath('tools');
summary = run_semantic_demo;
```

该入口调用原 `psaudit_semantic_demo_run`，执行 28 次真实 LP，沿用最多40次/单次5秒/累计60秒预算，比较正确候选与五种错误候选，并运行12项元数据/覆盖负控制。每次使用新的输出目录；不预装求解器，不绕过许可，不以旧结果冒充新捕获。输出绑定本次源码、规范、参数和结果的哈希以及实际路径；转移或公开运行产物前应检查其路径和来源信息，不得只重签旧证据。

可将完整 `skills/power-system-model-audit/` 目录复制到个人 Codex Skill 目录（通常为 `~/.codex/skills/`）；保持目录名与内部结构。若已安装同名版本，先自行比较并保留需要的修改。重新加载客户端后可使用 `$power-system-model-audit`。仓库层 `tools/` 不是 Skill 内部依赖，作为封装验证入口留在仓库中。

包完整性检查（Python 3，仅标准库）：

```text
python tools/verify_package.py
```

## 课程适配器的外部依赖

`psaudit_run(project,caseId,options)` 的课程目录断言保持原实现，因此不用于本包的独立演示。若要复现课程案例，需自行提供有权使用的原始输入与匹配证据，保持原布局及版本：

| 案例 | 原项目所需路径/资料 | 补充运行条件 |
| --- | --- | --- |
| HW4 | `电力系统分析与控制作业/HW4/`，以及 `PowerSystemModelAudit/archive/` 中对应结果 | replay 需匹配 MAT；capture 另需 YALMIP、MATPOWER 和原 Gurobi/COPT |
| HW5 | `电力系统分析与控制作业/HW5/`，`PowerSystemModelAudit/HW5/` | replay 需匹配 MAT；新求解依赖原后端 |
| course | 其余 HW 输入、`PowerSystemModelAudit/remaining/` 与诊断缓存 | 不同入口需相应工具箱/后端；缺数据应报告不足 |
| HW5 repair | 原 HW5 输入、独立参考与完整修复证据 | 协议成员重建需 YALMIP/MATPOWER，capture 另需 Gurobi |

具体文件契约、模式、预算和适用范围保留在各案例 runbook。原项目统计作为历史验证说明保留，但本公开包不附其完整证据，不应将这些统计写作本包新完成的验证。需要课程案例的全入口回归与本包自包含检查是两种不同范围。

## 材料来源与公开范围

本包来自作者当前维护的 `power-system-model-audit` v0.13 工作副本；逐文件来源差异记录见 `source-manifest.json`。核心审计流程、数学规范、错误归因、检查内核、修复验收、执行预算和案例能力边界均保留。封装仅调整入口说明、运行依赖说明、HW4 命令中的本机路径，以及能力表指向未随包发布证据的链接。

公开内容限本包 Skill 文本、工具代码、模板和适配器；课程原始材料、未公开研究输入、历史日志/证据、第三方软件及其许可证文件不在包内。适配器和规范保留必要的课程模型名称与数值关系，以维持原方法含义；第三方资料的再发布权及最终开源许可证由作者在正式发布前确定，本包未代选许可证或声称对第三方材料有授权。第三方工具遵循各自许可。

正式课程交付的 README 可引用本记录并补充作者、项目介绍、资料引用和最终公开范围。海报 PDF/PNG、报告 PDF、学号及姓名命名的课程 ZIP 均未在本次生成；当前 ZIP 仅为 GitHub 源码封装。
