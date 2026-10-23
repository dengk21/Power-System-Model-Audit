function [audit,run]=psaudit_course_validate(project,outdir,options)
% Replay is strictly read-only computation: no optimize or runpf callbacks.
if nargin<3,options=struct;end
if ~isfield(options,'mode'),options.mode='replay';end
assert(ismember(options.mode,{'replay','diagnose'}),'Capture uses psaudit_course_capture');
if ~isfield(options,'budget'),options.budget=struct;end
context=psaudit_execution_context(options.mode,options.budget);
if ~isfield(options,'evidenceDirectory'),options.evidenceDirectory=outdir;end
if ~isfield(options,'diagnosticDirectory'),options.diagnosticDirectory=fullfile(outdir,'diagnostics');end
evidenceDirectory=options.evidenceDirectory;
files=[dir(fullfile(evidenceDirectory,'results','*.mat'));dir(fullfile(evidenceDirectory,'rerun-results','*.mat'));dir(fullfile(evidenceDirectory,'diagnostic-results','*.mat'))];
% Select archived/re-captured versions before checking, so obsolete partial
% captures do not create misleading current CHECKER_FAILURE console output.
keys=cell(1,numel(files));
for k=1:numel(files)
    metadata=load(fullfile(files(k).folder,files(k).name),'r');keys{k}=metadata.r.relative;
    if isfield(metadata.r,'config')&&isfield(metadata.r.config,'reuseFitFile'),keys{k}=[keys{k} ' [UC-only diagnostic]'];end
end
keep=false(size(keys));for k=1:numel(keys),keep(k)=~any(strcmp(keys(k+1:end),keys{k}));end
files=files(keep);
audit=struct('relative',{},'resultFile',{},'resultHash',{},'r',{},'checks',{},'details',{},'checkerError',{});
for k=1:numel(files)
    file=fullfile(files(k).folder,files(k).name); z=load(file,'r'); r=z.r;
    source=fullfile(project,'电力系统分析与控制作业',r.relative);
    assert(strcmp(r.sourceHash,psaudit_hash_file(source)),'Source changed: %s',r.relative);
    assert(strcmp(r.specHash,psaudit_hash_file(fullfile(fileparts(mfilename('fullpath')),'math-spec.md'))),'Reference changed');
    for j=1:numel(r.inputs)
        assert(strcmp(r.inputs(j).hash,psaudit_hash_file(fullfile(r.sourceDirectory,r.inputs(j).name))),'Input changed: %s',r.inputs(j).name);
    end
    if isfield(r,'runtimeInputs')&&isfield(r,'config')
        for j=1:numel(r.runtimeInputs),assert(strcmp(r.runtimeInputs(j).hash,psaudit_hash_file(fullfile(r.config.executionDirectory,r.runtimeInputs(j).name))),'Runtime input changed');end
    end
    c=psaudit_check_relations(struct([]));d=struct;err='';
    try, [c,d]=inspect(r,project,file,options,context); catch e,err=getReport(e,'extended','hyperlinks','off');c=missing('CHECKER_FAILURE',e.message);end
    key=r.relative;if isfield(r,'config')&&isfield(r.config,'reuseFitFile'),key=[key ' [UC-only diagnostic]'];end
    item=struct('relative',key,'resultFile',file,'resultHash',psaudit_hash_file(file),'r',r,'checks',c,'details',d,'checkerError',err);
    j=find(strcmp({audit.relative},key)); if isempty(j),audit(end+1)=item;else,audit(j)=item;end
    fprintf('COURSE_CHECK %s: %d PASS / %d VIOLATION / %d DATA; checker=%s\n',r.relative,sum(strcmp({c.status},'PASS')),sum(strcmp({c.status},'VIOLATION')),sum(strcmp({c.status},'DATA_INSUFFICIENT')),err);
    for j=find(strcmp({c.status},'VIOLATION')),x=c(j);fprintf(' %s bad=%d residual=%.9g actual=%.9g expected=%.9g at=%s\n',x.id,x.count,x.positionResidual,x.actual,x.expected,x.position);end
end
run=context.snapshot();run.evidenceDirectory=evidenceDirectory;run.diagnosticDirectory=options.diagnosticDirectory;
run.originalSolveCount=0;
if ~isfolder(outdir),mkdir(outdir);end
save(fullfile(outdir,'validation.mat'),'audit','run','-v7');
writeEvidence(audit,fullfile(outdir,'numerical-evidence.md'));
end

function [c,d]=inspect(r,project,resultFile,options,context)
c=psaudit_check_relations(struct([]));d=struct;v=r.vars;rel=r.relative;
if startsWith(rel,'HW1/')||startsWith(rel,'HW2/')||startsWith(rel,'HW3/')||startsWith(rel,'HW8/')
    results=r.pfRuns;
    for fn={'res','res1','res2'},if isfield(v,fn{1}),results{end+1}=v.(fn{1});end;end
    if startsWith(rel,'HW8/'),results={struct('baseMVA',v.MVAbase,'bus',v.bus,'gen',v.gen,'branch',v.branch,'success',v.success)};end
    for j=1:numel(results)
        x=results{j};d.pfSuccess(j)=x.success;
        if ~x.success,c=[c missing(sprintf('PF%d_NO_CONVERGENCE',j),'Source reports no convergence; not a valid power-flow solution')];continue;end
        V=x.bus(:,8).*exp(1i*deg2rad(x.bus(:,9)));[S,Sf,St]=psaudit_ac_network(x,V);
        [~,gb]=ismember(x.gen(:,1),x.bus(:,1));online=x.gen(:,8)>0;
        injection=sparse(gb(online),1,x.gen(online,2)+1i*x.gen(online,3),size(x.bus,1),1)-x.bus(:,3)-1i*x.bus(:,4);
        append(sprintf('PF%d_P_BAL',j),real(injection),real(S),'eq','MW',1e-5);
        append(sprintf('PF%d_Q_BAL',j),imag(injection),imag(S),'eq','Mvar',1e-5);
        append(sprintf('PF%d_FROM_P',j),x.branch(:,14),real(Sf),'eq','MW',1e-5);
        append(sprintf('PF%d_FROM_Q',j),x.branch(:,15),imag(Sf),'eq','Mvar',1e-5);
        append(sprintf('PF%d_TO_P',j),x.branch(:,16),real(St),'eq','MW',1e-5);
        append(sprintf('PF%d_TO_Q',j),x.branch(:,17),imag(St),'eq','Mvar',1e-5);
        losses=sum(real(Sf+St))+sum(x.bus(:,5).*abs(V).^2);
        append(sprintf('PF%d_TOTAL_P',j),sum(x.gen(online,2))-sum(x.bus(:,3)),losses,'eq','MW',1e-5);
        d.losses(j)=losses;d.generation(j)=sum(x.gen(online,2));
    end
    if strcmp(rel,'HW1/test.m')
        append('HW1_I_BASE_LOW_TEXT',9524,100e6/(sqrt(3)*10.5e3),'eq','A',0.5);
        append('HW1_I_BASE_HIGH_TEXT',477.1,100e6/(sqrt(3)*121e3),'eq','A',.1);
        append('HW1_BUS6_TYPE_INPUT',v.mpc.bus(6,2),1,'eq','bus type',0);
        expected=[25*.131 25*.4 25*2.98e-6;50*.131 50*.4 50*2.98e-6;45*.105 45*.393 45*3.04e-6;30*.131 30*.4 30*2.98e-6;35*.105 35*.393 35*3.04e-6;20*.131 20*.4 20*2.98e-6];
        zb=121^2/100;expected(:,1:2)=expected(:,1:2)/zb;expected(:,3)=expected(:,3)*zb;
        append('HW1_LINE_PARAMETERS',v.mpc.branch(1:6,3:5),expected,'eq','p.u.',5e-5);
        d.slackPower=results{1}.gen(end,2:3);
    end
    if startsWith(rel,'HW3/')
        m=loadcase('case57'); P=net(m);[~,th,B]=psaudit_dc_network(m,P);idx=find(m.bus(:,2)~=3);
        if isfield(v,'BusTheta'),append('HW3_DC_ANGLE',v.BusTheta,rad2deg(th),'eq','degrees',1e-8);end
        if isfield(v,'Bbus')&&isequal(size(v.Bbus),size(B(idx,idx))),append('HW3_B_MATRIX',v.Bbus,full(B(idx,idx)),'eq','p.u.',1e-10);end
        if strcmp(rel,'HW3/HW3_2.m')
            ell=find((m.branch(:,1)==9&m.branch(:,2)==13)|(m.branch(:,1)==13&m.branch(:,2)==9));assert(isscalar(ell));
            q=zeros(size(P));q(8)=1;q(m.bus(:,2)==3)=-1;F=psaudit_dc_network(m,q);
            append('HW3_PTDF_REFERENCE',full(v.analytic),F(ell),'eq','MW/MW',1e-8);
            d.acPerturbation=full(v.Perturbation);d.dcSensitivity=F(ell);d.approximationDifference=full(v.Perturbation)-F(ell);
        elseif strcmp(rel,'HW3/HW3_3.m')
            [~,~,~,Y]=psaudit_ac_network(m,ones(size(m.bus,1),1));dd=find(m.bus(:,2)==1);gg=find(m.bus(:,2)==2);
            ref=-imag(Y(dd,dd))\imag(Y(dd,gg));append('HW3_QV_APPROX_MATRIX',v.sensitivity_1,full(ref),'eq','p.u./p.u.',1e-9);
            pure=m;pure.gen([2 3 4],6)=pure.gen([2 3 4],6)+.01;
            [probe,status,detail]=diagnostic('voltage_only',@(seconds)voltageprobe(pure,v,dd,seconds));
            d.voltageDiagnostic=struct('status',status,'detail',detail);
            if ~isempty(probe)&&probe.success
                d.pureVoltageResponse=probe.response;d.originalResponse=v.err_2;
                d.pureApproxError=probe.approxError;d.originalApproxError=v.maxError;
                append('D_VOLTAGE_ONLY_DIAGNOSTIC',double(probe.success),1,'eq','boolean',0);
            else,c=[c missing('D_VOLTAGE_ONLY_DIAGNOSTIC',detail)];end
            append('HW3_UNINTENDED_LOAD_CHANGE',v.res2.bus(:,3),v.res1.bus(:,3),'eq','MW',1e-9);
        end
    end
    if endsWith(rel,'DynamicPowerFlow.m')
        increment=v.gen(:,2)-v.mpc.gen(:,2);append('HW8_EQUAL_SHARING',increment,mean(increment),'eq','MW',1e-5);
        d.increment=increment;d.paths=r.paths;
    end
elseif startsWith(rel,'HW6/')||startsWith(rel,'HW7/')||startsWith(rel,'HW10/')
    if strcmp(rel,'HW6/test.m'),append('HW6_NORMAL_QUANTILE',v.x,20*(-sqrt(2)*erfcinv(2*.05)),'eq','MW',1e-9);return;end
    if strcmp(rel,'HW7/test.m'),d.note='辅助绘图/数据脚本，无独立求解模型';return;end
    folder=extractBefore(rel,'/'); caseName='case39_UC';if strcmp(folder,'HW10'),caseName='case39_FCUC';end
    m=localcase(fullfile(project,'电力系统分析与控制作业',folder),caseName); raw=load(fullfile(project,'电力系统分析与控制作业',folder,'load3996.mat'),'Pd');Pd=raw.Pd;
    s=struct('Pmin',m.gen(:,10),'Pmax',m.gen(:,9),'Ru',.4*m.gen(:,9)*.25,'Rd',.4*m.gen(:,9)*.25,'Su',.3*m.gen(:,9),'Sd',.3*m.gen(:,9),'Lon',4,'Loff',4);
    if strcmp(folder,'HW10'),s.Ru=.25*s.Pmax;s.Rd=s.Ru;s.Su=.5*s.Pmax;s.Sd=s.Su;end
    C=sparse(m.gen(:,1),(1:size(m.gen,1))',1,size(m.bus,1),size(m.gen,1));
    if strcmp(folder,'HW6')
        if ~usable(v,'result'),c=missing('NO_UC_INCUMBENT','No usable source solver status');return;end
        q=v.var;scenarios=size(q.Pb,3);costs=zeros(1,scenarios);used=zeros(size(m.bus,1),size(Pd,2),scenarios);
        for j=1:scenarios
            thermal=q.Pb(:,:,j);state=q.U(:,:,j);events=checkUC(thermal,state,q.Ustart(:,:,j),q.Ushut(:,:,j),s,sprintf('S%d_',j));
            z=q.Pic(:,:,j);wind=z-C*thermal+Pd;used(:,:,j)=wind;
            network(z,[],sprintf('S%d_',j));append(sprintf('S%d_WIND_LOW',j),wind,0,'ge','MW',1e-5);
            cap=zeros(size(Pd));if isfield(v,'PwindQuantile'),cap(30,:)=reshape(v.Pwind+v.PwindQuantile,1,[]);else,cap(30,:)=v.Pwind(:,j)';end
            append(sprintf('S%d_WIND_HIGH',j),wind,cap,'le','MW',1e-5);
            costs(j)=.25*sum(m.gencost(:,6).*thermal,'all')+sum(m.gencost(:,2).*q.Ustart(:,:,j)+m.gencost(:,3).*q.Ushut(:,:,j),'all');
            d.eventCounts(j,:)=[sum(events.start,'all') sum(events.stop,'all')];
        end
        append('HW6_EXPECTED_COST',v.obj,mean(costs),'eq','USD',1e-4);d.scenarioCosts=costs;d.usedWind=used;
        if scenarios>1,d.sharedStateDifferences=sum(any(q.U~=q.U(:,:,1),3),'all');end
        if isfield(v,'PwindQuantile')
            alpha=1-.95^(1/96);refq=-sqrt(2)*erfcinv(2*alpha)*.05*v.Pwind;
            append('HW6_LOWER_QUANTILE',v.PwindQuantile,refq,'eq','MW',1e-9);
            demand=max(sum(Pd,1)-sum(q.Pb,1),0);meanwind=reshape(v.Pwind,1,[]);sigma=.05*meanwind;
            probs=ones(size(meanwind));nz=sigma>0;probs(nz)=.5*erfc((demand(nz)-meanwind(nz))./(sqrt(2)*sigma(nz)));
            probs(~nz)=double(demand(~nz)<=meanwind(~nz));append('HW6_DAILY_PROBABILITY',prod(probs),.95,'ge','probability',1e-9);d.marginalProbability=probs;
        end
    elseif strcmp(folder,'HW7')
        if isfield(v,'ahead')&&usable(v,'result_ahead')&&all(isfinite(v.ahead.Pb),'all')
            q=v.ahead;p=reshape(q.Pb,10,96);u=reshape(q.U,10,96);vv=reshape(q.Ustart,10,96);ww=reshape(q.Ushut,10,96);
            checkUC(p,u,vv,ww,s,'MP_');w=reshape(q.Pwind,1,96);z=C*p-Pd;z(30,:)=z(30,:)+w;network(z,[],'MP_');
            append('MP_WIND_NONNEGATIVE',w,0,'ge','MW',1e-5);d.aheadEventCost=sum(m.gencost(:,2).*vv+m.gencost(:,3).*ww,'all');
            d.aheadGenerationCost=.25*sum(m.gencost(:,6).*p,'all');d.aheadObjective=v.obj_ahead;
            if isfield(v,'LB'),d.LB=v.LB;end;if isfield(v,'UB'),d.UB=v.UB;end;if isfield(v,'iteration'),d.iterations=v.iteration;end
            if isfield(v,'LB')&&isfield(v,'UB')&&isfinite(v.LB)&&isfinite(v.UB),append('CCG_BOUND_ORDER',v.LB,v.UB,'le','USD',1e-4);end
        elseif isfield(v,'ahead')||contains(rel,'Task4_')||contains(rel,'/MP'),c=[c missing('MP_NO_INCUMBENT','No usable first-stage state/power')];end
        if isfield(v,'intra')&&isfield(v.intra,'Pb')&&isfield(v.intra,'Pwind')&&usable(v,'result_intra') ...
                && all(isfinite(v.intra.Pb),'all')&&all(isfinite(v.intra.Pwind),'all')
            pp=reshape(v.intra.Pb,10,96);uu=reshape(v.U,10,96);wwind=reshape(v.intra.Pwind,1,96);
            checkUC(pp,uu,[],[],s,'SP_');zz=C*pp-Pd;zz(30,:)=zz(30,:)+wwind;network(zz,[],'SP_');
            forecast=readmatrix(fullfile(project,'电力系统分析与控制作业','HW7','Pwind.csv'));forecast=forecast(:,2)';
            append('SP_WIND_NONNEGATIVE',wwind,0,'ge','MW',1e-5);
            if isfield(v.intra,'Pwindmax')&&all(isfinite(v.intra.Pwindmax),'all')
                available=reshape(v.intra.Pwindmax,1,96);
                append('SP_BOX_LOW',available,.8*forecast,'ge','MW',1e-5);append('SP_BOX_HIGH',available,1.2*forecast,'le','MW',1e-5);
            else,available=1.2*forecast;end
            append('SP_WIND_AVAILABLE',wwind,available,'le','MW',1e-5);
            expected=.25*sum(m.gencost(:,6).*pp,'all');if endsWith(rel,'Task4_CandCG.m'),expected=-expected;end
            append('SP_DECLARED_OBJECTIVE',v.obj_intra,expected,'eq','USD',1e-4);d.intraGenerationCost=abs(expected);
        end
        if (endsWith(rel,'CandCG_column.m')||endsWith(rel,'SP_getbase.m'))&&usable(v,'result_intra')&&isfield(v,'intra')&&all(isfinite(v.intra.Pi),'all')
            u=reshape(v.U,10,96);weather=reshape(v.intra.Pwindmax,1,96);piV=v.intra.Pi;
            forecast=readmatrix(fullfile(project,'电力系统分析与控制作业','HW7','Pwind.csv'));forecast=forecast(:,2)';
            append('SP_BOX_LOW',weather,.8*forecast,'ge','MW',1e-5);append('SP_BOX_HIGH',weather,1.2*forecast,'le','MW',1e-5);
            [gradient,dualCost]=dualreference(m,Pd,u,weather,piV,s);
            target=[repmat(m.gencost(:,6)*.25,96,1);-.1*.25*ones(39*96,1)];
            append('SP_DUAL_NONNEGATIVE',piV,0,'ge','USD/MW',1e-6);append('SP_DUAL_FEASIBLE',gradient,target,'le','USD/MW',1e-6);
            append('SP_DUAL_OBJECTIVE',-v.obj_intra,dualCost,'eq','USD',1e-4);d.dualCost=dualCost;d.weather=weather;d.u=u;
            [probe,status,detail]=diagnostic('primal',@(seconds)primalreference(m,Pd,u,weather,s,seconds));
            d.primalDiagnostic=struct('status',status,'detail',detail);
            if ~isempty(probe),d.primalProbe=probe;d.probeFile=detail;end
            if ~isempty(probe)&&probe.problem==0&&isfinite(probe.objective)
                append('SP_PRIMAL_DUAL_GAP',dualCost,probe.objective,'eq','USD',1e-4);
            else,c=[c missing('SP_PRIMAL_DUAL_GAP',detail)];end
        elseif isfield(v,'result_intra'),d.intraStatus=v.result_intra.problem;end
    elseif strcmp(folder,'HW10')
        if isfield(v,'var')&&usable(v,'result')&&all(isfinite(v.var.Pb),'all')&&all(isfinite(v.var.U),'all')
            p=v.var.Pb;u=v.var.U;events=checkUC(p,u,v.var.Ustart,v.var.Ushut,s,'UC_');
            z=C*p-Pd;network(z,[],'UC_');J=.25*sum(m.gencost(:,6).*p,'all')+sum(m.gencost(:,2).*v.var.Ustart+m.gencost(:,3).*v.var.Ushut,'all');
            append('UC_OBJECTIVE',v.obj,J,'eq','USD',1e-4);d.objective=v.obj;d.eventCost=sum(m.gencost(:,2).*events.start+m.gencost(:,3).*events.stop,'all');
            frequency(u,p,rel);
        elseif isfield(v,'P_gen')&&isfield(v,'U')&&isfield(v,'parameter')&&all(isfinite(v.P_gen),'all')&&all(isfinite(v.U),'all')
            p=v.P_gen;u=v.U; s.Ru=.1*s.Pmax;s.Rd=s.Ru;s.Su=1.05*s.Pmin;s.Sd=s.Su;s.Lon=16;s.Loff=16;s.cyclicState=false;
            checkUC(p,u,[],[],s,'AUX_');network(C*p-Pd,[],'AUX_');frequency(u,p,rel);
        elseif isfield(v,'Pg')&&isfield(v,'Xgen')&&all(isfinite(v.Pg),'all')&&all(isfinite(v.Xgen),'all')
            p=v.Pg;u=v.Xgen;s.Ru=.1*s.Pmax;s.Rd=s.Ru;s.Su=1.2*s.Pmin;s.Sd=s.Su;
            checkUC(p,u,[],[],s,'AUX_');network(C*p-Pd,[],'AUX_');frequency(u,p,rel);
        elseif endsWith(rel,'/test.m')
            if ~isfield(r,'lastSolverResult'),c=[c missing('FIT_SOLVER_STATUS_MISSING','Fit-only helper: original capture did not retain a solver status; no UC model is expected')];end
        else,c=[c missing('UC_NO_INCUMBENT','Source did not reach UC solve or has no usable active p/u')];end
        if isfield(v,'linear')&&isfield(v.linear,'U')
            states=v.linear.U;M=states*(m.gen(:,9).*[15;14;13;13;15;15;10;9;9;15])/sum(m.gen(:,9));DD=states*(m.gen(:,9).*[2.7;2.9;2.1;2.5;2.7;2.6;2.4;2.8;2.2;2.6])/sum(m.gen(:,9));KK=states*(m.gen(:,9).*[15;16;22;21;20;28;23;17;18;21])/sum(m.gen(:,9));
            [truth,tm]=psaudit_frequency_extremum(M,DD,KK,12*ones(size(M)),500/sum(m.gen(:,9)));
            cached=isfield(r,'config')&&isfield(r.config,'reuseFitFile');
            if isfield(v,'IdealDeltaF'),append('FIT_IDEAL_LABEL',v.IdealDeltaF,truth,'eq','p.u. frequency',1e-8);end
            d.fitCount=size(states,1);d.fitTmMin=min(tm);
            if isfield(v.linear,'coefficientsValue'),coef=v.linear.coefficientsValue;elseif isfield(v.linear,'coefficients'),coef=v.linear.coefficients;else,coef=[];end
            if ~isempty(coef)&&all(isfinite(coef),'all')
                pred=max([M DD KK ones(size(M))]*coef,[],2);append('FIT_CONSERVATIVE_ENVELOPE',pred,truth,'ge','p.u. frequency',1e-6);d.fitUnderestimate=max(truth-pred);d.fitOverestimate=max(pred-truth);
                if ~cached&&isfield(v.linear,'choosePlane'),append('FIT_SELECTION_BINARY',v.linear.choosePlane,round(v.linear.choosePlane),'eq','binary',1e-6);d.fitSelectionDeviation=max(abs(v.linear.choosePlane-round(v.linear.choosePlane)),[],'all');end
                if ~cached&&isfield(v.linear,'DeltaF'),append('FIT_MAX_ENVELOPE',v.linear.DeltaF,pred,'eq','p.u. frequency',1e-6);end
            end
            if isfield(v,'mdl')
                coef=v.mdl.Beta;bias=v.mdl.Bias;pred=[DD KK M ones(size(M))]*coef+bias;
                append('SVR_FEATURE_MAPPING',DD*coef(1)+M*coef(2)+KK*coef(3)+bias,pred,'eq','p.u. frequency',1e-8);
                append('SVR_TRAINING_CONSERVATIVE',pred,truth,'ge','p.u. frequency',1e-6);d.svrUnderestimate=max(truth-pred);d.svrCoefficients=coef;
            end
        elseif isfield(v,'ratio_mu')&&all(isfinite(v.ratio_mu),'all')&&isfield(v,'Xgen_all')
            states=v.Xgen_all;M=states*(m.gen(:,9).*[15;14;13;13;15;15;10;9;9;15])/sum(m.gen(:,9));DD=states*(m.gen(:,9).*[2.7;2.9;2.1;2.5;2.7;2.6;2.4;2.8;2.2;2.6])/sum(m.gen(:,9));KK=states*(m.gen(:,9).*[15;16;22;21;20;28;23;17;18;21])/sum(m.gen(:,9));
            truth=psaudit_frequency_extremum(M,DD,KK,12*ones(size(M)),500/sum(m.gen(:,9)));
            pred=max([DD KK M ones(size(M))]*v.ratio_mu,[],2);append('AUX_FIT_CONSERVATIVE',pred,truth,'ge','p.u. frequency',1e-6);d.fitUnderestimate=max(truth-pred);
        elseif isfield(v,'parameter')&&isfield(v,'U_all')&&all(isfinite(v.parameter),'all')
            states=v.U_all;M=states*(m.gen(:,9).*[15;14;13;13;15;15;10;9;9;15])/sum(m.gen(:,9));DD=states*(m.gen(:,9).*[2.7;2.9;2.1;2.5;2.7;2.6;2.4;2.8;2.2;2.6])/sum(m.gen(:,9));KK=states*(m.gen(:,9).*[15;16;22;21;20;28;23;17;18;21])/sum(m.gen(:,9));
            truth=psaudit_frequency_extremum(M,DD,KK,12*ones(size(M)),500/sum(m.gen(:,9)));
            pred=max([DD KK M ones(size(M))]*v.parameter,[],2);append('AUX_FCUC_FIT_CONSERVATIVE',pred,truth,'ge','p.u. frequency',1e-6);d.fitUnderestimate=max(truth-pred);
        end
    end
elseif startsWith(rel,'HW9/')
    m=localcase(fullfile(project,'电力系统分析与控制作业','HW9'),'case39_UC');weights=m.gen(:,9).*m.gen(:,8)/sum(m.gen(:,9));
    DD=weights'*[2.7;2.9;2.1;2.5;2.7;2.6;2.4;2.8;2.2;2.6];KK=weights'*[15;16;22;21;20;28;23;17;18;21];
    append('HW9_SYSTEM_DC_GAIN',v.sys.num(end)/v.sys.den(end),1/(DD+KK),'eq','p.u./p.u.',1e-10);d.Kweighted=KK;d.Ksum=201;d.Dweighted=DD;
    if endsWith(rel,'FreResponse.m')
        [drop,tm,ss]=psaudit_frequency_extremum(5,DD,KK,12,.1);d.expectedDropHz=drop*50;d.expectedTime=tm;d.expectedSteadyHz=ss*50;
        [actualdrop,pos]=min(v.response_fixedTj(1,:));d.actualDropHz=-actualdrop*50;d.actualTime=v.t(pos)-4.99;
        d.initialDelay=4.99;d.requestedDelay=5;
    else
        % The saved system is the final M=15 variant; the base test uses M=10.
        [drop,tm]=psaudit_frequency_extremum(10,DD,KK,12,.1);d.expectedBaseDropHz=drop*50;d.expectedBaseTime=tm;
    end
end

    function [value,status,detail]=diagnostic(kind,callback)
        name=[strrep(erase(rel,'.m'),'/','_') '_' kind '_v10.mat'];
        writeFile=fullfile(options.diagnosticDirectory,name);
        binding=struct('sourceHash',r.sourceHash,'resultHash',psaudit_hash_file(resultFile), ...
            'specHash',r.specHash,'checkerHash',psaudit_hash_file(which('psaudit_course_validate')), ...
            'cacheToolHash',psaudit_hash_file(which('psaudit_read_diagnostic')),'inputs',r.inputs, ...
            'kind',kind,'matlab',version);
        reads={writeFile,fullfile(options.evidenceDirectory,'diagnostics',name)};
        [value,status,detail]=psaudit_read_diagnostic(context,reads,writeFile,binding,callback);
    end
    function append(id,a,e,sense,unit,tol)
        auditRelation=struct('id',id,'actual',full(a),'expected',full(e),'sense',sense,'unit',unit,'absTol',tol,'relTol',1e-8);c(end+1)=psaudit_check_relations(auditRelation);
    end
    function events=checkUC(p,u,vv,ww,ss,prefix)
        [cc,events]=psaudit_check_commitment(p,u,vv,ww,ss);
        for jj=1:numel(cc),cc(jj).id=[prefix cc(jj).id];end;c=[c cc];
    end
    function network(z,actualF,prefix)
        [F,~,~,~,A]=psaudit_dc_network(m,z);limit=repmat(m.branch(:,6),1,size(z,2));
        append([prefix 'BALANCE'],sum(z,1),0,'eq','MW',1e-5);append([prefix 'KCL'],A'*F,z,'eq','MW',1e-5);
        append([prefix 'FLOW_LOW'],F,-limit,'ge','MW',1e-5);append([prefix 'FLOW_HIGH'],F,limit,'le','MW',1e-5);
        if ~isempty(actualF),append([prefix 'SOURCE_FLOW'],actualF,F,'eq','MW',1e-5);end
    end
    function frequency(u,p,entry)
        weight=m.gen(:,9)/sum(m.gen(:,9));MM=([15;14;13;13;15;15;10;9;9;15].*weight)'*u;DD=([2.7;2.9;2.1;2.5;2.7;2.6;2.4;2.8;2.2;2.6].*weight)'*u;KK=([15;16;22;21;20;28;23;17;18;21].*weight)'*u;
        deficit=500/sum(m.gen(:,9));FR=0;if endsWith(entry,'Task2_1.m'),FR=.2;end
        [drop,tm,ss,rr]=psaudit_frequency_extremum(MM,DD,KK,12*ones(size(MM)),deficit,FR);
        append('D_FREQUENCY_EXACT_NADIR',drop,.5/50,'le','p.u. frequency',1e-6);append('D_FREQUENCY_ROCOF',rr,.5/50,'le','1/s',1e-6);append('D_FREQUENCY_STEADY',ss,.3/50,'le','p.u. frequency',1e-6);
        d.maxNadirHz=max(drop)*50;d.maxRoCoFHz=max(rr)*50;d.maxSteadyHz=max(ss)*50;d.nadirTimes=tm;
        headroom=(m.gen(:,9).*u-p)/sum(m.gen(:,9));
        if endsWith(entry,'basicTask1.m')||endsWith(entry,'basicTask2.m')
            response=pi*(.5/50)^2*KK.*MM/(4*12*deficit);
            if endsWith(entry,'basicTask1.m'),available=min(response,sum(headroom,1));else,ri=pi*(.5/50)^2*(weight.*[15;16;22;21;20;28;23;17;18;21]).*u.*MM/(4*12*deficit);available=sum(min(ri,headroom),1);end
            append('FREQUENCY_HEADROOM_GATED',available+DD*.5/50,deficit,'ge','p.u. power',1e-6);d.headroomRequired=deficit-DD*.5/50;d.response=response;d.availableResponse=available;
        elseif endsWith(entry,'Task2_1.m')
            predicted=v.deltaPGtm;append('TURBINE_OFFLINE_RESPONSE',predicted.*(1-u),0,'eq','p.u. power',1e-6);
            K=[15;16;22;21;20;28;23;17;18;21];correct=weight.*u.*K*.01.*(.2+.8*pi*MM*.01/(4*12*deficit));
            append('TURBINE_RESPONSE_REFERENCE',predicted,correct,'eq','p.u. power',1e-6);
            append('TURBINE_HEADROOM_GATED',sum(min(correct,headroom),1)+DD*.01,deficit,'ge','p.u. power',1e-6);
        end
        if endsWith(entry,'Task3.m'),coef=v.mdl.Beta;correct=DD*coef(1)+KK*coef(2)+MM*coef(3)+coef(4)+v.mdl.Bias;used=DD*coef(1)+MM*coef(2)+KK*coef(3)+v.mdl.Bias;append('SVR_ACTUAL_FEATURE_MAPPING',used,correct,'eq','p.u. frequency',1e-8);end
    end
end

function yes=usable(v,name)
yes=isfield(v,name)&&isfield(v.(name),'problem')&&ismember(v.(name).problem,[0 3]);
end
function P=net(m)
[~,gb]=ismember(m.gen(:,1),m.bus(:,1));on=m.gen(:,8)>0;P=full(sparse(gb(on),1,m.gen(on,2),size(m.bus,1),1))-m.bus(:,3);
end
function m=localcase(directory,name)
old=path;cleanup=onCleanup(@()path(old));addpath(directory,'-begin');
clear case39_UC case39_FCUC
m=loadcase(name);
end
function c=missing(id,message)
c=struct('id',id,'status','DATA_INSUFFICIENT','maxResidual',NaN,'positionResidual',NaN,'tolerance',NaN,'count',0,'position','n/a','actual',NaN,'expected',NaN,'unit','n/a','detail',message);
end

function [grad,J]=dualreference(m,D,u,weather,piV,s)
I=10;N=39;T=96;L=46;assert(numel(piV)==2*T+2*L*T+2*N*T+4*I*T);
[~,~,B,Bf]=psaudit_dc_network(m,zeros(N,1));idx=find(m.bus(:,2)~=3);H=zeros(L,N);H(:,idx)=Bf(:,idx)/B(idx,idx);
C=sparse(m.gen(:,1),(1:I)',1,N,I);cursor=0;
bp=take(1,T);bn=take(1,T);fl=take(L,T);fh=take(L,T);wl=take(N,T);wu=take(T,N)';pl=take(I,T);ph=take(I,T);ru=take(I,T);rd=take(I,T);
common=ones(N,1)*(bp-bn)+H'*(fl-fh);
gp=C'*common+pl-ph+ru-ru(:,[T 1:T-1])+rd-rd(:,[2:T 1]);gw=common+wl-wu;
grad=[gp(:);gw(:)];boundUp=s.Su+(s.Ru-s.Su).*u;boundDown=s.Sd+(s.Rd-s.Sd).*u;
J=sum(sum(D,1).*(bp-bn),'all')+sum((H*D-m.branch(:,6)).*fl+(-H*D-m.branch(:,6)).*fh,'all') ...
    -sum(weather.*wu(30,:),'all')+sum(s.Pmin.*u.*pl-s.Pmax.*u.*ph-boundUp.*ru-boundDown.*rd,'all')+.1*.25*sum(weather);
    function x=take(a,b),x=reshape(piV(cursor+(1:a*b)),a,b);cursor=cursor+a*b;end
end

function probe=primalreference(m,D,u,weather,s,seconds)
% Diagnostic LP only, never relabelled as an original-program solution.
I=10;N=39;T=96;L=46;[~,~,B,Bf]=psaudit_dc_network(m,zeros(N,1));idx=find(m.bus(:,2)~=3);H=zeros(L,N);H(:,idx)=Bf(:,idx)/B(idx,idx);
C=sparse(m.gen(:,1),(1:I)',1,N,I);p=sdpvar(I,T,'full');w=sdpvar(1,T,'full');z=C*p-D;z(30,:)=z(30,:)+w;
F=H*z;limit=repmat(m.branch(:,6),1,T);next=[2:T 1];dp=p(:,next)-p;
constraints=[sum(z,1)==0,F>=-limit,F<=limit,p>=s.Pmin.*u,p<=s.Pmax.*u,w>=0,w<=weather, ...
    dp<=s.Su+(s.Ru-s.Su).*u,-dp<=s.Sd+(s.Rd-s.Sd).*u(:,next)];
obj=.25*sum(repmat(m.gencost(:,6),1,T).*p,'all')+.1*.25*sum(weather-w,'all');
result=optimize(constraints,obj,sdpsettings('solver','gurobi','verbose',0,'gurobi.TimeLimit',seconds,'gurobi.Threads',4));
probe=struct('problem',result.problem,'info',result.info,'objective',value(obj),'p',value(p),'wind',value(w),'u',u,'weather',weather);
end

function probe=voltageprobe(pure,v,dd,seconds) %#ok<INUSD>
% runpf has no solver TimeLimit; the context records overrun and stops retries.
opt=mpoption('verbose',0,'out.all',0,'exp.use_legacy_core',1);x=runpf(pure,opt);
probe=struct('success',x.success,'response',[],'approxError',NaN);
if x.success,probe.response=x.bus(dd,8)-v.res1.bus(dd,8);probe.approxError=max(abs(v.err_1-probe.response));end
end

function writeEvidence(audit,file)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'# 剩余八份作业：独立数值证据\n\nPASS仅对所列关系有效；D前缀为物理/语义诊断，功率周期条件检查不能直接升格为代码ERROR。执行完成与求解成功分开，失败入口不当通过。\n\n');
for k=1:numel(audit)
    x=audit(k);fprintf(fid,'## %s\n\n原程序包装执行完成：%d；耗时：%.6fs。原始结果：%s；SHA-256：%s。\n\n',x.relative,x.r.completed,x.r.elapsed,x.resultFile,x.resultHash);
    if ~isempty(x.r.error),fprintf(fid,'```text\n%s\n```\n\n',x.r.error);end
    for fn={'result','result_ahead','result_intra'},if isfield(x.r.vars,fn{1}),r=x.r.vars.(fn{1});fprintf(fid,'- %s：problem=%d；%s\n',fn{1},r.problem,r.info);end;end
    if isfield(x.r,'lastSolverResult'),r=x.r.lastSolverResult;fprintf(fid,'- bare optimize：problem=%d；%s\n',r.problem,r.info);end
    fprintf(fid,'\n| ID | 状态 | 最大残差 | 位置 | 实际 | 期望 | 单位 | 容差 | 违规数 |\n| --- | --- | ---: | --- | ---: | ---: | --- | ---: | ---: |\n');
    for j=1:numel(x.checks),c=x.checks(j);fprintf(fid,'| %s | %s | %.10g | %s | %.10g | %.10g | %s | %.10g | %d |\n',c.id,c.status,c.maxResidual,c.position,c.actual,c.expected,c.unit,c.tolerance,c.count);end
    fprintf(fid,'\n');
end
end
