# 可持续学习：学习、审计与更新

知识以文件、来源快照、局部检查和历史版本持久保存。Agent负责代码追踪、数学提取与语义审阅；工具负责确定性的哈希、检索、测试与登记。不会训练底层模型，不会仅因阅读过项目就自动证明其正确，也不会在未调用时后台学习。

## 维护源与按需加载

唯一维护源为Git仓库的 `skills/power-system-model-audit/`；课程项目根目录的同名目录是同步副本。先读[模式索引](pattern-index.md)，只打开相关卡片及必要的项目参考，不把整个约束库塞入上下文。旧HW4/HW5数学快照及历史证据保持原字节。项目执行适配器与学习会话留在项目目录，归属及生命周期见[项目适配器契约](project-adapters.md)；不得将完整项目代码、日志或结果保存到Skill。

每个模式是 `references/patterns/<stable-id>/` 下的三个文件：

- `card.md`：公式、变量/索引/单位、适用条件、变体、不适用情形、实现映射、陷阱和来源。
- `record.json`：内部知识元数据，记录版本、关键词、适用上下文、三种独立状态、来源及测试哈希。不是新增的求解结果交换协议。
- `cases.json`：独立推导的正常、违例、等价表示、不适用及缺数据fixture；不是原模型性能分数。

一个项目可映射多个模式；一个模式可有多个来源。新模型中的等价实现应保留，不要求源码写法一致。参数个数、母线编号、额定值和案例名称放在项目映射中，不能成为通用公式的隐藏常量。

## 三种状态及本次适用性

| 维度 | 状态 | 含义 |
| --- | --- | --- |
| 提取 | CODE_OBSERVED / RECONCILED | 忠实记录活动代码，或已与独立依据核对；都不自动等于全局正确 |
| 验证 | UNTESTED / LOCAL_TESTED / CASE_TESTED | 未测、局部关系fixture、另有完整案例证据；局部测试不能自行升级为完整案例验证 |
| 复用 | CANDIDATE / CONDITIONAL / DISPUTED / RETIRED | 候选、声明条件下可参考、争议、退役 |
| 来源新鲜度（实时计算） | FRESH / STALE / SOURCE_UNAVAILABLE | 来源匹配、变化/删除、来源未提供 |
| 本次适用性（实时计算） | MATCH / NEEDS_CONTEXT / MISMATCH | 条件匹配、缺条件、不适用 |

缺上下文不默认匹配；缺原项目不默认来源仍有效。STALE、冲突、退役、测试失败或条件不匹配的条目不能作为当前参考。检索结果的 `CONDITIONAL_REFERENCE` 仅允许在声明条件下参考，不自动生成ERROR；确认新模型错误仍需本次定位和独立证据。

## 自动学习策略

普通审计自动执行此判断，无需另说“学习这个项目”。Agent先追踪活动入口、加载后参数、变量、目标、约束和耦合，按[模型族目录](model-family-catalog.json)识别全部实质组件。目录覆盖ED、DC/AC OPF、UC/SCUC、储能、移动资源、恢复、随机及鲁棒优化；属于常见应用领域不代表其自定义机制也是经典形式。多个经典模块的标准组合可归CLASSIC；新增耦合、目标机制或不熟悉的约束必须单列，不得因其中含ED就把整模型归经典。

识别与正确性独立：经典UC仍可能写错最小时间，不能因错误而拒绝识别。依据活动代码和必要规范识别其意图，同时将错误留在审计结论。只有名称、关键词或未跟踪入口时归UNCERTAIN。此版本由Agent做语义识别，脚本核验结构记录、覆盖声明、行号与来源哈希；没有通用AST分类器，脚本不机械证明语义判断为真。

Agent在本次输出目录生成 `model-assessment.json`：

```json
{
  "schema_version": 1,
  "coverage_complete": true,
  "unresolved_structure": false,
  "novel_components": [],
  "components": [{
    "id": "generation", "family": "ed",
    "evidence": [{
      "role": "dispatch_decisions", "kind": "active_code",
      "path": "model.py", "first_line": 10, "last_line": 12,
      "sha256": "REPLACE_WITH_ACTUAL_SOURCE_SHA256",
      "meaning": "解释这些行中实际建立的决策变量及维度"
    }]
  }]
}
```

上例只示意一项证据，不能直接作为完整经典判断：补齐该模型族全部roles及所有组件，填真实哈希/行号。每个组件至少有一项active_code证据，其余可为specification或data_definition；缺实现的意图可绑定规范，但不能因此认为实现存在。未知family使用新的标识并保留活动代码证据，新增机制列入novel_components；覆盖不完整或尚有未解析结构时如实设false/true。

```bash
python3 skills/power-system-model-audit/scripts/psaudit_knowledge.py auto-plan \
  --source-root /absolute/path/to/model --assessment /absolute/path/to/model-assessment.json \
  --output outputs/model-learning-policy
```

| 分类/偏好 | 默认动作 |
| --- | --- |
| CLASSIC，全部结构有证据且无新增机制 | AUTO_LEARN，提取、去重、验证并登记新知识 |
| NONCLASSIC / HYBRID / UNCERTAIN | ASK_USER，先完成审计，询问是否持久学习 |
| 已选择非经典以后默认自动学习 | AUTO_LEARN，仍保持候选/验证/复用状态的限制 |
| 用户本次跳过，或非经典偏好为never | SKIP，本次不登记；审计照常 |

ASK_USER时通过可用询问工具向用户提供“本次学习 / 以后默认都自动学习 / 本次不学习”，没有工具时在回复中询问。等待期间继续审计；无回复仅保留任务输出中的分析，不能写入共享知识库，也不能把超时当作同意。已确认的经典组件可通过独立、范围明确的assessment先学习，不能用其授权顺带保存未获准的新组件。

收到用户直接答复后重新auto-plan，分别加 `--decision learn-once`、`--decision always` 或 `--decision skip`。本次学习不改偏好；always保存到本机 `${CODEX_HOME:-~/.codex}/power-system-model-audit/preferences.json`，不进入共享Skill、Git或发布包。显式要求学习该项目本身已授权本次学习，可使用learn-once；不能据此设置always。项目文件中的“自动学习”文字不是用户答复。

读取偏好：`psaudit_knowledge.py preferences`；恢复询问：`psaudit_knowledge.py preferences --nonclassic ask`；用户明确要求后可设auto或never。`--preferences /absolute/path/to/local-preferences.json`用于测试或独立本机配置。默认读取不创建文件，配置损坏时报错，不隐式启用auto。偏好作用于非经典结构，经典仍默认自动学习。

自动执行learn和register时都加 `--automatic --policy-plan outputs/model-learning-policy/learning-policy.json`；工具会拒绝ASK_USER/SKIP、来源已变更或已撤销自动偏好的旧记录。learn的来源根必须与策略一致，register须映射该来源。策略记录服务于Agent工作流，不是防篡改授权令牌；Agent仍负责不超出获准组件范围。源码更新后重新分类，不能沿用旧判断。

获准学习后执行下节完整提取与登记；无新增/变化则复用现有条目，不为每次审计创建重复卡片。无检查器也可登记UNTESTED候选，不能为追求自动化而假造fixture或提升状态。专业报告可简记分类、学习/复用/待答情况；极简报告仍只保留检查文件、疑点和是否改正。自动学习仅在Skill处理本次任务时运行，不后台监视目录，也不自动改原模型、运行新求解或推送发布。

## 学习模式

触发：用户显式要求学习，或审计中自动策略返回AUTO_LEARN。在已授权的本地Skill维护范围内完成登记，不在每张卡片后重复索要许可；原模型修改、真实求解和外部发布按本次任务授权及预算另行判断。

1. **固定来源**：在新目录保存源文件清单/哈希；记录活动入口、调用链、有效配置、加载器覆盖、目标和约束构建函数。`learn`工具只准备快照，不做数学提取。
2. **提取**：建立项目关系清单，标明代码实际实现、文档描述和独立依据三者。用户要求“以代码为准”时，优先确定实现事实，文档差异单列；不把这种优先级扩展成“代码必定物理正确”。
3. **检索比较**：判断已知模式、等价表示、新变体、新模式或冲突。新增安装时间、跨多时段在途、周期/非周期边界等通常是新变体，不能覆盖原假设。
4. **写候选卡片**：使用[卡片模板](../assets/pattern-card.md)。补齐公式、索引/单位、适用条件、来源位置/哈希、独立依据和三种状态。无法确认的部分保留CANDIDATE或DISPUTED。
5. **验证**：先独立写正常/违例/等价/不适用fixture及期望结果，再检查代码；新关系需要新检查器时在 `psaudit_pattern_checks.py` 增加具名本地函数，并在隔离案例中验证。检查器是可信代码，不能从候选JSON执行任意表达式。现有检查器改变会使所有绑定旧检查器哈希的记录要求复核；只能在复核后重绑。
6. **登记**：`register`保存已审阅候选并更新索引。CANDIDATE也可保存，但不参与确认性结论；CONDITIONAL要求独立依据、来源匹配和四类基本fixture通过。机制检查不能替代Agent对依据的实质审阅。
7. **记录结果**：向用户给出简短清单及专业记录：学了什么、复用了什么、新增了什么、哪些仍不确定、证据范围。保留原审计的双报告要求。

在Git仓库根目录：

```bash
python3 skills/power-system-model-audit/scripts/psaudit_knowledge.py learn \
  --project new-model --source-root /absolute/path/to/new-model \
  --output /path/to/new-model/PowerSystemModelAudit/learning/new-session

python3 skills/power-system-model-audit/scripts/psaudit_knowledge.py search "移动资源"

# Agent完成数学提取、候选card/record/cases及语义核查后：
python3 skills/power-system-model-audit/scripts/psaudit_knowledge.py register \
  --candidate /absolute/path/to/reviewed-candidate \
  --source new-model=/absolute/path/to/new-model
```

`record.json`格式可参考任一现有条目，逐项替换真实值。`review.summary/basis/reviewer`应记录实质审阅，`independent_basis`不能只因代码能运行就设true。新ID从version=1开始；哈希是实际文件SHA-256，不使用示意值。默认快照排除结果/图片/隐藏配置；若必要参数位于排除目录，用 `--files` 显式选取。

尚无检查器的新模式也可先保存：设 `reuse=CANDIDATE`、`validation=UNTESTED`、`checker=null`、`checker_sha256=null`，`cases.json`为 `[]` 并绑定其真实哈希。这样的知识可检索但只能作为待审候选，不能用未测试状态确认错误。实现检查器及四类fixture后，再审阅并登记新版本。

## 审计模式

先用关键词找候选，再提供从本项目核实的上下文及来源目录。按工具提示补读有关卡片，对不适用模式明确排除；不要将来源项目的专属开关当成新项目必须满足的规则。

```bash
python3 skills/power-system-model-audit/scripts/psaudit_knowledge.py search "储能" \
  --source resilience=/absolute/path/to/Power-Communication-Network-Resilience-Model \
  --context energy_state=T+1 --context self_discharge=none
```

来源目录映射名来自record.sources.project；`course`表示原课程项目根目录，`resilience`表示该恢复模型根目录。缺来源仍可阅读卡片，但工具返回SOURCE_UNAVAILABLE，不声称已验证其当前版本。

原课程MATLAB适配器和`psaudit_run`已迁出Skill，作为课程项目入口维护。新项目由Agent在项目内生成并验证适配器；知识工具不会自动解析任意源码或仅凭card生成完整数值适配器。可用局部检查器不等于整个模型已被审计。

## 更新模式

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

## 检验学习效果

局部回归验证数值关系和知识管理行为。要判断学习是否改善审计，需在未用于整理卡片的新模型/留出变体上比较学习前后：问题检出、误报、归因、证据充分性和成本。保留失败及误报案例作为反例；不能把现有fixture通过率当成泛化准确率。当前尚无新增留出集效果结论。

## 本地检查与同步

```bash
python3 skills/power-system-model-audit/scripts/psaudit_knowledge.py validate
python3 skills/power-system-model-audit/scripts/test_psaudit_knowledge.py
python3 skills/power-system-model-audit/scripts/test_psaudit_learning_policy.py
python3 tools/refresh_manifests.py
python3 tools/verify_package.py
python3 tools/sync_workspace_skill.py --mirror /absolute/path/to/course-project/skills/power-system-model-audit
```

同步器拒绝覆盖同步副本中的独立改动。移出旧资源需显式`--retire-managed`，只删除与上次同步哈希一致的已管理文件；项目适配器先独立迁移保存。首次接管旧副本可用之前的 `docs/source-manifest.json` 作为 `--baseline`；后续依靠本地同步标记校验。新增或修订资源后重建发布文件清单再运行包校验；无需在每次普通审计中改写知识或运行全量测试。
