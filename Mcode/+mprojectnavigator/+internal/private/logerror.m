function error(msg, varargin)
%ERROR Log an ERROR level message from caller.
%
% jl.log.error(msg, varargin)
%
% This accepts a message with SLF4J style formatting, using '{}' as placeholders for
% values to be interpolated into the message.
%
% Examples:
%
% jl.log.error('Some message. value1={} value2={}', 'foo', 42);

loggerCallImpl('error', msg, varargin);

end