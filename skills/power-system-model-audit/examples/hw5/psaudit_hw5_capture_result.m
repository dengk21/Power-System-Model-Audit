function file=psaudit_hw5_capture_result(hw5,model,outdir,seconds)
% One real original-model solve; no changes to objective/constraints/inputs.
if nargin<4, seconds=120; end
assert(seconds>0 && seconds<=120,'Single solve budget must be <=120 s');
models={'basicTask2_UC.m','basicTask2_UC_2variable.m','basicTask2_UC_starttime.m','basicTask2_UC_maxstart.m'};
assert(ismember(model,models),'Unsupported HW5 entry');
source=fullfile(hw5,model); code=fileread(source);
cut=strfind(code,'%% 结果处理'); assert(isscalar(cut),'Unexpected source layout'); code=code(1:cut-1);
code=regexprep(code,'(?m)^\s*(clc|clear|close all);\s*$','');
needle="options = sdpsettings('solver', 'gurobi', 'verbose', 2);";
assert(contains(code,needle),'Original solver setup changed');
replacement=sprintf("options = sdpsettings('solver','gurobi','verbose',0,'savesolveroutput',1,'gurobi.TimeLimit',%.15g,'gurobi.Threads',4);",seconds);
code=strrep(code,needle,replacement);
if ~isfolder(outdir), mkdir(outdir); end
file=fullfile(outdir,[erase(model,'.m') '_result.mat']); assert(~isfile(file),'Result exists');
r=execute(code,hw5);
r.model=model; r.sourceHash=psaudit_hash_file(source);
r.caseHash=psaudit_hash_file(fullfile(hw5,'case39_UC.m'));
r.loadHash=psaudit_hash_file(fullfile(hw5,'load3996.mat'));
r.texHash=psaudit_hash_file(fullfile(hw5,'HW5.tex'));
r.assignmentHash=psaudit_hash_file(fullfile(hw5,'稳态大作业2-机组组合.docx'));
r.specHash=psaudit_hash_file(fullfile(fileparts(mfilename('fullpath')),'math-spec.md'));
r.matlab=version; r.yalmip=yalmip('version'); r.solverPath=which('gurobi');
r.timeLimit=seconds; r.executionMode='capture'; r.created=char(datetime('now','TimeZone','Asia/Shanghai'));
save(file,'r','-v7');
fprintf('CAPTURED=%s,problem=%d,usable=%d,time=%.6g\n',model,r.problem,r.hasSolution,r.elapsed);
end

function r=execute(code,hw5)
previous=pwd; cleanup=onCleanup(@() cd(previous)); cd(hw5);
r=struct('hasSolution',false,'problem',NaN,'info','','elapsed',NaN,'solveCount',0,'executionError','');
try
    eval(code);
    r.problem=result.problem; r.info=result.info; r.elapsed=solutionTime; r.solveCount=1;
    r.p=value(var.Pb); r.u=value(var.U); r.Pg=value(var.Pg);
    r.Pic=value(Pic); r.F=value(branchPF); r.objective=value(obj);
    if isfield(var,'Uaction')
        r.action=value(var.Uaction); r.actionCost=value(var.CostAction); r.formulation='two-variable';
    else
        r.start=value(var.Ustart); r.stop=value(var.Ushut); r.formulation='three-variable';
    end
    r.hasSolution=ismember(result.problem,[0 3]) && all(isfinite(r.p(:))) && all(isfinite(r.u(:))) && isfinite(r.objective);
    if isfield(result,'solveroutput'), r.solverOutput=result.solveroutput; end
catch e
    r.executionError=getReport(e,'extended','hyperlinks','off'); r.info=e.message;
    if exist('result','var'), r.solveCount=1; r.problem=result.problem; end
end
end
