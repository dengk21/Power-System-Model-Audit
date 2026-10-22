classdef psaudit_execution_context < handle
    % Explicit action modes and budgets; replay never executes a callback.
    properties (SetAccess=private)
        mode
        maxActions=0
        singleSeconds=0
        totalSeconds=0
        actions=struct('label',{},'kind',{},'limit',{},'elapsed',{},'status',{})
    end
    methods
        function self=psaudit_execution_context(mode,budget)
            if nargin<1,mode='replay';end
            if nargin<2,budget=struct;end
            assert(ismember(mode,{'replay','diagnose','capture'}),'Unknown execution mode');
            self.mode=mode;
            if strcmp(mode,'replay')
                assert(isempty(fieldnames(budget)),'Replay has no execution budget');return
            end
            names={'maxActions','singleSeconds','totalSeconds'};
            assert(all(isfield(budget,names)),'Explicit action/time budget required');
            for k=1:numel(names)
                x=budget.(names{k});assert(isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>0,'Invalid budget');
                self.(names{k})=x;
            end
            assert(self.maxActions==fix(self.maxActions),'maxActions must be an integer');
        end
        function yes=allows(self,kind)
            yes=((strcmp(self.mode,'diagnose')&&strcmp(kind,'diagnostic'))|| ...
                (strcmp(self.mode,'capture')&&strcmp(kind,'capture')))&& ...
                numel(self.actions)<self.maxActions&&sum([self.actions.elapsed])<self.totalSeconds&& ...
                ~any(strcmp({self.actions.status},'TIME_BUDGET_EXCEEDED'));
        end
        function value=run(self,kind,label,callback)
            assert(self.allows(kind),'psaudit:ExecutionDenied','Mode or exhausted budget forbids this action');
            limit=min(self.singleSeconds,self.totalSeconds-sum([self.actions.elapsed]));
            k=numel(self.actions)+1;
            self.actions(k)=struct('label',label,'kind',kind,'limit',limit,'elapsed',0,'status','STARTED');
            clock=tic;
            try,value=callback(limit);
            catch err
                self.actions(k).elapsed=toc(clock);self.actions(k).status='FAILED';rethrow(err)
            end
            self.actions(k).elapsed=toc(clock);self.actions(k).status='COMPLETED';
            if self.actions(k).elapsed>limit,self.actions(k).status='TIME_BUDGET_EXCEEDED';end
        end
        function state=snapshot(self)
            state=struct('mode',self.mode,'maxActions',self.maxActions,'singleSeconds',self.singleSeconds, ...
                'totalSeconds',self.totalSeconds,'actionCount',numel(self.actions), ...
                'elapsed',sum([self.actions.elapsed]),'actions',self.actions);
        end
    end
end
