function items=psaudit_hw5_repair_model_items(bundle,v,objective)
% Evaluate the very same matrix/bounds exported to Gurobi, including every row.
m=bundle.model;x=zeros(numel(m.obj),1);
x(bundle.map.p)=v.p(:);x(bundle.map.u)=v.u(:);x(bundle.map.z)=v.z(:);x(bundle.map.c)=v.c(:);
res=m.A*x-m.rhs;res(m.sense=='>')=-res(m.sense=='>');res(m.sense=='=')=abs(res(m.sense=='='));
items=relation('ACTIVE_ROWS',res,0,'le','native row units');
lo=isfinite(m.lb);hi=isfinite(m.ub);integer=m.vtype~='C';
items(end+1)=relation('ACTIVE_LOWER',x(lo),m.lb(lo),'ge','native variable units');
items(end+1)=relation('ACTIVE_UPPER',x(hi),m.ub(hi),'le','native variable units');
items(end+1)=relation('ACTIVE_INTEGER',x(integer),round(x(integer)),'eq','1');
items(end+1)=relation('OBJECTIVE',objective,m.obj'*x+m.objcon,'eq','USD');
end
function x=relation(id,a,e,sense,unit)
x=struct('id',id,'actual',a,'expected',e,'sense',sense,'unit',unit);
end
