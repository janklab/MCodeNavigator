classdef CodeRootsNodeData < mcodenavigator.internal.NodeData
    % Node user data for CodeRootsNavigatorWidget
    %
    % Programmers' note: this class is really sloppy; it's the union of a bunch
    % of different case-specific data types. Don't use this as an example of how
    % to write good code.
    
    % These properties are a union of the properties used for all types of nodes
    % in ClassesNavigatorWidget. Some may not be meaningful depending on the
    % context in which the object is used.
    properties
        % Fully-qualified name of whatever this node is holding
        name        char
        % For CodePaths nodes, whether it's USER or MATLAB paths
        pathsType   char
        % Path to the file or directory this node represents
        path        char
        basename    char
        isDir       logical = false
        isFile      logical = false
        isDummy     logical = false
    end
    
    methods
        function this = CodeRootsNodeData(type, name)
            if nargin == 0
                return
            end
            this.type = type;
            if nargin >= 2;     this.name = name;  end            
        end
    end
end