# 项目关系清单与遗漏追踪

先从活动入口、有效配置、参数加载和独立规范盘点关系，再关联card；不能将card任务反推为全部模型。清单与具体公式在项目内维护，本约定是审阅记录，不是通用检查器或模型接口，也不自动解析任意源码。

新项目init在adapter内创建空白`relations.json`，project.json以`relation_inventory`指定它；card项目scaffold也为旧初始化补齐空白清单，保留已有编辑。Agent审阅后填写，不从checks-plan自动复制为“已完整盘点”。已有项目显式补充清单后再冻结，不重签旧数值结果。

顶层含schema_version=1、reviewer、scope、enumeration_complete（布尔）、source_review、relations。source_review逐项记录所有声明源文件的path/sha256/meaning；目标、等式、不等式、变量域、初末边界、耦合和其他关系分别盘点，无某类时在scope解释。入口及依赖遗漏仍须Agent实质追踪；文件哈希不能证明盘点完整。

没有某类关系时，用`absent_kinds.<kind>`记录reason和source_evidence（格式同关系来源），不能静默跳过。某类既没有关系也没有有依据的缺省说明，输出unreviewed_kinds并保持盘点不完整；声明不存在的类别不能同时列出该类关系。

每条关系使用实际项目ID，含：

- kind：objective/equality/inequality/domain/boundary/coupling/other；components为涉及组件ID。
- source_evidence：原项目path/sha256/first_line/last_line/meaning，不能以适配器自身代码替代被审来源。
- required_scope：从规范和原始数据独立确定的节点、设备、时段、场景和边界，不沿用被审循环范围。
- implementation：NOT_IMPLEMENTED/IMPLEMENTED；execution：NOT_EXECUTED/EXECUTED；coverage：NOT_ASSESSED/PARTIAL/COMPLETE。
- result：NOT_ASSESSED/PASS/VIOLATION/DATA_INSUFFICIENT/NOT_APPLICABLE。未覆盖记录reason；排除须reason和独立verification_evidence；完整覆盖须已执行、PASS或VIOLATION及证据。
- verification_evidence：项目内adapter目录外的path/sha256。实际数据、断言、报告和语义核对形式由项目决定。
- card_links：可为空；有关联时记录component/pattern_id/relation。没有card的目标、耦合和边界仍在清单内。所选card验收中的项目关系ID必须关联到相应清单项并已执行。

```bash
python /path/to/skill/scripts/psaudit_relation_inventory.py --project /path/to/model
```

输出逐类数量、已检查、明确排除、未覆盖、缺源审阅、缺组件和未关联card关系。未完成盘点或仍有缺口保持PARTIAL；可冻结部分审计证据，但不能称模型全面通过。全部关系检查发现VIOLATION时仍可叫“已覆盖”，不能叫“模型正确”。完整状态仅为COMPLETE_FOR_DECLARED_SCOPE，数学正确性独立判断。

冻结记录保存这份摘要及源/验证证据依赖；变化后STALE。旧绑定没有清单时为NOT_ASSESSED，不自动继承完整覆盖。Agent写报告时保留无card及未完成项，不能用“匹配组件数”作为覆盖分母；enumeration_complete=false时不报整模型覆盖百分比。
