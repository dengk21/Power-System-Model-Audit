function checks = psaudit_check_relations(items)
% Model-independent evidence kernel; adapters compute the reference formulas.
checks=struct('id',{},'status',{},'maxResidual',{},'positionResidual',{}, ...
    'tolerance',{},'count',{},'position',{},'actual',{},'expected',{},'unit',{},'detail',{});
for j=1:numel(items)
    x=items(j); c=struct('id','UNKNOWN','status','DATA_INSUFFICIENT', ...
        'maxResidual',NaN,'positionResidual',NaN,'tolerance',NaN,'count',0, ...
        'position','n/a','actual',NaN,'expected',NaN,'unit','n/a','detail','');
    if isfield(x,'id'), c.id=x.id; end
    if isfield(x,'unit'), c.unit=x.unit; end
    try
        required={'actual','expected','sense','absTol','relTol','unit'};
        assert(all(isfield(x,required)),'Missing relation fields');
        a=x.actual; e=x.expected;
        assert(isnumeric(a) && isreal(a) && ~isempty(a) && all(isfinite(a(:))),'Invalid actual values');
        e=expand(e,a,'expected');
        assert(ismember(x.sense,{'eq','le','ge'}),'Unknown relation sense');
        assert(isscalar(x.absTol) && isfinite(x.absTol) && x.absTol>=0,'Invalid absolute tolerance');
        assert(isscalar(x.relTol) && isfinite(x.relTol) && x.relTol>=0,'Invalid relative tolerance');
        mask=true(size(a));
        if isfield(x,'mask') && ~isempty(x.mask)
            assert(islogical(x.mask) && isequal(size(x.mask),size(a)),'Invalid applicability mask'); mask=x.mask;
        end
        if ~any(mask(:)), c.status='NOT_APPLICABLE'; c.detail='No applicable indices'; checks(end+1)=c; continue; end
        scale=max(abs(a),abs(e));
        if isfield(x,'scale') && ~isempty(x.scale), scale=expand(x.scale,a,'scale'); end
        assert(all(scale(:)>=0),'Negative scale');
        tol=x.absTol+x.relTol*max(1,scale); raw=abs(a-e);
        if strcmp(x.sense,'le'), raw=max(a-e,0); elseif strcmp(x.sense,'ge'), raw=max(e-a,0); end
        bad=(raw>tol)&mask; idx=find(mask); [c.maxResidual,local]=max(raw(idx)); k=idx(local);
        if any(bad(:)), idx=find(bad); [~,local]=max(raw(idx)); k=idx(local); c.status='VIOLATION';
        else, c.status='PASS'; end
        subs=cell(1,ndims(a)); [subs{:}]=ind2sub(size(a),k);
        c.position=strjoin(cellfun(@num2str,subs,'UniformOutput',false),',');
        c.positionResidual=raw(k); c.tolerance=tol(k); c.count=nnz(bad); c.actual=a(k); c.expected=e(k);
    catch err
        c.detail=err.message;
    end
    checks(end+1)=c;
end
end

function value=expand(value,a,label)
assert(isnumeric(value) && isreal(value) && ~isempty(value) && all(isfinite(value(:))),'Invalid %s',label);
if isscalar(value), value=value+zeros(size(a));
else, assert(isequal(size(value),size(a)),'Shape mismatch: %s',label); end
end
