# 来源更新与学习效果

## 来源更新

```bash
python3 skills/power-system-model-audit/scripts/psaudit_knowledge.py update \
  --source resilience=/absolute/path/to/Power-Communication-Network-Resilience-Model \
  --source course=/absolute/path/to/course-project \
  --output outputs/knowledge-update
```

工具按各模式的依赖文件检测变化，生成 `relearning-plan.json`、`knowledge-results.json`、`audit_brief.md`、`audit_report.md`。STALE即时撤销本次参考资格，不改旧记录的哈希；同一依赖文件中的多个模式会保守地一起进入复核。当前没有基于AST的函数级变化定位，可能需要人工/Agent进一步缩小范围。

Agent重新读取变更、核查公式/条件、补回归，生成新候选。相同ID递增版本并说明实质变化；不同数学假设优先保留新变体ID。修订登记示例：

```bash
python3 skills/power-system-model-audit/scripts/psaudit_knowledge.py register \
  --candidate /absolute/path/to/reviewed-v2 \
  --source resilience=/absolute/path/to/updated-model \
  --expected-record-sha PREVIOUS_RECORD_SHA256
```

工具拒绝旧版本冲突，先将旧card/record/cases原字节保存到 `references/learning-history/`。单纯刷新来源哈希没有完成语义复核；登记器能检查版本、依据字段和fixture，不能机械证明这些字段的语义真实性。

## 学习效果评测

局部回归验证数值关系和知识管理行为。要判断学习是否改善审计，需在未用于整理卡片的新模型/留出变体上比较学习前后：问题检出、误报、归因、证据充分性和成本。保留失败及误报案例作为反例；不能把现有fixture通过率当成泛化准确率。当前尚无新增留出集效果结论。

项目内先固定留出模型、已知问题和判分规则，再分别运行不加载新card及加载新card的审计，保存两份原始报告、版本和耗时，人工/独立依据核对TP/FP/FN及归因。用过的模型不再作为后续新知识的盲测集；没有这类比较时明确“学习效果未评测”，不因工具回归通过填写提高百分比。


## 本地维护与同步

```bash
python3 skills/power-system-model-audit/scripts/psaudit_knowledge.py validate
python3 skills/power-system-model-audit/scripts/test_psaudit_knowledge.py
python3 skills/power-system-model-audit/scripts/test_psaudit_learning_policy.py
python3 tools/refresh_manifests.py
python3 tools/verify_package.py
python3 tools/sync_workspace_skill.py --mirror /absolute/path/to/course-project/skills/power-system-model-audit
```

同步器拒绝覆盖同步副本中的独立改动。移出旧资源需显式`--retire-managed`，只删除与上次同步哈希一致的已管理文件；项目适配器先独立迁移保存。首次接管旧副本可用之前的 `docs/source-manifest.json` 作为 `--baseline`；后续依靠本地同步标记校验。新增或修订资源后重建发布文件清单再运行包校验；无需在每次普通审计中改写知识或运行全量测试。
