function file=psaudit_write_brief_report(professionalFile,document)
% A short action list derived from the same reviewed data as the full report.
[folder,name,extension]=fileparts(professionalFile);
if strcmp(name,'audit_report'),briefName='audit_brief.md';
else,briefName=[name '_brief.md'];end
file=fullfile(folder,briefName);
if ~isempty(folder)&&~isfolder(folder),mkdir(folder);end
files={};
if isfield(document,'checkedFiles')
    files=document.checkedFiles;
elseif isfield(document,'versions')
    files={document.versions.path};
elseif isfield(document,'entries')
    files={document.entries.key};
end
files=unique(files(~cellfun(@isempty,files)),'stable');
labels=cellfun(@filename,files,'UniformOutput',false);
originalLabels=labels;
for k=1:numel(labels)
    if sum(strcmp(labels{k},originalLabels))>1,labels{k}=files{k};end
end
if isempty(labels),labels={'未记录，见专业报告的覆盖限制'};end
fid=fopen(file,'w','n','UTF-8');assert(fid>=0,'Cannot create brief report');
guard=onCleanup(@()fclose(fid));
fprintf(fid,'# 审计简报\n\n检查文件：%s。\n\n',clean(strjoin(labels,'、')));
fprintf(fid,'| 位置 | 可能的问题 | 是否需要改正 |\n| --- | --- | --- |\n');
count=0;
if isfield(document,'findings')
    for k=1:numel(document.findings)
        f=document.findings(k);
        if strcmp(f.severity,'INFO'),continue;end
        location=f.codeLocation;
        if ismember(f.origin,{'MATHEMATICAL_MODEL','DOCUMENTATION_GAP'}),location=f.textLocation;
        elseif strcmp(f.origin,'BOTH'),location=[f.textLocation '；' f.codeLocation];end
        action='待确认，暂不改';
        if strcmp(f.origin,'REFERENCE_CONFLICT'),action='先确认定义';
        elseif strcmp(f.severity,'ERROR')
            switch f.origin
                case 'MATHEMATICAL_MODEL',action='是，改正文/公式';
                case 'IMPLEMENTATION',action='是，改代码';
                case 'BOTH',action='是，改正文和代码';
                otherwise,action='需核实后改正';
            end
        elseif strcmp(f.origin,'DOCUMENTATION_GAP')&&strcmp(f.status,'CONFIRMED_GAP')
            action='是，补文档';
        end
        row(location,[f.id '：' f.reason],action);
    end
end
if ~isfield(document,'findings')||isempty(document.findings)
    row('数学说明/代码','尚无经审阅的语义清单','待完成检查');
end
if isfield(document,'entries')
    for k=1:numel(document.entries)
        e=document.entries(k);
        if isfield(e,'executionError')&&~isempty(e.executionError)
            row(e.key,['执行/检查失败：' e.executionError],'先排查失败');
        end
        for j=1:numel(e.checks)
            c=e.checks(j);
            if strcmp(c.status,'VIOLATION')
                row([e.key ' / ' c.id ' / ' c.position],'数值检查不满足参考关系','需核实后改正');
            elseif strcmp(c.status,'DATA_INSUFFICIENT')
                row([e.key ' / ' c.id],'数值证据不足','先补证据');
            end
        end
    end
end
if isfield(document,'briefIssues')
    for k=1:numel(document.briefIssues)
        x=document.briefIssues(k);row(x.location,x.problem,x.action);
    end
end
if count==0,row('本次已检查范围','未发现需处理问题','暂不需要');end
fprintf(fid,'\n[专业报告](<%s>)\n',[name extension]);

    function row(location,problem,action)
        count=count+1;
        location=strrep(location,'\','/');
        location=regexprep(location,'(?:[A-Za-z]:)?(?:/[^/;；\r\n]+)+/','');
        location=regexprep(location,'\s+\(.*\)$','');
        fprintf(fid,'| %s | %s | %s |\n',clean(location),short(problem),clean(action));
    end
end
function value=filename(value)
value=strrep(value,'\','/');parts=strsplit(value,'/');value=parts{end};
end
function value=clean(value)
value=char(value);value=strrep(value,'|','/');value=regexprep(value,'\s+',' ');
end
function value=short(value)
value=clean(value);if numel(value)>60,value=[value(1:59) '…'];end
end
