classdef a_classdef_with_hidden_items
    
    properties
        foo
        bar
    end
    
    properties (Hidden)
        hidden_foo
        hidden_bar
    end
    
    methods
        function x(this) %#ok<*MANU>
        end
        
        function y(this)
        end
    end
    
    methods (Hidden)
        function hidden_x(this)
        end
        
        function hidden_y(this)
        end
    end
end