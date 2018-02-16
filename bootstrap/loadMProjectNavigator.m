function loadMProjectNavigator(varargin)
    % Loads MProjectNavigator into the current Matlab session
    %
    % loadMProjectNavigator()
    %
    % Call this function to initialize MProjectNavigator and make it available
    % in your current Matlab session.
    %
    % This adds the required Matlab source code and Java JAR files to the Matlab
    % path and javaclasspath. It locates them relative to its own location, so
    % it will load them from the project installation it is invoked from.
    %
    % This load step is necessary, unfortunately, because MProjectNavigator uses
    % custom Java components.
    
    doDevKit = ismember(varargin, '-dev');
    
    thisFile = mfilename('fullpath');
    distDir = fileparts(fileparts(thisFile));
    mcodeDir = fullfile(distDir, 'Mcode');
    javaLibDir = fullfile(distDir, 'lib', 'java');
    jarFile = fullfile(javaLibDir, 'MProjectNavigator.jar');
    
    addpath(mcodeDir);
    javaaddpath(jarFile);
    
    MProjectNavigator -registerhotkey
    
    if doDevKit
        devKitPath = fullfile(distDir, 'dev-tools');
        addpath(fullfile(devKitPath, 'Mcode'));
    end
end