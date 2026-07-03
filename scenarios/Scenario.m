classdef (Abstract) Scenario < handle
    %SCENARIO Abstract base class defining the interface for simulation scenarios.
    %
    % Subclass this to create a scenario for a new robot or dataset.
    % For Bridge dataset scenarios using the WidowX robot, subclass BridgeData.
    %
    % See also BridgeData, BridgeDataTable, BridgeDataSink, ScenarioTemplate

    properties (Abstract, Constant)

        % Background image for green-screening (real-world photograph of the scene)
        BackgroundImg

        % Camera pose relative to robot base link
        CameraTransl        % [x, y, z] in meters
        CameraQuat          % [w, x, y, z] quaternion

        % Robot placement in the world frame
        RobotBaseTransl
        RobotBaseQuat

        % Robot initial joint configuration [q1..qN, fingerL, fingerR]
        RobotInitConfig

        % End-effector target translation offset
        EndEffTargetTransl

        % Robot model
        Robot               % rigidBodyTree
        EndEffector         % end-effector link name
        BaseLink            % base link name
        FingerPositionMin   % finger joint lower limit [m or rad]
        FingerPositionMax   % finger joint upper limit [m or rad]

        % Camera intrinsics
        ImageSize           % [height, width] in pixels
        FocalLength         % [fx, fy] in pixels
        OpticalCenter       % [cx, cy] in pixels

        % Timing
        Ts                  % Robot policy sample period [s]
    end

    properties (Abstract)
        TaskDescription     % Natural language task description
    end

    properties (Abstract, Dependent)
        CameraRot           % Camera rotation in Unreal frame
        RobotBaseRot        % Robot base rotation in Unreal frame
        RobotInitState      % Initial end-effector state [x,y,z,yaw,pitch,roll,gripper]
        FingerClose         % Finger closed position for the grasped object
    end

    methods (Abstract)
        setupRobotActor(obj, Actor, World)
        setupSceneActor(obj, Actor, World)
        setupObjectActor(obj, Actor, World)
    end
end
