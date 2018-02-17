function trace(msg, varargin)
% Log a TRACE level message from caller.
%
% jl.log.trace(msg, varargin)
%
% This accepts a message with SLF4J style formatting, using '{}' as placeholders for
% values to be interpolated into the message.
%
% Examples:
%
% jl.log.trace('Some message. value1={} value2={}', 'foo', 42);

loggerCallImpl('trace', msg, varargin);

end