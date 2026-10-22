function psaudit_test_repair_gate
% Meaningful negative controls for evidence-based repair acceptance.
e=struct('scopeVerified',true,'referenceVerified',true,'hasValidSolution',true,...
    'checks',struct('status','PASS'),'referenceAccepted',true,'objectiveConsistent',true,...
    'fullCoverage',true,'unresolvedDefinition',false,'beforeCost',100,'afterCost',160);
r=psaudit_repair_gate(e);assert(r.accepted,'A correct cost-increasing repair must be accepted');
v=e;v.checks.status='VIOLATION';r=psaudit_repair_gate(v);assert(~r.accepted);
v=e;v.checks.status='DATA_INSUFFICIENT';r=psaudit_repair_gate(v);assert(~r.accepted);
v=e;v.referenceAccepted=false;r=psaudit_repair_gate(v);assert(~r.accepted,'Overrestriction must not pass');
v=e;v.scopeVerified=false;r=psaudit_repair_gate(v);assert(~r.accepted,'Changing protected inputs must not pass');
v=e;v.unresolvedDefinition=true;r=psaudit_repair_gate(v);assert(strcmp(r.status,'DEFERRED'));
fprintf('PASS repair acceptance: 6 controls; zero solver calls\n');
end
