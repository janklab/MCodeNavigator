function loadMCodeNavigator(varargin)
    % Loads MCodeNavigator into the current Matlab session
    %
    % loadMCodeNavigator()
    %
    % Call this function to initialize MCodeNavigator and make it available
    % in your current Matlab session.
    %
    % This adds the required Matlab source code and Java JAR files to the Matlab
    % path and javaclasspath. It locates them relative to its own location, so
    % it will load them from the project installation it is invoked from.
    %
    % This load step is necessary, unfortunately, because MCodeNavigator uses
    % custom Java components.
    
    doDevKit = ismember('-dev', varargin);
    doDebug = ismember('-debug', varargin);
    
    thisFile = mfilename('fullpath');
    distDir = fileparts(fileparts(thisFile));
    mcodeDir = fullfile(distDir, 'Mcode');
    javaLibDir = fullfile(distDir, 'lib', 'java');
    jarFile = fullfile(javaLibDir, 'MCodeNavigator.jar');
    
    addpath(mcodeDir);
    %javaaddpath(jarFile);
    classpathHacker = mcodenavigator.internal.StaticClasspathHacker;
    classpathHacker.addToStaticClasspath(jarFile);
    
    mcodenavigator.internal.Log4jConfigurator.configureBasicConsoleLogging;
    if doDebug
        % Need to set this now so it's active during the initial
        % MCodeNavigator call.
        mcodenavigator.internal.Log4jConfigurator.setLevels({'root','DEBUG'});
    end
    
    MCodeNavigator -registerhotkey
    
    if doDevKit
        devKitPath = fullfile(distDir, 'dev-tools');
        addpath(fullfile(devKitPath, 'Mcode'));
    end
end