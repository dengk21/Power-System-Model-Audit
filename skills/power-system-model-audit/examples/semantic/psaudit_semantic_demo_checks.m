function items=psaudit_semantic_demo_checks(p,v,objective)
% Independently reconstruct all physics and accounting, never use candidate A/obj.
assert(isfield(v,'p')&&isequal(size(v.p),[2 1]),'Missing full two-generator trajectory');
item=struct('id','BALANCE','actual',sum(v.p),'expected',p.demand,'sense','eq','unit','MW');
items=item;
item.id='DOMAIN';item.actual=v.p;item.expected=0;item.sense='ge';items(end+1)=item;
item.id='CHEAP_CAP';item.actual=v.p(1);item.expected=p.cheapCapacity;item.sense='le';items(end+1)=item;
item.id='BACKUP_CAP';item.actual=v.p(2);item.expected=p.backupCapacity;items(end+1)=item;
item.id='OBJECTIVE';item.actual=objective;item.expected=p.hours*(p.cheapCost*v.p(1)+p.backupCost*v.p(2));
item.sense='eq';item.unit='USD';items(end+1)=item;
end
