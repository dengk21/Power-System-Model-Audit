function psaudit_course_test_helpers
% Analytical fixtures, independent of audited homework outputs; no solves.
m=struct('baseMVA',100,'bus',[1 3 zeros(1,11);2 1 zeros(1,11)],'branch',zeros(1,13));
m.branch(1,[1 2 4 11])=[1 2 1 1];
[S,Sf,St]=psaudit_ac_network(m,[1;1i]);
assert(max(abs(S-[-100+100i;100+100i]))<1e-10 && abs(Sf+100-100i)<1e-10 && abs(St-100-100i)<1e-10);
m.branch(9)=2; m.bus(1,6)=10; [S,Sf,St]=psaudit_ac_network(m,[1;1]);
assert(max(abs(S-[-35i;50i]))<1e-10 && abs(Sf+25i)<1e-10 && abs(St-50i)<1e-10);
m.bus(1,6)=0;m.branch(4)=0.1;m.branch(10)=5;
[F,theta]=psaudit_dc_network(m,[30;-30]);assert(abs(F-30)<1e-10 && abs(theta(1)-theta(2)-0.06-deg2rad(5))<1e-10);
m.branch=[m.branch;m.branch];[F,theta]=psaudit_dc_network(m,[30;-30]);assert(max(abs(F-15))<1e-10);
m.branch(2,[3 4 11])=0;F=psaudit_dc_network(m,[30;-30]);assert(abs(F(1)-30)<1e-10&&F(2)==0);
[S,Sf,St]=psaudit_ac_network(m,[1;1]);assert(all(isfinite(S))&&Sf(2)==0&&St(2)==0);
[drop,tm,ss,r]=psaudit_frequency_extremum(10,2,20,12,.1);
assert(abs(ss-.1/22)<1e-12 && r==.01 && drop>ss && tm>0);
A=[-.2 -.1;20/12 -1/12];xss=-A\[-.01;0];
times=tm+[-.001 0 .001];f=arrayfun(@(t)[1 0]*(xss-expm(A*t)*xss),times);
assert(f(2)<f(1)&&f(2)<f(3)&&abs(f(2)+drop)<1e-12);
[~,tm]=psaudit_frequency_extremum(40,1,20,12,.1); assert(tm>0);
oldAlpha=(40+12)/(2*40*12);wd=sqrt(21/(40*12)-oldAlpha^2);
assert(atan(wd/(oldAlpha-1/12))/wd<0);
s=struct('Pmin',10,'Pmax',100,'Ru',10,'Rd',10,'Su',30,'Sd',30,'Lon',4,'Loff',4);
u=[0 1 1 1 1 0 0 0 0 0 0 0];d=u-u([end 1:end-1]);
[c,e]=psaudit_check_commitment(20*u,u,max(d,0),max(-d,0),s);assert(all(strcmp({c.status},'PASS')));
u(5)=0;d=u-u([end 1:end-1]);c=psaudit_check_commitment(20*u,u,max(d,0),max(-d,0),s);assert(c(strcmp({c.id},'MIN_ON')).count==1);
ss=s;ss.cyclicState=false;u=[ones(1,9) zeros(1,3)];c=psaudit_check_commitment(20*u,u,[],[],ss);assert(c(strcmp({c.id},'MIN_OFF')).count==0);
alpha=1-.95^(1/96);q=-sqrt(2)*erfcinv(2*alpha);assert(abs((1-alpha)^96-.95)<1e-12 && abs(.5*erfc(-q/sqrt(2))-alpha)<1e-12);
fprintf('PSAUDIT_COURSE_HELPERS_PASS: 12 AC/DC/frequency/UC/probability fixture groups; zero optimizer calls.\n');
end
