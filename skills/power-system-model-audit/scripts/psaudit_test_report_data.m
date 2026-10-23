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
brief=fileread(fullfile(outdir,'first_brief.md'));
assert(contains(brief,'SYNTHETIC_TEXT')&&contains(brief,'是，改正文/公式'));
assert(~contains(brief,inventory.supplementLatex),'Brief must not expand mathematical supplements');
inventory.textCorrect=1;document.findings=psaudit_review_inventory(inventory);
item.actual=12;document.entries.checks=psaudit_check_relations(item);
file=fullfile(outdir,'second.md');summary=psaudit_write_audit_report(file,document);
assert(summary.pass==0&&summary.violations==1&&summary.errors==0);
body=fileread(file);assert(~contains(body,'CONFIRMED_MATH_ERROR'));
brief=fileread(fullfile(outdir,'second_brief.md'));
assert(contains(brief,'需核实后改正')&&~contains(brief,'是，改代码'), ...
    'Numerical disagreement alone must not confirm a code correction');
document.findings=psaudit_review_inventory(struct([]));
summary=psaudit_write_audit_report(fullfile(outdir,'unreviewed.md'),document);
assert(summary.errors==0);
brief=fileread(fullfile(outdir,'unreviewed_brief.md'));
assert(contains(brief,'待完成检查')&&~contains(brief,'暂不需要'));
inventory.referenceVerified=false;inventory.textCorrect=NaN;inventory.supplementLatex='PROPOSED_ONLY';
document.findings=psaudit_review_inventory(inventory);
file=fullfile(outdir,'unresolved.md');psaudit_write_audit_report(file,document);body=fileread(file);
assert(contains(body,'REFERENCE_CONFLICT')&&contains(body,'PROPOSED_DEFINITION')&&contains(body,'PROPOSED_ONLY'));
brief=fileread(fullfile(outdir,'unresolved_brief.md'));assert(contains(brief,'先确认定义'));
inventory.referenceVerified=true;inventory.textCorrect=1;inventory.codeCorrect=1;
document.findings=psaudit_review_inventory(inventory);document.entries.checks=psaudit_check_relations(struct([]));
document.checkedFiles={'model.m','model.tex'};
psaudit_write_audit_report(fullfile(outdir,'audit_report.md'),document);
brief=fileread(fullfile(outdir,'audit_brief.md'));
assert(contains(brief,'model.m')&&contains(brief,'model.tex')&&contains(brief,'暂不需要'));
assert(numel(brief)<300,'Clean brief should stay short');
inventory.textPresent=false;document.findings=psaudit_review_inventory(inventory);
psaudit_write_audit_report(fullfile(outdir,'gap.md'),document);
brief=fileread(fullfile(outdir,'gap_brief.md'));
assert(contains(brief,'是，补文档')&&~contains(brief,'是，改代码'));
document.entries.executionError='FAILED_FIXTURE';
psaudit_write_audit_report(fullfile(outdir,'failed.md'),document);
brief=fileread(fullfile(outdir,'failed_brief.md'));
assert(contains(brief,'先排查失败')&&~contains(brief,'暂不需要'));
fprintf('PSAUDIT_REPORT_DATA_PASS: 4 changed-evidence/candidate cases; zero solver calls.\n');
fprintf('PSAUDIT_BRIEF_PASS: correction target, disagreement, missing review, conflict, clean result, documentation and execution failure.\n');
end
