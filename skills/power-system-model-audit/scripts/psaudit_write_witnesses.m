function psaudit_write_witnesses(fid,evidence)
fprintf(fid,'\n## 约束过松与过紧的见证检查\n\n');
fprintf(fid,'参考接受而实现拒绝为OVERRESTRICTION；参考拒绝而实现接受为UNDERRESTRICTION。LOCAL_RELATIONS只证明所列关系的差异；有限见证没有找到差异不证明可行域等价。\n\n');
if isempty(evidence),fprintf(fid,'未提供见证，过松/过紧方向尚未完成验证。\n');return;end
for k=1:numel(evidence)
    x=evidence(k);
    fprintf(fid,'### %s · %s\n\n范围：%s；来源：%s；条件：%s。参考：%s；实现：%s。\n\n赋值：%s\n\n依据：%s\n\n源码：%s\n\n', ...
        x.id,x.status,x.scope,x.kind,x.condition,x.referenceStatus,x.implementationStatus,x.assignment,x.basis,x.codeLocation);
    fprintf(fid,'| 一侧 | 关系 | 状态 | 实际 | 期望 | 定位残差 | 阈值 | 单位 |\n| --- | --- | --- | ---: | ---: | ---: | ---: | --- |\n');
    for side={'reference','implementation'}
        c=x.([side{1} 'Checks']);for j=1:numel(c)
            fprintf(fid,'| %s | %s | %s | %.12g | %.12g | %.12g | %.12g | %s |\n', ...
                side{1},c(j).id,c(j).status,c(j).actual,c(j).expected,c(j).positionResidual,c(j).tolerance,c(j).unit);
        end
    end
    fprintf(fid,'\n');
end
end
