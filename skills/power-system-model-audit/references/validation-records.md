> v0.16：以下为历史验证记录。项目适配器及运行说明已迁出Skill；数量不重新计为迁移后验证。

# 历史验证记录与案例测试

以下保留原有案例和工具测试的范围，不因知识库升级而重计为v0.14泛化效果。


有限修复的证据门控运行 `psaudit_test_repair_gate`；这只验证验收规则，完整候选仍须案例后端真实求解与独立检查。

新增系数工具运行`psaudit_test_affine`（28项零求解控制）；绑定结果验收运行两机LP项目示例，含真实求解、正确成本上升、错误的小成本变化、费用倍数、过紧限制及优化方向，并测试缺项/版本异常。该示例验证工具行为，不计为Agent盲测或跨模型检出率。

真实HW5修复按统一入口重放，`psaudit_hw5_repair_test_replay`验证10项版本/覆盖/违规负控制；派生协议fixture不冒充新求解。`psaudit_test_run`在gurobi/optimize/runpf抛错替身下复查HW4/HW5/course及HW5修复，并验证危险/拼错模式、缺预算和输出碰撞在执行前被拒绝。

通用工具运行 `psaudit_test_core` 和 `psaudit_test_model_review`；案例运行自身适配测试及全入口复查。`psaudit_review_inventory`只处理经Agent审阅的结构清单，`psaudit_write_model_review`写归因与实文；它们不是通用TeX解析器或形式证明器。

模式/缓存/见证运行 `psaudit_test_execution_and_witnesses`，动态报告运行 `psaudit_test_report_data`。课程适配器的缺缓存与有缓存replay使用禁用optimize/runpf的测试替身验证；新诊断单独记预算。HW5提供最小开机/关机过紧与条件性周期爬坡过松三项LOCAL_RELATIONS见证；完整模型故障求解实验仍不能由这些手算替代。

能力记录区分方法适用族、可执行适配器、已验证实例和待适配条件。HW4五变体是首个ED/DCOPF案例；HW5四入口已完成UC适配与真实结果核查，133项数值类别通过，仍检出原文符号错误及二变量最小时间双方错误。其他族按自身假设接入，手算原语测试不等于完整优化实例已验证。

HW1—HW10现已全部形成审计覆盖。后续八作业基础754项类别含条件诊断，729 PASS/21 VIOLATION/4 DATA；加入Vg诊断可用性检查后的当前重放为755项，730 PASS/21 VIOLATION/4 DATA。11组数学/实现问题及执行/未证实项已报告。这表示全部入口完成审计，不表示所有原优化程序已求解或正确，也不把辅助潮流/符号脚本算成新的优化模型族。
