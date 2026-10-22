function a=psaudit_hw5_repair_affine(window,p,objective,constant)
% Shared serialization only. Window/target formulas come from separate builders.
I=p.s.I;T=p.s.T;n=I*T;L=p.s.Lon;
keys=arrayfun(@(k)sprintf('u/%d/%d',mod(k-1,I)+1,ceil(k/I)),1:n,'UniformOutput',false);
zk=strrep(keys,'u/','z/');rows=[strrep(keys,'u/','on/'),strrep(keys,'u/','off/')];
W=kron(window',speye(I));
a=struct('id','MINIMUM_TIME','kind','constraint','A',[W,-L*speye(n);-W,L*speye(n)], ...
    'b',[zeros(n,1);-L*ones(n,1)],'rowKeys',{rows},'variableKeys',{[keys,zk]}, ...
    'variableUnits',{repmat({'1'},1,2*n)},'rowUnits',{repmat({'1'},1,2*n)}, ...
    'sense','ge','confirmed',true,'basis','Reviewed repair/math-spec.md; independent cyclic dwell definition', ...
    'absTol',1e-9,'relTol',1e-9,'objectiveSense','');
b=a;b.id='DECLARED_OBJECTIVE';b.kind='objective';b.A=objective(:)';b.b=constant;
b.rowKeys={'cost'};b.rowUnits={'USD'};b.sense={'objective'};b.objectiveSense='min';
b.variableKeys=[strrep(keys,'u/','p/'),keys,zk,strrep(keys,'u/','c/')];
b.variableUnits=[repmat({'MW'},1,n),repmat({'1'},1,2*n),repmat({'USD'},1,n)];
a(2)=b;
end
