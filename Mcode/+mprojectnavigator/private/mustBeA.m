function mustBeA(value, type)
    assert(isa(value, type), 'Input must be a %s, but got a %s', type, class(value));
end
