function [F,theta,B,Bf,A]=psaudit_dc_network(mpc,P)
% Independently rebuild branch-level DC equations; MW input/output, rad angle.
N=size(mpc.bus,1); L=size(mpc.branch,1); T=size(P,2);
assert(isequal(size(P),[N T]) && all(isfinite(P),'all'),'Invalid injections');
[ok,f]=ismember(mpc.branch(:,1),mpc.bus(:,1)); assert(all(ok));
[ok,t]=ismember(mpc.branch(:,2),mpc.bus(:,1)); assert(all(ok));
tap=mpc.branch(:,9); tap(tap==0)=1;
active=mpc.branch(:,11)~=0;assert(all(mpc.branch(active,4)~=0),'Active zero-reactance branch unsupported');
beta=zeros(L,1);beta(active)=mpc.branch(active,11)./(mpc.branch(active,4).*tap(active));
A=sparse([(1:L)';(1:L)'],[f;t],[ones(L,1);-ones(L,1)],L,N);
Bf=spdiags(beta,0,L,L)*A; B=A'*Bf;
shiftFlow=-beta.*deg2rad(mpc.branch(:,10));
ref=find(mpc.bus(:,2)==3); assert(isscalar(ref),'Single connected slack required');
idx=setdiff(1:N,ref); theta=zeros(N,T);
theta(idx,:)=B(idx,idx)\(P(idx,:)/mpc.baseMVA-A(:,idx)'*shiftFlow);
F=mpc.baseMVA*(Bf*theta+shiftFlow);
end
