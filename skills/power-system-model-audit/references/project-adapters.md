# 项目接入与复用（1.1）

Skill保存知识、规范、通用工具和模板；项目保存活动模型的独立审阅、映射、适配器、测试和结果。已有项目先复用，不重建材料；FRESH只表示声明依赖未变，不证明依赖完整或模型正确。

## 按任务准备最小材料

按用户请求直接选择，无需为常规深度选择再询问：只审公式/代码用review；需要数值验算用numeric（init默认）；只有修复验收或card专项冻结才准备验收细节。静态审阅不要求数值入口、运行日志或冻结。

```bash
python /path/to/skill/scripts/psaudit_project.py init --project /path/to/model --profile review
# 之后需要数值验算时，保留原审阅与清单，只增加入口：
python /path/to/skill/scripts/psaudit_project.py enable-numeric --project /path/to/model
# 一开始就需要数值验算：init --project /path/to/model --profile numeric
```

项目默认目录为PowerSystemModelAudit/adapter/。新数值项目只有四份起始材料；review不生成run_audit.m：

| 文件 | 唯一维护的内容 |
| --- | --- |
| project.json | 活动源码/参数source_files、实际使用的skill_files、入口和文档路径；测试辅助文件可列test_files |
| relations.json | reviewer、scope、源码审阅、全部关系及无card缺口；逐关系公式formula、单位unit和独立索引required_scope可在此维护 |
| review.md | 独立依据、适用假设、映射与未决解释，引用关系ID，不再抄写关系清单或运行结果 |
| run_audit.m | numeric阶段才实现：结果读取、独立重建、全索引检查、双报告；初始骨架明确报错 |

采用card时才建立model-assessment.json并读取[专项检查](card-driven-checks.md)。规范输入映射只在assessment的check_bindings维护，review.md引用；checks-plan/task是生成结果，不再手抄一份映射。关系清单仍从源码独立盘点，不能由card任务反推。

旧项目的math-spec.md和mapping.md继续有效，不自动改写。init --profile legacy可建立旧布局。新项目用project.json中的review_document指定合并文档，freeze检查它已完成实质审阅。不要为统一布局改历史MAT、参考字节、路径或哈希。

## 自动采集测试运行事实

先实现项目检查器和测试。采集命令只执行明确给出的本地测试命令，默认不会执行原优化模型；若测试本身调用求解器，仍需符合本次任务的授权和求解预算。--timeout是整个测试进程树的时间限制，不代替求解次数账本。

```bash
python /path/to/skill/scripts/psaudit_project.py collect --project /path/to/model   --runner tests/test_adapter.py --output PowerSystemModelAudit/runs/check-01   --timeout 60 --run python -B tests/test_adapter.py
```

--run及其后面的参数必须放最后。Windows或MATLAB项目可换成已有环境的可执行路径与-batch命令；不使用shell求值。输出目录必须是项目内的新目录，位于adapter和Skill外。测试辅助代码/fixture在project.json.test_files声明；工具不会自动发现所有依赖。

测试将一次实际观察写入环境变量PSAUDIT_FACTS_PATH指向的JSON。结构只用于可选的测试事实采集，不要求改造项目模型接口。最小字段为schema_version=1和checks数组，每个检查器记录：

- function：专项函数名；card项目必须恰好对应全部MATCH任务。
- inputs：以规范输入名为键，记录实际shape、经审阅的unit和index_review。MATLAB可用psaudit_observe(value, unit, indexReview)自动取得精确形状、数量和范围。单位与物理ID含义由项目断言核对，工具不从变量名猜测。
- relations：card_relation、project_relation_ids与实际status（PASS/VIOLATION/DATA_INSUFFICIENT/NOT_APPLICABLE）。非card项目也可用自身关系角色。
- controls：normal、violation、equivalent、inapplicable、missing_data、boundary，每项给actual和expected状态；采集器比较它们，生成passed，不接受只写passed=true代替实际结果。

MATLAB项目在测试末尾调用psaudit_write_facts(checks)即可，它会统一处理单元素/多元素JSON数组和UTF-8文件写入；重复写入已有事实文件会报错。inputs里的观察由psaudit_observe产生，relations和controls来自实际执行的项目测试，不另填一份验收记录。

```matlab
inputs.energy = psaudit_observe(actualE, 'MWh', '设备ID及状态时刻顺序已由项目断言核对');
% 将inputs、已执行relations和actual/expected controls放入checks后：
psaudit_write_facts(checks);
```

完整字段见[验收记录](project-checker-acceptance.md)，证据引用、哈希、通过字段由采集器生成。

采集器保存真实命令、工作目录、UTC开始时间、耗时、退出码、宿主环境、stdout/stderr，以及运行前后源码/适配器/所选工具/声明测试文件快照。失败、超时、缺事实、控制失败或执行中依赖变化时保存execution.json及日志，不产生验收通过记录。成功时生成acceptance.json，reviewer/scope直接读取关系清单。模型关系出现VIOLATION可以被如实记录，不等于控制测试失败。

采集状态COLLECTED_NOT_REVIEWED仅证明这一工具观察到的子进程与数据，不证明所声明runner必然被调用、测试数学独立、实际物理映射正确或全模型已覆盖。项目关系的范围与覆盖仍由审阅确认；collect不自动改关系清单、不提升知识状态，也不把静态疑点改成ERROR。

## 审阅、冻结与重复运行

审阅采集出的实际输入、映射断言、反例和独立数学依据后，直接复用collect返回的test_evidence，不重写acceptance.json：

```bash
python /path/to/skill/scripts/psaudit_project.py freeze --project /path/to/model   --test-evidence PowerSystemModelAudit/runs/check-01/acceptance.json   --review-note "已审阅实际映射、独立依据及正常/负控制；完整模型覆盖另记"
python /path/to/skill/scripts/psaudit_project.py status --project /path/to/model
```

冻结会绑定原始facts、日志、测试入口及所声明测试文件；之后变化即STALE。card项目继续执行[专项验收](project-checker-acceptance.md)，普通项目不因使用采集器自动获得card验收或完整覆盖资格。也兼容现有手工验收记录，不重签旧证据。

STALE时复核受影响关系和测试，以旧bindings.json的SHA-256通过--expected-bindings-sha登记新版本，旧绑定归档；不只刷新哈希。输出放新runs目录，缓存放adapter外的cache目录，均不覆盖原证据。

数值环境由项目维护，Skill不安装或切换MATLAB/COPT/Gurobi等后端。执行项目入口前先检查绑定，MATLAB用which run_audit确认路径；初始骨架不能直接审计。已有项目可以保留自己的布局，具体关系、耦合公式、测试和原始结果不复制进Skill。
