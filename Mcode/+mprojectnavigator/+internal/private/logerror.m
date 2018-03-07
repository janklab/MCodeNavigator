function logerror(format, varargin)
% Log an ERROR level message from caller, with printf style formatting.
%
% logerror(msg, varargin)
%
% This accepts a message with printf style formatting, using '%...' formatting
% controls as placeholders.
%
% Examples:
%
% logerror('Some message. value1=%s value2=%d', 'foo', 42);

msg = sprintf(format, varargin{:});
loggerCallImpl('error', msg);

end