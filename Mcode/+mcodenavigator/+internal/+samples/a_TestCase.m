classdef a_TestCase < matlab.unittest.TestCase
%A_TESTCASE A class that inherits from matlab.unittest.TestCase

    methods (Test)
        function testNothing(t)
            t.verifyEqual(1 + 1, 2);
        end
    end
end