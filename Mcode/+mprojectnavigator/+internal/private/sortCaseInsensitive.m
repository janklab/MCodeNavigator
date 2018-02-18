function [out,ix] = sortCaseInsensitive(x)
[~,ix] = sort(lower(x));
out = x(ix);
end
