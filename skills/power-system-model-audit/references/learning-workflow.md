# 知识检索与学习路由

知识保存在文件、来源绑定、局部测试与版本记录中，不训练底层模型。这里只说明发现与选定；其他阶段按任务读取，不顺序展开全部文档。

| 任务 | 文档 |
| --- | --- |
| 普通审计识别经典/非经典、询问与偏好 | [识别与决策](learning-policy.md) |
| 已获准提取、比较等价关系和变体 | [提取与去重](learning-extraction.md) |
| 候选独立验证、状态与版本登记 | [验证与登记](learning-registration.md) |
| 来源变化、同步或留出效果评测 | [维护与评测](learning-maintenance.md) |

## 自动学习策略

原有章节入口保留供旧链接定位；实际规则在[识别与决策](learning-policy.md)。普通审计只加载该阶段，不先读取登记与维护细节。

## 检索与选定

1. 用关键词查询元数据，或读取小型[模式索引](pattern-index.md)。检索只返回候选摘要、条件及正文路径，不读取card正文、不加载检查器或运行fixture、不核验来源。
2. 根据实际项目结构和上下文选择少量ID；缺条件先补信息，冲突则排除。只打开所选card正文及必要独立依据。
3. 显式`verify --pattern ID`核对所选知识包、来源和fixture。可重复指定ID；条件缺失/不匹配或复用状态禁止时跳过fixture，保持未验证/不可参考，不把未执行当通过。
4. 需要项目数值验算时，再进入[card专项检查](card-driven-checks.md)。card局部验证不代替项目映射、耦合与全索引检查。

```bash
python3 /path/to/skill/scripts/psaudit_knowledge.py search "储能" --limit 3

python3 /path/to/skill/scripts/psaudit_knowledge.py verify --pattern storage-energy \
  --source resilience=/path/to/source-project \
  --context energy_state=T+1 --context self_discharge=none
```

search始终标记METADATA_ONLY、CANDIDATE_METADATA_ONLY及NOT_RUN；即使record写着CONDITIONAL也不授予本次参考资格。verify才检查实际绑定与来源；SOURCE_UNAVAILABLE保持缺来源，STALE/争议/退役不能确认错误。项目独立依据的处理见专项检查文档。

检索可用每张card旁的`discovery.json`（schema_version=1、aliases/relation_tags/families文本数组）。例如节点负荷、节点净注入、KCL与基尔霍夫电流定律可找到同一card；matched_terms解释命中原因。此文件仅帮助发现，不属于数学依据或项目执行依赖，改别名不重签数学record；没有此文件的card仍按原元数据检索。新card自行添加发现元数据，无集中领域注册表。

`--family dcopf --relation nodal_balance`按模型族和关系标签组合筛选；同一字段重复参数取并集，不同字段取交集。`--scope-filter compatible`默认排除已知条件冲突但保留缺条件候选；match只保留条件齐全匹配，any用于明确查看全部候选。筛选不能证明适用性。

verify默认只输出所选card的摘要；`--verbose`展开局部fixture，`--output`保存所选知识检查记录。`validate`是显式全库回归，维护时使用；`inspect`/`update`保留已有功能，可用`--pattern ID`缩小范围。不要在普通检索后默认执行validate。

重复验证可按[局部fixture缓存](fixture-cache.md)显式使用`--cache-dir`。缓存只复用数学fixture结果，来源及条件仍每次核查，项目数值通过结论不缓存；validate/update始终重新执行。

项目采用MATLAB、Python或Julia均由本项目映射；知识工具不解析任意源码或直接生成完整数值适配器，不自动安装后端。旧课程psaudit_run是项目入口。
