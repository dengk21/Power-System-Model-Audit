function checks = psaudit_hw4_check_solution(r,s)
% Fixed independent residual engine. No YALMIP/MATPOWER/solver calls.
checks = psaudit_check_relations(struct([]));
if ~isfield(r,'hasSolution') || ~isequal(r.hasSolution,true)
    missing('DATA','No usable solution'); return
end
if ~valid('p',[s.I s.T]), missing('DATA','Missing/nonfinite/wrong-sized p'); return; end
p=r.p; z=s.C*p-s.Pd;
add('C_BAL',sum(p,1),sum(s.Pd,1),'MW',s.powerAbs,false, ...
    max(sum(abs(p),1),sum(abs(s.Pd),1)));
add('C_GEN_LOW',p,s.Pmin+zeros(1,s.T),'MW',s.powerAbs,'lower');
add('C_GEN_HIGH',p,s.Pmax+zeros(1,s.T),'MW',s.powerAbs,'upper');
dp=diff(p,1,2); bound=s.ramp+zeros(1,s.T-1);
add('C_RAMP_UP',dp,bound,'MW/step',s.powerAbs,'upper');
add('C_RAMP_DOWN',dp,-bound,'MW/step',s.powerAbs,'lower');
if valid('Pg',[s.N s.T]), add('C_MAP_G',r.Pg,s.C*p,'MW',s.powerAbs,false);
else, missing('C_MAP_G','Pg unavailable'); end
if valid('Pic',[s.N s.T]), add('C_MAP_Z',r.Pic,z,'MW',s.powerAbs,false);
else, missing('C_MAP_Z','Pic unavailable'); end
% Every branch and time is reconstructed even if audited F is missing.
F=s.Bf*(s.Bstar\z);
add('C_FLOW_REF_LOW',F,-s.limit+zeros(1,s.T),'MW',s.powerAbs,'lower');
add('C_FLOW_REF_HIGH',F,s.limit+zeros(1,s.T),'MW',s.powerAbs,'upper');
if valid('F',[s.L s.T])
    add('C_NET_F',r.F,F,'MW',s.powerAbs,false);
    add('C_NET_KCL',s.A'*r.F,z,'MW',s.powerAbs,false);
    add('C_FLOW_LOW',r.F,-s.limit+zeros(1,s.T),'MW',s.powerAbs,'lower');
    add('C_FLOW_HIGH',r.F,s.limit+zeros(1,s.T),'MW',s.powerAbs,'upper');
else, missing('C_NET_F','Audited branch powers unavailable; only reconstructed limits checked'); end
% Cross-check the diagonal-zero representation against a fixed-slack solve.
idx=setdiff(1:s.N,s.slack); theta=zeros(s.N,s.T);
theta(idx,:)=s.B(idx,idx)\z(idx,:);
add('C_NET_EQUIV',F,s.Bf*theta,'MW',s.powerAbs,false);
if s.segmented
    if ~valid('q',[s.I 3 s.T]), missing('C_SEG','q missing/nonfinite/wrong-sized'); return; end
    add('C_SEG_SUM',reshape(sum(r.q,2),s.I,s.T),p,'MW',s.powerAbs,false);
    add('C_SEG_LOW',r.q,repmat(s.segLower,1,1,s.T),'MW',s.powerAbs,'lower');
    add('C_SEG_HIGH',r.q,repmat(s.segUpper,1,1,s.T),'MW',s.powerAbs,'upper');
    expectedCost=s.dt*sum(r.q.*repmat(s.slopes,1,1,s.T),'all')+s.constant;
else
    expectedCost=s.dt*sum(p.*s.cost(:,2),'all');
end
if valid('objective',[1 1]), add('O_COST',r.objective,expectedCost,'USD',s.costAbs,false);
else, missing('O_COST','Objective unavailable'); end

    function ok=valid(field,shape)
        ok=isfield(r,field) && isnumeric(r.(field)) && isreal(r.(field));
        if ~ok, return; end
        v=r.(field); actualShape=size(v); actualShape(end+1:numel(shape))=1;
        ok=isequal(actualShape,shape) && all(isfinite(v(:)));
    end
    function missing(id,why)
        checks(end+1)=struct('id',id,'status','DATA_INSUFFICIENT', ...
            'maxResidual',NaN,'positionResidual',NaN,'tolerance',NaN,'count',0,'position','n/a', ...
            'actual',NaN,'expected',NaN,'unit','n/a','detail',why);
    end
    function add(id,a,e,unit,absTol,side,scale)
        if nargin<7, scale=max(abs(a),abs(e)); end
        sense='eq';
        if isequal(side,'lower'), sense='ge'; elseif isequal(side,'upper'), sense='le'; end
        item=struct('id',id,'actual',a,'expected',e,'unit',unit, ...
            'absTol',absTol,'relTol',s.rel,'scale',scale,'sense',sense);
        checks(end+1)=psaudit_check_relations(item);
    end
end
