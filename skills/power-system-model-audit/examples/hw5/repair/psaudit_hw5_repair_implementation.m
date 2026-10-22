function out=psaudit_hw5_repair_implementation(p,variant,varargin)
% Execute only the actual model-building prefix; export and solve outside here.
if strcmp(variant,'candidate'),source=p.candidateFile;else,source=p.originalFile;end
code=fileread(source);cut=strfind(code,'%% 求解');assert(isscalar(cut),'Unexpected script layout');
code=code(1:cut-1);code=regexprep(code,'(?m)^\s*(clc|clear|close all);\s*$','');
code=strrep(code,"load = load('load3996.mat').Pd;",'load = p.Pd;');
code=strrep(code,"mpc = loadcase('case39_UC');",'mpc = p.mpc;');
eval(code);
[m,recovery,diagnostic]=export(cons,obj,sdpsettings('solver','gurobi','verbose',0));
assert(isempty(diagnostic)||diagnostic.problem==0,'Model export failed');
assert(nnz(m.Q)==0,'Unexpected nonlinear objective');
model=struct('A',m.A,'obj',m.obj(:),'rhs',m.rhs(:),'sense',m.sense(:), ...
    'lb',m.lb(:),'ub',m.ub(:),'vtype',m.vtype(:),'modelsense','min','objcon',m.objcon);
map=struct;
for name={'p','u','z','c'}
    switch name{1}
        case 'p',expression=var.Pb;
        case 'u',expression=var.U;
        case 'z',expression=var.Uaction;
        case 'c',expression=var.CostAction;
    end
    [ok,at]=ismember(getvariables(expression),recovery.used_variables);
    assert(all(ok)&&numel(at)==numel(expression),'Unexpected eliminated/reordered primary variables');
    map.(name{1})=at(:);
end
allIds=[map.p;map.u;map.z;map.c];assert(numel(unique(allIds))==numel(model.obj),'Unmapped active solver variables');
canonicalObjective=[model.obj(map.p);model.obj(map.u);model.obj(map.z);model.obj(map.c)];
extension=sparse(mod(0:num.T+gen.Hon-1,num.T)+1,1:num.T+gen.Hon,1,num.T,num.T+gen.Hon);
window=extension*HMatrix;
bundle=struct('model',model,'map',map,'C',sparse(gen.busi,1:num.I,1,num.bus,num.I),'H',H, ...
    'affine',psaudit_hw5_repair_affine(window,p,canonicalObjective,model.objcon));
if isempty(varargin),out=bundle;else,out=psaudit_hw5_repair_model_items(bundle,varargin{1},varargin{2});end
end
