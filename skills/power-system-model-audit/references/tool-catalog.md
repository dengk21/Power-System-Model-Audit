# 工具命名与职责

通用工具统一用 `psaudit_` 前缀（power-system audit）和动作/对象命名。项目工具放在各项目审计目录并保留项目标识；不把固定拓扑参数包装成通用函数。MATLAB 文件名与第一函数名一致。

| 当前函数 | 职责 | 位置 |
| --- | --- | --- |
| psaudit_project.py | 项目骨架初始化、声明依赖检查、绑定版本及旧记录归档；不执行模型 | scripts/ |
| test_psaudit_project.py | 项目与Skill分离、源码/工具变化、冲突及归档回归 | scripts/ |
| psaudit_knowledge.py | 自动学习计划/本机偏好、约束检索、来源快照/变更、局部回归、候选登记与版本归档 | scripts/ |
| psaudit_learning_policy.py | 检查Agent的模型族结构证据，生成学习/询问/跳过策略，保存本机偏好 | scripts/ |
| test_psaudit_learning_policy.py | 经典与混合结构、三种选择、偏好持久化/撤销、来源变化及自动操作门控回归 | scripts/ |
| psaudit_pattern_checks.py | 八类具名局部数学关系检查器；不执行模型源码或求解器 | scripts/ |
| test_psaudit_knowledge.py | 来源过期、适用条件、修订冲突、卡片/fixture变化及受控同步回归 | scripts/ |
| psaudit_write_brief_report | 从同一份审阅数据生成极简行动清单 | scripts/ |
| psaudit_check_relations | 等式/上下界、容差与全索引证据 | scripts/ |
| psaudit_compare_affine | 独立仿射块系数/常数/方向核对，索引对齐及已知单位换算 | scripts/ |
| psaudit_test_affine | 28项系数/等价写法/单位/休眠错误/优化方向控制，无求解 | scripts/ |
| psaudit_validate_semantic_candidate | 绑定真实结果、冻结工况/关系/形状，独立重放后验收 | scripts/ |
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

旧名迁移：`gma_check_relations`→`psaudit_check_relations`，`gma_storage_trace`→`psaudit_reconstruct_storage`，`gma_selftest`→`psaudit_test_core`，`hw4_sha256`→`psaudit_hash_file`；`hw4_reference/check_values/capture/audit/selftest/validate_all` 分别迁移为对应 HW4 案例函数。旧命名不保留隐式别名，以免混用历史实现。

skill 名称为 `$power-system-model-audit`；references 按 audit-workflow、math-model-review、verifier-contract、power-system-checks 命名；报告模板为 assets/audit-report.md。项目 math-spec.md 保留历史参考字节，以验证旧 MAT 的 specHash；它不是“原文永远正确”的承诺。
