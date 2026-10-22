function summary=psaudit_hw5_repair_run(project,outputDirectory,budget)
% One frozen repair, 3 full scenarios, real Gurobi capture followed by v0.12.
if nargin<3,budget=struct('maxActions',9,'singleSeconds',60,'totalSeconds',360);end
assert(~isfolder(outputDirectory),'Use a new directory; preserve earlier evidence');
assert(budget.maxActions<=9&&budget.singleSeconds<=60&&budget.totalSeconds<=360,'Budget exceeds frozen plan');
assert(exist('gurobi','file')~=0&&exist('sdpvar','file')~=0,'Gurobi/YALMIP required');
mkdir(outputDirectory);hw5=fullfile(project,'电力系统分析与控制作业','HW5');here=fileparts(mfilename('fullpath'));
originalFile=fullfile(hw5,'basicTask2_UC_2variable.m');originalTex=fullfile(hw5,'HW5.tex');
candidateFile=fullfile(outputDirectory,'basicTask2_UC_2variable_repaired.m');
code=fileread(originalFile);needle='HMatrix = [zeros(1, num.T); HMatrix(1:end, :)];';
assert(numel(strfind(code,needle))==1,'Original minimum-time expression changed');
fixed=strrep(code,needle,'HMatrix = [HMatrix(1:end, :); zeros(1, num.T)];');write(candidateFile,fixed);
candidateTex=fullfile(outputDirectory,'HW5_minimum_time_repaired.tex');text=fileread(originalTex);
oldOn='\sum_{k=t+1}^{t+T_i^o} x_{i, k}';newOn='\sum_{k=0}^{T_i^o-1} x_{i, 1+\operatorname{mod}(t-1+k,T)}';
oldOff='\sum_{k=t+1}^{t+T_i^c}\left(1-x_{i, k}\right)';newOff='\sum_{k=0}^{T_i^c-1}\left(1-x_{i, 1+\operatorname{mod}(t-1+k,T)}\right)';
assert(contains(text,oldOn)&&contains(text,oldOff),'Original TeX expressions changed');
text=strrep(strrep(text,oldOn,newOn),oldOff,newOff);
text=strrep(strrep(text,'T-T_i^o','T'),'T-T_i^c','T');
needleTex='最小机组启动停机时间约束如下所示：';
text=strrep(text,needleTex,[needleTex newline ...
    '此处最小持续时段包含动作当期，$T_i^o=T_i^c=4$，每时段15分钟；状态采用周期延拓$x_{i,0}=x_{i,T}$，并定义$z_{i,t}=x_{i,t}-x_{i,t-1}$于全部$t=1,\ldots,T$。']);
write(candidateTex,text);
mpc=loadcase(fullfile(hw5,'case39_UC.m'));data=load(fullfile(hw5,'load3996.mat'),'Pd');
s=psaudit_hw5_build_reference(hw5,'basicTask2_UC_2variable.m');
base=struct('s',s,'mpc',mpc,'Pd',data.Pd,'originalFile',originalFile,'candidateFile',candidateFile, ...
    'selectorUnit',3,'referenceState',[]);
v=struct('p',zeros(s.I,s.T),'u',zeros(s.I,s.T),'z',zeros(s.I,s.T),'c',zeros(s.I,s.T), ...
    'Pg',zeros(s.N,s.T),'Pic',zeros(s.N,s.T),'F',zeros(s.L,s.T));
relations=psaudit_hw5_repair_manifest(psaudit_hw5_repair_checks(base,v,0));
names={'nominal','exact_on','wrap_off'};fns={@psaudit_hw5_repair_original,@psaudit_hw5_repair_candidate};
contexts={psaudit_execution_context('capture',budget)};context=contexts{1};
contracts=cell(1,3);candidates=cell(3,2);reports=cell(3,2);inputs=cell(1,3);
% Freeze every input and contract before the first solve.
for k=1:3
    p=base;
    if k==2,p.referenceState=nan(1,s.T);p.referenceState([32 37])=0;p.referenceState(33:36)=1;
    elseif k==3,p.referenceState=nan(1,s.T);p.referenceState([94 3])=1;p.referenceState([95 96 1 2])=0;end
    ref=psaudit_hw5_repair_reference(p);
    scenarios=struct('id',names{k},'parameters',p,'relations',relations,'objectiveId','OBJECTIVE','affineReferences',ref.affine);
    inputFile=fullfile(outputDirectory,['inputs-' names{k} '.mat']);save(inputFile,'scenarios');
    files=inventory(inputFile);contract=struct('confirmed',true,'unresolvedDefinition',false,'files',files, ...
        'reconstruct',@psaudit_hw5_repair_checks,'scenarios',[],'objectiveId','OBJECTIVE','requireOptimal',k==1);
    contracts{k}=contract;inputs{k}=scenarios;
end
save(fullfile(outputDirectory,'frozen-plan.mat'),'contracts','inputs','budget');
for k=1:3
    input=inputs{k};p=input.parameters;contract=contracts{k};bindings=struct;
    for j=1:numel(contract.files),bindings.(contract.files(j).field)=contract.files(j).hash;end
    referenceFile=fullfile(outputDirectory,['reference-' names{k} '.mat']);
    capture(@psaudit_hw5_repair_reference,p,referenceFile,bindings);
    contract.scenarios=struct('id',names{k},'relations',relations,'referenceFile',referenceFile,'referenceHash',psaudit_hash_file(referenceFile));
    rr=load(referenceFile,'r');
    if ~isempty(p.referenceState)
        selected=isfinite(p.referenceState);
        assert(max(abs(rr.r.vars.u(p.selectorUnit,selected)-p.referenceState(selected)))<1e-6,'Reference selector was not satisfied');
    end
    for j=1:2
        fn=fns{j};source=which(func2str(fn));resultFile=fullfile(outputDirectory,sprintf('%s-%s.mat',erase(func2str(fn),'psaudit_hw5_repair_'),names{k}));
        capture(fn,p,resultFile,bindings);
        candidate=struct('sourceFile',source,'sourceHash',psaudit_hash_file(source),'evaluateImplementation',fn, ...
            'runs',struct('scenarioId',names{k},'resultFile',resultFile,'resultHash',psaudit_hash_file(resultFile)));
        decision=psaudit_validate_semantic_candidate(contract,candidate);
        candidates{k,j}=candidate;reports{k,j}=decision;
        fprintf('HW5_REPAIR %s/%s: %s (%s)\n',names{k},func2str(fn),decision.status,decision.reason);
    end
    contracts{k}=contract;
    save(fullfile(outputDirectory,'checkpoint.mat'),'contracts','candidates','reports','inputs');
end
run=context.snapshot();summary=struct('reports',{reports},'solverCalls',run.actionCount,'solverSeconds',run.elapsed, ...
    'originalFile',originalFile,'candidateFile',candidateFile,'candidateTex',candidateTex,'scope','HW5 minimum-time correction; cyclic-power dispute retained');
save(fullfile(outputDirectory,'repair-evidence.mat'),'summary','contracts','candidates','run');
assert(all(cellfun(@(r)strcmp(r.status,'ACCEPTED'),reports(:,2))),'Candidate not fully accepted; preserve evidence');
assert(all(cellfun(@(r)strcmp(r.status,'REJECTED'),reports(2:3,1))),'Original must reject complete exact-duration trajectories');
psaudit_hw5_repair_replay(outputDirectory,fullfile(outputDirectory,'audit_report.md'));

    function files=inventory(inputFile)
        files=struct('field',{},'path',{},'hash',{});
        paths={ 'specHash',fullfile(here,'math-spec.md');'inputHash',inputFile; ...
            'checkerHash',which('psaudit_hw5_repair_checks');'referenceSourceHash',which('psaudit_hw5_repair_reference'); ...
            'originalScriptHash',originalFile;'candidateScriptHash',candidateFile; ...
            'originalTexHash',originalTex;'candidateTexHash',candidateTex; ...
            'caseHash',fullfile(hw5,'case39_UC.m');'loadHash',fullfile(hw5,'load3996.mat'); ...
            'assignmentHash',fullfile(hw5,'稳态大作业2-机组组合.docx'); ...
            'oldSpecHash',fullfile(fileparts(here),'math-spec.md'); ...
            'parameterAdapterHash',which('psaudit_hw5_build_reference'); ...
            'candidateEntryHash',which('psaudit_hw5_repair_candidate');'originalEntryHash',which('psaudit_hw5_repair_original'); ...
            'implementationHash',which('psaudit_hw5_repair_implementation');'affineSerializerHash',which('psaudit_hw5_repair_affine'); ...
            'memberCheckerHash',which('psaudit_hw5_repair_model_items');'captureHash',mfilename('fullpath'); ...
            'manifestHash',which('psaudit_hw5_repair_manifest'); ...
            'validatorHash',which('psaudit_validate_semantic_candidate');'numericKernelHash',which('psaudit_check_relations'); ...
            'affineComparatorHash',which('psaudit_compare_affine');'gateHash',which('psaudit_repair_gate'); ...
            'executionHash',which('psaudit_execution_context');'hashToolHash',which('psaudit_hash_file')};
        paths{strcmp(paths(:,1),'captureHash'),2}=[mfilename('fullpath') '.m'];
        for a=1:size(paths,1),files(end+1)=struct('field',paths{a,1},'path',paths{a,2},'hash',psaudit_hash_file(paths{a,2}));end
    end
    function capture(fn,p,file,bindings)
        bundle=feval(fn,p);m=bundle.model;
        sol=context.run('capture',[func2str(fn) '/' names{k}],@(limit)gurobi(m, ...
            struct('OutputFlag',0,'Threads',4,'Seed',0,'MIPGap',1e-9,'TimeLimit',limit)));
        run=context.snapshot();save(fullfile(outputDirectory,'solver-ledger.mat'),'run');
        save([file '.solver.mat'],'sol','-v7');
        assert(isfield(sol,'x')&&strcmp(sol.status,'OPTIMAL'),'No proven solver optimum: %s',sol.status);
        vars=struct;for n={'p','u','z','c'},vars.(n{1})=reshape(sol.x(bundle.map.(n{1})),s.I,s.T);end
        vars.Pg=bundle.C*vars.p;vars.Pic=vars.Pg-p.Pd;vars.F=bundle.H*vars.Pic;
        impl=psaudit_hw5_repair_model_items(bundle,vars,sol.objval);
        r=struct('hasSolution',true,'problem',0,'objective',sol.objval,'vars',vars, ...
            'sourceHash',psaudit_hash_file(which(func2str(fn))),'bindings',bindings,'evidenceKind','SOLVER_RESULT', ...
            'implementationRelations',psaudit_hw5_repair_manifest(impl),'affineImplementation',bundle.affine, ...
            'solver','Gurobi','solverPath',which('gurobi'),'solverStatus',sol.status,'mipgap',sol.mipgap, ...
            'objbound',sol.objbound,'model',m,'map',bundle.map,'executionMode','capture', ...
            'created',char(datetime('now','TimeZone','Asia/Shanghai')));
        save(file,'r','-v7');
    end
end
function write(file,text)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0,'Cannot write output');guard=onCleanup(@()fclose(fid));fprintf(fid,'%s',text);
end
