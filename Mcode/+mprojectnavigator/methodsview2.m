function methodsview2(target)
%METHODSVIEW2 Enhanced view of class methods and properties
%
% Examples:
%
% mprojectnavigator.methodsview2('mprojectnavigator.internal.CodeRootsNavigatorWidget')
% mprojectnavigator.methodsview2('mprojectnavigator.internal.samples.a_TestCase')
% mprojectnavigator.methodsview2('double')

% Figure out if klass is an object or class name
if ischar(target)
    classDefn = [];
    try
        classDefn = meta.class.fromName(target);
    catch
        % quash - not a visible Matlab class
    end
    if ~isempty(classDefn)
        % It's a Matlab class
        methodsview2_matlab(target);
        return;
    end
    try
        classDefn = java.lang.Class.forName(target);
    catch
        % quash - not a visible Java class
    end
    if ~isempty(classDefn)
        % It's a Java class
        methodsview2_java(target);
        return;
    end
elseif isobject(target)
    className = class(target);
    methodsview2_matlab(className);
elseif isjava(target)
    javaClassName = target.getClass.getName;
    methodsview2_java(javaClassName);
else
    error('Unsupported input type for methodsview2: %s', class(target));
end

% Get class definition

% Bring up class structure widget in a dialog

end

function methodsview2_java(javaClassName)
% Show structure for Java class

% We don't have an enhanced view for Java classes; fall back to Matlab's
% methodsview.
methodsview(javaClassName);
end

function methodsview2_matlab(className)
% Show structure for Matlab class
classDefn = meta.class.fromName(className);
widget = mprojectnavigator.internal.ClassStructureWidget;
widget.classDefn = classDefn;
widget.showInDialog;
end