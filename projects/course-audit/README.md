# 课程模型的检查程序

本目录保存HW4、HW5、其他课程模型及双机LP示例的检查程序。它们负责读取各模型的变量、参数和运行结果，再调用Skill中的通用数值工具。由于这些对应关系与具体模型有关，因此单独放在课程项目中，而不随每次Skill安装一起复制。

## 先运行小例子

如果只想检查通用工具是否能正常使用，在仓库根目录的MATLAB中执行：

```matlab
addpath(fullfile(pwd, 'tools'));
summary = run_smoke_tests;
```

如果还要检查本目录的课程程序，可继续执行：

```matlab
skillRoot = fullfile(pwd, 'skills', 'power-system-model-audit');
addpath(fullfile(pwd, 'projects', 'course-audit'));
summary = run_adapter_tests(skillRoot);
```

前者包含六组通用工具检查，后者包含HW4、HW5和其他课程辅助函数的三组检查，均使用预设数值例子，不调用求解器。若已配置有效的Gurobi MATLAB接口，`run_semantic_demo`可以重新求解双机LP并检查六种修改方案，详细模型见`examples/semantic/`。

## 检查原课程模型

完整检查需要原模型输入和与代码版本一致的结果文件。课程工作区保留了本目录程序的副本，已有结果可按以下方式验算：

```matlab
project = pwd;
skillRoot = fullfile(project, 'skills', 'power-system-model-audit');
adapterRoot = fullfile(project, 'PowerSystemModelAudit', 'adapters', 'course-v015');
addpath(fullfile(skillRoot, 'scripts'), fullfile(adapterRoot, 'scripts'));
which psaudit_run
result = psaudit_run(project, 'hw5', struct('mode', 'replay', ...
    'outputDirectory', fullfile(project, 'PowerSystemModelAudit', 'new-hw5-replay')));
```

这条命令按HW5的既有目录读取数据。对于其他新模型，应编写它自己的入口，明确变量、单位和初末条件，再调用通用工具。移动旧文件后也需要核对原来的代码和结果是否仍然对应，不能仅修改文件校验值就把旧结果视为新运行结果。
