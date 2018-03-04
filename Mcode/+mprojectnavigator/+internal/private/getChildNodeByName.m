function [out,i] = getChildNodeByName(node, name)
out = [];
for i = 1:node.getChildCount
    child = node.getChildAt(i-1);
    if isequal(char(child.getName), name)
        out = child;
        return
    end
end
end
