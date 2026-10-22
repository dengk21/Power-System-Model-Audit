# 当前能力与版本 v0.13

更新日期：2026-10-15（Asia/Shanghai）。维护源为项目skills/power-system-model-audit；安装副本须与维护源逐文件同步。运行入口见[running.md](running.md)，语义验收协议版本仍为v0.12。

| 能力 | 方法/工具 | 已执行证据 | 目前边界 |
| --- | --- | --- | --- |
| 数学—代码—独立依据三方审查 | Agent语义审阅、review_inventory、报告实文 | HW1—HW10的原审计报告 | 清单需审阅；无任意TeX自动解析/形式证明 |
| 全索引数值重建 | check_relations、storage、AC/DC/UC/频率原语 | HW4五入口87类+3跨模型；HW5四入口133类；其他作业基础754类，含新增Vg诊断可用性检查的当前重放755类 | 类别数不是独立病例数，也不是准确率 |
| 仿射系数/单位/方向比较 | compare_affine | 28项控制、两机LP、真实HW5最小时间与目标块 | 未声明的非线性/隐式等价需专门推导；容差限制仍在 |
| 过松/过紧见证 | evaluate_witnesses、实际模型成员重建 | 旧HW5三项LOCAL_RELATIONS；新增两个完整模型过紧轨迹通过v0.12语义成员核查 | 新完整轨迹仅对应本次HW5变体，不冒充旧见证器的FULL_MODEL接口输出；有限见证不证明可行域等价 |
| 真实HW5修复及v0.12验收 | hw5/repair适配器 | 39节点/46支路/10机组/96时段；原始、恰好开机、跨界恰好停机三工况 | 仅修复M_MINIMUM_WINDOW；功率周期争议和其他文档问题保留 |
| 最优值与可行性模式分离 | validate_semantic_candidate | HW5 nominal为REFERENCE_OPTIMUM；两条参考选择轨迹为FEASIBILITY | 后两项参考费用不是全局最优值；solver最优报告不是形式证明 |
| replay/diagnose/capture与预算 | execution_context、read_diagnostic、psaudit_run | 原适配器模式测试及统一入口真实重放 | runpf为记录超限，非硬进程超时；其他后端未执行 |
| 效果评测 | 匿名复杂benchmark的A/B/C | 三组均10/10病例、14/14错误，确定错误误报0；C新增12次求解 | 尚未观察到准确率增益；该轮不含复杂案例修复 |

## 新旧协议覆盖

- HW5最小时间修复示范与两机LP：已接入真实结果、冻结关系、数组形状、源文件和参考轨迹的v0.12语义验收。
- 原HW4五入口、原HW5四入口、course适配器：继续使用已有哈希/数值审计协议，未自动全部迁移。统一分派不提升其证据等级。
- Python/Julia：方法可适配，当前交付没有声称已执行这些后端。其他电力模型仍按自身假设和规范开发适配器。

## 原项目证据入口（本公开包不附）

- HW5完整修复验收：原项目路径 `PowerSystemModelAudit/validation/hw5-repair-v012-20261015/run-03/audit_report.md`。最终版本9次真实MIP调用，每工况25类独立规范检查、5类完整成员检查；各类别内部覆盖所有声明索引。开发失败/包装重跑另存，不合并为独立成功病例。
- v0.12机制升级：原项目路径 `PowerSystemModelAudit/validation/semantic-upgrade-20261015/report.md`，保存历史两机LP和独立探针记录。
- 复杂benchmark：原项目路径 `测试benchmark/complex-v1-20261014/评测结果与可信度报告.md`，为冻结的Agent效果实验，不因本次工具接入而重计准确率。

以上路径仅用于追溯，不是本包内可点击的证据链接。本包能直接执行的无求解检查及独立LP示例见仓库 `docs/PACKAGING.md`；课程与benchmark结论需原项目证据另行复核。

v0.13新增统一入口、真实HW5接入及此能力表。历史文档中的v0.10/v0.11/v0.12结果按当时版本解释；旧输入、提交、标签与分数保持冻结。本次没有新增Agent盲测或声称检出率提高。
