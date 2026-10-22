function resultFile = psaudit_hw4_capture_result(hw4,model,outdir,seconds,specPath)
% One bounded real solve of the original active model; no source-file edits.
if nargin<4, seconds=60; end
if nargin<5, specPath=fullfile(fileparts(mfilename('fullpath')),'math-spec.md'); end
assert(seconds>0 && seconds<=60,'Initial tool supports 0 < time limit <= 60 s');
s=psaudit_hw4_build_reference(hw4,model,specPath); %#ok<NASGU>
source=fullfile(hw4,model); code=fileread(source);
cut=strfind(code,'%% 结果处理'); assert(isscalar(cut),'Unknown script layout');
code=code(1:cut-1);
% Remove workspace/UI housekeeping only; preserve all model expressions.
code=regexprep(code,'(?m)^\s*(clc|clear|close all);\s*$','');
solver='gurobi'; solverFunction='gurobi';
if strcmp(model,'basicTask1_ED_Flow.m'), solver='copt'; solverFunction='copt_solve'; end
assert(~isempty(which(solverFunction)),'Missing original solver: %s',solver);
needle=sprintf("options = sdpsettings('solver', '%s', 'verbose', 2);",solver);
assert(contains(code,needle),'Unknown solver setup');
replacement=sprintf("options = sdpsettings('solver','%s','verbose',0,'%s.TimeLimit',%.15g);",solver,solver,seconds);
code=strrep(code,needle,replacement);
if ~isfolder(outdir), mkdir(outdir); end
resultFile=fullfile(outdir,[erase(model,'.m') '_result.mat']);
assert(~isfile(resultFile),'Result already exists; choose another output directory');
r=execute(code,hw4);
r.model=model; r.sourcePath=source; r.sourceHash=psaudit_hash_file(source);
r.caseHash=psaudit_hash_file(fullfile(hw4,'case39_ED.m'));
r.loadHash=psaudit_hash_file(fullfile(hw4,'load3996.mat')); r.specHash=psaudit_hash_file(specPath);
r.created=char(datetime('now','TimeZone','Asia/Shanghai')); r.matlab=version;
r.solveCount=1; r.timeLimit=seconds; r.executionMode='capture';
r.yalmipVersion=yalmip('version'); r.gurobiPath=which('gurobi');
r.solver=solver; r.solverPath=which(solverFunction);
save(resultFile,'r','-v7');
end

function r=execute(code,hw4)
previous=pwd; cleanup=onCleanup(@() cd(previous)); cd(hw4);
eval(code); % Executes only locally selected, previously inspected HW4 code.
r=struct; r.problem=result.problem; r.info=result.info;
r.elapsed=solutionTime;
if ndims(var.Pb)==3
    r.q=value(var.Pb); r.p=reshape(sum(r.q,2),num.I,num.T);
else, r.p=value(var.Pb); end
r.Pg=value(var.Pg); r.Pic=value(var.Pic); r.F=value(branchPF);
if exist('obj_linear','var'), r.objective=value(obj_linear);
else, r.objective=value(obj); end
% Keep non-optimal incumbents only if values are finite; report optimality separately.
r.hasSolution=all(isfinite(r.p(:))) && all(isfinite(r.Pic(:))) && ...
    all(isfinite(r.F(:))) && isfinite(r.objective) && ismember(result.problem,[0 3]);
end
