function summary=psaudit_semantic_demo_run(outputDirectory)
% Real small LP solves and replay-only acceptance. Never runs an LLM.
assert(~isfolder(outputDirectory),'Use a new output directory; preserve previous runs');
assert(exist('gurobi','file')~=0,'Gurobi unavailable; cannot capture solver evidence');
mkdir(outputDirectory);here=fileparts(mfilename('fullpath'));
relations=manifest();names={'nominal','stress','light','boundary'};demand=[10 12 6 2];scenarios=[];
for k=1:numel(names)
    p=struct('demand',demand(k),'cheapCapacity',2,'backupCapacity',20, ...
        'cheapCost',1,'backupCost',10,'hours',1);
    a=affine(psaudit_semantic_demo_reference(p));
    scenarios=[scenarios struct('id',names{k},'parameters',p,'relations',relations, ...
        'objectiveId','OBJECTIVE','affineReferences',a)]; %#ok<AGROW>
end
inputFile=fullfile(outputDirectory,'inputs.mat');save(inputFile,'scenarios');
files=struct('field',{},'path',{},'hash',{});
bind('specHash',fullfile(here,'math-spec.md'));
bind('inputHash',inputFile);
bind('checkerHash',which('psaudit_semantic_demo_checks'));
bind('referenceSourceHash',which('psaudit_semantic_demo_reference'));
bind('implementationHelperHash',which('psaudit_semantic_demo_model'));
bind('validatorHash',which('psaudit_validate_semantic_candidate'));
bind('numericKernelHash',which('psaudit_check_relations'));
bind('affineComparatorHash',which('psaudit_compare_affine'));
bindings=struct;for k=1:numel(files),bindings.(files(k).field)=files(k).hash;end
contract=struct('confirmed',true,'unresolvedDefinition',false,'files',files, ...
    'reconstruct',@psaudit_semantic_demo_checks,'scenarios',[], ...
    'objectiveId','OBJECTIVE','requireOptimal',true);
ledger=struct('maxActions',40,'singleSeconds',5,'totalSeconds',60,'actions',0,'seconds',0);
for k=1:numel(scenarios)
    source=which('psaudit_semantic_demo_reference');
    file=fullfile(outputDirectory,['reference-' names{k} '.mat']);
    capture(@psaudit_semantic_demo_reference,scenarios(k).parameters,source,file);
    contract.scenarios=[contract.scenarios struct('id',names{k},'relations',relations, ...
        'referenceFile',file,'referenceHash',psaudit_hash_file(file))]; %#ok<AGROW>
end
functionsList={@psaudit_semantic_demo_candidate,@psaudit_semantic_demo_loose, ...
    @psaudit_semantic_demo_tiny,@psaudit_semantic_demo_cost,@psaudit_semantic_demo_tight,@psaudit_semantic_demo_maximize};
variantNames={'correct','missing_capacity','small_wrong_relaxation','double_cost','overrestriction','wrong_optimization_direction'};
expected={'ACCEPTED','REJECTED','REJECTED','REJECTED','REJECTED','REJECTED'};
reports=[];candidates=[];
for j=1:numel(functionsList)
    fn=functionsList{j};source=which(func2str(fn));
    candidate=struct('sourceFile',source,'sourceHash',psaudit_hash_file(source), ...
        'evaluateImplementation',fn,'runs',[],'beforeCost',10);
    for k=1:numel(scenarios)
        file=fullfile(outputDirectory,[variantNames{j} '-' names{k} '.mat']);
        capture(fn,scenarios(k).parameters,source,file);
        candidate.runs=[candidate.runs struct('scenarioId',names{k}, ...
            'resultFile',file,'resultHash',psaudit_hash_file(file))]; %#ok<AGROW>
    end
    reports=[reports psaudit_validate_semantic_candidate(contract,candidate)]; %#ok<AGROW>
    if ~strcmp(reports(end).status,expected{j})
        save(fullfile(outputDirectory,'failure-snapshot.mat'),'contract','candidate','reports','ledger');
    end
    assert(strcmp(reports(end).status,expected{j}),'Unexpected %s outcome: %s',variantNames{j},reports(end).reason);
    candidates=[candidates candidate]; %#ok<AGROW>
end
assert(~reports(2).coverageComplete&&strcmp(reports(2).scenarios(end).status,'DEFERRED'), ...
    'A dormant mismatch must remain unresolved while other bound violations reject the candidate');
% These controls alter only copied manifests/metadata, not captured real runs.
controls=struct('id',{},'status',{});good=candidates(1);
c=contract;c.confirmed=false;control('untrusted_reference',c,good);
c=contract;c.unresolvedDefinition=true;control('unresolved_definition',c,good);
c=contract;c.files(2).hash=repmat('0',1,64);control('changed_inputs',c,good);
v=good;v.sourceHash=repmat('0',1,64);control('changed_source',contract,v);
v=good;v.runs(end)=[];control('missing_stress_run',contract,v);
v=good;v.runs(2).scenarioId=v.runs(1).scenarioId;control('duplicate_run',contract,v);
v=good;v.runs(1).resultHash=repmat('0',1,64);control('tampered_result',contract,v);
c=contract;c.scenarios(1).relations(3)=[];control('missing_relation_manifest',c,good);
c=contract;c.scenarios(1).relations(2).shape=[1 1];control('partial_index_manifest',c,good);
c=contract;c.scenarios(1).relations(3).absTol=1e6;control('relaxed_tolerance_manifest',c,good);
c=contract;c.reconstruct=@(p,v,z)psaudit_semantic_demo_checks(p,v,z);control('anonymous_unbound_checker',c,good);
c=contract;c.objectiveId='NOT_THE_OBJECTIVE';control('missing_objective_contract',c,good);
assert(ledger.actions==28,'Unexpected number of solver calls');
summary=struct('variants',{variantNames},'reports',reports,'negativeControls',controls, ...
    'solverCalls',ledger.actions,'solverSeconds',ledger.seconds, ...
    'gateSolverCalls',0,'scope','Real 2-generator LPs; not an Agent/ReLoop end-to-end accuracy experiment');
save(fullfile(outputDirectory,'semantic-pilot.mat'),'summary','contract','candidates','ledger');
rows=cell(numel(reports),5);
for j=1:numel(reports)
    rows(j,:)={variantNames{j},reports(j).status,reports(j).afterCosts(1), ...
        reports(j).relativeCostChanges(1),reports(j).costDriftUsedAsGate};
end
writetable(cell2table(rows,'VariableNames',{'variant','decision','nominalObjective','relativeChange','driftUsedAsGate'}),fullfile(outputDirectory,'decisions.csv'));
fprintf('PASS semantic pilot: 6 candidates x 4 scenarios, %d metadata/coverage controls; %d actual LP solves, %.6f solver seconds; gate=0 solves\n',numel(controls),ledger.actions,ledger.seconds);

    function bind(field,path)
        files(end+1)=struct('field',field,'path',path,'hash',psaudit_hash_file(path));
    end
    function capture(fn,p,source,file)
        assert(ledger.actions<ledger.maxActions&&ledger.seconds<ledger.totalSeconds,'Solve budget exhausted');
        model=feval(fn,p);remaining=ledger.totalSeconds-ledger.seconds;
        params=struct('OutputFlag',0,'Threads',1,'Seed',0,'TimeLimit',min(ledger.singleSeconds,remaining));
        timer=tic;sol=gurobi(model,params);elapsed=toc(timer);
        ledger.actions=ledger.actions+1;ledger.seconds=ledger.seconds+elapsed;
        save(fullfile(outputDirectory,'solver-ledger.mat'),'ledger');
        assert(isfield(sol,'x')&&isfield(sol,'objval')&&strcmp(sol.status,'OPTIMAL'),'LP not solved to a valid optimum');
        r=struct('hasSolution',true,'problem',0,'objective',sol.objval,'vars',struct('p',sol.x), ...
            'sourceHash',psaudit_hash_file(source),'bindings',bindings,'evidenceKind','SOLVER_RESULT', ...
            'solver','Gurobi','solverStatus',sol.status,'solverSeconds',elapsed, ...
            'implementationRelations',relations,'affineImplementation',affine(model));
        save(file,'r');
    end
    function control(id,c,v)
        decision=psaudit_validate_semantic_candidate(c,v);
        assert(strcmp(decision.status,'DEFERRED')&&~decision.accepted,'Invalid metadata must not become accepted: %s',id);
        controls(end+1)=struct('id',id,'status',decision.status);
    end
end

function m=manifest()
names={'BALANCE','DOMAIN','CHEAP_CAP','BACKUP_CAP','OBJECTIVE'};
shape={[1 1],[2 1],[1 1],[1 1],[1 1]};sense={'eq','ge','le','le','eq'};units={'MW','MW','MW','MW','USD'};
m=[];
for k=1:numel(names)
    m=[m struct('id',names{k},'shape',shape{k},'sense',sense{k},'unit',units{k},'absTol',1e-7,'relTol',1e-9)]; %#ok<AGROW>
end
end

function a=affine(model)
% Serialization only: independent model matrices are built by separate sources.
a=struct('id','DISPATCH_CONSTRAINTS','kind','constraint', ...
    'A',[full(model.A);eye(2);eye(2)],'b',[model.rhs;model.lb;model.ub], ...
    'rowKeys',{{'balance','lower/g1','lower/g2','upper/g1','upper/g2'}}, ...
    'variableKeys',{{'g1','g2'}},'variableUnits',{{'MW','MW'}}, ...
    'rowUnits',{{'MW','MW','MW','MW','MW'}},'sense',{{'eq','ge','ge','le','le'}}, ...
    'confirmed',true,'basis','Reviewed math-spec.md and bound independent model builder', ...
    'absTol',1e-9,'relTol',1e-9,'objectiveSense','');
b=a;b.id='DISPATCH_COST';b.kind='objective';b.A=model.obj';b.b=0;
b.rowKeys={'cost'};b.rowUnits={'USD'};b.sense={'objective'};
b.objectiveSense=model.modelsense;
a(2)=b;
end
