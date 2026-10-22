function summary=psaudit_write_audit_report(file,document)
% Render this run's entries and reviewed evidence; no case conclusions here.
required={'title','entries','findings','witnesses','execution','notes','links'};
assert(all(isfield(document,required)),'Incomplete report document');
a=document.entries;f=document.findings;c=psaudit_check_relations(struct([]));
for k=1:numel(a),c=[c a(k).checks];end
summary=struct('entries',numel(a),'checks',numel(c),'pass',sum(strcmp({c.status},'PASS')), ...
    'violations',sum(strcmp({c.status},'VIOLATION')),'missing',sum(strcmp({c.status},'DATA_INSUFFICIENT')), ...
    'errors',sum(strcmp({f.severity},'ERROR')),'warnings',sum(strcmp({f.severity},'WARNING')));
folder=fileparts(file);if ~isfolder(folder),mkdir(folder);end
fid=fopen(file,'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'# %s\n\n报告生成时间：%s。\n\n',document.title,char(datetime('now','TimeZone','Asia/Shanghai')));
fprintf(fid,'本次读取%d个入口，%d项数值类别：%d PASS / %d VIOLATION / %d DATA_INSUFFICIENT。经审阅清单给出%d项ERROR、%d项WARNING；数值违规不自动等于代码错误。\n\n', ...
    summary.entries,summary.checks,summary.pass,summary.violations,summary.missing,summary.errors,summary.warnings);
state=document.execution;
fprintf(fid,'执行模式：%s；本次新增执行动作：%d；累计动作耗时：%.6fs。\n\n',state.mode,state.actionCount,state.elapsed);
if ~isempty(state.actions)
    fprintf(fid,'| 动作 | 类型 | 单次预算s | 实际s | 状态 |\n| --- | --- | ---: | ---: | --- |\n');
    for k=1:numel(state.actions),x=state.actions(k);fprintf(fid,'| %s | %s | %.6g | %.6g | %s |\n',x.label,x.kind,x.limit,x.elapsed,x.status);end
end
fprintf(fid,'\n## 全入口覆盖与数值状态\n\n| 入口 | 执行/有效解状态 | 原耗时s | 目标 | PASS/VIOLATION/DATA | 原始结果SHA-256 |\n| --- | --- | ---: | ---: | --- | --- |\n');
for k=1:numel(a)
    x=a(k);checks=x.checks;
    fprintf(fid,'| %s | %s | %.6g | %.12g | %d/%d/%d | %s |\n',x.key,x.state,x.elapsed,x.objective, ...
        sum(strcmp({checks.status},'PASS')),sum(strcmp({checks.status},'VIOLATION')),sum(strcmp({checks.status},'DATA_INSUFFICIENT')),x.resultHash);
end
fprintf(fid,'\n## 执行与检查器失败\n\n');
errors=0;
for k=1:numel(a)
    if isfield(a(k),'executionError')&&~isempty(a(k).executionError)
        errors=errors+1;fprintf(fid,'### %s\n\n```text\n%s\n```\n\n',a(k).key,a(k).executionError);
    end
end
if errors==0,fprintf(fid,'本次输入没有记录执行或检查器异常。\n');end
fprintf(fid,'\n## ERROR与WARNING\n\n');
if isempty(f),fprintf(fid,'没有经审阅语义清单，不能据数值通过声明模型正确。\n');end
for k=1:numel(f)
    if strcmp(f(k).severity,'INFO'),continue;end
    fprintf(fid,'- %s / %s · %s · %s：%s\n',f(k).severity,f(k).origin,f(k).id,f(k).status,f(k).reason);
end
if summary.errors==0,fprintf(fid,'经本次提供的清单未确认ERROR；缺失证据仍保留。\n');end
psaudit_write_model_review(fid,f);psaudit_write_witnesses(fid,document.witnesses);
fprintf(fid,'\n## 数值证据\n\n');
for k=1:numel(a)
    x=a(k);fprintf(fid,'### %s\n\n结果：[%s](<%s>)。\n\n',x.key,x.key,strrep(x.resultFile,'\','/'));
    fprintf(fid,'| ID | 状态 | 最大残差 | 定位残差 | 阈值 | 违规数 | 位置 | 实际 | 期望 | 单位 |\n| --- | --- | ---: | ---: | ---: | ---: | --- | ---: | ---: | --- |\n');
    for j=1:numel(x.checks),z=x.checks(j);fprintf(fid,'| %s | %s | %.12g | %.12g | %.12g | %d | %s | %.12g | %.12g | %s |\n', ...
        z.id,z.status,z.maxResidual,z.positionResidual,z.tolerance,z.count,z.position,z.actual,z.expected,z.unit);end
end
fprintf(fid,'\n## 证据、复验与限制\n\n');
if isfield(document,'versions')
    fprintf(fid,'| 输入/参考 | SHA-256 |\n| --- | --- |\n');
    for k=1:numel(document.versions),x=document.versions(k);fprintf(fid,'| [%s](<%s>) | %s |\n',x.label,strrep(x.path,'\','/'),x.hash);end
end
for k=1:numel(document.links),x=document.links(k);fprintf(fid,'- [%s](<%s>)\n',x.label,strrep(x.path,'\','/'));end
for k=1:numel(document.notes),fprintf(fid,'\n%s\n',document.notes{k});end
fprintf(fid,'\n脚本填充数值，数学语义来自经审阅清单。补全/修正为候选实文；未自动改原TeX或源码。当前结果不证明任意模型正确、可行域等价或未认证的最优性。\n');
end
