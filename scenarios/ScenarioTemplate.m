classdef ScenarioTemplate < Scenario
    %SCENARIOTEMPLATE Template for creating a simulation scenario for a new robot or dataset.
    %
    % Copy this file, rename the class, and fill in the required properties
    % and methods. For Bridge dataset scenarios using the WidowX robot,
    % subclass BridgeData instead.
    %
    % Usage:
    %   scenario = MyScenario;
    %   scenario.TaskDescription = "your task";
    %   sim("VLAClosedLoopControl.slx", "StopTime", "30")

    properties (Constant)

        % Background image for green-screening (real-world photo of the scene)
        BackgroundImg = imread('path/to/background.png')

        % Camera pose relative to robot base link
        CameraTransl = [0, 0, 0];       % [x, y, z] in meters
        CameraQuat   = [1, 0, 0, 0];    % [w, x, y, z]

        % Robot placement in Unreal world frame
        RobotBaseTransl = [0, 0, 0];
        RobotBaseQuat   = quaternion([1, 0, 0, 0]);  % [w, x, y, z]

        % Robot initial joint configuration [q1..qN, fingerL, fingerR]
        RobotInitConfig = zeros(1, 8);

        % End-effector target translation offset
        EndEffTargetTransl = [0, 0, 0];

        % Robot model
        Robot         = importrobot('path/to/robot.urdf', DataFormat='row')
        EndEffector   = 'end_effector_link';
        BaseLink      = 'base_link';
        FingerPositionMin = 0;
        FingerPositionMax = 0.04;

        % Camera intrinsics
        ImageSize     = [480, 640];      % [height, width] in pixels
        FocalLength   = [600, 600];      % [fx, fy] in pixels
        OpticalCenter = [320, 240];      % [cx, cy] in pixels

        Ts = 1;                          % Robot policy sample period [s]
    end

    properties
        TaskDescription = "describe your task";
    end

    properties (Dependent)
        CameraRot
        RobotBaseRot
        RobotInitState
        FingerClose
    end

    methods

        function rot = get.CameraRot(obj)
            eulAngles = so3(quaternion(obj.CameraQuat)).eul; % ZYX
            [yaw, pitch, roll] = deal(eulAngles(1), eulAngles(2), eulAngles(3));
            rot = [roll, pitch, yaw];
        end

        function rot = get.RobotBaseRot(obj)
            eulAngles = so3(quaternion(obj.RobotBaseQuat)).eul; % ZYX
            [yaw, pitch, roll] = deal(eulAngles(1), eulAngles(2), eulAngles(3));
            rot = sim3d.utils.Math.convertRot([roll, pitch, yaw], 'matlab', 'unreal');
        end

        function state = get.RobotInitState(obj)
            T = obj.Robot.getTransform(obj.RobotInitConfig, obj.EndEffector, obj.BaseLink);
            state = [tform2trvec(T), tform2eul(T), 1];
        end

        function val = get.FingerClose(obj)
            % Set the finger-closed position for the object being grasped.
            val = obj.FingerPositionMax * 0.5;
        end

        function setupRobotActor(obj, Actor, World)
            robotActor = sim3d.Actor(ActorName="RobotActor");
            World.add(robotActor, Actor);
            robotActor.load(obj.Robot);
            robotActor.Translation = obj.RobotBaseTransl;
            robotActor.Rotation    = obj.RobotBaseRot;
            robotActor.propagate('Mobility', sim3d.utils.MobilityTypes.Movable);
            robotActor.propagate('ActorClassId', 200);
            robotActor.propagate('Color', [0, 0, 0]);
            robotActor.propagate('VertexBlend', 0);
            robotActor.propagate('Flat', 0);
        end

        function setupSceneActor(obj, Actor, World)
            % Load scene geometry (table, countertop, walls, etc.)
            Actor.Translation = [0, 0, 0];
            sceneActor = sim3d.Actor(ActorName='sceneActor');
            World.add(sceneActor, Actor);
            sceneActor.load('path/to/scene.fbx');
            sceneActor.propagate('PreciseContacts', true);
        end

        function setupObjectActor(obj, Actor, World)
            % Place task objects: the target location and the object to pick up.
            Actor.Translation = [0, 0, 0];
            Actor.Rotation    = [0, 0, 0];

            sourceObj = sim3d.Actor('ActorName', 'sourceActor');
            World.add(sourceObj, Actor);
            sourceObj.load('path/to/target_location.fbx');
            sourceObj.Translation = sim3d.utils.Math.convertLoc([0, 0, 0], 'matlab', 'unreal');
            sourceObj.propagate('ActorClassId', 250);
            sourceObj.propagate('PreciseContacts', true);

            targetObj = sim3d.Actor('ActorName', 'targetActor');
            World.add(targetObj, Actor);
            targetObj.load('path/to/object_to_grasp.fbx');
            targetObj.Translation = sim3d.utils.Math.convertLoc([0, 0, 0], 'matlab', 'unreal');
            targetObj.propagate('ActorClassId', 240);
            targetObj.propagate('PreciseContacts', true);

            propagate(Actor, 'Mobility', sim3d.utils.MobilityTypes.Movable);
        end
    end
end
