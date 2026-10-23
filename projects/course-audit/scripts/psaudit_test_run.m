function summary=psaudit_test_run(project,outputDirectory,repairEvidence)
% End-to-end replay with solver stubs that throw on any hidden execution.
assert(~isfolder(outputDirectory),'Use a new test directory');mkdir(outputDirectory);
oldPath=path;cleanup=onCleanup(@()path(oldPath));guards=fullfile(outputDirectory,'solver-guards');mkdir(guards);
for name={'gurobi','optimize','runpf'}
    file=fullfile(guards,[name{1} '.m']);fid=fopen(file,'w');assert(fid>=0,'Cannot create test guard');
    fprintf(fid,'function varargout=%s(varargin)\nerror(''psaudit:UnexpectedSolve'',''Replay attempted %s'');\nend\n',name{1},name{1});fclose(fid);
end
addpath(guards,'-begin');assert(strcmp(which('gurobi'),fullfile(guards,'gurobi.m')),'Guard not active');
denied=0;next=fullfile(outputDirectory,'must-not-exist');
deny('hw5',struct('outputDirectory',next,'mode','capture'));
deny('hw5',struct('outputDirectory',next,'budget',struct('maxActions',1)));
deny('hw5-repair',struct('outputDirectory',next,'mode','capture'));
deny('hw5',struct('outputDirectory',next,'mod','capture'));
deny('unknown',struct('outputDirectory',next));
deny('hw5',struct('outputDirectory',outputDirectory));
assert(~isfolder(next),'Denied request must not create output');
cases={'hw5-repair','hw4','hw5','course'};results=cell(1,numel(cases));
for k=1:numel(cases)
    opts=struct('outputDirectory',fullfile(outputDirectory,cases{k}));
    if k==1,opts.evidenceDirectory=repairEvidence;end
    text=evalc('results{k}=psaudit_run(project,cases{k},opts);');
    fid=fopen(fullfile(outputDirectory,[cases{k} '.log']),'w','n','UTF-8');fprintf(fid,'%s',text);fclose(fid);
    assert(results{k}.solverCalls==0,'Replay cannot execute a solver');
end
assert(strcmp(results{1}.status,'ACCEPTED'),'Bound real HW5 repair must still pass');
legacy=results{3}.details.audit;
assert(numel(legacy)==4&&sum(arrayfun(@(a)numel(a.checks),legacy))==133,'Legacy HW5 coverage changed');
assert(all(arrayfun(@(a)all(strcmp({a.checks.status},'PASS')),legacy)),'Legacy HW5 numeric regression');
assert(numel(results{2}.details.audit)==5&&all(strcmp({results{2}.details.cross.status},'PASS')),'Legacy HW4 regression');
course=results{4}.details.audit;checks=[course.checks];
summary=struct('denialControls',denied,'caseIds',{cases},'solverCalls',0, ...
    'hw4Categories',sum(arrayfun(@(a)a.checks,results{2}.details.audit)), ...
    'hw5Categories',133,'courseEntries',numel(course),'courseCategories',numel(checks), ...
    'coursePass',nnz(strcmp({checks.status},'PASS')),'courseViolation',nnz(strcmp({checks.status},'VIOLATION')), ...
    'courseData',nnz(strcmp({checks.status},'DATA_INSUFFICIENT')));
save(fullfile(outputDirectory,'test-summary.mat'),'summary');disp(summary);
    function deny(caseId,opts)
        failed=false;
        try,psaudit_run(project,caseId,opts);catch err
            assert(~strcmp(err.identifier,'psaudit:UnexpectedSolve'),'Denied request tried executing');failed=true;
        end
        assert(failed,'Expected request to be denied');denied=denied+1;
    end
end
