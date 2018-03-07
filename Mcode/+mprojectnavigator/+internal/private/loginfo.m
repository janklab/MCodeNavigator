function loginfo(format, varargin)
% Log an INFO level message from caller, with printf style formatting.
%
% loginfo(msg, varargin)
%
% This accepts a message with printf style formatting, using '%...' formatting
% controls as placeholders.
%
% Examples:
%
% loginfo('Some message. value1=%s value2=%d', 'foo', 42);

msg = sprintf(format, varargin{:});
loggerCallImpl('info', msg);

end