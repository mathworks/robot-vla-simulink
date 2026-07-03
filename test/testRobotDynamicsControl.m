classdef testRobotDynamicsControl < matlab.unittest.TestCase
    % Verify Simulink robot dynamics model tracks commanded end-effector poses.

    properties (TestParameter)
        gripperAction = {1, -1}
    end

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
            load_system('RobotDynamicsControlTest');
            testCase.addTeardown(@() close_system('RobotDynamicsControlTest', 0));
        end
    end

    methods (Test)

        function verifyEndEffectorControl(testCase, gripperAction)
            % Verify that the robot dynamics control achieves the desired end-effector pose

            action = [0.012 -0.02996 -0.00671 -0.0225 0.003636 -0.01428 gripperAction];
            scenario = BridgeDataTable;

            % Simulink reads action/scenario from base workspace
            assignin('base', 'action', action);
            assignin('base', 'scenario', scenario);

            refEEPose = scenario.RobotInitState;
            out = sim('RobotDynamicsControlTest');
            testCase.verifyAllOutputs(out, scenario, action, refEEPose);
        end

        function verifyZeroActionMaintainsPose(testCase)
            % Verify that a zero-delta action keeps the robot at its initial pose

            scenario = BridgeDataTable;
            noaction = zeros(1, 7);
            noaction(7) = 1; % gripper open

            assignin('base', 'scenario', scenario);
            assignin('base', 'action', noaction);

            out = sim('RobotDynamicsControlTest');
            testCase.verifyAllOutputs(out, scenario, noaction, scenario.RobotInitState);
        end
    end

    methods (Access = private)
        function verifyAllOutputs(testCase, out, scenario, action, refEEPose)
            actualEEPose = out.EEPose.Data(end, :);

            positionTolerance = 0.001; % [m]
            orientationTolerance = 0.1*pi/180; % [rad]

            % Final EE pose should equal initial pose + commanded action delta
            testCase.verifyEqual(actualEEPose(1:3), refEEPose(1:3) + action(1:3), ...
                'AbsTol', positionTolerance, ...
                'End-effector position should match reference plus action');

            testCase.verifyEqual(actualEEPose(4:6), refEEPose(4:6) + action(4:6), ...
                'AbsTol', orientationTolerance, ...
                'End-effector orientation should match reference plus action');

            % Cross-check: forward kinematics from joint config should agree with logged EE pose
            config = out.Config.Data(end, :);
            robot = scenario.Robot;
            tform = getTransform(robot, config, scenario.EndEffector);
            computedPose = [tform(1:3, 4)', rotm2eul(tform(1:3, 1:3), 'ZYX')];
            testCase.verifyEqual(computedPose(1:3), actualEEPose(1:3), ...
                'AbsTol', positionTolerance, ...
                'Computed pose from config should match actual EE pose');

            gripperState = out.Config.Data(end, end-1:end);
            if action(7) == 1
                expectedGripperState = scenario.FingerPositionMax*[1,1];
                gripperStateStr = 'open';
            else
                expectedGripperState = max(scenario.FingerPositionMin, scenario.FingerClose)*[1,1];
                gripperStateStr = 'close';
            end

            testCase.verifyEqual(gripperState, expectedGripperState, ...
                'AbsTol', 0.01, ...
                sprintf('Gripper should be in %s state when action(7) = %d', ...
                gripperStateStr, action(7)));

            testCase.verifySize(actualEEPose(1:3), [1 3]);
        end
    end
end
