function out = getChildNodeValues(node)
%GETCHILDNODEVALUES Get values attached to child nodes of a uitree node
out = {};
for i = 1:node.getChildCount
    out{i} = get(node.getChildAt(i-1), 'Value'); %#ok<AGROW>
end
end