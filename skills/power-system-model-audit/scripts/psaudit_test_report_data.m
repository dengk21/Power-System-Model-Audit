function psaudit_test_report_data(outdir)
% Exercise real report rendering with different evidence, not a fixed story.
if nargin<1,outdir=tempname;end
if ~isfolder(outdir),mkdir(outdir);end
item=struct('id','POWER','actual',10,'expected',10,'sense','eq','unit','MW','absTol',1e-6,'relTol',1e-8);
entry=struct('key','SYNTHETIC','state','valid synthetic data','elapsed',0,'objective',10, ...
    'resultFile',fullfile(outdir,'fixture.txt'),'resultHash','synthetic','checks',psaudit_check_relations(item),'executionError','');
fid=fopen(entry.resultFile,'w');fprintf(fid,'synthetic report test');fclose(fid);
entry.resultHash=psaudit_hash_file(entry.resultFile);
inventory=struct('id','MATH','applicable',true,'textPresent',true,'codePresent',true, ...
    'textCorrect',0,'codeCorrect',1,'referenceVerified',true,'textLocation','SYNTHETIC_TEXT', ...
    'codeLocation','SYNTHETIC_CODE','basis','Hand-computed units','evidence','10MW is not 10MWh','supplementLatex','P=E/\Delta t');
document=struct('title','Synthetic report test','entries',entry,'findings',psaudit_review_inventory(inventory), ...
    'witnesses',psaudit_evaluate_witnesses(struct([])),'execution',psaudit_execution_context('replay').snapshot(), ...
    'notes',{{'Synthetic fixtures, no original optimization results.'}},'links',struct('label',{},'path',{}));
file=fullfile(outdir,'first.md');summary=psaudit_write_audit_report(file,document);
assert(summary.entries==1&&summary.pass==1&&summary.errors==1&&summary.warnings==0);
body=fileread(file);assert(contains(body,'MATHEMATICAL_MODEL')&&contains(body,inventory.supplementLatex));
inventory.textCorrect=1;document.findings=psaudit_review_inventory(inventory);
item.actual=12;document.entries.checks=psaudit_check_relations(item);
file=fullfile(outdir,'second.md');summary=psaudit_write_audit_report(file,document);
assert(summary.pass==0&&summary.violations==1&&summary.errors==0);
body=fileread(file);assert(~contains(body,'CONFIRMED_MATH_ERROR'));
document.findings=psaudit_review_inventory(struct([]));
summary=psaudit_write_audit_report(fullfile(outdir,'unreviewed.md'),document);
assert(summary.errors==0);
inventory.referenceVerified=false;inventory.textCorrect=NaN;inventory.supplementLatex='PROPOSED_ONLY';
document.findings=psaudit_review_inventory(inventory);
file=fullfile(outdir,'unresolved.md');psaudit_write_audit_report(file,document);body=fileread(file);
assert(contains(body,'REFERENCE_CONFLICT')&&contains(body,'PROPOSED_DEFINITION')&&contains(body,'PROPOSED_ONLY'));
fprintf('PSAUDIT_REPORT_DATA_PASS: 4 changed-evidence/candidate cases; zero solver calls.\n');
end
