function manifest=psaudit_hw5_repair_manifest(items)
% Freeze dimensions from trusted input/model construction, before any solve.
manifest=struct('id',{},'shape',{},'unit',{},'sense',{},'absTol',{},'relTol',{});
for k=1:numel(items)
    x=items(k);tol=1e-6;
    if strcmp(x.unit,'MW'),tol=1e-5;elseif strcmp(x.unit,'USD'),tol=1e-4;end
    manifest(end+1)=struct('id',x.id,'shape',size(x.actual),'unit',x.unit, ...
        'sense',x.sense,'absTol',tol,'relTol',1e-8);
end
end
