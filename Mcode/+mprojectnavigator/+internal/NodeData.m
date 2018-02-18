classdef NodeData < handle
    % Node user data
    %
    % Stick this in the UserData property of a UITreeNode
    
    properties
        % Indicates the node is currently in the process of being refreshed
        isRefreshing    logical = false
        % Indicates the node has been populated with data, at least initially
        isPopulated     logical = false
        % Indicates the node's backing data has changed, so it should be updated
        % on the next refresh
        isDirty         logical = true
        % Indicates this node contains a diagnostic message, not real data
        isDiagnostic    logical = false
    end
    
end