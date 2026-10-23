function s=psaudit_hw5_build_reference(hw5,model)
% Parameters from assignment/input files; no audited H or constraint objects.
models={'basicTask2_UC.m','basicTask2_UC_2variable.m','basicTask2_UC_starttime.m','basicTask2_UC_maxstart.m'};
assert(ismember(model,models),'Unsupported HW5 entry');
old=path; cleanup=onCleanup(@() path(old)); addpath(hw5,'-begin');
assert(strcmp(which('case39_UC'),fullfile(hw5,'case39_UC.m')),'Case shadowed');
mpc=feval('case39_UC'); data=load(fullfile(hw5,'load3996.mat'),'Pd');
s.N=size(mpc.bus,1); s.L=size(mpc.branch,1); s.I=size(mpc.gen,1); s.T=size(data.Pd,2);
assert(s.N==39 && s.L==46 && s.I==10 && s.T==96,'HW5 case changed');
assert(isequal(mpc.bus(:,1),(1:s.N)') && all(mpc.branch(:,10)==0),'Unsupported numbering/phase shift');
s.Pd=data.Pd; s.dt=0.25; s.genBus=mpc.gen(:,1); s.branchEnds=mpc.branch(:,1:2);
s.Pmin=mpc.gen(:,10); s.Pmax=mpc.gen(:,9);
s.b=mpc.gencost(:,6); s.Cstart=mpc.gencost(:,2); s.Cstop=mpc.gencost(:,3);
s.Ru=0.4*s.Pmax*s.dt; s.Rd=s.Ru;
sigma=0.3; if strcmp(model,models{4}), sigma=0.25; end
s.Su=sigma*s.Pmax; s.Sd=s.Su;
s.Lon=4; if strcmp(model,models{3}), s.Lon=1; end; s.Loff=s.Lon;
s.twoVariable=strcmp(model,models{2}); s.model=model;
s.C=sparse(s.genBus,(1:s.I)',1,s.N,s.I);
f=mpc.branch(:,1); t=mpc.branch(:,2); tap=mpc.branch(:,9); tap(tap==0)=1;
s.A=sparse([(1:s.L)';(1:s.L)'],[f;t],[ones(s.L,1);-ones(s.L,1)],s.L,s.N);
beta=mpc.branch(:,11)./(mpc.branch(:,4).*tap);
s.Bf=spdiags(beta,0,s.L,s.L)*s.A; s.B=s.A'*s.Bf;
s.slack=find(mpc.bus(:,2)==3); assert(isscalar(s.slack),'Expected one slack');
s.limit=mpc.branch(:,6); s.powerAbs=1e-5; s.costAbs=1e-4; s.domainAbs=1e-6; s.rel=1e-8;
s.specHash=psaudit_hash_file(fullfile(fileparts(mfilename('fullpath')),'math-spec.md'));
end
