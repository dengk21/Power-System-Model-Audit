function psaudit_test_model_review
% Synthetic reviewed inventories test attribution, applicability and report fidelity.
x=struct('id','Q_BAL','applicable',true,'textPresent',false,'codePresent',true, ...
    'textCorrect',NaN,'codeCorrect',1,'referenceVerified',true, ...
    'textLocation','fixture.tex:model section','codeLocation','fixture.m:12', ...
    'basis','AC model with declared reactive injections and no shunts in this fixture', ...
    'evidence','KCL with the stated line-end conventions, not a DC assumption', ...
    'supplementLatex','\sum_i Q_{G,i,t}-Q_{D,n,t}=\sum_j Q_{nj,t}');
f=psaudit_review_inventory(x); assert(strcmp(f.origin,'DOCUMENTATION_GAP') && ~strcmp(f.severity,'ERROR') && ~isempty(f.supplementLatex));
% The same common relation must not be forced into a declared DC model.
y=x; y.applicable=false; y.codePresent=false; f=psaudit_review_inventory(y);
assert(strcmp(f.status,'NOT_APPLICABLE') && isempty(f.supplementLatex));
% A text formula is wrong while the code satisfies an independently checked definition.
y=x; y.id='E_DIS'; y.textPresent=true; y.textCorrect=0;
y.basis='eta_d means delivered energy / removed energy, dt=1 h';
y.evidence='E0=10 MWh, Pdis=2 MW, eta_d=0.8: expected 7.5 MWh; text multiplication gives 8.4 MWh';
y.supplementLatex='E_{t+1}=E_t-P_{dis,t}\Delta t/\eta_d';
f=psaudit_review_inventory(y); assert(strcmp(f.origin,'MATHEMATICAL_MODEL') && strcmp(f.severity,'ERROR'));
y.codeCorrect=0; f=psaudit_review_inventory(y); assert(strcmp(f.origin,'BOTH'));
y.textCorrect=1; f=psaudit_review_inventory(y); assert(strcmp(f.origin,'IMPLEMENTATION'));
y.referenceVerified=false; f=psaudit_review_inventory(y); assert(strcmp(f.severity,'WARNING'));
y=x; y.codeCorrect=0; f=psaudit_review_inventory(y); assert(strcmp(f.origin,'IMPLEMENTATION') && strcmp(f.supplementStatus,'PROPOSED_CORRECTION'));
y=x; y.applicable=false; f=psaudit_review_inventory(y); assert(strcmp(f.action,'REVIEW_EXTRA_CODE_CONSTRAINT'));
y=x; y.basis=''; f=psaudit_review_inventory(y); assert(strcmp(f.status,'UNRESOLVED'));
y=x; y.textPresent=true; y.textCorrect=1; f=psaudit_review_inventory(y); assert(strcmp(f.status,'CONSISTENT'));
y=x; y.codePresent=false; f=psaudit_review_inventory(y); assert(strcmp(f.status,'MISSING_FROM_BOTH'));
y=x; y.supplementLatex=''; f=psaudit_review_inventory(y); assert(strcmp(f.action,'DERIVE_SUPPLEMENT'));
% Writer preserves the actual candidate formula and provenance, including literal backslashes.
f=psaudit_review_inventory(x); file=[tempname '.md']; fid=fopen(file,'w','n','UTF-8');
assert(fid>=0); psaudit_write_model_review(fid,f); fclose(fid);
body=fileread(file); delete(file);
assert(contains(body,x.supplementLatex) && contains(body,'DOCUMENTATION_GAP') && contains(body,x.codeLocation));
fprintf('PSAUDIT_MODEL_REVIEW_TEST_PASS: 13 attribution/completion/report cases; zero solver calls.\n');
end
