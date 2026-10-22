function report=psaudit_validate_semantic_candidate(contract,candidate)
% Replay bound results against a reviewed independent contract, then gate.
% Never solves. Named deterministic adapters supply numeric relations.
% Accepts only the declared scenario/row manifests, not global equivalence.
report=struct('accepted',false,'status','DEFERRED','reason','', ...
    'evidenceLevel','BOUND_SEMANTIC_REPLAY','costDriftUsedAsGate',false, ...
    'scope','Declared scenarios, shapes and reference trajectories; no whole-feasible-region or universal optimality guarantee', ...
    'scenarios',[],'beforeCost',NaN,'afterCosts',[],'relativeCostChanges',[], ...
    'solverOptimalityReported',false,'coverageComplete',false,'validationMode','UNDECLARED');
try
    need={'confirmed','unresolvedDefinition','files','reconstruct','scenarios','objectiveId','requireOptimal'};
    assert(all(isfield(contract,need)),'Incomplete semantic contract');
    assert(isequal(contract.requireOptimal,true)||isequal(contract.requireOptimal,false),'Declare logical requireOptimal explicitly');
    if contract.requireOptimal,report.validationMode='REFERENCE_OPTIMUM';else,report.validationMode='FEASIBILITY';end
    if ~isequal(contract.confirmed,true)||~isequal(contract.unresolvedDefinition,false)
        report.reason='Independent definitions unconfirmed or unresolved';return;
    end
    bindings=verify_files(contract.files);
    assert(all(isfield(bindings,{'specHash','inputHash','checkerHash','referenceSourceHash'})),'Missing required file bindings');
    assert(all(isfield(candidate,{'sourceFile','sourceHash','evaluateImplementation','runs'})),'Incomplete candidate');
    assert(strcmp(psaudit_hash_file(candidate.sourceFile),candidate.sourceHash),'Candidate source changed');
    assert(named_file(contract.reconstruct,file_for(contract.files,'checkerHash')),'Independent callback/file mismatch');
    assert(named_file(candidate.evaluateImplementation,candidate.sourceFile),'Implementation callback/file mismatch');
    inputs=load(file_for(contract.files,'inputHash'),'scenarios');
    assert(isfield(inputs,'scenarios')&&isstruct(inputs.scenarios),'Missing frozen input scenarios');
    declared=ids(contract.scenarios,'id');supplied=ids(candidate.runs,'scenarioId');dataIds=ids(inputs.scenarios,'id');
    assert(~isempty(declared)&&isequal(sort(declared),sort(supplied))&&isequal(sort(declared),sort(dataIds)), ...
        'Missing, extra or duplicate scenario');
    if isfield(candidate,'beforeCost')&&isnumeric(candidate.beforeCost)&&isscalar(candidate.beforeCost)&&isfinite(candidate.beforeCost)
        report.beforeCost=candidate.beforeCost;
    end
    allChecks=[];allOptimal=true;states=cell(numel(declared),1);
    for k=1:numel(declared)
        s=contract.scenarios(k);run=candidate.runs(strcmp(s.id,supplied));
        input=inputs.scenarios(strcmp(s.id,dataIds));
        rec=struct('id',s.id,'status','DEFERRED','reason','','candidateChecks',[], ...
            'referenceChecks',[],'referenceMembershipChecks',[],'objective',NaN, ...
            'referenceObjective',NaN,'candidateProblem',NaN,'referenceProblem',NaN,'affineComparisons',[], ...
            'optimalValueChecks',[],'referenceAffineComparisons',[]);
        try
            assert(all(isfield(s,{'relations','referenceFile','referenceHash'}))&&isfield(input,'parameters'),'Incomplete scenario contract');
            assert(all(isfield(input,{'relations','objectiveId'}))&&isequaln(s.relations,input.relations)&& ...
                strcmp(contract.objectiveId,input.objectiveId),'Scope/tolerance manifest differs from frozen input');
            assert(all(isfield(run,{'resultFile','resultHash'})),'Incomplete scenario run');
            r=read_result(run.resultFile,run.resultHash,candidate.sourceHash,bindings);
            ref=read_result(s.referenceFile,s.referenceHash,bindings.referenceSourceHash,bindings);
            rec.objective=r.objective;rec.referenceObjective=ref.objective;
            rec.candidateProblem=r.problem;rec.referenceProblem=ref.problem;
            isOptimal=r.problem==0&&ref.problem==0;allOptimal=allOptimal&&isOptimal;
            if isfield(contract,'requireOptimal')&&isequal(contract.requireOptimal,true)
                assert(isOptimal,'Optimality required but not established');
            end
            referenceItems=feval(contract.reconstruct,input.parameters,ref.vars,ref.objective);
            rec.referenceChecks=checked(referenceItems,s.relations,contract.objectiveId,ref.objective);
            assert(all(strcmp({rec.referenceChecks.status},'PASS')),'Reference trajectory/contract invalid or incomplete');
            items=feval(contract.reconstruct,input.parameters,r.vars,r.objective);
            rec.candidateChecks=checked(items,s.relations,contract.objectiveId,r.objective);
            if isfield(contract,'requireOptimal')&&isequal(contract.requireOptimal,true)
                % Two reported optima must agree under this same reviewed
                % objective/scope. Feasible membership alone misses max/min.
                m=s.relations(strcmp({s.relations.id},contract.objectiveId));
                z=struct('id','DERIVED_REFERENCE_OPTIMUM','actual',r.objective,'expected',ref.objective, ...
                    'unit',m.unit,'sense','eq','absTol',m.absTol,'relTol',m.relTol);
                rec.optimalValueChecks=psaudit_check_relations(z);
            end
            memberItems=feval(candidate.evaluateImplementation,input.parameters,ref.vars,ref.objective);
            rec.referenceMembershipChecks=checked(memberItems,r.implementationRelations,contract.objectiveId,ref.objective);
            affineKnown=true;
            if isfield(input,'affineReferences')&&~isempty(input.affineReferences)
                assert(isfield(r,'affineImplementation'),'Missing declared affine representation');
                assert(isfield(ref,'affineImplementation'),'Missing independent reference representation');
                refIds=ids(input.affineReferences,'id');implIds=ids(r.affineImplementation,'id');
                assert(isequal(sort(refIds),sort(implIds)),'Missing or extra affine block');
                builtRefIds=ids(ref.affineImplementation,'id');
                assert(isequal(sort(refIds),sort(builtRefIds)),'Reference model affine coverage differs');
                for q=1:numel(refIds)
                    referenceCmp=psaudit_compare_affine(input.affineReferences(q),ref.affineImplementation(strcmp(refIds{q},builtRefIds)));
                    rec.referenceAffineComparisons=[rec.referenceAffineComparisons referenceCmp]; %#ok<AGROW>
                    assert(strcmp(referenceCmp.status,'MATCH'),'Reference solver model differs from reviewed affine specification');
                    cmp=psaudit_compare_affine(input.affineReferences(q),r.affineImplementation(strcmp(refIds{q},implIds)));
                    rec.affineComparisons=[rec.affineComparisons cmp]; %#ok<AGROW>
                    affineKnown=affineKnown&&strcmp(cmp.status,'MATCH');
                end
            end
            combined=[rec.candidateChecks rec.referenceMembershipChecks rec.optimalValueChecks];
            if any(strcmp({combined.status},'DATA_INSUFFICIENT'))||any(strcmp({combined.status},'NOT_APPLICABLE'))
                rec.reason='Incomplete independent checks or applicability';
            elseif any(strcmp({combined.status},'VIOLATION'))
                rec.status='REJECTED';rec.reason='Candidate violates independent relations/objective or rejects a complete reference trajectory';
            elseif ~affineKnown
                rec.reason='Affine representation differs or cannot be verified; finite points do not resolve dormant defects or implicit equivalence';
            else
                rec.status='PASS';rec.reason='Declared candidate and reference trajectory checks pass';
            end
            allChecks=[allChecks combined]; %#ok<AGROW>
        catch failure
            rec.reason=failure.message;allOptimal=false;
        end
        report.scenarios=[report.scenarios rec]; %#ok<AGROW>
        states{k}=rec.status;
    end
    report.afterCosts=[report.scenarios.objective];
    if isfinite(report.beforeCost)&&report.beforeCost~=0
        report.relativeCostChanges=(report.afterCosts-report.beforeCost)/abs(report.beforeCost);
    end
    report.solverOptimalityReported=allOptimal;
    report.coverageComplete=~any(strcmp(states,'DEFERRED'));
    % A bound counterexample is sufficient to reject. Unresolved other cases
    % still forbid acceptance, but cannot erase an established violation.
    if any(strcmp(states,'REJECTED')),report.status='REJECTED';report.reason='Confirmed semantic or reference-membership violation';return;end
    if ~report.coverageComplete,report.reason='Missing, unbound or contradictory evidence; see scenario records';return;end
    evidence=struct('scopeVerified',true,'referenceVerified',true,'hasValidSolution',true, ...
        'checks',allChecks,'referenceAccepted',true,'objectiveConsistent',true, ...
        'fullCoverage',true,'unresolvedDefinition',false);
    decision=psaudit_repair_gate(evidence);
    report.accepted=decision.accepted;report.status=decision.status;report.reason=decision.reason;
catch failure
    report.reason=failure.message;
end
end

function bindings=verify_files(files)
assert(isstruct(files)&&~isempty(files)&&all(isfield(files,{'field','path','hash'})),'Invalid protected file inventory');
ids(files,'field');bindings=struct;
for k=1:numel(files)
    f=files(k);assert(isvarname(f.field),'Invalid binding name');
    assert(strcmp(psaudit_hash_file(f.path),f.hash),'Protected file changed: %s',f.field);
    bindings.(f.field)=f.hash;
end
end

function p=file_for(files,field)
at=find(strcmp({files.field},field));assert(isscalar(at),'Missing or duplicate file binding: %s',field);p=files(at).path;
end

function yes=named_file(f,file)
yes=false;if ~isa(f,'function_handle'),return;end
info=functions(f);if ~strcmp(info.type,'simple')||isempty(info.file),return;end
yes=strcmpi(char(java.io.File(info.file).getCanonicalPath()),char(java.io.File(file).getCanonicalPath()));
end

function values=ids(records,field)
assert(isstruct(records)&&~isempty(records)&&all(isfield(records,field)),'Missing manifest');
values={records.(field)};
assert(all(cellfun(@(x)ischar(x)&&isrow(x)&&~isempty(x),values)),'Manifest IDs must be nonempty char rows');
assert(numel(unique(values))==numel(values),'Duplicate manifest IDs');
end

function r=read_result(file,hash,sourceHash,bindings)
assert(strcmp(psaudit_hash_file(file),hash),'Result file changed');
saved=load(file,'r');assert(isfield(saved,'r')&&isstruct(saved.r)&&isscalar(saved.r),'Missing result r');r=saved.r;
required={'hasSolution','problem','objective','vars','sourceHash','bindings','evidenceKind','implementationRelations'};
assert(all(isfield(r,required)),'Incomplete captured result');
assert(isequal(r.hasSolution,true)&&isscalar(r.problem)&&ismember(r.problem,[0 3]),'No valid incumbent');
assert(strcmp(r.evidenceKind,'SOLVER_RESULT'),'Analytical/local points are not captured candidate execution');
assert(isnumeric(r.objective)&&isreal(r.objective)&&isscalar(r.objective)&&isfinite(r.objective),'Invalid objective');
assert(isstruct(r.vars)&&isscalar(r.vars)&&~isempty(fieldnames(r.vars)),'Missing complete numeric variables');
for f=fieldnames(r.vars)'
    v=r.vars.(f{1});assert(isnumeric(v)&&isreal(v)&&~isempty(v)&&all(isfinite(v(:))),'Nonfinite or nonnumeric variables');
end
assert(strcmp(r.sourceHash,sourceHash),'Result/source mismatch');
for f=fieldnames(bindings)'
    assert(isfield(r.bindings,f{1})&&strcmp(r.bindings.(f{1}),bindings.(f{1})),'Result/input/reference/checker mismatch');
end
end

function checks=checked(items,manifest,objectiveId,objective)
expected=ids(manifest,'id');actual=ids(items,'id');
assert(isequal(sort(expected),sort(actual)),'Relation coverage differs from frozen manifest');
assert(sum(strcmp(expected,objectiveId))==1,'Manifest lacks unique objective relation');
assert(all(isfield(manifest,{'shape','unit','sense','absTol','relTol'})),'Incomplete relation manifest');
ordered=[];
for k=1:numel(manifest)
    m=manifest(k);x=items(strcmp(actual,m.id));
    assert(all(isfield(x,{'actual','expected','unit','sense'})),'Incomplete reconstructed relation');
    assert(isnumeric(m.shape)&&numel(m.shape)>=2&&all(isfinite(m.shape))&&all(m.shape>=1)&&all(mod(m.shape,1)==0),'Invalid declared shape');
    n=max(ndims(x.actual),numel(m.shape));shape=size(x.actual);shape(end+1:n)=1;
    wanted=m.shape(:)';wanted(end+1:n)=1;assert(isequal(shape,wanted),'Relation shape differs from declared complete indices');
    assert(strcmp(x.unit,m.unit)&&strcmp(x.sense,m.sense),'Relation unit or sense changed');
    assert(~isfield(x,'mask')||isempty(x.mask)||all(x.mask(:)),'Partial masks cannot satisfy full semantic coverage');
    assert(~isfield(x,'scale')||isempty(x.scale),'Adapter-selected scale cannot override frozen tolerance');
    if strcmp(m.id,objectiveId)
        assert(isequal(x.actual,objective)&&strcmp(x.sense,'eq'),'Objective check must use captured objective');
    end
    % Never trust tolerances/extra mask fields supplied by the adapter.
    z=struct('id',m.id,'actual',x.actual,'expected',x.expected,'unit',m.unit, ...
        'sense',m.sense,'absTol',m.absTol,'relTol',m.relTol);
    ordered=[ordered z]; %#ok<AGROW>
end
checks=psaudit_check_relations(ordered);
end
