function infof(format, varargin)
% Log an INFO level message from caller, with printf style formatting.
%
% jl.log.infof(msg, varargin)
%
% This accepts a message with printf style formatting, using '%...' formatting
% controls as placeholders.
%
% Examples:
%
% jl.log.infof('Some message. value1=%s value2=%d', 'foo', 42);

msg = sprintf(format, varargin{:});
loggerCallImpl('info', msg);

end