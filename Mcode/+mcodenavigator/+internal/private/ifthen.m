function out = ifthen(condition, ifValue, elseValue)

if condition
    out = ifValue;
else
    out = elseValue;
end
end