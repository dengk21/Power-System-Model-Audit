function [summary,cross]=psaudit_hw4_validate_suite(hw4,outdir,linearResult,reportDir)
% Replay all five real model results through the common core, zero solves.
if nargin<4, reportDir=fullfile(outdir,'common-core-replay'); end
models={'basicTask1_ED_linear.m','basicTask1_ED_linear_seg.m', ...
    'basicTask1_ED_Quadratic.m','basicTask1_ED_Flow.m','basicTask1_ED_Ramp.m'};
psaudit_test_core; psaudit_hw4_test_adapter; psaudit_test_model_review;
summary=struct('model',{},'problem',{},'checks',{},'violations',{},'missing',{},'objective',{},'elapsed',{},'result',{},'report',{});
for k=1:numel(models)
    model=models{k}; f=fullfile(outdir,[erase(model,'.m') '_result.mat']);
    if k==1, f=linearResult; end
    report=fullfile(reportDir,[erase(model,'.m') '_audit_report.md']);
    c=psaudit_hw4_write_report(hw4,model,f,report);
    d=load(f,'r'); r=d.r;
    row=struct('model',model,'problem',r.problem,'checks',numel(c), ...
        'violations',nnz(strcmp({c.status},'VIOLATION')), ...
        'missing',nnz(strcmp({c.status},'DATA_INSUFFICIENT')), ...
        'objective',r.objective,'elapsed',r.elapsed,'result',f,'report',report);
    summary(end+1)=row;
    fprintf('VALIDATED=%s,problem=%d,checks=%d,violations=%d,missing=%d,cost=%.12g,time=%.6g\n', ...
        row.model,row.problem,row.checks,row.violations,row.missing,row.objective,row.elapsed);
end
assert(all([summary.problem]==0) && all([summary.missing]==0),'A model did not complete usable verification');
cost=[summary.objective];
items=struct('id','M_LINEAR_SEG_EQUIV_COST','actual',cost(2),'expected',cost(1), ...
    'sense','eq','unit','USD','absTol',1e-4,'relTol',1e-8);
items(2)=struct('id','M_FLOW_RESTRICT_COST','actual',cost(4),'expected',cost(3), ...
    'sense','ge','unit','USD','absTol',1e-4,'relTol',1e-8);
items(3)=struct('id','M_RAMP_RELAX_COST','actual',cost(5),'expected',cost(3), ...
    'sense','le','unit','USD','absTol',1e-4,'relTol',1e-8);
cross=psaudit_check_relations(items);
for k=1:numel(cross)
    fprintf('CROSS=%s,status=%s,actual=%.12g,reference=%.12g,residual=%.12g\n', ...
        cross(k).id,cross(k).status,cross(k).actual,cross(k).expected,cross(k).maxResidual);
end
end
