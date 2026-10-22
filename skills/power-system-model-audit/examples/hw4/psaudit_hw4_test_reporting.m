function psaudit_hw4_test_reporting(hw4,linearResult,outdir)
% Synthetic mathematical-review input tests the actual report/confirmation gate.
model='basicTask1_ED_linear.m'; x=psaudit_hw4_relation_inventory(hw4,model);
x.id='FIXTURE_RAMP_UNITS'; x.textPresent=true; x.textCorrect=0;
x.textLocation='SYNTHETIC_FIXTURE.tex:ramp equation';
x.basis='Synthetic fixture: ramp rate is explicitly MW/h, dt=0.25 h.';
x.evidence='Synthetic hand calculation: R=40 MW/h gives a 10 MW step bound; the fixture text uses 40 MW. This is not a detected HW4 source fault.';
x.supplementLatex='-R_d\Delta t \le p_t-p_{t-1} \le R_u\Delta t';
report=fullfile(outdir,'mathematical-error-fixture.md');
c=psaudit_hw4_write_report(hw4,model,linearResult,report, ...
    fullfile(fileparts(mfilename('fullpath')),'math-spec.md'),true,x);
body=fileread(report);
assert(numel(c)==15 && all(strcmp({c.status},'PASS')));
assert(contains(body,'MATHEMATICAL_MODEL') && contains(body,'CONFIRMED_MATH_ERROR'));
assert(contains(body,'规范确认：0') && contains(body,x.supplementLatex));
assert(~contains(body,'在本次检查范围与已有结果下未发现 ERROR。'));
x.referenceVerified=false;
report=fullfile(outdir,'unresolved-reference-fixture.md');
psaudit_hw4_write_report(hw4,model,linearResult,report, ...
    fullfile(fileparts(mfilename('fullpath')),'math-spec.md'),true,x);
body=fileread(report);
assert(contains(body,'规范确认：0') && contains(body,'REFERENCE_CONFLICT') && ~contains(body,'CONFIRMED_MATH_ERROR'));
fprintf('PSAUDIT_HW4_REPORT_TEST_PASS: 2 attribution/reference-gate cases; zero solver calls.\n');
end
