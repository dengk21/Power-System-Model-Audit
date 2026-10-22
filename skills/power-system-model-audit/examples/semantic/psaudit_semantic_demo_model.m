function output=psaudit_semantic_demo_model(p,variant,varargin)
% This numeric matrix is consumed BOTH by the solver and membership evaluation.
cap=p.cheapCapacity;cost=[p.cheapCost;p.backupCost]*p.hours;direction='min';
switch variant
    case 'correct'
    case 'loose',cap=p.backupCapacity;
    case 'tiny',cap=.999*p.demand;
    case 'cost',cost=2*cost;
    case 'tight',cap=.5*p.cheapCapacity;
    case 'maximize',direction='max';
    otherwise,error('Unknown variant');
end
model=struct('A',sparse([1 1]),'rhs',p.demand,'sense','=', ...
    'lb',[0;0],'ub',[cap;p.backupCapacity],'obj',cost,'modelsense',direction);
if isempty(varargin),output=model;return;end
v=varargin{1};objective=varargin{2};assert(isequal(size(v.p),[2 1]),'Missing complete trajectory');
item=struct('id','BALANCE','actual',model.A*v.p,'expected',model.rhs,'sense','eq','unit','MW');
items=item;item.id='DOMAIN';item.actual=v.p;item.expected=model.lb;item.sense='ge';items(end+1)=item;
item.id='CHEAP_CAP';item.actual=v.p(1);item.expected=model.ub(1);item.sense='le';items(end+1)=item;
item.id='BACKUP_CAP';item.actual=v.p(2);item.expected=model.ub(2);items(end+1)=item;
item.id='OBJECTIVE';item.actual=objective;item.expected=model.obj'*v.p;item.sense='eq';item.unit='USD';items(end+1)=item;
output=items;
end
