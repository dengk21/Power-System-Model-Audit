function Ehat = psaudit_reconstruct_storage(E0,Pch,Pdis,etaC,etaD,dt,rho)
% E=MWh, P=MW, dt=h, rho=declared loss fraction per step.
assert(isnumeric(Pch) && isreal(Pch) && isnumeric(Pdis) && isreal(Pdis) && ...
    ndims(Pch)<=2 && isequal(size(Pch),size(Pdis)) && ~isempty(Pch),'Invalid power shapes');
[K,T]=size(Pch); E0=expand(E0,[K 1]); etaC=expand(etaC,[K T]); etaD=expand(etaD,[K T]);
dt=expand(dt,[K T]); rho=expand(rho,[K T]);
assert(all(isfinite(Pch(:))) && all(isfinite(Pdis(:))) && all(Pch(:)>=0) && all(Pdis(:)>=0),'Invalid power values');
assert(all(etaC(:)>0 & etaC(:)<=1) && all(etaD(:)>0 & etaD(:)<=1),'Invalid efficiencies');
assert(all(dt(:)>0) && all(rho(:)>=0 & rho(:)<1),'Invalid time/loss parameters');
Ehat=zeros(K,T+1); Ehat(:,1)=E0;
for t=1:T
    Ehat(:,t+1)=(1-rho(:,t)).*Ehat(:,t)+etaC(:,t).*Pch(:,t).*dt(:,t)-Pdis(:,t).*dt(:,t)./etaD(:,t);
end
end

function v=expand(v,shape)
assert(isnumeric(v) && isreal(v) && ~isempty(v) && all(isfinite(v(:))),'Invalid parameter');
if isscalar(v), v=v+zeros(shape); else, assert(isequal(size(v),shape),'Parameter must be scalar or exact shape'); end
end
