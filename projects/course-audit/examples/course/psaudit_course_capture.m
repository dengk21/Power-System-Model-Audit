function file=psaudit_course_capture(project,relative,outdir,config)
% Capture current original computation, preserving all source/input bytes.
source=fullfile(project,'电力系统分析与控制作业',relative); assert(isfile(source));
if nargin<4,config=struct;end
if ~isfield(config,'mode'),config.mode='capture';end
assert(ismember(config.mode,{'capture','diagnose'}),'Replay must never call the capture API');
if isfield(config,'reuseFitFile'),assert(strcmp(config.mode,'diagnose'),'UC-only altered execution requires explicit diagnose mode');end
if strcmp(config.mode,'diagnose'),assert(isfield(config,'reuseFitFile'),'Use validate diagnose mode for independent probes');end
if ~isfield(config,'executionDirectory'),config.executionDirectory=fileparts(source);end
file=fullfile(outdir,[strrep(strrep(relative,'/','_'),'.m','') '_result.mat']);
assert(~isfile(file),'Original result already captured');
if ~isfolder(outdir), mkdir(outdir); end
code=fileread(source); code=strrep(code,sprintf('\r\n'),sprintf('\n'));
if isfield(config,'reuseFitFile')
    assert(endsWith(relative,'Task2_2_linear.m') && isfile(config.reuseFitFile));
    beginFit=strfind(code,'%% 线性化最低点频率表达式优化');endFit=strfind(code,'%% 决策变量');
    assert(isscalar(beginFit)&&isscalar(endFit)&&endFit>beginFit);
    fitPath=strrep(config.reuseFitFile,"'","''");
    code=[code(1:beginFit-1) sprintf('auditFitCache=load(''%s'',''linear''); linear=auditFitCache.linear;\n',fitPath) code(endFit:end)];
end
code=regexprep(code,'(?m)^\s*(clc|clear(?:\s+all)?|clearvars|close all)\s*;[^\r\n]*$','');
code=regexprep(code,'(?m)^\s*(save|saveas|movefile|writematrix)\([^\r\n]*\);[^\r\n]*$','');
assert(isempty(regexp(code,'(?m)^\s*(clear|clearvars|save|saveas|movefile|writematrix)\b','once')), ...
    'Unstripped reset/file mutation: inspect original layout before execution');
% Only cut final post-solve rendering, keeping earlier fit and both solve stages.
if startsWith(relative,'HW6/') || startsWith(relative,'HW10/')
    marker=regexp(code,'(?m)^%% 结果处理','start');
    if ~isempty(marker), code=code(1:marker(end)-1); end
end
if startsWith(relative,'HW7/')
    if contains(relative,'Task4_')
        marker=regexp(code,'(?m)^% 各时段负荷折线图','start');
        if ~isempty(marker), code=code(1:marker(1)-1); end
        code=strrep(code,'while(UB - LB > tol)','while(UB - LB > tol && iteration < 5 && toc(auditClock) < 240)');
    else
        marker=regexp(code,'(?m)^%% 日[前内][^\r\n]*结果处理','start');
        if ~isempty(marker), code=code(1:marker(end)-1); end
    end
end
if startsWith(relative,'HW7/')&&~endsWith(relative,'test.m')
    assert(contains(code,'optimize('),'Capture cut removed the actual solver entry');
end
% Runtime controls only; original solver name is retained, absent selection stays auto.
code=regexprep(code,"sdpsettings\('solver',\s*'gurobi',\s*'verbose',\s*[023]\)", ...
    "sdpsettings('solver','gurobi','verbose',0,'savesolveroutput',1,'gurobi.TimeLimit',120,'gurobi.Threads',4)");
code=strrep(code,'result = optimize(Constraints, Objective);', ...
    "result = optimize(Constraints,Objective,sdpsettings('verbose',0,'savesolveroutput',1,'gurobi.TimeLimit',120,'gurobi.Threads',4));");
% This load reads precisely the checkpoint just computed in the same script.
if endsWith(relative,'FCUC_xhr.m')
    code=strrep(code,"load('parameter.mat', 'parameter');", ...
        "assert(exist('parameter','var')==1,'Internal fit checkpoint missing');");
end
if isfield(config,'fitGap')
    assert(endsWith(relative,'Task2_2_linear.m') && config.fitGap>0 && config.fitGap<=0.2);
    code=strrep(code,'linear.result = optimize(linear.constraints, linear.obj, options);', ...
        sprintf('options.gurobi.MIPGap=%.15g; linear.result = optimize(linear.constraints, linear.obj, options);',config.fitGap));
end
code=regexprep(code,'(?m)^optimize\(([^\r\n;]*)\);','auditLastResult=optimize($1);');
% Add output capture to bare runpf calls, without changing their options/math.
code=regexprep(code,'(?m)^runpf\(([^\r\n]*)\);','auditPFRuns{end+1}=runpf($1);');
fprintf('COURSE_BEGIN %s\n',relative);
r=execute(code,config.executionDirectory);
r.relative=relative; r.sourceHash=psaudit_hash_file(source); r.matlab=version;
r.specHash=psaudit_hash_file(fullfile(fileparts(mfilename('fullpath')),'math-spec.md'));
r.inputs=manifest(fileparts(source)); r.sourceDirectory=fileparts(source);
r.config=config; r.executionMode=config.mode; r.runtimeInputs=manifest(config.executionDirectory);
r.runControls='rng=20261008, figures hidden, file writes suppressed; Gurobi each120s/4threads; C&CG<=5 iterations/240s outer guard';
save(file,'r','-v7');
fprintf('COURSE_CAPTURE %s completed=%d elapsed=%.3f error=%s\n',relative,r.completed,r.elapsed,r.error);
end

function r=execute(auditCode,auditDirectory)
auditPrevious=pwd; auditPath=path; auditVisibility=get(groot,'DefaultFigureVisible');
auditCleanup=onCleanup(@()restore(auditPrevious,auditPath,auditVisibility));
cd(auditDirectory); addpath(auditDirectory,'-begin');
clear runpf fdpf pfsoln newtonpf newtonpf_S_cart case39_UC case39_FCUC case39_d
set(groot,'DefaultFigureVisible','off'); rng(20261008,'twister'); yalmip('clear');
auditPFRuns={}; auditClock=tic; r=struct('completed',false,'error','','elapsed',NaN,'vars',struct,'log','');
try
    r.log=evalc('eval(auditCode)'); r.completed=true;
catch auditException
    r.error=getReport(auditException,'extended','hyperlinks','off');
end
r.elapsed=toc(auditClock);
auditW=whos;
for auditIndex=1:numel(auditW)
    auditName=auditW(auditIndex).name;
    if startsWith(auditName,'audit') || strcmp(auditName,'r'), continue; end
    try
        auditValue=eval(auditName); [auditKeep,auditValue]=numeric(auditValue,0);
        if auditKeep, r.vars.(auditName)=auditValue; end
    catch
    end
end
if exist('auditLastResult','var'),r.lastSolverResult=numericResult(auditLastResult);end
r.pfRuns=auditPFRuns; r.paths=struct('runpf',which('runpf'),'fdpf',which('fdpf'), ...
    'pfsoln',which('pfsoln'),'newtonpf',which('newtonpf'),'newtonpf_S_cart',which('newtonpf_S_cart'));
end

function r=numericResult(x)
[~,r]=numeric(x,0);
end

function [keep,x]=numeric(x,depth)
keep=false; if depth>4, return; end
if isa(x,'sdpvar')||isa(x,'ndsdpvar'), x=value(x); keep=numel(x)<=2e5;
elseif isnumeric(x)||islogical(x)||ischar(x)||isstring(x), keep=numel(x)<=2e5;
elseif isstruct(x) && isscalar(x)
    y=struct; names=fieldnames(x);
    for k=1:numel(names), [ok,v]=numeric(x.(names{k}),depth+1); if ok,y.(names{k})=v;end;end
    keep=true; x=y;
elseif isa(x,'RegressionSVM'), x=struct('Beta',x.Beta,'Bias',x.Bias); keep=true;
elseif isa(x,'tf'), [n,d]=tfdata(x,'v'); x=struct('num',n,'den',d); keep=true;
end
end

function m=manifest(directory)
files=[dir(fullfile(directory,'*.m'));dir(fullfile(directory,'*.tex'));dir(fullfile(directory,'*.mat'));dir(fullfile(directory,'*.csv'));dir(fullfile(directory,'*.docx'))];
m=struct('name',{},'hash',{});
for k=1:numel(files), m(end+1)=struct('name',files(k).name,'hash',psaudit_hash_file(fullfile(directory,files(k).name)));end
end

function restore(directory,paths,visibility)
cd(directory); path(paths); set(groot,'DefaultFigureVisible',visibility); close all force;
clear runpf fdpf pfsoln newtonpf newtonpf_S_cart case39_UC case39_FCUC case39_d
end
