function psaudit_test_affine
% Operator checks include mistakes that cannot activate at the saved point.
n=0;
r=struct('id','BALANCE','kind','constraint','A',[1 1;1 0], ...
    'b',[10;2],'rowKeys',{{'balance/t1','capacity/g1'}}, ...
    'variableKeys',{{'g1/t1','g2/t1'}},'variableUnits',{{'MW','MW'}}, ...
    'rowUnits',{{'MW','MW'}},'sense',{{'eq','le'}}, ...
    'confirmed',true,'basis','Independent hand-derived load and capacity', ...
    'absTol',1e-10,'relTol',1e-10);
expect(r,r,'MATCH');
v=r;v.A=v.A([2 1],[2 1]);v.b=v.b([2 1]);v.rowKeys=v.rowKeys([2 1]);
v.variableKeys=v.variableKeys([2 1]);v.sense=v.sense([2 1]);expect(r,v,'MATCH');
v=r;v.A=2*v.A;v.b=2*v.b;expect(r,v,'MATCH');
v=r;v.A(1,:)=-v.A(1,:);v.b(1)=-v.b(1);expect(r,v,'MATCH');
v=r;v.A(2,:)=-v.A(2,:);v.b(2)=-v.b(2);v.sense{2}='ge';expect(r,v,'MATCH');
v=r;v.A(1,1)=2;expect(r,v,'MISMATCH');
v=r;v.b(2)=3;expect(r,v,'MISMATCH');
v=r;v.sense{2}='eq';expect(r,v,'MISMATCH');
v=r;v.variableUnits={'kW','kW'};v.rowUnits={'kW','kW'};v.b=1000*v.b;expect(r,v,'MATCH');
v=r;v.variableUnits={'kW','kW'};v.A=v.A/1000;expect(r,v,'MATCH');
v=r;v.variableUnits={'kW','kW'};expect(r,v,'MISMATCH');
v=r;v.rowUnits={'pu','pu'};expect(r,v,'DATA_INSUFFICIENT');
v=r;v.rowKeys{2}='capacity/g2';expect(r,v,'MISMATCH');
v=r;v.variableKeys{2}=v.variableKeys{1};expect(r,v,'DATA_INSUFFICIENT');
v=r;v.A(1,1)=NaN;expect(r,v,'DATA_INSUFFICIENT');
v=r;v.b=[10 2 1];expect(r,v,'DATA_INSUFFICIENT');
u=r;u.confirmed=false;expect(u,r,'REFERENCE_CONFLICT');
u=r;u.basis='';expect(u,r,'REFERENCE_CONFLICT');
u=r;u.kind='objective';u.A=[10 20];u.b=5;u.rowKeys={'cost'};u.rowUnits={'USD'};u.sense='objective';u.objectiveSense='min';
expect(u,u,'MATCH');v=u;v.A=2*v.A;v.b=2*v.b;expect(u,v,'MISMATCH');
v=u;v.A=v.A/1000;v.variableUnits={'kW','kW'};expect(u,v,'MATCH');
v=u;v.rowUnits={'CNY'};expect(u,v,'DATA_INSUFFICIENT');
v=u;v.objectiveSense='max';expect(u,v,'MISMATCH');
v=rmfield(u,'objectiveSense');expect(u,v,'DATA_INSUFFICIENT');
u=r;u.A=[1 0;1 0];u.b=[1e12;2];
v=u;v.A(1,1)=2;expect(u,v,'MISMATCH');
v=u;v.A=2*v.A;v.b=2*v.b;expect(u,v,'MATCH');
% Correct p1-p0-dt*pch=0, with pch=0 in the saved point: a wrong dt is dormant.
u=r;u.id='STORAGE';u.A=[-1 1 -.25];u.b=0;u.rowKeys={'state/t1'};
u.variableKeys={'E0','E1','pch1'};u.variableUnits={'MWh','MWh','MW'};u.rowUnits={'MWh'};u.sense='eq';
v=u;v.A(3)=-1;assert(u.A*[10;10;0]==0&&v.A*[10;10;0]==0);expect(u,v,'MISMATCH');
v=u;v.A=[-1 -.25 1];expect(u,v,'MISMATCH');
fprintf('PASS affine semantic comparison: %d controls; zero solver calls\n',n);
    function expect(a,b,status)
        got=psaudit_compare_affine(a,b);assert(strcmp(got.status,status),'Expected %s, got %s: %s',status,got.status,got.detail);n=n+1;
    end
end
