# 移动资源约束：当前实际代码参考

来源：`Power-Communication-Network-Resilience-Model`，2026-10-22读取快照。按用户要求，实际入口、配置、参数加载后的活动代码优先于TeX、注释和旧结果。源码文件哈希见[来源清单](resilience-source-map.json)。本页是代码约束的数学整理，供选择检查项和编写新适配器；没有新增完整模型数值适配器，也没有重新求解或证明原模型正确。

## 入口、集合与变量

调用链：`Case1.m`—`Case5.m` → `funs/run_resilience_case.m` → `resilience_load_base.m` → `resilience_build_and_solve.m`。后者本页简称 `build`。正式场景均为 `comm_objective_mode='concave_pwl'`、6断点。

| 场景 | MESS移动 | IC移动 | CREW移动 | 跨节点移动通信依赖 |
| --- | --- | --- | --- | --- |
| Case1 | 是 | 是 | 是 | 关闭；维修完成上报仍需通信 |
| Case2 | 是 | 是 | 是 | 开启 |
| Case3 | 是 | 否 | 是 | 开启 |
| Case4 | 否 | 是 | 是 | 开启 |
| Case5 | 否 | 否 | 是 | 开启 |

位置集合：MESS只能停靠电力母线；CREW和IC可停靠母线及道路中点。道路中点索引为 `num.bus + GeoId`，不等同电力支路号，必须通过 `branch_GEO.Branch` 查表。`num.tau=1h`；位置有T个时刻、移动弧有T−1个间隔、MESS能量有T+1个边界。kW×h=kWh。

记资源类型r、车辆k、位置i、时刻t；`state_r` 对应二元位置 $x^r_{k,i,t}$，`move_r` 对应连续弧变量 $y^r_{k,a,t}\in[0,1]$。移动关闭时不创建 `move_r`。

## M_ARCS：由预计算数据生成稀疏可达弧

来源：`build:697–721`；`funs/GIS_trafficData_Gen.m`。

$$
\theta_{ij}=\min_{p:D_{ijp}\ge0.5}T_{ijp},\qquad
\mathcal A=\{(i,j):\theta_{ij}<\infty\}.
$$

每对端点仅保留一条弧及最短时间；要求每个位置存在自环。源交通生成器以距离/速度累计行驶时间，并只保存一步内可达路径。审查时核实加载的D/T与当前步长一致，不能只检查生成器而忽略实际加载的MAT。

这里不检查沿途节点通信，也没有路径容量/拥堵约束，因此不能把旧的五维 `path(k,i,j,p,t)` 形式当成当前实现。若新模型加入途中约束，最短路径压缩须重新核实。

## M_POSITION / M_INITIAL：唯一位置与逐车冻结

来源：`build:285–300,333–345,609–621,724–741`。

$$
\sum_{i\in\mathcal N_r}x^r_{k,i,t}=1,\qquad x^r_{k,i,t}\in\{0,1\}.
$$

`expand_initial_state`将位置计数按位置编号展开为逐车one-hot矩阵 $X^{r,0}$，拒绝负数、非整数或总数不符的输入。移动开启时，$X^r_t=X^{r,0}$ 在 $t=1,\ldots,T_{em}+1$ 成立；关闭时在全部时刻成立。不是只固定车辆总数，也不是旧版仅固定各位置汇总数量。

## M_FLOW：起点和终点守恒

来源：`build:299–314,344–359,620–631`。

$$
\sum_{a:\operatorname{from}(a)=i}y^r_{k,a,t}=x^r_{k,i,t},\qquad
\sum_{a:\operatorname{to}(a)=j}y^r_{k,a,t}=x^r_{k,j,t+1},\quad t=1,\ldots,T-1.
$$

代码使用 `B_from/B_to` 的矩阵乘法实现。弧为连续变量，但每对端点只有一条弧；在二元one-hot起终点条件下，选定端点间弧的流量为1。不能仅因 `move` 使用 `sdpvar` 就报告车辆分裂。该解释依赖当前唯一端点弧结构。

## M_TRAVEL_OPERATION：行驶与储能功率共用时段

来源：`build:310–322,355–363`。

$$
h^r_{k,t}=\sum_a\theta_a y^r_{k,a,t}.
$$

固定资源的h置零。CREW满足 $h^{CREW}_{k,t}\le\Delta t$。MESS满足

$$
h^{MESS}_{k,t}+\frac{\Delta t}{\bar P^{MESS}}
\sum_i(p^{ch}_{k,i,t}+p^{dis}_{k,i,t})\le\Delta t,\quad t<T.
$$

功率为该调度间隔的平均功率，额定功率比对应等效作业时长。IC没有单独的行驶时间不等式，依靠预计算可达弧限制。不能把MESS的功率—行驶耦合误加给IC。

## M_COMM_ENDPOINTS：跨节点移动的功能性通信依赖

来源：`build:365–402`。仅当 `enforce_comm_dependency=true`，且相应资源移动开启时，对MESS和CREW启用。定义仅汇总非自环弧的出发量d和到达量a：

$$
d_{k,i,t}=\sum_{a:\mathrm{from}(a)=i,\,\mathrm{from}(a)\ne\mathrm{to}(a)}y_{k,a,t},\qquad
a_{k,j,t}=\sum_{a:\mathrm{to}(a)=j,\,\mathrm{from}(a)\ne\mathrm{to}(a)}y_{k,a,t}.
$$

$$
d_{k,i,t}\le C_{i,t},\qquad a_{k,j,t}\le C_{j,t},\qquad a_{k,j,t}\le C_{j,t+1}.
$$

出发地在t覆盖；目的地在t和t+1均覆盖。自环停留豁免，不要求途中覆盖；IC自身移动不受本组约束。Case1只关闭这一组，仍保留通信功耗、覆盖及维修完成上报。不可沿用旧版 `state(:,:,t+1)<=C(:,:,t)` 的无条件位置门控。

## M_MESS_POWER / M_MESS_ENERGY：功率门控与全时域能量

来源：`build:278–283,324–331,576–580`。

$$
0\le p^{ch/dis}_{k,i,t}\le\bar P^{MESS}x^{MESS}_{k,i,t},\qquad
\sum_i(p^{ch}_{k,i,t}+p^{dis}_{k,i,t})\le\bar P^{MESS}.
$$

$$
E_{k,1}=\bar E,\quad
E_{k,t+1}=E_{k,t}+\eta\Delta t\sum_i p^{ch}_{k,i,t}
-\frac{\Delta t}{\eta}\sum_i p^{dis}_{k,i,t},\quad t=1,\ldots,T,
\qquad 0\le E_{k,t}\le\bar E.
$$

应急期 $t\le T_{em}$ 充放电均为零。当前能量包含末时段功率，不再把末时段充放电固定为零；未要求末能量回到初值。功率和上界不是严格充放电互斥，微小目标惩罚也不是互斥约束。无MESS无功变量；当前参数生成器设安装时间为0，活动模型未加入安装计时或行驶耗电关系，不能从旧TeX补成已实现功能。

## M_CREW_PROGRESS / M_REPAIR_UPDATE：维修累计与通信上报

来源：`build:416–440`。故障支路l对应维修位置g(l)，$u_{l,t}$为线路可用性，R为 `CREW.repairTime`，$H_{max}=K_{CREW}(T-1)\Delta t$：

$$
H_{l,t}=\Delta t\sum_{q=1}^{t-1}\sum_k x^{CREW}_{k,g(l),q},\quad
u_{l,1}=0,
$$

$$
R u_{l,t}\le H_{l,t}\le R-\Delta t+(H_{max}-R+\Delta t)u_{l,t},
\quad u_{l,t}\ge u_{l,t-1},\quad
u_{l,t}-u_{l,t-1}\le C_{g(l),t-1}.
$$

无故障支路可用性恒为1。累计量来自过去位置状态，允许多车并行、间断累计；没有单独维修作业变量，也没有在H中扣除行驶时间。按活动表达式读取，不将其改写为连续作业、独占作业或“自环弧工时”。阈值间隔使用Δt，迁移到非整步长维修需求前须核实离散对齐。

完成状态上升沿必须在t−1获得维修点通信确认，这条在Case1也开启。累计达到阈值但无法上报时，模型可能通过其他调度改变累计过程；不能把本组解读成“已完成后可无限延迟上报”。

## 使用与输出

新项目逐项确认位置集合、逐车身份、时间边界、交通数据、移动开关和通信开关，再选择本页关系。上面的代码形式是来源模型的参考实例，不是所有移动资源问题必须满足的统一规范。结合[电力—通信恢复约束](restoration-coupling-constraints.md)审查，并按Skill要求输出极简简报与专业报告。
