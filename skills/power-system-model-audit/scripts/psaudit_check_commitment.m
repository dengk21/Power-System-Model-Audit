function [checks,event]=psaudit_check_commitment(p,u,v,w,s)
% Independent UC trajectory relations; cyclic state, conditional power wrap.
checks=psaudit_check_relations(struct([])); event=struct;
[I,T]=size(u);
assert(isscalar(s.Lon)&&isscalar(s.Loff)&&s.Lon>=1&&s.Loff>=1&&s.Lon==round(s.Lon)&&s.Loff==round(s.Loff),'This helper requires uniform integer on/off durations; adapt per-device windows explicitly');
assert(isequal(size(p),[I T]) && all(isfinite(p),'all') && all(isfinite(u),'all'));
add('U_BINARY',u,round(u),'eq','binary',1e-6);add('U_LOW',u,0,'ge','binary',1e-6);add('U_HIGH',u,1,'le','binary',1e-6);
add('P_LOW',p,s.Pmin.*u,'ge','MW',1e-5);add('P_HIGH',p,s.Pmax.*u,'le','MW',1e-5);
if any(abs(u-round(u))>1e-6+1e-8,'all'), return;end
u=round(u); d=u-u(:,[T 1:T-1]);
cyclic=~isfield(s,'cyclicState')||s.cyclicState;
if ~cyclic,d(:,1)=0;end % unknown initial event is excluded from duration checks
event.start=max(d,0);event.stop=max(-d,0);event.delta=d;event.initialUnknown=~cyclic;
next=[2:T 1];dp=p(:,next)-p;up=s.Su+(s.Ru-s.Su).*u;down=s.Sd+(s.Rd-s.Sd).*u(:,next);
add('RAMP_UP',dp(:,1:T-1),up(:,1:T-1),'le','MW',1e-5);add('RAMP_DOWN',dp(:,1:T-1),-down(:,1:T-1),'ge','MW',1e-5);
add('WRAP_UP_CONDITIONAL',dp(:,T),up(:,T),'le','MW',1e-5);add('WRAP_DOWN_CONDITIONAL',dp(:,T),-down(:,T),'ge','MW',1e-5);
on=zeros(I,T);off=on;
for t=1:T,on(:,t)=sum(u(:,mod(t-1+(0:s.Lon-1),T)+1),2);off(:,t)=sum(1-u(:,mod(t-1+(0:s.Loff-1),T)+1),2);end
onMask=true(I,T);offMask=onMask;
if ~cyclic,onMask(:,1)=false;offMask(:,1)=false;onMask(:,max(2,T-s.Lon+2):T)=false;offMask(:,max(2,T-s.Loff+2):T)=false;end
add('MIN_ON',on,s.Lon*event.start,'ge','periods',1e-6,onMask);add('MIN_OFF',off,s.Loff*event.stop,'ge','periods',1e-6,offMask);
if ~isempty(v)&&~isempty(w)
    assert(isequal(size(v),size(u),size(w)) && all(isfinite(v),'all') && all(isfinite(w),'all'));
    add('V_BINARY',v,round(v),'eq','binary',1e-6);add('W_BINARY',w,round(w),'eq','binary',1e-6);
    add('V_LOW',v,0,'ge','binary',1e-6);add('V_HIGH',v,1,'le','binary',1e-6);add('W_LOW',w,0,'ge','binary',1e-6);add('W_HIGH',w,1,'le','binary',1e-6);
    add('V_LOWER',v,d,'ge','state change',1e-6);add('W_LOWER',w,-d,'ge','state change',1e-6);
    add('V_EVENT_DIAGNOSTIC',v,event.start,'eq','binary',1e-6);add('W_EVENT_DIAGNOSTIC',w,event.stop,'eq','binary',1e-6);
end
    function add(id,a,e,sense,unit,tol,mask)
        x=struct('id',id,'actual',a,'expected',e,'sense',sense,'unit',unit,'absTol',tol,'relTol',1e-8);
        if nargin==7,x.mask=mask;end
        checks(end+1)=psaudit_check_relations(x);
    end
end
