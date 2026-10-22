# HW4 验证案例运行说明

HW4 是 PowerSystemModelAudit 的首个 ED/DCOPF 适配器，不是通用 skill 的范围限制。固定关系内核与参数/公式适配分离；新模型按 ../../references/verifier-contract.md 接入。

开发环境为 MATLAB R2025b。读取/检查结果需 MATLAB 与 JVM，独立参考直接读取 case 和负荷，不依赖 MATPOWER。捕获真实解另需 YALMIP、MATPOWER 及原求解器：Flow 为 COPT，其他四入口为 Gurobi。已验证 COPT 的本机接口和 TimeLimit 参数；不替换原始 solver。

## 命令

本公开包不附课程原始输入和历史结果。以下命令供自行提供相应材料后使用，从仓库根目录启动；由 `pwd` 构造本机路径。原始文件不改，已存在输出默认拒绝覆盖。

```matlab
project = pwd;
skill = fullfile(project,'skills','power-system-model-audit');
addpath(fullfile(skill,'scripts'));
addpath(fullfile(skill,'examples','hw4'));
hw4 = fullfile(project,'电力系统分析与控制作业','HW4');
psaudit_test_model_review; % 数学模型/代码归因与实际补全测试
psaudit_test_core; % 通用原语手算/异常测试，不是完整模型求解
psaudit_hw4_test_adapter; % HW4 适配器手算测试

% 无已有结果且任务需要求解时，每次至多一次，默认60秒上限。
captureOut = fullfile(project,'outputs','hw4-run1');
f = psaudit_hw4_capture_result(hw4,'basicTask1_ED_Flow.m',captureOut,60);
psaudit_hw4_write_report(hw4,'basicTask1_ED_Flow.m',f,fullfile(captureOut,'audit_report.md'));

% 已有结果复查：零新增求解，输出另存。
psaudit_hw4_write_report(hw4,'basicTask1_ED_Flow.m',f,fullfile(project,'outputs','audit_report-rerun.md'));
```

`psaudit_hw4_validate_suite(hw4,resultDir,linearResult,reportDir)` 读取全部五份真实结果，检查通用内核/适配器测试、每个入口和三项跨模型目标关系。resultDir 包含其余四个入口的 *_result.mat，linearResult 单独指定；reportDir 必须另存。它不自动求解，不把缺失结果当通过。

本课程项目的历史结果已统一归档。以下命令从项目根目录运行，不再依赖旧的顶层审计目录：

```matlab
skill=fullfile(pwd,'skills','power-system-model-audit');
addpath(fullfile(skill,'scripts'));
addpath(fullfile(skill,'examples','hw4'));
hw4=fullfile(pwd,'电力系统分析与控制作业','HW4');
archive=fullfile(pwd,'PowerSystemModelAudit','archive');
results=fullfile(archive,'GridModelAudit','validation','hw4-all');
linear=fullfile(archive,'GridModelAudit-HW4','example-run','basicTask1_ED_linear_result.mat');
psaudit_hw4_validate_suite(hw4,results,linear,fullfile(pwd,'PowerSystemModelAudit','my-rerun'));
```

归档内MAT、旧报告和旧安装保持原字节；旧报告/MAT内部记录的旧路径表示采集时的位置。迁移清单在项目 `PowerSystemModelAudit/archive/migration-manifest.md`。新报告写入当前成果目录，已有报告不覆盖。

## 捕获与 provenance

capture 读取本地选定入口，去掉清屏/清变量/关图，截在“结果处理”前，设原求解器 verbose/TimeLimit，不改目标/约束/输入。调用前 Agent 读取入口，eval 的不是远程文本。默认每次最大60秒；批量次数和累计预算在报告另记。

样例 MAT 顶层 r：p(I×T)、可选 q(I×3×T)、Pg、Pic、F、objective、hasSolution、problem/info/elapsed，model/sourceHash/caseHash/loadHash/specHash，MATLAB/YALMIP/solver路径与solveCount/timeLimit。历史线性结果的 solver 字段缺失但保留原 Gurobi 路径，报告如实引用。

数值参考快照math-spec.md保留历史字节和specHash；数学原文有疑点时依../../references/math-model-review.md另行复核，不能以该快照证明正文正确。审核前重读独立参考并核对全部哈希，不能混用不同入口/版本；规范草案字节固定便于复用旧结果。用户确认相同公式契约及哈希时，确认人/日期可在报告另记并传第六参数 true；公式或参数变化必须新版本/相应检查器，不能改旧哈希绕过门控。求解状态0，或3且有有限incumbent，可验算；最优性与可行性分开。

## 双向审查与独立检查内容

psaudit_hw4_build_reference 按可信 case/负荷与 HW4 契约构造参数、每条支路电纳、节点/机组关联和成本；psaudit_hw4_check_solution 计算关系两侧，由通用 psaudit_check_relations 计算残差/容差/计数。参考不读取源码H、有效循环集合、obj或限额作为真值。

完整覆盖6台机组、39节点、46支路、96时段与95转换；p/q关系、全网平衡、实际F与独立重建、节点守恒、双向支路/机组界、爬坡及目标重算。q缺失时聚合项仍检查，分段/分段成本明确数据不足。NaN/Inf/错形状不当通过。拓扑、相移、集合或公式改变超出这个固定适配器时需新适配。

三项跨模型关系只在同一目标/输入和可比最优状态下检查：线性与线性分段目标相同（不要求退化LP的调度逐元素相同）；Flow收紧限额成本不低于Quadratic；Ramp放宽爬坡成本不高于Quadratic。

## 文档缺口与数学核查

psaudit_hw4_relation_inventory 对已审阅的HW4.tex快照识别C_BAL_DOC：正文未显式列式，五个活动入口含sum(Pic)=0。原文SHA改变时要求重新语义核查，匹配锚点只是快照门控，不是通用TeX解析。psaudit_hw4_write_report默认生成实际有功平衡LaTeX和来源/假设，作为文档补全WARNING；不改原TeX、数值基线或旧哈希。

psaudit_hw4_write_report第七参数可传经审阅inventory，供数学错误/代码错误/双方错误的归因。若发现原数学模型有独立反证，即使第六参数confirmed=true也将当前基线降为条件式检查，并保留原始数值证据。新参考另建测试版。原文修正与补全按用户授权范围执行，当前仅在报告给可合并实文。

## 验证记录边界

五入口真实求解与独立检查已完成；手算/异常测试及源哈希失配门控已验证。三类源码故障真实有效解、未激活故障和误报量化仍是后续实验，不用人工扰动数据冒充优化结果。HW4均为ED/DCOPF，不能把五个入口当作五种不同模型族来宣称已验证UC/ACOPF/储能。
