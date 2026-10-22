# 剩余课程作业适配器运行说明

此适配器覆盖HW1—HW3、HW6—HW10的31个原脚本入口；一份后续UC诊断另列。原始程序含错误时，执行失败/无解/时限也属于审计结论，不能伪称全部求解成功。HW4/HW5保留原适配器与报告。

通用可复用计算在`scripts/psaudit_ac_network.m`、`psaudit_dc_network.m`、`psaudit_check_commitment.m`、`psaudit_frequency_extremum.m`：逐支路AC/DC重建、UC轨迹及SFR首极值。当前DC工具要求单slack连通网络；UC工具支持本轮统一整数最小时间和显式非周期边界，逐机不同持续时间须另适配；频率工具为相同TG/FR的线性SFR，不是含饱和动态安全证明。

## 严格零新增求解复查

在课程项目根目录运行：

```matlab
root=pwd; skill=fullfile(root,'skills','power-system-model-audit');
addpath(fullfile(skill,'scripts')); addpath(fullfile(skill,'examples','course'));
psaudit_test_core; psaudit_test_model_review; psaudit_course_test_helpers;
out=fullfile(root,'PowerSystemModelAudit','remaining');
psaudit_course_validate(root,out,struct('mode','replay'));
psaudit_course_write_report(root,out);
```

12组手算/异常边界测试覆盖AC、tap/shunt、DC移相/并联/停运零阻抗、频率首极值、UC持续/非周期窗口及概率。验证器核对输入/参考/结果哈希，逐入口保存证据。replay不调用optimize或runpf，包括诊断缓存缺失时；仅Vg摄动也读取缓存。语义清单绑定已审阅输入清单哈希，不能仅修改哈希绕过重新审阅。

v0.10诊断缓存命名为 `*_v10.mat`，包含binding/计算值/原诊断预算。旧 `*_primal.mat` 无完整绑定，保留历史用途；不事后补哈希当新证据。新缓存不存在或版本不符时，相应类别为DATA_INSUFFICIENT。

## 独立诊断：显式预算

确有缺失证据且任务授权诊断时，另存输出。例如本轮只生成一个Vg潮流与两个固定天气LP参考，不重新求解原作业模型：

```matlab
options=struct('mode','diagnose','evidenceDirectory',out, ...
    'diagnosticDirectory',fullfile(newOutput,'diagnostics'), ...
    'budget',struct('maxActions',3,'singleSeconds',120,'totalSeconds',240));
[audit,run]=psaudit_course_validate(root,newOutput,options);
psaudit_course_write_report(root,newOutput);
% 后续只读同一缓存；移除诊断预算。
options.mode='replay'; options=rmfield(options,'budget');
psaudit_course_validate(root,newOutput,options);
```

LP使用剩余TimeLimit；runpf无硬TimeLimit，本工具记录实际耗时和超限并停止后续动作，不宣称硬进程超时。maxActions计独立诊断动作，原入口捕获与其分开。当前报告由公共 `psaudit_write_audit_report` 根据本次清单/数值生成，不在模板写死通过结论、日期或错误数量。

`results/`保留首次捕获；`rerun-results/`保留修复捕获或明确运行控制后的复跑，按入口取后者；`diagnostic-results/`明确标记原训练后半段UC诊断，不替换原流程失败。`isolated/HW10/`保存原辅助拟合产生的数值系数供test2执行，绑定运行输入哈希；它不是另造的参考真值。`validation.mat`和Markdown是允许更新的派生产物。

## 原始结果捕获

`psaudit_course_capture(project,relative,outdir,config)`保留原求解器、数学约束和目标，默认mode=capture；mode=replay直接拒绝。配置可指定隔离执行目录；`fitGap`仅用于已有案例有限拟合重试；`reuseFitFile`改变原流程，必须显式config.mode='diagnose'并单列UC-only。禁止覆盖既有真实结果。必要重试须有新问题/缺失证据依据。

包装器先统一CRLF、去清工作区/最终绘图写入，保存数值/solver状态；支持二维sdpvar及三维ndsdpvar。只保留已算出的内部checkpoint数值，不能禁止save后又让同一脚本load缺失文件。活动solver入口必须保留下来；截取不使用跨行通配符吞掉求解段。原优化通常每调用120s/4线程；C&CG另设5轮/240s外层保护。一个早期辅助拟合的多空格设置未套上时限，实际197.120s，主报告已明确记录，后续匹配已修复。

## 本轮结果与限定

2026-10-08—09，共754项类别（含明确的条件性诊断），729 PASS、21 VIOLATION、4 DATA；确认11组数学/实现问题、3处执行错误，另有基准、阶段和近似警告。HW6全部10场景与CCP数值通过；HW8当前AC结果/分摊通过。HW7主问题、界/KKT及辅助源码有问题，未认证鲁棒最优；HW10原拟合两次到时限并触发错误分支，后半段另做诊断。脚本值不改，原源码/TeX不修。

v0.10额外显式列出一个Vg诊断可用性类别：缺缓存复验为727 PASS/21 VIOLATION/7 DATA；有匹配缓存为730 PASS/21 VIOLATION/4 DATA，总计755。原754类别的其他结论未改变；新增类别不是新的优化模型。模式/报告/见证回归证据在项目 `PowerSystemModelAudit/validation/v0.10/`。

HW9已核对两张图：主脚本按图直接相加KG，辅助test容量加权；KG基准未明确，保留REFERENCE_CONFLICT，不凭常见基准解释硬判代码ERROR。拟合必须核真正max平面预测、训练特征顺序/域与整数容差传播；不能只检查内部DeltaF变量。SCUC未启用频率约束时，频率超限是基线诊断。

固定`math-spec.md`的箱式区间文字有多余点（`[.8,.1.2]`）；实际依据原TeX和代码使用0.8—1.2。保留旧字节以匹配已存结果哈希，不用该排版笔误改变数值公式。后续修订另立版本。
