classdef Logger
    %LOGGER Main entry point through which logging happens
    %
    % The logger class provides method calls for performing logging, and the ability
    % to look up loggers by name. This is the main entry point through which all
    % MCodeNavigator logging happens.
    %
    % This is a wrapper around SLF4J logging, so it is compatible with other
    % code that uses SLF4J/Matlab logging.
    %
    % See also:
    % jl.log.error
    % jl.log.warn
    % jl.log.info
    % jl.log.debug
    % jl.log.trace
    
    properties (SetAccess = private)
        % The underlying SLF4J Logger object
        jLogger
    end
    
    properties (Dependent = true)
        % The name of this logger
        name
        % A list of the levels enabled on this logger
        enabledLevels
    end
    
    
    methods (Static)
        function out = getLogger(identifier)
        % Gets the named Logger
        jLogger = org.slf4j.LoggerFactory.getLogger(identifier);
        out = mcodenavigator.internal.Logger(jLogger);
        end
        
    end
    
    methods
        function this = Logger(jLogger)
        %LOGGER Build a new logger object around an SLF4J Logger object
        %
        % Generally, you shouldn't call this. Use the static
        % mcodenavigator.Logger.getLogger() instead.
        mustBeA(jLogger, 'org.slf4j.Logger');
        this.jLogger = jLogger;
        end
        
        function errorj(this, msg, varargin)
        % Log a message at the ERROR level.
        if ~this.jLogger.isErrorEnabled()
            return
        end
        this.jLogger.error(msg, varargin{:});
        end
        
        function error(this, format, varargin)
        % Log a message at the ERROR level, with sprintf formatting.
        if ~this.jLogger.isErrorEnabled()
            return
        end
        msg = sprintf(format, varargin{:});
        this.errorj(msg);
        end
        
        function warnj(this, msg, varargin)
        % Log a message at the WARN level.
        if ~this.jLogger.isWarnEnabled()
            return
        end
        this.jLogger.warn(msg, varargin{:});
        end
        
        function warn(this, format, varargin)
        % Log a message at the WARN level, with sprintf formatting.
        if ~this.jLogger.isWarnEnabled()
            return
        end
        msg = sprintf(format, varargin{:});
        this.warnj(msg);
        end
        
        function infoj(this, msg, varargin)
        % Log a message at the INFO level.
        if ~this.jLogger.isInfoEnabled()
            return
        end
        this.jLogger.info(msg, varargin{:});
        end
        
        function info(this, format, varargin)
        % Log a message at the INFO level, with sprintf formatting.
        if ~this.jLogger.isInfoEnabled()
            return
        end
        msg = sprintf(format, varargin{:});
        this.infoj(msg);
        end
        
        function debugj(this, msg, varargin)
        % Log a message at the DEBUG level.
        if ~this.jLogger.isDebugEnabled()
            return
        end
        this.jLogger.debug(msg, varargin{:});
        end
        
        function debug(this, format, varargin)
        % Log a message at the DEBUG level, with sprintf formatting.
        if ~this.jLogger.isDebugEnabled()
            return
        end
        msg = sprintf(format, varargin{:});
        this.debugj(msg);
        end
        
        function tracej(this, msg, varargin)
        % Log a message at the TRACE level.
        if ~this.jLogger.isTraceEnabled()
            return
        end
        this.jLogger.trace(msg, varargin{:});
        end
        
        function trace(this, format, varargin)
        % Log a message at the TRACE level, with sprintf formatting.
        if ~this.jLogger.isTraceEnabled()
            return
        end
        msg = sprintf(format, varargin{:});
        this.tracej(msg);
        end
        
        function out = isErrorEnabled(this)
        % True if ERROR level logging is enabled for this logger.
        out = this.jLogger.isErrorEnabled;
        end
        
        function out = isWarnEnabled(this)
        % True if WARN level logging is enabled for this logger.
        out = this.jLogger.isWarnEnabled;
        end
        
        function out = isInfoEnabled(this)
        % True if INFO level logging is enabled for this logger.
        out = this.jLogger.isInfoEnabled;
        end
        
        function out = isDebugEnabled(this)
        % True if DEBUG level logging is enabled for this logger.
        out = this.jLogger.isDebugEnabled;
        end
        
        function out = isTraceEnabled(this)
        % True if TRACE level logging is enabled for this logger.
        out = this.jLogger.isTraceEnabled;
        end
        
        function out = listEnabledLevels(this)
        % List the levels that are enabled for this logger.
        out = {};
        if this.isErrorEnabled
            out{end+1} = 'error';
        end
        if this.isWarnEnabled
            out{end+1} = 'warn';
        end
        if this.isInfoEnabled
            out{end+1} = 'info';
        end
        if this.isDebugEnabled
            out{end+1} = 'debug';
        end
        if this.isTraceEnabled
            out{end+1} = 'trace';
        end
        end
        
        function out = get.enabledLevels(this)
        out = this.listEnabledLevels;
        end
        
        function out = get.name(this)
        out = char(this.jLogger.getName());
        end
    end
    
end

function mustBeA(value, type)
    assert(isa(value, type), 'Input must be a %s, but got a %s', type, class(value));
end
