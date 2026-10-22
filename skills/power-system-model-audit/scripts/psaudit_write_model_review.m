function psaudit_write_model_review(fid,findings)
% Append provenance-aware diagnosis and actual LaTeX supplements to a report.
assert(fid>=0,'Invalid report file handle');
fprintf(fid,'\n## 数学模型—代码双向核对\n\n');
fprintf(fid,'来源分别标记 MATHEMATICAL_MODEL、IMPLEMENTATION、BOTH、DOCUMENTATION_GAP 或 REFERENCE_CONFLICT；数值违规本身不能确定根因。补全是可合并草案，未自动修改原始 TeX 或原验证基线。\n\n');
if isempty(findings)
    fprintf(fid,'尚未提供经审阅的双向清单，数学模型正确性与文字补全未完成检查。\n'); return
end
for k=1:numel(findings)
    f=findings(k); if strcmp(f.status,'CONSISTENT'), continue; end
    fprintf(fid,'### %s · %s\n\n- 严重性/来源：%s / %s\n- 状态：%s\n',f.id,f.origin,f.severity,f.origin,f.status);
    fprintf(fid,'- 文字位置：%s\n- 代码位置：%s\n- 独立依据：%s\n- 证据：%s\n- 判断：%s\n- 后续动作：%s\n\n', ...
        f.textLocation,f.codeLocation,f.basis,f.evidence,f.reason,f.action);
end
fprintf(fid,'\n## 数学模型补全与修正草案\n\n'); count=0;
for k=1:numel(findings)
    f=findings(k); if isempty(strtrim(f.supplementLatex)), continue; end
    count=count+1;
    fprintf(fid,'### %s · %s\n\n状态：%s。文字位置：%s；代码来源：%s。\n\n```latex\n%s\n```\n\n', ...
        f.id,f.origin,f.supplementStatus,f.textLocation,f.codeLocation,f.supplementLatex);
    fprintf(fid,'依据与适用范围：%s\n\n证据：%s\n\n',f.basis,f.evidence);
end
if count==0, fprintf(fid,'本次未形成需要补入的公式。无法推导或依据不足的项保留为待补全 WARNING，不编造公式。\n'); end
end
