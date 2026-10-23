function result=psaudit_hw5_repair_replay(evidenceDirectory,reportFile)
% Replay only. No optimize/export/gurobi invocation is performed by this layer.
saved=load(fullfile(evidenceDirectory,'repair-evidence.mat'),'summary','contracts','candidates','run');
active=~all(cellfun(@isempty,saved.candidates),1);saved.candidates=saved.candidates(:,active);
assert(numel(saved.contracts)==3&&isequal(size(saved.candidates),[3 2]),'Complete three-scenario/two-variant bundle required');
expected={'nominal','exact_on','wrap_off'};
for k=1:3
    assert(isscalar(saved.contracts{k}.scenarios)&&strcmp(saved.contracts{k}.scenarios.id,expected{k}), ...
        'Repair scenario identities/order changed');
    assert(isequal(saved.contracts{k}.requireOptimal,k==1),'Repair acceptance mode changed');
end
reports=cell(size(saved.candidates));rows=cell(numel(reports),7);index=0;
for k=1:size(reports,1)
    for j=1:size(reports,2)
        r=psaudit_validate_semantic_candidate(saved.contracts{k},saved.candidates{k,j});reports{k,j}=r;
        index=index+1;scenario=saved.contracts{k}.scenarios.id;variant='original';if j==2,variant='repaired';end
        cost=NaN;referenceCost=NaN;
        if ~isempty(r.afterCosts),cost=r.afterCosts(1);end
        if ~isempty(r.scenarios),referenceCost=r.scenarios(1).referenceObjective;end
        rows(index,:)={scenario,variant,r.validationMode,r.status,cost,referenceCost,r.coverageComplete};
    end
end
result=struct('reports',{reports},'solverCalls',0,'originalSolverCalls',saved.run.actionCount, ...
    'candidateAccepted',all(cellfun(@(r)r.accepted,reports(:,2))));
if nargin<2||isempty(reportFile),return;end
assert(~isfile(reportFile),'Do not overwrite an existing report');
fid=fopen(reportFile,'w','n','UTF-8');assert(fid>=0,'Cannot create report');guard=onCleanup(@()fclose(fid));
fprintf(fid,'# HW5 最小开/关机时间完整修复与 v0.12 验收\n\n');
fprintf(fid,'生成时间：%s（Asia/Shanghai）。\n\n',char(datetime('now','TimeZone','Asia/Shanghai')));
fprintf(fid,'修复对象：M_MINIMUM_WINDOW / BOTH。原式从动作下一期计 L 项，实际限制 L+1 期；候选将 HMatrix 补零首行移至末行，从当期计 L 项。最小开机、关机两条关系一起修正。完整脚本和 TeX 副本均保留；原始文件不改。\n\n');
fprintf(fid,'捕获阶段实际 %d 次 Gurobi MIP 调用，调用墙钟 %.6fs；本次 replay 新增求解0次。\n\n',saved.run.actionCount,saved.run.elapsed);
fprintf(fid,'| 工况 | 版本 | 验收模式 | 决策 | 候选费用USD | 参考费用USD | 覆盖完整 |\n| --- | --- | --- | --- | ---: | ---: | --- |\n');
for k=1:size(rows,1),fprintf(fid,'| %s | %s | %s | %s | %.12g | %.12g | %d |\n',rows{k,:});end
fprintf(fid,'\n## 完整轨迹与独立证据\n\n');
for k=1:size(reports,1)
    c=reports{k,2};o=reports{k,1};scenario=saved.contracts{k}.scenarios;
    fprintf(fid,'### %s\n\n',scenario.id);
    if isempty(c.scenarios)
        fprintf(fid,'当前版本无法重放该工况：%s。\n\n',c.reason);continue;
    end
    data=load(scenario.referenceFile,'r');reference=data.r;
    fprintf(fid,'参考与候选均真实求解并报告 OPTIMAL；独立规范检查 %d/%d PASS，候选模型完整参考成员检查 %d/%d PASS。\n\n', ...
        nnz(strcmp({c.scenarios.referenceChecks.status},'PASS')),numel(c.scenarios.referenceChecks), ...
        nnz(strcmp({c.scenarios.referenceMembershipChecks.status},'PASS')),numel(c.scenarios.referenceMembershipChecks));
    frozen=load(files_path(saved.contracts{k}.files,'inputHash'),'scenarios');unit=frozen.scenarios.parameters.selectorUnit;
    fprintf(fid,'参考机组%d状态：`%s`。\n\n',unit,mat2str(round(reference.vars.u(unit,:))));
    for q=1:numel(o.scenarios.referenceMembershipChecks)
        check=o.scenarios.referenceMembershipChecks(q);
        if strcmp(check.status,'VIOLATION')
            fprintf(fid,'原版拒绝完整参考轨迹：%s，违规行数%d，最大残差%.12g，位置%s，阈值%.12g。\n\n', ...
                check.id,check.count,check.maxResidual,check.position,check.tolerance);
        end
    end
    if k>1
        fprintf(fid,'该参考额外固定局部状态仅用于选择合法完整轨迹；原版/候选没有该固定条件。FEASIBILITY 不比较受限参考费用与候选全局最优费用。\n\n');
    end
end
fprintf(fid,'## 修改与版本\n\n');
fprintf(fid,'- 原脚本：`%s`\n- 候选脚本：`%s`\n- 候选TeX：`%s`\n',saved.summary.originalFile,saved.summary.candidateFile,saved.summary.candidateTex);
files=saved.contracts{1}.files;
for k=1:numel(files),fprintf(fid,'- %s：`%s`，SHA-256 `%s`\n',files(k).field,files(k).path,files(k).hash);end
fprintf(fid,'\n## 结论边界\n\n');
fprintf(fid,'当前重放的修正版接受工况数：%d/%d。nominal 为独立参考最优值核对，exact_on/wrap_off 为完整可行轨迹验收。有限工况和已声明表示不构成完整可行域形式证明。\n\n', ...
    nnz(cellfun(@(r)r.accepted,reports(:,2))),size(reports,1));
fprintf(fid,'本次只修复最小时间，B_CYCLIC_RAMP 功率周期边界争议继续保留。契约保留原实现的非对称功率边界，不宣称已修复或确认其物理合理性；S/R 文字解释等其他历史问题不在本次补丁范围。solver OPTIMAL 依赖求解器，不是验证器对全局最优性的形式证明。\n');
issues=struct('location',{},'problem',{},'action',{});
action='是，候选尚未通过验收';
if result.candidateAccepted,action='是，采用已验收候选';end
issues(end+1)=struct('location','最小开/关机时间窗口', ...
    'problem','原版窗口多计一期；正文与代码均需改正','action',action);
issues(end+1)=struct('location','B_CYCLIC_RAMP', ...
    'problem','功率周期边界定义仍有争议，本次未修复','action','先确认定义');
for k=1:size(reports,1)
    c=reports{k,2};
    if ~c.accepted
        issues(end+1)=struct('location',saved.contracts{k}.scenarios.id, ...
            'problem',c.reason,'action','先核实候选/证据');
    end
end
brief=struct('checkedFiles',{{saved.summary.originalFile,saved.summary.candidateFile, ...
    saved.summary.candidateTex}},'findings',struct('severity','INFO'),'briefIssues',issues);
psaudit_write_brief_report(reportFile,brief);
end
function path=files_path(files,field)
at=find(strcmp({files.field},field));assert(isscalar(at),'Binding missing');path=files(at).path;
end
