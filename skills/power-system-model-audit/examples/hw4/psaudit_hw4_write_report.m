function checks=psaudit_hw4_write_report(hw4,model,resultFile,reportPath,specPath,confirmed,inventory)
% Result-only verification, with provenance gate and one Markdown output.
if nargin<5, specPath=fullfile(fileparts(mfilename('fullpath')),'math-spec.md'); end
if nargin<6, confirmed=false; end
s=psaudit_hw4_build_reference(hw4,model,specPath); s.confirmed=confirmed;
assert(~isfile(reportPath),'Report exists; choose another path');
checks=[]; warnings={}; r=[];
if nargin<7
    try, inventory=psaudit_hw4_relation_inventory(hw4,model);
    catch err, inventory=struct([]); warnings{end+1}=['数学模型双向复核需重新进行：' err.message]; end
end
findings=psaudit_review_inventory(inventory);
mathConflict=any(strcmp({findings.severity},'ERROR') & ...
    (strcmp({findings.origin},'MATHEMATICAL_MODEL') | strcmp({findings.origin},'BOTH')));
referenceConflict=any(strcmp({findings.origin},'REFERENCE_CONFLICT') & strcmp({findings.status},'UNRESOLVED'));
if (mathConflict || referenceConflict) && confirmed
    confirmed=false; s.confirmed=false;
    warnings{end+1}='原数学模型存在独立反证或未解决争议，撤销其作为当前已确认数值参考的定级；保留原基线条件式检查，修正需另建版本。';
end
if ~confirmed, warnings{end+1}='规范尚未人工确认；以下数值违规只能作为条件式 WARNING，不能确认代码错误。'; end
if isempty(resultFile) || ~isfile(resultFile)
    warnings{end+1}='没有完整调度结果；数值检查数据不足。load3996.mat 是输入，不能用作结果。';
else
    try
        data=load(resultFile,'r'); assert(isfield(data,'r'),'Missing r structure'); r=data.r;
        pairs={'sourceHash',psaudit_hash_file(fullfile(hw4,model)); ...
            'caseHash',psaudit_hash_file(fullfile(hw4,'case39_ED.m')); ...
            'loadHash',psaudit_hash_file(fullfile(hw4,'load3996.mat')); ...
            'specHash',s.specHash};
        for k=1:size(pairs,1)
            assert(isfield(r,pairs{k,1}) && strcmp(r.(pairs{k,1}),pairs{k,2}), ...
                'Hash mismatch: %s',pairs{k,1});
        end
        assert(isfield(r,'model') && strcmp(r.model,model),'Entry mismatch');
        assert(isfield(r,'problem') && ismember(r.problem,[0 3]),'No usable solver status');
        checks=psaudit_hw4_check_solution(r,s);
        if r.problem~=0, warnings{end+1}='存在非最优状态的可用解；没有证实最优性。'; end
    catch err
        warnings{end+1}=['结果无法用于检查：' err.message];
    end
end
folder=fileparts(reportPath); if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end
fid=fopen(reportPath,'w','n','UTF-8'); assert(fid>=0,'Cannot write report'); cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'# PowerSystemModelAudit · HW4 审计报告\n\n');
fprintf(fid,'## 输入与环境\n\n- 模型：`%s`\n- 源码 SHA-256：`%s`\n',fullfile(hw4,model),psaudit_hash_file(fullfile(hw4,model)));
fprintf(fid,'- case SHA-256：`%s`\n- 负荷 SHA-256：`%s`\n',psaudit_hash_file(fullfile(hw4,'case39_ED.m')),psaudit_hash_file(fullfile(hw4,'load3996.mat')));
fprintf(fid,'- 规范：`%s`\n- 规范 SHA-256：`%s`\n- 规范确认：%d\n',specPath,s.specHash,confirmed);
fprintf(fid,'- 检查器 SHA-256：`%s`\n- 参数构建器 SHA-256：`%s`\n',psaudit_hash_file(which('psaudit_hw4_check_solution')),psaudit_hash_file(which('psaudit_hw4_build_reference')));
fprintf(fid,'- 通用关系内核 SHA-256：`%s`\n',psaudit_hash_file(which('psaudit_check_relations')));
fprintf(fid,'- 原文 TeX SHA-256：`%s`\n- 归因规则 SHA-256：`%s`\n', ...
    psaudit_hash_file(fullfile(hw4,'HW4.tex')),psaudit_hash_file(which('psaudit_review_inventory')));
fprintf(fid,'- MATLAB：%s\n- 结果：`%s`\n- 本次检查新增求解：0\n',version,resultFile);
if ~isempty(r) && isfield(r,'problem')
    fprintf(fid,'- 已记录求解状态：%d；%s\n',r.problem,r.info);
    if isfield(r,'yalmipVersion'), fprintf(fid,'- YALMIP：%s\n',r.yalmipVersion); end
    if isfield(r,'solver'), fprintf(fid,'- 活动求解器：%s\n- 求解器接口：`%s`\n',r.solver,r.solverPath);
    elseif isfield(r,'gurobiPath'), fprintf(fid,'- Gurobi 接口：`%s`\n',r.gurobiPath); end
    if isfield(r,'elapsed'), fprintf(fid,'- 原求解耗时：%.6g s\n',r.elapsed); end
    if isfield(r,'solveCount'), fprintf(fid,'- 结果生成求解次数：%d\n- 原单次求解上限：%.6g s\n',r.solveCount,r.timeLimit); end
end
fprintf(fid,'\n## 检查范围与映射\n\n计划检查范围为全部机组、线路及 96 时段，爬坡包含 95 个转换；实际完成状态见数值证据表，数据不足不能作为通过。储能/启停/无功/电压不适用。公式—代码行号映射与源码根因由 Agent 阅读活动代码后补充；本表不代替静态审计。\n');
fprintf(fid,'\n## ERROR\n\n'); n=0;
for k=1:numel(checks)
    c=checks(k);
    if confirmed && strcmp(c.status,'VIOLATION')
        n=n+1; fprintf(fid,'- E%02d · 已确认数值违规 · %s：最大残差 %.12g %s，位置 %s；源码根因未定位。\n',n,c.id,c.maxResidual,c.unit,c.position);
    end
end
if n==0 && ~any(strcmp({findings.severity},'ERROR')), fprintf(fid,'在本次检查范围与已有结果下未发现 ERROR。\n'); end
for k=1:numel(findings)
    f=findings(k);
    if strcmp(f.severity,'ERROR'), fprintf(fid,'- %s · %s · %s：%s\n',f.id,f.origin,f.status,f.reason); end
end
fprintf(fid,'\n## WARNING\n\n');
for k=1:numel(checks)
    c=checks(k);
    if strcmp(c.status,'DATA_INSUFFICIENT'), warnings{end+1}=[c.id ': ' c.detail]; end
    if ~confirmed && strcmp(c.status,'VIOLATION'), warnings{end+1}=sprintf('%s：在草案假设下存在数值违规，需确认规范后定级。',c.id); end
end
for k=1:numel(findings)
    f=findings(k);
    if strcmp(f.severity,'WARNING'), warnings{end+1}=sprintf('%s / %s：%s',f.id,f.origin,f.reason); end
end
if isempty(warnings), fprintf(fid,'无。\n'); end
for k=1:numel(warnings), fprintf(fid,'- W%02d：%s\n',k,warnings{k}); end
fprintf(fid,'\n## 独立数值证据\n\n位置为数组 1-based 索引，p=(机组,时段)、q=(机组,分段,时段)、F=(支路,时段)；爬坡第二维 k 对应 k→k+1。机组节点为 [%s]；支路端点按 case 行顺序。\n\n',num2str(s.genBus'));
fprintf(fid,'| ID | 状态 | 最大原始残差 | 定位残差 | 定位阈值 | 违规数 | 位置 | 实际值 | 期望/边界 | 单位 |\n| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |\n');
for k=1:numel(checks)
    c=checks(k); fprintf(fid,'| %s | %s | %.12g | %.12g | %.12g | %d | %s | %.12g | %.12g | %s |\n',c.id,c.status,c.maxResidual,c.positionResidual,c.tolerance,c.count,c.position,c.actual,c.expected,c.unit);
end
if isempty(checks), fprintf(fid,'\n数据不足，未执行数值检查。\n'); end
psaudit_write_model_review(fid,findings);
fprintf(fid,'\n## 限制与复跑\n\n固定检查器按 HW4 草案重建网络/成本，未证明代码完整或 AC 可行性；参数/约定改变需要新规范与检查器。手算样例不是求解结果。保留上列输入哈希，调用 psaudit_hw4_write_report 可复跑；它不调用求解器。\n');
end
