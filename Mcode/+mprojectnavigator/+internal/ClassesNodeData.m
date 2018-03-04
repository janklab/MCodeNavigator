classdef ClassesNodeData < mprojectnavigator.internal.NodeData
    % Node user data for ClassesNavigatorWidget
    %
    % Programmers' note: this class is really sloppy; it's the union of a bunch
    % of different case-specific data types. Don't use this as an example of how
    % to write good code.
    
    % These properties are a union of the properties used for all types of nodes
    % in ClassesNavigatorWidget. Some may not be meaningful depending on the
    % context in which the object is used.
    properties
        type char
        % Fully-qualified name of this thing. Must uniquely identify a node
        % within the code navigator widget, within a type, for types that are
        % lookup-able; it's used as a key in the. Required.
        name        char
        % Label to be displayed to the user in the tree node
        label       char
        % Base name (non-qualified) of the package or class or whatever
        basename    char
        package     char
        % For CodePaths nodes, whether it's USER or MATLAB paths
        pathsType   char
        % For CodePathsGlobals nodes, paths to find stuff on
        paths
        found
        defn
        classNames
        functionNames
        definingClass
        % If true, then this node represents a file or directory, and this.path will
        % be populated with the full path to it. This is used for deciding
        % whether to add file-related operations to the context menu.
        isFile      logical = false
        path        char
    end
    
    methods
        function this = ClassesNodeData(type, name)
            if nargin == 0
                return
            end
            this.type = type;
            if nargin >= 2;     this.name = name;  end            
        end
    end
end