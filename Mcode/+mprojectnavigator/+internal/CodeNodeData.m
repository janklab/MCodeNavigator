classdef CodeNodeData < mprojectnavigator.internal.NodeData
    % Node user data for CodeNavigatorWidget
    
    % These properties are a union of the properties used for all types of nodes
    % in CodeNavigatorWidget. Some may not be meaningful depending on the
    % context in which the object is used.
    properties
        label char
        type char
        name char
        basename char
        package char
        paths
        found
        defn
        parentDefinition
        classNames
        functionNames
        definingClass
    end
    
    methods
        function this = CodeNodeData(type, name)
            if nargin == 0
                return
            end
            if nargin >= 1
                this.type = type;
            end
            if nargin >= 2
                this.name = name;
            end
        end
    end
end