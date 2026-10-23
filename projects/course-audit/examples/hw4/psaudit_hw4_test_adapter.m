function psaudit_hw4_test_adapter
% Hand-computed verifier tests, never presented as optimization results.
s=struct('N',2,'L',1,'I',1,'T',3,'C',[1;0],'Pd',[0 0 0;10 11 12], ...
    'Pmin',0,'Pmax',20,'ramp',1,'A',[1 -1],'Bf',[1 -1], ...
    'B',[1 -1;-1 1],'Bstar',[0 -1;-1 1],'slack',1,'limit',20, ...
    'segmented',false,'cost',[0 2 0],'dt',0.25,'powerAbs',1e-5,'costAbs',1e-4,'rel',1e-8);
r=struct('hasSolution',true,'p',[10 11 12],'Pg',[10 11 12;0 0 0], ...
    'Pic',[10 11 12;-10 -11 -12],'F',[10 11 12],'objective',16.5);
c=psaudit_hw4_check_solution(r,s); assert(all(strcmp({c.status},'PASS')));
% Formula/coefficient: exported objective missing dt.
bad=r; bad.objective=66; c=psaudit_hw4_check_solution(bad,s);
assert(strcmp(c(strcmp({c.id},'O_COST')).status,'VIOLATION'));
% Temporal offset: non-constant Pic is shifted one step, p stays correct.
bad=r; bad.Pic=r.Pic(:,[2 3 1]); c=psaudit_hw4_check_solution(bad,s);
assert(strcmp(c(strcmp({c.id},'C_MAP_Z')).status,'VIOLATION'));
% A missing upper bound may permit p=21; this only tests the residual engine.
bad=r; bad.p(3)=21; c=psaudit_hw4_check_solution(bad,s);
g=c(strcmp({c.id},'C_GEN_HIGH')); assert(g.count==1 && g.maxResidual==1);
% Exact ramp boundary passes; final transition violation is found.
bad=r; bad.p(3)=13; c=psaudit_hw4_check_solution(bad,s);
g=c(strcmp({c.id},'C_RAMP_UP')); assert(g.count==1 && strcmp(g.position,'1,2'));
bad=r; bad.p(1)=NaN; c=psaudit_hw4_check_solution(bad,s); assert(strcmp(c(1).status,'DATA_INSUFFICIENT'));
bad=rmfield(r,'p'); c=psaudit_hw4_check_solution(bad,s); assert(strcmp(c(1).status,'DATA_INSUFFICIENT'));
bad=r; bad.hasSolution=false; c=psaudit_hw4_check_solution(bad,s); assert(strcmp(c(1).status,'DATA_INSUFFICIENT'));
bad=r; bad.F=Inf(1,3); c=psaudit_hw4_check_solution(bad,s);
assert(strcmp(c(strcmp({c.id},'C_NET_F')).status,'DATA_INSUFFICIENT'));
% Segments: same dispatch, 3 pieces, known slopes, T=3.
ss=s; ss.segmented=true; ss.segLower=[0 0 0]; ss.segUpper=[8 8 4]; ss.slopes=[1 2 3]; ss.constant=0;
rr=r; rr.q=zeros(1,3,3); rr.q(1,1,:)=8; rr.q(1,2,:)=reshape([2 3 4],1,1,3);
rr.objective=10.5; c=psaudit_hw4_check_solution(rr,ss); assert(all(strcmp({c.status},'PASS')));
% Missing q is not a passing segmented-cost check.
c=psaudit_hw4_check_solution(r,ss); assert(strcmp(c(end).status,'DATA_INSUFFICIENT'));
fprintf('PSAUDIT_HW4_TEST_PASS: 11 hand-computed cases; zero solver calls.\n');
end
