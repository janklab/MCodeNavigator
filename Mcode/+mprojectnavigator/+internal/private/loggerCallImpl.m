function loggerCallImpl(logLevel, msg, args)
%LOGGERCALLIMPL Implementation for the top-level logger functions

if nargin < 3;  args = {};  end

strStack = evalc('dbstack(2)');
stackLine = regexprep(strStack, '\n.+', '');
caller = regexp(stackLine, '>([^<>]+)<', 'once', 'tokens');
if isempty(caller)
    callerClass = 'unknown';
else
    caller = caller{1};
    callerClass = regexprep(caller, '/.*', '');
end

logger = mprojectnavigator.Logger.getLogger(callerClass);

switch logLevel
    case 'error'
        logger.error(msg, args{:});
        return
    case 'warn'
        logger.warn(msg, args{:});
        return
    case 'info'
        logger.info(msg, args{:});
        return
    case 'debug'
        logger.debug(msg, args{:});
        return
    case 'trace'
        logger.trace(msg, args{:});
        return
    otherwise
        error('mprojectnavigator:InvalidInput', 'Invalid logLevel: %s', logLevel);
end


end