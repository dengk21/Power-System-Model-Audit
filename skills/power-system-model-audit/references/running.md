# 运行入口 v0.16

Skill负责知识与审计规范，通用数值工具保留在scripts。每个项目生成并维护自己的适配器、入口、映射和测试；不会向Skill增加固定caseId。首次生成、版本绑定及MATLAB调用见[项目适配器契约](project-adapters.md)。

## 新项目

使用Skill追踪实际入口、审阅独立规范并在项目内实现适配器。`psaudit_project.py init`只创建未实现骨架，不能直接审计；实现和测试后用freeze记录依赖，重复审计先用status检查变化。默认replay、新输出目录、缺证据不自动求解；diagnose/capture须有明确动作及时间预算，见[执行契约](verifier-contract.md#执行模式与诊断缓存)。

## 原课程项目

原`psaudit_run(project,caseId,options)`与课程适配器已经迁到项目中。独立项目的README及各runbook保留课程运行说明；课程工作区使用`PowerSystemModelAudit/adapters/course-v015/`。需同时添加当前Skill的scripts及该项目的scripts；用`which psaudit_run`核对实际来源。旧支持组合为hw4/hw5 replay，course replay/diagnose，hw5-repair和semantic replay/capture；它们是历史项目能力，不是Skill固定分派协议。

历史数学规范与MAT不改字节或哈希。旧证据中的绝对路径/具名回调不因迁移自动有效；有不匹配就暂缓，重新执行按授权和预算另行安排。

## 仓库测试与独立LP

仓库`tools/run_smoke_tests.m`只检查六组通用内核，不加载课程适配器。课程适配器三组局部测试在独立项目`run_adapter_tests.m`中；`tools/run_semantic_demo.m`显式加载独立课程项目的两机LP，需有效Gurobi许可。它们不属于新模型自动接入能力。

## 学习与报告

自动学习由Agent与Python知识工具执行，MATLAB项目入口不会自行识别模型或登记card。专业报告与简报仍须基于同一份本次证据。COMPLETED表示流程完成；FRESH表示声明依赖未变；两者均不表示模型正确或全部入口已覆盖。
