# 文件映射与审查重点

五个入口在 HW4 根目录；`case39_ED.m`/`load3996.mat` 为公共参数，`HW4.tex` 为可检索原始数学描述。`generateBwithSlackBus.m` 当前仅出现在注释中，不能误报其逻辑为活动模型。`case39_ED.m` 首行函数名为 case39，文件名不同，需记录实际 MATLAB 加载行为。Flow 的活动 solver 是 COPT（125 行），其他四入口是 Gurobi；不得仅依据报告正文推断所有入口都使用 Gurobi。

| ID | 源码搜索锚点 | 核对重点 |
| --- | --- | --- |
| C_MAP | sparse(gen.busi…); var.Pic == var.Pg - Pd | 31 节点多机组、var.Pg 被表达式覆盖，声明未使用不等于遗漏 |
| C_BAL | sum(var.Pic) == zeros(1,num.T) | 每时段求和轴，结合 C_MAP 可等价于系统发用电平衡 |
| C_NET | makeBdc; Bnode; Bline; H; branchPF | taps、status、slack、标幺/MW、并联线路及平衡注入等价性 |
| C_FLOW | branch.Pmax; branch.Pmin; branchPF >= / <= | Flow 是双向 0.96 限额；上下限均需活动实现 |
| C_GEN | var.Pb 或 squeeze(sum(var.Pb,2)) | 线性入口是 I×T，其他是 I×3×T；聚合后约束所有机组 |
| C_RAMP | deltaPb; gen.Ru; gen.Rd; num.tau | 首末转换、两侧符号、MW/h→每步 MW、Ramp β 与正文歧义 |
| C_SEG | Psegmin; Psegmax; segcost; repmat | q 三维广播形状、第一段包含 Pmin、斜率排序、凸性 |
| O_COST | optimize(cons,obj…); obj/obj_linear | 真正活动目标、时间系数、常数成本、Quadratic 近似模式 |

先用带行号源码核对，当前快照行号不得当永久映射。`linear.m` 大量分段代码被注释；其他入口存在备用目标和备用约束块。逐个追踪赋值与实际 optimize，检查维度而不是匹配字符串。

可用的区分场景：非恒定相邻负荷暴露爬坡错位；低成本机组逼近上限暴露遗漏；非零成本/不同 Δt 暴露系数；平衡但不对称节点注入检验 H。不预设原 HW4 已有这些故障，不将静态候选写成检出结果。

求解失败后的绘图、图例等可记录执行问题；仅在影响审计/用户请求范围时处理，不扩展成一般代码质量审查。
