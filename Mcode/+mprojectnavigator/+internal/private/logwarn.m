function warn(msg, varargin)
%WARN Log a WARN level message from caller.
%
% jl.log.warn(msg, varargin)
%
% This accepts a message with SLF4J style formatting, using '{}' as placeholders for
% values to be interpolated into the message.
%
% Examples:
%
% jl.log.warn('Some message. value1={} value2={}', 'foo', 42);

loggerCallImpl('warn', msg, varargin);

end