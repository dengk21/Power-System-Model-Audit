function observation = psaudit_observe(value, unit, indexReview)
% Emit measured shape; unit and physical/time index meaning are reviewed inputs.
assert(isnumeric(value) && isreal(value) && ~isempty(value) && all(isfinite(value(:))), ...
    'Runtime observation requires finite, nonempty real numeric values');
assert(~isempty(unit) && ~isempty(indexReview),'Supply reviewed unit and index meaning');
observation=struct('shape',size(value),'unit',unit,'index_review',indexReview, ...
    'minimum',min(value(:)),'maximum',max(value(:)),'count',numel(value));
end
