# 项目检查器的验收证据

本约定仅供`psaudit_project.py freeze`记录验收证据，不是通用模型数据接口、检查器API或求解器插件协议。项目自行实现测试入口、断言和输出格式；MATLAB、COPT等环境由项目管理。

对有`card_plan`的项目，`--test-evidence`使用项目内、adapter目录外的JSON记录。1.1优先使用[项目接入的collect](project-adapters.md#自动采集测试运行事实)：项目测试写一次facts，工具采集执行事实并派生验收引用和通过字段；Agent实质审阅后直接用于freeze，不手抄记录。既有手工记录继续兼容；不能仅删除骨架错误标记或伪造通过字段。

顶层字段：`schema_version=1`、`reviewer`、`scope`、`files`、`runner`、`execution_evidence`、`checks`。所有文件引用用`{root,path,sha256}`，root为project/adapter/skill，path相对对应目录且用正斜杠。files完整绑定声明的模型源、所选Skill依赖及adapter文件，不包括bindings/history；runner引用实际项目测试入口，execution_evidence引用实际执行日志或轨迹。测试用fixture、辅助代码、配置也须列入files。工具不自动发现漏列依赖。

checks逐一对应MATCH任务的`function`，每项记录：

项目还须独立维护[关系清单](relation-inventory.md)，在project.json声明relation_inventory；验收引用的每个项目ID必须在清单中关联对应card角色且已执行。清单外的无card关系不能丢弃；未完成项保留PARTIAL，不阻止保存诚实的局部审计证据。旧项目补清单并复核再冻结，不重签历史结果。

- `inputs`：以card规范输入名为键，每个值含实际`shape`（正整数数组）、`unit`、`index_review`及`evidence`文件引用。证据须有项目断言与实际观察，核对节点/设备ID和时间顺序，不能复制bindings描述充数。
- `relations`：每个card关系一项，含`card_relation`、实际执行的`project_relation_ids`数组和`evidence`。映射/域关系若通过项目断言而非数值items验证，使用项目断言ID并保留轨迹；未检查的关系不能用别的PASS顶替。
- `controls`：正常normal、违例violation、等价equivalent、不适用inapplicable、缺数据missing_data、边界boundary，各含`category`、`passed=true`及`evidence`。passed表示测试结果符合预期，例如故意违例必须被检出；不是要求所有模型关系均PASS。不适用控制也可记录规划层排除行为。

freeze会拒绝任意文本日志、缺关系/输入/控制项、失败控制及与测试时快照不一致的代码。测试入口、原始证据与所有引用文件纳入绑定；之后变化即STALE。结果仍是BOUND_NOT_PROOF，专项状态仅为REVIEWED_EVIDENCE_BOUND；旧版绑定无此记录时为NOT_ASSESSED。哈希与字段不能证明执行真实性或数学独立性，Agent负责实质审阅。

自定义关系和耦合继续保存在项目完整关系清单及本地测试中，不强制套用card任务结构。当前工具只检查选中card的证据完整性，不声称发现了全部活动关系、证明了整模型正确，或已自动验证任意项目映射。
