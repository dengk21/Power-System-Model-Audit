function result=psaudit_compare_affine(reference,implementation)
% Compare independently specified affine rows, including dormant coefficients.
% Constraints: A*x sense b. Objective rows: A*x+b (no rescaling allowed).
% This compares declared representations, not whole-model equivalence.
result=struct('id','','status','DATA_INSUFFICIENT','detail','', ...
    'coefficientChecks',[],'constantChecks',[],'senseMismatchRows',{{}},'objectiveSenseMismatch',false, ...
    'referenceCanonical',[],'implementationCanonical',[], ...
    'scope','Declared affine rows; implicit constraints/elimination require separate review');
try
    assert(isstruct(reference)&&isscalar(reference)&&isstruct(implementation)&&isscalar(implementation),'Expected scalar descriptors');
    result.id=reference.id;
    if ~isfield(reference,'confirmed')||~isequal(reference.confirmed,true)|| ...
            ~isfield(reference,'basis')||isempty(strtrim(char(reference.basis)))
        result.status='REFERENCE_CONFLICT';result.detail='Independent reference not confirmed';return;
    end
    required={'id','kind','A','b','rowKeys','variableKeys','variableUnits','rowUnits','sense'};
    assert(all(isfield(reference,required))&&all(isfield(implementation,required)),'Missing affine descriptor fields');
    assert(strcmp(reference.id,implementation.id),'Relation IDs differ');
    assert(ismember(reference.kind,{'constraint','objective'})&&strcmp(reference.kind,implementation.kind),'Relation kinds differ');
    assert(all(isfield(reference,{'absTol','relTol'})),'Missing reference tolerances');
    assert(isscalar(reference.absTol)&&isfinite(reference.absTol)&&reference.absTol>=0&& ...
        isscalar(reference.relTol)&&isfinite(reference.relTol)&&reference.relTol>=0,'Invalid tolerance');
    r=validate(reference);i=validate(implementation);
    if strcmp(r.kind,'objective')
        result.objectiveSenseMismatch=~strcmp(r.objectiveSense,i.objectiveSense);
    end
    if ~isequal(sort(r.rowKeys),sort(i.rowKeys))||~isequal(sort(r.variableKeys),sort(i.variableKeys))
        result.status='MISMATCH';result.detail='Declared row/variable sets differ; review missing rows, auxiliaries or elimination before assigning ERROR';return;
    end
    [~,rows]=ismember(r.rowKeys,i.rowKeys);[~,cols]=ismember(r.variableKeys,i.variableKeys);
    i.A=i.A(rows,cols);i.b=i.b(rows);i.sense=i.sense(rows);
    i.variableUnits=i.variableUnits(cols);i.rowUnits=i.rowUnits(rows);
    [ra,rb,rd,rs]=canonical(r);[ia,ib,id,is]=canonical(i);
    assert(isequal(rd,id),'Incompatible dimensions or unspecified power/energy base');
    result.senseMismatchRows=r.rowKeys(~strcmp(rs,is));
    item=struct('id',[reference.id '_COEFFICIENTS'],'actual',ia,'expected',ra, ...
        'sense','eq','unit','canonical row/variable units','absTol',reference.absTol,'relTol',reference.relTol);
    result.coefficientChecks=psaudit_check_relations(item);
    item.id=[reference.id '_CONSTANT'];item.actual=ib;item.expected=rb;
    result.constantChecks=psaudit_check_relations(item);
    result.referenceCanonical=struct('A',ra,'b',rb,'sense',{rs},'rowKeys',{r.rowKeys},'variableKeys',{r.variableKeys});
    result.implementationCanonical=struct('A',ia,'b',ib,'sense',{is},'rowKeys',{r.rowKeys},'variableKeys',{r.variableKeys});
    if any(strcmp({result.coefficientChecks.status,result.constantChecks.status},'DATA_INSUFFICIENT'))
        result.detail='Canonical numeric comparison incomplete';return;
    end
    if isempty(result.senseMismatchRows)&&~result.objectiveSenseMismatch&&strcmp(result.coefficientChecks.status,'PASS')&&strcmp(result.constantChecks.status,'PASS')
        result.status='MATCH';result.detail='Declared rows match after key alignment, unit conversion and permitted constraint scaling';
    else
        result.status='MISMATCH';result.detail='Declared coefficient, constant or sense differs; establish applicability and nonredundancy before assigning model ERROR';
    end
catch err
    result.detail=err.message;
end
end

function x=validate(x)
assert(isnumeric(x.A)&&isreal(x.A)&&ismatrix(x.A)&&~isempty(x.A)&&all(isfinite(x.A(:))),'Invalid A');
[m,n]=size(x.A);x.rowKeys=keys(x.rowKeys,m);x.variableKeys=keys(x.variableKeys,n);
assert(numel(unique(x.rowKeys))==m&&numel(unique(x.variableKeys))==n,'Duplicate row or variable keys');
x.variableUnits=keys(x.variableUnits,n);x.rowUnits=keys(x.rowUnits,m);
assert(isnumeric(x.b)&&isreal(x.b)&&numel(x.b)==m&&all(isfinite(x.b(:))),'Invalid b');x.b=x.b(:);
if ischar(x.sense)||isstring(x.sense)&&isscalar(x.sense),x.sense=repmat({char(x.sense)},m,1);end
x.sense=keys(x.sense,m);
if strcmp(x.kind,'constraint'),assert(all(ismember(x.sense,{'eq','le','ge'})),'Invalid constraint sense');
else
    assert(all(strcmp(x.sense,'objective')),'Objective rows require objective sense');
    assert(isfield(x,'objectiveSense')&&ischar(x.objectiveSense)&&ismember(x.objectiveSense,{'min','max'}), ...
        'Objective requires reviewed min/max direction');
end
end

function k=keys(k,n)
assert(isstring(k)||iscellstr(k),'Expected string/cellstr keys'); %#ok<ISCLSTR>
k=cellstr(k(:));assert(numel(k)==n&&all(~cellfun(@isempty,k)),'Key/unit count or value invalid');
end

function [a,b,dimensions,sense]=canonical(x)
[vs,vd]=units(x.variableUnits);[rs,rd]=units(x.rowUnits);
a=bsxfun(@rdivide,bsxfun(@times,x.A,rs),vs');b=x.b.*rs;sense=x.sense;
dimensions=struct('variable',{vd},'row',{rd});
if strcmp(x.kind,'objective'),return;end
for k=1:size(a,1)
    if strcmp(sense{k},'ge'),a(k,:)=-a(k,:);b(k)=-b(k);sense{k}='le';end
    % The RHS must not shrink all coefficients beneath absolute tolerance.
    % For x<=1e12 vs 2*x<=1e12, normalize A, exposing the different bound.
    v=[a(k,:),b(k)];scale=max(abs(a(k,:)));
    if scale==0,scale=abs(b(k));end
    if scale==0,scale=1;end
    if strcmp(sense{k},'eq')
        first=find(v~=0,1);if ~isempty(first)&&v(first)<0,scale=-scale;end
    end
    a(k,:)=a(k,:)/scale;b(k)=b(k)/scale;
end
end

function [scale,dimension]=units(names)
% Currency conversions and per-unit bases are deliberately not guessed.
registry={ ...
 'MW',1,'power';'kW',1e-3,'power';'W',1e-6,'power'; ...
 'MWh',1,'energy';'kWh',1e-3,'energy';'Wh',1e-6,'energy'; ...
 'h',1,'time';'min',1/60,'time';'s',1/3600,'time'; ...
 'rad',1,'angle';'deg',pi/180,'angle'; ...
 '1',1,'dimensionless';'dimensionless',1,'dimensionless'; ...
 'USD',1,'USD';'CNY',1,'CNY'};
scale=zeros(numel(names),1);dimension=cell(numel(names),1);
for k=1:numel(names)
    at=find(strcmp(names{k},registry(:,1)));assert(isscalar(at),'Unknown unit: %s',names{k});
    scale(k)=registry{at,2};dimension{k}=registry{at,3};
end
end
