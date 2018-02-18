function out = sortCaseInsensitive(x)
[~,ix] = sort(lower(x));
out = x(ix);
end
