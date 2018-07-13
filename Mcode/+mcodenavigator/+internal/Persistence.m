classdef Persistence
    
    methods (Static)
        function deleteAllSettings()
            if ispref(PREFGROUP)
                rmpref(PREFGROUP);
            end
        end
    end
end