function controls=psaudit_hw5_repair_test_replay(evidenceDirectory,outputDirectory)
% Derived protocol fixtures only; preserve captured solver files and hashes.
assert(~isfolder(outputDirectory),'Use new test output directory');mkdir(outputDirectory);
s=load(fullfile(evidenceDirectory,'repair-evidence.mat'),'contracts','candidates');
c=s.contracts{1};v=s.candidates{1,2};controls=struct('id',{},'status',{});
assert(psaudit_validate_semantic_candidate(c,v).accepted,'Valid captured candidate must pass');
t=c;t=rmfield(t,'requireOptimal');check('undeclared_mode',t,v,'DEFERRED');
t=c;t.files(1).hash=repmat('0',1,64);check('changed_spec',t,v,'DEFERRED');
t=c;t.scenarios.relations(1).shape=[1 1];check('shrunk_shape',t,v,'DEFERRED');
t=c;t.scenarios.relations(1).absTol=1;check('relaxed_tolerance',t,v,'DEFERRED');
w=v;w.sourceHash=repmat('0',1,64);check('changed_candidate',c,w,'DEFERRED');
w=v;w.runs.resultHash=repmat('0',1,64);check('changed_result',c,w,'DEFERRED');
t=c;t.reconstruct=@(p,v,o)psaudit_hw5_repair_checks(p,v,o);check('anonymous_checker',t,v,'DEFERRED');
raw=load(v.runs.resultFile,'r');
r=raw.r;r.vars.p(1,1)=r.vars.p(1,1)+50;derived('violating_trajectory',r,'REJECTED');
r=raw.r;r.objective=2*r.objective;derived('wrong_objective',r,'REJECTED');
r=raw.r;r.vars.z=r.vars.z(:,1:end-1);derived('missing_final_period',r,'DEFERRED');
save(fullfile(outputDirectory,'controls.mat'),'controls');
writetable(struct2table(controls),fullfile(outputDirectory,'controls.csv'));
fprintf('PASS HW5 replay: %d controls from copied protocol fixtures, zero solves\n',numel(controls));
    function check(id,contract,candidate,expected)
        d=psaudit_validate_semantic_candidate(contract,candidate);
        assert(strcmp(d.status,expected),'Unexpected %s: %s (%s)',id,d.status,d.reason);
        controls(end+1)=struct('id',id,'status',d.status);
    end
    function derived(id,r,expected)
        file=fullfile(outputDirectory,[id '.mat']);save(file,'r');
        w=v;w.runs.resultFile=file;w.runs.resultHash=psaudit_hash_file(file);check(id,c,w,expected);
    end
end
