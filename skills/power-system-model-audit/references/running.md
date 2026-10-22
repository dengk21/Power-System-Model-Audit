# 统一运行入口 v0.13

公开包说明：本页 `psaudit_run` 为原课程项目分派入口，要求项目根目录存在 `电力系统分析与控制作业/`，并依赖下列历史证据。公开包不附这些输入；独立检查请从仓库根目录执行 `addpath('tools'); run_smoke_tests;`，独立LP使用 `run_semantic_demo`（需Gurobi），不经课程分派入口。环境、安装及外部材料边界见仓库 `docs/PACKAGING.md`。

`psaudit_run(project,caseId,options)`分派已实现适配器；保留原函数用于具体开发。默认 replay，新输出目录必须不存在，不自动挑“最新”证据或新增求解。v0.13 是组织与真实HW5接入版本，语义验收契约沿用v0.12。

## 支持的组合

| caseId | 模式 | 默认证据 | 结果含义 |
| --- | --- | --- | --- |
| hw4 | replay | 项目archive内五份ED/DCOPF结果 | 五入口条件数值核查与跨模型关系；不调用求解器 |
| hw5 | replay | PowerSystemModelAudit/HW5 | 原始四UC入口历史审计；保留原错误/争议 |
| course | replay、diagnose | PowerSystemModelAudit/remaining | 其余31入口与单列诊断；replay读取匹配缓存，缺项不求解 |
| hw5-repair | replay、capture | replay必须显式指定 | M_MINIMUM_WINDOW完整修复的三工况v0.12验收 |
| semantic | replay、capture | replay必须显式指定 | 两机LP机制实验；不是Agent准确率 |

未知案例/模式/选项、replay附带预算、已存在输出目录会在运行前拒绝。`COMPLETED`只表示审计完成，原模型仍可有ERROR/WARNING/DATA；`ACCEPTED`仅指候选在合同声明范围通过。

## 从项目根目录复查真实HW5修复

```matlab
project=pwd;
addpath(fullfile(project,'skills','power-system-model-audit','scripts'));
evidence=fullfile(project,'PowerSystemModelAudit','validation', ...
    'hw5-repair-v012-20261015','run-03');
result=psaudit_run(project,'hw5-repair',struct( ...
    'evidenceDirectory',evidence, ...
    'outputDirectory',fullfile(project,'PowerSystemModelAudit','my-hw5-repair-replay')));
```

`result.status='ACCEPTED'`且`result.solverCalls=0`表示当前绑定版本的修正版三工况重放通过。独立规范、源码或检查器改变时暂缓；旧结果不得重签当前哈希。保存合同中的具名回调必须对应其绑定文件，不能把安装副本或不同版本同名函数默认为同一来源。重放项目证据时优先加载项目维护源。

## 原案例复查

```matlab
result=psaudit_run(project,'hw5',struct('outputDirectory',fullfile(project,'PowerSystemModelAudit','my-hw5-replay')));
result=psaudit_run(project,'hw4',struct('outputDirectory',fullfile(project,'PowerSystemModelAudit','my-hw4-replay')));
result=psaudit_run(project,'course',struct('outputDirectory',fullfile(project,'PowerSystemModelAudit','my-course-replay')));
```

course replay默认从原证据目录读取diagnostics，输出派生产物写入新目录。指定其他缓存时用`diagnosticDirectory`。HW4线性结果仍来自其历史归档，其他四项来自`evidenceDirectory`。

## 新捕获与诊断

```matlab
budget=struct('maxActions',9,'singleSeconds',60,'totalSeconds',360);
result=psaudit_run(project,'hw5-repair',struct('mode','capture','budget',budget, ...
    'outputDirectory',fullfile(project,'PowerSystemModelAudit','my-new-hw5-repair')));
```

该操作真实求解9次完整MIP，候选脚本与TeX在新目录生成，原作业只读。三个独立参考及原版/修正版分别捕获。两个轨迹选择工况用FEASIBILITY，只有原始工况用REFERENCE_OPTIMUM；参见[修复契约](../examples/hw5/repair/math-spec.md)。较小预算允许因不足而停止，不能把未完成当通过。semantic capture沿用已有冻结40次/单次5s/累计60s预算，不接受另设budget。

course diagnose必须提供`maxActions/singleSeconds/totalSeconds`，由原适配器管理动作与缓存。潮流诊断、独立LP和原优化捕获分别计数，`run-summary`动作数不能直接当成全部原模型求解次数。原HW4/HW5的额外捕获仍用各自case API；统一入口不隐式重跑它们。

## 环境与测试

旧结果数值重放依赖MATLAB与相应适配器；HW5新协议成员重建需要YALMIP/MATPOWER，capture另外需要Gurobi。记录本轮实际路径、版本与执行结果，不将方法兼容性写成已执行其他后端。

HW5负控制：`psaudit_hw5_repair_test_replay(evidence,newTestDirectory)`。其派生协议fixture用于测试版本、形状、费用与反例门控，不计为新求解或Agent自主修复。公共内核与各案例已有测试保持适用。
