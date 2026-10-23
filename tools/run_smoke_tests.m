function summary = run_smoke_tests(outputDirectory)
% Run existing self-contained checks without course inputs or solver calls.
repo = fileparts(fileparts(mfilename('fullpath')));
if nargin < 1
    outputDirectory = fullfile(repo, 'outputs', ['smoke-' char(java.util.UUID.randomUUID)]);
end
assert(~isfolder(outputDirectory) && ~isfile(outputDirectory), ...
    'Use a new output directory');
mkdir(outputDirectory);
oldPath = path;
pathGuard = onCleanup(@() path(oldPath)); %#ok<NASGU>
skill = fullfile(repo, 'skills', 'power-system-model-audit');
addpath(fullfile(skill, 'scripts'));
% A hidden attempt to execute a solver must fail the smoke suite.
guards = fullfile(outputDirectory, 'solver-guards');
mkdir(guards);
for name = {'gurobi', 'optimize', 'runpf', 'copt'}
    fid = fopen(fullfile(guards, [name{1} '.m']), 'w');
    assert(fid >= 0, 'Cannot write solver guard');
    fprintf(fid, 'function varargout=%s(varargin)\nerror(''psaudit:UnexpectedSolve'',''Smoke test attempted a solver call'');\nend\n', name{1});
    fclose(fid);
end
addpath(guards, '-begin');
assert(strcmp(which('gurobi'), fullfile(guards, 'gurobi.m')), 'Solver guard inactive');
tests = {@psaudit_test_core, @psaudit_test_model_review, ...
    @psaudit_test_affine, @psaudit_test_repair_gate, ...
    @() psaudit_test_execution_and_witnesses(fullfile(outputDirectory, 'execution')),...
    @() psaudit_test_report_data(fullfile(outputDirectory, 'report'))};
names = {'core', 'model_review', 'affine', 'repair_gate', 'execution_and_witnesses', ...
    'report_data'};
summary = struct('suite', 'public-package-smoke', 'groupsPassed', 0, ...
    'groupsTotal', numel(tests), 'solverCalls', 0, 'tests', {names});
for k = 1:numel(tests)
    test = tests{k};
    logText = evalc('test();');
    fid = fopen(fullfile(outputDirectory, [names{k} '.log']), 'w', 'n', 'UTF-8');
    assert(fid >= 0, 'Cannot write test log');
    fprintf(fid, '%s', logText);
    fclose(fid);
    summary.groupsPassed = k;
    fprintf('PASS %s\n', names{k});
end
save(fullfile(outputDirectory, 'smoke-summary.mat'), 'summary');
disp(summary);
end
