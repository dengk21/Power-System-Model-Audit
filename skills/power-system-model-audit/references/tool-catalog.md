# 工具命名与职责

通用工具统一用 `psaudit_` 前缀（power-system audit）和动作/对象命名。案例工具放在 `examples/<case>/` 并保留案例标识；不把固定拓扑参数包装成通用函数。MATLAB 文件名与第一函数名一致。

| 当前函数 | 职责 | 位置 |
| --- | --- | --- |
| psaudit_run | 统一案例/模式分派，默认零求解重放、新输出目录及显式预算 | scripts/ |
| psaudit_test_run | 禁用gurobi/optimize/runpf的真实案例重放与入口拒绝控制 | scripts/ |
| psaudit_hw5_repair_run/replay | 完整HW5二变量脚本最小时间修复、三工况真实捕获/v0.12重放 | examples/hw5/repair/ |
| psaudit_hw5_repair_test_replay | 10项基于复制协议fixture的版本/维度/违规控制，零求解 | examples/hw5/repair/ |
| psaudit_check_relations | 等式/上下界、容差与全索引证据 | scripts/ |
| psaudit_compare_affine | 独立仿射块系数/常数/方向核对，索引对齐及已知单位换算 | scripts/ |
| psaudit_test_affine | 28项系数/等价写法/单位/休眠错误/优化方向控制，无求解 | scripts/ |
| psaudit_validate_semantic_candidate | 绑定真实结果、冻结工况/关系/形状，独立重放后验收 | scripts/ |
| psaudit_semantic_demo_run | 两机LP四工况六候选真实求解与12项负控制 | examples/semantic/ |
| psaudit_reconstruct_storage | 从独立初值重建储能轨迹 | scripts/ |
| psaudit_hash_file | 文件原始字节 SHA-256 | scripts/ |
| psaudit_review_inventory | 数学模型/代码/文档缺口归因 | scripts/ |
| psaudit_write_model_review | 报告中的归因与补全实文 | scripts/ |
| psaudit_test_core | 数值原语测试 | scripts/ |
| psaudit_test_model_review | 数学归因、适用性与补全测试 | scripts/ |
| psaudit_ac_network | 逐支路AC复tap/充电/并联重建与两端功率 | scripts/ |
| psaudit_dc_network | 独立DC角度/支路功率，含tap/status/shift | scripts/ |
| psaudit_check_commitment | UC独立事件、持续窗口、门控出力及爬坡 | scripts/ |
| psaudit_frequency_extremum | 相同TG/FR线性SFR的矩阵指数首极值 | scripts/ |
| psaudit_execution_context | replay/diagnose/capture回调门控与动作/时间账本 | scripts/ |
| psaudit_read_diagnostic | 绑定版本的诊断缓存读取与有预算生成 | scripts/ |
| psaudit_evaluate_witnesses | 参考/实现双向成员见证，过松与过紧分开 | scripts/ |
| psaudit_write_witnesses | 见证范围、赋值、两侧关系和条件报告 | scripts/ |
| psaudit_write_audit_report | 从本次结构证据生成公共报告 | scripts/ |
| psaudit_repair_gate | 门控候选的范围、参考、关系、费用与完整成员验收证据 | scripts/ |
| psaudit_test_repair_gate | 修复验收的6项正常/负控制，含正确成本上升与争议推迟 | scripts/ |
| psaudit_test_execution_and_witnesses | 模式、缓存、预算及成员方向行为测试 | scripts/ |
| psaudit_test_report_data | 证据改变时报告摘要与实文随之改变 | scripts/ |
| psaudit_hw4_build_reference | HW4 数值参考快照 | examples/hw4/ |
| psaudit_hw4_check_solution | HW4 数值输出→独立关系 | examples/hw4/ |
| psaudit_hw4_capture_result | 原入口真实结果保存 | examples/hw4/ |
| psaudit_hw4_relation_inventory | 已审阅 HW4 文字/代码清单 | examples/hw4/ |
| psaudit_hw4_write_report | 案例证据与补全报告 | examples/hw4/ |
| psaudit_hw4_test_adapter | 案例手算/异常数据测试 | examples/hw4/ |
| psaudit_hw4_test_reporting | 数学归因/争议引起的参考降级报告测试 | examples/hw4/ |
| psaudit_hw4_validate_suite | 五入口零求解复查与交叉证据 | examples/hw4/ |
| psaudit_hw5_build_reference | UC参数与逐支路DC独立网络 | examples/hw5/ |
| psaudit_hw5_check_solution | UC域、独立启停、时间窗口、爬坡、成本及DC检查 | examples/hw5/ |
| psaudit_hw5_capture_result | 四个原UC入口的完整真实结果保存 | examples/hw5/ |
| psaudit_hw5_relation_inventory | 哈希门控的数学错误/代码/文档遗漏清单 | examples/hw5/ |
| psaudit_hw5_test_adapter | 10组手算/异常轨迹，含局部公式反例 | examples/hw5/ |
| psaudit_hw5_feasibility_probes | 两项最小时间过紧及一项条件性爬坡过松见证 | examples/hw5/ |
| psaudit_hw5_validate_suite | 四入口零求解数值复查 | examples/hw5/ |
| psaudit_hw5_write_report | 全入口数值证据、归因与LaTeX补全报告 | examples/hw5/ |
| psaudit_course_capture | 剩余课程全部原入口结果/执行状态捕获 | examples/course/ |
| psaudit_course_test_helpers | 12组AC/DC/UC/频率/概率手算测试 | examples/course/ |
| psaudit_course_validate | 全量独立核查，原/复跑/诊断明确区分 | examples/course/ |
| psaudit_course_review_inventory | 固定输入清单门控的课程语义归因 | examples/course/ |
| psaudit_course_review_notes | 已审阅课程边界/覆盖警告与实际情景差异 | examples/course/ |
| psaudit_course_write_report | 单个主报告、实际补全与失败/限定汇总 | examples/course/ |

旧名迁移：`gma_check_relations`→`psaudit_check_relations`，`gma_storage_trace`→`psaudit_reconstruct_storage`，`gma_selftest`→`psaudit_test_core`，`hw4_sha256`→`psaudit_hash_file`；`hw4_reference/check_values/capture/audit/selftest/validate_all` 分别迁移为对应 HW4 案例函数。旧命名不保留隐式别名，以免混用历史实现。

skill 名称为 `$power-system-model-audit`；references 按 audit-workflow、math-model-review、verifier-contract、power-system-checks 命名；报告模板为 assets/audit-report.md。案例 math-spec.md 保留历史参考字节，以验证旧 MAT 的 specHash；它不是“原文永远正确”的承诺。
