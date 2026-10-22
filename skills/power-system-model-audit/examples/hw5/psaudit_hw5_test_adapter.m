function psaudit_hw5_test_adapter
% Hand-computed UC trajectories, not optimization results.
s=struct('N',2,'L',1,'I',1,'T',12,'Pd',zeros(2,12),'C',[1;0], ...
    'Pmin',10,'Pmax',100,'Ru',10,'Rd',10,'Su',30,'Sd',30,'Lon',4,'Loff',4, ...
    'B',[1 -1;-1 1],'Bf',[1 -1],'A',[1 -1],'slack',1,'limit',100, ...
    'b',2,'Cstart',3,'Cstop',1,'dt',0.25,'twoVariable',false, ...
    'powerAbs',1e-5,'costAbs',1e-4,'domainAbs',1e-6,'rel',1e-8);
u=[0 1 1 1 1 0 0 0 0 0 0 0]; r=fixture(u,20*u,s); s.Pd(2,:)=r.p;
c=psaudit_hw5_check_solution(r,s); assert(all(strcmp({c.status},'PASS')));
% Same physical trajectory in the exact action/cost formulation.
ss=s; ss.twoVariable=true; rr=rmfield(r,{'start','stop'});
rr.action=u-u([end 1:end-1]); rr.actionCost=3*max(rr.action,0)+max(-rr.action,0);
c=psaudit_hw5_check_solution(rr,ss);
assert(all(strcmp({c(~startsWith({c.id},'D_LEGACY')).status},'PASS')));
on=c(strcmp({c.id},'D_LEGACY_MIN_ON')); assert(on.count==1 && on.positionResidual==1);
% One-hour operation is four periods; the original excluded-current window rejects it.
assert(sum(u(2:5))==4 && sum(u(3:6))==3);
% A three-period on run must fail the correct physical minimum-time relation.
uu=u; uu(5)=0; bad=fixture(uu,20*uu,s); bs=s; bs.Pd(2,:)=bad.p;
c=psaudit_hw5_check_solution(bad,bs); assert(c(strcmp({c.id},'C_MIN_ON')).count==1);
% A cyclic startup near the final period is checked across the boundary.
uu=[1 1 0 0 0 0 0 0 0 0 1 1]; bad=fixture(uu,20*uu,s); bs=s; bs.Pd(2,:)=bad.p;
c=psaudit_hw5_check_solution(bad,bs); assert(c(strcmp({c.id},'C_MIN_ON')).count==0);
% Boundary ramp omitted by the original upper-ramp matrix: internal checks pass.
uu=ones(1,12); p=[100 90 80 70*ones(1,9)]; bad=fixture(uu,p,s); bs=s; bs.Pd(2,:)=p;
c=psaudit_hw5_check_solution(bad,bs); a=c(strcmp({c.id},'C_RAMP_UP_CYCLIC'));
assert(a.count==1 && a.positionResidual==20);
assert(c(strcmp({c.id},'C_RAMP_UP_INTERNAL')).count==0 && c(strcmp({c.id},'C_RAMP_DOWN_INTERNAL')).count==0);
M=flip(flip(eye(13,12)),2)-eye(13,12); originalUp=[p p(end)]*M;
assert(all(originalUp<=10) && p(1)-p(end)==30);
bad=r; bad.p(1)=NaN; c=psaudit_hw5_check_solution(bad,s); assert(strcmp(c(1).status,'DATA_INSUFFICIENT'));
bad=r; bad.u(2)=0.5; c=psaudit_hw5_check_solution(bad,s); assert(c(strcmp({c.id},'C_U_BINARY')).count==1);
bad=r; bad.objective=bad.objective+5; c=psaudit_hw5_check_solution(bad,s); assert(c(strcmp({c.id},'O_DECLARED')).positionResidual==5);
bad=r; bad.hasSolution=false; c=psaudit_hw5_check_solution(bad,s); assert(strcmp(c(1).status,'DATA_INSUFFICIENT'));
ss=s; ss.Lon=1; ss.Loff=1; uu=[0 1 0 1 0 0 0 0 0 0 0 0]; bad=fixture(uu,20*uu,ss); ss.Pd(2,:)=bad.p;
c=psaudit_hw5_check_solution(bad,ss); assert(c(strcmp({c.id},'C_MIN_ON')).count==0 && c(strcmp({c.id},'C_MIN_OFF')).count==0);
witnesses=psaudit_hw5_feasibility_probes();
assert(numel(witnesses)==3&&all(strcmp({witnesses(1:2).status},'OVERRESTRICTION'))&&strcmp(witnesses(3).status,'UNDERRESTRICTION'));
assert(all(strcmp({witnesses.scope},'LOCAL_RELATIONS'))&&strcmp(witnesses(3).condition,'ONLY_IF_POWER_IS_CYCLIC'));
fprintf('PSAUDIT_HW5_TEST_PASS: 10 UC trajectories/invalid-data cases plus 3 scoped witnesses; zero solver calls.\n');
end

function r=fixture(u,p,s)
delta=u-u([end 1:end-1]); start=max(delta,0); stop=max(-delta,0);
r=struct('hasSolution',true,'p',p,'u',u,'start',start,'stop',stop, ...
    'Pg',[p;zeros(size(p))],'Pic',[p;-p],'F',p, ...
    'objective',s.dt*sum(s.b.*p)+sum(s.Cstart.*start+s.Cstop.*stop));
end
