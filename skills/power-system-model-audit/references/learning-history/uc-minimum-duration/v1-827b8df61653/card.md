# 机组最小开停机时间窗口

## 数学形式

$$
\sum_{k=0}^{L^{on}-1}u_{t+k}\ge L^{on}v_t^*,\quad\sum_{k=0}^{L^{off}-1}(1-u_{t+k})\ge L^{off}w_t^*
$$

## 适用条件

动作当期起计；先独立重建实际启停；明确周期状态或给定初态与末边界策略。

## 变体与不适用情形

过去窗口形式、三变量启停、初始剩余义务需另行映射；本fixture非周期仅支持明确truncate。

## 实现映射与边界

来源HW5 C_MIN_ON/OFF；局部fixture不证明所有UC变体等价。

## 常见陷阱

从下一期起计会多约束一期；单个正常解不能排除可行域过紧。

## 独立依据与验证范围

独立状态序列的连续持续期计数；恰好持续L期应被接纳。局部数值测试见同目录cases.json，覆盖正常、违例、等价表示、不适用和缺数据。等价fixture检验数值表示/单位/索引等价，不证明任意符号实现等价。状态见record.json；LOCAL_TESTED不表示原模型已整体求解或物理假设已普遍成立。

## 来源

- `course:skills/power-system-model-audit/examples/hw5/math-spec.md`（哈希见同目录record.json）
