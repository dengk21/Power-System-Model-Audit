function summary=run_adapter_tests(skillRoot)
% Project-owned adapter controls; no source project inputs or solver calls.
here=fileparts(mfilename('fullpath')); oldPath=path; guard=onCleanup(@()path(oldPath));
addpath(fullfile(skillRoot,'scripts'),fullfile(here,'examples','hw4'), ...
    fullfile(here,'examples','hw5'),fullfile(here,'examples','course'));
psaudit_hw4_test_adapter; psaudit_hw5_test_adapter; psaudit_course_test_helpers;
summary=struct('projectAdapterGroups',3,'scope','Local fixtures only; not full-model replay');
end
