classdef StaticClasspathHacker
    %STATICCLASSPATHHACKER Tool for manipulating the Matlab static Java classpath
    
    methods
        function addToStaticClasspath(~, file, classname)
        %addToStaticClasspath Add an entry to the static Java classpath at run time.
        %
        % obj.addToStaticClasspath(file, classname)
        %
        % Adds the given file to the static classpath. This is in contrast to the
        % regular javaaddpath, which adds a file to the dynamic classpath.
        %
        % Files added to the path will not show up in the output of
        % javaclasspath(), but they will still actually be on there, and classes
        % from it will be picked up.
        %
        % If classname is supplied, that class will be loaded using the discovered
        % ClassLoader.
        %
        % Caveats:
        %  * This is a HACK and bound to be unsupported.
        %  * You need to call this before attempting to reference any class in it,
        %    or Matlab may "remember" that the symbols could not be resolved. Use
        %    the optional classname input arg to let Matlab know this class exists.
        %  * There is no way to remove the new path entry once it is added.
        %
        % See also:
        % javaaddpath, javaclasspath
                
        % Find the Application class loader
        % Pick a class that's known to ship with Matlab in jarext
        obj = com.google.common.util.concurrent.AtomicDouble;
        appClassLoader = obj.getClass().getClassLoader();
        
        % Have to use reflection because we're calling a private/protected method
        parms = javaArray('java.lang.Class', 1);
        parms(1) = java.lang.Class.forName('java.net.URL');
        loaderClass = java.lang.Class.forName('java.net.URLClassLoader');
        addUrlMeth = loaderClass.getDeclaredMethod('addURL', parms);
        addUrlMeth.setAccessible(1);
        
        % Add the URL for the given file
        argArray = javaArray('java.lang.Object', 1);
        jFile = java.io.File(file);
        argArray(1) = jFile.toURI().toURL();
        addUrlMeth.invoke(appClassLoader, argArray);
        
        % Load the class if requested
        if nargin > 2
            % load the class into Matlab's memory (a no-args public constructor is
            % expected to exist for this class)
            eval(classname);
        end
        end
        
    end
    
end
