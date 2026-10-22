function file=psaudit_course_write_report(project,outdir,inventory)
% Reviewed course semantics stay in the adapter; rendering is case-independent.
data=load(fullfile(outdir,'validation.mat'));a=data.audit;
if isfield(data,'run'),run=data.run;else,run=psaudit_execution_context('replay').snapshot();run.evidenceDirectory=outdir;end
if nargin<3,inventory=psaudit_course_review_inventory(project,run.evidenceDirectory,a);end
findings=psaudit_review_inventory(inventory);
entries=struct('key',{},'state',{},'elapsed',{},'objective',{},'resultFile',{},'resultHash',{},'checks',{},'executionError',{});
notes={ ...
    '优化入口、非优化辅助、原流程失败和UC-only诊断分别记录。捕获完成不表示求解成功；VIOLATION不自动等于代码错误。', ...
    '经审阅清单的数学/实现结论对应其绑定的原文与源码。当前数值缺证据时，历史审阅证据不冒充本次新求解结果；固定手算见证也不当完整模型有效解。', ...
    'replay只读取匹配版本的诊断缓存；缓存缺失/过期为DATA_INSUFFICIENT。diagnose需明确动作与时间预算。旧无绑定缓存保留原样，不自动追补当前哈希。', ...
    '当前DC要求声明的网络假设；频率参考是相同TG/FR的线性SFR。严格鲁棒最优性、含限幅动态安全、完整AC优化与未接入模型族均未证明。'};
if nargin<3,notes=[notes psaudit_course_review_notes(a)];end
for k=1:numel(a)
    x=a(k);assert(strcmp(x.resultHash,psaudit_hash_file(x.resultFile)),'Result changed since validation');
    source=fullfile(project,'电力系统分析与控制作业',x.r.relative);
    assert(strcmp(x.r.sourceHash,psaudit_hash_file(source)),'Source changed since validation');
    objective=NaN;if isfield(x.details,'objective'),objective=x.details.objective;
    elseif isfield(x.r.vars,'obj')&&isscalar(x.r.vars.obj),objective=x.r.vars.obj;end
    error=x.r.error;if ~isempty(x.checkerError),error=[error newline 'CHECKER: ' x.checkerError];end
    entries(k)=struct('key',x.relative,'state',status(x.r),'elapsed',x.r.elapsed,'objective',objective, ...
        'resultFile',x.resultFile,'resultHash',x.resultHash,'checks',x.checks,'executionError',error);
    for key={'voltageDiagnostic','primalDiagnostic'}
        if isfield(x.details,key{1}),z=x.details.(key{1});notes{end+1}=sprintf('%s / %s：%s；%s',x.relative,key{1},z.status,z.detail);end
    end
    if isfield(x.details,'pureApproxError')
        notes{end+1}=sprintf('%s：当前匹配诊断缓存给出仅Vg摄动近似误差%.12g，原实验误差%.12g；近似接近不撤销输入定义错误。',x.relative,x.details.pureApproxError,x.details.originalApproxError);
    end
end
links=struct('label',{'原始输入清单','全量数值附表','独立数值参考','HW4报告','HW5报告'}, ...
    'path',{fullfile(run.evidenceDirectory,'input-manifest.md'),fullfile(outdir,'numerical-evidence.md'), ...
    fullfile(fileparts(mfilename('fullpath')),'math-spec.md'),fullfile(project,'PowerSystemModelAudit','audit_report.md'), ...
    fullfile(project,'PowerSystemModelAudit','HW5','audit_report.md')});
versions=struct('label',{},'path',{},'hash',{});
for k=1:numel(a)
    source=fullfile(project,'电力系统分析与控制作业',a(k).r.relative);
    versions(end+1)=struct('label',a(k).relative,'path',source,'hash',psaudit_hash_file(source));
end
versions(end+1)=struct('label','Reviewed manifest','path',links(1).path,'hash',psaudit_hash_file(links(1).path));
for tool={'psaudit_course_validate','psaudit_course_review_inventory','psaudit_course_review_notes','psaudit_read_diagnostic', ...
        'psaudit_execution_context','psaudit_check_relations','psaudit_review_inventory','psaudit_write_audit_report'}
    source=which(tool{1});versions(end+1)=struct('label',tool{1},'path',source,'hash',psaudit_hash_file(source));
end
notes{end+1}=sprintf('复验：psaudit_course_validate(project,outdir,struct(''mode'',''replay'',''evidenceDirectory'',''%s'',''diagnosticDirectory'',''%s'')); psaudit_course_write_report(project,outdir);', ...
    strrep(run.evidenceDirectory,'''',''''''),strrep(run.diagnosticDirectory,'''',''''''));
witnesses=psaudit_evaluate_witnesses(struct([]));
document=struct('title','电力系统分析与控制作业：其余作业审计报告','entries',entries, ...
    'findings',findings,'witnesses',witnesses,'execution',run,'notes',{notes},'links',links,'versions',versions);
file=fullfile(outdir,'audit_report.md');psaudit_write_audit_report(file,document);
fprintf('PSAUDIT_COURSE_REPORT=%s\n',file);
end
function s=status(r)
parts={};
for fn={'result','result_ahead','result_intra'}
    if isfield(r.vars,fn{1}),v=r.vars.(fn{1});parts{end+1}=sprintf('%s:%d',fn{1},v.problem);end
end
if isfield(r,'lastSolverResult'),parts{end+1}=sprintf('bare:%d',r.lastSolverResult.problem);end
if isfield(r.vars,'linear')&&isfield(r.vars.linear,'result')
    if isfield(r,'config')&&isfield(r.config,'reuseFitFile'),parts{end+1}='fit:historical cache / UC-only diagnosis';
    else,parts{end+1}=sprintf('fit:%d',r.vars.linear.result.problem);end
end
if ~isempty(r.pfRuns),parts{end+1}=['PF:' mat2str(cellfun(@(x)x.success,r.pfRuns))];end
if isfield(r.vars,'success'),parts{end+1}=sprintf('PF:%d',r.vars.success);end
for fn={'res','res1','res2'}
    if isfield(r.vars,fn{1})&&isfield(r.vars.(fn{1}),'success'),parts{end+1}=sprintf('%s PF:%d',fn{1},r.vars.(fn{1}).success);end
end
if isempty(parts)
    if ~r.completed,s='execution failed before solve';else,s='auxiliary computation / no retained solver status';end
else,s=strjoin(parts,', ');end
end
