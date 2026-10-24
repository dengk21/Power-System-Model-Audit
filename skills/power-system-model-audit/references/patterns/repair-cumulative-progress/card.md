# 并行维修累计与完成上报

## 数学形式

$$
Ru_t\le H_t\le R-\Delta t+(H_{max}-R+\Delta t)u_t,\quad u_t\ge u_{t-1},\quad u_t-u_{t-1}\le C_{g,t-1}
$$

## 适用条件

H是过去位置占用累计车时，允许并行/间断；R与步长离散对齐，Hmax为可信上界。

## 变体与不适用情形

非并行、连续作业、按剩余工时扣除行驶必须另立模式。

## 实现映射与边界

来源build:416–440；阈值与上报共同限制可行调度，不是无约束延迟上报队列。

## 常见陷阱

不能把占位计数擅自解释成自环工作量；旧版分式上界会限制完成后的累计值。

## 独立依据与验证范围

离散阈值真值表：H<R时u=0，H≥R时u=1；上升沿还需通信。局部数值测试见同目录cases.json，覆盖正常、违例、等价表示、不适用和缺数据。等价fixture检验数值表示/单位/索引等价，不证明任意符号实现等价。状态见record.json；LOCAL_TESTED不表示原模型已整体求解或物理假设已普遍成立。

## 来源

- `resilience:funs/resilience_build_and_solve.m`（哈希见同目录record.json）

## 项目专项检查

根据[项目检查契约](project-checks.json)核实输入、单位、边界和全部适用索引，由Agent在项目适配器内实现专项关系检查。card旁checker.py仅检验独立小型fixture，不直接替代项目检查器。
