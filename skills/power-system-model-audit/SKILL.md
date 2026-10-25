---
name: power-system-model-audit
description: 审计电力系统优化模型，输出简短与专业报告；审计中自动识别经典模型并积累约束，非经典或不确定结构先询问学习偏好，按条件检索验证并版本化更新知识。适用于ED/OPF、UC、储能、移动资源及随机或鲁棒调度。
metadata:
  version: "1.1.2"
---

# Power System Model Audit

中文名称：电力系统优化问题校核与修正Skill。

核查数学模型、活动代码和文字描述，独立验算并归因。审计交付`audit_brief.md`与`audit_report.md`；讨论架构、维护知识或检查绑定时只执行对应任务。

## 共同边界

- 数学说明和代码都可能错误。求解成功、双方一致、残差为零或card匹配，均不能证明整模型正确；候选、实现、执行、覆盖和正确性分开记录。
- Skill只积累知识card、规范、空白模板与通用工具。项目适配器、变量映射、具体耦合公式、测试和结果在项目内生成维护；成熟通用关系再提炼card，不增加固定caseId或通用插件API。
- 数值环境及COPT/Gurobi等后端由项目维护，Skill不安装。默认replay、新增求解预算0；诊断和真实求解另核范围与预算。原始来源、结果和候选修改保持版本可分，不静默覆盖或重签。
- Git仓库的`skills/power-system-model-audit/`是唯一维护源；工作区及安装版为受控副本。知识积累不保存完整项目或本机偏好。

## 按阶段读取

先按请求确定深度，不为常规选择再询问：只看公式/源码用review，要求结果验算用numeric；已有项目直接复用本次仍适用的记录。首次接入只读[项目接入](references/project-adapters.md)：项目配置和关系清单各维护一份，独立依据与映射合并在review.md；静态审阅不建立数值入口。card识别/学习材料仅在对应阶段需要时生成。测试运行事实优先用collect采集并生成验收记录，不手写哈希、耗时和通过统计；数学判断、物理索引含义及完整性仍须审阅。

先判断本次任务和当前阶段，只打开下表对应文档。链接是路由，不是递归阅读清单；不默认读取全部references、card正文、fixture、工具源码或历史版本。

| 当前工作 | 此时读取 | 阶段结果 |
| --- | --- | --- |
| 审计活动入口和关系 | [审计方法](references/audit-workflow.md) | 来源版本、活动组件、完整关系与缺口清单 |
| 普通审计的学习判断 | [识别与决策](references/learning-policy.md)，按需查模型族目录 | AUTO_LEARN / ASK_USER / SKIP及证据 |
| 发现或选择知识card | [知识检索](references/learning-workflow.md#检索与选定) | 候选ID、条件、待补上下文；尚未验证 |
| 获准提取新知识 | [提取与去重](references/learning-extraction.md) | 已有/等价/变体/新模式/冲突及候选 |
| 验证并登记候选 | [验证与登记](references/learning-registration.md) | 独立依据、fixture、知识状态与版本 |
| 新项目接入或局部维护 | [项目适配器](references/project-adapters.md)；采用card时再读[专项检查](references/card-driven-checks.md) | 最小材料、实际映射、自动运行记录及绑定 |
| 数学争议或文字补全 | [数学核查](references/math-model-review.md) | 双向依据、归因及可直接使用的补全实文 |
| 数值执行 | [检查器契约](references/verifier-contract.md)，调用方式查[运行说明](references/running.md) | 全索引残差、数据不足与执行记录 |
| 主动诊断或授权修复 | [诊断与验收](references/diagnostic-repair-loop.md) | 冻结基线、有限候选与验收证据 |
| 写审计报告 | [报告与定级](references/reporting.md) | 共用同一证据的简报与专业报告 |
| 来源更新、知识维护或效果评测 | [维护与评测](references/learning-maintenance.md) | 受影响关系、新版本或留出比较 |

普通审计自动判断是否学习：有证据的经典结构自动学习；非经典、创新耦合或不确定结构按策略询问，未答继续审计但不持久登记。无新增则复用，不后台学习。进入登记时再读取登记规范，不为分类先加载整个学习流程。

领域细节按活动结构选择：[电力检查项](references/power-system-checks.md)；移动资源读[移动约束](references/mobile-resource-constraints.md)，配电网与通信恢复读[恢复耦合](references/restoration-coupling-constraints.md)。这些实例参考仍需核实来源与适用性；历史代码形式不等于独立物理依据。纯有功DC不强加AC无功关系。

阶段间只传递当前来源版本、已选card及条件、关系覆盖、未决问题和证据位置；必要时回看原文，不重复展开全部资料。已有上下文不会因切换阶段自动卸载，此规则控制后续读取。

工具按名称查[目录](references/tool-catalog.md)；能力或历史证据被询及时再读[能力表](references/capabilities.md)和[验证记录](references/validation-records.md)。普通审计不执行全库回归；维护共享工具或明确要求全库检查时才用`validate`。
