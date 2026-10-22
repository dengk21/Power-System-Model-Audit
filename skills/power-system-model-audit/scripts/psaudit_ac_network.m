function [S,Sf,St,Y]=psaudit_ac_network(mpc,V)
% Independent pi branches, complex taps/shift, charging and bus shunts.
N=size(mpc.bus,1); L=size(mpc.branch,1); assert(isequal(size(V),[N 1]));
[ok,f]=ismember(mpc.branch(:,1),mpc.bus(:,1)); assert(all(ok));
[ok,t]=ismember(mpc.branch(:,2),mpc.bus(:,1)); assert(all(ok));
state=mpc.branch(:,11); impedance=mpc.branch(:,3)+1i*mpc.branch(:,4);
active=state~=0;assert(all(impedance(active)~=0),'Active zero-impedance branches need a different network treatment');
y=zeros(L,1);y(active)=state(active)./impedance(active);
b=1i*state.*mpc.branch(:,5)/2;
tap=mpc.branch(:,9); tap(tap==0)=1; tap=tap.*exp(1i*deg2rad(mpc.branch(:,10)));
yff=(y+b)./(tap.*conj(tap)); ytt=y+b; yft=-y./conj(tap); ytf=-y./tap;
Y=sparse([f;f;t;t],[f;t;f;t],[yff;yft;ytf;ytt],N,N);
Y=Y+spdiags((mpc.bus(:,5)+1i*mpc.bus(:,6))/mpc.baseMVA,0,N,N);
S=mpc.baseMVA*V.*conj(Y*V);
Sf=mpc.baseMVA*V(f).*conj(yff.*V(f)+yft.*V(t));
St=mpc.baseMVA*V(t).*conj(ytf.*V(f)+ytt.*V(t));
end
