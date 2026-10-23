# 配电网恢复与电力—通信耦合：活动代码参考

来源与版本同[移动资源约束](mobile-resource-constraints.md)，文件哈希见[来源清单](resilience-source-map.json)。本页以 `funs/resilience_build_and_solve.m`（简称build）和 `resilience_load_base.m` 的实际表达式为准；TeX不一致时不覆盖代码。本次是约束知识整理，未实现此模型的完整自动数值审计适配器，未重新求解。

## R_LOAD / R_DG：负荷与固定电源

来源：`build:262–276`。D/QD为当前时段负荷，s/qs为削减量，b为节点供电二元状态：

$$
0\le s_{i,t}\le D_{i,t},\quad s_{i,t}\ge D_{i,t}(1-b_{i,t}),\qquad
q^s_{i,t}=\frac{Q_i^0}{P_i^0}s_{i,t}.
$$

失电节点全削减，供电节点仍可部分削减。比例在零有功基准节点须另核实。DEG是非负有功/无功的独立矩形上界；PV满足 $0\le p^{PV}\le\bar p^{PV}$、$q^{PV}=0.2p^{PV}$。活动代码没有完整逆变器容量圆、柴油机启停或燃油动态；不根据TeX、README提到设备就认为EV/小水电已实现。

## R_PQ_BALANCE：含基站用电的有功/无功平衡

来源：`build:489–510`。A=from关联−to关联；G为各设备节点映射：

$$
AP_t=p^{grid}_t+G_{DEG}p^{DEG}_t+G_{PV}p^{PV}_t
+\sum_k(p^{dis}_{k,:,t}-p^{ch}_{k,:,t})-p^{BS,grid}_t-D_t+s_t,
$$

$$
AQ_t=q^{grid}_t+G_{DEG}q^{DEG}_t+G_{PV}q^{PV}_t-QD_t+q^s_t.
$$

这是无损线性配电潮流；本模型含Q，必须检查无功平衡。MESS和基站在该实现中无无功项。电力母线、道路中点、电力支路、道路链路不能共用未经映射的编号。

## R_BRANCH / R_VOLTAGE：可用、闭合、供电及电压降

来源：`build:404–414,469–487`。z为闭合、u为可用：

$$
z_{l,t}\le u_{l,t},\quad z_{l,t}\le b_{f(l),t},\quad z_{l,t}\le b_{to(l),t},\qquad
V_{min}b_{i,t}\le V_{i,t}\le V_{max}.
$$

活动关系是“闭合必须可用”，不是“可用必须闭合”，虽有源码注释反向书写仍以不等式为准。V是kV电压幅值；b=0时仅下界变0，并未强制V=0。

$$
-\bar S z_{l,t}\le P_{l,t},Q_{l,t}\le\bar S z_{l,t},\qquad
\bar S=\sqrt3V_{max}(1.44\,baseA),
$$

$$
\left|V_{to(l),t}-V_{f(l),t}+
(r_lP_{l,t}+x_lQ_{l,t})\frac{baseZ}{1000\,baseKV}\right|
\le M_V(1-z_{l,t}),\quad M_V=2V_{max}.
$$

P/Q分别限幅是矩形，不是 $P^2+Q^2\le\bar S^2$。核实r/x的实际MATPOWER单位及kW、kV换算；不将线性电压幅值式替换成V平方式。当前模型未在主网节点另固定电压参考值，不从常见OPF模板补成既有约束。

## R_GRID_AND：全部故障修复后主网可用

来源：`build:443–466`。F为受损线路集合，d=`U_Dist`、g=`U_MainGrid`：

$$
d_t\le u_{l,t}\ (l\in F),\qquad
d_t\ge\sum_{l\in F}u_{l,t}-|F|+1,\qquad g_t=d_t.
$$

F为空则d恒为1。主网接入节点b≥g，主网有功/无功均在 $[-Mg_t,Mg_t]$，其他节点主网注入为0，M=10⁴。没有外生主网恢复时刻；允许正负交换。全部故障线路可用不等于所有线路闭合，也不等于所有负荷已恢复。

## R_FOREST：单商品流与多源森林

来源：`build:512–526`。s为虚拟根二元变量，Fv为线路虚拟流，fv为节点虚拟注入，$M_s=N_{bus}$：

$$
\sum_l z_{l,t}=\sum_i b_{i,t}-\sum_i s_{i,t},\qquad
A F^v_t=f^v_t-b_t,
$$

$$
-M_s z\le F^v\le M_s z,\qquad -M_s s\le f^v\le M_s s.
$$

根资格上界由DEG/PV所在位置、MESS当前停靠数量及主网g组成；主网接入节点s≥g。每相邻时刻满足 $\sum_l|z_{l,t+1}-z_{l,t}|\le3$。允许多孤岛，不改成单树边数=N−1。图论复核还需核查各受电连通分量、根和实际可用电源；虚拟流不等于有功潮流。

## C_BS_POWER：基础功耗与可调发射功耗分开

来源：`build:528–539,552–574`，加载器 `ensure_bs_power_split`。对宏/微基站类型a，o为开机二元状态：

$$
p^{a,base}_{i,t}=\bar p^{a,base}_i o_{i,t},\qquad
0\le p^{a,var}_{i,t}\le\bar p^{a,var}_i o_{i,t},\qquad
p^{a,comm}=p^{a,base}+p^{a,var}.
$$

总通信功耗为宏+微。无基站及故障基站o=0；可用基站可决定开关，但开启后承担基础功耗。加载器会补齐并重算旧MAT字段，实际生效值优先于参数文件或生成器的旧值。

## C_UPS_FIXED：确定性应急UPS序列

来源：`build:541–549,566–580`，加载器 `ensure_bs_power_split`。对正常基站，$\bar P_i$为宏+微峰值通信输入：

$$
p^{UPS}_{i,t}=\begin{cases}\bar P_i,&t\le T_{em}\\0,&t>T_{em}\end{cases},\quad
E^{UPS}_{i,1}=\bar P_iT_{em}/\eta_{BS},
$$

$$
E^{UPS}_{i,t+1}=E^{UPS}_{i,1}-\frac{\Delta t}{\eta_{BS}}
\sum_{q=1}^{t}p^{UPS}_{i,q},\qquad
p^{BS,grid}_{i,t}=p^{comm}_{i,t}-p^{UPS}_{i,t},\quad
0\le p^{BS,grid}_{i,t}\le\bar P_i b_{i,t}.
$$

源加载器固定Δt=1h，以应急时段数T_em配置容量；迁移到其他Δt时不能省略单位核查。故障基站不放电；无站位置容量为0。UPS及其T+1能量是预先计算的数值数组，不再是充放电优化变量，不能收录旧版“UPS可充电或跨期调度”的约束。代码对能量越界直接抛错。应急期另固定MESS充放电为0。

## C_COVERAGE：宏基站门槛与IC局部覆盖

来源：`build:584–607`；加载器 `ensure_ic_coverage`。IC覆盖矩阵 $H_{ij}=1[dist_{ij}\le R_{IC}+10^{-9}]$，缺省R_IC=1km；有参数时使用实际值。停车点及半径内目标都可覆盖，不是只覆盖停车点。

对宏基站i、目标j，R为预计算 `BS.CommReachable`，s为门槛二元状态，$q=p^{macro,comm}-P^{threshold}_{ij}$，M_BS=100kW，ε=10⁻⁴kW：

$$
s_{ij,t}\le R_{ij},\quad q_{ij,t}\ge-M_{BS}(1-s_{ij,t}),\quad
q_{ij,t}\le-\varepsilon+M_{BS}s_{ij,t}+M_{BS}(1-R_{ij}).
$$

对R=1，达到门槛强制s=1，低于门槛至少ε时s=0；(-ε,0)间隙不允许任取状态，不等同连续阈值函数。不可将ε写成无条件容差。

令 $n^{BS}_{j,t}=\sum_i s_{ij,t}$、$n^{IC}_{j,t}=\sum_{k,i}H_{ij}x^{IC}_{k,i,t}$，c为基站覆盖、C为总覆盖：

$$
\frac{n^{BS}_{j,t}}{N_{bus}+N_{link}}\le c_{j,t}\le n^{BS}_{j,t},\quad
C_{j,t}\le c_{j,t}+n^{IC}_{j,t},\quad C_{j,t}\ge c_{j,t},\quad
C_{j,t}\ge n^{IC}_{j,t}/K_{IC}.
$$

c和C均二元；该形式依赖计数有界且K_IC>0，零通信车需单独适配。微基站影响流量目标和用电，但这里覆盖门槛仅用宏基站功耗。

## O_COMM_PWL：正式六断点流量损失目标

来源：`build:164–243`；`funs/resilience_select_concave_pwl.m`。正式模型使用凹采样曲线的分段弦线，辅助函数校验原点和离散斜率非增，并贪心选择最大低估误差处作为断点。6断点对应5条直线，**不使用SOS2**。

对宏或微类型a、本站数量n、总发射功率 $P^{trx}=1000p^{a,var}/slope_a$（W）：

$$
0\le L^a_{i,t}\le n_i^a\Phi_{max}^a,\quad
L^a_{i,t}\ge n_i^a(\Phi_{max}^a-b^a_j)-m^a_jP^{trx}_{i,t}\quad\forall j,
$$

$$
L^a_{i,t}\ge n_i^a\Phi_{max}^a(1-o_{i,t}).
$$

单位为Mbps；n_macro来自BS.numStations，n_micro再乘每节点微站数。正目标权重下上图约束把L压到最大损失直线。通用推广须保留功率域、凹性、数量缩放及正权重条件，不能换成凸组合/SOS2后声称仍是同一代码形式。

$$
J=\sum_{i,t}w_i s_{i,t}+\omega_\Phi\sum_{i,t}(L^{macro}_{i,t}+L^{micro}_{i,t})
+10^{-6}\left[\sum p^{MESS,ch}+\sum p^{MESS,dis}+\sum p^{DEG}\right],
$$

其中ω_Φ=`comm_flow_weight`×总满发射容量(kW)/总满流量容量(Mbps)，当前正式场景 `comm_flow_weight=10`。活动目标没有显式Δt；当前Δt=1，不把它直接标成任意步长的货币成本。`power_linear`仅是显式选择的历史对照分支，不能代替正式目标。离线排队论和SINR计算不等于优化模型内直接包含完整非线性时延约束。

## 取证与适配边界

需要原始变量和有效参数、场景开关、源版本、求解状态/界/gap。压缩JSON或位置轨迹不能自动代表所有原始变量；结果导出聚合掉的信息应记数据不足。当前求解设置MIPGap=0.005，不把problem=0说成形式化精确最优证明。

迁移到新项目时逐项注明“源代码已有／新项目适用／尚需确认”，并输出简短与专业两份报告。本参考不增加 `psaudit_run` 的caseId，不宣称已重放该项目全部结果或完成真实求解验收。
