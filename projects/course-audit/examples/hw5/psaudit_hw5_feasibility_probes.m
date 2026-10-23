function evidence=psaudit_hw5_feasibility_probes(hw5)
% Reviewed source-formula witnesses; these are local analytical trajectories.
if nargin>0,psaudit_hw5_relation_inventory(hw5);end
probes=struct('id',{},'scope',{},'kind',{},'condition',{},'referenceItems',{}, ...
    'implementationItems',{},'assignment',{},'basis',{},'codeLocation',{});
u=[0 1 1 1 1 0 0 0 0 0 0 0];
for k=1:2
    state=u;if k==2,state=1-u;end
    z=state-state([end 1:end-1]);on=max(z,0);off=max(-z,0);
    a=zeros(1,12);b=a;oldA=a;oldB=a;
    for t=1:12
        a(t)=sum(state(mod(t-1+(0:3),12)+1));b(t)=sum(1-state(mod(t-1+(0:3),12)+1));
        oldA(t)=sum(state(mod(t-1+(1:4),12)+1));oldB(t)=sum(1-state(mod(t-1+(1:4),12)+1));
    end
    reference=[relation('MIN_ON',a,4*on,'ge','periods'),relation('MIN_OFF',b,4*off,'ge','periods')];
    implementation=[relation('MIN_ON',oldA,4*z,'ge','periods'),relation('MIN_OFF',oldB,-4*z,'ge','periods')];
    id='W_MINIMUM_ON';if k==2,id='W_MINIMUM_OFF';end
    add(id,'DECLARED_ONE_HOUR',reference,implementation,['u=' mat2str(state) '; dt=0.25h; L=4'], ...
        'Count four periods beginning at the action period. Reviewed source excludes that period.', ...
        'basicTask2_UC_2variable.m:105-112 / HW5.tex:34-40');
end
p=[100 90 80 70*ones(1,9)];dp=p([2:end 1])-p;
reference=relation('RAMP_UP',dp,10,'le','MW/step');
implementation=relation('RAMP_UP',[diff(p) 0],10,'le','MW/step');
add('W_CYCLIC_UP_RAMP','ONLY_IF_POWER_IS_CYCLIC',reference,implementation, ...
    ['u=ones(1,12); p=' mat2str(p) '; R=10 MW/step'], ...
    'Internal transitions pass; T to 1 rises 30MW. Original upper-ramp matrix replaces that transition with zero.', ...
    'four UC entries: upper-ramp circle');
evidence=psaudit_evaluate_witnesses(probes);
    function add(id,condition,ref,impl,assignment,basis,location)
        if nargin>0 && exist('hw5','var'),location=fullfile(hw5,location);end
        probes(end+1)=struct('id',id,'scope','LOCAL_RELATIONS','kind','ANALYTICAL_TRAJECTORY', ...
            'condition',condition,'referenceItems',ref,'implementationItems',impl, ...
            'assignment',assignment,'basis',basis,'codeLocation',location);
    end
end
function x=relation(id,a,e,sense,unit)
x=struct('id',id,'actual',a,'expected',e,'sense',sense,'unit',unit,'absTol',1e-6,'relTol',1e-8);
end
