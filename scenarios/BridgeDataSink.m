classdef BridgeDataSink < BridgeData
    %BridgeDataSink - Sink-area manipulation scenario (eggplant into basket).
    %
    % Usage:
    %   scenario = BridgeDataSink;
    %   scenario.TaskDescription = "put eggplant into yellow basket";
    %   % Then simulate "VLAClosedLoopControl.slx" model

    properties(Constant)

        %------------------------------------------------------------------
        % Scene
        %------------------------------------------------------------------
        % ManiSkill2_real2sim\mani_skill2_real2sim\envs\custom_scenes\put_on_in_scene.py
        % class: PutEggplantInBasketScene/_setup_prepackaged_env_init_config

        BackgroundImg = imread(fullfile(BridgeData.SceneDir, 'bridge_sink.png'))

        SceneFile = fullfile(BridgeData.SceneDir, 'bridge_table_1_v2.fbx');

        SceneOffset = -sim3d.utils.Math.convertLoc([-2.0634, -2.8313, 0], 'matlab', 'unreal') %SAPIEN/ROS/MATLAB to Unreal coordinate system

        %------------------------------------------------------------------
        % Camera configuration
        %------------------------------------------------------------------
        % ManiSkill2_real2sim\mani_skill2_real2sim\agents\configs\widowx\defaults.py
        % class: WidowXSinkCameraSetupConfig
        % 3rd_view_camera
        % actor_uid="base_link"
        %
        % ManiSkill2_real2sim\mani_skill2_real2sim\envs\custom_scenes\put_on_in_scene.py
        % class: PutEggplantInBasketScene
        % "widowx_sink_camera_setup"

        CameraTransl = [-0.00300001, -0.21, 0.39];

        CameraQuat = [-0.907313, 0.0782, -0.36434, -0.194741];

        %------------------------------------------------------------------
        % Robot initial configuration
        %------------------------------------------------------------------
        % ManiSkill2_real2sim\mani_skill2_real2sim\envs\custom_scenes\base_env.py
        % class: CustomSceneEnv: _load_agent
        RobotInitConfig = [-0.2600599, -0.12875618, 0.04461369, -0.00652761, 1.7033415, -0.26983038, 0.037, 0.037];

        RobotBaseTransl = sim3d.utils.Math.convertLoc([0.127, 0.06, 0.85], 'matlab', 'unreal'); %0.147, 0.07 (default)

        RobotBaseQuat = quaternion([0,0,0,1]);

        EndEffTargetTransl = [-0.00 0 0];

        %------------------------------------------------------------------
        % Sink
        %------------------------------------------------------------------
        % ManiSkill2_real2sim\mani_skill2_real2sim\envs\custom_scenes\put_on_in_scene.py
        % class: PutEggplantInBasketScene/_initialize_actors
        SinkTransl = sim3d.utils.Math.convertLoc([-0.16, 0.13, 0.88], 'matlab', 'unreal');
	end

	properties
        %------------------------------------------------------------------
        % Task description
        %------------------------------------------------------------------
        TaskDescription = "put eggplant into yellow basket";

    end

    properties(Dependent)
        FingerClose % Finger close position based on object to be grasped
    end

    methods

        function val = get.FingerClose(obj)
              val = obj.FingerPositionMax*0.7;
        end

        function setupSceneActor(obj, Actor, World)

            Actor.Translation = [0,0,0];

            bridgeTable = sim3d.Actor(ActorName='bridgeTable');
            World.add(bridgeTable, Actor)
            bridgeTable.load(obj.SceneFile)
            bridgeTable.propagate('PreciseContacts', true)
            bridgeTable.Translation = obj.SceneOffset;

            sink = sim3d.Actor(ActorName='sink');
            World.add(sink, Actor);
            sink.load(fullfile(obj.ObjectDir , 'sink.fbx'))
            sink.Translation = obj.SinkTransl;
            sink.propagate('PreciseContacts', true);
        end

        function setupObjectActor(obj, Actor, World)

            Actor.Translation = [0 0 0];
            Actor.Rotation = [0 0 0];

            % ManiSkill2_real2sim\mani_skill2_real2sim\envs\custom_scenes\put_on_in_scene.py
            % class: PutEggplantInBasketScene
            [sourceTransl, sourceQuat] = objectPoses(obj.Randomize);
            sourceTransl = [sourceTransl, 0.94];
            sourceTransl = sim3d.utils.Math.convertLoc(sourceTransl, 'matlab', 'unreal');
            rot = quat2eul(sourceQuat);
            % rot = [roll, pitch, yaw];
            rot = sim3d.utils.Math.convertRot(rot, 'matlab', 'unreal');
            % rot = [-pi/2, 0, pi/4];

            eggplant = sim3d.Actor('ActorName', 'targetActor');
            World.add(eggplant, Actor);
            eggplant.load(fullfile(obj.ObjectDir, 'eggplant.fbx'));
            eggplant.propagate('ActorClassId', 250)

            eggplant.Translation = sourceTransl;
            eggplant.Rotation = rot;
            
            % propagate(eggplant, 'Translation', sourceTransl);
            % propagate(eggplant, 'Rotation', rot);

            % eggplant_0 = findBy(Actor, 'ActorName', 'eggplant_0', 'first');   
            % propagate(eggplant_0, 'Translation', sourceTransl);
            % propagate(eggplant_0, 'Rotation', rot);

            propagate(Actor, 'Mobility', sim3d.utils.MobilityTypes.Movable);
            % propagate(Actor, 'Gravity', false);
            % propagate(Actor, 'Physics', true);
            % propagate(Actor, 'Friction', 1);
            % propagate(Actor, 'Restitution', 0);
            % eggplant.Mass = 0.2;
        end
    end
end

function [sourceTransl, sourceQuat] = objectPoses(randomize)

% ManiSkill2_real2sim\mani_skill2_real2sim\envs\custom_scenes\put_on_in_scene.py
% class: PutEggplantInBasketScene
sourceTransl = ...
    [-0.115,  0.191;
    -0.115,  0.201;
    -0.115,  0.211;
    -0.115,  0.221;
    -0.095,  0.191;
    -0.095,  0.201;
    -0.095,  0.211;
    -0.095,  0.221;
    ];

if randomize
    ind = randi(height(sourceTransl));
else
    ind = 6;
end
sourceTransl = sourceTransl(ind,:);

sourceQuat = [1,0,0,0;
    0.92387953,0,0,0.38268343;
    0.92387953,0,0,-0.38268343];
if randomize
    rotInd = randi(height(sourceQuat));
else
    rotInd = 1;
end
sourceQuat = sourceQuat(rotInd,:);

end