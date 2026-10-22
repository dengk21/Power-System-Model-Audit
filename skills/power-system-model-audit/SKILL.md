---
name: power-system-model-audit
description: 审计电力系统与电气工程优化求解模型的文字、TeX数学模型、活动代码和数值结果；独立核查公式与物理关系，区分数学模型错误、代码错误及文档遗漏，补全文字未列但代码已实现的适用约束，并输出带来源和证据的Markdown报告。适用于ED/OPF、UC、储能、多能及随机或鲁棒调度；HW4为首个验证案例。
metadata:
  version: "0.13"
---

# PowerSystemModelAudit

同时审计“数学模型是否合理、代码是否正确实现、文字是否完整描述实际模型”。输出一份 `audit_report.md`，包含错误归因、数值证据及可直接合并的数学补全/修正实文。方法适用于MATLAB/YALMIP、Python建模、Julia/JuMP等；现有数值工具使用MATLAB，实例按可用后端接入。

## 输入与核查边界

列出用户要求的全部入口、原始TeX/文字、参数、结果和参考依据，逐个记录覆盖与失败。原始数学规范是核对对象，必要时也可能有错；不能总把差异归咎代码，也不能以双方一致或求解成功证明正确。

保持原文、数值基线、候选修正版与代码版本可区分。缺少定义或独立依据时可形成候选实文，状态保留WARNING。默认补全写入报告；用户已授权修改特定原文时直接落实修改并记录原式→新式和版本。审计或维护skill不默认授权改写全部原模型/TeX。

公开仓库以 `skills/power-system-model-audit/` 为维护源。本发布包保留通用工具、规范与案例适配器，不附课程原始作业、历史求解证据或benchmark材料；下文既有案例统计是原项目验证记录，不代表本包已附相应数据。无需课程输入的检查使用仓库 `tools/run_smoke_tests.m`，独立两机LP使用 `tools/run_semantic_demo.m`（需Gurobi）。课程案例依赖及公开范围见仓库 `docs/PACKAGING.md`。原项目中 `PowerSystemModelAudit/` 为报告/证据入口，旧结果保存在其 `archive/` 下；HW4复验按案例runbook读取归档结果。不得为迁移而重签旧MAT或规范哈希。其他项目按用户选择的目录组织。

## 使用路由

- 现有案例通过`psaudit_run(project,caseId,options)`统一运行，默认replay且要求新输出目录；模式、预算、证据目录与示例见[统一入口](references/running.md)。当前实现/已验证/待迁移能力和版本见[能力表](references/capabilities.md)，不把统一分派等同于旧案例全部迁移。
- 所有模型先读 [审计流程](references/audit-workflow.md) 和 [数学模型核查/补全](references/math-model-review.md)，双向建立文字—代码清单。
- 按模型假设选择 [电力系统检查项](references/power-system-checks.md)。AC无功平衡可补全到相应模型，纯有功DC不强加Q方程；代码中多出的约束先判断正确性和是否有意扩展。
- 新检查器按 [编写契约](references/verifier-contract.md) 开发、测试并固定；不为消除疑点随审计结论改公式。
- 参数已出现仍须检查其系数、单位、时间/设备索引和关系方向；可审阅的仿射关系用 [系数核查与语义验收](references/semantic-verification.md)，不能以关键词存在或当前解残差为零替代。
- 需要主动诊断或已授权候选修复时，读 [诊断—修复—验收](references/diagnostic-repair-loop.md)：先固定参数测试计划，再执行有限诊断；候选副本经冻结关系与完整轨迹验收，不按目标漂移大小直接回滚。
- 函数命名/职责见 [工具目录](references/tool-catalog.md)。通用脚本在scripts/，案例适配器在examples/。
- 执行按 [编写契约](references/verifier-contract.md#执行模式与诊断缓存) 区分replay、diagnose、capture；可行域过松/过紧按 [双向见证](references/audit-workflow.md#可行域双向见证) 核查，不把局部轨迹升级为完整模型有效解。
- HW4案例读 [数值参考快照](examples/hw4/math-spec.md)、[源码映射](examples/hw4/source-map.md)、[运行说明](examples/hw4/runbook.md)。固定快照保持历史MAT哈希，不表示原文不可质疑。
- HW5 UC案例读 [独立规范](examples/hw5/math-spec.md)和[运行说明](examples/hw5/runbook.md)，调用四入口适配器。注意最小时间从动作当期计数、首尾状态与功率边界分开，以及正成本下单侧启停逻辑的等价性；局部手算反例与原模型真实解分别报告。
- HW5最小时间完整修复使用[修复验收契约](examples/hw5/repair/math-spec.md)及`caseId='hw5-repair'`：在完整脚本/TeX副本中修正窗口，原始工况核对独立参考最优值，恰好开/关机两条完整轨迹用FEASIBILITY验收。保留B_CYCLIC_RAMP，不把该范围修复表述成全部HW5已正确。
- HW1—HW3、HW6—HW10读 [课程核查规范](examples/course/math-spec.md)与[运行说明](examples/course/runbook.md)。已有31入口审计及1项单列诊断；优化族包括SAA/CCP、C&CG/对偶及频率代理模型，非优化作业只使用相应数学/物理辅助检查。图示、功率基准未定义时保留REFERENCE_CONFLICT，不能靠常见约定自动定代码ERROR。

## 审计流程

1. **输入与版本**：记录源码、TeX/文字、参数、参考版本和结果哈希、求解状态及原solver。输入MAT/图形/日志不当完整结果。
2. **模型核查**：检查单位、符号、物理守恒、适用集合、边界、域与推导；必要时用独立定义/来源、手算反例或参考工况核查原文。原文错时报告数学错误并提出修正，不要求代码迎合错式。
3. **双向映射**：从文字找活动实现，也从活动代码找正文依据。追踪实际optimize/求解入口、注释/覆盖赋值/代数消元和隐含等价约束，不以关键词未找到就判遗漏。
4. **约束补全**：文字未列、代码正确实现且适用时，实际撰写完整公式、符号/单位、索引/边界、源码/原文位置和适用依据；在报告记DOCUMENTATION_GAP及补全状态。仅观察到代码但未独立核实时仍给草案，不将其升格成独立参考。
5. **独立数值检查**：先验证版本、状态、维度和有限性；批量验算全部适用索引。`psaudit_check_relations`统计残差/容差，适配器独立重建关系；`psaudit_reconstruct_storage`从独立初值重建轨迹。对可映射仿射块另用`psaudit_compare_affine`比较独立系数、常数和方向，识别当前解未激活的错误；被审H/obj/循环范围不作为参考真值。非仿射关系按独立公式、边界与激活工况接入，不自动宣称符号等价已证明。
6. **有限补充验证**：默认replay、新增执行预算0；诊断缓存缺失/版本不符仅报DATA_INSUFFICIENT，不调用optimize/runpf。diagnose明确动作、单次/累计时间预算且与原程序结果分开；capture专用于原入口结果捕获。无有效incumbent不算完整求解反例。已有解验算之外，用双向见证分别检查实现是否放过参考禁止的轨迹、排除参考允许的轨迹；局部反例和完整模型有效解分开。新参考另建测试版，不覆盖旧结果/哈希。
7. **报告**：按 [模板](assets/audit-report.md) 汇总全部入口、归因、数字与补全实文；`psaudit_write_audit_report`从本次entries/findings/witnesses/execution生成日期、数量与表格，不内置案例结论。经审阅的数学解释留在适配器清单并绑定版本。原文修改已授权时记录实际变化，否则给候选；不额外开发JSON/HTML接口。
8. **有限修复与验收（授权范围内）**：先固定审计结论和基线，再另存最小候选补丁。代码、文档、争议、等价实现分别处理；预算和轮数预先限定。新数值修复优先用`psaudit_validate_semantic_candidate`重放绑定源码、输入、规范、检查器和真实结果的证据，核对冻结工况/关系ID/数组形状，再调用`psaudit_repair_gate`。明确反例足以拒绝；缺项或未解决等价性只能暂缓，全部声明工况通过才可接受。成本涨跌只记录，不据此回滚。失败保留候选和依据，达到上限停止；具体捕获与独立重建由案例提供。

## 定级与来源

严重性与来源分开：来源为MATHEMATICAL_MODEL、IMPLEMENTATION、BOTH、DOCUMENTATION_GAP、REFERENCE_CONFLICT、NUMERICAL_EVIDENCE、CHECKER或EXECUTION。

- ERROR仅用于独立证据充分的数学错误、实现错误、双方错误或有效数值违规；执行错误单列。原规范有未解决矛盾时不把对其的条件式数值偏离自动确认为代码错。
- WARNING用于文字缺口/补全、规范争议、静态疑点、依据/数据不足、仅数值未激活且无独立证明、无有效解或未证实最优性。独立系数映射和定义已充分证明错误时，不因当前解未激活而降级；表示差异本身不证明非等价。文档遗漏而代码正确不判代码ERROR。
- INFO用于适用范围摘要、关系一致或不适用。
- 每条含ID、来源、原文/源码位置、独立依据、判断状态、实际/期望/残差/单位/阈值/数量，以及补全/修正状态。数值通过不证明代码完整，也不撤销未解决数学争议。

## 验证

有限修复的证据门控运行 `psaudit_test_repair_gate`；这只验证验收规则，完整候选仍须案例后端真实求解与独立检查。

新增系数工具运行`psaudit_test_affine`（28项零求解控制）；绑定结果验收运行[两机LP示例](examples/semantic/runbook.md)，含真实求解、正确成本上升、错误的小成本变化、费用倍数、过紧限制及优化方向，并测试缺项/版本异常。该示例验证工具行为，不计为Agent盲测或跨模型检出率。

真实HW5修复按统一入口重放，`psaudit_hw5_repair_test_replay`验证10项版本/覆盖/违规负控制；派生协议fixture不冒充新求解。`psaudit_test_run`在gurobi/optimize/runpf抛错替身下复查HW4/HW5/course及HW5修复，并验证危险/拼错模式、缺预算和输出碰撞在执行前被拒绝。

通用工具运行 `psaudit_test_core` 和 `psaudit_test_model_review`；案例运行自身适配测试及全入口复查。`psaudit_review_inventory`只处理经Agent审阅的结构清单，`psaudit_write_model_review`写归因与实文；它们不是通用TeX解析器或形式证明器。

模式/缓存/见证运行 `psaudit_test_execution_and_witnesses`，动态报告运行 `psaudit_test_report_data`。课程适配器的缺缓存与有缓存replay使用禁用optimize/runpf的测试替身验证；新诊断单独记预算。HW5提供最小开机/关机过紧与条件性周期爬坡过松三项LOCAL_RELATIONS见证；完整模型故障求解实验仍不能由这些手算替代。

能力记录区分方法适用族、可执行适配器、已验证实例和待适配条件。HW4五变体是首个ED/DCOPF案例；HW5四入口已完成UC适配与真实结果核查，133项数值类别通过，仍检出原文符号错误及二变量最小时间双方错误。其他族按自身假设接入，手算原语测试不等于完整优化实例已验证。

HW1—HW10现已全部形成审计覆盖。后续八作业基础754项类别含条件诊断，729 PASS/21 VIOLATION/4 DATA；加入Vg诊断可用性检查后的当前重放为755项，730 PASS/21 VIOLATION/4 DATA。11组数学/实现问题及执行/未证实项已报告。这表示全部入口完成审计，不表示所有原优化程序已求解或正确，也不把辅助潮流/符号脚本算成新的优化模型族。
