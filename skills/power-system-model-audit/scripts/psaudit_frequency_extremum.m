function [drop,tm,steady,rocof]=psaudit_frequency_extremum(M,D,K,TG,deficit,FR)
% First nadir from the two-state ODE, with correct quadrant and damping cases.
if nargin<6,FR=0;end
assert(isequal(size(M),size(D),size(K),size(TG)) && isscalar(deficit) && deficit>0 && isscalar(FR) && FR>=0 && FR<=1);
assert(all(M>0 & D>=0 & K>=0 & TG>0,'all'));
drop=zeros(size(M)); tm=drop; steady=deficit./(D+K); rocof=deficit./M;
for k=1:numel(M)
    A=[-D(k)/M(k),-1/M(k);K(k)/TG(k)-K(k)*FR*D(k)/M(k),-1/TG(k)-K(k)*FR/M(k)]; B=[1/M(k);K(k)*FR/M(k)];
    xss=-A\(-deficit*B); alpha=-trace(A)/2; wd2=det(A)-alpha^2;
    if wd2>1e-14
        wd=sqrt(wd2); C=-xss(1); E=(-deficit/M(k)+alpha*C)/wd;
        c0=-alpha*C+wd*E; s0=-alpha*E-wd*C;
        angle=atan2(-c0,s0); if angle<=0,angle=angle+pi;end
        time=angle/wd;
    else
        % Stable nonoscillatory dynamics: bracket actual derivative sign changes.
        grid=[0 logspace(-5,5,300)]; derivative=arrayfun(@(t)[1 0]*A*expm(A*t)*(-xss),grid);
        j=find(derivative(1:end-1)<0 & derivative(2:end)>=0,1);
        if isempty(j), time=Inf; else, time=fzero(@(t)[1 0]*A*expm(A*t)*(-xss),grid(j:j+1));end
    end
    tm(k)=time;
    if isinf(time),drop(k)=-xss(1);else,x=xss-expm(A*time)*xss;drop(k)=-x(1);end
end
end
