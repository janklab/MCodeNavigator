classdef a_classdef_with_only_hidden_items
    %Has only hidden methods and properties
    
    properties (Hidden)
        foo
    end
    
    methods (Hidden)
        function this = a_classdef_with_only_hidden_items()
        end
        
        function x(this) %#ok<*MANU>
        end
    end
end