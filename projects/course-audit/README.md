# 课程项目适配器（独立于Skill）

此项目保存从v0.15 Skill迁出的HW4/HW5/course/semantic适配器、数学规范和课程分派入口；MATLAB实现及math-spec迁移时保持原字节。它们不再随Skill安装，也不是自动生成任意项目适配器的模板。实际课程工作区的副本在`PowerSystemModelAudit/adapters/course-v015/`。

在课程工作区中：

```matlab
project=pwd;
skillRoot=fullfile(project,'skills','power-system-model-audit');
adapterRoot=fullfile(project,'PowerSystemModelAudit','adapters','course-v015');
addpath(fullfile(skillRoot,'scripts'),fullfile(adapterRoot,'scripts'));
which psaudit_run
result=psaudit_run(project,'hw5',struct('mode','replay', ...
    'outputDirectory',fullfile(project,'PowerSystemModelAudit','new-hw5-replay')));
```

旧入口固定课程caseId；新项目使用自己生成的入口，不扩展这个分派器。移动文件不代表旧结果自动绑定新路径；具名回调或版本不符仍须暂缓，不重签旧MAT。

仅本地适配器fixture：`summary=run_adapter_tests(skillRoot)`。通用内核的六组测试在仓库`tools/run_smoke_tests.m`；真实课程全入口重放仍需要原项目输入和匹配证据。
