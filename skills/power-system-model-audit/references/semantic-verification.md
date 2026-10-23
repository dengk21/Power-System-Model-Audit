# 系数核查与语义验收

## 参数出现以后继续检查什么

将规范关系独立写成带索引的算子，再与活动实现比较。每条记录规范来源、参数定义/单位、变量与行索引、实际系数、期望系数、常数、等式或不等式方向。不能用被审矩阵或其派生量生成期望矩阵；共享序列化函数可以，共享公式构造器不能算独立参考。

`psaudit_compare_affine(reference, implementation)`处理`Ax sense b`或目标`Ax+b`。两个描述均含`id/kind/A/b/rowKeys/variableKeys/variableUnits/rowUnits/sense`；参考另含`confirmed=true`、独立依据`basis`和固定`absTol/relTol`。`kind`为`constraint/objective`；方向为`eq/le/ge`，目标用`objective`且必须声明`objectiveSense='min'/'max'`。`A`形状为行数×变量数，`b`为列向量；索引唯一。

工具按行/变量ID对齐，转换已知单位，再规范化约束的正比例缩放、等式符号和上下界翻转。按非零A系数归一，避免大右端常数将系数差异压到绝对容差以下；零系数行另用常数。目标不做比例归一化，因而费用整体乘二仍会检出；目标方向也须一致。支持功率、能量、时间、角度及USD/CNY各自维度；不猜测未知标幺基准、汇率或复合单位。返回系数/常数的残差位置与方向差异，状态为`MATCH/MISMATCH/DATA_INSUFFICIENT/REFERENCE_CONFLICT`。

储能例：`E1-E0-0.25*pch=0`写成`E1-E0-pch=0`，在`pch=0,E1=E0`时两者残差均为零；独立系数比较仍能定位时间步长错误。设备/时段绑定错误也通过列ID及系数比较检查。非仿射乘积、逻辑条件和隐式消元需要专用适配器或推导，不能直接交给该仿射工具证明。

`MISMATCH`是声明表示的差异。先排查辅助变量、冗余约束、条件域和其他活动关系是否使两者等价；已确认同一变量基且独立规范充分时可形成静态错误证据，否则保持疑点或补做见证。有限采样通过不能消除休眠系数差异。

## 语义验收接口

`psaudit_validate_semantic_candidate(contract,candidate)`不求解，从已捕获结果中重建验算。内部MATLAB结构如下：

- `contract.files`：`field/path/hash`清单，必须含`specHash,inputHash,checkerHash,referenceSourceHash`；实际依赖、验证器和数值内核也应绑定。`confirmed=true,unresolvedDefinition=false`表示独立定义已经审阅，不由工具自动建立。
- `contract.reconstruct`：与`checkerHash`对应的具名函数，接收`(parameters,vars,reportedObjective)`，从独立定义返回关系items。匿名函数不作为可绑定检查器。
- `contract.requireOptimal`必须显式为logical；优化修复设true，报告模式为`REFERENCE_OPTIMUM`。仅可行性验收可设false，模式为`FEASIBILITY`，该模式允许次优可行解，不能报告最优修复通过。遗漏模式则暂缓。
- 输入MAT含`scenarios`，每项`id/parameters/relations/objectiveId`，可选`affineReferences`。`relations`逐项固定`id/shape/unit/sense/absTol/relTol`，应在求解前确定。`contract.scenarios`重复同一关系清单，并提供`referenceFile/referenceHash`。
- `candidate`含`sourceFile/sourceHash/evaluateImplementation/runs`；具名`evaluateImplementation`对应候选入口，使用同一活动模型构造器判断参考轨迹成员关系。`runs`逐项为`scenarioId/resultFile/resultHash`；可选`beforeCost`仅用于展示。
- 每个结果MAT含标量`r`：`hasSolution,problem,objective,vars,sourceHash,bindings,evidenceKind,implementationRelations`；`problem`为0（报告最优）或3（有效incumbent），`evidenceKind='SOLVER_RESULT'`。`vars`为完整有限数值数组。绑定仿射参考时还须`affineImplementation`。`implementationRelations`描述捕获时的活动关系全集；捕获器必须将同一个实际送求解器的模型用于序列化与成员检查。示例展示此做法。

验收核对实际文件哈希、具名回调与源码对应、全部冻结工况、关系ID及完整数组形状；拒用局部mask或适配器自选scale，覆盖适配器自报容差。目标必须用捕获的实际费用与独立分项核对。先检查参考轨迹自身满足规范，再检查候选解满足规范，以及候选是否排除了该完整参考轨迹。声明仿射参考时，参考求解模型自身也必须与其一致。`requireOptimal=true`时要求两侧`problem=0`，并用冻结费用容差核对同一规范下的参考最优值；这不是与修复前成本比较，仍依赖参考求解的可信性。

存在可信数值反例即`REJECTED`；其他工况缺证据仍显示`coverageComplete=false`，不能掩盖已确认反例。无反例但证据缺失、定义冲突、仿射差异未解释时为`DEFERRED`；只有全部声明工况与覆盖通过才`ACCEPTED`。该层派生证据后调用旧`psaudit_repair_gate`，保留旧接口兼容历史运行。

成本由10变82可以是补回容量约束的正确修复；成本只变0.9%也可能仍违反容量。不能把变化阈值作为通用正确性判据。`beforeCost`和相对变化是信息字段，非门控输入。

## 信任与范围

哈希验证文件版本一致，不证明文件的生成历史真实，也不阻止有权限的人同时重写MAT及其哈希。`SOLVER_RESULT`是捕获协议，不是密码学执行证明。参考、关系全集、单位、变量映射、实际求解捕获器及依赖闭包必须先审阅；`confirmed`不能替代该工作。具名文件绑定也不自动发现其全部依赖。

通过只适用于冻结工况、独立规范和已声明表示。有限参考成员检查不证明整个可行域一致；solver报告最优不等于验证器证明全局最优。对非凸或近似模型按相应假设解释。当前有通用接口、两机LP集成示例及真实HW5最小时间修复（已迁出Skill的课程项目）；HW5原始工况核对独立参考最优值，两条额外选择的完整参考轨迹使用FEASIBILITY，不能比较受限参考费用与全局最优费用。旧课程适配器没有自动全部迁移到新捕获协议。

系数比较也是容差检验，低于冻结容差的差异可能MATCH。例如A=[1,1e-12]与[1,0]在1e-9绝对容差下不能区分；结合变量范围评估该项贡献，必要时在正式执行前固定更合适的单位、尺度或容差，不能声称检出任意小系数错误。
