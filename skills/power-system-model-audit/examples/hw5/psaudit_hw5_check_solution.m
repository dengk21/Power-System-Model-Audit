function [checks,detail]=psaudit_hw5_check_solution(r,s)
% Independent event reconstruction, cyclic dwell windows and DC power checks.
checks=psaudit_check_relations(struct([])); detail=struct;
if ~isfield(r,'hasSolution') || ~isequal(r.hasSolution,true), missing('DATA','No usable incumbent'); return; end
if ~valid('p',[s.I s.T]) || ~valid('u',[s.I s.T]), missing('DATA','Invalid p/u shape or values'); return; end
p=r.p; u=r.u; z=s.C*p-s.Pd;
add('C_U_BINARY',u,round(u),'eq','binary',s.domainAbs);
add('C_U_LOW',u,0,'ge','binary',s.domainAbs); add('C_U_HIGH',u,1,'le','binary',s.domainAbs);
add('C_BAL',sum(p,1),sum(s.Pd,1),'eq','MW',s.powerAbs,max(sum(abs(p),1),sum(abs(s.Pd),1)));
add('C_GEN_LOW',p,s.Pmin.*u,'ge','MW',s.powerAbs); add('C_GEN_HIGH',p,s.Pmax.*u,'le','MW',s.powerAbs);
if valid('Pg',[s.N s.T]), add('C_MAP_G',r.Pg,s.C*p,'eq','MW',s.powerAbs); else, missing('C_MAP_G','Pg missing'); end
if valid('Pic',[s.N s.T]), add('C_MAP_Z',r.Pic,z,'eq','MW',s.powerAbs); else, missing('C_MAP_Z','Pic missing'); end
idx=setdiff(1:s.N,s.slack); theta=zeros(s.N,s.T); theta(idx,:)=s.B(idx,idx)\z(idx,:); Fref=s.Bf*theta;
add('C_FLOW_REF_LOW',Fref,-s.limit+zeros(1,s.T),'ge','MW',s.powerAbs);
add('C_FLOW_REF_HIGH',Fref,s.limit+zeros(1,s.T),'le','MW',s.powerAbs);
if valid('F',[s.L s.T])
    add('C_NET_F',r.F,Fref,'eq','MW',s.powerAbs); add('C_NET_KCL',s.A'*r.F,z,'eq','MW',s.powerAbs);
    add('C_FLOW_LOW',r.F,-s.limit+zeros(1,s.T),'ge','MW',s.powerAbs);
    add('C_FLOW_HIGH',r.F,s.limit+zeros(1,s.T),'le','MW',s.powerAbs);
else, missing('C_NET_F','Actual branch powers missing'); end
domainBad=any(abs(u-round(u))>s.domainAbs+s.rel,'all') || any(u<-s.domainAbs | u>1+s.domainAbs,'all');
if domainBad, missing('C_STATE','Invalid binary state; cannot infer physical events'); return; end
u=round(u); prev=u(:,[s.T 1:s.T-1]); delta=u-prev; start=max(delta,0); stop=max(-delta,0);
detail.start=start; detail.stop=stop; detail.delta=delta;
next=[2:s.T 1]; dp=p(:,next)-p;
up=s.Su+(s.Ru-s.Su).*u; down=s.Sd+(s.Rd-s.Sd).*u(:,next);
add('C_RAMP_UP_INTERNAL',dp(:,1:s.T-1),up(:,1:s.T-1),'le','MW/step',s.powerAbs);
add('C_RAMP_DOWN_INTERNAL',dp(:,1:s.T-1),-down(:,1:s.T-1),'ge','MW/step',s.powerAbs);
add('C_RAMP_UP_CYCLIC',dp(:,s.T),up(:,s.T),'le','MW/step',s.powerAbs);
add('C_RAMP_DOWN_CYCLIC',dp(:,s.T),-down(:,s.T),'ge','MW/step',s.powerAbs);
on=zeros(s.I,s.T); off=on; pastOn=on; pastOff=on; legacyOn=on; legacyOff=on;
for t=1:s.T
    on(:,t)=sum(u(:,mod(t-1+(0:s.Lon-1),s.T)+1),2);
    off(:,t)=sum(1-u(:,mod(t-1+(0:s.Loff-1),s.T)+1),2);
    pastOn(:,t)=sum(u(:,mod(t-1-(1:s.Lon),s.T)+1),2);
    pastOff(:,t)=sum(1-u(:,mod(t-1-(1:s.Loff),s.T)+1),2);
    legacyOn(:,t)=sum(u(:,mod(t-1+(1:s.Lon),s.T)+1),2);
    legacyOff(:,t)=sum(1-u(:,mod(t-1+(1:s.Loff),s.T)+1),2);
end
add('C_MIN_ON',on,s.Lon*start,'ge','periods',s.domainAbs);
add('C_MIN_OFF',off,s.Loff*stop,'ge','periods',s.domainAbs);
add('C_MIN_ON_BACKWARD',pastOn,s.Lon*stop,'ge','periods',s.domainAbs);
add('C_MIN_OFF_BACKWARD',pastOff,s.Loff*start,'ge','periods',s.domainAbs);
declaredEventCost=NaN;
if s.twoVariable
    if valid('action',[s.I s.T])
        add('C_Z_INTEGER',r.action,round(r.action),'eq','integer',s.domainAbs);
        add('C_Z_TRANSITION',r.action,delta,'eq','state change',s.domainAbs);
        add('D_LEGACY_MIN_ON',legacyOn,s.Lon*r.action,'ge','periods',s.domainAbs);
        add('D_LEGACY_MIN_OFF',legacyOff,-s.Loff*r.action,'ge','periods',s.domainAbs);
        if valid('actionCost',[s.I s.T])
            add('C_COST_START_EPIGRAPH',r.actionCost,s.Cstart.*r.action,'ge','USD',s.costAbs);
            add('C_COST_STOP_EPIGRAPH',r.actionCost,-s.Cstop.*r.action,'ge','USD',s.costAbs);
            add('D_COST_EVENT_EQUALITY',r.actionCost,s.Cstart.*start+s.Cstop.*stop,'eq','USD',s.costAbs);
            declaredEventCost=sum(r.actionCost,'all');
        else, missing('C_COST_EPIGRAPH','Action cost unavailable'); end
    else, missing('C_Z_TRANSITION','Action unavailable'); end
else
    if valid('start',[s.I s.T]) && valid('stop',[s.I s.T])
        add('C_START_BINARY',r.start,round(r.start),'eq','binary',s.domainAbs);
        add('C_STOP_BINARY',r.stop,round(r.stop),'eq','binary',s.domainAbs);
        add('C_START_LOW',r.start,0,'ge','binary',s.domainAbs); add('C_START_HIGH',r.start,1,'le','binary',s.domainAbs);
        add('C_STOP_LOW',r.stop,0,'ge','binary',s.domainAbs); add('C_STOP_HIGH',r.stop,1,'le','binary',s.domainAbs);
        add('C_START_LOWER',r.start,delta,'ge','state change',s.domainAbs);
        add('C_STOP_LOWER',r.stop,-delta,'ge','state change',s.domainAbs);
        add('D_START_EVENT_EQUALITY',r.start,start,'eq','binary',s.domainAbs);
        add('D_STOP_EVENT_EQUALITY',r.stop,stop,'eq','binary',s.domainAbs);
        declaredEventCost=sum(s.Cstart.*r.start+s.Cstop.*r.stop,'all');
    else, missing('C_ACTION','Start/stop values unavailable'); end
end
detail.generationCost=s.dt*sum(s.b.*p,'all');
detail.actualEventCost=sum(s.Cstart.*start+s.Cstop.*stop,'all');
detail.declaredEventCost=declaredEventCost;
if valid('objective',[1 1]) && isfinite(declaredEventCost)
    add('O_DECLARED',r.objective,detail.generationCost+declaredEventCost,'eq','USD',s.costAbs);
    add('D_OBJECTIVE_EVENT',r.objective,detail.generationCost+detail.actualEventCost,'eq','USD',s.costAbs);
else, missing('O_DECLARED','Objective/cost data unavailable'); end
detail.maxWrapUp=max(dp(:,s.T)-up(:,s.T)); detail.rampUpWrap=dp(:,s.T); detail.rampUpWrapLimit=up(:,s.T);
detail.longestNeededOn=s.Lon; detail.longestNeededOff=s.Loff;

    function ok=valid(name,shape)
        ok=isfield(r,name) && isnumeric(r.(name)) && isreal(r.(name));
        if ok, x=r.(name); ok=isequal(size(x),shape) && all(isfinite(x(:))); end
    end
    function add(id,a,e,sense,unit,absTol,scale)
        if nargin<7, scale=max(abs(a),abs(e)); end
        item=struct('id',id,'actual',a,'expected',e,'sense',sense,'unit',unit,'absTol',absTol,'relTol',s.rel,'scale',scale);
        checks(end+1)=psaudit_check_relations(item);
    end
    function missing(id,message)
        checks(end+1)=struct('id',id,'status','DATA_INSUFFICIENT','maxResidual',NaN,'positionResidual',NaN, ...
            'tolerance',NaN,'count',0,'position','n/a','actual',NaN,'expected',NaN,'unit','n/a','detail',message);
    end
end
