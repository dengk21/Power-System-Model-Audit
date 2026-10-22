function psaudit_test_core
% Cross-family hand calculations, not claims about complete optimization models.
x=struct('id','KCL','actual',[10 12],'expected',[10 12],'sense','eq', ...
    'unit','MW','absTol',1e-5,'relTol',1e-8);
c=psaudit_check_relations(x); assert(strcmp(c.status,'PASS'));
x.id='THERMAL_LIMIT'; x.actual=[80 105]; x.expected=100; x.sense='le';
c=psaudit_check_relations(x); assert(c.count==1 && c.positionResidual==5);
x.id='VOLTAGE_MIN'; x.actual=[0.95 0.90]; x.expected=0.94; x.sense='ge'; x.unit='pu';
c=psaudit_check_relations(x); assert(c.count==1 && abs(c.positionResidual-0.04)<1e-12);
u=[0 1 0.25]; x.id='BINARY_DOMAIN'; x.actual=min(abs(u),abs(u-1)); x.expected=0; x.sense='eq'; x.unit='dimensionless';
c=psaudit_check_relations(x); assert(c.count==1 && c.positionResidual==0.25);
x.id='UC_TRANSITION'; x.actual=[1 -1]; x.expected=[1 -1];
c=psaudit_check_relations(x); assert(strcmp(c.status,'PASS'));
x.id='PROBABILITY_SUM'; x.actual=sum([0.2 0.3 0.5]); x.expected=1;
c=psaudit_check_relations(x); assert(strcmp(c.status,'PASS'));
E=psaudit_reconstruct_storage(10,[4 0 0],[0 2 0],0.9,0.8,0.5,0);
assert(max(abs(E-[10 11.8 10.55 10.55]))<1e-12);
x.id='STORAGE_TRACE'; x.unit='MWh'; x.actual=[10 11.8 11 11]; x.expected=E;
c=psaudit_check_relations(x); assert(c.count==2 && abs(c.positionResidual-0.45)<1e-12);
x.actual=[1 NaN]; x.expected=0; c=psaudit_check_relations(x); assert(strcmp(c.status,'DATA_INSUFFICIENT'));
x.actual=ones(2,3); x.expected=ones(2,1); c=psaudit_check_relations(x); assert(strcmp(c.status,'DATA_INSUFFICIENT'));
x.expected=1; x.mask=false(2,3); c=psaudit_check_relations(x); assert(strcmp(c.status,'NOT_APPLICABLE'));
x.mask=true(2,3); x.actual(2,3)=2; x.mask(2,3)=false;
c=psaudit_check_relations(x); assert(strcmp(c.status,'PASS'));
x=rmfield(x,'mask'); x.actual=[1e8 0.001]; x.expected=[1e8-0.5 0]; x.relTol=1e-8;
c=psaudit_check_relations(x); assert(c.maxResidual==0.5 && strcmp(c.position,'1,2') && c.positionResidual>c.tolerance);
E=psaudit_reconstruct_storage([10;20],[2 0;0 4],[0 2;4 0],0.5,0.5,0.5,0.1);
assert(max(abs(E-[10 9.5 6.55;20 14 13.6]),[],'all')<1e-12);
rejected=false;
try, psaudit_reconstruct_storage(10,ones(1,2,2),ones(1,2,2),1,1,1,0); catch, rejected=true; end
assert(rejected,'3-D storage data must not be silently flattened');
fprintf('PSAUDIT_CORE_TEST_PASS: 15 cross-family primitive/invalid-data cases; zero solver calls.\n');
end
