function logtrace(format, varargin)
% Log a TRACE level message from caller, with printf style formatting.
%
% logtrace(msg, varargin)
%
% This accepts a message with printf style formatting, using '%...' formatting
% controls as placeholders.
%
% Examples:
%
% logtrace('Some message. value1=%s value2=%d', 'foo', 42);

msg = sprintf(format, varargin{:});
loggerCallImpl('trace', msg);

end