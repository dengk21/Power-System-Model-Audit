function evidence=psaudit_evaluate_witnesses(probes)
% Membership counterexamples; finite witnesses never prove model equivalence.
evidence=struct('id',{},'scope',{},'kind',{},'condition',{},'status',{}, ...
    'referenceStatus',{},'implementationStatus',{},'referenceChecks',{}, ...
    'implementationChecks',{},'assignment',{},'basis',{},'codeLocation',{});
for k=1:numel(probes)
    p=probes(k);
    required={'id','scope','kind','condition','referenceItems','implementationItems','assignment','basis','codeLocation'};
    assert(all(isfield(p,required)),'Witness lacks scope/evidence');
    assert(ismember(p.scope,{'LOCAL_RELATIONS','FULL_MODEL'}),'Unknown witness scope');
    assert(ismember(p.kind,{'ANALYTICAL_TRAJECTORY','VALIDATED_OPTIMIZATION_RESULT'}),'Unknown evidence kind');
    complete=true;
    if strcmp(p.scope,'FULL_MODEL')
        required={'expectedReferenceIds','expectedImplementationIds','witnessFile','witnessHash','hasSolution','solverStatus','provenanceFiles'};
        complete=all(isfield(p,required));
        if complete
            complete=isequal(p.hasSolution,true)&&ismember(p.solverStatus,[0 3])&& ...
                isfile(p.witnessFile)&&strcmp(psaudit_hash_file(p.witnessFile),p.witnessHash)&& ...
                isequal(sort(p.expectedReferenceIds),sort({p.referenceItems.id}))&& ...
                isequal(sort(p.expectedImplementationIds),sort({p.implementationItems.id}))&& ...
                strcmp(p.kind,'VALIDATED_OPTIMIZATION_RESULT');
            if complete
                try
                    saved=load(p.witnessFile,'r');r=saved.r;
                    complete=isfield(r,'hasSolution')&&isequal(r.hasSolution,true)&& ...
                        isfield(r,'problem')&&isequal(r.problem,p.solverStatus)&& ...
                        all(isfield(p.provenanceFiles,{'field','path','hash'}))&& ...
                        all(ismember({'sourceHash','specHash'},{p.provenanceFiles.field}));
                    for j=1:numel(p.provenanceFiles)
                        q=p.provenanceFiles(j);
                        complete=complete&&isfile(q.path)&&strcmp(psaudit_hash_file(q.path),q.hash)&& ...
                            isfield(r,q.field)&&strcmp(r.(q.field),q.hash);
                    end
                catch,complete=false;end
            end
        end
    end
    rc=psaudit_check_relations(p.referenceItems);ic=psaudit_check_relations(p.implementationItems);
    rs=membership(rc);is=membership(ic);status='NO_WITNESS_FOUND';
    if ~complete||strcmp(rs,'UNKNOWN')||strcmp(is,'UNKNOWN'),status='DATA_INSUFFICIENT';
    elseif strcmp(rs,'ACCEPTED')&&strcmp(is,'REJECTED'),status='OVERRESTRICTION';
    elseif strcmp(rs,'REJECTED')&&strcmp(is,'ACCEPTED'),status='UNDERRESTRICTION';end
    evidence(end+1)=struct('id',p.id,'scope',p.scope,'kind',p.kind,'condition',p.condition, ...
        'status',status,'referenceStatus',rs,'implementationStatus',is, ...
        'referenceChecks',rc,'implementationChecks',ic,'assignment',p.assignment, ...
        'basis',p.basis,'codeLocation',p.codeLocation);
end
end
function status=membership(c)
% Missing coverage cannot be overridden by a violation elsewhere.
status='UNKNOWN';if isempty(c)||any(strcmp({c.status},'DATA_INSUFFICIENT')),return;end
if any(strcmp({c.status},'VIOLATION')),status='REJECTED';
elseif all(strcmp({c.status},'PASS')),status='ACCEPTED';end
end
