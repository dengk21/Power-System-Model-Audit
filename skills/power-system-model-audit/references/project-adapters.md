# 项目适配器：生成、验证与维护

Skill保存可复用的知识、审计规范、通用检查器和空白模板。具体项目的适配器、独立规范、变量/参数映射、测试、运行结果及日志保存在项目中。学习不向Skill加入项目执行代码或课程caseId；项目特有的检查器也留在项目中，只有经独立提炼验证的通用关系才进入Skill。

## 项目布局

```text
<project>/PowerSystemModelAudit/
  adapter/
    run_audit.m       项目入口；Agent实现，可增加本地辅助函数
    math-spec.md      本项目独立关系、边界、单位和覆盖范围
    mapping.md        活动源码、变量、结果、知识卡片及工具映射
    project.json      项目源文件和实际使用的Skill文件清单
    bindings.json     审阅后绑定的依赖哈希与版本，不是正确性证明
    history/          旧绑定记录
  tests/             项目适配器测试与证据
  runs/<run-id>/     真实结果、日志、双报告；新目录，不覆盖旧证据
```

已有项目可保留自己的审计布局；初始化工具仅提供以上默认结构。不要为了统一目录改写历史MAT中的路径或哈希。

## 首次接入

1. 追踪活动入口、有效参数及依赖，审阅数学说明与独立物理关系；按学习策略检索相关card，先判断适用条件。
2. 使用通用骨架初始化，或直接在项目审计目录生成适配器。`init`只生成未实现骨架，绝不表示已经审计。
3. Agent实现结果读取、变量映射、独立数学重建、全索引检查和双报告。可调用Skill通用工具，但不把项目适配器复制回Skill。不从被审H/循环范围生成独立参考。
4. 在项目内测试正常、违例、等价、不适用、首末边界及缺数据。默认replay且零新增求解；真实运行仍按预算和授权执行。无完整适配器时可先交付语义审阅/局部证据，明确未覆盖范围。
5. 补全`project.json`的`source_files`（相对项目根目录）和`skill_files`（相对Skill根目录，含实际工具、card/record等）；在项目中保存测试证据，审阅后freeze绑定。工具不运行或判断测试证据的语义，仍由Agent负责实质核查。

```bash
python /path/to/skill/scripts/psaudit_project.py init --project /path/to/model
python /path/to/skill/scripts/psaudit_project.py freeze --project /path/to/model \
  --test-evidence PowerSystemModelAudit/tests/replay-tests.log \
  --review-note "已独立核查能量关系、变量单位与末期边界；正常和负控制通过，未执行完整求解"
python /path/to/skill/scripts/psaudit_project.py status --project /path/to/model
```

## 重复审计与变化

不在每次审计重写适配器。先执行status并追踪本次实际入口/依赖覆盖；FRESH仅表示声明文件未变，不证明没有漏列依赖。源文件、配置、适配器、测试证据或所用Skill工具/card变化、删除时为STALE。新增适配器文件也要求复核。入口改接到新文件时补充依赖清单；工具没有通用AST依赖发现能力。

STALE时输出变化清单，重新审阅受影响关系、更新映射和测试，再用旧`bindings.json`的SHA-256作为`--expected-bindings-sha`登记新版本。旧绑定原字节归档；不以刷新哈希代替审阅，也不重签历史结果。适配器绑定状态与数学参考确认、完整案例验证分别判断。

## 从MATLAB启动

项目适配器实现并验证后，在MATLAB中添加当前Skill的`scripts/`及项目`adapter/`，检查`which run_audit`确实指向本项目，调用项目入口：

```matlab
addpath(fullfile(skillRoot,'scripts'));
addpath(fullfile(project,'PowerSystemModelAudit','adapter'));
which run_audit
% 先检查绑定状态及适用性；options由本项目入口明确规定。
result = run_audit(project, skillRoot, options);
```

骨架会明确抛出AdapterNotImplemented，不返回伪通过。状态检查本身不会执行模型，也不会自动生成数学适配。旧课程`psaudit_run`已迁出Skill，是课程项目的历史入口，不是新项目必用的API。

## 学习后的归属

- 留在项目：拓扑、设备编号、额定值、变量名、路径、适配器、项目fixture、完整运行与原始证据。
- 进入Skill：去除实例常量后的约束card、适用条件、来源引用及小型独立正常/反例fixture。来源用路径/哈希引用，不复制整份项目。
- 已有或等价知识复用，不重复建卡；不同假设保留变体。项目新增数量不应线性增加Skill内的执行入口或固定适配器数量。
