function [out,i] = getChildNodeByValue(node, value)
out = [];
for i = 1:node.getChildCount
    child = node.getChildAt(i-1);
    if isequal(char(child.getValue), value)
        out = child;
        return
    end
end
end
