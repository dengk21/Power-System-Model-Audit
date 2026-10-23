function out=psaudit_hw5_repair_reference(p)
% Independent sparse MIP, derived from the reviewed contract and branch data.
s=p.s;I=s.I;T=s.T;n=I*T;Z=sparse(n,n);E=speye(n);
np=1:n;nu=n+(1:n);nz=2*n+(1:n);nc=3*n+(1:n);
m=struct('A',sparse(0,4*n),'rhs',zeros(0,1),'sense',char(zeros(0,1)), ...
    'obj',[repmat(s.dt*s.b,T,1);zeros(2*n,1);ones(n,1)], ...
    'lb',[zeros(2*n,1);-ones(n,1);zeros(n,1)], ...
    'ub',[inf(n,1);ones(2*n,1);inf(n,1)], ...
    'vtype',[repmat('C',n,1);repmat('B',n,1);repmat('I',n,1);repmat('C',n,1)], ...
    'modelsense','min','objcon',0);
add([kron(speye(T),ones(1,I)),sparse(T,3*n)],sum(s.Pd,1)','=',T);
% Independent angle elimination from branch x/tap/status, never original H.
idx=setdiff(1:s.N,s.slack);H=zeros(s.L,s.N);H(:,idx)=s.Bf(:,idx)/s.B(idx,idx);
network=kron(speye(T),H*s.C);offset=H*s.Pd;
add([network,sparse(s.L*T,3*n)],repmat(s.limit,T,1)+offset(:),'<',s.L*T);
add([-network,sparse(s.L*T,3*n)],repmat(s.limit,T,1)-offset(:),'<',s.L*T);
add([E,-spdiags(repmat(s.Pmin,T,1),0,n,n),Z,Z],zeros(n,1),'>',n);
add([E,-spdiags(repmat(s.Pmax,T,1),0,n,n),Z,Z],zeros(n,1),'<',n);
previous=sparse(1:T,[T,1:T-1],1,T,T);D=speye(n)-kron(previous,speye(I));
add([Z,-D,E,Z],zeros(n,1),'=',n);
next=sparse(1:T,[2:T,1],1,T,T);dp=kron(next-speye(T),speye(I));
upper=dp;upper(end-I+1:end,:)=0;
add([upper,spdiags(repmat(s.Su-s.Ru,T,1),0,n,n),Z,Z],repmat(s.Su,T,1),'<',n);
add([-dp,spdiags(repmat(s.Sd-s.Rd,T,1),0,n,n)*kron(next,speye(I)),Z,Z],repmat(s.Sd,T,1),'<',n);
% Independently construct current-period-inclusive cyclic windows.
window=sparse(T,T);
for t=1:T
    window(mod(t-1+(0:s.Lon-1),T)+1,t)=1;
end
W=kron(window',speye(I));
add([Z,W,-s.Lon*E,Z],zeros(n,1),'>',n);
add([Z,-W,s.Loff*E,Z],-s.Loff*ones(n,1),'>',n);
add([Z,Z,-spdiags(repmat(s.Cstart,T,1),0,n,n),E],zeros(n,1),'>',n);
add([Z,Z,spdiags(repmat(s.Cstop,T,1),0,n,n),E],zeros(n,1),'>',n);
% Selector chooses a complete reference trajectory, never a candidate condition.
if ~isempty(p.referenceState)
    selected=isfinite(p.referenceState);fixed=n+(find(selected)-1)*I+p.selectorUnit;
    m.lb(fixed)=p.referenceState(selected);m.ub(fixed)=p.referenceState(selected);
end
out=struct('model',m,'map',struct('p',np(:),'u',nu(:),'z',nz(:),'c',nc(:)), ...
    'C',s.C,'H',H,'affine',psaudit_hw5_repair_affine(window,p,m.obj,0));
    function add(A,b,sense,count)
        assert(size(A,1)==count&&size(A,2)==4*n&&numel(b)==count,'Reference block shape');
        m.A=[m.A;A];m.rhs=[m.rhs;b(:)];m.sense=[m.sense;repmat(sense,count,1)];
    end
end
