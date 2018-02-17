function info(msg, varargin)
%INFO Log an INFO level message from caller.
%
% jl.log.info(msg, varargin)
%
% This accepts a message with SLF4J style formatting, using '{}' as placeholders for
% values to be interpolated into the message.
%
% Examples:
%
% jl.log.info('Some message. value1={} value2={}', 'foo', 42);

loggerCallImpl('info', msg, varargin);

end