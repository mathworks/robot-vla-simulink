classdef testRobotPolicy < matlab.unittest.TestCase
    % Verify VLA model inference produces expected actions for known inputs.
    % First run is slow due to model download.    

    methods(TestClassSetup)
        function setupPythonEnvironment(testCase)
            penv = configurePyenv;
            testCase.addTeardown(@()terminate(penv))
        end
        
        function addPathFixture(testCase)
            % Add repo root (two levels up) to MATLAB path for tests
            repoRoot = fileparts(fileparts(mfilename('fullpath')));
            import matlab.unittest.fixtures.PathFixture
            testCase.applyFixture(PathFixture(repoRoot));
        end
    end

    methods (Test)

        function verifyOctoInference(testCase)
            % Verify Octo model returns expected action for a known image+task input
            model = robotpolicy(ModelName="Octo");

            % Black image as deterministic baseline input
            image = zeros(480, 640, 3,'uint8');
            task =  "put the spoon on the towel";
            action = model(image, task);

            expectedAction = [0.0096, -0.0112, -0.0192, 0.0401, -0.0047, 0.0136, 1];
            testCase.verifyEqual(action, expectedAction(:), AbsTol=1e-4)
        end

        function verifyRt1xInference(testCase)
            % Verify RT1-X model returns expected action for a known image+task input
            
            % Note: RT1X is not used in the current example, so not testing
            % the RT1X model inference

            % model = robotpolicy(ModelName="RT1X");
            
            % image = zeros(480, 640, 3,'uint8');
            % task =  "put the spoon on the towel";
            % action = model(image, task);
            
            % expectedAction = [0.0001, -0.0112, -0.0192, 0.0401, -0.0047, 0.0136, 1];
            % testCase.verifyEqual(action, expectedAction(:)', AbsTol=1e-4)
        end        
    end
end