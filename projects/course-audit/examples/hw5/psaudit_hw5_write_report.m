function report=psaudit_hw5_write_report(hw5,outdir,inventory)
% Case adapter supplies reviewed evidence; common renderer derives conclusions.
data=load(fullfile(outdir,'validation.mat'));a=data.audit;
if isfield(data,'run'),run=data.run;else,run=psaudit_execution_context('replay').snapshot();end
if nargin<3,inventory=psaudit_hw5_relation_inventory(hw5);end
findings=psaudit_review_inventory(inventory);
entries=struct('key',{},'state',{},'elapsed',{},'objective',{},'resultFile',{},'resultHash',{},'checks',{},'executionError',{});
versions=struct('label',{},'path',{},'hash',{});
for k=1:numel(a)
    x=a(k);
    assert(strcmp(psaudit_hash_file(x.resultFile),x.resultHash),'Result changed since validation');
    paths={fullfile(hw5,x.model),fullfile(hw5,'case39_UC.m'),fullfile(hw5,'load3996.mat'), ...
        fullfile(hw5,'HW5.tex'),fullfile(hw5,'稳态大作业2-机组组合.docx'), ...
        fullfile(fileparts(mfilename('fullpath')),'math-spec.md')};
    fields={'sourceHash','caseHash','loadHash','texHash','assignmentHash','specHash'};
    for j=1:numel(paths),assert(strcmp(x.r.(fields{j}),psaudit_hash_file(paths{j})),'Input/reference changed');end
    entries(k)=struct('key',x.model,'state',sprintf('problem=%g; hasSolution=%d',x.r.problem,x.r.hasSolution), ...
        'elapsed',x.r.elapsed,'objective',field(x.r,'objective',NaN),'resultFile',x.resultFile, ...
        'resultHash',x.resultHash,'checks',x.checks,'executionError',field(x.r,'executionError',''));
    versions(end+1)=struct('label',x.model,'path',paths{1},'hash',x.r.sourceHash);
end
for j=2:numel(paths),versions(end+1)=struct('label',fields{j},'path',paths{j},'hash',psaudit_hash_file(paths{j}));end
for tool={'psaudit_hw5_check_solution','psaudit_hw5_build_reference','psaudit_hw5_relation_inventory', ...
        'psaudit_hw5_feasibility_probes','psaudit_check_relations','psaudit_review_inventory','psaudit_write_audit_report'}
    source=which(tool{1});versions(end+1)=struct('label',tool{1},'path',source,'hash',psaudit_hash_file(source));
end
witnesses=psaudit_hw5_feasibility_probes(hw5);
notes={ ...
    '审阅清单绑定HW5原文/源码快照；已知符号与窗口问题的依据来自清单，不在报告模板中预设错误数量。', ...
    '三项见证均为局部手算轨迹；周期上爬坡见证只在功率周期成立时适用，不无条件升为代码ERROR。数值可行性通过不能撤销可行域过度收紧的局部反例。', ...
    '使用当前线性成本、无损DC网络与状态周期假设。功率周期、非周期初末义务、AC无功/电压及其他输入需要单独审阅；费用相同不证明模型等价或精确最优。', ...
    ['复验：psaudit_hw5_validate_suite(hw5,outdir,struct(''mode'',''replay'',''evidenceDirectory'',''' ...
        strrep(run.evidenceDirectory,'''','''''') ''')); psaudit_hw5_write_report(hw5,outdir);']};
links=struct('label','独立数值参考','path',paths{end});
document=struct('title','HW5 电力系统优化模型审计报告','entries',entries,'findings',findings, ...
    'witnesses',witnesses,'execution',run,'notes',{notes},'links',links,'versions',versions);
document.checkedFiles=[arrayfun(@(x)fullfile(hw5,x.model),a,'UniformOutput',false) paths(2:end)];
report=fullfile(outdir,'audit_report.md');psaudit_write_audit_report(report,document);
fprintf('PSAUDIT_HW5_REPORT=%s\n',report);
end
function value=field(x,name,fallback)
if isfield(x,name),value=x.(name);else,value=fallback;end
end
