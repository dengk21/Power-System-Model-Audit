# 候选验证与版本登记

| 维度 | 状态 | 含义 |
| --- | --- | --- |
| 提取 | CODE_OBSERVED / RECONCILED | 忠实记录活动代码，或已与独立依据核对；都不自动等于全局正确 |
| 验证 | UNTESTED / LOCAL_TESTED / CASE_TESTED | 未测、局部关系fixture、另有完整案例证据；局部测试不能自行升级为完整案例验证 |
| 复用 | CANDIDATE / CONDITIONAL / DISPUTED / RETIRED | 候选、声明条件下可参考、争议、退役 |
| 来源新鲜度（实时计算） | FRESH / STALE / SOURCE_UNAVAILABLE | 来源匹配、变化/删除、来源未提供 |
| 本次适用性（实时计算） | MATCH / NEEDS_CONTEXT / MISMATCH | 条件匹配、缺条件、不适用 |

缺上下文不默认匹配；缺原项目不默认来源仍有效。STALE、冲突、退役、测试失败或条件不匹配的条目不能作为当前参考。显式验证结果的 `CONDITIONAL_REFERENCE` 仅允许在声明条件下参考，不自动生成ERROR；确认新模型错误仍需本次定位和独立证据。

## 验证与登记

1. **验证**：先独立写正常/违例/等价/不适用fixture及期望结果，再在该card目录实现checker.py的check(data)。record分别绑定本检查器、通用加载器和数值原语；新card不改集中注册字典。只改某card检查器时复核其依赖者，修改共享内核仍复核真正依赖它的card。检查器是经审阅可信代码，JSON仅作数据；固定文件、ID/API与哈希需一致。schema1旧记录可归档追溯，未经显式迁移不冒充当前可执行验证。专项生成方法见[card驱动专项检查](card-driven-checks.md)。
2. **登记**：`register`保存已审阅候选并更新索引。CANDIDATE也可保存，但不参与确认性结论；CONDITIONAL要求独立依据、来源匹配和四类基本fixture通过。机制检查不能替代Agent对依据的实质审阅。
3. **记录结果**：向用户给出简短清单及专业记录：学了什么、复用了什么、新增了什么、哪些仍不确定、证据范围。保留原审计的双报告要求。

在Git仓库根目录：

```bash
# Agent完成数学提取、候选card/record/cases及语义核查后：
python3 skills/power-system-model-audit/scripts/psaudit_knowledge.py register \
  --candidate /absolute/path/to/reviewed-candidate \
  --source new-model=/absolute/path/to/new-model
```

`record.json`格式可参考任一现有条目，逐项替换真实值。`review.summary/basis/reviewer`应记录实质审阅，`independent_basis`不能只因代码能运行就设true。新ID从version=1开始；哈希是实际文件SHA-256，不使用示意值。默认快照排除结果/图片/隐藏配置；若必要参数位于排除目录，用 `--files` 显式选取。

尚无检查器的新模式也可先保存：设 `reuse=CANDIDATE`、`validation=UNTESTED`、`checker=null`、`checker_sha256=null`（项目检查契约仍须提供），`cases.json`为 `[]` 并绑定其真实哈希。这样的知识可检索但只能作为待审候选，不能用未测试状态确认错误。实现检查器及四类fixture后，再审阅并登记新版本。

局部fixture不自动运行完整模型或新求解。维护源只接收知识包，项目代码和证据留项目。
