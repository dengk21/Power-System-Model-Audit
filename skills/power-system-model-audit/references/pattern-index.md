# 约束模式索引

本索引由知识工具生成。状态、来源新鲜度和本次适用性分别判断；LOCAL_TESTED不等于完整模型已验证。

| 模式 | 模型族 | 提取/验证/复用 | 关键词 |
| --- | --- | --- | --- |
| [凹分段流量曲线的损失上图](patterns/communication-concave-loss/card.md) | communication | CODE_OBSERVED / LOCAL_TESTED / CONDITIONAL | 通信, 凹函数, PWL, SOS2, epigraph, 流量损失 |
| [无损有功发用电平衡](patterns/ed-power-balance/card.md) | ED/DCOPF | RECONCILED / LOCAL_TESTED / CONDITIONAL | ED, 经济调度, 功率平衡, balance |
| [逐车位置与稀疏移动弧守恒](patterns/mobile-arc-conservation/card.md) | mobile | CODE_OBSERVED / LOCAL_TESTED / CONDITIONAL | 移动资源, MESS, CREW, IC, mobile, 弧守恒 |
| [跨节点移动的端点通信门控](patterns/mobile-communication-endpoints/card.md) | mobile-communication | CODE_OBSERVED / LOCAL_TESTED / CONDITIONAL | 通信, 端点, 自环, endpoint, Case1 |
| [行驶与储能运行共享调度时段](patterns/mobile-travel-operation/card.md) | mobile-storage | CODE_OBSERVED / LOCAL_TESTED / CONDITIONAL | MESS, 移动储能, 行驶, travel, 运行时间 |
| [并行维修累计与完成上报](patterns/repair-cumulative-progress/card.md) | restoration | CODE_OBSERVED / LOCAL_TESTED / CONDITIONAL | 抢修, 维修车, CREW, repair, 并行 |
| [储能能量递推与T+1边界](patterns/storage-energy/card.md) | storage | CODE_OBSERVED / LOCAL_TESTED / CONDITIONAL | storage, 储能, SOC, 能量, 效率, T+1 |
| [机组最小开停机时间窗口](patterns/uc-minimum-duration/card.md) | UC | RECONCILED / LOCAL_TESTED / CONDITIONAL | UC, 机组组合, 最小开机, minimum time |

学习、审计和更新方法见[学习流程](learning-workflow.md)。
