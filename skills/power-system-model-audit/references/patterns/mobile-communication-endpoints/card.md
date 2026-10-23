# 跨节点移动的端点通信门控

## 数学形式

$$
d_{k,i,t}\le C_{i,t},\quad a_{k,j,t}\le C_{j,t},\quad a_{k,j,t}\le C_{j,t+1}
$$

## 适用条件

仅汇总非自环弧；仅MESS/CREW且通信移动开关开启时适用。

## 变体与不适用情形

沿途覆盖、仅到达时覆盖、全时段位置门控是不同模式，不混用。

## 实现映射与边界

来源build:365–402；不得把旧版所有位置无条件门控重新学成现行规则。

## 常见陷阱

Case1关闭移动门控但不关闭维修上报；IC自身移动不受本组约束。

## 独立依据与验证范围

三个必要端点/时间条件逐一检查；自环对应零跨节点流。局部数值测试见同目录cases.json，覆盖正常、违例、等价表示、不适用和缺数据。等价fixture检验数值表示/单位/索引等价，不证明任意符号实现等价。状态见record.json；LOCAL_TESTED不表示原模型已整体求解或物理假设已普遍成立。

## 来源

- `resilience:funs/resilience_build_and_solve.m`（哈希见同目录record.json）
- `resilience:Case1.m`（哈希见同目录record.json）
- `resilience:Case2.m`（哈希见同目录record.json）
