function items=psaudit_hw5_repair_checks(p,v,objective)
% Independent full trajectory reconstruction. No candidate H, A, obj or window.
s=p.s;I=s.I;T=s.T;
for name={'p','u','z','c'}
    assert(isfield(v,name{1})&&isequal(size(v.(name{1})),[I T]),'Missing full primary trajectory');
end
u=v.u;g=v.p;z=u-u(:,[T,1:T-1]);start=max(z,0);stop=max(-z,0);
items=relation('U_BINARY',u,round(u),'eq','1');
add('U_LOW',u,0,'ge','1');add('U_HIGH',u,1,'le','1');
add('Z_INTEGER',v.z,round(v.z),'eq','1');add('Z_LOW',v.z,-1,'ge','1');add('Z_HIGH',v.z,1,'le','1');
add('TRANSITION',v.z,z,'eq','1');
add('BALANCE',sum(g,1),sum(s.Pd,1),'eq','MW');
add('P_LOW',g,s.Pmin.*u,'ge','MW');add('P_HIGH',g,s.Pmax.*u,'le','MW');
Pg=s.C*g;Pic=Pg-s.Pd;idx=setdiff(1:s.N,s.slack);theta=zeros(s.N,T);
theta(idx,:)=s.B(idx,idx)\Pic(idx,:);F=s.Bf*theta;
add('MAP_PG',v.Pg,Pg,'eq','MW');add('MAP_PIC',v.Pic,Pic,'eq','MW');
add('NETWORK_FLOW',v.F,F,'eq','MW');add('NETWORK_KCL',s.A'*v.F,Pic,'eq','MW');
add('FLOW_LOW',F,-s.limit+zeros(1,T),'ge','MW');add('FLOW_HIGH',F,s.limit+zeros(1,T),'le','MW');
dp=g(:,[2:T,1])-g;
add('RAMP_UP_INTERNAL',dp(:,1:T-1),s.Su+(s.Ru-s.Su).*u(:,1:T-1),'le','MW');
add('RAMP_DOWN_INTERNAL',-dp(:,1:T-1),s.Sd+(s.Rd-s.Sd).*u(:,2:T),'le','MW');
add('RAMP_DOWN_WRAP',-dp(:,T),s.Sd+(s.Rd-s.Sd).*u(:,1),'le','MW');
on=zeros(I,T);off=on;
for t=1:T
    on(:,t)=sum(u(:,mod(t-1+(0:s.Lon-1),T)+1),2);
    off(:,t)=sum(1-u(:,mod(t-1+(0:s.Loff-1),T)+1),2);
end
add('MIN_ON',on,s.Lon*start,'ge','1');add('MIN_OFF',off,s.Loff*stop,'ge','1');
add('COST_START',v.c,s.Cstart.*v.z,'ge','USD');add('COST_STOP',v.c,-s.Cstop.*v.z,'ge','USD');
add('COST_NONNEGATIVE',v.c,0,'ge','USD');
add('OBJECTIVE',objective,s.dt*sum(s.b.*g,'all')+sum(v.c,'all'),'eq','USD');
    function add(id,a,e,sense,unit)
        items(end+1)=relation(id,a,e,sense,unit);
    end
end
function x=relation(id,a,e,sense,unit)
x=struct('id',id,'actual',a,'expected',e,'sense',sense,'unit',unit);
end
