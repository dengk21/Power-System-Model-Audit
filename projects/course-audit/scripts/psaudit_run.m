function result=psaudit_run(project,caseId,options)
% Unified explicit dispatch; defaults to replay and never invents a solve budget.
if nargin<3,options=struct;end
assert(isstruct(options)&&isscalar(options),'Options must be a scalar struct');
allowed={'mode','outputDirectory','evidenceDirectory','diagnosticDirectory','budget'};
assert(all(ismember(fieldnames(options),allowed)),'Unknown option; refusing a possibly misspelled mode/budget');
if ~isfield(options,'mode'),options.mode='replay';end
if ~isfield(options,'budget'),options.budget=struct;end
assert(isfield(options,'outputDirectory')&&~isempty(options.outputDirectory),'Explicit new outputDirectory required');
out=char(options.outputDirectory);assert(~isfolder(out)&&~isfile(out),'Output already exists; use a new directory');
cases={'hw4','hw5','course','hw5-repair','semantic'};
assert(ismember(caseId,cases),'Unknown caseId; see references/running.md');
modes={{'replay'},{'replay'},{'replay','diagnose'},{'replay','capture'},{'replay','capture'}};
assert(ismember(options.mode,modes{strcmp(caseId,cases)}),'Mode not implemented for this case');
if strcmp(options.mode,'replay')
    assert(isempty(fieldnames(options.budget)),'Replay cannot have an execution budget');
elseif strcmp(options.mode,'capture')&&strcmp(caseId,'semantic')
    assert(isempty(fieldnames(options.budget)),'Semantic demo has its own frozen 40/5s/60s budget');
else
    psaudit_execution_context(options.mode,options.budget); % Validate before mutation.
end
project=char(java.io.File(project).getCanonicalPath());
assert(isfolder(fullfile(project,'电力系统分析与控制作业')),'Project inputs unavailable');
skill=fileparts(fileparts(mfilename('fullpath')));oldPath=path;guard=onCleanup(@()path(oldPath));
addpath(fullfile(skill,'scripts'),fullfile(skill,'examples','hw4'),fullfile(skill,'examples','hw5'), ...
    fullfile(skill,'examples','course'),fullfile(skill,'examples','semantic'),fullfile(skill,'examples','hw5','repair'));
if ~isfield(options,'evidenceDirectory')
    switch caseId
        case 'hw4',options.evidenceDirectory=fullfile(project,'PowerSystemModelAudit','archive','GridModelAudit','validation','hw4-all');
        case 'hw5',options.evidenceDirectory=fullfile(project,'PowerSystemModelAudit','HW5');
        case 'course',options.evidenceDirectory=fullfile(project,'PowerSystemModelAudit','remaining');
        otherwise,options.evidenceDirectory='';
    end
end
if strcmp(options.mode,'replay'),assert(isfolder(options.evidenceDirectory),'Explicit existing evidenceDirectory required');end
result=struct('releaseVersion','0.15','semanticContractVersion','0.12','caseId',caseId, ...
    'mode',options.mode,'status','STARTED','solverCalls',0,'reportFile','','details',[]);
% Capture adapters create their own directory. Other modes are reserved here.
if ~strcmp(options.mode,'capture'),mkdir(out);end
try
    switch caseId
        case 'hw4'
            linear=fullfile(project,'PowerSystemModelAudit','archive','GridModelAudit-HW4','example-run','basicTask1_ED_linear_result.mat');
            [a,cross]=psaudit_hw4_validate_suite(fullfile(project,'电力系统分析与控制作业','HW4'),options.evidenceDirectory,linear,out);
            result.details=struct('audit',a,'cross',cross);result.reportFile=out;
        case 'hw5'
            hw5=fullfile(project,'电力系统分析与控制作业','HW5');
            [a,run]=psaudit_hw5_validate_suite(hw5,out,struct('mode','replay','evidenceDirectory',options.evidenceDirectory));
            psaudit_hw5_write_report(hw5,out);result.details=struct('audit',a,'execution',run);
            result.reportFile=fullfile(out,'audit_report.md');
        case 'course'
            opts=struct('mode',options.mode,'budget',options.budget,'evidenceDirectory',options.evidenceDirectory);
            if isfield(options,'diagnosticDirectory'),opts.diagnosticDirectory=options.diagnosticDirectory;
            elseif strcmp(options.mode,'replay'),opts.diagnosticDirectory=fullfile(options.evidenceDirectory,'diagnostics');end
            [a,run]=psaudit_course_validate(project,out,opts);psaudit_course_write_report(project,out);
            result.details=struct('audit',a,'execution',run);result.solverCalls=run.actionCount;
            result.reportFile=fullfile(out,'audit_report.md');
        case 'hw5-repair'
            if strcmp(options.mode,'capture')
                result.details=psaudit_hw5_repair_run(project,out,options.budget);result.solverCalls=result.details.solverCalls;
                result.status='ACCEPTED';
            else
                result.details=psaudit_hw5_repair_replay(options.evidenceDirectory,fullfile(out,'audit_report.md'));
                result.status='DEFERRED';if result.details.candidateAccepted,result.status='ACCEPTED';end
            end
            result.reportFile=fullfile(out,'audit_report.md');
        case 'semantic'
            if strcmp(options.mode,'capture')
                result.details=psaudit_semantic_demo_run(out);result.solverCalls=result.details.solverCalls;
            else
                saved=load(fullfile(options.evidenceDirectory,'semantic-pilot.mat'),'contract','candidates');
                reports=[];
                for k=1:numel(saved.candidates)
                    reports=[reports psaudit_validate_semantic_candidate(saved.contract,saved.candidates(k))]; %#ok<AGROW>
                end
                result.details=reports;
            end
    end
    if strcmp(result.status,'STARTED'),result.status='COMPLETED';end
    briefFiles=dir(fullfile(out,'*brief.md'));
    result.briefReports=arrayfun(@(x)fullfile(out,x.name),briefFiles,'UniformOutput',false);
    save(fullfile(out,'run-summary.mat'),'result','options');
    writeSummary(fullfile(out,'run-summary.md'),result);
catch err
    result.status='EXECUTION_FAILED';result.error=getReport(err,'extended','hyperlinks','off');
    if ~strcmp(options.mode,'replay')
        result.solverCalls=NaN; % Do not label a partially executed failure as zero calls.
        ledgerFile=fullfile(out,'solver-ledger.mat');
        if isfile(ledgerFile)
            savedLedger=load(ledgerFile);
            if isfield(savedLedger,'run'),result.solverCalls=savedLedger.run.actionCount;
            elseif isfield(savedLedger,'ledger'),result.solverCalls=savedLedger.ledger.actions;end
        end
    end
    if ~isfolder(out),mkdir(out);end
    save(fullfile(out,'run-summary.mat'),'result','options');
    writeSummary(fullfile(out,'run-summary.md'),result);rethrow(err);
end
end
function writeSummary(file,r)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0,'Cannot create run summary');guard=onCleanup(@()fclose(fid));
fprintf(fid,'# PowerSystemModelAudit 统一运行摘要\n\n版本：v%s；语义验收契约：v%s。\n\n',r.releaseVersion,r.semanticContractVersion);
fprintf(fid,'案例：%s；模式：%s；状态：%s；本次新增执行动作/求解调用：%d。\n\n',r.caseId,r.mode,r.status,r.solverCalls);
fprintf(fid,'COMPLETED仅表示审计流程完成，不能解释为全部原模型正确。course诊断动作可能包含潮流等计算，不能全部算优化求解次数。\n\n报告：`%s`\n',r.reportFile);
if isfield(r,'briefReports')
    for k=1:numel(r.briefReports),fprintf(fid,'\n简短报告：`%s`\n',r.briefReports{k});end
end
if isfield(r,'error'),fprintf(fid,'\n执行失败：\n```text\n%s\n```\n',r.error);end
end
