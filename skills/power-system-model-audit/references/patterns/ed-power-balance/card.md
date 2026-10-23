# 无损有功发用电平衡

## 数学形式

$$
\sum_i p_{i,t}=\sum_n D_{n,t}
$$

## 适用条件

所有供电和用电设备必须纳入同一边界；功率单位一致；逐时段核查。

## 变体与不适用情形

含网损、储能、外部交换、基站功耗时需增补相应项；这些不是当前简化fixture。

## 实现映射与边界

来源HW4 math-spec: C_BAL；该规范对网络、成本的其他假设不随本卡片一起确认。

## 常见陷阱

忽略同节点多机组、跨时段加总掩盖某时段违规。

## 独立依据与验证范围

同一系统边界下的有功守恒；100MW发电对应100MW负荷。局部数值测试见同目录cases.json，覆盖正常、违例、等价表示、不适用和缺数据。等价fixture检验数值表示/单位/索引等价，不证明任意符号实现等价。状态见record.json；LOCAL_TESTED不表示原模型已整体求解或物理假设已普遍成立。

## 来源

- `course:PowerSystemModelAudit/adapters/course-v015/examples/hw4/math-spec.md`（哈希见同目录record.json）
