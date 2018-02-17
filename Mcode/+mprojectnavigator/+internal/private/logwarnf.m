function warnf(format, varargin)
% Log a WARN level message from caller, with printf style formatting.
%
% jl.log.warnf(msg, varargin)
%
% This accepts a message with printf style formatting, using '%...' formatting
% controls as placeholders.
%
% Examples:
%
% jl.log.warnf('Some message. value1=%s value2=%d', 'foo', 42);

msg = sprintf(format, varargin{:});
loggerCallImpl('warn', msg);

end