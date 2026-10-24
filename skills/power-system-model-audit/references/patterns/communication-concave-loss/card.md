# 凹分段流量曲线的损失上图

## 数学形式

$$
L\ge n(\Phi_{max}-b_j)-m_j P,\quad0\le L\le n\Phi_{max}\quad\forall j
$$

## 适用条件

凹采样曲线、明确有效功率域、本站数量缩放；正权重最小化时L取紧。

## 变体与不适用情形

凸曲线、需要SOS2的非凹关系、负权重和非最优解不能沿用紧性结论。

## 实现映射与边界

来源build:176–234及select_concave_pwl；正式项目六断点，fixture仅用两段验证代数。

## 常见陷阱

约束满足不等于L已取最小；W/kW与bps/Mbps需换算。

## 独立依据与验证范围

max_j[Phi_max-(m_j P+b_j)]=Phi_max-min_j(m_j P+b_j)。局部数值测试见同目录cases.json，覆盖正常、违例、等价表示、不适用和缺数据。等价fixture检验数值表示/单位/索引等价，不证明任意符号实现等价。状态见record.json；LOCAL_TESTED不表示原模型已整体求解或物理假设已普遍成立。

## 来源

- `resilience:funs/resilience_build_and_solve.m`（哈希见同目录record.json）
- `resilience:funs/resilience_select_concave_pwl.m`（哈希见同目录record.json）

## 项目专项检查

根据[项目检查契约](project-checks.json)核实输入、单位、边界和全部适用索引，由Agent在项目适配器内实现专项关系检查。card旁checker.py仅检验独立小型fixture，不直接替代项目检查器。
