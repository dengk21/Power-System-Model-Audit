# 独立检查器适配契约

通用层负责方法、证据状态、残差和报告原则；适配层负责结果读取、可信集合/参数、独立公式、物理重建与源码映射；运行层保存真实结果与版本。暂不设计跨模型外部 JSON/统一结果交换接口，允许内部 MATLAB struct。

现有数值工具使用 MATLAB。其他建模语言仍使用相同审计方法；可将数值结果交给 MATLAB 适配器，或在运行环境不可用时实现并固定相同证据契约的本地检查后端，每个实例维护一个主验证器，避免两套公式漂移。不因非 MATLAB 实现拒绝静态审计。

## 接入流程

1. 先对文字、活动代码和适用物理关系做双向审查，区分原始规范、当前数值基线和候选修正/补全。从已核查的参考整理变量、单位、索引和条件，列全部ID；原文错误/歧义不得默认为真值，按math-model-review.md处理。
2. 明确输入/输出读取方法，记录源码/参数/规范哈希、状态、solver/版本、场景和数值变量，核对版本。
3. 独立计算关系两侧。不得将代码 H、效率组合、活动循环集合或限额直接当真值；代码可定位变量，不能自动生成参考公式。
4. 使用 `psaudit_check_relations` 聚合关系；先验证维度/单位。拓扑与设备重建放在适配器，不塞入通用内核。
5. 手算测试正常、已知违例、首末边界、缺失/非有限、无解和未激活情况，再运行全部真实入口。故障注入用隔离副本，检查是否有冗余等价约束；手算不冒充优化结果。
6. 固定版本再审计，新输入可开发新适配器，不随审计结论改变验证逻辑。

每个参考关系记录来源/推导、适用性、确认或争议状态；文档补全先作为代码观察草案，独立核查后注明声明假设下成立，不能因补全来自代码就证明原代码正确。核实规范错误后可开发新版本，但保留原版结果与变更记录，不能修改旧结果哈希。

结果包装应保留活动求解入口和内部依赖；禁止输出覆盖时不能同时破坏同一脚本的save→load checkpoint。三维YALMIP结果须支持ndsdpvar，serialized旧对象的变量ID不能当当前解，优先用已保存数值。核对截取后实际optimize是否仍在、运行控制是否匹配原空格/换行，包装器故障不归咎原模型。MATLAB嵌套函数避免用临时关系struct覆盖外层被审结果。

近似/代理检查必须重建实际预测，核特征顺序、域、符号及Big-M×整数容差；内部epigraph变量通过不证明用于调度的函数保守。主/子问题报告有效界时，使用与目标方向一致的solver bound，不能直接把incumbent当精确LB/UB。原图也属于数学规范，单位/基准未给时并列条件参考。

严重性与归因分离：数值内核只给PASS/VIOLATION/DATA_INSUFFICIENT/NOT_APPLICABLE，模型复核另给MATHEMATICAL_MODEL/IMPLEMENTATION/BOTH/DOCUMENTATION_GAP等来源。`confirmed=true`只能用于当前参考版本已核查且不存在已知未解决数学矛盾的情形，不能仅凭用户曾确认原文而忽略新证据。

## 执行模式与诊断缓存

| 模式 | 行为 | 缺失证据 |
| --- | --- | --- |
| replay（默认） | 读取结果、匹配的诊断缓存及确定性公式验算；不调用optimize、runpf或捕获入口 | DATA_INSUFFICIENT，不自动求解 |
| diagnose | 单独执行独立反例/参考计算；必须给maxActions、singleSeconds、totalSeconds | 预算不足或失败仍报告缺失，不转为通过 |
| capture | 捕获原入口的真实计算，保留原solver；按案例次数/时限契约执行 | 记录原执行状态，禁止覆盖真实结果 |

`psaudit_execution_context`门控回调模式、动作数量及累计耗时；诊断动作数不混写成原优化求解次数。LP回调把剩余预算传入原solver的TimeLimit。MATPOWER runpf没有TimeLimit，当前记录实际耗时及超限状态，超限后停止后续动作；它不是硬进程超时保证。

`psaudit_read_diagnostic`只重放带binding的缓存：绑定原结果、源码、输入、参考、诊断计算与缓存工具版本。旧无绑定缓存保留历史用途，不能事后简单补上当前哈希当作当前证据。缓存缺失或不符时replay不执行回调；diagnose写新文件，不覆盖不匹配的旧缓存。

课程validate默认replay；第三参数可设mode、budget、evidenceDirectory、diagnosticDirectory，将原始证据与新派生产物分开。原入口capture与validate分API；reuseFitFile改变原执行流程时必须显式标记diagnose。其他后端沿用同样模式约束，但不凭方法兼容声明已实现其超时机制。

## 内部关系接口

`items` 为 struct 数组，各项：`id`, `actual`, `expected`, `sense`（eq/le/ge）, `unit`, `absTol`, `relTol`；可选 `scale`, `mask`。actual 为实数数组；expected/scale 只允许显式标量扩展或同形，拒绝隐式行列广播；mask 为同形 logical，表示规范的适用集合，不从源码现有循环抄出。

输出 struct：status、maxResidual、positionResidual、tolerance、count、position、actual、expected、unit、detail。内核不自行决定 ERROR，报告层结合规范确认、provenance 和源码定级。maxResidual 为全适用集合最大残差；有违例时 position 是最严重违例，positionResidual/tolerance/actual/expected 都属于该位置。

`psaudit_evaluate_witnesses`接受独立referenceItems与已审阅implementationItems，输出双方接受/拒绝/未知及OVERRESTRICTION、UNDERRESTRICTION、NO_WITNESS_FOUND或DATA_INSUFFICIENT。必须给范围、来源、赋值、条件、依据与源码位置。FULL_MODEL还要求完整关系ID集合、真实结果文件/哈希及provenanceFiles（field/path/hash）；脚本读取MAT中的r核对有效解、solver状态和至少源码/参考哈希，参数文件也应纳入provenanceFiles。其他后端须在适配器提供对应内部证据记录；局部手算只使用LOCAL_RELATIONS。未知/缺失不能被其他违规掩盖，NO_WITNESS_FOUND不证明等价。

`psaudit_write_audit_report`接收内部document struct：entries、findings、witnesses、execution、notes、links及可选versions；只从这些输入计算汇总和填表。Agent提供经审阅清单/实文，案例适配器提供变量和参数映射，不在渲染器写死日期、错误数量、当前解通过结论或课程解释。

`psaudit_reconstruct_storage` 按单步自放电 rho 与 Δt 重建 Ehat；每小时自放电、SOC 等不同定义由适配器依独立规范先转换。

## 实现范围

新增[系数核查与语义验收](semantic-verification.md)规定仿射系数块、冻结关系形状/容差和真实结果绑定。新修复优先调用`psaudit_validate_semantic_candidate`从实际证据派生旧门控标志；旧`psaudit_repair_gate`只验证传入证据组合，不负责读取结果。`psaudit_compare_affine`可检出未激活系数差异，但须审阅单位、索引和等价实现，不能把任意表示差异判代码错误。

可执行通用关系内核与储能轨迹工具；HW4 是首个完整 ED/DCOPF 适配器，HW5新增四入口UC适配器，包含独立事件重建、当期起计的持续窗口和条件性周期爬坡。其他族已有检查路由和接入契约，完整数值适配器需依新输入开发验证。通用手算只验证数值原语，不证明每个完整模型已验证。
