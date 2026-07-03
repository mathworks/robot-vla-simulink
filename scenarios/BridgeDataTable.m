classdef BridgeDataTable < BridgeData
    %BridgeDataTable - Table-top manipulation scenario (carrot, spoon, blocks).
    %
    % Usage:
    %   scenario = BridgeDataTable;
    %   scenario.TaskDescription = "put carrot on plate";
    %   % Then simulate "VLAClosedLoopControl.slx" model
    %
    % Supported tasks: "put carrot on plate", "move carrot near plate",
    %   "put the spoon on the towel", "stack the green block on the yellow block"

    % These properties are extracted from the following project referenced
    % by the simpler-env project
    % https://github.com/simpler-env/ManiSkill2_real2sim/tree/ef7a4d4fdf4b69f2c2154db5b15b9ac8dfe10682
    
    properties(Constant)

        %------------------------------------------------------------------
        % Scene
        %------------------------------------------------------------------
        % ManiSkill2_real2sim\mani_skill2_real2sim\envs\custom_scenes\put_on_in_scene.py
        % class: PutOnBridgeInSceneEnv/_setup_prepackaged_env_init_config
        % class: PutSpoonOnTableClothInScene, PutCarrotOnPlateInScene,
        % StackGreenCubeOnYellowCubeInScene

        BackgroundImg = imread(fullfile(BridgeData.SceneDir, 'bridge_real_eval_1.png'))

        SceneFile = fullfile(BridgeData.SceneDir , 'bridge_table_1_v1.fbx');

        SceneOffset = -sim3d.utils.Math.convertLoc([-2.0634, -2.8313, 0], 'matlab', 'unreal') %SAPIEN/ROS/MATLAB to Unreal coordinate system

        %------------------------------------------------------------------
        % Camera setup configuration
        %------------------------------------------------------------------
        % ManiSkill2_real2sim\mani_skill2_real2sim\agents\configs\widowx\defaults.py
        % class: WidowXBridgeDatasetCameraSetupConfig
        %   3rd_view_camera
        %   actor_uid="base_link"

        CameraTransl = [0.0, -0.16, 0.336]; % WidowXBridgeDatasetCameraSetupConfig % Matches with Unreal coordinate system somehow!

        CameraQuat = [0.909182, -0.0819809, 0.347277, 0.214629]; % WidowXBridgeDatasetCameraSetupConfig [w,x,y,z]
        % CameraQuat = [0.90069039 -0.07786596  0.36268423  0.2261722];


        %------------------------------------------------------------------
        % Robot Initial Configuration
        %------------------------------------------------------------------
        % ManiSkill2_real2sim\mani_skill2_real2sim\envs\custom_scenes\base_env.py
        % class: CustomSceneEnv: _load_agent
        RobotInitConfig = [-0.01840777,  0.0398835,   0.22242722,  -0.00460194,  1.36524296,  0.00153398, 0.037, 0.037];

        RobotBaseTransl = sim3d.utils.Math.convertLoc([0.147, 0.028, 0.87], 'matlab', 'unreal');  

        RobotBaseQuat = quaternion([0,0,0,1]); %[w,x,y,z]

        EndEffTargetTransl = [0 0 0];
    end

    properties
        %------------------------------------------------------------------
        % Task description
        %------------------------------------------------------------------
        TaskDescription = "put carrot on plate";        
        % TaskDescription = "move carrot near plate";
        %TaskDescription = "put the spoon on the towel";
        % TaskDescription = "stack the green block on the yellow block";
    end

    properties(Dependent)
        FingerClose % Finger close position based on object to be grasped
    end

    methods

        function val = get.FingerClose(obj)
            if contains(obj.TaskDescription, "carrot")
                val = 0.025;
            elseif contains(obj.TaskDescription, "spoon")
                val = obj.FingerPositionMax*0.4;
            elseif contains(obj.TaskDescription, "green block")
                val = 0.05/2;
            end
        end

        function setupSceneActor(obj, Actor, World)
            Actor.Translation = [0,0,0];
            bridgeTable = sim3d.Actor(ActorName='bridgeTable');
            World.add(bridgeTable, Actor)
            bridgeTable.load(obj.SceneFile)
            bridgeTable.propagate('PreciseContacts', true)
            bridgeTable.Translation = obj.SceneOffset;
        end

        function setupObjectActor(obj, Actor, World)
            if ~obj.Randomize
                rng(42, "twister")
            end
            Actor.Translation = [0,0,0];
            Actor.Rotation = [0,0,0];

            switch obj.TaskDescription
                case {"put carrot on plate", "move carrot near plate"}
                    [sourceObjFile, targetObjFile, sourceObjTransl, targetObjTransl] =...
                        putCarrotInScene(obj.Randomize);
                case 'put the spoon on the towel'
                    [sourceObjFile, targetObjFile, sourceObjTransl, targetObjTransl] = ...
                        putSpoonOnTableCloth(obj.Randomize);
                case "stack the green block on the yellow block"
                    [sourceObjFile, targetObjFile, sourceObjTransl, targetObjTransl] = ...
                        stackGreenBlockOnYelloBlock(obj.Randomize);
            end
            
            % Source: stationary destination object (plate, cloth, yellow block)
            sourceObj = sim3d.Actor('ActorName', 'sourceActor');
            World.add(sourceObj, Actor);
            sourceObj.load(fullfile(obj.ObjectDir, sourceObjFile))
            sourceObj.Translation = sourceObjTransl;
            sourceObj.Rotation = [0, 0, 0];
            sourceObj.propagate('ActorClassId', 250)
            sourceObj.propagate('PreciseContacts', true);

            % Target: object the robot picks up and places (carrot, spoon, green block)
            targetObj = sim3d.Actor('ActorName', 'targetActor');
            World.add(targetObj, Actor);
            targetObj.load(fullfile(obj.ObjectDir, targetObjFile))
            targetObj.Translation = targetObjTransl;
            targetObj.Rotation = [0,0,0];
            % targetObj.Rotation = [-pi/2, 0, pi/2];
            targetObj.propagate('ActorClassId', 240)
            targetObj.propagate('PreciseContacts', true);
            propagate(Actor, 'Mobility', sim3d.utils.MobilityTypes.Movable);
            % propagate(Actor, 'Gravity', true);
            % propagate(Actor, 'Physics', true);   
        end
    end
end

function [sourceObjFile, targetObjFile, sourceObjTransl, targetObjTransl] =...
    putCarrotInScene(randomize)

objectPoses = ...
    [-0.235, -0.075, -0.235,  0.075;
    -0.235, -0.075, -0.085, -0.075;
    -0.235, -0.075, -0.085,  0.075;
    -0.235,  0.075, -0.235, -0.075;
    -0.235,  0.075, -0.085, -0.075;
    -0.235,  0.075, -0.085,  0.075;
    -0.085, -0.075, -0.235, -0.075;
    -0.085, -0.075, -0.235,  0.075;
    -0.085, -0.075, -0.085,  0.075;
    -0.085,  0.075, -0.235, -0.075;
    -0.085,  0.075, -0.235,  0.075;
    -0.085,  0.075, -0.085, -0.075];

if randomize
    ind = randi(height(objectPoses));
else
    ind = 5;
end
sourceObjTransl = objectPoses(ind,1:2);
targetObjTransl = objectPoses(ind,3:4);

sourceObjTransl = [sourceObjTransl, 0.87];
targetObjTransl = [targetObjTransl, 0.89];

sourceObjFile = "bridge_plate_objaverse_larger.fbx";
targetObjFile = "bridge_carrot_generated_modified.fbx"; % to be moved
end

function [sourceObjFile, targetObjFile, sourceObjTransl, targetObjTransl] = ...
    putSpoonOnTableCloth(randomize)
objectPoses = ...
    [-0.235, -0.075, -0.235,  0.075;
    -0.235, -0.075, -0.085, -0.075;
    -0.235, -0.075, -0.085,  0.075;
    -0.235,  0.075, -0.235, -0.075;
    -0.235,  0.075, -0.085, -0.075;
    -0.235,  0.075, -0.085,  0.075;
    -0.085, -0.075, -0.235, -0.075;
    -0.085, -0.075, -0.235,  0.075;
    -0.085, -0.075, -0.085,  0.075;
    -0.085,  0.075, -0.235, -0.075;
    -0.085,  0.075, -0.235,  0.075;
    -0.085,  0.075, -0.085, -0.075];

if randomize
    ind = randi(height(objectPoses));
else
    ind = 4;
end
sourceObjTransl = objectPoses(ind,1:2);
targetObjTransl = objectPoses(ind,3:4);

sourceObjTransl = [sourceObjTransl, 0.87];
targetObjTransl = [targetObjTransl, 0.89];

sourceObjFile = "table_cloth_generated_shorter.fbx";
targetObjFile = "bridge_spoon_generated_modified.fbx"; % to be moved
end

function [sourceObjFile, targetObjFile, sourceObjTransl, targetObjTransl] = ...
                        stackGreenBlockOnYelloBlock(randomize)
objectPoses = ...
    [-0.21, -0.05, -0.21,  0.05;
    -0.21, -0.05, -0.11, -0.05;
    -0.21, -0.05, -0.11,  0.05;
    -0.21,  0.05, -0.21, -0.05;
    -0.21,  0.05, -0.11, -0.05;
    -0.21,  0.05, -0.11,  0.05;
    -0.11, -0.05, -0.21, -0.05;
    -0.11, -0.05, -0.21,  0.05;
    -0.11, -0.05, -0.11,  0.05;
    -0.11,  0.05, -0.21, -0.05;
    -0.11,  0.05, -0.21,  0.05;
    -0.11,  0.05, -0.11, -0.05;
    -0.26, -0.1 , -0.26,  0.1 ;
    -0.26, -0.1 , -0.06, -0.1 ;
    -0.26, -0.1 , -0.06,  0.1 ;
    -0.26,  0.1 , -0.26, -0.1 ;
    -0.26,  0.1 , -0.06, -0.1 ;
    -0.26,  0.1 , -0.06,  0.1 ;
    -0.06, -0.1 , -0.26, -0.1 ;
    -0.06, -0.1 , -0.26,  0.1 ;
    -0.06, -0.1 , -0.06,  0.1 ;
    -0.06,  0.1 , -0.26, -0.1 ;
    -0.06,  0.1 , -0.26,  0.1 ;
    -0.06,  0.1 , -0.06, -0.1 ];

if randomize
    ind = randi(height(objectPoses));
else
    ind = 5;
end
sourceObjTransl = objectPoses(ind,1:2);
targetObjTransl = objectPoses(ind,3:4);

sourceObjTransl = [sourceObjTransl, 0.89];
targetObjTransl = [targetObjTransl, 0.89];

sourceObjFile = "yellow_cube_3cm.fbx";
targetObjFile = "green_cube_3cm.fbx"; % to be moved

end