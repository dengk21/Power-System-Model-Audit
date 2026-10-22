function psaudit_test_execution_and_witnesses(outdir)
% Behavioral tests: forbidden callbacks, missing caches, membership directions.
if nargin<1,outdir=tempname;end
if ~isfolder(outdir),mkdir(outdir);end
calls=0;context=psaudit_execution_context('replay');
rejected=false;try,context.run('diagnostic','forbidden',@counted);catch err,rejected=strcmp(err.identifier,'psaudit:ExecutionDenied');end
assert(rejected&&calls==0&&context.snapshot().actionCount==0);
binding=struct('sourceHash','fixture');cache=fullfile(outdir,'diagnostic.mat');
[value,status]=psaudit_read_diagnostic(context,{cache},cache,binding,@counted);
assert(isempty(value)&&strcmp(status,'DATA_INSUFFICIENT')&&calls==0&&~isfile(cache));
context=psaudit_execution_context('diagnose',struct('maxActions',1,'singleSeconds',10,'totalSeconds',10));
[value,status]=psaudit_read_diagnostic(context,{cache},cache,binding,@counted);
assert(value==7&&strcmp(status,'COMPUTED')&&calls==1&&context.snapshot().actionCount==1);
assert(~context.allows('diagnostic')&&~context.allows('capture'));
[value,status]=psaudit_read_diagnostic(psaudit_execution_context('replay'),{cache},cache,binding,@counted);
assert(value==7&&strcmp(status,'CACHED')&&calls==1);
other=struct('sourceHash','changed');
[~,status]=psaudit_read_diagnostic(psaudit_execution_context('replay'),{cache},cache,other,@counted);
assert(strcmp(status,'DATA_INSUFFICIENT')&&calls==1);
x=struct('id','BOUND','actual',4,'expected',4,'sense','ge','unit','periods','absTol',1e-6,'relTol',1e-8);
p=struct('id','LOCAL','scope','LOCAL_RELATIONS','kind','ANALYTICAL_TRAJECTORY','condition','declared', ...
    'referenceItems',x,'implementationItems',x,'assignment','x=4','basis','hand calculation','codeLocation','synthetic fixture');
p.implementationItems.expected=5;e=psaudit_evaluate_witnesses(p);assert(strcmp(e.status,'OVERRESTRICTION'));
p.referenceItems.expected=5;p.implementationItems.expected=4;e=psaudit_evaluate_witnesses(p);assert(strcmp(e.status,'UNDERRESTRICTION'));
p.referenceItems=x;p.implementationItems=x;e=psaudit_evaluate_witnesses(p);assert(strcmp(e.status,'NO_WITNESS_FOUND'));
p.referenceItems.actual=NaN;e=psaudit_evaluate_witnesses(p);assert(strcmp(e.status,'DATA_INSUFFICIENT'));
p.referenceItems=x;p.scope='FULL_MODEL';e=psaudit_evaluate_witnesses(p);assert(strcmp(e.status,'DATA_INSUFFICIENT'));
% Simulated full-result metadata checks only; this is not a solved model.
source=fullfile(outdir,'simulated-source.txt');spec=fullfile(outdir,'simulated-reference.txt');
for path={source,spec},fid=fopen(path{1},'w');fprintf(fid,'synthetic provenance fixture');fclose(fid);end
r=struct('hasSolution',true,'problem',0,'sourceHash',psaudit_hash_file(source),'specHash',psaudit_hash_file(spec));
p.witnessFile=fullfile(outdir,'simulated-solver.mat');save(p.witnessFile,'r');p.witnessHash=psaudit_hash_file(p.witnessFile);
p.kind='VALIDATED_OPTIMIZATION_RESULT';p.hasSolution=true;p.solverStatus=0;
p.expectedReferenceIds={x.id};p.expectedImplementationIds={x.id};
p.provenanceFiles=struct('field',{'sourceHash','specHash'},'path',{source,spec},'hash',{r.sourceHash,r.specHash});
e=psaudit_evaluate_witnesses(p);assert(strcmp(e.status,'NO_WITNESS_FOUND'));
r.sourceHash='stale';save(p.witnessFile,'r');p.witnessHash=psaudit_hash_file(p.witnessFile);
e=psaudit_evaluate_witnesses(p);assert(strcmp(e.status,'DATA_INSUFFICIENT'));
capture=psaudit_execution_context('capture',struct('maxActions',1,'singleSeconds',10,'totalSeconds',10));
assert(capture.allows('capture')&&~capture.allows('diagnostic'));
timed=psaudit_execution_context('diagnose',struct('maxActions',2,'singleSeconds',.01,'totalSeconds',10));
timed.run('diagnostic','synthetic overrun',@slow);
assert(strcmp(timed.snapshot().actions(1).status,'TIME_BUDGET_EXCEEDED')&&~timed.allows('diagnostic'));
fprintf('PSAUDIT_EXECUTION_WITNESS_PASS: mode/cache/budget/membership behavior cases; no optimization solves.\n');
    function value=counted(~),calls=calls+1;value=7;end
    function value=slow(~),pause(.03);value=7;end
end
