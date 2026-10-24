function psaudit_write_facts(checks)
% Write observed project test facts for an explicitly started collect run.
target=getenv('PSAUDIT_FACTS_PATH');
assert(~isempty(target),'Run through psaudit_project.py collect to set PSAUDIT_FACTS_PATH');
assert(~isfile(target),'Runtime facts already exist; preserve the previous evidence');
if isstruct(checks), checks=num2cell(checks); end
assert(iscell(checks) && ~isempty(checks),'Supply actual project check observations');
for k=1:numel(checks)
    x=checks{k};
    assert(isstruct(x) && isscalar(x),'Each check must be a scalar struct');
    if isstruct(x.relations), x.relations=num2cell(x.relations); end
    if isstruct(x.controls), x.controls=num2cell(x.controls); end
    checks{k}=x;
end
facts=struct('schema_version',1,'checks',{checks});
fid=fopen(target,'w','n','UTF-8');
assert(fid>=0,'Cannot create runtime facts');
cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(facts));
end
