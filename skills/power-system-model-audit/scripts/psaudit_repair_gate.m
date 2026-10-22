function decision=psaudit_repair_gate(evidence)
% Accept a candidate only after independent evidence gates; cost drift is not a gate.
fields={'scopeVerified','referenceVerified','hasValidSolution','checks','referenceAccepted',...
    'objectiveConsistent','fullCoverage','unresolvedDefinition'};
for k=1:numel(fields),assert(isfield(evidence,fields{k}),'Missing repair evidence');end
decision=struct('accepted',false,'status','REJECTED','reason','');
if evidence.unresolvedDefinition
    decision.status='DEFERRED';decision.reason='Definitions unresolved; keep original and candidate alternatives';return;
end
gates={'scopeVerified','referenceVerified','hasValidSolution','fullCoverage','referenceAccepted','objectiveConsistent'};
for k=1:numel(gates)
    if ~isequal(evidence.(gates{k}),true)
        decision.reason=['Failed evidence gate: ' gates{k}];return;
    end
end
if isempty(evidence.checks)||~all(ismember({evidence.checks.status},{'PASS','NOT_APPLICABLE'}))
    decision.reason='Independent checks contain violation, insufficient data, or no coverage';return;
end
decision.accepted=true;decision.status='ACCEPTED';
decision.reason='Declared scenarios pass frozen relations, objective and full reference trajectory membership';
end
