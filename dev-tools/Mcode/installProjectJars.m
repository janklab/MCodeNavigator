function installProjectJars()
    % Install this project's JARs from the Java project build dir
    %
    % After running this, you will need to `clear java` or (probably) restart
    % Matlab.
    thisFile = mfilename('fullpath');
    distDir = fileparts(fileparts(fileparts(thisFile)));
    relJarLibDir = 'lib/java';
    jarLibDir = [distDir  '/' relJarLibDir];
    relJarBuildDir = 'src/java/MCodeNavigator/out/artifacts/MCodeNavigator';
    relJarFile = [relJarBuildDir '/MCodeNavigator.jar'];
    jarFile = [distDir '/' relJarFile];
    copyfile(jarFile, jarLibDir, 'f');
    fprintf('Installed %s -> %s\n', relJarFile, relJarLibDir);
end