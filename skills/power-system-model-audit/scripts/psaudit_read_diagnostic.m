function [value,status,detail]=psaudit_read_diagnostic(context,readFiles,writeFile,binding,callback)
% Only hash-bound diagnostics are replayed. A cache miss never implies solve.
value=[];status='DATA_INSUFFICIENT';detail='No matching diagnostic cache';
if ischar(readFiles),readFiles={readFiles};end
for k=1:numel(readFiles)
    if ~isfile(readFiles{k}),continue;end
    try
        data=load(readFiles{k},'diagnostic');
        if isfield(data,'diagnostic')&&isequaln(data.diagnostic.binding,binding)
            value=data.diagnostic.value;status='CACHED';detail=readFiles{k};return
        end
    catch err,detail=['Unreadable cache: ' err.message];end
end
if ~context.allows('diagnostic')
    detail=[detail '; mode/budget forbids a new diagnostic'];return
end
% Keep old caches intact, including an unmatched cache at the requested path.
assert(~isfile(writeFile),'Diagnostic cache exists with a different binding; choose a new directory');
try,value=context.run('diagnostic',writeFile,callback);
catch err,detail=['Diagnostic failed: ' err.message];return
end
diagnostic=struct('binding',binding,'value',value,'created',char(datetime('now')), ...
    'execution',context.snapshot());
folder=fileparts(writeFile);if ~isfolder(folder),mkdir(folder);end
save(writeFile,'diagnostic','-v7');status='COMPUTED';detail=writeFile;
end
