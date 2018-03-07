classdef a_TestCase < matlab.unittest.TestCase
    
    methods (Test)
        function testNothing(t)
            t.verifyEqual(1 + 1, 2);
        end
    end
end