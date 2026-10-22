# 两机LP：系数核查与真实结果验收

先读[独立规范](math-spec.md)和[语义验收契约](../../references/semantic-verification.md)。本例使用MATLAB与Gurobi，不调用大模型，不修改原作业或历史benchmark。

```matlab
addpath(fullfile(skillRoot,'scripts'));
addpath(fullfile(skillRoot,'examples','semantic'));
psaudit_test_affine;
summary=psaudit_semantic_demo_run(newOutputDirectory);
```

`newOutputDirectory`必须不存在，保留每轮原始记录。固定四个负荷工况10/12/6/2 MW；先捕获4个独立参考，再运行正确、容量过松、小幅错误放宽、费用倍数、容量过紧、错误最大化6个候选，共28次真实LP求解。预算最多40次、单次5秒、累计60秒，求解器实际TimeLimit取剩余预算；账本逐次保存。求解器不可用时不能用手算冒充捕获结果。

正确候选在普通工况费用82，相比遗漏限制时的10增加720%，应接受；容量过松费用10、小幅错误放宽10.09、费用乘二164、过紧91和错误最大化100均应拒绝。四工况分别核对独立关系、费用、参考轨迹成员性、已声明仿射表示和参考最优值。边界工况中休眠表示差异仍单列DEFERRED，其他工况已确认反例足以拒绝整个错误候选。

另有12项元数据/覆盖负控制，涉及不可信参考、未明定义、输入/源码/结果版本、缺失/重复工况、关系缺项、缩小数组形状、放松容差、匿名检查器和目标缺项，均须暂缓；没有额外求解。

输出`semantic-pilot.mat`保存summary/contract/candidates/ledger；`decisions.csv`保存决策和费用；输入、参考和候选原始MAT逐项独立保存。重放不重新求解：

```matlab
saved=load(fullfile(outputDirectory,'semantic-pilot.mat'));
decision=psaudit_validate_semantic_candidate(saved.contract,saved.candidates(1));
```

受保护工具/输入变化后，旧结果应暂缓，须新建输出目录重新捕获；不能只把旧MAT重签当前哈希。此例证明可执行机制，不是Agent端到端性能对照，也没有测量相对ReLoop的准确率优势。
