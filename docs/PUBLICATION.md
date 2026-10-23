# v0.13 仓库发布核验

日期：2026-10-22（Asia/Shanghai）。

本次发布以 2026-10-20 已验证的公开包为基础，新增仓库首页和本记录，并重新生成包文件清单。90 个 Skill 资源及 MATLAB 工具保持发布包原字节；原项目维护源码、课程材料和实验记录未改动。macOS 自动生成的 `.DS_Store` 未进入发布副本。

发布前运行标准库完整性检查，核对文件大小、SHA-256、Skill 来源、内部 Markdown 链接及私有绝对路径。历史九组 MATLAB 测试记录见 VALIDATION.md；本次运行情况在下文记录。

## 本次实测

在 macOS 的 MATLAB R2025b 中重新运行 `run_smoke_tests`，core、model_review、affine、repair_gate、execution_and_witnesses、report_data、hw4_adapter、hw5_adapter、course_helpers 九组全部通过；汇总 `groupsPassed=9`、`groupsTotal=9`、`solverCalls=0`。本地日志未上传。未在本次发布中运行需要 Gurobi 的真实 LP 演示或完整课程案例。

标准库包检查通过：99 个清单内文件、90 个 Skill 资源、86 个资源与原维护源逐字节一致、4 份既有公开包文档适配、45 个内部链接。清单文件本身另计，共发布 100 个文件。

## 双报告更新（2026-10-22）

按用户要求增加极简简报 `audit_brief.md`，原专业报告保留为 `audit_report.md`。简报只显示实际检查文件、问题位置、简述及是否需要改正；未解决争议和缺证据不自动转成改代码要求。逐模型输出使用同名 `_brief.md`。

新增共用简报写入器和模板，接入通用专业报告器、HW4逐模型报告及HW5完整修复报告；HW5与course共用报告器自动生成两份。统一运行摘要记录简报路径。直接审计新模型时，Skill同样要求交付两份。semantic仍为机制示例，不将机制实验冒充完整模型审计报告。

更新后的Skill共92个资源，88个与当前维护源逐字节一致，4份保留公开包文档适配。历史报告、实验输入和冻结证据未回写。

Updated package verification: all nine self-contained MATLAB test groups passed again with zero solver calls. The paired-report tests cover correction targets, numerical disagreement, missing semantic review, unresolved definitions, clean results, documentation gaps and execution failures. A real HW4 result was replayed to generate both reports in a separate local example directory; historical evidence was not modified.

## 移动资源与电力—通信恢复知识参考（2026-10-22）

重新读取用户更新后的Power-Communication-Network-Resilience-Model，以实际调用的代码及有效配置为准，新增移动资源、配电网恢复和通信约束两份数学形式参考，以及22项源文件/输入哈希清单。Skill入口、检查路由和能力表已接入；当前共有95个Skill资源，4份保留发布文档适配。

本次未复制原模型代码、数据或TeX到发布包，未修改来源项目，未添加完整数值适配器或统一入口caseId。来源清单是学习快照，不是新项目的固定正确答案；其他项目仍按自身变量、单位、边界和物理假设适配。测试范围与结果记在本地学习验证目录，不充当该大模型的求解或全面审计证据。

## v0.14持续学习改造（2026-10-22）

Git仓库Skill成为唯一维护源；原课程目录Skill由同步工具生成，旧来源清单归档为source-manifest-v0.13.json。数学规范、原课程模型和历史求解证据不因本次改造改写。

新增8张约束卡片，每张包含数学形式、条件/变体、来源、独立依据、记录状态及5个局部fixture，共40项。覆盖ED平衡、UC最小时间、储能能量、移动弧守恒、行驶—运行时间、端点通信、维修累计和凹PWL损失。CODE_OBSERVED/RECONCILED、LOCAL_TESTED、CONDITIONAL以及实时来源新鲜度/适用性分开记录。

知识工具提供learn/search/inspect/update/register/validate/index。learn仅准备来源快照，Agent完成语义提取；新关系可先存UNTESTED候选，不能据此确认错误。修订需匹配旧记录哈希、递增版本并归档原卡片/记录/fixture。卡片、fixture、检查器或来源变化均需复核；工具不机械证明审阅文字真实，也不证明任意模型正确。

验证：40项局部fixture、21项知识管理/同步回归通过；既有9组MATLAB自包含测试通过，新增求解0次。已实测来源更新检查、带适用条件的检索和新来源快照命令。未新增留出集Agent准确率或完整恢复模型求解结论。

独立前向试用：另一Agent仅获得当前Skill及未参与卡片整理的单区间储能模型，识别充电效率遗漏，用非零功率探针及局部双向见证支撑结论；对上层边界职责保留WARNING，生成简短与专业两份报告。此为单个合成模型的行为试用，不是学习前后准确率对照或泛化效果评测。完整材料保存在仓库外的本地验证目录。

## v0.15自动学习判断（2026-10-22，本地更新）

普通审计无需显式学习指令。Agent依据活动代码完成组件覆盖与10类模型族的结构识别；Python核验其来源哈希、行号和必要角色，不能代替Agent的语义判断。全部经典结构自动学习；非经典、创新混合及不确定结构默认先询问“本次学习 / 以后默认都自动学习 / 本次不学习”，审计继续，未答不登记。

仅永久选择写入本机偏好，不进入Git或发布包。本次学习不持久启用；恢复ask后撤销旧自动策略；来源变化要求重新生成策略。自动learn/register接入策略门控，不自动提升知识验证状态，不执行求解、改原模型或推送。MATLAB数值入口本身不执行学习。

验证：新增20项策略回归与既有21项知识管理回归通过，共41项；现有40项公式fixture仍独立统计。上述检查验证工作流，不作为模型分类准确率或自动学习效果评测。本节记录本地待发布内容，不表示已经推送仓库。

## v0.16 项目适配器分离（2026-10-23，本地更新）

按用户要求，Skill只积累可复用约束知识、审计规范和通用工具；原examples及固定课程psaudit_run/psaudit_test_run迁到独立`projects/course-audit/`，课程工作区保留项目本地副本。新项目在自己的PowerSystemModelAudit/adapter目录生成入口、独立规范和映射；项目fixture、日志、结果均留项目中。已有适配器未变则复用，变化后审阅、回归并递增绑定版本，不每次重新生成。

新增psaudit_project.py的init/status/freeze。init是明确未实现的骨架，不能伪报审计通过；绑定检查声明源码、参数、项目适配器、实际使用的Skill工具/card及测试证据，支持旧记录哈希冲突检查和原字节归档。工具不自动提取数学、不执行测试或求解、不发现所有隐式依赖，也不以FRESH证明模型正确。

迁移核对50份原执行代码和数学规范原字节不变。ED/UC两张card递增至v2，仅修改来源位置和说明；来源规范哈希、数学公式和fixture期望不变，旧v1完整归档。8张当前card在实际项目来源映射下均FRESH。课程Skill副本与安装版均通过受控同步更新；旧安装版已归档，未改写原模型和历史求解MAT。此节记录v0.16发布内容；实际发布状态以仓库标签和Release为准。

验证：54项Python回归、40项公式fixture、Skill结构验证及包完整性检查通过。MATLAB六组通用内核、三组独立项目适配器fixture通过；另从课程项目新位置调用psaudit_run，HW5四入口133项数值类别重放通过，双报告已生成。所有本次执行新增求解0次。未重放其他完整课程案例或新做优化求解，迁移和局部测试不作为学习效果提升的证明。

## v0.16 发布封装

版本标签为`v0.16`。Release提供纯Skill安装ZIP、完整仓库源码ZIP和SHA256SUMS.txt，更新说明见`releases/v0.16.md`。仓库用.gitattributes禁用换行转换，确保SHA-256记录在提交、源码归档及跨平台检出中保持原始字节。发布前从Git暂存树导出干净快照检查清单，安装ZIP只取Skill清单中的资源，不附课程适配器、运行输出、缓存或本机偏好。
