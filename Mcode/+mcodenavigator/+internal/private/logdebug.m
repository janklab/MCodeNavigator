function logdebug(format, varargin)
% Log a DEBUG level message from caller, with printf style formatting.
%
% logdebug(msg, varargin)
%
% This accepts a message with printf style formatting, using '%...' formatting
% controls as placeholders.
%
% Examples:
%
% logdebug('Some message. value1=%s value2=%d', 'foo', 42);

msg = sprintf(format, varargin{:});
loggerCallImpl('debug', msg, {});

end