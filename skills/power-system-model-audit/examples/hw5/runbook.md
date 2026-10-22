# HW5 UC 运行说明

覆盖四个原入口：`basicTask2_UC.m`、`basicTask2_UC_2variable.m`、`basicTask2_UC_starttime.m`、`basicTask2_UC_maxstart.m`。不要将maxstart名称解释成启动次数。使用固定独立规范 `math-spec.md`；数学错误和缺口由经审阅、哈希门控的 `psaudit_hw5_relation_inventory` 归因，数值检查器不把双方一致当正确。

2026-10-15新增：最小开/关机时间已在完整脚本及TeX副本中修复，并接入v0.12真实结果验收。见[修复契约](repair/math-spec.md)、[统一运行命令](../../references/running.md)与[能力边界](../../references/capabilities.md)。本页下文仍描述原始四入口的历史审计，未用候选覆盖原始输入或旧结果；功率周期争议保留。

## 已完成的本轮验证

2026-10-08：四个原模型各真实求解一次，Gurobi、单次120s上限、累计480s预算、4线程；只修改运行控制和保存结果，没有修改原模型的公式、参数或文件。保存位置为项目 `PowerSystemModelAudit/HW5/results/`。全部133项数值类别检查通过；仍确认原文S/R含义错误，以及二变量最小时间多计一时段的双方错误。周期上爬坡遗漏未在原数据激活，且功率周期假设未完全声明，保留条件性WARNING。报告已有实际LaTeX补全/修正。

## 复查：零新增求解

在课程项目根目录运行：

```matlab
skill=fullfile(pwd,'skills','power-system-model-audit');
addpath(fullfile(skill,'scripts')); addpath(fullfile(skill,'examples','hw5'));
psaudit_test_core; psaudit_test_model_review; psaudit_hw5_test_adapter;
hw5=fullfile(pwd,'电力系统分析与控制作业','HW5');
out=fullfile(pwd,'PowerSystemModelAudit','HW5');
psaudit_hw5_validate_suite(hw5,out,struct('mode','replay'));
psaudit_hw5_write_report(hw5,out);
```

`validate_suite`仅允许replay；读取结果、核对六类输入哈希、独立批量验算并保存audit/run。可用第三参数evidenceDirectory读取现有原结果并另存派生输出。`write_report`将案例清单交给公共渲染器，日期/错误数量/通过数量来自本次数据，不预设课程结论。这两个派生产物可更新；四份原始结果不可覆盖。输入变化时须重新审阅。

`psaudit_hw5_feasibility_probes(hw5)`在已审阅源码哈希门控下生成3项局部见证：最小开机、最小关机过紧，以及仅在功率周期成立时的上爬坡过松。两侧关系、赋值、残差和LOCAL_RELATIONS范围实际写入报告；没有用这些手算冒充完整模型优化结果。通用见证器能接入其他模型的独立参考/实现关系，有限候选未找到差异不证明等价。

## 新结果捕获

仅在已授权真实求解且确有需要时运行；已有结果复查不得调用本函数。先固定并测试独立规范/检查器。以下命令必须使用新的结果目录，不覆盖当前四个结果：

```matlab
models={'basicTask2_UC.m','basicTask2_UC_2variable.m', ...
        'basicTask2_UC_starttime.m','basicTask2_UC_maxstart.m'};
% 设置本次新目录与总预算；每入口只求解一次，单次上限120s
for k=1:numel(models)
    psaudit_hw5_capture_result(hw5,models{k},newResultsDirectory,120);
end
```

捕获保留原求解器，记录executionMode=capture；剥离清屏/清工作区/关图和结果绘图，只新增时限、线程、solver output保存。记录原目标、全量变量、solver状态/间隙及源码/参数/TeX/要求/规范哈希。没有有效解时返回DATA_INSUFFICIENT；报告保留失败记录和不可用目标，不编造费用或通过结论。

## 证据与适用范围

最小时间从动作当期计数；独立事件来自状态差分。内部与周期爬坡分别检查，后者在功率周期假设未确认时只提供条件证据。单侧启停变量在正事件成本下可能是经济等价表示，不能仅以未写精确等式误报。费用采用当前线性b*p目标；不擅自改为完整二次gencost。

10组手算/异常测试含合法/违规最小时间、首尾运行、非法域、NaN、无解、成本误差及两条局部源码公式反例。它们不是原始模型优化得到的违规解，也不等于完整受控源码故障实验。
