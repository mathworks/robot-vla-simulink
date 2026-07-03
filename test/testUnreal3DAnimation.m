classdef testUnreal3DAnimation < matlab.unittest.TestCase
    % Smoke test: verify Unreal3DAnimation.slx simulates without errors.

    methods(TestClassSetup)
        function addPathFixture(testCase)
            % Add repo root (two levels up) to MATLAB path for tests
            repoRoot = fileparts(fileparts(mfilename('fullpath')));
            import matlab.unittest.fixtures.PathFixture
            testCase.applyFixture(PathFixture(repoRoot));
        end
    end

    methods(TestMethodSetup)
        function loadSimulinkModel(testCase)
            load_system('Unreal3DAnimationTest');
            testCase.addTeardown(@() close_system('Unreal3DAnimationTest', 0));
        end
    end

    methods (Test)
        function verifySimulationRuns(testCase)
            % Verify model simulates for 1s without throwing errors
            scenario = BridgeDataTable;
            assignin('base', 'scenario', scenario)
            try
                sim('Unreal3DAnimationTest', 'StopTime', '1');
                testCase.verifyTrue(true, 'Simulation completed successfully');
            catch ME
                testCase.verifyFail(['Simulation failed with error: ' ME.message]);
            end
        end
    end

end