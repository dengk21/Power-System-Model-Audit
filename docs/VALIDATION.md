# 本次封装验证

日期：2026-10-20（Asia/Shanghai）。执行环境：Windows，MATLAB 25.2.0.2998904（R2025b），启用 JVM。

## 核心内容保留

维护源包含90个文件。86个文件逐字节保留，4份 Markdown 仅调整公开包说明、外部依赖、私有路径及未随包发布证据的链接。全部 MATLAB 文件、独立数学规范、模板及 Agent 元数据均未改动；未修改原工作区维护源与安装副本。差异及 SHA-256 见 `source-manifest.json`。

## 已执行验证

通过 `tools/run_smoke_tests.m` 执行以下九组已有测试：

| 测试组 | 原测试输出的范围 | 结果 |
| --- | --- | --- |
| core | 15个跨模型原语/无效数据案例 | PASS |
| model_review | 13个归因/补全/报告案例 | PASS |
| affine | 28项系数语义比较控制 | PASS |
| repair_gate | 6项修复接受控制 | PASS |
| execution_and_witnesses | 模式/缓存/预算/成员性行为检查 | PASS |
| report_data | 4项证据变化/候选报告检查 | PASS |
| hw4_adapter | 11项手算案例 | PASS |
| hw5_adapter | 10项UC轨迹/异常数据案例，另含3项限定范围见证 | PASS |
| course_helpers | 12组AC/DC/频率/UC/概率fixture | PASS |

设置 `gurobi/optimize/runpf/copt` 抛错替身防止隐式求解；九组全部返回，记录新增求解调用0次。上述数量沿用各测试自身的统计口径，不相加冒充独立模型数或 Agent 准确率。

Skill 创建工具附带的 `quick_validate.py` 返回 `Skill is valid!`。该工具的 PyYAML 仅在本地临时目录提供，不构成本包运行依赖。

`tools/verify_package.py` 检查公开包文件大小/哈希、Skill来源哈希、33个内部 Markdown 文件链接和私有绝对路径，全部通过。ZIP 由清单中的受跟踪文件生成，不含 `outputs/`、本地日志、临时验证依赖和历史项目材料。

## 验证边界

未在本次封装中执行两机LP真实求解、HW4/HW5/course完整课程案例重放、HW5完整修复捕获或新的 Agent benchmark。独立 LP 入口只是对原示例的路径封装，需要用户配置 Gurobi 后运行；它不是本次新增的真实求解证据。历史案例统计保留在 Skill 中，完整原始证据未随此包公开。
