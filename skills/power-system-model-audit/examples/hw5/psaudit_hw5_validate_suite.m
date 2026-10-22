function [audit,run]=psaudit_hw5_validate_suite(hw5,outdir,options)
% Replay all four saved original solves; never calls optimize or a solver.
if nargin<3,options=struct;end
if ~isfield(options,'mode'),options.mode='replay';end
assert(strcmp(options.mode,'replay'),'This API only replays; capture uses the capture API');
if ~isfield(options,'evidenceDirectory'),options.evidenceDirectory=outdir;end
models={'basicTask2_UC.m','basicTask2_UC_2variable.m','basicTask2_UC_starttime.m','basicTask2_UC_maxstart.m'};
adapter=fileparts(mfilename('fullpath'));
audit=struct('model',{},'resultFile',{},'resultHash',{},'r',{},'s',{},'checks',{},'detail',{});
for k=1:numel(models)
    model=models{k}; file=fullfile(options.evidenceDirectory,'results',[erase(model,'.m') '_result.mat']);
    data=load(file,'r'); r=data.r;
    fields={'sourceHash','caseHash','loadHash','texHash','assignmentHash','specHash'};
    paths={fullfile(hw5,model),fullfile(hw5,'case39_UC.m'),fullfile(hw5,'load3996.mat'), ...
        fullfile(hw5,'HW5.tex'),fullfile(hw5,'稳态大作业2-机组组合.docx'),fullfile(adapter,'math-spec.md')};
    assert(strcmp(r.model,model),'Result model mismatch');
    for j=1:numel(fields)
        assert(isfield(r,fields{j}) && strcmp(r.(fields{j}),psaudit_hash_file(paths{j})), ...
            'Version mismatch: %s / %s',model,fields{j});
    end
    s=psaudit_hw5_build_reference(hw5,model); [checks,detail]=psaudit_hw5_check_solution(r,s);
    audit(k)=struct('model',model,'resultFile',file,'resultHash',psaudit_hash_file(file), ...
        'r',r,'s',s,'checks',checks,'detail',detail);
    fprintf('\nMODEL=%s; problem=%d; objective=%.12f; categories=%d\n',model,r.problem,r.objective,numel(checks));
    for j=1:numel(checks)
        c=checks(j);
        fprintf('%s %s max=%.10g bad=%d at=%s actual=%.10g expected=%.10g tol=%.10g\n', ...
            c.id,c.status,c.maxResidual,c.count,c.position,c.actual,c.expected,c.tolerance);
    end
    fprintf('EVENTS start=%g stop=%g; generationCost=%.10f; eventCost=%.10f; wrapUpMax=%.10g\n', ...
        sum(detail.start,'all'),sum(detail.stop,'all'),detail.generationCost,detail.actualEventCost,detail.maxWrapUp);
    if isfield(r,'solverOutput')
        fprintf('SOLVER_OUTPUT_FIELDS=%s\n',strjoin(fieldnames(r.solverOutput),','));
        so=r.solverOutput;
        if isfield(so,'result'), so=so.result; end
        for field={'status','objval','objbound','mipgap','runtime','nodecount'}
            if isfield(so,field{1})
                v=so.(field{1}); if ischar(v), fprintf('%s=%s\n',field{1},v); else, fprintf('%s=%.12g\n',field{1},v); end
            end
        end
    end
end
run=psaudit_execution_context('replay').snapshot();run.evidenceDirectory=options.evidenceDirectory;
if ~isfolder(outdir),mkdir(outdir);end
save(fullfile(outdir,'validation.mat'),'audit','run','-v7');
fprintf('PSAUDIT_HW5_REPLAY_DONE: %d models; %d categories; zero additional solves.\n',numel(audit),sum(arrayfun(@(x)numel(x.checks),audit)));
end
