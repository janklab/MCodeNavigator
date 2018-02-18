classdef CodeNodeData < mprojectnavigator.internal.NodeData
    % Node user data for CodeNavigatorWidget
    
    % These properties are a union of the properties used for all types of nodes
    % in CodeNavigatorWidget. Some may not be meaningful depending on the
    % context in which the object is used.
    properties
        type char
        % Fully-qualified name of this thing. Must uniquely identify a node
        % within the code navigator widget, within a type, for types that are
        % lookup-able; it's used as a key in the. Required.
        name        char
        % Label to be displayed to the user in the tree node
        label       char
        basename    char
        package     char
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
        function this = CodeNodeData(type, name)
            if nargin == 0
                return
            end
            this.type = type;
            if nargin >= 2;     this.name = name;  end
            
        end
    end
end