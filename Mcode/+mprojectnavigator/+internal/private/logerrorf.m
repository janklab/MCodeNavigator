function errorf(format, varargin)
% Log an ERROR level message from caller, with printf style formatting.
%
% jl.log.errorf(msg, varargin)
%
% This accepts a message with printf style formatting, using '%...' formatting
% controls as placeholders.
%
% Examples:
%
% jl.log.errorf('Some message. value1=%s value2=%d', 'foo', 42);

msg = sprintf(format, varargin{:});
loggerCallImpl('error', msg);

end