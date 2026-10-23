function result = run_audit(project, skillRoot, options)
% Project-owned entrypoint. Agent must implement and test actual mappings.
% Call the project binding status check before replay; STALE requires review.
% Default replay: never solve implicitly. Explicit execution needs a budget.
error('psaudit:AdapterNotImplemented', ...
    'Adapter scaffold only. Implement independent reconstruction and tests first.');
end
