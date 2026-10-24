# 运行入口 1.1

新项目先按[项目接入](project-adapters.md)选择review或numeric；默认数值接入只生成配置、关系清单、合并审阅文档和未实现入口。静态审阅不建立数值验证器，review项目之后可用enable-numeric升级，保留原记录。

已有项目先status并复用；依赖变化后局部复核。采用知识card时再读[专项检查](card-driven-checks.md)，不要求所有数值接入先填写card识别材料。学习仍按学习策略处理，不在普通审阅开始时加载全部登记规范。

需要实际测试时使用psaudit_project.py collect，明确测试命令和时间限制，自动生成运行日志、快照和待审验收记录；具体命令与事实格式只在项目接入文档维护。freeze前仍须实质审阅，默认模型审计replay且新增求解预算0；采集器不会自动调用求解器。

旧math-spec.md/mapping.md、既有验收记录和原项目入口继续兼容。课程psaudit_run位于独立项目，不是新项目必用API；旧课程调用说明在项目README。历史证据保持原字节，路径不匹配时暂缓，不补签旧结果。

仓库tools/run_smoke_tests.m检查六组通用内核；课程项目run_adapter_tests.m检查自身适配器。独立LP例子需要有效Gurobi许可，不是普通接入步骤。COMPLETED、FRESH或COLLECTED_NOT_REVIEWED均不代表模型正确。
