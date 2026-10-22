function findings = psaudit_review_inventory(inventory)
% Classify an Agent-reviewed text/code/physics inventory, not a TeX parser.
findings=struct('id',{},'severity',{},'origin',{},'status',{},'action',{}, ...
    'textLocation',{},'codeLocation',{},'basis',{},'evidence',{},'reason',{}, ...
    'supplementLatex',{},'supplementStatus',{});
for k=1:numel(inventory)
    x=inventory(k);
    required={'id','applicable','textPresent','codePresent','textCorrect','codeCorrect', ...
        'referenceVerified','textLocation','codeLocation','basis','evidence','supplementLatex'};
    assert(all(isfield(x,required)),'Inventory lacks required evidence fields');
    flags={'applicable','textPresent','codePresent','referenceVerified'};
    for j=1:numel(flags), v=x.(flags{j}); assert(islogical(v) && isscalar(v),'Invalid flag: %s',flags{j}); end
    assert(tristate(x.textCorrect) && tristate(x.codeCorrect),'Correctness must be 0, 1 or NaN');
    f=struct('id',x.id,'severity','WARNING','origin','REFERENCE_CONFLICT', ...
        'status','UNRESOLVED','action','REVIEW_MATH_AND_CODE', ...
        'textLocation',x.textLocation,'codeLocation',x.codeLocation, ...
        'basis',x.basis,'evidence',x.evidence,'reason','独立依据不足，不能把差异自动归因为代码错误。', ...
        'supplementLatex','','supplementStatus','NONE');
    verified=x.referenceVerified && ~isempty(strtrim(x.basis)) && ~isempty(strtrim(x.evidence));
    if ~x.applicable
        f.origin='APPLICABILITY'; f.action='DO_NOT_SUPPLEMENT';
        f.status='NOT_APPLICABLE'; f.severity='INFO'; f.reason='当前模型假设下不适用，不补入该约束。';
        if x.codePresent
            f.status='UNRESOLVED'; f.severity='WARNING'; f.action='REVIEW_EXTRA_CODE_CONSTRAINT';
            f.reason='该关系不属于当前模型范围，但代码中存在；需评估是否是有意扩展或错误限制。';
        end
    elseif ~x.textPresent && x.codePresent
        f.origin='DOCUMENTATION_GAP'; f.action='SUPPLEMENT_DOCUMENTATION';
        f.reason='代码包含文字未显式列出的关系，应补全文档并保留源码与适用假设。';
        f.supplementLatex=x.supplementLatex; f.supplementStatus='CODE_OBSERVED_DRAFT';
        if verified && x.codeCorrect==1
            f.status='CONFIRMED_GAP'; f.supplementStatus='RECONCILED_UNDER_STATED_ASSUMPTIONS';
        elseif verified && x.codeCorrect==0
            f.severity='ERROR'; f.origin='IMPLEMENTATION'; f.status='CONFIRMED_IMPLEMENTATION_ERROR';
            f.action='CORRECT_CODE_AND_DRAFT_DOCUMENTATION'; f.supplementStatus='PROPOSED_CORRECTION';
            f.reason='代码关系违反独立依据，不能按代码原样补成正确数学规范。';
        end
        if isempty(strtrim(f.supplementLatex))
            f.action='DERIVE_SUPPLEMENT'; f.reason=[f.reason ' 尚无可用公式，需推导后在报告中补全。'];
        end
    elseif verified && x.textPresent && x.textCorrect==0
        f.severity='ERROR'; f.origin='MATHEMATICAL_MODEL'; f.status='CONFIRMED_MATH_ERROR';
        f.action='PROPOSE_MATH_CORRECTION'; f.reason='文字或数学公式违反独立依据；不能仅因代码不同而修改代码。';
        f.supplementLatex=x.supplementLatex; f.supplementStatus='PROPOSED_CORRECTION';
        if x.codePresent && x.codeCorrect==0
            f.origin='BOTH'; f.status='CONFIRMED_MATH_AND_CODE_ERROR'; f.action='PROPOSE_BOTH_CORRECTIONS';
            f.reason='数学模型和代码均违反同一独立依据；二者一致不能证明二者正确。';
        elseif ~x.codePresent
            f.action='PROPOSE_MATH_CORRECTION_AND_REVIEW_CODE_COVERAGE';
        end
    elseif verified && ((x.codePresent && x.codeCorrect==0) || (x.textPresent && x.textCorrect==1 && ~x.codePresent))
        f.severity='ERROR'; f.origin='IMPLEMENTATION'; f.status='CONFIRMED_IMPLEMENTATION_ERROR';
        f.action='CORRECT_OR_COMPLETE_IMPLEMENTATION'; f.reason='代码缺失或错误实现了独立依据支持的适用关系。';
    elseif verified && ~x.textPresent && ~x.codePresent
        f.origin='BOTH'; f.status='MISSING_FROM_BOTH'; f.action='PROPOSE_REQUIRED_RELATION';
        f.reason='适用的必要关系在文字与代码中都没有找到；先核查隐含等价实现，再决定定级。';
        f.supplementLatex=x.supplementLatex; f.supplementStatus='PROPOSED_CORRECTION';
    elseif verified && x.textPresent && x.codePresent && x.textCorrect==1 && x.codeCorrect==1
        f.severity='INFO'; f.origin='CONSISTENCY'; f.status='CONSISTENT';
        f.action='NONE'; f.reason='已提供的文字、代码与独立依据一致；仅代表该关系的证据范围。';
    end
    if strcmp(f.origin,'REFERENCE_CONFLICT')&&~isempty(strtrim(x.supplementLatex))
        f.supplementLatex=x.supplementLatex;f.supplementStatus='PROPOSED_DEFINITION';
    end
    findings(end+1)=f;
end
end

function ok=tristate(v)
ok=(isnumeric(v)||islogical(v)) && isreal(v) && isscalar(v) && (isnan(v)||v==0||v==1);
end
