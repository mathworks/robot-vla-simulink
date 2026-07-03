classdef (Abstract) BridgeData < Scenario
    %BRIDGEDATA Base configuration for the BridgeData V2 simulation environment.
    %   Defines shared constants (robot specs, camera intrinsics, scene paths)
    %   inherited by scenario-specific subclasses (BridgeDataTable, BridgeDataSink).    

    % [1] Reference: Li, Xuanlin, et al. "Evaluating Real-World Robot
    % Manipulation Policies in Simulation." ArXiv:2405.05941 [cs.RO], May
    % 2024. arXiv.org, https://arxiv.org/abs/2405.05941. GitHub Project
    % Page: https://simpler-env.github.io

    % These properties are extracted from the following project referenced
    % by the simpler-env project
    % https://github.com/simpler-env/ManiSkill2_real2sim/tree/ef7a4d4fdf4b69f2c2154db5b15b9ac8dfe10682

    properties(Constant)

        % Scene/model assets converted from glb/dae to fbx via Blender
        SceneDir = fullfile(getRootDir, 'data/bridge');
        ObjectDir = fullfile(getRootDir, 'data/models');

        %------------------------------------
        % Robot properties
        %------------------------------------
        RobotName = 'WidowX'
        Robot = importrobot(getWidowXFilePath, DataFormat='row');
        EndEffector = 'ee_gripper_link';
        BaseLink = 'base_link';
        NumStates = 7; % [x, y, z, yaw, pitch, roll, gripper_opening]
        NumConfig = length(homeConfiguration(BridgeData.Robot));
        FingerLinkIds = [7,8];        
        FingerPositionMin = 0.015   % Finger joint lower limit [m]
        FingerPositionMax = 0.037   % Finger joint upper limit [m]

        %------------------------------------
        % PID gain parameters
        %------------------------------------
        PGain = 500*eye(6)*2;
        IGain = 100*eye(6)*2;

        %------------------------------------
        % Camera properties
        %------------------------------------
        ImageSize = [480, 640]; % [height, width] in pixels
        FocalLength = [623.588, 623.588]; % [fx, fy] in pixels
        OpticalCenter = [319.501, 239.545]; % [cx, cy] in pixels

        % Viewer camera for Unreal scene preview (not the robot-mounted camera)
        ViewerTranslation = sim3d.utils.Math.convertLoc([0.8, 0.2, 1.5], 'matlab', 'unreal');
        ViewerRot = sim3d.utils.Math.convertRot([0., 0.5, pi], 'matlab', 'unreal'); % [roll, pitch, yaw] in MATLAB frame

        Ts = 1; % Robot policy sampling period [s]
    end

    properties
        Randomize (1,1) logical = false  % Set true to randomize object placement each simulation
    end

    properties (Dependent)
        CameraRot
        RobotBaseRot
        RobotInitState
    end

    methods

        function rot = get.CameraRot(obj)
            eulAngles = so3(quaternion(obj.CameraQuat)).eul; % ZYX
            [cameraYaw, cameraPitch, cameraRoll] = deal(eulAngles(1), eulAngles(2), eulAngles(3));
            rot = [cameraRoll, cameraPitch, cameraYaw];
        end

        function rot = get.RobotBaseRot(obj)
            eulAngles = so3(quaternion(obj.RobotBaseQuat)).eul; % ZYX
            [robotYaw, robotPitch, robotRoll] = deal(eulAngles(1), eulAngles(2), eulAngles(3));
            rot = sim3d.utils.Math.convertRot([robotRoll, robotPitch, robotYaw], 'matlab', 'unreal');
        end

        function state = get.RobotInitState(obj)
            robotInitT = obj.Robot.getTransform(obj.RobotInitConfig, obj.EndEffector, obj.BaseLink);
            robotInitXYZ = tform2trvec(robotInitT);
            robotInitRot = tform2eul(robotInitT);
            state = [robotInitXYZ, robotInitRot, 1];
        end

        function setupRobotActor(obj, Actor, World)
            robotActor = sim3d.Actor(ActorName="RobotActor");
            World.add(robotActor, Actor);
            robotActor.load(obj.Robot);
            robotActor.Translation = obj.RobotBaseTransl;
            robotActor.Rotation = obj.RobotBaseRot;
            robotActor.propagate('Mobility', sim3d.utils.MobilityTypes.Movable);
            robotActor.propagate('ActorClassId', 200);
            robotActor.propagate('Color', [0,0,0]);
            robotActor.propagate('VertexBlend', 0);
            robotActor.propagate('Flat', 0);
        end
    end
end

function urdfFile = getWidowXFilePath
    urdfFile = fullfile(fileparts(mfilename('fullpath')), '..', 'data', 'widowx_description', 'wx250s.urdf');
end

function rootdir = getRootDir
rootdir = fullfile(fileparts(mfilename('fullpath')),'..');
end