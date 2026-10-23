function summary = run_semantic_demo(outputDirectory)
% Explicit opt-in real LP demonstration: MATLAB + licensed Gurobi required.
repo = fileparts(fileparts(mfilename('fullpath')));
if nargin < 1
    outputDirectory = fullfile(repo, 'outputs', ['semantic-' char(java.util.UUID.randomUUID)]);
end
assert(~isfolder(outputDirectory) && ~isfile(outputDirectory), 'Use a new output directory');
oldPath = path;
pathGuard = onCleanup(@() path(oldPath)); %#ok<NASGU>
skill = fullfile(repo, 'skills', 'power-system-model-audit');
addpath(fullfile(skill, 'scripts'), fullfile(repo, 'projects', 'course-audit', 'examples', 'semantic'));
assert(exist('gurobi', 'file') ~= 0, 'Configure the licensed Gurobi MATLAB interface first');
summary = psaudit_semantic_demo_run(outputDirectory);
end
