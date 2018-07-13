function mustBeA(value, type)
    if isequal(type, 'cellstr')
        assert(iscellstr(value), 'Input must be a %s, but got a %s', 'cellstr', class(value));
    else
        assert(isa(value, type), 'Input must be a %s, but got a %s', type, class(value));
    end
end
