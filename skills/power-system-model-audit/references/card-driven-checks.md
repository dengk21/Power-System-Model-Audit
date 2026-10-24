# 从知识card到项目专项检查器

Skill保留通用数值内核、知识card及知识自身的小型回归。项目适配器在新模型中按适用card生成专项关系检查器，由统一内核计算残差。实际节点/机组/场景/时段、变量名称、设备拓扑和求解后端均属于项目。

## 三层职责

1. card：公式、假设、边界、独立依据与`project-checks.json`中的适用模型族、规范输入和关系清单。
2. 项目专项检查器：Agent将规范输入映射到本项目实际变量、参数和结果，在`adapter/checks/`内实现独立公式，返回`items`；不自动安装或调用求解器。
3. 通用数值内核：`psaudit_check_relations`逐元素检查等式/上下界、容差和违规位置；不承担模型识别或变量解释。

card旁`checker.py`只验证`cases.json`中的小型独立fixture，不能当作完整项目验证，也不直接复制为项目MATLAB适配器。

## 识别、匹配与生成

Agent先完整追踪活动入口、有效参数、变量、目标、约束及耦合，建立学习流程规定的`model-assessment.json`。每个组件除了模型族及源码行/哈希证据，可补充：

```json
{
  "id": "battery",
  "family": "storage",
  "context": {"energy_state": "T+1", "self_discharge": "none"},
  "check_bindings": {
    "storage-energy": {
      "energy": "result.E：设备×T+1，MWh；初值来自config.E0",
      "charge": "result.Pch：设备×T，MW",
      "discharge": "result.Pdis：设备×T，MW",
      "eta_c": "config.eta_c：输入侧效率",
      "eta_d": "config.eta_d：输出侧效率",
      "dt_h": "config.dt：h"
    }
  }
}
```

示例省略的`evidence`仍须补齐对应模型族的结构角色。若同一组件的不同card使用不同上下文键值，用`card_context.<pattern-id>`显式补充，不能靠默认值猜测。bindings是审阅记录，不作为可执行表达式求值。

工具先按card的families及元数据找候选；结构未确认、上下文缺失或条件冲突时不加载card正文、检查器和fixture。结构与条件匹配后才完整核对知识包、来源、局部fixture和规范输入映射。仅关键词或模型族名称不能确认适用。未匹配、新耦合和争议关系继续独立审计，不因没有card而跳过。

```bash
python /path/to/skill/scripts/psaudit_project.py init --project /path/to/model

python /path/to/skill/scripts/psaudit_card_checks.py plan \
  --project /path/to/model --assessment /path/to/model/model-assessment.json \
  --source course=/path/to/course --source resilience=/path/to/restoration \
  --output /path/to/model/PowerSystemModelAudit/plans/run-01

python /path/to/skill/scripts/psaudit_card_checks.py scaffold \
  --project /path/to/model \
  --plan /path/to/model/PowerSystemModelAudit/plans/run-01/checks-plan.json
```

按实际card来源提供source映射，不要求无关项目。来源不可用仍可阅读知识，但保持REFERENCE_REVIEW_REQUIRED；缺上下文保持NEEDS_CONTEXT，条件冲突为NOT_APPLICABLE，不生成可执行确认性结论。通过来源和条件核查但缺变量映射时可生成待实现任务，freeze前必须补齐。

新项目没有原始案例时，Agent可在组件的`reference_review.<pattern-id>`单独记录本项目独立依据：`independent_basis=true`、实质`basis`、`reviewer`以及`evidence`（本项目specification文件的path/first_line/last_line/sha256/meaning，role为independent_reference）。工具核验文件和行范围，数学独立性由Agent负责实质审阅。仅原来源SOURCE_UNAVAILABLE、card自身可条件复用且fixture通过、结构/条件匹配时，这份本项目依据可得到PROJECT_REVIEWED_REFERENCE。原card来源状态仍为SOURCE_UNAVAILABLE，不回写为FRESH；已知STALE、争议、退役或测试失败不能以此绕过。本项目依据文件纳入适配器绑定，变化后复核。

scaffold只为适用card生成项目内专项函数骨架、task和`check_all.m`汇集入口。它自动登记本项目实际选中的card文件/版本及相关通用依赖，不登记整个知识库目录。骨架明确抛出CheckNotImplemented；Agent完成公式、独立参考、全索引/形状/单位核对、项目测试及`run_audit→check_all→psaudit_check_relations`集成后才可冻结。

## 维护与验收

新项目还须独立填写[项目关系清单](relation-inventory.md)：scaffold只创建空清单，不以匹配card自动填为完整。所选card的验收关系ID须与清单关联；无card关系及未检查项保留，部分覆盖可保存但不能称全面通过。重复组件的fixture在单次规划内复用，跨阶段可显式采用[局部缓存](fixture-cache.md)，项目数值结论不缓存。

计划的`uncovered_components`在规划阶段保留全部组件，因为尚无数值覆盖证据；`components_without_ready_match`单列没有MATCH的组件，NOT_APPLICABLE、NEEDS_CONTEXT等候选不能隐藏缺口。`relation_tasks`逐条列出card关系，选中不代表实现或执行。项目另建完整关系清单，包括没有card的关系、跨模块耦合、目标、初末边界和离散域；报告分别记录实现、执行、适用索引、验证结论及遗漏，不用“匹配了几个组件”作为覆盖率分母。

实际变量映射必须在项目测试中断言：读取原始结果/参数，核对精确形状、物理单位换算、真实节点/设备ID、支路方向、时段和场景顺序、T/T+1边界。非空的bindings描述只表明映射意图。检验应包含保持总量的节点错位、转置/重排、单位比例和时间偏移反例；同一错误映射被检查器与参考共同复用时，零残差不能证明映射正确。

card计划项目freeze须提供[项目验收证据](project-checker-acceptance.md)。1.1可用[collect](project-adapters.md#自动采集测试运行事实)执行明确的测试命令并生成记录，Agent审阅后直接冻结，不重复填写形状、哈希和控制结果。freeze本身只核对完整性和新鲜度，不执行测试或判断数学语义；采集也不能证明所声明runner必然被调用或物理映射正确。缺执行证据不能宣称已执行。未采用card计划的历史绑定仍仅为依赖绑定，不能继承专项验收资格。

- 新card不修改集中CHECKERS字典；每个card自行声明独立fixture检查器及其依赖。
- 改某card的checker.py只影响依赖该card的验证；修改共享数值原语或加载内核，仍要求真正依赖它的card复核。
- 当前card局部checker采用单文件实现，允许标准库及声明的共享数值原语；新增其他本地依赖时先扩展显式依赖契约，不能用未绑定的辅助模块绕过版本检查。
- 项目绑定只包含选中的card与实际使用文件。无关card新增或修改，不应令既有无关项目适配器失效。
- 重复scaffold保留已实现代码；card版本、task或汇集入口发生变化时拒绝静默覆盖，由Agent审阅后维护并重新冻结。
- 注册新版card时旧card/record/cases及其独立检查器/项目契约一并归档；schema1历史记录保持原字节，不自动替换哈希或冒充当前可执行验证。
- 每个专项检查器须在项目中验证正常、已知违例、等价、不适用、缺数据及边界；知识fixture通过不能代替项目测试。

## 节点负荷检验

ED全网功率平衡card只能检查总量；逐节点检查需要DC节点有功平衡card及实际节点/设备/支路映射。专项检查器对所有节点×时段比较`A'*F`与节点净注入；两节点负荷错配即使全网总量相等，也应形成违规。AC损耗/无功及其他边界需对应的独立关系，不能套用无损DC卡片。

## 项目内的跨模块耦合

具体耦合检查留在项目，例如储能充放电是否以正确符号、单位和节点进入网络平衡，通信可用性是否对应实际设备，维修完成时刻是否控制正确线路。Agent从实际数据流盘点共享变量和生效条件，在项目`checks/`中独立写公式并接入本项目汇集入口；无需Skill提供统一耦合函数或插件接口。

项目负控制应让两个单模块关系分别通过而模块连接错误，例如储能能量与全网总平衡都正确，但充电被分配到错误节点；耦合检查应失败。未实现的耦合关系在项目清单显式标为待检查。只有关系、假设和反例已可独立复用时，才提炼为知识card，项目实现仍留原处。

## 数值环境

MATLAB/Python/Julia及COPT、Gurobi等后端由项目配置和维护。Skill只检查声明的能力、接口、状态和证据，不安装这些环境，不因安装Skill自动换求解器。replay默认零新增求解；换后端后重新记录运行来源，不能继承旧结果验证资格。
