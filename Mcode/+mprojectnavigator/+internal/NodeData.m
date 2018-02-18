classdef NodeData < handle
    % Node user data
    %
    % Stick this in the UserData property of a UITreeNode
    
    properties
        % Indicates the node is currently in the process of being refreshed
        isRefreshing logical = false
        % Indicates the node has been populated with data, at least initially
        isPopulated logical = false
    end
    
end