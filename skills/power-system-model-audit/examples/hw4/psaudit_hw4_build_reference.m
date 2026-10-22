function s = psaudit_hw4_build_reference(hw4, model, specPath)
% Independent fixed HW4 reference; never uses the audited H or limits.
models = {'basicTask1_ED_linear.m','basicTask1_ED_linear_seg.m', ...
    'basicTask1_ED_Quadratic.m','basicTask1_ED_Flow.m','basicTask1_ED_Ramp.m'};
assert(ismember(model,models),'Unsupported HW4 entry');
old = path; cleanup = onCleanup(@() path(old)); addpath(hw4,'-begin');
assert(strcmp(which('case39_ED'),fullfile(hw4,'case39_ED.m')), 'Case shadowed');
mpc = feval('case39_ED'); % MATLAB resolves the file, despite original name mismatch.
d = load(fullfile(hw4,'load3996.mat'),'Pd');
keep = ~ismember(mpc.gen(:,1),[30 32 33 35 37]);
g = mpc.gen(keep,:); cost = mpc.gencost(keep,5:7);
s.N = size(mpc.bus,1); s.L = size(mpc.branch,1); s.I = size(g,1);
s.T = size(d.Pd,2); s.dt = 0.25; s.Pd = d.Pd;
assert(s.N==39 && s.L==46 && s.I==6 && s.T==96,'Outside fixed HW4 scope');
assert(isequal(mpc.bus(:,1),(1:s.N)'),'Unsupported bus numbering');
assert(all(mpc.branch(:,10)==0) && all(mpc.branch(:,11)==1),'Unsupported shift/status');
assert(all(mpc.branch(:,4)>0),'Invalid branch X');
assert(isequal(size(s.Pd),[s.N s.T]) && all(isfinite(s.Pd(:))),'Invalid Pd');
s.genBus = g(:,1); s.branchEnds = mpc.branch(:,1:2);
s.Pmin = g(:,10); s.Pmax = g(:,9); s.cost = cost;
s.C = sparse(s.genBus,(1:s.I)',1,s.N,s.I);
alpha = 1; beta = 0.4;
if strcmp(model,models{4}), alpha=0.96; end
if strcmp(model,models{5}), beta=1; end
s.limit = alpha*mpc.branch(:,6); s.ramp = beta*s.Pmax*s.dt;
s.segmented = ~strcmp(model,models{1});
s.quad = ismember(model,models(3:5));
w = (s.Pmax-s.Pmin)/3;
s.segUpper = [s.Pmin+w,w,w]; s.segLower = [s.Pmin,zeros(s.I,2)];
x = [s.Pmin+w,s.Pmin+2*w,s.Pmax];
assert(all(s.segUpper(:)>0),'Invalid segment width');
if s.quad, y = cost(:,1).*x.^2 + cost(:,2).*x;
else, y = cost(:,2).*x; end
s.slopes = [y(:,1),diff(y,1,2)]./s.segUpper;
s.constant = 0; if s.quad, s.constant = sum(cost(:,3))*s.T*s.dt; end
f = mpc.branch(:,1); t = mpc.branch(:,2);
s.A = sparse([(1:s.L)';(1:s.L)'],[f;t],[ones(s.L,1);-ones(s.L,1)],s.L,s.N);
tap = mpc.branch(:,9); tap(tap==0)=1;
b = mpc.branch(:,11)./(mpc.branch(:,4).*tap);
s.Bf = spdiags(b,0,s.L,s.L)*s.A;
s.B = s.A'*s.Bf; s.slack = find(mpc.bus(:,2)==3);
assert(isscalar(s.slack),'Expected one slack');
s.Bstar = s.B; s.Bstar(s.slack,s.slack)=0;
s.powerAbs=1e-5; s.costAbs=1e-4; s.rel=1e-8;
s.model=model; s.specPath=specPath; s.specHash=psaudit_hash_file(specPath);
% Confirmation is external provenance; script defaults to draft.
s.confirmed=false;
end
