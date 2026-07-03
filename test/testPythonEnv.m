classdef testPythonEnv < matlab.unittest.TestCase
    % Smoke test: if Python modules import successfully, deps are installed correctly.

    properties(TestParameter)
        ModuleName = {'octoModel', 'rt1xModel'};
    end

    methods(TestClassSetup)
        function setupPythonEnvironment(testCase)
            penv = configurePyenv;
            testCase.addTeardown(@()terminate(penv))

            pythonVersion = string(penv.Version);
            testCase.assertEqual(pythonVersion, "3.10", ...
                sprintf('Expected Python version 3.10, but got %s', pythonVersion));
        end
    end

    methods (Test)
        function verifyModuleImport(testCase, ModuleName)
            % Verify each VLA Python module imports without warnings or errors
            testCase.verifyWarningFree(@() py.importlib.import_module(ModuleName), ...
                sprintf('Failed to import module: %s', ModuleName));

            module = py.importlib.import_module(ModuleName);

            testCase.verifyNotEmpty(module, ...
                sprintf('Module %s is empty or was not imported correctly', ModuleName));

            % __file__ attribute confirms module is a real file, not a namespace package
            testCase.verifyTrue(py.hasattr(module, '__file__'), ...
                sprintf('Module %s does not have __file__ attribute', ModuleName));
        end
    end
end